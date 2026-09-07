// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Filipino Pilipino (`fil`).
class AppLocalizationsFil extends AppLocalizations {
  AppLocalizationsFil([String locale = 'fil']) : super(locale);

  @override
  String get devOptionsClipRecovery => 'Pagbawi ng clip';

  @override
  String get devOptionsClipRecoveryDescription =>
      'Naghahanap ng mga recording na nakaimbak sa ibang account at mga video file na wala nang tumutukoy na entry.';

  @override
  String get devOptionsClipRecoveryScan => 'I-scan';

  @override
  String get devOptionsClipRecoveryFailure => 'Nabigo ang pagbawi ng clip';

  @override
  String devOptionsClipRecoveryVisible(int clips, int drafts) {
    return 'Nakikita ngayon: $clips clip, $drafts draft';
  }

  @override
  String get devOptionsClipRecoveryOtherAccounts => 'Nakatago sa ibang account';

  @override
  String devOptionsClipRecoveryCounts(int clips, int drafts) {
    return '$clips clip, $drafts draft';
  }

  @override
  String get devOptionsClipRecoveryClaim => 'Ilipat sa account na ito';

  @override
  String devOptionsClipRecoveryOrphanFiles(int count, String size) {
    return 'Mga file na walang tumutukoy: $count ($size)';
  }

  @override
  String get devOptionsClipRecoveryImport => 'Ibalik sa library';

  @override
  String get devOptionsClipRecoveryEmpty => 'Walang mababawi';

  @override
  String devOptionsClipRecoveryRecovered(int count) {
    return 'Nabawi ang $count clip';
  }

  @override
  String get devOptionsClipRecoveryCopied => 'Nakopya ang recovery report';

  @override
  String get devOptionsStorageFootprint => 'Paggamit ng storage';

  @override
  String get devOptionsStorageFootprintDescription =>
      'Bawat folder na sinusulatan ng app. Bahagi lang nito ang nababawi kapag nag-clear ng cache.';

  @override
  String get devOptionsStorageFootprintMeasure => 'Sukatin';

  @override
  String devOptionsStorageFootprintTotal(String size) {
    return 'Kabuuan: $size';
  }

  @override
  String get devOptionsStorageFootprintCopied => 'Nakopya ang storage report';

  @override
  String get devOptionsStorageFootprintFailure => 'Hindi masukat ang storage';

  @override
  String get feedTuningMoreLabel => 'Mas marami pa nito';

  @override
  String get feedTuningLessLabel => 'Bawasan ang ganito';

  @override
  String get feedTuningUndo => 'I-undo';

  @override
  String get dmMessageBubbleVideoReplyHint => 'Buksan ang tinukoy na video';

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => 'Mga Setting';

  @override
  String get settingsSecureAccount => 'I-secure ang iyong account';

  @override
  String get settingsSessionExpired => 'Nag-expire na ang session';

  @override
  String get settingsSessionExpiredSubtitle =>
      'Mag-sign in ulit para mabalik ang buong access';

  @override
  String get settingsAccountRestoreFailed => 'Account Restore Failed';

  @override
  String get settingsAccountRestoreFailedSwitchMessage =>
      'We couldn\'t unlock that account on this device. Signing back into it means signing out of the one you\'re on now.';

  @override
  String get settingsCreatorAnalytics => 'Creator Analytics';

  @override
  String get settingsSupportCenter => 'Support Center';

  @override
  String get settingsNotifications => 'Mga Notification';

  @override
  String get settingsBlueskyPublishing => 'Bluesky Publishing';

  @override
  String get settingsBlueskyPublishingSubtitle =>
      'Pamahalaan ang crossposting sa Bluesky';

  @override
  String get settingsNostrSettings => 'Mga Nostr Setting';

  @override
  String get settingsIntegratedApps => 'Mga Integrated App';

  @override
  String get settingsIntegratedAppsSubtitle =>
      'Mga inaprubahang third-party app na tumatakbo sa loob ng Divine';

  @override
  String get settingsExperimentalFeatures => 'Mga Experimental Feature';

  @override
  String get settingsExperimentalFeaturesSubtitle =>
      'Mga tweak na maaaring magka-glitch—subukan kung curious ka.';

  @override
  String get settingsLegal => 'Legal';

  @override
  String get settingsIntegrationPermissions => 'Mga Integration Permission';

  @override
  String get settingsIntegrationPermissionsSubtitle =>
      'Tingnan at bawiin ang mga naka-save na integration approval';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsVersionEmpty => 'Version';

  @override
  String get settingsDeveloperModeAlreadyEnabled =>
      'Naka-enable na ang developer mode';

  @override
  String get settingsDeveloperModeEnabled => 'Na-enable ang developer mode!';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    return '$count pang tap para ma-enable ang developer mode';
  }

  @override
  String get settingsShareDivine => 'I-share ang Divine sa mga kaibigan mo';

  @override
  String get settingsSwitchAccount => 'Magpalit ng account';

  @override
  String get settingsAddAnotherAccount => 'Magdagdag ng isa pang account';

  @override
  String get settingsAccountSwitchFailed =>
      'Hindi mailipat ang mga account. Pakisubukan ulit.';

  @override
  String get settingsUnsavedDraftsTitle => 'Mga Hindi Naka-save na Draft';

  @override
  String get settingsUploadInProgressTitle => 'May kasalukuyang upload';

  @override
  String settingsUploadInProgressMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mga video',
      one: 'video',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mga video mo bilang mga draft',
      one: 'video mo bilang draft',
    );
    return 'May $count pa ring $_temp0 na nag-a-upload. Kapag nagpalit ka ng account, hihinto ang upload — mananatili ang $_temp1 sa account na ito.';
  }

  @override
  String settingsUnsavedDraftsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mga draft',
      one: 'draft',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mga draft',
      one: 'draft',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mga ito',
      one: 'draft na ito',
    );
    return 'Mayroon kang $count na hindi naka-save na $_temp0. Kapag nagpalit ka ng account, mananatili ang iyong $_temp1, pero baka gusto mong i-publish o tingnan muna ang $_temp2.';
  }

  @override
  String get settingsCancel => 'Kanselahin';

  @override
  String get settingsSwitchAnyway => 'Magpalit pa rin';

  @override
  String get settingsSessionExpiredSwitchMessage =>
      'Nag-expire na ang session ng account na iyon. Ang mag-sign in ulit doon ay mangangahulugang mag-sign out sa account na ginagamit mo ngayon.';

  @override
  String get settingsAppVersionLabel => 'Bersyon ng app';

  @override
  String get settingsAppLanguage => 'Wika ng App';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language (default ng device)';
  }

  @override
  String get settingsAppLanguageTitle => 'Wika ng App';

  @override
  String get settingsAppLanguageDescription =>
      'Piliin ang wika para sa interface ng app';

  @override
  String get settingsAppLanguageUseDeviceLanguage =>
      'Gamitin ang wika ng device';

  @override
  String get settingsGeneralTitle => 'Mga pangkalahatang setting';

  @override
  String get settingsContentSafetyTitle => 'Content at Safety';

  @override
  String get generalSettingsSectionIntegrations => 'MGA INTEGRATION';

  @override
  String get generalSettingsSectionViewing => 'PANONOOD';

  @override
  String get generalSettingsSectionCreating => 'PAGLIKHA';

  @override
  String get generalSettingsSectionApp => 'APP';

  @override
  String get appearanceSettingsTitle => 'Hitsura';

  @override
  String get appearanceSettingsSubtitle =>
      'Piliin kung paano magmumukha ang Divine sa device na ito';

  @override
  String get appearanceSettingsSystem => 'Default ng system';

  @override
  String get appearanceSettingsLight => 'Maliwanag';

  @override
  String get appearanceSettingsDark => 'Madilim';

  @override
  String get generalSettingsClosedCaptions => 'Closed Captions';

  @override
  String get generalSettingsClosedCaptionsSubtitle =>
      'Ipakita ang captions kapag may captions ang video';

  @override
  String get generalSettingsVideoShapeSquareOnly => 'Square videos lang';

  @override
  String get generalSettingsVideoShapeSquareOnlySubtitle =>
      'Panatilihin ang feeds sa classic na square format';

  @override
  String get contentPreferencesTitle => 'Mga Content Preference';

  @override
  String get contentPreferencesContentFilters => 'Mga Content Filter';

  @override
  String get contentPreferencesContentFiltersSubtitle =>
      'Pamahalaan ang mga content warning filter';

  @override
  String get contentPreferencesContentLanguage => 'Wika ng Content';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language (default ng device)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      'Tag-an ang iyong mga video ng wika para mai-filter ng manonood ang content.';

  @override
  String get contentPreferencesUseDeviceLanguage =>
      'Gamitin ang wika ng device (default)';

  @override
  String get contentPreferencesAudioSharing =>
      'Gawing magagamit ng iba ang audio ko';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      'Kapag naka-enable, magagamit ng iba ang audio mula sa mga video mo';

  @override
  String get contentPreferencesMusicMode => 'Music mode';

  @override
  String get contentPreferencesMusicModeSubtitle =>
      'Ini-skip ang noise cleanup na pumipipi sa mga instrumento. Mas maganda sa musika, mas magaspang sa boses.';

  @override
  String get contentPreferencesAccountLabels => 'Mga Account Label';

  @override
  String get contentPreferencesAccountLabelsEmpty =>
      'I-label mo ang sarili mong content';

  @override
  String get contentPreferencesAccountContentLabels =>
      'Mga Account Content Label';

  @override
  String get contentPreferencesClearAll => 'I-clear lahat';

  @override
  String get contentPreferencesSelectAllThatApply =>
      'Piliin lahat ng tumutugma sa account mo';

  @override
  String get contentPreferencesDoneNoLabels => 'Tapos na (Walang Label)';

  @override
  String contentPreferencesDoneCount(int count) {
    return 'Tapos na ($count napili)';
  }

  @override
  String get contentPreferencesAudioInputDevice => 'Device para sa audio input';

  @override
  String get contentPreferencesAutoRecommended => 'Auto (inirerekomenda)';

  @override
  String get contentPreferencesAutoSelectsBest =>
      'Awtomatikong pumipili ng pinakamagandang microphone';

  @override
  String get contentPreferencesSelectAudioInput => 'Pumili ng Audio Input';

  @override
  String get contentPreferencesUnknownMicrophone => 'Hindi Kilalang Microphone';

  @override
  String get contentFiltersAdultContent => 'NILALAMAN PARA SA MATATANDA';

  @override
  String get contentFiltersViolenceGore => 'KARAHASAN AT GORE';

  @override
  String get contentFiltersSubstances => 'MGA SUBSTANSIYA';

  @override
  String get contentFiltersOther => 'IBA PA';

  @override
  String get contentFiltersAgeGateMessage =>
      'I-verify ang edad mo sa Safety & Privacy settings para i-unlock ang mga adult content filter';

  @override
  String get contentFiltersShow => 'Ipakita';

  @override
  String get contentFiltersWarn => 'Babala';

  @override
  String get contentFiltersFilterOut => 'I-filter Out';

  @override
  String get profileBlockedAccountNotAvailable =>
      'Hindi available ang account na ito';

  @override
  String get profileInvalidId => 'Invalid ang profile ID';

  @override
  String profileShareText(String displayName, String npub) {
    return 'Tingnan si $displayName sa Divine!\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return 'Si $displayName sa Divine';
  }

  @override
  String get profileShareFailed => 'Hindi na-share ang profile. Subukan ulit.';

  @override
  String get profileCopyPublicKey => 'Kopyahin ang public key (npub)';

  @override
  String get profileGetEmbedCode => 'Kunin ang embed code';

  @override
  String get profilePublicKeyCopied => 'Nakopya na sa clipboard ang public key';

  @override
  String get profileEmbedCodeCopied => 'Nakopya na sa clipboard ang embed code';

  @override
  String get profileMoreTooltip => 'Higit pa';

  @override
  String get profileMoreSemanticLabel => 'Iba pang options';

  @override
  String get profileAvatarLightboxBarrierLabel => 'Isara ang avatar';

  @override
  String get profileAvatarLightboxCloseSemanticLabel =>
      'Isara ang avatar preview';

  @override
  String get profileFollowingLabel => 'Sinusundan';

  @override
  String get profileFollowLabel => 'Sundan';

  @override
  String get profileBlockedLabel => 'Naka-block';

  @override
  String get profileFollowersLabel => 'Mga Follower';

  @override
  String get profileFollowingStatLabel => 'Sinusundan';

  @override
  String get profileVideosLabel => 'Mga Video';

  @override
  String get profileCollabsLabel => 'Mga Collab';

  @override
  String get profileLikedLabel => 'Na-like';

  @override
  String get profileRepostsLabel => 'Mga Repost';

  @override
  String get profileListsLabel => 'Mga List';

  @override
  String get profileCommentsLabel => 'Mga Komento';

  @override
  String profileCollaboratorInvitePendingHeadline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count collaborator invite ang kailangan pang ipadala',
      one: '$count collaborator invite ang kailangan pang ipadala',
    );
    return '$_temp0';
  }

  @override
  String get profileCollaboratorInvitePendingDetail =>
      'Naka-queue pa rin ang invite. Subukan ulit dito.';

  @override
  String profileCollaboratorInvitePendingDetailWithTitle(String title) {
    return 'Para sa \"$title\". Subukan ulit dito.';
  }

  @override
  String get profileCollaboratorInviteRetryAction => 'Subukan ulit';

  @override
  String get profileCollaboratorInviteRetryingAction => 'Sinusubukan ulit';

  @override
  String get profileCollaboratorInviteRetryUnavailable =>
      'Hindi available ngayon ang pag-retry ng collaborator invite.';

  @override
  String profileCollaboratorInviteRetryResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count collaborator invite ang kailangan pang ipadala.',
      one: '$count collaborator invite ang kailangan pang ipadala.',
      zero: 'Naipadala na ang mga collaborator invite.',
    );
    return '$_temp0';
  }

  @override
  String profileCollaboratorInviteBlockedResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count collaborator ang hindi makakatanggap ng mga invite.',
      one: '$count collaborator ang hindi makakatanggap ng mga invite.',
    );
    return '$_temp0';
  }

  @override
  String profileFollowerCountUsers(int count) {
    return '$count user';
  }

  @override
  String profileBlockTitle(String displayName) {
    return 'I-block si $displayName?';
  }

  @override
  String get profileBlockExplanation => 'Kapag nag-block ka ng user:';

  @override
  String get profileBlockBulletHidePosts =>
      'Hindi na lalabas ang mga post nila sa feed mo.';

  @override
  String get profileBlockBulletCantView =>
      'Hindi na nila makikita ang profile mo, hindi ka masusundan, at hindi makikita ang mga post mo.';

  @override
  String get profileBlockBulletNoNotify =>
      'Hindi sila aabisuhan tungkol sa pagbabagong ito.';

  @override
  String get profileBlockBulletYouCanView =>
      'Makikita mo pa rin ang profile nila.';

  @override
  String profileBlockConfirmButton(String displayName) {
    return 'I-block si $displayName';
  }

  @override
  String get profileCancelButton => 'Kanselahin';

  @override
  String get profileLearnMore => 'Alamin pa';

  @override
  String profileUnblockTitle(String displayName) {
    return 'I-unblock si $displayName?';
  }

  @override
  String get profileUnblockExplanation =>
      'Kapag in-unblock mo ang user na ito:';

  @override
  String get profileUnblockBulletShowPosts =>
      'Lalabas ang mga post nila sa feed mo.';

  @override
  String get profileUnblockBulletCanView =>
      'Makikita nila ang profile mo, masusundan ka nila, at makikita ang mga post mo.';

  @override
  String get profileUnblockBulletNoNotify =>
      'Hindi sila aabisuhan tungkol sa pagbabagong ito.';

  @override
  String get profileLearnMoreAt => 'Alamin pa sa ';

  @override
  String get profileUnblockButton => 'I-unblock';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return 'I-unfollow si $displayName';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return 'I-block si $displayName';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return 'I-unblock si $displayName';
  }

  @override
  String profileReportDisplayName(String displayName) {
    return 'I-report si $displayName';
  }

  @override
  String profileAddToListDisplayName(String displayName) {
    return 'Idagdag si $displayName sa isang list';
  }

  @override
  String get profileNoCollabsTitle => 'Wala pang collab';

  @override
  String get profileCollabsOwnEmpty =>
      'Lalabas dito ang mga video na nag-collab ka.';

  @override
  String get profileCollabsOtherEmpty =>
      'Lalabas dito ang mga video na nag-collab sila.';

  @override
  String get profileErrorLoadingCollabs =>
      'May error sa pag-load ng mga collab video';

  @override
  String get profileNoSavedVideosTitle => 'Wala pang naka-save';

  @override
  String get profileSavedOwnEmpty =>
      'Mag-bookmark ng video mula sa share sheet at lalabas dito.';

  @override
  String get profileErrorLoadingSaved =>
      'May error sa pag-load ng saved videos';

  @override
  String get profileNoCommentsOwnTitle => 'Wala pang komento';

  @override
  String get profileNoCommentsOtherTitle => 'Wala pang komento';

  @override
  String get profileCommentsOwnEmpty =>
      'Lalabas dito ang mga komento at reply mo.';

  @override
  String get profileCommentsOtherEmpty =>
      'Lalabas dito ang mga komento at reply nila.';

  @override
  String get profileErrorLoadingComments =>
      'May error sa pag-load ng mga komento';

  @override
  String get profileVideoRepliesSection => 'Mga Video Reply';

  @override
  String get profileCommentsSection => 'Mga Komento';

  @override
  String get profileEditLabel => 'I-edit';

  @override
  String get profileLibraryLabel => 'Library';

  @override
  String get profileNoLikedVideosTitle => 'Wala pang like';

  @override
  String get profileLikedOwnEmpty =>
      'Pag may nakita kang nakakaakit, i-tap ang puso. Lalabas dito ang mga like mo.';

  @override
  String get profileLikedOtherEmpty =>
      'Wala pa silang nagugustuhan. Hintayin mo lang.';

  @override
  String get profileErrorLoadingLiked =>
      'May error sa pag-load ng mga liked video';

  @override
  String get profileNoRepostsTitle => 'Wala pang repost';

  @override
  String get profileRepostsOwnEmpty =>
      'May nakita kang dapat ipasa? I-repost mo at lalabas ito dito.';

  @override
  String get profileRepostsOtherEmpty =>
      'Wala pa silang ipinasang content. Pag may inipasa, lalabas dito.';

  @override
  String get profileErrorLoadingReposts =>
      'May error sa pag-load ng mga reposted video';

  @override
  String get profileNoVideosTitle => 'Wala pang video';

  @override
  String get profileNoVideosOwnSubtitle =>
      'Handa na ang stage mo. Magsimula nang mag-post at maglalagi rito ang mga video mo.';

  @override
  String get profileNoVideosOtherSubtitle =>
      'Naghihintay ang mundo. Sundan mo sila para hindi ka mahuli.';

  @override
  String profileVideoThumbnailLabel(int number) {
    return 'Thumbnail ng video $number';
  }

  @override
  String get profileShowMore => 'Ipakita pa';

  @override
  String get profileShowLess => 'Ipakita nang mas kaunti';

  @override
  String get dmMessageDisplayLimitReached =>
      'Hindi ipinapakita ang natitirang bahagi ng mensaheng ito.';

  @override
  String get profileCompleteYourProfile => 'Kumpletuhin ang iyong profile';

  @override
  String get profileCompleteSubtitle =>
      'Idagdag ang iyong pangalan, bio, at larawan para makapagsimula';

  @override
  String get profilePleaseTryAgain => 'Subukan ulit';

  @override
  String get profileSecureYourAccount => 'I-secure ang iyong account';

  @override
  String get profileSecureSubtitle =>
      'Magdagdag ng email at password para mabawi ang account mo sa kahit anong device';

  @override
  String get profileRetryButton => 'Subukan ulit';

  @override
  String get profileSessionExpired => 'Nag-expire na ang session';

  @override
  String get profileSignInToRestore =>
      'Mag-sign in ulit para mabalik ang buong access';

  @override
  String get profileSignInButton => 'Mag-sign in';

  @override
  String get profileMaybeLaterLabel => 'Sa Susunod Na Lang';

  @override
  String get profileSecurePrimaryButton => 'Magdagdag ng Email at Password';

  @override
  String get profileCompletePrimaryButton => 'I-update ang Profile Mo';

  @override
  String get profileLoopsLabel => 'Loops';

  @override
  String get profileLikesLabel => 'Mga Like';

  @override
  String get profileMyLibraryLabel => 'Aking Library';

  @override
  String get profileMessageLabel => 'Mensahe';

  @override
  String get profileShareLabel => 'I-share ang profile';

  @override
  String get profileDeletedAccountName => 'Tinanggal na account';

  @override
  String get inboxActionReportVanishedAccount => 'I-report ang account na ito';

  @override
  String get inboxActionBlockVanishedAccount => 'I-block ang account na ito';

  @override
  String get inboxActionUnblockVanishedAccount =>
      'I-unblock ang account na ito';

  @override
  String get inboxReportedVanishedAccount => 'Na-report ang account na ito';

  @override
  String get inboxBlockedVanishedAccount => 'Na-block ang account na ito';

  @override
  String get inboxUnblockedVanishedAccount => 'Na-unblock ang account na ito';

  @override
  String get inboxRemoveConfirmBodyVanishedAccount =>
      'Aalisin nito sa iyong inbox ang usapan. Kung magme-message ulit siya, magsisimula ng bagong usapan.';

  @override
  String get inboxConversationDeletedAccountSubtitle =>
      'Tinanggal na ang account na ito';

  @override
  String get profileUserFallback => 'user';

  @override
  String get profileLinkCopied => 'Nakopya na ang profile link';

  @override
  String get profileSetupEditProfileTitle => 'I-edit ang Profile';

  @override
  String get nostrSettingsNip05ProfileRequired =>
      'I-set up ang profile mo bago magdagdag ng NIP-05 address.';

  @override
  String get nostrSettingsNip05CreateProfileAction => 'Gumawa ng profile';

  @override
  String get profileSetupBackLabel => 'Bumalik';

  @override
  String get profileSetupAboutNostr => 'Tungkol sa Nostr';

  @override
  String get profileSetupProfilePublished =>
      'Matagumpay na na-publish ang profile!';

  @override
  String get profileSetupUnsavedChangesTitle => 'I-save ang mga pagbabago?';

  @override
  String get profileSetupUnsavedChangesSubtitle =>
      'I-save ang mga binago mo bago umalis, o itapon ang mga ito at magpatuloy.';

  @override
  String get profileSetupUnsavedChangesSaveButton => 'I-save ang mga pagbabago';

  @override
  String get profileSetupUnsavedChangesDiscardButton =>
      'Itapon ang mga pagbabago';

  @override
  String get profileSetupUnsavedChangesKeepButton => 'Magpatuloy sa pag-edit';

  @override
  String get profileSetupCreateNewProfile => 'Gumawa ng bagong profile?';

  @override
  String get profileSetupNoExistingProfile =>
      'Wala kaming nakitang existing profile sa mga relay mo. Ang pag-publish ay gagawa ng bagong profile. Ituloy?';

  @override
  String get profileSetupPublishButton => 'I-publish';

  @override
  String get profileSetupUsernameTaken =>
      'Nakuha na ang username. Pumili ng iba.';

  @override
  String get profileSetupClaimFailed =>
      'Nabigong i-claim ang username. Subukan ulit.';

  @override
  String get profileSetupPublishFailed =>
      'Nabigong i-publish ang profile. Subukan ulit.';

  @override
  String get profileSetupNoRelaysConnected =>
      'Hindi makonekta sa network. Tingnan ang koneksyon mo at subukan ulit.';

  @override
  String get profileSetupDisplayNameLabel => 'Pangalang ipapakita';

  @override
  String get profileSetupDisplayNameRequired => 'Maglagay ng display name';

  @override
  String get profileSetupBioLabel => 'Bio (opsyonal)';

  @override
  String get profileSetupWebsiteLabel => 'Website (opsyonal)';

  @override
  String get profileSetupPublicKeyLabel => 'Pampublikong susi (npub)';

  @override
  String get profileSetupUsernameLabel => 'Username (opsyonal)';

  @override
  String get profileSetupUsernameHelper =>
      'Gumamit ng mga letra, numero, o gitling. Magiging divine.video address ang username mo. Gamitin ang display name para sa mga espasyo o simbolo.';

  @override
  String get profileSetupSaveButton => 'I-save';

  @override
  String get profileSetupSavingButton => 'Sine-save...';

  @override
  String get profileSetupImageUrlTitle => 'Magdagdag ng image URL';

  @override
  String get profileSetupImageSelectionFailed =>
      'Nabigo ang pagpili ng larawan. I-paste na lang ang image URL sa baba.';

  @override
  String get profileSetupImagesTypeGroup => 'mga larawan';

  @override
  String get cameraPickErrorPermissionDenied =>
      'Naka-off ang camera access. I-on ito sa Settings para makakuha ng litrato.';

  @override
  String get cameraPickErrorPermissionRestricted =>
      'Hindi pinapayagan ang camera access sa device na ito.';

  @override
  String get cameraPickErrorBusy =>
      'Bukas na ang picker. Isara mo muna at subukan ulit.';

  @override
  String get cameraPickErrorGeneric =>
      'Hindi nabuksan ang camera. Subukan ulit.';

  @override
  String get profileSetupGotItButton => 'Sige';

  @override
  String get profileSetupUploadFailedGeneric =>
      'Nabigo ang upload. Subukan ulit mamaya.';

  @override
  String get profileSetupUploadNetworkError =>
      'Network error: Tingnan ang internet connection mo at subukan ulit.';

  @override
  String get profileSetupUploadAuthError =>
      'Authentication error: Subukang mag-log out at mag-log in ulit.';

  @override
  String get profileSetupUploadFileTooLarge =>
      'Masyadong malaki ang file: Pumili ng mas maliit na larawan (max 10MB).';

  @override
  String get profileSetupUploadServerError =>
      'Nabigo ang upload. Pansamantalang hindi available ang servers namin. Subukan ulit mamaya.';

  @override
  String get profileSetupBannerClearButton => 'I-clear ang banner';

  @override
  String get profileSetupBannerChangeColor => 'Kulay ng banner';

  @override
  String get profileSetupChangeBannerTitle => 'Palitan ang banner';

  @override
  String get profileSetupBannerColorPickerTitle =>
      'Baguhin ang kulay ng banner';

  @override
  String get profileSetupBannerColorCustom => 'Custom';

  @override
  String get profileSetupBannerColorNone => 'Walang kulay';

  @override
  String get profileSetupBannerColorLime => 'Lime';

  @override
  String get profileSetupBannerColorYellow => 'Dilaw';

  @override
  String get profileSetupBannerColorViolet => 'Biyoleta';

  @override
  String get profileSetupBannerColorPink => 'Rosas';

  @override
  String get profileSetupBannerColorOrange => 'Kahel';

  @override
  String get profileSetupBannerColorPurple => 'Lila';

  @override
  String get profileSetupAvatarClearButton => 'Alisin ang larawan';

  @override
  String get profileSetupImageTakePhoto => 'Kumuha ng larawan';

  @override
  String get profileSetupImageUploadFromCameraRoll =>
      'Mag-upload mula sa camera roll';

  @override
  String get profileSetupImagePasteLink => 'I-paste ang link ng larawan';

  @override
  String get profileSetupEditAvatarLabel => 'I-edit ang larawan sa profile';

  @override
  String get profileSetupEditBannerLabel => 'I-edit ang banner';

  @override
  String get profileSetupUsernameChecking => 'Tinitingnan ang availability...';

  @override
  String get profileSetupUsernameAvailable => 'Available ang username!';

  @override
  String get profileSetupUsernameTakenIndicator => 'Nakuha na ang username';

  @override
  String get profileSetupUsernameReserved => 'Naka-reserve ang username';

  @override
  String get profileSetupContactSupport => 'Makipag-ugnayan sa support';

  @override
  String get profileSetupCheckAgain => 'Tingnan ulit';

  @override
  String get profileSetupUsernameBurned =>
      'Hindi na available ang username na ito';

  @override
  String get profileSetupUsernameInvalidFormat =>
      'Mga letra, numero, at gitling lang ang pwede';

  @override
  String get profileSetupUsernameInvalidHyphenPlacement =>
      'Hindi puwedeng magsimula o magtapos sa gitling ang username';

  @override
  String get profileSetupUsernameInvalidLength =>
      'Dapat 3-63 character ang username';

  @override
  String get profileSetupUsernameNetworkError =>
      'Hindi natingnan ang availability. Subukan ulit.';

  @override
  String get profileSetupUsernameInvalidFormatGeneric =>
      'Invalid ang format ng username';

  @override
  String get profileSetupUsernameCheckFailed =>
      'Nabigong tingnan ang availability';

  @override
  String get profileSetupUsernameReservedTitle => 'Naka-reserve ang username';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return 'Ang pangalang $username ay naka-reserve. Sabihin mo sa amin kung bakit dapat sa iyo ito.';
  }

  @override
  String get profileSetupUsernameReservedHint =>
      'hal. Brand name ko, stage name, atbp.';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      'Nakipag-ugnayan ka na ba sa support? I-tap ang \"Tingnan ulit\" para makita kung naibigay na sa iyo.';

  @override
  String get profileSetupSupportRequestSent =>
      'Naipadala na ang support request! Babalikan ka namin agad.';

  @override
  String get profileSetupCouldntOpenEmail =>
      'Hindi nabuksan ang email. Ipadala sa: names@divine.video';

  @override
  String get profileSetupSendRequest => 'Ipadala ang request';

  @override
  String get profileSetupUseOwnNip05 =>
      'Gamitin ang sarili mong NIP-05 address';

  @override
  String get profileSetupNip05AddressLabel => 'NIP-05 Address';

  @override
  String get profileSetupExternalNip05InvalidFormat =>
      'Invalid NIP-05 format (hal., name@domain.com)';

  @override
  String get profileSetupExternalNip05DivineDomain =>
      'Gamitin ang username field sa itaas para sa divine.video';

  @override
  String get nostrSettingsNip05Address => 'NIP-05 address';

  @override
  String get nostrSettingsNip05AddressSubtitle =>
      'Gamitin ang divine.video username mo, o ituro ang handle mo sa isang NIP-05 address sa domain na kontrolado mo.';

  @override
  String get nostrSettingsNip05AddressHint => 'you@example.com';

  @override
  String get nostrSettingsNip05SaveAction => 'I-save ang NIP-05';

  @override
  String get nostrSettingsNip05Saved => 'Na-save ang NIP-05';

  @override
  String get nostrSettingsNip05SaveFailed =>
      'Hindi na-save ang NIP-05. Subukan ulit.';

  @override
  String get profileSetupNip05ConfirmTitle =>
      'Gagamit ka ng sarili mong NIP-05?';

  @override
  String get profileSetupNip05ConfirmBody =>
      'Iniuugnay ng NIP-05 ang pangalan tulad ng ikaw@domainmo.com sa Nostr identity mo. Kailangan mong kontrolin ang domain at maglagay ng verification file sa tamang path. Kapag mali ito, hindi ka makikita ng iba at mawawala ang verified handle mo. Magpatuloy lang kung na-set up mo na ito.';

  @override
  String get profileSetupNip05ConfirmContinue => 'Magpatuloy';

  @override
  String get profileSetupNip05ConfirmCancel => 'Kanselahin';

  @override
  String get profileSetupProfilePicturePreview => 'Preview ng profile picture';

  @override
  String get nostrInfoIntroBuiltOn => 'Ang Divine ay binuo sa Nostr,';

  @override
  String get nostrInfoIntroDescription =>
      ' isang censorship-resistant na open protocol na nagbibigay-daan sa mga tao na makipag-usap online nang hindi umaasa sa iisang kompanya o platform. ';

  @override
  String get nostrInfoIntroIdentity =>
      'Kapag nag-sign up ka sa Divine, makakakuha ka ng bagong Nostr identity.';

  @override
  String get nostrInfoOwnership =>
      'Ang Nostr ay nagbibigay sa iyo ng kontrol sa iyong content, identity, at social graph, na maaari mong gamitin sa iba\'t ibang app. Ang resulta ay mas maraming pagpipilian, mas kaunting lock-in, at mas malusog at matibay na social internet.';

  @override
  String get nostrInfoLingo => 'Mga termino sa Nostr:';

  @override
  String get nostrInfoNpubLabel => 'npub:';

  @override
  String get nostrInfoNpubDescription =>
      ' Ang public Nostr address mo. Ligtas itong i-share at nagbibigay-daan sa iba na hanapin, sundan, o mag-message sa iyo sa iba\'t ibang Nostr app.';

  @override
  String get nostrInfoNsecLabel => 'nsec:';

  @override
  String get nostrInfoNsecDescription =>
      ' Ang private key mo at patunay ng pagmamay-ari. Nagbibigay ito ng buong kontrol sa Nostr identity mo, kaya ';

  @override
  String get nostrInfoNsecWarning => 'panatilihin itong sekreto!';

  @override
  String get nostrInfoUsernameLabel => 'Nostr username:';

  @override
  String get nostrInfoUsernameDescription =>
      ' Isang nababasang pangalan (tulad ng @name.divine.video) na naka-link sa npub mo. Ginagawa nitong mas madaling makilala at ma-verify ang Nostr identity mo, parang email address.';

  @override
  String get nostrInfoLearnMoreAt => 'Alamin pa sa ';

  @override
  String get nostrInfoGotIt => 'Sige!';

  @override
  String get videoGridRefreshLabel => 'Naghahanap ng iba pang video';

  @override
  String get videoGridOptionsTitle => 'Mga Video Option';

  @override
  String get videoGridEditVideo => 'I-edit ang Video';

  @override
  String get videoGridEditVideoSubtitle =>
      'I-update ang title, description, at hashtag';

  @override
  String get videoGridDeleteVideo => 'Burahin ang Video';

  @override
  String get videoGridDeleteVideoSubtitle =>
      'Tanggalin ang video na ito sa Divine. Maaari pa rin itong lumabas sa ibang Nostr client.';

  @override
  String get videoGridDeletingContent => 'Binubura ang content...';

  @override
  String get exploreTabFeatured => 'Itinatampok';

  @override
  String get exploreTabClassics => 'Klasiko';

  @override
  String get exploreTabNew => 'Bago';

  @override
  String get exploreTabPopular => 'Sikat';

  @override
  String get exploreTabCategories => 'Mga Category';

  @override
  String get exploreTabForYou => 'Para sa Iyo';

  @override
  String get exploreTabLists => 'Mga List';

  @override
  String get exploreTabIntegratedApps => 'Mga Integrated App';

  @override
  String exploreFeaturedSponsoredBy(String sponsor) {
    return 'Sponsored by $sponsor';
  }

  @override
  String exploreFeaturedSponsoredPillSemanticLabel(String name) {
    return '$name, sponsored';
  }

  @override
  String get featuredTabEmpty => 'Wala pa rito. Balikan mo mamaya.';

  @override
  String get featuredTabLoadFailed => 'Hindi na-load ang koleksyong ito.';

  @override
  String get featuredTabRetry => 'Subukan ulit';

  @override
  String get exploreNoVideosAvailable => 'Walang available na video';

  @override
  String get exploreDiscoverLists => 'Tuklasin ang mga List';

  @override
  String get exploreAboutLists => 'Tungkol sa mga List';

  @override
  String get exploreAboutListsDescription =>
      'Tinutulungan ka ng mga list na ayusin at i-curate ang Divine content sa dalawang paraan:';

  @override
  String get explorePeopleLists => 'Mga People List';

  @override
  String get explorePeopleListsDescription =>
      'Sundan ang mga grupo ng creator at tingnan ang kanilang mga pinakabagong video';

  @override
  String get exploreVideoLists => 'Mga Video List';

  @override
  String get exploreVideoListsDescription =>
      'Gumawa ng playlist ng iyong mga paboritong video para mapanood mamaya';

  @override
  String get exploreMyLists => 'Mga List Ko';

  @override
  String get exploreSubscribedLists => 'Mga Subscribed List';

  @override
  String get exploreErrorLoadingLists =>
      'May error sa pag-load ng mga list. Subukan ulit.';

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bagong video',
      one: '$count bagong video',
    );
    return '$_temp0';
  }

  @override
  String exploreLoadNewVideosLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'video',
      one: 'video',
    );
    return 'I-load ang $count bagong $_temp0';
  }

  @override
  String get videoPlayerPlayVideo => 'I-play ang video';

  @override
  String get videoPlayerMute => 'I-mute ang video';

  @override
  String get videoPlayerUnmute => 'I-unmute ang video';

  @override
  String get videoPlayerTapHint =>
      'I-tap para i-play o i-pause. Mag-double tap para i-like.';

  @override
  String get videoSettingsMenuOpen => 'Buksan ang playback settings';

  @override
  String get videoSettingsMenuClose => 'Isara ang playback settings';

  @override
  String get videoSettingsCaptionsEnable => 'I-enable ang captions';

  @override
  String get videoSettingsCaptionsDisable => 'I-disable ang captions';

  @override
  String get videoSettingsAutoAdvanceOn => 'Naka-on ang auto advance';

  @override
  String get videoSettingsAutoAdvanceOff => 'Naka-off ang auto advance';

  @override
  String get videoSettingsCaptionsOn => 'Naka-on ang captions';

  @override
  String get videoSettingsCaptionsOff => 'Naka-off ang captions';

  @override
  String get videoSettingsCaptionsOnForVideo =>
      'Naka-on ang captions para sa video na ito';

  @override
  String get videoSettingsCaptionsOffForVideo =>
      'Naka-off ang captions para sa video na ito';

  @override
  String get contentWarningLabel => 'Babala sa nilalaman';

  @override
  String get contentWarningNudity => 'Kahubaran';

  @override
  String get contentWarningSexualContent => 'Sekswal na nilalaman';

  @override
  String get contentWarningPornography => 'Pornograpiya';

  @override
  String get contentWarningGraphicMedia => 'Nakakabahalang media';

  @override
  String get contentWarningViolence => 'Karahasan';

  @override
  String get contentWarningSelfHarm => 'Pananakit sa sarili';

  @override
  String get contentWarningDrugUse => 'Paggamit ng Droga';

  @override
  String get contentWarningAlcohol => 'Alak';

  @override
  String get contentWarningTobacco => 'Tabako';

  @override
  String get contentWarningGambling => 'Sugal';

  @override
  String get contentWarningProfanity => 'Mura';

  @override
  String get contentWarningFlashingLights => 'Mga Kumikislap na Ilaw';

  @override
  String get contentWarningAiGenerated => 'Gawa ng AI';

  @override
  String get contentWarningSpoiler => 'Spoiler';

  @override
  String get contentWarningSensitiveContent => 'Sensitibong Content';

  @override
  String get contentWarningDescNudity =>
      'Naglalaman ng kahubaran o bahagyang kahubaran';

  @override
  String get contentWarningDescSexual => 'Naglalaman ng sexual content';

  @override
  String get contentWarningDescPorn =>
      'Naglalaman ng tahasang pornographic content';

  @override
  String get contentWarningDescGraphicMedia =>
      'Naglalaman ng graphic o nakakagulat na imahe';

  @override
  String get contentWarningDescViolence => 'Naglalaman ng marahas na content';

  @override
  String get contentWarningDescSelfHarm =>
      'Naglalaman ng reference sa self-harm';

  @override
  String get contentWarningDescDrugs =>
      'Naglalaman ng content tungkol sa droga';

  @override
  String get contentWarningDescAlcohol =>
      'Naglalaman ng content tungkol sa alak';

  @override
  String get contentWarningDescTobacco =>
      'Naglalaman ng content tungkol sa tabako';

  @override
  String get contentWarningDescGambling =>
      'Naglalaman ng content tungkol sa sugal';

  @override
  String get contentWarningDescProfanity => 'Naglalaman ng malalakas na salita';

  @override
  String get contentWarningDescFlashingLights =>
      'Naglalaman ng kumikislap na ilaw (photosensitivity warning)';

  @override
  String get contentWarningDescAiGenerated =>
      'Ang content na ito ay gawa ng AI';

  @override
  String get contentWarningDescSpoiler => 'Naglalaman ng spoiler';

  @override
  String get contentWarningDescContentWarning =>
      'Minarkahan ito ng creator bilang sensitibo';

  @override
  String get contentWarningDescDefault =>
      'Minarkahan ng creator ang content na ito';

  @override
  String get contentWarningDetailsTitle => 'Mga Content Warning';

  @override
  String get contentWarningDetailsSubtitle =>
      'Inilapat ng creator ang mga label na ito:';

  @override
  String get contentWarningManageFilters => 'Pamahalaan ang mga content filter';

  @override
  String get contentWarningViewAnyway => 'Tingnan pa rin';

  @override
  String get contentWarningReportContentTooltip => 'I-report ang Content';

  @override
  String get contentWarningBlockUserTooltip => 'I-block ang User';

  @override
  String get contentWarningBlockedTitle => 'Naka-block ang Content';

  @override
  String get contentWarningBlockedPolicy =>
      'Na-block ang content na ito dahil sa policy violations.';

  @override
  String get contentWarningNoticeTitle => 'Paalala tungkol sa nilalaman';

  @override
  String get contentWarningPotentiallyHarmfulTitle =>
      'Posibleng Nakakapinsalang Content';

  @override
  String get contentWarningView => 'Tingnan';

  @override
  String get contentWarningReportAction => 'I-report';

  @override
  String get contentWarningHideAllLikeThis =>
      'Itago lahat ng content na ganito';

  @override
  String get contentWarningNoFilterYet =>
      'Wala pang naka-save na filter para sa warning na ito.';

  @override
  String get contentWarningHiddenConfirmation =>
      'Itatago na namin ang ganitong post mula ngayon.';

  @override
  String get communitySuggestTitle => 'Tulungang i-classify ito';

  @override
  String get communitySuggestSubtitle =>
      'May kulang na content warning? Public, naka-sign, at hindi na mababawi ang suggestion mo.';

  @override
  String get communitySuggestSubmit => 'I-suggest';

  @override
  String get communitySuggestSuccess =>
      'Salamat. Naipadala na ang suggestion mo.';

  @override
  String get communitySuggestFailure =>
      'Hindi naipadala ang suggestion mo. Subukan ulit.';

  @override
  String get communitySuggestAlready => 'Na-suggest mo na ito';

  @override
  String get communitySuggestActionLabel => 'I-classify';

  @override
  String get videoErrorNotFound => 'Hindi nakita ang video';

  @override
  String get videoErrorPlayback => 'Error sa playback ng video';

  @override
  String get videoErrorAgeRestricted => 'Nilalamang may age restriction';

  @override
  String get videoErrorUnavailable => 'Hindi available ang video';

  @override
  String get videoErrorUnavailableBody =>
      'Hindi available ang video na ito ngayon.';

  @override
  String get videoErrorRetry => 'Subukan ulit';

  @override
  String get videoErrorContentRestricted => 'Restricted ang content';

  @override
  String get videoErrorContentRestrictedBody =>
      'Inalis ang video na ito dahil lumabag ito sa aming mga patakaran sa content.';

  @override
  String get videoErrorVerifyAgeBody =>
      'I-verify ang edad mo para mapanood ang video na ito.';

  @override
  String get videoErrorSkip => 'Laktawan';

  @override
  String get videoErrorVerifyAgeButton => 'I-verify ang edad';

  @override
  String get videoErrorVerifyAgeFailed =>
      'Hindi na-verify ang edad mo. Subukan ulit.';

  @override
  String get videoErrorVerifyAgeSignerUnreachable =>
      'Nag-timeout ang pag-verify. I-check ang koneksyon mo o subukan ulit mamaya.';

  @override
  String get videoErrorAdultContentHiddenTitle => 'Naka-off ang adult content';

  @override
  String get videoErrorAdultContentHiddenBody =>
      'I-on mo ito sa Content Filters mo para mapanood ang video na ito.';

  @override
  String get videoErrorAdultContentHiddenAction => 'Buksan ang Content Filters';

  @override
  String get videoDetailLoadError => 'Hindi ma-load ang video';

  @override
  String get videoDetailLoadErrorBody => 'May sumablay sa daan. Subukan ulit.';

  @override
  String get videoDetailNotFoundBody =>
      'Baka nabura na, wala sa abot, o nakatago dahil sa mga setting mo.';

  @override
  String get databaseCorruptionTitle => 'Nasira ang local data mo';

  @override
  String get databaseCorruptionBody =>
      'Isara ang Divine at buksan ulit — awtomatiko naming aayusin. Ise-save namin ang makakaya sa mga draft at clip mo, mag-reload na lang ang iba.';

  @override
  String get databaseCorruptionCloseButton => 'Isara ang Divine';

  @override
  String get videoDetailContextTitle => 'Na-share na video';

  @override
  String get videoDetailCloseSemanticLabel => 'Isara ang video player';

  @override
  String get videoFollowButtonFollow => 'Sundan';

  @override
  String get audioAttributionOriginalSound => 'Orihinal na sound';

  @override
  String get audioAttributionUnavailableSound => 'Hindi available ang sound';

  @override
  String videoInspiredByAttributionMultiple(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return 'Inspirasyon mula kay @$creatorName +$additionalCreatorCount';
  }

  @override
  String videoInspiredByAttribution(String creatorName) {
    return 'Inspirasyon mula kay @$creatorName';
  }

  @override
  String videoCollaboratorWithOne(String name) {
    return 'kasama si @$name';
  }

  @override
  String videoCollaboratorWithMore(String name, int count) {
    return 'kasama si @$name +$count';
  }

  @override
  String videoCollaboratorCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count collaborator',
      one: '$count collaborator',
    );
    return '$_temp0. I-tap para tingnan ang profile.';
  }

  @override
  String get videoCollaboratorPendingDecoration => 'Naghihintay';

  @override
  String get videoCollaboratorPendingSemanticLabel =>
      'Collaborator na naghihintay';

  @override
  String videoCollaboratorWithPendingSuffix(String label, int pending) {
    return '$label ($pending naghihintay)';
  }

  @override
  String profileChipTapHint(String name) {
    return '$name. I-tap para makita ang profile.';
  }

  @override
  String metadataHashtagChipTapHint(String hashtag) {
    return '#$hashtag. I-tap para makita ang mga video na may ganitong hashtag.';
  }

  @override
  String get listAttributionFallback => 'Listahan';

  @override
  String get shareVideoLabel => 'I-share ang video';

  @override
  String sharePostSharedWith(String recipientName) {
    return 'Naipadala ang post kay $recipientName';
  }

  @override
  String sharePostSharedWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Naipadala ang post sa $count tao',
      one: 'Naipadala ang post sa $count tao',
    );
    return '$_temp0';
  }

  @override
  String get shareFailedToSend => 'Nabigong ipadala ang video';

  @override
  String get shareAddedToBookmarks => 'Naidagdag sa bookmarks';

  @override
  String get shareRemovedFromBookmarks => 'Tinanggal sa bookmarks';

  @override
  String get shareFailedToAddBookmark => 'Nabigong magdagdag ng bookmark';

  @override
  String get shareFailedToRemoveBookmark => 'Nabigong tanggalin ang bookmark';

  @override
  String get shareActionFailed => 'Nabigo ang action';

  @override
  String get shareWithTitle => 'I-share kasama si';

  @override
  String get shareFindPeople => 'Maghanap ng tao';

  @override
  String get shareFindPeopleMultiline => 'Maghanap\nng tao';

  @override
  String get shareSent => 'Naipadala';

  @override
  String shareSelectedRecipientAnnouncement(String name) {
    return 'Napili si $name';
  }

  @override
  String get shareMessageHint => 'Magdagdag ng optional na mensahe...';

  @override
  String get videoActionUnlike => 'I-unlike ang video';

  @override
  String get videoActionLike => 'I-like ang video';

  @override
  String get videoActionAutoLabel => 'Compilation';

  @override
  String get videoActionLikeLabel => 'I-like';

  @override
  String get videoActionReplyLabel => 'Sumagot';

  @override
  String get videoActionRepostLabel => 'Revine';

  @override
  String get videoActionShareLabel => 'I-share';

  @override
  String get videoActionReportLabel => 'I-report';

  @override
  String get videoActionReport => 'I-report ang video';

  @override
  String get videoActionEditLabel => 'I-edit';

  @override
  String get videoActionEdit => 'I-edit ang video';

  @override
  String get videoActionAboutLabel => 'Tungkol';

  @override
  String get videoActionEnableAutoAdvance => 'I-enable ang auto advance';

  @override
  String get videoActionDisableAutoAdvance => 'I-disable ang auto advance';

  @override
  String get videoActionRemoveRepost => 'Tanggalin ang repost';

  @override
  String get videoActionRepost => 'I-repost ang video';

  @override
  String get videoActionViewComments => 'Tingnan ang mga komento';

  @override
  String get videoActionMoreOptions => 'Iba pang options';

  @override
  String get videoEngagementLikersTitle => 'Nag-like';

  @override
  String get videoEngagementRepostersTitle => 'Nag-repost';

  @override
  String get videoEngagementLikersEmpty => 'Wala pang nag-like';

  @override
  String get videoEngagementRepostersEmpty => 'Wala pang nag-repost';

  @override
  String get videoEngagementLoadFailed => 'Hindi ma-load ang listahan';

  @override
  String get videoOverlayOpenMetadataFromTitle => 'Buksan ang video details';

  @override
  String get videoOverlayOpenMetadataFromDescription =>
      'Buksan ang video details';

  @override
  String get videoOverlayCommentBarHint => 'Magdagdag ng komento...';

  @override
  String get videoOverlayCommentBarSemanticLabel => 'Magdagdag ng komento';

  @override
  String get videoOverlayCommentBarSendLabel => 'Ipadala ang komento';

  @override
  String get videoOverlayCommentPostedSnackbar => 'Nai-post ang komento';

  @override
  String get videoOverlayCommentPostFailedSnackbar =>
      'Hindi nai-post ang komento';

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
  String get metadataBadgeNotDivine => 'Hindi Divine';

  @override
  String get metadataBadgeHumanMade => 'Gawa ng Tao';

  @override
  String get metadataSoundsLabel => 'Mga Tunog';

  @override
  String get metadataOriginalSound => 'Orihinal na sound';

  @override
  String get metadataVerificationLabel => 'Beripikasyon';

  @override
  String get metadataDeviceAttestation => 'Device attestation';

  @override
  String get metadataPgpSignature => 'PGP signature';

  @override
  String get metadataC2paCredentials => 'C2PA Content Credentials';

  @override
  String get metadataProofManifest => 'Proof manifest';

  @override
  String get metadataVerificationInfoTooltip =>
      'Ano ang ibig sabihin ng mga pagsusuring ito?';

  @override
  String metadataSectionInfoSemanticsLabel(String section, String question) {
    return '$section. $question';
  }

  @override
  String get metadataVerificationInfoTitle =>
      'Ang ibig sabihin ng mga pagsusuring ito';

  @override
  String get metadataVerificationInfoIntro =>
      'Nanggagaling ang mga senyas na ito sa camera at sa mismong video file. Kapag mas marami nito ang dala ng isang video, mas marami kaming mapapatunayan tungkol sa pinanggalingan nito.';

  @override
  String get metadataVerificationInfoDeviceAttestation =>
      'Pinanindigan ng operating system ng telepono ang app na nag-record nito. Malakas na patunay na galing ito sa camera, hindi sa file na may nag-upload.';

  @override
  String get metadataVerificationInfoPgpSignature =>
      'Cryptographic na nilagdaan ang video sa mismong sandali ng pagkuha. Baguhin ang kahit isang frame pagkatapos, masisira ang lagda.';

  @override
  String get metadataVerificationInfoC2paCredentials =>
      'Isang industry-standard na tala ng pinagmulan na dala mismo ng file — kaya kayang suriin ito ng ibang app bukod sa Divine.';

  @override
  String get metadataVerificationInfoProofManifest =>
      'Ang buong ProofMode record: fingerprint ng file, timestamp at konteksto ng pagkuha, kasama ng video.';

  @override
  String get metadataVerificationInfoFootnote =>
      'Ang kulang na pagsusuri ay hindi nangangahulugang peke ang video. Ang mga lumang clip at upload ay wala talaga nito — ibig lang sabihin, hindi namin mapapatunayan ang bahaging iyon.';

  @override
  String metadataVerificationInfoLearnMore(String url) {
    return 'Matuto pa sa $url';
  }

  @override
  String get metadataCreatorLabel => 'Creator';

  @override
  String get metadataCollaboratorsLabel => 'Mga Collaborator';

  @override
  String get metadataInspiredByLabel => 'Inspirasyon mula kay';

  @override
  String get metadataRepostedByLabel => 'Na-repost ni';

  @override
  String metadataMoreReposters(int count) {
    return '+$count pa';
  }

  @override
  String metadataLoopsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Loops',
      one: 'Loop',
    );
    return '$_temp0';
  }

  @override
  String get metadataLikesLabel => 'Mga Like';

  @override
  String get metadataCommentsLabel => 'Mga Komento';

  @override
  String get metadataRepostsLabel => 'Mga Repost';

  @override
  String get metadataVineStatsLabel => 'Sa Vine';

  @override
  String metadataVineStatsLine(
    String loops,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$loops loop · $likes like · $comments komento · $reposts repost';
  }

  @override
  String get metadataDivineStatsLabel => 'Sa Divine';

  @override
  String metadataDivineStatsLine(
    String views,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$views panonood · $likes like · $comments komento · $reposts repost';
  }

  @override
  String metadataPostedDateSemantics(String date) {
    return 'Na-post noong $date';
  }

  @override
  String get devOptionsTitle => 'Mga opsyon para sa developer';

  @override
  String get devOptionsDisableDeveloperMode => 'I-disable ang Developer Mode';

  @override
  String get devOptionsDisableDeveloperModeSubtitle =>
      'Itago ang developer options mula sa settings';

  @override
  String get devOptionsDisableDeveloperModeToast =>
      'Na-disable ang developer mode';

  @override
  String get devOptionsShorebirdTitle => 'Mga patch ng Shorebird';

  @override
  String get devOptionsShorebirdPatchLabel => 'Kasalukuyang patch';

  @override
  String get devOptionsShorebirdNoPatch => 'Walang naka-install na patch';

  @override
  String get devOptionsShorebirdUnavailable =>
      'Hindi available sa build na ito';

  @override
  String get devOptionsShorebirdUnavailableSubtitle =>
      'Gumagana lang ang mga patch sa build na ginawa gamit ang shorebird release.';

  @override
  String get devOptionsShorebirdLoading => 'Binabasa ang status ng patch…';

  @override
  String get devOptionsShorebirdNotChecked =>
      'Hindi pa nasusuri ang staging track.';

  @override
  String get devOptionsShorebirdCheck => 'Suriin ang staging track';

  @override
  String get devOptionsShorebirdApply => 'Ilapat ang staging patch';

  @override
  String get devOptionsShorebirdUseStable => 'Bumalik sa stable na mga update';

  @override
  String get devOptionsShorebirdChecking => 'Sinusuri ang staging track…';

  @override
  String get devOptionsShorebirdUpdateAvailable =>
      'May staging patch na handang ilapat.';

  @override
  String get devOptionsShorebirdUpToDate =>
      'Walang staging patch para sa release na ito.';

  @override
  String get devOptionsShorebirdRestartRequired =>
      'Na-download na. I-restart ang app para i-load ito.';

  @override
  String get devOptionsShorebirdRollbackRequired =>
      'Handa na ang rollback. I-restart para bumalik sa base release.';

  @override
  String get devOptionsShorebirdApplying => 'Nagda-download at nag-i-install…';

  @override
  String get devOptionsShorebirdApplied =>
      'Naka-install na. I-restart ang app para i-load ito.';

  @override
  String get devOptionsShorebirdUnchanged =>
      'Walang na-install. Suriin ang staging track at subukan ulit.';

  @override
  String get devOptionsShorebirdSelectingStableTrack =>
      'Pinipili ang stable track…';

  @override
  String get devOptionsShorebirdStableRestored =>
      'Napili ang stable track. I-restart ang app para tingnan kung may stable patch.';

  @override
  String get devOptionsShorebirdFailure =>
      'Hindi gumana. Tingnan ang mga log para sa detalye.';

  @override
  String get devOptionsPageLoadTimes => 'Mga Oras ng Page Load';

  @override
  String get devOptionsNoPageLoads =>
      'Wala pang naitalang page load.\nMag-navigate sa app para makita ang timing data.';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return 'Visible: ${visibleMs}ms  |  Data: ${dataMs}ms';
  }

  @override
  String get devOptionsSlowestScreens => 'Pinakamabagal na Screen';

  @override
  String get devOptionsVideoPlaybackFormat => 'Format ng video playback';

  @override
  String get devOptionsSwitchEnvironmentTitle => 'Magpalit ng Environment?';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return 'Lipat sa $envName?\n\nIki-clear nito ang cached video data at magkokonekta sa bagong relay.';
  }

  @override
  String get devOptionsCancel => 'Kanselahin';

  @override
  String get devOptionsSwitch => 'Magpalit';

  @override
  String devOptionsSwitchedTo(String envName) {
    return 'Lumipat sa $envName';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return 'Lumipat sa $formatName — na-clear ang cache';
  }

  @override
  String get featureFlagTitle => 'Mga Feature Flag';

  @override
  String get featureFlagResetAllTooltip => 'I-reset lahat ng flag sa default';

  @override
  String get featureFlagError => 'Error';

  @override
  String get relaySettingsTitle => 'Mga Relay';

  @override
  String get relaySettingsInfoTitle =>
      'Open system ang Divine - ikaw ang may kontrol sa mga koneksyon mo';

  @override
  String get relaySettingsInfoDescription =>
      'Ang mga relay na ito ay namamahagi ng iyong content sa decentralized na Nostr network. Maaari kang magdagdag o magtanggal ng relay ayon sa gusto mo.';

  @override
  String get relaySettingsLearnMoreNostr => 'Alamin pa ang tungkol sa Nostr →';

  @override
  String get relaySettingsFindPublicRelays =>
      'Maghanap ng public relay sa nostr.co.uk →';

  @override
  String get relaySettingsAppNotFunctional => 'Hindi Gumagana ang App';

  @override
  String get relaySettingsRequiresRelay =>
      'Nangangailangan ang Divine ng kahit isang relay para mag-load ng video, mag-post ng content, at mag-sync ng data.';

  @override
  String get relaySettingsRestoreDefaultRelay => 'Ibalik ang Default Relay';

  @override
  String get relaySettingsAddCustomRelay => 'Magdagdag ng Custom Relay';

  @override
  String get relaySettingsAddRelay => 'Magdagdag ng Relay';

  @override
  String get relaySettingsRetry => 'Subukan ulit';

  @override
  String get relaySettingsNoStats => 'Wala pang available na statistics';

  @override
  String get relaySettingsConnection => 'Koneksyon';

  @override
  String get relaySettingsConnected => 'Konektado';

  @override
  String get relaySettingsDisconnected => 'Hindi Konektado';

  @override
  String get relaySettingsSessionDuration => 'Tagal ng Session';

  @override
  String get relaySettingsLastConnected => 'Huling Konektado';

  @override
  String get relaySettingsDisconnectedLabel => 'Hindi Konektado';

  @override
  String get relaySettingsReason => 'Dahilan';

  @override
  String get relaySettingsActiveSubscriptions => 'Mga Active na Subscription';

  @override
  String get relaySettingsTotalSubscriptions => 'Kabuuang Subscription';

  @override
  String get relaySettingsEventsReceived => 'Mga Event na Natanggap';

  @override
  String get relaySettingsEventsSent => 'Mga Event na Naipadala';

  @override
  String get relaySettingsRequestsThisSession =>
      'Mga Request sa Session na Ito';

  @override
  String get relaySettingsFailedRequests => 'Mga Bigong Request';

  @override
  String get relaySettingsLoadingRelayInfo =>
      'Naglo-load ng impormasyon ng relay...';

  @override
  String get relaySettingsAboutRelay => 'Tungkol sa Relay';

  @override
  String get relaySettingsSupportedNips => 'Mga Suportadong NIP';

  @override
  String get relaySettingsSoftware => 'Software';

  @override
  String get relaySettingsViewWebsite => 'Tingnan ang Website';

  @override
  String get relaySettingsRemoveRelayTitle => 'Alisin ang Relay?';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return 'Sigurado ka bang gusto mong alisin ang relay na ito?\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveDefaultRelayTitle =>
      'Alisin ang relay ng Divine?';

  @override
  String relaySettingsRemoveDefaultRelayMessage(String relayUrl) {
    return 'Kapag inalis mo ang relay ng Divine, hihina ang karanasan mo sa app. Baka maging hindi maaasahan ang video, pag-post, at pag-sync. Para lang ito sa mga sanay nang gumamit ng Nostr.\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveRelayTooltip => 'Alisin ang relay';

  @override
  String get relaySettingsCancel => 'Kanselahin';

  @override
  String get relaySettingsRemove => 'Alisin';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return 'Inalis ang relay: $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay => 'Hindi naalis ang relay';

  @override
  String get relaySettingsForcingReconnection =>
      'Pinipilit ang muling pagkonekta sa relay...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    return 'Nakakonekta sa $count relay!';
  }

  @override
  String get relaySettingsFailedToConnectCheck =>
      'Hindi nakakonekta sa mga relay. Pakitsek ang iyong network connection.';

  @override
  String get relaySettingsSavedLocallyPublishPending =>
      'Naka-save sa device na ito. Isi-sync namin ito sa account mo kapag gumana ulit ang publishing.';

  @override
  String get relaySettingsAddRelayTitle => 'Magdagdag ng Relay';

  @override
  String get relaySettingsAddRelayPrompt =>
      'Ilagay ang WebSocket URL ng relay na gusto mong idagdag:';

  @override
  String get relaySettingsBrowsePublicRelays =>
      'I-browse ang mga public relay sa nostr.co.uk';

  @override
  String get relaySettingsAdd => 'Idagdag';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return 'Naidagdag na relay: $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      'Hindi naidagdag ang relay. Pakitsek ang URL at subukan ulit.';

  @override
  String get relaySettingsInvalidUrl =>
      'Ang URL ng relay ay dapat magsimula sa wss:// o ws://';

  @override
  String get relaySettingsInsecureUrl =>
      'Dapat gumamit ng wss:// ang relay URL (pinapayagan lang ang ws:// para sa localhost)';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return 'Naibalik ang default na relay: $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      'Hindi naibalik ang default na relay. Pakitsek ang iyong network connection.';

  @override
  String get relaySettingsCouldNotOpenBrowser => 'Hindi mabuksan ang browser';

  @override
  String get relaySettingsFailedToOpenLink => 'Hindi mabuksan ang link';

  @override
  String get relaySettingsExternalRelay => 'Panlabas na relay';

  @override
  String get relaySettingsNotConnected => 'Hindi konektado';

  @override
  String relaySettingsDisconnectedAgo(String duration) {
    return 'Nadiskonek $duration na ang nakalipas';
  }

  @override
  String relaySettingsSubscriptionsSummary(int count) {
    return '$count subs';
  }

  @override
  String relaySettingsEventsSummary(int countValue, String count) {
    return '$count events';
  }

  @override
  String relaySettingsTimeAgo(String duration) {
    return '$duration na ang nakalipas';
  }

  @override
  String get nostrSettingsIntro =>
      'Gumagamit ang Divine ng Nostr protocol para sa decentralized publishing. Naka-host sa mga napili mong relay ang content mo, at ang mga key mo ang iyong identity.';

  @override
  String get nostrSettingsSectionNetwork => 'Network';

  @override
  String get nostrSettingsSectionAccount => 'Account';

  @override
  String get nostrSettingsSectionDangerZone => 'Mapanganib na bahagi';

  @override
  String get nostrSettingsRelays => 'Mga Relay';

  @override
  String get nostrSettingsRelaysSubtitle =>
      'I-manage ang mga Nostr relay connection';

  @override
  String get nostrSettingsRelayDiagnostics => 'Relay Diagnostics';

  @override
  String get nostrSettingsRelayDiagnosticsSubtitle =>
      'I-debug ang relay connectivity at network issues';

  @override
  String get nostrSettingsMediaServers => 'Mga Media Server';

  @override
  String get nostrSettingsMediaServersSubtitle =>
      'I-configure ang mga Blossom upload server';

  @override
  String get settingsDeveloperOptions => 'Mga opsyon para sa developer';

  @override
  String get settingsDeveloperOptionsSubtitle =>
      'Environment switcher at debug settings';

  @override
  String get nostrSettingsKeyManagement => 'Pamamahala ng key';

  @override
  String get nostrSettingsKeyManagementSubtitle =>
      'I-export, i-backup, at i-restore ang iyong Nostr keys';

  @override
  String get nostrSettingsClientAttribution => 'Pagkilala sa kliyente';

  @override
  String get nostrSettingsClientAttributionSubtitle =>
      'Maglagay ng Divine client tag sa mga event na pina-publish mo para maituro ito nang tama ng ibang Nostr apps. Kung wala ito, mas magaan ang timbang ng mga report mong pinapadala kapag sinusuri ng mga moderator namin.';

  @override
  String get nostrSettingsMoveAccount => 'Ilipat ang account mo';

  @override
  String get nostrSettingsMoveAccountSubtitle =>
      'I-download ang archive mo at ilipat ang mga post at video mo sa ibang relay o media server.';

  @override
  String get nostrSettingsRemoveKeys => 'Alisin ang mga Key sa Device';

  @override
  String get nostrSettingsRemoveKeysSubtitle =>
      'Burahin ang private key mo sa device na ito lang. Mananatili ang content mo sa mga relay, pero kakailanganin mo ang nsec backup mo para ma-access ulit ang account mo.';

  @override
  String get nostrSettingsCouldNotRemoveKeys =>
      'Hindi naalis ang account na ito sa device na ito. Subukan ulit.';

  @override
  String get nostrSettingsDeleteAccount => 'Burahin ang Account at Data';

  @override
  String get nostrSettingsDeleteAccountSubtitle =>
      'Nagpapadala ng mga deletion request para sa content mo at nila-log out ka sa device na ito. Ang mga relay, client, search index, at iba pang naka-log in na device ay maaaring may kopya pa rin.';

  @override
  String get relayDiagnosticTitle => 'Mga Relay Diagnostic';

  @override
  String get relayDiagnosticRefreshTooltip => 'I-refresh ang diagnostics';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return 'Huling refresh: $time';
  }

  @override
  String get relayDiagnosticRelayStatus => 'Status ng Relay';

  @override
  String get relayDiagnosticInitialized => 'Na-initialize na';

  @override
  String get relayDiagnosticReady => 'Handa na';

  @override
  String get relayDiagnosticNotInitialized => 'Hindi pa na-initialize';

  @override
  String get relayDiagnosticDatabaseEvents => 'Mga Database Event';

  @override
  String get relayDiagnosticActiveSubscriptions => 'Mga Aktibong Subscription';

  @override
  String get relayDiagnosticExternalRelays => 'Mga Panlabas na Relay';

  @override
  String get relayDiagnosticConfigured => 'Naka-configure';

  @override
  String relayDiagnosticRelayCount(int count) {
    return '$count relay';
  }

  @override
  String get relayDiagnosticConnectedLabel => 'Nakakonekta';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => 'Mga Video Event';

  @override
  String get relayDiagnosticHomeFeed => 'Home Feed';

  @override
  String relayDiagnosticVideosCount(int count) {
    return '$count video';
  }

  @override
  String get relayDiagnosticDiscovery => 'Discovery';

  @override
  String get relayDiagnosticLoading => 'Naglo-load';

  @override
  String get relayDiagnosticYes => 'Oo';

  @override
  String get relayDiagnosticNo => 'Hindi';

  @override
  String get relayDiagnosticTestDirectQuery => 'Subukan ang Direct Query';

  @override
  String get relayDiagnosticNetworkConnectivity => 'Koneksyon sa network';

  @override
  String get relayDiagnosticRunNetworkTest => 'Patakbuhin ang Network Test';

  @override
  String get relayDiagnosticBlossomServer => 'Blossom Server';

  @override
  String get relayDiagnosticTestAllEndpoints => 'Subukan Lahat ng Endpoint';

  @override
  String get relayDiagnosticStatus => 'Status';

  @override
  String get relayDiagnosticUrl => 'URL';

  @override
  String get relayDiagnosticError => 'Error';

  @override
  String get relayDiagnosticFunnelCakeApi => 'FunnelCake API';

  @override
  String get relayDiagnosticBaseUrl => 'Base URL';

  @override
  String get relayDiagnosticSummary => 'Buod';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount OK (avg ${avgMs}ms)';
  }

  @override
  String get relayDiagnosticRetestAll => 'Subukang Muli Lahat';

  @override
  String get relayDiagnosticRetrying => 'Sinusubukang muli...';

  @override
  String get relayDiagnosticRetryConnection => 'Subukang Muli ang Connection';

  @override
  String get relayDiagnosticTroubleshooting => 'Pag-troubleshoot';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• Berdeng status = Nakakonekta at gumagana\n• Pulang status = Nabigo ang connection\n• Kung nabigo ang network test, tsek ang internet connection\n• Kung naka-configure ang mga relay pero hindi konektado, i-tap ang \"Subukang Muli ang Connection\"\n• Mag-screenshot ng screen na ito para sa debugging';

  @override
  String get relayDiagnosticAllEndpointsHealthy =>
      'Lahat ng REST endpoint ay malusog!';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      'May ilang REST endpoint na nabigo - tingnan ang detalye sa itaas';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    return 'Nakahanap ng $count video event sa database';
  }

  @override
  String get relayDiagnosticQueryFailed => 'Nabigo ang query. Subukan ulit.';

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    return 'Nakakonekta sa $count relay!';
  }

  @override
  String get relayDiagnosticFailedToConnect =>
      'Hindi nakakonekta sa kahit anong relay';

  @override
  String get relayDiagnosticConnectionRetryFailed =>
      'Nabigo ang muling pagkonekta. Subukan ulit.';

  @override
  String get relayDiagnosticConnectedAuthenticated =>
      'Nakakonekta at Authenticated';

  @override
  String get relayDiagnosticConnectedOnly => 'Nakakonekta';

  @override
  String get relayDiagnosticNotConnected => 'Hindi nakakonekta';

  @override
  String get relayDiagnosticNoRelaysConfigured =>
      'Walang naka-configure na relay';

  @override
  String get relayDiagnosticFailed => 'Nabigo';

  @override
  String get notificationSettingsTitle => 'Mga Notification';

  @override
  String get notificationSettingsResetTooltip => 'I-reset sa default';

  @override
  String get notificationSettingsTypes => 'Mga Uri ng Notification';

  @override
  String get notificationSettingsLikes => 'Mga Like';

  @override
  String get notificationSettingsLikesSubtitle =>
      'Kapag may nag-like sa iyong mga video';

  @override
  String get notificationSettingsComments => 'Mga Comment';

  @override
  String get notificationSettingsCommentsSubtitle =>
      'Kapag may nag-comment sa iyong mga video';

  @override
  String get notificationSettingsFollows => 'Mga Follow';

  @override
  String get notificationSettingsFollowsSubtitle =>
      'Kapag may nag-follow sa iyo';

  @override
  String get notificationSettingsMentions => 'Mga Mention';

  @override
  String get notificationSettingsMentionsSubtitle => 'Kapag na-mention ka';

  @override
  String get notificationSettingsReposts => 'Mga Repost';

  @override
  String get notificationSettingsRepostsSubtitle =>
      'Kapag may nag-repost ng iyong mga video';

  @override
  String get notificationSettingsNewPosts => 'Mga Bagong Vine';

  @override
  String get notificationSettingsNewPostsSubtitle =>
      'Kapag nag-post ang taong binabantayan mo';

  @override
  String get notificationSettingsActions => 'Mga Aksyon';

  @override
  String get notificationSettingsMarkAllAsRead =>
      'Markahang Lahat Bilang Nabasa';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle =>
      'Markahan lahat ng notification bilang nabasa na';

  @override
  String get notificationSettingsAllMarkedAsRead =>
      'Lahat ng notification ay namarkahan bilang nabasa';

  @override
  String get notificationSettingsMarkAllAsReadFailed =>
      'Hindi nagawang markahan lahat bilang nabasa';

  @override
  String get notificationSettingsResetToDefaults =>
      'Naibalik ang mga setting sa default';

  @override
  String get notificationSettingsAbout => 'Tungkol sa Mga Notification';

  @override
  String get notificationSettingsAboutDescription =>
      'Ang mga notification ay pinapagana ng Nostr protocol. Ang real-time na update ay nakadepende sa iyong koneksyon sa mga Nostr relay. May ilang notification na maaaring ma-delay.';

  @override
  String get safetySettingsWhatYouSee => 'ANG NAKIKITA MO';

  @override
  String get safetySettingsWhatYouPublish => 'ANG PINO-POST MO';

  @override
  String get safetySettingsShowDivineHostedOnly =>
      'Ipakita lang ang mga video na naka-host sa Divine';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle =>
      'Itago ang mga video na galing sa ibang media host';

  @override
  String get safetySettingsModeration => 'MODERASYON';

  @override
  String get safetySettingsBlockedUsers => 'MGA NA-BLOCK NA USER';

  @override
  String get safetySettingsAgeVerification => 'BERIPIKASYON NG EDAD';

  @override
  String get safetySettingsAgeConfirmation =>
      'Kinukumpirma ko na ako ay 18 taong gulang o mas matanda';

  @override
  String get safetySettingsAgeRequired =>
      'Kailangan para makita ang adult content';

  @override
  String get safetySettingsAgeLockedForMinor => 'Naka-lock para sa account mo';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle =>
      'Opisyal na moderation service (naka-on bilang default)';

  @override
  String get safetySettingsPeopleIFollow => 'Mga taong fino-follow ko';

  @override
  String get safetySettingsPeopleIFollowSubtitle =>
      'Mag-subscribe sa mga label mula sa mga taong fino-follow mo';

  @override
  String get safetySettingsAddCustomLabeler => 'Magdagdag ng Custom Labeler';

  @override
  String get safetySettingsAddCustomLabelerHint => 'Ilagay ang npub...';

  @override
  String get safetySettingsAddCustomLabelerListTitle =>
      'Magdagdag ng custom labeler';

  @override
  String get safetySettingsRemoveLabeler => 'Alisin ang labeler';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle =>
      'Ilagay ang npub address';

  @override
  String get safetySettingsNoBlockedUsers => 'Walang na-block na user';

  @override
  String get safetySettingsUnblock => 'I-unblock';

  @override
  String get safetySettingsUserUnblocked => 'Na-unblock ang user';

  @override
  String get safetySettingsCancel => 'Kanselahin';

  @override
  String get safetySettingsAdd => 'Idagdag';

  @override
  String get analyticsTitle => 'Creator Analytics';

  @override
  String get analyticsDiagnosticsTooltip => 'Diagnostics';

  @override
  String get analyticsDiagnosticsSemanticLabel => 'I-toggle ang diagnostics';

  @override
  String get analyticsRetry => 'Subukan Ulit';

  @override
  String get analyticsUnableToLoad => 'Hindi na-load ang analytics.';

  @override
  String get analyticsServerUnavailable =>
      'Creator analytics is having server trouble. Please try again in a moment.';

  @override
  String get analyticsConnectionIssue =>
      'Creator analytics could not connect. Check your connection and try again.';

  @override
  String get analyticsSignInRequired =>
      'Mag-sign in para makita ang creator analytics.';

  @override
  String get analyticsViewDataUnavailable =>
      'Hindi makuha ngayon ang views mula sa relay para sa mga post na ito. Tama pa rin ang metrics ng like, comment, at repost.';

  @override
  String get analyticsViewDataTitle => 'Data ng views';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return 'Na-update $time • Ginagamit ng mga score ang likes, comments, reposts, at views/loops mula sa Funnelcake kapag available.';
  }

  @override
  String get analyticsVideos => 'Mga Video';

  @override
  String get analyticsViews => 'Mga View';

  @override
  String get analyticsInteractions => 'Mga Interaction';

  @override
  String get analyticsEngagement => 'Engagement';

  @override
  String get analyticsFollowers => 'Mga Follower';

  @override
  String get analyticsAvgPerPost => 'Avg/Post';

  @override
  String get analyticsInteractionMix => 'Halo ng interaksyon';

  @override
  String get analyticsLikes => 'Mga Like';

  @override
  String get analyticsComments => 'Mga Comment';

  @override
  String get analyticsReposts => 'Mga Repost';

  @override
  String get analyticsPerformanceHighlights => 'Mga Performance Highlight';

  @override
  String get analyticsMostViewed => 'Pinakamaraming napanood';

  @override
  String get analyticsMostDiscussed => 'Pinakamaraming napag-usapan';

  @override
  String get analyticsMostReposted => 'Pinakamaraming na-repost';

  @override
  String get analyticsNoVideosYet => 'Wala pang video';

  @override
  String get analyticsViewDataUnavailableShort =>
      'Hindi available ang view data';

  @override
  String analyticsViewsCount(int countValue, String count) {
    return '$count views';
  }

  @override
  String analyticsCommentsCount(int countValue, String count) {
    return '$count komento';
  }

  @override
  String analyticsRepostsCount(int countValue, String count) {
    return '$count reposts';
  }

  @override
  String get analyticsTopContent => 'Nangungunang content';

  @override
  String get analyticsPublishPrompt =>
      'Mag-publish ng ilang video para makita ang ranking.';

  @override
  String get analyticsEngagementRateExplainer =>
      'Right-side % = Engagement Rate (interactions na hinati sa views).';

  @override
  String get analyticsEngagementRateNoViews =>
      'Kailangan ng Engagement Rate ng view data; lalabas N/A ang values hangga\'t hindi available ang views.';

  @override
  String get analyticsEngagementLabel => 'Engagement';

  @override
  String get analyticsViewsUnavailable => 'hindi available ang views';

  @override
  String analyticsInteractionsCount(int countValue, String count) {
    return '$count interaksyon';
  }

  @override
  String get analyticsPostAnalytics => 'Analytics ng post';

  @override
  String get analyticsOpenPost => 'Buksan ang Post';

  @override
  String get analyticsRecentDailyInteractions =>
      'Kamakailang Pang-araw-araw na Interaction';

  @override
  String get analyticsNoActivityYet => 'Wala pang aktibidad sa range na ito.';

  @override
  String get analyticsDailyInteractionsExplainer =>
      'Interactions = likes + comments + reposts ayon sa petsa ng post.';

  @override
  String get analyticsDailyBarExplainer =>
      'Ang haba ng bar ay base sa pinakamataas na araw mo sa window na ito.';

  @override
  String get analyticsAudienceSnapshot => 'Snapshot ng audience';

  @override
  String analyticsFollowersCount(String count) {
    return 'Mga follower: $count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return 'Fino-follow: $count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      'Lalabas ang audience source/geo/time breakdown habang nagdadagdag ang Funnelcake ng mga audience analytics endpoint.';

  @override
  String get analyticsRetention => 'Retention';

  @override
  String get analyticsRetentionWithViews =>
      'Lalabas ang retention curve at watch-time breakdown kapag dumating na ang per-second/per-bucket retention mula sa Funnelcake.';

  @override
  String get analyticsRetentionWithoutViews =>
      'Hindi available ang retention data hangga\'t hindi pa naibabalik ng Funnelcake ang view+watch-time analytics.';

  @override
  String get analyticsDiagnostics => 'Diagnostics';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return 'Kabuuang video: $count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return 'May views: $count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return 'Walang views: $count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return 'Hydrated (bulk): $count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return 'Hydrated (/views): $count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return 'Mga source: $sources';
  }

  @override
  String analyticsDiagnosticsFailedSources(String sources) {
    return 'Failed sources: $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => 'Gumamit ng fixture data';

  @override
  String get analyticsNa => 'Wala';

  @override
  String get authCreateNewAccount => 'Gumawa ng bagong Divine account';

  @override
  String get authCreateNewAccountShort => 'Gumawa ng bagong account';

  @override
  String get authSignInDifferentAccount =>
      'Mag-sign in gamit ang ibang account';

  @override
  String get authUseAnotherAccount => 'Gumamit ng ibang account';

  @override
  String authContinueAs(String displayName) {
    return 'Magpatuloy bilang $displayName';
  }

  @override
  String get authRecoveryDraftsOwner =>
      'Ang iyong mga draft at clip ay naka-save para sa account na ito';

  @override
  String get authRecoveryOtherAccountWarning =>
      'Ang pag-sign in dito ay magtatago ng mga draft at clip na iyon';

  @override
  String get authTermsPrefix =>
      'Sa pagpili ng opsyon sa ibaba, kinukumpirma mong hindi ka bababa sa 16 taong gulang (o natapos mo na ang ';

  @override
  String get authTermsAgeAuthorizationCta => 'pag-authorize ng edad ng Divine';

  @override
  String get authTermsAfterAgeAuthorization => ') at sumasang-ayon ka sa ';

  @override
  String get authTermsOfService => 'Mga Tuntunin ng Serbisyo';

  @override
  String get authPrivacyPolicy => 'Patakaran sa Privacy';

  @override
  String get authTermsAnd => ', at ';

  @override
  String get authSafetyStandards => 'Mga Pamantayan sa Kaligtasan';

  @override
  String get authAmberNotInstalled => 'Hindi naka-install ang Amber app';

  @override
  String get authAmberConnectionFailed => 'Hindi nakakonekta sa Amber';

  @override
  String get authPasswordResetSent =>
      'Kung may account na umiiral sa email na iyon, naipadala na ang link para sa pag-reset ng password.';

  @override
  String get authSignInTitle => 'Mag-sign in';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authConfirmPasswordLabel => 'Kumpirmahin ang password';

  @override
  String get authEmailRequired => 'Kailangan ang email';

  @override
  String get authEmailInvalid => 'Pakilagay ang valid na email';

  @override
  String get authPasswordRequired => 'Kailangan ang password';

  @override
  String get authConfirmPasswordRequired => 'Pakikumpirma ang iyong password';

  @override
  String get authPasswordsDoNotMatch => 'Hindi magkatugma ang mga password';

  @override
  String get authForgotPassword => 'Nakalimutan ang password?';

  @override
  String get authImportNostrKey => 'Mag-import ng Nostr key';

  @override
  String get authConnectSignerApp => 'Kumonekta gamit ang signer app';

  @override
  String get authSignInWithAmber => 'Mag-sign in gamit ang Amber';

  @override
  String get authSignInWithBrowserExtension =>
      'Mag-sign in gamit ang browser extension';

  @override
  String get authNip07ConnectionFailed =>
      'Hindi nakakonekta sa iyong browser extension.';

  @override
  String get authNip07ExtensionNotFound =>
      'Walang nahanap na browser extension. Mag-install ng Alby, nos2x, o iba pang NIP-07 compatible na extension.';

  @override
  String get authSignInOptionsTitle => 'Mga opsyon sa pag-sign in';

  @override
  String get authInfoEmailPasswordTitle => 'Email at Password';

  @override
  String get authInfoEmailPasswordDescription =>
      'Mag-sign in gamit ang iyong Divine account. Kung nag-register ka gamit ang email at password, gamitin mo iyon dito.';

  @override
  String get authInfoImportNostrKeyDescription =>
      'May Nostr identity ka na? I-import ang iyong nsec private key mula sa ibang client.';

  @override
  String get authInfoSignerAppTitle => 'Signer App';

  @override
  String get authInfoSignerAppDescription =>
      'Kumonekta gamit ang NIP-46 compatible na remote signer tulad ng nsecBunker para sa mas mahigpit na key security.';

  @override
  String get authInfoAmberTitle => 'Amber';

  @override
  String get authInfoAmberDescription =>
      'Gamitin ang Amber signer app sa Android para ligtas na pamahalaan ang iyong mga Nostr key.';

  @override
  String get authInfoBrowserExtensionTitle => 'Browser Extension';

  @override
  String get authInfoBrowserExtensionDescription =>
      'Mag-sign in gamit ang NIP-07 browser extension tulad ng Alby o nos2x. Nananatili sa extension ang iyong mga key — hindi ito nakikita ng Divine.';

  @override
  String get authSignInErrorInvalidCredentials =>
      'Mali ang email o password. Subukan ulit.';

  @override
  String get authSignInErrorEmailNotVerified =>
      'I-verify ang iyong email bago mag-sign in — tingnan ang inbox mo para sa link.';

  @override
  String get authSignInErrorInvalidEmail =>
      'Mukhang hindi iyon wastong email address.';

  @override
  String get authSignInErrorNetwork =>
      'Hindi maabot ang server. Tingnan ang iyong koneksyon at subukan ulit.';

  @override
  String get authSignInErrorGeneric => 'May nangyaring mali. Subukan ulit.';

  @override
  String get authSignInOptionsHintPrefix =>
      'Hindi sigurado kung paano ka nakapasok noong huli? ';

  @override
  String get authSignInOptionsHintCta =>
      'Tingnan ang lahat ng opsyon sa pag-sign in';

  @override
  String get authCreateAccountTitle => 'Gumawa ng account';

  @override
  String get authBackToInviteCode => 'Bumalik sa invite code';

  @override
  String get authUseDivineNoBackup => 'Gamitin ang Divine nang walang backup';

  @override
  String get authSkipConfirmTitle => 'Isang huling bagay...';

  @override
  String get authSkipConfirmKeyCreated =>
      'Pasok ka na! Gagawa kami ng secure na key na magpapagana sa iyong Divine account.';

  @override
  String get authSkipConfirmKeyOnly =>
      'Kung walang email, ang key mo ang tanging paraan para malaman ng Divine na sa iyo ang account na ito.';

  @override
  String get authSkipConfirmRecommendEmail =>
      'Pwede mong i-access ang key mo sa app, pero kung hindi ka technical, mas inirerekomenda namin na magdagdag ka na ng email at password ngayon. Mas madali ang pag-sign in at pagbalik sa account mo kapag nawala o na-reset ang device na ito.';

  @override
  String get authAddEmailPassword => 'Magdagdag ng email at password';

  @override
  String get authUseThisDeviceOnly => 'Sa device na ito lang gamitin';

  @override
  String get authCompleteRegistration => 'Kumpletuhin ang iyong registration';

  @override
  String get authVerifying => 'Vine-verify...';

  @override
  String get authVerificationLinkSent =>
      'Nagpadala kami ng verification link sa:';

  @override
  String get authClickVerificationLink =>
      'Pakiclick ang link sa iyong email para\nkumpletuhin ang iyong registration.';

  @override
  String get authPleaseWaitVerifying =>
      'Pakihintay habang vine-verify namin ang iyong email...';

  @override
  String get authWaitingForVerification => 'Naghihintay ng verification';

  @override
  String get authOpenEmailApp => 'Buksan ang email app';

  @override
  String get authVerificationPinPrompt =>
      'O ilagay ang 6-digit na code mula sa email mo';

  @override
  String get authVerificationPinFieldLabel => '6-digit na code';

  @override
  String get authVerificationPinSubmit => 'I-verify ang code';

  @override
  String get authVerificationResendPrompt => 'Hindi mo natanggap?';

  @override
  String get authVerificationResend => 'Ipadala ulit';

  @override
  String authVerificationResendCooldown(String time) {
    return 'Ipadala ulit pagkalipas ng $time';
  }

  @override
  String get authVerificationResendFailed =>
      'Hindi namin naipadala ulit ang email. Subukan ulit.';

  @override
  String get authVerificationResendExpired =>
      'Nag-expire na ang sign-up na iyon. Magsimula ulit para makakuha ng bagong code.';

  @override
  String get authVerificationResendUnavailable =>
      'Hindi pa pwedeng magpadala ulit ngayon. Gamitin ang 6-digit na code mula sa email na naipadala na namin sa iyo.';

  @override
  String get authVerificationPollingStopped =>
      'Tumigil na kaming mag-check para sa iyo. Ilagay ang 6-digit na code mula sa email mo para matapos ang pag-sign in.';

  @override
  String get authWelcomeToDivine => 'Welcome sa Divine!';

  @override
  String get authEmailVerified => 'Na-verify na ang iyong email.';

  @override
  String get authSigningYouIn => 'Sini-sign in ka';

  @override
  String get authErrorTitle => 'Naku.';

  @override
  String get authVerificationFailed =>
      'Hindi na-verify ang iyong email.\nPakisubukang ulit.';

  @override
  String get authStartOver => 'Magsimulang muli';

  @override
  String get authEmailVerifiedLogin =>
      'Na-verify ang email! Pakilog in para magpatuloy.';

  @override
  String get authVerificationLinkExpired =>
      'Hindi na valid ang verification link na ito.';

  @override
  String get authVerificationConnectionError =>
      'Hindi na-verify ang email. Pakitsek ang iyong connection at subukang ulit.';

  @override
  String get authWaitlistConfirmTitle => 'Pasok ka na!';

  @override
  String authWaitlistUpdatesAt(String email) {
    return 'Magbabahagi kami ng update sa $email.\nKapag may mga bagong invite code na, ipapadala namin sa iyo.';
  }

  @override
  String get authOk => 'OK';

  @override
  String get authTryAgain => 'Subukan ulit';

  @override
  String get authContactSupport => 'Makipag-ugnayan sa support';

  @override
  String authCouldNotOpenEmail(String email) {
    return 'Hindi mabuksan ang $email';
  }

  @override
  String get authAddInviteCode => 'Idagdag ang iyong invite code';

  @override
  String get authInviteCodeLabel => 'Invite code';

  @override
  String get authEnterYourCode => 'Ilagay ang iyong code';

  @override
  String get authNext => 'Susunod';

  @override
  String get authJoinWaitlist => 'Sumali sa waitlist';

  @override
  String get authJoinWaitlistTitle => 'Sumali sa waitlist';

  @override
  String get authJoinWaitlistDescription =>
      'Ibahagi ang iyong email at magpapadala kami ng invite code kapag may bukas na access.';

  @override
  String get authJoinWaitlistNewsletterOptIn =>
      'Padalhan ako ng inspirasyon mula sa Divine';

  @override
  String get authInviteAccessHelp => 'Tulong sa invite access';

  @override
  String get authGeneratingConnection => 'Bumubuo ng connection...';

  @override
  String get authConnectedAuthenticating =>
      'Nakakonekta! Nagsa-authenticate...';

  @override
  String get authConnectionTimedOut => 'Nag-time out ang connection';

  @override
  String get authApproveConnection =>
      'Siguraduhin na inaprubahan mo ang connection sa iyong signer app.';

  @override
  String get authConnectionCancelled => 'Kinansela ang connection';

  @override
  String get authConnectionCancelledMessage => 'Kinansela ang connection.';

  @override
  String get authConnectionFailed => 'Nabigo ang connection';

  @override
  String get authUnknownError => 'May hindi inaasahang error na nangyari.';

  @override
  String get authNostrConnectStartFailed =>
      'Hindi maabot ang signer app. Pakitsek ang iyong connection at subukan ulit.';

  @override
  String get authNostrConnectInvalidSession =>
      'Hindi na valid ang connection link na ito. Magsimula ng bago.';

  @override
  String get authNostrConnectSetupFailed =>
      'Malapit na — hindi namin natapos ang pag-sign in sa iyo. Subukan ulit.';

  @override
  String get authUrlCopied => 'Nakopya ang URL sa clipboard';

  @override
  String get authConnectToDivine => 'Kumonekta sa Divine';

  @override
  String get authPasteBunkerUrl => 'I-paste ang bunker:// URL';

  @override
  String get authBunkerUrlHint => 'bunker:// URL';

  @override
  String get authInvalidBunkerUrl =>
      'Invalid ang bunker URL. Dapat magsimula ito sa bunker://';

  @override
  String get authScanSignerApp =>
      'I-scan gamit ang iyong\nsigner app para kumonekta.';

  @override
  String authWaitingForConnection(int seconds) {
    return 'Naghihintay ng connection... ${seconds}s';
  }

  @override
  String get authCopyUrl => 'Kopyahin ang URL';

  @override
  String get authShare => 'I-share';

  @override
  String get authAddBunker => 'Magdagdag ng bunker';

  @override
  String get authCompatibleSignerApps => 'Mga compatible na Signer app';

  @override
  String get authFailedToConnect => 'Hindi nakakonekta';

  @override
  String get authResetPasswordTitle => 'I-reset ang Password';

  @override
  String get authResetPasswordSubtitle =>
      'Pakilagay ang iyong bagong password. Dapat ay hindi bababa sa 8 character ang haba.';

  @override
  String get authNewPasswordLabel => 'Bagong Password';

  @override
  String get authConfirmNewPasswordLabel => 'Kumpirmahin ang bagong password';

  @override
  String get authPasswordTooShort =>
      'Dapat ay hindi bababa sa 8 character ang password';

  @override
  String get authPasswordResetSuccess =>
      'Matagumpay na na-reset ang password. Pakilog in.';

  @override
  String get authPasswordResetFailed => 'Hindi na-reset ang password';

  @override
  String get authUnexpectedError =>
      'May hindi inaasahang error na nangyari. Pakisubukang ulit.';

  @override
  String get authUpdatePassword => 'I-update ang password';

  @override
  String get authSecureAccountTitle => 'I-secure ang account';

  @override
  String get authUnableToAccessKeys =>
      'Hindi ma-access ang iyong mga key. Pakisubukang ulit.';

  @override
  String get authRegistrationFailed => 'Nabigo ang registration';

  @override
  String get authRegistrationComplete =>
      'Kumpleto na ang registration. Pakitsek ang iyong email.';

  @override
  String get authSecureAccountAlreadyRegistered =>
      'Looks like an account already exists. Try a different email, or sign in to the existing account with this email address. If neither works, contact support.';

  @override
  String get authFailedToSendResetEmail => 'Hindi naipadala ang reset email.';

  @override
  String get authSending => 'Nagpapadala...';

  @override
  String get authSignInButton => 'Mag-sign in';

  @override
  String get authVerificationErrorTimeout =>
      'Nag-time out ang verification. Pakisubukang mag-register ulit.';

  @override
  String get authVerificationErrorMissingCode =>
      'Nabigo ang verification — kulang ang authorization code.';

  @override
  String get authVerificationErrorPollFailed =>
      'Nabigo ang verification. Pakisubukang ulit.';

  @override
  String get authVerificationErrorNetworkExchange =>
      'May network error habang nagsa-sign in. Pakisubukang ulit.';

  @override
  String get authVerificationErrorOAuthExchange =>
      'Nabigo ang verification. Pakisubukang mag-register ulit.';

  @override
  String get authVerificationErrorSignInFailed =>
      'Nabigo ang sign-in. Pakisubukang mag-log in nang manu-mano.';

  @override
  String get authVerificationEmailAlreadyRegistered =>
      'Nakarehistro na ang email na ito. Mag-sign in na lang.';

  @override
  String get authVerificationErrorPinInvalid =>
      'Hindi tumugma ang code. I-double check ito at subukan ulit.';

  @override
  String get authVerificationErrorPinExpired =>
      'Nag-expire na ang code. I-tap ang Ipadala ulit para kumuha ng bago.';

  @override
  String get authVerificationErrorPinLocked =>
      'Masyadong maraming tries. I-tap ang Ipadala ulit para kumuha ng bagong code.';

  @override
  String get authVerificationErrorPinFailed =>
      'Hindi namin na-verify ang code. Pakisubukan ulit.';

  @override
  String get authVerificationErrorPinUnavailable =>
      'Hindi available ang paglalagay ng code ngayon. I-tap ang link sa email mo, o ipadala ulit para kumuha ng bago.';

  @override
  String get authInviteCodeErrorMalformed =>
      'Maglagay ng invite code tulad ng ABCD-EFGH.';

  @override
  String get authInviteCodeErrorNotFound =>
      'Mukhang hindi valid ang invite code na iyan.';

  @override
  String get authInviteCodeErrorAlreadyUsed =>
      'Nagamit na o binawi na ang invite code na iyan.';

  @override
  String get authInviteGateErrorCreatorFull =>
      'Ubos na ang mga invite ng creator na ito';

  @override
  String get authInviteGateErrorUnavailable =>
      'Hindi available ang invite code na iyan. Sumali sa waitlist at padadalhan ka namin ng invite kapag may bakante.';

  @override
  String get authInviteGateErrorCheckFailed =>
      'Hindi namin ma-check ang code na iyan. Subukan ulit.';

  @override
  String get authInviteGateErrorUnknown =>
      'May nangyaring mali. Subukan ulit ang invite code mo.';

  @override
  String get authInviteErrorAlreadyUsed =>
      'Hindi na available ang invite code na iyon. Bumalik sa iyong invite code, sumali sa waitlist, o makipag-ugnayan sa support.';

  @override
  String get authInviteErrorInvalid =>
      'Hindi pwedeng gamitin ngayon ang invite code na iyon. Bumalik sa iyong invite code, sumali sa waitlist, o makipag-ugnayan sa support.';

  @override
  String get authInviteErrorTemporary =>
      'Hindi namin ma-confirm ang iyong invite ngayon. Bumalik sa iyong invite code at subukang ulit, o makipag-ugnayan sa support.';

  @override
  String get authInviteErrorUnknown =>
      'Hindi namin na-activate ang iyong invite. Bumalik sa iyong invite code, sumali sa waitlist, o makipag-ugnayan sa support.';

  @override
  String get shareSheetSave => 'I-save';

  @override
  String get shareSheetRemoveFromSaved => 'Alisin sa naka-save';

  @override
  String get shareSheetSaveToGallery => 'I-save sa Gallery';

  @override
  String get shareSheetSaveWithWatermark => 'I-save na may Watermark';

  @override
  String get shareSheetSaveVideo => 'I-save ang Video';

  @override
  String get shareSheetAddToClips => 'Idagdag sa clips';

  @override
  String get shareSheetNameClipTitle => 'Pangalanan ang clip na ito';

  @override
  String get shareSheetNameClipSubtitle =>
      'Pumili ng pangalang makikilala mo sa iyong library.';

  @override
  String get shareSheetClipTitleLabel => 'Pamagat ng clip';

  @override
  String get shareSheetSaveClip => 'I-save ang clip';

  @override
  String shareSheetSavedClipToClips(String title) {
    return 'Na-save ang \"$title\" sa mga clip';
  }

  @override
  String get shareSheetUntitledClip => 'Clip na walang pamagat';

  @override
  String get shareSheetAddToClipsFailed => 'Hindi naidagdag sa clips';

  @override
  String get shareSheetAddToList => 'Idagdag sa List';

  @override
  String get shareSheetCopy => 'Kopyahin';

  @override
  String get shareSheetShareVia => 'I-share gamit ang';

  @override
  String get shareSheetEventJson => 'Event JSON';

  @override
  String get shareSheetEventId => 'Event ID';

  @override
  String get shareSheetMoreActions => 'Iba pang aksyon';

  @override
  String get shareSheetCrosspost => 'I-crosspost';

  @override
  String get crosspostSheetTitle => 'I-crosspost ang video na ito';

  @override
  String get crosspostSheetSubtitle =>
      'Ipadala ito sa mga naka-connect mong platform. Maaaring tumagal nang ilang minuto ang pag-post.';

  @override
  String get crosspostSubmit => 'I-crosspost';

  @override
  String get crosspostStatusQueued => 'Naka-queue';

  @override
  String get crosspostStatusUploading => 'Ina-upload';

  @override
  String get crosspostStatusProcessing => 'Pinoproseso';

  @override
  String get crosspostStatusPosted => 'Nai-post';

  @override
  String get crosspostStatusFailed => 'Nabigo';

  @override
  String get crosspostStatusSkipped => 'Nilaktawan';

  @override
  String get crosspostStatusNeedsReauth => 'Kailangang i-reconnect';

  @override
  String get crosspostViewPost => 'Tingnan ang post';

  @override
  String crosspostReconnectPrompt(String platform) {
    return 'I-reconnect ang $platform sa crossposting settings para makapag-post pa rin.';
  }

  @override
  String get crosspostReconnect => 'I-reconnect';

  @override
  String get crosspostErrorNotOwner =>
      'Mga sarili mong video lang ang puwedeng i-crosspost.';

  @override
  String get crosspostErrorNotEligible =>
      'Hindi eligible ang video na ito para sa crossposting.';

  @override
  String get crosspostErrorNotConnected =>
      'Hindi naka-connect ang platform na iyon.';

  @override
  String get crosspostErrorUnauthorized =>
      'I-reconnect ang account mo, tapos subukan ulit.';

  @override
  String get crosspostErrorNetwork =>
      'Hindi maabot ang crossposter. Pakisubukan ulit mamaya.';

  @override
  String get crosspostFailedGeneric => 'Nabigo ang crosspost.';

  @override
  String get crosspostStillWorking =>
      'Pinoproseso pa. Puwede mo nang isara ito — tuloy ang pag-post sa background.';

  @override
  String get crosspostDone => 'Tapos na';

  @override
  String get watermarkDownloadSavedToCameraRoll => 'Na-save sa Camera Roll';

  @override
  String get watermarkDownloadShare => 'I-share';

  @override
  String get watermarkDownloadDone => 'Tapos na';

  @override
  String get watermarkDownloadPhotosAccessNeeded =>
      'Kailangan ng Photos Access';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      'Para makapag-save ng video, pahintulutan ang Photos access sa Settings.';

  @override
  String get watermarkDownloadOpenSettings => 'Buksan ang Settings';

  @override
  String get watermarkDownloadNotNow => 'Hindi Ngayon';

  @override
  String get watermarkDownloadFailed => 'Nabigo ang Download';

  @override
  String get watermarkDownloadDismiss => 'I-dismiss';

  @override
  String get watermarkDownloadStageDownloading => 'Dina-download ang Video';

  @override
  String get watermarkDownloadStageWatermarking => 'Naglalagay ng Watermark';

  @override
  String get watermarkDownloadStageSaving => 'Sina-save sa Camera Roll';

  @override
  String get watermarkDownloadStageDownloadingDesc =>
      'Kinukuha ang video mula sa network...';

  @override
  String get watermarkDownloadStageWatermarkingDesc =>
      'Inilalagay ang Divine watermark...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      'Sina-save ang naka-watermark na video sa iyong camera roll...';

  @override
  String get shareMenuBookmarks => 'Mga Bookmark';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    return '$count follow sets ang available';
  }

  @override
  String get peopleListsAddToList => 'Idagdag sa listahan';

  @override
  String get peopleListsSheetTitle => 'Idagdag sa listahan';

  @override
  String get peopleListsEmptyTitle => 'Wala pang listahan';

  @override
  String get peopleListsEmptySubtitle =>
      'Gumawa ng listahan para simulang igrupo ang mga tao.';

  @override
  String get peopleListsCreateList => 'Gumawa ng listahan';

  @override
  String get peopleListsNewListTitle => 'Bagong listahan';

  @override
  String get peopleListsRouteTitle => 'Listahan ng tao';

  @override
  String get peopleListsListNameLabel => 'Pangalan ng listahan';

  @override
  String get peopleListsListNameHint => 'Mga close friend';

  @override
  String get peopleListsCreateButton => 'Gumawa';

  @override
  String get peopleListsAddPeopleTitle => 'Magdagdag ng tao';

  @override
  String get peopleListsAddPeopleTooltip => 'Magdagdag ng tao';

  @override
  String get peopleListsAddPeopleSemanticLabel =>
      'Magdagdag ng tao sa listahan';

  @override
  String get peopleListsListNotFoundTitle => 'Hindi nakita ang listahan';

  @override
  String get peopleListsListNotFoundSubtitle =>
      'Hindi nakita ang listahan. Maaaring nabura na ito.';

  @override
  String get peopleListsListDeletedSubtitle =>
      'Maaaring nabura na ang listahang ito.';

  @override
  String get peopleListsNoPeopleTitle => 'Walang tao sa listahang ito';

  @override
  String get peopleListsNoPeopleSubtitle =>
      'Magdagdag ng mga tao para magsimula';

  @override
  String get peopleListsNoVideosTitle => 'Wala pang video';

  @override
  String get peopleListsNoVideosSubtitle =>
      'Lalabas dito ang mga video mula sa mga miyembro ng listahan';

  @override
  String get peopleListsNoVideosAvailable => 'Walang available na video';

  @override
  String get peopleListsFailedToLoadVideos => 'Hindi na-load ang mga video';

  @override
  String get peopleListsVideoNotAvailable => 'Hindi available ang video';

  @override
  String get peopleListsBackToGridTooltip => 'Bumalik sa grid';

  @override
  String get peopleListsErrorLoadingVideos =>
      'May error sa pag-load ng mga video';

  @override
  String get peopleListsNoPeopleToAdd =>
      'Walang available na tao na maidadagdag.';

  @override
  String peopleListsAddToListName(String name) {
    return 'Idagdag sa $name';
  }

  @override
  String get peopleListsAddPeopleSearchHint => 'Maghanap ng tao';

  @override
  String get peopleListsAddPeopleError =>
      'Hindi na-load ang mga tao. Subukan ulit.';

  @override
  String get peopleListsAddPeopleRetry => 'Subukan ulit';

  @override
  String get peopleListsAddButton => 'Idagdag';

  @override
  String peopleListsAddButtonWithCount(int count) {
    return 'Idagdag ang $count';
  }

  @override
  String peopleListsInNLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Nasa $count listahan',
      one: 'Nasa $count listahan',
    );
    return '$_temp0';
  }

  @override
  String peopleListsRemoveConfirmTitle(String name) {
    return 'Alisin si $name?';
  }

  @override
  String get peopleListsRemoveConfirmBody => 'Aalisin sila sa listahang ito.';

  @override
  String get peopleListsRemove => 'Alisin';

  @override
  String peopleListsRemovedFromList(String name) {
    return 'Naalis si $name sa listahan';
  }

  @override
  String get peopleListsUndo => 'I-undo';

  @override
  String peopleListsProfileLongPressHint(String name) {
    return 'Profile ni $name. Long press para alisin.';
  }

  @override
  String peopleListsViewProfileHint(String name) {
    return 'Tingnan ang profile ni $name';
  }

  @override
  String get shareMenuEditVideo => 'I-edit ang Video';

  @override
  String get shareMenuDeleteVideo => 'Burahin ang Video';

  @override
  String shareMenuVideoCount(int count) {
    return '$count mga video';
  }

  @override
  String get shareMenuDeleteConfirmation =>
      'Permanenteng buburahin nito ang video na ito sa Divine. Maaari pa rin itong lumitaw sa third-party Nostr clients na gumagamit ng ibang relays.';

  @override
  String get shareMenuCancel => 'Kanselahin';

  @override
  String get shareMenuDelete => 'Burahin';

  @override
  String get shareMenuDeleteFailedNotInitialized =>
      'Hindi pa handa ang pagbubura. Subukan ulit mamaya.';

  @override
  String get shareMenuDeleteFailedNotOwner =>
      'Sariling video mo lang ang puwede mong burahin.';

  @override
  String get shareMenuDeleteFailedNotAuthenticated =>
      'Mag-sign in ulit, tapos subukang burahin.';

  @override
  String get shareMenuDeleteFailedCouldNotSign =>
      'Hindi na-sign ang delete request. Subukan ulit.';

  @override
  String get shareMenuDeleteFailedRelayRejected =>
      'Hindi tinanggap ng relay ang delete request na ito. Subukan ulit mamaya.';

  @override
  String get shareMenuDeleteFailedAccountRestricted =>
      'Your account is restricted, so this delete request couldn\'t be sent. Contact support for help deleting it.';

  @override
  String get shareMenuDeleteFailedRelayNoResponse =>
      'Hindi maabot ang relay. Tingnan ang koneksyon mo at subukan ulit.';

  @override
  String get shareMenuDeletePartiallyConfirmed =>
      'Nabura na. Hindi lahat ng relay ang nakumpirma, kaya baka lumabas pa rin ito sa ibang app.';

  @override
  String get shareMenuDeleteFailedGeneric =>
      'Hindi nabura ang video na ito. Subukan ulit.';

  @override
  String get shareMenuUpdate => 'I-update';

  @override
  String get shareMenuChangeCover => 'Palitan ang Cover';

  @override
  String get shareMenuVideoUpdated => 'Matagumpay na na-update ang video';

  @override
  String shareMenuVideoUpdatedWithInviteFailures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mga imbitasyon sa collaborator ang hindi naipadala.',
      one: '$count imbitasyon sa collaborator ang hindi naipadala.',
    );
    return 'Na-update ang video, pero $_temp0';
  }

  @override
  String get videoUpdateErrorNotAuthenticated =>
      'Mag-sign in ulit, tapos subukan ulit.';

  @override
  String get videoUpdateErrorNoPlayableVideo =>
      'Walang mapa-play na source ang video na ito, kaya hindi ito ma-edit.';

  @override
  String get videoUpdateErrorCouldNotSign =>
      'Hindi na-sign ang update. Subukan ulit.';

  @override
  String get videoUpdateErrorPublishRejected =>
      'Hindi tinanggap ng relay ang update. Subukan ulit maya-maya.';

  @override
  String get videoUpdateErrorGeneric =>
      'Hindi na-update ang video na ito. Subukan ulit.';

  @override
  String get shareMenuOriginalVideoUnavailable =>
      'Couldn\'t load the original video. Try again in a moment.';

  @override
  String get shareMenuDeleteVideoQuestion => 'Burahin ang Video?';

  @override
  String get shareMenuDeleteCleanupInProgress => 'Inaalis ang video…';

  @override
  String get shareMenuDeleteCleanupConfirmed => 'Na-delete ang video.';

  @override
  String get shareMenuDeleteCleanupDelayed =>
      'Na-delete ang video. Maaaring matagalan nang kaunti bago ito mawala sa lahat ng lugar.';

  @override
  String get shareMenuDeleteCleanupFailed =>
      'Na-delete ang video, pero hindi namin naalis ang lahat ng kopya. Makipag-ugnayan sa support.';

  @override
  String get authSessionExpired =>
      'Nag-expire na ang iyong session. Mag-sign in ulit.';

  @override
  String get authAccountRestoreFailed =>
      'We couldn\'t unlock that account on this device. Sign in again.';

  @override
  String get authSignInFailed => 'Hindi nag-sign in. Subukan ulit.';

  @override
  String get webAuthNotSupportedSecureMode =>
      'Hindi suportado ang web authentication sa secure mode. Gamitin ang mobile app para sa secure key management.';

  @override
  String get webAuthEnterBunkerUri => 'Maglagay ng bunker URI';

  @override
  String get webAuthConnectTitle => 'Mag-connect sa Divine';

  @override
  String get webAuthChooseMethod =>
      'Piliin ang gusto mong paraan ng Nostr authentication';

  @override
  String get webAuthBrowserExtension => 'Browser Extension';

  @override
  String get webAuthRecommended => 'INIREREKOMENDA';

  @override
  String get webAuthNsecBunker => 'nsec bunker';

  @override
  String get webAuthConnectRemoteSigner => 'Mag-connect sa remote signer';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => 'I-paste mula sa clipboard';

  @override
  String get webAuthConnectToBunker => 'Mag-connect sa Bunker';

  @override
  String get webAuthNewToNostr => 'Bago ka sa Nostr?';

  @override
  String get webAuthNostrHelp =>
      'Mag-install ng browser extension tulad ng Alby o nos2x para sa pinakamadaling karanasan, o gamitin ang nsec bunker para sa secure remote signing.';

  @override
  String get soundsTitle => 'Mga Sound';

  @override
  String get soundsSearchHint => 'Maghanap ng sounds...';

  @override
  String get soundsSearchResults => 'Mga Resulta ng Paghahanap';

  @override
  String get soundsNoSoundsFound => 'Walang nahanap na sound';

  @override
  String get soundsNoSoundsFoundDescription => 'Subukan ang ibang search term';

  @override
  String get soundsSavedToLibrary => 'Na-save sa Sounds';

  @override
  String get soundsAlreadySavedToLibrary => 'Nasa Sounds na';

  @override
  String get soundsSavedLibraryTitle => 'Mga Sound Ko';

  @override
  String get soundsSavedEmptyTitle => 'Wala pang naka-save na sound';

  @override
  String get soundsSavedEmptyDescription =>
      'I-tap ang Use Sound sa isang video para i-save ito dito.';

  @override
  String get soundsRemoveSavedSound => 'Alisin ang sound';

  @override
  String get savedSoundSaveAction => 'I-save';

  @override
  String get savedSoundPausePreviewAction => 'I-pause ang preview';

  @override
  String get savedSoundResumePreviewAction => 'Ipagpatuloy ang preview';

  @override
  String get savedSoundDetailsSheetTitle => 'Mga detalye ng sound';

  @override
  String get savedSoundRemoveConfirmTitle => 'Alisin ang sound na ito?';

  @override
  String get savedSoundRemoveConfirmMessage =>
      'Mawawala ito sa library mo, pero puwede mo itong i-save ulit mula sa kahit anong video na gumagamit nito.';

  @override
  String get soundsRemovedFromLibrary => 'Naalis sa Sounds';

  @override
  String get soundsSaveFailed =>
      'Hindi na-save ang sound na iyon. Subukan ulit.';

  @override
  String get soundsRemoveFailed =>
      'Hindi natanggal ang sound na iyon. Subukan ulit.';

  @override
  String get soundSyncStatusSyncing => 'Sini-sync ang iyong mga tunog…';

  @override
  String get soundSyncStatusSynced => 'Napapanahon na ang mga tunog';

  @override
  String get soundSyncStatusFailed =>
      'Hindi na-sync ang iyong mga tunog. Susubukan ulit namin.';

  @override
  String get soundSyncStatusLocked =>
      'Hindi mabuksan ang iyong naka-sync na library sa device na ito.';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileMoreOptions => 'Iba pang opsyon';

  @override
  String profileBlockedUser(String name) {
    return 'Na-block si $name';
  }

  @override
  String profileUnblockedUser(String name) {
    return 'Na-unblock si $name';
  }

  @override
  String profileUnfollowedUser(String name) {
    return 'Na-unfollow si $name';
  }

  @override
  String get profileFeedError =>
      'Hindi maabot ang server. Tingnan ang iyong koneksyon at subukan ulit.';

  @override
  String get profileFeedLoadMoreError =>
      'Hindi na-load ang iba pang video. Hilahin pababa para mag-refresh.';

  @override
  String get notificationsTabAll => 'Lahat';

  @override
  String get notificationsTabLikes => 'Likes';

  @override
  String get notificationsTabComments => 'Mga komento';

  @override
  String get notificationsTabFollows => 'Mga follow';

  @override
  String get notificationsTabReposts => 'Reposts';

  @override
  String get notificationsFailedToLoad => 'Hindi na-load ang notifications';

  @override
  String get notificationsRetry => 'Subukan ulit';

  @override
  String get notificationsRefreshError =>
      'Hindi ma-refresh — ipinapakita ang nasa iyo';

  @override
  String get notificationsUnreadPrefix => 'Hindi pa nababasang notification';

  @override
  String notificationsBadgeUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hindi pa nababasang notification',
      one: '$count hindi pa nababasang notification',
    );
    return '$_temp0';
  }

  @override
  String notificationsViewProfileSemanticLabel(String displayName) {
    return 'Tingnan ang profile ni $displayName';
  }

  @override
  String get notificationsViewProfilesSemanticLabel =>
      'Tingnan ang mga profile';

  @override
  String notificationsVideoThumbnailFor(String title) {
    return 'Thumbnail ng video para sa $title';
  }

  @override
  String get notificationsVideoThumbnail => 'Thumbnail ng video';

  @override
  String get notificationsInviteSingular =>
      'May 1 ka pang invite na puwedeng i-share sa kaibigan!';

  @override
  String notificationsInvitePlural(int count) {
    return 'May $count ka pang invites na puwedeng i-share sa mga kaibigan!';
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
  String get notificationsVideoUnavailable => 'Hindi available ang video';

  @override
  String get feedFailedToLoadVideos => 'Hindi na-load ang mga video';

  @override
  String get feedRetry => 'Subukan ulit';

  @override
  String get feedNoFollowedUsers =>
      'Wala kang fino-follow.\nMag-follow ng tao para makita ang kanilang mga video dito.';

  @override
  String get feedModeForYou => 'Para Sa Iyo';

  @override
  String get feedModeNew => 'Bago';

  @override
  String get feedModeFollowing => 'Fino-follow';

  @override
  String get feedModeClassics => 'Klasiko';

  @override
  String feedModeSemanticLabel(String label) {
    return 'Mode ng feed: $label';
  }

  @override
  String videoAuthorSemanticLabel(String displayName) {
    return 'May-akda ng video: $displayName';
  }

  @override
  String get videoAuthorAvatarSemanticLabel => 'Avatar ng may-akda';

  @override
  String get feedForYouEmpty =>
      'Walang laman ang For You feed mo.\nMag-explore ng video at mag-follow ng creators para mahubog ito.';

  @override
  String get feedFollowingEmpty =>
      'Wala pang video mula sa mga taong fino-follow mo.\nHumanap ng creators na gusto mo at i-follow sila.';

  @override
  String get feedLatestEmpty => 'Wala pang bagong video.\nBumalik mamaya.';

  @override
  String get feedClassicEmpty => 'Wala pang klasiko.\nBumalik mamaya.';

  @override
  String get feedExploreVideos => 'Mag-explore ng Video';

  @override
  String get feedLoadingMore => 'Naglo-load ng iba pang video…';

  @override
  String get feedRefreshed => 'Na-refresh ang feed';

  @override
  String get uploadUploadingVideo => 'Nag-u-upload ng video';

  @override
  String get postPublishConfirmationTitle => 'Na-publish na sa profile mo';

  @override
  String get postPublishConfirmationView => 'Tingnan';

  @override
  String get postPublishConfirmationShare => 'I-share';

  @override
  String get postPublishConfirmationThumbnailLabel =>
      'Thumbnail ng video na kaka-publish mo lang';

  @override
  String get userSearchNoResults => 'Walang nahanap na user';

  @override
  String get userPickerFilterByNameHint => 'I-filter ayon sa pangalan...';

  @override
  String get userPickerSearchByNameHint => 'Hanapin ayon sa pangalan...';

  @override
  String get userPickerClearSearchSemantics => 'I-clear ang paghahanap';

  @override
  String userPickerAlreadyAddedSemantics(String name) {
    return 'Naidagdag na si $name';
  }

  @override
  String userPickerSelectSemantics(String name) {
    return 'Piliin si $name';
  }

  @override
  String userPickerRemoveSelectionSemantics(String name) {
    return 'Alisin si $name';
  }

  @override
  String get userPickerEmptyFollowListTitle => 'Naghihintay sa iyo ang crew mo';

  @override
  String get userPickerEmptyFollowListBody =>
      'Mag-follow ng mga taong vibe mo. Kapag nag-follow back sila, puwede kayong mag-collab.';

  @override
  String get userPickerGoBack => 'Bumalik';

  @override
  String get userPickerTypeNameToSearch => 'Mag-type ng pangalan para maghanap';

  @override
  String get userPickerUnavailable =>
      'Hindi available ang user search. Subukan ulit mamaya.';

  @override
  String get userPickerSearchFailedTryAgain => 'Hindi nahanap. Subukan ulit.';

  @override
  String get forgotPasswordTitle => 'I-reset ang Password';

  @override
  String get forgotPasswordDescription =>
      'Ilagay ang iyong email address at magpapadala kami ng link para i-reset ang password mo.';

  @override
  String get forgotPasswordEmailLabel => 'Email Address';

  @override
  String get forgotPasswordCancel => 'Kanselahin';

  @override
  String get forgotPasswordSendLink => 'I-email ang Reset Link';

  @override
  String get ageVerificationContentWarning => 'Babala sa Content';

  @override
  String get ageVerificationTitle => 'Pagpapatunay ng Edad';

  @override
  String get ageVerificationAdultDescription =>
      'Na-flag ang content na ito bilang posibleng may adult material. Kailangan kang 18 taong gulang o mas matanda para mapanood ito.';

  @override
  String get ageVerificationCreationDescription =>
      'Para gamitin ang camera at gumawa ng content, kailangan kang 16 taong gulang o mas matanda.';

  @override
  String get ageVerificationAdultQuestion =>
      '18 taong gulang ka na ba o mas matanda?';

  @override
  String get ageVerificationCreationQuestion =>
      '16 taong gulang ka na ba o mas matanda?';

  @override
  String get ageVerificationNo => 'Hindi';

  @override
  String get ageVerificationYes => 'Oo';

  @override
  String get navHome => 'Home';

  @override
  String get navExplore => 'Tuklasin';

  @override
  String get navInbox => 'Inbox';

  @override
  String get navProfile => 'Profile';

  @override
  String get navMyProfile => 'Profile Ko';

  @override
  String get navNotifications => 'Mga notification';

  @override
  String get navOpenCamera => 'Buksan ang camera';

  @override
  String get navExploreClassics => 'Classics';

  @override
  String get navExploreNewVideos => 'Bagong Video';

  @override
  String get navExploreTrending => 'Trending';

  @override
  String get navExploreForYou => 'Para Sa Iyo';

  @override
  String get navExploreLists => 'Mga Listahan';

  @override
  String get routeErrorTitle => 'Error';

  @override
  String get routeInvalidHashtag => 'Invalid na hashtag';

  @override
  String get routeInvalidConversationId => 'Invalid na conversation ID';

  @override
  String get routeInvalidRequestId => 'Invalid na request ID';

  @override
  String get routeInvalidListId => 'Invalid na list ID';

  @override
  String get routeInvalidUserId => 'Invalid na user ID';

  @override
  String get routeInvalidVideoId => 'Invalid na video ID';

  @override
  String get routeInvalidSoundId => 'Invalid na sound ID';

  @override
  String get routeInvalidCategory => 'Invalid na category';

  @override
  String get routeNoVideosToDisplay => 'Walang video na maipapakita';

  @override
  String get routeGoHome => 'Pumunta sa home';

  @override
  String get routeInvalidProfileId => 'Invalid na profile ID';

  @override
  String get routeUnknownPath => 'Wala ang page na iyon sa app.';

  @override
  String get routeDefaultListName => 'Listahan';

  @override
  String get supportTitle => 'Support Center';

  @override
  String get supportContactSupport => 'Makipag-ugnayan sa Support';

  @override
  String get supportContactSupportSubtitle =>
      'Magsimula ng usapan o tingnan ang mga lumang mensahe';

  @override
  String get supportReportBug => 'Mag-report ng Bug';

  @override
  String get supportReportBugSubtitle => 'Mga technical issue sa app';

  @override
  String get supportRequestFeature => 'Humiling ng Feature';

  @override
  String get supportRequestFeatureSubtitle =>
      'Magmungkahi ng improvement o bagong feature';

  @override
  String get supportSaveLogs => 'I-save ang Logs';

  @override
  String get supportSaveLogsSubtitle =>
      'I-export ang logs sa file para manual na maipadala';

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
  String get supportFaqSubtitle => 'Mga karaniwang tanong at sagot';

  @override
  String get supportFamily => 'Divine Family';

  @override
  String get supportFamilySubtitle =>
      'Tumutulong sa mga magulang at teenager na bumuo ng malusog na gawi online';

  @override
  String get supportKids => 'Divine Kids';

  @override
  String get supportKidsSubtitle =>
      'Kung paano namin pinangangasiwaan ang mga account ayon sa edad';

  @override
  String get supportProofMode => 'ProofMode';

  @override
  String get supportProofModeSubtitle =>
      'Alamin ang tungkol sa verification at authenticity';

  @override
  String get supportLoginRequired =>
      'Mag-log in para makipag-ugnayan sa support';

  @override
  String get supportExportingLogs => 'Nag-e-export ng logs...';

  @override
  String get supportExportLogsFailed => 'Hindi na-export ang logs';

  @override
  String get supportNoLogsToExport =>
      'No logs yet — they start fresh each launch. Reproduce the problem, then come back without restarting.';

  @override
  String get supportExportLogsUnconfirmed =>
      'Logs handed off. Check the app you shared to.';

  @override
  String supportLogsSavedTo(String path) {
    return 'Na-save ang logs sa $path';
  }

  @override
  String get supportRevealLogsAction => 'Ipakita sa folder';

  @override
  String get supportChatNotAvailable => 'Hindi available ang support chat';

  @override
  String get supportCouldNotOpenMessages =>
      'Hindi nabuksan ang support messages';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return 'Hindi nabuksan ang $pageName';
  }

  @override
  String get reportWhyReporting => 'Bakit mo rine-report ang content na ito?';

  @override
  String get reportPolicyNotice =>
      'Aaksyunan ng Divine ang mga content report sa loob ng 24 oras sa pamamagitan ng pag-alis ng content at pag-eject sa user na nagbigay ng masamang content.';

  @override
  String get reportBlockUser => 'I-block ang user na ito';

  @override
  String get reportCancel => 'Kanselahin';

  @override
  String get reportSubmit => 'I-report';

  @override
  String get reportSelectReason =>
      'Pumili ng dahilan para i-report ang content na ito';

  @override
  String get reportOtherRequiresDetails =>
      'Pakilarawan ang problema kapag pinili mo ang Iba pa';

  @override
  String get reportDetailsRequired => 'Pakilarawan ang problema';

  @override
  String get reportDetailsTextOnly =>
      'Text lang — hindi puwedeng mag-attach ng mga litrato o GIF dito.';

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
  String get reportReasonSpam => 'Spam o Hindi Gustong Content';

  @override
  String get reportReasonSpamSubtitle =>
      'Hindi gustong o paulit-ulit na content';

  @override
  String get reportReasonHarassment => 'Harassment, Bullying, o Pagbabanta';

  @override
  String get reportReasonHarassmentSubtitle =>
      'Nakakapinsala at hindi gustong reply o mention';

  @override
  String get reportReasonViolence => 'Marahas o Extremist na Content';

  @override
  String get reportReasonViolenceSubtitle =>
      'Marahas, extremist, o nakakapinsalang content';

  @override
  String get reportReasonSexualContent => 'Sekswal o Adult na Content';

  @override
  String get reportReasonSexualContentSubtitle =>
      'Hubad, porn, o explicit na content';

  @override
  String get reportReasonCopyright => 'Paglabag sa Copyright';

  @override
  String get reportReasonCopyrightSubtitle =>
      'Hindi awtorisadong paggamit ng intellectual property';

  @override
  String get reportReasonFalseInfo => 'Maling Impormasyon';

  @override
  String get reportReasonFalseInfoSubtitle => 'Mapanlinlang o maling claim';

  @override
  String get reportReasonChildSafety => 'Paglabag sa Kaligtasan ng Bata';

  @override
  String get reportReasonChildSafetySubtitle =>
      'Pangkalahatang alalahanin tungkol sa kaligtasan ng mga menor de edad';

  @override
  String get reportReasonCsam => 'Sekswal na Pang-aabuso sa Bata';

  @override
  String get reportReasonCsamSubtitle =>
      'Content na naglalarawan ng sekswal na pang-aabuso sa mga menor de edad';

  @override
  String get reportReasonUnderageUser => 'Mukhang Wala Pang 16 ang User';

  @override
  String get reportReasonUnderageUserSubtitle =>
      'Mukhang menor de edad ang may-ari ng account';

  @override
  String get reportReasonAiGenerated => 'AI-Generated na Content';

  @override
  String get reportReasonAiGeneratedSubtitle =>
      'Pinaghihinalaang AI-generated content';

  @override
  String get reportReasonOther => 'Iba pang Paglabag sa Patakaran';

  @override
  String get reportReasonOtherSubtitle =>
      'Mga paglabag na hindi nakalista sa itaas';

  @override
  String get reportFailed => 'Hindi na-report ang content. Subukan ulit.';

  @override
  String get reportNotSent =>
      'Hindi naipadala ang report mo. Tingnan ang koneksyon mo at subukan ulit.';

  @override
  String get reportReceivedTitle => 'Natanggap ang Report';

  @override
  String get reportReceivedThankYou =>
      'Salamat sa pagtulong panatilihing ligtas ang Divine.';

  @override
  String get reportReceivedReviewNotice =>
      'Susuriin ng team namin ang report mo at gagawa ng naaangkop na aksyon. Maaari kang makatanggap ng updates via direct message.';

  @override
  String get reportModerationDmDelayed =>
      'Hindi namin naabot nang direkta ang moderation team ngayon, pero natanggap ang iyong report at ire-review ito.';

  @override
  String get reportContactModeration => 'I-message ang moderation team';

  @override
  String get reportLearnMoreAt => 'Alamin pa sa';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => 'Isara';

  @override
  String get listAddToList => 'Idagdag sa Listahan';

  @override
  String listVideoCount(int count) {
    return '$count mga video';
  }

  @override
  String listPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tao',
      one: '$count tao',
    );
    return '$_temp0';
  }

  @override
  String get listByAuthorPrefix => 'Ni ';

  @override
  String get listNewList => 'Bagong Listahan';

  @override
  String get listDone => 'Tapos na';

  @override
  String get listErrorLoading => 'Error sa pag-load ng listahan';

  @override
  String listRemovedFrom(String name) {
    return 'Inalis sa $name';
  }

  @override
  String listAddedTo(String name) {
    return 'Naidagdag sa $name';
  }

  @override
  String get listCreateNewList => 'Gumawa ng Bagong Listahan';

  @override
  String get listNewPeopleList => 'Bagong people list';

  @override
  String get listCollaboratorsNone => 'Wala';

  @override
  String get listAddCollaboratorTitle => 'Magdagdag ng collaborator';

  @override
  String get listCollaboratorSearchHint => 'Maghanap sa Divine...';

  @override
  String get listNameLabel => 'Pangalan ng Listahan';

  @override
  String get listDescriptionLabel => 'Description (opsyonal)';

  @override
  String get listPublicList => 'Public na Listahan';

  @override
  String get listPublicListSubtitle =>
      'Puwedeng i-follow at makita ng iba ang listahang ito';

  @override
  String get listPrivateListSubtitle =>
      'Mananatiling pribado ang mga video. Nakikita pa rin ang pangalan, description, tags, at cover.';

  @override
  String get listVisibilityPublic => 'Pampubliko';

  @override
  String get listVisibilityPrivate => 'Pribado';

  @override
  String get profileListsEmpty =>
      'Wala pang list. Gumawa ng isa para sa mga loop na gusto mong pagsama-samahin.';

  @override
  String get listEditTitle => 'I-edit ang list';

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
  String get listShareAction => 'I-share ang list';

  @override
  String get listShareFailed => 'Hindi na-share ang list na ito. Subukan ulit.';

  @override
  String get listSave => 'I-save';

  @override
  String get listContinue => 'Magpatuloy';

  @override
  String get listPrivateFull =>
      'This private list is full. Remove something to add more.';

  @override
  String get listUpdateFailed =>
      'Hindi na-update ang list na ito. Subukan ulit.';

  @override
  String get listMakePrivateTitle => 'Gawing private ang list na ito?';

  @override
  String get listMakePrivateWarning =>
      'Ie-encrypt ang mga video kaya ikaw lang ang makakakita. Nakikita pa rin ang pangalan, description, tags, at cover, at puwedeng manatili ang mga kopyang naipamahagi na.';

  @override
  String get listMakePublicTitle => 'Gawing public ang list na ito?';

  @override
  String get listMakePublicWarning =>
      'Makikita ng kahit sino na may link ang list na ito at ang mga video nito.';

  @override
  String listShareText(String name, String url) {
    return 'Tingnan mo $name sa Divine: $url';
  }

  @override
  String listShareSubject(String name) {
    return '$name sa Divine';
  }

  @override
  String get listCancel => 'Kanselahin';

  @override
  String get listCreate => 'Gumawa';

  @override
  String get listCreateFailed => 'Hindi nagawa ang listahan';

  @override
  String get keyManagementTitle => 'Mga Nostr key';

  @override
  String get keyManagementWhatAreKeys => 'Ano ang Nostr keys?';

  @override
  String get keyManagementExplanation =>
      'Ang iyong Nostr identity ay isang cryptographic key pair:\n\n• Ang public key mo (npub) ay parang username mo - puwede mong i-share nang malaya\n• Ang private key mo (nsec) ay parang password mo - itago mo ito!\n\nAng nsec mo ang magbibigay sa iyo ng access sa account mo sa anumang Nostr app.';

  @override
  String get keyManagementImportTitle => 'Mag-import ng Existing na Key';

  @override
  String get keyManagementImportSubtitle =>
      'May Nostr account ka na? I-paste ang private key mo (nsec) para ma-access dito.';

  @override
  String get keyManagementImportButton => 'Mag-import ng Key';

  @override
  String get keyManagementImportWarning => 'Papalitan nito ang current key mo!';

  @override
  String get keyManagementBackupTitle => 'I-backup ang Key Mo';

  @override
  String get keyManagementBackupSubtitle =>
      'I-save ang private key mo (nsec) para magamit ang account mo sa ibang Nostr apps.';

  @override
  String get keyManagementCopyNsec => 'Kopyahin ang Private Key Ko (nsec)';

  @override
  String get keyManagementNeverShare =>
      'Huwag i-share ang nsec mo sa kahit kanino!';

  @override
  String get keyManagementKeycastRemoteSigning =>
      'Nasa login service ng Divine ang key mo, hindi sa device na ito. Kumpirmahin ang password mo at kukunin namin ito.';

  @override
  String get keyManagementKeycastPasswordPrompt =>
      'Nasa login service ng Divine nakatago ang key mo. Ilagay ang password ng account mo at kukunin namin ito.';

  @override
  String get keyManagementKeycastCopyKey => 'Kopyahin ang key';

  @override
  String get keyManagementKeycastCopyBlocked =>
      'Hinarangan ng device mo ang pagkopya, kaya hindi nakarating sa clipboard ang key mo.';

  @override
  String get keyManagementKeycastWrongPassword =>
      'Hindi tugma ang password. Subukan muli.';

  @override
  String get keyManagementKeycastTooManyAttempts =>
      'Sobrang dami nang subok. Isara ito at magsimula ulit.';

  @override
  String get keyManagementKeycastRateLimited =>
      'Sobrang dami nang hiling para sa key. Maghintay ng ilang minuto at subukan muli.';

  @override
  String get keyManagementKeycastSignInAgain =>
      'Nag-expire na ang session mo. Mag-sign in muli para makopya ang key mo.';

  @override
  String get keyManagementKeycastEmailUnverified =>
      'I-verify ang email address mo bago kopyahin ang key.';

  @override
  String get keyManagementKeycastDenied =>
      'Ang Divine ang nangangalaga sa mga key ng account na ito, kaya hindi ito makokopya dito.';

  @override
  String get keyManagementKeycastNoKey =>
      'Walang key na nakatala para sa account na ito.';

  @override
  String get keyManagementKeycastGenericFailure =>
      'Hindi maabot ang login service. Subukan ulit.';

  @override
  String get keyManagementRestrictedTitle =>
      'Pinamamahalaan ng Divine ang mga key mo';

  @override
  String get keyManagementRestrictedBody =>
      'Para manatiling ligtas ang account mo, hindi available dito ang key backup at pag-import ng ibang key.';

  @override
  String get keyManagementPasteKey => 'Pakipasta ang private key mo';

  @override
  String get keyManagementInvalidFormat =>
      'Invalid na format ng key. Kailangang mag-umpisa sa \"nsec1\"';

  @override
  String get keyManagementConfirmImportTitle => 'I-import ang Key na Ito?';

  @override
  String get keyManagementConfirmImportBody =>
      'Papalitan nito ang kasalukuyang identity mo ng na-import.\n\nMawawala ang current key mo maliban kung na-backup mo na muna.';

  @override
  String get keyManagementImportConfirm => 'I-import';

  @override
  String get keyManagementImportSuccess => 'Matagumpay na na-import ang key!';

  @override
  String get keyManagementImportFailed =>
      'Hindi na-import ang key. Subukan ulit.';

  @override
  String get keyManagementExportSuccess =>
      'Nakopya ang private key sa clipboard!\n\nItago ito sa ligtas na lugar.';

  @override
  String get keyManagementExportFailed =>
      'Hindi na-export ang key. Subukan ulit.';

  @override
  String get keyManagementYourPublicKeyLabel => 'Ang public key mo (npub)';

  @override
  String get keyManagementCopyPublicKeyTooltip => 'Kopyahin ang public key';

  @override
  String get keyManagementPublicKeyCopied => 'Nakopya ang public key';

  @override
  String get saveOriginalSavedToCameraRoll => 'Na-save sa Camera Roll';

  @override
  String get saveOriginalShare => 'I-share';

  @override
  String get saveOriginalDone => 'Tapos na';

  @override
  String get saveOriginalPhotosAccessNeeded => 'Kailangan ng Access sa Photos';

  @override
  String get saveOriginalPhotosAccessMessage =>
      'Para mag-save ng video, payagan ang access sa Photos sa Settings.';

  @override
  String get saveOriginalOpenSettings => 'Buksan ang Settings';

  @override
  String get saveOriginalNotNow => 'Hindi muna';

  @override
  String get saveOriginalDownloadFailed => 'Hindi Nag-download';

  @override
  String get saveOriginalDismiss => 'Isantabi';

  @override
  String get saveOriginalDownloadingVideo => 'Nagda-download ng Video';

  @override
  String get saveOriginalSavingToCameraRoll => 'Sini-save sa Camera Roll';

  @override
  String get saveOriginalFetchingVideo =>
      'Kinukuha ang video mula sa network...';

  @override
  String get saveOriginalSavingVideo =>
      'Sini-save ang original na video sa camera roll mo...';

  @override
  String get soundTitle => 'Sound';

  @override
  String get soundOriginalSound => 'Original na sound';

  @override
  String get soundVideosUsingThisSound =>
      'Mga video na gumagamit ng sound na ito';

  @override
  String get soundSourceVideo => 'Pinagmulang video';

  @override
  String get soundNoVideosYet => 'Wala pang video';

  @override
  String get soundBeFirstToUse => 'Maging unang gumamit ng sound na ito!';

  @override
  String get soundFailedToLoadVideos => 'Hindi na-load ang mga video';

  @override
  String get soundRetry => 'Subukan ulit';

  @override
  String get soundVideosUnavailable => 'Hindi available ang mga video';

  @override
  String get soundCouldNotLoadDetails => 'Hindi na-load ang detalye ng video';

  @override
  String get soundPreview => 'Preview';

  @override
  String get soundStop => 'Itigil';

  @override
  String get soundUseSound => 'Gamitin ang Sound';

  @override
  String get soundUntitled => 'Sound na walang pamagat';

  @override
  String get soundStopPreview => 'Itigil ang preview';

  @override
  String soundPreviewSemanticLabel(String title) {
    return 'I-preview ang $title';
  }

  @override
  String soundViewDetailsSemanticLabel(String title) {
    return 'Tingnan ang details para sa $title';
  }

  @override
  String get soundNoVideoCount => 'Wala pang video';

  @override
  String get soundOneVideo => '1 video';

  @override
  String soundVideoCount(int count) {
    return '$count mga video';
  }

  @override
  String get soundUnableToPreview =>
      'Hindi ma-preview ang sound - walang available na audio';

  @override
  String get soundPreviewFailed => 'Hindi na-play ang preview. Subukan ulit.';

  @override
  String get soundViewSource => 'Tingnan ang source';

  @override
  String get soundCloseTooltip => 'Isara';

  @override
  String get exploreNotExploreRoute => 'Hindi explore route';

  @override
  String get legalTitle => 'Legal';

  @override
  String get legalTermsOfService => 'Mga Tuntunin ng Serbisyo';

  @override
  String get legalTermsOfServiceSubtitle =>
      'Mga terms at kondisyon ng paggamit';

  @override
  String get legalPrivacyPolicy => 'Patakaran sa Privacy';

  @override
  String get legalPrivacyPolicySubtitle => 'Paano namin ina-handle ang data mo';

  @override
  String get legalSafetyStandards => 'Mga Pamantayan sa Kaligtasan';

  @override
  String get legalSafetyStandardsSubtitle =>
      'Mga community guidelines at kaligtasan';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle => 'Patakaran sa copyright at takedown';

  @override
  String get legalOpenSourceLicenses => 'Mga open source license';

  @override
  String get legalOpenSourceLicensesSubtitle =>
      'Mga attribution sa third-party packages';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return 'Hindi nabuksan ang $pageName';
  }

  @override
  String get categoryAction => 'Action';

  @override
  String get categoryAdventure => 'Adventure';

  @override
  String get categoryAnimals => 'Mga Hayop';

  @override
  String get categoryAnimation => 'Animation';

  @override
  String get categoryArchitecture => 'Arkitektura';

  @override
  String get categoryArt => 'Sining';

  @override
  String get categoryAutomotive => 'Automotive';

  @override
  String get categoryAwardShow => 'Award Show';

  @override
  String get categoryAwards => 'Mga Award';

  @override
  String get categoryBaseball => 'Baseball';

  @override
  String get categoryBasketball => 'Basketball';

  @override
  String get categoryBeauty => 'Beauty';

  @override
  String get categoryBeverage => 'Inumin';

  @override
  String get categoryCars => 'Mga Sasakyan';

  @override
  String get categoryCelebration => 'Pagdiriwang';

  @override
  String get categoryCelebrities => 'Mga Celebrity';

  @override
  String get categoryCelebrity => 'Celebrity';

  @override
  String get categoryCityscape => 'Cityscape';

  @override
  String get categoryComedy => 'Comedy';

  @override
  String get categoryConcert => 'Konsiyerto';

  @override
  String get categoryCooking => 'Pagluluto';

  @override
  String get categoryCostume => 'Kostyum';

  @override
  String get categoryCrafts => 'Crafts';

  @override
  String get categoryCrime => 'Krimen';

  @override
  String get categoryCulture => 'Kultura';

  @override
  String get categoryDance => 'Sayaw';

  @override
  String get categoryDiy => 'DIY';

  @override
  String get categoryDrama => 'Drama';

  @override
  String get categoryEducation => 'Edukasyon';

  @override
  String get categoryEmotional => 'Emotional';

  @override
  String get categoryEmotions => 'Mga Damdamin';

  @override
  String get categoryEntertainment => 'Entertainment';

  @override
  String get categoryEvent => 'Event';

  @override
  String get categoryFamily => 'Pamilya';

  @override
  String get categoryFans => 'Mga Fan';

  @override
  String get categoryFantasy => 'Fantasy';

  @override
  String get categoryFashion => 'Estilo';

  @override
  String get categoryFestival => 'Pista';

  @override
  String get categoryFilm => 'Pelikula';

  @override
  String get categoryFitness => 'Fitness';

  @override
  String get categoryFood => 'Pagkain';

  @override
  String get categoryFootball => 'Football';

  @override
  String get categoryFurniture => 'Muwebles';

  @override
  String get categoryGaming => 'Gaming';

  @override
  String get categoryGolf => 'Golf';

  @override
  String get categoryGrooming => 'Grooming';

  @override
  String get categoryGuitar => 'Gitara';

  @override
  String get categoryHalloween => 'Halloween';

  @override
  String get categoryHealth => 'Kalusugan';

  @override
  String get categoryHockey => 'Hockey';

  @override
  String get categoryHoliday => 'Holiday';

  @override
  String get categoryHome => 'Bahay';

  @override
  String get categoryHomeImprovement => 'Home Improvement';

  @override
  String get categoryHorror => 'Horror';

  @override
  String get categoryHospital => 'Ospital';

  @override
  String get categoryHumor => 'Humor';

  @override
  String get categoryInteriorDesign => 'Interior Design';

  @override
  String get categoryInterview => 'Interview';

  @override
  String get categoryKids => 'Mga Bata';

  @override
  String get categoryLifestyle => 'Lifestyle';

  @override
  String get categoryMagic => 'Magic';

  @override
  String get categoryMakeup => 'Makeup';

  @override
  String get categoryMedical => 'Medikal';

  @override
  String get categoryMusic => 'Musika';

  @override
  String get categoryMystery => 'Misteryo';

  @override
  String get categoryNature => 'Kalikasan';

  @override
  String get categoryNews => 'Balita';

  @override
  String get categoryOutdoor => 'Outdoor';

  @override
  String get categoryParty => 'Party';

  @override
  String get categoryPeople => 'Mga Tao';

  @override
  String get categoryPerformance => 'Performance';

  @override
  String get categoryPets => 'Mga Alagang Hayop';

  @override
  String get categoryPolitics => 'Pulitika';

  @override
  String get categoryPrank => 'Prank';

  @override
  String get categoryPranks => 'Mga Prank';

  @override
  String get categoryRealityShow => 'Reality Show';

  @override
  String get categoryRelationship => 'Relasyon';

  @override
  String get categoryRelationships => 'Mga Relasyon';

  @override
  String get categoryRomance => 'Romansa';

  @override
  String get categorySchool => 'Eskwela';

  @override
  String get categoryScienceFiction => 'Science Fiction';

  @override
  String get categorySelfie => 'Selfie';

  @override
  String get categoryShopping => 'Shopping';

  @override
  String get categorySkateboarding => 'Skateboarding';

  @override
  String get categorySkincare => 'Skincare';

  @override
  String get categorySoccer => 'Soccer';

  @override
  String get categorySocialGathering => 'Pagtitipon';

  @override
  String get categorySocialMedia => 'Social Media';

  @override
  String get categorySports => 'Sports';

  @override
  String get categoryTalkShow => 'Talk Show';

  @override
  String get categoryTech => 'Tech';

  @override
  String get categoryTechnology => 'Teknolohiya';

  @override
  String get categoryTelevision => 'Telebisyon';

  @override
  String get categoryToys => 'Mga Laruan';

  @override
  String get categoryTransportation => 'Transportasyon';

  @override
  String get categoryTravel => 'Travel';

  @override
  String get categoryUrban => 'Urban';

  @override
  String get categoryViolence => 'Karahasan';

  @override
  String get categoryVlog => 'Vlog';

  @override
  String get categoryVlogging => 'Vlogging';

  @override
  String get categoryWrestling => 'Wrestling';

  @override
  String get profileSetupUploadStaged =>
      'Na-upload na — i-tap ang I-save para ilapat';

  @override
  String inboxReportedUser(String displayName) {
    return 'Na-report si $displayName';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return 'Na-block si $displayName';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return 'Na-unblock si $displayName';
  }

  @override
  String get inboxRemovedConversation => 'Inalis ang conversation';

  @override
  String get inboxRestorePausedTitle => 'May mga chat na hindi pa tapos ibalik';

  @override
  String get conversationRestorePausedTitle =>
      'Hindi pa tapos ibalik ang chat na ito';

  @override
  String get inboxRestoreRetryAction => 'Subukan ulit';

  @override
  String get inboxRestoringMessages => 'Ibinabalik ang mga message mo…';

  @override
  String get inboxEmptyTitle => 'Wala pang messages';

  @override
  String get inboxEmptySubtitle => 'Hindi ka kakagatin ng + button na \'yan.';

  @override
  String get inboxLoadErrorTitle => 'Hindi na-load ang mga mensahe';

  @override
  String get inboxLoadErrorSubtitle =>
      'Suriin ang koneksyon mo at subukan ulit.';

  @override
  String get inboxFilterAll => 'Lahat';

  @override
  String get inboxFilterUnread => 'Hindi pa nababasa';

  @override
  String get dmBlockedThreadTitle => 'Na-block mo ang account na ito';

  @override
  String get dmBlockedThreadBody =>
      'Nananatili rito ang mga mensahe para mabasa o ma-screenshot mo. Mag-unblock para makasagot.';

  @override
  String get inboxFilterBlocked => 'Naka-block';

  @override
  String get inboxBlockedEmptyTitle => 'Walang naka-block na chat';

  @override
  String get inboxBlockedEmptySubtitle =>
      'Lumalabas dito ang mga account na bina-block mo.';

  @override
  String get inboxBlockedNoMessages => 'Walang mensahe';

  @override
  String get inboxUnreadEmptyTitle => 'Nabasa mo na lahat';

  @override
  String get inboxUnreadEmptySubtitle => 'Walang hindi pa nababasang mensahe.';

  @override
  String get inboxSearchHint => 'Maghanap ng mga mensahe';

  @override
  String get inboxSupportRowTitle => 'Moderasyon ng Divine';

  @override
  String get inboxSupportRowSubtitle =>
      'Mga bug, moderation, usaping account — nakikinig kami.';

  @override
  String get inboxSearchEmptyTitle => 'Walang tugma';

  @override
  String get inboxSearchEmptySubtitle => 'Subukan ang ibang pangalan o salita.';

  @override
  String get inboxActionMute => 'I-mute ang conversation';

  @override
  String inboxActionReport(String displayName) {
    return 'I-report si $displayName';
  }

  @override
  String inboxActionBlock(String displayName) {
    return 'I-block si $displayName';
  }

  @override
  String inboxActionUnblock(String displayName) {
    return 'I-unblock si $displayName';
  }

  @override
  String get inboxActionRemove => 'Alisin ang conversation';

  @override
  String get inboxRemoveConfirmTitle => 'Alisin ang conversation?';

  @override
  String inboxRemoveConfirmBody(String displayName) {
    return 'Aalisin nito sa iyong inbox ang usapan mo kay $displayName. Kung magme-message ulit siya, magsisimula ng bagong usapan.';
  }

  @override
  String get inboxRemoveConfirmBodyGroup =>
      'Aalisin nito sa iyong inbox ang group chat. Kung may magme-message ulit sa group, magsisimula ng bagong usapan.';

  @override
  String get inboxRemoveConfirmConfirm => 'Alisin';

  @override
  String get inboxConversationMuted => 'Na-mute ang conversation';

  @override
  String get inboxConversationUnmuted => 'Na-unmute ang conversation';

  @override
  String get inboxCollabInviteCardTitle => 'Imbitasyon bilang collaborator';

  @override
  String get inboxCollabInviteCardUntitledVideo => 'Video na walang pamagat';

  @override
  String get clickableTextViewVideoLink => 'Tingnan ang video';

  @override
  String get messageExternalLinkDialogTitle => 'Buksan ang external na link?';

  @override
  String messageExternalLinkDialogBody(String url) {
    return 'Papunta ang link na ito sa isang external na site at baka hindi ito ligtas:\n\n$url';
  }

  @override
  String get messageExternalLinkDialogOpen => 'Buksan';

  @override
  String get inboxCollabInviteCoPostButton => 'Co-post';

  @override
  String get inboxCollabInviteNotMineButton => 'Hindi akin';

  @override
  String get inboxCollabInvitePreviewTitle => 'Imbitasyon sa co-post';

  @override
  String inboxCollabInvitePreviewTitleFrom(String displayName) {
    return 'Imbitasyon sa co-post mula kay $displayName';
  }

  @override
  String get inboxCollabInviteTimelineConsequence =>
      'Idaragdag ng co-posting ang video na ito sa timeline mo bilang collaboration.';

  @override
  String get inboxCollabInviteAcceptedStatus => 'Tinanggap';

  @override
  String get inboxCollabInviteIgnoredStatus => 'Binalewala';

  @override
  String get inboxCollabInviteAcceptError => 'Hindi natanggap. Subukan ulit.';

  @override
  String get inboxCollabInviteSentStatus => 'Naipadala ang imbitasyon';

  @override
  String get inboxConversationCollabInvitePreview =>
      'Imbitasyon bilang collaborator';

  @override
  String collaboratorInviteDmBody(String title, String url) {
    return 'In-imbita ka bilang collaborator sa $title: $url\n\nOpen Divine to review and accept.';
  }

  @override
  String collaboratorInviteDmBodyUntitled(String url) {
    return 'In-imbita ka bilang collaborator sa isang video: $url\n\nOpen Divine to review and accept.';
  }

  @override
  String videoPublishCollaboratorInviteWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count collaborator invite ang hindi naipadala.',
      one: '$count collaborator invite ang hindi naipadala.',
    );
    return 'Nai-post ang video, pero $_temp0';
  }

  @override
  String get dmSendNoRecipientMessage =>
      'Hindi namin matukoy kung kanino ang thread na ito. Buksan ulit ito mula sa iyong inbox.';

  @override
  String get dmSendBlockedMessage =>
      'Opisyal na Divine accounts lang ang pwede mong ma-message';

  @override
  String get dmSendBlockedRetiredMessage =>
      'Walang nagbabasa ng usapang ito. Mag-message na lang sa Divine Moderation.';

  @override
  String get dmDeletePendingLabel => 'Deleting for everyone';

  @override
  String get dmDeleteRefusedMessage => 'Hindi na-delete para sa lahat.';

  @override
  String get dmDeleteRefusedDetails =>
      'Maaaring nakikita pa rin ng ilang tao ang mensaheng ito.';

  @override
  String get dmRetiredThreadClosedTitle => 'Sarado na ang usapang ito.';

  @override
  String get messageRequestModerationNoticeCannotBeRemoved =>
      'Hindi maaalis ang abisong ito mula sa Divine Moderation.';

  @override
  String get dmRetiredThreadClosedBody =>
      'Inilipat namin ang Divine Moderation sa bagong account. Wala nang nagbabasa nito.';

  @override
  String get dmRetiredThreadOpenSupport => 'I-message ang Divine Moderation';

  @override
  String get dmSendTooLongMessage =>
      'That message is too long to send. Shorten it and try again.';

  @override
  String get dmSendFailedMessage => 'Hindi naipadala ang message';

  @override
  String get dmResendFailedMessage => 'Hindi pa rin naipadala';

  @override
  String get dmSendFailedSubtitle =>
      'I-resend ito ngayon, o itigil ang pagsubok.';

  @override
  String get dmSendFailedRetry => 'Subukan ulit';

  @override
  String get dmSendPartialMessage =>
      'Naipadala, pero hindi nag-sync sa iba mong device';

  @override
  String get dmConversationLoadError => 'Hindi na-load ang mga message';

  @override
  String get dmMessageInputHint => 'Magsabi ng kahit ano…';

  @override
  String get dmMessageBubbleSentHint => 'Naipadalang mensahe';

  @override
  String get dmMessageBubbleReceivedHint => 'Natanggap na mensahe';

  @override
  String get dmMessageBubbleLongPressHint => 'Mga aksyon sa mensahe';

  @override
  String get dmMessageBubbleFailedTapHint =>
      'I-resend o burahin ang mensaheng ito';

  @override
  String get dmMessageActionCopyText => 'Kopyahin ang text';

  @override
  String get dmMessageActionCopyVideoUrl => 'Kopyahin ang video URL';

  @override
  String get dmMessageActionDeleteForEveryone => 'Burahin para sa lahat';

  @override
  String get dmMessageActionReport => 'I-report';

  @override
  String get dmMessageActionRetrySend => 'Ipadala muli';

  @override
  String get dmMessageActionCancelSend => 'Itigil ang pagsubok';

  @override
  String get dmReactionAddCustomA11yLabel =>
      'Magdagdag ng custom na emoji reaction';

  @override
  String dmReelReplyComposerHint(String name) {
    return 'Mag-message kay $name…';
  }

  @override
  String get dmReelReplyComposerHintSelf => 'Sagutin ang sarili mo…';

  @override
  String get dmReelReplyComposerSemanticLabel => 'Tumugon sa reel na ito';

  @override
  String get dmReelReplyViewChat => 'Tingnan ang chat';

  @override
  String get dmReelReplySentAnnouncement => 'Naipadala ang tugon';

  @override
  String dmReelReactionSentAnnouncement(String emoji) {
    return 'Nag-react ng $emoji';
  }

  @override
  String get dmReelReplyFailed => 'Hindi maipadala';

  @override
  String get dmReelReplyUnverified => 'Hindi makumpirma ang pagpapadala';

  @override
  String dmReactionChipOwnA11yLabel(String emoji) {
    return 'Reaction mo: $emoji';
  }

  @override
  String dmReactionChipOtherA11yLabel(String name, String emoji) {
    return 'Nag-react si $name ng $emoji';
  }

  @override
  String dmReactionChipPendingA11yLabel(String emoji) {
    return 'Ipinapadala ang reaction: $emoji';
  }

  @override
  String get dmReactionChipFailedA11yLabel =>
      'Nabigo ang reaction, i-double tap para subukan ulit';

  @override
  String get dmReactionChipRetryAnnouncement => 'Sinusubukan ulit ang reaction';

  @override
  String dmReactionRemovalRefusedA11yLabel(String emoji) {
    return 'Couldn\'t remove your $emoji reaction. Double tap to try again';
  }

  @override
  String get dmReactionRemovalRefusedTitle => 'Couldn\'t remove your reaction.';

  @override
  String get dmReactionAddBlockedByRemoval =>
      'Tapusin munang alisin ang dati mong reaksyon bago magdagdag ng bago.';

  @override
  String get dmReactionRemovalRefusedDetails =>
      'Some people may still be able to see this reaction.';

  @override
  String get dmReactionsSheetTitle => 'Mga reaksyon';

  @override
  String get dmReactionsViewA11yLabel => 'Tingnan kung sino ang nag-react';

  @override
  String get dmReactionRemoveAction => 'Alisin';

  @override
  String get dmReactionRetryAction => 'Subukan muli';

  @override
  String get dmFormatBold => 'Makapal';

  @override
  String get dmFormatItalic => 'Pahilis';

  @override
  String get dmFormatStrikethrough => 'May guhit';

  @override
  String get dmFormatCode => 'Code';

  @override
  String get dmStatusFailed => 'Nabigong ipadala';

  @override
  String get inboxConversationActionsSheetLabel => 'Mga aksyon sa usapan';

  @override
  String inboxConversationTileLabel(String displayName) {
    return 'Usapan kay $displayName';
  }

  @override
  String inboxConversationTileLabelUnread(String displayName) {
    return 'Hindi pa nababasa, Usapan kay $displayName';
  }

  @override
  String inboxGroupConversationTitle(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pa',
    );
    return '$name at $_temp0';
  }

  @override
  String get inboxConversationTileLongPressHint =>
      'Ipakita ang mga aksyon sa usapan';

  @override
  String exploreVideoId(String id) {
    return 'ID: $id';
  }

  @override
  String exploreVideoTitle(String title) {
    return 'Pamagat: $title';
  }

  @override
  String exploreVideoCounter(int current, int total) {
    return 'Video $current/$total';
  }

  @override
  String get exploreSearchHint => 'Maghanap...';

  @override
  String categoryVideoCount(int countValue, String count) {
    return '$count na video';
  }

  @override
  String get discoverListsFailedToUpdateSubscription =>
      'Hindi na-update ang subscription. Subukan ulit.';

  @override
  String get discoverListsTitle => 'Tuklasin ang mga Listahan';

  @override
  String get discoverListsFailedToLoad => 'Hindi na-load ang mga listahan';

  @override
  String get discoverListsLoading => 'Naghahanap ng mga public list...';

  @override
  String get discoverListsRelayTimeout =>
      'Hindi nagbalik ng mga list ang relay sa oras. Subukan ulit.';

  @override
  String get discoverListsServiceUnavailable => 'Hindi available ang serbisyo.';

  @override
  String get discoverListsEmptyTitle => 'Walang nakitang public list';

  @override
  String get discoverListsEmptySubtitle =>
      'Bumalik mamaya para sa mga bagong listahan';

  @override
  String get discoverListsByAuthorPrefix => 'ni';

  @override
  String get curatedListEmptyTitle => 'Walang video sa listahang ito';

  @override
  String get curatedListEmptySubtitle =>
      'Magdagdag ng mga video para magsimula';

  @override
  String get curatedListLoadingVideos => 'Naglo-load ng mga video...';

  @override
  String get curatedListFailedToLoad => 'Hindi na-load ang listahan';

  @override
  String get curatedListVideoNotAvailable => 'Hindi available ang video';

  @override
  String get curatedListActionsTooltip => 'Mga aksyon sa list';

  @override
  String get curatedListDeleteConfirmTitle => 'Burahin ang list?';

  @override
  String get curatedListDeleteConfirmBody =>
      'Aalisin nito ang list sa mga relay. Hindi mabubura ang mga video sa list.';

  @override
  String get curatedListDeletedSnack => 'Binura ang list';

  @override
  String get curatedListDeleteFailed => 'Hindi nabura ang list';

  @override
  String get peopleListsActionsTooltip => 'Mga aksyon sa list';

  @override
  String get listDeleteAction => 'Burahin ang list';

  @override
  String get peopleListsDeleteConfirmTitle => 'Burahin ang list?';

  @override
  String get peopleListsDeleteConfirmBody =>
      'Aalisin nito ang list para sa lahat. Hindi maa-unfollow ang mga taong nasa loob nito.';

  @override
  String get peopleListsDeleteFailed => 'Hindi nabura ang list';

  @override
  String get commonRetry => 'Subukan ulit';

  @override
  String get commonSomethingWentWrong => 'May nangyaring problema';

  @override
  String get commonDelete => 'Burahin';

  @override
  String get commonCancel => 'Kanselahin';

  @override
  String get commonBack => 'Bumalik';

  @override
  String get commonClose => 'Isara';

  @override
  String get commonNotNow => 'Hindi muna';

  @override
  String get commonLoading => 'Naglo-load';

  @override
  String get videoMetadataEditCoverFailedSnackbar =>
      'Hindi na-update ang cover. Subukan ulit.';

  @override
  String get videoMetadataEditCoverSuccessAnnouncement => 'Na-update ang cover';

  @override
  String get videoMetadataC2paMissingTitle =>
      'I-post nang walang human-made check?';

  @override
  String get videoMetadataC2paMissingBody =>
      'Hindi kami nakapaglagay ng content credentials, kaya hindi makukumpirma na gawa ng tao ang video na ito. I-regenerate para subukan ulit, o i-post na lang ito.';

  @override
  String get videoMetadataC2paMissingNote =>
      'Kailangan ng internet connection ang content credentials.';

  @override
  String get videoMetadataC2paMissingNoteServiceUnavailable =>
      'Hindi sumagot ang content credential service. Hindi ito problema ng koneksyon mo.';

  @override
  String get videoMetadataC2paMissingRegenerate => 'I-regenerate';

  @override
  String get videoMetadataC2paMissingSkip => 'Laktawan';

  @override
  String get videoMetadataGenerationFailed => 'Nabigo ang paggawa';

  @override
  String get videoMetadataTags => 'Mga Tag';

  @override
  String get videoMetadataExpiration => 'Pag-expire';

  @override
  String get videoMetadataExpirationNotExpire => 'Hindi mag-e-expire';

  @override
  String get videoMetadataExpirationOneDay => '1 araw';

  @override
  String get videoMetadataExpirationOneWeek => '1 linggo';

  @override
  String get videoMetadataExpirationOneMonth => '1 buwan';

  @override
  String get videoMetadataExpirationOneYear => '1 taon';

  @override
  String get videoMetadataExpirationOneDecade => '1 dekada';

  @override
  String get videoMetadataContentWarnings => 'Mga Babala sa Content';

  @override
  String get videoEditorStickers => 'Mga Sticker';

  @override
  String get trendingTitle => 'Trending';

  @override
  String get libraryDeleteConfirm => 'Burahin';

  @override
  String get libraryWebUnavailableHeadline =>
      'Available ang Library sa mobile app';

  @override
  String get libraryWebUnavailableDescription =>
      'Naka-save sa device mo ang mga draft at clip, kaya buksan ang Divine sa phone mo para i-manage ang mga ito.';

  @override
  String get libraryTabDrafts => 'Mga Draft';

  @override
  String get libraryTabClips => 'Mga Clip';

  @override
  String get libraryDeleteSelectedClipsTooltip =>
      'Burahin ang mga napiling clip';

  @override
  String get libraryCloseSemanticLabel => 'Isara ang library';

  @override
  String get libraryStopSelectingClipsSemanticLabel =>
      'Ihinto ang pagpili ng mga clip';

  @override
  String get librarySelectClipsSemanticLabel => 'Pumili ng mga clip';

  @override
  String get libraryGridSizeLabel => 'Laki ng grid';

  @override
  String get libraryDisplayOptionsLabel => 'Pagkakasunod-sunod at laki ng grid';

  @override
  String get libraryMoreActionsSemanticLabel => 'Higit pang aksyon sa library';

  @override
  String libraryGridSizeColumns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count na hanay',
      one: '$count hanay',
    );
    return '$_temp0';
  }

  @override
  String get librarySelect => 'Piliin';

  @override
  String get librarySortNewestCreation => 'Pinakabagong ginawa';

  @override
  String get librarySortOldestCreation => 'Pinakalumang ginawa';

  @override
  String get librarySortLongestClip => 'Pinakamahabang clip';

  @override
  String get librarySortShortestClip => 'Pinakamaikling clip';

  @override
  String get librarySortSquareFirst => 'Unahin ang parisukat';

  @override
  String get librarySortVerticalFirst => 'Unahin ang patayo';

  @override
  String get libraryDeleteClipsWarning =>
      'Hindi na ito mababawi. Permanenteng maaalis sa device mo ang mga video file.';

  @override
  String get libraryPreparingVideo => 'Hinahanda ang video...';

  @override
  String libraryCreateVideo(int count) {
    return 'Gumawa ng Video ($count)';
  }

  @override
  String libraryClipsSavedToDestination(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clip',
      one: '$count clip',
    );
    return '$_temp0 na-save sa $destination';
  }

  @override
  String libraryClipsSavePartialResult(int successCount, int failureCount) {
    return '$successCount na-save, $failureCount ang nabigo';
  }

  @override
  String libraryClipsSaveFailed(String destination) {
    return 'Hindi na-save sa $destination';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return 'Tinanggihan ang permission para sa $destination';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clip ang nabura',
      one: '$count clip ang nabura',
    );
    return '$_temp0';
  }

  @override
  String get libraryClipsDeletedUndoLabel => 'Bawiin';

  @override
  String libraryTrashAutoDeletes(int daysLeft) {
    String _temp0 = intl.Intl.pluralLogic(
      daysLeft,
      locale: localeName,
      other: 'Awtomatikong made-delete sa loob ng $daysLeft araw',
      one: 'Awtomatikong made-delete bukas',
      zero: 'Awtomatikong made-delete ngayon',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts => 'Hindi na-load ang mga draft';

  @override
  String get libraryCouldNotLoadClips => 'Hindi na-load ang mga clip';

  @override
  String get libraryOpenErrorDescription =>
      'May nangyaring problema habang binubuksan ang library mo. Pwede mong subukan ulit.';

  @override
  String get libraryNoDraftsYetTitle => 'Wala Pang Draft';

  @override
  String get libraryNoDraftsYetSubtitle =>
      'Lalabas dito ang mga video na ise-save mo bilang draft';

  @override
  String get libraryNoClipsYetTitle => 'Wala Pang Clip';

  @override
  String get libraryNoClipsYetSubtitle =>
      'Lalabas dito ang mga na-record mong video clip';

  @override
  String get libraryDraftDeletedSnackbar => 'Nabura ang draft';

  @override
  String get libraryDraftDeleteFailedSnackbar => 'Hindi nabura ang draft';

  @override
  String get libraryDraftDuplicatedSnackbar => 'Na-duplicate ang draft';

  @override
  String get libraryDraftDuplicateFailedSnackbar =>
      'Hindi na-duplicate ang draft';

  @override
  String get libraryDraftInProgressBadge => 'Ginagawa pa';

  @override
  String get libraryDraftActionPost => 'I-post';

  @override
  String get libraryDraftActionEdit => 'I-edit';

  @override
  String get libraryDraftActionDuplicate => 'I-duplicate';

  @override
  String get libraryDraftActionDelete => 'Burahin ang draft';

  @override
  String libraryDraftCopyTitle(String title, int number) {
    return '$title (kopya $number)';
  }

  @override
  String get libraryDeleteDraftTitle => 'Burahin ang Draft';

  @override
  String libraryDeleteDraftMessage(String title) {
    return 'Sigurado ka bang gusto mong burahin ang \"$title\"?';
  }

  @override
  String get libraryDeleteClipTitle => 'Burahin ang Clip';

  @override
  String get libraryDeleteClipMessage =>
      'Sigurado ka bang gusto mong burahin ang clip na ito?';

  @override
  String libraryClipDuration(String seconds) {
    return '${seconds}s';
  }

  @override
  String get libraryRecordVideo => 'Mag-record ng Video';

  @override
  String videoClipSemanticLabel(String duration) {
    return 'Video clip, $duration segundo';
  }

  @override
  String videoClipArchivedSemanticLabel(String label) {
    return 'Naka-archive. $label';
  }

  @override
  String videoClipStopMotionSemanticLabel(String frames) {
    return 'Stop-motion clip, $frames';
  }

  @override
  String videoClipSemanticValueSelectedAtPosition(int position) {
    return 'Napili, numero $position';
  }

  @override
  String get videoClipSemanticValueSelected => 'Napili';

  @override
  String get videoClipSemanticValueNotSelected => 'Hindi napili';

  @override
  String get videoClipSemanticHintDisabled => 'Hindi pinagana';

  @override
  String get videoClipSemanticHintSelect =>
      'I-tap para piliin, pindutin nang matagal para i-preview';

  @override
  String get videoClipSemanticHintDeselect =>
      'I-tap para alisin ang pagpili, pindutin nang matagal para i-preview';

  @override
  String get routerInvalidCreator => 'Invalid na creator';

  @override
  String get routerInvalidHashtagRoute => 'Invalid na hashtag route';

  @override
  String get categoryGalleryCouldNotLoadVideos => 'Hindi na-load ang mga video';

  @override
  String get categoryGalleryNoVideosInCategory =>
      'Walang video sa category na ito';

  @override
  String get categoryGallerySortOptionsLabel => 'Mga sort option ng category';

  @override
  String get categoryGallerySortHot => 'Hot';

  @override
  String get categoryGallerySortNew => 'Bago';

  @override
  String get categoryGallerySortClassic => 'Classic';

  @override
  String get categoryGallerySortForYou => 'Para Sa\'yo';

  @override
  String get categoriesCouldNotLoadCategories =>
      'Hindi na-load ang mga category';

  @override
  String get categoriesNoCategoriesAvailable => 'Walang available na category';

  @override
  String get notificationsEmptyTitle => 'Wala pang activity';

  @override
  String get notificationsEmptySubtitle =>
      'Kapag nag-interact ang mga tao sa content mo, makikita mo dito';

  @override
  String get appsPermissionsTitle => 'Mga Integration Permission';

  @override
  String get appsPermissionsRevoke => 'I-revoke';

  @override
  String get appsPermissionsEmptyTitle =>
      'Walang naka-save na integration permission';

  @override
  String get appsPermissionsEmptySubtitle =>
      'Lalabas dito ang mga approved integration kapag may na-remember kang access approval.';

  @override
  String nostrAppPermissionTitle(String appName) {
    return 'Hinihingi ng $appName ang pag-apruba mo';
  }

  @override
  String get nostrAppPermissionDescription =>
      'Humihingi ng access ang app na ito gamit ang vetted sandbox ng Divine.';

  @override
  String get nostrAppPermissionOrigin => 'Pinagmulan';

  @override
  String get nostrAppPermissionMethod => 'Paraan';

  @override
  String get nostrAppPermissionCapability => 'Kakayahan';

  @override
  String get nostrAppPermissionEventKind => 'Uri ng event';

  @override
  String get nostrAppPermissionAllow => 'Payagan';

  @override
  String get appsDetailDefaultTitle => 'Integrated App';

  @override
  String get appsDetailNotFoundTitle => 'Hindi nakita ang integration';

  @override
  String get appsDetailNotFoundSubtitle =>
      'Hindi na available sa Divine ang aprubadong integration na ito.';

  @override
  String get appsDetailHowItWorksTitle => 'Paano ito gumagana';

  @override
  String get appsDetailHowItWorksBody =>
      'Ito ay aprubadong third-party app na tumatakbo sa loob ng Divine. Ang Divine lang ang nagbibigay ng mga na-review na kakayahan para sa integration na ito, at hinaharangan nito ang pag-navigate palabas ng mga aprubadong origin.';

  @override
  String get appsDetailAboutTitle => 'Tungkol dito';

  @override
  String get appsDetailPrimaryOriginTitle => 'Pangunahing origin';

  @override
  String get appsDetailApprovedOriginsTitle => 'Mga aprubadong origin';

  @override
  String get appsDetailCapabilitiesTitle => 'Mga available na kakayahan';

  @override
  String get appsDetailAskBeforeTitle => 'Magtanong bago';

  @override
  String get appsDetailOpenButton => 'Buksan ang Integration';

  @override
  String get appsDetailNoneDeclared => 'Wala pang naideklara';

  @override
  String get appsDirectoryTitle => 'Integrated Apps';

  @override
  String get appsDirectoryIntroTitle => 'Mga aprubadong third-party app';

  @override
  String get appsDirectoryIntroBody =>
      'Mga aprubadong third-party app na tumatakbo sa loob ng Divine';

  @override
  String get appsDirectoryErrorTitle => 'Hindi ma-load ang mga integrated app';

  @override
  String get appsDirectoryErrorSubtitle =>
      'Hilahin para subukan ulit ang mga aprubadong integration.';

  @override
  String get appsDirectoryEmptyTitle => 'Wala pang aprubadong integration';

  @override
  String get appsDirectoryEmptySubtitle =>
      'Lalabas dito ang mga aprubadong third-party app habang idinaragdag ng Divine.';

  @override
  String get appsDirectoryRefresh => 'I-refresh';

  @override
  String get appsDirectoryUnsupportedTitle =>
      'Tumatakbo sa Divine mobile ang Integrated Apps';

  @override
  String get appsDirectoryUnsupportedSubtitle =>
      'Available lang sa mobile ang mga aprubadong integration sa ngayon.';

  @override
  String get appsSandboxUnavailableTitle => 'Hindi available ang integration';

  @override
  String get appsSandboxUnavailableBody =>
      'Buksan ang mga aprubadong integration mula sa Integrated Apps tab para mailapat ng Divine ang tamang access policy.';

  @override
  String get appsSandboxLoadingTitle => 'Naglo-load ng integration';

  @override
  String get appsSandboxLoadingSubtitle =>
      'Sinusuri ang aprubadong integration bago i-launch.';

  @override
  String get appsSandboxBlockedTitle => 'Hinarangan para sa kaligtasan';

  @override
  String appsSandboxBlockedSubtitle(String uri) {
    return 'Sinubukan ng integration na ito na lumabas sa aprubadong origin nito.\n\n$uri';
  }

  @override
  String get shareCopiedPostLink => 'Nakopya sa clipboard ang link sa post';

  @override
  String get shareCopiedEventJson =>
      'Nakopya sa clipboard ang Nostr event JSON';

  @override
  String get shareCopiedEventId => 'Nakopya sa clipboard ang Nostr event ID';

  @override
  String get authHeroTaglineAuthentic => 'Tunay na sandali.';

  @override
  String get authHeroTaglineHuman => 'Pagkamalikhain ng tao.';

  @override
  String get keyImportFailedToImport =>
      'Hindi na-import ang key o na-connect ang bunker';

  @override
  String get keyImportInvalidBunkerUrl => 'Hindi wastong bunker URL';

  @override
  String get keyImportInvalidFormat =>
      'Hindi wastong format. Gamitin ang nsec..., hex, ncryptsec1..., o bunker://...';

  @override
  String get keyImportInvalidNsecFormat =>
      'Hindi wastong nsec format. Dapat 63 characters';

  @override
  String get keyImportKeyFieldLabel => 'Private key o bunker URL';

  @override
  String get keyImportKeyRequired =>
      'Pakilagay ang iyong private key o bunker URL';

  @override
  String get keyImportPasswordRequired =>
      'Pakilagay ang password para sa naka-encrypt na key na ito';

  @override
  String get keyImportSecurityWarningBody =>
      'Huwag kailanman ibahagi ang iyong private key kahit kanino. Ang key na ito ay nagbibigay ng buong access sa iyong Nostr identity.';

  @override
  String get keyImportSecurityWarningTitle =>
      'Panatilihing secure ang iyong private key!';

  @override
  String get keyImportSubtitle =>
      'I-import ang iyong umiiral na Nostr identity gamit ang iyong private key o bunker URL.';

  @override
  String get keyImportTitle => 'I-import ang iyong\nNostr identity';

  @override
  String get commentAuthorYouIndicator => 'Ikaw';

  @override
  String commentAuthorAvatarSemanticLabel(String name) {
    return 'Tingnan ang profile ni $name';
  }

  @override
  String get commentOptionsDeleteSemanticLabel => 'Burahin ang komento';

  @override
  String get commentOptionsEditSemanticLabel => 'I-edit ang komento';

  @override
  String get commentOptionsFlagContentLabel => 'I-flag ang Content';

  @override
  String get commentOptionsFlagContentSemanticLabel =>
      'I-flag ang content na ito';

  @override
  String get commentOptionsFlagReasonPrompt =>
      'Pumili ng dahilan sa pag-flag sa komentong ito';

  @override
  String get commentOptionsFlagSubmit => 'I-submit';

  @override
  String get commentOptionsTitle => 'Mga Option';

  @override
  String get commentsEmptyClassicVineMessage =>
      'Ginagawa pa namin ang pag-import ng mga lumang komento mula sa archive. Hindi pa ito handa.';

  @override
  String get commentsEmptyClassicVineTitle => 'Classic Vine';

  @override
  String get commentsInputEditingLabel => 'Nag-e-edit';

  @override
  String get commentsInputSemanticHint => 'Magdagdag ng komento';

  @override
  String get commentsInputSemanticHintEdit => 'I-edit ang komento';

  @override
  String get commentsInputSemanticHintReply => 'Magdagdag ng reply';

  @override
  String get commentsInputSemanticLabel => 'Input ng komento';

  @override
  String get commentsInputSemanticLabelEdit => 'I-edit ang input';

  @override
  String get commentsInputSemanticLabelReply => 'Input ng reply';

  @override
  String classicVinersViewProfileSemanticLabel(String displayName) {
    return 'Tingnan ang profile ni $displayName';
  }

  @override
  String get classicsEmptyDescription => 'Naglo-load ang Classics archive';

  @override
  String get classicsEmptyTitle => 'Walang Nakitang Classics';

  @override
  String get classicsErrorTitle => 'Hindi ma-load ang Classics';

  @override
  String get classicsUnavailableDescription =>
      'Available lang ang Classics kapag nakakonekta sa mga Funnelcake relay.';

  @override
  String get classicsUnavailableSettingsHint =>
      'Lumipat sa isang Funnelcake-enabled na relay sa Settings para ma-access ang Classics archive.';

  @override
  String get classicsUnavailableTitle => 'Hindi Available ang Classics';

  @override
  String get hashtagFeedEmptySubtitle =>
      'Ikaw ang mauna! Mag-post ng video na may ganitong hashtag!';

  @override
  String hashtagFeedEmptyTitle(String hashtag) {
    return 'Walang nakitang video para sa #$hashtag';
  }

  @override
  String get hashtagFeedLoadingSubtitle =>
      'Maaaring tumagal ito nang ilang sandali';

  @override
  String hashtagFeedLoadingTitle(String hashtag) {
    return 'Naglo-load ng mga video tungkol sa #$hashtag...';
  }

  @override
  String get hashtagInputHint => 'Magdagdag ng hashtag... #vine #nostr';

  @override
  String get newVideosTabEmptySubtitle =>
      'Bumalik ka mamaya para sa bagong content';

  @override
  String get newVideosTabEmptyTitle => 'Walang video sa New Videos';

  @override
  String get popularVideosContextTitle => 'Mga sikat na video';

  @override
  String get popularVideosEmptySubtitle =>
      'Bumalik ka mamaya para sa bagong content';

  @override
  String get popularVideosEmptyTitle => 'Walang video sa Popular Videos';

  @override
  String get popularVideosErrorTitle => 'Hindi ma-load ang mga trending video';

  @override
  String get popularVideosFeedSourceLabel => 'Source ng popular feed';

  @override
  String get trendingHashtagsLoading => 'Naglo-load ng mga hashtag...';

  @override
  String trendingHashtagsViewVideosTagged(String hashtag) {
    return 'Tingnan ang mga video na naka-tag ng $hashtag';
  }

  @override
  String videoGridAuthorSemanticLabel(String name) {
    return 'May-akda ng video: $name';
  }

  @override
  String videoGridDescriptionSemanticLabel(String description) {
    return 'Deskripsyon ng video: $description';
  }

  @override
  String get forYouAlgorithmChoiceBody =>
      'Ang vision ng Divine ay bigyan ka ng tunay na algorithmic choice. Sa halip na ma-lock sa iisang black-box na algorithm, makakapili ka mula sa maraming paraan ng rekomendasyon:';

  @override
  String get forYouAlgorithmChoiceChronological =>
      'Chronological timeline mula sa mga creator na sinusundan mo';

  @override
  String get forYouAlgorithmChoiceClosing =>
      'Inilalagay ka nito sa kontrol ng iyong atensyon sa halip na iwan ito sa platform. Dapat mong malaman kung paano ini-curate ang iyong feed at may kapangyarihan kang baguhin ito anumang oras.';

  @override
  String get forYouAlgorithmChoiceCustomFeeds =>
      'Mga custom feed na gawa ng komunidad para sa mga topic tulad ng musika, komedya, o sining';

  @override
  String get forYouAlgorithmChoicePersonalizedFeed =>
      'Personalized na \"For You\" feed';

  @override
  String get forYouAlgorithmChoiceTitle =>
      'Ang Iyong Algorithm, Ang Iyong Pagpili';

  @override
  String get forYouAlgorithmChoiceTrending => 'Trending at popular na content';

  @override
  String get forYouAlgorithmCommentsDescription =>
      'Malakas na signal — sapat ang iyong interes para tumugon';

  @override
  String get forYouAlgorithmHowItWorksBody =>
      'Pinapansin ng Divine kung paano ka nakikisalamuha sa content para maunawaan kung ano ang gusto mo. Sa tuwing manonood ka ng video, magbibigay ng reaction, mag-iiwan ng komento, o mag-re-repost nito, tinatandaan ito ng system.';

  @override
  String get forYouAlgorithmHowItWorksTitle => 'Paano Ito Gumagana';

  @override
  String get forYouAlgorithmInteractionsIntro =>
      'Iba\'t ibang aksyon ay nagpapakita ng iba\'t ibang antas ng interes:';

  @override
  String get forYouAlgorithmNewToDivineBody1 =>
      'Kung wala ka pang nabuong viewing history, nagpapakita kami ng halo ng kasalukuyang popular at trending kasama ng mga bagong upload. Nagbibigay ito ng magandang panimula para mag-explore.';

  @override
  String get forYouAlgorithmNewToDivineBody2 =>
      'Habang nanonood, nagla-like, at nakikisalamuha ka sa content, unti-unting nagiging mas personalized ang mga rekomendasyon. Sa paglipas ng panahon, ipinapakita ng iyong For You feed ang mga video mula sa mga creator na baka hindi mo pa natuklasan mag-isa.';

  @override
  String get forYouAlgorithmNewToDivineTitle => 'Bago sa Divine?';

  @override
  String get forYouAlgorithmOpenSourceBody =>
      'Gumagawa kami ng open system kung saan puwedeng magpatupad ang mga developer ng sarili nilang algorithm, at makakapili ka kung alin ang gagamitin — o mag-opt out nang buo.';

  @override
  String get forYouAlgorithmOpenSourceTitle => 'Open Source at Transparent';

  @override
  String get forYouAlgorithmReactionsDescription =>
      'Katamtamang signal — mabilis na paraan para magpakita ng pagpapahalaga';

  @override
  String get forYouAlgorithmReactionsTitle => 'Mga Reaction';

  @override
  String get forYouAlgorithmRepostsDescription =>
      'Pinakamalakas na signal — ang pagbabahagi sa iyong mga follower ay malakas na endorsement';

  @override
  String get forYouAlgorithmSubtitle =>
      'Pinapatakbo ng Gorse, isang open-source na recommendation engine';

  @override
  String get forYouAlgorithmTitle => 'Ang Divine Algorithm';

  @override
  String get forYouAlgorithmViewsDescription =>
      'Magaan na signal — nagpapahiwatig ng basic na interes';

  @override
  String get forYouEmptyDescription =>
      'Manood at mag-like ng ilang video para makakuha ng personalized na rekomendasyon.';

  @override
  String get forYouEmptyTitle => 'Wala Pang Rekomendasyon';

  @override
  String get forYouErrorTitle => 'Hindi ma-load ang mga rekomendasyon';

  @override
  String get forYouUnavailableDescription =>
      'Nangangailangan ng koneksyon sa Funnelcake ang mga personalized na rekomendasyon.';

  @override
  String get forYouUnavailableTitle => 'Hindi Available ang For You';

  @override
  String get inboxConversationOptionsLabel => 'Mga Option';

  @override
  String get inboxConversationViewProfileButton => 'Tingnan ang profile';

  @override
  String get inboxMessageRequestsEmpty => 'Walang message request';

  @override
  String inboxMessageRequestsSemanticLabel(int requestCount) {
    return 'Mga message request, $requestCount nakabinbin';
  }

  @override
  String get inboxMessageRequestsTitle => 'Mga message request';

  @override
  String get inboxMessagesTab => 'Mga Mensahe';

  @override
  String inboxRequestTileLabel(String displayName) {
    return 'Message request ni $displayName';
  }

  @override
  String get inboxRequestTileSubtitle => 'Nagpadala ng message request';

  @override
  String get inboxRequestsMarkAllRead => 'Markahang nabasa lahat ng request';

  @override
  String get inboxRequestsRemoveAll => 'Alisin lahat ng request';

  @override
  String get messageRequestDeclineAndRemoveButton => 'Tanggihan at alisin';

  @override
  String messageRequestDeclinedSnackbar(String displayName) {
    return 'Tinanggihan ang request ni $displayName';
  }

  @override
  String get messageRequestLoadFailed =>
      'Hindi na-load ang message request na ito.';

  @override
  String messageRequestFollowersCount(int countValue, String count) {
    return '$count Follower';
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
      other: '$count mensahe',
      one: '$count mensahe',
    );
    return '$_temp0';
  }

  @override
  String get messageRequestViewMessagesButton => 'Tingnan ang mga mensahe';

  @override
  String get messageRequestViewProfileButton => 'Tingnan ang profile';

  @override
  String messageRequestWantsToMessageYou(
    String displayName,
    String messageText,
  ) {
    return 'Gustong mag-message sa iyo ni $displayName, nagpadala sila ng $messageText.';
  }

  @override
  String get deleteAccountAccountChanged =>
      'Nagpalit ka ng account, kaya walang na-delete. Buksan ulit ang pag-delete para sa account na gusto mong alisin.';

  @override
  String get deleteAccountConfirmDeletePrompt => 'Para kumpirmahin, i-type:';

  @override
  String get deleteAccountConfirmUsernamePrompt =>
      'Para kumpirmahin, i-type ang username mo:';

  @override
  String get deleteAccountConfirmationHint => 'I-type ang DELETE';

  @override
  String get deleteAccountConfirmationHintUsername => 'I-type ang username mo';

  @override
  String get deleteAccountDeleteAllContentButton => 'Burahin Lahat ng Content';

  @override
  String get accountDeletionRecoveryTitle => 'Dine-delete ang account mo';

  @override
  String get accountDeletionRecoveryBody =>
      'Hindi namin natapos ang pag-delete ng account mo. Naka-reserve pa rin sa iyo ang username mo at puwede pang maibalik.';

  @override
  String accountDeletionRecoveryBodyWithExpiry(String expiryDate) {
    return 'We couldn\'t finish deleting your account. Your username is reserved for you until $expiryDate and can still be restored.';
  }

  @override
  String get accountDeletionRestoreUsername => 'Ibalik ang username ko';

  @override
  String get accountDeletionFinishingBody =>
      'Pinoproseso pa ang request na i-delete ang account mo. Puwede kang gumamit ng ibang account habang tinatapos namin ito.';

  @override
  String get accountDeletionOtherAccountPending =>
      'Pinoproseso pa sa device na ito ang pag-delete ng ibang account. Hintayin itong matapos bago i-delete ang account na ito.';

  @override
  String get accountDeletionCancellingBody =>
      'Kina-cancel na namin ang delete mo. Tingnan ulit bago ka umalis sa screen na ito.';

  @override
  String get accountDeletionRecoveryFailed =>
      'Hindi pa namin naibabalik ang username mo. Tingnan ang koneksyon mo at subukan ulit.';

  @override
  String get accountDeletionUsernameRestored =>
      'Naibalik na ang username mo. Hindi na-delete ang account mo.';

  @override
  String get accountDeletionRecoveryStatusFailed =>
      'Hindi namin ma-check ang status ng pag-delete mo. Tingnan ang koneksyon mo at subukan ulit.';

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
      'Hindi available ngayon ang pag-delete ng account. Walang na-delete.';

  @override
  String get deleteAccountDeletionIncomplete =>
      'Hindi namin natapos ang pag-delete ng account mo. Subukan ulit.';

  @override
  String get deleteAccountDeletionNotStarted =>
      'We couldn\'t start deleting your account. Nothing was deleted. Try again.';

  @override
  String get deleteAccountFinalConfirmationTitle =>
      '⚠️ Panghuling Kumpirmasyon';

  @override
  String get deleteAccountKeyDeletionWarning =>
      'Naipadala na ang mga deletion request, pero maaaring hindi pa lubusang naalis ang iyong mga key sa device na ito. Pumunta sa Settings → Nostr Keys → Remove Keys para subukan ulit.';

  @override
  String get deleteAccountLocalDataDeletionFailed =>
      'Naipadala na ang mga deletion request at naka-log out ka na, pero may ilang local data na hindi maalis sa device na ito.';

  @override
  String get deleteAccountPreparingDeletion => 'Inihahanda ang pagbura...';

  @override
  String deleteAccountProgressEvents(int current, int total) {
    return '$current / $total na event';
  }

  @override
  String get deleteAccountRemoveKeysBody =>
      'Inaalis nito ang lokal na login para sa account na ito sa device na ito. Hindi nito buburahin ang iyong Divine account o Nostr identity.\n\nMananatiling naka-save sa device na ito ang iyong mga draft at clip para sa account na ito. Kung ito ang huli mong lokal na account, babalik ka sa login screen.';

  @override
  String get deleteAccountRemoveKeysConfirm => 'Alisin sa device';

  @override
  String get deleteAccountRemoveKeysTitle =>
      'Alisin ang account na ito sa device na ito?';

  @override
  String get deleteAccountReauthRequired =>
      'Mag-sign in ulit para i-delete ang account mo. Wala pang na-delete.';

  @override
  String get deleteAccountServerDeletionFailed =>
      'Naipadala na ang mga request na burahin ang iyong mga post, pero hindi namin natapos ang pagbura ng iyong account. Subukan ulit mamaya.';

  @override
  String get deleteAccountSuccess =>
      'Na-delete na ang Divine account mo. Naipadala na ang mga request na i-delete ang mga Nostr post mo, pero maaaring may mga relay, client, o cache na nagpapanatili ng mga kopya.';

  @override
  String get deleteAccountSuccessContentUnverified =>
      'Na-request na ang pag-delete ng account. May ilang existing na post na hindi makumpirma nang isa-isa para sa pag-delete.';

  @override
  String get deleteAccountWarningBody =>
      'Nagpapadala ito ng mga deletion request para sa account at content mo, binubura ang Divine account mo kapag posible, at nila-log out ka sa device na ito. Ang ilang relay, client, at search index ay maaaring may kopya pa rin. Ang iba pang naka-log in na device ay mananatiling aktibo hanggang alisin mo ang mga key doon.';

  @override
  String get findPeopleNoContacts =>
      'Walang nakitang contact.\nSimulang sundan ang mga tao para makita sila dito.';

  @override
  String get geoBlockedCityLabel => 'Lungsod';

  @override
  String get geoBlockedCountryLabel => 'Bansa';

  @override
  String get geoBlockedDefaultReason =>
      'Hindi available ang serbisyong ito sa iyong rehiyon dahil sa mga lokal na regulasyon.';

  @override
  String get geoBlockedLegalNotice =>
      'Iginagalang namin ang iyong mga lokal na batas at regulasyon. Nakabatay ang restriksyong ito sa lokasyon ng iyong IP address.';

  @override
  String get geoBlockedRegionLabel => 'Rehiyon';

  @override
  String get geoBlockedTitle => 'Hindi Available ang Serbisyo';

  @override
  String get likedVideosEmpty => 'Walang naka-like na video';

  @override
  String get likedVideosInvalidRoute => 'Hindi wastong route';

  @override
  String get likedVideosTitle => 'Mga Naka-like na Video';

  @override
  String get uploadFailureSheetRetryingSnackbar =>
      'Sinusubukan ulit ang upload…';

  @override
  String get uploadFailureSheetSaveToDraftsButton => 'I-save sa Drafts';

  @override
  String get uploadFailureSheetSavedToDraftsSnackbar => 'Na-save sa drafts';

  @override
  String get uploadFailureSheetTitle => 'Nabigo ang Upload';

  @override
  String get uploadFailureSheetTryAgainButton => 'Subukan Ulit';

  @override
  String get videoEditorAudioImportAudio => 'Mag-import ng audio';

  @override
  String get videoEditorAudioImportFailed => 'Nabigo ang pag-import ng audio.';

  @override
  String get videoIconPlaceholderLabel => 'Video';

  @override
  String get publishErrorNotSignedIn =>
      'Mag-sign in muna para makapag-publish ng video.';

  @override
  String get publishErrorNoRetry => 'Walang upload na puwedeng subukan ulit.';

  @override
  String get publishErrorNoInternet =>
      'Walang internet connection. Tingnan ang iyong Wi-Fi o mobile data at subukan ulit.';

  @override
  String get publishErrorServerUnreachable =>
      'Hindi maabot ang server. Pakisubukan ulit mamaya.';

  @override
  String get publishErrorTimeout =>
      'Nag-timeout ang upload. Subukan ang mas malakas na koneksyon o mas maliit na video.';

  @override
  String get publishErrorTls =>
      'Nabigo ang secure connection. Tingnan ang iyong network — puwedeng harangan ng public Wi-Fi ang mga upload.';

  @override
  String publishErrorServerNotFound(String serverName) {
    return 'Hindi available ang media server ($serverName). Puwede kang pumili ng iba sa iyong settings.';
  }

  @override
  String get publishErrorFileTooLarge =>
      'Masyadong malaki ang video file para sa server. Subukang i-trim ito o babaan ang quality.';

  @override
  String publishErrorServerInternalError(String serverName) {
    return 'Nagka-internal error ang media server ($serverName). Puwede kang pumili ng iba sa iyong settings.';
  }

  @override
  String publishErrorServerDown(String serverName) {
    return 'Pansamantalang down ang media server ($serverName). Subukan ulit saglit o pumili ng iba sa iyong settings.';
  }

  @override
  String get publishErrorForbidden =>
      'Wala kang permission para mag-upload sa server na ito.';

  @override
  String get publishErrorFileNotFound =>
      'Hindi makita ang video file. Baka na-delete na ito. Mag-record ulit at subukan muli.';

  @override
  String get publishErrorLowStorage =>
      'Kulang ang storage sa device mo. Magbakante ng espasyo at subukan ulit.';

  @override
  String get publishErrorThumbnailFailed =>
      'Na-upload ang video, pero hindi naihanda ang thumbnail. Pakisubukan ulit.';

  @override
  String get publishErrorNostrPublishFailed =>
      'Na-upload ang video pero hindi na-publish ang post. Tingnan ang iyong relay settings at subukan ulit.';

  @override
  String get publishErrorAccountRestricted =>
      'Your account is restricted, so this post couldn’t be published.';

  @override
  String get uploadFailureSheetAccountStatusButton => 'View Account Status';

  @override
  String get publishErrorAudioReuseNotPermitted =>
      'Na-upload ang video pero hindi pinapayagang gamitin ulit ang sound nito. Pumili ng ibang sound para makapag-post.';

  @override
  String get publishErrorInterrupted =>
      'Naputol ang upload na ito. Gusto mo bang subukan ulit?';

  @override
  String get publishErrorAccountChanged =>
      'Sa ibang account ang video na ito. Bumalik sa account na iyon para i-post.';

  @override
  String get publishErrorGeneric =>
      'May nangyaring problema. Pakisubukan ulit.';

  @override
  String get publishErrorRateLimited =>
      'Masyadong maraming upload ngayon. Maghintay sandali at subukan ulit.';

  @override
  String get publishErrorUploadSessionExpired =>
      'Nag-expire ang iyong upload session. Pakisubukan ulit.';

  @override
  String get publishErrorPermissionDenied =>
      'Walang permission ang Divine para mag-upload. Tingnan ang app permissions sa iyong settings at subukan ulit.';

  @override
  String get publishErrorOutOfMemory =>
      'Kulang ang memory sa device mo. Magsara ng ilang app at subukan ulit.';

  @override
  String get publishErrorOverlaysUnavailable =>
      'Hindi na-prepare ang text at stickers sa draft na ito. Buksan mo sa editor, tapos i-post ulit.';

  @override
  String get publishErrorUnknownServer => 'Hindi kilalang server';

  @override
  String searchFilterPillSemanticLabel(String filter) {
    return 'Filter: $filter';
  }

  @override
  String searchNoResultsFound(String query) {
    return 'Walang nakitang resulta para sa \"$query\"';
  }

  @override
  String searchTagChipViewVideosTaggedLabel(String tag) {
    return 'Tingnan ang mga video na naka-tag ng $tag';
  }

  @override
  String audioAttributionRowSemanticLabel(
    String soundName,
    String creatorName,
  ) {
    return 'Tunog: $soundName ni $creatorName. I-tap para tingnan ang mga detalye ng tunog.';
  }

  @override
  String metadataSoundsOriginalSoundSemantics(String creatorName) {
    return 'Original sound ni $creatorName. I-tap para gamitin ang tunog na ito.';
  }

  @override
  String metadataSoundsSharedSoundSemantics(
    String soundName,
    String creatorName,
  ) {
    return 'Tunog: $soundName ni $creatorName. I-tap para tingnan ang mga detalye.';
  }

  @override
  String get soundDetailLoadError => 'Hindi ma-load ang tunog. Subukan ulit.';

  @override
  String get soundDetailNotFoundMessage => 'Hindi mahanap ang tunog na ito';

  @override
  String get soundDetailNotFoundTitle => 'Hindi Nakita ang Tunog';

  @override
  String videoFeedLoopCountLabel(int count) {
    return '🔁 $count loops';
  }

  @override
  String get originalSoundUnavailableBody =>
      'Hindi available nang hiwalay ang audio mula sa video na ito.';

  @override
  String originalSoundByCreator(String creatorName) {
    return 'Orihinal na sound - $creatorName';
  }

  @override
  String get ogVinerBadgeLabel => 'OG Viner';

  @override
  String get profileBadgeOgVinerBody =>
      'Nag-post ang taong ito ng orihinal na Vine na nakita ng Divine sa archive. Hindi ito badge ng verification ng account.';

  @override
  String get ogBetaTesterBadgeLabel => 'OG Beta Tester';

  @override
  String get profileBadgeOgBetaTesterBody =>
      'This person was testing Divine during the beta, before it opened to everyone. It is not an account verification badge.';

  @override
  String get profileBadgeCheckmarkTitle => 'Tsek sa profile';

  @override
  String get profileBadgeCheckmarkBody =>
      'Ibinibigay ng Divine ang tsek na ito sa mga account ng team. Hiwalay ito sa NIP-05, sa mga verified na link ng account, at sa OG Viner status.';

  @override
  String get unfollowConfirmButton => 'I-unfollow';

  @override
  String get videoClipSaveFailed => 'Hindi na-save ang clip';

  @override
  String videoClipSaveTo(String destination) {
    return 'I-save sa $destination';
  }

  @override
  String get videoClipDelete => 'Burahin ang clip';

  @override
  String inspiredByAttributionMultipleSemanticLabel(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return 'Inspirado ni $creatorName +$additionalCreatorCount. I-tap para tingnan ang kanilang profile.';
  }

  @override
  String inspiredByAttributionSemanticLabel(String creatorName) {
    return 'Inspirado ni $creatorName. I-tap para tingnan ang kanilang profile.';
  }

  @override
  String get bugReportSendReport => 'Ipadala ang Report';

  @override
  String get supportSubjectRequiredLabel => 'Paksa *';

  @override
  String get supportPublicSubmissionTitle => 'Pampublikong GitHub post';

  @override
  String get supportPublicSubmissionMessage =>
      'Lahat ng isusumite mo rito ay ipo-post sa aming open-source repository sa GitHub para maasikaso ito ng mga developer. Makikita ng lahat ang post at ang account na ginamit mong mag-sign in.';

  @override
  String get supportRequiredHelper => 'Kailangan';

  @override
  String get supportFieldLimitReached =>
      'Iyan na ang pinakamahabang pwede. Hindi naidagdag ang lampas doon.';

  @override
  String get bugReportSubjectHint => 'Maikling buod ng problema';

  @override
  String get bugReportDescriptionRequiredLabel => 'Ano\'ng nangyari? *';

  @override
  String get bugReportDescriptionHint =>
      'I-describe ang problemang naranasan mo';

  @override
  String get bugReportStepsLabel => 'Mga Hakbang Para Maulit';

  @override
  String get bugReportStepsHint =>
      '1. Pumunta sa...\n2. I-tap ang...\n3. Lalabas ang error';

  @override
  String get bugReportExpectedBehaviorLabel => 'Inaasahang Behavior';

  @override
  String get bugReportExpectedBehaviorHint => 'Ano sana dapat ang nangyari?';

  @override
  String get bugReportDiagnosticsNotice =>
      'Awtomatikong isasama ang device info at logs.';

  @override
  String get bugReportSuccessMessage =>
      'Salamat! Natanggap namin ang report mo at gagamitin namin ito para mas gumanda ang Divine.';

  @override
  String get bugReportAttachImages => 'Maglakip ng mga larawan';

  @override
  String bugReportImagesCount(int count, int max) {
    return '$count sa $max larawan ang napili';
  }

  @override
  String get bugReportRemoveImage => 'Alisin ang larawan';

  @override
  String get bugReportUploadFailed =>
      'Hindi namin na-upload ang piniling larawan. Subukan ulit o ipadala ang report nang wala ito.';

  @override
  String get bugReportSendFailed =>
      'Hindi naipadala ang bug report. Subukan ulit mamaya.';

  @override
  String get featureRequestSendRequest => 'Ipadala ang Request';

  @override
  String get featureRequestSubjectHint => 'Maikling buod ng idea mo';

  @override
  String get featureRequestDescriptionRequiredLabel => 'Ano ang gusto mo? *';

  @override
  String get featureRequestDescriptionHint =>
      'I-describe ang feature na gusto mo';

  @override
  String get featureRequestUsefulnessLabel =>
      'Paano ito magiging kapaki-pakinabang?';

  @override
  String get featureRequestUsefulnessHint =>
      'Ipaliwanag kung anong benepisyo ang maibibigay ng feature na ito';

  @override
  String get featureRequestWhenLabel => 'Kailan mo ito gagamitin?';

  @override
  String get featureRequestWhenHint =>
      'I-describe ang mga sitwasyon kung saan makakatulong ito';

  @override
  String get featureRequestSuccessMessage =>
      'Salamat! Natanggap namin ang feature request mo at irereview namin ito.';

  @override
  String get featureRequestSendFailed =>
      'Hindi naipadala ang feature request. Subukan ulit mamaya.';

  @override
  String get notificationFollowBack => 'I-follow back';

  @override
  String get followingTitle => 'Fino-follow';

  @override
  String followingTitleForName(String displayName) {
    return 'Fino-follow ni $displayName';
  }

  @override
  String get followingFailedToLoadList => 'Hindi na-load ang following list';

  @override
  String get followingEmptyTitle => 'Wala ka pang fino-follow';

  @override
  String get followersTitle => 'Mga Follower';

  @override
  String followersTitleForName(String displayName) {
    return 'Mga Follower ni $displayName';
  }

  @override
  String get followersFailedToLoadList => 'Hindi na-load ang followers list';

  @override
  String get followersEmptyTitle => 'Wala pang follower';

  @override
  String get followersUpdateFollowFailed =>
      'Hindi na-update ang follow status. Subukan ulit.';

  @override
  String get followersSortSemanticLabel => 'Ayusin ang mga follower';

  @override
  String get followingSortSemanticLabel => 'Ayusin ang mga sinusundan';

  @override
  String get followSortTitle => 'Ayusin ayon sa';

  @override
  String get followSortNewest => 'Pinakabago muna';

  @override
  String get followSortOldest => 'Pinakaluma muna';

  @override
  String get newMessageTitle => 'Bagong message';

  @override
  String get newMessageFindPeople => 'Maghanap ng tao';

  @override
  String get newMessageNoContacts =>
      'Walang nakitang contact.\nMag-follow ng mga tao para makita sila dito.';

  @override
  String get newMessageNoUsersFound => 'Walang nakitang user';

  @override
  String get hashtagSearchTitle => 'Maghanap ng hashtag';

  @override
  String get hashtagSearchSubtitle => 'Tuklasin ang trending topics at content';

  @override
  String hashtagSearchNoResults(String query) {
    return 'Walang nakitang hashtag para sa \"$query\"';
  }

  @override
  String get hashtagSearchFailed => 'Nabigo ang paghahanap';

  @override
  String get userNotAvailableTitle => 'Hindi available ang account';

  @override
  String get userNotAvailableBody =>
      'Hindi available ang account na ito ngayon.';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String get blossomFailedToSaveSettings =>
      'Hindi na-save ang settings. Subukan ulit.';

  @override
  String get blossomValidServerUrl =>
      'Maglagay ng valid na server URL (hal., https://blossom.band)';

  @override
  String get blossomSettingsSaved => 'Na-save ang Blossom settings';

  @override
  String get blossomSaveTooltip => 'I-save';

  @override
  String get blossomAboutTitle => 'Tungkol sa Blossom';

  @override
  String get blossomAboutDescription =>
      'Ang Blossom ay isang decentralized media storage protocol na nagpapahintulot sa iyong mag-upload ng video sa anumang compatible server. By default, naka-upload ang mga video sa Blossom server ng Divine. I-enable ang option sa baba para gumamit ng custom server.';

  @override
  String get blossomUseCustomServer => 'Gumamit ng Custom Blossom Server';

  @override
  String get blossomCustomServerEnabledSubtitle =>
      'Mag-u-upload ang mga video sa custom Blossom server mo';

  @override
  String get blossomCustomServerDisabledSubtitle =>
      'Naka-upload ang mga video mo sa Blossom server ng Divine';

  @override
  String get blossomCustomServerUrl => 'Custom Blossom Server URL';

  @override
  String get blossomCustomServerHelper =>
      'Ilagay ang URL ng custom Blossom server mo';

  @override
  String get blossomPopularServers => 'Mga Popular na Blossom Server';

  @override
  String get blossomServerUrlMustUseHttps =>
      'Dapat gumamit ng https:// ang Blossom server URL';

  @override
  String get blueskyFailedToUpdateCrosspost =>
      'Hindi na-update ang crosspost setting';

  @override
  String get blueskySignInRequired =>
      'Mag-sign in para i-manage ang Bluesky settings';

  @override
  String get blueskyPublishVideos => 'Mag-publish ng mga video sa Bluesky';

  @override
  String get blueskyEnabledSubtitle =>
      'Ipa-publish ang mga video mo sa Bluesky';

  @override
  String get blueskyDisabledSubtitle =>
      'Hindi ipa-publish ang mga video mo sa Bluesky';

  @override
  String get blueskyBackfillDisclosureTitle =>
      'Mapo-post din ang mga dati mong video';

  @override
  String get blueskyBackfillDisclosureSubtitle =>
      'Kapag binuksan mo ito, sisimulan ng Divine na ipadala sa Bluesky ang mas luma mong mga video, pinakaluma muna, nang hindi minamadali ang daily limit.';

  @override
  String get blueskyHandle => 'Bluesky Handle';

  @override
  String get blueskyDid => 'Bluesky DID';

  @override
  String get blueskyStatus => 'Status';

  @override
  String get blueskyStatusReady => 'Provisioned at ready na ang account';

  @override
  String get blueskyStatusPending => 'Pino-provision pa ang account...';

  @override
  String get blueskyStatusFailed => 'Nabigo ang provisioning ng account';

  @override
  String get blueskyStatusDisabled => 'Naka-disable ang account';

  @override
  String get blueskyStatusNotLinked => 'Walang Bluesky account na naka-link';

  @override
  String get blueskyUsernameRequired =>
      'Mag-set up ng divine.video handle bago mag-publish sa Bluesky';

  @override
  String get blueskyUsernameRequiredSubtitle =>
      'Kailangan ng na-claim na username.divine.video handle para makapag-publish sa Bluesky.';

  @override
  String get blueskyUsernameSyncPending =>
      'Na-claim na ang Divine handle mo. Ikinokonekta namin ito sa Bluesky — subukan ulit mamaya.';

  @override
  String get blueskyStatusUnavailableRetry =>
      'Hindi namin na-check ang Divine handle mo. Subukan ulit.';

  @override
  String get blueskySetUpHandle => 'I-set up';

  @override
  String get blueskyTemporarilyUnavailable =>
      'Pansamantalang hindi available ang pag-publish sa Bluesky. Subukan ulit.';

  @override
  String get invitesTitle => 'Mag-invite ng Kaibigan';

  @override
  String invitesGenerateCardTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count imbitasyon ang handa nang gawin',
      one: '$count imbitasyon ang handa nang gawin',
    );
    return '$_temp0';
  }

  @override
  String get invitesGenerateCardSubtitle =>
      'Gumawa ng code kapag handa ka nang magbahagi.';

  @override
  String get invitesGenerateButtonLabel => 'Gumawa ng imbitasyon';

  @override
  String get invitesNoneAvailable => 'Walang available na invite ngayon';

  @override
  String get invitesShareWithPeople => 'I-share ang Divine sa mga kakilala mo';

  @override
  String get invitesUsedInvites => 'Mga nagamit na invite';

  @override
  String invitesShareMessage(String code) {
    return 'Sumali sa akin sa Divine! Gamitin ang invite code $code para magsimula:\nhttps://divine.video/invite/$code';
  }

  @override
  String get invitesCopyInvite => 'I-copy ang invite';

  @override
  String get invitesCopied => 'Na-copy ang invite!';

  @override
  String get invitesShareInvite => 'I-share ang invite';

  @override
  String get invitesShareSubject => 'Sumali sa akin sa Divine';

  @override
  String get invitesClaimed => 'Na-claim';

  @override
  String get invitesCouldNotLoad => 'Hindi na-load ang mga invite';

  @override
  String get invitesRetry => 'Subukan ulit';

  @override
  String get searchSomethingWentWrong => 'May nangyaring problema';

  @override
  String get searchTryAgain => 'Subukan ulit';

  @override
  String get searchForLists => 'Maghanap ng mga list';

  @override
  String get searchFindCuratedVideoLists =>
      'Maghanap ng mga curated na video list';

  @override
  String get searchEnterQuery => 'Maglagay ng search query';

  @override
  String get searchDiscoverSomethingInteresting => 'Tumuklas ng kawili-wili';

  @override
  String get searchPeopleSectionHeader => 'Mga tao';

  @override
  String get searchPeopleLoadingLabel =>
      'Nilo-load ang mga resulta para sa tao';

  @override
  String get searchTagsSectionHeader => 'Mga tag';

  @override
  String get searchTagsLoadingLabel => 'Nilo-load ang mga resulta para sa tag';

  @override
  String get searchVideosSectionHeader => 'Mga video';

  @override
  String get searchVideosLoadingLabel =>
      'Nilo-load ang mga resulta para sa video';

  @override
  String get searchVideosSortOptionsLabel => 'Ayusin ang mga resulta ng video';

  @override
  String get searchVideosSortTrending => 'Hot';

  @override
  String get searchVideosSortLoops => 'Pinakamaraming loop';

  @override
  String get searchVideosSortEngagement => 'Pinaka-engaged';

  @override
  String get searchVideosSortRecent => 'Kamakailan';

  @override
  String get searchListsSectionHeader => 'Mga List';

  @override
  String get searchListsLoadingLabel =>
      'Naglo-load ng mga resulta para sa list';

  @override
  String get cameraAgeRestriction =>
      'Dapat 16 taong gulang ka pataas para gumawa ng content';

  @override
  String get keyImportInsecureBunkerRelay =>
      'Dapat gumamit ng wss:// ang bunker relay (pinapayagan lang ang ws:// para sa localhost)';

  @override
  String get timeNow => 'ngayon';

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
    return '${count}w';
  }

  @override
  String timeShortMonths(int count) {
    return '${count}mo';
  }

  @override
  String timeShortYears(int count) {
    return '${count}y';
  }

  @override
  String get timeVerboseNow => 'Ngayon';

  @override
  String timeAgo(String time) {
    return '$time ang nakaraan';
  }

  @override
  String get timeToday => 'Ngayong araw';

  @override
  String get timeYesterday => 'Kahapon';

  @override
  String get timeJustNow => 'kanina lang';

  @override
  String timeMinutesAgo(int count) {
    return '${count}m ang nakaraan';
  }

  @override
  String timeHoursAgo(int count) {
    return '${count}h ang nakaraan';
  }

  @override
  String timeDaysAgo(int count) {
    return '${count}d ang nakaraan';
  }

  @override
  String get draftTimeJustNow => 'Kanina lang';

  @override
  String get contentLabelNudity => 'Kahubaran';

  @override
  String get contentLabelSexualContent => 'Sekswal na Content';

  @override
  String get contentLabelPornography => 'Pornograpiya';

  @override
  String get contentLabelGraphicMedia => 'Graphic na Media';

  @override
  String get contentLabelViolence => 'Karahasan';

  @override
  String get contentLabelSelfHarm => 'Pananakit sa sarili/Pagpapakamatay';

  @override
  String get contentLabelDrugUse => 'Paggamit ng Droga';

  @override
  String get contentLabelAlcohol => 'Alak';

  @override
  String get contentLabelTobacco => 'Tabako/Paninigarilyo';

  @override
  String get contentLabelGambling => 'Sugal';

  @override
  String get contentLabelProfanity => 'Mura';

  @override
  String get contentLabelHateSpeech => 'Mapoot na pananalita';

  @override
  String get contentLabelHarassment => 'Panliligalig';

  @override
  String get contentLabelFlashingLights => 'Kumikislap na Ilaw';

  @override
  String get contentLabelAiGenerated => 'Gawa ng AI';

  @override
  String get contentLabelDeepfake => 'Deepfake';

  @override
  String get contentLabelSpam => 'Spam';

  @override
  String get contentLabelScam => 'Scam/Pandaraya';

  @override
  String get contentLabelSpoiler => 'Spoiler';

  @override
  String get contentLabelMisleading => 'Nakakapagligaw';

  @override
  String get contentLabelSensitiveContent => 'Sensitibong Content';

  @override
  String notificationLikedYourVideo(String actorName) {
    return 'Ni-like ni $actorName ang video mo';
  }

  @override
  String notificationLikedYourComment(String actorName) {
    return 'Ni-like ni $actorName ang comment mo';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return 'Nag-comment si $actorName sa video mo';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return 'Sinimulan kang i-follow ni $actorName';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return 'Binanggit ka ni $actorName';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return 'Na-repost ni $actorName ang video mo';
  }

  @override
  String notificationPostedNewVine(String actorName) {
    return 'Nag-post si $actorName ng bagong vine';
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
      other: '$count sa mga vine mo',
      one: 'vine mo',
    );
    return 'Idinagdag ni $actorName ang $_temp0 sa $listName';
  }

  @override
  String notificationRepliedToYourComment(String actorName) {
    return 'nag-reply si $actorName sa comment mo';
  }

  @override
  String get notificationAndConnector => 'at';

  @override
  String notificationOthersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count iba pa',
      one: '$count iba pa',
    );
    return '$_temp0';
  }

  @override
  String get notificationSystemUpdate => 'May bago kang update';

  @override
  String get commentReplyToPrefix => 'Re:';

  @override
  String get commentHideKeyboard => 'Itago ang keyboard';

  @override
  String get commentsErrorLoadFailed => 'Hindi na-load ang mga komento';

  @override
  String get commentsErrorNotAuthenticatedComment =>
      'Mag-sign in para makapagkomento';

  @override
  String get commentsErrorPostCommentFailed => 'Hindi na-post ang komento';

  @override
  String get commentsErrorPostReplyFailed => 'Hindi na-post ang sagot';

  @override
  String get commentsErrorEditFailed => 'Hindi na-edit ang komento';

  @override
  String get commentsErrorNotAuthenticatedInteract =>
      'Mag-sign in para makilahok';

  @override
  String get commentsErrorVoteFailed => 'Hindi naiboto ang komento';

  @override
  String get commentsErrorReportFailed => 'Hindi na-report ang komento';

  @override
  String get commentsErrorBlockFailed => 'Hindi na-block ang user';

  @override
  String get commentsErrorDeleteFailed => 'Hindi na-delete ang komento';

  @override
  String commentsHeaderCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Komento',
      one: '$count Komento',
    );
    return '$_temp0';
  }

  @override
  String get commentsVideoReplyPending => 'Nagpo-post…';

  @override
  String get commentsVideoReplyPendingSemanticLabel =>
      'Nagpo-post ang iyong video reply';

  @override
  String get commentsSortNew => 'Bago';

  @override
  String get commentsSortTop => 'Top';

  @override
  String get commentsSortOld => 'Luma';

  @override
  String get commentsSortSemanticLabel => 'Pagkakasunod-sunod ng mga komento';

  @override
  String get commentReply => 'Sumagot';

  @override
  String get commentReplySemanticLabel => 'Sagutin ang komento';

  @override
  String get commentUpvoteLabel => 'I-upvote ang komento';

  @override
  String get commentRemoveUpvoteLabel => 'Alisin ang upvote';

  @override
  String get commentDownvoteLabel => 'I-downvote ang komento';

  @override
  String get commentRemoveDownvoteLabel => 'Alisin ang downvote';

  @override
  String get commentsInputHint => 'Magdagdag ng komento...';

  @override
  String get commentsInputHintEdit => 'I-edit ang komento...';

  @override
  String get commentsEmptyTitle => 'Wala pang komento';

  @override
  String get commentsEmptySubtitle => 'Ikaw na ang magsimula!';

  @override
  String get draftUntitled => 'Walang Pamagat';

  @override
  String get contentWarningNone => 'Wala';

  @override
  String get textBackgroundNone => 'Wala';

  @override
  String get textBackgroundSolid => 'Solid';

  @override
  String get textBackgroundHighlight => 'Highlight';

  @override
  String get textBackgroundTransparent => 'Transparent';

  @override
  String get textAlignLeft => 'Kaliwa';

  @override
  String get textAlignRight => 'Kanan';

  @override
  String get textAlignCenter => 'Gitna';

  @override
  String get cameraPermissionWebUnsupportedTitle =>
      'Hindi pa supported ang camera sa web';

  @override
  String get cameraPermissionWebUnsupportedDescription =>
      'Hindi pa available ang camera capture at recording sa web version.';

  @override
  String get cameraPermissionBackToFeed => 'Bumalik sa feed';

  @override
  String get cameraCouldNotStart => 'Hindi ma-start ang camera';

  @override
  String get cameraUnsupportedPlatform =>
      'Hindi pa available ang camera sa platform na ito.\nPwede ka pa ring mag-browse at manood ng mga video.';

  @override
  String get cameraPermissionErrorTitle => 'Error sa pahintulot';

  @override
  String get cameraPermissionErrorDescription =>
      'May nangyaring problema habang sinusuri ang mga permission.';

  @override
  String get cameraPermissionRetry => 'Subukan ulit';

  @override
  String get cameraPermissionAllowAccessTitle =>
      'Payagan ang access sa camera at mikropono';

  @override
  String get cameraPermissionAllowAccessDescription =>
      'Pinapayagan ka nitong kumuha at mag-edit ng video dito mismo sa app, wala nang iba.';

  @override
  String get cameraPermissionGoToSettings => 'Pumunta sa settings';

  @override
  String get videoRecorderWhySixSecondsTitle => 'Bakit anim na segundo?';

  @override
  String get videoRecorderWhySixSecondsSubtitle =>
      'Ang mabilis na clip ay nagbibigay-daan sa pagiging spontaneous. Ang 6-second format ay tumutulong sa\'yong makuha ang mga authentic na sandali habang nangyayari.';

  @override
  String get videoRecorderWhySixSecondsButton => 'Sige na!';

  @override
  String get videoRecorderUploadTitle => 'Bakit walang upload?';

  @override
  String get videoRecorderUploadBody =>
      'Ang nakikita mo sa Divine ay gawa ng tao: raw at kuha sa mismong sandali. Hindi tulad ng ibang platform na pumapayag ng highly produced o AI-generated na upload, inuuna namin ang authenticity ng camera-direct na karanasan.';

  @override
  String get videoRecorderUploadBodyDetail =>
      'Sa pamamagitan ng pananatili ng paggawa sa loob ng app, mas magagarantiyahan namin na ang content ay totoo at hindi na-edit. Hindi muna namin binubuksan ang external gallery upload sa ngayon para protektahan ang pagiging totoo at panatilihing libre ang community namin sa synthetic content hangga\'t kaya namin.';

  @override
  String get videoRecorderUploadBodyCta =>
      'Lumipat sa Capture o Classic para mag-record ng tunay.';

  @override
  String get videoRecorderUploadLearnMore =>
      'Alamin kung paano gumagana ang verification';

  @override
  String get videoRecorderAutosaveFoundTitle =>
      'May nahanap kaming work in progress';

  @override
  String get videoRecorderAutosaveFoundSubtitle =>
      'Gusto mo bang ipagpatuloy kung saan ka tumigil?';

  @override
  String get videoRecorderAutosaveContinueButton => 'Oo, ipagpatuloy';

  @override
  String get videoRecorderAutosaveDiscardButton =>
      'Hindi, magsimula ng bagong video';

  @override
  String get videoRecorderAutosaveRestoreFailure =>
      'Hindi na-restore ang draft mo';

  @override
  String get videoRecorderStopRecordingTooltip => 'Itigil ang pag-record';

  @override
  String get videoRecorderStartRecordingTooltip => 'Simulan ang pag-record';

  @override
  String get videoRecorderRecordingTapToStopLabel =>
      'Nagre-record. I-tap kahit saan para itigil';

  @override
  String get videoRecorderTapToStartLabel =>
      'I-tap kahit saan para magsimulang mag-record';

  @override
  String get videoRecorderDeleteLastClipLabel => 'Burahin ang huling clip';

  @override
  String get videoRecorderSwitchCameraLabel => 'Magpalit ng camera';

  @override
  String videoRecorderZoomLevelLabel(String zoom) {
    return 'I-zoom sa $zoom×';
  }

  @override
  String get videoRecorderToggleGridLabel => 'I-toggle ang grid';

  @override
  String get videoRecorderToggleGhostFrameLabel => 'I-toggle ang ghost frame';

  @override
  String get videoRecorderGhostFrameEnabled => 'Naka-enable ang ghost frame';

  @override
  String get videoRecorderGhostFrameDisabled => 'Naka-disable ang ghost frame';

  @override
  String get videoRecorderClipDeletedMessage =>
      'Inilipat ang clip sa basurahan';

  @override
  String get videoRecorderClipUndoLabel => 'I-undo';

  @override
  String get libraryTrashEmptyTitle => 'Walang laman ang basurahan';

  @override
  String get libraryTrashEmptySubtitle =>
      'Mananatili dito ang mga nabura na clip ng 30 araw bago tuluyang alisin.';

  @override
  String get libraryTrashRestoreLabel => 'Ibalik';

  @override
  String get libraryTrashDeleteNowLabel => 'Burahin ngayon';

  @override
  String get libraryTrashEmptyAllLabel => 'I-empty ang basurahan';

  @override
  String get libraryTrashDeleteConfirmTitle => 'I-delete ang clip ngayon?';

  @override
  String get libraryTrashDeleteConfirmMessage =>
      'Aalisin nito agad ang clip mula sa trash.';

  @override
  String get libraryTrashEmptyConfirmTitle => 'I-empty ang trash?';

  @override
  String libraryTrashEmptyConfirmMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clip',
      one: '$count clip',
    );
    return 'Permanente nitong ide-delete agad mula sa trash ang $_temp0.';
  }

  @override
  String get videoRecorderCloseLabel => 'Isara ang video recorder';

  @override
  String get videoRecorderContinueToEditorLabel => 'Magpatuloy sa video editor';

  @override
  String get videoRecorderCameraPreviewLabel => 'Preview ng camera';

  @override
  String get videoRecorderCameraPreviewFocusHint => 'I-focus ang camera';

  @override
  String videoRecorderSwitchToModeLabel(String mode) {
    return 'Lumipat sa $mode mode';
  }

  @override
  String get videoRecorderLipSyncAddAudioFirst =>
      'Magdagdag ng audio bago mag-record';

  @override
  String get videoRecorderStopMotionAssembleFailed =>
      'Hindi magawa ang video. Subukan ulit.';

  @override
  String videoRecorderStopMotionShotsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count shot na lang',
      one: '$count shot na lang',
      zero: 'Wala nang natitirang shot',
    );
    return '$_temp0';
  }

  @override
  String get videoRecorderToggleFlashLabel => 'I-toggle ang flash';

  @override
  String get videoRecorderCycleTimerLabel => 'I-cycle ang timer';

  @override
  String get videoRecorderToggleAspectRatioLabel => 'I-toggle ang aspect ratio';

  @override
  String get videoRecorderStabilizationLabel => 'Estabilisasyon';

  @override
  String get videoRecorderStabilizationModeOff => 'Naka-off';

  @override
  String get videoRecorderStabilizationModeStandard => 'Standard';

  @override
  String get videoRecorderStabilizationModeCinematic => 'Cinematic';

  @override
  String get videoRecorderStabilizationModeCinematicExtended =>
      'Cinematic Extended';

  @override
  String get videoRecorderStabilizationModePreviewOptimized =>
      'Optimized para sa Preview';

  @override
  String get videoRecorderStabilizationModeLowLatency => 'Low Latency';

  @override
  String get videoRecorderStabilizationModeAuto => 'Auto';

  @override
  String get videoRecorderFlashValueOff => 'Naka-off';

  @override
  String get videoRecorderFlashValueOn => 'Naka-on';

  @override
  String get videoRecorderFlashValueAuto => 'Auto';

  @override
  String get videoRecorderTimerValueOff => 'Naka-off';

  @override
  String get videoRecorderTimerValueThreeSeconds => '3 segundo';

  @override
  String get videoRecorderTimerValueTenSeconds => '10 segundo';

  @override
  String get videoRecorderAspectRatioValueSquare => 'Parisukat';

  @override
  String get videoRecorderAspectRatioValueVertical => 'Patayo';

  @override
  String get videoRecorderCameraValueFront => 'Camera sa harap';

  @override
  String get videoRecorderCameraValueBack => 'Camera sa likod';

  @override
  String get videoRecorderLibraryEmptyLabel => 'Clip library, walang clip';

  @override
  String videoRecorderLibraryOpenLabel(int clipCount) {
    String _temp0 = intl.Intl.pluralLogic(
      clipCount,
      locale: localeName,
      other: 'Buksan ang clip library, $clipCount clip',
      one: 'Buksan ang clip library, $clipCount clip',
    );
    return '$_temp0';
  }

  @override
  String videoRecorderLibraryOpenStopMotionLabel(int frameCount) {
    String _temp0 = intl.Intl.pluralLogic(
      frameCount,
      locale: localeName,
      other: 'Buksan ang stop-motion library, $frameCount frame',
      zero: 'Buksan ang stop-motion library',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorCameraLabel => 'Camera';

  @override
  String get videoEditorOpenCameraSemanticLabel => 'Buksan ang camera';

  @override
  String get videoEditorLibraryLabel => 'Library';

  @override
  String get videoEditorTextLabel => 'Text';

  @override
  String get videoEditorDrawLabel => 'Mag-drawing';

  @override
  String get videoEditorFilterLabel => 'Filter';

  @override
  String get videoEditorTuneLabel => 'Isaayos';

  @override
  String get videoEditorOpenTuneSemanticLabel =>
      'Buksan ang editor ng pagsasaayos';

  @override
  String get videoEditorTuneBrightness => 'Liwanag';

  @override
  String get videoEditorTuneContrast => 'Kontrast';

  @override
  String get videoEditorTuneSaturation => 'Saturasyon';

  @override
  String get videoEditorTuneExposure => 'Eksposyur';

  @override
  String get videoEditorTuneHue => 'Kulay';

  @override
  String get videoEditorTuneTemperature => 'Temperatura';

  @override
  String get videoEditorTuneTint => 'Tina';

  @override
  String get videoEditorTuneFade => 'Kupas';

  @override
  String get videoEditorAudioLabel => 'Audio';

  @override
  String get videoEditorAddTitle => 'Idagdag';

  @override
  String get videoEditorOpenLibrarySemanticLabel => 'Buksan ang Library';

  @override
  String get videoEditorOpenAudioSemanticLabel => 'Buksan ang audio editor';

  @override
  String get videoEditorCaptionsLabel => 'Mga subtitle';

  @override
  String get videoEditorOpenCaptionsSemanticLabel =>
      'Buksan ang subtitle editor';

  @override
  String get videoEditorCaptionsBurnInLabel => 'I-burn sa video';

  @override
  String get videoEditorCaptionsPresetCustom => 'Custom';

  @override
  String get videoEditorCaptionsCustomStyleTitle => 'Custom na estilo';

  @override
  String get videoEditorCaptionsCustomApply => 'Ilapat';

  @override
  String get videoEditorCaptionsCustomFont => 'Font';

  @override
  String get videoEditorCaptionsCustomTextColor => 'Kulay ng teksto';

  @override
  String get videoEditorCaptionsCustomBackground => 'Background';

  @override
  String get videoEditorCaptionsCustomBackgroundColor => 'Kulay ng background';

  @override
  String get videoEditorCaptionsCustomAnimation => 'Animation';

  @override
  String get videoEditorCaptionsAnimationNone => 'Wala';

  @override
  String get videoEditorCaptionsAnimationFade => 'Fade';

  @override
  String get videoEditorCaptionsAnimationPop => 'Pop';

  @override
  String get videoEditorCaptionsAnimationSpring => 'Spring';

  @override
  String get videoEditorCaptionsEditTitle => 'Mga subtitle';

  @override
  String get videoEditorCaptionsGeneratingTitle => 'Nakikinig…';

  @override
  String get videoEditorCaptionsGeneratingSubtitle =>
      'Ginagawang mga suhestiyong subtitle ang audio mo.';

  @override
  String get videoEditorCaptionsNoSpeechMessage =>
      'Wala kaming narinig na boses. Puwede mo pa ring isulat ang mga subtitle.';

  @override
  String get videoEditorCaptionsUnavailableMessage =>
      'Hindi available ang speech recognition sa device na ito. Puwede mong isulat ang mga subtitle.';

  @override
  String get videoEditorCaptionsNotAuthorizedMessage =>
      'Hindi pinapayagan ang speech recognition. I-enable ito sa Settings o isulat ang mga subtitle.';

  @override
  String get videoEditorCaptionsFailedMessage =>
      'Hindi gumana ang transcription ngayon. Puwede mong isulat ang mga subtitle.';

  @override
  String get videoEditorCaptionsStartEmptyButton =>
      'Ako na ang magsusulat ng mga subtitle';

  @override
  String get videoEditorCaptionsAddCue => 'Magdagdag ng subtitle';

  @override
  String get videoEditorCaptionsCueTextHint => 'Teksto ng subtitle';

  @override
  String get videoEditorCaptionsCueDeleteSemanticLabel =>
      'Burahin ang subtitle';

  @override
  String get videoEditorCaptionsDeleteTrack => 'Alisin ang lahat ng subtitle';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmTitle =>
      'Alisin ang mga subtitle?';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmSubtitle =>
      'Mawawala ang lahat ng teksto at timing.';

  @override
  String get videoEditorCaptionsCloseSemanticLabel =>
      'Isara ang subtitle editor';

  @override
  String get videoEditorCaptionsDoneSemanticLabel =>
      'Kumpirmahin ang mga subtitle';

  @override
  String get videoEditorCaptionsPresetTitle => 'Istilo ng subtitle';

  @override
  String get videoEditorCaptionsPresetClassic => 'Klasiko';

  @override
  String get videoEditorCaptionsPresetPop => 'Pop';

  @override
  String get videoEditorCaptionsPresetZoom => 'Zoom';

  @override
  String get videoEditorCaptionsPresetSpring => 'Spring';

  @override
  String get videoEditorCaptionsPresetMono => 'Mono';

  @override
  String get videoEditorCaptionsPresetHeadline => 'Headline';

  @override
  String get videoEditorCaptionsPresetTypewriter => 'Makinilya';

  @override
  String get videoEditorCaptionsPresetMarker => 'Marker';

  @override
  String get videoEditorCaptionsPresetScript => 'Kaligrapiya';

  @override
  String get videoEditorCaptionsPresetRetro => 'Retro';

  @override
  String get videoEditorCaptionsPresetElegant => 'Elegante';

  @override
  String get videoEditorCaptionsPresetBubble => 'Bula';

  @override
  String get videoEditorCaptionsPresetNeon => 'Neon';

  @override
  String get videoEditorCaptionsPresetBold => 'Makapal';

  @override
  String get videoEditorCaptionsPresetDreamy => 'Panaginip';

  @override
  String get videoEditorCaptionsPresetOcean => 'Karagatan';

  @override
  String get videoEditorCaptionsPresetSunny => 'Maaraw';

  @override
  String get videoEditorCaptionsPresetHandwritten => 'Sulat-kamay';

  @override
  String get videoEditorCaptionsPresetSerif => 'Serif';

  @override
  String get videoEditorCaptionsPresetStamp => 'Selyo';

  @override
  String get videoEditorOpenTextSemanticLabel => 'Buksan ang text editor';

  @override
  String get videoEditorOpenDrawSemanticLabel => 'Buksan ang draw editor';

  @override
  String get videoEditorOpenFilterSemanticLabel => 'Buksan ang filter editor';

  @override
  String get videoEditorOpenStickerSemanticLabel => 'Buksan ang sticker editor';

  @override
  String get videoEditorSaveDraftTitle => 'I-save ang draft mo?';

  @override
  String get videoEditorSaveDraftSubtitle =>
      'Itago ang mga edit para sa susunod, o burahin at lumabas sa editor.';

  @override
  String get videoEditorSaveDraftButton => 'I-save ang draft';

  @override
  String get videoEditorDiscardChangesButton => 'Burahin ang mga pagbabago';

  @override
  String get videoEditorKeepEditingButton => 'Magpatuloy sa pag-edit';

  @override
  String get videoEditorDeleteLayerDropZone =>
      'Drop zone para burahin ang layer';

  @override
  String get videoEditorReleaseToDeleteLayer =>
      'Bitawan para burahin ang layer';

  @override
  String get videoEditorDoneLabel => 'Tapos na';

  @override
  String get videoEditorPlayPauseSemanticLabel => 'I-play o i-pause ang video';

  @override
  String videoEditorSplitPositionInvalid(int minDurationMs) {
    return 'Invalid ang split position. Dapat hindi bababa sa ${minDurationMs}ms ang haba ng dalawang clip.';
  }

  @override
  String get videoEditorSaveSelectedClip => 'I-save ang napiling clip';

  @override
  String get videoEditorSaveClip => 'I-save ang clip';

  @override
  String get videoEditorClipSavedSuccess => 'Na-save sa library ang clip';

  @override
  String get videoEditorClipSaveFailed => 'Hindi na-save ang clip';

  @override
  String get videoEditorColorPickerSemanticLabel => 'Pumili ng kulay';

  @override
  String get videoEditorUndoSemanticLabel => 'I-undo';

  @override
  String get videoEditorRedoSemanticLabel => 'I-redo';

  @override
  String get videoEditorTextColorSemanticLabel => 'Kulay ng text';

  @override
  String get videoEditorTextAlignmentSemanticLabel => 'Alignment ng text';

  @override
  String get videoEditorTextBackgroundSemanticLabel => 'Background ng text';

  @override
  String get videoEditorFontSemanticLabel => 'Font';

  @override
  String get videoEditorNoStickersFound => 'Walang nahanap na sticker';

  @override
  String get videoEditorNoStickersAvailable => 'Walang available na sticker';

  @override
  String get videoEditorFailedLoadStickers => 'Hindi na-load ang mga sticker';

  @override
  String get videoEditorVoiceOverLabel => 'Voice over';

  @override
  String videoEditorVoiceOverTakeName(int number) {
    return 'Recording $number';
  }

  @override
  String get videoEditorOpenVoiceOverSemanticLabel =>
      'Mag-record ng voice over';

  @override
  String get videoEditorVoiceOverRecordSemanticLabel =>
      'Simulan ang pag-record';

  @override
  String get videoEditorVoiceOverStopSemanticLabel => 'Itigil ang pag-record';

  @override
  String get videoEditorVoiceOverHint =>
      'I-tap para mag-record. Magdagdag ng kahit ilang take.';

  @override
  String videoEditorVoiceOverRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count na recording',
      one: '$count recording',
      zero: 'Wala pang recording',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorVoiceOverDeleteLast => 'Burahin ang huling recording';

  @override
  String get videoEditorVoiceOverPermissionTitle =>
      'Kailangan ng access sa mikropono';

  @override
  String get videoEditorVoiceOverPermissionBody =>
      'Payagan ang access sa mikropono para makapag-record ng voice over.';

  @override
  String get videoEditorVoiceOverOpenSettings => 'Buksan ang mga setting';

  @override
  String get videoEditorVoiceOverRecordingStarted => 'Nagsimula ang pag-record';

  @override
  String get videoEditorVoiceOverRecordingSaved => 'Na-save ang recording';

  @override
  String get videoEditorVoiceOverTooLong =>
      'Mas mahaba ang recording kaysa sa video mo';

  @override
  String get videoEditorPlaySemanticLabel => 'I-play';

  @override
  String get videoEditorPauseSemanticLabel => 'I-pause';

  @override
  String get videoEditorVolumeSemanticLabel => 'Ayusin ang volume';

  @override
  String videoEditorTimelineVolumePreview(int percent) {
    return 'Volume $percent%';
  }

  @override
  String get videoEditorTimelineSlideToAdjust => 'I-slide para i-adjust';

  @override
  String get videoEditorChromaKeyLabel => 'Green screen';

  @override
  String get videoEditorChromaKeyTitle => 'Green screen';

  @override
  String get videoEditorChromaKeySemanticLabel =>
      'I-set up ang green screen para sa clip na ito';

  @override
  String get videoEditorChromaKeyCloseSemanticLabel =>
      'Itapon ang mga pagbabago sa green screen';

  @override
  String get videoEditorChromaKeyDoneSemanticLabel => 'Ilapat ang green screen';

  @override
  String get videoEditorChromaKeyAutoDetect => 'Auto-detect';

  @override
  String get videoEditorChromaKeyPresetGreen => 'Berde';

  @override
  String get videoEditorChromaKeyPresetBlue => 'Asul';

  @override
  String get videoEditorChromaKeyScreenColorLabel => 'Kulay ng screen';

  @override
  String get videoEditorChromaKeyAmountLabel => 'Lakas';

  @override
  String get videoEditorChromaKeyAmountHint =>
      'Gaano karaming kulay ng screen ang mawawala';

  @override
  String get videoEditorChromaKeyEdgeLabel => 'Gilid';

  @override
  String get videoEditorChromaKeyEdgeHint =>
      'Pinapalambot ang gupit para hindi magaspang ang buhok';

  @override
  String get videoEditorChromaKeySpillLabel => 'Spill';

  @override
  String get videoEditorChromaKeySpillHint =>
      'Inaalis ang kulay ng screen sa subject mo';

  @override
  String get videoEditorChromaKeyBackgroundLabel => 'Palitan ng';

  @override
  String get videoEditorChromaKeyBackgroundNone => 'Wala';

  @override
  String get videoEditorChromaKeyBackgroundColor => 'Kulay';

  @override
  String get videoEditorChromaKeyBackgroundImage => 'Larawan';

  @override
  String get videoEditorChromaKeyBackgroundVideo => 'Clip';

  @override
  String get videoEditorChromaKeyTransparentHint =>
      'Hindi kayang magdala ng transparency ang video, kaya magiging itim ito sa export.';

  @override
  String get videoEditorChromaKeyDetectFailed =>
      'Walang nakitang screen. Kailangang umabot ito sa gilid ng frame — kung hindi, piliin ang kulay nang manu-mano.';

  @override
  String get videoEditorChromaKeyPickClipTitle => 'Pumili ng clip';

  @override
  String get videoEditorChromaKeyNoLibraryClips =>
      'Walang laman ang library mo. Mag-save muna ng clip, tapos gamitin bilang background.';

  @override
  String get videoEditorChromaKeyImagePickFailed =>
      'Hindi ma-load ang larawang iyon.';

  @override
  String get videoEditorChromaKeyRemove => 'Alisin ang green screen';

  @override
  String get videoEditorChromaKeyFailed =>
      'Hindi na-apply ang green screen. Hindi nagbago ang clip mo.';

  @override
  String get videoEditorChromaKeyRemoveFailed =>
      'Hindi naalis ang green screen. Hindi nagbago ang clip mo.';

  @override
  String get videoEditorChromaKeyApplying => 'Ina-apply ang green screen…';

  @override
  String get videoEditorChromaKeyPreviewUnavailable =>
      'Hindi maipapakita ng device na ito ang live preview. Gumagana pa rin ang mga setting mo kapag nag-export.';

  @override
  String videoEditorClipVolumeLabel(int index) {
    return 'Clip $index';
  }

  @override
  String get videoEditorDeleteLabel => 'Burahin';

  @override
  String get videoEditorDeleteSelectedItemSemanticLabel =>
      'Burahin ang napiling item';

  @override
  String get videoEditorStopMotionFramesPerImageLabel =>
      'Mga frame kada larawan';

  @override
  String videoEditorStopMotionFramesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count frame',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorStopMotionFramesPerImageButtonLabel => 'Mga frame';

  @override
  String videoEditorStopMotionFramesPerImageValueSemanticLabel(int count) {
    return '$count na frame kada larawan';
  }

  @override
  String videoEditorStopMotionFrameSemanticLabel(int position, int total) {
    return 'Stop-motion frame $position ng $total';
  }

  @override
  String get videoEditorEditLabel => 'I-edit';

  @override
  String get videoEditorEditSelectedItemSemanticLabel =>
      'I-edit ang napiling item';

  @override
  String get videoEditorDuplicateLabel => 'I-duplicate';

  @override
  String get videoEditorDuplicateSelectedItemSemanticLabel =>
      'I-duplicate ang napiling item';

  @override
  String get videoEditorCombineLabel => 'Pagsamahin';

  @override
  String get videoEditorCombineDrawLayersSemanticLabel =>
      'Pagsamahin ang mga napiling drawing sa isang layer';

  @override
  String get videoEditorSplitLabel => 'I-split';

  @override
  String get videoEditorSplitSelectedClipSemanticLabel =>
      'I-split ang napiling clip';

  @override
  String get videoEditorExtractAudioLabel => 'I-extract ang Audio';

  @override
  String get videoEditorClipAudioTitle => 'Audio ng clip';

  @override
  String get videoEditorExtractAudioFromClipSemanticLabel =>
      'I-extract ang audio mula sa clip at i-mute ang orihinal';

  @override
  String get videoEditorExtractAudioNoLocalFile =>
      'Hindi ma-extract ang audio: hindi available ang clip nang lokal.';

  @override
  String get videoEditorExtractAudioFailed =>
      'Hindi na-extract ang audio. Pakisubukang muli.';

  @override
  String get videoEditorSpeedLabel => 'Bilis';

  @override
  String get videoEditorSetClipSpeedSemanticLabel =>
      'Itakda ang bilis ng playback para sa napiling clip';

  @override
  String get videoEditorReverseLabel => 'Baligtad';

  @override
  String get videoEditorReverseClipSemanticLabel =>
      'I-toggle ang pabalik na pagpapalaro para sa napiling clip';

  @override
  String get videoEditorReverseProgressLabel =>
      'Sandali lang, nirereverse namin ang clip mo';

  @override
  String get videoEditorTransformLabel => 'I-transform';

  @override
  String get videoEditorTransformSelectedClipSemanticLabel =>
      'I-crop, i-rotate, o i-flip ang napiling clip';

  @override
  String get videoEditorTransformProgressLabel =>
      'Sandali, tina-transform namin ang iyong clip';

  @override
  String get videoEditorTransformFailed =>
      'Hindi ma-transform ang clip. Pakisubukang muli.';

  @override
  String get videoEditorTransformNoLocalFile =>
      'Hindi ma-transform: hindi available nang lokal ang clip.';

  @override
  String get videoEditorTransformSelectedFrameSemanticLabel =>
      'I-crop, i-rotate, o i-flip ang napiling frame';

  @override
  String get videoEditorTransformFrameProgressLabel =>
      'Sandali lang, tina-transform namin ang frame mo';

  @override
  String get videoEditorTransformFrameFailed =>
      'Hindi ma-transform ang frame. Subukan ulit.';

  @override
  String get videoEditorTransformRotateLabel => 'I-rotate';

  @override
  String get videoEditorTransformFlipLabel => 'I-flip';

  @override
  String get videoEditorTransformResetLabel => 'I-reset';

  @override
  String get videoEditorTransformApplySemanticLabel => 'Ilapat ang transform';

  @override
  String get videoEditorTransformCancelSemanticLabel =>
      'Kanselahin ang transform';

  @override
  String get videoEditorTransformPlayLabel => 'I-play';

  @override
  String get videoEditorTransformPauseLabel => 'I-pause';

  @override
  String get videoEditorReverseNoLocalFile =>
      'Hindi ma-reverse: hindi available ang clip nang lokal.';

  @override
  String get videoEditorReverseFailed =>
      'Hindi na-reverse ang clip. Pakisubukang muli.';

  @override
  String get videoEditorSpeedSheetTitle => 'Bilis ng Clip';

  @override
  String get videoEditorTransitionSheetTitle => 'Transisyon';

  @override
  String get videoEditorTransitionNone => 'Wala';

  @override
  String get videoEditorTransitionDissolve => 'Dissolve';

  @override
  String get videoEditorTransitionFadeToBlack => 'Pagkupas sa itim';

  @override
  String get videoEditorTransitionFadeToWhite => 'Pagkupas sa puti';

  @override
  String get videoEditorTransitionSlide => 'Pag-slide';

  @override
  String get videoEditorTransitionPush => 'Pagtulak';

  @override
  String get videoEditorTransitionWipe => 'Pagpunas';

  @override
  String get videoEditorTransitionButtonSemanticLabel =>
      'I-edit ang transisyon';

  @override
  String get videoEditorLoopTransitionSheetTitle => 'Transisyon ng loop';

  @override
  String get videoEditorLoopTransitionButtonSemanticLabel =>
      'I-edit ang transisyon ng loop';

  @override
  String get videoEditorTransitionDuration => 'Tagal';

  @override
  String get videoEditorTransitionDurationLimitedHint =>
      'Pinaikli para hindi mag-overlap sa katabing transition.';

  @override
  String get videoEditorTransitionCurve => 'Kurba';

  @override
  String get videoEditorTransitionDirection => 'Direksyon';

  @override
  String get videoEditorTransitionDirectionLeft => 'Kaliwa';

  @override
  String get videoEditorTransitionDirectionRight => 'Kanan';

  @override
  String get videoEditorTransitionDirectionUp => 'Pataas';

  @override
  String get videoEditorTransitionDirectionDown => 'Pababa';

  @override
  String videoEditorTransitionCurveOptionSemanticLabel(int number) {
    return 'Kurba ng animation $number';
  }

  @override
  String get videoEditorLayerAnimationLabel => 'Animation';

  @override
  String get videoEditorLayerAnimationButtonSemanticLabel =>
      'I-edit ang animation ng layer';

  @override
  String get videoEditorLayerAnimationEnter => 'Pasok';

  @override
  String get videoEditorLayerAnimationLeave => 'Labas';

  @override
  String get videoEditorLayerAnimationFade => 'Fade';

  @override
  String get videoEditorLayerAnimationScale => 'Scale';

  @override
  String get videoEditorLayerAnimationScaleFrom => 'Scale mula sa';

  @override
  String get videoEditorFinishTimelineEditingSemanticLabel =>
      'Tapusin ang pag-edit ng timeline';

  @override
  String get videoEditorAudioPlayPreviewSemanticLabel => 'I-play ang preview';

  @override
  String get videoEditorAudioPausePreviewSemanticLabel => 'I-pause ang preview';

  @override
  String get videoEditorAudioUntitledSound => 'Walang pamagat na sound';

  @override
  String get videoEditorAudioUntitled => 'Walang Pamagat';

  @override
  String get videoEditorAudioAddAudio => 'Magdagdag ng audio';

  @override
  String get videoEditorAudioNoSoundsAvailableTitle =>
      'Walang available na sound';

  @override
  String get videoEditorAudioNoSoundsAvailableSubtitle =>
      'Lalabas dito ang mga sound kapag may share ang mga creator ng audio';

  @override
  String get videoEditorAudioFailedToLoadTitle => 'Hindi na-load ang mga sound';

  @override
  String get videoEditorAudioSegmentInstruction =>
      'Piliin ang audio segment para sa video mo';

  @override
  String get videoEditorAudioCategoryDivine => 'Divine';

  @override
  String get videoEditorAudioCategoryCommunity => 'Community';

  @override
  String get videoEditorAudioCategoryFeatured => 'Itinatampok';

  @override
  String get videoEditorAudioCategoryMySounds => 'Mga Sound Ko';

  @override
  String get videoEditorDrawToolArrowSemanticLabel => 'Tool na arrow';

  @override
  String get videoEditorDrawToolEraserSemanticLabel => 'Tool na pambura';

  @override
  String get videoEditorDrawToolMarkerSemanticLabel => 'Tool na marker';

  @override
  String get videoEditorDrawToolPencilSemanticLabel => 'Tool na lapis';

  @override
  String get videoEditorShowTimelineSemanticLabel => 'Ipakita ang timeline';

  @override
  String get videoEditorHideTimelineSemanticLabel => 'Itago ang timeline';

  @override
  String get videoEditorFeedPreviewContent =>
      'Iwasan ang paglalagay ng content sa likod ng mga area na ito.';

  @override
  String get videoEditorStickersDivineOriginals => 'Divine Originals';

  @override
  String get videoEditorStickerSearchHint => 'Maghanap ng mga sticker...';

  @override
  String get videoEditorSelectFontSemanticLabel => 'Pumili ng font';

  @override
  String get videoEditorFontUnknown => 'Hindi alam';

  @override
  String get videoEditorSplitPlayheadOutsideClip =>
      'Dapat nasa loob ng napiling clip ang playhead para mag-split.';

  @override
  String get videoEditorTimelineTrimStartSemanticLabel => 'I-trim ang simula';

  @override
  String get videoEditorTimelineTrimEndSemanticLabel => 'I-trim ang dulo';

  @override
  String get videoEditorTimelineTrimClipSemanticLabel => 'I-trim ang clip';

  @override
  String get videoEditorTimelineTrimClipHint =>
      'I-drag ang mga handle para i-adjust ang haba ng clip';

  @override
  String videoEditorTimelineDraggingClipSemanticLabel(int index) {
    return 'Dina-drag ang clip $index';
  }

  @override
  String videoEditorTimelineClipSemanticLabel(
    int index,
    int total,
    String duration,
  ) {
    return 'Clip $index sa $total, $duration segundo';
  }

  @override
  String get videoEditorTimelineClipReorderHint =>
      'Pindutin nang matagal para mag-reorder';

  @override
  String get videoEditorTimelineClipMoveLeft => 'Ilipat sa kaliwa';

  @override
  String get videoEditorTimelineClipMoveRight => 'Ilipat sa kanan';

  @override
  String videoEditorTimelineClipSelectedSemanticLabel(int index, int total) {
    return 'Clip $index ng $total, napili';
  }

  @override
  String videoEditorTimelineClipUnselectedSemanticLabel(int index, int total) {
    return 'Clip $index ng $total, hindi napili';
  }

  @override
  String get videoEditorMultiSelectLabel => 'Pumili';

  @override
  String get videoEditorMultiSelectSemanticLabel => 'Pumili ng maraming clip';

  @override
  String get videoEditorMultiSelectDoneSemanticLabel => 'Tapusin ang pagpili';

  @override
  String videoEditorMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clip ang napili',
      one: '$count clip ang napili',
      zero: 'Walang napiling clip',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorLayerMultiSelectSemanticLabel =>
      'Pumili ng maraming drawing';

  @override
  String get videoEditorLayerMultiSelectDoneSemanticLabel =>
      'Tapos nang pumili ng mga drawing';

  @override
  String get videoEditorDeleteSelectedDrawingsSemanticLabel =>
      'Burahin ang mga napiling drawing';

  @override
  String videoEditorLayerMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count drawing ang napili',
      one: '$count drawing ang napili',
      zero: 'Walang napiling drawing',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorMergeLabel => 'Pagsamahin';

  @override
  String get videoEditorMergeSelectedClipsSemanticLabel =>
      'Pagsamahin ang mga napiling clip';

  @override
  String get videoEditorDeleteSelectedClipsSemanticLabel =>
      'Tanggalin ang mga napiling clip';

  @override
  String get videoEditorDeleteSelectedFramesSemanticLabel =>
      'Tanggalin ang mga napiling frame';

  @override
  String get videoEditorReverseSelectedFramesSemanticLabel =>
      'Baligtarin ang mga napiling frame';

  @override
  String get videoEditorDuplicateSelectedFramesSemanticLabel =>
      'I-duplicate ang mga napiling frame';

  @override
  String videoEditorStopMotionTooShortSnackbar(int seconds) {
    return 'Kailangang hindi bababa sa $seconds segundo ang video mo — kumuha pa ng ilang frame.';
  }

  @override
  String get videoEditorMergeProgressLabel =>
      'Sandali lang, pinagsasama namin ang iyong mga clip';

  @override
  String get videoEditorMergeFailed =>
      'Hindi mapagsama ang mga clip. Pakisubukang muli.';

  @override
  String get videoEditorTimelineLongPressToDragHint =>
      'Pindutin nang matagal para i-drag';

  @override
  String get videoEditorVideoTimelineSemanticLabel => 'Timeline ng video';

  @override
  String videoEditorTimelinePositionFormat(int minutes, String seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String videoEditorColorSelectedSemanticLabel(String colorName) {
    return '$colorName, napili';
  }

  @override
  String get videoEditorCloseColorPickerSemanticLabel =>
      'Isara ang color picker';

  @override
  String get videoEditorPickColorTitle => 'Pumili ng kulay';

  @override
  String get videoEditorConfirmColorSemanticLabel => 'Kumpirmahin ang kulay';

  @override
  String get videoEditorSaturationBrightnessSemanticLabel =>
      'Saturation at brightness';

  @override
  String videoEditorSaturationBrightnessValue(int saturation, int brightness) {
    return 'Saturation $saturation%, Brightness $brightness%';
  }

  @override
  String get videoEditorHueSemanticLabel => 'Hue';

  @override
  String get videoEditorAddElementSemanticLabel => 'Magdagdag ng element';

  @override
  String get videoEditorDoneSemanticLabel => 'Tapos na';

  @override
  String get videoEditorLevelSemanticLabel => 'Antas';

  @override
  String get videoMetadataClosePostDetailsSemanticLabel =>
      'Isara ang mga detalye ng post';

  @override
  String get videoMetadataDismissHelpDialogSemanticLabel =>
      'I-dismiss ang help dialog';

  @override
  String get videoMetadataGotItButton => 'Sige na!';

  @override
  String get videoMetadataLimitReachedWarning =>
      'Naabot na ang 64KB limit. Mag-alis ng content para magpatuloy.';

  @override
  String get videoMetadataExpirationLabel => 'Pag-expire';

  @override
  String get videoMetadataSelectExpirationSemanticLabel =>
      'Piliin ang oras ng pag-expire';

  @override
  String get videoMetadataTitleLabel => 'Pamagat';

  @override
  String get videoMetadataDescriptionLabel => 'Deskripsyon';

  @override
  String get videoMetadataTagsLabel => 'Mga Tag';

  @override
  String videoMetadataDeleteTagHint(String tag) {
    return 'Burahin ang Tag $tag';
  }

  @override
  String get videoMetadataContentWarningLabel => 'Babala sa Content';

  @override
  String get videoMetadataSelectContentWarningsSemanticLabel =>
      'Pumili ng mga content warning';

  @override
  String get videoMetadataContentWarningSelectAllThatApply =>
      'Piliin lahat ng tumutugma sa content mo';

  @override
  String get videoMetadataAudioReuseSubtitle =>
      'Hayaan ang iba na i-save at gamitin ulit ang audio ng video na ito.';

  @override
  String get publishAudioReuseDegradedWarning =>
      'Nakalabas na ang video mo, pero hindi na-publish ang sound. I-edit ang video para maibahagi ito.';

  @override
  String get videoMetadataCollaboratorsLabel => 'Mga Collaborator';

  @override
  String get videoMetadataAddCollaboratorSemanticLabel =>
      'Mag-imbita ng collaborator';

  @override
  String get videoMetadataMutualFollowersSearchText => 'Mga mutual follower';

  @override
  String get videoMetadataInspiredByLabel => 'Inspirado mula sa';

  @override
  String get videoMetadataSetInspiredBySemanticLabel =>
      'Itakda ang inspirado mula sa';

  @override
  String get videoMetadataCreatorCannotBeReferencedSnackbar =>
      'Hindi pwedeng i-reference ang creator na ito.';

  @override
  String get videoMetadataPostDetailsTitle => 'Mga detalye ng post';

  @override
  String get videoMetadataSavedToLibrarySnackbar => 'Na-save sa library';

  @override
  String get videoMetadataFailedToSaveSnackbar => 'Hindi na-save';

  @override
  String get videoMetadataGoToLibraryButton => 'Pumunta sa Library';

  @override
  String get videoMetadataSaveForLaterSemanticLabel =>
      'Button na i-save para mamaya';

  @override
  String get videoMetadataSavingVideoHint => 'Sine-save ang video...';

  @override
  String videoMetadataSaveToDraftsHint(String destination) {
    return 'I-save ang video sa drafts at $destination';
  }

  @override
  String videoMetadataSaveToDraftsWithoutGalleryHint(String destination) {
    return 'I-save ang video sa mga draft. Wala pang na-render na video, kaya walang kopyang idadagdag sa $destination.';
  }

  @override
  String get videoMetadataSaveForLaterButton => 'I-save Para Mamaya';

  @override
  String get videoMetadataPostSemanticLabel => 'Button na mag-post';

  @override
  String get videoMetadataPublishVideoHint => 'I-publish ang video sa feed';

  @override
  String get videoMetadataShareReplyToFeedTitle => 'Ibahagi rin sa feed ko';

  @override
  String get videoMetadataShareReplyToFeedSubtitle =>
      'Kapag naka-off, sa thread lang ng komento mananatili ang video na ito.';

  @override
  String get videoMetadataFormNotReadyHint => 'Punan ang form para ma-enable';

  @override
  String get videoMetadataPostButton => 'I-post';

  @override
  String get videoMetadataOpenPreviewSemanticLabel =>
      'Buksan ang post preview screen';

  @override
  String get videoMetadataShareTitle => 'I-share';

  @override
  String get videoMetadataVideoDetailsSubtitle => 'Mga detalye ng video';

  @override
  String get videoMetadataClassicDoneButton => 'Tapos na';

  @override
  String get videoMetadataPlayPreviewSemanticLabel => 'I-play ang preview';

  @override
  String get videoMetadataPausePreviewSemanticLabel => 'I-pause ang preview';

  @override
  String get videoMetadataClosePreviewSemanticLabel =>
      'Isara ang video preview';

  @override
  String get videoMetadataRemoveSemanticLabel => 'Alisin';

  @override
  String get fullscreenFeedRemovedMessage => 'Naalis ang video';

  @override
  String get fullscreenFeedEmptyMessage => 'Wala nang matutugtog dito';

  @override
  String get settingsBadgesTitle => 'Mga Badge';

  @override
  String get settingsBadgesSubtitle =>
      'Tanggapin ang mga award at tingnan ang status ng issued badge.';

  @override
  String get badgesTitle => 'Mga Badge';

  @override
  String get badgesLoadError => 'Hindi na-load ang mga badge';

  @override
  String get badgesUpdateError => 'Hindi na-update ang badge';

  @override
  String get badgesAwardedEmptyTitle => 'Wala pang badge award';

  @override
  String get badgesAwardedEmptySubtitle =>
      'Kapag may nag-award sa iyo ng Nostr badge, lalabas ito dito.';

  @override
  String get badgesStatusAccepted => 'Tinanggap';

  @override
  String get badgesStatusNotAccepted => 'Hindi tinanggap';

  @override
  String get badgesActionRemove => 'Alisin';

  @override
  String get badgesActionAccept => 'Tanggapin';

  @override
  String get badgesActionReject => 'Tanggihan';

  @override
  String get badgesIssuedEmptyTitle => 'Wala ka pang issued badge';

  @override
  String get badgesIssuedEmptySubtitle =>
      'Lalabas dito ang acceptance status ng mga badge na ini-issue mo.';

  @override
  String get badgesIssuedNoRecipients =>
      'Walang nakitang recipient para sa award na ito.';

  @override
  String get badgesRecipientAcceptedStatus => 'Tinanggap ng recipient';

  @override
  String get badgesRecipientWaitingStatus => 'Naghihintay ng recipient';

  @override
  String badgesHiddenSectionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Nakatago ($count)',
      one: 'Nakatago ($count)',
    );
    return '$_temp0';
  }

  @override
  String get badgesActionRestore => 'Ibalik';

  @override
  String get badgesHiddenSnackbar => 'Nakatago ang badge';

  @override
  String get badgesHiddenSnackbarUndo => 'I-undo';

  @override
  String get badgesTabAwarded => 'Natanggap';

  @override
  String get badgesTabCreated => 'Ginawa';

  @override
  String get badgesTabIssued => 'Naibigay';

  @override
  String get badgesCreateAction => 'Bagong badge';

  @override
  String get badgesCreatedEmptyTitle => 'Wala ka pang gawang badge';

  @override
  String get badgesCreatedEmptySubtitle =>
      'Gumawa ng isa at ibigay sa taong karapat-dapat.';

  @override
  String badgesCreatedAwardSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Naibigay sa $count tao',
      one: 'Naibigay sa $count tao',
      zero: 'Hindi pa naibibigay',
    );
    return '$_temp0';
  }

  @override
  String get badgeEditorCreateTitle => 'Bagong badge';

  @override
  String get badgeEditorEditTitle => 'I-edit ang badge';

  @override
  String get badgeEditorNameLabel => 'Pangalan';

  @override
  String get badgeEditorNameHint => 'Nangunguha ng Eksena';

  @override
  String get badgeEditorIdentifierLabel => 'Identifier';

  @override
  String get badgeEditorIdentifierHelp =>
      'Bahagi ito ng address ng badge, kaya hindi na ito nagbabago kapag umiiral na ang badge.';

  @override
  String get badgeEditorIdentifierTaken =>
      'May badge ka nang ganitong identifier. I-edit na lang iyon — kung mag-publish ka rito, mapapalitan iyon.';

  @override
  String get badgeEditorIdentifierRequired =>
      'Kailangan ng bawat badge ng identifier — mag-type ka kung hindi ito napunan ng pangalan.';

  @override
  String get badgeEditorDescriptionLabel => 'Paglalarawan';

  @override
  String get badgeEditorDescriptionHint =>
      'Para sa nangunguha ng eksena sa isang loop lang.';

  @override
  String get badgeEditorArtworkLabel => 'Artwork';

  @override
  String get badgeEditorArtworkAdd => 'Magdagdag ng artwork';

  @override
  String get badgeEditorArtworkReplace => 'Palitan';

  @override
  String get badgeEditorArtworkError => 'Hindi na-upload ang larawang iyon';

  @override
  String get badgeEditorArtworkRequired =>
      'Kailangan ng artwork ang bawat badge.';

  @override
  String get badgeEditorArtworkRemove => 'Alisin ang artwork';

  @override
  String get badgeEditorArtworkSheetTitle => 'Artwork ng badge';

  @override
  String get badgeDetailDeleteAction => 'Burahin ang badge';

  @override
  String get badgeDetailDeleteTitle => 'Burahin ang badge na ito?';

  @override
  String get badgeDetailDeleteBody =>
      'Hinihiling nito sa mga relay na tanggalin ang badge at lahat ng ibinigay mo. Puwedeng tumanggi ang mga relay, at mananatili ito sa profile ng nag-pin hangga\'t hindi nila inaalis.';

  @override
  String get badgeDetailDeleteConfirm => 'Burahin';

  @override
  String get badgeEditorSaveAction => 'I-publish ang badge';

  @override
  String get badgeEditorSaveError => 'Hindi na-publish ang badge';

  @override
  String get badgeEditorLoadError => 'Hindi na-load ang badge na ito';

  @override
  String get badgeDetailTitle => 'Badge';

  @override
  String get badgeDetailMadeBy => 'Ginawa ni';

  @override
  String get badgeDetailRecipientsTitle => 'Naibigay kay';

  @override
  String get badgeDetailNoRecipients => 'Wala pang may hawak nito.';

  @override
  String get badgeDetailAwardAction => 'Ibigay ang badge na ito';

  @override
  String get badgeDetailEditAction => 'I-edit ang badge';

  @override
  String get badgeDetailShareAction => 'Ibahagi';

  @override
  String badgeDetailShareMessage(String link) {
    return 'Tingnan ang badge na ito sa Divine: $link';
  }

  @override
  String get badgeDetailRevokeAction => 'Bawiin ang badge';

  @override
  String get badgeDetailRevokeTitle => 'Bawiin ang badge na ito?';

  @override
  String get badgeDetailRevokeBody =>
      'Hinihiling nito sa mga relay na tanggalin ang ibinigay mo sa taong ito. Puwedeng tumanggi ang mga relay, at kung na-pin na nila ang badge, mananatili ito sa profile nila hangga\'t hindi nila inaalis. Alinman doon, hindi sila sasabihan.';

  @override
  String get badgeDetailRevokeSelfBody =>
      'Hinihiling nito sa mga relay na tanggalin ang ibinigay mo sa sarili mo, at inaalis ang badge sa profile mo. Kung tumanggi ang mga relay sa pagtanggal, walang mababago.';

  @override
  String get badgeDetailRevokeConfirm => 'Bawiin';

  @override
  String get badgeDetailRevokeSuccess => 'Nabawi ang badge';

  @override
  String get badgeDetailBlockClaimantsAction =>
      'I-block ang nag-claim ng badge';

  @override
  String get badgeDetailBlockClaimantsTitle => 'I-block ang claimants ng badge';

  @override
  String get badgeDetailBlockClaimantsLoadError =>
      'Hindi ma-load ang nag-claim ng badge na ito';

  @override
  String get badgeDetailBlockClaimantsEmptyTitle =>
      'Walang nag-claim ng badge na ito ngayon';

  @override
  String get badgeDetailBlockClaimantsEmptyBody =>
      'Wala kaming nahanap na kasalukuyang claimants na iba-block.';

  @override
  String badgeDetailBlockClaimantsHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'I-block ang $count claimants?',
      one: 'I-block ang $count claimant?',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Iba-block nito ang $count account na kasalukuyang nag-claim ng badge na ito. Mawawala ang posts nila sa feeds mo, at hindi sila aabisuhan.',
      one:
          'Iba-block nito ang account na kasalukuyang nag-claim ng badge na ito. Mawawala ang posts nila sa feeds mo, at hindi sila aabisuhan.',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'I-block ang $count account',
      one: 'I-block ang $count account',
    );
    return '$_temp0';
  }

  @override
  String get badgeDetailBlockClaimantsSuccess => 'Na-block ang badge claimants';

  @override
  String get badgeDetailBlockClaimantsFailure =>
      'Hindi ma-block ang badge claimants';

  @override
  String get badgeDetailLoadError => 'Hindi na-load ang badge na ito';

  @override
  String get badgeDetailMissing =>
      'Hindi namin makita ang badge na ito sa kahit anong relay.';

  @override
  String get badgeDetailActionError => 'Hindi ito natuloy';

  @override
  String get badgeAwardTitle => 'Magbigay ng badge';

  @override
  String get badgeAwardPickAction => 'Pumili ng tao';

  @override
  String get badgeAwardManualLabel => 'O mag-paste ng mga key';

  @override
  String get badgeAwardManualHint => 'npub1…, npub1…';

  @override
  String get badgeAwardEmptyHint => 'Pumili ng kahit isang tao.';

  @override
  String badgeAwardSubmitAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ibigay sa $count tao',
      one: 'Ibigay sa $count tao',
      zero: 'Ibigay ang badge',
    );
    return '$_temp0';
  }

  @override
  String get profileBadgeAwardedBy => 'Ibinigay ni';

  @override
  String get profileBadgeRecipients => 'Mga tumanggap';

  @override
  String profileBadgeMoreRecipients(int count) {
    return '+$count pa';
  }

  @override
  String profileBadgeSemanticLabel(String name) {
    return 'Badge na $name';
  }

  @override
  String get profileBadgeFallbackSemanticLabel => 'Badge';

  @override
  String get profileBadgeFooterBody =>
      'Ang mga badge ay maliliit na parangal na kahit sino ay puwedeng gumawa sa Nostr. Bigyan ang isang kaibigan, isang creator, o kung sino man ang nagpasaya sa araw mo.';

  @override
  String get profileBadgeFooterLink => 'Gumawa ng sarili mong badge';

  @override
  String get minorAccountReviewWelcomePageTitle => 'Gabay para sa pamilya';

  @override
  String get minorAccountReviewWelcomeTitle => 'Hindi ka pa 16? Ayos lang.';

  @override
  String get minorAccountReviewWelcomeBody =>
      'Ang pag-click mo papunta sa page na ito imbes na piliin na lang ang sagot na magpapapasok sa iyo ay may halaga. Ipinapakita nitong tapat ka, may tapang, at totoong may malasakit sa mga tao sa paligid mo.\n\nMagkakaiba ang mga panuntunan para sa mga wala pang 16 depende sa kung saan ka nakatira. Sa Divine, gusto naming pag-usapan ito nang sama-sama ng pamilya at magpasya kung ano ang malusog na paggamit ng social media.';

  @override
  String get minorAccountReviewModerationTitle =>
      'May isa pang hakbang na kailangan';

  @override
  String get minorAccountReviewModerationBody =>
      'Hiniling sa amin na tingnang mabuti ang account na ito dahil maaaring pag-aari ito ng wala pang 16 taong gulang. Pinapanatiling pribado ng daloy na ito ang mga susunod na hakbang at itinuturo ang tamang landas para sa edad mo.';

  @override
  String get minorAccountReviewRulesTitle =>
      'Hindi pare-pareho ang mga patakaran sa bawat lugar';

  @override
  String get minorAccountReviewRulesBody =>
      'Magkaiba ang pagtingin ng mga bansa at rehiyon sa paggamit ng social media ng mga teenager. Kaya hinihiling namin sa mga pamilya na dahan-dahan muna, tingnan ang mga katotohanan, at pumili nang sabay ng susunod na hakbang.';

  @override
  String get minorAccountReviewApproachTitle =>
      'Ganito ito tinitingnan ng Divine';

  @override
  String get minorAccountReviewApproachBody =>
      'Naniniwala kaming nagmumula ang malusog na ugali sa teknolohiya sa paghinto, pagninilay, at paglilipat ng atensyon sa mas magagandang bagay — hindi sa panunubaybay sa mga bata o sa pagiging bantay ng mga magulang. Sinusuportahan din ito ng pananaliksik.';

  @override
  String get minorAccountReviewLearnMoreTitle => 'Higit pa para sa mga pamilya';

  @override
  String get minorAccountReviewKidsPolicyCta =>
      'Basahin ang patakaran ng Divine para sa mga bata';

  @override
  String get minorAccountReviewChooseAgeBandTitle =>
      'Piliin ang landas na bagay sa iyo';

  @override
  String get minorAccountReviewUnder13Cta => 'Wala pang 13';

  @override
  String get minorAccountReviewTeenCta => 'Edad 13-15';

  @override
  String get minorAccountReviewFamilyResourcesBody =>
      'Bisitahin ang gabay ng Divine para sa pamilya para sa mga praktikal na tip, kagamitan sa pag-uusap, at materyales na tumutulong sa mga teenager na gumamit ng social media nang mas ligtas.';

  @override
  String get minorAccountReviewFamilyResourcesCta =>
      'Kunin ang mga gabay at tip para sa pamilya';

  @override
  String get minorAccountReviewFooter =>
      'Kung 16 ka na o mas matanda at napunta ka rito nang hindi sinasadya, kontakin ang Divine support para may totoong tao na tumingin dito.';

  @override
  String get minorAccountReviewTitle => 'Pagsusuri ng account';

  @override
  String get minorAccountReviewCheckingStatusTitle =>
      'Sinusuri ang status ng account...';

  @override
  String get minorAccountReviewCheckingStatusBody =>
      'Maghintay habang kinukumpirma namin ang kasalukuyang status ng pagsusuri sa account na ito.';

  @override
  String get minorAccountReviewDefaultTitle =>
      'Kailangan ng pagsusuri ng account';

  @override
  String get minorAccountReviewDefaultBody =>
      'Kailangan naming suriin ang account na ito bago ito makagamit ng Divine nang normal.';

  @override
  String minorAccountReviewCaseId(String caseId) {
    return 'Case ID: $caseId';
  }

  @override
  String get minorAccountReviewCaseIdShortLabel => 'Case ID';

  @override
  String get minorAccountReviewRestrictionsTitle =>
      'Ano ang naka-restrict ngayon';

  @override
  String get minorAccountReviewRestrictionPosting =>
      'Naka-pause ang pag-post at pag-publish';

  @override
  String get minorAccountReviewRestrictionEngagement =>
      'Naka-pause ang mga komento, like, repost, at pag-follow';

  @override
  String get minorAccountReviewRestrictionMessaging =>
      'Naka-pause ang pagsisimula o pagsagot sa mga karaniwang mensahe';

  @override
  String get minorAccountReviewRestrictionSupport =>
      'Available pa rin ang support at ang moderation message mo';

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
  String get minorAccountReviewOpenSupportCenter => 'Buksan ang support center';

  @override
  String get minorAccountReviewOpenModerationMessage =>
      'Buksan ang moderation message';

  @override
  String get minorAccountReviewOpenReviewPage => 'Buksan ang review page';

  @override
  String get minorAccountReviewCheckAgain => 'Suriin ulit';

  @override
  String get minorAccountReviewLogOut => 'Mag-log out';

  @override
  String get minorAccountReviewNextStepTitle => 'Susunod na hakbang';

  @override
  String get minorAccountReviewNextStepBody =>
      'Buksan ang support center o ang moderation message mo kung kailangan mo ng tulong sa pagsusuring ito.';

  @override
  String get minorAccountReviewInProgressTitle => 'Isinasagawa ang pagsusuri';

  @override
  String get minorAccountReviewInProgressBody =>
      'Nasa amin na ang kailangan sa ngayon. Sinusuri ng team namin ang kasong ito bago ibalik ang normal na access sa account.';

  @override
  String get minorAccountReviewUnder13Title => 'Mga account na wala pang 13';

  @override
  String minorAccountReviewUnder13Body(String supportEmail) {
    return 'Kung ang account na ito ay pag-aari ng wala pang 13 taong gulang, kailangang mag-email ang magulang o tagapag-alaga sa $supportEmail at isama ang case ID.';
  }

  @override
  String get minorAccountReviewUnder13PublicTitle =>
      'Hindi ka pa namin mabibigyan ng account';

  @override
  String get minorAccountReviewUnder13PublicBody =>
      'Hindi ginawa ang Divine para sa mga batang wala pang 13, at nakatali ang kamay namin sa mga patakaran sa social media sa buong mundo.\n\nMaraming bagay sa internet ang nagtutulak sa iyong magsinungaling para makuha ang gusto mo, at ayaw na ayaw namin iyon. Maling aral iyon sa buhay, at hindi namin iyon ituturo sa iyo dito.';

  @override
  String get minorAccountReviewUnder13FamilyTitle =>
      'Ano ang pwedeng gawin ng pamilya mo sa halip';

  @override
  String get minorAccountReviewUnder13FamilyBody =>
      'Pwedeng ang magulang o tagapag-alaga ang may hawak ng account at siyang mag-post, at pwedeng-pwede kang lumabas sa mga video kasama nila. Gusto naming ma-enjoy ng mga pamilya ang Divine sa paraang bagay sa kanila.';

  @override
  String get minorAccountReviewUnder13ComeBackTitle => 'Kapag naging 13 ka na';

  @override
  String get minorAccountReviewUnder13ComeBackBody =>
      'Depende sa mga patakaran sa lugar mo, baka pwede kang bumalik at mag-apply ng sarili mong account. Kung 13 hanggang 15 ka noon, kakailanganin mo ng pahintulot ng magulang o tagapag-alaga.';

  @override
  String get minorAccountReviewUnder13HonestyTitle =>
      'Bakit hindi ka namin sasabihang mag-back na lang';

  @override
  String get minorAccountReviewUnder13HonestyBody =>
      'Maraming bahagi ng internet ang naka-set up para gantimpalaan ang mga taong nagsasabi ng kahit ano para makapasok. Sa tingin namin, hindi iyon maganda. Oo, puwede kang bumalik at sabihing mas matanda ka kaysa sa totoong edad mo, pero hindi iyon tapat, at hindi ka namin tuturuang magsinungaling para makuha ang gusto mo.';

  @override
  String get minorAccountReviewUnder13LegalBody =>
      'Sinusubukan naming tulungan ang mga kabataan na gamitin ang Divine sa mga paraang malusog at positibo para sa kanila at sa mga tao sa paligid nila. Kailangan din naming sumunod sa mga batas na magkakaiba sa iba\'t ibang lugar. Kaya, kung wala ka pang 13, ang sagot ay hindi ka pa maaaring magkaroon ng sarili mong account sa ngayon.';

  @override
  String get minorAccountReviewTeenBody =>
      'Kung ang account na ito ay pag-aari ng 13 hanggang 15 taong gulang, gamitin ang moderation message o ang support para sundin ang mga tagubilin sa pahintulot ng magulang.';

  @override
  String get minorAccountReviewParentConsentTitle =>
      'Kung ang account ay mapupunta sa 13 hanggang 15 taong gulang';

  @override
  String get minorAccountReviewParentConsentBody =>
      'Dapat mag-email ang magulang o tagapag-alaga sa Divine support kasama ang maikling pribadong video. Susuriin ito ng team namin at tutulong sa mga susunod na hakbang.\n\nKung hindi posibleng makontak ang magulang o tagapag-alaga o kung maglalagay ito sa panganib ng kahit sino, mag-email sa Divine support at sabihin sa amin.';

  @override
  String get minorAccountReviewParentConsentPauseNote =>
      'Pansamantalang paghinto lang ito habang sinusuri ng Divine support team ang video. Kapag naaprubahan, gagabayan ka nila sa pag-set up ng bagong account.';

  @override
  String get minorAccountReviewParentConsentHonestyTitle =>
      'Bakit hinihiling namin na masangkot ang isang magulang o guardian';

  @override
  String get minorAccountReviewParentConsentHonestyBody =>
      'Kailangang sumunod ng Divine sa mga batas na may kinalaman sa edad sa buong mundo. Alam din namin na karamihan sa mga technical age gate ay hindi perpekto. Sa halip na magpanggap na walang mga panuntunan o na cool ang magsinungaling tungkol sa edad, gusto namin na ang mga teen at pamilya ay gumawa ng maingat na desisyon kung paano pinakamainam na gamitin ang Divine. Kaya naman, para sa mga 13-15 taong gulang, hinihiling namin na maging bahagi ang mga magulang sa proseso ng paggawa ng account.';

  @override
  String get minorAccountReviewParentConsentLegalBody =>
      'Kailangan din naming sumunod sa batas, at magkakaiba ang mga panuntunang iyon depende sa kung saan nakatira ang isang tao. Kaya sa halip na magpanggap na walang mga panuntunan, hinihiling namin na maging bahagi ng proseso ang isang magulang o guardian.';

  @override
  String get minorAccountReviewParentConsentChecklist =>
      'Ano ang dapat ipakita ng video';

  @override
  String get minorAccountReviewParentConsentChecklistKid =>
      'Ang teenager sa video';

  @override
  String get minorAccountReviewParentConsentChecklistPermission =>
      'Isang magulang o tagapag-alaga na nagsasalita sa harap ng camera';

  @override
  String get minorAccountReviewParentConsentChecklistAgeBand =>
      'Malinaw na pahayag na ang teenager ay 13 hanggang 15 at may pahintulot gumamit ng Divine';

  @override
  String get minorAccountReviewParentConsentChecklistSupervision =>
      'Malinaw na pahayag na alam ng magulang o tagapag-alaga ang account at babantayan nila ang paggamit nito';

  @override
  String get minorAccountReviewParentConsentPrivacy => 'Paano ito ipadala';

  @override
  String get minorAccountReviewParentConsentNeverPost =>
      'Ilakip ang video kapag nag-email ka sa Divine support';

  @override
  String get minorAccountReviewParentConsentDoNotSave =>
      'Panatilihing pribado ang video at huwag itong i-post sa app';

  @override
  String get minorAccountReviewParentConsentOneMove =>
      'Susuriin ito ng team namin at sasagot kami ng mga susunod na hakbang';

  @override
  String get minorAccountReviewParentConsentEmailCta =>
      'Mag-email sa Divine support';

  @override
  String get minorAccountReviewParentConsentEmailSubject =>
      'Tulong sa pagsusuri ng Divine Greenlight (edad 13-15)';

  @override
  String get minorAccountReviewParentConsentEmailBody =>
      'Kumusta Divine support,\n\nnakikipag-ugnayan ako tungkol sa Divine Greenlight para sa isang teenager na 13-15 taong gulang.\n\nNaglakip ako ng maikli at pribadong video na nagpapakita ng:\n- ang teenager\n- isang magulang o tagapag-alaga na nagsasalita sa harap ng camera\n- na may pahintulot ang teenager na gumamit ng Divine\n- na alam ng magulang o tagapag-alaga ang account at babantayan nila ang paggamit nito\n\nBansang tinitirhan:\n\nKaragdagang impormasyon:\n\nSalamat.';

  @override
  String get minorAccountReviewParentSupportInstructions =>
      'Mga tagubilin sa support para sa magulang';

  @override
  String get minorAccountReviewContinue => 'Magpatuloy';

  @override
  String get minorAccountReviewErrorTitle =>
      'Hindi namin na-load ang status ng pagsusuri sa account mo.';

  @override
  String get minorAccountReviewErrorBody => 'Subukan ulit mamaya.';

  @override
  String get minorAccountReviewTryAgain => 'Subukan ulit';

  @override
  String get minorAccountReviewParentContactTitle => 'Kontak ng magulang';

  @override
  String get minorAccountReviewParentContactHeading =>
      'Magdagdag ng email ng magulang o tagapag-alaga';

  @override
  String minorAccountReviewParentContactBody(String caseId) {
    return 'Gagamitin namin ang address na ito para sa pagsusuri ng pahintulot ng magulang sa kaso $caseId.';
  }

  @override
  String get minorAccountReviewParentContactFieldLabel =>
      'Email ng magulang o tagapag-alaga';

  @override
  String get minorAccountReviewSubmitting => 'Ipinapadala...';

  @override
  String get minorAccountReviewSubmitEmail => 'Ipadala ang email';

  @override
  String get minorAccountReviewBackToReview =>
      'Bumalik sa pagsusuri ng account';

  @override
  String get minorAccountReviewSubmissionReceivedTitle => 'Naipadala ang email';

  @override
  String minorAccountReviewSubmissionReceivedBody(String email) {
    return 'Isinumite namin ang $email para suriin. Mag-e-email kami sa address na ito para kumpirmahin. Kapag sumagot na ang magulang o tagapag-alaga mo, tutuloy na ang kaso mo. Gamitin ang Suriin ulit sa screen ng pagsusuri ng account para sa mga update.';
  }

  @override
  String get minorAccountReviewSubmissionReceivedLocalBody =>
      'Natanggap namin ang kontak ng magulang o tagapag-alaga para sa account na ito. Susuriin ito ng team namin bago ibalik ang access.';

  @override
  String get minorAccountReviewMissingCase =>
      'Wala kaming nakitang aktibong kaso ng pagsusuri para sa account na ito.';

  @override
  String get minorAccountReviewParentContactError =>
      'Hindi naipadala ang email ng magulang. Subukan ulit.';

  @override
  String get minorAccountReviewUnder13SupportTitle =>
      'Support para sa magulang';

  @override
  String get minorAccountReviewUnder13Heading =>
      'Kailangang makipag-ugnayan sa Divine ang magulang o tagapag-alaga';

  @override
  String get minorAccountReviewUnder13SupportBody =>
      'Para sa mga account na malamang wala pang 13, ang susunod na hakbang ay pakikipag-ugnayan ng magulang o tagapag-alaga sa pamamagitan ng email.';

  @override
  String get minorAccountReviewSupportEmailLabel => 'Email ng support';

  @override
  String get minorAccountReviewCopySupportEmail =>
      'Kopyahin ang email ng support';

  @override
  String get minorAccountReviewSupportEmailCopied =>
      'Nakopya ang email ng support';

  @override
  String get minorAccountReviewCopyCaseId => 'Kopyahin ang case ID';

  @override
  String get minorAccountReviewCaseIdCopied => 'Nakopya ang case ID';

  @override
  String get minorAccountReviewUnavailable => 'Hindi available';

  @override
  String get minorAccountReviewUnder13Instructions =>
      'Hilingin sa magulang o tagapag-alaga na isama ang case ID at ipaliwanag na nakikipag-ugnayan sila sa Divine tungkol sa pagsusuring ito ng account.';

  @override
  String minorAccountReviewUnder13EmailSubject(String caseId) {
    return 'Pagsusuri ng account na wala pang 13 para sa kaso $caseId';
  }

  @override
  String minorAccountReviewUnder13EmailBody(String caseId) {
    return 'Kumusta Divine support,\n\nako ang magulang o tagapag-alaga ng batang wala pang 13 taong gulang at nakikipag-ugnayan ako tungkol sa kaso ng pagsusuri ng account na $caseId.\n\nSalamat.';
  }

  @override
  String get devOptionsMinorReviewSimulationTitle =>
      'Simulasyon ng pagsusuri ng account ng menor de edad';

  @override
  String get devOptionsMinorReviewCurrentStateLabel => 'Kasalukuyang status';

  @override
  String devOptionsMinorReviewStateRestricted(String state) {
    return 'Naka-restrict ($state)';
  }

  @override
  String get devOptionsMinorReviewStateActive => 'Aktibo';

  @override
  String get devOptionsMinorReviewStateLoading => 'Nilo-load...';

  @override
  String get devOptionsMinorReviewStateError =>
      'May error sa pag-load ng status';

  @override
  String get devOptionsMinorReviewClearTitle =>
      'I-clear ang simulation override';

  @override
  String get devOptionsMinorReviewClearSubtitle =>
      'Gamitin ulit ang backend o ang default na aktibong status';

  @override
  String get devOptionsMinorReviewTeenTitle =>
      'I-simulate ang kaso ng pagsusuri 13-15';

  @override
  String get devOptionsMinorReviewTeenSubtitle =>
      'Naka-restrict na account na may daan para sa kontak ng magulang';

  @override
  String get devOptionsMinorReviewUnder13Title =>
      'I-simulate ang support case na wala pang 13';

  @override
  String get devOptionsMinorReviewUnder13Subtitle =>
      'Naka-restrict na account na may tagubilin sa email ng magulang lang';

  @override
  String get devOptionsMinorReviewClearedToast =>
      'Na-clear ang simulasyon ng pagsusuri ng account ng menor de edad';

  @override
  String get devOptionsMinorReviewUnder13EnabledToast =>
      'Naka-on ang na-simulate na support case na wala pang 13';

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
      'Simulasyon ng protektadong menor de edad';

  @override
  String get devOptionsProtectedMinorCurrentStateLabel => 'Kasalukuyang status';

  @override
  String get devOptionsProtectedMinorStateProtected =>
      'Protektadong menor de edad (13-15)';

  @override
  String get devOptionsProtectedMinorStateNotProtected => 'Hindi protektado';

  @override
  String get devOptionsProtectedMinorStateLoading => 'Nilo-load…';

  @override
  String get devOptionsProtectedMinorStateError =>
      'May error sa pagbasa ng status';

  @override
  String get devOptionsProtectedMinorOverrideNone =>
      'Walang override (totoong status ng account)';

  @override
  String get devOptionsProtectedMinorOverrideProtected =>
      'Override: piniling protektado';

  @override
  String get devOptionsProtectedMinorOverrideNotProtected =>
      'Override: piniling hindi protektado';

  @override
  String get devOptionsProtectedMinorSimulateTitle =>
      'I-simulate ang protektadong menor de edad (13-15)';

  @override
  String get devOptionsProtectedMinorSimulateSubtitle =>
      'Piliting gamitin ang status na protektadong menor de edad para ma-QA ang mga proteksyon sa #175/#176';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorTitle =>
      'I-simulate ang nasa hustong gulang';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorSubtitle =>
      'Piliting hindi protektado (tahasang hindi, iba sa walang override)';

  @override
  String get devOptionsProtectedMinorClearTitle => 'I-clear ang override';

  @override
  String get devOptionsProtectedMinorClearSubtitle =>
      'Bumalik sa totoong status ng account mula sa Keycast';

  @override
  String get devOptionsProtectedMinorEnabledToast =>
      'Pinilit ang status na protektadong menor de edad';

  @override
  String get devOptionsProtectedMinorNonMinorToast =>
      'Pinatay ang status na protektadong menor de edad';

  @override
  String get devOptionsProtectedMinorClearedToast =>
      'Na-clear ang override na protektadong menor de edad';

  @override
  String get devOptionsInviteAvailabilityTitle =>
      'Mga imbitasyon sa pag-sign up';

  @override
  String get devOptionsInviteAvailabilityCurrentLabel => 'Kasalukuyang status';

  @override
  String get devOptionsInviteAvailabilityServerLoading =>
      'Server value: nilo-load';

  @override
  String get devOptionsInviteAvailabilityServerEnabled =>
      'Server value: naka-on';

  @override
  String get devOptionsInviteAvailabilityServerDisabled =>
      'Server value: naka-off';

  @override
  String get devOptionsInviteAvailabilityServerUnknown =>
      'Server value: hindi alam';

  @override
  String get devOptionsInviteAvailabilityOverrideNone =>
      'Override: gamitin ang server value';

  @override
  String get devOptionsInviteAvailabilityOverrideEnabled =>
      'Override: piliting i-on';

  @override
  String get devOptionsInviteAvailabilityOverrideDisabled =>
      'Override: piliting i-off';

  @override
  String get devOptionsInviteAvailabilityUseServer =>
      'Gamitin ang server value';

  @override
  String get devOptionsInviteAvailabilityUseServerSubtitle =>
      'Sundin ang onboardingMode ng invite service';

  @override
  String get devOptionsInviteAvailabilityForceEnabled => 'Piliting i-on';

  @override
  String get devOptionsInviteAvailabilityForceEnabledSubtitle =>
      'Ipakita nang lokal ang mga gate at pamamahala ng invite sa pag-sign up';

  @override
  String get devOptionsInviteAvailabilityForceDisabled => 'Piliting i-off';

  @override
  String get devOptionsInviteAvailabilityForceDisabledSubtitle =>
      'Itago nang lokal ang invite UI nang hindi binabago ang server';

  @override
  String get devOptionsInviteAvailabilityUseServerToast =>
      'Sumusunod na sa server ang mga imbitasyon sa pag-sign up';

  @override
  String get devOptionsInviteAvailabilityForceEnabledToast =>
      'Pinilit i-on ang mga imbitasyon sa pag-sign up';

  @override
  String get devOptionsInviteAvailabilityForceDisabledToast =>
      'Pinilit i-off ang mga imbitasyon sa pag-sign up';

  @override
  String get commentsRecordVideoButtonLabel => 'Mag-record ng video comment';

  @override
  String get commentsOpenVideoLabel => 'Buksan ang video comment';

  @override
  String get commentsMuteVideoReplyLabel => 'I-mute ang video reply';

  @override
  String get commentsUnmuteVideoReplyLabel => 'I-unmute ang video reply';

  @override
  String get commentsOpenReplyParentLabel =>
      'Buksan ang video na nire-replyan nito';

  @override
  String get commentsReplyParentSectionTitle => 'Reply sa video';

  @override
  String commentsReplyParentLabel(String target) {
    return 'Reply kay $target';
  }

  @override
  String get commentsReplyParentFallbackLabel => 'Reply sa video';

  @override
  String verifiedAccountChipSemanticLabel(String platform, String identity) {
    return 'Na-verify na $platform account: $identity';
  }

  @override
  String get profileEditVerifiedAccountsTitle => 'Mga na-verify na account';

  @override
  String get profileEditGetVerifiedCta => 'Magpa-verify';

  @override
  String get profileEditGetVerifiedSubtitle =>
      'I-link ang iyong mga social media account para malaman ng mga tao na ikaw talaga ito.';

  @override
  String profileWebsiteSemanticLabel(String url) {
    return 'Bisitahin ang website: $url';
  }

  @override
  String get profileCouldNotOpenWebsite => 'Hindi mabuksan ang website';

  @override
  String get videoMetadataEditCoverTitle => 'I-edit ang cover';

  @override
  String get videoMetadataEditCoverCloseSemanticLabel =>
      'I-discard ang mga pagbabago sa cover';

  @override
  String get videoMetadataEditCoverConfirmSemanticLabel =>
      'Gamitin ang napiling frame bilang cover ng video';

  @override
  String get videoMetadataEditCoverStripSemanticLabel =>
      'Mag-seek sa video para pumili ng cover frame';

  @override
  String get videoMetadataTagsPickerSearchHint => 'Maghanap o magdagdag ng tag';

  @override
  String get videoMetadataTagsPickerEmptyHint =>
      'Magdagdag ng tag para matuklasan ang video mo';

  @override
  String get videoMetadataTagsPickerNoResults => 'Walang tugmang tag';

  @override
  String videoMetadataTagsPickerAddTag(String tag) {
    return 'Idagdag ang \"#$tag\"';
  }

  @override
  String get authMinAgeNotice => 'Divine Greenlight';

  @override
  String get authUnder16Prefix => 'Wala pang 16? Okay lang iyon. ';

  @override
  String get authUnder16ChoicesCta => 'Narito ang mga pagpipilian mo.';

  @override
  String get minorAccountReviewUnder13WhyTitle => 'Narito ang dahilan';

  @override
  String get generalSettingsHoldToRecord =>
      'Pindutin nang matagal para mag-record';

  @override
  String get generalSettingsHoldToRecordSubtitle =>
      'Magsisimulang mag-record kapag pinindot nang matagal at titigil kapag inalis';

  @override
  String uploadPublishedCountMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Na-publish na ang $count na video sa profile mo',
      one: 'Na-publish na ang video sa profile mo',
    );
    return '$_temp0';
  }

  @override
  String get dmMessageSendLabel => 'Ipadala ang mensahe';

  @override
  String get emojiPickerSearchHint => 'Maghanap';

  @override
  String get emojiCategoryRecent => 'Kamakailan';

  @override
  String get emojiCategorySmileys => 'Mga Smiley at Tao';

  @override
  String get emojiCategoryAnimals => 'Mga Hayop at Kalikasan';

  @override
  String get emojiCategoryFood => 'Pagkain at Inumin';

  @override
  String get emojiCategoryActivities => 'Mga Aktibidad';

  @override
  String get emojiCategoryTravel => 'Paglalakbay at Mga Lugar';

  @override
  String get emojiCategoryObjects => 'Mga Bagay';

  @override
  String get emojiCategorySymbols => 'Mga Simbolo';

  @override
  String get emojiCategoryFlags => 'Mga Bandila';

  @override
  String get videoEditorMarkerLabel => 'Marker';

  @override
  String get videoEditorAddTimelineMarkerSemanticLabel =>
      'Magdagdag ng marker sa timeline';

  @override
  String get videoEditorRemoveTimelineMarkerSemanticLabel =>
      'Alisin ang marker sa timeline';

  @override
  String get videoEditorRemoveTimelineMarkerAtPlayheadSemanticLabel =>
      'Alisin ang marker sa posisyon ng pagpapatugtog';

  @override
  String get videoEditorDeleteTimelineMarkerTitle => 'Burahin ang marker?';

  @override
  String get videoEditorDeleteTimelineMarkerSubtitle =>
      'Aalisin nito ang marker sa timeline. Mananatili ang iyong edit.';

  @override
  String get videoEditorVolumeLongPressHint =>
      'I-mute o i-unmute ang lahat ng track';

  @override
  String get videoEditorSplitFailed => 'Nabigo ang paghati. Pakisubukan muli.';

  @override
  String get videoEditEditSubtitles => 'I-edit ang subtitles';

  @override
  String get subtitleEditorTitle => 'I-edit ang subtitles';

  @override
  String get subtitleEditorSave => 'I-save';

  @override
  String get subtitleEditorProcessing =>
      'Ginagawa pa ang subtitles. Bumalik ka mamaya.';

  @override
  String get subtitleEditorNoSpeech =>
      'Walang na-detect na salita sa video na ito, kaya walang gagawing subtitle.';

  @override
  String get subtitleEditorWriteOwn => 'Ikaw na ang magsulat';

  @override
  String get subtitleEditorAddCue => 'Magdagdag ng linya';

  @override
  String get subtitleEditorRemoveCue => 'Alisin ang linyang ito';

  @override
  String get subtitleEditorPreviewUnavailable =>
      'Hindi ma-play ang video ngayon, pero pwede mo pa ring ayusin ang mga caption.';

  @override
  String get subtitleEditorPlayPreview => 'I-play ang video';

  @override
  String get subtitleEditorPausePreview => 'I-pause ang video';

  @override
  String get subtitleEditorInvalidHint =>
      'Kailangan ng bawat linya ng teksto at katapusan pagkatapos ng simula.';

  @override
  String get subtitleEditorLoadError =>
      'Hindi ma-load ang subtitles. Subukan ulit.';

  @override
  String get subtitleEditorSaveSuccess => 'Na-update ang subtitles';

  @override
  String get subtitleEditorSaveError =>
      'Hindi ma-save ang subtitles. Subukan ulit.';

  @override
  String get subtitleEditorRetry => 'Subukan ulit';

  @override
  String get subtitleEditorCueHint => 'Text ng caption';

  @override
  String get imageCropEditorRotateLabel => 'Iikot';

  @override
  String get imageCropEditorFlipLabel => 'Baligtarin';

  @override
  String get imageCropEditorResetLabel => 'I-reset';

  @override
  String get imageCropEditorCloseSemanticLabel => 'Kanselahin ang pag-crop';

  @override
  String get imageCropEditorDoneSemanticLabel => 'Ilapat ang pag-crop';

  @override
  String get imageCropEditorProcessing => 'Inilalapat ang pag-crop…';

  @override
  String get backgroundUploadNotificationTitle => 'Ina-upload ang video';

  @override
  String get monetizationSettingsTitle => 'Suporta sa creator';

  @override
  String get monetizationSettingsSubtitle =>
      'Magdagdag ng link para sa tip at subscription';

  @override
  String get monetizationSettingsIntroTitle => 'Mga panlabas na link lang';

  @override
  String get monetizationSettingsIntroBody =>
      'Magdagdag ng mga destinasyong ikaw ang kumokontrol. Hindi kailanman hinahawakan ng Divine ang bayad at hindi nagbubukas ng content sa app ang mga link na ito.';

  @override
  String monetizationSettingsConfiguredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count aktibong link sa profile mo',
      one: '$count aktibong link sa profile mo',
    );
    return '$_temp0';
  }

  @override
  String get monetizationSettingsTipSection => 'Magpadala ng tip';

  @override
  String get monetizationSettingsSubscriptionSection =>
      'Mag-subscribe / sumuporta';

  @override
  String get monetizationSettingsSave => 'I-save ang mga support link';

  @override
  String get monetizationSettingsSaving => 'Sini-save...';

  @override
  String get monetizationSettingsSaved => 'Na-update ang mga support link';

  @override
  String get monetizationSettingsSaveFailed =>
      'Hindi na-save ang mga support link. Tingnan ang koneksyon mo at subukan ulit.';

  @override
  String get monetizationSettingsErrorEmpty => 'Magdagdag ng handle o URL.';

  @override
  String get monetizationSettingsErrorInvalid =>
      'Mukhang mali ang link na iyon.';

  @override
  String get monetizationSettingsErrorWrongProvider =>
      'Gumamit ng link para sa provider na ito.';

  @override
  String get monetizationSettingsHintCashApp => '\$cashtag o cash.app link';

  @override
  String get monetizationSettingsHintPayPal => 'PayPal.me handle o link';

  @override
  String get monetizationSettingsHintVenmo => 'Venmo handle o link';

  @override
  String get monetizationSettingsHintPatreon => 'Patreon handle o link';

  @override
  String get monetizationSettingsHintSubstack => 'Substack domain o link';

  @override
  String get monetizationSettingsHintMedium => 'Medium handle o link';

  @override
  String get monetizationSettingsHintOpenCollective =>
      'Open Collective slug o link';

  @override
  String get profileSupportSheetTitle => 'Suportahan ang creator na ito';

  @override
  String get profileSupportSheetBody =>
      'Bumubukas ang mga link na ito sa labas ng Divine. Walang dito ang nagbubukas ng content sa app.';

  @override
  String get profileSupportTipSection => 'Magpadala ng tip';

  @override
  String get profileSupportSubscriptionSection => 'Mag-subscribe / sumuporta';

  @override
  String get profileSupportButtonLabel => 'Suportahan';

  @override
  String get monetizationTipsSettingsTitle => 'Mga tip';

  @override
  String get monetizationTipsSettingsSubtitle =>
      'Magdagdag ng opsyonal na tip link';

  @override
  String get monetizationTipsSettingsIntroTitle => 'Opsyonal na tip lang';

  @override
  String get monetizationTipsSettingsIntroBody =>
      'Ang tip ay opsyonal na regalo sa pagitan ng mga user. Hindi ito nagbubukas ng content, subscription, feature, ranking, visibility, o access sa Divine.';

  @override
  String monetizationTipsSettingsConfiguredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count aktibong tip link sa profile mo',
      one: '$count aktibong tip link sa profile mo',
    );
    return '$_temp0';
  }

  @override
  String get monetizationTipsSettingsSave => 'I-save ang mga tip link';

  @override
  String get monetizationTipsSettingsSaved => 'Na-update ang mga tip link';

  @override
  String get profileTipButtonLabel => 'Tip';

  @override
  String get profileTipSheetTitle => 'Bigyan ng tip ang creator na ito';

  @override
  String get profileTipSheetBody =>
      'Bumubukas ang mga tip link sa labas ng Divine. Opsyonal ang mga ito at hindi nagbubukas ng content, subscription, feature, o access sa Divine.';

  @override
  String get settingsStorageTitle => 'Storage';

  @override
  String get settingsStorageCacheSectionTitle => 'Naka-cache na media';

  @override
  String get settingsStorageCacheDescription =>
      'Mga naka-cache na video ng feed, thumbnail, at pansamantalang render. Ligtas itong burahin — muli itong made-download o magagawa kapag kailangan.';

  @override
  String get settingsStorageMeasuring => 'Kinokompute…';

  @override
  String settingsStorageCacheInUse(String size) {
    return '$size ang ginagamit';
  }

  @override
  String get settingsStorageClearButton => 'I-clear ang cache';

  @override
  String get settingsStorageClearConfirmTitle =>
      'I-clear ang naka-cache na media?';

  @override
  String settingsStorageClearConfirmMessage(String size) {
    return 'Nagbabakante ito ng $size. Hindi maaapektuhan ang iyong clip library.';
  }

  @override
  String get settingsStorageClearConfirmAction => 'I-clear';

  @override
  String get settingsStorageCleared => 'Na-clear ang cache';

  @override
  String get settingsStorageLibrarySectionTitle => 'Library ng clip';

  @override
  String get settingsStorageLibraryDescription =>
      'Maghanap ng mga sirang clip na nawawala ang video file.';

  @override
  String get settingsStorageScanButton => 'Suriin ang library';

  @override
  String get settingsStorageLibraryHealthy => 'Walang nakitang sirang clip';

  @override
  String settingsStorageBrokenClipsFound(int count) {
    return 'Mga nakitang sirang clip: $count';
  }

  @override
  String get settingsStorageRemoveBrokenButton => 'Alisin ang mga sirang clip';

  @override
  String get settingsStorageBrokenClipsRemoved => 'Naalis ang mga sirang clip';

  @override
  String get settingsStorageError => 'May nangyaring mali';

  @override
  String get settingsStorageMaxVideoCacheLabel =>
      'Pinakamataas na cache ng video';

  @override
  String settingsStorageApproxVideos(int count) {
    return '≈ $count video';
  }

  @override
  String get settingsStorageRemoveBrokenConfirmTitle =>
      'Alisin ang mga sirang clip?';

  @override
  String get settingsStorageRepairSectionTitle => 'Ayusin ang install';

  @override
  String get settingsStorageRepairDescription =>
      'Kung paulit-ulit na nagka-crash o kakaiba ang app, kadalasang nakakatulong ang pag-reset ng lokal na data. Nananatili ang mga clip at draft mo.';

  @override
  String get settingsStorageRepairButton => 'I-reset ang app data';

  @override
  String get settingsStorageRepairConfirmTitle => 'I-reset ang app data?';

  @override
  String get settingsStorageRepairConfirmMessage =>
      'Buburahin nito ang naka-cache na data ng feed at ang mga pansamantalang file. Mananatili ang mga clip, draft, setting at pag-sign in mo, pero kailangan mong i-restart ang app pagkatapos.';

  @override
  String settingsStorageRepairFootprint(String size) {
    return 'Buburahin ang $size';
  }

  @override
  String get settingsStorageRepairConfirmAction => 'I-reset';

  @override
  String get settingsStorageRepairInProgress => 'Nagre-reset…';

  @override
  String get settingsStorageRepairSuccess =>
      'Tapos na — i-restart ang app para makumpleto.';

  @override
  String get settingsStorageRepairFailure =>
      'Hindi lahat ay na-reset. Subukan ulit pagkatapos mag-restart.';

  @override
  String get nostrSettingsSignatureVerification => 'Pag-verify ng lagda';

  @override
  String get nostrSettingsSignatureVerificationIntro =>
      'Piliin kung kailan susuriin ng Divine ang mga lagda ng event mula sa mga relay. Palaging unang bine-validate ang mga event ID.';

  @override
  String get nostrSettingsSignatureVerificationAll => 'Lahat ng relay';

  @override
  String get nostrSettingsSignatureVerificationAllSubtitle =>
      'Pinakaligtas. I-verify ang lagda ng bawat event mula sa relay.';

  @override
  String get nostrSettingsSignatureVerificationUntrusted =>
      'Hindi pinagkakatiwalaang relay';

  @override
  String get nostrSettingsSignatureVerificationUntrustedSubtitle =>
      'Laktawan ang mga pagsusuri para sa mga relay na nasa naka-configure mong pool na.';

  @override
  String get nostrSettingsSignatureVerificationNonDivine =>
      'Mga relay na hindi Divine';

  @override
  String get nostrSettingsSignatureVerificationNonDivineSubtitle =>
      'Pagkatiwalaan ang mga Divine relay, i-verify ang iba.';

  @override
  String get settingsCrosspostingTitle => 'Crossposting';

  @override
  String get settingsCrosspostingSubtitle =>
      'I-share ang mga video mo sa ibang platform';

  @override
  String get crosspostingSignInRequired =>
      'Mag-sign in gamit ang Divine para pamahalaan ang crossposting';

  @override
  String get crosspostingLoadFailed =>
      'Hindi ma-load ang crossposting settings mo';

  @override
  String get crosspostingNoPlatforms =>
      'Walang available na crossposting platform sa ngayon';

  @override
  String get crosspostingRetry => 'Subukan ulit';

  @override
  String get crosspostingNotConnected => 'Hindi konektado';

  @override
  String get crosspostingConnected => 'Konektado';

  @override
  String get crosspostingNeedsReconnect => 'Kailangang i-reconnect';

  @override
  String get crosspostingConnect => 'I-connect';

  @override
  String get crosspostingReconnect => 'I-reconnect';

  @override
  String get crosspostingDisconnect => 'I-disconnect';

  @override
  String get crosspostingModeOff => 'Naka-off';

  @override
  String get crosspostingModeManual => 'Manual';

  @override
  String get crosspostingModeManualSubtitle => 'Ikaw ang pipili sa bawat video';

  @override
  String get crosspostingModeAutomatic => 'Awtomatiko';

  @override
  String get crosspostingModeAutomaticSubtitle =>
      'Awtomatikong napo-post ang mga susunod na video — yung mga na-publish mo lang matapos mong i-on ito';

  @override
  String get crosspostingNotConnectedError =>
      'I-connect muna ang platform na ito para mabago kung paano ito nagpo-post.';

  @override
  String get crosspostingGenericError => 'May nangyaring mali. Subukan ulit.';

  @override
  String get crosspostingCallbackTimeoutError =>
      'Wala kaming natanggap na sagot mula sa sign-in page. Kung natapos mo na doon, i-refresh — baka naka-link na ang account mo.';

  @override
  String crosspostingConnectionSuccess(String platform) {
    return 'Naka-connect na ang $platform';
  }

  @override
  String crosspostingConnectionFailed(String platform) {
    return 'Hindi ma-connect ang $platform';
  }

  @override
  String crosspostingConnectionDenied(String platform) {
    return 'Kinansela ang koneksyon sa $platform';
  }

  @override
  String get supporterTitle => 'Mga Divine Supporter';

  @override
  String get supporterTileSubtitle =>
      'Suportahan ang Divine gamit ang optional na monthly subscription.';

  @override
  String get supporterHeroTitle => 'Panatilihing tumatakbo ang Divine';

  @override
  String get supporterHeroBody =>
      'Libre ang Divine at laging magiging libre. Kung gusto mo kaming tulungang panatilihing umaandar ang mga loop, maging monthly supporter ka. Walang naka-lock — pinapanatili lang nitong bukas ang ilaw at taos-puso kaming nagpapasalamat.';

  @override
  String get supporterActiveBadge =>
      'Isa kang Divine Supporter. Salamat sa pagpapanatili nito.';

  @override
  String get supporterPurchasePending =>
      'Naghihintay ng approval ang purchase mo.';

  @override
  String get supporterPurchaseConfirming => 'Kinukumpirma ang suporta mo…';

  @override
  String get supporterStoreChecking => 'Tinitingnan ang store…';

  @override
  String get supporterUnavailable =>
      'Hindi available ang mga supporter subscription dito ngayon.';

  @override
  String get supporterRestorePurchases => 'I-restore ang mga purchase';

  @override
  String get supporterDismissError => 'I-dismiss ang error';

  @override
  String get supporterErrorStoreUnavailable =>
      'Hindi available ang store sa device na ito.';

  @override
  String get supporterErrorPurchaseFailed =>
      'Hindi natapos ang purchase. Hindi ka siningil.';

  @override
  String get supporterErrorPurchasePending =>
      'Naghihintay ng approval ang purchase mo.';

  @override
  String get supporterErrorRestoreFailed =>
      'Walang nahanap na supporter subscription na puwedeng i-restore.';

  @override
  String get supporterErrorOwnershipConflict =>
      'Ang purchase na ito ay pag-aari ng ibang Divine account.';

  @override
  String get supporterErrorVerificationUnavailable =>
      'Hindi makumpirma ng Divine ang supporter status mo ngayon.';

  @override
  String get supporterErrorUnknown =>
      'May nangyaring problema. Pakisubukan ulit.';

  @override
  String get supporterDisclaimer =>
      'Kinukumpirma ng Divine ang supporter status pagkatapos i-verify ng store ang purchase mo. Optional ang recognition, at hindi verification ang halo.';

  @override
  String get profileNotifyBellOff => 'Ipaalam ang mga bagong vine';

  @override
  String get profileNotifyBellOn => 'Itigil ang pagpaalam sa mga bagong vine';

  @override
  String get profileNotifyUpdateFailed => 'Hindi nai-save. Subukan muli?';

  @override
  String get savedSoundYourLabel => 'Label mo';

  @override
  String get savedSoundAddHashtags => 'Magdagdag ng hashtag';

  @override
  String get savedSoundDeviceOnly => 'Naka-save sa device na ito';

  @override
  String get savedSoundDetailsRetry =>
      'Hindi na-save ang mga detalyeng iyon. I-tap para subukan ulit.';

  @override
  String get savedSoundFallbackTitle => 'Naka-save na sound';

  @override
  String get savedSoundPreviewAction => 'Pakinggan ang sound';

  @override
  String get savedSoundEditAction => 'I-edit ang detalye ng sound';

  @override
  String get savedSoundRemoveAction => 'Alisin ang naka-save na sound';

  @override
  String get savedSoundClearHashtagFilter => 'I-clear ang hashtag filter';

  @override
  String get soundAllowRemix => 'Payagan ang iba na i-remix ang sound na ito';

  @override
  String get soundReuseUnavailable =>
      'Hindi pwedeng i-remix ang sound na ito ngayon.';

  @override
  String get soundPublicCredit => 'Pampublikong credit ng sound';

  @override
  String get soundCreditRequired =>
      'Magdagdag ng pampublikong credit ng sound bago mag-post.';

  @override
  String get soundSharedAs => 'Ibinahagi bilang';

  @override
  String get soundOwnWork => 'Ako ang gumawa ng sound na ito';

  @override
  String soundCreatorBy(String creator) {
    return 'Ni $creator';
  }

  @override
  String soundSharedBy(String publisher) {
    return 'Ibinahagi ni $publisher';
  }

  @override
  String get soundRemixingAllowed => 'Pwedeng i-remix';

  @override
  String get soundCreditOnly => 'Credit lang';

  @override
  String get soundCreditTitleLabel => 'Pamagat ng sound';

  @override
  String get soundCreditCreatorLabel => 'Creator';

  @override
  String get soundCreditSourceUrlLabel => 'URL ng pinagmulan';

  @override
  String get soundCreditPublicHashtagsLabel => 'Pampublikong hashtag';

  @override
  String get videoMetadataTagsPickerCancelSemanticLabel =>
      'Kanselahin ang pagpili ng mga tag';

  @override
  String get videoMetadataTagsPickerConfirmSemanticLabel =>
      'Ilapat ang mga napiling tag';

  @override
  String get userPickerCancelSemanticLabel => 'Kanselahin ang pagpili ng user';

  @override
  String get userPickerConfirmSemanticLabel =>
      'Kumpirmahin ang mga napiling user';

  @override
  String get userPickerClearSelectionSemanticLabel =>
      'I-clear ang pagpili ng user';

  @override
  String get videoMetadataContentWarningsPickerCancelSemanticLabel =>
      'Kanselahin ang pagpili ng mga babala sa content';

  @override
  String get videoMetadataContentWarningsPickerConfirmSemanticLabel =>
      'Ilapat ang mga napiling babala sa content';

  @override
  String get videoEditorCloseEditorSemanticLabel => 'Isara ang video editor';

  @override
  String get videoEditorContinueToPostDetailsSemanticLabel =>
      'Magpatuloy sa mga detalye ng post';

  @override
  String videoEditorDiscardToolChangesSemanticLabel(String tool) {
    return 'I-discard ang mga pagbabago sa $tool';
  }

  @override
  String videoEditorApplyToolChangesSemanticLabel(String tool) {
    return 'Ilapat ang mga pagbabago sa $tool';
  }

  @override
  String get videoEditorRemoveAudioSemanticLabel => 'Alisin ang audio';

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
  String get verifyTitle => 'Mga verified na account';

  @override
  String get verifySignedOutMessage =>
      'Mag-sign in para i-link ang mga account mo.';

  @override
  String get verifyIntro =>
      'I-link ang mga account na meron ka na, para alam nilang ikaw talaga \'to.';

  @override
  String get verifyLoadFailed => 'Hindi ma-load ang mga link mo.';

  @override
  String get verifyRetry => 'Subukan ulit';

  @override
  String get verifyLinkedSectionTitle => 'Naka-link';

  @override
  String get verifyVerifierUnreachable =>
      'Hindi maabot ang verifier, kaya lahat ay lumalabas na hindi pa na-check.';

  @override
  String get verifyAddSectionTitle => 'Magdagdag ng account';

  @override
  String get verifyAllPlatformsLinked =>
      'Na-link mo na lahat ng suportado namin.';

  @override
  String get verifyStatusVerified => 'Na-verify';

  @override
  String get verifyStatusUnverified => 'Hindi verified';

  @override
  String verifyUnlinkSemanticLabel(String platform, String identity) {
    return 'I-unlink ang $platform account na $identity';
  }

  @override
  String verifyUnlinkConfirmTitle(String platform) {
    return 'I-unlink ang $platform?';
  }

  @override
  String verifyUnlinkConfirmSubtitle(String identity) {
    return 'Hindi na lalabas ang $identity sa profile mo. Puwede mo \'tong i-link ulit mamaya, pero kailangan mong mag-sign in o mag-post ng bagong proof.';
  }

  @override
  String get verifyUnlinkConfirmCta => 'I-unlink';

  @override
  String verifyLinkSemanticLabel(String platform) {
    return 'I-link ang $platform account mo';
  }

  @override
  String get verifyOneTapBadge => 'Isang tap';

  @override
  String verifyConnectOauthExplainer(String platform) {
    return 'Mag-sign in sa $platform, kami na bahala sa iba. Walang ipo-post.';
  }

  @override
  String verifyConnectOauthCta(String platform) {
    return 'Magpatuloy gamit ang $platform';
  }

  @override
  String get verifyConnectProofTitle => 'O mag-post ng patunay';

  @override
  String get verifyConnectProofExplainer =>
      'I-post ang npub mo sa account mo, tapos i-paste ang link ng post na \'yon.';

  @override
  String get verifyNpubLabel => 'Ang npub mo';

  @override
  String get verifyCopyNpubSemanticLabel => 'Kopyahin ang npub mo';

  @override
  String get verifyNpubCopied => 'Nakopya ang npub';

  @override
  String get verifyIdentityLabel => 'Pangalan ng account';

  @override
  String get verifyProofLabel => 'Link ng post mo';

  @override
  String get verifyConnectProofCta => 'I-check at i-link';

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
      'Hindi maabot ang verifier. Subukan ulit mamaya.';

  @override
  String get verifyErrorOauthFailed => 'Hindi natuloy. Subukan ulit.';

  @override
  String get verifyErrorHandleRequired => 'Ilagay muna ang handle mo.';

  @override
  String get verifyErrorPublishFailed =>
      'Verified, pero walang relay na tumanggap ng update. Subukan ulit.';

  @override
  String get verifyErrorOauthUnavailable =>
      'Hindi pa naka-set up ang one-tap sign-in dito. Gamitin ang patunay sa ibaba.';

  @override
  String get verifyConnectProofExplainerGithub =>
      'Gumawa ng public gist na nasa unang file ang npub mo, tapos i-paste ang gist link.';

  @override
  String get verifyConnectProofExplainerDiscord =>
      'I-post ang npub mo sa Discord channel na kayang basahin ng bot namin, tapos i-paste ang message link. Walang pinapatunayan ang server invite.';

  @override
  String get verifyConnectProofExplainerTwitter =>
      'I-tweet ang npub mo mula sa account na \'yon, tapos i-paste ang link ng tweet.';

  @override
  String get verifyConnectProofExplainerMastodon =>
      'I-post ang npub mo mula sa account na \'yon, tapos i-paste ang link. Kailangan may instance ang pangalan ng account — mastodon.social/@alice, hindi lang alice.';

  @override
  String get verifyConnectProofExplainerTelegram =>
      'Ang channel ang nali-link, hindi ang Telegram account mo. Kailangan muna nitong may public link (private ang bago sa Telegram). I-post ang npub mo doon at i-paste ang message link.';

  @override
  String get verifyConnectProofExplainerBluesky =>
      'Naka-sign in ka na sa taas? Wala nang kailangan. Kung hindi, i-post ang npub mo at i-paste ang link ng post.';

  @override
  String get verifyConnectProofExplainerTiktok =>
      'Ilagay ang npub mo sa caption ng video, tapos i-paste ang link ng video.';

  @override
  String get verifyConnectProofExplainerYoutube =>
      'Ilagay ang npub mo sa description ng video, tapos i-paste ang link ng video.';

  @override
  String verifyLinkedConfirmation(String platform) {
    return 'Naka-link na ang $platform.';
  }

  @override
  String get verifyErrorTelegramNotPublic =>
      'Private channel \'yan o invite. Bigyan mo ng public link ang channel, tapos i-paste ang message link.';

  @override
  String get verifyErrorRemoveFailed => 'Hindi na-unlink. Subukan ulit.';

  @override
  String get verifyErrorLinksUnreadable =>
      'Hindi namin nabasa ang kasalukuyang mga link mo, kaya walang binago. I-check ang koneksyon mo at subukan ulit.';

  @override
  String get verifyChannelLabel => 'Pangalan ng channel';

  @override
  String get verifyHowItWorksTitle => 'Paano ito gumagana?';

  @override
  String get verifyHowItWorksIntro =>
      'Isipin mo itong parang pagkakamayan ng dalawang account:';

  @override
  String get verifyHowItWorksYourSide =>
      'Sabi ng Divine profile mo: “Ako si @alice sa Twitter.”';

  @override
  String get verifyHowItWorksOtherSide =>
      'Kinukumpirma ng Twitter account mo: “Oo, akin ang Divine profile na \'yan.”';

  @override
  String get verifyHowItWorksBothSides =>
      'Chine-check namin ang dalawang panig. Kung tugma, verified ka na. Walang makakapeke — makokopya ang pangalan at litrato mo, pero hindi sila makakapag-post mula sa totoong account mo.';

  @override
  String get verifyHowItWorksOwnership =>
      'Nasa sarili mong Nostr identity ang mga link, kaya matatanggal mo sila dito anumang oras.';

  @override
  String get generalSettingsSectionIdentity => 'Pagkakakilanlan';

  @override
  String get libraryFilterAll => 'Lahat';

  @override
  String get libraryFilterArchive => 'Archive';

  @override
  String get libraryFilterDeleted => 'Na-delete';

  @override
  String get libraryCategoryNewChipLabel => 'Bago';

  @override
  String get libraryCategoryCreateSemanticLabel => 'Gumawa ng kategorya';

  @override
  String get libraryCategoryCreateTitle => 'Bagong kategorya';

  @override
  String get libraryCategoryCreateAction => 'Gumawa';

  @override
  String get libraryCategoryRenameTitle => 'Palitan ang pangalan ng kategorya';

  @override
  String get libraryCategoryRenameAction => 'Palitan ang pangalan';

  @override
  String get libraryCategoryDeleteAction => 'I-delete ang kategorya';

  @override
  String get libraryCategoryNameLabel => 'Pangalan ng kategorya';

  @override
  String libraryCategoryDeleteConfirmTitle(String name) {
    return 'I-delete ang “$name”?';
  }

  @override
  String get libraryCategoryDeleteConfirmMessage =>
      'Nananatili ang mga clip mo. Babalik lang sila sa Lahat.';

  @override
  String get libraryCategoryManageSemanticLabel =>
      'Palitan ang pangalan o i-delete ang kategoryang ito';

  @override
  String get libraryCategoryMoveTitle => 'Ilipat sa';

  @override
  String get libraryCategoryMoveNone => 'Walang kategorya';

  @override
  String get libraryCategoryMoveNewCategory => 'Bagong kategorya';

  @override
  String get libraryArchiveAction => 'I-archive';

  @override
  String get libraryUnarchiveAction => 'I-unarchive';

  @override
  String libraryArchiveKeepCategoryTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Panatilihin sa mga kategoryang ito?',
      one: 'Panatilihin sa kategoryang ito?',
    );
    return '$_temp0';
  }

  @override
  String libraryArchiveKeepCategoryAction(String name) {
    return 'Panatilihin sa $name';
  }

  @override
  String get libraryArchiveKeepCategoryActionMixed =>
      'Panatilihin sa mga kategorya nila';

  @override
  String libraryArchiveRemoveCategoryAction(String name) {
    return 'Alisin sa $name';
  }

  @override
  String get libraryArchiveRemoveCategoryActionMixed =>
      'Alisin sa mga kategorya nila';

  @override
  String get libraryMoveSelectedClipsTooltip => 'Ilipat ang mga napiling clip';

  @override
  String get libraryCategoryEmptyTitle => 'Wala pa rito';

  @override
  String get libraryCategoryEmptySubtitle =>
      'Pumili ng ilang clip at ilipat sila sa kategoryang ito.';

  @override
  String get libraryArchiveEmptyTitle => 'Walang naka-archive';

  @override
  String get libraryArchiveEmptySubtitle =>
      'Naghihintay dito ang mga naka-archive na clip, hiwalay sa pangunahing library mo.';

  @override
  String libraryClipsMovedToCategory(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clip ang inilipat sa $name',
      one: '$count clip ang inilipat sa $name',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsRemovedFromCategory(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clip ang inalis sa kategorya nila',
      one: '$count clip ang inalis sa kategorya nito',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsArchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clip ang na-archive',
      one: '$count clip ang na-archive',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsUnarchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clip ang bumalik sa library mo',
      one: '$count clip ang bumalik sa library mo',
    );
    return '$_temp0';
  }

  @override
  String get accountSettingsChangeEmail => 'Palitan ang email';

  @override
  String get accountSettingsChangeEmailSubtitle =>
      'Ilipat ang account mo sa ibang address';

  @override
  String get accountSettingsChangePassword => 'Palitan ang password';

  @override
  String get accountSettingsChangePasswordSubtitle =>
      'Pumili ng bagong password para sa pag-sign in';

  @override
  String get accountCredentialsNeedsSignIn =>
      'Nag-expire ang session mo. Mag-sign in ulit para gawin ito.';

  @override
  String get accountCredentialsRateLimited =>
      'Sobrang dami nang subok. Maghintay ng ilang minuto.';

  @override
  String get accountCredentialsNetwork =>
      'Hindi maabot ang Divine. Tingnan ang koneksyon mo at subukan ulit.';

  @override
  String get accountCredentialsUnknown => 'Hindi umubra. Subukan ulit.';

  @override
  String get changePasswordSubtitle =>
      'I-type ang kasalukuyang password, tapos pumili ng bago.';

  @override
  String get changePasswordCurrentLabel => 'Kasalukuyang password';

  @override
  String get changePasswordWrongCurrent =>
      'Hindi \'yan ang kasalukuyang password mo.';

  @override
  String get changePasswordSuccess => 'Napalitan ang password.';

  @override
  String get changeEmailSubtitle =>
      'Magpapadala kami ng confirmation link sa bago mong address at sa nasa account mo. Magbabago ang email mo kapag na-confirm mo pareho.';

  @override
  String changeEmailCurrentAddress(String email) {
    return 'Nasa account mo: $email';
  }

  @override
  String get changeEmailNewLabel => 'Bagong email';

  @override
  String get changeEmailPasswordLabel => 'Ang password mo';

  @override
  String get changeEmailSameAsCurrent => 'Email address mo na \'yan.';

  @override
  String get changeEmailWrongPassword => 'Hindi \'yan ang password mo.';

  @override
  String get changeEmailSubmit => 'Ipadala ang mga confirmation link';

  @override
  String get changeEmailSentTitle => 'Papunta na ang dalawang link';

  @override
  String changeEmailSentMessage(String email) {
    return 'I-confirm mula sa $email at mula sa address na nasa account mo. Magpapalit ang email mo kapag tapos na pareho.';
  }

  @override
  String get changeEmailSentExpiry =>
      'Titigil gumana ang mga link pagkatapos ng 24 oras.';

  @override
  String get changeEmailSentDone => 'Sige';

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
  String get socialProofMutual => 'Mutual';

  @override
  String get socialProofFollowsYou => 'Sinusundan ka';

  @override
  String get socialProofYouFollow => 'Sinusundan mo';

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
      'Hindi nagloload ang mga video ngayon.\nSa amin ito, hindi sa iyo — inaayos na namin.';

  @override
  String get feedOfflineMessage =>
      'Offline ka.\nTingnan ang koneksyon mo at subukan ulit.';

  @override
  String get dbFailureTitle => 'hindi ma-unlock ang iyong lokal na database';

  @override
  String get dbFailureAdviceResettable =>
      'Hindi ito maaayos ng pag-restart. Ang pag-reset ng lokal na database sa ibaba ay nagbibigay sa Divine ng malinis na simula — mananatili ang iyong account.';

  @override
  String get dbFailureAdviceRestart =>
      'I-restart ang Divine matapos i-unlock ang iyong device. Kung patuloy itong nangyayari, i-update ang app o makipag-ugnayan sa suporta.';

  @override
  String get dbFailureAdviceHotJournal =>
      'Subukang i-restart ang Divine nang isang beses. Kung patuloy itong mangyari, i-update ang app o makipag-ugnayan sa support. Nandoon pa rin ang lokal mong data.';

  @override
  String dbFailureDiagnostic(String code) {
    return 'Diagnostic: $code';
  }

  @override
  String get dbFailureCloseApp => 'isara ang Divine';

  @override
  String get dbFailureResetAction => 'i-reset ang lokal na database';

  @override
  String get dbFailureConfirmTitle => 'i-reset ang iyong lokal na database?';

  @override
  String get dbFailureConfirmBody =>
      'Mananatili ang iyong account. Buburahin ang mga draft at clip na naka-save sa device na ito — babalik ang mga mensahe at feed mula sa network.';

  @override
  String get dbFailureResetConfirm => 'i-reset na ang lokal na database';

  @override
  String get dbFailureCancel => 'kanselahin';

  @override
  String get dbFailureResetFailed =>
      'Hindi ito gumana. Isara ang Divine at subukan ulit.';

  @override
  String get dbFailureResetDoneTitle => 'na-reset ang lokal na database';

  @override
  String get dbFailureResetDoneBody =>
      'Isara ang Divine at buksan itong muli — gagawa ng bagong lokal na database sa susunod na paglulunsad.';

  @override
  String get authSignInOptionsInfo => 'Tungkol sa mga opsyon sa pag-sign in';

  @override
  String get authShowPassword => 'Ipakita ang password';

  @override
  String get authHidePassword => 'Itago ang password';

  @override
  String get followUserSemanticLabel => 'Sundan ang user';

  @override
  String get unfollowUserSemanticLabel => 'I-unfollow ang user';

  @override
  String get commentsLoadingSemanticLabel => 'Nilo-load ang mga komento';

  @override
  String get analyticsWindowAll => 'Lahat';

  @override
  String followUserIndexedSemanticLabel(String index) {
    return 'Sundan ang user $index';
  }

  @override
  String unfollowUserIndexedSemanticLabel(String index) {
    return 'I-unfollow ang user $index';
  }

  @override
  String supporterTierMonthlyLabel(String title, String price) {
    return '$title — $price / buwan';
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
  String get updateGentleBanner => 'May bagong update. Tingnan ito →';

  @override
  String get updateModerateTitle => 'May update mula noong huli mong tingnan';

  @override
  String get updateUrgentTitle => 'May mahahalagang pag-aayos na wala ka pa';

  @override
  String get updateNotNow => 'Hindi ngayon';

  @override
  String get updateAction => 'I-update';

  @override
  String updateNewIn(String version) {
    return 'Bago sa $version:';
  }

  @override
  String get settingsUpdateAvailable => 'May update';
}

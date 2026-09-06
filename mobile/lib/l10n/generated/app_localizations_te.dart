// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Telugu (`te`).
class AppLocalizationsTe extends AppLocalizations {
  AppLocalizationsTe([String locale = 'te']) : super(locale);

  @override
  String get devOptionsClipRecovery => 'క్లిప్ రికవరీ';

  @override
  String get devOptionsClipRecoveryDescription =>
      'మరొక ఖాతా క్రింద నిల్వ చేయబడిన రికార్డింగ్‌లను కనుగొంటుంది మరియు వీడియో ఫైల్‌లు ఇకపై ఎంట్రీ రిఫరెన్స్‌లు లేవు.';

  @override
  String get devOptionsClipRecoveryScan => 'స్కాన్';

  @override
  String get devOptionsClipRecoveryFailure => 'క్లిప్ రికవరీ విఫలమైంది';

  @override
  String devOptionsClipRecoveryVisible(int clips, int drafts) {
    String _temp0 = intl.Intl.pluralLogic(
      clips,
      locale: localeName,
      other: '$clipsక్లిప్‌లు',
      one: '$clipsక్లిప్',
    );
    String _temp1 = intl.Intl.pluralLogic(
      drafts,
      locale: localeName,
      other: '$draftsచిత్తుప్రతులు',
      one: '$draftsడ్రాఫ్ట్',
    );
    return 'ఇప్పుడు కనిపిస్తుంది: $_temp0, $_temp1';
  }

  @override
  String get devOptionsClipRecoveryOtherAccounts =>
      'ఇతర ఖాతాల క్రింద దాచబడింది';

  @override
  String devOptionsClipRecoveryCounts(int clips, int drafts) {
    String _temp0 = intl.Intl.pluralLogic(
      clips,
      locale: localeName,
      other: '$clipsక్లిప్‌లు',
      one: '$clipsక్లిప్',
    );
    String _temp1 = intl.Intl.pluralLogic(
      drafts,
      locale: localeName,
      other: '$draftsచిత్తుప్రతులు',
      one: '$draftsడ్రాఫ్ట్',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get devOptionsClipRecoveryClaim => 'ఈ ఖాతాకు తరలించండి';

  @override
  String devOptionsClipRecoveryOrphanFiles(int count, String size) {
    return 'ప్రస్తావించని ఫైల్‌లు: $count ($size)';
  }

  @override
  String get devOptionsClipRecoveryImport => 'లైబ్రరీలో పునర్నిర్మించండి';

  @override
  String get devOptionsClipRecoveryEmpty => 'కోలుకోవడానికి ఏమీ లేదు';

  @override
  String devOptionsClipRecoveryRecovered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'పునరుద్ధరించబడింది $countక్లిప్‌లు',
      one: 'పునరుద్ధరించబడింది $countక్లిప్',
    );
    return '$_temp0';
  }

  @override
  String get devOptionsClipRecoveryCopied => 'రికవరీ నివేదిక కాపీ చేయబడింది';

  @override
  String get devOptionsStorageFootprint => 'నిల్వ పాదముద్ర';

  @override
  String get devOptionsStorageFootprintDescription =>
      'యాప్ వ్రాసే ప్రతి డైరెక్టరీ. కాష్‌లను క్లియర్ చేయడం వల్ల ఇందులో కొంత భాగాన్ని మాత్రమే తిరిగి పొందుతుంది.';

  @override
  String get devOptionsStorageFootprintMeasure => 'కొలత';

  @override
  String devOptionsStorageFootprintTotal(String size) {
    return 'మొత్తం: $size';
  }

  @override
  String get devOptionsStorageFootprintCopied => 'నిల్వ నివేదిక కాపీ చేయబడింది';

  @override
  String get devOptionsStorageFootprintFailure => 'నిల్వను కొలవలేకపోయింది';

  @override
  String get feedTuningMoreLabel => 'ఇలాంటివి మరిన్ని';

  @override
  String get feedTuningLessLabel => 'ఇలాంటివి తక్కువ';

  @override
  String get feedTuningUndo => 'అన్డు';

  @override
  String get dmMessageBubbleVideoReplyHint => 'సూచించబడిన వీడియోను తెరవండి';

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => 'సెట్టింగ్‌లు';

  @override
  String get settingsSecureAccount => 'మీ ఖాతాను సురక్షితం చేసుకోండి';

  @override
  String get settingsSessionExpired => 'సెషన్ గడువు ముగిసింది';

  @override
  String get settingsSessionExpiredSubtitle =>
      'పూర్తి యాక్సెస్‌ని పునరుద్ధరించడానికి మళ్లీ సైన్ ఇన్ చేయండి';

  @override
  String get settingsAccountRestoreFailed => 'ఖాతా పునరుద్ధరణ విఫలమైంది';

  @override
  String get settingsAccountRestoreFailedSwitchMessage =>
      'మేము ఈ పరికరంలో ఆ ఖాతాను అన్‌లాక్ చేయలేకపోయాము. దానిలోకి తిరిగి సైన్ ఇన్ చేయడం అంటే మీరు ఇప్పుడు ఉన్న దాని నుండి సైన్ అవుట్ చేయడం.';

  @override
  String get settingsCreatorAnalytics => 'క్రియేటర్ అనలిటిక్స్';

  @override
  String get settingsSupportCenter => 'మద్దతు కేంద్రం';

  @override
  String get settingsNotifications => 'నోటిఫికేషన్‌లు';

  @override
  String get settingsBlueskyPublishing => 'Bluesky పబ్లిషింగ్';

  @override
  String get settingsBlueskyPublishingSubtitle =>
      'క్రాస్‌పోస్టింగ్‌ని Blueskyకి నిర్వహించండి';

  @override
  String get settingsNostrSettings => 'Nostr సెట్టింగ్‌లు';

  @override
  String get settingsIntegratedApps => 'ఇంటిగ్రేటెడ్ యాప్‌లు';

  @override
  String get settingsIntegratedAppsSubtitle =>
      'Divine లోపల అమలు చేసే ఆమోదించబడిన మూడవ పక్ష యాప్‌లు';

  @override
  String get settingsExperimentalFeatures => 'ప్రయోగాత్మక లక్షణాలు';

  @override
  String get settingsExperimentalFeaturesSubtitle =>
      'ఎక్కిళ్ళు కలిగించే ట్వీక్‌లు—మీకు ఆసక్తి ఉంటే వాటిని ప్రయత్నించండి.';

  @override
  String get settingsLegal => 'చట్టపరమైన';

  @override
  String get settingsIntegrationPermissions => 'ఇంటిగ్రేషన్ అనుమతులు';

  @override
  String get settingsIntegrationPermissionsSubtitle =>
      'గుర్తుంచుకోబడిన ఇంటిగ్రేషన్ ఆమోదాలను సమీక్షించండి మరియు ఉపసంహరించుకోండి';

  @override
  String settingsVersion(String version) {
    return 'వెర్షన్ $version';
  }

  @override
  String get settingsVersionEmpty => 'వెర్షన్';

  @override
  String get settingsDeveloperModeAlreadyEnabled =>
      'డెవలపర్ మోడ్ ఇప్పటికే ప్రారంభించబడింది';

  @override
  String get settingsDeveloperModeEnabled =>
      'డెవలపర్ మోడ్ ప్రారంభించబడింది!\nడెవలపర్ మోడ్‌ని ప్రారంభించడానికి ';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countమరిన్ని నొక్కండి',
      one: '$countమరింత నొక్కండి\nడెవలపర్ మోడ్‌ని ప్రారంభించడానికి ',
    );
    return '$_temp0';
  }

  @override
  String get settingsShareDivine => 'Divineని మీ స్నేహితులతో పంచుకోండి';

  @override
  String get settingsSwitchAccount => 'ఖాతాను మార్చండి';

  @override
  String get settingsAddAnotherAccount => 'మరొక ఖాతాను జోడించండి';

  @override
  String get settingsAccountSwitchFailed =>
      'ఖాతాలను మార్చడం సాధ్యపడలేదు. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get settingsUnsavedDraftsTitle => 'సేవ్ చేయని చిత్తుప్రతులు';

  @override
  String get settingsUploadInProgressTitle => 'అప్‌లోడ్ ప్రోగ్రెస్‌లో ఉంది';

  @override
  String settingsUploadInProgressMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'వీడియోలు',
      one: 'వీడియో',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'వీడియోలు చిత్తుప్రతులుగా ఉంటాయి\nఈ ఖాతాలో ',
      one: 'వీడియో డ్రాఫ్ట్‌గా ఉంటుంది',
    );
    return 'మీకు ఇంకా ఉంది $count $_temp0అప్‌లోడ్ అవుతోంది. ఖాతాలను మార్చడం వలన అప్‌లోడ్ ఆగిపోతుంది — మీ $_temp1.';
  }

  @override
  String settingsUnsavedDraftsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'చిత్తుప్రతులు',
      one: 'డ్రాఫ్ట్',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'చిత్తుప్రతులు',
      one: 'డ్రాఫ్ట్',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'వాటిని\nముందుగా ',
      one: 'అది',
    );
    return 'మీరు కలిగి ఉన్నారు $countసేవ్ చేయబడలేదు $_temp0. ఖాతాలను మార్చడం మీ ఉంచుతుంది $_temp1, కానీ మీరు ప్రచురించవచ్చు లేదా సమీక్షించవచ్చు $_temp2.';
  }

  @override
  String get settingsCancel => 'రద్దు';

  @override
  String get settingsSwitchAnyway => 'ఎలాగైనా మారండి';

  @override
  String get settingsSessionExpiredSwitchMessage =>
      'ఆ ఖాతా సెషన్ అయిపోయింది. దానిలోకి తిరిగి సైన్ ఇన్ చేయడం అంటే మీరు ఇప్పుడు ఉన్న దాని నుండి సైన్ అవుట్ చేయడం.';

  @override
  String get settingsAppVersionLabel => 'యాప్ వెర్షన్';

  @override
  String get settingsAppLanguage => 'యాప్ లాంగ్వేజ్';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language(పరికరం డిఫాల్ట్)';
  }

  @override
  String get settingsAppLanguageTitle => 'యాప్ భాష';

  @override
  String get settingsAppLanguageDescription =>
      'యాప్ ఇంటర్‌ఫేస్ కోసం భాషను ఎంచుకోండి';

  @override
  String get settingsAppLanguageUseDeviceLanguage => 'పరికర భాషను ఉపయోగించండి';

  @override
  String get settingsGeneralTitle => 'సాధారణ సెట్టింగ్‌లు';

  @override
  String get settingsContentSafetyTitle => 'కంటెంట్ & భద్రత';

  @override
  String get generalSettingsSectionIntegrations => 'ఇంటిగ్రేషన్‌లు';

  @override
  String get generalSettingsSectionViewing => 'వీక్షణ';

  @override
  String get generalSettingsSectionCreating => 'సృష్టిస్తోంది';

  @override
  String get generalSettingsSectionApp => 'APP';

  @override
  String get appearanceSettingsTitle => 'స్వరూపం';

  @override
  String get appearanceSettingsSubtitle =>
      'ఈ పరికరంలో Divine ఎలా కనిపిస్తుందో ఎంచుకోండి';

  @override
  String get appearanceSettingsSystem => 'సిస్టమ్ డిఫాల్ట్';

  @override
  String get appearanceSettingsLight => 'కాంతి';

  @override
  String get appearanceSettingsDark => 'చీకటి';

  @override
  String get generalSettingsClosedCaptions => 'సంవృత శీర్షికలు';

  @override
  String get generalSettingsClosedCaptionsSubtitle =>
      'వీడియోలు వాటిని చేర్చినప్పుడు వాటిని చూపండి';

  @override
  String get generalSettingsVideoShapeSquareOnly => 'స్క్వేర్ వీడియోలు మాత్రమే';

  @override
  String get generalSettingsVideoShapeSquareOnlySubtitle =>
      'ఫీడ్‌లను క్లాసిక్ స్క్వేర్ ఫార్మాట్‌లో ఉంచండి';

  @override
  String get contentPreferencesTitle => 'కంటెంట్ ప్రాధాన్యతలు';

  @override
  String get contentPreferencesContentFilters => 'కంటెంట్ ఫిల్టర్‌లు';

  @override
  String get contentPreferencesContentFiltersSubtitle =>
      'కంటెంట్ హెచ్చరిక ఫిల్టర్‌లను నిర్వహించండి';

  @override
  String get contentPreferencesContentLanguage => 'కంటెంట్ భాష';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language(పరికరం డిఫాల్ట్)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      'మీ వీడియోలను భాషతో ట్యాగ్ చేయండి, తద్వారా వీక్షకులు కంటెంట్‌ని ఫిల్టర్ చేయవచ్చు.';

  @override
  String get contentPreferencesUseDeviceLanguage =>
      'పరికర భాషను ఉపయోగించండి (డిఫాల్ట్)';

  @override
  String get contentPreferencesAudioSharing =>
      'పునర్వినియోగం కోసం నా ఆడియోను అందుబాటులో ఉంచు';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      'ప్రారంభించబడినప్పుడు, ఇతరులు మీ వీడియోల నుండి ఆడియోను ఉపయోగించవచ్చు';

  @override
  String get contentPreferencesMusicMode => 'మ్యూజిక్ మోడ్';

  @override
  String get contentPreferencesMusicModeSubtitle =>
      'పరికరాలను చదును చేసే నాయిస్ క్లీనప్‌ను దాటవేస్తుంది. సంగీతానికి ఉత్తమమైనది, స్వరాలకు కఠినమైనది.';

  @override
  String get contentPreferencesAccountLabels => 'ఖాతా లేబుల్‌లు';

  @override
  String get contentPreferencesAccountLabelsEmpty =>
      'మీ కంటెంట్‌ను స్వీయ-లేబుల్ చేయండి';

  @override
  String get contentPreferencesAccountContentLabels => 'ఖాతా కంటెంట్ లేబుల్‌లు';

  @override
  String get contentPreferencesClearAll => 'అన్నింటినీ క్లియర్ చేయండి';

  @override
  String get contentPreferencesSelectAllThatApply =>
      'మీ ఖాతాకు వర్తించే అన్నింటినీ ఎంచుకోండి';

  @override
  String get contentPreferencesDoneNoLabels => 'పూర్తయింది (లేబుల్‌లు లేవు)';

  @override
  String contentPreferencesDoneCount(int count) {
    return 'పూర్తయింది ($countఎంచుకోబడింది)';
  }

  @override
  String get contentPreferencesAudioInputDevice => 'ఆడియో ఇన్‌పుట్ పరికరం';

  @override
  String get contentPreferencesAutoRecommended => 'ఆటో (సిఫార్సు చేయబడింది)';

  @override
  String get contentPreferencesAutoSelectsBest =>
      'ఉత్తమ మైక్రోఫోన్‌ను స్వయంచాలకంగా ఎంపిక చేస్తుంది';

  @override
  String get contentPreferencesSelectAudioInput =>
      'ఆడియో ఇన్‌పుట్‌ని ఎంచుకోండి';

  @override
  String get contentPreferencesUnknownMicrophone => 'తెలియని మైక్రోఫోన్';

  @override
  String get contentFiltersAdultContent => 'పెద్దల కంటెంట్';

  @override
  String get contentFiltersViolenceGore => 'హింస & గోరే';

  @override
  String get contentFiltersSubstances => 'పదార్థాలు';

  @override
  String get contentFiltersOther => 'ఇతర';

  @override
  String get contentFiltersAgeGateMessage =>
      'అడల్ట్ కంటెంట్ ఫిల్టర్‌లను అన్‌లాక్ చేయడానికి భద్రత & గోప్యతా సెట్టింగ్‌లలో మీ వయస్సును ధృవీకరించండి';

  @override
  String get contentFiltersShow => 'చూపించు';

  @override
  String get contentFiltersWarn => 'హెచ్చరించండి';

  @override
  String get contentFiltersFilterOut => 'ఫిల్టర్ అవుట్';

  @override
  String get profileBlockedAccountNotAvailable => 'ఈ ఖాతా అందుబాటులో లేదు';

  @override
  String get profileInvalidId => 'చెల్లని ప్రొఫైల్ ID';

  @override
  String profileShareText(String displayName, String npub) {
    return 'Divineలో $displayNameని చూడండి!\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return 'Divineలో $displayName';
  }

  @override
  String get profileShareFailed =>
      'ప్రొఫైల్‌ను భాగస్వామ్యం చేయడంలో విఫలమైంది. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get profileCopyPublicKey => 'పబ్లిక్ కీని కాపీ చేయండి (npub)';

  @override
  String get profileGetEmbedCode => 'పొందుపరిచిన కోడ్‌ని పొందండి';

  @override
  String get profilePublicKeyCopied =>
      'పబ్లిక్ కీ క్లిప్‌బోర్డ్‌కి కాపీ చేయబడింది';

  @override
  String get profileEmbedCodeCopied =>
      'పొందుపరిచిన కోడ్ క్లిప్‌బోర్డ్‌కి కాపీ చేయబడింది';

  @override
  String get profileMoreTooltip => 'మరిన్ని';

  @override
  String get profileMoreSemanticLabel => 'మరిన్ని ఎంపికలు';

  @override
  String get profileAvatarLightboxBarrierLabel => 'అవతార్‌ను మూసివేయండి';

  @override
  String get profileAvatarLightboxCloseSemanticLabel =>
      'అవతార్ ప్రివ్యూను మూసివేయండి';

  @override
  String get profileFollowingLabel => 'అనుసరిస్తున్నారు';

  @override
  String get profileFollowLabel => 'అనుసరించండి';

  @override
  String get profileBlockedLabel => 'నిరోధించబడింది';

  @override
  String get profileFollowersLabel => 'అనుచరులు';

  @override
  String get profileFollowingStatLabel => 'అనుసరిస్తున్నారు';

  @override
  String get profileVideosLabel => 'వీడియోలు';

  @override
  String get profileCollabsLabel => 'సహకరిస్తుంది';

  @override
  String get profileLikedLabel => 'ఇష్టపడ్డారు';

  @override
  String get profileRepostsLabel => 'రీపోస్ట్‌లు';

  @override
  String get profileListsLabel => 'జాబితాలు';

  @override
  String get profileCommentsLabel => 'వ్యాఖ్యలు';

  @override
  String profileCollaboratorInvitePendingHeadline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countసహకారి ఆహ్వానాలను ఇంకా పంపాలి',
      one: '1 సహకారి ఆహ్వానాన్ని ఇంకా పంపాలి',
    );
    return '$_temp0';
  }

  @override
  String get profileCollaboratorInvitePendingDetail =>
      'మేము ఆహ్వానాన్ని క్యూలో ఉంచాము. ఇక్కడ మళ్లీ ప్రయత్నించండి.';

  @override
  String profileCollaboratorInvitePendingDetailWithTitle(String title) {
    return '\"కోసం$title\". ఇక్కడ మళ్లీ ప్రయత్నించండి.';
  }

  @override
  String get profileCollaboratorInviteRetryAction => 'మళ్లీ ప్రయత్నించండి';

  @override
  String get profileCollaboratorInviteRetryingAction => 'మళ్లీ ప్రయత్నిస్తోంది';

  @override
  String get profileCollaboratorInviteRetryUnavailable =>
      'సహకారి ఆహ్వానం మళ్లీ ప్రయత్నించడం ప్రస్తుతం అందుబాటులో లేదు.';

  @override
  String profileCollaboratorInviteRetryResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countసహకారి ఆహ్వానాలను ఇంకా పంపాలి.',
      one: '1 సహకారి ఆహ్వానాన్ని ఇంకా పంపవలసి ఉంది.',
      zero: 'సహకారి ఆహ్వానాలు పంపబడ్డాయి.',
    );
    return '$_temp0';
  }

  @override
  String profileCollaboratorInviteBlockedResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countసహకారులు ఆహ్వానాలను స్వీకరించలేరు.',
      one: '1 సహకారి ఆహ్వానాలను స్వీకరించలేరు.',
    );
    return '$_temp0';
  }

  @override
  String profileFollowerCountUsers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countవినియోగదారులు',
      one: '$countవినియోగదారు',
    );
    return '$_temp0';
  }

  @override
  String profileBlockTitle(String displayName) {
    return 'బ్లాక్ $displayName?';
  }

  @override
  String get profileBlockExplanation =>
      'మీరు వినియోగదారుని బ్లాక్ చేసినప్పుడు:';

  @override
  String get profileBlockBulletHidePosts =>
      'వారి పోస్ట్‌లు మీ ఫీడ్‌లలో కనిపించవు.';

  @override
  String get profileBlockBulletCantView =>
      'వారు మీ ప్రొఫైల్‌ను వీక్షించలేరు, మిమ్మల్ని అనుసరించలేరు లేదా మీ పోస్ట్‌లను వీక్షించలేరు.';

  @override
  String get profileBlockBulletNoNotify =>
      'ఈ మార్పు గురించి వారికి తెలియజేయబడదు.';

  @override
  String get profileBlockBulletYouCanView =>
      'మీరు ఇప్పటికీ వారి ప్రొఫైల్‌ను వీక్షించగలరు.';

  @override
  String profileBlockConfirmButton(String displayName) {
    return 'బ్లాక్ $displayName';
  }

  @override
  String get profileCancelButton => 'రద్దు';

  @override
  String get profileLearnMore => 'మరింత తెలుసుకోండి';

  @override
  String profileUnblockTitle(String displayName) {
    return 'అన్‌బ్లాక్ చేయండి $displayName?';
  }

  @override
  String get profileUnblockExplanation =>
      'మీరు ఈ వినియోగదారుని అన్‌బ్లాక్ చేసినప్పుడు:';

  @override
  String get profileUnblockBulletShowPosts =>
      'వారి పోస్ట్‌లు మీ ఫీడ్‌లలో కనిపిస్తాయి.';

  @override
  String get profileUnblockBulletCanView =>
      'వారు మీ ప్రొఫైల్‌ను వీక్షించగలరు, మిమ్మల్ని అనుసరించగలరు మరియు మీ పోస్ట్‌లను వీక్షించగలరు.';

  @override
  String get profileUnblockBulletNoNotify =>
      'ఈ మార్పు గురించి వారికి తెలియజేయబడదు.';

  @override
  String get profileLearnMoreAt => 'ఇక్కడ మరింత తెలుసుకోండి ';

  @override
  String get profileUnblockButton => 'అన్‌బ్లాక్ చేయండి';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return 'అనుసరించవద్దు $displayName';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return 'బ్లాక్ $displayName';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return 'అన్‌బ్లాక్ చేయండి $displayName';
  }

  @override
  String profileReportDisplayName(String displayName) {
    return 'నివేదిక $displayName';
  }

  @override
  String profileAddToListDisplayName(String displayName) {
    return 'జోడించండి \nజాబితాకు $displayName';
  }

  @override
  String get profileNoCollabsTitle => 'ఇంకా కొల్లాబ్‌లు లేవు';

  @override
  String get profileCollabsOwnEmpty =>
      'మీరు సహకరించే వీడియోలు ఇక్కడ కనిపిస్తాయి.';

  @override
  String get profileCollabsOtherEmpty =>
      'వారు సహకరించే వీడియోలు ఇక్కడ కనిపిస్తాయి.';

  @override
  String get profileErrorLoadingCollabs =>
      'కొల్లాబ్ వీడియోలను లోడ్ చేయడంలో లోపం';

  @override
  String get profileNoSavedVideosTitle => 'ఇంకా ఏదీ సేవ్ చేయబడలేదు';

  @override
  String get profileSavedOwnEmpty =>
      'షేర్ షీట్ నుండి వీడియోలను బుక్‌మార్క్ చేయండి మరియు అవి ఇక్కడ చూపబడతాయి.';

  @override
  String get profileErrorLoadingSaved =>
      'సేవ్ చేసిన వీడియోలను లోడ్ చేయడంలో లోపం';

  @override
  String get profileNoCommentsOwnTitle => 'ఇంకా వ్యాఖ్యలు లేవు';

  @override
  String get profileNoCommentsOtherTitle => 'ఇంకా వ్యాఖ్యలు లేవు';

  @override
  String get profileCommentsOwnEmpty =>
      'మీ వ్యాఖ్యలు మరియు ప్రత్యుత్తరాలు ఇక్కడ కనిపిస్తాయి.';

  @override
  String get profileCommentsOtherEmpty =>
      'వారి వ్యాఖ్యలు మరియు ప్రత్యుత్తరాలు ఇక్కడ కనిపిస్తాయి.';

  @override
  String get profileErrorLoadingComments => 'వ్యాఖ్యలను లోడ్ చేయడంలో లోపం';

  @override
  String get profileVideoRepliesSection => 'వీడియో ప్రత్యుత్తరాలు';

  @override
  String get profileCommentsSection => 'వ్యాఖ్యలు';

  @override
  String get profileEditLabel => 'సవరించండి';

  @override
  String get profileLibraryLabel => 'లైబ్రరీ';

  @override
  String get profileNoLikedVideosTitle => 'ఇంకా ఇష్టాలు లేవు';

  @override
  String get profileLikedOwnEmpty =>
      'ఏదైనా మీ దృష్టిని ఆకర్షించినప్పుడు, హృదయాన్ని నొక్కండి. మీ ఇష్టాలు ఇక్కడ చూపబడతాయి.';

  @override
  String get profileLikedOtherEmpty =>
      'ఇంకా ఏదీ వారి దృష్టిని ఆకర్షించలేదు. సమయం ఇవ్వండి.';

  @override
  String get profileErrorLoadingLiked => 'ఇష్టపడిన వీడియోలను లోడ్ చేయడంలో లోపం';

  @override
  String get profileNoRepostsTitle => 'ఇంకా రీపోస్ట్‌లు లేవు';

  @override
  String get profileRepostsOwnEmpty =>
      'భాగస్వామ్యం చేయదగినది ఏదైనా చూసారా? దాన్ని మళ్లీ పోస్ట్ చేయండి మరియు అది ఇక్కడ కనిపిస్తుంది.';

  @override
  String get profileRepostsOtherEmpty =>
      'వారు ఇంకా ఏమీ పాస్ చేయలేదు. వారు చేసినప్పుడు, అది ఇక్కడ చూపబడుతుంది.';

  @override
  String get profileErrorLoadingReposts =>
      'రీపోస్ట్ చేసిన వీడియోలను లోడ్ చేయడంలో లోపం';

  @override
  String get profileNoVideosTitle => 'ఇంకా వీడియోలు లేవు';

  @override
  String get profileNoVideosOwnSubtitle =>
      'మీ వేదిక సెట్ చేయబడింది. పోస్ట్ చేయడం ప్రారంభించండి మరియు మీ వీడియోలు ఇక్కడ ప్రత్యక్షమవుతాయి.';

  @override
  String get profileNoVideosOtherSubtitle =>
      'ప్రపంచం ఎదురుచూస్తోంది. వాటిని అనుసరించండి, తద్వారా మీరు దానిని కోల్పోరు.';

  @override
  String profileVideoThumbnailLabel(int number) {
    return 'వీడియో సూక్ష్మచిత్రం $number';
  }

  @override
  String get profileShowMore => 'మరింత చూపించు';

  @override
  String get profileShowLess => 'తక్కువ చూపు';

  @override
  String get dmMessageDisplayLimitReached =>
      'ఈ సందేశంలోని మిగిలిన భాగం చూపబడదు.';

  @override
  String get profileCompleteYourProfile => 'మీ ప్రొఫైల్‌ను పూర్తి చేయండి';

  @override
  String get profileCompleteSubtitle =>
      'ప్రారంభించడానికి మీ పేరు, బయో మరియు చిత్రాన్ని జోడించండి';

  @override
  String get profilePleaseTryAgain => 'దయచేసి మళ్లీ ప్రయత్నించండి';

  @override
  String get profileSecureYourAccount => 'మీ ఖాతాను సురక్షితం చేసుకోండి';

  @override
  String get profileSecureSubtitle =>
      'ఏదైనా పరికరంలో మీ ఖాతాను పునరుద్ధరించడానికి ఇమెయిల్ & పాస్‌వర్డ్‌ను జోడించండి';

  @override
  String get profileRetryButton => 'మళ్లీ ప్రయత్నించండి';

  @override
  String get profileSessionExpired => 'సెషన్ గడువు ముగిసింది';

  @override
  String get profileSignInToRestore =>
      'పూర్తి ప్రాప్యతను పునరుద్ధరించడానికి మళ్లీ సైన్ ఇన్ చేయండి';

  @override
  String get profileSignInButton => 'సైన్ ఇన్ చేయండి';

  @override
  String get profileMaybeLaterLabel => 'బహుశా తర్వాత';

  @override
  String get profileSecurePrimaryButton => 'ఇమెయిల్ & పాస్‌వర్డ్‌ను జోడించండి';

  @override
  String get profileCompletePrimaryButton => 'మీ ప్రొఫైల్‌ను అప్‌డేట్ చేయండి';

  @override
  String get profileLoopsLabel => 'లూప్స్';

  @override
  String get profileLikesLabel => 'ఇష్టాలు';

  @override
  String get profileMyLibraryLabel => 'నా లైబ్రరీ';

  @override
  String get profileMessageLabel => 'సందేశం';

  @override
  String get profileShareLabel => 'ప్రొఫైల్‌ను భాగస్వామ్యం చేయండి';

  @override
  String get profileDeletedAccountName => 'ఖాతా తొలగించబడింది';

  @override
  String get inboxActionReportVanishedAccount => 'ఈ ఖాతాను నివేదించండి';

  @override
  String get inboxActionBlockVanishedAccount => 'ఈ ఖాతాను బ్లాక్ చేయండి';

  @override
  String get inboxActionUnblockVanishedAccount => 'ఈ ఖాతాను అన్‌బ్లాక్ చేయండి';

  @override
  String get inboxReportedVanishedAccount => 'ఈ ఖాతాను నివేదించారు';

  @override
  String get inboxBlockedVanishedAccount => 'ఈ ఖాతాను బ్లాక్ చేసారు';

  @override
  String get inboxUnblockedVanishedAccount => 'ఈ ఖాతాను అన్‌బ్లాక్ చేసారు';

  @override
  String get inboxRemoveConfirmBodyVanishedAccount =>
      'ఇది మీ ఇన్‌బాక్స్ నుండి సంభాషణను తీసివేస్తుంది. వారు మీకు మళ్లీ మెసేజ్ చేస్తే, కొత్త సంభాషణ ప్రారంభమవుతుంది.';

  @override
  String get inboxConversationDeletedAccountSubtitle => 'ఈ ఖాతా తొలగించబడింది';

  @override
  String get profileUserFallback => 'వినియోగదారు';

  @override
  String get profileLinkCopied => 'ప్రొఫైల్ లింక్ కాపీ చేయబడింది';

  @override
  String get profileSetupEditProfileTitle => 'ప్రొఫైల్‌ను సవరించండి';

  @override
  String get nostrSettingsNip05ProfileRequired =>
      'NIP-05 చిరునామాను జోడించే ముందు మీ ప్రొఫైల్‌ను సెటప్ చేయండి.';

  @override
  String get nostrSettingsNip05CreateProfileAction => 'ప్రొఫైల్‌ను సృష్టించండి';

  @override
  String get profileSetupBackLabel => 'వెనుకకు';

  @override
  String get profileSetupAboutNostr => 'Nostr గురించి';

  @override
  String get profileSetupProfilePublished =>
      'ప్రొఫైల్ విజయవంతంగా ప్రచురించబడింది!';

  @override
  String get profileSetupUnsavedChangesTitle => 'మార్పులను సేవ్ చేయాలా?';

  @override
  String get profileSetupUnsavedChangesSubtitle =>
      'నిష్క్రమించే ముందు మీ సవరణలను సేవ్ చేయండి లేదా వాటిని విస్మరించి, కదులుతూ ఉండండి.';

  @override
  String get profileSetupUnsavedChangesSaveButton => 'మార్పులను సేవ్ చేయండి';

  @override
  String get profileSetupUnsavedChangesDiscardButton =>
      'మార్పులను విస్మరించండి';

  @override
  String get profileSetupUnsavedChangesKeepButton => 'ఎడిటింగ్ చేస్తూ ఉండండి';

  @override
  String get profileSetupCreateNewProfile => 'కొత్త ప్రొఫైల్‌ని సృష్టించాలా?';

  @override
  String get profileSetupNoExistingProfile =>
      'మేము మీ రిలేలలో ఇప్పటికే ఉన్న ప్రొఫైల్‌ని కనుగొనలేదు. ప్రచురించడం వలన కొత్త ప్రొఫైల్ సృష్టించబడుతుంది. కొనసాగించాలా?';

  @override
  String get profileSetupPublishButton => 'ప్రచురించండి';

  @override
  String get profileSetupUsernameTaken =>
      'వినియోగదారు పేరు ఇప్పుడే తీసుకోబడింది. దయచేసి మరొకటి ఎంచుకోండి.';

  @override
  String get profileSetupClaimFailed =>
      'వినియోగదారు పేరును క్లెయిమ్ చేయడంలో విఫలమైంది. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get profileSetupPublishFailed =>
      'ప్రొఫైల్‌ను ప్రచురించడంలో విఫలమైంది. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get profileSetupNoRelaysConnected =>
      'నెట్‌వర్క్‌ని చేరుకోవడం సాధ్యపడలేదు. మీ కనెక్షన్‌ని తనిఖీ చేసి, మళ్లీ ప్రయత్నించండి.';

  @override
  String get profileSetupDisplayNameLabel => 'ప్రదర్శన పేరు';

  @override
  String get profileSetupDisplayNameRequired =>
      'దయచేసి ప్రదర్శన పేరును నమోదు చేయండి';

  @override
  String get profileSetupBioLabel => 'బయో (ఐచ్ఛికం)';

  @override
  String get profileSetupWebsiteLabel => 'వెబ్‌సైట్ (ఐచ్ఛికం)';

  @override
  String get profileSetupPublicKeyLabel => 'పబ్లిక్ కీ (npub)';

  @override
  String get profileSetupUsernameLabel => 'వినియోగదారు పేరు (ఐచ్ఛికం)';

  @override
  String get profileSetupUsernameHelper =>
      'అక్షరాలు, సంఖ్యలు లేదా హైఫన్‌లను ఉపయోగించండి. మీ వినియోగదారు పేరు divine.video చిరునామాగా మారుతుంది. ఖాళీలు లేదా చిహ్నాల కోసం మీ ప్రదర్శన పేరును ఉపయోగించండి.';

  @override
  String get profileSetupSaveButton => 'సేవ్ చేయండి';

  @override
  String get profileSetupSavingButton => 'సేవ్ చేస్తోంది...';

  @override
  String get profileSetupImageUrlTitle => 'చిత్రం URLని జోడించండి';

  @override
  String get profileSetupImageSelectionFailed =>
      'చిత్రం ఎంపిక విఫలమైంది. దయచేసి బదులుగా ఒక చిత్ర URLను దిగువన అతికించండి.';

  @override
  String get profileSetupImagesTypeGroup => 'చిత్రాలు';

  @override
  String get cameraPickErrorPermissionDenied =>
      'కెమెరా యాక్సెస్ ఆఫ్ చేయబడింది. ఫోటో తీయడానికి సెట్టింగ్‌లలో దాన్ని ఆన్ చేయండి.';

  @override
  String get cameraPickErrorPermissionRestricted =>
      'ఈ పరికరంలో కెమెరా యాక్సెస్ అనుమతించబడదు.';

  @override
  String get cameraPickErrorBusy =>
      'పికర్ ఇప్పటికే తెరిచి ఉంది. దాన్ని మూసివేసి, మళ్లీ ప్రయత్నించండి.';

  @override
  String get cameraPickErrorGeneric =>
      'కెమెరాను తెరవడం సాధ్యపడలేదు. మళ్లీ ప్రయత్నించండి.';

  @override
  String get profileSetupGotItButton => 'అర్థమైంది';

  @override
  String get profileSetupUploadFailedGeneric =>
      'అప్‌లోడ్ విఫలమైంది. దయచేసి తర్వాత మళ్లీ ప్రయత్నించండి.';

  @override
  String get profileSetupUploadNetworkError =>
      'నెట్‌వర్క్ లోపం: దయచేసి మీ ఇంటర్నెట్ కనెక్షన్‌ని తనిఖీ చేసి, మళ్లీ ప్రయత్నించండి.';

  @override
  String get profileSetupUploadAuthError =>
      'ప్రామాణీకరణ లోపం: దయచేసి లాగ్ అవుట్ చేసి, తిరిగి ప్రవేశించడానికి ప్రయత్నించండి.';

  @override
  String get profileSetupUploadFileTooLarge =>
      'ఫైల్ చాలా పెద్దది: దయచేసి చిన్న చిత్రాన్ని ఎంచుకోండి (గరిష్టంగా 10MB).';

  @override
  String get profileSetupUploadServerError =>
      'అప్‌లోడ్ విఫలమైంది. మా సర్వర్లు తాత్కాలికంగా అందుబాటులో లేవు. దయచేసి ఒక క్షణంలో మళ్లీ ప్రయత్నించండి.';

  @override
  String get profileSetupBannerClearButton => 'బ్యానర్‌ను క్లియర్ చేయండి';

  @override
  String get profileSetupBannerChangeColor => 'బ్యానర్ రంగు';

  @override
  String get profileSetupChangeBannerTitle => 'బ్యానర్‌ని మార్చండి';

  @override
  String get profileSetupBannerColorPickerTitle => 'బ్యానర్ రంగును మార్చండి';

  @override
  String get profileSetupBannerColorCustom => 'కస్టమ్';

  @override
  String get profileSetupBannerColorNone => 'రంగు లేదు';

  @override
  String get profileSetupBannerColorLime => 'సున్నం';

  @override
  String get profileSetupBannerColorYellow => 'పసుపు';

  @override
  String get profileSetupBannerColorViolet => 'వైలెట్';

  @override
  String get profileSetupBannerColorPink => 'పింక్';

  @override
  String get profileSetupBannerColorOrange => 'ఆరెంజ్';

  @override
  String get profileSetupBannerColorPurple => 'పర్పుల్';

  @override
  String get profileSetupAvatarClearButton => 'ఫోటోను తీసివేయండి';

  @override
  String get profileSetupImageTakePhoto => 'ఫోటో తీయండి';

  @override
  String get profileSetupImageUploadFromCameraRoll =>
      'కెమెరా రోల్ నుండి అప్‌లోడ్ చేయండి';

  @override
  String get profileSetupImagePasteLink => 'చిత్రం లింక్‌ను అతికించండి';

  @override
  String get profileSetupEditAvatarLabel => 'ప్రొఫైల్ చిత్రాన్ని సవరించండి';

  @override
  String get profileSetupEditBannerLabel => 'బ్యానర్‌ని సవరించండి';

  @override
  String get profileSetupUsernameChecking => 'లభ్యతను తనిఖీ చేస్తోంది...';

  @override
  String get profileSetupUsernameAvailable =>
      'వినియోగదారు పేరు అందుబాటులో ఉంది!';

  @override
  String get profileSetupUsernameTakenIndicator =>
      'వినియోగదారు పేరు ఇప్పటికే తీసుకోబడింది';

  @override
  String get profileSetupUsernameReserved =>
      'వినియోగదారు పేరు రిజర్వ్ చేయబడింది';

  @override
  String get profileSetupContactSupport => 'మద్దతును సంప్రదించండి';

  @override
  String get profileSetupCheckAgain => 'మళ్లీ తనిఖీ చేయండి';

  @override
  String get profileSetupUsernameBurned =>
      'ఈ వినియోగదారు పేరు ఇప్పుడు అందుబాటులో లేదు';

  @override
  String get profileSetupUsernameInvalidFormat =>
      'అక్షరాలు, సంఖ్యలు మరియు హైఫన్‌లు మాత్రమే అనుమతించబడతాయి';

  @override
  String get profileSetupUsernameInvalidHyphenPlacement =>
      'వినియోగదారు పేరు హైఫన్‌తో ప్రారంభించబడదు లేదా ముగించదు';

  @override
  String get profileSetupUsernameInvalidLength =>
      'వినియోగదారు పేరు తప్పనిసరిగా 3-63 అక్షరాలు ఉండాలి';

  @override
  String get profileSetupUsernameNetworkError =>
      'లభ్యతను తనిఖీ చేయడం సాధ్యపడలేదు. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get profileSetupUsernameInvalidFormatGeneric =>
      'చెల్లని వినియోగదారు పేరు ఫార్మాట్';

  @override
  String get profileSetupUsernameCheckFailed =>
      'లభ్యతను తనిఖీ చేయడంలో విఫలమైంది';

  @override
  String get profileSetupUsernameReservedTitle =>
      'వినియోగదారు పేరు రిజర్వ్ చేయబడింది';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return 'పేరు $usernameరిజర్వ్ చేయబడింది. ఇది ఎందుకు మీదే అవ్వాలో మాకు చెప్పండి.';
  }

  @override
  String get profileSetupUsernameReservedHint =>
      'ఉదా. ఇది నా బ్రాండ్ పేరు, స్టేజ్ పేరు మొదలైనవి.';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      'ఇప్పటికే మద్దతును సంప్రదించారా? ఇది మీకు విడుదల చేయబడిందో లేదో చూడటానికి \"మళ్లీ తనిఖీ చేయి\" నొక్కండి.';

  @override
  String get profileSetupSupportRequestSent =>
      'మద్దతు అభ్యర్థన పంపబడింది! మేము త్వరలో మిమ్మల్ని సంప్రదిస్తాము.';

  @override
  String get profileSetupCouldntOpenEmail =>
      'ఇమెయిల్‌ను తెరవడం సాధ్యపడలేదు. దీనికి పంపండి: names@divine.video';

  @override
  String get profileSetupSendRequest => 'అభ్యర్థన పంపండి';

  @override
  String get profileSetupUseOwnNip05 =>
      'మీ స్వంత NIP-05 చిరునామాను ఉపయోగించండి';

  @override
  String get profileSetupNip05AddressLabel => 'NIP-05 చిరునామా';

  @override
  String get profileSetupExternalNip05InvalidFormat =>
      'చెల్లని NIP-05 ఫార్మాట్ (ఉదా., name@domain.com)';

  @override
  String get profileSetupExternalNip05DivineDomain =>
      'divine.video కోసం ఎగువన ఉన్న వినియోగదారు పేరు ఫీల్డ్‌ని ఉపయోగించండి';

  @override
  String get nostrSettingsNip05Address => 'NIP-05 చిరునామా';

  @override
  String get nostrSettingsNip05AddressSubtitle =>
      'మీ divine.వీడియో వినియోగదారు పేరును ఉపయోగించండి లేదా మీరు నియంత్రించే డొమైన్‌లో NIP-05 చిరునామాలో మీ హ్యాండిల్‌ను సూచించండి.';

  @override
  String get nostrSettingsNip05AddressHint => 'you@example.com';

  @override
  String get nostrSettingsNip05SaveAction => 'సేవ్ NIP-05';

  @override
  String get nostrSettingsNip05Saved => 'NIP-05 సేవ్ చేయబడింది';

  @override
  String get nostrSettingsNip05SaveFailed =>
      'NIP-05ని సేవ్ చేయడం సాధ్యపడలేదు. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get profileSetupNip05ConfirmTitle => 'మీ స్వంత NIP-05ని ఉపయోగించాలా?';

  @override
  String get profileSetupNip05ConfirmBody =>
      'NIP-05 మీ Nostr గుర్తింపుకు you@yourdomain.com వంటి పేరును మ్యాప్ చేస్తుంది. మీరు డొమైన్‌ను నియంత్రించాలి మరియు సరైన మార్గంలో ధృవీకరణ ఫైల్‌ను హోస్ట్ చేయాలి. ఇది తప్పు అయితే, వ్యక్తులు మిమ్మల్ని కనుగొనలేరు మరియు మీ ధృవీకరించబడిన హ్యాండిల్ అదృశ్యమవుతుంది. మీరు దీన్ని సెటప్ చేసి ఉంటే మాత్రమే కొనసాగించండి.';

  @override
  String get profileSetupNip05ConfirmContinue => 'కొనసాగించండి';

  @override
  String get profileSetupNip05ConfirmCancel => 'రద్దు';

  @override
  String get profileSetupProfilePicturePreview => 'ప్రొఫైల్ చిత్ర పరిదృశ్యం';

  @override
  String get nostrInfoIntroBuiltOn => 'Divine Nostrపై నిర్మించబడింది,';

  @override
  String get nostrInfoIntroDescription =>
      'సెన్సార్‌షిప్-నిరోధక ఓపెన్ ప్రోటోకాల్, ఇది ఒకే కంపెనీ లేదా ప్లాట్‌ఫారమ్‌పై ఆధారపడకుండా ఆన్‌లైన్‌లో కమ్యూనికేట్ చేయడానికి వ్యక్తులను అనుమతిస్తుంది. ';

  @override
  String get nostrInfoIntroIdentity =>
      'మీరు Divine కోసం సైన్ అప్ చేసినప్పుడు, మీరు కొత్త Nostr గుర్తింపును పొందుతారు.';

  @override
  String get nostrInfoOwnership =>
      'Nostr మీ కంటెంట్, గుర్తింపు మరియు సామాజిక గ్రాఫ్‌ను మీరు స్వంతం చేసుకోవడానికి అనుమతిస్తుంది, వీటిని మీరు అనేక యాప్‌లలో ఉపయోగించవచ్చు. ఫలితం మరింత ఎంపిక, తక్కువ లాక్-ఇన్ మరియు ఆరోగ్యకరమైన, మరింత స్థితిస్థాపకమైన సామాజిక ఇంటర్నెట్.';

  @override
  String get nostrInfoLingo => 'Nostr లింగో:';

  @override
  String get nostrInfoNpubLabel => 'npub:';

  @override
  String get nostrInfoNpubDescription =>
      'మీ పబ్లిక్ Nostr చిరునామా. ఇది భాగస్వామ్యం చేయడం సురక్షితం మరియు ఇతరులు Nostr యాప్‌లలో మిమ్మల్ని కనుగొనడానికి, అనుసరించడానికి లేదా సందేశం పంపడానికి అనుమతిస్తుంది.';

  @override
  String get nostrInfoNsecLabel => 'nsec:';

  @override
  String get nostrInfoNsecDescription =>
      'మీ ప్రైవేట్ కీ మరియు యాజమాన్య రుజువు. ఇది మీ Nostr గుర్తింపుపై పూర్తి నియంత్రణను ఇస్తుంది, కాబట్టి ';

  @override
  String get nostrInfoNsecWarning => 'దీన్ని ఎల్లప్పుడూ రహస్యంగా ఉంచండి!';

  @override
  String get nostrInfoUsernameLabel => 'Nostr వినియోగదారు పేరు:';

  @override
  String get nostrInfoUsernameDescription =>
      'మీ npubకి లింక్ చేసే మానవులు చదవగలిగే పేరు (@name.divine.video వంటివి). ఇది ఇమెయిల్ చిరునామా మాదిరిగానే మీ Nostr గుర్తింపును గుర్తించడం మరియు ధృవీకరించడం సులభం చేస్తుంది.';

  @override
  String get nostrInfoLearnMoreAt => 'ఇక్కడ మరింత తెలుసుకోండి ';

  @override
  String get nostrInfoGotIt => 'అర్థమైంది!';

  @override
  String get videoGridRefreshLabel => 'మరిన్ని వీడియోల కోసం శోధిస్తోంది';

  @override
  String get videoGridOptionsTitle => 'వీడియో ఎంపికలు';

  @override
  String get videoGridEditVideo => 'వీడియోను సవరించండి';

  @override
  String get videoGridEditVideoSubtitle =>
      'శీర్షిక, వివరణ మరియు హ్యాష్‌ట్యాగ్‌లను నవీకరించండి';

  @override
  String get videoGridDeleteVideo => 'వీడియోని తొలగించండి';

  @override
  String get videoGridDeleteVideoSubtitle =>
      'Divine నుండి ఈ వీడియోని తీసివేయండి. ఇది ఇప్పటికీ ఇతర Nostr క్లయింట్‌లలో కనిపించవచ్చు.';

  @override
  String get videoGridDeletingContent => 'కంటెంట్‌ని తొలగిస్తోంది...';

  @override
  String get exploreTabFeatured => 'ఫీచర్ చేయబడింది';

  @override
  String get exploreTabClassics => 'క్లాసిక్స్';

  @override
  String get exploreTabNew => 'కొత్తది';

  @override
  String get exploreTabPopular => 'జనాదరణ పొందినది';

  @override
  String get exploreTabCategories => 'వర్గాలు';

  @override
  String get exploreTabForYou => 'మీ కోసం';

  @override
  String get exploreTabLists => 'జాబితాలు';

  @override
  String get exploreTabIntegratedApps => 'ఇంటిగ్రేటెడ్ యాప్‌లు';

  @override
  String exploreFeaturedSponsoredBy(String sponsor) {
    return 'ద్వారా స్పాన్సర్ చేయబడింది $sponsor';
  }

  @override
  String exploreFeaturedSponsoredPillSemanticLabel(String name) {
    return '$name, స్పాన్సర్ చేయబడింది';
  }

  @override
  String get featuredTabEmpty =>
      'ఇక్కడ ఇంకా ఏమీ లేదు. త్వరలో తిరిగి తనిఖీ చేయండి.';

  @override
  String get featuredTabLoadFailed => 'ఈ సేకరణను లోడ్ చేయడం సాధ్యపడలేదు.';

  @override
  String get featuredTabRetry => 'మళ్లీ ప్రయత్నించండి';

  @override
  String get exploreNoVideosAvailable => 'వీడియోలు అందుబాటులో లేవు';

  @override
  String get exploreDiscoverLists => 'జాబితాలను కనుగొనండి';

  @override
  String get exploreAboutLists => 'జాబితాల గురించి';

  @override
  String get exploreAboutListsDescription =>
      'జాబితాలు Divine కంటెంట్‌ని రెండు విధాలుగా నిర్వహించడానికి మరియు నిర్వహించడంలో మీకు సహాయపడతాయి:';

  @override
  String get explorePeopleLists => 'వ్యక్తుల జాబితాలు';

  @override
  String get explorePeopleListsDescription =>
      'సృష్టికర్తల సమూహాలను అనుసరించండి మరియు వారి తాజా వీడియోలను చూడండి';

  @override
  String get exploreVideoLists => 'వీడియో జాబితాలు';

  @override
  String get exploreVideoListsDescription =>
      'తర్వాత చూడటానికి మీకు ఇష్టమైన వీడియోల ప్లేజాబితాలను సృష్టించండి';

  @override
  String get exploreMyLists => 'నా జాబితాలు';

  @override
  String get exploreSubscribedLists => 'సభ్యత్వం పొందిన జాబితాలు';

  @override
  String get exploreErrorLoadingLists =>
      'జాబితాలను లోడ్ చేయడంలో లోపం. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countకొత్త వీడియోలు',
      one: '1 కొత్త వీడియో',
    );
    return '$_temp0';
  }

  @override
  String exploreLoadNewVideosLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'వీడియోలు',
      one: 'వీడియో',
    );
    return 'లోడ్ $countకొత్తది $_temp0';
  }

  @override
  String get videoPlayerPlayVideo => 'వీడియోని ప్లే చేయండి';

  @override
  String get videoPlayerMute => 'వీడియోను మ్యూట్ చేయండి';

  @override
  String get videoPlayerUnmute => 'వీడియోను అన్‌మ్యూట్ చేయండి';

  @override
  String get videoPlayerTapHint =>
      'ప్లే చేయడానికి లేదా పాజ్ చేయడానికి నొక్కండి. లైక్ చేయడానికి రెండుసార్లు నొక్కండి.';

  @override
  String get videoSettingsMenuOpen => 'ప్లేబ్యాక్ సెట్టింగ్‌లను తెరవండి';

  @override
  String get videoSettingsMenuClose => 'ప్లేబ్యాక్ సెట్టింగ్‌లను మూసివేయండి';

  @override
  String get videoSettingsCaptionsEnable => 'శీర్షికలను ప్రారంభించండి';

  @override
  String get videoSettingsCaptionsDisable => 'శీర్షికలను నిలిపివేయండి';

  @override
  String get videoSettingsAutoAdvanceOn => 'ఆటో అడ్వాన్స్ ఆన్';

  @override
  String get videoSettingsAutoAdvanceOff => 'ఆటో అడ్వాన్స్ ఆఫ్';

  @override
  String get videoSettingsCaptionsOn => 'శీర్షికలు ఆన్‌లో ఉన్నాయి';

  @override
  String get videoSettingsCaptionsOff => 'శీర్షికలు ఆఫ్';

  @override
  String get videoSettingsCaptionsOnForVideo =>
      'ఈ వీడియో కోసం శీర్షికలు ఆన్‌లో ఉన్నాయి';

  @override
  String get videoSettingsCaptionsOffForVideo =>
      'ఈ వీడియోకు శీర్షికలు ఆఫ్ చేయబడ్డాయి';

  @override
  String get contentWarningLabel => 'కంటెంట్ హెచ్చరిక';

  @override
  String get contentWarningNudity => 'నగ్నత్వం';

  @override
  String get contentWarningSexualContent => 'లైంగిక కంటెంట్';

  @override
  String get contentWarningPornography => 'అశ్లీలత';

  @override
  String get contentWarningGraphicMedia => 'గ్రాఫిక్ మీడియా';

  @override
  String get contentWarningViolence => 'హింస';

  @override
  String get contentWarningSelfHarm => 'స్వీయ-హాని';

  @override
  String get contentWarningDrugUse => 'ఔషధ వినియోగం';

  @override
  String get contentWarningAlcohol => 'మద్యం';

  @override
  String get contentWarningTobacco => 'పొగాకు';

  @override
  String get contentWarningGambling => 'జూదం';

  @override
  String get contentWarningProfanity => 'అసభ్యత';

  @override
  String get contentWarningFlashingLights => 'ఫ్లాషింగ్ లైట్లు';

  @override
  String get contentWarningAiGenerated => 'AI-ఉత్పత్తి';

  @override
  String get contentWarningSpoiler => 'స్పాయిలర్';

  @override
  String get contentWarningSensitiveContent => 'సున్నితమైన కంటెంట్';

  @override
  String get contentWarningDescNudity =>
      'నగ్నత్వం లేదా పాక్షిక నగ్నత్వం కలిగి ఉంటుంది';

  @override
  String get contentWarningDescSexual => 'లైంగిక కంటెంట్‌ను కలిగి ఉంది';

  @override
  String get contentWarningDescPorn => 'స్పష్టమైన అశ్లీల కంటెంట్‌ని కలిగి ఉంది';

  @override
  String get contentWarningDescGraphicMedia =>
      'గ్రాఫిక్ లేదా అవాంతర చిత్రాలను కలిగి ఉంది';

  @override
  String get contentWarningDescViolence => 'హింసాత్మక కంటెంట్‌ని కలిగి ఉంది';

  @override
  String get contentWarningDescSelfHarm => 'స్వీయ-హాని సూచనలను కలిగి ఉంది';

  @override
  String get contentWarningDescDrugs => 'ఔషధ సంబంధిత కంటెంట్‌ని కలిగి ఉంది';

  @override
  String get contentWarningDescAlcohol =>
      'ఆల్కహాల్ సంబంధిత కంటెంట్‌ను కలిగి ఉంది';

  @override
  String get contentWarningDescTobacco =>
      'పొగాకు సంబంధిత కంటెంట్‌ని కలిగి ఉంది';

  @override
  String get contentWarningDescGambling =>
      'జూదానికి సంబంధించిన కంటెంట్‌ను కలిగి ఉంది';

  @override
  String get contentWarningDescProfanity => 'బలమైన భాషను కలిగి ఉంది';

  @override
  String get contentWarningDescFlashingLights =>
      'ఫ్లాషింగ్ లైట్‌లను కలిగి ఉంది (ఫోటోసెన్సిటివిటీ హెచ్చరిక)';

  @override
  String get contentWarningDescAiGenerated =>
      'ఈ కంటెంట్ AI ద్వారా రూపొందించబడింది';

  @override
  String get contentWarningDescSpoiler => 'స్పాయిలర్‌లను కలిగి ఉంటుంది';

  @override
  String get contentWarningDescContentWarning =>
      'సృష్టికర్త దీన్ని సెన్సిటివ్‌గా గుర్తు పెట్టారు';

  @override
  String get contentWarningDescDefault =>
      'సృష్టికర్త ఈ కంటెంట్‌ను ఫ్లాగ్ చేసారు';

  @override
  String get contentWarningDetailsTitle => 'కంటెంట్ హెచ్చరికలు';

  @override
  String get contentWarningDetailsSubtitle =>
      'సృష్టికర్త ఈ లేబుల్‌లను వర్తింపజేశారు:';

  @override
  String get contentWarningManageFilters => 'కంటెంట్ ఫిల్టర్‌లను నిర్వహించండి';

  @override
  String get contentWarningViewAnyway => 'ఏమైనప్పటికీ వీక్షించండి';

  @override
  String get contentWarningReportContentTooltip => 'రిపోర్ట్ కంటెంట్';

  @override
  String get contentWarningBlockUserTooltip => 'వినియోగదారుని నిరోధించండి';

  @override
  String get contentWarningBlockedTitle => 'కంటెంట్ బ్లాక్ చేయబడింది';

  @override
  String get contentWarningBlockedPolicy =>
      'విధాన ఉల్లంఘనల కారణంగా ఈ కంటెంట్ బ్లాక్ చేయబడింది.';

  @override
  String get contentWarningNoticeTitle => 'కంటెంట్ నోటీసు';

  @override
  String get contentWarningPotentiallyHarmfulTitle =>
      'సంభావ్య హానికరమైన కంటెంట్';

  @override
  String get contentWarningView => 'వీక్షించండి';

  @override
  String get contentWarningReportAction => 'నివేదిక';

  @override
  String get contentWarningHideAllLikeThis => 'ఇలా మొత్తం కంటెంట్‌ను దాచండి';

  @override
  String get contentWarningNoFilterYet =>
      'ఈ హెచ్చరిక కోసం ఇంకా సేవ్ చేయబడిన ఫిల్టర్ లేదు.';

  @override
  String get contentWarningHiddenConfirmation =>
      'మేము ఇక నుండి ఇలాంటి పోస్ట్‌లను దాచిపెడతాము.';

  @override
  String get communitySuggestTitle => 'దీన్ని వర్గీకరించడంలో సహాయం చేయండి';

  @override
  String get communitySuggestSubtitle =>
      'కంటెంట్ హెచ్చరికను కోల్పోయారా? మీ సూచన పబ్లిక్, సంతకం చేయబడింది మరియు తిరిగి తీసుకోబడదు.';

  @override
  String get communitySuggestSubmit => 'సూచించండి';

  @override
  String get communitySuggestSuccess => 'ధన్యవాదాలు. మీ సూచన పంపబడింది.';

  @override
  String get communitySuggestFailure =>
      'మీ సూచనను పంపడం సాధ్యపడలేదు. మళ్లీ ప్రయత్నించండి.';

  @override
  String get communitySuggestAlready => 'మీరు దీన్ని సూచించారు';

  @override
  String get communitySuggestActionLabel => 'వర్గీకరించండి';

  @override
  String get videoErrorNotFound => 'వీడియో కనుగొనబడలేదు';

  @override
  String get videoErrorPlayback => 'వీడియో ప్లేబ్యాక్ లోపం';

  @override
  String get videoErrorAgeRestricted => 'వయో-పరిమితి కంటెంట్';

  @override
  String get videoErrorUnavailable => 'వీడియో అందుబాటులో లేదు';

  @override
  String get videoErrorUnavailableBody => 'ఈ వీడియో ప్రస్తుతం అందుబాటులో లేదు.';

  @override
  String get videoErrorRetry => 'మళ్లీ ప్రయత్నించండి';

  @override
  String get videoErrorContentRestricted => 'కంటెంట్ పరిమితం చేయబడింది';

  @override
  String get videoErrorContentRestrictedBody =>
      'మా కంటెంట్ నియమాలను ఉల్లంఘించినందుకు ఈ వీడియో తీసివేయబడింది.';

  @override
  String get videoErrorVerifyAgeBody =>
      'ఈ వీడియోను వీక్షించడానికి మీ వయస్సును ధృవీకరించండి.';

  @override
  String get videoErrorSkip => 'దాటవేయి';

  @override
  String get videoErrorVerifyAgeButton => 'వయస్సుని ధృవీకరించండి';

  @override
  String get videoErrorVerifyAgeFailed =>
      'మీ వయస్సుని ధృవీకరించడం సాధ్యపడలేదు. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get videoErrorVerifyAgeSignerUnreachable =>
      'ధృవీకరణ సమయం ముగిసింది. మీ కనెక్షన్‌ని తనిఖీ చేయండి లేదా త్వరలో మళ్లీ ప్రయత్నించండి.';

  @override
  String get videoErrorAdultContentHiddenTitle =>
      'వయోజన కంటెంట్ స్విచ్ ఆఫ్ చేయబడింది';

  @override
  String get videoErrorAdultContentHiddenBody =>
      'దీన్ని చూడటానికి మీ కంటెంట్ ఫిల్టర్‌లలో దీన్ని ఆన్ చేయండి.';

  @override
  String get videoErrorAdultContentHiddenAction =>
      'కంటెంట్ ఫిల్టర్‌లను తెరవండి';

  @override
  String get videoDetailLoadError => 'వీడియోను లోడ్ చేయడంలో విఫలమైంది';

  @override
  String get videoDetailLoadErrorBody =>
      'ఇక్కడ దారిలో ఏదో పక్కకు పోయింది. మరొకసారి ప్రయత్నించండి.';

  @override
  String get videoDetailNotFoundBody =>
      'ఇది మీ సెట్టింగ్‌ల ద్వారా పోయి ఉండవచ్చు, అందుబాటులో లేకుండా ఉండవచ్చు లేదా దాచబడవచ్చు.';

  @override
  String get databaseCorruptionTitle => 'మీ స్థానిక డేటా స్క్రాంబుల్ చేయబడింది';

  @override
  String get databaseCorruptionBody =>
      'Divineని మూసివేసి, దాన్ని మళ్లీ తెరవండి — మేము దానిని స్వయంచాలకంగా ప్యాచ్ చేస్తాము. మేము చేయగలిగిన చిత్తుప్రతులు మరియు క్లిప్‌లను సేవ్ చేస్తాము, మిగతావన్నీ మళ్లీ లోడ్ అవుతాయి.';

  @override
  String get databaseCorruptionCloseButton => 'మూసివేయి Divine';

  @override
  String get videoDetailContextTitle => 'భాగస్వామ్యం చేసిన వీడియో';

  @override
  String get videoDetailCloseSemanticLabel => 'వీడియో ప్లేయర్‌ని మూసివేయండి';

  @override
  String get videoFollowButtonFollow => 'అనుసరించండి';

  @override
  String get audioAttributionOriginalSound => 'అసలు ధ్వని';

  @override
  String get audioAttributionUnavailableSound => 'సౌండ్ అందుబాటులో లేదు';

  @override
  String videoInspiredByAttributionMultiple(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return '@ ద్వారా ప్రేరణ పొందింది$creatorName +$additionalCreatorCount';
  }

  @override
  String videoInspiredByAttribution(String creatorName) {
    return '@ ద్వారా ప్రేరణ పొందింది\n@ తో $creatorName';
  }

  @override
  String videoCollaboratorWithOne(String name) {
    return '\n@ తో $name';
  }

  @override
  String videoCollaboratorWithMore(String name, int count) {
    return '$name +$count';
  }

  @override
  String videoCollaboratorCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countసహకారులు',
      one: '1 సహకారి',
    );
    return '$_temp0. ప్రొఫైల్ వీక్షించడానికి నొక్కండి.';
  }

  @override
  String get videoCollaboratorPendingDecoration => 'పెండింగ్‌లో ఉంది';

  @override
  String get videoCollaboratorPendingSemanticLabel => 'పెండింగ్ సహకారి';

  @override
  String videoCollaboratorWithPendingSuffix(String label, int pending) {
    return '$label ($pendingపెండింగ్‌లో ఉంది)';
  }

  @override
  String profileChipTapHint(String name) {
    return '$name. ప్రొఫైల్ వీక్షించడానికి నొక్కండి.';
  }

  @override
  String metadataHashtagChipTapHint(String hashtag) {
    return '#$hashtag. ఈ హ్యాష్‌ట్యాగ్‌తో వీడియోలను వీక్షించడానికి నొక్కండి.';
  }

  @override
  String get listAttributionFallback => 'జాబితా';

  @override
  String get shareVideoLabel => 'వీడియోను భాగస్వామ్యం చేయండి';

  @override
  String sharePostSharedWith(String recipientName) {
    return 'పోస్ట్ వీరితో భాగస్వామ్యం చేయబడింది $recipientName';
  }

  @override
  String sharePostSharedWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'పోస్ట్ వీరితో భాగస్వామ్యం చేయబడింది $countవ్యక్తులు',
      one: 'పోస్ట్ వీరితో భాగస్వామ్యం చేయబడింది $countవ్యక్తి',
    );
    return '$_temp0';
  }

  @override
  String get shareFailedToSend => 'వీడియోను పంపడంలో విఫలమైంది';

  @override
  String get shareAddedToBookmarks => 'బుక్‌మార్క్‌లకు జోడించబడింది';

  @override
  String get shareRemovedFromBookmarks => 'బుక్‌మార్క్‌ల నుండి తీసివేయబడింది';

  @override
  String get shareFailedToAddBookmark => 'బుక్‌మార్క్‌ని జోడించడంలో విఫలమైంది';

  @override
  String get shareFailedToRemoveBookmark =>
      'బుక్‌మార్క్‌ని తీసివేయడంలో విఫలమైంది';

  @override
  String get shareActionFailed => 'చర్య విఫలమైంది';

  @override
  String get shareWithTitle => 'వీరితో భాగస్వామ్యం చేయండి';

  @override
  String get shareFindPeople => 'వ్యక్తులను కనుగొనండి';

  @override
  String get shareFindPeopleMultiline => '\nవ్యక్తులను కనుగొనండి';

  @override
  String get shareSent => 'పంపబడింది';

  @override
  String shareSelectedRecipientAnnouncement(String name) {
    return 'ఎంచుకోబడింది$name';
  }

  @override
  String get shareMessageHint => 'ఐచ్ఛిక సందేశాన్ని జోడించండి...';

  @override
  String get videoActionUnlike => 'వీడియో కాకుండా';

  @override
  String get videoActionLike => 'వీడియోని ఇష్టపడండి';

  @override
  String get videoActionAutoLabel => 'సంకలనం';

  @override
  String get videoActionLikeLabel => 'ఇష్టం';

  @override
  String get videoActionReplyLabel => 'ప్రత్యుత్తరం';

  @override
  String get videoActionRepostLabel => 'రివైన్';

  @override
  String get videoActionShareLabel => 'భాగస్వామ్యం చేయండి';

  @override
  String get videoActionReportLabel => 'నివేదిక';

  @override
  String get videoActionReport => 'వీడియోను నివేదించండి';

  @override
  String get videoActionEditLabel => 'సవరించండి';

  @override
  String get videoActionEdit => 'వీడియోను సవరించండి';

  @override
  String get videoActionAboutLabel => 'గురించి';

  @override
  String get videoActionEnableAutoAdvance => 'ఆటో అడ్వాన్స్‌ని ప్రారంభించండి';

  @override
  String get videoActionDisableAutoAdvance => 'ఆటో అడ్వాన్స్‌ని నిలిపివేయండి';

  @override
  String get videoActionRemoveRepost => 'రీపోస్ట్‌ని తీసివేయండి';

  @override
  String get videoActionRepost => 'వీడియోను రీపోస్ట్ చేయండి';

  @override
  String get videoActionViewComments => 'వ్యాఖ్యలను వీక్షించండి';

  @override
  String get videoActionMoreOptions => 'మరిన్ని ఎంపికలు';

  @override
  String get videoEngagementLikersTitle => 'దీన్ని ఇష్టపడ్డారు';

  @override
  String get videoEngagementRepostersTitle => 'ద్వారా మళ్లీ పోస్ట్ చేయబడింది';

  @override
  String get videoEngagementLikersEmpty => 'ఇంకా ఇష్టాలు లేవు';

  @override
  String get videoEngagementRepostersEmpty => 'ఇంకా రీపోస్ట్‌లు లేవు';

  @override
  String get videoEngagementLoadFailed => 'ఆ జాబితాను లోడ్ చేయడం సాధ్యపడలేదు';

  @override
  String get videoOverlayOpenMetadataFromTitle => 'వీడియో వివరాలను తెరవండి';

  @override
  String get videoOverlayOpenMetadataFromDescription =>
      'వీడియో వివరాలను తెరవండి';

  @override
  String get videoOverlayCommentBarHint => 'వ్యాఖ్యను జోడించండి...';

  @override
  String get videoOverlayCommentBarSemanticLabel => 'వ్యాఖ్యను జోడించండి';

  @override
  String get videoOverlayCommentBarSendLabel => 'వ్యాఖ్యను పంపండి';

  @override
  String get videoOverlayCommentPostedSnackbar => 'వ్యాఖ్య పోస్ట్ చేయబడింది';

  @override
  String get videoOverlayCommentPostFailedSnackbar =>
      'వ్యాఖ్యను పోస్ట్ చేయడం సాధ్యపడలేదు';

  @override
  String videoFeedLoopCountLine(String compactCount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'లూప్‌లు',
      one: 'లూప్',
    );
    return '$compactCount $_temp0';
  }

  @override
  String get metadataBadgeNotDivine => 'కాదు Divine';

  @override
  String get metadataBadgeHumanMade => 'మానవ నిర్మిత';

  @override
  String get metadataSoundsLabel => 'శబ్దాలు';

  @override
  String get metadataOriginalSound => 'అసలు ధ్వని';

  @override
  String get metadataVerificationLabel => 'ధృవీకరణ';

  @override
  String get metadataDeviceAttestation => 'పరికర ధృవీకరణ';

  @override
  String get metadataPgpSignature => 'PGP సంతకం';

  @override
  String get metadataC2paCredentials => 'C2PA కంటెంట్ ఆధారాలు';

  @override
  String get metadataProofManifest => 'ప్రూఫ్ మానిఫెస్ట్';

  @override
  String get metadataVerificationInfoTooltip => 'ఈ తనిఖీల అర్థం ఏమిటి?';

  @override
  String metadataSectionInfoSemanticsLabel(String section, String question) {
    return '$section. $question';
  }

  @override
  String get metadataVerificationInfoTitle => 'ఈ తనిఖీల అర్థం ఏమిటి';

  @override
  String get metadataVerificationInfoIntro =>
      'ఈ సంకేతాలు కెమెరా మరియు వీడియో ఫైల్ నుండి వస్తాయి. ఒక వీడియో ఎంత ఎక్కువగా తీసుకువెళితే, అది ఎక్కడి నుండి వచ్చిందో మనం అంత ఎక్కువగా నిరూపించగలము.';

  @override
  String get metadataVerificationInfoDeviceAttestation =>
      'దీన్ని రికార్డ్ చేసిన యాప్ కోసం ఫోన్ ఆపరేటింగ్ సిస్టమ్ హామీ ఇచ్చింది. ఇది కెమెరా నుండి వచ్చింది, ఎవరో అప్‌లోడ్ చేసిన ఫైల్ కాదు.';

  @override
  String get metadataVerificationInfoPgpSignature =>
      'వీడియో క్యాప్చర్ చేయబడిన క్షణంలో క్రిప్టోగ్రాఫికల్‌గా సంతకం చేయబడింది. తర్వాత ఒకే ఫ్రేమ్‌ని మార్చండి మరియు సంతకం విరిగిపోతుంది.';

  @override
  String get metadataVerificationInfoC2paCredentials =>
      'వీడియో ఎక్కడి నుండి వచ్చింది అనేదానికి సంబంధించిన పరిశ్రమ-ప్రామాణిక రికార్డ్, ఫైల్ లోపల తీసుకువెళ్లబడుతుంది — కాబట్టి Divine కాకుండా ఇతర యాప్‌లు కూడా దీన్ని తనిఖీ చేయగలవు.';

  @override
  String get metadataVerificationInfoProofManifest =>
      'పూర్తి ProofMode రికార్డ్: ఫైల్ ఫింగర్‌ప్రింట్, టైమ్‌స్టాంప్ మరియు క్యాప్చర్ సందర్భం, వీడియోతో బండిల్ చేయబడింది.';

  @override
  String get metadataVerificationInfoFootnote =>
      'తప్పిపోయిన చెక్ వీడియోను నకిలీ చేయదు. పాత క్లిప్‌లు మరియు అప్‌లోడ్‌లు ఎప్పుడూ పొందలేదు — అంటే మేము ఆ భాగాన్ని నిరూపించలేము.';

  @override
  String metadataVerificationInfoLearnMore(String url) {
    return 'ఇక్కడ మరింత తెలుసుకోండి $url';
  }

  @override
  String get metadataCreatorLabel => 'సృష్టికర్త';

  @override
  String get metadataCollaboratorsLabel => 'సహకారులు';

  @override
  String get metadataInspiredByLabel => 'ప్రేరణ';

  @override
  String get metadataRepostedByLabel => 'ద్వారా మళ్లీ పోస్ట్ చేయబడింది';

  @override
  String metadataMoreReposters(int count) {
    return '+$countమరిన్ని';
  }

  @override
  String metadataLoopsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'లూప్‌లు',
      one: 'లూప్',
    );
    return '$_temp0';
  }

  @override
  String get metadataLikesLabel => 'ఇష్టాలు';

  @override
  String get metadataCommentsLabel => 'వ్యాఖ్యలు';

  @override
  String get metadataRepostsLabel => 'రీపోస్ట్‌లు';

  @override
  String get metadataVineStatsLabel => 'Vineలో';

  @override
  String metadataVineStatsLine(
    String loops,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$loopsలూప్‌లు · $likesఇష్టాలు · $commentsవ్యాఖ్యలు · $repostsరీపోస్ట్‌లు';
  }

  @override
  String get metadataDivineStatsLabel => 'Divineలో';

  @override
  String metadataDivineStatsLine(
    String views,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$viewsవీక్షణలు · $likesఇష్టాలు · $commentsవ్యాఖ్యలు · $repostsరీపోస్ట్‌లు';
  }

  @override
  String metadataPostedDateSemantics(String date) {
    return 'పోస్ట్ చేయబడింది $date';
  }

  @override
  String get devOptionsTitle => 'డెవలపర్ ఎంపికలు';

  @override
  String get devOptionsDisableDeveloperMode => 'డెవలపర్ మోడ్‌ని నిలిపివేయండి';

  @override
  String get devOptionsDisableDeveloperModeSubtitle =>
      'సెట్టింగ్‌ల నుండి డెవలపర్ ఎంపికలను దాచండి';

  @override
  String get devOptionsDisableDeveloperModeToast =>
      'డెవలపర్ మోడ్ నిలిపివేయబడింది';

  @override
  String get devOptionsShorebirdTitle => 'షోర్‌బర్డ్ పాచెస్';

  @override
  String get devOptionsShorebirdPatchLabel => 'రన్నింగ్ ప్యాచ్';

  @override
  String get devOptionsShorebirdNoPatch => 'ప్యాచ్ ఏదీ ఇన్‌స్టాల్ చేయబడలేదు';

  @override
  String get devOptionsShorebirdUnavailable => 'ఈ బిల్డ్‌లో అందుబాటులో లేదు';

  @override
  String get devOptionsShorebirdUnavailableSubtitle =>
      'ప్యాచ్‌లు షోర్‌బర్డ్ విడుదల చేసిన బిల్డ్‌లో మాత్రమే అమలవుతాయి.';

  @override
  String get devOptionsShorebirdLoading => 'రీడింగ్ ప్యాచ్ స్థితి…';

  @override
  String get devOptionsShorebirdNotChecked =>
      'స్టేజింగ్ ట్రాక్ ఇంకా తనిఖీ చేయబడలేదు.';

  @override
  String get devOptionsShorebirdCheck => 'స్టేజింగ్ ట్రాక్‌ని తనిఖీ చేయండి';

  @override
  String get devOptionsShorebirdApply => 'స్టేజ్డ్ ప్యాచ్‌ని వర్తింపజేయండి';

  @override
  String get devOptionsShorebirdUseStable => 'స్థిరమైన నవీకరణలకు తిరిగి వెళ్ళు';

  @override
  String get devOptionsShorebirdChecking =>
      'స్టేజింగ్ ట్రాక్‌ని తనిఖీ చేస్తోంది…';

  @override
  String get devOptionsShorebirdUpdateAvailable =>
      'దశలవారీ ప్యాచ్ దరఖాస్తు చేయడానికి సిద్ధంగా ఉంది.';

  @override
  String get devOptionsShorebirdUpToDate =>
      'ఈ విడుదల కోసం స్టేజ్డ్ ప్యాచ్ లేదు.';

  @override
  String get devOptionsShorebirdRestartRequired =>
      'డౌన్‌లోడ్ చేయబడింది. యాప్‌ను లోడ్ చేయడానికి దాన్ని రీస్టార్ట్ చేయండి.';

  @override
  String get devOptionsShorebirdRollbackRequired =>
      'రోల్‌బ్యాక్ సిద్ధంగా ఉంది. బేస్ విడుదలకు తిరిగి రావడానికి పునఃప్రారంభించండి.';

  @override
  String get devOptionsShorebirdApplying =>
      'డౌన్‌లోడ్ చేస్తోంది మరియు ఇన్‌స్టాల్ చేస్తోంది…';

  @override
  String get devOptionsShorebirdApplied =>
      'ఇన్‌స్టాల్ చేయబడింది. యాప్‌ను లోడ్ చేయడానికి దాన్ని రీస్టార్ట్ చేయండి.';

  @override
  String get devOptionsShorebirdUnchanged =>
      'ఏదీ ఇన్‌స్టాల్ చేయబడలేదు. స్టేజింగ్ ట్రాక్‌ని తనిఖీ చేసి, మళ్లీ ప్రయత్నించండి.';

  @override
  String get devOptionsShorebirdSelectingStableTrack =>
      'స్థిరమైన ట్రాక్‌ని ఎంచుకోవడం...';

  @override
  String get devOptionsShorebirdStableRestored =>
      'స్థిరమైన ట్రాక్ ఎంచుకోబడింది. స్థిరమైన ప్యాచ్ కోసం తనిఖీ చేయడానికి పునఃప్రారంభించండి.';

  @override
  String get devOptionsShorebirdFailure =>
      'అది పని చేయలేదు. వివరాల కోసం లాగ్‌లను తనిఖీ చేయండి.';

  @override
  String get devOptionsPageLoadTimes => 'పేజీ లోడ్ సమయాలు';

  @override
  String get devOptionsNoPageLoads =>
      'ఇంకా ఏ పేజీ లోడ్‌లు రికార్డ్ చేయబడలేదు.\n సమయ డేటాను చూడటానికి యాప్ చుట్టూ నావిగేట్ చేయండి.';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return 'కనిపిస్తుంది: ${visibleMs}ms |  డేటా: ${dataMs}ms';
  }

  @override
  String get devOptionsSlowestScreens => 'నెమ్మదైన స్క్రీన్‌లు';

  @override
  String get devOptionsVideoPlaybackFormat => 'వీడియో ప్లేబ్యాక్ ఫార్మాట్';

  @override
  String get devOptionsSwitchEnvironmentTitle => 'పర్యావరణాన్ని మార్చాలా?';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return 'కి మారండి $envName?\n\nఇది కాష్ చేసిన వీడియో డేటాను క్లియర్ చేస్తుంది మరియు కొత్త రిలేకి మళ్లీ కనెక్ట్ చేస్తుంది.';
  }

  @override
  String get devOptionsCancel => 'రద్దు';

  @override
  String get devOptionsSwitch => 'మారండి';

  @override
  String devOptionsSwitchedTo(String envName) {
    return 'కి మార్చబడింది $envName';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return 'కి మార్చబడింది $formatName— కాష్ క్లియర్ చేయబడింది';
  }

  @override
  String get featureFlagTitle => 'ఫీచర్ ఫ్లాగ్‌లు';

  @override
  String get featureFlagResetAllTooltip =>
      'అన్ని ఫ్లాగ్‌లను డిఫాల్ట్‌లకు రీసెట్ చేయండి';

  @override
  String get featureFlagError => 'లోపం';

  @override
  String get relaySettingsTitle => 'రిలేలు';

  @override
  String get relaySettingsInfoTitle =>
      'Divine ఒక ఓపెన్ సిస్టమ్ - మీరు మీ కనెక్షన్‌లను నియంత్రిస్తారు';

  @override
  String get relaySettingsInfoDescription =>
      'ఈ రిలేలు మీ కంటెంట్‌ను వికేంద్రీకృత Nostr నెట్‌వర్క్‌లో పంపిణీ చేస్తాయి. మీరు కోరుకున్న విధంగా రిలేలను జోడించవచ్చు లేదా తీసివేయవచ్చు.';

  @override
  String get relaySettingsLearnMoreNostr => 'Nostr → గురించి మరింత తెలుసుకోండి';

  @override
  String get relaySettingsFindPublicRelays =>
      'nostr.co.uk →లో పబ్లిక్ రిలేలను కనుగొనండి';

  @override
  String get relaySettingsAppNotFunctional => 'యాప్ పని చేయదు';

  @override
  String get relaySettingsRequiresRelay =>
      'Divine వీడియోలను లోడ్ చేయడానికి, కంటెంట్‌ను పోస్ట్ చేయడానికి మరియు డేటాను సమకాలీకరించడానికి కనీసం ఒక రిలే అవసరం.';

  @override
  String get relaySettingsRestoreDefaultRelay =>
      'డిఫాల్ట్ రిలేని పునరుద్ధరించండి';

  @override
  String get relaySettingsAddCustomRelay => 'కస్టమ్ రిలేని జోడించండి';

  @override
  String get relaySettingsAddRelay => 'రిలేని జోడించండి';

  @override
  String get relaySettingsRetry => 'మళ్లీ ప్రయత్నించండి';

  @override
  String get relaySettingsNoStats => 'ఇంకా గణాంకాలు అందుబాటులో లేవు';

  @override
  String get relaySettingsConnection => 'కనెక్షన్';

  @override
  String get relaySettingsConnected => 'కనెక్ట్ చేయబడింది';

  @override
  String get relaySettingsDisconnected => 'డిస్‌కనెక్ట్ చేయబడింది';

  @override
  String get relaySettingsSessionDuration => 'సెషన్ వ్యవధి';

  @override
  String get relaySettingsLastConnected => 'చివరిగా కనెక్ట్ చేయబడింది';

  @override
  String get relaySettingsDisconnectedLabel => 'డిస్‌కనెక్ట్ చేయబడింది';

  @override
  String get relaySettingsReason => 'కారణం';

  @override
  String get relaySettingsActiveSubscriptions => 'సక్రియ సభ్యత్వాలు';

  @override
  String get relaySettingsTotalSubscriptions => 'మొత్తం సభ్యత్వాలు';

  @override
  String get relaySettingsEventsReceived => 'ఈవెంట్‌లు స్వీకరించబడ్డాయి';

  @override
  String get relaySettingsEventsSent => 'ఈవెంట్‌లు పంపబడ్డాయి';

  @override
  String get relaySettingsRequestsThisSession => 'ఈ సెషన్‌ను అభ్యర్థిస్తుంది';

  @override
  String get relaySettingsFailedRequests => 'విఫలమైన అభ్యర్థనలు';

  @override
  String get relaySettingsLoadingRelayInfo => 'రిలే సమాచారం లోడ్ అవుతోంది...';

  @override
  String get relaySettingsAboutRelay => 'రిలే గురించి';

  @override
  String get relaySettingsSupportedNips => 'మద్దతు ఉన్న NIPలు';

  @override
  String get relaySettingsSoftware => 'సాఫ్ట్‌వేర్';

  @override
  String get relaySettingsViewWebsite => 'వెబ్‌సైట్‌ను వీక్షించండి';

  @override
  String get relaySettingsRemoveRelayTitle => 'రిలేని తీసివేయాలా?';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return 'మీరు ఖచ్చితంగా ఈ రిలేని తీసివేయాలనుకుంటున్నారా?\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveDefaultRelayTitle =>
      'Divine రిలేని తీసివేయాలా?';

  @override
  String relaySettingsRemoveDefaultRelayMessage(String relayUrl) {
    return 'Divine యొక్క రిలేని తీసివేయడం యాప్ అనుభవాన్ని క్షీణింపజేస్తుంది. వీడియోలు, పోస్టింగ్ మరియు సమకాలీకరణ తక్కువ విశ్వసనీయంగా ఉండవచ్చు. ఇది అనుభవజ్ఞులైన Nostr వినియోగదారులు మాత్రమే చేయాలి.\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveRelayTooltip => 'రిలేని తీసివేయండి';

  @override
  String get relaySettingsCancel => 'రద్దు';

  @override
  String get relaySettingsRemove => 'తీసివేయి';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return 'తీసివేయబడిన రిలే: $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay => 'రిలేని తీసివేయడంలో విఫలమైంది';

  @override
  String get relaySettingsForcingReconnection => 'రిలే రీకనెక్షన్ బలవంతంగా...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'దీనికి కనెక్ట్ చేయబడింది $countరిలేలు!',
      one: 'కి కనెక్ట్ చేయబడింది $countరిలే!',
    );
    return '$_temp0';
  }

  @override
  String get relaySettingsFailedToConnectCheck =>
      'రిలేలకు కనెక్ట్ చేయడంలో విఫలమైంది. దయచేసి మీ నెట్‌వర్క్ కనెక్షన్‌ని తనిఖీ చేయండి.';

  @override
  String get relaySettingsSavedLocallyPublishPending =>
      'ఈ పరికరంలో సేవ్ చేయబడింది. రచనలను మళ్లీ ప్రచురించేటప్పుడు మేము దానిని మీ ఖాతాకు సమకాలీకరిస్తాము.';

  @override
  String get relaySettingsAddRelayTitle => 'రిలేని జోడించండి';

  @override
  String get relaySettingsAddRelayPrompt =>
      'మీరు జోడించాలనుకుంటున్న రిలే యొక్క WebSocket URLని నమోదు చేయండి:';

  @override
  String get relaySettingsBrowsePublicRelays =>
      'nostr.co.ukలో పబ్లిక్ రిలేలను బ్రౌజ్ చేయండి';

  @override
  String get relaySettingsAdd => 'జోడించండి';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return 'రిలే జోడించబడింది: $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      'రిలేని జోడించడంలో విఫలమైంది. దయచేసి URLని తనిఖీ చేసి, మళ్లీ ప్రయత్నించండి.';

  @override
  String get relaySettingsInvalidUrl =>
      'రిలే URL తప్పనిసరిగా wss:// లేదా ws://తో ప్రారంభం కావాలి';

  @override
  String get relaySettingsInsecureUrl =>
      'రిలే URL తప్పనిసరిగా wss://ని ఉపయోగించాలి (ws:// లోకల్ హోస్ట్ కోసం మాత్రమే అనుమతించబడుతుంది)';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return 'డిఫాల్ట్ రిలే పునరుద్ధరించబడింది: $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      'డిఫాల్ట్ రిలేని పునరుద్ధరించడంలో విఫలమైంది. దయచేసి మీ నెట్‌వర్క్ కనెక్షన్‌ని తనిఖీ చేయండి.';

  @override
  String get relaySettingsCouldNotOpenBrowser =>
      'బ్రౌజర్‌ని తెరవడం సాధ్యపడలేదు';

  @override
  String get relaySettingsFailedToOpenLink => 'లింక్‌ని తెరవడంలో విఫలమైంది';

  @override
  String get relaySettingsExternalRelay => 'బాహ్య రిలే';

  @override
  String get relaySettingsNotConnected => 'కనెక్ట్ కాలేదు';

  @override
  String relaySettingsDisconnectedAgo(String duration) {
    return 'డిస్‌కనెక్ట్ చేయబడింది$durationక్రితం';
  }

  @override
  String relaySettingsSubscriptionsSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countసబ్‌లు',
      one: '$countఉప',
    );
    return '$_temp0';
  }

  @override
  String relaySettingsEventsSummary(int countValue, String count) {
    String _temp0 = intl.Intl.pluralLogic(
      countValue,
      locale: localeName,
      other: '$countఈవెంట్‌లు',
      one: '$countఈవెంట్',
    );
    return '$_temp0';
  }

  @override
  String relaySettingsTimeAgo(String duration) {
    return '$durationక్రితం';
  }

  @override
  String get nostrSettingsIntro =>
      'Divine వికేంద్రీకృత ప్రచురణ కోసం Nostr ప్రోటోకాల్‌ను ఉపయోగిస్తుంది. మీ కంటెంట్ మీరు ఎంచుకున్న రిలేలలో నివసిస్తుంది మరియు మీ కీలు మీ గుర్తింపు.';

  @override
  String get nostrSettingsSectionNetwork => 'నెట్‌వర్క్';

  @override
  String get nostrSettingsSectionAccount => 'ఖాతా';

  @override
  String get nostrSettingsSectionDangerZone => 'డేంజర్ జోన్';

  @override
  String get nostrSettingsRelays => 'రిలేలు';

  @override
  String get nostrSettingsRelaysSubtitle =>
      'Nostr రిలే కనెక్షన్‌లను నిర్వహించండి';

  @override
  String get nostrSettingsRelayDiagnostics => 'రిలే డయాగ్నోస్టిక్స్';

  @override
  String get nostrSettingsRelayDiagnosticsSubtitle =>
      'డీబగ్ రిలే కనెక్టివిటీ మరియు నెట్‌వర్క్ సమస్యలు';

  @override
  String get nostrSettingsMediaServers => 'మీడియా సర్వర్లు';

  @override
  String get nostrSettingsMediaServersSubtitle =>
      'Blossom అప్‌లోడ్ సర్వర్‌లను కాన్ఫిగర్ చేయండి';

  @override
  String get settingsDeveloperOptions => 'డెవలపర్ ఎంపికలు';

  @override
  String get settingsDeveloperOptionsSubtitle =>
      'ఎన్విరాన్‌మెంట్ స్విచ్చర్ మరియు డీబగ్ సెట్టింగ్‌లు';

  @override
  String get nostrSettingsKeyManagement => 'కీ నిర్వహణ';

  @override
  String get nostrSettingsKeyManagementSubtitle =>
      'మీ Nostr కీలను ఎగుమతి చేయండి, బ్యాకప్ చేయండి మరియు పునరుద్ధరించండి';

  @override
  String get nostrSettingsClientAttribution => 'క్లయింట్ అట్రిబ్యూషన్';

  @override
  String get nostrSettingsClientAttributionSubtitle =>
      'మీరు ప్రచురించే ఈవెంట్‌లపై Divine క్లయింట్ ట్యాగ్‌ని చేర్చండి, తద్వారా ఇతర Nostr యాప్‌లు వాటిని సరిగ్గా ఆపాదించగలవు. అది లేకుండా, మా మోడరేటర్‌లు సమీక్షించినప్పుడు మీరు పంపే నివేదికలు తక్కువ బరువును కలిగి ఉంటాయి.';

  @override
  String get nostrSettingsMoveAccount => 'మీ ఖాతాను తరలించండి';

  @override
  String get nostrSettingsMoveAccountSubtitle =>
      'మీ ఆర్కైవ్‌ని డౌన్‌లోడ్ చేసుకోండి మరియు మీ పోస్ట్‌లు మరియు వీడియోలను మరొక రిలే లేదా మీడియా సర్వర్‌కి తరలించండి.';

  @override
  String get nostrSettingsRemoveKeys => 'ఈ పరికరం నుండి ఈ ఖాతాను తీసివేయండి';

  @override
  String get nostrSettingsRemoveKeysSubtitle =>
      'ఈ పరికరం నుండి ఈ ఖాతా యొక్క స్థానిక లాగిన్‌ని తీసివేయండి. మీ స్థానిక చిత్తుప్రతులు మరియు క్లిప్‌లు ఈ ఖాతా కోసం సేవ్ చేయబడతాయి.';

  @override
  String get nostrSettingsCouldNotRemoveKeys =>
      'ఈ పరికరం నుండి ఈ ఖాతాను తీసివేయడం సాధ్యపడలేదు. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get nostrSettingsDeleteAccount => 'ఖాతా మరియు డేటాను తొలగించండి';

  @override
  String get nostrSettingsDeleteAccountSubtitle =>
      'మీ కంటెంట్ కోసం తొలగింపు అభ్యర్థనలను పంపుతుంది మరియు ఈ పరికరంలో మిమ్మల్ని సైన్ అవుట్ చేస్తుంది. రిలేలు, క్లయింట్లు, శోధన సూచికలు మరియు ఇతర సైన్ ఇన్ చేసిన పరికరాలు కాపీలను ఉంచవచ్చు.';

  @override
  String get relayDiagnosticTitle => 'రిలే డయాగ్నోస్టిక్స్';

  @override
  String get relayDiagnosticRefreshTooltip =>
      'డయాగ్నోస్టిక్‌లను రిఫ్రెష్ చేయండి';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return 'చివరి రిఫ్రెష్: $time';
  }

  @override
  String get relayDiagnosticRelayStatus => 'రిలే స్థితి';

  @override
  String get relayDiagnosticInitialized => 'ప్రారంభించబడింది';

  @override
  String get relayDiagnosticReady => 'సిద్ధంగా ఉంది';

  @override
  String get relayDiagnosticNotInitialized => 'ప్రారంభించబడలేదు';

  @override
  String get relayDiagnosticDatabaseEvents => 'డేటాబేస్ ఈవెంట్‌లు';

  @override
  String get relayDiagnosticActiveSubscriptions =>
      'యాక్టివ్ సబ్‌స్క్రిప్షన్‌లు';

  @override
  String get relayDiagnosticExternalRelays => 'బాహ్య రిలేలు';

  @override
  String get relayDiagnosticConfigured => 'కాన్ఫిగర్ చేయబడింది';

  @override
  String relayDiagnosticRelayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countరిలేలు',
      one: '$countరిలే',
    );
    return '$_temp0';
  }

  @override
  String get relayDiagnosticConnectedLabel => 'కనెక్ట్ చేయబడింది';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => 'వీడియో ఈవెంట్‌లు';

  @override
  String get relayDiagnosticHomeFeed => 'హోమ్ ఫీడ్';

  @override
  String relayDiagnosticVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countవీడియోలు',
      one: '$countవీడియో',
    );
    return '$_temp0';
  }

  @override
  String get relayDiagnosticDiscovery => 'డిస్కవరీ';

  @override
  String get relayDiagnosticLoading => 'లోడ్ అవుతోంది';

  @override
  String get relayDiagnosticYes => 'అవును';

  @override
  String get relayDiagnosticNo => 'నం';

  @override
  String get relayDiagnosticTestDirectQuery =>
      'ప్రత్యక్ష ప్రశ్నను పరీక్షించండి';

  @override
  String get relayDiagnosticNetworkConnectivity => 'నెట్‌వర్క్ కనెక్టివిటీ';

  @override
  String get relayDiagnosticRunNetworkTest => 'నెట్‌వర్క్ పరీక్షను అమలు చేయండి';

  @override
  String get relayDiagnosticBlossomServer => 'Blossom సర్వర్';

  @override
  String get relayDiagnosticTestAllEndpoints =>
      'అన్ని ఎండ్ పాయింట్లను పరీక్షించండి';

  @override
  String get relayDiagnosticStatus => 'స్థితి';

  @override
  String get relayDiagnosticUrl => 'URL';

  @override
  String get relayDiagnosticError => 'లోపం';

  @override
  String get relayDiagnosticFunnelCakeApi => 'FunnelCake API';

  @override
  String get relayDiagnosticBaseUrl => 'బేస్ URL';

  @override
  String get relayDiagnosticSummary => 'సారాంశం';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCountసరే (సగటు ${avgMs}ms)';
  }

  @override
  String get relayDiagnosticRetestAll => 'అన్నింటినీ మళ్లీ పరీక్షించండి';

  @override
  String get relayDiagnosticRetrying => 'మళ్లీ ప్రయత్నిస్తోంది...';

  @override
  String get relayDiagnosticRetryConnection =>
      'కనెక్షన్‌ని మళ్లీ ప్రయత్నించండి';

  @override
  String get relayDiagnosticTroubleshooting => 'ట్రబుల్షూటింగ్';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• గ్రీన్ స్టేటస్ = కనెక్ట్ చేయబడింది మరియు పని చేస్తోంది\n• రెడ్ స్టేటస్ = కనెక్షన్ విఫలమైంది\n• నెట్‌వర్క్ పరీక్ష విఫలమైతే, ఇంటర్నెట్ కనెక్షన్‌ని తనిఖీ చేయండి\n• రిలేలు కాన్ఫిగర్ చేయబడి ఉంటే కానీ కనెక్ట్ కానట్లయితే, ఈ స్క్రీన్‌ని డీబగ్ చేయడం కోసం \"కనెక్షన్‌ని మళ్లీ ప్రయత్నించండి\"\nని ట్యాప్ చేయండి';

  @override
  String get relayDiagnosticAllEndpointsHealthy =>
      'అన్ని REST ముగింపు పాయింట్‌లు ఆరోగ్యంగా ఉన్నాయి!';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      'కొన్ని REST ముగింపు పాయింట్‌లు విఫలమయ్యాయి - ఎగువన వివరాలను చూడండి';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'కనుగొనబడింది \nడేటాబేస్‌లో $countవీడియో ఈవెంట్‌లు',
      one: 'కనుగొనబడింది \nడేటాబేస్‌లో $countవీడియో ఈవెంట్',
    );
    return '$_temp0';
  }

  @override
  String get relayDiagnosticQueryFailed =>
      'ప్రశ్న విఫలమైంది. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'దీనికి కనెక్ట్ చేయబడింది $countరిలేలు!',
      one: 'దీనికి కనెక్ట్ చేయబడింది $countరిలే!',
    );
    return '$_temp0';
  }

  @override
  String get relayDiagnosticFailedToConnect =>
      'ఏ రిలేలకు కనెక్ట్ చేయడంలో విఫలమైంది';

  @override
  String get relayDiagnosticConnectionRetryFailed =>
      'కనెక్షన్ పునఃప్రయత్నం విఫలమైంది. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get relayDiagnosticConnectedAuthenticated =>
      'కనెక్ట్ చేయబడింది & ప్రామాణీకరించబడింది';

  @override
  String get relayDiagnosticConnectedOnly => 'కనెక్ట్ చేయబడింది';

  @override
  String get relayDiagnosticNotConnected => 'కనెక్ట్ కాలేదు';

  @override
  String get relayDiagnosticNoRelaysConfigured =>
      'ఏ రిలేలు కాన్ఫిగర్ చేయబడలేదు';

  @override
  String get relayDiagnosticFailed => 'విఫలమైంది';

  @override
  String get notificationSettingsTitle => 'నోటిఫికేషన్‌లు';

  @override
  String get notificationSettingsResetTooltip => 'డిఫాల్ట్‌లకు రీసెట్ చేయండి';

  @override
  String get notificationSettingsTypes => 'నోటిఫికేషన్ రకాలు';

  @override
  String get notificationSettingsLikes => 'ఇష్టాలు';

  @override
  String get notificationSettingsLikesSubtitle =>
      'ఎవరైనా మీ వీడియోలను లైక్ చేసినప్పుడు';

  @override
  String get notificationSettingsComments => 'వ్యాఖ్యలు';

  @override
  String get notificationSettingsCommentsSubtitle =>
      'ఎవరైనా మీ వీడియోలపై వ్యాఖ్యానించినప్పుడు';

  @override
  String get notificationSettingsFollows => 'అనుసరిస్తుంది';

  @override
  String get notificationSettingsFollowsSubtitle =>
      'ఎవరైనా మిమ్మల్ని అనుసరించినప్పుడు';

  @override
  String get notificationSettingsMentions => 'ప్రస్తావనలు';

  @override
  String get notificationSettingsMentionsSubtitle =>
      'మీరు ప్రస్తావించబడినప్పుడు';

  @override
  String get notificationSettingsReposts => 'రీపోస్ట్‌లు';

  @override
  String get notificationSettingsRepostsSubtitle =>
      'ఎవరైనా మీ వీడియోలను రీపోస్ట్ చేసినప్పుడు';

  @override
  String get notificationSettingsNewPosts => 'కొత్త తీగలు';

  @override
  String get notificationSettingsNewPostsSubtitle =>
      'ఎవరైనా మీరు పోస్ట్‌లను చూస్తున్నప్పుడు';

  @override
  String get notificationSettingsActions => 'చర్యలు';

  @override
  String get notificationSettingsMarkAllAsRead =>
      'అన్నింటినీ చదివినట్లుగా గుర్తించండి';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle =>
      'అన్ని నోటిఫికేషన్‌లను చదివినట్లుగా మార్క్ చేయండి';

  @override
  String get notificationSettingsAllMarkedAsRead =>
      'అన్ని నోటిఫికేషన్‌లు చదివినట్లు గుర్తు పెట్టబడ్డాయి';

  @override
  String get notificationSettingsMarkAllAsReadFailed =>
      'అన్నింటినీ చదివినట్లు గుర్తించడంలో విఫలమైంది';

  @override
  String get notificationSettingsResetToDefaults =>
      'సెట్టింగ్‌లు డిఫాల్ట్‌లకు రీసెట్ చేయబడ్డాయి';

  @override
  String get notificationSettingsAbout => 'నోటిఫికేషన్‌ల గురించి';

  @override
  String get notificationSettingsAboutDescription =>
      'నోటిఫికేషన్‌లు Nostr ప్రోటోకాల్ ద్వారా అందించబడతాయి. నిజ-సమయ నవీకరణలు Nostr రిలేలకు మీ కనెక్షన్‌పై ఆధారపడి ఉంటాయి. కొన్ని నోటిఫికేషన్‌లు ఆలస్యం కావచ్చు.';

  @override
  String get safetySettingsWhatYouSee => 'మీరు ఏమి చూస్తారు';

  @override
  String get safetySettingsWhatYouPublish => 'మీరు ఏమి ప్రచురించారు';

  @override
  String get safetySettingsShowDivineHostedOnly =>
      'Divine-హోస్ట్ చేసిన వీడియోలను మాత్రమే చూపు';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle =>
      'ఇతర మీడియా హోస్ట్‌ల నుండి అందించబడిన వీడియోలను దాచండి';

  @override
  String get safetySettingsModeration => 'మోడరేషన్';

  @override
  String get safetySettingsBlockedUsers => 'బ్లాక్ చేయబడిన వినియోగదారులు';

  @override
  String get safetySettingsAgeVerification => 'వయస్సు ధృవీకరణ';

  @override
  String get safetySettingsAgeConfirmation =>
      'నాకు 18 సంవత్సరాలు లేదా అంతకంటే ఎక్కువ వయస్సు ఉందని నేను ధృవీకరిస్తున్నాను';

  @override
  String get safetySettingsAgeRequired =>
      'పెద్దల కంటెంట్‌ని వీక్షించడానికి అవసరం';

  @override
  String get safetySettingsAgeLockedForMinor => 'మీ ఖాతా కోసం లాక్ చేయబడింది';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle =>
      'అధికారిక మోడరేషన్ సేవ (డిఫాల్ట్‌గా ఆన్)';

  @override
  String get safetySettingsPeopleIFollow => 'నేను అనుసరించే వ్యక్తులు';

  @override
  String get safetySettingsPeopleIFollowSubtitle =>
      'మీరు అనుసరించే వ్యక్తుల నుండి లేబుల్‌లకు సభ్యత్వం పొందండి';

  @override
  String get safetySettingsAddCustomLabeler => 'కస్టమ్ లేబులర్‌ని జోడించండి';

  @override
  String get safetySettingsAddCustomLabelerHint => 'npub నమోదు చేయండి...';

  @override
  String get safetySettingsAddCustomLabelerListTitle =>
      'అనుకూల లేబులర్‌ని జోడించండి';

  @override
  String get safetySettingsRemoveLabeler => 'లేబులర్‌ను తీసివేయండి';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle =>
      'npub చిరునామాను నమోదు చేయండి';

  @override
  String get safetySettingsNoBlockedUsers =>
      'బ్లాక్ చేయబడిన వినియోగదారులు లేరు';

  @override
  String get safetySettingsUnblock => 'అన్‌బ్లాక్ చేయండి';

  @override
  String get safetySettingsUserUnblocked => 'వినియోగదారు అన్‌బ్లాక్ చేయబడ్డారు';

  @override
  String get safetySettingsCancel => 'రద్దు';

  @override
  String get safetySettingsAdd => 'జోడించండి';

  @override
  String get analyticsTitle => 'క్రియేటర్ అనలిటిక్స్';

  @override
  String get analyticsDiagnosticsTooltip => 'డయాగ్నోస్టిక్స్';

  @override
  String get analyticsDiagnosticsSemanticLabel =>
      'డయాగ్నస్టిక్‌లను టోగుల్ చేయండి';

  @override
  String get analyticsRetry => 'మళ్లీ ప్రయత్నించండి';

  @override
  String get analyticsUnableToLoad => 'విశ్లేషణలను లోడ్ చేయడం సాధ్యపడలేదు.';

  @override
  String get analyticsServerUnavailable =>
      'క్రియేటర్ అనలిటిక్స్ సర్వర్ సమస్యను ఎదుర్కొంటోంది. దయచేసి ఒక క్షణంలో మళ్లీ ప్రయత్నించండి.';

  @override
  String get analyticsConnectionIssue =>
      'క్రియేటర్ అనలిటిక్స్ కనెక్ట్ కాలేదు. మీ కనెక్షన్‌ని తనిఖీ చేసి, మళ్లీ ప్రయత్నించండి.';

  @override
  String get analyticsSignInRequired =>
      'సృష్టికర్త విశ్లేషణలను వీక్షించడానికి సైన్ ఇన్ చేయండి.';

  @override
  String get analyticsViewDataUnavailable =>
      'ఈ పోస్ట్‌ల కోసం రిలే నుండి వీక్షణలు ప్రస్తుతం అందుబాటులో లేవు. లైక్/కామెంట్/రీపోస్ట్ మెట్రిక్‌లు ఇప్పటికీ ఖచ్చితమైనవి.';

  @override
  String get analyticsViewDataTitle => 'డేటాను వీక్షించండి';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return 'నవీకరించబడింది $time• అందుబాటులో ఉన్నప్పుడు ఫన్నెల్‌కేక్ నుండి స్కోర్‌లు ఇష్టాలు, వ్యాఖ్యలు, రీపోస్ట్‌లు మరియు వీక్షణలు/లూప్‌లను ఉపయోగిస్తాయి.';
  }

  @override
  String get analyticsVideos => 'వీడియోలు';

  @override
  String get analyticsViews => 'వీక్షణలు';

  @override
  String get analyticsInteractions => 'పరస్పర చర్యలు';

  @override
  String get analyticsEngagement => 'నిశ్చితార్థం';

  @override
  String get analyticsFollowers => 'అనుచరులు';

  @override
  String get analyticsAvgPerPost => 'సగటు/పోస్ట్';

  @override
  String get analyticsInteractionMix => 'ఇంటరాక్షన్ మిక్స్';

  @override
  String get analyticsLikes => 'ఇష్టాలు';

  @override
  String get analyticsComments => 'వ్యాఖ్యలు';

  @override
  String get analyticsReposts => 'రీపోస్ట్‌లు';

  @override
  String get analyticsPerformanceHighlights => 'పనితీరు ముఖ్యాంశాలు';

  @override
  String get analyticsMostViewed => 'ఎక్కువగా వీక్షించారు';

  @override
  String get analyticsMostDiscussed => 'ఎక్కువగా చర్చించబడింది';

  @override
  String get analyticsMostReposted => 'చాలా రీపోస్ట్ చేయబడింది';

  @override
  String get analyticsNoVideosYet => 'ఇంకా వీడియోలు లేవు';

  @override
  String get analyticsViewDataUnavailableShort => 'డేటా అందుబాటులో లేదు';

  @override
  String analyticsViewsCount(int countValue, String count) {
    String _temp0 = intl.Intl.pluralLogic(
      countValue,
      locale: localeName,
      other: '$countవీక్షణలు',
      one: '$countవీక్షణ',
    );
    return '$_temp0';
  }

  @override
  String analyticsCommentsCount(int countValue, String count) {
    String _temp0 = intl.Intl.pluralLogic(
      countValue,
      locale: localeName,
      other: '$countవ్యాఖ్యలు',
      one: '$countవ్యాఖ్య',
    );
    return '$_temp0';
  }

  @override
  String analyticsRepostsCount(int countValue, String count) {
    String _temp0 = intl.Intl.pluralLogic(
      countValue,
      locale: localeName,
      other: '$countరీపోస్ట్‌లు',
      one: '$countరీపోస్ట్',
    );
    return '$_temp0';
  }

  @override
  String get analyticsTopContent => 'అగ్ర కంటెంట్';

  @override
  String get analyticsPublishPrompt =>
      'ర్యాంకింగ్‌లను చూడటానికి కొన్ని వీడియోలను ప్రచురించండి.';

  @override
  String get analyticsEngagementRateExplainer =>
      'కుడివైపు % = ఎంగేజ్‌మెంట్ రేటు (ఇంటరాక్షన్‌లు వీక్షణల ద్వారా విభజించబడ్డాయి).';

  @override
  String get analyticsEngagementRateNoViews =>
      'ఎంగేజ్‌మెంట్ రేటుకు డేటాను వీక్షించడం అవసరం; వీక్షణలు అందుబాటులోకి వచ్చే వరకు విలువలు N/Aగా చూపబడతాయి.';

  @override
  String get analyticsEngagementLabel => 'నిశ్చితార్థం';

  @override
  String get analyticsViewsUnavailable => 'వీక్షణలు అందుబాటులో లేవు';

  @override
  String analyticsInteractionsCount(int countValue, String count) {
    String _temp0 = intl.Intl.pluralLogic(
      countValue,
      locale: localeName,
      other: '$countపరస్పర చర్యలు',
      one: '$countపరస్పర చర్య',
    );
    return '$_temp0';
  }

  @override
  String get analyticsPostAnalytics => 'పోస్ట్ ఎనలిటిక్స్';

  @override
  String get analyticsOpenPost => 'ఓపెన్ పోస్ట్';

  @override
  String get analyticsRecentDailyInteractions =>
      'ఇటీవలి రోజువారీ పరస్పర చర్యలు';

  @override
  String get analyticsNoActivityYet => 'ఈ పరిధిలో ఇంకా కార్యాచరణ లేదు.';

  @override
  String get analyticsDailyInteractionsExplainer =>
      'పరస్పర చర్యలు = లైక్‌లు + కామెంట్‌లు + పోస్ట్ తేదీ వారీగా రీపోస్ట్‌లు.';

  @override
  String get analyticsDailyBarExplainer =>
      'బార్ పొడవు ఈ విండోలో మీ అత్యధిక రోజుకు సంబంధించి ఉంటుంది.';

  @override
  String get analyticsAudienceSnapshot => 'ప్రేక్షకుల స్నాప్‌షాట్';

  @override
  String analyticsFollowersCount(String count) {
    return 'అనుచరులు: $count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return 'క్రిందివి: $count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      'ఫన్నెల్‌కేక్ ఆడియన్స్ అనలిటిక్స్ ఎండ్ పాయింట్‌లను జోడిస్తుంది కాబట్టి ప్రేక్షకుల మూలం/భూగోళం/సమయం బ్రేక్‌డౌన్‌లు జనాదరణ పొందుతాయి.';

  @override
  String get analyticsRetention => 'నిలుపుదల';

  @override
  String get analyticsRetentionWithViews =>
      'ఫన్నెల్‌కేక్ నుండి సెకనుకు/బకెట్‌కు రిటెన్షన్ వచ్చిన తర్వాత రిటెన్షన్ కర్వ్ మరియు వాచ్-టైమ్ బ్రేక్‌డౌన్ కనిపిస్తుంది.';

  @override
  String get analyticsRetentionWithoutViews =>
      'Funnelcake ద్వారా వీక్షణ+వాచ్-టైమ్ అనలిటిక్స్ తిరిగి వచ్చే వరకు రిటెన్షన్ డేటా అందుబాటులో ఉండదు.';

  @override
  String get analyticsDiagnostics => 'డయాగ్నోస్టిక్స్';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return 'మొత్తం వీడియోలు: $count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return 'వీక్షణలతో: $count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return 'వీక్షణలు లేవు: $count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return 'హైడ్రేటెడ్ (బల్క్): $count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return 'హైడ్రేటెడ్ (/వీక్షణలు): $count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return 'మూలాలు: $sources';
  }

  @override
  String analyticsDiagnosticsFailedSources(String sources) {
    return 'విఫలమైన మూలాలు: $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => 'ఫిక్చర్ డేటాను ఉపయోగించండి';

  @override
  String get analyticsNa => 'N/A';

  @override
  String get authCreateNewAccount => 'కొత్త Divine ఖాతాను సృష్టించండి';

  @override
  String get authCreateNewAccountShort => 'కొత్త ఖాతాను సృష్టించండి';

  @override
  String get authSignInDifferentAccount =>
      'ఇప్పటికే ఉన్న ఖాతాతో సైన్ ఇన్ చేయండి';

  @override
  String get authUseAnotherAccount => 'మరొక ఖాతాను ఉపయోగించండి';

  @override
  String authContinueAs(String displayName) {
    return 'ఇలా కొనసాగించండి $displayName';
  }

  @override
  String get authRecoveryDraftsOwner =>
      'ఈ ఖాతా కోసం మీ చిత్తుప్రతులు మరియు క్లిప్‌లు సేవ్ చేయబడ్డాయి';

  @override
  String get authRecoveryOtherAccountWarning =>
      'ఇక్కడ సైన్ ఇన్ చేయడం వల్ల ఆ చిత్తుప్రతులు మరియు క్లిప్‌లు దాచబడతాయి';

  @override
  String get authTermsPrefix =>
      'దిగువన ఉన్న ఎంపికను ఎంచుకోవడం ద్వారా, మీకు కనీసం 16 సంవత్సరాలు (లేదా పూర్తి చేసినట్లు) నిర్ధారిస్తారు ';

  @override
  String get authTermsAgeAuthorizationCta => 'Divine వయస్సు అధికారం';

  @override
  String get authTermsAfterAgeAuthorization => ') మరియు అంగీకరిస్తున్నారు ';

  @override
  String get authTermsOfService => 'సేవా నిబంధనలు';

  @override
  String get authPrivacyPolicy => 'గోప్యతా విధానం';

  @override
  String get authTermsAnd => ', మరియు ';

  @override
  String get authSafetyStandards => 'భద్రతా ప్రమాణాలు';

  @override
  String get authAmberNotInstalled => 'అంబర్ యాప్ ఇన్‌స్టాల్ చేయబడలేదు';

  @override
  String get authAmberConnectionFailed => 'Amberతో కనెక్ట్ చేయడంలో విఫలమైంది';

  @override
  String get authPasswordResetSent =>
      'ఆ ఇమెయిల్‌తో ఖాతా ఉన్నట్లయితే, పాస్‌వర్డ్ రీసెట్ లింక్ పంపబడింది.';

  @override
  String get authSignInTitle => 'సైన్ ఇన్ చేయండి';

  @override
  String get authEmailLabel => 'ఇమెయిల్';

  @override
  String get authPasswordLabel => 'పాస్‌వర్డ్';

  @override
  String get authConfirmPasswordLabel => 'పాస్‌వర్డ్‌ను నిర్ధారించండి';

  @override
  String get authEmailRequired => 'ఇమెయిల్ అవసరం';

  @override
  String get authEmailInvalid =>
      'దయచేసి చెల్లుబాటు అయ్యే ఇమెయిల్‌ను నమోదు చేయండి';

  @override
  String get authPasswordRequired => 'పాస్‌వర్డ్ అవసరం';

  @override
  String get authConfirmPasswordRequired =>
      'దయచేసి మీ పాస్‌వర్డ్‌ను నిర్ధారించండి';

  @override
  String get authPasswordsDoNotMatch => 'పాస్‌వర్డ్‌లు సరిపోలడం లేదు';

  @override
  String get authForgotPassword => 'పాస్‌వర్డ్ మర్చిపోయారా?';

  @override
  String get authImportNostrKey => 'దిగుమతి Nostr కీ';

  @override
  String get authConnectSignerApp => 'సంతకం చేసే యాప్‌తో కనెక్ట్ అవ్వండి';

  @override
  String get authSignInWithAmber => 'అంబర్‌తో సైన్ ఇన్ చేయండి';

  @override
  String get authSignInWithBrowserExtension =>
      'బ్రౌజర్ పొడిగింపుతో సైన్ ఇన్ చేయండి';

  @override
  String get authNip07ConnectionFailed =>
      'మీ బ్రౌజర్ పొడిగింపుకు కనెక్ట్ చేయడం సాధ్యపడలేదు.';

  @override
  String get authNip07ExtensionNotFound =>
      'బ్రౌజర్ పొడిగింపు కనుగొనబడలేదు. Alby, nos2x లేదా మరొక NIP-07 అనుకూల పొడిగింపును ఇన్‌స్టాల్ చేయండి.';

  @override
  String get authSignInOptionsTitle => 'సైన్-ఇన్ ఎంపికలు';

  @override
  String get authInfoEmailPasswordTitle => 'ఇమెయిల్ & పాస్‌వర్డ్';

  @override
  String get authInfoEmailPasswordDescription =>
      'మీ Divine ఖాతాతో సైన్ ఇన్ చేయండి. మీరు ఇమెయిల్ మరియు పాస్‌వర్డ్‌తో నమోదు చేసుకున్నట్లయితే, వాటిని ఇక్కడ ఉపయోగించండి.';

  @override
  String get authInfoImportNostrKeyDescription =>
      'ఇప్పటికే Nostr గుర్తింపు ఉందా? మరొక క్లయింట్ నుండి మీ nsec ప్రైవేట్ కీని దిగుమతి చేయండి.';

  @override
  String get authInfoSignerAppTitle => 'సైనర్ యాప్';

  @override
  String get authInfoSignerAppDescription =>
      'మెరుగైన కీ భద్రత కోసం nsecBunker వంటి NIP-46 అనుకూల రిమోట్ సైనర్‌ని ఉపయోగించి కనెక్ట్ చేయండి.';

  @override
  String get authInfoAmberTitle => 'అంబర్';

  @override
  String get authInfoAmberDescription =>
      'మీ Nostr కీలను సురక్షితంగా నిర్వహించడానికి Androidలో అంబర్ సైనర్ యాప్‌ని ఉపయోగించండి.';

  @override
  String get authInfoBrowserExtensionTitle => 'బ్రౌజర్ పొడిగింపు';

  @override
  String get authInfoBrowserExtensionDescription =>
      'Alby లేదా nos2x వంటి NIP-07 బ్రౌజర్ పొడిగింపుతో సైన్ ఇన్ చేయండి. మీ కీలు పొడిగింపులో ఉంటాయి - Divine వాటిని ఎప్పటికీ చూడవు.';

  @override
  String get authSignInErrorInvalidCredentials =>
      'తప్పు ఇమెయిల్ లేదా పాస్‌వర్డ్. మరొకసారి ప్రయత్నించండి.';

  @override
  String get authSignInErrorEmailNotVerified =>
      'సైన్ ఇన్ చేయడానికి ముందు మీ ఇమెయిల్‌ను ధృవీకరించండి — లింక్ కోసం మీ ఇన్‌బాక్స్‌ని తనిఖీ చేయండి.';

  @override
  String get authSignInErrorInvalidEmail =>
      'అది చెల్లుబాటు అయ్యే ఇమెయిల్ చిరునామాలా కనిపించడం లేదు.';

  @override
  String get authSignInErrorNetwork =>
      'సర్వర్‌ని చేరుకోలేకపోయింది. మీ కనెక్షన్‌ని తనిఖీ చేసి, మళ్లీ ప్రయత్నించండి.';

  @override
  String get authSignInErrorGeneric =>
      'ఏదో తప్పు జరిగింది. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get authSignInOptionsHintPrefix =>
      'మీరు చివరిసారి ఎలా పొందారో ఖచ్చితంగా తెలియదా? ';

  @override
  String get authSignInOptionsHintCta => 'ప్రతి సైన్-ఇన్ ఎంపికను చూడండి';

  @override
  String get authCreateAccountTitle => 'ఖాతాను సృష్టించండి';

  @override
  String get authBackToInviteCode => 'ఆహ్వాన కోడ్‌కి తిరిగి వెళ్లండి';

  @override
  String get authUseDivineNoBackup => 'బ్యాకప్ లేకుండా Divineని ఉపయోగించండి';

  @override
  String get authSkipConfirmTitle => 'చివరి విషయం...';

  @override
  String get authSkipConfirmKeyCreated =>
      'మీరు ఉన్నారు! మేము మీ Divine ఖాతాను శక్తివంతం చేసే సురక్షిత కీని సృష్టిస్తాము.';

  @override
  String get authSkipConfirmKeyOnly =>
      'ఇమెయిల్ లేకుండా, ఈ ఖాతా మీదే అని Divine తెలుసుకునే ఏకైక మార్గం మీ కీ.';

  @override
  String get authSkipConfirmRecommendEmail =>
      'మీరు యాప్‌లో మీ కీని యాక్సెస్ చేయవచ్చు, కానీ, మీరు సాంకేతికంగా లేకుంటే ఇప్పుడే ఇమెయిల్ మరియు పాస్‌వర్డ్‌ని జోడించమని మేము సిఫార్సు చేస్తున్నాము. మీరు ఈ పరికరాన్ని పోగొట్టుకున్నా లేదా రీసెట్ చేసినా మీ ఖాతాను సైన్ ఇన్ చేయడం మరియు పునరుద్ధరించడం సులభతరం చేస్తుంది.';

  @override
  String get authAddEmailPassword => 'ఇమెయిల్ & పాస్‌వర్డ్‌ని జోడించండి';

  @override
  String get authUseThisDeviceOnly => 'ఈ పరికరాన్ని మాత్రమే ఉపయోగించండి';

  @override
  String get authCompleteRegistration => 'మీ రిజిస్ట్రేషన్‌ను పూర్తి చేయండి';

  @override
  String get authVerifying => 'ధృవీకరిస్తోంది...';

  @override
  String get authVerificationLinkSent => 'మేము వీరికి ధృవీకరణ లింక్‌ని పంపాము:';

  @override
  String get authClickVerificationLink =>
      'దయచేసి మీ నమోదును పూర్తి చేయడానికి మీ ఇమెయిల్‌లోని లింక్‌ను క్లిక్ చేయండి.';

  @override
  String get authPleaseWaitVerifying =>
      'దయచేసి మేము మీ ఇమెయిల్‌ని ధృవీకరించే వరకు వేచి ఉండండి...';

  @override
  String get authWaitingForVerification => 'ధృవీకరణ కోసం వేచి ఉంది';

  @override
  String get authOpenEmailApp => 'ఇమెయిల్ యాప్‌ను తెరవండి';

  @override
  String get authVerificationPinPrompt =>
      'లేదా మీ ఇమెయిల్ నుండి 6-అంకెల కోడ్‌ను నమోదు చేయండి';

  @override
  String get authVerificationPinFieldLabel => '6-అంకెల కోడ్';

  @override
  String get authVerificationPinSubmit => 'కోడ్‌ని ధృవీకరించండి';

  @override
  String get authVerificationResendPrompt => 'అది అర్థం కాలేదా?';

  @override
  String get authVerificationResend => 'మళ్లీ పంపండి';

  @override
  String authVerificationResendCooldown(String time) {
    return 'మళ్లీ పంపండి $time';
  }

  @override
  String get authVerificationResendFailed =>
      'మేము ఇమెయిల్‌ను మళ్లీ పంపలేకపోయాము. మళ్లీ ప్రయత్నించండి.';

  @override
  String get authVerificationResendExpired =>
      'ఆ సైన్అప్ గడువు ముగిసింది. తాజా కోడ్‌ని పొందడానికి మళ్లీ ప్రారంభించండి.';

  @override
  String get authVerificationResendUnavailable =>
      'మళ్లీ పంపడం ప్రస్తుతం అందుబాటులో లేదు. మేము ఇప్పటికే మీకు పంపిన ఇమెయిల్ నుండి 6-అంకెల కోడ్‌ని ఉపయోగించండి.';

  @override
  String get authVerificationPollingStopped =>
      'మేము మీ కోసం తనిఖీ చేయడం ఆపివేసాము. సైన్ ఇన్ చేయడం పూర్తి చేయడానికి మీ ఇమెయిల్ నుండి 6-అంకెల కోడ్‌ను నమోదు చేయండి.';

  @override
  String get authWelcomeToDivine => 'Divineకి స్వాగతం!';

  @override
  String get authEmailVerified => 'మీ ఇమెయిల్ ధృవీకరించబడింది.';

  @override
  String get authSigningYouIn => 'మిమ్మల్ని సైన్ ఇన్ చేస్తున్నాను';

  @override
  String get authErrorTitle => 'అయ్యో.';

  @override
  String get authVerificationFailed =>
      'మేము మీ ఇమెయిల్‌ని ధృవీకరించడంలో విఫలమయ్యాము.\nదయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get authStartOver => 'మళ్లీ ప్రారంభించండి';

  @override
  String get authEmailVerifiedLogin =>
      'ఇమెయిల్ ధృవీకరించబడింది! దయచేసి కొనసాగించడానికి లాగిన్ చేయండి.';

  @override
  String get authVerificationLinkExpired => 'ఈ ధృవీకరణ లింక్ ఇకపై చెల్లదు.';

  @override
  String get authVerificationConnectionError =>
      'ఇమెయిల్‌ని ధృవీకరించడం సాధ్యం కాలేదు. దయచేసి మీ కనెక్షన్‌ని తనిఖీ చేసి, మళ్లీ ప్రయత్నించండి.';

  @override
  String get authWaitlistConfirmTitle => 'మీరు ఉన్నారు!';

  @override
  String authWaitlistUpdatesAt(String email) {
    return 'మేము అప్‌డేట్‌లను ఇందులో భాగస్వామ్యం చేస్తాము $email.\nమరిన్ని ఆహ్వాన కోడ్‌లు అందుబాటులో ఉన్నప్పుడు, మేము వాటిని మీకే పంపుతాము.';
  }

  @override
  String get authOk => 'సరే';

  @override
  String get authTryAgain => 'మళ్లీ ప్రయత్నించండి';

  @override
  String get authContactSupport => 'మద్దతును సంప్రదించండి';

  @override
  String authCouldNotOpenEmail(String email) {
    return 'తెరవడం సాధ్యపడలేదు $email';
  }

  @override
  String get authAddInviteCode => 'మీ ఆహ్వాన కోడ్‌ని జోడించండి';

  @override
  String get authInviteCodeLabel => 'ఆహ్వాన కోడ్';

  @override
  String get authEnterYourCode => 'మీ కోడ్‌ని నమోదు చేయండి';

  @override
  String get authNext => 'తదుపరి';

  @override
  String get authJoinWaitlist => 'వెయిట్‌లిస్ట్‌లో చేరండి';

  @override
  String get authJoinWaitlistTitle => 'వెయిట్‌లిస్ట్‌లో చేరండి';

  @override
  String get authJoinWaitlistDescription =>
      'మీ ఇమెయిల్‌ను భాగస్వామ్యం చేయండి మరియు యాక్సెస్ తెరవబడినప్పుడు మేము ఆహ్వాన కోడ్‌ని పంపుతాము.';

  @override
  String get authJoinWaitlistNewsletterOptIn => 'నాకు Divine స్ఫూర్తిని పంపండి';

  @override
  String get authInviteAccessHelp => 'యాక్సెస్ సహాయాన్ని ఆహ్వానించండి';

  @override
  String get authGeneratingConnection => 'కనెక్షన్‌ని రూపొందిస్తోంది...';

  @override
  String get authConnectedAuthenticating =>
      'కనెక్ట్ చేయబడింది! ప్రమాణీకరిస్తోంది...';

  @override
  String get authConnectionTimedOut => 'కనెక్షన్ సమయం ముగిసింది';

  @override
  String get authApproveConnection =>
      'మీరు మీ సంతకం చేసే యాప్‌లో కనెక్షన్‌ని ఆమోదించారని నిర్ధారించుకోండి.';

  @override
  String get authConnectionCancelled => 'కనెక్షన్ రద్దు చేయబడింది';

  @override
  String get authConnectionCancelledMessage => 'కనెక్షన్ రద్దు చేయబడింది.';

  @override
  String get authConnectionFailed => 'కనెక్షన్ విఫలమైంది';

  @override
  String get authUnknownError => 'తెలియని లోపం సంభవించింది.';

  @override
  String get authNostrConnectStartFailed =>
      'సంతకం చేసిన వ్యక్తిని చేరుకోలేకపోయింది. మీ కనెక్షన్‌ని తనిఖీ చేసి, మళ్లీ ప్రయత్నించండి.';

  @override
  String get authNostrConnectInvalidSession =>
      'ఈ కనెక్షన్ లింక్ ఇకపై చెల్లదు. కొత్తది ప్రారంభించండి.';

  @override
  String get authNostrConnectSetupFailed =>
      'దాదాపు పూర్తయింది — మేము మిమ్మల్ని సైన్ ఇన్ చేయడం పూర్తి చేయలేకపోయాము. మళ్లీ ప్రయత్నించండి.';

  @override
  String get authUrlCopied => 'URL క్లిప్‌బోర్డ్‌కి కాపీ చేయబడింది';

  @override
  String get authConnectToDivine => 'Divineకి కనెక్ట్ చేయండి';

  @override
  String get authPasteBunkerUrl => 'అతికించండి bunker:// URL';

  @override
  String get authBunkerUrlHint => 'bunker:// URL';

  @override
  String get authInvalidBunkerUrl =>
      'చెల్లని bunker URL. ఇది bunker://తో ప్రారంభం కావాలి\nకనెక్ట్ చేయడానికి ';

  @override
  String get authScanSignerApp => 'మీ\nsigner యాప్‌తో స్కాన్ చేయండి.';

  @override
  String authWaitingForConnection(int seconds) {
    return 'కనెక్షన్ కోసం వేచి ఉంది... $secondsసె';
  }

  @override
  String get authCopyUrl => 'URLని కాపీ చేయండి';

  @override
  String get authShare => 'భాగస్వామ్యం చేయండి';

  @override
  String get authAddBunker => 'bunkerని జోడించండి';

  @override
  String get authCompatibleSignerApps => 'అనుకూల సంతకం చేసే యాప్‌లు';

  @override
  String get authFailedToConnect => 'కనెక్ట్ చేయడంలో విఫలమైంది';

  @override
  String get authResetPasswordTitle => 'పాస్‌వర్డ్‌ని రీసెట్ చేయండి';

  @override
  String get authResetPasswordSubtitle =>
      'దయచేసి మీ కొత్త పాస్‌వర్డ్‌ను నమోదు చేయండి. ఇది తప్పనిసరిగా కనీసం 8 అక్షరాల పొడవు ఉండాలి.';

  @override
  String get authNewPasswordLabel => 'కొత్త పాస్‌వర్డ్';

  @override
  String get authConfirmNewPasswordLabel => 'కొత్త పాస్‌వర్డ్‌ను నిర్ధారించండి';

  @override
  String get authPasswordTooShort =>
      'పాస్‌వర్డ్ తప్పనిసరిగా కనీసం 8 అక్షరాలు ఉండాలి';

  @override
  String get authPasswordResetSuccess =>
      'పాస్‌వర్డ్ రీసెట్ విజయవంతమైంది. దయచేసి లాగిన్ అవ్వండి.';

  @override
  String get authPasswordResetFailed => 'పాస్‌వర్డ్ రీసెట్ విఫలమైంది';

  @override
  String get authUnexpectedError =>
      'ఊహించని లోపం సంభవించింది. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get authUpdatePassword => 'పాస్‌వర్డ్‌ను నవీకరించండి';

  @override
  String get authSecureAccountTitle => 'సురక్షిత ఖాతా';

  @override
  String get authUnableToAccessKeys =>
      'మీ కీలను యాక్సెస్ చేయడం సాధ్యపడలేదు. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get authRegistrationFailed => 'నమోదు విఫలమైంది';

  @override
  String get authRegistrationComplete =>
      'నమోదు పూర్తయింది. దయచేసి మీ ఇమెయిల్‌ని తనిఖీ చేయండి.';

  @override
  String get authSecureAccountAlreadyRegistered =>
      'ఖాతా ఇప్పటికే ఉన్నట్లు కనిపిస్తోంది. వేరే ఇమెయిల్‌ని ప్రయత్నించండి లేదా ఈ ఇమెయిల్ చిరునామాతో ఇప్పటికే ఉన్న ఖాతాకు సైన్ ఇన్ చేయండి. రెండూ పని చేయకపోతే, మద్దతును సంప్రదించండి.';

  @override
  String get authFailedToSendResetEmail => 'రీసెట్ ఇమెయిల్ పంపడంలో విఫలమైంది.';

  @override
  String get authSending => 'పంపుతోంది...';

  @override
  String get authSignInButton => 'సైన్ ఇన్ చేయండి';

  @override
  String get authVerificationErrorTimeout =>
      'ధృవీకరణ సమయం ముగిసింది. దయచేసి మళ్లీ నమోదు చేసుకోవడానికి ప్రయత్నించండి.';

  @override
  String get authVerificationErrorMissingCode =>
      'ధృవీకరణ విఫలమైంది — అధికార కోడ్ లేదు.';

  @override
  String get authVerificationErrorPollFailed =>
      'ధృవీకరణ విఫలమైంది. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get authVerificationErrorNetworkExchange =>
      'సైన్-ఇన్ సమయంలో నెట్‌వర్క్ లోపం. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get authVerificationErrorOAuthExchange =>
      'ధృవీకరణ విఫలమైంది. దయచేసి మళ్లీ నమోదు చేసుకోవడానికి ప్రయత్నించండి.';

  @override
  String get authVerificationErrorSignInFailed =>
      'సైన్-ఇన్ విఫలమైంది. దయచేసి మాన్యువల్‌గా లాగిన్ అవ్వడానికి ప్రయత్నించండి.';

  @override
  String get authVerificationEmailAlreadyRegistered =>
      'ఈ ఇమెయిల్ ఇప్పటికే నమోదు చేయబడింది. బదులుగా సైన్ ఇన్ చేయండి.';

  @override
  String get authVerificationErrorPinInvalid =>
      'ఆ కోడ్ సరిపోలలేదు. దీన్ని ఒకటికి రెండుసార్లు తనిఖీ చేసి, మళ్లీ ప్రయత్నించండి.';

  @override
  String get authVerificationErrorPinExpired =>
      'ఆ కోడ్ గడువు ముగిసింది. కొత్తదాన్ని పొందడానికి మళ్లీ పంపు నొక్కండి.';

  @override
  String get authVerificationErrorPinLocked =>
      'చాలా ప్రయత్నాలు చేసారు. తాజా కోడ్‌ని పొందడానికి మళ్లీ పంపు నొక్కండి.';

  @override
  String get authVerificationErrorPinFailed =>
      'మేము ఆ కోడ్‌ని ధృవీకరించలేకపోయాము. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get authVerificationErrorPinUnavailable =>
      'కోడ్ నమోదు ప్రస్తుతం అందుబాటులో లేదు. మీ ఇమెయిల్‌లోని లింక్‌ను నొక్కండి లేదా తాజాదాన్ని పొందడానికి మళ్లీ పంపండి.';

  @override
  String get authInviteCodeErrorMalformed =>
      'ABCD-EFGH వంటి ఆహ్వాన కోడ్‌ని నమోదు చేయండి.';

  @override
  String get authInviteCodeErrorNotFound =>
      'ఆ ఆహ్వాన కోడ్ చెల్లుబాటు అయ్యేలా లేదు.';

  @override
  String get authInviteCodeErrorAlreadyUsed =>
      'ఆ ఆహ్వాన కోడ్ ఇప్పటికే ఉపయోగించబడింది లేదా రద్దు చేయబడింది.';

  @override
  String get authInviteGateErrorCreatorFull =>
      'ఈ సృష్టికర్త ఆహ్వానాలు నిండిపోయాయి';

  @override
  String get authInviteGateErrorUnavailable =>
      'ఆ ఆహ్వాన కోడ్ అందుబాటులో లేదు. వెయిట్‌లిస్ట్‌లో చేరండి మరియు స్థలం ఉన్నప్పుడు మేము ఆహ్వానాన్ని పంపుతాము.';

  @override
  String get authInviteGateErrorCheckFailed =>
      'మేము ఆ కోడ్‌ని తనిఖీ చేయలేకపోయాము. మళ్లీ ప్రయత్నించండి.';

  @override
  String get authInviteGateErrorUnknown =>
      'ఏదో తప్పు జరిగింది. మీ ఆహ్వాన కోడ్‌ని మళ్లీ ప్రయత్నించండి.';

  @override
  String get authInviteErrorAlreadyUsed =>
      'ఆ ఆహ్వాన కోడ్ అందుబాటులో లేదు. మీ ఆహ్వాన కోడ్‌కి తిరిగి వెళ్లండి, వెయిట్‌లిస్ట్‌లో చేరండి లేదా మద్దతును సంప్రదించండి.';

  @override
  String get authInviteErrorInvalid =>
      'ఆ ఆహ్వాన కోడ్ ప్రస్తుతం ఉపయోగించబడదు. మీ ఆహ్వాన కోడ్‌కి తిరిగి వెళ్లండి, వెయిట్‌లిస్ట్‌లో చేరండి లేదా మద్దతును సంప్రదించండి.';

  @override
  String get authInviteErrorTemporary =>
      'మేము ప్రస్తుతం మీ ఆహ్వానాన్ని నిర్ధారించలేకపోయాము. మీ ఆహ్వాన కోడ్‌కి తిరిగి వెళ్లి, మళ్లీ ప్రయత్నించండి లేదా మద్దతును సంప్రదించండి.';

  @override
  String get authInviteErrorUnknown =>
      'మేము మీ ఆహ్వానాన్ని సక్రియం చేయలేకపోయాము. మీ ఆహ్వాన కోడ్‌కి తిరిగి వెళ్లండి, వెయిట్‌లిస్ట్‌లో చేరండి లేదా మద్దతును సంప్రదించండి.';

  @override
  String get shareSheetSave => 'సేవ్ చేయండి';

  @override
  String get shareSheetRemoveFromSaved => 'సేవ్ చేయబడిన వాటి నుండి తీసివేయండి';

  @override
  String get shareSheetSaveToGallery => 'గ్యాలరీకి సేవ్ చేయండి';

  @override
  String get shareSheetSaveWithWatermark => 'వాటర్‌మార్క్‌తో సేవ్ చేయండి';

  @override
  String get shareSheetSaveVideo => 'వీడియోను సేవ్ చేయండి';

  @override
  String get shareSheetAddToClips => 'క్లిప్‌లకు జోడించండి';

  @override
  String get shareSheetNameClipTitle => 'ఈ క్లిప్‌కు పేరు పెట్టండి';

  @override
  String get shareSheetNameClipSubtitle =>
      'మీ లైబ్రరీలో మీరు గుర్తించే పేరును ఎంచుకోండి.';

  @override
  String get shareSheetClipTitleLabel => 'క్లిప్ శీర్షిక';

  @override
  String get shareSheetSaveClip => 'క్లిప్‌ను సేవ్ చేయండి';

  @override
  String shareSheetSavedClipToClips(String title) {
    return 'సేవ్ చేయబడింది \"$title\"';
  }

  @override
  String get shareSheetUntitledClip => 'శీర్షికలేని క్లిప్';

  @override
  String get shareSheetAddToClipsFailed => 'క్లిప్‌లకు జోడించడం సాధ్యపడలేదు';

  @override
  String get shareSheetAddToList => 'జాబితాకు జోడించండి';

  @override
  String get shareSheetCopy => 'కాపీ';

  @override
  String get shareSheetShareVia => 'ద్వారా భాగస్వామ్యం చేయండి';

  @override
  String get shareSheetEventJson => 'ఈవెంట్ JSON';

  @override
  String get shareSheetEventId => 'ఈవెంట్ ID';

  @override
  String get shareSheetMoreActions => 'మరిన్ని చర్యలు';

  @override
  String get shareSheetCrosspost => 'క్రాస్‌పోస్ట్';

  @override
  String get crosspostSheetTitle => 'ఈ వీడియోను క్రాస్‌పోస్ట్ చేయండి';

  @override
  String get crosspostSheetSubtitle =>
      'దీన్ని మీ కనెక్ట్ చేయబడిన ప్లాట్‌ఫారమ్‌లకు పంపండి. పోస్ట్ చేయడానికి కొన్ని నిమిషాలు పట్టవచ్చు.';

  @override
  String get crosspostSubmit => 'క్రాస్‌పోస్ట్';

  @override
  String get crosspostStatusQueued => 'క్యూలో ఉంది';

  @override
  String get crosspostStatusUploading => 'అప్‌లోడ్ అవుతోంది';

  @override
  String get crosspostStatusProcessing => 'ప్రాసెసింగ్';

  @override
  String get crosspostStatusPosted => 'పోస్ట్ చేయబడింది';

  @override
  String get crosspostStatusFailed => 'విఫలమైంది';

  @override
  String get crosspostStatusSkipped => 'దాటవేయబడింది';

  @override
  String get crosspostStatusNeedsReauth => 'మళ్లీ కనెక్ట్ కావాలి';

  @override
  String get crosspostViewPost => 'పోస్ట్‌ను వీక్షించండి';

  @override
  String crosspostReconnectPrompt(String platform) {
    return 'మళ్లీ కనెక్ట్ చేయండి \nపోస్ట్ చేయడం కొనసాగించడానికి క్రాస్‌పోస్టింగ్ సెట్టింగ్‌లలో $platform.';
  }

  @override
  String get crosspostReconnect => 'మళ్లీ కనెక్ట్ చేయండి';

  @override
  String get crosspostErrorNotOwner =>
      'మీ స్వంత వీడియోలు మాత్రమే క్రాస్‌పోస్ట్ చేయబడతాయి.';

  @override
  String get crosspostErrorNotEligible =>
      'ఈ వీడియో క్రాస్‌పోస్టింగ్‌కు అర్హత లేదు.';

  @override
  String get crosspostErrorNotConnected => 'ఆ ప్లాట్‌ఫారమ్ కనెక్ట్ చేయబడలేదు.';

  @override
  String get crosspostErrorUnauthorized =>
      'మీ ఖాతాను మళ్లీ కనెక్ట్ చేసి, ఆపై మళ్లీ ప్రయత్నించండి.';

  @override
  String get crosspostErrorNetwork =>
      'క్రాస్‌పోస్టర్‌ని చేరుకోలేకపోయింది. క్షణంలో మళ్లీ ప్రయత్నించండి.';

  @override
  String get crosspostFailedGeneric => 'క్రాస్‌పోస్ట్ విఫలమైంది.';

  @override
  String get crosspostStillWorking =>
      'ఇంకా పని చేస్తోంది. మీరు దీన్ని మూసివేయవచ్చు - నేపథ్యంలో పోస్టింగ్ కొనసాగుతుంది.';

  @override
  String get crosspostDone => 'పూర్తయింది';

  @override
  String get watermarkDownloadSavedToCameraRoll =>
      'కెమెరా రోల్‌కి సేవ్ చేయబడింది';

  @override
  String get watermarkDownloadShare => 'భాగస్వామ్యం చేయండి';

  @override
  String get watermarkDownloadDone => 'పూర్తయింది';

  @override
  String get watermarkDownloadPhotosAccessNeeded => 'ఫోటోల యాక్సెస్ అవసరం';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      'వీడియోలను సేవ్ చేయడానికి, సెట్టింగ్‌లలో ఫోటోల యాక్సెస్‌ను అనుమతించండి.';

  @override
  String get watermarkDownloadOpenSettings => 'సెట్టింగ్‌లను తెరవండి';

  @override
  String get watermarkDownloadNotNow => 'ఇప్పుడు కాదు';

  @override
  String get watermarkDownloadFailed => 'డౌన్‌లోడ్ విఫలమైంది';

  @override
  String get watermarkDownloadDismiss => 'తీసివేయండి';

  @override
  String get watermarkDownloadStageDownloading => 'వీడియో డౌన్‌లోడ్ అవుతోంది';

  @override
  String get watermarkDownloadStageWatermarking => 'వాటర్‌మార్క్ కలుపుతోంది';

  @override
  String get watermarkDownloadStageSaving => 'కెమెరా రోల్‌కు సేవ్ చేస్తోంది';

  @override
  String get watermarkDownloadStageDownloadingDesc =>
      'నెట్‌వర్క్ నుండి వీడియోని పొందుతోంది...';

  @override
  String get watermarkDownloadStageWatermarkingDesc =>
      'Divine వాటర్‌మార్క్‌ని వర్తింపజేస్తోంది...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      'వాటర్‌మార్క్ చేసిన వీడియోను మీ కెమెరా రోల్‌లో సేవ్ చేస్తోంది...';

  @override
  String get shareMenuBookmarks => 'బుక్‌మార్క్‌లు';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countఫాలో సెట్‌లు అందుబాటులో ఉన్నాయి',
      one: '$countఫాలో సెట్ అందుబాటులో ఉంది',
    );
    return '$_temp0';
  }

  @override
  String get peopleListsAddToList => 'జాబితాకు జోడించండి';

  @override
  String get peopleListsSheetTitle => 'జాబితాకు జోడించండి';

  @override
  String get peopleListsEmptyTitle => 'ఇంకా జాబితాలు లేవు';

  @override
  String get peopleListsEmptySubtitle =>
      'వ్యక్తులను సమూహపరచడం ప్రారంభించడానికి జాబితాను సృష్టించండి.';

  @override
  String get peopleListsCreateList => 'జాబితాను సృష్టించండి';

  @override
  String get peopleListsNewListTitle => 'కొత్త జాబితా';

  @override
  String get peopleListsRouteTitle => 'వ్యక్తుల జాబితా';

  @override
  String get peopleListsListNameLabel => 'జాబితా పేరు';

  @override
  String get peopleListsListNameHint => 'సన్నిహిత స్నేహితులు';

  @override
  String get peopleListsCreateButton => 'సృష్టించు';

  @override
  String get peopleListsAddPeopleTitle => 'వ్యక్తులను జోడించండి';

  @override
  String get peopleListsAddPeopleTooltip => 'వ్యక్తులను జోడించండి';

  @override
  String get peopleListsAddPeopleSemanticLabel =>
      'జాబితాకు వ్యక్తులను జోడించండి';

  @override
  String get peopleListsListNotFoundTitle => 'జాబితా కనుగొనబడలేదు';

  @override
  String get peopleListsListNotFoundSubtitle =>
      'జాబితా కనుగొనబడలేదు. ఇది తొలగించబడి ఉండవచ్చు.';

  @override
  String get peopleListsListDeletedSubtitle => 'ఈ జాబితా తొలగించబడి ఉండవచ్చు.';

  @override
  String get peopleListsNoPeopleTitle => 'ఈ జాబితాలో వ్యక్తులు లేరు';

  @override
  String get peopleListsNoPeopleSubtitle =>
      'ప్రారంభించడానికి కొంతమంది వ్యక్తులను జోడించండి';

  @override
  String get peopleListsNoVideosTitle => 'ఇంకా వీడియోలు లేవు';

  @override
  String get peopleListsNoVideosSubtitle =>
      'జాబితా సభ్యుల నుండి వీడియోలు ఇక్కడ కనిపిస్తాయి';

  @override
  String get peopleListsNoVideosAvailable => 'వీడియోలు అందుబాటులో లేవు';

  @override
  String get peopleListsFailedToLoadVideos =>
      'వీడియోలను లోడ్ చేయడంలో విఫలమైంది';

  @override
  String get peopleListsVideoNotAvailable => 'వీడియో అందుబాటులో లేదు';

  @override
  String get peopleListsBackToGridTooltip => 'తిరిగి గ్రిడ్‌కి';

  @override
  String get peopleListsErrorLoadingVideos => 'వీడియోలను లోడ్ చేయడంలో లోపం';

  @override
  String get peopleListsNoPeopleToAdd =>
      'జోడించడానికి వ్యక్తులు ఎవరూ అందుబాటులో లేరు.';

  @override
  String peopleListsAddToListName(String name) {
    return 'దీనికి జోడించండి $name';
  }

  @override
  String get peopleListsAddPeopleSearchHint => 'వ్యక్తులను శోధించండి';

  @override
  String get peopleListsAddPeopleError =>
      'వ్యక్తులను లోడ్ చేయడం సాధ్యపడలేదు. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get peopleListsAddPeopleRetry => 'మళ్లీ ప్రయత్నించండి';

  @override
  String get peopleListsAddButton => 'జోడించండి';

  @override
  String peopleListsAddButtonWithCount(int count) {
    return 'జోడించండి $count';
  }

  @override
  String peopleListsInNLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count జాబితాల్లో',
      one: '1 జాబితాలో',
    );
    return '$_temp0';
  }

  @override
  String peopleListsRemoveConfirmTitle(String name) {
    return 'తీసివేయి $name?';
  }

  @override
  String get peopleListsRemoveConfirmBody =>
      'వారు ఈ జాబితా నుండి తీసివేయబడతారు.';

  @override
  String get peopleListsRemove => 'తీసివేయి';

  @override
  String peopleListsRemovedFromList(String name) {
    return 'తీసివేయబడింది \nజాబితా నుండి $name';
  }

  @override
  String get peopleListsUndo => 'అన్డు';

  @override
  String peopleListsProfileLongPressHint(String name) {
    return 'ప్రొఫైల్ $name. తీసివేయడానికి ఎక్కువసేపు నొక్కండి.';
  }

  @override
  String peopleListsViewProfileHint(String name) {
    return 'దీని కోసం ప్రొఫైల్‌ని వీక్షించండి $name';
  }

  @override
  String get shareMenuEditVideo => 'వీడియోను సవరించండి';

  @override
  String get shareMenuDeleteVideo => 'వీడియోని తొలగించండి';

  @override
  String shareMenuVideoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countవీడియోలు',
      one: '$countవీడియో',
    );
    return '$_temp0';
  }

  @override
  String get shareMenuDeleteConfirmation =>
      'ఇది Divine నుండి ఈ వీడియోని శాశ్వతంగా తొలగిస్తుంది. ఇది ఇప్పటికీ ఇతర రిలేలను ఉపయోగించే మూడవ పక్షం Nostr క్లయింట్‌లలో కనిపించవచ్చు.';

  @override
  String get shareMenuCancel => 'రద్దు';

  @override
  String get shareMenuDelete => 'తొలగించు';

  @override
  String get shareMenuDeleteFailedNotInitialized =>
      'తొలగింపు ఇంకా సిద్ధంగా లేదు. క్షణంలో మళ్లీ ప్రయత్నించండి.';

  @override
  String get shareMenuDeleteFailedNotOwner =>
      'మీరు మీ స్వంత వీడియోలను మాత్రమే తొలగించగలరు.';

  @override
  String get shareMenuDeleteFailedNotAuthenticated =>
      'మళ్లీ సైన్ ఇన్ చేసి, ఆపై తొలగించడానికి ప్రయత్నించండి.';

  @override
  String get shareMenuDeleteFailedCouldNotSign =>
      'తొలగింపు అభ్యర్థనపై సంతకం చేయడం సాధ్యపడలేదు. మళ్లీ ప్రయత్నించండి.';

  @override
  String get shareMenuDeleteFailedRelayRejected =>
      'రిలే ఈ తొలగింపు అభ్యర్థనను అంగీకరించదు. క్షణంలో మళ్లీ ప్రయత్నించండి.';

  @override
  String get shareMenuDeleteFailedAccountRestricted =>
      'మీ ఖాతా పరిమితం చేయబడింది, కాబట్టి ఈ తొలగింపు అభ్యర్థన పంపబడదు. దీన్ని తొలగించడంలో సహాయం కోసం మద్దతును సంప్రదించండి.';

  @override
  String get shareMenuDeleteFailedRelayNoResponse =>
      'రిలేను చేరుకోలేకపోయింది. మీ కనెక్షన్‌ని తనిఖీ చేసి, మళ్లీ ప్రయత్నించండి.';

  @override
  String get shareMenuDeletePartiallyConfirmed =>
      'తొలగించబడింది. ప్రతి రిలే నిర్ధారించబడలేదు, కనుక ఇది ఇప్పటికీ ఇతర యాప్‌లలో చూపబడవచ్చు.';

  @override
  String get shareMenuDeleteFailedGeneric =>
      'ఈ వీడియోని తొలగించడం సాధ్యపడలేదు. మళ్లీ ప్రయత్నించండి.';

  @override
  String get shareMenuUpdate => 'నవీకరణ';

  @override
  String get shareMenuChangeCover => 'కవర్ మార్చండి';

  @override
  String get shareMenuVideoUpdated => 'వీడియో విజయవంతంగా నవీకరించబడింది';

  @override
  String shareMenuVideoUpdatedWithInviteFailures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countసహకారి ఆహ్వానాలు పంపలేదు.',
      one: '1 సహకారి ఆహ్వానం పంపలేదు.',
    );
    return 'వీడియో నవీకరించబడింది, కానీ $_temp0';
  }

  @override
  String get videoUpdateErrorNotAuthenticated =>
      'మళ్లీ సైన్ ఇన్ చేసి, అప్‌డేట్ చేయడానికి ప్రయత్నించండి.';

  @override
  String get videoUpdateErrorNoPlayableVideo =>
      'ఈ వీడియోలో ప్లే చేయదగిన మూలం లేదు, కనుక ఇది నవీకరించబడదు.';

  @override
  String get videoUpdateErrorCouldNotSign =>
      'నవీకరణపై సంతకం చేయడం సాధ్యపడలేదు. మళ్లీ ప్రయత్నించండి.';

  @override
  String get videoUpdateErrorPublishRejected =>
      'రిలే నవీకరణను అంగీకరించదు. క్షణంలో మళ్లీ ప్రయత్నించండి.';

  @override
  String get videoUpdateErrorGeneric =>
      'ఈ వీడియోని అప్‌డేట్ చేయడం సాధ్యపడలేదు. మళ్లీ ప్రయత్నించండి.';

  @override
  String get shareMenuOriginalVideoUnavailable =>
      'అసలు వీడియోను లోడ్ చేయడం సాధ్యపడలేదు. క్షణంలో మళ్లీ ప్రయత్నించండి.';

  @override
  String get shareMenuDeleteVideoQuestion => 'వీడియోని తొలగించాలా?';

  @override
  String get shareMenuDeleteCleanupInProgress => 'వీడియోని తీసివేస్తోంది…';

  @override
  String get shareMenuDeleteCleanupConfirmed => 'వీడియో తొలగించబడింది.';

  @override
  String get shareMenuDeleteCleanupDelayed =>
      'వీడియో తొలగించబడింది. ప్రతిచోటా అదృశ్యం కావడానికి కొంచెం సమయం పట్టవచ్చు.';

  @override
  String get shareMenuDeleteCleanupFailed =>
      'వీడియో తొలగించబడింది, కానీ మేము ప్రతి కాపీని తీసివేయలేకపోయాము. దయచేసి మద్దతును సంప్రదించండి.';

  @override
  String get authSessionExpired =>
      'మీ సెషన్ గడువు ముగిసింది. దయచేసి మళ్లీ సైన్ ఇన్ చేయండి.';

  @override
  String get authAccountRestoreFailed =>
      'మేము ఈ పరికరంలో ఆ ఖాతాను అన్‌లాక్ చేయలేకపోయాము. మళ్లీ సైన్ ఇన్ చేయండి.';

  @override
  String get authSignInFailed =>
      'సైన్ ఇన్ చేయడంలో విఫలమైంది. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get webAuthNotSupportedSecureMode =>
      'సురక్షిత మోడ్‌లో వెబ్ ప్రమాణీకరణకు మద్దతు లేదు. సురక్షిత కీ నిర్వహణ కోసం దయచేసి మొబైల్ యాప్‌ని ఉపయోగించండి.';

  @override
  String get webAuthEnterBunkerUri => 'దయచేసి bunker URIని నమోదు చేయండి';

  @override
  String get webAuthConnectTitle => 'Divineకి కనెక్ట్ చేయండి';

  @override
  String get webAuthChooseMethod =>
      'మీకు ఇష్టమైన Nostr ప్రమాణీకరణ పద్ధతిని ఎంచుకోండి';

  @override
  String get webAuthBrowserExtension => 'బ్రౌజర్ పొడిగింపు';

  @override
  String get webAuthRecommended => 'సిఫార్సు చేయబడింది';

  @override
  String get webAuthNsecBunker => 'nsec bunker';

  @override
  String get webAuthConnectRemoteSigner => 'రిమోట్ సైనర్‌కి కనెక్ట్ చేయండి';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => 'క్లిప్‌బోర్డ్ నుండి అతికించండి';

  @override
  String get webAuthConnectToBunker => 'Bunkerకి కనెక్ట్ చేయండి';

  @override
  String get webAuthNewToNostr => 'Nostrకి కొత్తదా?';

  @override
  String get webAuthNostrHelp =>
      'సులభమైన అనుభవం కోసం Alby లేదా nos2x వంటి బ్రౌజర్ పొడిగింపును ఇన్‌స్టాల్ చేయండి లేదా సురక్షితమైన రిమోట్ సంతకం కోసం nsec bunkerని ఉపయోగించండి.';

  @override
  String get soundsTitle => 'శబ్దాలు';

  @override
  String get soundsSearchHint => 'శోధన శబ్దాలు...';

  @override
  String get soundsSearchResults => 'శోధన ఫలితాలు';

  @override
  String get soundsNoSoundsFound => 'శబ్దాలు ఏవీ కనుగొనబడలేదు';

  @override
  String get soundsNoSoundsFoundDescription =>
      'వేరొక శోధన పదాన్ని ప్రయత్నించండి';

  @override
  String get soundsSavedToLibrary => 'సౌండ్‌లకు సేవ్ చేయబడింది';

  @override
  String get soundsAlreadySavedToLibrary => 'ఇప్పటికే సౌండ్స్‌లో ఉన్నాయి';

  @override
  String get soundsSavedLibraryTitle => 'నా సౌండ్స్';

  @override
  String get soundsSavedEmptyTitle => 'ఇంకా సేవ్ చేయబడిన శబ్దాలు లేవు';

  @override
  String get soundsSavedEmptyDescription =>
      'వీడియోను ఇక్కడ సేవ్ చేయడానికి సౌండ్ ఉపయోగించండి నొక్కండి.';

  @override
  String get soundsRemoveSavedSound => 'ధ్వనిని తీసివేయండి';

  @override
  String get savedSoundSaveAction => 'సేవ్ చేయండి';

  @override
  String get savedSoundPausePreviewAction => 'ప్రివ్యూను పాజ్ చేయండి';

  @override
  String get savedSoundResumePreviewAction => 'ప్రివ్యూను పునఃప్రారంభించండి';

  @override
  String get savedSoundDetailsSheetTitle => 'ధ్వని వివరాలు';

  @override
  String get savedSoundRemoveConfirmTitle => 'ఈ ధ్వనిని తీసివేయాలా?';

  @override
  String get savedSoundRemoveConfirmMessage =>
      'ఇది మీ లైబ్రరీని వదిలివేస్తుంది, కానీ మీరు దాన్ని ఉపయోగించే ఏదైనా వీడియో నుండి దాన్ని మళ్లీ సేవ్ చేయవచ్చు.';

  @override
  String get soundsRemovedFromLibrary => 'సౌండ్స్ నుండి తీసివేయబడింది';

  @override
  String get soundsSaveFailed =>
      'ఆ ధ్వనిని సేవ్ చేయడం సాధ్యపడలేదు. మళ్లీ ప్రయత్నించండి.';

  @override
  String get soundsRemoveFailed =>
      'ఆ ధ్వనిని తీసివేయడం సాధ్యపడలేదు. మళ్లీ ప్రయత్నించండి.';

  @override
  String get soundSyncStatusSyncing => 'మీ శబ్దాలను సమకాలీకరిస్తోంది...';

  @override
  String get soundSyncStatusSynced => 'తాజాగా వినిపిస్తోంది';

  @override
  String get soundSyncStatusFailed =>
      'మీ సౌండ్‌లను సింక్ చేయడం సాధ్యపడలేదు. మేము మళ్లీ ప్రయత్నిస్తాము.';

  @override
  String get soundSyncStatusLocked =>
      'ఈ పరికరంలో మీ సమకాలీకరించబడిన లైబ్రరీని అన్‌లాక్ చేయడం సాధ్యపడదు.';

  @override
  String get profileTitle => 'ప్రొఫైల్';

  @override
  String get profileMoreOptions => 'మరిన్ని ఎంపికలు';

  @override
  String profileBlockedUser(String name) {
    return 'నిరోధించబడింది $name';
  }

  @override
  String profileUnblockedUser(String name) {
    return 'అన్‌బ్లాక్ చేయబడింది $name';
  }

  @override
  String profileUnfollowedUser(String name) {
    return 'అనుసరించలేదు $name';
  }

  @override
  String get profileFeedError =>
      'సర్వర్‌ని చేరుకోలేదు. మీ కనెక్షన్‌ని తనిఖీ చేసి, మళ్లీ ప్రయత్నించండి.';

  @override
  String get profileFeedLoadMoreError =>
      'మరిన్ని వీడియోలను లోడ్ చేయడం సాధ్యపడలేదు. రిఫ్రెష్ చేయడానికి లాగండి.';

  @override
  String get notificationsTabAll => 'అన్నీ';

  @override
  String get notificationsTabLikes => 'ఇష్టాలు';

  @override
  String get notificationsTabComments => 'వ్యాఖ్యలు';

  @override
  String get notificationsTabFollows => 'అనుసరిస్తుంది';

  @override
  String get notificationsTabReposts => 'రీపోస్ట్‌లు';

  @override
  String get notificationsFailedToLoad =>
      'నోటిఫికేషన్‌లను లోడ్ చేయడంలో విఫలమైంది';

  @override
  String get notificationsRetry => 'మళ్లీ ప్రయత్నించండి';

  @override
  String get notificationsRefreshError =>
      'రిఫ్రెష్ చేయడం సాధ్యపడలేదు — మీ వద్ద ఉన్న వాటిని చూపుతోంది';

  @override
  String get notificationsUnreadPrefix => 'చదవని నోటిఫికేషన్';

  @override
  String notificationsBadgeUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countచదవని నోటిఫికేషన్‌లు',
      one: '1 చదవని నోటిఫికేషన్',
    );
    return '$_temp0';
  }

  @override
  String notificationsViewProfileSemanticLabel(String displayName) {
    return 'వీక్షించండి $displayNameప్రొఫైల్';
  }

  @override
  String get notificationsViewProfilesSemanticLabel =>
      'ప్రొఫైల్‌లను వీక్షించండి';

  @override
  String notificationsVideoThumbnailFor(String title) {
    return 'వీడియో సూక్ష్మచిత్రం కోసం $title';
  }

  @override
  String get notificationsVideoThumbnail => 'వీడియో సూక్ష్మచిత్రం';

  @override
  String get notificationsInviteSingular =>
      'స్నేహితుడితో భాగస్వామ్యం చేయడానికి మీకు 1 ఆహ్వానం ఉంది!';

  @override
  String notificationsInvitePlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'మీరు కలిగి ఉన్నారు $countస్నేహితులతో భాగస్వామ్యం చేయడానికి ఆహ్వానిస్తున్నారు!',
      one:
          'మీరు కలిగి ఉన్నారు $countస్నేహితులతో భాగస్వామ్యం చేయడానికి ఆహ్వానించండి!',
    );
    return '$_temp0';
  }

  @override
  String notificationsTabBadges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'బ్యాడ్జ్‌లు ($count)',
      zero: 'బ్యాడ్జ్‌లు',
    );
    return '$_temp0';
  }

  @override
  String notificationsPendingBadges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countబ్యాడ్జ్‌లు వేచి ఉన్నాయి',
      one: 'మీరు ఆమోదించడానికి బ్యాడ్జ్ వేచి ఉంది\nమీరు వాటిని ఆమోదించడానికి ',
    );
    return '$_temp0';
  }

  @override
  String get notificationsBadgesEmpty =>
      'బ్యాడ్జ్‌లు ఏవీ వేచి ఉండవు. ఎవరైనా మీకు అవార్డు ఇస్తే, అది ఇక్కడకు వస్తుంది.';

  @override
  String get notificationsVideoUnavailable => 'వీడియో అందుబాటులో లేదు';

  @override
  String get feedFailedToLoadVideos => 'వీడియోలను లోడ్ చేయడంలో విఫలమైంది';

  @override
  String get feedRetry => 'మళ్లీ ప్రయత్నించండి';

  @override
  String get feedNoFollowedUsers =>
      'అనుసరించే వినియోగదారులు లేరు.\nఎవరైనా వారి వీడియోలను ఇక్కడ చూడటానికి వారిని అనుసరించండి.';

  @override
  String get feedModeForYou => 'మీ కోసం';

  @override
  String get feedModeNew => 'కొత్తది';

  @override
  String get feedModeFollowing => 'అనుసరిస్తున్నారు';

  @override
  String get feedModeClassics => 'క్లాసిక్స్';

  @override
  String feedModeSemanticLabel(String label) {
    return 'ఫీడ్ మోడ్: $label';
  }

  @override
  String videoAuthorSemanticLabel(String displayName) {
    return 'వీడియో రచయిత: $displayName';
  }

  @override
  String get videoAuthorAvatarSemanticLabel => 'రచయిత అవతార్';

  @override
  String get feedForYouEmpty =>
      'మీ కోసం మీ ఫీడ్ ఖాళీగా ఉంది.\nవీడియోలను అన్వేషించండి మరియు దానిని ఆకృతి చేయడానికి సృష్టికర్తలను అనుసరించండి.';

  @override
  String get feedFollowingEmpty =>
      'మీరు అనుసరించే వ్యక్తుల నుండి ఇంకా వీడియోలు లేవు.\nమీకు నచ్చిన సృష్టికర్తలను కనుగొని వారిని అనుసరించండి.';

  @override
  String get feedLatestEmpty =>
      'ఇంకా కొత్త వీడియోలు లేవు.\nత్వరలో మళ్లీ తనిఖీ చేయండి.';

  @override
  String get feedClassicEmpty =>
      'ఇంకా క్లాసిక్ వైన్‌లు లేవు.\nత్వరలో మళ్లీ తనిఖీ చేయండి.';

  @override
  String get feedExploreVideos => 'వీడియోలను అన్వేషించండి';

  @override
  String get feedLoadingMore => 'మరిన్ని వీడియోలను లోడ్ చేస్తోంది…';

  @override
  String get feedRefreshed => 'ఫీడ్ రిఫ్రెష్ చేయబడింది';

  @override
  String get uploadUploadingVideo => 'వీడియోను అప్‌లోడ్ చేస్తోంది';

  @override
  String get postPublishConfirmationTitle => 'మీ ప్రొఫైల్‌లో ప్రచురించబడింది';

  @override
  String get postPublishConfirmationView => 'వీక్షించండి';

  @override
  String get postPublishConfirmationShare => 'భాగస్వామ్యం చేయండి';

  @override
  String get postPublishConfirmationThumbnailLabel =>
      'మీరు ఇప్పుడే ప్రచురించిన వీడియో యొక్క సూక్ష్మచిత్రం';

  @override
  String get userSearchNoResults => 'వినియోగదారులు ఎవరూ కనుగొనబడలేదు';

  @override
  String get userPickerFilterByNameHint => 'పేరుతో ఫిల్టర్ చేయండి...';

  @override
  String get userPickerSearchByNameHint => 'పేరుతో శోధించండి...';

  @override
  String get userPickerClearSearchSemantics => 'శోధనను క్లియర్ చేయండి';

  @override
  String userPickerAlreadyAddedSemantics(String name) {
    return '$nameఇప్పటికే జోడించబడింది';
  }

  @override
  String userPickerSelectSemantics(String name) {
    return 'ఎంచుకోండి $name';
  }

  @override
  String userPickerRemoveSelectionSemantics(String name) {
    return 'తీసివేయి $name';
  }

  @override
  String get userPickerEmptyFollowListTitle => 'మీ సిబ్బంది అక్కడ ఉన్నారు';

  @override
  String get userPickerEmptyFollowListBody =>
      'మీరు వైబ్ చేసే వ్యక్తులను అనుసరించండి. వారు తిరిగి అనుసరించినప్పుడు, మీరు సహకరించవచ్చు.';

  @override
  String get userPickerGoBack => 'వెనక్కి వెళ్లండి';

  @override
  String get userPickerTypeNameToSearch => 'శోధించడానికి పేరును టైప్ చేయండి';

  @override
  String get userPickerUnavailable =>
      'వినియోగదారు శోధన అందుబాటులో లేదు. దయచేసి తర్వాత మళ్లీ ప్రయత్నించండి.';

  @override
  String get userPickerSearchFailedTryAgain =>
      'శోధన విఫలమైంది. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get forgotPasswordTitle => 'పాస్‌వర్డ్‌ని రీసెట్ చేయండి';

  @override
  String get forgotPasswordDescription =>
      'మీ ఇమెయిల్ చిరునామాను నమోదు చేయండి మరియు మీ పాస్‌వర్డ్‌ని రీసెట్ చేయడానికి మేము మీకు లింక్‌ను పంపుతాము.';

  @override
  String get forgotPasswordEmailLabel => 'ఇమెయిల్ చిరునామా';

  @override
  String get forgotPasswordCancel => 'రద్దు';

  @override
  String get forgotPasswordSendLink => 'ఇమెయిల్ రీసెట్ లింక్';

  @override
  String get ageVerificationContentWarning => 'కంటెంట్ హెచ్చరిక';

  @override
  String get ageVerificationTitle => 'వయస్సు ధృవీకరణ';

  @override
  String get ageVerificationAdultDescription =>
      'ఈ కంటెంట్ అడల్ట్ మెటీరియల్‌ని కలిగి ఉండే అవకాశం ఉందని ఫ్లాగ్ చేయబడింది. దీన్ని వీక్షించడానికి మీకు 18 లేదా అంతకంటే ఎక్కువ వయస్సు ఉండాలి.';

  @override
  String get ageVerificationCreationDescription =>
      'కెమెరాను ఉపయోగించడానికి మరియు కంటెంట్‌ని సృష్టించడానికి, మీకు కనీసం 16 ఏళ్లు ఉండాలి.';

  @override
  String get ageVerificationAdultQuestion =>
      'మీ వయస్సు 18 సంవత్సరాలు లేదా అంతకంటే ఎక్కువ?';

  @override
  String get ageVerificationCreationQuestion =>
      'మీ వయస్సు 16 సంవత్సరాలు లేదా అంతకంటే ఎక్కువ?';

  @override
  String get ageVerificationNo => 'నం';

  @override
  String get ageVerificationYes => 'అవును';

  @override
  String get navHome => 'హోమ్';

  @override
  String get navExplore => 'అన్వేషించండి';

  @override
  String get navInbox => 'ఇన్‌బాక్స్';

  @override
  String get navProfile => 'ప్రొఫైల్';

  @override
  String get navMyProfile => 'నా ప్రొఫైల్';

  @override
  String get navNotifications => 'నోటిఫికేషన్‌లు';

  @override
  String get navOpenCamera => 'కెమెరా తెరవండి';

  @override
  String get navExploreClassics => 'క్లాసిక్స్';

  @override
  String get navExploreNewVideos => 'కొత్త వీడియోలు';

  @override
  String get navExploreTrending => 'ట్రెండింగ్';

  @override
  String get navExploreForYou => 'మీ కోసం';

  @override
  String get navExploreLists => 'జాబితాలు';

  @override
  String get routeErrorTitle => 'లోపం';

  @override
  String get routeInvalidHashtag => 'హ్యాష్‌ట్యాగ్ చెల్లదు';

  @override
  String get routeInvalidConversationId => 'చెల్లని సంభాషణ ID';

  @override
  String get routeInvalidRequestId => 'చెల్లని అభ్యర్థన ID';

  @override
  String get routeInvalidListId => 'చెల్లని జాబితా ID';

  @override
  String get routeInvalidUserId => 'చెల్లని వినియోగదారు ID';

  @override
  String get routeInvalidVideoId => 'చెల్లని వీడియో ID';

  @override
  String get routeInvalidSoundId => 'చెల్లని ధ్వని ID';

  @override
  String get routeInvalidCategory => 'చెల్లని వర్గం';

  @override
  String get routeNoVideosToDisplay => 'ప్రదర్శించడానికి వీడియోలు లేవు';

  @override
  String get routeGoHome => 'ఇంటికి వెళ్లండి';

  @override
  String get routeInvalidProfileId => 'చెల్లని ప్రొఫైల్ ID';

  @override
  String get routeUnknownPath => 'ఆ పేజీ యాప్‌లో లేదు.';

  @override
  String get routeDefaultListName => 'జాబితా';

  @override
  String get supportTitle => 'మద్దతు కేంద్రం';

  @override
  String get supportContactSupport => 'మద్దతును సంప్రదించండి';

  @override
  String get supportContactSupportSubtitle =>
      'సంభాషణను ప్రారంభించండి లేదా గత సందేశాలను వీక్షించండి';

  @override
  String get supportReportBug => 'బగ్‌ను నివేదించండి';

  @override
  String get supportReportBugSubtitle => 'యాప్‌తో సాంకేతిక సమస్యలు';

  @override
  String get supportRequestFeature => 'లక్షణాన్ని అభ్యర్థించండి';

  @override
  String get supportRequestFeatureSubtitle =>
      'మెరుగుదల లేదా కొత్త ఫీచర్‌ను సూచించండి';

  @override
  String get supportSaveLogs => 'లాగ్‌లను సేవ్ చేయండి';

  @override
  String get supportSaveLogsSubtitle =>
      'మాన్యువల్ పంపడం కోసం ఫైల్‌కి లాగ్‌లను ఎగుమతి చేయండి';

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
  String get supportFaq => 'తరచుగా అడిగే ప్రశ్నలు';

  @override
  String get supportFaqSubtitle => 'సాధారణ ప్రశ్నలు & సమాధానాలు';

  @override
  String get supportFamily => 'Divine కుటుంబం';

  @override
  String get supportFamilySubtitle =>
      'తల్లిదండ్రులు మరియు యుక్తవయస్కులు ఆన్‌లైన్‌లో ఆరోగ్యకరమైన అలవాట్లను ఏర్పరచుకోవడంలో సహాయపడటం';

  @override
  String get supportKids => 'Divine పిల్లలు';

  @override
  String get supportKidsSubtitle =>
      'మేము వయస్సు ఆధారంగా ఖాతాలను ఎలా నిర్వహిస్తాము';

  @override
  String get supportProofMode => 'ProofMode';

  @override
  String get supportProofModeSubtitle =>
      'ధృవీకరణ మరియు ప్రామాణికత గురించి తెలుసుకోండి';

  @override
  String get supportLoginRequired => 'మద్దతును సంప్రదించడానికి లాగిన్ చేయండి';

  @override
  String get supportExportingLogs => 'లాగ్‌లను ఎగుమతి చేస్తోంది...';

  @override
  String get supportExportLogsFailed => 'లాగ్‌లను ఎగుమతి చేయడంలో విఫలమైంది';

  @override
  String get supportNoLogsToExport =>
      'ఇంకా లాగ్‌లు లేవు — అవి ప్రతి ప్రయోగాన్ని తాజాగా ప్రారంభిస్తాయి. సమస్యను పునరుత్పత్తి చేసి, ఆపై పునఃప్రారంభించకుండానే తిరిగి రండి.';

  @override
  String get supportExportLogsUnconfirmed =>
      'లాగ్‌లు అందజేయబడ్డాయి. మీరు భాగస్వామ్యం చేసిన యాప్‌ను తనిఖీ చేయండి.';

  @override
  String supportLogsSavedTo(String path) {
    return 'లాగ్‌లు దీనికి సేవ్ చేయబడ్డాయి $path';
  }

  @override
  String get supportRevealLogsAction => 'ఫోల్డర్‌లో చూపించు';

  @override
  String get supportChatNotAvailable => 'మద్దతు చాట్ అందుబాటులో లేదు';

  @override
  String get supportCouldNotOpenMessages =>
      'మద్దతు సందేశాలను తెరవడం సాధ్యపడలేదు';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return 'తెరవడం సాధ్యపడలేదు $pageName';
  }

  @override
  String get reportWhyReporting => 'మీరు ఈ కంటెంట్‌ను ఎందుకు నివేదిస్తున్నారు?';

  @override
  String get reportPolicyNotice =>
      'Divine కంటెంట్‌ని తీసివేసి, ఆక్షేపణీయ కంటెంట్‌ని అందించిన వినియోగదారుని ఎజెక్ట్ చేయడం ద్వారా 24 గంటలలోపు కంటెంట్ నివేదికలపై పని చేస్తుంది.';

  @override
  String get reportBlockUser => 'ఈ వినియోగదారుని బ్లాక్ చేయండి';

  @override
  String get reportCancel => 'రద్దు';

  @override
  String get reportSubmit => 'నివేదిక';

  @override
  String get reportSelectReason =>
      'దయచేసి ఈ కంటెంట్‌ని నివేదించడానికి కారణాన్ని ఎంచుకోండి';

  @override
  String get reportOtherRequiresDetails =>
      'దయచేసి ఇతర వాటిని ఎంచుకున్నప్పుడు సమస్యను వివరించండి';

  @override
  String get reportDetailsRequired => 'దయచేసి సమస్యను వివరించండి';

  @override
  String get reportDetailsTextOnly =>
      'వచనం మాత్రమే — ఫోటోలు మరియు GIFలు ఇక్కడ జోడించబడవు.';

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
  String get reportReasonSpam => 'స్పామ్ లేదా అవాంఛిత కంటెంట్';

  @override
  String get reportReasonSpamSubtitle => 'అవాంఛిత లేదా పునరావృత కంటెంట్';

  @override
  String get reportReasonHarassment =>
      'వేధింపులు, బెదిరింపులు లేదా బెదిరింపులు';

  @override
  String get reportReasonHarassmentSubtitle =>
      'హానికరమైన మరియు అవాంఛిత ప్రత్యుత్తరాలు లేదా ప్రస్తావనలు';

  @override
  String get reportReasonViolence => 'హింసాత్మక లేదా తీవ్రవాద కంటెంట్';

  @override
  String get reportReasonViolenceSubtitle =>
      'హింసాత్మక, తీవ్రవాద లేదా హానికరమైన కంటెంట్';

  @override
  String get reportReasonSexualContent => 'లైంగిక లేదా వయోజన కంటెంట్';

  @override
  String get reportReasonSexualContentSubtitle =>
      'నగ్నత్వం, అశ్లీలత లేదా స్పష్టమైన కంటెంట్';

  @override
  String get reportReasonCopyright => 'కాపీరైట్ ఉల్లంఘన';

  @override
  String get reportReasonCopyrightSubtitle =>
      'మేధో సంపత్తిని అనధికారికంగా ఉపయోగించడం';

  @override
  String get reportReasonFalseInfo => 'తప్పుడు సమాచారం';

  @override
  String get reportReasonFalseInfoSubtitle =>
      'తప్పుదారి పట్టించే లేదా తప్పుడు దావాలు';

  @override
  String get reportReasonChildSafety => 'పిల్లల భద్రత ఉల్లంఘన';

  @override
  String get reportReasonChildSafetySubtitle =>
      'మైనర్‌ల భద్రత గురించిన సాధారణ ఆందోళనలు';

  @override
  String get reportReasonCsam => 'పిల్లల లైంగిక దుర్వినియోగం';

  @override
  String get reportReasonCsamSubtitle =>
      'మైనర్‌లపై లైంగిక వేధింపులను వర్ణించే కంటెంట్';

  @override
  String get reportReasonUnderageUser => 'వినియోగదారు 16 ఏళ్లలోపు కనిపిస్తారు';

  @override
  String get reportReasonUnderageUserSubtitle =>
      'ఖాతాదారుడు వయస్సు తక్కువగా ఉన్నట్లు కనిపిస్తోంది';

  @override
  String get reportReasonAiGenerated => 'AI-సృష్టించిన కంటెంట్';

  @override
  String get reportReasonAiGeneratedSubtitle => 'అనుమానిత AI-ఉత్పత్తి కంటెంట్';

  @override
  String get reportReasonOther => 'ఇతర పాలసీ ఉల్లంఘన';

  @override
  String get reportReasonOtherSubtitle => 'ఉల్లంఘనలు పైన జాబితా చేయబడలేదు';

  @override
  String get reportFailed =>
      'కంటెంట్‌ని నివేదించడంలో విఫలమైంది. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get reportNotSent =>
      'మీ నివేదికను పంపడం సాధ్యపడలేదు. మీ కనెక్షన్‌ని తనిఖీ చేసి, మళ్లీ ప్రయత్నించండి.';

  @override
  String get reportReceivedTitle => 'నివేదిక స్వీకరించబడింది';

  @override
  String get reportReceivedThankYou =>
      'Divineని సురక్షితంగా ఉంచడంలో సహాయం చేసినందుకు ధన్యవాదాలు.';

  @override
  String get reportReceivedReviewNotice =>
      'మా బృందం మీ నివేదికను సమీక్షించి తగిన చర్య తీసుకుంటుంది. మీరు ప్రత్యక్ష సందేశం ద్వారా నవీకరణలను స్వీకరించవచ్చు.';

  @override
  String get reportModerationDmDelayed =>
      'మేము ఇప్పుడే మోడరేషన్ బృందాన్ని నేరుగా చేరుకోలేకపోయాము, కానీ మీ నివేదిక స్వీకరించబడింది మరియు సమీక్షించబడుతుంది.';

  @override
  String get reportContactModeration => 'మోడరేషన్ బృందానికి సందేశం పంపండి';

  @override
  String get reportLearnMoreAt => 'ఇక్కడ మరింత తెలుసుకోండి';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => 'మూసివేయండి';

  @override
  String get listAddToList => 'జాబితాకు జోడించండి';

  @override
  String listVideoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countవీడియోలు',
      one: '$countవీడియో',
    );
    return '$_temp0';
  }

  @override
  String listPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countవ్యక్తులు',
      one: '1 వ్యక్తి',
    );
    return '$_temp0';
  }

  @override
  String get listByAuthorPrefix => 'ద్వారా ';

  @override
  String get listNewList => 'కొత్త జాబితా';

  @override
  String get listDone => 'పూర్తయింది';

  @override
  String get listErrorLoading => 'జాబితాలను లోడ్ చేయడంలో లోపం';

  @override
  String listRemovedFrom(String name) {
    return 'నుండి తీసివేయబడింది $name';
  }

  @override
  String listAddedTo(String name) {
    return 'దీనికి జోడించబడింది $name';
  }

  @override
  String get listCreateNewList => 'కొత్త జాబితాను సృష్టించండి';

  @override
  String get listNewPeopleList => 'కొత్త వ్యక్తుల జాబితా';

  @override
  String get listCollaboratorsNone => 'ఏదీ లేదు';

  @override
  String get listAddCollaboratorTitle => 'సహకారిని జోడించండి';

  @override
  String get listCollaboratorSearchHint => 'శోధన Divine...';

  @override
  String get listNameLabel => 'జాబితా పేరు';

  @override
  String get listDescriptionLabel => 'వివరణ (ఐచ్ఛికం)';

  @override
  String get listPublicList => 'పబ్లిక్ జాబితా';

  @override
  String get listPublicListSubtitle =>
      'ఇతరులు ఈ జాబితాను అనుసరించవచ్చు మరియు చూడవచ్చు';

  @override
  String get listPrivateListSubtitle =>
      'వీడియోలు ప్రైవేట్‌గా ఉంటాయి. పేరు, వివరణ, ట్యాగ్‌లు మరియు కవర్ కనిపించేలా ఉంటాయి.';

  @override
  String get listVisibilityPublic => 'పబ్లిక్';

  @override
  String get listVisibilityPrivate => 'ప్రైవేట్';

  @override
  String get profileListsEmpty =>
      'ఇంకా జాబితాలు లేవు. మీరు కలిసి ఉంచాలనుకుంటున్న లూప్‌ల కోసం ఒకదాన్ని తయారు చేయండి.';

  @override
  String get listEditTitle => 'జాబితాను సవరించండి';

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
  String get listShareAction => 'షేర్ జాబితా';

  @override
  String get listShareFailed =>
      'ఈ జాబితాను భాగస్వామ్యం చేయడం సాధ్యపడలేదు. మళ్లీ ప్రయత్నించండి.';

  @override
  String get listSave => 'సేవ్ చేయండి';

  @override
  String get listContinue => 'కొనసాగించండి';

  @override
  String get listPrivateFull =>
      'This private list is full. Remove something to add more.';

  @override
  String get listUpdateFailed =>
      'ఈ జాబితాను నవీకరించడం సాధ్యపడలేదు. మళ్లీ ప్రయత్నించండి.';

  @override
  String get listMakePrivateTitle => 'ఈ జాబితాను ప్రైవేట్‌గా చేయాలా?';

  @override
  String get listMakePrivateWarning =>
      'దీని వీడియోలు గుప్తీకరించబడతాయి కాబట్టి మీరు మాత్రమే వాటిని చూడగలరు. పేరు, వివరణ, ట్యాగ్‌లు మరియు కవర్ కనిపిస్తాయి మరియు ఇంతకు ముందు భాగస్వామ్యం చేసిన కాపీలు అలాగే ఉండవచ్చు.';

  @override
  String get listMakePublicTitle => 'ఈ జాబితాను పబ్లిక్‌గా చేయాలా?';

  @override
  String get listMakePublicWarning =>
      'లింక్‌ని కలిగి ఉన్న ఎవరైనా ఈ జాబితాను మరియు దాని వీడియోలను చూడగలరు.';

  @override
  String listShareText(String name, String url) {
    return 'Divineలో $nameని చూడండి: $url';
  }

  @override
  String listShareSubject(String name) {
    return 'Divineలో $name';
  }

  @override
  String get listCancel => 'రద్దు';

  @override
  String get listCreate => 'సృష్టించు';

  @override
  String get listCreateFailed => 'జాబితాను రూపొందించడంలో విఫలమైంది';

  @override
  String get keyManagementTitle => 'Nostr కీలు';

  @override
  String get keyManagementWhatAreKeys => 'Nostr కీలు అంటే ఏమిటి?';

  @override
  String get keyManagementExplanation =>
      'మీ Nostr గుర్తింపు ఒక క్రిప్టోగ్రాఫిక్ కీ జత: రహస్యం!\n\nమీ nsec ఏదైనా Nostr యాప్‌లో మీ ఖాతాను యాక్సెస్ చేయడానికి మిమ్మల్ని అనుమతిస్తుంది.';

  @override
  String get keyManagementImportTitle => 'ఇప్పటికే ఉన్న కీని దిగుమతి చేయండి';

  @override
  String get keyManagementImportSubtitle =>
      'ఇప్పటికే Nostr ఖాతా ఉందా? దీన్ని ఇక్కడ యాక్సెస్ చేయడానికి మీ ప్రైవేట్ కీని (nsec) అతికించండి.';

  @override
  String get keyManagementImportButton => 'దిగుమతి కీ';

  @override
  String get keyManagementImportWarning =>
      'ఇది మీ ప్రస్తుత కీని భర్తీ చేస్తుంది!';

  @override
  String get keyManagementBackupTitle => 'మీ కీని బ్యాకప్ చేయండి';

  @override
  String get keyManagementBackupSubtitle =>
      'ఇతర Nostr యాప్‌లలో మీ ఖాతాను ఉపయోగించడానికి మీ ప్రైవేట్ కీ (nsec)ని సేవ్ చేయండి.';

  @override
  String get keyManagementCopyNsec => 'నా ప్రైవేట్ కీని కాపీ చేయండి (nsec)';

  @override
  String get keyManagementNeverShare =>
      'మీ nsecని ఎవరితోనూ భాగస్వామ్యం చేయవద్దు!';

  @override
  String get keyManagementKeycastRemoteSigning =>
      'మీ కీ ఈ పరికరంలో కాకుండా Divine లాగిన్ సేవలో ఉంటుంది. మీ పాస్‌వర్డ్‌ను నిర్ధారించండి మరియు మేము దానిని మీ కోసం తీసుకువస్తాము.';

  @override
  String get keyManagementKeycastPasswordPrompt =>
      'మీ కీ Divine యొక్క లాగిన్ సేవ ద్వారా ఉంచబడుతుంది. మీ ఖాతా పాస్‌వర్డ్‌ని నమోదు చేయండి మరియు మేము దానిని పొందుతాము.';

  @override
  String get keyManagementKeycastCopyKey => 'కాపీ కీ';

  @override
  String get keyManagementKeycastCopyBlocked =>
      'మీ పరికరం కాపీని బ్లాక్ చేసింది, కాబట్టి మీ కీ క్లిప్‌బోర్డ్‌కు చేరలేదు.';

  @override
  String get keyManagementKeycastWrongPassword =>
      'ఆ పాస్‌వర్డ్ సరిపోలలేదు. మళ్లీ ప్రయత్నించండి.';

  @override
  String get keyManagementKeycastTooManyAttempts =>
      'చాలా ప్రయత్నాలు చేసారు. దీన్ని మూసివేసి మళ్లీ ప్రారంభించండి.';

  @override
  String get keyManagementKeycastRateLimited =>
      'చాలా కీలక అభ్యర్థనలు. కొన్ని నిమిషాలు వేచి ఉండి, మళ్లీ ప్రయత్నించండి.';

  @override
  String get keyManagementKeycastSignInAgain =>
      'మీ సెషన్ గడువు ముగిసింది. మీ కీని కాపీ చేయడానికి మళ్లీ సైన్ ఇన్ చేయండి.';

  @override
  String get keyManagementKeycastEmailUnverified =>
      'మీ కీని కాపీ చేయడానికి ముందు మీ ఇమెయిల్ చిరునామాను ధృవీకరించండి.';

  @override
  String get keyManagementKeycastDenied =>
      'Divine ఈ ఖాతా కీలను చూసుకుంటుంది, కాబట్టి వాటిని ఇక్కడ కాపీ చేయడం సాధ్యం కాదు.';

  @override
  String get keyManagementKeycastNoKey =>
      'ఈ ఖాతా కోసం రికార్డ్‌లో కీ ఏదీ లేదు.';

  @override
  String get keyManagementKeycastGenericFailure =>
      'లాగిన్ సేవను చేరుకోలేకపోయింది. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get keyManagementRestrictedTitle =>
      'మీ కీలు Divine ద్వారా నిర్వహించబడుతున్నాయి';

  @override
  String get keyManagementRestrictedBody =>
      'మీ ఖాతాను సురక్షితంగా ఉంచడానికి, కీ బ్యాకప్ మరియు వేరే కీని దిగుమతి చేయడం ఇక్కడ అందుబాటులో లేదు.';

  @override
  String get keyManagementPasteKey => 'దయచేసి మీ ప్రైవేట్ కీని అతికించండి';

  @override
  String get keyManagementInvalidFormat =>
      'చెల్లని కీ ఫార్మాట్. తప్పనిసరిగా \"nsec1\"తో ప్రారంభం కావాలి';

  @override
  String get keyManagementConfirmImportTitle => 'ఈ కీని దిగుమతి చేయాలా?';

  @override
  String get keyManagementConfirmImportBody =>
      'ఇది మీ ప్రస్తుత గుర్తింపును దిగుమతి చేసుకున్న దానితో భర్తీ చేస్తుంది.';

  @override
  String get keyManagementImportConfirm => 'దిగుమతి';

  @override
  String get keyManagementImportSuccess => 'కీ విజయవంతంగా దిగుమతి చేయబడింది!';

  @override
  String get keyManagementImportFailed =>
      'కీని దిగుమతి చేయడంలో విఫలమైంది. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get keyManagementExportSuccess =>
      'ప్రైవేట్ కీ క్లిప్‌బోర్డ్‌కి కాపీ చేయబడింది!\n\nదాన్ని ఎక్కడైనా సురక్షితంగా నిల్వ చేయండి.';

  @override
  String get keyManagementExportFailed =>
      'కీని ఎగుమతి చేయడంలో విఫలమైంది. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get keyManagementYourPublicKeyLabel => 'మీ పబ్లిక్ కీ (npub)';

  @override
  String get keyManagementCopyPublicKeyTooltip => 'పబ్లిక్ కీని కాపీ చేయండి';

  @override
  String get keyManagementPublicKeyCopied => 'పబ్లిక్ కీ కాపీ చేయబడింది';

  @override
  String get saveOriginalSavedToCameraRoll => 'కెమెరా రోల్‌కి సేవ్ చేయబడింది';

  @override
  String get saveOriginalShare => 'భాగస్వామ్యం చేయండి';

  @override
  String get saveOriginalDone => 'పూర్తయింది';

  @override
  String get saveOriginalPhotosAccessNeeded => 'ఫోటోల యాక్సెస్ అవసరం';

  @override
  String get saveOriginalPhotosAccessMessage =>
      'వీడియోలను సేవ్ చేయడానికి, సెట్టింగ్‌లలో ఫోటోల యాక్సెస్‌ను అనుమతించండి.';

  @override
  String get saveOriginalOpenSettings => 'సెట్టింగ్‌లను తెరవండి';

  @override
  String get saveOriginalNotNow => 'ఇప్పుడు కాదు';

  @override
  String get saveOriginalDownloadFailed => 'డౌన్‌లోడ్ విఫలమైంది';

  @override
  String get saveOriginalDismiss => 'తీసివేయండి';

  @override
  String get saveOriginalDownloadingVideo => 'వీడియో డౌన్‌లోడ్ అవుతోంది';

  @override
  String get saveOriginalSavingToCameraRoll => 'కెమెరా రోల్‌కు సేవ్ చేస్తోంది';

  @override
  String get saveOriginalFetchingVideo =>
      'నెట్‌వర్క్ నుండి వీడియోని పొందుతోంది...';

  @override
  String get saveOriginalSavingVideo =>
      'ఒరిజినల్ వీడియోని మీ కెమెరా రోల్‌లో సేవ్ చేస్తోంది...';

  @override
  String get soundTitle => 'ధ్వని';

  @override
  String get soundOriginalSound => 'అసలు ధ్వని';

  @override
  String get soundVideosUsingThisSound => 'ఈ ధ్వనిని ఉపయోగించే వీడియోలు';

  @override
  String get soundSourceVideo => 'మూల వీడియో';

  @override
  String get soundNoVideosYet => 'ఇంకా వీడియోలు లేవు';

  @override
  String get soundBeFirstToUse => 'ఈ ధ్వనిని ఉపయోగించిన మొదటి వ్యక్తి అవ్వండి!';

  @override
  String get soundFailedToLoadVideos => 'వీడియోలను లోడ్ చేయడంలో విఫలమైంది';

  @override
  String get soundRetry => 'మళ్లీ ప్రయత్నించండి';

  @override
  String get soundVideosUnavailable => 'వీడియోలు అందుబాటులో లేవు';

  @override
  String get soundCouldNotLoadDetails =>
      'వీడియో వివరాలను లోడ్ చేయడం సాధ్యపడలేదు';

  @override
  String get soundPreview => 'ప్రివ్యూ';

  @override
  String get soundStop => 'ఆపు';

  @override
  String get soundUseSound => 'సౌండ్ ఉపయోగించండి';

  @override
  String get soundUntitled => 'శీర్షికలేని ధ్వని';

  @override
  String get soundStopPreview => 'ప్రివ్యూను ఆపు';

  @override
  String soundPreviewSemanticLabel(String title) {
    return 'ప్రివ్యూ $title';
  }

  @override
  String soundViewDetailsSemanticLabel(String title) {
    return 'దీని కోసం వివరాలను వీక్షించండి $title';
  }

  @override
  String get soundNoVideoCount => 'ఇంకా వీడియోలు లేవు';

  @override
  String get soundOneVideo => '1 వీడియో';

  @override
  String soundVideoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countవీడియోలు',
      one: '$countవీడియో',
    );
    return '$_temp0';
  }

  @override
  String get soundUnableToPreview =>
      'ధ్వనిని ప్రివ్యూ చేయడం సాధ్యపడలేదు - ఆడియో అందుబాటులో లేదు';

  @override
  String get soundPreviewFailed =>
      'ప్రివ్యూని ప్లే చేయడంలో విఫలమైంది. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get soundViewSource => 'మూలాన్ని వీక్షించండి';

  @override
  String get soundCloseTooltip => 'మూసివేయండి';

  @override
  String get exploreNotExploreRoute => 'అన్వేషణ మార్గం కాదు';

  @override
  String get legalTitle => 'చట్టపరమైన';

  @override
  String get legalTermsOfService => 'సేవా నిబంధనలు';

  @override
  String get legalTermsOfServiceSubtitle => 'వినియోగ నిబంధనలు మరియు షరతులు';

  @override
  String get legalPrivacyPolicy => 'గోప్యతా విధానం';

  @override
  String get legalPrivacyPolicySubtitle => 'మేము మీ డేటాను ఎలా నిర్వహిస్తాము';

  @override
  String get legalSafetyStandards => 'భద్రతా ప్రమాణాలు';

  @override
  String get legalSafetyStandardsSubtitle => 'సంఘం మార్గదర్శకాలు మరియు భద్రత';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle => 'కాపీరైట్ మరియు తొలగింపు విధానం';

  @override
  String get legalOpenSourceLicenses => 'ఓపెన్ సోర్స్ లైసెన్స్‌లు';

  @override
  String get legalOpenSourceLicensesSubtitle =>
      'థర్డ్-పార్టీ ప్యాకేజీ అట్రిబ్యూషన్‌లు';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return 'తెరవడం సాధ్యపడలేదు $pageName';
  }

  @override
  String get categoryAction => 'చర్య';

  @override
  String get categoryAdventure => 'సాహసం';

  @override
  String get categoryAnimals => 'జంతువులు';

  @override
  String get categoryAnimation => 'యానిమేషన్';

  @override
  String get categoryArchitecture => 'ఆర్కిటెక్చర్';

  @override
  String get categoryArt => 'కళ';

  @override
  String get categoryAutomotive => 'ఆటోమోటివ్';

  @override
  String get categoryAwardShow => 'అవార్డ్ షో';

  @override
  String get categoryAwards => 'అవార్డులు';

  @override
  String get categoryBaseball => 'బేస్‌బాల్';

  @override
  String get categoryBasketball => 'బాస్కెట్‌బాల్';

  @override
  String get categoryBeauty => 'అందం';

  @override
  String get categoryBeverage => 'పానీయం';

  @override
  String get categoryCars => 'కార్లు';

  @override
  String get categoryCelebration => 'వేడుక';

  @override
  String get categoryCelebrities => 'ప్రముఖులు';

  @override
  String get categoryCelebrity => 'సెలబ్రిటీ';

  @override
  String get categoryCityscape => 'సిటీస్కేప్';

  @override
  String get categoryComedy => 'కామెడీ';

  @override
  String get categoryConcert => 'కచేరీ';

  @override
  String get categoryCooking => 'వంట';

  @override
  String get categoryCostume => 'కాస్ట్యూమ్';

  @override
  String get categoryCrafts => 'క్రాఫ్ట్స్';

  @override
  String get categoryCrime => 'నేరం';

  @override
  String get categoryCulture => 'సంస్కృతి';

  @override
  String get categoryDance => 'డాన్స్';

  @override
  String get categoryDiy => 'DIY';

  @override
  String get categoryDrama => 'డ్రామా';

  @override
  String get categoryEducation => 'విద్య';

  @override
  String get categoryEmotional => 'భావోద్వేగ';

  @override
  String get categoryEmotions => 'భావోద్వేగాలు';

  @override
  String get categoryEntertainment => 'వినోదం';

  @override
  String get categoryEvent => 'ఈవెంట్';

  @override
  String get categoryFamily => 'కుటుంబం';

  @override
  String get categoryFans => 'అభిమానులు';

  @override
  String get categoryFantasy => 'ఫాంటసీ';

  @override
  String get categoryFashion => 'శైలి';

  @override
  String get categoryFestival => 'పండుగ';

  @override
  String get categoryFilm => 'ఫిల్మ్';

  @override
  String get categoryFitness => 'ఫిట్‌నెస్';

  @override
  String get categoryFood => 'ఆహారం';

  @override
  String get categoryFootball => 'ఫుట్‌బాల్';

  @override
  String get categoryFurniture => 'ఫర్నిచర్';

  @override
  String get categoryGaming => 'గేమింగ్';

  @override
  String get categoryGolf => 'గోల్ఫ్';

  @override
  String get categoryGrooming => 'గ్రూమింగ్';

  @override
  String get categoryGuitar => 'గిటార్';

  @override
  String get categoryHalloween => 'హాలోవీన్';

  @override
  String get categoryHealth => 'ఆరోగ్యం';

  @override
  String get categoryHockey => 'హాకీ';

  @override
  String get categoryHoliday => 'సెలవు';

  @override
  String get categoryHome => 'హోమ్';

  @override
  String get categoryHomeImprovement => 'గృహ మెరుగుదల';

  @override
  String get categoryHorror => 'హర్రర్';

  @override
  String get categoryHospital => 'హాస్పిటల్';

  @override
  String get categoryHumor => 'హాస్యం';

  @override
  String get categoryInteriorDesign => 'ఇంటీరియర్ డిజైన్';

  @override
  String get categoryInterview => 'ఇంటర్వ్యూ';

  @override
  String get categoryKids => 'పిల్లలు';

  @override
  String get categoryLifestyle => 'జీవనశైలి';

  @override
  String get categoryMagic => 'మ్యాజిక్';

  @override
  String get categoryMakeup => 'మేకప్';

  @override
  String get categoryMedical => 'మెడికల్';

  @override
  String get categoryMusic => 'సంగీతం';

  @override
  String get categoryMystery => 'మిస్టరీ';

  @override
  String get categoryNature => 'ప్రకృతి';

  @override
  String get categoryNews => 'వార్తలు';

  @override
  String get categoryOutdoor => 'అవుట్‌డోర్';

  @override
  String get categoryParty => 'పార్టీ';

  @override
  String get categoryPeople => 'వ్యక్తులు';

  @override
  String get categoryPerformance => 'పనితీరు';

  @override
  String get categoryPets => 'పెంపుడు జంతువులు';

  @override
  String get categoryPolitics => 'రాజకీయాలు';

  @override
  String get categoryPrank => 'చిలిపి';

  @override
  String get categoryPranks => 'చిలిపి పనులు';

  @override
  String get categoryRealityShow => 'రియాలిటీ షో';

  @override
  String get categoryRelationship => 'సంబంధం';

  @override
  String get categoryRelationships => 'సంబంధాలు';

  @override
  String get categoryRomance => 'శృంగారం';

  @override
  String get categorySchool => 'స్కూల్';

  @override
  String get categoryScienceFiction => 'సైన్స్ ఫిక్షన్';

  @override
  String get categorySelfie => 'సెల్ఫీ';

  @override
  String get categoryShopping => 'షాపింగ్';

  @override
  String get categorySkateboarding => 'స్కేట్‌బోర్డింగ్';

  @override
  String get categorySkincare => 'చర్మ సంరక్షణ';

  @override
  String get categorySoccer => 'సాకర్';

  @override
  String get categorySocialGathering => 'సామాజిక సేకరణ';

  @override
  String get categorySocialMedia => 'సోషల్ మీడియా';

  @override
  String get categorySports => 'క్రీడలు';

  @override
  String get categoryTalkShow => 'టాక్ షో';

  @override
  String get categoryTech => 'టెక్';

  @override
  String get categoryTechnology => 'టెక్నాలజీ';

  @override
  String get categoryTelevision => 'టెలివిజన్';

  @override
  String get categoryToys => 'బొమ్మలు';

  @override
  String get categoryTransportation => 'రవాణా';

  @override
  String get categoryTravel => 'ప్రయాణం';

  @override
  String get categoryUrban => 'అర్బన్';

  @override
  String get categoryViolence => 'హింస';

  @override
  String get categoryVlog => 'వ్లాగ్';

  @override
  String get categoryVlogging => 'వ్లాగింగ్';

  @override
  String get categoryWrestling => 'రెజ్లింగ్';

  @override
  String get profileSetupUploadStaged =>
      'అప్‌లోడ్ చేయబడింది — దరఖాస్తు చేయడానికి సేవ్ చేయి నొక్కండి';

  @override
  String inboxReportedUser(String displayName) {
    return 'నివేదించబడింది $displayName';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return 'నిరోధించబడింది $displayName';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return 'అన్‌బ్లాక్ చేయబడింది $displayName';
  }

  @override
  String get inboxRemovedConversation => 'సంభాషణ తీసివేయబడింది';

  @override
  String get inboxRestorePausedTitle =>
      'కొన్ని చాట్‌ల పునరుద్ధరణ పూర్తి కాలేదు';

  @override
  String get conversationRestorePausedTitle =>
      'ఈ చాట్ పునరుద్ధరణ పూర్తి కాలేదు';

  @override
  String get inboxRestoreRetryAction => 'మళ్లీ ప్రయత్నించండి';

  @override
  String get inboxRestoringMessages => 'మీ సందేశాలను పునరుద్ధరిస్తోంది…';

  @override
  String get inboxEmptyTitle => 'ఇంకా సందేశాలు లేవు';

  @override
  String get inboxEmptySubtitle => 'ఆ + బటన్ కాటు వేయదు.';

  @override
  String get inboxLoadErrorTitle => 'సందేశాలు లోడ్ కాలేదు';

  @override
  String get inboxLoadErrorSubtitle =>
      'మీ కనెక్షన్‌ని తనిఖీ చేసి, మరొకసారి ప్రయత్నించండి.';

  @override
  String get inboxFilterAll => 'అన్నీ';

  @override
  String get inboxFilterUnread => 'చదవలేదు';

  @override
  String get dmBlockedThreadTitle => 'మీరు ఈ ఖాతాను బ్లాక్ చేసారు';

  @override
  String get dmBlockedThreadBody =>
      'సందేశాలు ఇక్కడ ఉంటాయి కాబట్టి మీరు వాటిని చదవవచ్చు లేదా స్క్రీన్‌షాట్ చేయవచ్చు. ప్రత్యుత్తరం ఇవ్వడానికి అన్‌బ్లాక్ చేయండి.';

  @override
  String get inboxFilterBlocked => 'నిరోధించబడింది';

  @override
  String get inboxBlockedEmptyTitle => 'బ్లాక్ చేయబడిన చాట్‌లు లేవు';

  @override
  String get inboxBlockedEmptySubtitle =>
      'మీరు బ్లాక్ చేసిన ఖాతాలు ఇక్కడ చూపబడతాయి.';

  @override
  String get inboxBlockedNoMessages => 'సందేశాలు లేవు';

  @override
  String get inboxUnreadEmptyTitle => 'మీరంతా పట్టుకున్నారు';

  @override
  String get inboxUnreadEmptySubtitle => 'ప్రస్తుతం చదవని సందేశాలు లేవు.';

  @override
  String get inboxSearchHint => 'సందేశాలను శోధించండి';

  @override
  String get inboxSupportRowTitle => 'Divine మోడరేషన్';

  @override
  String get inboxSupportRowSubtitle =>
      'బగ్‌లు, నియంత్రణ, ఖాతా అంశాలు — మేము వింటున్నాము.';

  @override
  String get inboxSearchEmptyTitle => 'సరిపోలికలు లేవు';

  @override
  String get inboxSearchEmptySubtitle =>
      'వేరే పేరు లేదా పదాన్ని ప్రయత్నించండి.';

  @override
  String get inboxActionMute => 'సంభాషణను మ్యూట్ చేయండి';

  @override
  String inboxActionReport(String displayName) {
    return 'నివేదిక $displayName';
  }

  @override
  String inboxActionBlock(String displayName) {
    return 'బ్లాక్ $displayName';
  }

  @override
  String inboxActionUnblock(String displayName) {
    return 'అన్‌బ్లాక్ చేయండి $displayName';
  }

  @override
  String get inboxActionRemove => 'సంభాషణను తీసివేయండి';

  @override
  String get inboxRemoveConfirmTitle => 'సంభాషణను తీసివేయాలా?';

  @override
  String inboxRemoveConfirmBody(String displayName) {
    return 'ఇది వారితో మీ సంభాషణను తీసివేస్తుంది$displayName. వారు మీకు మళ్లీ మెసేజ్ చేస్తే, కొత్త సంభాషణ ప్రారంభమవుతుంది.';
  }

  @override
  String get inboxRemoveConfirmBodyGroup =>
      'ఇది మీ ఇన్‌బాక్స్ నుండి సమూహ సంభాషణను తీసివేస్తుంది. ఎవరైనా గ్రూప్‌కి మళ్లీ మెసేజ్ చేస్తే, కొత్త సంభాషణ ప్రారంభమవుతుంది.';

  @override
  String get inboxRemoveConfirmConfirm => 'తీసివేయి';

  @override
  String get inboxConversationMuted => 'సంభాషణ మ్యూట్ చేయబడింది';

  @override
  String get inboxConversationUnmuted => 'సంభాషణ అన్‌మ్యూట్ చేయబడింది';

  @override
  String get inboxCollabInviteCardTitle => 'సహకారి ఆహ్వానం';

  @override
  String get inboxCollabInviteCardUntitledVideo => 'శీర్షికలేని వీడియో';

  @override
  String get clickableTextViewVideoLink => 'వీడియోని వీక్షించండి';

  @override
  String get messageExternalLinkDialogTitle => 'బాహ్య లింక్‌ను తెరవాలా?';

  @override
  String messageExternalLinkDialogBody(String url) {
    return 'ఈ లింక్ బాహ్య సైట్‌కి వెళుతుంది మరియు సురక్షితంగా ఉండకపోవచ్చు:\n\n$url';
  }

  @override
  String get messageExternalLinkDialogOpen => 'తెరవండి';

  @override
  String get inboxCollabInviteCoPostButton => 'కో-పోస్ట్';

  @override
  String get inboxCollabInviteNotMineButton => 'నాది కాదు';

  @override
  String get inboxCollabInvitePreviewTitle => 'కో-పోస్ట్ ఆహ్వానం';

  @override
  String inboxCollabInvitePreviewTitleFrom(String displayName) {
    return 'సహ-పోస్ట్ నుండి ఆహ్వానం $displayName';
  }

  @override
  String get inboxCollabInviteTimelineConsequence =>
      'సహ-పోస్టింగ్ ఈ వీడియోను మీ టైమ్‌లైన్‌కి సహకారంగా జోడిస్తుంది.';

  @override
  String get inboxCollabInviteAcceptedStatus => 'ఆమోదించబడింది';

  @override
  String get inboxCollabInviteIgnoredStatus => 'విస్మరించబడింది';

  @override
  String get inboxCollabInviteAcceptError =>
      'అంగీకరించడం సాధ్యపడలేదు. మళ్లీ ప్రయత్నించండి.';

  @override
  String get inboxCollabInviteSentStatus => 'ఆహ్వానం పంపబడింది';

  @override
  String get inboxConversationCollabInvitePreview => 'సహకారి ఆహ్వానం';

  @override
  String collaboratorInviteDmBody(String title, String url) {
    return 'మీరు సహకరించడానికి ఆహ్వానించబడ్డారు $title: $url\n\nని సమీక్షించడానికి మరియు ఆమోదించడానికి Divineని తెరవండి.';
  }

  @override
  String collaboratorInviteDmBodyUntitled(String url) {
    return 'మీరు వీడియోలో సహకరించడానికి ఆహ్వానించబడ్డారు: $url\n\nని సమీక్షించడానికి మరియు ఆమోదించడానికి Divineని తెరవండి.';
  }

  @override
  String videoPublishCollaboratorInviteWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countసహకారి ఆహ్వానాలు పంపలేదు.',
      one: '1 సహకారి ఆహ్వానం పంపలేదు.',
    );
    return 'వీడియో పోస్ట్ చేయబడింది, కానీ $_temp0';
  }

  @override
  String get dmSendNoRecipientMessage =>
      'ఈ థ్రెడ్ ఎవరితో ఉందో మేము చెప్పలేకపోయాము. మీ ఇన్‌బాక్స్ నుండి దాన్ని మళ్లీ తెరవండి.';

  @override
  String get dmSendBlockedMessage =>
      'మీరు అధికారిక Divine ఖాతాలకు మాత్రమే సందేశం పంపగలరు';

  @override
  String get dmSendBlockedRetiredMessage =>
      'ఈ సంభాషణను ఎవరూ చదవడం లేదు. బదులుగా Divine మోడరేషన్ అని సందేశం పంపండి.';

  @override
  String get dmDeletePendingLabel => 'Deleting for everyone';

  @override
  String get dmDeleteRefusedMessage => 'అందరి కోసం తొలగించడం సాధ్యపడలేదు.';

  @override
  String get dmDeleteRefusedDetails =>
      'కొంతమంది ఇప్పటికీ ఈ సందేశాన్ని చూడగలిగే అవకాశం ఉంది.';

  @override
  String get dmRetiredThreadClosedTitle => 'ఈ సంభాషణ మూసివేయబడింది.';

  @override
  String get messageRequestModerationNoticeCannotBeRemoved =>
      'ఈ Divine మోడరేషన్ నోటీసు తీసివేయబడదు.';

  @override
  String get dmRetiredThreadClosedBody =>
      'మేము Divine మోడరేషన్‌ని కొత్త ఖాతాకు తరలించాము. దీన్ని ఇకపై ఎవరూ చదవరు.';

  @override
  String get dmRetiredThreadOpenSupport => 'సందేశం Divine మోడరేషన్';

  @override
  String get dmSendTooLongMessage =>
      'That message is too long to send. Shorten it and try again.';

  @override
  String get dmSendFailedMessage => 'సందేశాన్ని పంపడం సాధ్యపడలేదు';

  @override
  String get dmResendFailedMessage => 'ఇంకా పంపలేకపోయాం';

  @override
  String get dmSendFailedSubtitle =>
      'దీన్ని ఇప్పుడే మళ్లీ పంపండి లేదా ప్రయత్నాన్ని ఆపివేయండి.';

  @override
  String get dmSendFailedRetry => 'మళ్లీ ప్రయత్నించండి';

  @override
  String get dmSendPartialMessage =>
      'పంపబడింది, కానీ మీ ఇతర పరికరాలకు సమకాలీకరించబడలేదు';

  @override
  String get dmConversationLoadError => 'సందేశాలను లోడ్ చేయడం సాధ్యపడలేదు';

  @override
  String get dmMessageInputHint => 'ఏదైనా చెప్పండి...';

  @override
  String get dmMessageBubbleSentHint => 'సందేశం పంపబడింది';

  @override
  String get dmMessageBubbleReceivedHint => 'సందేశం స్వీకరించబడింది';

  @override
  String get dmMessageBubbleLongPressHint => 'సందేశ చర్యలు';

  @override
  String get dmMessageBubbleFailedTapHint =>
      'ఈ సందేశాన్ని మళ్లీ పంపండి లేదా తొలగించండి';

  @override
  String get dmMessageActionCopyText => 'వచనాన్ని కాపీ చేయండి';

  @override
  String get dmMessageActionCopyVideoUrl => 'వీడియో URLని కాపీ చేయండి';

  @override
  String get dmMessageActionDeleteForEveryone => 'అందరి కోసం తొలగించండి';

  @override
  String get dmMessageActionReport => 'నివేదిక';

  @override
  String get dmMessageActionRetrySend => 'మళ్లీ పంపండి';

  @override
  String get dmMessageActionCancelSend => 'ప్రయత్నించడం ఆపు';

  @override
  String get dmReactionAddCustomA11yLabel =>
      'అనుకూల ఎమోజి ప్రతిచర్యను జోడించండి';

  @override
  String dmReelReplyComposerHint(String name) {
    return 'సందేశం $name…';
  }

  @override
  String get dmReelReplyComposerHintSelf => 'మీకు మీరే ప్రత్యుత్తరం ఇవ్వండి...';

  @override
  String get dmReelReplyComposerSemanticLabel =>
      'ఈ రీల్‌కి ప్రత్యుత్తరం ఇవ్వండి';

  @override
  String get dmReelReplyViewChat => 'చాట్‌ని వీక్షించండి';

  @override
  String get dmReelReplySentAnnouncement => 'ప్రత్యుత్తరం పంపబడింది';

  @override
  String dmReelReactionSentAnnouncement(String emoji) {
    return 'ప్రతిస్పందించారు $emoji';
  }

  @override
  String get dmReelReplyFailed => 'పంపడం సాధ్యపడలేదు';

  @override
  String get dmReelReplyUnverified => 'పంపినట్లు నిర్ధారించడం సాధ్యపడలేదు';

  @override
  String dmReactionChipOwnA11yLabel(String emoji) {
    return 'మీ స్పందన: $emoji';
  }

  @override
  String dmReactionChipOtherA11yLabel(String name, String emoji) {
    return '$nameదీనితో ప్రతిస్పందించారు $emoji';
  }

  @override
  String dmReactionChipPendingA11yLabel(String emoji) {
    return 'ప్రతిస్పందనను పంపుతోంది: $emoji';
  }

  @override
  String get dmReactionChipFailedA11yLabel =>
      'ప్రతిచర్య విఫలమైంది, మళ్లీ ప్రయత్నించడానికి రెండుసార్లు నొక్కండి';

  @override
  String get dmReactionChipRetryAnnouncement =>
      'ప్రతిచర్యను మళ్లీ ప్రయత్నిస్తోంది';

  @override
  String dmReactionRemovalRefusedA11yLabel(String emoji) {
    return 'Couldn\'t remove your $emoji reaction. Double tap to try again';
  }

  @override
  String get dmReactionRemovalRefusedTitle => 'Couldn\'t remove your reaction.';

  @override
  String get dmReactionAddBlockedByRemoval =>
      'మరొక ప్రతిస్పందనను జోడించే ముందు మీ మునుపటి ప్రతిస్పందనను తొలగించడం పూర్తి చేయండి.';

  @override
  String get dmReactionRemovalRefusedDetails =>
      'Some people may still be able to see this reaction.';

  @override
  String get dmReactionsSheetTitle => 'ప్రతిచర్యలు';

  @override
  String get dmReactionsViewA11yLabel => 'ఎవరు స్పందించారో చూడండి';

  @override
  String get dmReactionRemoveAction => 'తీసివేయి';

  @override
  String get dmReactionRetryAction => 'మళ్లీ ప్రయత్నించండి';

  @override
  String get dmFormatBold => 'బోల్డ్';

  @override
  String get dmFormatItalic => 'ఇటాలిక్';

  @override
  String get dmFormatStrikethrough => 'స్ట్రైక్‌త్రూ';

  @override
  String get dmFormatCode => 'కోడ్';

  @override
  String get dmStatusFailed => 'పంపడంలో విఫలమైంది';

  @override
  String get inboxConversationActionsSheetLabel => 'సంభాషణ చర్యలు';

  @override
  String inboxConversationTileLabel(String displayName) {
    return '$displayNameసంభాషణ';
  }

  @override
  String inboxConversationTileLabelUnread(String displayName) {
    return 'చదవలేదు, $displayNameసంభాషణ';
  }

  @override
  String inboxGroupConversationTitle(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countఇతరులు',
      one: '$countఇతర',
    );
    return '$nameమరియు $_temp0';
  }

  @override
  String get inboxConversationTileLongPressHint => 'సంభాషణ చర్యలను చూపు';

  @override
  String exploreVideoId(String id) {
    return 'ID: $id';
  }

  @override
  String exploreVideoTitle(String title) {
    return 'శీర్షిక: $title';
  }

  @override
  String exploreVideoCounter(int current, int total) {
    return 'వీడియో $current/$total';
  }

  @override
  String get exploreSearchHint => 'శోధన...';

  @override
  String categoryVideoCount(int countValue, String count) {
    String _temp0 = intl.Intl.pluralLogic(
      countValue,
      locale: localeName,
      other: '$countవీడియోలు',
      one: '$countవీడియో',
    );
    return '$_temp0';
  }

  @override
  String get discoverListsFailedToUpdateSubscription =>
      'సభ్యత్వాన్ని నవీకరించడంలో విఫలమైంది. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get discoverListsTitle => 'జాబితాలను కనుగొనండి';

  @override
  String get discoverListsFailedToLoad => 'జాబితాలను లోడ్ చేయడంలో విఫలమైంది';

  @override
  String get discoverListsLoading => 'పబ్లిక్ జాబితాలను కనుగొంటోంది...';

  @override
  String get discoverListsRelayTimeout =>
      'రిలే సమయానికి జాబితాలను అందించలేదు. మళ్లీ ప్రయత్నించండి.';

  @override
  String get discoverListsServiceUnavailable => 'సేవ అందుబాటులో లేదు.';

  @override
  String get discoverListsEmptyTitle => 'పబ్లిక్ జాబితాలు ఏవీ కనుగొనబడలేదు';

  @override
  String get discoverListsEmptySubtitle =>
      'కొత్త జాబితాల కోసం తర్వాత మళ్లీ తనిఖీ చేయండి';

  @override
  String get discoverListsByAuthorPrefix => 'ద్వారా';

  @override
  String get curatedListEmptyTitle => 'ఈ జాబితాలో వీడియోలు లేవు';

  @override
  String get curatedListEmptySubtitle =>
      'ప్రారంభించడానికి కొన్ని వీడియోలను జోడించండి';

  @override
  String get curatedListLoadingVideos => 'వీడియోలు లోడ్ అవుతోంది...';

  @override
  String get curatedListFailedToLoad => 'జాబితాను లోడ్ చేయడంలో విఫలమైంది';

  @override
  String get curatedListVideoNotAvailable => 'వీడియో అందుబాటులో లేదు';

  @override
  String get curatedListActionsTooltip => 'జాబితా చర్యలు';

  @override
  String get curatedListDeleteConfirmTitle => 'జాబితాను తొలగించాలా?';

  @override
  String get curatedListDeleteConfirmBody =>
      'ఇది రిలేల నుండి జాబితాను తీసివేస్తుంది. జాబితాలోని వీడియోలు తొలగించబడవు.';

  @override
  String get curatedListDeletedSnack => 'తొలగించబడిన జాబితా';

  @override
  String get curatedListDeleteFailed => 'జాబితాను తొలగించడం సాధ్యపడలేదు';

  @override
  String get peopleListsActionsTooltip => 'జాబితా చర్యలు';

  @override
  String get listDeleteAction => 'జాబితాను తొలగించండి';

  @override
  String get peopleListsDeleteConfirmTitle => 'జాబితాను తొలగించాలా?';

  @override
  String get peopleListsDeleteConfirmBody =>
      'ఇది అందరి కోసం జాబితాను తీసివేస్తుంది. అందులోని వ్యక్తులు అన్ ఫాలో అవ్వరు.';

  @override
  String get peopleListsDeleteFailed => 'జాబితాను తొలగించడం సాధ్యపడలేదు';

  @override
  String get commonRetry => 'మళ్లీ ప్రయత్నించండి';

  @override
  String get commonSomethingWentWrong => 'ఏదో తప్పు జరిగింది';

  @override
  String get commonDelete => 'తొలగించు';

  @override
  String get commonCancel => 'రద్దు';

  @override
  String get commonBack => 'వెనుకకు';

  @override
  String get commonClose => 'మూసివేయండి';

  @override
  String get commonNotNow => 'ఇప్పుడు కాదు';

  @override
  String get commonLoading => 'లోడ్ అవుతోంది';

  @override
  String get videoMetadataEditCoverFailedSnackbar =>
      'కవర్‌ను అప్‌డేట్ చేయడం సాధ్యపడలేదు. మళ్లీ ప్రయత్నించండి.';

  @override
  String get videoMetadataEditCoverSuccessAnnouncement => 'కవర్ నవీకరించబడింది';

  @override
  String get videoMetadataC2paMissingTitle =>
      'మానవ నిర్మిత తనిఖీ లేకుండా పోస్ట్ చేయాలా?';

  @override
  String get videoMetadataC2paMissingBody =>
      'మేము కంటెంట్ ఆధారాలను జోడించలేకపోయాము, కాబట్టి ఈ వీడియో మానవ నిర్మితమైనదిగా నిర్ధారించబడదు. మళ్లీ ప్రయత్నించడానికి రీజెనరేట్ చేయండి లేదా దాన్ని అలాగే పోస్ట్ చేయండి.';

  @override
  String get videoMetadataC2paMissingNote =>
      'కంటెంట్ ఆధారాలకు ఇంటర్నెట్ కనెక్షన్ అవసరం.';

  @override
  String get videoMetadataC2paMissingNoteServiceUnavailable =>
      'కంటెంట్ క్రెడెన్షియల్ సర్వీస్ స్పందించలేదు. ఇది మీ కనెక్షన్ కాదు.';

  @override
  String get videoMetadataC2paMissingRegenerate => 'పునరుత్పత్తి';

  @override
  String get videoMetadataC2paMissingSkip => 'దాటవేయి';

  @override
  String get videoMetadataGenerationFailed => 'జనరేషన్ విఫలమైంది';

  @override
  String get videoMetadataTags => 'ట్యాగ్‌లు';

  @override
  String get videoMetadataExpiration => 'గడువు';

  @override
  String get videoMetadataExpirationNotExpire => 'గడువు ముగియదు';

  @override
  String get videoMetadataExpirationOneDay => '1 రోజు';

  @override
  String get videoMetadataExpirationOneWeek => '1 వారం';

  @override
  String get videoMetadataExpirationOneMonth => '1 నెల';

  @override
  String get videoMetadataExpirationOneYear => '1 సంవత్సరం';

  @override
  String get videoMetadataExpirationOneDecade => '1 దశాబ్దం';

  @override
  String get videoMetadataContentWarnings => 'కంటెంట్ హెచ్చరికలు';

  @override
  String get videoEditorStickers => 'స్టిక్కర్లు';

  @override
  String get trendingTitle => 'ట్రెండింగ్';

  @override
  String get libraryDeleteConfirm => 'తొలగించు';

  @override
  String get libraryWebUnavailableHeadline =>
      'లైబ్రరీ మొబైల్ యాప్‌లో అందుబాటులో ఉంది';

  @override
  String get libraryWebUnavailableDescription =>
      'చిత్తుప్రతులు మరియు క్లిప్‌లు మీ పరికరంలో సేవ్ చేయబడ్డాయి, కాబట్టి వాటిని నిర్వహించడానికి మీ ఫోన్‌లో Divineని తెరవండి.';

  @override
  String get libraryTabDrafts => 'చిత్తుప్రతులు';

  @override
  String get libraryTabClips => 'క్లిప్‌లు';

  @override
  String get libraryDeleteSelectedClipsTooltip =>
      'ఎంచుకున్న క్లిప్‌లను తొలగించండి';

  @override
  String get libraryCloseSemanticLabel => 'లైబ్రరీని మూసివేయండి';

  @override
  String get libraryStopSelectingClipsSemanticLabel =>
      'క్లిప్‌లను ఎంచుకోవడం ఆపివేయండి';

  @override
  String get librarySelectClipsSemanticLabel => 'క్లిప్‌లను ఎంచుకోండి';

  @override
  String get libraryGridSizeLabel => 'గ్రిడ్ పరిమాణం';

  @override
  String get libraryDisplayOptionsLabel => 'క్రమబద్ధీకరించు & గ్రిడ్ పరిమాణం';

  @override
  String get libraryMoreActionsSemanticLabel => 'మరిన్ని లైబ్రరీ చర్యలు';

  @override
  String libraryGridSizeColumns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countనిలువు వరుసలు',
      one: '1 నిలువు వరుస',
    );
    return '$_temp0';
  }

  @override
  String get librarySelect => 'ఎంచుకోండి';

  @override
  String get librarySortNewestCreation => 'సరికొత్త సృష్టి';

  @override
  String get librarySortOldestCreation => 'పురాతన సృష్టి';

  @override
  String get librarySortLongestClip => 'పొడవైన క్లిప్';

  @override
  String get librarySortShortestClip => 'చిన్నదైన క్లిప్';

  @override
  String get librarySortSquareFirst => 'స్క్వేర్ మొదట';

  @override
  String get librarySortVerticalFirst => 'వర్టికల్ ఫస్ట్';

  @override
  String get libraryDeleteClipsWarning =>
      'ఈ చర్య రద్దు చేయబడదు. వీడియో ఫైల్‌లు మీ పరికరం నుండి శాశ్వతంగా తీసివేయబడతాయి.';

  @override
  String get libraryPreparingVideo => 'వీడియోని సిద్ధం చేస్తోంది...';

  @override
  String libraryCreateVideo(int count) {
    return 'వీడియోని సృష్టించండి ($count)';
  }

  @override
  String libraryClipsSavedToDestination(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countక్లిప్‌లు',
      one: '1 క్లిప్',
    );
    return '$_temp0కి సేవ్ చేయబడింది $destination';
  }

  @override
  String libraryClipsSavePartialResult(int successCount, int failureCount) {
    return '$successCountసేవ్ చేయబడింది, $failureCountవిఫలమైంది';
  }

  @override
  String libraryClipsSaveFailed(String destination) {
    return 'కి సేవ్ చేయడం సాధ్యపడలేదు $destination';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return '$destinationఅనుమతి నిరాకరించబడింది';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countక్లిప్‌లు తొలగించబడ్డాయి',
      one: '1 క్లిప్ తొలగించబడింది',
    );
    return '$_temp0';
  }

  @override
  String get libraryClipsDeletedUndoLabel => 'అన్డు';

  @override
  String libraryTrashAutoDeletes(int daysLeft) {
    String _temp0 = intl.Intl.pluralLogic(
      daysLeft,
      locale: localeName,
      other: 'స్వీయ-తొలగింపులు $daysLeftరోజులు',
      one: 'రేపు స్వయంచాలకంగా తొలగించబడుతుంది',
      zero: 'ఈరోజు స్వయంచాలకంగా తొలగించబడుతుంది',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts => 'డ్రాఫ్ట్‌లను లోడ్ చేయడం సాధ్యపడలేదు';

  @override
  String get libraryCouldNotLoadClips => 'క్లిప్‌లను లోడ్ చేయడం సాధ్యపడలేదు';

  @override
  String get libraryOpenErrorDescription =>
      'మీ లైబ్రరీని తెరిచేటప్పుడు ఏదో తప్పు జరిగింది. మీరు మళ్లీ ప్రయత్నించవచ్చు.';

  @override
  String get libraryNoDraftsYetTitle => 'ఇంకా చిత్తుప్రతులు లేవు';

  @override
  String get libraryNoDraftsYetSubtitle =>
      'మీరు డ్రాఫ్ట్‌గా సేవ్ చేసిన వీడియోలు ఇక్కడ కనిపిస్తాయి';

  @override
  String get libraryNoClipsYetTitle => 'ఇంకా క్లిప్‌లు లేవు';

  @override
  String get libraryNoClipsYetSubtitle =>
      'మీ రికార్డ్ చేసిన వీడియో క్లిప్‌లు ఇక్కడ కనిపిస్తాయి';

  @override
  String get libraryDraftDeletedSnackbar => 'డ్రాఫ్ట్ తొలగించబడింది';

  @override
  String get libraryDraftDeleteFailedSnackbar =>
      'చిత్తుప్రతిని తొలగించడంలో విఫలమైంది';

  @override
  String get libraryDraftDuplicatedSnackbar => 'డ్రాఫ్ట్ నకిలీ చేయబడింది';

  @override
  String get libraryDraftDuplicateFailedSnackbar =>
      'డ్రాఫ్ట్‌ను నకిలీ చేయడంలో విఫలమైంది';

  @override
  String get libraryDraftInProgressBadge => 'ప్రోగ్రెస్‌లో ఉంది';

  @override
  String get libraryDraftActionPost => 'పోస్ట్';

  @override
  String get libraryDraftActionEdit => 'సవరించండి';

  @override
  String get libraryDraftActionDuplicate => 'నకిలీ';

  @override
  String get libraryDraftActionDelete => 'డ్రాఫ్ట్‌ను తొలగించండి';

  @override
  String libraryDraftCopyTitle(String title, int number) {
    return '$title(కాపీ $number)';
  }

  @override
  String get libraryDeleteDraftTitle => 'డ్రాఫ్ట్‌ను తొలగించండి';

  @override
  String libraryDeleteDraftMessage(String title) {
    return 'మీరు ఖచ్చితంగా తొలగించాలనుకుంటున్నారా \"$title\"?';
  }

  @override
  String get libraryDeleteClipTitle => 'క్లిప్‌ను తొలగించండి';

  @override
  String get libraryDeleteClipMessage =>
      'మీరు ఖచ్చితంగా ఈ క్లిప్‌ని తొలగించాలనుకుంటున్నారా?';

  @override
  String libraryClipDuration(String seconds) {
    return '$secondsసె';
  }

  @override
  String get libraryRecordVideo => 'వీడియోను రికార్డ్ చేయండి';

  @override
  String videoClipSemanticLabel(String duration) {
    return 'వీడియో క్లిప్, $durationసెకన్లు';
  }

  @override
  String videoClipArchivedSemanticLabel(String label) {
    return 'ఆర్కైవ్ చేయబడింది. $label';
  }

  @override
  String videoClipStopMotionSemanticLabel(String frames) {
    return 'స్టాప్-మోషన్ క్లిప్, $frames';
  }

  @override
  String videoClipSemanticValueSelectedAtPosition(int position) {
    return 'ఎంచుకోబడింది, నంబర్ $position';
  }

  @override
  String get videoClipSemanticValueSelected => 'ఎంచుకోబడింది';

  @override
  String get videoClipSemanticValueNotSelected => 'ఎంచుకోబడలేదు';

  @override
  String get videoClipSemanticHintDisabled => 'నిలిపివేయబడింది';

  @override
  String get videoClipSemanticHintSelect =>
      'ఎంచుకోవడానికి నొక్కండి, ప్రివ్యూ చేయడానికి ఎక్కువసేపు నొక్కండి';

  @override
  String get videoClipSemanticHintDeselect =>
      'ఎంపికను తీసివేయడానికి నొక్కండి, ప్రివ్యూ చేయడానికి ఎక్కువసేపు నొక్కండి';

  @override
  String get routerInvalidCreator => 'చెల్లని సృష్టికర్త';

  @override
  String get routerInvalidHashtagRoute => 'హ్యాష్‌ట్యాగ్ మార్గం చెల్లదు';

  @override
  String get categoryGalleryCouldNotLoadVideos =>
      'వీడియోలను లోడ్ చేయడం సాధ్యపడలేదు';

  @override
  String get categoryGalleryNoVideosInCategory => 'ఈ వర్గంలో వీడియోలు లేవు';

  @override
  String get categoryGallerySortOptionsLabel => 'వర్గం క్రమబద్ధీకరణ ఎంపికలు';

  @override
  String get categoryGallerySortHot => 'హాట్';

  @override
  String get categoryGallerySortNew => 'కొత్తది';

  @override
  String get categoryGallerySortClassic => 'క్లాసిక్';

  @override
  String get categoryGallerySortForYou => 'మీ కోసం';

  @override
  String get categoriesCouldNotLoadCategories =>
      'వర్గాలను లోడ్ చేయడం సాధ్యపడలేదు';

  @override
  String get categoriesNoCategoriesAvailable => 'వర్గాలు ఏవీ అందుబాటులో లేవు';

  @override
  String get notificationsEmptyTitle => 'ఇంకా కార్యాచరణ లేదు';

  @override
  String get notificationsEmptySubtitle =>
      'వ్యక్తులు మీ కంటెంట్‌తో పరస్పర చర్య చేసినప్పుడు, మీరు దాన్ని ఇక్కడ చూస్తారు';

  @override
  String get appsPermissionsTitle => 'ఇంటిగ్రేషన్ అనుమతులు';

  @override
  String get appsPermissionsRevoke => 'రద్దు';

  @override
  String get appsPermissionsEmptyTitle =>
      'సేవ్ చేయబడిన ఇంటిగ్రేషన్ అనుమతులు లేవు';

  @override
  String get appsPermissionsEmptySubtitle =>
      'మీరు యాక్సెస్ ఆమోదాన్ని గుర్తుంచుకున్న తర్వాత ఆమోదించబడిన ఇంటిగ్రేషన్‌లు ఇక్కడ కనిపిస్తాయి.';

  @override
  String nostrAppPermissionTitle(String appName) {
    return '$appNameమీ ఆమోదం కావాలి';
  }

  @override
  String get nostrAppPermissionDescription =>
      'ఈ యాప్ Divine యొక్క పరిశీలించబడిన శాండ్‌బాక్స్ ద్వారా యాక్సెస్‌ను అభ్యర్థిస్తోంది.';

  @override
  String get nostrAppPermissionOrigin => 'మూలం';

  @override
  String get nostrAppPermissionMethod => 'పద్ధతి';

  @override
  String get nostrAppPermissionCapability => 'సామర్థ్యం';

  @override
  String get nostrAppPermissionEventKind => 'ఈవెంట్ రకం';

  @override
  String get nostrAppPermissionAllow => 'అనుమతించండి';

  @override
  String get appsDetailDefaultTitle => 'ఇంటిగ్రేటెడ్ యాప్';

  @override
  String get appsDetailNotFoundTitle => 'ఇంటిగ్రేషన్ కనుగొనబడలేదు';

  @override
  String get appsDetailNotFoundSubtitle =>
      'ఈ ఆమోదించబడిన ఇంటిగ్రేషన్ Divineలో అందుబాటులో ఉండదు.';

  @override
  String get appsDetailHowItWorksTitle => 'ఇది ఎలా పని చేస్తుంది';

  @override
  String get appsDetailHowItWorksBody =>
      'ఇది Divine లోపల రన్ అయ్యే ఆమోదించబడిన మూడవ పక్ష యాప్. Divine ఈ ఏకీకరణ కోసం సమీక్షించబడిన సామర్థ్యాలను మాత్రమే మంజూరు చేస్తుంది మరియు దాని ఆమోదించబడిన మూలాల వెలుపల నావిగేషన్‌ను బ్లాక్ చేస్తుంది.';

  @override
  String get appsDetailAboutTitle => 'గురించి';

  @override
  String get appsDetailPrimaryOriginTitle => 'ప్రాథమిక మూలం';

  @override
  String get appsDetailApprovedOriginsTitle => 'ఆమోదించబడిన మూలాలు';

  @override
  String get appsDetailCapabilitiesTitle => 'అందుబాటులో ఉన్న సామర్థ్యాలు';

  @override
  String get appsDetailAskBeforeTitle => 'ముందు అడగండి';

  @override
  String get appsDetailOpenButton => 'ఓపెన్ ఇంటిగ్రేషన్';

  @override
  String get appsDetailNoneDeclared => 'ఏదీ ఇంకా ప్రకటించబడలేదు';

  @override
  String get appsDirectoryTitle => 'ఇంటిగ్రేటెడ్ యాప్‌లు';

  @override
  String get appsDirectoryIntroTitle => 'ఆమోదించబడిన మూడవ పక్ష యాప్‌లు';

  @override
  String get appsDirectoryIntroBody =>
      'Divine లోపల అమలు చేసే ఆమోదించబడిన మూడవ పక్ష యాప్‌లు';

  @override
  String get appsDirectoryErrorTitle =>
      'ఇంటిగ్రేటెడ్ యాప్‌లను లోడ్ చేయడం సాధ్యపడలేదు';

  @override
  String get appsDirectoryErrorSubtitle =>
      'ఆమోదించబడిన ఇంటిగ్రేషన్‌లను మళ్లీ ప్రయత్నించడానికి లాగండి.';

  @override
  String get appsDirectoryEmptyTitle => 'ఇంకా ఆమోదించబడిన ఇంటిగ్రేషన్‌లు లేవు';

  @override
  String get appsDirectoryEmptySubtitle =>
      'ఆమోదించబడిన థర్డ్-పార్టీ యాప్‌లు Divine జోడించినందున ఇక్కడ కనిపిస్తాయి.';

  @override
  String get appsDirectoryRefresh => 'రిఫ్రెష్';

  @override
  String get appsDirectoryUnsupportedTitle =>
      'ఇంటిగ్రేటెడ్ యాప్‌లు Divine మొబైల్‌లో రన్ అవుతాయి';

  @override
  String get appsDirectoryUnsupportedSubtitle =>
      'ఆమోదించబడిన ఇంటిగ్రేషన్‌లు ప్రస్తుతానికి మొబైల్‌లో మాత్రమే అందుబాటులో ఉన్నాయి.';

  @override
  String get appsSandboxUnavailableTitle => 'ఇంటిగ్రేషన్ అందుబాటులో లేదు';

  @override
  String get appsSandboxUnavailableBody =>
      'ఇంటిగ్రేటెడ్ యాప్‌ల ట్యాబ్ నుండి ఆమోదించబడిన ఇంటిగ్రేషన్‌లను తెరవండి, తద్వారా Divine సరైన యాక్సెస్ విధానాన్ని వర్తింపజేయవచ్చు.';

  @override
  String get appsSandboxLoadingTitle => 'ఇంటిగ్రేషన్ లోడ్ అవుతోంది';

  @override
  String get appsSandboxLoadingSubtitle =>
      'ప్రారంభించే ముందు ఆమోదించబడిన ఇంటిగ్రేషన్‌ను తనిఖీ చేస్తోంది.';

  @override
  String get appsSandboxBlockedTitle => 'భద్రత కోసం బ్లాక్ చేయబడింది';

  @override
  String appsSandboxBlockedSubtitle(String uri) {
    return 'ఈ ఏకీకరణ దాని ఆమోదించబడిన మూలాన్ని వదిలివేయడానికి ప్రయత్నించింది.\n\n$uri';
  }

  @override
  String get shareCopiedPostLink =>
      'పోస్ట్‌కి లింక్ క్లిప్‌బోర్డ్‌కి కాపీ చేయబడింది';

  @override
  String get shareCopiedEventJson =>
      'Nostr ఈవెంట్ JSON క్లిప్‌బోర్డ్‌కి కాపీ చేయబడింది';

  @override
  String get shareCopiedEventId =>
      'Nostr ఈవెంట్ ID క్లిప్‌బోర్డ్‌కి కాపీ చేయబడింది';

  @override
  String get authHeroTaglineAuthentic => 'ప్రామాణికమైన క్షణాలు.';

  @override
  String get authHeroTaglineHuman => 'మానవ సృజనాత్మకత.';

  @override
  String get keyImportFailedToImport =>
      'కీని దిగుమతి చేయడం లేదా కనెక్ట్ చేయడంలో విఫలమైంది bunker';

  @override
  String get keyImportInvalidBunkerUrl => 'చెల్లదు bunker URL';

  @override
  String get keyImportInvalidFormat =>
      'చెల్లని ఫార్మాట్. nsec..., hex, ncryptsec1..., లేదా bunker://...ని ఉపయోగించండి';

  @override
  String get keyImportInvalidNsecFormat =>
      'చెల్లని nsec ఫార్మాట్. 63 అక్షరాలు ఉండాలి';

  @override
  String get keyImportKeyFieldLabel => 'ప్రైవేట్ కీ లేదా bunker URL';

  @override
  String get keyImportKeyRequired =>
      'దయచేసి మీ ప్రైవేట్ కీ లేదా bunker URLని నమోదు చేయండి';

  @override
  String get keyImportPasswordRequired =>
      'దయచేసి ఈ ఎన్‌క్రిప్టెడ్ కీ కోసం పాస్‌వర్డ్‌ను నమోదు చేయండి';

  @override
  String get keyImportSecurityWarningBody =>
      'మీ ప్రైవేట్ కీని ఎవరితోనూ పంచుకోవద్దు. ఈ కీ మీ Nostr గుర్తింపుకు పూర్తి ప్రాప్తిని ఇస్తుంది.';

  @override
  String get keyImportSecurityWarningTitle =>
      'మీ ప్రైవేట్ కీని సురక్షితంగా ఉంచండి!';

  @override
  String get keyImportSubtitle =>
      'మీ ప్రైవేట్ కీ లేదా bunker URLని ఉపయోగించి మీ ప్రస్తుత Nostr గుర్తింపును దిగుమతి చేయండి.';

  @override
  String get keyImportTitle => 'మీ\nNostr గుర్తింపును దిగుమతి చేసుకోండి';

  @override
  String get commentAuthorYouIndicator => 'మీరు';

  @override
  String commentAuthorAvatarSemanticLabel(String name) {
    return 'వీక్షించండి $nameయొక్క ప్రొఫైల్';
  }

  @override
  String get commentOptionsDeleteSemanticLabel => 'వ్యాఖ్యను తొలగించండి';

  @override
  String get commentOptionsEditSemanticLabel => 'వ్యాఖ్యను సవరించండి';

  @override
  String get commentOptionsFlagContentLabel => 'ఫ్లాగ్ కంటెంట్';

  @override
  String get commentOptionsFlagContentSemanticLabel =>
      'ఈ కంటెంట్‌ను ఫ్లాగ్ చేయండి';

  @override
  String get commentOptionsFlagReasonPrompt =>
      'ఈ వ్యాఖ్యను ఫ్లాగ్ చేయడానికి కారణాన్ని ఎంచుకోండి';

  @override
  String get commentOptionsFlagSubmit => 'సమర్పించండి';

  @override
  String get commentOptionsTitle => 'ఎంపికలు';

  @override
  String get commentsEmptyClassicVineMessage =>
      'మేము ఇప్పటికీ ఆర్కైవ్ నుండి పాత వ్యాఖ్యలను దిగుమతి చేసే పనిలో ఉన్నాము. వారు ఇంకా సిద్ధంగా లేరు.';

  @override
  String get commentsEmptyClassicVineTitle => 'క్లాసిక్ Vine';

  @override
  String get commentsInputEditingLabel => 'సవరణ';

  @override
  String get commentsInputSemanticHint => 'వ్యాఖ్యను జోడించండి';

  @override
  String get commentsInputSemanticHintEdit => 'వ్యాఖ్యను సవరించండి';

  @override
  String get commentsInputSemanticHintReply => 'ప్రత్యుత్తరాన్ని జోడించండి';

  @override
  String get commentsInputSemanticLabel => 'వ్యాఖ్య ఇన్‌పుట్';

  @override
  String get commentsInputSemanticLabelEdit => 'ఇన్‌పుట్‌ని సవరించండి';

  @override
  String get commentsInputSemanticLabelReply => 'ప్రత్యుత్తర ఇన్‌పుట్';

  @override
  String classicVinersViewProfileSemanticLabel(String displayName) {
    return 'దీని కోసం ప్రొఫైల్‌ని వీక్షించండి$displayName';
  }

  @override
  String get classicsEmptyDescription => 'క్లాసిక్స్ ఆర్కైవ్ లోడ్ అవుతోంది';

  @override
  String get classicsEmptyTitle => 'క్లాసిక్‌లు ఏవీ కనుగొనబడలేదు';

  @override
  String get classicsErrorTitle => 'క్లాసిక్‌లను లోడ్ చేయడంలో విఫలమైంది';

  @override
  String get classicsUnavailableDescription =>
      'క్లాసిక్‌లు ఫన్నెల్‌కేక్ రిలేలకు కనెక్ట్ చేసినప్పుడు మాత్రమే అందుబాటులో ఉంటాయి.';

  @override
  String get classicsUnavailableSettingsHint =>
      'క్లాసిక్స్ ఆర్కైవ్‌ను యాక్సెస్ చేయడానికి సెట్టింగ్‌లలో ఫన్నెల్‌కేక్-ప్రారంభించబడిన రిలేకి మారండి.';

  @override
  String get classicsUnavailableTitle => 'క్లాసిక్‌లు అందుబాటులో లేవు';

  @override
  String get hashtagFeedEmptySubtitle =>
      'ఈ హ్యాష్‌ట్యాగ్‌తో వీడియోను పోస్ట్ చేసిన మొదటి వ్యక్తి అవ్వండి!';

  @override
  String hashtagFeedEmptyTitle(String hashtag) {
    return '# కోసం వీడియోలు ఏవీ కనుగొనబడలేదు$hashtag';
  }

  @override
  String get hashtagFeedLoadingSubtitle => 'దీనికి కొన్ని క్షణాలు పట్టవచ్చు';

  @override
  String hashtagFeedLoadingTitle(String hashtag) {
    return '# గురించిన వీడియోలను లోడ్ చేస్తోంది$hashtag...';
  }

  @override
  String get hashtagInputHint => 'హ్యాష్‌ట్యాగ్‌లను జోడించండి... #vine #nostr';

  @override
  String get newVideosTabEmptySubtitle =>
      'కొత్త కంటెంట్ కోసం తర్వాత మళ్లీ తనిఖీ చేయండి';

  @override
  String get newVideosTabEmptyTitle => 'కొత్త వీడియోలలో వీడియోలు లేవు';

  @override
  String get popularVideosContextTitle => 'జనాదరణ పొందిన వీడియోలు';

  @override
  String get popularVideosEmptySubtitle =>
      'కొత్త కంటెంట్ కోసం తర్వాత మళ్లీ తనిఖీ చేయండి';

  @override
  String get popularVideosEmptyTitle => 'జనాదరణ పొందిన వీడియోలలో వీడియోలు లేవు';

  @override
  String get popularVideosErrorTitle =>
      'ట్రెండింగ్ వీడియోలను లోడ్ చేయడంలో విఫలమైంది';

  @override
  String get popularVideosFeedSourceLabel => 'జనాదరణ పొందిన ఫీడ్ సోర్స్';

  @override
  String get trendingHashtagsLoading => 'హ్యాష్‌ట్యాగ్‌లను లోడ్ చేస్తోంది...';

  @override
  String trendingHashtagsViewVideosTagged(String hashtag) {
    return 'ట్యాగ్ చేయబడిన వీడియోలను వీక్షించండి $hashtag';
  }

  @override
  String videoGridAuthorSemanticLabel(String name) {
    return 'వీడియో రచయిత: $name';
  }

  @override
  String videoGridDescriptionSemanticLabel(String description) {
    return 'వీడియో వివరణ: $description';
  }

  @override
  String get forYouAlgorithmChoiceBody =>
      'Divine దృష్టి మీకు నిజమైన అల్గారిథమిక్ ఎంపికను అందించడం. ఒకే బ్లాక్-బాక్స్ అల్గారిథమ్‌లోకి లాక్ చేయబడటానికి బదులుగా, మీరు బహుళ సిఫార్సు విధానాల నుండి ఎంచుకోవచ్చు:';

  @override
  String get forYouAlgorithmChoiceChronological =>
      'మీరు అనుసరించే సృష్టికర్తల నుండి కాలక్రమానుసారం';

  @override
  String get forYouAlgorithmChoiceClosing =>
      'ఇది మీ దృష్టిని ప్లాట్‌ఫారమ్‌కు వదిలివేయకుండా మీపై నియంత్రణలో ఉంచుతుంది. మీ ఫీడ్ ఎలా క్యూరేట్ చేయబడిందో మీరు తెలుసుకోవాలి మరియు మీకు కావలసినప్పుడు దాన్ని మార్చుకునే అధికారం ఉండాలి.';

  @override
  String get forYouAlgorithmChoiceCustomFeeds =>
      'సంగీతం, హాస్యం లేదా కళ వంటి అంశాల కోసం సంఘం సృష్టించిన అనుకూల ఫీడ్‌లు';

  @override
  String get forYouAlgorithmChoicePersonalizedFeed =>
      '\"మీ కోసం\" ఫీడ్ వ్యక్తిగతీకరించబడింది';

  @override
  String get forYouAlgorithmChoiceTitle => 'మీ అల్గోరిథం, మీ ఎంపిక';

  @override
  String get forYouAlgorithmChoiceTrending =>
      'ట్రెండింగ్ మరియు జనాదరణ పొందిన కంటెంట్';

  @override
  String get forYouAlgorithmCommentsDescription =>
      'బలమైన సంకేతం — మీరు ప్రతిస్పందించడానికి తగినంత నిమగ్నమై ఉన్నారు';

  @override
  String get forYouAlgorithmHowItWorksBody =>
      'Divine మీరు ఆనందించే వాటిని అర్థం చేసుకోవడానికి మీరు కంటెంట్‌తో ఎలా పరస్పర చర్య చేస్తారనే దానిపై శ్రద్ధ చూపుతుంది. మీరు వీడియోను చూసిన ప్రతిసారీ, దానికి ప్రతిస్పందన ఇవ్వండి, వ్యాఖ్యానించండి లేదా దాన్ని మళ్లీ పోస్ట్ చేయండి, సిస్టమ్ గమనిస్తుంది.';

  @override
  String get forYouAlgorithmHowItWorksTitle => 'ఇది ఎలా పని చేస్తుంది';

  @override
  String get forYouAlgorithmInteractionsIntro =>
      'విభిన్న చర్యలు వివిధ స్థాయిల ఆసక్తిని సూచిస్తాయి:';

  @override
  String get forYouAlgorithmNewToDivineBody1 =>
      'మీరు వీక్షణ చరిత్రను ఇంకా నిర్మించకుంటే, మేము ఇటీవలి అప్‌లోడ్‌లతో పాటు ప్రస్తుతం జనాదరణ పొందిన మరియు ట్రెండింగ్‌లో ఉన్న వాటి మిశ్రమాన్ని చూపుతాము. ఇది అన్వేషించడానికి మీకు గొప్ప ప్రారంభ స్థానం ఇస్తుంది.';

  @override
  String get forYouAlgorithmNewToDivineBody2 =>
      'మీరు కంటెంట్‌ని వీక్షిస్తున్నప్పుడు, ఇష్టపడుతున్నప్పుడు మరియు దానితో నిమగ్నమై ఉన్నప్పుడు, సిఫార్సులు క్రమంగా మరింత వ్యక్తిగతీకరించబడతాయి. కాలక్రమేణా, సృష్టికర్తల నుండి మీ కోసం మీ ఫీడ్ ఉపరితలాల వీడియోలను మీరు మీ స్వంతంగా ఎప్పటికీ కనుగొని ఉండకపోవచ్చు.';

  @override
  String get forYouAlgorithmNewToDivineTitle => 'Divineకి కొత్తవా?';

  @override
  String get forYouAlgorithmOpenSourceBody =>
      'డెవలపర్‌లు వారి స్వంత అల్గారిథమ్‌లను అమలు చేయగల ఓపెన్ సిస్టమ్‌ను మేము రూపొందిస్తున్నాము మరియు మీరు ఏవి ఉపయోగించాలో ఎంచుకోవచ్చు — లేదా పూర్తిగా నిలిపివేయండి.';

  @override
  String get forYouAlgorithmOpenSourceTitle => 'ఓపెన్ సోర్స్ & పారదర్శకం';

  @override
  String get forYouAlgorithmReactionsDescription =>
      'మీడియం సిగ్నల్ — ప్రశంసలను చూపించడానికి శీఘ్ర మార్గం';

  @override
  String get forYouAlgorithmReactionsTitle => 'ప్రతిచర్యలు';

  @override
  String get forYouAlgorithmRepostsDescription =>
      'బలమైన సంకేతం — మీ అనుచరులతో భాగస్వామ్యం చేయడం ఒక శక్తివంతమైన ఆమోదం';

  @override
  String get forYouAlgorithmSubtitle =>
      'ఓపెన్ సోర్స్ సిఫార్సు ఇంజిన్ అయిన గోర్స్ ద్వారా ఆధారితం';

  @override
  String get forYouAlgorithmTitle => 'Divine అల్గోరిథం';

  @override
  String get forYouAlgorithmViewsDescription =>
      'లైట్ సిగ్నల్ — ప్రాథమిక ఆసక్తిని సూచిస్తుంది';

  @override
  String get forYouEmptyDescription =>
      'వ్యక్తిగతీకరించిన సిఫార్సులను పొందడానికి కొన్ని వీడియోలను చూడండి మరియు లైక్ చేయండి.';

  @override
  String get forYouEmptyTitle => 'ఇంకా ఎటువంటి సిఫార్సులు లేవు';

  @override
  String get forYouErrorTitle => 'సిఫార్సులను లోడ్ చేయడంలో విఫలమైంది';

  @override
  String get forYouUnavailableDescription =>
      'వ్యక్తిగతీకరించిన సిఫార్సులకు Funnelcakeకి కనెక్షన్ అవసరం.';

  @override
  String get forYouUnavailableTitle => 'మీ కోసం అందుబాటులో లేదు';

  @override
  String get inboxConversationOptionsLabel => 'ఎంపికలు';

  @override
  String get inboxConversationViewProfileButton => 'ప్రొఫైల్‌ని వీక్షించండి';

  @override
  String get inboxMessageRequestsEmpty => 'సందేశ అభ్యర్థనలు లేవు';

  @override
  String inboxMessageRequestsSemanticLabel(int requestCount) {
    return 'సందేశ అభ్యర్థనలు, $requestCountపెండింగ్‌లో ఉంది';
  }

  @override
  String get inboxMessageRequestsTitle => 'సందేశ అభ్యర్థనలు';

  @override
  String get inboxMessagesTab => 'సందేశాలు';

  @override
  String inboxRequestTileLabel(String displayName) {
    return '$displayNameసందేశ అభ్యర్థన';
  }

  @override
  String get inboxRequestTileSubtitle => 'సందేశ అభ్యర్థన పంపబడింది';

  @override
  String get inboxRequestsMarkAllRead =>
      'అన్ని అభ్యర్థనలను చదివినట్లుగా గుర్తించండి';

  @override
  String get inboxRequestsRemoveAll => 'అన్ని అభ్యర్థనలను తీసివేయండి';

  @override
  String get messageRequestDeclineAndRemoveButton =>
      'తిరస్కరించండి మరియు తీసివేయండి';

  @override
  String messageRequestDeclinedSnackbar(String displayName) {
    return 'తిరస్కరించబడింది $displayNameయొక్క అభ్యర్థన';
  }

  @override
  String get messageRequestLoadFailed => 'ఈ అభ్యర్థనను లోడ్ చేయడం సాధ్యపడలేదు.';

  @override
  String messageRequestFollowersCount(int countValue, String count) {
    String _temp0 = intl.Intl.pluralLogic(
      countValue,
      locale: localeName,
      other: '$countఅనుచరులు',
      one: '$countఅనుచరుడు',
    );
    return '$_temp0';
  }

  @override
  String messageRequestVideosCount(int countValue, String count) {
    String _temp0 = intl.Intl.pluralLogic(
      countValue,
      locale: localeName,
      other: '$countవీడియోలు',
      one: '$countవీడియో',
    );
    return '$_temp0';
  }

  @override
  String messageRequestMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countసందేశాలు',
      one: '1 సందేశం',
    );
    return '$_temp0';
  }

  @override
  String get messageRequestViewMessagesButton => 'సందేశాలను వీక్షించండి';

  @override
  String get messageRequestViewProfileButton => 'ప్రొఫైల్‌ని వీక్షించండి';

  @override
  String messageRequestWantsToMessageYou(
    String displayName,
    String messageText,
  ) {
    return '$displayNameమీకు సందేశం పంపాలనుకుంటున్నారు, వారు పంపారు $messageText.';
  }

  @override
  String get deleteAccountAccountChanged =>
      'మీరు ఖాతాలను మార్చారు, కాబట్టి ఏదీ తొలగించబడలేదు. మీరు తీసివేయాలనుకుంటున్న ఖాతా కోసం తొలగింపును మళ్లీ తెరవండి.';

  @override
  String get deleteAccountConfirmDeletePrompt =>
      'నిర్ధారించడానికి, టైప్ చేయండి:';

  @override
  String get deleteAccountConfirmUsernamePrompt =>
      'నిర్ధారించడానికి, మీ వినియోగదారు పేరును టైప్ చేయండి:';

  @override
  String get deleteAccountConfirmationHint => 'DELETE అని టైప్ చేయండి';

  @override
  String get deleteAccountConfirmationHintUsername =>
      'మీ వినియోగదారు పేరును టైప్ చేయండి';

  @override
  String get deleteAccountDeleteAllContentButton =>
      'మొత్తం కంటెంట్‌ను తొలగించండి';

  @override
  String get accountDeletionRecoveryTitle => 'మీ ఖాతా తొలగించబడుతోంది';

  @override
  String get accountDeletionRecoveryBody =>
      'మేము మీ ఖాతాను తొలగించడాన్ని పూర్తి చేయలేకపోయాము. మీ వినియోగదారు పేరు మీ కోసం ప్రత్యేకించబడింది మరియు ఇప్పటికీ పునరుద్ధరించబడవచ్చు.';

  @override
  String accountDeletionRecoveryBodyWithExpiry(String expiryDate) {
    return 'మేము మీ ఖాతాను తొలగించడాన్ని పూర్తి చేయలేకపోయాము. మీ వినియోగదారు పేరు మీ కోసం రిజర్వ్ చేయబడింది $expiryDateమరియు ఇప్పటికీ పునరుద్ధరించబడవచ్చు.';
  }

  @override
  String get accountDeletionRestoreUsername =>
      'నా వినియోగదారు పేరును పునరుద్ధరించండి';

  @override
  String get accountDeletionFinishingBody =>
      'మీ ఖాతా తొలగింపు అభ్యర్థన ఇప్పటికీ ప్రాసెస్ చేయబడుతోంది. మేము దీన్ని పూర్తి చేసే వరకు మీరు మరొక ఖాతాను ఉపయోగించవచ్చు.';

  @override
  String get accountDeletionOtherAccountPending =>
      'ఈ పరికరంలో మరొక ఖాతా తొలగింపు ఇప్పటికీ ప్రాసెస్ చేయబడుతోంది. ఈ ఖాతాను తొలగించే ముందు అది పూర్తయ్యే వరకు వేచి ఉండండి.';

  @override
  String get accountDeletionCancellingBody =>
      'మేము మీ తొలగింపును రద్దు చేస్తున్నాము. ఈ స్క్రీన్ నుండి నిష్క్రమించే ముందు మళ్లీ తనిఖీ చేయండి.';

  @override
  String get accountDeletionRecoveryFailed =>
      'మేము మీ వినియోగదారు పేరును ఇంకా పునరుద్ధరించలేకపోయాము. మీ కనెక్షన్‌ని తనిఖీ చేసి, మళ్లీ ప్రయత్నించండి.';

  @override
  String get accountDeletionUsernameRestored =>
      'మీ వినియోగదారు పేరు పునరుద్ధరించబడింది. మీ ఖాతా తొలగించబడలేదు.';

  @override
  String get accountDeletionRecoveryStatusFailed =>
      'మేము మీ తొలగింపు స్థితిని తనిఖీ చేయలేకపోయాము. మీ కనెక్షన్‌ని తనిఖీ చేసి, మళ్లీ ప్రయత్నించండి.';

  @override
  String get accountDeletionCancelAttemptBody =>
      'మేము మీ ఖాతాను తొలగించడాన్ని పూర్తి చేయలేకపోయాము. మీరు ఈ ప్రయత్నాన్ని రద్దు చేసి, మీ ఖాతాను ఉంచుకోవచ్చు.';

  @override
  String get accountDeletionCancelAttempt => 'నా ఖాతాను ఉంచండి';

  @override
  String get accountDeletionAttemptCancelled =>
      'ఖాతా తొలగింపు రద్దు చేయబడింది. మీ ఖాతా తొలగించబడలేదు.';

  @override
  String get accountDeletionTerminalFailureBody =>
      'మేము మీ ఖాతాను తొలగించలేకపోయాము. సహాయం కోసం మద్దతును సంప్రదించండి లేదా ఈ స్క్రీన్ నుండి నిష్క్రమించడానికి సైన్ అవుట్ చేయండి.';

  @override
  String get accountDeletionSignOut => 'సైన్ అవుట్ చేయండి';

  @override
  String get deleteAccountDeletionUnavailable =>
      'ఖాతా తొలగింపు ప్రస్తుతం అందుబాటులో లేదు. ఏదీ తొలగించబడలేదు.';

  @override
  String get deleteAccountDeletionIncomplete =>
      'మేము మీ ఖాతాను తొలగించడాన్ని పూర్తి చేయలేకపోయాము. మళ్లీ ప్రయత్నించండి.';

  @override
  String get deleteAccountDeletionNotStarted =>
      'మేము మీ ఖాతాను తొలగించడం ప్రారంభించలేకపోయాము. ఏదీ తొలగించబడలేదు. మళ్లీ ప్రయత్నించండి.';

  @override
  String get deleteAccountFinalConfirmationTitle => '⚠️ తుది నిర్ధారణ';

  @override
  String get deleteAccountKeyDeletionWarning =>
      'తొలగింపు అభ్యర్థనలు పంపబడ్డాయి, కానీ మీ కీలు ఈ పరికరం నుండి పూర్తిగా తీసివేయబడి ఉండకపోవచ్చు. మళ్లీ ప్రయత్నించడానికి సెట్టింగ్‌లు → Nostr కీలు → కీలను తీసివేయండి.';

  @override
  String get deleteAccountLocalDataDeletionFailed =>
      'తొలగింపు అభ్యర్థనలు పంపబడ్డాయి మరియు మీరు సైన్ అవుట్ చేసారు, కానీ ఈ పరికరం నుండి కొంత స్థానిక డేటా తీసివేయబడలేదు.';

  @override
  String get deleteAccountPreparingDeletion => 'తొలగింపును సిద్ధం చేస్తోంది...';

  @override
  String deleteAccountProgressEvents(int current, int total) {
    return '$current / $totalఈవెంట్‌లు';
  }

  @override
  String get deleteAccountRemoveKeysBody =>
      'ఇది ఈ పరికరం నుండి ఈ ఖాతా కోసం స్థానిక లాగిన్‌ను తీసివేస్తుంది. ఇది మీ Divine ఖాతాను లేదా Nostr గుర్తింపును తొలగించదు. ఇది మీ చివరి స్థానిక ఖాతా అయితే, మీరు లాగిన్ స్క్రీన్‌కి తిరిగి వస్తారు.';

  @override
  String get deleteAccountRemoveKeysConfirm => 'పరికరం నుండి తీసివేయండి';

  @override
  String get deleteAccountRemoveKeysTitle =>
      'ఈ పరికరం నుండి ఈ ఖాతాను తీసివేయాలా?';

  @override
  String get deleteAccountReauthRequired =>
      'మీ ఖాతాను తొలగించడానికి మళ్లీ సైన్ ఇన్ చేయండి. ఇంకా ఏదీ తొలగించబడలేదు.';

  @override
  String get deleteAccountServerDeletionFailed =>
      'మీ పోస్ట్‌ల కోసం తొలగింపు అభ్యర్థనలు పంపబడ్డాయి, కానీ మేము మీ ఖాతాను తొలగించడాన్ని పూర్తి చేయలేకపోయాము. కొంచెం తర్వాత మళ్లీ ప్రయత్నించండి.';

  @override
  String get deleteAccountSuccess =>
      'మీ Divine ఖాతా తొలగించబడింది. మీ Nostr పోస్ట్‌ల కోసం తొలగింపు అభ్యర్థనలు పంపబడ్డాయి, కానీ కొన్ని రిలేలు, క్లయింట్లు లేదా క్యాష్‌లు కాపీలను ఉంచవచ్చు.';

  @override
  String get deleteAccountSuccessContentUnverified =>
      'ఖాతా తొలగింపు అభ్యర్థించబడింది. ఇప్పటికే ఉన్న కొన్ని పోస్ట్‌లు తొలగింపు కోసం వ్యక్తిగతంగా నిర్ధారించబడలేదు.';

  @override
  String get deleteAccountWarningBody =>
      'ఇది మీ ఖాతా మరియు కంటెంట్ కోసం తొలగింపు అభ్యర్థనలను పంపుతుంది, సాధ్యమైనప్పుడు మీ Divine ఖాతాను తొలగిస్తుంది మరియు ఈ పరికరంలో మిమ్మల్ని సైన్ అవుట్ చేస్తుంది. కొన్ని రిలేలు, క్లయింట్లు మరియు శోధన సూచికలు కాపీలను ఉంచవచ్చు. మీరు అక్కడ ఉన్న కీలను తీసివేసే వరకు ఇతర సైన్ ఇన్ చేసిన పరికరాలు సక్రియంగా ఉంటాయి.';

  @override
  String get findPeopleNoContacts =>
      'పరిచయాలు ఏవీ కనుగొనబడలేదు.\nవ్యక్తులను ఇక్కడ చూడటానికి వారిని అనుసరించడం ప్రారంభించండి.';

  @override
  String get geoBlockedCityLabel => 'నగరం';

  @override
  String get geoBlockedCountryLabel => 'దేశం';

  @override
  String get geoBlockedDefaultReason =>
      'స్థానిక నిబంధనల కారణంగా ఈ సేవ మీ ప్రాంతంలో అందుబాటులో లేదు.';

  @override
  String get geoBlockedLegalNotice =>
      'మేము మీ స్థానిక చట్టాలు మరియు నిబంధనలను గౌరవిస్తాము. ఈ పరిమితి మీ IP చిరునామా స్థానం ఆధారంగా ఉంటుంది.';

  @override
  String get geoBlockedRegionLabel => 'ప్రాంతం';

  @override
  String get geoBlockedTitle => 'సేవ అందుబాటులో లేదు';

  @override
  String get likedVideosEmpty => 'ఇష్టపడిన వీడియోలు లేవు';

  @override
  String get likedVideosInvalidRoute => 'మార్గం చెల్లదు';

  @override
  String get likedVideosTitle => 'ఇష్టపడిన వీడియోలు';

  @override
  String get uploadFailureSheetRetryingSnackbar =>
      'అప్‌లోడ్ చేయడానికి మళ్లీ ప్రయత్నిస్తోంది…';

  @override
  String get uploadFailureSheetSaveToDraftsButton => 'డ్రాఫ్ట్‌లకు సేవ్ చేయండి';

  @override
  String get uploadFailureSheetSavedToDraftsSnackbar =>
      'చిత్తుప్రతులకు సేవ్ చేయబడింది';

  @override
  String get uploadFailureSheetTitle => 'అప్‌లోడ్ విఫలమైంది';

  @override
  String get uploadFailureSheetTryAgainButton => 'మళ్లీ ప్రయత్నించండి';

  @override
  String get videoEditorAudioImportAudio => 'ఆడియోను దిగుమతి చేయండి';

  @override
  String get videoEditorAudioImportFailed => 'ఆడియో దిగుమతి విఫలమైంది.';

  @override
  String get videoIconPlaceholderLabel => 'వీడియో';

  @override
  String get publishErrorNotSignedIn =>
      'దయచేసి వీడియోలను ప్రచురించడానికి సైన్ ఇన్ చేయండి.';

  @override
  String get publishErrorNoRetry => 'మళ్లీ ప్రయత్నించడానికి అప్‌లోడ్ లేదు.';

  @override
  String get publishErrorNoInternet =>
      'ఇంటర్నెట్ కనెక్షన్ లేదు. మీ Wi-Fi లేదా మొబైల్ డేటాను తనిఖీ చేసి, మళ్లీ ప్రయత్నించండి.';

  @override
  String get publishErrorServerUnreachable =>
      'సర్వర్‌ని చేరుకోలేకపోయింది. దయచేసి ఒక క్షణంలో మళ్లీ ప్రయత్నించండి.';

  @override
  String get publishErrorTimeout =>
      'అప్‌లోడ్ సమయం ముగిసింది. బలమైన కనెక్షన్ లేదా చిన్న వీడియోని ప్రయత్నించండి.';

  @override
  String get publishErrorTls =>
      'సురక్షిత కనెక్షన్ విఫలమైంది. మీ నెట్‌వర్క్‌ని తనిఖీ చేయండి — పబ్లిక్ Wi-Fi అప్‌లోడ్‌లను నిరోధించగలదు.';

  @override
  String publishErrorServerNotFound(String serverName) {
    return 'మీడియా సర్వర్ ($serverName) అందుబాటులో లేదు. మీరు మీ సెట్టింగ్‌లలో మరొకటి ఎంచుకోవచ్చు.';
  }

  @override
  String get publishErrorFileTooLarge =>
      'వీడియో ఫైల్ సర్వర్‌కు చాలా పెద్దదిగా ఉంది. దాన్ని కత్తిరించడం లేదా నాణ్యతను తగ్గించడం ప్రయత్నించండి.';

  @override
  String publishErrorServerInternalError(String serverName) {
    return 'మీడియా సర్వర్ ($serverName) అంతర్గత లోపాన్ని కలిగి ఉంది. మీరు మీ సెట్టింగ్‌లలో మరొకటి ఎంచుకోవచ్చు.';
  }

  @override
  String publishErrorServerDown(String serverName) {
    return 'మీడియా సర్వర్ ($serverName) తాత్కాలికంగా తగ్గింది. త్వరలో మళ్లీ ప్రయత్నించండి లేదా మీ సెట్టింగ్‌లలో మరొకదాన్ని ఎంచుకోండి.';
  }

  @override
  String get publishErrorForbidden =>
      'ఈ సర్వర్‌కి అప్‌లోడ్ చేయడానికి మీకు అనుమతి లేదు.';

  @override
  String get publishErrorFileNotFound =>
      'వీడియో ఫైల్ కనుగొనబడలేదు. ఇది తొలగించబడి ఉండవచ్చు. మళ్లీ రికార్డ్ చేసి, మళ్లీ ప్రయత్నించండి.';

  @override
  String get publishErrorLowStorage =>
      'మీ పరికరంలో తగినంత నిల్వ లేదు. కొంత స్థలాన్ని ఖాళీ చేసి, మళ్లీ ప్రయత్నించండి.';

  @override
  String get publishErrorThumbnailFailed =>
      'వీడియో అప్‌లోడ్ చేయబడింది, కానీ సూక్ష్మచిత్రాన్ని సిద్ధం చేయడం సాధ్యపడలేదు. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get publishErrorNostrPublishFailed =>
      'వీడియో అప్‌లోడ్ చేయబడింది కానీ పోస్ట్ ప్రచురించబడలేదు. మీ రిలే సెట్టింగ్‌లను తనిఖీ చేసి, మళ్లీ ప్రయత్నించండి.';

  @override
  String get publishErrorAccountRestricted =>
      'మీ ఖాతా పరిమితం చేయబడింది, కాబట్టి ఈ పోస్ట్ ప్రచురించబడదు.';

  @override
  String get uploadFailureSheetAccountStatusButton =>
      'ఖాతా స్థితిని వీక్షించండి';

  @override
  String get publishErrorAudioReuseNotPermitted =>
      'వీడియో అప్‌లోడ్ చేయబడింది, కానీ దాని ధ్వని పునర్వినియోగం కోసం క్లియర్ చేయబడలేదు. దాన్ని పోస్ట్ చేయడానికి వేరే ధ్వనిని ఎంచుకోండి.';

  @override
  String get publishErrorInterrupted =>
      'ఈ అప్‌లోడ్ అంతరాయం కలిగింది. మీరు మళ్లీ ప్రయత్నించాలనుకుంటున్నారా?';

  @override
  String get publishErrorAccountChanged =>
      'ఈ వీడియో వేరే ఖాతాకు చెందినది. దాన్ని పోస్ట్ చేయడానికి ఆ ఖాతాకు తిరిగి మారండి.';

  @override
  String get publishErrorGeneric =>
      'ఏదో తప్పు జరిగింది. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get publishErrorRateLimited =>
      'ప్రస్తుతం చాలా ఎక్కువ అప్‌లోడ్‌లు ఉన్నాయి. ఒక క్షణం వేచి ఉండి, మళ్లీ ప్రయత్నించండి.';

  @override
  String get publishErrorUploadSessionExpired =>
      'మీ అప్‌లోడ్ సెషన్ గడువు ముగిసింది. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get publishErrorPermissionDenied =>
      'Divineకి అప్‌లోడ్ చేయడానికి అనుమతి లేదు. మీ సెట్టింగ్‌లలో యాప్ అనుమతులను తనిఖీ చేసి, మళ్లీ ప్రయత్నించండి.';

  @override
  String get publishErrorOutOfMemory =>
      'మీ పరికరంలో మెమరీ తక్కువగా ఉంది. కొన్ని యాప్‌లను మూసివేసి, మళ్లీ ప్రయత్నించండి.';

  @override
  String get publishErrorOverlaysUnavailable =>
      'ఈ డ్రాఫ్ట్‌లోని టెక్స్ట్ మరియు స్టిక్కర్‌లను సిద్ధం చేయడం సాధ్యపడలేదు. దాన్ని ఎడిటర్‌లో తెరిచి, ఆపై మళ్లీ పోస్ట్ చేయండి.';

  @override
  String get publishErrorUnknownServer => 'తెలియని సర్వర్';

  @override
  String searchFilterPillSemanticLabel(String filter) {
    return 'ఫిల్టర్: $filter';
  }

  @override
  String searchNoResultsFound(String query) {
    return '\" కోసం ఫలితాలు కనుగొనబడలేదు$query\"';
  }

  @override
  String searchTagChipViewVideosTaggedLabel(String tag) {
    return 'ట్యాగ్ చేయబడిన వీడియోలను వీక్షించండి $tag';
  }

  @override
  String audioAttributionRowSemanticLabel(
    String soundName,
    String creatorName,
  ) {
    return 'ధ్వని: $soundNameద్వారా $creatorName. ధ్వని వివరాలను వీక్షించడానికి నొక్కండి.';
  }

  @override
  String metadataSoundsOriginalSoundSemantics(String creatorName) {
    return 'ద్వారా అసలు ధ్వని $creatorName. ఈ ధ్వనిని ఉపయోగించడానికి నొక్కండి.';
  }

  @override
  String metadataSoundsSharedSoundSemantics(
    String soundName,
    String creatorName,
  ) {
    return 'ధ్వని: $soundNameద్వారా$creatorName. వివరాలను వీక్షించడానికి నొక్కండి.';
  }

  @override
  String get soundDetailLoadError =>
      'ధ్వనిని లోడ్ చేయడంలో విఫలమైంది. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get soundDetailNotFoundMessage => 'ఈ ధ్వని కనుగొనబడలేదు';

  @override
  String get soundDetailNotFoundTitle => 'ధ్వని కనుగొనబడలేదు';

  @override
  String videoFeedLoopCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '🔁 $countలూప్‌లు',
      one: '🔁 $countలూప్',
    );
    return '$_temp0';
  }

  @override
  String get originalSoundUnavailableBody =>
      'ఈ వీడియో నుండి ఆడియో విడిగా అందుబాటులో లేదు.';

  @override
  String originalSoundByCreator(String creatorName) {
    return 'అసలు ధ్వని - $creatorName';
  }

  @override
  String get ogVinerBadgeLabel => 'OG Viner';

  @override
  String get profileBadgeOgVinerBody =>
      'ఈ వ్యక్తి ఆర్కైవ్‌లో Divine కనుగొనబడిన అసలైన Vineని పోస్ట్ చేసారు. ఇది ఖాతా ధృవీకరణ బ్యాడ్జ్ కాదు.';

  @override
  String get ogBetaTesterBadgeLabel => 'OG బీటా టెస్టర్';

  @override
  String get profileBadgeOgBetaTesterBody =>
      'ఈ వ్యక్తి బీటా సమయంలో Divineని ప్రతి ఒక్కరికీ తెరవడానికి ముందు పరీక్షిస్తున్నారు. ఇది ఖాతా ధృవీకరణ బ్యాడ్జ్ కాదు.';

  @override
  String get profileBadgeCheckmarkTitle => 'ప్రొఫైల్ చెక్‌మార్క్';

  @override
  String get profileBadgeCheckmarkBody =>
      'Divine జట్టు ఖాతాలకు ఈ చెక్‌మార్క్ ఇస్తుంది. ఇది NIP-05, ధృవీకరించబడిన ఖాతా లింక్‌లు మరియు OG Viner స్థితి నుండి వేరుగా ఉంటుంది.';

  @override
  String get unfollowConfirmButton => 'అనుసరించవద్దు';

  @override
  String get videoClipSaveFailed => 'క్లిప్‌ను సేవ్ చేయడంలో విఫలమైంది';

  @override
  String videoClipSaveTo(String destination) {
    return 'కు సేవ్ చేయండి $destination';
  }

  @override
  String get videoClipDelete => 'క్లిప్‌ను తొలగించండి';

  @override
  String inspiredByAttributionMultipleSemanticLabel(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return 'ప్రేరణ $creatorName +$additionalCreatorCount. వారి ప్రొఫైల్‌ను వీక్షించడానికి నొక్కండి.';
  }

  @override
  String inspiredByAttributionSemanticLabel(String creatorName) {
    return 'ప్రేరణ $creatorName. వారి ప్రొఫైల్‌ను వీక్షించడానికి నొక్కండి.';
  }

  @override
  String get bugReportSendReport => 'నివేదిక పంపండి';

  @override
  String get supportSubjectRequiredLabel => 'విషయం *';

  @override
  String get supportPublicSubmissionTitle => 'పబ్లిక్ గిట్‌హబ్ పోస్ట్';

  @override
  String get supportPublicSubmissionMessage =>
      'మీరు ఇక్కడ సమర్పించిన ప్రతిదీ GitHubలోని మా ఓపెన్-సోర్స్ రిపోజిటరీకి పోస్ట్ చేయబడుతుంది కాబట్టి డెవలపర్‌లు దాన్ని ఎంచుకోవచ్చు. మీ పోస్ట్ మరియు మీరు సైన్ ఇన్ చేసిన ఖాతా అందరికీ పబ్లిక్‌గా కనిపిస్తాయి.';

  @override
  String get supportRequiredHelper => 'అవసరం';

  @override
  String get supportFieldLimitReached =>
      'ఇది గరిష్ట పొడవు. ఇంతకు ముందు ఏదీ జోడించబడలేదు.';

  @override
  String get bugReportSubjectHint => 'సమస్య యొక్క సంక్షిప్త సారాంశం';

  @override
  String get bugReportDescriptionRequiredLabel => 'ఏం జరిగింది? *';

  @override
  String get bugReportDescriptionHint => 'మీరు ఎదుర్కొన్న సమస్యను వివరించండి';

  @override
  String get bugReportStepsLabel => 'పునరుత్పత్తికి దశలు';

  @override
  String get bugReportStepsHint =>
      '1. దీనికి వెళ్లండి...\n2. నొక్కండి...\n3. లోపం చూడండి';

  @override
  String get bugReportExpectedBehaviorLabel => 'ఊహించిన ప్రవర్తన';

  @override
  String get bugReportExpectedBehaviorHint => 'బదులుగా ఏమి జరిగి ఉండాలి?';

  @override
  String get bugReportDiagnosticsNotice =>
      'పరికర సమాచారం మరియు లాగ్‌లు స్వయంచాలకంగా చేర్చబడతాయి.';

  @override
  String get bugReportSuccessMessage =>
      'ధన్యవాదాలు! మేము మీ నివేదికను స్వీకరించాము మరియు Divineని మెరుగుపరచడానికి దాన్ని ఉపయోగిస్తాము.';

  @override
  String get bugReportAttachImages => 'చిత్రాలను అటాచ్ చేయండి\nయొక్క ';

  @override
  String bugReportImagesCount(int count, int max) {
    return '$count$maxచిత్రాలు ఎంచుకోబడ్డాయి';
  }

  @override
  String get bugReportRemoveImage => 'చిత్రాన్ని తీసివేయండి';

  @override
  String get bugReportUploadFailed =>
      'మేము ఎంచుకున్న చిత్రాన్ని అప్‌లోడ్ చేయలేకపోయాము. మళ్లీ ప్రయత్నించండి లేదా నివేదిక లేకుండానే పంపండి.';

  @override
  String get bugReportSendFailed =>
      'బగ్ నివేదికను పంపడంలో విఫలమైంది. దయచేసి తర్వాత మళ్లీ ప్రయత్నించండి.';

  @override
  String get featureRequestSendRequest => 'అభ్యర్థన పంపండి';

  @override
  String get featureRequestSubjectHint => 'మీ ఆలోచన యొక్క సంక్షిప్త సారాంశం';

  @override
  String get featureRequestDescriptionRequiredLabel =>
      'మీరు ఏమి కోరుకుంటున్నారు? *';

  @override
  String get featureRequestDescriptionHint =>
      'మీకు కావలసిన లక్షణాన్ని వివరించండి';

  @override
  String get featureRequestUsefulnessLabel => 'ఇది ఎలా ఉపయోగపడుతుంది?';

  @override
  String get featureRequestUsefulnessHint =>
      'ఈ ఫీచర్ అందించే ప్రయోజనాన్ని వివరించండి';

  @override
  String get featureRequestWhenLabel => 'మీరు దీన్ని ఎప్పుడు ఉపయోగిస్తారు?';

  @override
  String get featureRequestWhenHint => 'ఇది సహాయపడే పరిస్థితులను వివరించండి';

  @override
  String get featureRequestSuccessMessage =>
      'ధన్యవాదాలు! మేము మీ ఫీచర్ అభ్యర్థనను స్వీకరించాము మరియు దానిని సమీక్షిస్తాము.';

  @override
  String get featureRequestSendFailed =>
      'ఫీచర్ అభ్యర్థనను పంపడంలో విఫలమైంది. దయచేసి తర్వాత మళ్లీ ప్రయత్నించండి.';

  @override
  String get notificationFollowBack => 'తిరిగి అనుసరించండి';

  @override
  String get followingTitle => 'అనుసరిస్తున్నారు';

  @override
  String followingTitleForName(String displayName) {
    return '$displayName\'లు అనుసరిస్తున్నారు';
  }

  @override
  String get followingFailedToLoadList =>
      'క్రింది జాబితాను లోడ్ చేయడంలో విఫలమైంది';

  @override
  String get followingEmptyTitle => 'ఇంకా ఎవరినీ అనుసరించడం లేదు';

  @override
  String get followersTitle => 'అనుచరులు';

  @override
  String followersTitleForName(String displayName) {
    return '$displayNameయొక్క అనుచరులు';
  }

  @override
  String get followersFailedToLoadList =>
      'అనుచరుల జాబితాను లోడ్ చేయడంలో విఫలమైంది';

  @override
  String get followersEmptyTitle => 'ఇంకా అనుచరులు లేరు';

  @override
  String get followersUpdateFollowFailed =>
      'ఫాలో స్థితిని నవీకరించడంలో విఫలమైంది. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get followersSortSemanticLabel => 'అనుచరులను క్రమబద్ధీకరించండి';

  @override
  String get followingSortSemanticLabel => 'కింది వాటిని క్రమబద్ధీకరించండి';

  @override
  String get followSortTitle => 'క్రమబద్ధీకరించండి';

  @override
  String get followSortNewest => 'కొత్తది మొదటిది';

  @override
  String get followSortOldest => 'పాతది మొదటిది';

  @override
  String get newMessageTitle => 'కొత్త సందేశం';

  @override
  String get newMessageFindPeople => 'వ్యక్తులను కనుగొనండి';

  @override
  String get newMessageNoContacts =>
      'పరిచయాలు ఏవీ కనుగొనబడలేదు.\nవ్యక్తులను ఇక్కడ చూడటానికి వారిని అనుసరించండి.';

  @override
  String get newMessageNoUsersFound => 'వినియోగదారులు ఎవరూ కనుగొనబడలేదు';

  @override
  String get hashtagSearchTitle => 'హ్యాష్‌ట్యాగ్‌ల కోసం శోధించండి';

  @override
  String get hashtagSearchSubtitle =>
      'ట్రెండింగ్ విషయాలు మరియు కంటెంట్‌ను కనుగొనండి';

  @override
  String hashtagSearchNoResults(String query) {
    return '\" కోసం హ్యాష్‌ట్యాగ్‌లు ఏవీ కనుగొనబడలేదు$query\"';
  }

  @override
  String get hashtagSearchFailed => 'శోధన విఫలమైంది';

  @override
  String get userNotAvailableTitle => 'ఖాతా అందుబాటులో లేదు';

  @override
  String get userNotAvailableBody => 'ఈ ఖాతా ప్రస్తుతం అందుబాటులో లేదు.';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String get blossomFailedToSaveSettings =>
      'సెట్టింగ్‌లను సేవ్ చేయడంలో విఫలమైంది. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get blossomValidServerUrl =>
      'దయచేసి చెల్లుబాటు అయ్యే సర్వర్ URLని నమోదు చేయండి (ఉదా., https://blossom.band)';

  @override
  String get blossomSettingsSaved => 'Blossom సెట్టింగ్‌లు సేవ్ చేయబడ్డాయి';

  @override
  String get blossomSaveTooltip => 'సేవ్ చేయండి';

  @override
  String get blossomAboutTitle => 'Blossom గురించి';

  @override
  String get blossomAboutDescription =>
      'Blossom అనేది వికేంద్రీకృత మీడియా నిల్వ ప్రోటోకాల్, ఇది ఏదైనా అనుకూలమైన సర్వర్‌కి వీడియోలను అప్‌లోడ్ చేయడానికి మిమ్మల్ని అనుమతిస్తుంది. డిఫాల్ట్‌గా, వీడియోలు Divine యొక్క Blossom సర్వర్‌కి అప్‌లోడ్ చేయబడతాయి. బదులుగా అనుకూల సర్వర్‌ని ఉపయోగించడానికి దిగువ ఎంపికను ప్రారంభించండి.';

  @override
  String get blossomUseCustomServer => 'కస్టమ్ Blossom సర్వర్ ఉపయోగించండి';

  @override
  String get blossomCustomServerEnabledSubtitle =>
      'వీడియోలు మీ అనుకూల Blossom సర్వర్‌కి అప్‌లోడ్ చేయబడతాయి';

  @override
  String get blossomCustomServerDisabledSubtitle =>
      'మీ వీడియోలు ప్రస్తుతం Divine యొక్క Blossom సర్వర్‌కి అప్‌లోడ్ చేయబడుతున్నాయి';

  @override
  String get blossomCustomServerUrl => 'కస్టమ్ Blossom సర్వర్ URL';

  @override
  String get blossomCustomServerHelper =>
      'మీ అనుకూల Blossom సర్వర్ యొక్క URLని నమోదు చేయండి';

  @override
  String get blossomPopularServers => 'జనాదరణ పొందిన Blossom సర్వర్లు';

  @override
  String get blossomServerUrlMustUseHttps =>
      'Blossom సర్వర్ URL తప్పనిసరిగా https://ని ఉపయోగించాలి';

  @override
  String get blueskyFailedToUpdateCrosspost =>
      'క్రాస్‌పోస్ట్ సెట్టింగ్‌ని నవీకరించడంలో విఫలమైంది';

  @override
  String get blueskySignInRequired =>
      'Bluesky సెట్టింగ్‌లను నిర్వహించడానికి సైన్ ఇన్ చేయండి';

  @override
  String get blueskyPublishVideos => 'వీడియోలను Blueskyకి ప్రచురించండి';

  @override
  String get blueskyEnabledSubtitle => 'మీ వీడియోలు Blueskyకి ప్రచురించబడతాయి';

  @override
  String get blueskyDisabledSubtitle => 'మీ వీడియోలు Blueskyకి ప్రచురించబడవు';

  @override
  String get blueskyBackfillDisclosureTitle =>
      'మీ గత వీడియోలు కూడా పోస్ట్ చేయబడతాయి';

  @override
  String get blueskyBackfillDisclosureSubtitle =>
      'మీరు దీన్ని ఆన్ చేసినప్పుడు, Divine మీ పాత వీడియోలను Blueskyకి పంపడం ప్రారంభిస్తుంది.';

  @override
  String get blueskyHandle => 'Bluesky హ్యాండిల్';

  @override
  String get blueskyDid => 'Bluesky DID';

  @override
  String get blueskyStatus => 'స్థితి';

  @override
  String get blueskyStatusReady => 'ఖాతా అందించబడింది మరియు సిద్ధంగా ఉంది';

  @override
  String get blueskyStatusPending => 'ఖాతా ప్రొవిజనింగ్ ప్రోగ్రెస్‌లో ఉంది...';

  @override
  String get blueskyStatusFailed => 'ఖాతా కేటాయింపు విఫలమైంది';

  @override
  String get blueskyStatusDisabled => 'ఖాతా నిలిపివేయబడింది';

  @override
  String get blueskyStatusNotLinked => 'సంఖ్య Bluesky ఖాతా లింక్ చేయబడింది';

  @override
  String get blueskyUsernameRequired =>
      'Blueskyకి ప్రచురించే ముందు divine.వీడియో హ్యాండిల్‌ని సెటప్ చేయండి';

  @override
  String get blueskyUsernameRequiredSubtitle =>
      'Bluesky ప్రచురణకు క్లెయిమ్ చేయబడిన వినియోగదారు పేరు అవసరం.divine.వీడియో హ్యాండిల్.';

  @override
  String get blueskyUsernameSyncPending =>
      'మీ Divine హ్యాండిల్ క్లెయిమ్ చేయబడింది. మేము దీన్ని Blueskyకి లింక్ చేస్తున్నాము - క్షణంలో మళ్లీ ప్రయత్నించండి.';

  @override
  String get blueskyStatusUnavailableRetry =>
      'మేము మీ Divine హ్యాండిల్‌ని తనిఖీ చేయలేకపోయాము. మళ్లీ ప్రయత్నించండి.';

  @override
  String get blueskySetUpHandle => 'సెటప్';

  @override
  String get blueskyTemporarilyUnavailable =>
      'Bluesky ప్రచురణ తాత్కాలికంగా అందుబాటులో లేదు. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get invitesTitle => 'స్నేహితులను ఆహ్వానించండి';

  @override
  String invitesGenerateCardTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countఆహ్వానాలు రూపొందించడానికి సిద్ధంగా ఉన్నాయి',
      one: '1 ఆహ్వానం రూపొందించడానికి సిద్ధంగా ఉంది',
    );
    return '$_temp0';
  }

  @override
  String get invitesGenerateCardSubtitle =>
      'మీరు ఒక కోడ్‌ను భాగస్వామ్యం చేయడానికి సిద్ధంగా ఉన్నప్పుడు దాన్ని రూపొందించండి.';

  @override
  String get invitesGenerateButtonLabel => 'ఆహ్వానాన్ని రూపొందించండి';

  @override
  String get invitesNoneAvailable => 'ప్రస్తుతం ఆహ్వానాలు ఏవీ అందుబాటులో లేవు';

  @override
  String get invitesShareWithPeople =>
      'మీకు తెలిసిన వ్యక్తులతో Divineని భాగస్వామ్యం చేయండి';

  @override
  String get invitesUsedInvites => 'ఉపయోగించిన ఆహ్వానాలు';

  @override
  String invitesShareMessage(String code) {
    return 'Divineలో నాతో చేరండి! ఆహ్వాన కోడ్‌ని ఉపయోగించండి $codeప్రారంభించడానికి:\nhttps://divine.video/invite/$code';
  }

  @override
  String get invitesCopyInvite => 'ఆహ్వానాన్ని కాపీ చేయండి';

  @override
  String get invitesCopied => 'ఆహ్వానం కాపీ చేయబడింది!';

  @override
  String get invitesShareInvite => 'ఆహ్వానాన్ని భాగస్వామ్యం చేయండి';

  @override
  String get invitesShareSubject => 'Divineలో నాతో చేరండి';

  @override
  String get invitesClaimed => 'క్లెయిమ్ చేయబడింది';

  @override
  String get invitesCouldNotLoad => 'ఆహ్వానాలను లోడ్ చేయడం సాధ్యపడలేదు';

  @override
  String get invitesRetry => 'మళ్లీ ప్రయత్నించండి';

  @override
  String get searchSomethingWentWrong => 'ఏదో తప్పు జరిగింది';

  @override
  String get searchTryAgain => 'మళ్లీ ప్రయత్నించండి';

  @override
  String get searchForLists => 'జాబితాల కోసం శోధించండి';

  @override
  String get searchFindCuratedVideoLists =>
      'క్యూరేటెడ్ వీడియో జాబితాలను కనుగొనండి';

  @override
  String get searchEnterQuery => 'శోధన ప్రశ్నను నమోదు చేయండి';

  @override
  String get searchDiscoverSomethingInteresting =>
      'ఆసక్తికరమైనదాన్ని కనుగొనండి';

  @override
  String get searchPeopleSectionHeader => 'వ్యక్తులు';

  @override
  String get searchPeopleLoadingLabel => 'వ్యక్తుల ఫలితాలను లోడ్ చేస్తోంది';

  @override
  String get searchTagsSectionHeader => 'ట్యాగ్‌లు';

  @override
  String get searchTagsLoadingLabel => 'ట్యాగ్ ఫలితాలు లోడ్ అవుతోంది';

  @override
  String get searchVideosSectionHeader => 'వీడియోలు';

  @override
  String get searchVideosLoadingLabel => 'వీడియో ఫలితాలు లోడ్ అవుతోంది';

  @override
  String get searchVideosSortOptionsLabel =>
      'వీడియో ఫలితాలను క్రమబద్ధీకరించండి';

  @override
  String get searchVideosSortTrending => 'హాట్';

  @override
  String get searchVideosSortLoops => 'చాలా లూప్‌లు';

  @override
  String get searchVideosSortEngagement => 'అత్యంత నిశ్చితార్థం';

  @override
  String get searchVideosSortRecent => 'ఇటీవలిది';

  @override
  String get searchListsSectionHeader => 'జాబితాలు';

  @override
  String get searchListsLoadingLabel => 'జాబితా ఫలితాలు లోడ్ అవుతోంది';

  @override
  String get cameraAgeRestriction =>
      'కంటెంట్‌ని సృష్టించడానికి మీకు 16 లేదా అంతకంటే ఎక్కువ వయస్సు ఉండాలి';

  @override
  String get keyImportInsecureBunkerRelay =>
      'Bunker రిలే తప్పనిసరిగా wss://ని ఉపయోగించాలి (ws:// లోకల్ హోస్ట్ కోసం మాత్రమే అనుమతించబడుతుంది)';

  @override
  String get timeNow => 'ఇప్పుడు';

  @override
  String timeShortMinutes(int count) {
    return '$countమీ';
  }

  @override
  String timeShortHours(int count) {
    return '${count}h';
  }

  @override
  String timeShortDays(int count) {
    return '$countడి';
  }

  @override
  String timeShortWeeks(int count) {
    return '${count}w';
  }

  @override
  String timeShortMonths(int count) {
    return '$countమో';
  }

  @override
  String timeShortYears(int count) {
    return '$countవై';
  }

  @override
  String get timeVerboseNow => 'ఇప్పుడు';

  @override
  String timeAgo(String time) {
    return '$timeక్రితం';
  }

  @override
  String get timeToday => 'ఈరోజు';

  @override
  String get timeYesterday => 'నిన్న';

  @override
  String get timeJustNow => 'ఇప్పుడే';

  @override
  String timeMinutesAgo(int count) {
    return '$countమీ క్రితం';
  }

  @override
  String timeHoursAgo(int count) {
    return '${count}h క్రితం';
  }

  @override
  String timeDaysAgo(int count) {
    return '${count}d క్రితం';
  }

  @override
  String get draftTimeJustNow => 'ఇప్పుడే';

  @override
  String get contentLabelNudity => 'నగ్నత్వం';

  @override
  String get contentLabelSexualContent => 'లైంగిక కంటెంట్';

  @override
  String get contentLabelPornography => 'అశ్లీలత';

  @override
  String get contentLabelGraphicMedia => 'గ్రాఫిక్ మీడియా';

  @override
  String get contentLabelViolence => 'హింస';

  @override
  String get contentLabelSelfHarm => 'స్వీయ-హాని/ఆత్మహత్య';

  @override
  String get contentLabelDrugUse => 'డ్రగ్ వాడకం';

  @override
  String get contentLabelAlcohol => 'మద్యం';

  @override
  String get contentLabelTobacco => 'పొగాకు/ధూమపానం';

  @override
  String get contentLabelGambling => 'జూదం';

  @override
  String get contentLabelProfanity => 'అసభ్యత';

  @override
  String get contentLabelHateSpeech => 'ద్వేషపూరిత ప్రసంగం';

  @override
  String get contentLabelHarassment => 'వేధింపు';

  @override
  String get contentLabelFlashingLights => 'ఫ్లాషింగ్ లైట్లు';

  @override
  String get contentLabelAiGenerated => 'AI-జనరేటెడ్';

  @override
  String get contentLabelDeepfake => 'డీప్‌ఫేక్';

  @override
  String get contentLabelSpam => 'స్పామ్';

  @override
  String get contentLabelScam => 'స్కామ్/మోసం';

  @override
  String get contentLabelSpoiler => 'స్పాయిలర్';

  @override
  String get contentLabelMisleading => 'తప్పుదారి పట్టించేది';

  @override
  String get contentLabelSensitiveContent => 'సున్నితమైన కంటెంట్';

  @override
  String notificationLikedYourVideo(String actorName) {
    return '$actorNameమీ వీడియోను ఇష్టపడ్డారు';
  }

  @override
  String notificationLikedYourComment(String actorName) {
    return '$actorNameమీ వ్యాఖ్యను ఇష్టపడ్డారు';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return '$actorNameమీ వీడియోపై వ్యాఖ్యానించారు';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return '$actorNameమిమ్మల్ని అనుసరించడం ప్రారంభించారు';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return '$actorNameమిమ్మల్ని పేర్కొన్నారు';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return '$actorNameమీ వీడియోను మళ్లీ పోస్ట్ చేసారు';
  }

  @override
  String notificationPostedNewVine(String actorName) {
    return '$actorNameకొత్త vineని పోస్ట్ చేసారు';
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
      other: '$count',
      one: 'మీ vine\nమీ తీగల్లో ',
    );
    return '$actorNameజోడించబడింది $_temp0వరకు $listName';
  }

  @override
  String notificationRepliedToYourComment(String actorName) {
    return '$actorNameమీ వ్యాఖ్యకు ప్రత్యుత్తరం ఇచ్చారు';
  }

  @override
  String get notificationAndConnector => 'మరియు';

  @override
  String notificationOthersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countఇతరులు',
      one: '1 ఇతర',
    );
    return '$_temp0';
  }

  @override
  String get notificationSystemUpdate => 'మీకు కొత్త అప్‌డేట్ ఉంది';

  @override
  String get commentReplyToPrefix => 'Re:';

  @override
  String get commentHideKeyboard => 'కీబోర్డ్‌ను దాచండి';

  @override
  String get commentsErrorLoadFailed => 'వ్యాఖ్యలను లోడ్ చేయడంలో విఫలమైంది';

  @override
  String get commentsErrorNotAuthenticatedComment =>
      'దయచేసి వ్యాఖ్యానించడానికి సైన్ ఇన్ చేయండి';

  @override
  String get commentsErrorPostCommentFailed =>
      'వ్యాఖ్యను పోస్ట్ చేయడంలో విఫలమైంది';

  @override
  String get commentsErrorPostReplyFailed =>
      'ప్రత్యుత్తరాన్ని పోస్ట్ చేయడంలో విఫలమైంది';

  @override
  String get commentsErrorEditFailed => 'వ్యాఖ్యను సవరించడంలో విఫలమైంది';

  @override
  String get commentsErrorNotAuthenticatedInteract =>
      'పరస్పర చర్య చేయడానికి దయచేసి సైన్ ఇన్ చేయండి';

  @override
  String get commentsErrorVoteFailed => 'వ్యాఖ్యపై ఓటు వేయడం విఫలమైంది';

  @override
  String get commentsErrorReportFailed => 'వ్యాఖ్యను నివేదించడంలో విఫలమైంది';

  @override
  String get commentsErrorBlockFailed => 'వినియోగదారుని నిరోధించడంలో విఫలమైంది';

  @override
  String get commentsErrorDeleteFailed => 'వ్యాఖ్యను తొలగించడంలో విఫలమైంది';

  @override
  String commentsHeaderCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countవ్యాఖ్యలు',
      one: '$countవ్యాఖ్య',
    );
    return '$_temp0';
  }

  @override
  String get commentsVideoReplyPending => 'పోస్టింగ్…';

  @override
  String get commentsVideoReplyPendingSemanticLabel =>
      'మీ వీడియో ప్రత్యుత్తరం పోస్ట్ చేయబడుతోంది';

  @override
  String get commentsSortNew => 'కొత్తది';

  @override
  String get commentsSortTop => 'టాప్';

  @override
  String get commentsSortOld => 'పాతది';

  @override
  String get commentsSortSemanticLabel => 'వ్యాఖ్యల క్రమబద్ధీకరణ';

  @override
  String get commentReply => 'ప్రత్యుత్తరం ఇవ్వండి';

  @override
  String get commentReplySemanticLabel => 'వ్యాఖ్యకు ప్రత్యుత్తరం ఇవ్వండి';

  @override
  String get commentUpvoteLabel => 'వ్యాఖ్యను అనుకూల ఓటు వేయండి';

  @override
  String get commentRemoveUpvoteLabel => 'అప్‌వోట్‌ను తీసివేయండి';

  @override
  String get commentDownvoteLabel => 'వ్యాఖ్యను డౌన్‌వోట్ చేయండి';

  @override
  String get commentRemoveDownvoteLabel => 'డౌన్‌వోట్‌ను తీసివేయండి';

  @override
  String get commentsInputHint => 'వ్యాఖ్యను జోడించండి...';

  @override
  String get commentsInputHintEdit => 'వ్యాఖ్యను సవరించండి...';

  @override
  String get commentsEmptyTitle => 'ఇంకా వ్యాఖ్యలు లేవు';

  @override
  String get commentsEmptySubtitle => 'పార్టీని ప్రారంభించండి!';

  @override
  String get draftUntitled => 'శీర్షిక లేదు';

  @override
  String get contentWarningNone => 'ఏదీ లేదు';

  @override
  String get textBackgroundNone => 'ఏదీ లేదు';

  @override
  String get textBackgroundSolid => 'ఘన';

  @override
  String get textBackgroundHighlight => 'హైలైట్';

  @override
  String get textBackgroundTransparent => 'పారదర్శకం';

  @override
  String get textAlignLeft => 'ఎడమ';

  @override
  String get textAlignRight => 'కుడి';

  @override
  String get textAlignCenter => 'కేంద్రం';

  @override
  String get cameraPermissionWebUnsupportedTitle =>
      'కెమెరాకు వెబ్‌లో ఇంకా మద్దతు లేదు';

  @override
  String get cameraPermissionWebUnsupportedDescription =>
      'వెబ్ వెర్షన్‌లో కెమెరా క్యాప్చర్ మరియు రికార్డింగ్ ఇంకా అందుబాటులో లేవు.';

  @override
  String get cameraPermissionBackToFeed => 'ఫీడ్‌కి తిరిగి వెళ్ళు';

  @override
  String get cameraCouldNotStart => 'కెమెరాను ప్రారంభించడం సాధ్యపడలేదు';

  @override
  String get cameraUnsupportedPlatform =>
      'ఈ ప్లాట్‌ఫారమ్‌లో కెమెరా ఇంకా అందుబాటులో లేదు.\nమీరు ఇప్పటికీ వీడియోలను బ్రౌజ్ చేయవచ్చు మరియు చూడవచ్చు.';

  @override
  String get cameraPermissionErrorTitle => 'అనుమతి లోపం';

  @override
  String get cameraPermissionErrorDescription =>
      'అనుమతులను తనిఖీ చేస్తున్నప్పుడు ఏదో తప్పు జరిగింది.';

  @override
  String get cameraPermissionRetry => 'మళ్లీ ప్రయత్నించండి';

  @override
  String get cameraPermissionAllowAccessTitle =>
      'కెమెరా & మైక్రోఫోన్ యాక్సెస్‌ను అనుమతించండి';

  @override
  String get cameraPermissionAllowAccessDescription =>
      'ఇది యాప్‌లోనే వీడియోలను క్యాప్చర్ చేయడానికి మరియు సవరించడానికి మిమ్మల్ని అనుమతిస్తుంది, మరేమీ లేదు.';

  @override
  String get cameraPermissionGoToSettings => 'సెట్టింగ్‌లకు వెళ్లండి';

  @override
  String get videoRecorderWhySixSecondsTitle => 'ఆరు సెకన్లు ఎందుకు?';

  @override
  String get videoRecorderWhySixSecondsSubtitle =>
      'త్వరిత క్లిప్‌లు ఆకస్మికతను కలిగి ఉంటాయి. 6-సెకన్ల ఫార్మాట్ మీకు ప్రామాణికమైన క్షణాలు జరిగినప్పుడు వాటిని క్యాప్చర్ చేయడంలో సహాయపడుతుంది.';

  @override
  String get videoRecorderWhySixSecondsButton => 'అర్థమైంది!';

  @override
  String get videoRecorderUploadTitle => 'ఎందుకు అప్‌లోడ్ చేయలేదు?';

  @override
  String get videoRecorderUploadBody =>
      'Divineలో మీరు చూసేది మానవ నిర్మితమైనది: ముడి మరియు క్షణంలో సంగ్రహించబడింది. అత్యధికంగా ఉత్పత్తి చేయబడిన లేదా AI-సృష్టించిన అప్‌లోడ్‌లను అనుమతించే ప్లాట్‌ఫారమ్‌ల వలె కాకుండా, మేము కెమెరా-ప్రత్యక్ష అనుభవం యొక్క ప్రామాణికతకు ప్రాధాన్యతనిస్తాము.';

  @override
  String get videoRecorderUploadBodyDetail =>
      'యాప్‌లో సృష్టిని ఉంచడం ద్వారా, కంటెంట్ నిజమైనదని మరియు సవరించబడలేదని మేము మెరుగ్గా హామీ ఇవ్వగలము. మేము ఈ సమయంలో బాహ్య గ్యాలరీ అప్‌లోడ్‌లను తెరవడం లేదు, ఆ వాస్తవికతను రక్షించడానికి మరియు మా కమ్యూనిటీని మనకు వీలైనంత వరకు సింథటిక్ కంటెంట్ లేకుండా ఉంచడానికి.';

  @override
  String get videoRecorderUploadBodyCta =>
      'వాస్తవమైనదాన్ని రోల్ చేయడానికి క్యాప్చర్ లేదా క్లాసిక్‌కి మారండి.';

  @override
  String get videoRecorderUploadLearnMore =>
      'ధృవీకరణ ఎలా పని చేస్తుందో తెలుసుకోండి';

  @override
  String get videoRecorderAutosaveFoundTitle =>
      'మేము పని పురోగతిలో ఉన్నట్లు గుర్తించాము';

  @override
  String get videoRecorderAutosaveFoundSubtitle =>
      'మీరు ఎక్కడ ఆపారో అక్కడ కొనసాగించాలనుకుంటున్నారా?';

  @override
  String get videoRecorderAutosaveContinueButton => 'అవును, కొనసాగించండి';

  @override
  String get videoRecorderAutosaveDiscardButton =>
      'లేదు, కొత్త వీడియోని ప్రారంభించండి';

  @override
  String get videoRecorderAutosaveRestoreFailure =>
      'మీ చిత్తుప్రతిని పునరుద్ధరించడం సాధ్యపడలేదు';

  @override
  String get videoRecorderStopRecordingTooltip => 'రికార్డింగ్‌ను ఆపివేయండి';

  @override
  String get videoRecorderStartRecordingTooltip => 'రికార్డింగ్ ప్రారంభించండి';

  @override
  String get videoRecorderRecordingTapToStopLabel =>
      'రికార్డింగ్. ఆపడానికి ఎక్కడైనా నొక్కండి';

  @override
  String get videoRecorderTapToStartLabel =>
      'రికార్డింగ్ ప్రారంభించడానికి ఎక్కడైనా నొక్కండి';

  @override
  String get videoRecorderDeleteLastClipLabel => 'చివరి క్లిప్‌ను తొలగించండి';

  @override
  String get videoRecorderSwitchCameraLabel => 'కెమెరాను మార్చండి';

  @override
  String videoRecorderZoomLevelLabel(String zoom) {
    return 'దీనికి జూమ్ చేయండి $zoom×';
  }

  @override
  String get videoRecorderToggleGridLabel => 'టోగుల్ గ్రిడ్';

  @override
  String get videoRecorderToggleGhostFrameLabel =>
      'గోస్ట్ ఫ్రేమ్‌ని టోగుల్ చేయండి';

  @override
  String get videoRecorderGhostFrameEnabled => 'ఘోస్ట్ ఫ్రేమ్ ప్రారంభించబడింది';

  @override
  String get videoRecorderGhostFrameDisabled => 'ఘోస్ట్ ఫ్రేమ్ నిలిపివేయబడింది';

  @override
  String get videoRecorderClipDeletedMessage => 'క్లిప్ ట్రాష్‌కి తరలించబడింది';

  @override
  String get videoRecorderClipUndoLabel => 'అన్డు';

  @override
  String get libraryTrashEmptyTitle => 'ట్రాష్ ఖాళీగా ఉంది';

  @override
  String get libraryTrashEmptySubtitle =>
      'తొలగించబడిన క్లిప్‌లు మంచి కోసం తీసివేయబడటానికి ముందు 30 రోజుల పాటు ఇక్కడ ప్రత్యక్షంగా ఉంటాయి.';

  @override
  String get libraryTrashRestoreLabel => 'పునరుద్ధరించు';

  @override
  String get libraryTrashDeleteNowLabel => 'ఇప్పుడే తొలగించండి';

  @override
  String get libraryTrashEmptyAllLabel => 'ట్రాష్‌ను ఖాళీ చేయండి';

  @override
  String get libraryTrashDeleteConfirmTitle => 'క్లిప్‌ని ఇప్పుడే తొలగించాలా?';

  @override
  String get libraryTrashDeleteConfirmMessage =>
      'ఇది వెంటనే ట్రాష్ నుండి క్లిప్‌ను తీసివేస్తుంది.';

  @override
  String get libraryTrashEmptyConfirmTitle => 'చెత్తను ఖాళీ చేయాలా?';

  @override
  String libraryTrashEmptyConfirmMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countక్లిప్‌లు\nవెంటనే ట్రాష్ నుండి ',
      one: '1 క్లిప్',
    );
    return 'ఇది శాశ్వతంగా తొలగిస్తుంది$_temp0.';
  }

  @override
  String get videoRecorderCloseLabel => 'వీడియో రికార్డర్‌ను మూసివేయండి';

  @override
  String get videoRecorderContinueToEditorLabel => 'వీడియో ఎడిటర్‌కి కొనసాగండి';

  @override
  String get videoRecorderCameraPreviewLabel => 'కెమెరా ప్రివ్యూ';

  @override
  String get videoRecorderCameraPreviewFocusHint => 'ఫోకస్ కెమెరా';

  @override
  String videoRecorderSwitchToModeLabel(String mode) {
    return 'కి మారండి $modeమోడ్';
  }

  @override
  String get videoRecorderLipSyncAddAudioFirst =>
      'రికార్డింగ్ చేయడానికి ముందు ఆడియోను జోడించండి';

  @override
  String get videoRecorderStopMotionAssembleFailed =>
      'వీడియోని సృష్టించడం సాధ్యపడలేదు. మళ్లీ ప్రయత్నించండి.';

  @override
  String videoRecorderStopMotionShotsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countషాట్లు మిగిలి ఉన్నాయి',
      one: '1 షాట్ మిగిలి ఉంది',
      zero: 'షాట్‌లు లేవు',
    );
    return '$_temp0';
  }

  @override
  String get videoRecorderToggleFlashLabel => 'ఫ్లాష్‌ని టోగుల్ చేయండి';

  @override
  String get videoRecorderCycleTimerLabel => 'సైకిల్ టైమర్';

  @override
  String get videoRecorderToggleAspectRatioLabel =>
      'కారక నిష్పత్తిని టోగుల్ చేయండి';

  @override
  String get videoRecorderStabilizationLabel => 'స్థిరీకరణ';

  @override
  String get videoRecorderStabilizationModeOff => 'ఆఫ్';

  @override
  String get videoRecorderStabilizationModeStandard => 'ప్రమాణం';

  @override
  String get videoRecorderStabilizationModeCinematic => 'సినిమాటిక్';

  @override
  String get videoRecorderStabilizationModeCinematicExtended =>
      'సినిమాటిక్ విస్తరించబడింది';

  @override
  String get videoRecorderStabilizationModePreviewOptimized =>
      'ప్రివ్యూ ఆప్టిమైజ్ చేయబడింది';

  @override
  String get videoRecorderStabilizationModeLowLatency => 'తక్కువ జాప్యం';

  @override
  String get videoRecorderStabilizationModeAuto => 'ఆటో';

  @override
  String get videoRecorderFlashValueOff => 'ఆఫ్';

  @override
  String get videoRecorderFlashValueOn => 'ఆన్';

  @override
  String get videoRecorderFlashValueAuto => 'ఆటో';

  @override
  String get videoRecorderTimerValueOff => 'ఆఫ్';

  @override
  String get videoRecorderTimerValueThreeSeconds => '3 సెకన్లు';

  @override
  String get videoRecorderTimerValueTenSeconds => '10 సెకన్లు';

  @override
  String get videoRecorderAspectRatioValueSquare => 'స్క్వేర్';

  @override
  String get videoRecorderAspectRatioValueVertical => 'నిలువు';

  @override
  String get videoRecorderCameraValueFront => 'ఫ్రంట్ కెమెరా';

  @override
  String get videoRecorderCameraValueBack => 'వెనుక కెమెరా';

  @override
  String get videoRecorderLibraryEmptyLabel => 'క్లిప్ లైబ్రరీ, క్లిప్‌లు లేవు';

  @override
  String videoRecorderLibraryOpenLabel(int clipCount) {
    String _temp0 = intl.Intl.pluralLogic(
      clipCount,
      locale: localeName,
      other: 'క్లిప్ లైబ్రరీని తెరవండి, $clipCountక్లిప్‌లు',
      one: 'క్లిప్ లైబ్రరీని తెరవండి, 1 క్లిప్',
    );
    return '$_temp0';
  }

  @override
  String videoRecorderLibraryOpenStopMotionLabel(int frameCount) {
    String _temp0 = intl.Intl.pluralLogic(
      frameCount,
      locale: localeName,
      other: 'స్టాప్-మోషన్ లైబ్రరీని తెరవండి, $frameCountఫ్రేమ్‌లు',
      one: 'స్టాప్-మోషన్ లైబ్రరీని తెరవండి, 1 ఫ్రేమ్',
      zero: 'స్టాప్-మోషన్ లైబ్రరీని తెరవండి',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorCameraLabel => 'కెమెరా';

  @override
  String get videoEditorOpenCameraSemanticLabel => 'కెమెరా తెరవండి';

  @override
  String get videoEditorLibraryLabel => 'లైబ్రరీ';

  @override
  String get videoEditorTextLabel => 'వచనం';

  @override
  String get videoEditorDrawLabel => 'డ్రా';

  @override
  String get videoEditorFilterLabel => 'ఫిల్టర్';

  @override
  String get videoEditorTuneLabel => 'సర్దుబాటు';

  @override
  String get videoEditorOpenTuneSemanticLabel => 'సర్దుబాట్ల ఎడిటర్‌ను తెరవండి';

  @override
  String get videoEditorTuneBrightness => 'ప్రకాశం';

  @override
  String get videoEditorTuneContrast => 'కాంట్రాస్ట్';

  @override
  String get videoEditorTuneSaturation => 'సంతృప్తత';

  @override
  String get videoEditorTuneExposure => 'ఎక్స్పోజర్';

  @override
  String get videoEditorTuneHue => 'రంగు';

  @override
  String get videoEditorTuneTemperature => 'ఉష్ణోగ్రత';

  @override
  String get videoEditorTuneTint => 'టింట్';

  @override
  String get videoEditorTuneFade => 'ఫేడ్';

  @override
  String get videoEditorAudioLabel => 'ఆడియో';

  @override
  String get videoEditorAddTitle => 'జోడించండి';

  @override
  String get videoEditorOpenLibrarySemanticLabel => 'లైబ్రరీని తెరవండి';

  @override
  String get videoEditorOpenAudioSemanticLabel => 'ఆడియో ఎడిటర్‌ను తెరవండి';

  @override
  String get videoEditorCaptionsLabel => 'శీర్షికలు';

  @override
  String get videoEditorOpenCaptionsSemanticLabel =>
      'శీర్షికల ఎడిటర్‌ను తెరవండి';

  @override
  String get videoEditorCaptionsBurnInLabel => 'వీడియోలోకి బర్న్ చేయండి';

  @override
  String get videoEditorCaptionsPresetCustom => 'కస్టమ్';

  @override
  String get videoEditorCaptionsCustomStyleTitle => 'అనుకూల శైలి';

  @override
  String get videoEditorCaptionsCustomApply => 'వర్తించు';

  @override
  String get videoEditorCaptionsCustomFont => 'ఫాంట్';

  @override
  String get videoEditorCaptionsCustomTextColor => 'వచన రంగు';

  @override
  String get videoEditorCaptionsCustomBackground => 'నేపథ్యం';

  @override
  String get videoEditorCaptionsCustomBackgroundColor => 'నేపథ్య రంగు';

  @override
  String get videoEditorCaptionsCustomAnimation => 'యానిమేషన్';

  @override
  String get videoEditorCaptionsAnimationNone => 'ఏదీ లేదు';

  @override
  String get videoEditorCaptionsAnimationFade => 'ఫేడ్';

  @override
  String get videoEditorCaptionsAnimationPop => 'పాప్';

  @override
  String get videoEditorCaptionsAnimationSpring => 'వసంతకాలం';

  @override
  String get videoEditorCaptionsEditTitle => 'శీర్షికలు';

  @override
  String get videoEditorCaptionsGeneratingTitle => 'ప్రసంగం వింటోంది…';

  @override
  String get videoEditorCaptionsGeneratingSubtitle =>
      'మీ ఆడియోను శీర్షిక సూచనలుగా మారుస్తోంది.';

  @override
  String get videoEditorCaptionsNoSpeechMessage =>
      'మేము ఏ ప్రసంగాన్ని వినలేకపోయాము. మీరు ఇప్పటికీ మీరే శీర్షికలను వ్రాయవచ్చు.';

  @override
  String get videoEditorCaptionsUnavailableMessage =>
      'ఈ పరికరంలో ప్రసంగ గుర్తింపు అందుబాటులో లేదు. మీరు మీరే శీర్షికలు వ్రాయవచ్చు.';

  @override
  String get videoEditorCaptionsNotAuthorizedMessage =>
      'ప్రసంగ గుర్తింపు అనుమతించబడదు. దీన్ని సెట్టింగ్‌లలో ప్రారంభించండి లేదా మీరే శీర్షికలను వ్రాయండి.';

  @override
  String get videoEditorCaptionsFailedMessage =>
      'లిప్యంతరీకరణ ఈసారి పని చేయలేదు. మీరు మీరే శీర్షికలు వ్రాయవచ్చు.';

  @override
  String get videoEditorCaptionsStartEmptyButton =>
      'క్యాప్షన్‌లను నేనే వ్రాయండి';

  @override
  String get videoEditorCaptionsAddCue => 'శీర్షికను జోడించండి';

  @override
  String get videoEditorCaptionsCueTextHint => 'శీర్షిక వచనం';

  @override
  String get videoEditorCaptionsCueDeleteSemanticLabel =>
      'శీర్షికను తొలగించండి';

  @override
  String get videoEditorCaptionsDeleteTrack => 'అన్ని శీర్షికలను తీసివేయండి';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmTitle =>
      'శీర్షికలను తీసివేయాలా?';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmSubtitle =>
      'మొత్తం క్యాప్షన్ టెక్స్ట్ మరియు టైమింగ్ పోతాయి.';

  @override
  String get videoEditorCaptionsCloseSemanticLabel =>
      'శీర్షికల ఎడిటర్‌ను మూసివేయండి';

  @override
  String get videoEditorCaptionsDoneSemanticLabel => 'శీర్షికలను నిర్ధారించండి';

  @override
  String get videoEditorCaptionsPresetTitle => 'శీర్షిక శైలి';

  @override
  String get videoEditorCaptionsPresetClassic => 'క్లాసిక్';

  @override
  String get videoEditorCaptionsPresetPop => 'పాప్';

  @override
  String get videoEditorCaptionsPresetZoom => 'జూమ్';

  @override
  String get videoEditorCaptionsPresetSpring => 'వసంతకాలం';

  @override
  String get videoEditorCaptionsPresetMono => 'మోనో';

  @override
  String get videoEditorCaptionsPresetHeadline => 'హెడ్‌లైన్';

  @override
  String get videoEditorCaptionsPresetTypewriter => 'టైప్‌రైటర్';

  @override
  String get videoEditorCaptionsPresetMarker => 'మార్కర్';

  @override
  String get videoEditorCaptionsPresetScript => 'స్క్రిప్ట్';

  @override
  String get videoEditorCaptionsPresetRetro => 'రెట్రో';

  @override
  String get videoEditorCaptionsPresetElegant => 'సొగసైన';

  @override
  String get videoEditorCaptionsPresetBubble => 'బబుల్';

  @override
  String get videoEditorCaptionsPresetNeon => 'నియాన్';

  @override
  String get videoEditorCaptionsPresetBold => 'బోల్డ్';

  @override
  String get videoEditorCaptionsPresetDreamy => 'కలలు కనే';

  @override
  String get videoEditorCaptionsPresetOcean => 'మహాసముద్రం';

  @override
  String get videoEditorCaptionsPresetSunny => 'సన్నీ';

  @override
  String get videoEditorCaptionsPresetHandwritten => 'చేతిరాత';

  @override
  String get videoEditorCaptionsPresetSerif => 'సెరిఫ్';

  @override
  String get videoEditorCaptionsPresetStamp => 'స్టాంప్';

  @override
  String get videoEditorOpenTextSemanticLabel => 'టెక్స్ట్ ఎడిటర్‌ను తెరవండి';

  @override
  String get videoEditorOpenDrawSemanticLabel => 'డ్రా ఎడిటర్‌ను తెరవండి';

  @override
  String get videoEditorOpenFilterSemanticLabel => 'ఫిల్టర్ ఎడిటర్‌ను తెరవండి';

  @override
  String get videoEditorOpenStickerSemanticLabel =>
      'స్టిక్కర్ ఎడిటర్‌ను తెరవండి';

  @override
  String get videoEditorSaveDraftTitle => 'మీ చిత్తుప్రతిని సేవ్ చేయాలా?';

  @override
  String get videoEditorSaveDraftSubtitle =>
      'మీ సవరణలను తర్వాత కోసం ఉంచండి లేదా వాటిని విస్మరించి, ఎడిటర్‌ను వదిలివేయండి.';

  @override
  String get videoEditorSaveDraftButton => 'డ్రాఫ్ట్‌ను సేవ్ చేయండి';

  @override
  String get videoEditorDiscardChangesButton => 'మార్పులను విస్మరించండి';

  @override
  String get videoEditorKeepEditingButton => 'ఎడిటింగ్ చేస్తూ ఉండండి';

  @override
  String get videoEditorDeleteLayerDropZone =>
      'లేయర్ డ్రాప్ జోన్‌ను తొలగించండి';

  @override
  String get videoEditorReleaseToDeleteLayer =>
      'లేయర్‌ని తొలగించడానికి విడుదల చేయండి';

  @override
  String get videoEditorDoneLabel => 'పూర్తయింది';

  @override
  String get videoEditorPlayPauseSemanticLabel =>
      'వీడియోని ప్లే చేయండి లేదా పాజ్ చేయండి';

  @override
  String videoEditorSplitPositionInvalid(int minDurationMs) {
    return 'స్ప్లిట్ స్థానం చెల్లదు. రెండు క్లిప్‌లు కనీసం ఉండాలి ${minDurationMs}ms పొడవు.';
  }

  @override
  String get videoEditorSaveSelectedClip => 'ఎంచుకున్న క్లిప్‌ను సేవ్ చేయండి';

  @override
  String get videoEditorSaveClip => 'క్లిప్‌ను సేవ్ చేయండి';

  @override
  String get videoEditorClipSavedSuccess => 'క్లిప్ లైబ్రరీకి సేవ్ చేయబడింది';

  @override
  String get videoEditorClipSaveFailed => 'క్లిప్‌ను సేవ్ చేయడంలో విఫలమైంది';

  @override
  String get videoEditorColorPickerSemanticLabel => 'కలర్ పికర్';

  @override
  String get videoEditorUndoSemanticLabel => 'అన్డు';

  @override
  String get videoEditorRedoSemanticLabel => 'పునరావృతం';

  @override
  String get videoEditorTextColorSemanticLabel => 'వచన రంగు';

  @override
  String get videoEditorTextAlignmentSemanticLabel => 'వచన అమరిక';

  @override
  String get videoEditorTextBackgroundSemanticLabel => 'వచన నేపథ్యం';

  @override
  String get videoEditorFontSemanticLabel => 'ఫాంట్';

  @override
  String get videoEditorNoStickersFound => 'స్టిక్కర్‌లు ఏవీ కనుగొనబడలేదు';

  @override
  String get videoEditorNoStickersAvailable => 'స్టిక్కర్‌లు అందుబాటులో లేవు';

  @override
  String get videoEditorFailedLoadStickers =>
      'స్టిక్కర్‌లను లోడ్ చేయడంలో విఫలమైంది';

  @override
  String get videoEditorVoiceOverLabel => 'వాయిస్ ఓవర్';

  @override
  String videoEditorVoiceOverTakeName(int number) {
    return 'రికార్డింగ్ $number';
  }

  @override
  String get videoEditorOpenVoiceOverSemanticLabel =>
      'వాయిస్ ఓవర్‌ను రికార్డ్ చేయండి';

  @override
  String get videoEditorVoiceOverRecordSemanticLabel =>
      'రికార్డింగ్ ప్రారంభించండి';

  @override
  String get videoEditorVoiceOverStopSemanticLabel =>
      'రికార్డింగ్‌ను ఆపివేయండి';

  @override
  String get videoEditorVoiceOverHint =>
      'రికార్డ్ చేయడానికి నొక్కండి. మీకు నచ్చినన్ని టేక్‌లను జోడించండి.';

  @override
  String videoEditorVoiceOverRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countరికార్డింగ్‌లు',
      one: '1 రికార్డింగ్',
      zero: 'ఇంకా రికార్డింగ్‌లు లేవు',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorVoiceOverDeleteLast =>
      'చివరి రికార్డింగ్‌ను తొలగించండి';

  @override
  String get videoEditorVoiceOverPermissionTitle => 'మైక్రోఫోన్ యాక్సెస్ అవసరం';

  @override
  String get videoEditorVoiceOverPermissionBody =>
      'వాయిస్ ఓవర్ రికార్డ్ చేయడానికి మైక్రోఫోన్ యాక్సెస్‌ని అనుమతించండి.';

  @override
  String get videoEditorVoiceOverOpenSettings => 'సెట్టింగ్‌లను తెరవండి';

  @override
  String get videoEditorVoiceOverRecordingStarted => 'రికార్డింగ్ ప్రారంభమైంది';

  @override
  String get videoEditorVoiceOverRecordingSaved => 'రికార్డింగ్ సేవ్ చేయబడింది';

  @override
  String get videoEditorVoiceOverTooLong =>
      'రికార్డింగ్ మీ వీడియో కంటే పొడవుగా ఉంది';

  @override
  String get videoEditorPlaySemanticLabel => 'ప్లే';

  @override
  String get videoEditorPauseSemanticLabel => 'పాజ్';

  @override
  String get videoEditorVolumeSemanticLabel => 'వాల్యూమ్‌ని సర్దుబాటు చేయండి';

  @override
  String videoEditorTimelineVolumePreview(int percent) {
    return 'వాల్యూమ్ $percent%';
  }

  @override
  String get videoEditorTimelineSlideToAdjust =>
      'సర్దుబాటు చేయడానికి స్లయిడ్ చేయండి';

  @override
  String get videoEditorChromaKeyLabel => 'గ్రీన్ స్క్రీన్';

  @override
  String get videoEditorChromaKeyTitle => 'గ్రీన్ స్క్రీన్';

  @override
  String get videoEditorChromaKeySemanticLabel =>
      'ఈ క్లిప్ కోసం గ్రీన్ స్క్రీన్‌ను సెటప్ చేయండి';

  @override
  String get videoEditorChromaKeyCloseSemanticLabel =>
      'గ్రీన్ స్క్రీన్ మార్పులను విస్మరించండి';

  @override
  String get videoEditorChromaKeyDoneSemanticLabel =>
      'ఆకుపచ్చ స్క్రీన్‌ను వర్తింపజేయండి';

  @override
  String get videoEditorChromaKeyAutoDetect => 'ఆటో-డిటెక్ట్';

  @override
  String get videoEditorChromaKeyPresetGreen => 'ఆకుపచ్చ';

  @override
  String get videoEditorChromaKeyPresetBlue => 'నీలం';

  @override
  String get videoEditorChromaKeyScreenColorLabel => 'స్క్రీన్ రంగు';

  @override
  String get videoEditorChromaKeyAmountLabel => 'మొత్తం';

  @override
  String get videoEditorChromaKeyAmountHint =>
      'స్క్రీన్ రంగులో ఎంత భాగం అదృశ్యమవుతుంది';

  @override
  String get videoEditorChromaKeyEdgeLabel => 'ఎడ్జ్';

  @override
  String get videoEditorChromaKeyEdgeHint =>
      'కటౌట్‌ను మృదువుగా చేస్తుంది కాబట్టి జుట్టు బెల్లం రంగులోకి మారదు';

  @override
  String get videoEditorChromaKeySpillLabel => 'స్పిల్';

  @override
  String get videoEditorChromaKeySpillHint =>
      'స్క్రీన్ రంగును మీ విషయం నుండి వెనక్కి లాగుతుంది';

  @override
  String get videoEditorChromaKeyBackgroundLabel => 'దీనితో భర్తీ చేయండి';

  @override
  String get videoEditorChromaKeyBackgroundNone => 'ఏమీ లేదు';

  @override
  String get videoEditorChromaKeyBackgroundColor => 'రంగు';

  @override
  String get videoEditorChromaKeyBackgroundImage => 'చిత్రం';

  @override
  String get videoEditorChromaKeyBackgroundVideo => 'క్లిప్';

  @override
  String get videoEditorChromaKeyTransparentHint =>
      'వీడియో పారదర్శకతను కలిగి ఉండదు, కనుక ఇది నలుపు రంగులో ఎగుమతి అవుతుంది.';

  @override
  String get videoEditorChromaKeyDetectFailed =>
      'స్క్రీన్‌ని కనుగొనడం సాధ్యపడలేదు. ఇది ఫ్రేమ్ అంచులను చేరుకోవాలి - బదులుగా చేతితో రంగును ఎంచుకోండి.';

  @override
  String get videoEditorChromaKeyPickClipTitle => 'క్లిప్‌ను ఎంచుకోండి';

  @override
  String get videoEditorChromaKeyNoLibraryClips =>
      'మీ లైబ్రరీ ఖాళీగా ఉంది. ముందుగా క్లిప్‌ను సేవ్ చేసి, ఆపై దాన్ని నేపథ్యంగా ఉపయోగించండి.';

  @override
  String get videoEditorChromaKeyImagePickFailed =>
      'ఆ చిత్రాన్ని లోడ్ చేయడం సాధ్యపడలేదు.';

  @override
  String get videoEditorChromaKeyRemove => 'ఆకుపచ్చ స్క్రీన్‌ను తీసివేయండి';

  @override
  String get videoEditorChromaKeyFailed =>
      'ఆకుపచ్చ స్క్రీన్‌ని వర్తింపజేయడం సాధ్యపడలేదు. మీ క్లిప్ మారలేదు.';

  @override
  String get videoEditorChromaKeyRemoveFailed =>
      'ఆకుపచ్చ స్క్రీన్‌ని తీసివేయడం సాధ్యపడలేదు. మీ క్లిప్ మారలేదు.';

  @override
  String get videoEditorChromaKeyApplying =>
      'గ్రీన్ స్క్రీన్‌ని వర్తింపజేస్తోంది…';

  @override
  String get videoEditorChromaKeyPreviewUnavailable =>
      'ఈ పరికరం ప్రత్యక్ష పరిదృశ్యాన్ని చూపలేదు. మీరు ఎగుమతి చేసినప్పుడు మీ సెట్టింగ్‌లు ఇప్పటికీ వర్తిస్తాయి.';

  @override
  String videoEditorClipVolumeLabel(int index) {
    return 'క్లిప్ $index';
  }

  @override
  String get videoEditorDeleteLabel => 'తొలగించు';

  @override
  String get videoEditorDeleteSelectedItemSemanticLabel =>
      'ఎంచుకున్న అంశాన్ని తొలగించండి\nప్రతి చిత్రానికి ';

  @override
  String get videoEditorStopMotionFramesPerImageLabel => 'ఫ్రేమ్‌లు';

  @override
  String videoEditorStopMotionFramesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countఫ్రేమ్‌లు',
      one: '1 ఫ్రేమ్',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorStopMotionFramesPerImageButtonLabel =>
      'ఫ్రేమ్‌లు\nప్రతి చిత్రానికి ';

  @override
  String videoEditorStopMotionFramesPerImageValueSemanticLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countఫ్రేమ్‌లు',
      one: '$countఫ్రేమ్\nప్రతి చిత్రానికి ',
    );
    return '$_temp0';
  }

  @override
  String videoEditorStopMotionFrameSemanticLabel(int position, int total) {
    return 'స్టాప్-మోషన్ ఫ్రేమ్ \nయొక్క $position$total';
  }

  @override
  String get videoEditorEditLabel => 'సవరించండి';

  @override
  String get videoEditorEditSelectedItemSemanticLabel =>
      'ఎంచుకున్న అంశాన్ని సవరించండి';

  @override
  String get videoEditorDuplicateLabel => 'నకిలీ';

  @override
  String get videoEditorDuplicateSelectedItemSemanticLabel =>
      'ఎంచుకున్న అంశం నకిలీ';

  @override
  String get videoEditorCombineLabel => 'కలపండి';

  @override
  String get videoEditorCombineDrawLayersSemanticLabel =>
      'ఎంచుకున్న డ్రాయింగ్‌లను ఒక లేయర్‌గా కలపండి';

  @override
  String get videoEditorSplitLabel => 'స్ప్లిట్';

  @override
  String get videoEditorSplitSelectedClipSemanticLabel =>
      'ఎంచుకున్న క్లిప్‌ని విభజించండి';

  @override
  String get videoEditorExtractAudioLabel => 'ఆడియోను సంగ్రహించండి';

  @override
  String get videoEditorClipAudioTitle => 'క్లిప్ ఆడియో';

  @override
  String get videoEditorExtractAudioFromClipSemanticLabel =>
      'క్లిప్ నుండి ఆడియోను సంగ్రహించి అసలైన దాన్ని మ్యూట్ చేయండి';

  @override
  String get videoEditorExtractAudioNoLocalFile =>
      'ఆడియోను సంగ్రహించడం సాధ్యం కాదు: క్లిప్ స్థానికంగా అందుబాటులో లేదు.';

  @override
  String get videoEditorExtractAudioFailed =>
      'ఆడియోను సంగ్రహించడం సాధ్యపడలేదు. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get videoEditorSpeedLabel => 'వేగం';

  @override
  String get videoEditorSetClipSpeedSemanticLabel =>
      'ఎంచుకున్న క్లిప్ కోసం ప్లేబ్యాక్ వేగాన్ని సెట్ చేయండి';

  @override
  String get videoEditorReverseLabel => 'రివర్స్';

  @override
  String get videoEditorReverseClipSemanticLabel =>
      'ఎంచుకున్న క్లిప్ కోసం రివర్స్ ప్లేబ్యాక్‌ని టోగుల్ చేయండి';

  @override
  String get videoEditorReverseProgressLabel =>
      'ఒక్క క్షణం, మేము మీ క్లిప్‌ను రివర్స్ చేస్తున్నాము';

  @override
  String get videoEditorTransformLabel => 'రూపాంతరం';

  @override
  String get videoEditorTransformSelectedClipSemanticLabel =>
      'ఎంచుకున్న క్లిప్‌ను కత్తిరించండి, తిప్పండి లేదా తిప్పండి';

  @override
  String get videoEditorTransformProgressLabel =>
      'ఒక్క క్షణం, మేము మీ క్లిప్‌ని మారుస్తున్నాము';

  @override
  String get videoEditorTransformFailed =>
      'క్లిప్‌ని మార్చడం సాధ్యపడలేదు. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get videoEditorTransformNoLocalFile =>
      'రూపాంతరం చెందదు: క్లిప్ స్థానికంగా అందుబాటులో లేదు.';

  @override
  String get videoEditorTransformSelectedFrameSemanticLabel =>
      'ఎంచుకున్న ఫ్రేమ్‌ను కత్తిరించండి, తిప్పండి లేదా తిప్పండి';

  @override
  String get videoEditorTransformFrameProgressLabel =>
      'ఒక్క క్షణం, మేము మీ ఫ్రేమ్‌ని మారుస్తున్నాము';

  @override
  String get videoEditorTransformFrameFailed =>
      'ఫ్రేమ్‌ని మార్చడం సాధ్యపడలేదు. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get videoEditorTransformRotateLabel => 'తిప్పండి';

  @override
  String get videoEditorTransformFlipLabel => 'ఫ్లిప్';

  @override
  String get videoEditorTransformResetLabel => 'రీసెట్';

  @override
  String get videoEditorTransformApplySemanticLabel =>
      'రూపాంతరాన్ని వర్తింపజేయండి';

  @override
  String get videoEditorTransformCancelSemanticLabel =>
      'రూపాంతరాన్ని రద్దు చేయండి';

  @override
  String get videoEditorTransformPlayLabel => 'ప్లే';

  @override
  String get videoEditorTransformPauseLabel => 'పాజ్';

  @override
  String get videoEditorReverseNoLocalFile =>
      'రివర్స్ చేయలేరు: క్లిప్ స్థానికంగా అందుబాటులో లేదు.';

  @override
  String get videoEditorReverseFailed =>
      'క్లిప్‌ను రివర్స్ చేయడం సాధ్యపడలేదు. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get videoEditorSpeedSheetTitle => 'క్లిప్ స్పీడ్';

  @override
  String get videoEditorTransitionSheetTitle => 'పరివర్తన';

  @override
  String get videoEditorTransitionNone => 'ఏదీ లేదు';

  @override
  String get videoEditorTransitionDissolve => 'రద్దు';

  @override
  String get videoEditorTransitionFadeToBlack => 'నలుపు రంగులోకి మారండి';

  @override
  String get videoEditorTransitionFadeToWhite => 'తెల్లగా మారండి';

  @override
  String get videoEditorTransitionSlide => 'స్లయిడ్';

  @override
  String get videoEditorTransitionPush => 'పుష్';

  @override
  String get videoEditorTransitionWipe => 'తుడవడం';

  @override
  String get videoEditorTransitionButtonSemanticLabel => 'పరివర్తనను సవరించండి';

  @override
  String get videoEditorLoopTransitionSheetTitle => 'లూప్ ట్రాన్సిషన్';

  @override
  String get videoEditorLoopTransitionButtonSemanticLabel =>
      'లూప్ పరివర్తనను సవరించండి';

  @override
  String get videoEditorTransitionDuration => 'వ్యవధి';

  @override
  String get videoEditorTransitionDurationLimitedHint =>
      'పొరుగు పరివర్తన అతివ్యాప్తి చెందకుండా ఉండటానికి సంక్షిప్తీకరించబడింది.';

  @override
  String get videoEditorTransitionCurve => 'కర్వ్';

  @override
  String get videoEditorTransitionDirection => 'దిశ';

  @override
  String get videoEditorTransitionDirectionLeft => 'ఎడమ';

  @override
  String get videoEditorTransitionDirectionRight => 'కుడి';

  @override
  String get videoEditorTransitionDirectionUp => 'పైకి';

  @override
  String get videoEditorTransitionDirectionDown => 'డౌన్';

  @override
  String videoEditorTransitionCurveOptionSemanticLabel(int number) {
    return 'ఈజింగ్ కర్వ్ $number';
  }

  @override
  String get videoEditorLayerAnimationLabel => 'యానిమేషన్';

  @override
  String get videoEditorLayerAnimationButtonSemanticLabel =>
      'లేయర్ యానిమేషన్‌ను సవరించండి';

  @override
  String get videoEditorLayerAnimationEnter => 'నమోదు చేయండి';

  @override
  String get videoEditorLayerAnimationLeave => 'వదిలివేయండి';

  @override
  String get videoEditorLayerAnimationFade => 'ఫేడ్';

  @override
  String get videoEditorLayerAnimationScale => 'స్కేల్';

  @override
  String get videoEditorLayerAnimationScaleFrom => 'స్కేల్ నుండి';

  @override
  String get videoEditorFinishTimelineEditingSemanticLabel =>
      'టైమ్‌లైన్ సవరణను ముగించండి';

  @override
  String get videoEditorAudioPlayPreviewSemanticLabel =>
      'ప్రివ్యూని ప్లే చేయండి';

  @override
  String get videoEditorAudioPausePreviewSemanticLabel =>
      'ప్రివ్యూను పాజ్ చేయండి';

  @override
  String get videoEditorAudioUntitledSound => 'శీర్షికలేని ధ్వని';

  @override
  String get videoEditorAudioUntitled => 'శీర్షిక లేదు';

  @override
  String get videoEditorAudioAddAudio => 'ఆడియోని జోడించండి';

  @override
  String get videoEditorAudioNoSoundsAvailableTitle =>
      'శబ్దాలు అందుబాటులో లేవు\nసృష్టికర్తలు ఆడియోను షేర్ చేసినప్పుడు ';

  @override
  String get videoEditorAudioNoSoundsAvailableSubtitle =>
      'సౌండ్‌లు ఇక్కడ కనిపిస్తాయి';

  @override
  String get videoEditorAudioFailedToLoadTitle =>
      'శబ్దాలను లోడ్ చేయడంలో విఫలమైంది';

  @override
  String get videoEditorAudioSegmentInstruction =>
      'మీ వీడియో కోసం ఆడియో విభాగాన్ని ఎంచుకోండి';

  @override
  String get videoEditorAudioCategoryDivine => 'Divine';

  @override
  String get videoEditorAudioCategoryCommunity => 'సంఘం';

  @override
  String get videoEditorAudioCategoryFeatured => 'ఫీచర్ చేయబడింది';

  @override
  String get videoEditorAudioCategoryMySounds => 'నా సౌండ్స్';

  @override
  String get videoEditorDrawToolArrowSemanticLabel => 'బాణం సాధనం';

  @override
  String get videoEditorDrawToolEraserSemanticLabel => 'ఎరేజర్ సాధనం';

  @override
  String get videoEditorDrawToolMarkerSemanticLabel => 'మార్కర్ సాధనం';

  @override
  String get videoEditorDrawToolPencilSemanticLabel => 'పెన్సిల్ సాధనం';

  @override
  String get videoEditorShowTimelineSemanticLabel => 'కాలక్రమాన్ని చూపు';

  @override
  String get videoEditorHideTimelineSemanticLabel => 'కాలక్రమాన్ని దాచండి';

  @override
  String get videoEditorFeedPreviewContent =>
      'ఈ ప్రాంతాల వెనుక కంటెంట్‌ను ఉంచడం మానుకోండి.';

  @override
  String get videoEditorStickersDivineOriginals => 'Divine ఒరిజినల్‌లు';

  @override
  String get videoEditorStickerSearchHint => 'స్టిక్కర్‌లను శోధించండి...';

  @override
  String get videoEditorSelectFontSemanticLabel => 'ఫాంట్‌ని ఎంచుకోండి';

  @override
  String get videoEditorFontUnknown => 'తెలియదు';

  @override
  String get videoEditorSplitPlayheadOutsideClip =>
      'ప్లేహెడ్ విభజించడానికి ఎంచుకున్న క్లిప్‌లో ఉండాలి.';

  @override
  String get videoEditorTimelineTrimStartSemanticLabel => 'ట్రిమ్ ప్రారంభం';

  @override
  String get videoEditorTimelineTrimEndSemanticLabel => 'ట్రిమ్ ముగింపు';

  @override
  String get videoEditorTimelineTrimClipSemanticLabel =>
      'క్లిప్‌ను కత్తిరించండి';

  @override
  String get videoEditorTimelineTrimClipHint =>
      'క్లిప్ వ్యవధిని సర్దుబాటు చేయడానికి హ్యాండిల్‌లను లాగండి';

  @override
  String videoEditorTimelineDraggingClipSemanticLabel(int index) {
    return 'డ్రాగింగ్ క్లిప్ $index';
  }

  @override
  String videoEditorTimelineClipSemanticLabel(
    int index,
    int total,
    String duration,
  ) {
    return 'క్లిప్ $indexయొక్క $total, $durationసెకన్లు';
  }

  @override
  String get videoEditorTimelineClipReorderHint =>
      'మళ్లీ ఆర్డర్ చేయడానికి ఎక్కువసేపు నొక్కండి';

  @override
  String get videoEditorTimelineClipMoveLeft => 'ఎడమవైపుకు తరలించండి';

  @override
  String get videoEditorTimelineClipMoveRight => 'కుడివైపుకు తరలించండి';

  @override
  String videoEditorTimelineClipSelectedSemanticLabel(int index, int total) {
    return 'క్లిప్ \nయొక్క $index$total, ఎంచుకోబడింది';
  }

  @override
  String videoEditorTimelineClipUnselectedSemanticLabel(int index, int total) {
    return 'క్లిప్ \nయొక్క $index$total, ఎంచుకోబడలేదు';
  }

  @override
  String get videoEditorMultiSelectLabel => 'ఎంచుకోండి';

  @override
  String get videoEditorMultiSelectSemanticLabel => 'బహుళ క్లిప్‌లను ఎంచుకోండి';

  @override
  String get videoEditorMultiSelectDoneSemanticLabel =>
      'క్లిప్‌లను ఎంచుకోవడం పూర్తయింది';

  @override
  String videoEditorMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countక్లిప్‌లు ఎంచుకోబడ్డాయి',
      one: '1 క్లిప్ ఎంచుకోబడింది',
      zero: 'క్లిప్‌లు ఏవీ ఎంచుకోబడలేదు',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorLayerMultiSelectSemanticLabel =>
      'బహుళ డ్రాయింగ్‌లను ఎంచుకోండి';

  @override
  String get videoEditorLayerMultiSelectDoneSemanticLabel =>
      'డ్రాయింగ్‌లను ఎంచుకోవడం పూర్తయింది';

  @override
  String get videoEditorDeleteSelectedDrawingsSemanticLabel =>
      'ఎంచుకున్న డ్రాయింగ్‌లను తొలగించండి';

  @override
  String videoEditorLayerMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countడ్రాయింగ్‌లు ఎంచుకోబడ్డాయి',
      one: '1 డ్రాయింగ్ ఎంచుకోబడింది',
      zero: 'డ్రాయింగ్‌లు ఏవీ ఎంచుకోబడలేదు',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorMergeLabel => 'విలీనం';

  @override
  String get videoEditorMergeSelectedClipsSemanticLabel =>
      'ఎంచుకున్న క్లిప్‌లను విలీనం చేయండి';

  @override
  String get videoEditorDeleteSelectedClipsSemanticLabel =>
      'ఎంచుకున్న క్లిప్‌లను తొలగించండి';

  @override
  String get videoEditorDeleteSelectedFramesSemanticLabel =>
      'ఎంచుకున్న ఫ్రేమ్‌లను తొలగించండి';

  @override
  String get videoEditorReverseSelectedFramesSemanticLabel =>
      'ఎంచుకున్న ఫ్రేమ్‌లను రివర్స్ చేయండి';

  @override
  String get videoEditorDuplicateSelectedFramesSemanticLabel =>
      'ఎంచుకున్న ఫ్రేమ్‌లను నకిలీ చేయండి';

  @override
  String videoEditorStopMotionTooShortSnackbar(int seconds) {
    return 'మీ వీడియోకి కనీసం అవసరం ${seconds}s — మరికొన్ని ఫ్రేమ్‌లను క్యాప్చర్ చేయండి.';
  }

  @override
  String get videoEditorMergeProgressLabel =>
      'ఒక్క క్షణం, మేము మీ క్లిప్‌లను విలీనం చేస్తున్నాము';

  @override
  String get videoEditorMergeFailed =>
      'క్లిప్‌లను విలీనం చేయడం సాధ్యపడలేదు. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get videoEditorTimelineLongPressToDragHint =>
      'లాగడానికి ఎక్కువసేపు నొక్కండి';

  @override
  String get videoEditorVideoTimelineSemanticLabel => 'వీడియో టైమ్‌లైన్';

  @override
  String videoEditorTimelinePositionFormat(int minutes, String seconds) {
    return '$minutesమీ $secondsసె';
  }

  @override
  String videoEditorColorSelectedSemanticLabel(String colorName) {
    return '$colorName, ఎంచుకోబడింది';
  }

  @override
  String get videoEditorCloseColorPickerSemanticLabel =>
      'రంగు ఎంపికను మూసివేయండి';

  @override
  String get videoEditorPickColorTitle => 'రంగును ఎంచుకోండి';

  @override
  String get videoEditorConfirmColorSemanticLabel => 'రంగును నిర్ధారించండి';

  @override
  String get videoEditorSaturationBrightnessSemanticLabel =>
      'సంతృప్తత మరియు ప్రకాశం';

  @override
  String videoEditorSaturationBrightnessValue(int saturation, int brightness) {
    return 'సంతృప్తత $saturation%, ప్రకాశం $brightness%';
  }

  @override
  String get videoEditorHueSemanticLabel => 'రంగు';

  @override
  String get videoEditorAddElementSemanticLabel => 'మూలకాన్ని జోడించండి';

  @override
  String get videoEditorDoneSemanticLabel => 'పూర్తయింది';

  @override
  String get videoEditorLevelSemanticLabel => 'స్థాయి';

  @override
  String get videoMetadataClosePostDetailsSemanticLabel =>
      'పోస్ట్ వివరాలను మూసివేయండి';

  @override
  String get videoMetadataDismissHelpDialogSemanticLabel =>
      'సహాయ డైలాగ్‌ను తీసివేయండి';

  @override
  String get videoMetadataGotItButton => 'అర్థమైంది!';

  @override
  String get videoMetadataLimitReachedWarning =>
      '64KB పరిమితిని చేరుకున్నారు. కొనసాగించడానికి కొంత కంటెంట్‌ని తీసివేయండి.';

  @override
  String get videoMetadataExpirationLabel => 'గడువు';

  @override
  String get videoMetadataSelectExpirationSemanticLabel =>
      'గడువు ముగింపు సమయాన్ని ఎంచుకోండి';

  @override
  String get videoMetadataTitleLabel => 'శీర్షిక';

  @override
  String get videoMetadataDescriptionLabel => 'వివరణ';

  @override
  String get videoMetadataTagsLabel => 'ట్యాగ్‌లు';

  @override
  String videoMetadataDeleteTagHint(String tag) {
    return 'ట్యాగ్‌ని తొలగించండి $tag';
  }

  @override
  String get videoMetadataContentWarningLabel => 'కంటెంట్ హెచ్చరికను జోడించండి';

  @override
  String get videoMetadataSelectContentWarningsSemanticLabel =>
      'కంటెంట్ హెచ్చరికలను ఎంచుకోండి';

  @override
  String get videoMetadataContentWarningSelectAllThatApply =>
      'వర్తించే అన్నింటినీ ఎంచుకోండి';

  @override
  String get videoMetadataAudioReuseSubtitle =>
      'ఇతరులను ఈ వీడియో ఆడియోను సేవ్ చేసి, మళ్లీ ఉపయోగించనివ్వండి.';

  @override
  String get publishAudioReuseDegradedWarning =>
      'మీ వీడియో ముగిసింది, కానీ ధ్వని ప్రచురించబడలేదు. భాగస్వామ్యం చేయడానికి వీడియోను సవరించండి.';

  @override
  String get videoMetadataCollaboratorsLabel => 'సహకారులను జోడించండి';

  @override
  String get videoMetadataAddCollaboratorSemanticLabel =>
      'సహకారిని ఆహ్వానించండి';

  @override
  String get videoMetadataMutualFollowersSearchText => 'పరస్పర అనుచరులు';

  @override
  String get videoMetadataInspiredByLabel => 'ప్రేరణతో జోడించండి';

  @override
  String get videoMetadataSetInspiredBySemanticLabel =>
      'ప్రేరణతో సెట్ చేయబడింది';

  @override
  String get videoMetadataCreatorCannotBeReferencedSnackbar =>
      'ఈ సృష్టికర్తను సూచించడం సాధ్యం కాదు.';

  @override
  String get videoMetadataPostDetailsTitle => 'పోస్ట్ వివరాలు';

  @override
  String get videoMetadataSavedToLibrarySnackbar => 'లైబ్రరీకి సేవ్ చేయబడింది';

  @override
  String get videoMetadataFailedToSaveSnackbar => 'సేవ్ చేయడంలో విఫలమైంది';

  @override
  String get videoMetadataGoToLibraryButton => 'లైబ్రరీకి వెళ్లండి';

  @override
  String get videoMetadataSaveForLaterSemanticLabel =>
      'తర్వాత బటన్ కోసం సేవ్ చేయండి';

  @override
  String get videoMetadataSavingVideoHint => 'వీడియోను సేవ్ చేస్తోంది...';

  @override
  String videoMetadataSaveToDraftsHint(String destination) {
    return 'వీడియోని డ్రాఫ్ట్‌లకు సేవ్ చేయండి మరియు $destination';
  }

  @override
  String videoMetadataSaveToDraftsWithoutGalleryHint(String destination) {
    return 'వీడియోని డ్రాఫ్ట్‌లకు సేవ్ చేయండి. ఇంకా రెండర్ చేయబడిన వీడియో లేదు, కాబట్టి దీనికి కాపీ జోడించబడలేదు $destination.';
  }

  @override
  String get videoMetadataSaveForLaterButton => 'తర్వాత కోసం సేవ్ చేయండి';

  @override
  String get videoMetadataPostSemanticLabel => 'పోస్ట్ బటన్';

  @override
  String get videoMetadataPublishVideoHint => 'ఫీడ్ కోసం వీడియోను ప్రచురించండి';

  @override
  String get videoMetadataShareReplyToFeedTitle =>
      'నా ఫీడ్‌కి కూడా భాగస్వామ్యం చేయండి';

  @override
  String get videoMetadataShareReplyToFeedSubtitle =>
      'ఆఫ్ ఈ వీడియోను వ్యాఖ్య థ్రెడ్‌లో మాత్రమే ఉంచుతుంది.';

  @override
  String get videoMetadataFormNotReadyHint =>
      'ఎనేబుల్ చేయడానికి ఫారమ్‌ను పూరించండి';

  @override
  String get videoMetadataPostButton => 'పోస్ట్';

  @override
  String get videoMetadataOpenPreviewSemanticLabel =>
      'పోస్ట్ ప్రివ్యూ స్క్రీన్‌ను తెరవండి';

  @override
  String get videoMetadataShareTitle => 'భాగస్వామ్యం చేయండి';

  @override
  String get videoMetadataVideoDetailsSubtitle => 'వీడియో వివరాలు';

  @override
  String get videoMetadataClassicDoneButton => 'పూర్తయింది';

  @override
  String get videoMetadataPlayPreviewSemanticLabel => 'ప్రివ్యూని ప్లే చేయండి';

  @override
  String get videoMetadataPausePreviewSemanticLabel => 'ప్రివ్యూను పాజ్ చేయండి';

  @override
  String get videoMetadataClosePreviewSemanticLabel =>
      'వీడియో ప్రివ్యూను మూసివేయండి';

  @override
  String get videoMetadataRemoveSemanticLabel => 'తీసివేయి';

  @override
  String get fullscreenFeedRemovedMessage => 'వీడియో తీసివేయబడింది';

  @override
  String get fullscreenFeedEmptyMessage => 'ఇక్కడ ఆడటానికి ఏదీ లేదు';

  @override
  String get settingsBadgesTitle => 'బ్యాడ్జ్‌లు';

  @override
  String get settingsBadgesSubtitle =>
      'అవార్డులను అంగీకరించండి మరియు జారీ చేయబడిన బ్యాడ్జ్ స్థితిని తనిఖీ చేయండి.';

  @override
  String get badgesTitle => 'బ్యాడ్జ్‌లు';

  @override
  String get badgesLoadError => 'బ్యాడ్జ్‌లను లోడ్ చేయడం సాధ్యపడలేదు';

  @override
  String get badgesUpdateError => 'బ్యాడ్జ్‌ని అప్‌డేట్ చేయడం సాధ్యపడలేదు';

  @override
  String get badgesAwardedEmptyTitle => 'ఇంకా బ్యాడ్జ్ అవార్డులు లేవు';

  @override
  String get badgesAwardedEmptySubtitle =>
      'ఎవరైనా మీకు Nostr బ్యాడ్జ్‌ని ప్రదానం చేసినప్పుడు, అది ఇక్కడ ల్యాండ్ అవుతుంది.';

  @override
  String get badgesStatusAccepted => 'ఆమోదించబడింది';

  @override
  String get badgesStatusNotAccepted => 'ఆమోదించబడలేదు';

  @override
  String get badgesActionRemove => 'తీసివేయి';

  @override
  String get badgesActionAccept => 'అంగీకరించండి';

  @override
  String get badgesActionReject => 'తిరస్కరించండి';

  @override
  String get badgesIssuedEmptyTitle => 'ఇంకా జారీ చేయబడిన బ్యాడ్జ్‌లు లేవు';

  @override
  String get badgesIssuedEmptySubtitle =>
      'మీరు జారీ చేసే బ్యాడ్జ్‌లు ఇక్కడ అంగీకార స్థితిని చూపుతాయి.';

  @override
  String get badgesIssuedNoRecipients =>
      'ఈ అవార్డు కోసం గ్రహీతలు ఎవరూ కనుగొనబడలేదు.';

  @override
  String get badgesRecipientAcceptedStatus => 'గ్రహీత ద్వారా ఆమోదించబడింది';

  @override
  String get badgesRecipientWaitingStatus => 'గ్రహీత కోసం వేచి ఉంది';

  @override
  String badgesHiddenSectionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'దాచబడింది ($count)',
      one: 'దాచబడింది (1)',
    );
    return '$_temp0';
  }

  @override
  String get badgesActionRestore => 'పునరుద్ధరించండి';

  @override
  String get badgesHiddenSnackbar => 'బ్యాడ్జ్ దాచబడింది';

  @override
  String get badgesHiddenSnackbarUndo => 'అన్డు';

  @override
  String get badgesTabAwarded => 'ప్రదానం చేయబడింది';

  @override
  String get badgesTabCreated => 'సృష్టించబడింది';

  @override
  String get badgesTabIssued => 'జారీ చేయబడింది';

  @override
  String get badgesCreateAction => 'కొత్త బ్యాడ్జ్';

  @override
  String get badgesCreatedEmptyTitle => 'ఇంకా బ్యాడ్జ్‌లు రూపొందించబడలేదు';

  @override
  String get badgesCreatedEmptySubtitle =>
      'ఒకదాన్ని తయారు చేసి, దాన్ని సంపాదించిన వారికి అందజేయండి.';

  @override
  String badgesCreatedAwardSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'వీరికి ప్రదానం చేయబడింది $countవ్యక్తులు',
      one: '1 వ్యక్తికి అందించబడింది',
      zero: 'ఇంకా ప్రదానం చేయలేదు',
    );
    return '$_temp0';
  }

  @override
  String get badgeEditorCreateTitle => 'కొత్త బ్యాడ్జ్';

  @override
  String get badgeEditorEditTitle => 'బ్యాడ్జ్‌ని సవరించండి';

  @override
  String get badgeEditorNameLabel => 'పేరు';

  @override
  String get badgeEditorNameHint => 'సీన్ స్టీలర్';

  @override
  String get badgeEditorIdentifierLabel => 'ఐడెంటిఫైయర్';

  @override
  String get badgeEditorIdentifierHelp =>
      'బ్యాడ్జ్ చిరునామాలో భాగం, కాబట్టి బ్యాడ్జ్ ఉనికిలో ఉన్న తర్వాత అది అలాగే ఉంటుంది.';

  @override
  String get badgeEditorIdentifierTaken =>
      'మీరు ఇప్పటికే ఈ ఐడెంటిఫైయర్‌తో బ్యాడ్జ్‌ని కలిగి ఉన్నారు. బదులుగా దాన్ని సవరించండి - ఇక్కడ ప్రచురించడం దానిని భర్తీ చేస్తుంది.';

  @override
  String get badgeEditorIdentifierRequired =>
      'ప్రతి బ్యాడ్జ్‌కు ఐడెంటిఫైయర్ అవసరం — పేరు దాన్ని పూరించకపోతే ఒకటి టైప్ చేయండి.';

  @override
  String get badgeEditorDescriptionLabel => 'వివరణ';

  @override
  String get badgeEditorDescriptionHint =>
      'ఒకే లూప్‌తో స్క్రోల్‌ను దొంగిలించే వారికి.';

  @override
  String get badgeEditorArtworkLabel => 'కళాకృతి';

  @override
  String get badgeEditorArtworkAdd => 'కళాకృతిని జోడించండి';

  @override
  String get badgeEditorArtworkReplace => 'భర్తీ చేయండి';

  @override
  String get badgeEditorArtworkError =>
      'ఆ చిత్రాన్ని అప్‌లోడ్ చేయడం సాధ్యపడలేదు';

  @override
  String get badgeEditorArtworkRequired =>
      'ప్రతి బ్యాడ్జ్‌కి ఆర్ట్‌వర్క్ అవసరం.';

  @override
  String get badgeEditorArtworkRemove => 'కళాకృతిని తీసివేయండి';

  @override
  String get badgeEditorArtworkSheetTitle => 'బ్యాడ్జ్ ఆర్ట్‌వర్క్';

  @override
  String get badgeDetailDeleteAction => 'బ్యాడ్జ్‌ని తొలగించండి';

  @override
  String get badgeDetailDeleteTitle => 'ఈ బ్యాడ్జ్‌ని తొలగించాలా?';

  @override
  String get badgeDetailDeleteBody =>
      'ఇది బ్యాడ్జ్‌ను మరియు దాని కోసం మీరు అందజేసే ప్రతి అవార్డును వదలమని రిలేలను అడుగుతుంది. రిలేలు తిరస్కరించవచ్చు మరియు దానిని పిన్ చేసిన ఎవరైనా దానిని తీసివేసే వరకు వారి ప్రొఫైల్‌లో ఉంచుతారు.';

  @override
  String get badgeDetailDeleteConfirm => 'తొలగించు';

  @override
  String get badgeEditorSaveAction => 'బ్యాడ్జ్‌ని ప్రచురించండి';

  @override
  String get badgeEditorSaveError => 'బ్యాడ్జ్‌ని ప్రచురించడం సాధ్యపడలేదు';

  @override
  String get badgeEditorLoadError => 'ఈ బ్యాడ్జ్‌ని లోడ్ చేయడం సాధ్యపడలేదు';

  @override
  String get badgeDetailTitle => 'బ్యాడ్జ్';

  @override
  String get badgeDetailMadeBy => 'ద్వారా తయారు చేయబడింది';

  @override
  String get badgeDetailRecipientsTitle => 'వీరికి ప్రదానం చేయబడింది';

  @override
  String get badgeDetailNoRecipients => 'దీన్ని ఇంకా ఎవరూ కలిగి లేరు.';

  @override
  String get badgeDetailAwardAction => 'ఈ బ్యాడ్జ్‌ని ప్రదానం చేయండి';

  @override
  String get badgeDetailEditAction => 'బ్యాడ్జ్‌ని సవరించండి';

  @override
  String get badgeDetailShareAction => 'భాగస్వామ్యం చేయండి';

  @override
  String badgeDetailShareMessage(String link) {
    return 'Divineలో ఈ బ్యాడ్జ్‌ని చూడండి: $link';
  }

  @override
  String get badgeDetailRevokeAction => 'బ్యాడ్జ్‌ని వెనక్కి తీసుకోండి';

  @override
  String get badgeDetailRevokeTitle => 'ఈ బ్యాడ్జ్‌ని వెనక్కి తీసుకోవాలా?';

  @override
  String get badgeDetailRevokeBody =>
      'ఇది మీరు ఈ వ్యక్తికి ఇచ్చిన అవార్డును వదలమని రిలేలను అడుగుతుంది. రిలేలు తిరస్కరించవచ్చు మరియు వారు ఇప్పటికే బ్యాడ్జ్‌ని పిన్ చేసి ఉంటే, వారు దానిని తీసివేసే వరకు అది వారి ప్రొఫైల్‌లో ఉంటుంది. ఎలాగైనా, వారికి చెప్పలేదు.';

  @override
  String get badgeDetailRevokeSelfBody =>
      'ఇది మీకు మీరే ఇచ్చిన అవార్డును వదలమని రిలేలను అడుగుతుంది మరియు మీ ప్రొఫైల్ నుండి బ్యాడ్జ్‌ను తీసివేస్తుంది. రిలేలు తొలగింపును నిరాకరిస్తే, ఏమీ మారదు.';

  @override
  String get badgeDetailRevokeConfirm => 'దాన్ని వెనక్కి తీసుకోండి';

  @override
  String get badgeDetailRevokeSuccess => 'బ్యాడ్జ్ తిరిగి తీసుకోబడింది';

  @override
  String get badgeDetailBlockClaimantsAction =>
      'బ్యాడ్జ్ హక్కుదారులను బ్లాక్ చేయండి';

  @override
  String get badgeDetailBlockClaimantsTitle =>
      'బ్యాడ్జ్ హక్కుదారులను బ్లాక్ చేయండి';

  @override
  String get badgeDetailBlockClaimantsLoadError =>
      'ఈ బ్యాడ్జ్ కోసం హక్కుదారులను లోడ్ చేయడం సాధ్యపడలేదు';

  @override
  String get badgeDetailBlockClaimantsEmptyTitle =>
      'ప్రస్తుతం ఈ బ్యాడ్జ్‌ని ఎవరూ క్లెయిమ్ చేయలేదు';

  @override
  String get badgeDetailBlockClaimantsEmptyBody =>
      'మేము బ్లాక్ చేయడానికి ప్రస్తుత హక్కుదారులెవరూ కనుగొనలేదు.';

  @override
  String badgeDetailBlockClaimantsHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'బ్లాక్ $countహక్కుదారులు?',
      one: 'బ్లాక్ 1 హక్కుదారు?',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'ఇది బ్లాక్ చేస్తుంది $countఖాతాలు ప్రస్తుతం ఈ బ్యాడ్జ్‌ను క్లెయిమ్ చేస్తున్నాయి. వారి పోస్ట్‌లు మీ ఫీడ్‌లను వదిలివేస్తాయి మరియు వారికి తెలియజేయబడదు.',
      one:
          'ఇది ప్రస్తుతం ఈ బ్యాడ్జ్‌ను క్లెయిమ్ చేస్తున్న ఖాతాను బ్లాక్ చేస్తుంది. వారి పోస్ట్‌లు మీ ఫీడ్‌లను వదిలివేస్తాయి మరియు వారికి తెలియజేయబడదు.',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'బ్లాక్ $countఖాతాలు',
      one: '1 ఖాతాను బ్లాక్ చేయండి',
    );
    return '$_temp0';
  }

  @override
  String get badgeDetailBlockClaimantsSuccess =>
      'బ్యాడ్జ్ హక్కుదారులు బ్లాక్ చేయబడ్డారు';

  @override
  String get badgeDetailBlockClaimantsFailure =>
      'బ్యాడ్జ్ హక్కుదారులను బ్లాక్ చేయడం సాధ్యపడలేదు';

  @override
  String get badgeDetailLoadError => 'ఈ బ్యాడ్జ్‌ని లోడ్ చేయడం సాధ్యపడలేదు';

  @override
  String get badgeDetailMissing =>
      'మేము ఈ బ్యాడ్జ్‌ని ఏ రిలేలో కనుగొనలేకపోయాము.';

  @override
  String get badgeDetailActionError => 'అది జరగలేదు';

  @override
  String get badgeAwardTitle => 'అవార్డు బ్యాడ్జ్';

  @override
  String get badgeAwardPickAction => 'వ్యక్తులను ఎంచుకోండి';

  @override
  String get badgeAwardManualLabel => 'లేదా కీలను అతికించండి';

  @override
  String get badgeAwardManualHint => 'npub1…, npub1…';

  @override
  String get badgeAwardEmptyHint => 'కనీసం ఒక వ్యక్తిని ఎంచుకోండి.';

  @override
  String badgeAwardSubmitAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'అవార్డు $countవ్యక్తులు',
      one: 'అవార్డు 1 వ్యక్తికి',
      zero: 'అవార్డు బ్యాడ్జ్',
    );
    return '$_temp0';
  }

  @override
  String get profileBadgeAwardedBy => 'ద్వారా ప్రదానం చేయబడింది';

  @override
  String get profileBadgeRecipients => 'గ్రహీతలు';

  @override
  String profileBadgeMoreRecipients(int count) {
    return '+$countమరిన్ని';
  }

  @override
  String profileBadgeSemanticLabel(String name) {
    return '$nameబ్యాడ్జ్';
  }

  @override
  String get profileBadgeFallbackSemanticLabel => 'బ్యాడ్జ్';

  @override
  String get profileBadgeFooterBody =>
      'బ్యాడ్జ్‌లు Nostrలో ఎవరైనా పొందగలిగే చిన్న అవార్డులు. స్నేహితుడికి, సృష్టికర్తకు లేదా మీ రోజును సృష్టించిన వారికి ఒకదాన్ని అందించండి.';

  @override
  String get profileBadgeFooterLink => 'మీ స్వంత బ్యాడ్జ్‌ని తయారు చేసుకోండి';

  @override
  String get minorAccountReviewWelcomePageTitle => 'ఫ్యామిలీ గైడ్';

  @override
  String get minorAccountReviewWelcomeTitle => 'ఇంకా 16 కాదా? అది సరే.';

  @override
  String get minorAccountReviewWelcomeBody =>
      'మీకు వచ్చిన సమాధానాన్ని ఎంచుకునే బదులు మీరు ఈ పేజీకి క్లిక్ చేసినట్లయితే, అది ముఖ్యమైనది. ఇది మీ చుట్టూ ఉన్న వ్యక్తుల పట్ల నిజాయితీ, వెన్నెముక మరియు నిజమైన శ్రద్ధను చూపుతుంది. Divine వద్ద, కుటుంబాలు కలిసి చర్చించుకుని ఆరోగ్యకరమైన సోషల్ మీడియా వినియోగం ఎలా ఉంటుందో నిర్ణయించుకోవాలని మేము కోరుకుంటున్నాము.';

  @override
  String get minorAccountReviewModerationTitle => 'మాకు మరో అడుగు అవసరం';

  @override
  String get minorAccountReviewModerationBody =>
      'ఈ ఖాతాను నిశితంగా పరిశీలించాల్సిందిగా మేము కోరాము, ఎందుకంటే ఇది 16 ఏళ్లలోపు వారికి చెందినది కావచ్చు. ఈ విధానం తదుపరి దశలను ప్రైవేట్‌గా ఉంచుతుంది మరియు మీ వయస్సుకి సరైన మార్గాన్ని చూపుతుంది.';

  @override
  String get minorAccountReviewRulesTitle => 'నియమాలు ప్రతిచోటా ఒకేలా ఉండవు';

  @override
  String get minorAccountReviewRulesBody =>
      'వివిధ దేశాలు మరియు ప్రాంతాలు టీనేజ్ సోషల్ మీడియా వినియోగాన్ని విభిన్నంగా చూస్తాయి. అందుకే మేము కుటుంబాలు నెమ్మదించమని, వాస్తవాలను తనిఖీ చేసి, కలిసి తదుపరి దశను ఎంచుకోమని అడుగుతున్నాము.';

  @override
  String get minorAccountReviewApproachTitle =>
      'Divine దాని గురించి ఎలా ఆలోచిస్తుంది';

  @override
  String get minorAccountReviewApproachBody =>
      'ఆరోగ్యకరమైన సాంకేతిక అలవాట్లు పిల్లలపై గూఢచర్యం చేయడం లేదా తల్లిదండ్రులను హాల్ మానిటర్‌లుగా మార్చడం ద్వారా కాకుండా మెరుగైన విషయాల వైపు దృష్టిని పాజ్ చేయడం, ప్రతిబింబించడం మరియు మళ్లించడం ద్వారా వస్తాయని మేము భావిస్తున్నాము. పరిశోధన కూడా దానిని సమర్థిస్తుంది.';

  @override
  String get minorAccountReviewLearnMoreTitle => 'కుటుంబాల కోసం మరిన్ని';

  @override
  String get minorAccountReviewKidsPolicyCta => 'Divine పిల్లల పాలసీని చదవండి';

  @override
  String get minorAccountReviewChooseAgeBandTitle =>
      'సరిపోయే మార్గాన్ని ఎంచుకోండి';

  @override
  String get minorAccountReviewUnder13Cta => '13 ఏళ్లలోపు';

  @override
  String get minorAccountReviewTeenCta => 'వయస్సు 13-15';

  @override
  String get minorAccountReviewFamilyResourcesBody =>
      'యువత సోషల్ మీడియాను మరింత సురక్షితంగా ఉపయోగించడం కోసం ఆచరణాత్మక చిట్కాలు, సంభాషణ సాధనాలు మరియు వనరుల కోసం Divine ఫ్యామిలీ గైడ్‌ని సందర్శించండి.';

  @override
  String get minorAccountReviewFamilyResourcesCta =>
      'కుటుంబ గైడ్‌లు మరియు చిట్కాలను పొందండి';

  @override
  String get minorAccountReviewFooter =>
      'మీకు 16 ఏళ్లు లేదా అంతకంటే ఎక్కువ వయస్సు ఉండి, పొరపాటున ఇక్కడకు పంపబడితే, Divine మద్దతును సంప్రదించండి, తద్వారా నిజమైన వ్యక్తి దీన్ని సమీక్షించవచ్చు.';

  @override
  String get minorAccountReviewTitle => 'ఖాతా సమీక్ష';

  @override
  String get minorAccountReviewCheckingStatusTitle =>
      'ఖాతా స్థితిని తనిఖీ చేస్తోంది...';

  @override
  String get minorAccountReviewCheckingStatusBody =>
      'దయచేసి మేము ఈ ఖాతా యొక్క ప్రస్తుత సమీక్ష స్థితిని నిర్ధారించే వరకు వేచి ఉండండి.';

  @override
  String get minorAccountReviewDefaultTitle => 'ఖాతా సమీక్ష అవసరం';

  @override
  String get minorAccountReviewDefaultBody =>
      'సాధారణంగా Divineని ఉపయోగించే ముందు మేము ఈ ఖాతాను సమీక్షించాలి.';

  @override
  String minorAccountReviewCaseId(String caseId) {
    return 'కేసు ID: $caseId';
  }

  @override
  String get minorAccountReviewCaseIdShortLabel => 'కేసు ID';

  @override
  String get minorAccountReviewRestrictionsTitle =>
      'ప్రస్తుతం ఏమి పరిమితం చేయబడింది';

  @override
  String get minorAccountReviewRestrictionPosting =>
      'పోస్టింగ్ మరియు పబ్లిషింగ్ పాజ్ చేయబడ్డాయి';

  @override
  String get minorAccountReviewRestrictionEngagement =>
      'వ్యాఖ్యలు, ఇష్టాలు, రీపోస్ట్‌లు మరియు ఫాలోలు పాజ్ చేయబడ్డాయి';

  @override
  String get minorAccountReviewRestrictionMessaging =>
      'సాధారణ సందేశాలను ప్రారంభించడం లేదా వాటికి ప్రత్యుత్తరం ఇవ్వడం పాజ్ చేయబడింది';

  @override
  String get minorAccountReviewRestrictionSupport =>
      'మద్దతు మరియు మీ మోడరేషన్ సందేశం అందుబాటులో ఉన్నాయి';

  @override
  String get minorAccountReviewContentTitle => 'మీ వీడియోలకు ఏమి జరుగుతుంది';

  @override
  String get minorAccountReviewContentBody =>
      'ఈ సమీక్ష తెరిచి ఉన్నప్పుడు మీ వీడియోలు దాచబడతాయి. మీ ఖాతా క్లియర్ చేయబడితే, వారు తిరిగి వస్తారు. ప్రతిస్పందన లేకుండా సమీక్ష మూసివేయబడితే, మీ ఖాతా మూసివేయబడుతుంది మరియు మీ వీడియోలు తొలగించబడతాయి.';

  @override
  String get minorAccountReviewResponseClockRunningTitle =>
      'ప్రతిస్పందించడానికి సమయం';

  @override
  String minorAccountReviewResponseClockRunningDays(int days, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$daysరోజులు',
      one: '1 రోజు',
    );
    return '$_temp0ప్రతిస్పందించడానికి మిగిలి ఉంది. గడువు: $date.';
  }

  @override
  String minorAccountReviewResponseClockRunningHours(int hours, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hoursగంటలు\nప్రతిస్పందించడానికి ',
      one: '1 గంట',
    );
    return '$_temp0మిగిలి ఉంది. గడువు: $date.';
  }

  @override
  String get minorAccountReviewResponseClockPausedTitle =>
      'ప్రతిస్పందన గడియారం పాజ్ చేయబడింది';

  @override
  String minorAccountReviewResponseClockPausedBody(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$daysరోజులు',
      one: '1 రోజు',
    );
    return 'ప్రతిస్పందన గడియారం పాజ్ చేయబడింది. గురించి $_temp0పునఃప్రారంభించినప్పుడు అలాగే ఉంటుంది.';
  }

  @override
  String get minorAccountReviewResponseClockExpiredTitle =>
      'ప్రతిస్పందన గడువు ముగిసింది';

  @override
  String get minorAccountReviewResponseClockExpiredBody =>
      'ప్రతిస్పందన గడువు ముగిసింది. మీకు సహాయం కావాలంటే సపోర్ట్ సెంటర్‌ని సంప్రదించండి.';

  @override
  String get minorAccountReviewResponseClockUnavailableTitle =>
      'గడువు అందుబాటులో లేదు';

  @override
  String get minorAccountReviewResponseClockUnavailableBody =>
      'మేము ప్రస్తుతం మీ ప్రతిస్పందన గడువును చూపలేము. మీకు సహాయం కావాలంటే సపోర్ట్ సెంటర్‌ని సంప్రదించండి.';

  @override
  String get minorAccountReviewAppealTitle =>
      'మేము దీన్ని తప్పుగా అర్థం చేసుకున్నామని అనుకుంటున్నారా?';

  @override
  String get minorAccountReviewAppealTeenBody =>
      'మద్దతు కేంద్రాన్ని సంప్రదించండి మరియు ఏమి జరిగిందో మాకు తెలియజేయండి. మేము మరొకసారి పరిశీలిస్తాము, కానీ నిర్ణయం మారుతుందని మేము హామీ ఇవ్వలేము.';

  @override
  String get minorAccountReviewAppealUnder13Body =>
      'మీ తల్లిదండ్రులు లేదా సంరక్షకులు సపోర్ట్ సెంటర్‌ను సంప్రదించి ఏమి జరిగిందో మాకు తెలియజేయగలరు. మేము మరొకసారి పరిశీలిస్తాము, కానీ నిర్ణయం మారుతుందని మేము హామీ ఇవ్వలేము.';

  @override
  String get minorAccountReviewOpenSupportCenter =>
      'మద్దతు కేంద్రాన్ని తెరవండి';

  @override
  String get minorAccountReviewOpenModerationMessage =>
      'మోడరేషన్ సందేశాన్ని తెరవండి';

  @override
  String get minorAccountReviewOpenReviewPage => 'సమీక్ష పేజీని తెరవండి';

  @override
  String get minorAccountReviewCheckAgain => 'మళ్లీ తనిఖీ చేయండి';

  @override
  String get minorAccountReviewLogOut => 'లాగ్ అవుట్ చేయండి';

  @override
  String get minorAccountReviewNextStepTitle => 'తదుపరి దశ';

  @override
  String get minorAccountReviewNextStepBody =>
      'మీకు ఈ సమీక్షలో సహాయం కావాలంటే మద్దతు కేంద్రాన్ని లేదా మీ మోడరేషన్ సందేశాన్ని తెరవండి.';

  @override
  String get minorAccountReviewInProgressTitle => 'సమీక్ష ప్రోగ్రెస్‌లో ఉంది';

  @override
  String get minorAccountReviewInProgressBody =>
      'ప్రస్తుతం మనకు కావాల్సినవి మా వద్ద ఉన్నాయి. సాధారణ ఖాతా యాక్సెస్‌ని పునరుద్ధరించడానికి ముందు మా బృందం ఈ కేసును సమీక్షిస్తోంది.';

  @override
  String get minorAccountReviewUnder13Title => 'అండర్-13 ఖాతాలు';

  @override
  String minorAccountReviewUnder13Body(String supportEmail) {
    return 'ఈ ఖాతా 13 ఏళ్లలోపు వారిది అయితే, తల్లిదండ్రులు లేదా సంరక్షకులు తప్పనిసరిగా ఇమెయిల్ చేయాలి $supportEmailమరియు కేసు IDని చేర్చండి.';
  }

  @override
  String get minorAccountReviewUnder13PublicTitle =>
      'మేము మీకు ఇంకా ఖాతాను అందించలేము';

  @override
  String get minorAccountReviewUnder13PublicBody =>
      'Divine 13 ఏళ్లలోపు పిల్లల కోసం రూపొందించబడలేదు మరియు ప్రపంచవ్యాప్తంగా ఉన్న సోషల్ మీడియా నియమాలు మన చేతులను కట్టిపడేస్తాయి. ఇది జీవితానికి తప్పుడు పాఠం, మరియు మేము దానిని ఇక్కడ మీకు నేర్పడం లేదు.';

  @override
  String get minorAccountReviewUnder13FamilyTitle =>
      'బదులుగా మీ కుటుంబం ఏమి చేయగలదు';

  @override
  String get minorAccountReviewUnder13FamilyBody =>
      'తల్లిదండ్రులు లేదా సంరక్షకులు ఖాతాను కలిగి ఉంటారు మరియు పోస్టింగ్ చేయవచ్చు మరియు మీరు ఖచ్చితంగా వారితో వీడియోలలో ఉండవచ్చు. కుటుంబాలు వారికి సరైన విధంగా Divineని ఆస్వాదించాలని మేము కోరుకుంటున్నాము.';

  @override
  String get minorAccountReviewUnder13ComeBackTitle =>
      'మీకు 13 ఏళ్లు వచ్చినప్పుడు';

  @override
  String get minorAccountReviewUnder13ComeBackBody =>
      'మీరు నివసించే నియమాల ఆధారంగా, మీరు తిరిగి వచ్చి మీ స్వంత ఖాతా కోసం దరఖాస్తు చేసుకోవచ్చు. అలాంటప్పుడు, మీరు 13 మరియు 15 సంవత్సరాల మధ్య ఉన్నట్లయితే, మీకు తల్లిదండ్రులు లేదా సంరక్షకుల నుండి సమ్మతి అవసరం.';

  @override
  String get minorAccountReviewUnder13HonestyTitle =>
      'వెనుకకు క్లిక్ చేయమని మేము మీకు ఎందుకు చెప్పము';

  @override
  String get minorAccountReviewUnder13HonestyBody =>
      'చాలా ఇంటర్నెట్‌లు గేట్ ద్వారా ప్రజలకు ఏది వచ్చినా వారికి రివార్డ్ చేయడానికి సెట్ చేయబడింది. మేము అది గొప్పగా భావించడం లేదు. అవును, మీరు తిరిగి వెళ్లి, మీరు మీ కంటే పెద్దవారని చెప్పవచ్చు, కానీ అది నిజాయితీగా ఉండదు, మరియు మీరు కోరుకున్నది పొందడానికి మేము మీకు అబద్ధం చెప్పడంలో శిక్షణ ఇవ్వబోము.';

  @override
  String get minorAccountReviewUnder13LegalBody =>
      'మేము Divineని యువతకు మరియు వారి చుట్టూ ఉన్న వ్యక్తులకు ఆరోగ్యకరమైన మరియు అనుకూలమైన మార్గాలలో ఉపయోగించడంలో సహాయం చేయడానికి ప్రయత్నిస్తున్నాము. మేము కూడా వివిధ ప్రదేశాలలో వేర్వేరుగా ఉన్న చట్టాలను అనుసరించాలి. కాబట్టి, మీరు 13 ఏళ్లలోపు వారైతే, ఈరోజు మీకు మీ స్వంత ఖాతా ఉండదని సమాధానం.';

  @override
  String get minorAccountReviewTeenBody =>
      'ఈ ఖాతా 13 నుండి 15 సంవత్సరాల వయస్సు గల వారికి చెందినదైతే, తల్లిదండ్రుల సమ్మతి సూచనలను అనుసరించడానికి మోడరేషన్ సందేశం లేదా మద్దతు మార్గాన్ని ఉపయోగించండి.';

  @override
  String get minorAccountReviewParentConsentTitle =>
      'ఖాతా 13 నుండి 15 ఏళ్ల వారికి చెందినదైతే';

  @override
  String get minorAccountReviewParentConsentBody =>
      'తల్లిదండ్రులు లేదా సంరక్షకులు చిన్న ప్రైవేట్ వీడియోతో Divine మద్దతుకు ఇమెయిల్ చేయాలి. మా బృందం దీన్ని సమీక్షించి, తదుపరి దశల్లో సహాయం చేస్తుంది.\n\nతల్లిదండ్రులు లేదా సంరక్షకుల పరిచయం సాధ్యం కాకపోతే లేదా ఎవరైనా ప్రమాదంలో పడినట్లయితే, Divine మద్దతుకు ఇమెయిల్ చేసి మాకు తెలియజేయండి.';

  @override
  String get minorAccountReviewParentConsentPauseNote =>
      'Divine మద్దతు బృందం వీడియోను సమీక్షిస్తున్నప్పుడు ఇది పాజ్. ఇది ఆమోదించబడినట్లయితే, వారు కొత్త ఖాతాను సెటప్ చేయడం ద్వారా మీకు మార్గనిర్దేశం చేస్తారు.';

  @override
  String get minorAccountReviewParentConsentHonestyTitle =>
      'మేము తల్లిదండ్రులను లేదా సంరక్షకులను ఎందుకు పాలుపంచుకోమని అడుగుతాము';

  @override
  String get minorAccountReviewParentConsentHonestyBody =>
      'Divine ప్రపంచవ్యాప్తంగా వయస్సు-సంబంధిత చట్టాలను అనుసరించాలి. చాలా సాంకేతిక వయస్సు గేట్లు అసంపూర్ణంగా ఉన్నాయని కూడా మాకు తెలుసు. నియమాలు లేవని లేదా మీ వయస్సు గురించి అబద్ధాలు చెప్పడం మంచిదని భావించే బదులు, Divineని ఎలా ఉపయోగించాలనే దాని గురించి టీనేజ్ యువకులు మరియు కుటుంబాలు ఆలోచించి నిర్ణయాలు తీసుకోవాలని మేము కోరుకుంటున్నాము. అందుకే, 13-15 సంవత్సరాల వయస్సు గల వారి కోసం, ఖాతా సృష్టి ప్రక్రియలో భాగం కావాలని మేము తల్లిదండ్రులను కోరుతున్నాము.';

  @override
  String get minorAccountReviewParentConsentLegalBody =>
      'మేము కూడా చట్టాన్ని అనుసరించాలి మరియు ఎవరైనా ఎక్కడ నివసిస్తున్నారనే దానిపై ఆధారపడి ఆ నియమాలు భిన్నంగా ఉంటాయి. కాబట్టి నియమాలు ఉనికిలో లేనట్లు నటించడానికి బదులుగా, మేము ప్రక్రియలో భాగం కావాలని తల్లిదండ్రులు లేదా సంరక్షకులను అడుగుతాము.';

  @override
  String get minorAccountReviewParentConsentChecklist => 'వీడియో ఏమి చూపాలి';

  @override
  String get minorAccountReviewParentConsentChecklistKid => 'వీడియోలో యువకుడు';

  @override
  String get minorAccountReviewParentConsentChecklistPermission =>
      'కెమెరాలో మాట్లాడుతున్న తల్లిదండ్రులు లేదా సంరక్షకులు';

  @override
  String get minorAccountReviewParentConsentChecklistAgeBand =>
      'యువకుడికి 13 నుండి 15 సంవత్సరాలు మరియు Divineని ఉపయోగించడానికి అనుమతి ఉందని స్పష్టమైన ప్రకటన';

  @override
  String get minorAccountReviewParentConsentChecklistSupervision =>
      'ఖాతా గురించి తల్లిదండ్రులు లేదా సంరక్షకులకు తెలుసు మరియు దాని వినియోగాన్ని పర్యవేక్షిస్తారనే స్పష్టమైన ప్రకటన';

  @override
  String get minorAccountReviewParentConsentPrivacy => 'దీన్ని ఎలా పంపాలి';

  @override
  String get minorAccountReviewParentConsentNeverPost =>
      'మీరు Divine మద్దతుకు ఇమెయిల్ చేసినప్పుడు వీడియోను అటాచ్ చేయండి';

  @override
  String get minorAccountReviewParentConsentDoNotSave =>
      'వీడియోను ప్రైవేట్‌గా ఉంచండి మరియు యాప్‌లో పోస్ట్ చేయవద్దు';

  @override
  String get minorAccountReviewParentConsentOneMove =>
      'మా బృందం దీన్ని సమీక్షించి తదుపరి దశలతో ప్రత్యుత్తరం ఇస్తుంది';

  @override
  String get minorAccountReviewParentConsentEmailCta => 'ఇమెయిల్ Divine మద్దతు';

  @override
  String get minorAccountReviewParentConsentEmailSubject =>
      'Divine గ్రీన్‌లైట్ సమీక్ష సహాయం (వయస్సు 13-15)';

  @override
  String get minorAccountReviewParentConsentEmailBody =>
      'హాయ్ Divine సపోర్ట్,\n\nనేను Divineని సంప్రదిస్తున్నాను Divine గ్రీన్‌లైట్ 13-15 ఏళ్ల ప్రైవేట్ యువకుడి కోసం.\n⟧N యువకుడు\n- కెమెరాలో మాట్లాడుతున్న తల్లిదండ్రులు లేదా సంరక్షకులు\n- టీనేజ్‌కి Divine\n-ని ఉపయోగించడానికి అనుమతి ఉందని తల్లిదండ్రులు లేదా సంరక్షకులకు ఖాతా గురించి తెలుసు మరియు దాని వినియోగాన్ని పర్యవేక్షిస్తారు\n\nదేశం సందర్భం:\n\nధన్యవాదాలు.';

  @override
  String get minorAccountReviewParentSupportInstructions =>
      'పేరెంట్ సపోర్ట్ సూచనలు';

  @override
  String get minorAccountReviewContinue => 'కొనసాగించండి';

  @override
  String get minorAccountReviewErrorTitle =>
      'మేము మీ ఖాతా సమీక్ష స్థితిని లోడ్ చేయలేకపోయాము.';

  @override
  String get minorAccountReviewErrorBody =>
      'దయచేసి ఒక క్షణంలో మళ్లీ ప్రయత్నించండి.';

  @override
  String get minorAccountReviewTryAgain => 'మళ్లీ ప్రయత్నించండి';

  @override
  String get minorAccountReviewParentContactTitle => 'తల్లిదండ్రుల సంప్రదింపు';

  @override
  String get minorAccountReviewParentContactHeading =>
      'తల్లిదండ్రులు లేదా సంరక్షకుల ఇమెయిల్‌ను జోడించండి';

  @override
  String minorAccountReviewParentContactBody(String caseId) {
    return 'కేసుపై తల్లిదండ్రుల సమ్మతి సమీక్ష కోసం మేము ఈ చిరునామాను ఉపయోగిస్తాము $caseId.';
  }

  @override
  String get minorAccountReviewParentContactFieldLabel =>
      'తల్లిదండ్రులు లేదా సంరక్షకుల ఇమెయిల్';

  @override
  String get minorAccountReviewSubmitting => 'సమర్పిస్తోంది...';

  @override
  String get minorAccountReviewSubmitEmail => 'ఇమెయిల్‌ను సమర్పించండి';

  @override
  String get minorAccountReviewBackToReview => 'ఖాతా సమీక్షకు తిరిగి వెళ్లండి';

  @override
  String get minorAccountReviewSubmissionReceivedTitle =>
      'ఇమెయిల్ సమర్పించబడింది';

  @override
  String minorAccountReviewSubmissionReceivedBody(String email) {
    return 'మేము సమర్పించాము \nసమీక్ష కోసం $email. మేము నిర్ధారించడానికి ఈ చిరునామాకు ఇమెయిల్ చేస్తాము. మీ తల్లిదండ్రులు లేదా సంరక్షకులు ప్రతిస్పందించిన తర్వాత, మీ కేసు ముందుకు సాగుతుంది. అప్‌డేట్‌ల కోసం ఖాతా సమీక్ష స్క్రీన్ నుండి మళ్లీ తనిఖీ చేయండి.';
  }

  @override
  String get minorAccountReviewSubmissionReceivedLocalBody =>
      'మేము ఈ ఖాతా కోసం తల్లిదండ్రులు లేదా సంరక్షకుల పరిచయాన్ని అందుకున్నాము. యాక్సెస్‌ని పునరుద్ధరించే ముందు మా బృందం దాన్ని సమీక్షిస్తుంది.';

  @override
  String get minorAccountReviewMissingCase =>
      'మేము ఈ ఖాతా కోసం సక్రియ సమీక్ష కేసును కనుగొనలేకపోయాము.';

  @override
  String get minorAccountReviewParentContactError =>
      'పేరెంట్ ఇమెయిల్‌ను సమర్పించడం సాధ్యపడలేదు. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get minorAccountReviewUnder13SupportTitle => 'పేరెంట్ సపోర్ట్';

  @override
  String get minorAccountReviewUnder13Heading =>
      'తల్లిదండ్రులు లేదా సంరక్షకులు తప్పనిసరిగా Divineని సంప్రదించాలి';

  @override
  String get minorAccountReviewUnder13SupportBody =>
      '13 ఏళ్లలోపు ఖాతాల కోసం, తదుపరి దశ ఇమెయిల్ ద్వారా తల్లిదండ్రులు లేదా సంరక్షకుల సంప్రదింపు.';

  @override
  String get minorAccountReviewSupportEmailLabel => 'మద్దతు ఇమెయిల్';

  @override
  String get minorAccountReviewCopySupportEmail =>
      'మద్దతు ఇమెయిల్‌ను కాపీ చేయండి';

  @override
  String get minorAccountReviewSupportEmailCopied =>
      'మద్దతు ఇమెయిల్ కాపీ చేయబడింది';

  @override
  String get minorAccountReviewCopyCaseId => 'కేసు IDని కాపీ చేయండి';

  @override
  String get minorAccountReviewCaseIdCopied => 'కేస్ ID కాపీ చేయబడింది';

  @override
  String get minorAccountReviewUnavailable => 'అందుబాటులో లేదు';

  @override
  String get minorAccountReviewUnder13Instructions =>
      'కేసు IDని చేర్చమని తల్లిదండ్రులు లేదా సంరక్షకులను అడగండి మరియు వారు ఈ ఖాతా సమీక్ష గురించి Divineని సంప్రదిస్తున్నారని వివరించండి.\nకేసు కోసం ';

  @override
  String minorAccountReviewUnder13EmailSubject(String caseId) {
    return 'అండర్-13 ఖాతా సమీక్ష $caseId';
  }

  @override
  String minorAccountReviewUnder13EmailBody(String caseId) {
    return 'హాయ్ Divine సపోర్ట్,\n\nనేను 13 ఏళ్లలోపు పిల్లలకు తల్లిదండ్రులు లేదా సంరక్షకుడిని మరియు నేను ఖాతా సమీక్ష కేసు గురించి Divineని సంప్రదిస్తున్నాను $caseId.\n\nధన్యవాదాలు.';
  }

  @override
  String get devOptionsMinorReviewSimulationTitle => 'చిన్న ఖాతా సమీక్ష అనుకరణ';

  @override
  String get devOptionsMinorReviewCurrentStateLabel => 'ప్రస్తుత స్థితి';

  @override
  String devOptionsMinorReviewStateRestricted(String state) {
    return 'పరిమితం చేయబడింది ($state)';
  }

  @override
  String get devOptionsMinorReviewStateActive => 'యాక్టివ్';

  @override
  String get devOptionsMinorReviewStateLoading => 'లోడ్ అవుతోంది...';

  @override
  String get devOptionsMinorReviewStateError => 'స్థితిని లోడ్ చేయడంలో లోపం';

  @override
  String get devOptionsMinorReviewClearTitle =>
      'అనుకరణ ఓవర్‌రైడ్‌ను క్లియర్ చేయండి';

  @override
  String get devOptionsMinorReviewClearSubtitle =>
      'బ్యాకెండ్ లేదా డిఫాల్ట్ క్రియాశీల స్థితిని మళ్లీ ఉపయోగించండి';

  @override
  String get devOptionsMinorReviewTeenTitle =>
      '13-15 సమీక్ష కేసును అనుకరించండి';

  @override
  String get devOptionsMinorReviewTeenSubtitle =>
      'మాతృ సంప్రదింపు మార్గంతో పరిమితం చేయబడిన ఖాతా';

  @override
  String get devOptionsMinorReviewUnder13Title =>
      'అండర్-13 సపోర్ట్ కేస్‌ను అనుకరించండి';

  @override
  String get devOptionsMinorReviewUnder13Subtitle =>
      'తల్లిదండ్రుల ఇమెయిల్-మాత్రమే సూచనలతో పరిమితం చేయబడిన ఖాతా';

  @override
  String get devOptionsMinorReviewClearedToast =>
      'చిన్న ఖాతా సమీక్ష అనుకరణ క్లియర్ చేయబడింది';

  @override
  String get devOptionsMinorReviewUnder13EnabledToast =>
      'సిమ్యులేటెడ్ అండర్-13 సపోర్ట్ కేస్ ఎనేబుల్ చేయబడింది';

  @override
  String get devOptionsMinorReviewResponseClockTitle => 'ప్రతిస్పందన గడియారం';

  @override
  String get devOptionsMinorReviewResponseClockRunning => 'రన్ అవుతోంది';

  @override
  String get devOptionsMinorReviewResponseClockPaused => 'పాజ్ చేయబడింది';

  @override
  String get devOptionsMinorReviewResponseClockExpired => 'గడువు ముగిసింది';

  @override
  String get devOptionsMinorReviewResponseClockNotApplicable => 'వర్తించదు';

  @override
  String get devOptionsMinorReviewResponseClockMalformed =>
      'తప్పుగా రూపొందించిన పేలోడ్';

  @override
  String get devOptionsMinorReviewResponseClockRunningToast =>
      'అనుకరణ నడుస్తున్న ప్రతిస్పందన గడియారం';

  @override
  String get devOptionsMinorReviewResponseClockPausedToast =>
      'అనుకరణ పాజ్ చేయబడిన ప్రతిస్పందన గడియారం';

  @override
  String get devOptionsMinorReviewResponseClockExpiredToast =>
      'అనుకరణ గడువు ముగిసిన ప్రతిస్పందన గడియారం';

  @override
  String get devOptionsMinorReviewResponseClockNotApplicableToast =>
      'అనుకరణ వర్తించని ప్రతిస్పందన గడియారం';

  @override
  String get devOptionsMinorReviewResponseClockMalformedToast =>
      'తప్పుగా రూపొందించబడిన ప్రతిస్పందన గడియారం';

  @override
  String get devOptionsProtectedMinorSimulationTitle =>
      'రక్షిత మైనర్ సిమ్యులేషన్';

  @override
  String get devOptionsProtectedMinorCurrentStateLabel => 'ప్రస్తుత స్థితి';

  @override
  String get devOptionsProtectedMinorStateProtected => 'రక్షిత మైనర్ (13-15)';

  @override
  String get devOptionsProtectedMinorStateNotProtected => 'రక్షించబడలేదు';

  @override
  String get devOptionsProtectedMinorStateLoading => 'లోడ్ అవుతోంది…';

  @override
  String get devOptionsProtectedMinorStateError => 'స్థితిని చదవడంలో లోపం';

  @override
  String get devOptionsProtectedMinorOverrideNone =>
      'ఓవర్‌రైడ్ లేదు (నిజ ఖాతా స్థితి)';

  @override
  String get devOptionsProtectedMinorOverrideProtected =>
      'ఓవర్‌రైడ్: బలవంతంగా రక్షించబడింది';

  @override
  String get devOptionsProtectedMinorOverrideNotProtected =>
      'ఓవర్‌రైడ్: బలవంతంగా రక్షించబడలేదు';

  @override
  String get devOptionsProtectedMinorSimulateTitle =>
      'రక్షిత మైనర్‌ను అనుకరించండి (13-15)';

  @override
  String get devOptionsProtectedMinorSimulateSubtitle =>
      '#175/#176 రక్షణలను QAకి రక్షిత-మైనర్ స్థితిని బలవంతం చేయండి';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorTitle =>
      'నాన్-మైనర్‌ను అనుకరించండి';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorSubtitle =>
      'ఫోర్స్ నాట్-ప్రొటెక్టెడ్ (స్పష్టమైన ప్రతికూలమైనది, ఓవర్‌రైడ్‌కు భిన్నంగా ఉంటుంది)';

  @override
  String get devOptionsProtectedMinorClearTitle =>
      'ఓవర్‌రైడ్‌ను క్లియర్ చేయండి';

  @override
  String get devOptionsProtectedMinorClearSubtitle =>
      'వాస్తవ Keycast-ఆధారిత ఖాతా స్థితికి తిరిగి వెళ్లండి';

  @override
  String get devOptionsProtectedMinorEnabledToast =>
      'రక్షిత-మైనర్ రాష్ట్రం బలవంతంగా ఆన్ చేయబడింది';

  @override
  String get devOptionsProtectedMinorNonMinorToast =>
      'రక్షిత-మైనర్ రాష్ట్రం బలవంతంగా ఆఫ్ చేయబడింది';

  @override
  String get devOptionsProtectedMinorClearedToast =>
      'ప్రొటెక్టెడ్-మైనర్ ఓవర్‌రైడ్ క్లియర్ చేయబడింది';

  @override
  String get devOptionsInviteAvailabilityTitle => 'సైన్అప్ ఆహ్వానాలు';

  @override
  String get devOptionsInviteAvailabilityCurrentLabel => 'ప్రస్తుత స్థితి';

  @override
  String get devOptionsInviteAvailabilityServerLoading =>
      'సర్వర్ విలువ: లోడ్ అవుతోంది';

  @override
  String get devOptionsInviteAvailabilityServerEnabled =>
      'సర్వర్ విలువ: ప్రారంభించబడింది';

  @override
  String get devOptionsInviteAvailabilityServerDisabled =>
      'సర్వర్ విలువ: నిలిపివేయబడింది';

  @override
  String get devOptionsInviteAvailabilityServerUnknown =>
      'సర్వర్ విలువ: తెలియదు';

  @override
  String get devOptionsInviteAvailabilityOverrideNone =>
      'ఓవర్‌రైడ్: సర్వర్ విలువను ఉపయోగించండి';

  @override
  String get devOptionsInviteAvailabilityOverrideEnabled =>
      'ఓవర్‌రైడ్: ఫోర్స్ ఎనేబుల్ చేయబడింది';

  @override
  String get devOptionsInviteAvailabilityOverrideDisabled =>
      'ఓవర్‌రైడ్: ఫోర్స్ డిజేబుల్ చేయబడింది';

  @override
  String get devOptionsInviteAvailabilityUseServer =>
      'సర్వర్ విలువను ఉపయోగించండి';

  @override
  String get devOptionsInviteAvailabilityUseServerSubtitle =>
      'ఆహ్వాన సేవ ఆన్‌బోర్డింగ్ మోడ్‌ను అనుసరించండి';

  @override
  String get devOptionsInviteAvailabilityForceEnabled =>
      'ఫోర్స్ ఎనేబుల్ చేయబడింది';

  @override
  String get devOptionsInviteAvailabilityForceEnabledSubtitle =>
      'సైన్అప్ ఆహ్వాన గేట్‌లు మరియు నిర్వహణను స్థానికంగా చూపండి';

  @override
  String get devOptionsInviteAvailabilityForceDisabled =>
      'బలవంతంగా నిలిపివేయబడింది';

  @override
  String get devOptionsInviteAvailabilityForceDisabledSubtitle =>
      'సర్వర్‌ని మార్చకుండా స్థానికంగా సైన్అప్ ఆహ్వాన UIని దాచండి';

  @override
  String get devOptionsInviteAvailabilityUseServerToast =>
      'సైన్అప్ ఆహ్వానాలు ఇప్పుడు సర్వర్‌ని అనుసరించాయి';

  @override
  String get devOptionsInviteAvailabilityForceEnabledToast =>
      'సైన్అప్ ఆహ్వానాలు బలవంతంగా ఆన్ చేయబడ్డాయి';

  @override
  String get devOptionsInviteAvailabilityForceDisabledToast =>
      'సైన్అప్ ఆహ్వానాలు బలవంతంగా ఆఫ్ చేయబడ్డాయి';

  @override
  String get commentsRecordVideoButtonLabel =>
      'వీడియో వ్యాఖ్యను రికార్డ్ చేయండి';

  @override
  String get commentsOpenVideoLabel => 'వీడియో వ్యాఖ్యను తెరవండి';

  @override
  String get commentsMuteVideoReplyLabel =>
      'వీడియో ప్రత్యుత్తరాన్ని మ్యూట్ చేయండి';

  @override
  String get commentsUnmuteVideoReplyLabel =>
      'వీడియో ప్రత్యుత్తరాన్ని అన్‌మ్యూట్ చేయండి';

  @override
  String get commentsOpenReplyParentLabel =>
      'దీనికి ప్రత్యుత్తరం ఇచ్చే వీడియోని తెరవండి';

  @override
  String get commentsReplyParentSectionTitle => 'దీనికి సమాధానంగా';

  @override
  String commentsReplyParentLabel(String target) {
    return 'దీనికి ప్రత్యుత్తరం ఇవ్వండి $target';
  }

  @override
  String get commentsReplyParentFallbackLabel =>
      'వీడియోకి ప్రత్యుత్తరం ఇవ్వండి';

  @override
  String verifiedAccountChipSemanticLabel(String platform, String identity) {
    return 'ధృవీకరించబడింది $platformఖాతా: $identity';
  }

  @override
  String get profileEditVerifiedAccountsTitle => 'ధృవీకరించబడిన ఖాతాలు';

  @override
  String get profileEditGetVerifiedCta => 'ధృవీకరించండి';

  @override
  String get profileEditGetVerifiedSubtitle =>
      'మీ సోషల్ మీడియా ఖాతాలను లింక్ చేయండి, తద్వారా ఇది నిజంగా మీరేనని ప్రజలు తెలుసుకుంటారు.';

  @override
  String profileWebsiteSemanticLabel(String url) {
    return 'వెబ్‌సైట్‌ను సందర్శించండి: $url';
  }

  @override
  String get profileCouldNotOpenWebsite => 'వెబ్‌సైట్‌ను తెరవడం సాధ్యపడలేదు';

  @override
  String get videoMetadataEditCoverTitle => 'కవర్‌ని సవరించండి';

  @override
  String get videoMetadataEditCoverCloseSemanticLabel =>
      'కవర్ మార్పులను విస్మరించండి';

  @override
  String get videoMetadataEditCoverConfirmSemanticLabel =>
      'ఎంచుకున్న ఫ్రేమ్‌ను వీడియో కవర్‌గా ఉపయోగించండి';

  @override
  String get videoMetadataEditCoverStripSemanticLabel =>
      'కవర్ ఫ్రేమ్‌ని ఎంచుకోవడానికి వీడియో ద్వారా చూడండి';

  @override
  String get videoMetadataTagsPickerSearchHint =>
      'ట్యాగ్‌లను శోధించండి లేదా జోడించండి';

  @override
  String get videoMetadataTagsPickerEmptyHint =>
      'వ్యక్తులు మీ వీడియోను కనుగొనడంలో సహాయపడటానికి ట్యాగ్‌లను జోడించండి';

  @override
  String get videoMetadataTagsPickerNoResults => 'సరిపోలే ట్యాగ్‌లు లేవు';

  @override
  String videoMetadataTagsPickerAddTag(String tag) {
    return '\"# జోడించండి$tag\"';
  }

  @override
  String get authMinAgeNotice => 'Divine గ్రీన్‌లైట్';

  @override
  String get authUnder16Prefix => 'ఇంకా 16 కాదా? అది సరే. ';

  @override
  String get authUnder16ChoicesCta => 'ఇక్కడ మీ ఎంపికలు ఉన్నాయి.';

  @override
  String get minorAccountReviewUnder13WhyTitle => 'ఇక్కడ ఎందుకు ఉంది';

  @override
  String get generalSettingsHoldToRecord => 'రికార్డ్ చేయడానికి పట్టుకోండి';

  @override
  String get generalSettingsHoldToRecordSubtitle =>
      'మీరు నొక్కి ఉంచినప్పుడు రికార్డింగ్ ప్రారంభించండి, ఆపై మీరు విడుదల చేసినప్పుడు ఆపివేయండి';

  @override
  String uploadPublishedCountMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countవీడియోలు మీ ప్రొఫైల్‌లో ప్రచురించబడ్డాయి',
      one: 'వీడియో మీ ప్రొఫైల్‌లో ప్రచురించబడింది',
    );
    return '$_temp0';
  }

  @override
  String get dmMessageSendLabel => 'సందేశాన్ని పంపండి';

  @override
  String get emojiPickerSearchHint => 'శోధన';

  @override
  String get emojiCategoryRecent => 'ఇటీవలిది';

  @override
  String get emojiCategorySmileys => 'స్మైలీలు & వ్యక్తులు';

  @override
  String get emojiCategoryAnimals => 'జంతువులు & ప్రకృతి';

  @override
  String get emojiCategoryFood => 'ఆహారం & పానీయం';

  @override
  String get emojiCategoryActivities => 'కార్యకలాపాలు';

  @override
  String get emojiCategoryTravel => 'ప్రయాణం & స్థలాలు';

  @override
  String get emojiCategoryObjects => 'వస్తువులు';

  @override
  String get emojiCategorySymbols => 'చిహ్నాలు';

  @override
  String get emojiCategoryFlags => 'జెండాలు';

  @override
  String get videoEditorMarkerLabel => 'మార్కర్';

  @override
  String get videoEditorAddTimelineMarkerSemanticLabel =>
      'టైమ్‌లైన్ మార్కర్‌ను జోడించండి';

  @override
  String get videoEditorRemoveTimelineMarkerSemanticLabel =>
      'టైమ్‌లైన్ మార్కర్‌ను తీసివేయండి';

  @override
  String get videoEditorRemoveTimelineMarkerAtPlayheadSemanticLabel =>
      'ప్లేహెడ్ వద్ద మార్కర్‌ను తీసివేయండి';

  @override
  String get videoEditorDeleteTimelineMarkerTitle => 'మార్కర్‌ను తొలగించాలా?';

  @override
  String get videoEditorDeleteTimelineMarkerSubtitle =>
      'ఇది టైమ్‌లైన్ నుండి మార్కర్‌ను తీసివేస్తుంది. మీ సవరణ చెక్కుచెదరకుండా ఉంటుంది.';

  @override
  String get videoEditorVolumeLongPressHint =>
      'అన్ని ట్రాక్‌లను మ్యూట్ చేయండి లేదా అన్‌మ్యూట్ చేయండి';

  @override
  String get videoEditorSplitFailed =>
      'విభజన విఫలమైంది. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get videoEditEditSubtitles => 'ఉపశీర్షికలను సవరించండి';

  @override
  String get subtitleEditorTitle => 'ఉపశీర్షికలను సవరించండి';

  @override
  String get subtitleEditorSave => 'సేవ్ చేయండి';

  @override
  String get subtitleEditorProcessing =>
      'ఉపశీర్షికలు ఇప్పటికీ రూపొందించబడుతున్నాయి. ఒక క్షణంలో తిరిగి తనిఖీ చేయండి.';

  @override
  String get subtitleEditorNoSpeech =>
      'ఈ వీడియోలో ప్రసంగం కనుగొనబడలేదు, కాబట్టి క్యాప్షన్ చేయడానికి ఏమీ లేదు.';

  @override
  String get subtitleEditorWriteOwn => 'వాటిని మీరే వ్రాయండి';

  @override
  String get subtitleEditorAddCue => 'పంక్తిని జోడించండి';

  @override
  String get subtitleEditorRemoveCue => 'ఈ లైన్‌ని తీసివేయండి';

  @override
  String get subtitleEditorPreviewUnavailable =>
      'వీడియో ప్రస్తుతం ప్లే చేయబడదు, కానీ మీరు ఇప్పటికీ శీర్షికలను పరిష్కరించవచ్చు.';

  @override
  String get subtitleEditorPlayPreview => 'వీడియోని ప్లే చేయండి';

  @override
  String get subtitleEditorPausePreview => 'వీడియోను పాజ్ చేయండి';

  @override
  String get subtitleEditorInvalidHint =>
      'ప్రతి పంక్తికి టెక్స్ట్ మరియు దాని ప్రారంభం తర్వాత ముగింపు అవసరం.';

  @override
  String get subtitleEditorLoadError =>
      'ఉపశీర్షికలను లోడ్ చేయడం సాధ్యపడలేదు. మళ్లీ ప్రయత్నించండి.';

  @override
  String get subtitleEditorSaveSuccess => 'ఉపశీర్షికలు నవీకరించబడ్డాయి';

  @override
  String get subtitleEditorSaveError =>
      'ఉపశీర్షికలను సేవ్ చేయడం సాధ్యపడలేదు. మళ్లీ ప్రయత్నించండి.';

  @override
  String get subtitleEditorRetry => 'మళ్లీ ప్రయత్నించండి';

  @override
  String get subtitleEditorCueHint => 'శీర్షిక వచనం';

  @override
  String get imageCropEditorRotateLabel => 'తిప్పండి';

  @override
  String get imageCropEditorFlipLabel => 'ఫ్లిప్';

  @override
  String get imageCropEditorResetLabel => 'రీసెట్ చేయండి';

  @override
  String get imageCropEditorCloseSemanticLabel => 'క్రాపింగ్‌ని రద్దు చేయండి';

  @override
  String get imageCropEditorDoneSemanticLabel => 'పంటను వర్తింపజేయండి';

  @override
  String get imageCropEditorProcessing => 'పంటను వర్తింపజేస్తోంది…';

  @override
  String get backgroundUploadNotificationTitle => 'వీడియోను అప్‌లోడ్ చేస్తోంది';

  @override
  String get monetizationSettingsTitle => 'సృష్టికర్త మద్దతు';

  @override
  String get monetizationSettingsSubtitle =>
      'చిట్కా మరియు సబ్‌స్క్రిప్షన్ లింక్‌లను జోడించండి';

  @override
  String get monetizationSettingsIntroTitle => 'అవుట్‌బౌండ్ లింక్‌లు మాత్రమే';

  @override
  String get monetizationSettingsIntroBody =>
      'సృష్టికర్త-నియంత్రిత గమ్యస్థానాలను జోడించండి. Divine చెల్లింపును ఎప్పుడూ నిర్వహించదు లేదా ఈ లింక్‌ల నుండి యాప్‌లోని కంటెంట్‌ను అన్‌లాక్ చేయదు.\nమీ ప్రొఫైల్‌లో ';

  @override
  String monetizationSettingsConfiguredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countక్రియాశీల లింక్‌లు',
      one: '$countసక్రియ లింక్\nమీ ప్రొఫైల్‌లో ',
    );
    return '$_temp0';
  }

  @override
  String get monetizationSettingsTipSection => 'చిట్కా పంపండి';

  @override
  String get monetizationSettingsSubscriptionSection =>
      'సబ్స్క్రయిబ్ / సపోర్ట్ చేయండి';

  @override
  String get monetizationSettingsSave => 'మద్దతు లింక్‌లను సేవ్ చేయండి';

  @override
  String get monetizationSettingsSaving => 'సేవ్ చేస్తోంది...';

  @override
  String get monetizationSettingsSaved => 'మద్దతు లింక్‌లు నవీకరించబడ్డాయి';

  @override
  String get monetizationSettingsSaveFailed =>
      'మద్దతు లింక్‌లను సేవ్ చేయడం సాధ్యపడలేదు. మీ కనెక్షన్‌ని తనిఖీ చేసి, మళ్లీ ప్రయత్నించండి.';

  @override
  String get monetizationSettingsErrorEmpty =>
      'హ్యాండిల్ లేదా URLని జోడించండి.';

  @override
  String get monetizationSettingsErrorInvalid =>
      'ఆ లింక్ సరిగ్గా కనిపించడం లేదు.';

  @override
  String get monetizationSettingsErrorWrongProvider =>
      'ఈ ప్రొవైడర్ కోసం లింక్‌ని ఉపయోగించండి.';

  @override
  String get monetizationSettingsHintCashApp => '\$cashtag లేదా cash.app లింక్';

  @override
  String get monetizationSettingsHintPayPal => 'PayPal.me హ్యాండిల్ లేదా లింక్';

  @override
  String get monetizationSettingsHintVenmo => 'వెన్మో హ్యాండిల్ లేదా లింక్';

  @override
  String get monetizationSettingsHintPatreon => 'Patreon హ్యాండిల్ లేదా లింక్';

  @override
  String get monetizationSettingsHintSubstack => 'సబ్‌స్టాక్ డొమైన్ లేదా లింక్';

  @override
  String get monetizationSettingsHintMedium => 'మీడియం హ్యాండిల్ లేదా లింక్';

  @override
  String get monetizationSettingsHintOpenCollective =>
      'కలెక్టివ్ స్లగ్ లేదా లింక్‌ని తెరవండి';

  @override
  String get profileSupportSheetTitle => 'ఈ సృష్టికర్తకు మద్దతు ఇవ్వండి';

  @override
  String get profileSupportSheetBody =>
      'ఈ లింక్‌లు Divine వెలుపల తెరవబడతాయి. ఇక్కడ ఏదీ యాప్‌లోని కంటెంట్‌ను అన్‌లాక్ చేయదు.';

  @override
  String get profileSupportTipSection => 'చిట్కా పంపండి';

  @override
  String get profileSupportSubscriptionSection =>
      'సబ్స్క్రయిబ్ / సపోర్ట్ చేయండి';

  @override
  String get profileSupportButtonLabel => 'మద్దతు';

  @override
  String get monetizationTipsSettingsTitle => 'చిట్కాలు';

  @override
  String get monetizationTipsSettingsSubtitle =>
      'ఐచ్ఛిక చిట్కా లింక్‌లను జోడించండి';

  @override
  String get monetizationTipsSettingsIntroTitle => 'ఐచ్ఛిక చిట్కాలు మాత్రమే';

  @override
  String get monetizationTipsSettingsIntroBody =>
      'చిట్కాలు వినియోగదారు నుండి వినియోగదారుకు ఐచ్ఛిక బహుమతులు. వారు Divineలో కంటెంట్, సబ్‌స్క్రిప్షన్‌లు, ఫీచర్‌లు, ర్యాంకింగ్, విజిబిలిటీ లేదా యాక్సెస్‌ని అన్‌లాక్ చేయరు.\nమీ ప్రొఫైల్‌లో ';

  @override
  String monetizationTipsSettingsConfiguredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countసక్రియ చిట్కా లింక్‌లు',
      one: '$countసక్రియ చిట్కా లింక్\nమీ ప్రొఫైల్‌లో ',
    );
    return '$_temp0';
  }

  @override
  String get monetizationTipsSettingsSave => 'చిట్కా లింక్‌లను సేవ్ చేయండి';

  @override
  String get monetizationTipsSettingsSaved => 'చిట్కా లింక్‌లు నవీకరించబడ్డాయి';

  @override
  String get profileTipButtonLabel => 'చిట్కా';

  @override
  String get profileTipSheetTitle => 'ఈ సృష్టికర్తకు చిట్కా ఇవ్వండి';

  @override
  String get profileTipSheetBody =>
      'చిట్కాలు Divine వెలుపల తెరవబడతాయి. అవి ఐచ్ఛికం మరియు Divineలో కంటెంట్, సబ్‌స్క్రిప్షన్‌లు, ఫీచర్‌లు లేదా యాక్సెస్‌ను అన్‌లాక్ చేయవు.';

  @override
  String get settingsStorageTitle => 'నిల్వ';

  @override
  String get settingsStorageCacheSectionTitle => 'కాష్ చేయబడిన మీడియా';

  @override
  String get settingsStorageCacheDescription =>
      'కాష్ చేసిన ఫీడ్ వీడియోలు, థంబ్‌నెయిల్‌లు మరియు తాత్కాలిక రెండర్‌లు. వాటిని క్లియర్ చేయడం సురక్షితం - అవసరమైనప్పుడు అవి మళ్లీ డౌన్‌లోడ్ చేయబడతాయి లేదా పునరుత్పత్తి చేయబడతాయి.';

  @override
  String get settingsStorageMeasuring => 'కొలుస్తోంది…';

  @override
  String settingsStorageCacheInUse(String size) {
    return '$sizeఉపయోగంలో ఉంది';
  }

  @override
  String get settingsStorageClearButton => 'కాష్‌ని క్లియర్ చేయండి';

  @override
  String get settingsStorageClearConfirmTitle =>
      'కాష్ చేసిన మీడియాను క్లియర్ చేయాలా?';

  @override
  String settingsStorageClearConfirmMessage(String size) {
    return 'ఇది ఖాళీ చేస్తుంది $size. మీ క్లిప్ లైబ్రరీ ప్రభావితం కాలేదు.';
  }

  @override
  String get settingsStorageClearConfirmAction => 'క్లియర్';

  @override
  String get settingsStorageCleared => 'కాష్ క్లియర్ చేయబడింది';

  @override
  String get settingsStorageLibrarySectionTitle => 'క్లిప్ లైబ్రరీ';

  @override
  String get settingsStorageLibraryDescription =>
      'వీడియో ఫైల్ తప్పిపోయిన విరిగిన క్లిప్‌ల కోసం తనిఖీ చేయండి.';

  @override
  String get settingsStorageScanButton => 'లైబ్రరీని తనిఖీ చేయండి';

  @override
  String get settingsStorageLibraryHealthy =>
      'విరిగిన క్లిప్‌లు ఏవీ కనుగొనబడలేదు';

  @override
  String settingsStorageBrokenClipsFound(int count) {
    return 'విరిగిన క్లిప్‌లు కనుగొనబడ్డాయి: $count';
  }

  @override
  String get settingsStorageRemoveBrokenButton =>
      'విరిగిన క్లిప్‌లను తొలగించండి';

  @override
  String get settingsStorageBrokenClipsRemoved =>
      'విరిగిన క్లిప్‌లు తీసివేయబడ్డాయి';

  @override
  String get settingsStorageError => 'ఏదో తప్పు జరిగింది';

  @override
  String get settingsStorageMaxVideoCacheLabel => 'గరిష్ట వీడియో కాష్';

  @override
  String settingsStorageApproxVideos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '≈ $countవీడియోలు',
      one: '≈ $countవీడియో',
    );
    return '$_temp0';
  }

  @override
  String get settingsStorageRemoveBrokenConfirmTitle =>
      'విరిగిన క్లిప్‌లను తీసివేయాలా?';

  @override
  String get settingsStorageRepairSectionTitle => 'రిపేర్ ఇన్‌స్టాల్';

  @override
  String get settingsStorageRepairDescription =>
      'యాప్ క్రాష్ అవుతూ ఉంటే లేదా వింతగా వ్యవహరిస్తుంటే, దాని స్థానిక డేటాను రీసెట్ చేయడం సాధారణంగా దాన్ని పరిష్కరిస్తుంది. మీ క్లిప్‌లు మరియు చిత్తుప్రతులు అలాగే ఉంటాయి.';

  @override
  String get settingsStorageRepairButton => 'యాప్ డేటాను రీసెట్ చేయండి';

  @override
  String get settingsStorageRepairConfirmTitle => 'యాప్ డేటాను రీసెట్ చేయాలా?';

  @override
  String get settingsStorageRepairConfirmMessage =>
      'ఇది కాష్ చేసిన ఫీడ్ డేటా మరియు తాత్కాలిక ఫైల్‌లను క్లియర్ చేస్తుంది. మీ క్లిప్‌లు, చిత్తుప్రతులు, సెట్టింగ్‌లు మరియు సైన్-ఇన్ స్టే, కానీ మీరు తర్వాత యాప్‌ని పునఃప్రారంభించాలి.';

  @override
  String settingsStorageRepairFootprint(String size) {
    return '$sizeతీసివేయబడుతుంది';
  }

  @override
  String get settingsStorageRepairConfirmAction => 'రీసెట్';

  @override
  String get settingsStorageRepairInProgress => 'రీసెట్ చేస్తోంది…';

  @override
  String get settingsStorageRepairSuccess =>
      'పూర్తయింది — పూర్తి చేయడానికి యాప్‌ని పునఃప్రారంభించండి.';

  @override
  String get settingsStorageRepairFailure =>
      'అన్నింటినీ రీసెట్ చేయడం సాధ్యపడలేదు. పునఃప్రారంభించిన తర్వాత మళ్లీ ప్రయత్నించండి.';

  @override
  String get nostrSettingsSignatureVerification => 'సంతకం ధృవీకరణ';

  @override
  String get nostrSettingsSignatureVerificationIntro =>
      'Divine రిలే ఈవెంట్ సంతకాలను ఎప్పుడు తనిఖీ చేస్తుందో ఎంచుకోండి. ఈవెంట్ IDలు ఎల్లప్పుడూ ముందుగా ధృవీకరించబడతాయి.';

  @override
  String get nostrSettingsSignatureVerificationAll => 'అన్ని రిలేలు';

  @override
  String get nostrSettingsSignatureVerificationAllSubtitle =>
      'సురక్షితమైనది. ప్రతి రిలే ఈవెంట్ సంతకాన్ని ధృవీకరించండి.';

  @override
  String get nostrSettingsSignatureVerificationUntrusted => 'అవిశ్వసనీయ రిలేలు';

  @override
  String get nostrSettingsSignatureVerificationUntrustedSubtitle =>
      'ఇప్పటికే మీ కాన్ఫిగర్ చేసిన పూల్‌లో ఉన్న రిలేల కోసం తనిఖీలను దాటవేయండి.';

  @override
  String get nostrSettingsSignatureVerificationNonDivine =>
      'నాన్-Divine రిలేలు';

  @override
  String get nostrSettingsSignatureVerificationNonDivineSubtitle =>
      'Divine రిలేలను నమ్మండి, మిగిలిన వాటిని ధృవీకరించండి.';

  @override
  String get settingsCrosspostingTitle => 'క్రాస్‌పోస్టింగ్';

  @override
  String get settingsCrosspostingSubtitle =>
      'మీ వీడియోలను ఇతర ప్లాట్‌ఫారమ్‌లకు భాగస్వామ్యం చేయండి\nక్రాస్‌పోస్టింగ్‌ని నిర్వహించడానికి ';

  @override
  String get crosspostingSignInRequired => 'Divineతో సైన్ ఇన్ చేయండి';

  @override
  String get crosspostingLoadFailed =>
      'మీ క్రాస్‌పోస్టింగ్ సెట్టింగ్‌లను లోడ్ చేయడం సాధ్యపడలేదు';

  @override
  String get crosspostingNoPlatforms =>
      'ప్రస్తుతం క్రాస్‌పోస్టింగ్ ప్లాట్‌ఫారమ్‌లు ఏవీ అందుబాటులో లేవు';

  @override
  String get crosspostingRetry => 'మళ్లీ ప్రయత్నించండి';

  @override
  String get crosspostingNotConnected => 'కనెక్ట్ కాలేదు';

  @override
  String get crosspostingConnected => 'కనెక్ట్ చేయబడింది';

  @override
  String get crosspostingNeedsReconnect => 'మళ్లీ కనెక్ట్ కావాలి';

  @override
  String get crosspostingConnect => 'కనెక్ట్ చేయండి';

  @override
  String get crosspostingReconnect => 'మళ్లీ కనెక్ట్ చేయండి';

  @override
  String get crosspostingDisconnect => 'డిస్‌కనెక్ట్';

  @override
  String get crosspostingModeOff => 'ఆఫ్';

  @override
  String get crosspostingModeManual => 'మాన్యువల్';

  @override
  String get crosspostingModeManualSubtitle =>
      'మీరు ఒక్కో వీడియోను ఎంచుకుంటారు';

  @override
  String get crosspostingModeAutomatic => 'ఆటోమేటిక్';

  @override
  String get crosspostingModeAutomaticSubtitle =>
      'భవిష్యత్ వీడియోలు స్వయంచాలకంగా పోస్ట్ చేయబడతాయి — మీరు దీన్ని ఆన్ చేసిన తర్వాత మాత్రమే ప్రచురించబడిన వీడియోలు';

  @override
  String get crosspostingNotConnectedError =>
      'ఈ ప్లాట్‌ఫారమ్ ఎలా పోస్ట్ చేస్తుందో మార్చడానికి ముందుగా దాన్ని కనెక్ట్ చేయండి.';

  @override
  String get crosspostingGenericError =>
      'ఏదో తప్పు జరిగింది. మళ్లీ ప్రయత్నించండి.';

  @override
  String get crosspostingCallbackTimeoutError =>
      'మేము సైన్-ఇన్ పేజీ నుండి తిరిగి వినలేదు. మీరు అక్కడ కనెక్ట్ చేయడం పూర్తి చేసినట్లయితే, రిఫ్రెష్ చేయండి - మీ ఖాతా ఇప్పటికే లింక్ చేయబడి ఉండవచ్చు.';

  @override
  String crosspostingConnectionSuccess(String platform) {
    return '$platformకనెక్ట్ చేయబడింది';
  }

  @override
  String crosspostingConnectionFailed(String platform) {
    return 'కనెక్ట్ చేయడం సాధ్యపడలేదు $platform';
  }

  @override
  String crosspostingConnectionDenied(String platform) {
    return 'కనెక్షన్ రద్దు చేయబడింది $platform';
  }

  @override
  String get supporterTitle =>
      'Divine మద్దతుదారులు\nఐచ్ఛిక నెలవారీ సభ్యత్వంతో ';

  @override
  String get supporterTileSubtitle => 'మద్దతు Divine.';

  @override
  String get supporterHeroTitle => 'Divine రన్ చేస్తూ ఉండండి';

  @override
  String get supporterHeroBody =>
      'Divine ఉచితం మరియు ఎల్లప్పుడూ ఉంటుంది. మీరు లూప్‌లను కొనసాగించడంలో మాకు సహాయం చేయాలనుకుంటే, నెలవారీ మద్దతుదారుగా అవ్వండి. ఏదీ లాక్ చేయబడలేదు - ఇది కేవలం లైట్లను ఆన్ చేస్తుంది మరియు మా కృతజ్ఞతలు పొందుతుంది.';

  @override
  String get supporterActiveBadge =>
      'మీరు Divine మద్దతుదారు. దీన్ని కొనసాగించినందుకు ధన్యవాదాలు.';

  @override
  String get supporterPurchasePending => 'మీ కొనుగోలు ఆమోదం పెండింగ్‌లో ఉంది.';

  @override
  String get supporterPurchaseConfirming => 'మీ మద్దతును నిర్ధారిస్తోంది…';

  @override
  String get supporterStoreChecking => 'స్టోర్‌ని తనిఖీ చేస్తోంది…';

  @override
  String get supporterUnavailable =>
      'సపోర్టర్ సబ్‌స్క్రిప్షన్‌లు ప్రస్తుతం ఇక్కడ అందుబాటులో లేవు.';

  @override
  String get supporterRestorePurchases => 'కొనుగోళ్లను పునరుద్ధరించండి';

  @override
  String get supporterDismissError => 'దోషాన్ని తీసివేయండి';

  @override
  String get supporterErrorStoreUnavailable =>
      'ఈ పరికరంలో స్టోర్ అందుబాటులో లేదు.';

  @override
  String get supporterErrorPurchaseFailed =>
      'కొనుగోలు పూర్తి కాలేదు. మీకు ఛార్జీ విధించబడలేదు.';

  @override
  String get supporterErrorPurchasePending =>
      'మీ కొనుగోలు ఆమోదం పెండింగ్‌లో ఉంది.';

  @override
  String get supporterErrorRestoreFailed =>
      'పునరుద్ధరించడానికి మద్దతుదారు సభ్యత్వం కనుగొనబడలేదు.';

  @override
  String get supporterErrorOwnershipConflict =>
      'ఈ కొనుగోలు మరొక Divine ఖాతాకు చెందినది.';

  @override
  String get supporterErrorVerificationUnavailable =>
      'Divine ప్రస్తుతం మద్దతుదారు స్థితిని నిర్ధారించలేకపోయింది.';

  @override
  String get supporterErrorUnknown =>
      'ఏదో తప్పు జరిగింది. దయచేసి మళ్లీ ప్రయత్నించండి.\nస్టోర్ మీ కొనుగోలును ధృవీకరించిన తర్వాత ';

  @override
  String get supporterDisclaimer =>
      'Divine మద్దతుదారు స్థితిని నిర్ధారిస్తుంది. గుర్తింపు అనేది ఐచ్ఛికం మరియు హాలో అనేది ధృవీకరణ కాదు.';

  @override
  String get profileNotifyBellOff => 'కొత్త తీగల గురించి తెలియజేయండి';

  @override
  String get profileNotifyBellOn =>
      'కొత్త తీగల గురించి నాకు తెలియజేయడం ఆపివేయండి';

  @override
  String get profileNotifyUpdateFailed =>
      'దాన్ని సేవ్ చేయడం సాధ్యపడలేదు. మళ్లీ ప్రయత్నించాలా?';

  @override
  String get savedSoundYourLabel => 'మీ లేబుల్';

  @override
  String get savedSoundAddHashtags => 'హ్యాష్‌ట్యాగ్‌లను జోడించండి';

  @override
  String get savedSoundDeviceOnly => 'ఈ పరికరంలో సేవ్ చేయబడింది';

  @override
  String get savedSoundDetailsRetry =>
      'ఆ వివరాలను సేవ్ చేయడం సాధ్యపడలేదు. మళ్లీ ప్రయత్నించడానికి నొక్కండి.';

  @override
  String get savedSoundFallbackTitle => 'సేవ్ చేయబడిన ధ్వని';

  @override
  String get savedSoundPreviewAction => 'ప్రివ్యూ సౌండ్';

  @override
  String get savedSoundEditAction => 'ధ్వని వివరాలను సవరించండి';

  @override
  String get savedSoundRemoveAction => 'సేవ్ చేయబడిన ధ్వనిని తీసివేయండి';

  @override
  String get savedSoundClearHashtagFilter =>
      'హ్యాష్‌ట్యాగ్ ఫిల్టర్‌ను క్లియర్ చేయండి';

  @override
  String get soundAllowRemix =>
      'ఈ ధ్వనిని రీమిక్స్ చేయడానికి ఇతరులను అనుమతించండి';

  @override
  String get soundReuseUnavailable =>
      'ఈ ధ్వనిని ప్రస్తుతం రీమిక్స్ చేయడం సాధ్యం కాదు.';

  @override
  String get soundPublicCredit => 'పబ్లిక్ సౌండ్ క్రెడిట్';

  @override
  String get soundCreditRequired =>
      'పోస్ట్ చేయడానికి ముందు పబ్లిక్ సౌండ్ క్రెడిట్‌ను జోడించండి.';

  @override
  String get soundSharedAs => 'ఇలా భాగస్వామ్యం చేయబడింది';

  @override
  String get soundOwnWork => 'నేను ఈ ధ్వని చేసాను';

  @override
  String soundCreatorBy(String creator) {
    return 'ద్వారా $creator';
  }

  @override
  String soundSharedBy(String publisher) {
    return 'భాగస్వామ్యం చేసారు $publisher';
  }

  @override
  String get soundRemixingAllowed => 'రీమిక్సింగ్ అనుమతించబడింది';

  @override
  String get soundCreditOnly => 'క్రెడిట్ మాత్రమే';

  @override
  String get soundCreditTitleLabel => 'ధ్వని శీర్షిక';

  @override
  String get soundCreditCreatorLabel => 'సృష్టికర్త';

  @override
  String get soundCreditSourceUrlLabel => 'మూల URL';

  @override
  String get soundCreditPublicHashtagsLabel => 'పబ్లిక్ హ్యాష్‌ట్యాగ్‌లు';

  @override
  String get videoMetadataTagsPickerCancelSemanticLabel =>
      'ట్యాగ్ ఎంపికను రద్దు చేయండి';

  @override
  String get videoMetadataTagsPickerConfirmSemanticLabel =>
      'ఎంచుకున్న ట్యాగ్‌లను వర్తింపజేయండి';

  @override
  String get userPickerCancelSemanticLabel =>
      'వినియోగదారు ఎంపికను రద్దు చేయండి';

  @override
  String get userPickerConfirmSemanticLabel =>
      'ఎంచుకున్న వినియోగదారులను నిర్ధారించండి';

  @override
  String get userPickerClearSelectionSemanticLabel =>
      'వినియోగదారు ఎంపికను క్లియర్ చేయండి';

  @override
  String get videoMetadataContentWarningsPickerCancelSemanticLabel =>
      'కంటెంట్ హెచ్చరిక ఎంపికను రద్దు చేయండి';

  @override
  String get videoMetadataContentWarningsPickerConfirmSemanticLabel =>
      'ఎంచుకున్న కంటెంట్ హెచ్చరికలను వర్తింపజేయండి';

  @override
  String get videoEditorCloseEditorSemanticLabel =>
      'వీడియో ఎడిటర్‌ను మూసివేయండి';

  @override
  String get videoEditorContinueToPostDetailsSemanticLabel =>
      'వివరాలను పోస్ట్ చేయడం కొనసాగించండి';

  @override
  String videoEditorDiscardToolChangesSemanticLabel(String tool) {
    return 'లో మార్పులను విస్మరించండి $tool';
  }

  @override
  String videoEditorApplyToolChangesSemanticLabel(String tool) {
    return 'లో మార్పులను వర్తింపజేయండి $tool';
  }

  @override
  String get videoEditorRemoveAudioSemanticLabel => 'ఆడియోను తీసివేయండి';

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
  String get verifyTitle => 'ధృవీకరించబడిన ఖాతాలు';

  @override
  String get verifySignedOutMessage =>
      'మీ ఖాతాలను లింక్ చేయడానికి సైన్ ఇన్ చేయండి.';

  @override
  String get verifyIntro =>
      'మీరు ఇప్పటికే కలిగి ఉన్న ఖాతాలను లింక్ చేయండి, కాబట్టి ఇది నిజంగా మీరేనని వ్యక్తులు చెప్పగలరు.';

  @override
  String get verifyLoadFailed => 'మీ లింక్‌లను లోడ్ చేయడం సాధ్యపడలేదు.';

  @override
  String get verifyRetry => 'మళ్లీ ప్రయత్నించండి';

  @override
  String get verifyLinkedSectionTitle => 'లింక్ చేయబడింది';

  @override
  String get verifyVerifierUnreachable =>
      'వెరిఫైయర్‌ని చేరుకోలేకపోయింది, కాబట్టి ఇవి ఎంపిక చేయబడలేదు.';

  @override
  String get verifyAddSectionTitle => 'ఖాతాను జోడించండి';

  @override
  String get verifyAllPlatformsLinked =>
      'మేము మద్దతిచ్చే ప్రతిదానికీ మీరు లింక్ చేసారు.';

  @override
  String get verifyStatusVerified => 'ధృవీకరించబడింది';

  @override
  String get verifyStatusUnverified => 'ధృవీకరించబడలేదు';

  @override
  String verifyUnlinkSemanticLabel(String platform, String identity) {
    return 'అన్‌లింక్ చేయండి $platformఖాతా $identity';
  }

  @override
  String verifyUnlinkConfirmTitle(String platform) {
    return 'అన్‌లింక్ చేయండి $platform?';
  }

  @override
  String verifyUnlinkConfirmSubtitle(String identity) {
    return '$identityమీ ప్రొఫైల్‌లో చూపడం ఆగిపోతుంది. మీరు దీన్ని తర్వాత మళ్లీ లింక్ చేయవచ్చు, కానీ మీరు సైన్ ఇన్ చేయాలి లేదా కొత్త రుజువును పోస్ట్ చేయాలి.';
  }

  @override
  String get verifyUnlinkConfirmCta => 'అన్‌లింక్ చేయండి';

  @override
  String verifyLinkSemanticLabel(String platform) {
    return 'లింక్ మీ $platformఖాతా';
  }

  @override
  String get verifyOneTapBadge => 'ఒక్కసారి నొక్కండి';

  @override
  String verifyConnectOauthExplainer(String platform) {
    return 'కు సైన్ ఇన్ చేయండి $platformమరియు మేము మిగిలిన వాటిని నిర్వహిస్తాము. ఏదీ పోస్ట్ చేయబడదు.';
  }

  @override
  String verifyConnectOauthCta(String platform) {
    return 'దీనితో కొనసాగించండి $platform';
  }

  @override
  String get verifyConnectProofTitle => 'లేదా రుజువును పోస్ట్ చేయండి';

  @override
  String get verifyConnectProofExplainer =>
      'మీ ఖాతాలో మీ npubని పోస్ట్ చేసి, ఆ పోస్ట్‌కి లింక్‌ను అతికించండి.';

  @override
  String get verifyNpubLabel => 'మీ npub';

  @override
  String get verifyCopyNpubSemanticLabel => 'మీ npubని కాపీ చేయండి';

  @override
  String get verifyNpubCopied => 'npub కాపీ చేయబడింది';

  @override
  String get verifyIdentityLabel => 'ఖాతా పేరు';

  @override
  String get verifyProofLabel => 'మీ పోస్ట్‌కి లింక్';

  @override
  String get verifyConnectProofCta => 'తనిఖీ చేసి లింక్ చేయండి';

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
      'వెరిఫైయర్‌ని చేరుకోలేకపోయింది. క్షణంలో మళ్లీ ప్రయత్నించండి.';

  @override
  String get verifyErrorOauthFailed => 'అది జరగలేదు. మరొకసారి ఇవ్వండి.';

  @override
  String get verifyErrorHandleRequired =>
      'ముందుగా మీ హ్యాండిల్‌ని నమోదు చేయండి.';

  @override
  String get verifyErrorPublishFailed =>
      'ధృవీకరించబడింది, కానీ ఏ రిలే నవీకరణను తీసుకోలేదు. మళ్లీ ప్రయత్నించండి.';

  @override
  String get verifyErrorOauthUnavailable =>
      'దీని కోసం వన్-ట్యాప్ సైన్-ఇన్ ఇంకా సెటప్ చేయబడలేదు. దిగువ రుజువు పోస్ట్‌ను ఉపయోగించండి.';

  @override
  String get verifyConnectProofExplainerGithub =>
      'మొదటి ఫైల్‌లో మీ npubతో పబ్లిక్ సారాంశాన్ని రూపొందించండి, ఆపై సారాంశం లింక్‌ను అతికించండి.';

  @override
  String get verifyConnectProofExplainerDiscord =>
      'మా బాట్ చదవగలిగే డిస్కార్డ్ ఛానెల్‌లో మీ npubని పోస్ట్ చేసి, ఆపై సందేశ లింక్‌ను అతికించండి. సర్వర్ ఆహ్వానం ఏమీ నిరూపించదు.';

  @override
  String get verifyConnectProofExplainerTwitter =>
      'ఆ ఖాతా నుండి మీ npubని ట్వీట్ చేసి, ఆపై ట్వీట్‌కి లింక్‌ను అతికించండి.';

  @override
  String get verifyConnectProofExplainerMastodon =>
      'ఆ ఖాతా నుండి మీ npubని పోస్ట్ చేసి, ఆపై లింక్‌ను అతికించండి. ఖాతా పేరుకు దాని ఉదాహరణ అవసరం - mastodon.social/@alice, కేవలం ఆలిస్ కాదు.';

  @override
  String get verifyConnectProofExplainerTelegram =>
      'ఛానెల్ లింక్ చేయబడింది, మీ టెలిగ్రామ్ ఖాతా కాదు. దీనికి ముందుగా పబ్లిక్ లింక్ అవసరం (టెలిగ్రామ్ కొత్త వాటిని ప్రైవేట్‌గా చేస్తుంది). మీ npubని అక్కడ పోస్ట్ చేసి, సందేశ లింక్‌ను అతికించండి.';

  @override
  String get verifyConnectProofExplainerBluesky =>
      'పైన సైన్ ఇన్ చేసారా? ఇంకేమీ అవసరం లేదు. లేదంటే మీ npubని పోస్ట్ చేసి, ఆ పోస్ట్‌కి లింక్‌ను అతికించండి.';

  @override
  String get verifyConnectProofExplainerTiktok =>
      'మీ npubని వీడియో శీర్షికలో ఉంచండి, ఆపై ఆ వీడియోకి లింక్‌ను అతికించండి.';

  @override
  String get verifyConnectProofExplainerYoutube =>
      'మీ npubని వీడియో వివరణలో ఉంచండి, ఆపై ఆ వీడియోకి లింక్‌ను అతికించండి.';

  @override
  String verifyLinkedConfirmation(String platform) {
    return '$platformలింక్ చేయబడింది.';
  }

  @override
  String get verifyErrorTelegramNotPublic =>
      'అది ప్రైవేట్ ఛానెల్ లేదా ఆహ్వానం. ఛానెల్‌కు పబ్లిక్ లింక్‌ని అందించి, ఆపై సందేశ లింక్‌ను అతికించండి.';

  @override
  String get verifyErrorRemoveFailed =>
      '​​దాన్ని అన్‌లింక్ చేయడం సాధ్యపడలేదు. మళ్లీ ప్రయత్నించండి.';

  @override
  String get verifyErrorLinksUnreadable =>
      'మీ ప్రస్తుత లింక్‌లను చదవడం సాధ్యపడలేదు, కాబట్టి ఏమీ మార్చబడలేదు. మీ కనెక్షన్‌ని తనిఖీ చేసి, మళ్లీ ప్రయత్నించండి.';

  @override
  String get verifyChannelLabel => 'ఛానెల్ పేరు';

  @override
  String get verifyHowItWorksTitle => 'ఇది ఎలా పని చేస్తుంది?';

  @override
  String get verifyHowItWorksIntro =>
      'దీన్ని రెండు ఖాతాల మధ్య హ్యాండ్‌షేక్‌గా భావించండి:';

  @override
  String get verifyHowItWorksYourSide =>
      'మీ Divine ప్రొఫైల్ ఇలా చెబుతోంది: “Twitterలో నేను @alice.”';

  @override
  String get verifyHowItWorksOtherSide =>
      'మీ Twitter ఖాతా నిర్ధారిస్తుంది: “అవును, ఆ Divine ప్రొఫైల్ నాదే.”';

  @override
  String get verifyHowItWorksBothSides =>
      'మేము రెండు వైపులా తనిఖీ చేస్తాము. అవి సరిపోలితే, మీరు ధృవీకరించబడతారు. ఎవరూ దీన్ని నకిలీ చేయలేరు — ఎవరైనా మీ పేరు మరియు ఫోటోను కాపీ చేయవచ్చు, కానీ వారు మీ నిజమైన ఖాతా నుండి పోస్ట్ చేయలేరు.';

  @override
  String get verifyHowItWorksOwnership =>
      'లింక్‌లు మీ స్వంత Nostr గుర్తింపుపై ఆధారపడి ఉంటాయి, కాబట్టి మీకు కావలసినప్పుడు వాటిలో దేనినైనా ఇక్కడ తీసివేయవచ్చు.';

  @override
  String get generalSettingsSectionIdentity => 'గుర్తింపు';

  @override
  String get libraryFilterAll => 'అన్నీ';

  @override
  String get libraryFilterArchive => 'ఆర్కైవ్';

  @override
  String get libraryFilterDeleted => 'తొలగించబడింది';

  @override
  String get libraryCategoryNewChipLabel => 'కొత్తది';

  @override
  String get libraryCategoryCreateSemanticLabel => 'వర్గాన్ని సృష్టించండి';

  @override
  String get libraryCategoryCreateTitle => 'కొత్త వర్గం';

  @override
  String get libraryCategoryCreateAction => 'సృష్టించు';

  @override
  String get libraryCategoryRenameTitle => 'వర్గం పేరు మార్చండి';

  @override
  String get libraryCategoryRenameAction => 'పేరు మార్చండి';

  @override
  String get libraryCategoryDeleteAction => 'వర్గాన్ని తొలగించండి';

  @override
  String get libraryCategoryNameLabel => 'వర్గం పేరు';

  @override
  String libraryCategoryDeleteConfirmTitle(String name) {
    return 'తొలగించు \"$name”?';
  }

  @override
  String get libraryCategoryDeleteConfirmMessage =>
      'మీ క్లిప్‌లు అలాగే ఉంటాయి. వారు కేవలం అన్నింటికి తిరిగి వెళతారు.';

  @override
  String get libraryCategoryManageSemanticLabel =>
      'ఈ వర్గం పేరు మార్చండి లేదా తొలగించండి';

  @override
  String get libraryCategoryMoveTitle => 'ఇక్కడికి తరలించండి';

  @override
  String get libraryCategoryMoveNone => 'వర్గం లేదు';

  @override
  String get libraryCategoryMoveNewCategory => 'కొత్త వర్గం';

  @override
  String get libraryArchiveAction => 'ఆర్కైవ్';

  @override
  String get libraryUnarchiveAction => 'అన్‌ఆర్కైవ్';

  @override
  String libraryArchiveKeepCategoryTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ఈ వర్గాల్లో ఉంచాలా?',
      one: 'ఈ వర్గంలో ఉంచాలా?',
    );
    return '$_temp0';
  }

  @override
  String libraryArchiveKeepCategoryAction(String name) {
    return 'లోపల ఉంచండి $name';
  }

  @override
  String get libraryArchiveKeepCategoryActionMixed => 'వారి వర్గాల్లో ఉంచండి';

  @override
  String libraryArchiveRemoveCategoryAction(String name) {
    return 'నుండి తీసివేయండి $name';
  }

  @override
  String get libraryArchiveRemoveCategoryActionMixed =>
      'వారి వర్గాల నుండి తీసివేయండి';

  @override
  String get libraryMoveSelectedClipsTooltip =>
      'ఎంచుకున్న క్లిప్‌లను తరలించండి';

  @override
  String get libraryCategoryEmptyTitle => 'ఇక్కడ ఇంకా ఏదీ ఫైల్ చేయలేదు';

  @override
  String get libraryCategoryEmptySubtitle =>
      'కొన్ని క్లిప్‌లను ఎంచుకుని, వాటిని ఈ వర్గంలోకి తరలించండి.';

  @override
  String get libraryArchiveEmptyTitle => 'ఏదీ ఆర్కైవ్ చేయబడలేదు';

  @override
  String get libraryArchiveEmptySubtitle =>
      'ఆర్కైవ్ చేసిన క్లిప్‌లు మీ ప్రధాన లైబ్రరీకి దూరంగా ఇక్కడ వేచి ఉన్నాయి.';

  @override
  String libraryClipsMovedToCategory(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countక్లిప్‌లు దీనికి తరలించబడ్డాయి $name',
      one: '1 క్లిప్ దీనికి తరలించబడింది $name',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsRemovedFromCategory(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countక్లిప్‌లు వాటి వర్గం నుండి తీసివేయబడ్డాయి',
      one: '1 క్లిప్ దాని వర్గం నుండి తీసివేయబడింది',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsArchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countక్లిప్‌లు ఆర్కైవ్ చేయబడ్డాయి',
      one: '1 క్లిప్ ఆర్కైవ్ చేయబడింది',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsUnarchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countక్లిప్‌లు మీ లైబ్రరీలో తిరిగి వచ్చాయి',
      one: '1 క్లిప్ మీ లైబ్రరీలో తిరిగి వచ్చింది',
    );
    return '$_temp0';
  }

  @override
  String get accountSettingsChangeEmail => 'ఇమెయిల్ మార్చండి';

  @override
  String get accountSettingsChangeEmailSubtitle =>
      'మీ ఖాతాను వేరే చిరునామాకు తరలించండి';

  @override
  String get accountSettingsChangePassword => 'పాస్‌వర్డ్ మార్చండి';

  @override
  String get accountSettingsChangePasswordSubtitle =>
      'సైన్ ఇన్ చేయడానికి కొత్త పాస్‌వర్డ్‌ని ఎంచుకోండి';

  @override
  String get accountCredentialsNeedsSignIn =>
      'మీ సెషన్ అయిపోయింది. ఈ మార్పు చేయడానికి మళ్లీ సైన్ ఇన్ చేయండి.';

  @override
  String get accountCredentialsRateLimited =>
      'చాలా ప్రయత్నాలు చేసారు. కొన్ని నిమిషాలు ఇవ్వండి.';

  @override
  String get accountCredentialsNetwork =>
      'Divineని చేరుకోలేకపోయింది. మీ కనెక్షన్‌ని తనిఖీ చేసి, మళ్లీ ప్రయత్నించండి.';

  @override
  String get accountCredentialsUnknown =>
      'అది పని చేయలేదు. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get changePasswordSubtitle =>
      'మీ ప్రస్తుత పాస్‌వర్డ్‌ని టైప్ చేసి, ఆపై కొత్తదాన్ని ఎంచుకోండి.';

  @override
  String get changePasswordCurrentLabel => 'ప్రస్తుత పాస్‌వర్డ్';

  @override
  String get changePasswordWrongCurrent => 'అది మీ ప్రస్తుత పాస్‌వర్డ్ కాదు.';

  @override
  String get changePasswordSuccess => 'పాస్‌వర్డ్ మార్చబడింది.';

  @override
  String get changeEmailSubtitle =>
      'మేము మీ కొత్త చిరునామాకు మరియు మీ ఖాతాలో ఉన్నదానికి నిర్ధారణ లింక్‌ను ఇమెయిల్ చేస్తాము. మీరు రెండింటి నుండి నిర్ధారించిన తర్వాత మీ ఇమెయిల్ మారుతుంది.';

  @override
  String changeEmailCurrentAddress(String email) {
    return 'మీ ఖాతాలో: $email';
  }

  @override
  String get changeEmailNewLabel => 'కొత్త ఇమెయిల్';

  @override
  String get changeEmailPasswordLabel => 'మీ పాస్‌వర్డ్';

  @override
  String get changeEmailSameAsCurrent => 'ఇది ఇప్పటికే మీ ఇమెయిల్ చిరునామా.';

  @override
  String get changeEmailWrongPassword => 'అది మీ పాస్‌వర్డ్ కాదు.';

  @override
  String get changeEmailSubmit => 'నిర్ధారణ లింక్‌లను పంపండి';

  @override
  String get changeEmailSentTitle => 'రెండు లింక్‌లు అందుబాటులో ఉన్నాయి';

  @override
  String changeEmailSentMessage(String email) {
    return 'నుండి నిర్ధారించండి $emailమరియు మీ ఖాతాలోని చిరునామా నుండి. రెండూ పూర్తయిన తర్వాత మీ ఇమెయిల్ స్విచ్ అవుతుంది.';
  }

  @override
  String get changeEmailSentExpiry =>
      'లింక్‌లు 24 గంటల తర్వాత పని చేయడం ఆగిపోతాయి.';

  @override
  String get changeEmailSentDone => 'అర్థమైంది';

  @override
  String searchUserVideoCount(int count, String formattedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formattedCountవీడియోలు',
      one: '$formattedCountవీడియో',
    );
    return '$_temp0';
  }

  @override
  String get socialProofMutual => 'పరస్పరం';

  @override
  String get socialProofFollowsYou => 'మిమ్మల్ని అనుసరిస్తున్నారు';

  @override
  String get socialProofYouFollow => 'మీరు అనుసరించండి';

  @override
  String socialProofFollowerCount(int count, String formattedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formattedCountఅనుచరులు',
      one: '$formattedCountఅనుచరుడు',
    );
    return '$_temp0';
  }

  @override
  String get feedOutageMessage => 'వీడియోలు ప్రస్తుతం లోడ్ కావడం లేదు.';

  @override
  String get feedOfflineMessage =>
      'మీరు ఆఫ్‌లైన్‌లో ఉన్నారు.\nమీ కనెక్షన్‌ని తనిఖీ చేసి, మళ్లీ ప్రయత్నించండి.';

  @override
  String get dbFailureTitle => 'మీ స్థానిక డేటాబేస్‌ని అన్‌లాక్ చేయలేకపోయింది';

  @override
  String get dbFailureAdviceResettable =>
      'పునఃప్రారంభం దీనిని పరిష్కరించదు. దిగువ స్థానిక డేటాబేస్‌ని రీసెట్ చేయడం వలన Divine క్లీన్ స్టార్ట్ అవుతుంది — మీ ఖాతా అలాగే ఉంటుంది.';

  @override
  String get dbFailureAdviceRestart =>
      'మీ పరికరాన్ని అన్‌లాక్ చేసిన తర్వాత Divineని పునఃప్రారంభించండి. ఇలాగే జరుగుతూ ఉంటే, యాప్‌ని అప్‌డేట్ చేయండి లేదా సపోర్ట్‌ని సంప్రదించండి.';

  @override
  String get dbFailureAdviceHotJournal =>
      'Divineని ఒకసారి పునఃప్రారంభించి చూడండి. ఇది కొనసాగితే, యాప్‌ని అప్‌డేట్ చేయండి లేదా సపోర్ట్‌ని సంప్రదించండి. మీ స్థానిక డేటా ఇంకా భద్రంగా ఉంది.';

  @override
  String dbFailureDiagnostic(String code) {
    return 'డయాగ్నోస్టిక్: $code';
  }

  @override
  String get dbFailureCloseApp => 'మూసివేయండి Divine';

  @override
  String get dbFailureResetAction => 'స్థానిక డేటాబేస్ రీసెట్ చేయండి';

  @override
  String get dbFailureConfirmTitle => 'మీ స్థానిక డేటాబేస్‌ని రీసెట్ చేయాలా?';

  @override
  String get dbFailureConfirmBody =>
      'మీ ఖాతా అలాగే ఉంటుంది. ఈ పరికరంలో సేవ్ చేయబడిన చిత్తుప్రతులు మరియు క్లిప్‌లు తొలగించబడతాయి - సందేశాలు మరియు ఫీడ్‌లు నెట్‌వర్క్ నుండి తిరిగి వస్తాయి.';

  @override
  String get dbFailureResetConfirm =>
      'ఇప్పుడు స్థానిక డేటాబేస్‌ని రీసెట్ చేయండి';

  @override
  String get dbFailureCancel => 'రద్దు';

  @override
  String get dbFailureResetFailed =>
      'అది పని చేయలేదు. Divineని మూసివేసి, మళ్లీ ప్రయత్నించండి.';

  @override
  String get dbFailureResetDoneTitle => 'స్థానిక డేటాబేస్ రీసెట్';

  @override
  String get dbFailureResetDoneBody =>
      'Divineని మూసివేసి, దాన్ని మళ్లీ తెరవండి — తదుపరి ప్రయోగం తాజా స్థానిక డేటాబేస్‌ను రూపొందిస్తుంది.';

  @override
  String get authSignInOptionsInfo => 'సైన్-ఇన్ ఎంపికల గురించి';

  @override
  String get authShowPassword => 'పాస్‌వర్డ్ చూపించు';

  @override
  String get authHidePassword => 'పాస్‌వర్డ్‌ను దాచండి';

  @override
  String get followUserSemanticLabel => 'వినియోగదారుని అనుసరించండి';

  @override
  String get unfollowUserSemanticLabel => 'వినియోగదారుని అనుసరించవద్దు';

  @override
  String get commentsLoadingSemanticLabel => 'వ్యాఖ్యలు లోడ్ అవుతోంది';

  @override
  String get analyticsWindowAll => 'అన్నీ';

  @override
  String followUserIndexedSemanticLabel(String index) {
    return 'వినియోగదారుని అనుసరించండి $index';
  }

  @override
  String unfollowUserIndexedSemanticLabel(String index) {
    return 'వినియోగదారుని అనుసరించవద్దు $index';
  }

  @override
  String supporterTierMonthlyLabel(String title, String price) {
    return '$title — $price/ నెల';
  }

  @override
  String get videoDetailHiddenBySettingsTitle =>
      'మీ సెట్టింగ్‌ల ద్వారా దాచబడింది';

  @override
  String videoDetailHiddenByHostFilterBody(String host) {
    return 'ఇది హోస్ట్ చేయబడింది $host, మరియు మీరు Divine-హోస్ట్ చేసిన వీడియోలను మాత్రమే చూపించడానికి సెట్ చేసారు.';
  }

  @override
  String get videoDetailHiddenByContentFilterBody =>
      'మీ కంటెంట్ ఫిల్టర్‌లు దీన్ని దాచిపెడుతున్నాయి.';

  @override
  String get videoDetailHiddenByProvenanceFilterBody =>
      'దీనిలో కెమెరాకు తిరిగి క్యాప్చర్ చైన్ లేదు మరియు మీరు కెమెరా-ధృవీకరించబడిన వీడియోలను మాత్రమే చూపించడానికి సెట్ చేసారు.';

  @override
  String get videoDetailHiddenShowAnyway => 'దీన్ని ఏమైనప్పటికీ చూపించు';

  @override
  String get videoDetailHiddenOpenSettings => 'సెట్టింగ్‌ని మార్చండి';

  @override
  String get safetySettingsShowVerifiedOnly =>
      'కెమెరా-ధృవీకరించబడిన వీడియోలను మాత్రమే చూపండి';

  @override
  String get safetySettingsShowVerifiedOnlySubtitle =>
      'కెమెరాకు తిరిగి క్యాప్చర్ చైన్ లేకుండా వీడియోలను దాచండి. Vine ఆర్కైవ్ వీడియోలు ఎల్లప్పుడూ చూపబడతాయి.';

  @override
  String get accountStatusTitle => 'ఖాతా స్థితి';

  @override
  String get accountStatusTileSubtitleRestricted => 'మీ ఖాతా పరిమితం చేయబడింది';

  @override
  String get accountStatusAllClearHeading => 'అంతా బాగానే ఉంది!';

  @override
  String get profileAccountRestricted => 'ఖాతా పరిమితం చేయబడింది';

  @override
  String get accountStatusSuspendedHeading =>
      'మీ ఖాతా తాత్కాలికంగా నిలిపివేయబడింది';

  @override
  String get accountStatusSuspendedBody =>
      'మీరు ప్రస్తుతం Divineలో పోస్ట్ చేయలేరు, వ్యాఖ్యానించలేరు లేదా సందేశాలను పంపలేరు. మీ వీడియోలు తొలగించబడకుండా దాచబడ్డాయి మరియు సస్పెన్షన్ ఎత్తివేయబడినట్లయితే అవి తిరిగి వస్తాయి.';

  @override
  String get accountStatusBannedHeading => 'మీ ఖాతా నిషేధించబడింది';

  @override
  String get accountStatusBannedBody =>
      'మీరు Divineలో పోస్ట్ చేయలేరు, వ్యాఖ్యానించలేరు లేదా సందేశాలను పంపలేరు మరియు మీ వీడియోలు Divine నుండి తీసివేయబడ్డాయి.';

  @override
  String get accountStatusRestrictedHeading => 'మీ ఖాతా పరిమితం చేయబడింది';

  @override
  String get accountStatusRestrictedBody =>
      'మీరు సాధారణంగా Divineలో చేయగలిగే కొన్ని పనులు ప్రస్తుతం అందుబాటులో లేవు. యాప్‌ను అప్‌డేట్ చేయడం వలన మీకు మరింత వివరాలు చూపవచ్చు.';

  @override
  String get accountStatusLastKnownBody =>
      'మేము మీ స్థితిని రిఫ్రెష్ చేయలేకపోయాము. ఇదే మాకు చివరి హోదా.';

  @override
  String get accountStatusUnavailableHeading =>
      'మేము మీ స్థితిని తనిఖీ చేయలేకపోయాము';

  @override
  String get accountStatusUnavailableBody =>
      'మీ కనెక్షన్‌ని తనిఖీ చేసి, మళ్లీ ప్రయత్నించండి.';

  @override
  String get accountStatusSignedOutHeading =>
      'మీ ఖాతా స్థితిని తనిఖీ చేయడానికి సైన్ ఇన్ చేయండి';

  @override
  String get accountStatusSignedOutBody =>
      'ప్రస్తుతం తనిఖీ చేయడానికి సైన్ ఇన్ చేసిన ఖాతా లేదు.';

  @override
  String get accountStatusKeysUnaffectedHeading =>
      'మీ ఖాతా ఇప్పటికీ మీకు చెందుతుంది';

  @override
  String get accountStatusKeysUnaffectedBody =>
      'ఈ పరిమితి Divineకి వర్తిస్తుంది. మీ కీలు మరియు మీ గుర్తింపు మీదే, మీ అనుచరులు వారితో పాటు ప్రయాణిస్తారు మరియు మీరు వాటిని Divine అమలు చేయని ఇతర యాప్‌లు మరియు సర్వర్‌లలో ఉపయోగించడం కొనసాగించవచ్చు.';

  @override
  String get accountStatusAppealHeading => 'ఇది తప్పు అని మీరు అనుకుంటే';

  @override
  String get accountStatusAppealBody =>
      'Divine నియంత్రణ నిర్ణయాన్ని పునఃపరిశీలించడానికి అభ్యర్థనలను సమీక్షించవచ్చు, కానీ బాధ్యత వహించదు. మీరు దీన్ని పెంచాలనుకుంటే, మద్దతును సంప్రదించండి మరియు ఏమి జరిగిందో మాకు చెప్పండి.';

  @override
  String get accountStatusContactSupport => 'మద్దతును సంప్రదించండి';

  @override
  String get accountStatusMoveAccount => 'మీ ఖాతాను తరలించండి';

  @override
  String get accountStatusRetry => 'మళ్లీ ప్రయత్నించండి';

  @override
  String get updateGentleBanner => 'కొత్త అప్‌డేట్ వచ్చింది. చూడండి →';

  @override
  String get updateModerateTitle =>
      'మీరు చివరిసారి చూసిన తర్వాత ఒక అప్‌డేట్ వచ్చింది';

  @override
  String get updateUrgentTitle => 'మీకు ముఖ్యమైన పరిష్కారాలు అందడం లేదు';

  @override
  String get updateNotNow => 'ఇప్పుడు వద్దు';

  @override
  String get updateAction => 'అప్‌డేట్ చేయండి';

  @override
  String updateNewIn(String version) {
    return '$versionలో కొత్తవి:';
  }

  @override
  String get settingsUpdateAvailable => 'అప్‌డేట్ అందుబాటులో ఉంది';
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Malay (`ms`).
class AppLocalizationsMs extends AppLocalizations {
  AppLocalizationsMs([String locale = 'ms']) : super(locale);

  @override
  String get devOptionsClipRecovery => 'Pemulihan klip';

  @override
  String get devOptionsClipRecoveryDescription =>
      'Mencari rakaman yang disimpan di bawah akaun lain dan fail video yang tidak lagi dirujuk oleh mana-mana entri.';

  @override
  String get devOptionsClipRecoveryScan => 'Imbas';

  @override
  String get devOptionsClipRecoveryFailure => 'Pemulihan klip gagal';

  @override
  String devOptionsClipRecoveryVisible(int clips, int drafts) {
    return 'Kelihatan sekarang: $clips klip, $drafts draf';
  }

  @override
  String get devOptionsClipRecoveryOtherAccounts =>
      'Tersembunyi di bawah akaun lain';

  @override
  String devOptionsClipRecoveryCounts(int clips, int drafts) {
    return '$clips klip, $drafts draf';
  }

  @override
  String get devOptionsClipRecoveryClaim => 'Alih ke akaun ini';

  @override
  String devOptionsClipRecoveryOrphanFiles(int count, String size) {
    return 'Fail tanpa rujukan: $count ($size)';
  }

  @override
  String get devOptionsClipRecoveryImport => 'Bina semula dalam pustaka';

  @override
  String get devOptionsClipRecoveryEmpty => 'Tiada apa-apa untuk dipulihkan';

  @override
  String devOptionsClipRecoveryRecovered(int count) {
    return '$count klip dipulihkan';
  }

  @override
  String get devOptionsClipRecoveryCopied => 'Laporan pemulihan disalin';

  @override
  String get devOptionsStorageFootprint => 'Penggunaan storan';

  @override
  String get devOptionsStorageFootprintDescription =>
      'Setiap folder yang ditulis oleh apl. Mengosongkan cache hanya membebaskan sebahagian daripadanya.';

  @override
  String get devOptionsStorageFootprintMeasure => 'Ukur';

  @override
  String devOptionsStorageFootprintTotal(String size) {
    return 'Jumlah: $size';
  }

  @override
  String get devOptionsStorageFootprintCopied => 'Laporan storan disalin';

  @override
  String get devOptionsStorageFootprintFailure => 'Storan tidak dapat diukur';

  @override
  String get feedTuningMoreLabel => 'Lebih banyak seperti ini';

  @override
  String get feedTuningLessLabel => 'Kurang seperti ini';

  @override
  String get feedTuningUndo => 'Buat Asal';

  @override
  String get dmMessageBubbleVideoReplyHint => 'Buka video yang dirujuk';

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => 'Tetapan';

  @override
  String get settingsSecureAccount => 'Selamatkan Akaun Anda';

  @override
  String get settingsSessionExpired => 'Sesi Tamat Tempoh';

  @override
  String get settingsSessionExpiredSubtitle =>
      'Log masuk semula untuk memulihkan akses penuh';

  @override
  String get settingsAccountRestoreFailed => 'Account Restore Failed';

  @override
  String get settingsAccountRestoreFailedSwitchMessage =>
      'We couldn\'t unlock that account on this device. Signing back into it means signing out of the one you\'re on now.';

  @override
  String get settingsCreatorAnalytics => 'Analitik Pencipta';

  @override
  String get settingsSupportCenter => 'Pusat Sokongan';

  @override
  String get settingsNotifications => 'Pemberitahuan';

  @override
  String get settingsBlueskyPublishing => 'Penerbitan Bluesky';

  @override
  String get settingsBlueskyPublishingSubtitle =>
      'Urus siaran silang ke Bluesky';

  @override
  String get settingsNostrSettings => 'Tetapan Nostr';

  @override
  String get settingsIntegratedApps => 'Apl Bersepadu';

  @override
  String get settingsIntegratedAppsSubtitle =>
      'Apl pihak ketiga yang diluluskan dan berjalan dalam Divine';

  @override
  String get settingsExperimentalFeatures => 'Ciri Eksperimen';

  @override
  String get settingsExperimentalFeaturesSubtitle =>
      'Ubahan yang mungkin tersandung—cubalah kalau anda ingin tahu.';

  @override
  String get settingsLegal => 'Undang-undang';

  @override
  String get settingsIntegrationPermissions => 'Kebenaran Integrasi';

  @override
  String get settingsIntegrationPermissionsSubtitle =>
      'Semak dan batalkan kelulusan integrasi yang diingati';

  @override
  String settingsVersion(String version) {
    return 'Versi $version';
  }

  @override
  String get settingsVersionEmpty => 'Versi';

  @override
  String get settingsDeveloperModeAlreadyEnabled =>
      'Mod pembangun sudah didayakan';

  @override
  String get settingsDeveloperModeEnabled => 'Mod pembangun didayakan!';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    return '$count ketikan lagi untuk mendayakan mod pembangun';
  }

  @override
  String get settingsShareDivine => 'Kongsi Divine dengan rakan anda';

  @override
  String get settingsSwitchAccount => 'Tukar akaun';

  @override
  String get settingsAddAnotherAccount => 'Tambah akaun lain';

  @override
  String get settingsAccountSwitchFailed =>
      'Tidak dapat menukar akaun. Sila cuba lagi.';

  @override
  String get settingsUnsavedDraftsTitle => 'Draf Belum Disimpan';

  @override
  String get settingsUploadInProgressTitle => 'Muat naik sedang berjalan';

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
      other: 'video anda kekal sebagai draf',
      one: 'video anda kekal sebagai draf',
    );
    return 'Anda masih mempunyai $count $_temp0 sedang dimuat naik. Menukar akaun akan menghentikan muat naik — $_temp1 dalam akaun ini.';
  }

  @override
  String settingsUnsavedDraftsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'draf',
      one: 'draf',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'draf',
      one: 'draf',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'draf itu',
      one: 'draf itu',
    );
    return 'Anda mempunyai $count $_temp0 belum disimpan. Menukar akaun akan menyimpan $_temp1 anda, tetapi anda mungkin mahu menerbitkan atau menyemak $_temp2 dahulu.';
  }

  @override
  String get settingsCancel => 'Batal';

  @override
  String get settingsSwitchAnyway => 'Tukar Juga';

  @override
  String get settingsSessionExpiredSwitchMessage =>
      'Sesi akaun itu telah tamat. Log masuk semula ke sana bermakna anda log keluar daripada akaun yang anda guna sekarang.';

  @override
  String get settingsAppVersionLabel => 'Versi apl';

  @override
  String get settingsAppLanguage => 'Bahasa Aplikasi';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language (lalai peranti)';
  }

  @override
  String get settingsAppLanguageTitle => 'Bahasa aplikasi';

  @override
  String get settingsAppLanguageDescription =>
      'Pilih bahasa untuk antara muka apl';

  @override
  String get settingsAppLanguageUseDeviceLanguage => 'Guna bahasa peranti';

  @override
  String get settingsGeneralTitle => 'Tetapan Umum';

  @override
  String get settingsContentSafetyTitle => 'Kandungan & Keselamatan';

  @override
  String get generalSettingsSectionIntegrations => 'INTEGRASI';

  @override
  String get generalSettingsSectionViewing => 'TONTONAN';

  @override
  String get generalSettingsSectionCreating => 'PENCIPTAAN';

  @override
  String get generalSettingsSectionApp => 'APLIKASI';

  @override
  String get appearanceSettingsTitle => 'Rupa';

  @override
  String get appearanceSettingsSubtitle => 'Pilih rupa Divine pada peranti ini';

  @override
  String get appearanceSettingsSystem => 'Lalai sistem';

  @override
  String get appearanceSettingsLight => 'Cerah';

  @override
  String get appearanceSettingsDark => 'Gelap';

  @override
  String get generalSettingsClosedCaptions => 'Sarikata Tertutup';

  @override
  String get generalSettingsClosedCaptionsSubtitle =>
      'Papar sarikata apabila video menyertainya';

  @override
  String get generalSettingsVideoShapeSquareOnly => 'Video segi empat sahaja';

  @override
  String get generalSettingsVideoShapeSquareOnlySubtitle =>
      'Kekalkan suapan dalam format segi empat klasik';

  @override
  String get contentPreferencesTitle => 'Keutamaan Kandungan';

  @override
  String get contentPreferencesContentFilters => 'Penapis Kandungan';

  @override
  String get contentPreferencesContentFiltersSubtitle =>
      'Urus penapis amaran kandungan';

  @override
  String get contentPreferencesContentLanguage => 'Bahasa Kandungan';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language (lalai peranti)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      'Tag video anda dengan bahasa supaya penonton boleh menapis kandungan.';

  @override
  String get contentPreferencesUseDeviceLanguage =>
      'Guna bahasa peranti (lalai)';

  @override
  String get contentPreferencesAudioSharing =>
      'Benarkan audio saya digunakan semula';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      'Apabila didayakan, orang lain boleh menggunakan audio daripada video anda';

  @override
  String get contentPreferencesMusicMode => 'Mod muzik';

  @override
  String get contentPreferencesMusicModeSubtitle =>
      'Melangkau pembersihan hingar yang memampatkan bunyi alat muzik. Lebih baik untuk muzik, lebih kasar untuk suara.';

  @override
  String get contentPreferencesAccountLabels => 'Label Akaun';

  @override
  String get contentPreferencesAccountLabelsEmpty =>
      'Labelkan kandungan anda sendiri';

  @override
  String get contentPreferencesAccountContentLabels => 'Label Kandungan Akaun';

  @override
  String get contentPreferencesClearAll => 'Kosongkan Semua';

  @override
  String get contentPreferencesSelectAllThatApply =>
      'Pilih semua yang berkaitan dengan akaun anda';

  @override
  String get contentPreferencesDoneNoLabels => 'Siap (Tiada Label)';

  @override
  String contentPreferencesDoneCount(int count) {
    return 'Siap ($count dipilih)';
  }

  @override
  String get contentPreferencesAudioInputDevice => 'Peranti Input Audio';

  @override
  String get contentPreferencesAutoRecommended => 'Auto (disyorkan)';

  @override
  String get contentPreferencesAutoSelectsBest =>
      'Memilih mikrofon terbaik secara automatik';

  @override
  String get contentPreferencesSelectAudioInput => 'Pilih Input Audio';

  @override
  String get contentPreferencesUnknownMicrophone => 'Mikrofon Tidak Diketahui';

  @override
  String get contentFiltersAdultContent => 'KANDUNGAN DEWASA';

  @override
  String get contentFiltersViolenceGore => 'KEGANASAN & KEKEJAMAN';

  @override
  String get contentFiltersSubstances => 'BAHAN TERKAWAL';

  @override
  String get contentFiltersOther => 'LAIN-LAIN';

  @override
  String get contentFiltersAgeGateMessage =>
      'Sahkan umur anda dalam tetapan Keselamatan & Privasi untuk membuka kunci penapis kandungan dewasa';

  @override
  String get contentFiltersShow => 'Tunjuk';

  @override
  String get contentFiltersWarn => 'Amaran';

  @override
  String get contentFiltersFilterOut => 'Tapis Keluar';

  @override
  String get profileBlockedAccountNotAvailable => 'Akaun ini tidak tersedia';

  @override
  String get profileInvalidId => 'ID profil tidak sah';

  @override
  String profileShareText(String displayName, String npub) {
    return 'Lihat $displayName di Divine!\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return '$displayName di Divine';
  }

  @override
  String get profileShareFailed => 'Gagal berkongsi profil. Sila cuba lagi.';

  @override
  String get profileCopyPublicKey => 'Salin kunci awam (npub)';

  @override
  String get profileGetEmbedCode => 'Dapatkan kod terbenam';

  @override
  String get profilePublicKeyCopied => 'Kunci awam disalin ke papan klip';

  @override
  String get profileEmbedCodeCopied => 'Kod terbenam disalin ke papan klip';

  @override
  String get profileMoreTooltip => 'Lagi';

  @override
  String get profileMoreSemanticLabel => 'Lagi pilihan';

  @override
  String get profileAvatarLightboxBarrierLabel => 'Tutup avatar';

  @override
  String get profileAvatarLightboxCloseSemanticLabel =>
      'Tutup pratonton avatar';

  @override
  String get profileFollowingLabel => 'Mengikuti';

  @override
  String get profileFollowLabel => 'Ikut';

  @override
  String get profileBlockedLabel => 'Disekat';

  @override
  String get profileFollowersLabel => 'Pengikut';

  @override
  String get profileFollowingStatLabel => 'Mengikuti';

  @override
  String get profileVideosLabel => 'Video';

  @override
  String get profileCollabsLabel => 'Kolaborasi';

  @override
  String get profileLikedLabel => 'Disukai';

  @override
  String get profileRepostsLabel => 'Siaran Semula';

  @override
  String get profileListsLabel => 'Senarai';

  @override
  String get profileCommentsLabel => 'Komen';

  @override
  String profileCollaboratorInvitePendingHeadline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jemputan kolaborator masih perlu dihantar',
      one: '1 jemputan kolaborator masih perlu dihantar',
    );
    return '$_temp0';
  }

  @override
  String get profileCollaboratorInvitePendingDetail =>
      'Kami mengekalkan jemputan dalam baris gilir. Cuba semula di sini.';

  @override
  String profileCollaboratorInvitePendingDetailWithTitle(String title) {
    return 'Untuk \"$title\". Cuba semula di sini.';
  }

  @override
  String get profileCollaboratorInviteRetryAction => 'Cuba Semula';

  @override
  String get profileCollaboratorInviteRetryingAction => 'Sedang mencuba semula';

  @override
  String get profileCollaboratorInviteRetryUnavailable =>
      'Cubaan semula jemputan kolaborator tidak tersedia sekarang.';

  @override
  String profileCollaboratorInviteRetryResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jemputan kolaborator masih perlu dihantar.',
      one: '1 jemputan kolaborator masih perlu dihantar.',
      zero: 'Jemputan kolaborator dihantar.',
    );
    return '$_temp0';
  }

  @override
  String profileCollaboratorInviteBlockedResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kolaborator tidak dapat menerima jemputan.',
      one: '1 kolaborator tidak dapat menerima jemputan.',
    );
    return '$_temp0';
  }

  @override
  String profileFollowerCountUsers(int count) {
    return '$count pengguna';
  }

  @override
  String profileBlockTitle(String displayName) {
    return 'Sekat $displayName?';
  }

  @override
  String get profileBlockExplanation => 'Apabila anda menyekat pengguna:';

  @override
  String get profileBlockBulletHidePosts =>
      'Siaran mereka tidak akan muncul dalam suapan anda.';

  @override
  String get profileBlockBulletCantView =>
      'Mereka tidak akan dapat melihat profil anda, mengikuti anda, atau melihat siaran anda.';

  @override
  String get profileBlockBulletNoNotify =>
      'Mereka tidak akan diberitahu tentang perubahan ini.';

  @override
  String get profileBlockBulletYouCanView =>
      'Anda masih boleh melihat profil mereka.';

  @override
  String profileBlockConfirmButton(String displayName) {
    return 'Sekat $displayName';
  }

  @override
  String get profileCancelButton => 'Batal';

  @override
  String get profileLearnMore => 'Ketahui Lebih Lanjut';

  @override
  String profileUnblockTitle(String displayName) {
    return 'Nyahsekat $displayName?';
  }

  @override
  String get profileUnblockExplanation =>
      'Apabila anda menyahsekat pengguna ini:';

  @override
  String get profileUnblockBulletShowPosts =>
      'Siaran mereka akan muncul dalam suapan anda.';

  @override
  String get profileUnblockBulletCanView =>
      'Mereka akan dapat melihat profil anda, mengikuti anda, dan melihat siaran anda.';

  @override
  String get profileUnblockBulletNoNotify =>
      'Mereka tidak akan diberitahu tentang perubahan ini.';

  @override
  String get profileLearnMoreAt => 'Ketahui lebih lanjut di ';

  @override
  String get profileUnblockButton => 'Nyahsekat';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return 'Nyahikut $displayName';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return 'Sekat $displayName';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return 'Nyahsekat $displayName';
  }

  @override
  String profileReportDisplayName(String displayName) {
    return 'Laporkan $displayName';
  }

  @override
  String profileAddToListDisplayName(String displayName) {
    return 'Tambah $displayName ke senarai';
  }

  @override
  String get profileNoCollabsTitle => 'Belum ada kolab';

  @override
  String get profileCollabsOwnEmpty =>
      'Video yang anda kolaborasi akan muncul di sini.';

  @override
  String get profileCollabsOtherEmpty =>
      'Video yang mereka kolaborasi akan muncul di sini.';

  @override
  String get profileErrorLoadingCollabs => 'Ralat memuatkan video kolab';

  @override
  String get profileNoSavedVideosTitle => 'Belum ada yang disimpan';

  @override
  String get profileSavedOwnEmpty =>
      'Tandakan video daripada helaian kongsi dan ia akan muncul di sini.';

  @override
  String get profileErrorLoadingSaved => 'Ralat memuatkan video disimpan';

  @override
  String get profileNoCommentsOwnTitle => 'Belum ada komen';

  @override
  String get profileNoCommentsOtherTitle => 'Belum ada komen';

  @override
  String get profileCommentsOwnEmpty =>
      'Komen dan balasan anda akan muncul di sini.';

  @override
  String get profileCommentsOtherEmpty =>
      'Komen dan balasan mereka akan muncul di sini.';

  @override
  String get profileErrorLoadingComments => 'Ralat memuatkan komen';

  @override
  String get profileVideoRepliesSection => 'Balasan Video';

  @override
  String get profileCommentsSection => 'Komen';

  @override
  String get profileEditLabel => 'Sunting';

  @override
  String get profileLibraryLabel => 'Pustaka';

  @override
  String get profileNoLikedVideosTitle => 'Belum ada sukaan';

  @override
  String get profileLikedOwnEmpty =>
      'Apabila sesuatu menarik perhatian anda, ketik hati itu. Sukaan anda akan muncul di sini.';

  @override
  String get profileLikedOtherEmpty =>
      'Belum ada yang menarik perhatian mereka. Beri sedikit masa.';

  @override
  String get profileErrorLoadingLiked => 'Ralat memuatkan video disukai';

  @override
  String get profileNoRepostsTitle => 'Belum ada siaran semula';

  @override
  String get profileRepostsOwnEmpty =>
      'Nampak sesuatu yang berbaloi untuk dikongsi? Siarkan semula dan ia akan muncul di sini.';

  @override
  String get profileRepostsOtherEmpty =>
      'Mereka belum mengongsikan apa-apa lagi. Apabila mereka berbuat demikian, ia akan muncul di sini.';

  @override
  String get profileErrorLoadingReposts =>
      'Ralat memuatkan video siaran semula';

  @override
  String get profileNoVideosTitle => 'Belum ada video';

  @override
  String get profileNoVideosOwnSubtitle =>
      'Pentas anda sudah sedia. Mula menyiarkan dan video anda akan berada di sini.';

  @override
  String get profileNoVideosOtherSubtitle =>
      'Dunia sedang menanti. Ikuti mereka supaya anda tidak terlepas.';

  @override
  String profileVideoThumbnailLabel(int number) {
    return 'Lakaran kecil video $number';
  }

  @override
  String get profileShowMore => 'Tunjuk lagi';

  @override
  String get profileShowLess => 'Tunjuk kurang';

  @override
  String get dmMessageDisplayLimitReached => 'Baki mesej ini tidak dipaparkan.';

  @override
  String get profileCompleteYourProfile => 'Lengkapkan Profil Anda';

  @override
  String get profileCompleteSubtitle =>
      'Tambah nama, bio dan gambar anda untuk bermula';

  @override
  String get profilePleaseTryAgain => 'Sila cuba lagi';

  @override
  String get profileSecureYourAccount => 'Selamatkan Akaun Anda';

  @override
  String get profileSecureSubtitle =>
      'Tambah e-mel & kata laluan untuk memulihkan akaun anda pada mana-mana peranti';

  @override
  String get profileRetryButton => 'Cuba Semula';

  @override
  String get profileSessionExpired => 'Sesi Tamat Tempoh';

  @override
  String get profileSignInToRestore =>
      'Log masuk semula untuk memulihkan akses penuh';

  @override
  String get profileSignInButton => 'Log masuk';

  @override
  String get profileMaybeLaterLabel => 'Mungkin Nanti';

  @override
  String get profileSecurePrimaryButton => 'Tambah E-mel & Kata Laluan';

  @override
  String get profileCompletePrimaryButton => 'Kemas Kini Profil Anda';

  @override
  String get profileLoopsLabel => 'Loop';

  @override
  String get profileLikesLabel => 'Sukaan';

  @override
  String get profileMyLibraryLabel => 'Pustaka Saya';

  @override
  String get profileMessageLabel => 'Mesej';

  @override
  String get profileShareLabel => 'Kongsi profil';

  @override
  String get profileDeletedAccountName => 'Akaun dipadam';

  @override
  String get inboxActionReportVanishedAccount => 'Laporkan akaun ini';

  @override
  String get inboxActionBlockVanishedAccount => 'Sekat akaun ini';

  @override
  String get inboxActionUnblockVanishedAccount => 'Nyahsekat akaun ini';

  @override
  String get inboxReportedVanishedAccount => 'Akaun ini dilaporkan';

  @override
  String get inboxBlockedVanishedAccount => 'Akaun ini disekat';

  @override
  String get inboxUnblockedVanishedAccount => 'Akaun ini dinyahsekat';

  @override
  String get inboxRemoveConfirmBodyVanishedAccount =>
      'Ini mengalih keluar perbualan daripada peti masuk anda. Jika dia menghantar mesej lagi, perbualan baharu akan bermula.';

  @override
  String get inboxConversationDeletedAccountSubtitle =>
      'Akaun ini telah dipadam';

  @override
  String get profileUserFallback => 'pengguna';

  @override
  String get profileLinkCopied => 'Pautan profil disalin';

  @override
  String get profileSetupEditProfileTitle => 'Sunting Profil';

  @override
  String get nostrSettingsNip05ProfileRequired =>
      'Sediakan profil anda sebelum menambah alamat NIP-05.';

  @override
  String get nostrSettingsNip05CreateProfileAction => 'Cipta profil';

  @override
  String get profileSetupBackLabel => 'Kembali';

  @override
  String get profileSetupAboutNostr => 'Perihal Nostr';

  @override
  String get profileSetupProfilePublished => 'Profil berjaya diterbitkan!';

  @override
  String get profileSetupUnsavedChangesTitle => 'Simpan perubahan?';

  @override
  String get profileSetupUnsavedChangesSubtitle =>
      'Simpan suntingan anda sebelum pergi, atau buang dan teruskan.';

  @override
  String get profileSetupUnsavedChangesSaveButton => 'Simpan perubahan';

  @override
  String get profileSetupUnsavedChangesDiscardButton => 'Buang perubahan';

  @override
  String get profileSetupUnsavedChangesKeepButton => 'Terus menyunting';

  @override
  String get profileSetupCreateNewProfile => 'Cipta profil baharu?';

  @override
  String get profileSetupNoExistingProfile =>
      'Kami tidak menemui profil sedia ada pada relay anda. Penerbitan akan mencipta profil baharu. Teruskan?';

  @override
  String get profileSetupPublishButton => 'Terbitkan';

  @override
  String get profileSetupUsernameTaken =>
      'Nama pengguna baru sahaja diambil. Sila pilih yang lain.';

  @override
  String get profileSetupClaimFailed =>
      'Gagal mengambil nama pengguna. Sila cuba lagi.';

  @override
  String get profileSetupPublishFailed =>
      'Gagal menerbitkan profil. Sila cuba lagi.';

  @override
  String get profileSetupNoRelaysConnected =>
      'Tidak dapat mencapai rangkaian. Semak sambungan anda dan cuba lagi.';

  @override
  String get profileSetupDisplayNameLabel => 'Nama Paparan';

  @override
  String get profileSetupDisplayNameRequired => 'Sila masukkan nama paparan';

  @override
  String get profileSetupBioLabel => 'Bio (Pilihan)';

  @override
  String get profileSetupWebsiteLabel => 'Laman Web (Pilihan)';

  @override
  String get profileSetupPublicKeyLabel => 'Kunci awam (npub)';

  @override
  String get profileSetupUsernameLabel => 'Nama Pengguna (Pilihan)';

  @override
  String get profileSetupUsernameHelper =>
      'Gunakan huruf, nombor atau tanda sempang. Nama pengguna anda menjadi alamat divine.video. Gunakan nama paparan untuk ruang atau simbol.';

  @override
  String get profileSetupSaveButton => 'Simpan';

  @override
  String get profileSetupSavingButton => 'Menyimpan...';

  @override
  String get profileSetupImageUrlTitle => 'Tambah URL imej';

  @override
  String get profileSetupImageSelectionFailed =>
      'Pemilihan imej gagal. Sila tampal URL imej di bawah.';

  @override
  String get profileSetupImagesTypeGroup => 'imej';

  @override
  String get cameraPickErrorPermissionDenied =>
      'Akses kamera dimatikan. Hidupkan dalam Tetapan untuk mengambil gambar.';

  @override
  String get cameraPickErrorPermissionRestricted =>
      'Akses kamera tidak dibenarkan pada peranti ini.';

  @override
  String get cameraPickErrorBusy =>
      'Pemilih sudah dibuka. Tutup dan cuba lagi.';

  @override
  String get cameraPickErrorGeneric => 'Gagal membuka kamera. Cuba lagi.';

  @override
  String get profileSetupGotItButton => 'Faham';

  @override
  String get profileSetupUploadFailedGeneric =>
      'Muat naik gagal. Sila cuba lagi nanti.';

  @override
  String get profileSetupUploadNetworkError =>
      'Ralat rangkaian: Sila semak sambungan internet anda dan cuba lagi.';

  @override
  String get profileSetupUploadAuthError =>
      'Ralat pengesahan: Sila cuba log keluar dan log masuk semula.';

  @override
  String get profileSetupUploadFileTooLarge =>
      'Fail terlalu besar: Sila pilih imej yang lebih kecil (maks 10MB).';

  @override
  String get profileSetupUploadServerError =>
      'Muat naik gagal. Pelayan kami tidak tersedia buat sementara. Sila cuba lagi sebentar nanti.';

  @override
  String get profileSetupBannerClearButton => 'Kosongkan sepanduk';

  @override
  String get profileSetupBannerChangeColor => 'Warna sepanduk';

  @override
  String get profileSetupChangeBannerTitle => 'Tukar sepanduk';

  @override
  String get profileSetupBannerColorPickerTitle => 'Tukar warna sepanduk';

  @override
  String get profileSetupBannerColorCustom => 'Tersuai';

  @override
  String get profileSetupBannerColorNone => 'Tiada warna';

  @override
  String get profileSetupBannerColorLime => 'Limau nipis';

  @override
  String get profileSetupBannerColorYellow => 'Kuning';

  @override
  String get profileSetupBannerColorViolet => 'Ungu';

  @override
  String get profileSetupBannerColorPink => 'Merah jambu';

  @override
  String get profileSetupBannerColorOrange => 'Jingga';

  @override
  String get profileSetupBannerColorPurple => 'Ungu';

  @override
  String get profileSetupAvatarClearButton => 'Buang foto';

  @override
  String get profileSetupImageTakePhoto => 'Ambil foto';

  @override
  String get profileSetupImageUploadFromCameraRoll => 'Muat naik dari galeri';

  @override
  String get profileSetupImagePasteLink => 'Tampal pautan imej';

  @override
  String get profileSetupEditAvatarLabel => 'Edit gambar profil';

  @override
  String get profileSetupEditBannerLabel => 'Edit sepanduk';

  @override
  String get profileSetupUsernameChecking => 'Menyemak ketersediaan...';

  @override
  String get profileSetupUsernameAvailable => 'Nama pengguna tersedia!';

  @override
  String get profileSetupUsernameTakenIndicator =>
      'Nama pengguna sudah diambil';

  @override
  String get profileSetupUsernameReserved => 'Nama pengguna ditempah';

  @override
  String get profileSetupContactSupport => 'Hubungi sokongan';

  @override
  String get profileSetupCheckAgain => 'Semak semula';

  @override
  String get profileSetupUsernameBurned =>
      'Nama pengguna ini tidak lagi tersedia';

  @override
  String get profileSetupUsernameInvalidFormat =>
      'Hanya huruf, nombor dan sempang dibenarkan';

  @override
  String get profileSetupUsernameInvalidHyphenPlacement =>
      'Nama pengguna tidak boleh bermula atau berakhir dengan tanda sempang';

  @override
  String get profileSetupUsernameInvalidLength =>
      'Nama pengguna mestilah 3-63 aksara';

  @override
  String get profileSetupUsernameNetworkError =>
      'Tidak dapat menyemak ketersediaan. Sila cuba lagi.';

  @override
  String get profileSetupUsernameInvalidFormatGeneric =>
      'Format nama pengguna tidak sah';

  @override
  String get profileSetupUsernameCheckFailed => 'Gagal menyemak ketersediaan';

  @override
  String get profileSetupUsernameReservedTitle => 'Nama pengguna ditempah';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return 'Nama $username ditempah. Beritahu kami mengapa ia patut menjadi milik anda.';
  }

  @override
  String get profileSetupUsernameReservedHint =>
      'cth. Nama jenama saya, nama pentas, dsb.';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      'Sudah menghubungi sokongan? Ketik \"Semak semula\" untuk melihat jika ia telah dilepaskan kepada anda.';

  @override
  String get profileSetupSupportRequestSent =>
      'Permintaan sokongan dihantar! Kami akan menghubungi anda tidak lama lagi.';

  @override
  String get profileSetupCouldntOpenEmail =>
      'Tidak dapat membuka e-mel. Hantar ke: names@divine.video';

  @override
  String get profileSetupSendRequest => 'Hantar permintaan';

  @override
  String get profileSetupUseOwnNip05 => 'Guna alamat NIP-05 anda sendiri';

  @override
  String get profileSetupNip05AddressLabel => 'Alamat NIP-05';

  @override
  String get profileSetupExternalNip05InvalidFormat =>
      'Format NIP-05 tidak sah (cth. nama@domain.com)';

  @override
  String get profileSetupExternalNip05DivineDomain =>
      'Guna medan nama pengguna di atas untuk divine.video';

  @override
  String get nostrSettingsNip05Address => 'Alamat NIP-05';

  @override
  String get nostrSettingsNip05AddressSubtitle =>
      'Guna nama pengguna divine.video anda, atau halakan handle anda ke alamat NIP-05 pada domain yang anda kawal.';

  @override
  String get nostrSettingsNip05AddressHint => 'anda@contoh.com';

  @override
  String get nostrSettingsNip05SaveAction => 'Simpan NIP-05';

  @override
  String get nostrSettingsNip05Saved => 'NIP-05 disimpan';

  @override
  String get nostrSettingsNip05SaveFailed =>
      'Tidak dapat menyimpan NIP-05. Sila cuba lagi.';

  @override
  String get profileSetupNip05ConfirmTitle => 'Guna NIP-05 anda sendiri?';

  @override
  String get profileSetupNip05ConfirmBody =>
      'NIP-05 memetakan nama seperti anda@domainanda.com kepada identiti Nostr anda. Anda perlu mengawal domain itu dan menjadi hos fail pengesahan pada laluan yang betul. Jika salah, orang tidak dapat menemui anda dan handle anda yang disahkan akan hilang. Teruskan hanya jika anda telah menyediakannya.';

  @override
  String get profileSetupNip05ConfirmContinue => 'Teruskan';

  @override
  String get profileSetupNip05ConfirmCancel => 'Batal';

  @override
  String get profileSetupProfilePicturePreview => 'Pratonton gambar profil';

  @override
  String get nostrInfoIntroBuiltOn => 'Divine dibina di atas Nostr,';

  @override
  String get nostrInfoIntroDescription =>
      ' protokol terbuka tahan penapisan yang membolehkan orang berkomunikasi dalam talian tanpa bergantung pada satu syarikat atau platform. ';

  @override
  String get nostrInfoIntroIdentity =>
      'Apabila anda mendaftar dengan Divine, anda mendapat identiti Nostr baharu.';

  @override
  String get nostrInfoOwnership =>
      'Nostr membolehkan anda memiliki kandungan, identiti dan graf sosial anda, yang boleh anda gunakan merentasi banyak apl. Hasilnya ialah lebih banyak pilihan, kurang terikat, dan internet sosial yang lebih sihat dan berdaya tahan.';

  @override
  String get nostrInfoLingo => 'Istilah Nostr:';

  @override
  String get nostrInfoNpubLabel => 'npub:';

  @override
  String get nostrInfoNpubDescription =>
      ' Alamat Nostr awam anda. Ia selamat untuk dikongsi dan membolehkan orang lain menemui, mengikuti atau menghantar mesej kepada anda merentasi apl Nostr.';

  @override
  String get nostrInfoNsecLabel => 'nsec:';

  @override
  String get nostrInfoNsecDescription =>
      ' Kunci peribadi anda dan bukti pemilikan. Ia memberi kawalan penuh ke atas identiti Nostr anda, jadi ';

  @override
  String get nostrInfoNsecWarning => 'sentiasa rahsiakannya!';

  @override
  String get nostrInfoUsernameLabel => 'Nama pengguna Nostr:';

  @override
  String get nostrInfoUsernameDescription =>
      ' Nama mesra manusia (seperti @nama.divine.video) yang memaut kepada npub anda. Ia menjadikan identiti Nostr anda lebih mudah dikenali dan disahkan, seperti alamat e-mel.';

  @override
  String get nostrInfoLearnMoreAt => 'Ketahui lebih lanjut di ';

  @override
  String get nostrInfoGotIt => 'Faham!';

  @override
  String get videoGridRefreshLabel => 'Mencari lebih banyak video';

  @override
  String get videoGridOptionsTitle => 'Pilihan Video';

  @override
  String get videoGridEditVideo => 'Sunting Video';

  @override
  String get videoGridEditVideoSubtitle =>
      'Kemas kini tajuk, keterangan dan hashtag';

  @override
  String get videoGridDeleteVideo => 'Padam Video';

  @override
  String get videoGridDeleteVideoSubtitle =>
      'Alih keluar video ini daripada Divine. Ia mungkin masih muncul pada klien Nostr lain.';

  @override
  String get videoGridDeletingContent => 'Memadam kandungan...';

  @override
  String get exploreTabFeatured => 'Pilihan';

  @override
  String get exploreTabClassics => 'Klasik';

  @override
  String get exploreTabNew => 'Baharu';

  @override
  String get exploreTabPopular => 'Popular';

  @override
  String get exploreTabCategories => 'Kategori';

  @override
  String get exploreTabForYou => 'Untuk Anda';

  @override
  String get exploreTabLists => 'Senarai';

  @override
  String get exploreTabIntegratedApps => 'Apl Bersepadu';

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
      'Belum ada apa-apa di sini. Datang semula tidak lama lagi.';

  @override
  String get featuredTabLoadFailed => 'Koleksi ini tidak dapat dimuatkan.';

  @override
  String get featuredTabRetry => 'Cuba lagi';

  @override
  String get exploreNoVideosAvailable => 'Tiada video tersedia';

  @override
  String get exploreDiscoverLists => 'Terokai Senarai';

  @override
  String get exploreAboutLists => 'Perihal Senarai';

  @override
  String get exploreAboutListsDescription =>
      'Senarai membantu anda menyusun dan mengurus kandungan Divine dalam dua cara:';

  @override
  String get explorePeopleLists => 'Senarai Orang';

  @override
  String get explorePeopleListsDescription =>
      'Ikut kumpulan pencipta dan lihat video terbaharu mereka';

  @override
  String get exploreVideoLists => 'Senarai Video';

  @override
  String get exploreVideoListsDescription =>
      'Cipta senarai main video kegemaran anda untuk ditonton nanti';

  @override
  String get exploreMyLists => 'Senarai Saya';

  @override
  String get exploreSubscribedLists => 'Senarai Langganan';

  @override
  String get exploreErrorLoadingLists =>
      'Ralat memuatkan senarai. Sila cuba lagi.';

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count video baharu',
      one: '1 video baharu',
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
    return 'Muatkan $count $_temp0 baharu';
  }

  @override
  String get videoPlayerPlayVideo => 'Mainkan video';

  @override
  String get videoPlayerMute => 'Senyapkan video';

  @override
  String get videoPlayerUnmute => 'Nyahsenyap video';

  @override
  String get videoPlayerTapHint =>
      'Ketik untuk main atau jeda. Ketik dua kali untuk suka.';

  @override
  String get videoSettingsMenuOpen => 'Buka tetapan main balik';

  @override
  String get videoSettingsMenuClose => 'Tutup tetapan main balik';

  @override
  String get videoSettingsCaptionsEnable => 'Dayakan sarikata';

  @override
  String get videoSettingsCaptionsDisable => 'Lumpuhkan sarikata';

  @override
  String get videoSettingsAutoAdvanceOn => 'Maju automatik dihidupkan';

  @override
  String get videoSettingsAutoAdvanceOff => 'Maju automatik dimatikan';

  @override
  String get videoSettingsCaptionsOn => 'Sarikata dihidupkan';

  @override
  String get videoSettingsCaptionsOff => 'Sarikata dimatikan';

  @override
  String get videoSettingsCaptionsOnForVideo =>
      'Sari kata dihidupkan untuk video ini';

  @override
  String get videoSettingsCaptionsOffForVideo =>
      'Sari kata dimatikan untuk video ini';

  @override
  String get contentWarningLabel => 'Amaran Kandungan';

  @override
  String get contentWarningNudity => 'Kebogelan';

  @override
  String get contentWarningSexualContent => 'Kandungan Seksual';

  @override
  String get contentWarningPornography => 'Pornografi';

  @override
  String get contentWarningGraphicMedia => 'Media Grafik';

  @override
  String get contentWarningViolence => 'Keganasan';

  @override
  String get contentWarningSelfHarm => 'Mencederakan Diri';

  @override
  String get contentWarningDrugUse => 'Penggunaan Dadah';

  @override
  String get contentWarningAlcohol => 'Alkohol';

  @override
  String get contentWarningTobacco => 'Tembakau';

  @override
  String get contentWarningGambling => 'Perjudian';

  @override
  String get contentWarningProfanity => 'Bahasa Kasar';

  @override
  String get contentWarningFlashingLights => 'Cahaya Berkelip';

  @override
  String get contentWarningAiGenerated => 'Dijana AI';

  @override
  String get contentWarningSpoiler => 'Spoiler';

  @override
  String get contentWarningSensitiveContent => 'Kandungan Sensitif';

  @override
  String get contentWarningDescNudity =>
      'Mengandungi kebogelan atau separa bogel';

  @override
  String get contentWarningDescSexual => 'Mengandungi kandungan seksual';

  @override
  String get contentWarningDescPorn =>
      'Mengandungi kandungan pornografi eksplisit';

  @override
  String get contentWarningDescGraphicMedia =>
      'Mengandungi imej grafik atau menyakitkan hati';

  @override
  String get contentWarningDescViolence => 'Mengandungi kandungan ganas';

  @override
  String get contentWarningDescSelfHarm =>
      'Mengandungi rujukan kepada mencederakan diri';

  @override
  String get contentWarningDescDrugs => 'Mengandungi kandungan berkaitan dadah';

  @override
  String get contentWarningDescAlcohol =>
      'Mengandungi kandungan berkaitan alkohol';

  @override
  String get contentWarningDescTobacco =>
      'Mengandungi kandungan berkaitan tembakau';

  @override
  String get contentWarningDescGambling =>
      'Mengandungi kandungan berkaitan perjudian';

  @override
  String get contentWarningDescProfanity => 'Mengandungi bahasa kasar';

  @override
  String get contentWarningDescFlashingLights =>
      'Mengandungi cahaya berkelip (amaran fotosensitiviti)';

  @override
  String get contentWarningDescAiGenerated => 'Kandungan ini dijana oleh AI';

  @override
  String get contentWarningDescSpoiler => 'Mengandungi spoiler';

  @override
  String get contentWarningDescContentWarning =>
      'Pencipta menandakan ini sebagai sensitif';

  @override
  String get contentWarningDescDefault => 'Pencipta menandakan kandungan ini';

  @override
  String get contentWarningDetailsTitle => 'Amaran Kandungan';

  @override
  String get contentWarningDetailsSubtitle => 'Pencipta menggunakan label ini:';

  @override
  String get contentWarningManageFilters => 'Urus penapis kandungan';

  @override
  String get contentWarningViewAnyway => 'Lihat Juga';

  @override
  String get contentWarningReportContentTooltip => 'Laporkan Kandungan';

  @override
  String get contentWarningBlockUserTooltip => 'Sekat Pengguna';

  @override
  String get contentWarningBlockedTitle => 'Kandungan Disekat';

  @override
  String get contentWarningBlockedPolicy =>
      'Kandungan ini telah disekat kerana pelanggaran dasar.';

  @override
  String get contentWarningNoticeTitle => 'Notis Kandungan';

  @override
  String get contentWarningPotentiallyHarmfulTitle =>
      'Kandungan Berpotensi Memudaratkan';

  @override
  String get contentWarningView => 'Lihat';

  @override
  String get contentWarningReportAction => 'Laporkan';

  @override
  String get contentWarningHideAllLikeThis =>
      'Sembunyikan semua kandungan seperti ini';

  @override
  String get contentWarningNoFilterYet =>
      'Belum ada penapis disimpan untuk amaran ini.';

  @override
  String get contentWarningHiddenConfirmation =>
      'Kami akan menyembunyikan siaran seperti ini mulai sekarang.';

  @override
  String get communitySuggestTitle => 'Bantu mengelaskan ini';

  @override
  String get communitySuggestSubtitle =>
      'Tiada amaran kandungan? Cadangan anda adalah awam, ditandatangani, dan tidak boleh ditarik balik.';

  @override
  String get communitySuggestSubmit => 'Cadangkan';

  @override
  String get communitySuggestSuccess =>
      'Terima kasih. Cadangan anda telah dihantar.';

  @override
  String get communitySuggestFailure =>
      'Tidak dapat menghantar cadangan anda. Cuba lagi.';

  @override
  String get communitySuggestAlready => 'Anda mencadangkan ini';

  @override
  String get communitySuggestActionLabel => 'Kelaskan';

  @override
  String get videoErrorNotFound => 'Video tidak ditemui';

  @override
  String get videoErrorPlayback => 'Ralat main balik video';

  @override
  String get videoErrorAgeRestricted => 'Kandungan terhad mengikut umur';

  @override
  String get videoErrorUnavailable => 'Video tidak tersedia';

  @override
  String get videoErrorUnavailableBody =>
      'Video ini tidak tersedia buat masa ini.';

  @override
  String get videoErrorRetry => 'Cuba Semula';

  @override
  String get videoErrorContentRestricted => 'Kandungan dihadkan';

  @override
  String get videoErrorContentRestrictedBody =>
      'Video ini dialih keluar kerana melanggar peraturan kandungan kami.';

  @override
  String get videoErrorVerifyAgeBody =>
      'Sahkan umur anda untuk menonton video ini.';

  @override
  String get videoErrorSkip => 'Langkau';

  @override
  String get videoErrorVerifyAgeButton => 'Sahkan umur';

  @override
  String get videoErrorVerifyAgeFailed =>
      'Tidak dapat mengesahkan umur anda. Sila cuba lagi.';

  @override
  String get videoErrorVerifyAgeSignerUnreachable =>
      'Pengesahan tamat masa. Semak sambungan anda atau cuba lagi sebentar nanti.';

  @override
  String get videoErrorAdultContentHiddenTitle => 'Kandungan dewasa dimatikan';

  @override
  String get videoErrorAdultContentHiddenBody =>
      'Hidupkan dalam Penapis Kandungan anda untuk menonton video ini.';

  @override
  String get videoErrorAdultContentHiddenAction => 'Buka Penapis Kandungan';

  @override
  String get videoDetailLoadError => 'Gagal memuatkan video';

  @override
  String get videoDetailLoadErrorBody =>
      'Ada yang tak kena dalam perjalanan. Cuba lagi.';

  @override
  String get videoDetailNotFoundBody =>
      'Mungkin ia dipadam, di luar capaian, atau disembunyikan oleh tetapan anda.';

  @override
  String get databaseCorruptionTitle => 'Data setempat anda bercelaru';

  @override
  String get databaseCorruptionBody =>
      'Tutup Divine dan buka semula — kami akan membaikinya secara automatik. Kami akan menyelamatkan draf dan klip yang dapat kami selamatkan, yang lain akan dimuatkan semula.';

  @override
  String get databaseCorruptionCloseButton => 'Tutup Divine';

  @override
  String get videoDetailContextTitle => 'Video Dikongsi';

  @override
  String get videoDetailCloseSemanticLabel => 'Tutup pemain video';

  @override
  String get videoFollowButtonFollow => 'Ikut';

  @override
  String get audioAttributionOriginalSound => 'Bunyi asal';

  @override
  String get audioAttributionUnavailableSound => 'Bunyi tidak tersedia';

  @override
  String videoInspiredByAttributionMultiple(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return 'Diilhamkan oleh @$creatorName +$additionalCreatorCount';
  }

  @override
  String videoInspiredByAttribution(String creatorName) {
    return 'Diilhamkan oleh @$creatorName';
  }

  @override
  String videoCollaboratorWithOne(String name) {
    return 'bersama @$name';
  }

  @override
  String videoCollaboratorWithMore(String name, int count) {
    return 'bersama @$name +$count';
  }

  @override
  String videoCollaboratorCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kolaborator',
      one: '1 kolaborator',
    );
    return '$_temp0. Ketik untuk melihat profil.';
  }

  @override
  String get videoCollaboratorPendingDecoration => 'Menunggu';

  @override
  String get videoCollaboratorPendingSemanticLabel => 'Kolaborator menunggu';

  @override
  String videoCollaboratorWithPendingSuffix(String label, int pending) {
    return '$label ($pending menunggu)';
  }

  @override
  String profileChipTapHint(String name) {
    return '$name. Ketik untuk melihat profil.';
  }

  @override
  String metadataHashtagChipTapHint(String hashtag) {
    return '#$hashtag. Ketik untuk melihat video dengan hashtag ini.';
  }

  @override
  String get listAttributionFallback => 'Senarai';

  @override
  String get shareVideoLabel => 'Kongsi video';

  @override
  String sharePostSharedWith(String recipientName) {
    return 'Siaran dikongsi dengan $recipientName';
  }

  @override
  String sharePostSharedWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Siaran dikongsi dengan $count orang',
      one: 'Siaran dikongsi dengan $count orang',
    );
    return '$_temp0';
  }

  @override
  String get shareFailedToSend => 'Gagal menghantar video';

  @override
  String get shareAddedToBookmarks => 'Ditambah ke penanda buku';

  @override
  String get shareRemovedFromBookmarks => 'Dialih keluar daripada penanda buku';

  @override
  String get shareFailedToAddBookmark => 'Gagal menambah penanda buku';

  @override
  String get shareFailedToRemoveBookmark =>
      'Gagal mengalih keluar penanda buku';

  @override
  String get shareActionFailed => 'Tindakan gagal';

  @override
  String get shareWithTitle => 'Kongsi dengan';

  @override
  String get shareFindPeople => 'Cari orang';

  @override
  String get shareFindPeopleMultiline => 'Cari\norang';

  @override
  String get shareSent => 'Dihantar';

  @override
  String shareSelectedRecipientAnnouncement(String name) {
    return '$name dipilih';
  }

  @override
  String get shareMessageHint => 'Tambah mesej pilihan...';

  @override
  String get videoActionUnlike => 'Nyahsuka video';

  @override
  String get videoActionLike => 'Suka video';

  @override
  String get videoActionAutoLabel => 'Kompilasi';

  @override
  String get videoActionLikeLabel => 'Suka';

  @override
  String get videoActionReplyLabel => 'Balas';

  @override
  String get videoActionRepostLabel => 'Revine';

  @override
  String get videoActionShareLabel => 'Kongsi';

  @override
  String get videoActionReportLabel => 'Laporkan';

  @override
  String get videoActionReport => 'Laporkan video';

  @override
  String get videoActionEditLabel => 'Sunting';

  @override
  String get videoActionEdit => 'Sunting video';

  @override
  String get videoActionAboutLabel => 'Perihal';

  @override
  String get videoActionEnableAutoAdvance => 'Dayakan maju automatik';

  @override
  String get videoActionDisableAutoAdvance => 'Lumpuhkan maju automatik';

  @override
  String get videoActionRemoveRepost => 'Alih keluar siaran semula';

  @override
  String get videoActionRepost => 'Siarkan semula video';

  @override
  String get videoActionViewComments => 'Lihat komen';

  @override
  String get videoActionMoreOptions => 'Lagi pilihan';

  @override
  String get videoEngagementLikersTitle => 'Disukai oleh';

  @override
  String get videoEngagementRepostersTitle => 'Disiarkan semula oleh';

  @override
  String get videoEngagementLikersEmpty => 'Belum ada sukaan';

  @override
  String get videoEngagementRepostersEmpty => 'Belum ada siaran semula';

  @override
  String get videoEngagementLoadFailed => 'Tidak dapat memuatkan senarai itu';

  @override
  String get videoOverlayOpenMetadataFromTitle => 'Buka butiran video';

  @override
  String get videoOverlayOpenMetadataFromDescription => 'Buka butiran video';

  @override
  String get videoOverlayCommentBarHint => 'Tambah komen...';

  @override
  String get videoOverlayCommentBarSemanticLabel => 'Tambah komen';

  @override
  String get videoOverlayCommentBarSendLabel => 'Hantar komen';

  @override
  String get videoOverlayCommentPostedSnackbar => 'Komen disiarkan';

  @override
  String get videoOverlayCommentPostFailedSnackbar =>
      'Tidak dapat menyiarkan komen';

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
  String get metadataBadgeNotDivine => 'Bukan Divine';

  @override
  String get metadataBadgeHumanMade => 'Buatan Manusia';

  @override
  String get metadataSoundsLabel => 'Bunyi';

  @override
  String get metadataOriginalSound => 'Bunyi asal';

  @override
  String get metadataVerificationLabel => 'Pengesahan';

  @override
  String get metadataDeviceAttestation => 'Pengesahan peranti';

  @override
  String get metadataPgpSignature => 'Tandatangan PGP';

  @override
  String get metadataC2paCredentials => 'Kelayakan Kandungan C2PA';

  @override
  String get metadataProofManifest => 'Manifes bukti';

  @override
  String get metadataVerificationInfoTooltip =>
      'Apakah maksud pemeriksaan ini?';

  @override
  String metadataSectionInfoSemanticsLabel(String section, String question) {
    return '$section. $question';
  }

  @override
  String get metadataVerificationInfoTitle => 'Apa maksud pemeriksaan ini';

  @override
  String get metadataVerificationInfoIntro =>
      'Isyarat ini datang daripada kamera dan daripada fail video itu sendiri. Lebih banyak yang dibawa sesebuah video, lebih banyak yang boleh kami buktikan tentang asalnya.';

  @override
  String get metadataVerificationInfoDeviceAttestation =>
      'Sistem pengendalian telefon menjamin apl yang merakam ini. Bukti kukuh bahawa ia datang daripada kamera, bukan fail yang dimuat naik seseorang.';

  @override
  String get metadataVerificationInfoPgpSignature =>
      'Video ditandatangani secara kriptografi pada saat ia dirakam. Ubah satu bingkai selepas itu, tandatangan akan rosak.';

  @override
  String get metadataVerificationInfoC2paCredentials =>
      'Rekod asal usul berstandard industri yang dibawa di dalam fail — jadi apl selain Divine pun boleh menyemaknya.';

  @override
  String get metadataVerificationInfoProofManifest =>
      'Rekod ProofMode penuh: cap jari fail, cap masa dan konteks rakaman, disatukan dengan video.';

  @override
  String get metadataVerificationInfoFootnote =>
      'Pemeriksaan yang tiada tidak menjadikan video itu palsu. Klip lama dan muat naik memang tidak pernah ada — ia cuma bermakna kami tidak dapat membuktikan bahagian itu.';

  @override
  String metadataVerificationInfoLearnMore(String url) {
    return 'Ketahui lebih lanjut di $url';
  }

  @override
  String get metadataCreatorLabel => 'Pencipta';

  @override
  String get metadataCollaboratorsLabel => 'Kolaborator';

  @override
  String get metadataInspiredByLabel => 'Diilhamkan oleh';

  @override
  String get metadataRepostedByLabel => 'Disiarkan semula oleh';

  @override
  String metadataMoreReposters(int count) {
    return '+$count lagi';
  }

  @override
  String metadataLoopsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Loop',
      one: 'Loop',
    );
    return '$_temp0';
  }

  @override
  String get metadataLikesLabel => 'Sukaan';

  @override
  String get metadataCommentsLabel => 'Komen';

  @override
  String get metadataRepostsLabel => 'Siaran Semula';

  @override
  String get metadataVineStatsLabel => 'Di Vine';

  @override
  String metadataVineStatsLine(
    String loops,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$loops loop · $likes sukaan · $comments komen · $reposts siaran semula';
  }

  @override
  String get metadataDivineStatsLabel => 'Di Divine';

  @override
  String metadataDivineStatsLine(
    String views,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$views tontonan · $likes sukaan · $comments komen · $reposts siaran semula';
  }

  @override
  String metadataPostedDateSemantics(String date) {
    return 'Disiarkan pada $date';
  }

  @override
  String get devOptionsTitle => 'Pilihan Pembangun';

  @override
  String get devOptionsDisableDeveloperMode => 'Lumpuhkan Mod Pembangun';

  @override
  String get devOptionsDisableDeveloperModeSubtitle =>
      'Sembunyikan pilihan pembangun daripada tetapan';

  @override
  String get devOptionsDisableDeveloperModeToast => 'Mod pembangun dilumpuhkan';

  @override
  String get devOptionsShorebirdTitle => 'Tampalan Shorebird';

  @override
  String get devOptionsShorebirdPatchLabel => 'Tampalan aktif';

  @override
  String get devOptionsShorebirdNoPatch => 'Tiada tampalan dipasang';

  @override
  String get devOptionsShorebirdUnavailable =>
      'Tidak tersedia dalam binaan ini';

  @override
  String get devOptionsShorebirdUnavailableSubtitle =>
      'Tampalan hanya berfungsi dalam binaan yang dibuat dengan shorebird release.';

  @override
  String get devOptionsShorebirdLoading => 'Membaca status tampalan…';

  @override
  String get devOptionsShorebirdNotChecked =>
      'Trek pementasan belum diperiksa.';

  @override
  String get devOptionsShorebirdCheck => 'Periksa trek pementasan';

  @override
  String get devOptionsShorebirdApply => 'Gunakan tampalan pementasan';

  @override
  String get devOptionsShorebirdUseStable => 'Kembali kepada kemas kini stabil';

  @override
  String get devOptionsShorebirdChecking => 'Memeriksa trek pementasan…';

  @override
  String get devOptionsShorebirdUpdateAvailable =>
      'Tampalan pementasan sedia untuk digunakan.';

  @override
  String get devOptionsShorebirdUpToDate =>
      'Tiada tampalan pementasan untuk keluaran ini.';

  @override
  String get devOptionsShorebirdRestartRequired =>
      'Dimuat turun. Mulakan semula aplikasi untuk memuatkannya.';

  @override
  String get devOptionsShorebirdRollbackRequired =>
      'Pengunduran sedia. Mulakan semula untuk kembali kepada keluaran asas.';

  @override
  String get devOptionsShorebirdApplying => 'Memuat turun dan memasang…';

  @override
  String get devOptionsShorebirdApplied =>
      'Dipasang. Mulakan semula aplikasi untuk memuatkannya.';

  @override
  String get devOptionsShorebirdUnchanged =>
      'Tiada apa-apa dipasang. Periksa trek pementasan dan cuba lagi.';

  @override
  String get devOptionsShorebirdSelectingStableTrack => 'Memilih trek stabil…';

  @override
  String get devOptionsShorebirdStableRestored =>
      'Trek stabil dipilih. Mulakan semula aplikasi untuk menyemak tampalan stabil.';

  @override
  String get devOptionsShorebirdFailure =>
      'Tidak berjaya. Periksa log untuk butiran.';

  @override
  String get devOptionsPageLoadTimes => 'Masa Muat Halaman';

  @override
  String get devOptionsNoPageLoads =>
      'Belum ada pemuatan halaman direkodkan.\nLayari apl untuk melihat data masa.';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return 'Kelihatan: ${visibleMs}ms  |  Data: ${dataMs}ms';
  }

  @override
  String get devOptionsSlowestScreens => 'Skrin Paling Perlahan';

  @override
  String get devOptionsVideoPlaybackFormat => 'Format Main Balik Video';

  @override
  String get devOptionsSwitchEnvironmentTitle => 'Tukar Persekitaran?';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return 'Tukar ke $envName?\n\nIni akan mengosongkan data video cache dan menyambung semula ke relay baharu.';
  }

  @override
  String get devOptionsCancel => 'Batal';

  @override
  String get devOptionsSwitch => 'Tukar';

  @override
  String devOptionsSwitchedTo(String envName) {
    return 'Bertukar ke $envName';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return 'Bertukar ke $formatName — cache dikosongkan';
  }

  @override
  String get featureFlagTitle => 'Bendera Ciri';

  @override
  String get featureFlagResetAllTooltip =>
      'Tetapkan semula semua bendera kepada lalai';

  @override
  String get featureFlagError => 'Ralat';

  @override
  String get relaySettingsTitle => 'Relay';

  @override
  String get relaySettingsInfoTitle =>
      'Divine ialah sistem terbuka - anda mengawal sambungan anda';

  @override
  String get relaySettingsInfoDescription =>
      'Relay ini mengedarkan kandungan anda merentasi rangkaian Nostr yang terdesentralisasi. Anda boleh menambah atau mengalih keluar relay mengikut kesukaan anda.';

  @override
  String get relaySettingsLearnMoreNostr =>
      'Ketahui lebih lanjut tentang Nostr →';

  @override
  String get relaySettingsFindPublicRelays =>
      'Cari relay awam di nostr.co.uk →';

  @override
  String get relaySettingsAppNotFunctional => 'Apl Tidak Berfungsi';

  @override
  String get relaySettingsRequiresRelay =>
      'Divine memerlukan sekurang-kurangnya satu relay untuk memuatkan video, menyiarkan kandungan dan menyegerak data.';

  @override
  String get relaySettingsRestoreDefaultRelay => 'Pulihkan Relay Lalai';

  @override
  String get relaySettingsAddCustomRelay => 'Tambah Relay Tersuai';

  @override
  String get relaySettingsAddRelay => 'Tambah Relay';

  @override
  String get relaySettingsRetry => 'Cuba Semula';

  @override
  String get relaySettingsNoStats => 'Belum ada statistik tersedia';

  @override
  String get relaySettingsConnection => 'Sambungan';

  @override
  String get relaySettingsConnected => 'Bersambung';

  @override
  String get relaySettingsDisconnected => 'Terputus';

  @override
  String get relaySettingsSessionDuration => 'Tempoh Sesi';

  @override
  String get relaySettingsLastConnected => 'Kali Terakhir Bersambung';

  @override
  String get relaySettingsDisconnectedLabel => 'Terputus';

  @override
  String get relaySettingsReason => 'Sebab';

  @override
  String get relaySettingsActiveSubscriptions => 'Langganan Aktif';

  @override
  String get relaySettingsTotalSubscriptions => 'Jumlah Langganan';

  @override
  String get relaySettingsEventsReceived => 'Acara Diterima';

  @override
  String get relaySettingsEventsSent => 'Acara Dihantar';

  @override
  String get relaySettingsRequestsThisSession => 'Permintaan Sesi Ini';

  @override
  String get relaySettingsFailedRequests => 'Permintaan Gagal';

  @override
  String get relaySettingsLoadingRelayInfo => 'Memuatkan maklumat relay...';

  @override
  String get relaySettingsAboutRelay => 'Perihal Relay';

  @override
  String get relaySettingsSupportedNips => 'NIP Disokong';

  @override
  String get relaySettingsSoftware => 'Perisian';

  @override
  String get relaySettingsViewWebsite => 'Lihat Laman Web';

  @override
  String get relaySettingsRemoveRelayTitle => 'Alih Keluar Relay?';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return 'Adakah anda pasti mahu mengalih keluar relay ini?\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveDefaultRelayTitle => 'Buang relay Divine?';

  @override
  String relaySettingsRemoveDefaultRelayMessage(String relayUrl) {
    return 'Membuang relay Divine akan menjejaskan pengalaman dalam apl. Video, siaran dan penyegerakan mungkin kurang boleh dipercayai. Ini hanya patut dilakukan oleh pengguna Nostr yang berpengalaman.\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveRelayTooltip => 'Buang relay';

  @override
  String get relaySettingsCancel => 'Batal';

  @override
  String get relaySettingsRemove => 'Alih Keluar';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return 'Relay dialih keluar: $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay => 'Gagal mengalih keluar relay';

  @override
  String get relaySettingsForcingReconnection =>
      'Memaksa sambungan semula relay...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    return 'Bersambung ke $count relay!';
  }

  @override
  String get relaySettingsFailedToConnectCheck =>
      'Gagal bersambung ke relay. Sila semak sambungan rangkaian anda.';

  @override
  String get relaySettingsSavedLocallyPublishPending =>
      'Disimpan pada peranti ini. Kami akan menyegerakkannya ke akaun anda apabila penerbitan berfungsi semula.';

  @override
  String get relaySettingsAddRelayTitle => 'Tambah Relay';

  @override
  String get relaySettingsAddRelayPrompt =>
      'Masukkan URL WebSocket relay yang mahu anda tambah:';

  @override
  String get relaySettingsBrowsePublicRelays =>
      'Semak imbas relay awam di nostr.co.uk';

  @override
  String get relaySettingsAdd => 'Tambah';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return 'Relay ditambah: $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      'Gagal menambah relay. Sila semak URL dan cuba lagi.';

  @override
  String get relaySettingsInvalidUrl =>
      'URL relay mestilah bermula dengan wss:// atau ws://';

  @override
  String get relaySettingsInsecureUrl =>
      'URL relay mestilah menggunakan wss:// (ws:// dibenarkan untuk localhost sahaja)';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return 'Relay lalai dipulihkan: $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      'Gagal memulihkan relay lalai. Sila semak sambungan rangkaian anda.';

  @override
  String get relaySettingsCouldNotOpenBrowser => 'Tidak dapat membuka pelayar';

  @override
  String get relaySettingsFailedToOpenLink => 'Gagal membuka pautan';

  @override
  String get relaySettingsExternalRelay => 'Relay luaran';

  @override
  String get relaySettingsNotConnected => 'Tidak bersambung';

  @override
  String relaySettingsDisconnectedAgo(String duration) {
    return 'Terputus $duration lalu';
  }

  @override
  String relaySettingsSubscriptionsSummary(int count) {
    return '$count langganan';
  }

  @override
  String relaySettingsEventsSummary(int countValue, String count) {
    return '$count acara';
  }

  @override
  String relaySettingsTimeAgo(String duration) {
    return '$duration lalu';
  }

  @override
  String get nostrSettingsIntro =>
      'Divine menggunakan protokol Nostr untuk penerbitan terdesentralisasi. Kandungan anda berada pada relay yang anda pilih, dan kunci anda ialah identiti anda.';

  @override
  String get nostrSettingsSectionNetwork => 'Rangkaian';

  @override
  String get nostrSettingsSectionAccount => 'Akaun';

  @override
  String get nostrSettingsSectionDangerZone => 'Zon Bahaya';

  @override
  String get nostrSettingsRelays => 'Relay';

  @override
  String get nostrSettingsRelaysSubtitle => 'Urus sambungan relay Nostr';

  @override
  String get nostrSettingsRelayDiagnostics => 'Diagnostik Relay';

  @override
  String get nostrSettingsRelayDiagnosticsSubtitle =>
      'Nyahpepijat kesambungan relay dan isu rangkaian';

  @override
  String get nostrSettingsMediaServers => 'Pelayan Media';

  @override
  String get nostrSettingsMediaServersSubtitle =>
      'Konfigurasikan pelayan muat naik Blossom';

  @override
  String get settingsDeveloperOptions => 'Pilihan Pembangun';

  @override
  String get settingsDeveloperOptionsSubtitle =>
      'Penukar persekitaran dan tetapan nyahpepijat';

  @override
  String get nostrSettingsKeyManagement => 'Pengurusan Kunci';

  @override
  String get nostrSettingsKeyManagementSubtitle =>
      'Eksport, sandar dan pulihkan kunci Nostr anda';

  @override
  String get nostrSettingsClientAttribution => 'Atribusi Klien';

  @override
  String get nostrSettingsClientAttributionSubtitle =>
      'Sertakan tag klien Divine pada acara yang anda terbitkan supaya apl Nostr lain dapat mengatribusikannya dengan betul. Tanpanya, laporan yang anda hantar kurang berat semasa moderator kami menyemaknya.';

  @override
  String get nostrSettingsMoveAccount => 'Alihkan akaun anda';

  @override
  String get nostrSettingsMoveAccountSubtitle =>
      'Muat turun arkib anda dan alihkan siaran serta video anda ke relay atau pelayan media lain.';

  @override
  String get nostrSettingsRemoveKeys =>
      'Alih keluar akaun ini daripada peranti ini';

  @override
  String get nostrSettingsRemoveKeysSubtitle =>
      'Alih keluar log masuk setempat akaun ini daripada peranti ini. Draf dan klip setempat anda kekal disimpan untuk akaun ini.';

  @override
  String get nostrSettingsCouldNotRemoveKeys =>
      'Tidak dapat mengalih keluar akaun ini daripada peranti ini. Sila cuba lagi.';

  @override
  String get nostrSettingsDeleteAccount => 'Padam Akaun dan Data';

  @override
  String get nostrSettingsDeleteAccountSubtitle =>
      'Menghantar permintaan pemadaman untuk kandungan anda dan melog keluar anda pada peranti ini. Relay, klien, indeks carian dan peranti lain yang dilog masuk mungkin menyimpan salinan.';

  @override
  String get relayDiagnosticTitle => 'Diagnostik Relay';

  @override
  String get relayDiagnosticRefreshTooltip => 'Muat semula diagnostik';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return 'Muat semula terakhir: $time';
  }

  @override
  String get relayDiagnosticRelayStatus => 'Status Relay';

  @override
  String get relayDiagnosticInitialized => 'Dimulakan';

  @override
  String get relayDiagnosticReady => 'Sedia';

  @override
  String get relayDiagnosticNotInitialized => 'Belum dimulakan';

  @override
  String get relayDiagnosticDatabaseEvents => 'Acara Pangkalan Data';

  @override
  String get relayDiagnosticActiveSubscriptions => 'Langganan Aktif';

  @override
  String get relayDiagnosticExternalRelays => 'Relay Luaran';

  @override
  String get relayDiagnosticConfigured => 'Dikonfigurasikan';

  @override
  String relayDiagnosticRelayCount(int count) {
    return '$count relay';
  }

  @override
  String get relayDiagnosticConnectedLabel => 'Bersambung';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => 'Acara Video';

  @override
  String get relayDiagnosticHomeFeed => 'Suapan Utama';

  @override
  String relayDiagnosticVideosCount(int count) {
    return '$count video';
  }

  @override
  String get relayDiagnosticDiscovery => 'Penemuan';

  @override
  String get relayDiagnosticLoading => 'Memuatkan';

  @override
  String get relayDiagnosticYes => 'Ya';

  @override
  String get relayDiagnosticNo => 'Tidak';

  @override
  String get relayDiagnosticTestDirectQuery => 'Uji Pertanyaan Langsung';

  @override
  String get relayDiagnosticNetworkConnectivity => 'Kesambungan Rangkaian';

  @override
  String get relayDiagnosticRunNetworkTest => 'Jalankan Ujian Rangkaian';

  @override
  String get relayDiagnosticBlossomServer => 'Pelayan Blossom';

  @override
  String get relayDiagnosticTestAllEndpoints => 'Uji Semua Titik Hujung';

  @override
  String get relayDiagnosticStatus => 'Status';

  @override
  String get relayDiagnosticUrl => 'URL';

  @override
  String get relayDiagnosticError => 'Ralat';

  @override
  String get relayDiagnosticFunnelCakeApi => 'API FunnelCake';

  @override
  String get relayDiagnosticBaseUrl => 'URL Asas';

  @override
  String get relayDiagnosticSummary => 'Ringkasan';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount OK (purata ${avgMs}ms)';
  }

  @override
  String get relayDiagnosticRetestAll => 'Uji Semula Semua';

  @override
  String get relayDiagnosticRetrying => 'Mencuba semula...';

  @override
  String get relayDiagnosticRetryConnection => 'Cuba Semula Sambungan';

  @override
  String get relayDiagnosticTroubleshooting => 'Penyelesaian Masalah';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• Status hijau = Bersambung dan berfungsi\n• Status merah = Sambungan gagal\n• Jika ujian rangkaian gagal, semak sambungan internet\n• Jika relay dikonfigurasikan tetapi tidak bersambung, ketik \"Cuba Semula Sambungan\"\n• Ambil tangkapan skrin skrin ini untuk nyahpepijat';

  @override
  String get relayDiagnosticAllEndpointsHealthy =>
      'Semua titik hujung REST sihat!';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      'Sesetengah titik hujung REST gagal - lihat butiran di atas';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    return 'Menemui $count acara video dalam pangkalan data';
  }

  @override
  String get relayDiagnosticQueryFailed => 'Pertanyaan gagal. Sila cuba lagi.';

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    return 'Bersambung ke $count relay!';
  }

  @override
  String get relayDiagnosticFailedToConnect =>
      'Gagal bersambung ke mana-mana relay';

  @override
  String get relayDiagnosticConnectionRetryFailed =>
      'Cubaan semula sambungan gagal. Sila cuba lagi.';

  @override
  String get relayDiagnosticConnectedAuthenticated => 'Bersambung & Disahkan';

  @override
  String get relayDiagnosticConnectedOnly => 'Bersambung';

  @override
  String get relayDiagnosticNotConnected => 'Tidak bersambung';

  @override
  String get relayDiagnosticNoRelaysConfigured =>
      'Tiada relay dikonfigurasikan';

  @override
  String get relayDiagnosticFailed => 'Gagal';

  @override
  String get notificationSettingsTitle => 'Pemberitahuan';

  @override
  String get notificationSettingsResetTooltip => 'Tetapkan semula kepada lalai';

  @override
  String get notificationSettingsTypes => 'Jenis Pemberitahuan';

  @override
  String get notificationSettingsLikes => 'Sukaan';

  @override
  String get notificationSettingsLikesSubtitle =>
      'Apabila seseorang menyukai video anda';

  @override
  String get notificationSettingsComments => 'Komen';

  @override
  String get notificationSettingsCommentsSubtitle =>
      'Apabila seseorang mengomen video anda';

  @override
  String get notificationSettingsFollows => 'Ikutan';

  @override
  String get notificationSettingsFollowsSubtitle =>
      'Apabila seseorang mengikuti anda';

  @override
  String get notificationSettingsMentions => 'Sebutan';

  @override
  String get notificationSettingsMentionsSubtitle => 'Apabila anda disebut';

  @override
  String get notificationSettingsReposts => 'Siaran Semula';

  @override
  String get notificationSettingsRepostsSubtitle =>
      'Apabila seseorang menyiarkan semula video anda';

  @override
  String get notificationSettingsNewPosts => 'Vine baharu';

  @override
  String get notificationSettingsNewPostsSubtitle =>
      'Apabila seseorang yang anda ikuti menyiarkan';

  @override
  String get notificationSettingsActions => 'Tindakan';

  @override
  String get notificationSettingsMarkAllAsRead =>
      'Tandakan Semua sebagai Dibaca';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle =>
      'Tandakan semua pemberitahuan sebagai dibaca';

  @override
  String get notificationSettingsAllMarkedAsRead =>
      'Semua pemberitahuan ditandakan sebagai dibaca';

  @override
  String get notificationSettingsMarkAllAsReadFailed =>
      'Gagal menandakan semua sebagai dibaca';

  @override
  String get notificationSettingsResetToDefaults =>
      'Tetapan ditetapkan semula kepada lalai';

  @override
  String get notificationSettingsAbout => 'Perihal Pemberitahuan';

  @override
  String get notificationSettingsAboutDescription =>
      'Pemberitahuan dikuasakan oleh protokol Nostr. Kemas kini masa nyata bergantung pada sambungan anda ke relay Nostr. Sesetengah pemberitahuan mungkin lewat.';

  @override
  String get safetySettingsWhatYouSee => 'APA YANG ANDA LIHAT';

  @override
  String get safetySettingsWhatYouPublish => 'APA YANG ANDA TERBITKAN';

  @override
  String get safetySettingsShowDivineHostedOnly =>
      'Tunjuk video yang dihoskan Divine sahaja';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle =>
      'Sembunyikan video yang disampaikan daripada hos media lain';

  @override
  String get safetySettingsModeration => 'KESSEDERHANAAN';

  @override
  String get safetySettingsBlockedUsers => 'PENGGUNA DISEKAT';

  @override
  String get safetySettingsAgeVerification => 'PENGESAHAN UMUR';

  @override
  String get safetySettingsAgeConfirmation =>
      'Saya mengesahkan bahawa saya berumur 18 tahun ke atas';

  @override
  String get safetySettingsAgeRequired =>
      'Diperlukan untuk melihat kandungan dewasa';

  @override
  String get safetySettingsAgeLockedForMinor => 'Dikunci untuk akaun anda';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle =>
      'Perkhidmatan kesederhanaan rasmi (hidup secara lalai)';

  @override
  String get safetySettingsPeopleIFollow => 'Orang yang saya ikuti';

  @override
  String get safetySettingsPeopleIFollowSubtitle =>
      'Langgan label daripada orang yang anda ikuti';

  @override
  String get safetySettingsAddCustomLabeler => 'Tambah Pelabel Tersuai';

  @override
  String get safetySettingsAddCustomLabelerHint => 'Masukkan npub...';

  @override
  String get safetySettingsAddCustomLabelerListTitle =>
      'Tambah pelabel tersuai';

  @override
  String get safetySettingsRemoveLabeler => 'Buang pelabel';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle =>
      'Masukkan alamat npub';

  @override
  String get safetySettingsNoBlockedUsers => 'Tiada pengguna disekat';

  @override
  String get safetySettingsUnblock => 'Nyahsekat';

  @override
  String get safetySettingsUserUnblocked => 'Pengguna dinyahsekat';

  @override
  String get safetySettingsCancel => 'Batal';

  @override
  String get safetySettingsAdd => 'Tambah';

  @override
  String get analyticsTitle => 'Analitik Pencipta';

  @override
  String get analyticsDiagnosticsTooltip => 'Diagnostik';

  @override
  String get analyticsDiagnosticsSemanticLabel => 'Togol diagnostik';

  @override
  String get analyticsRetry => 'Cuba Semula';

  @override
  String get analyticsUnableToLoad => 'Tidak dapat memuatkan analitik.';

  @override
  String get analyticsServerUnavailable =>
      'Creator analytics is having server trouble. Please try again in a moment.';

  @override
  String get analyticsConnectionIssue =>
      'Creator analytics could not connect. Check your connection and try again.';

  @override
  String get analyticsSignInRequired =>
      'Log masuk untuk melihat analitik pencipta.';

  @override
  String get analyticsViewDataUnavailable =>
      'Tontonan tidak tersedia daripada relay untuk siaran ini buat masa ini. Metrik sukaan/komen/siaran semula masih tepat.';

  @override
  String get analyticsViewDataTitle => 'Data Tontonan';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return 'Dikemas kini $time • Skor menggunakan sukaan, komen, siaran semula dan tontonan/loop daripada Funnelcake apabila tersedia.';
  }

  @override
  String get analyticsVideos => 'Video';

  @override
  String get analyticsViews => 'Tontonan';

  @override
  String get analyticsInteractions => 'Interaksi';

  @override
  String get analyticsEngagement => 'Penglibatan';

  @override
  String get analyticsFollowers => 'Pengikut';

  @override
  String get analyticsAvgPerPost => 'Purata/Siaran';

  @override
  String get analyticsInteractionMix => 'Gabungan Interaksi';

  @override
  String get analyticsLikes => 'Sukaan';

  @override
  String get analyticsComments => 'Komen';

  @override
  String get analyticsReposts => 'Siaran Semula';

  @override
  String get analyticsPerformanceHighlights => 'Sorotan Prestasi';

  @override
  String get analyticsMostViewed => 'Paling banyak ditonton';

  @override
  String get analyticsMostDiscussed => 'Paling banyak dibincangkan';

  @override
  String get analyticsMostReposted => 'Paling banyak disiarkan semula';

  @override
  String get analyticsNoVideosYet => 'Belum ada video';

  @override
  String get analyticsViewDataUnavailableShort =>
      'Data tontonan tidak tersedia';

  @override
  String analyticsViewsCount(int countValue, String count) {
    return '$count tontonan';
  }

  @override
  String analyticsCommentsCount(int countValue, String count) {
    return '$count komen';
  }

  @override
  String analyticsRepostsCount(int countValue, String count) {
    return '$count siaran semula';
  }

  @override
  String get analyticsTopContent => 'Kandungan Teratas';

  @override
  String get analyticsPublishPrompt =>
      'Terbitkan beberapa video untuk melihat kedudukan.';

  @override
  String get analyticsEngagementRateExplainer =>
      '% sebelah kanan = Kadar Penglibatan (interaksi dibahagi dengan tontonan).';

  @override
  String get analyticsEngagementRateNoViews =>
      'Kadar Penglibatan memerlukan data tontonan; nilai ditunjukkan sebagai N/A sehingga tontonan tersedia.';

  @override
  String get analyticsEngagementLabel => 'Penglibatan';

  @override
  String get analyticsViewsUnavailable => 'tontonan tidak tersedia';

  @override
  String analyticsInteractionsCount(int countValue, String count) {
    return '$count interaksi';
  }

  @override
  String get analyticsPostAnalytics => 'Analitik Siaran';

  @override
  String get analyticsOpenPost => 'Buka Siaran';

  @override
  String get analyticsRecentDailyInteractions => 'Interaksi Harian Terkini';

  @override
  String get analyticsNoActivityYet => 'Belum ada aktiviti dalam julat ini.';

  @override
  String get analyticsDailyInteractionsExplainer =>
      'Interaksi = sukaan + komen + siaran semula mengikut tarikh siaran.';

  @override
  String get analyticsDailyBarExplainer =>
      'Panjang bar adalah relatif kepada hari tertinggi anda dalam tetingkap ini.';

  @override
  String get analyticsAudienceSnapshot => 'Ringkasan Audiens';

  @override
  String analyticsFollowersCount(String count) {
    return 'Pengikut: $count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return 'Mengikuti: $count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      'Pecahan sumber/geo/masa audiens akan diisi apabila Funnelcake menambah titik hujung analitik audiens.';

  @override
  String get analyticsRetention => 'Pengekalan';

  @override
  String get analyticsRetentionWithViews =>
      'Lengkung pengekalan dan pecahan masa tontonan akan muncul sebaik sahaja pengekalan sesaat/per-baldi tiba daripada Funnelcake.';

  @override
  String get analyticsRetentionWithoutViews =>
      'Data pengekalan tidak tersedia sehingga analitik tontonan+masa tontonan dikembalikan oleh Funnelcake.';

  @override
  String get analyticsDiagnostics => 'Diagnostik';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return 'Jumlah video: $count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return 'Dengan tontonan: $count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return 'Tontonan hilang: $count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return 'Dihidrasi (pukal): $count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return 'Dihidrasi (/views): $count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return 'Sumber: $sources';
  }

  @override
  String analyticsDiagnosticsFailedSources(String sources) {
    return 'Failed sources: $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => 'Guna data lekapan';

  @override
  String get analyticsNa => 'Tiada';

  @override
  String get authCreateNewAccount => 'Cipta akaun Divine baharu';

  @override
  String get authCreateNewAccountShort => 'Cipta akaun baharu';

  @override
  String get authSignInDifferentAccount => 'Log masuk dengan akaun sedia ada';

  @override
  String get authUseAnotherAccount => 'Guna akaun lain';

  @override
  String authContinueAs(String displayName) {
    return 'Teruskan sebagai $displayName';
  }

  @override
  String get authRecoveryDraftsOwner =>
      'Draf dan klip anda disimpan untuk akaun ini';

  @override
  String get authRecoveryOtherAccountWarning =>
      'Log masuk di sini akan menyembunyikan draf dan klip itu';

  @override
  String get authTermsPrefix =>
      'Dengan memilih pilihan di bawah, anda mengesahkan bahawa anda berumur sekurang-kurangnya 16 tahun (atau telah melengkapkan ';

  @override
  String get authTermsAgeAuthorizationCta => 'kebenaran umur Divine';

  @override
  String get authTermsAfterAgeAuthorization => ') dan bersetuju dengan ';

  @override
  String get authTermsOfService => 'Terma Perkhidmatan';

  @override
  String get authPrivacyPolicy => 'Dasar Privasi';

  @override
  String get authTermsAnd => ', dan ';

  @override
  String get authSafetyStandards => 'Piawaian Keselamatan';

  @override
  String get authAmberNotInstalled => 'Apl Amber tidak dipasang';

  @override
  String get authAmberConnectionFailed => 'Gagal bersambung dengan Amber';

  @override
  String get authPasswordResetSent =>
      'Jika akaun wujud dengan e-mel itu, pautan tetapan semula kata laluan telah dihantar.';

  @override
  String get authSignInTitle => 'Log masuk';

  @override
  String get authEmailLabel => 'E-mel';

  @override
  String get authPasswordLabel => 'Kata laluan';

  @override
  String get authConfirmPasswordLabel => 'Sahkan kata laluan';

  @override
  String get authEmailRequired => 'E-mel diperlukan';

  @override
  String get authEmailInvalid => 'Sila masukkan e-mel yang sah';

  @override
  String get authPasswordRequired => 'Kata laluan diperlukan';

  @override
  String get authConfirmPasswordRequired => 'Sila sahkan kata laluan anda';

  @override
  String get authPasswordsDoNotMatch => 'Kata laluan tidak sepadan';

  @override
  String get authForgotPassword => 'Lupa kata laluan?';

  @override
  String get authImportNostrKey => 'Import kunci Nostr';

  @override
  String get authConnectSignerApp => 'Bersambung dengan apl penandatangan';

  @override
  String get authSignInWithAmber => 'Log masuk dengan Amber';

  @override
  String get authSignInWithBrowserExtension =>
      'Log masuk dengan sambungan pelayar';

  @override
  String get authNip07ConnectionFailed =>
      'Tidak dapat bersambung ke sambungan pelayar anda.';

  @override
  String get authNip07ExtensionNotFound =>
      'Tiada sambungan pelayar ditemui. Pasang Alby, nos2x atau sambungan serasi NIP-07 lain.';

  @override
  String get authSignInOptionsTitle => 'Pilihan log masuk';

  @override
  String get authInfoEmailPasswordTitle => 'E-mel & Kata Laluan';

  @override
  String get authInfoEmailPasswordDescription =>
      'Log masuk dengan akaun Divine anda. Jika anda mendaftar dengan e-mel dan kata laluan, gunakannya di sini.';

  @override
  String get authInfoImportNostrKeyDescription =>
      'Sudah mempunyai identiti Nostr? Import kunci peribadi nsec anda daripada klien lain.';

  @override
  String get authInfoSignerAppTitle => 'Apl Penandatangan';

  @override
  String get authInfoSignerAppDescription =>
      'Bersambung menggunakan penandatangan jauh serasi NIP-46 seperti nsecBunker untuk keselamatan kunci yang dipertingkatkan.';

  @override
  String get authInfoAmberTitle => 'Amber';

  @override
  String get authInfoAmberDescription =>
      'Guna apl penandatangan Amber pada Android untuk mengurus kunci Nostr anda dengan selamat.';

  @override
  String get authInfoBrowserExtensionTitle => 'Sambungan Pelayar';

  @override
  String get authInfoBrowserExtensionDescription =>
      'Log masuk dengan sambungan pelayar NIP-07 seperti Alby atau nos2x. Kunci anda kekal dalam sambungan — Divine tidak pernah melihatnya.';

  @override
  String get authSignInErrorInvalidCredentials =>
      'E-mel atau kata laluan salah. Cuba sekali lagi.';

  @override
  String get authSignInErrorEmailNotVerified =>
      'Sahkan e-mel anda sebelum log masuk — semak peti masuk anda untuk pautan itu.';

  @override
  String get authSignInErrorInvalidEmail =>
      'Itu tidak kelihatan seperti alamat e-mel yang sah.';

  @override
  String get authSignInErrorNetwork =>
      'Tidak dapat mencapai pelayan. Semak sambungan anda dan cuba lagi.';

  @override
  String get authSignInErrorGeneric => 'Sesuatu telah berlaku. Sila cuba lagi.';

  @override
  String get authSignInOptionsHintPrefix =>
      'Tidak pasti bagaimana anda masuk kali terakhir? ';

  @override
  String get authSignInOptionsHintCta => 'Lihat semua pilihan log masuk';

  @override
  String get authCreateAccountTitle => 'Cipta akaun';

  @override
  String get authBackToInviteCode => 'Kembali ke kod jemputan';

  @override
  String get authUseDivineNoBackup => 'Guna Divine tanpa sandaran';

  @override
  String get authSkipConfirmTitle => 'Satu lagi perkara...';

  @override
  String get authSkipConfirmKeyCreated =>
      'Anda masuk! Kami akan mencipta kunci selamat yang menggerakkan akaun Divine anda.';

  @override
  String get authSkipConfirmKeyOnly =>
      'Tanpa e-mel, kunci anda ialah satu-satunya cara Divine mengetahui akaun ini milik anda.';

  @override
  String get authSkipConfirmRecommendEmail =>
      'Anda boleh mengakses kunci anda dalam apl, tetapi jika anda tidak teknikal, kami mengesyorkan menambah e-mel dan kata laluan sekarang. Ia memudahkan log masuk dan memulihkan akaun anda jika anda kehilangan atau menetapkan semula peranti ini.';

  @override
  String get authAddEmailPassword => 'Tambah e-mel & kata laluan';

  @override
  String get authUseThisDeviceOnly => 'Guna peranti ini sahaja';

  @override
  String get authCompleteRegistration => 'Lengkapkan pendaftaran anda';

  @override
  String get authVerifying => 'Mengesahkan...';

  @override
  String get authVerificationLinkSent =>
      'Kami menghantar pautan pengesahan ke:';

  @override
  String get authClickVerificationLink =>
      'Sila klik pautan dalam e-mel anda untuk\nmelengkapkan pendaftaran anda.';

  @override
  String get authPleaseWaitVerifying =>
      'Sila tunggu sementara kami mengesahkan e-mel anda...';

  @override
  String get authWaitingForVerification => 'Menunggu pengesahan';

  @override
  String get authOpenEmailApp => 'Buka apl e-mel';

  @override
  String get authVerificationPinPrompt =>
      'Atau masukkan kod 6 digit daripada e-mel anda';

  @override
  String get authVerificationPinFieldLabel => 'Kod 6 digit';

  @override
  String get authVerificationPinSubmit => 'Sahkan kod';

  @override
  String get authVerificationResendPrompt => 'Tidak menerimanya?';

  @override
  String get authVerificationResend => 'Hantar semula';

  @override
  String authVerificationResendCooldown(String time) {
    return 'Hantar semula dalam $time';
  }

  @override
  String get authVerificationResendFailed =>
      'Kami tidak dapat menghantar semula e-mel itu. Cuba lagi.';

  @override
  String get authVerificationResendExpired =>
      'Pendaftaran itu telah tamat tempoh. Mulakan semula untuk dapatkan kod baharu.';

  @override
  String get authVerificationResendUnavailable =>
      'Penghantaran semula tidak tersedia sekarang. Gunakan kod 6 digit daripada e-mel yang telah kami hantar kepada anda.';

  @override
  String get authVerificationPollingStopped =>
      'Kami berhenti menyemak untuk anda. Masukkan kod 6 digit daripada e-mel anda untuk selesaikan log masuk.';

  @override
  String get authWelcomeToDivine => 'Selamat datang ke Divine!';

  @override
  String get authEmailVerified => 'E-mel anda telah disahkan.';

  @override
  String get authSigningYouIn => 'Melogg anda masuk';

  @override
  String get authErrorTitle => 'Alamak.';

  @override
  String get authVerificationFailed =>
      'Kami gagal mengesahkan e-mel anda.\nSila cuba lagi.';

  @override
  String get authStartOver => 'Mula semula';

  @override
  String get authEmailVerifiedLogin =>
      'E-mel disahkan! Sila log masuk untuk meneruskan.';

  @override
  String get authVerificationLinkExpired =>
      'Pautan pengesahan ini tidak lagi sah.';

  @override
  String get authVerificationConnectionError =>
      'Tidak dapat mengesahkan e-mel. Sila semak sambungan anda dan cuba lagi.';

  @override
  String get authWaitlistConfirmTitle => 'Anda masuk!';

  @override
  String authWaitlistUpdatesAt(String email) {
    return 'Kami akan berkongsi kemas kini di $email.\nApabila lebih banyak kod jemputan tersedia, kami akan menghantarnya kepada anda.';
  }

  @override
  String get authOk => 'OK';

  @override
  String get authTryAgain => 'Cuba lagi';

  @override
  String get authContactSupport => 'Hubungi sokongan';

  @override
  String authCouldNotOpenEmail(String email) {
    return 'Tidak dapat membuka $email';
  }

  @override
  String get authAddInviteCode => 'Masukkan kod jemputan anda';

  @override
  String get authInviteCodeLabel => 'Kod jemputan';

  @override
  String get authEnterYourCode => 'Masukkan kod anda';

  @override
  String get authNext => 'Seterusnya';

  @override
  String get authJoinWaitlist => 'Sertai senarai menunggu';

  @override
  String get authJoinWaitlistTitle => 'Sertai senarai menunggu';

  @override
  String get authJoinWaitlistDescription =>
      'Kongsi e-mel anda dan kami akan menghantar kod jemputan apabila akses dibuka.';

  @override
  String get authJoinWaitlistNewsletterOptIn =>
      'Hantarkan saya inspirasi Divine';

  @override
  String get authInviteAccessHelp => 'Bantuan akses jemputan';

  @override
  String get authGeneratingConnection => 'Menjana sambungan...';

  @override
  String get authConnectedAuthenticating => 'Bersambung! Mengesahkan...';

  @override
  String get authConnectionTimedOut => 'Sambungan tamat masa';

  @override
  String get authApproveConnection =>
      'Pastikan anda meluluskan sambungan dalam apl penandatangan anda.';

  @override
  String get authConnectionCancelled => 'Sambungan dibatalkan';

  @override
  String get authConnectionCancelledMessage => 'Sambungan telah dibatalkan.';

  @override
  String get authConnectionFailed => 'Sambungan gagal';

  @override
  String get authUnknownError => 'Ralat tidak diketahui berlaku.';

  @override
  String get authNostrConnectStartFailed =>
      'Tidak dapat mencapai penandatangan. Semak sambungan anda dan cuba lagi.';

  @override
  String get authNostrConnectInvalidSession =>
      'Pautan sambungan ini tidak lagi sah. Mulakan yang baharu.';

  @override
  String get authNostrConnectSetupFailed =>
      'Hampir siap — kami tidak dapat melengkapkan log masuk anda. Cuba lagi.';

  @override
  String get authUrlCopied => 'URL disalin ke papan klip';

  @override
  String get authConnectToDivine => 'Bersambung ke Divine';

  @override
  String get authPasteBunkerUrl => 'Tampal URL bunker://';

  @override
  String get authBunkerUrlHint => 'URL bunker://';

  @override
  String get authInvalidBunkerUrl =>
      'URL bunker tidak sah. Ia sepatutnya bermula dengan bunker://';

  @override
  String get authScanSignerApp =>
      'Imbas dengan apl\npenandatangan anda untuk bersambung.';

  @override
  String authWaitingForConnection(int seconds) {
    return 'Menunggu sambungan... ${seconds}s';
  }

  @override
  String get authCopyUrl => 'Salin URL';

  @override
  String get authShare => 'Kongsi';

  @override
  String get authAddBunker => 'Tambah bunker';

  @override
  String get authCompatibleSignerApps => 'Apl Penandatangan serasi';

  @override
  String get authFailedToConnect => 'Gagal bersambung';

  @override
  String get authResetPasswordTitle => 'Tetapkan Semula Kata Laluan';

  @override
  String get authResetPasswordSubtitle =>
      'Sila masukkan kata laluan baharu anda. Ia mestilah sekurang-kurangnya 8 aksara.';

  @override
  String get authNewPasswordLabel => 'Kata Laluan Baharu';

  @override
  String get authConfirmNewPasswordLabel => 'Sahkan kata laluan baharu';

  @override
  String get authPasswordTooShort =>
      'Kata laluan mestilah sekurang-kurangnya 8 aksara';

  @override
  String get authPasswordResetSuccess =>
      'Kata laluan berjaya ditetapkan semula. Sila log masuk.';

  @override
  String get authPasswordResetFailed => 'Tetapan semula kata laluan gagal';

  @override
  String get authUnexpectedError =>
      'Ralat tidak dijangka berlaku. Sila cuba lagi.';

  @override
  String get authUpdatePassword => 'Kemas kini kata laluan';

  @override
  String get authSecureAccountTitle => 'Selamatkan akaun';

  @override
  String get authUnableToAccessKeys =>
      'Tidak dapat mengakses kunci anda. Sila cuba lagi.';

  @override
  String get authRegistrationFailed => 'Pendaftaran gagal';

  @override
  String get authRegistrationComplete =>
      'Pendaftaran lengkap. Sila semak e-mel anda.';

  @override
  String get authSecureAccountAlreadyRegistered =>
      'Looks like an account already exists. Try a different email, or sign in to the existing account with this email address. If neither works, contact support.';

  @override
  String get authFailedToSendResetEmail =>
      'Gagal menghantar e-mel tetapan semula.';

  @override
  String get authSending => 'Menghantar...';

  @override
  String get authSignInButton => 'Log masuk';

  @override
  String get authVerificationErrorTimeout =>
      'Pengesahan tamat masa. Sila cuba mendaftar semula.';

  @override
  String get authVerificationErrorMissingCode =>
      'Pengesahan gagal — kod kebenaran hilang.';

  @override
  String get authVerificationErrorPollFailed =>
      'Pengesahan gagal. Sila cuba lagi.';

  @override
  String get authVerificationErrorNetworkExchange =>
      'Ralat rangkaian semasa log masuk. Sila cuba lagi.';

  @override
  String get authVerificationErrorOAuthExchange =>
      'Pengesahan gagal. Sila cuba mendaftar semula.';

  @override
  String get authVerificationErrorSignInFailed =>
      'Log masuk gagal. Sila cuba log masuk secara manual.';

  @override
  String get authVerificationEmailAlreadyRegistered =>
      'E-mel ini sudah didaftarkan. Log masuk sebaliknya.';

  @override
  String get authVerificationErrorPinInvalid =>
      'Kod itu tidak sepadan. Semak semula dan cuba lagi.';

  @override
  String get authVerificationErrorPinExpired =>
      'Kod itu telah tamat tempoh. Ketik hantar semula untuk mendapatkan yang baharu.';

  @override
  String get authVerificationErrorPinLocked =>
      'Terlalu banyak percubaan. Ketik hantar semula untuk mendapatkan kod baharu.';

  @override
  String get authVerificationErrorPinFailed =>
      'Kami tidak dapat mengesahkan kod itu. Sila cuba lagi.';

  @override
  String get authVerificationErrorPinUnavailable =>
      'Kemasukan kod tidak tersedia sekarang. Ketik pautan dalam e-mel anda, atau hantar semula untuk mendapatkan yang baharu.';

  @override
  String get authInviteCodeErrorMalformed =>
      'Masukkan kod jemputan seperti ABCD-EFGH.';

  @override
  String get authInviteCodeErrorNotFound =>
      'Kod jemputan itu nampaknya tidak sah.';

  @override
  String get authInviteCodeErrorAlreadyUsed =>
      'Kod jemputan itu telah digunakan atau dibatalkan.';

  @override
  String get authInviteGateErrorCreatorFull =>
      'Jemputan pencipta ini telah habis';

  @override
  String get authInviteGateErrorUnavailable =>
      'Kod jemputan itu tidak tersedia. Sertai senarai menunggu dan kami akan menghantar jemputan sebaik ada tempat.';

  @override
  String get authInviteGateErrorCheckFailed =>
      'Kami tidak dapat menyemak kod itu. Cuba lagi.';

  @override
  String get authInviteGateErrorUnknown =>
      'Ada sesuatu yang tidak kena. Cuba kod jemputan anda sekali lagi.';

  @override
  String get authInviteErrorAlreadyUsed =>
      'Kod jemputan itu tidak lagi tersedia. Kembali ke kod jemputan anda, sertai senarai menunggu, atau hubungi sokongan.';

  @override
  String get authInviteErrorInvalid =>
      'Kod jemputan itu tidak boleh digunakan sekarang. Kembali ke kod jemputan anda, sertai senarai menunggu, atau hubungi sokongan.';

  @override
  String get authInviteErrorTemporary =>
      'Kami tidak dapat mengesahkan jemputan anda sekarang. Kembali ke kod jemputan anda dan cuba lagi, atau hubungi sokongan.';

  @override
  String get authInviteErrorUnknown =>
      'Kami tidak dapat mengaktifkan jemputan anda. Kembali ke kod jemputan anda, sertai senarai menunggu, atau hubungi sokongan.';

  @override
  String get shareSheetSave => 'Simpan';

  @override
  String get shareSheetRemoveFromSaved => 'Alih keluar simpanan';

  @override
  String get shareSheetSaveToGallery => 'Simpan ke Galeri';

  @override
  String get shareSheetSaveWithWatermark => 'Simpan dengan Tera Air';

  @override
  String get shareSheetSaveVideo => 'Simpan Video';

  @override
  String get shareSheetAddToClips => 'Tambah ke klip';

  @override
  String get shareSheetNameClipTitle => 'Namakan klip ini';

  @override
  String get shareSheetNameClipSubtitle =>
      'Pilih nama yang anda akan kenali dalam pustaka anda.';

  @override
  String get shareSheetClipTitleLabel => 'Tajuk klip';

  @override
  String get shareSheetSaveClip => 'Simpan klip';

  @override
  String shareSheetSavedClipToClips(String title) {
    return '\"$title\" disimpan ke klip';
  }

  @override
  String get shareSheetUntitledClip => 'Klip tanpa tajuk';

  @override
  String get shareSheetAddToClipsFailed => 'Tidak dapat menambah ke klip';

  @override
  String get shareSheetAddToList => 'Tambah ke Senarai';

  @override
  String get shareSheetCopy => 'Salin';

  @override
  String get shareSheetShareVia => 'Kongsi melalui';

  @override
  String get shareSheetEventJson => 'JSON Acara';

  @override
  String get shareSheetEventId => 'ID Acara';

  @override
  String get shareSheetMoreActions => 'Lagi tindakan';

  @override
  String get shareSheetCrosspost => 'Siaran silang';

  @override
  String get crosspostSheetTitle => 'Siarkan silang video ini';

  @override
  String get crosspostSheetSubtitle =>
      'Hantarnya ke platform anda yang bersambung. Penyiaran boleh mengambil masa beberapa minit.';

  @override
  String get crosspostSubmit => 'Siarkan silang';

  @override
  String get crosspostStatusQueued => 'Dalam baris gilir';

  @override
  String get crosspostStatusUploading => 'Memuat naik';

  @override
  String get crosspostStatusProcessing => 'Memproses';

  @override
  String get crosspostStatusPosted => 'Disiarkan';

  @override
  String get crosspostStatusFailed => 'Gagal';

  @override
  String get crosspostStatusSkipped => 'Dilangkau';

  @override
  String get crosspostStatusNeedsReauth => 'Perlu sambungan semula';

  @override
  String get crosspostViewPost => 'Lihat siaran';

  @override
  String crosspostReconnectPrompt(String platform) {
    return 'Sambung semula $platform dalam tetapan siaran silang untuk terus menyiarkan.';
  }

  @override
  String get crosspostReconnect => 'Sambung semula';

  @override
  String get crosspostErrorNotOwner =>
      'Hanya video anda sendiri boleh disiarkan silang.';

  @override
  String get crosspostErrorNotEligible =>
      'Video ini tidak layak untuk siaran silang.';

  @override
  String get crosspostErrorNotConnected => 'Platform itu tidak bersambung.';

  @override
  String get crosspostErrorUnauthorized =>
      'Sambung semula akaun anda, kemudian cuba lagi.';

  @override
  String get crosspostErrorNetwork =>
      'Tidak dapat mencapai penyiar silang. Cuba lagi sebentar nanti.';

  @override
  String get crosspostFailedGeneric => 'Siaran silang gagal.';

  @override
  String get crosspostStillWorking =>
      'Masih bekerja. Anda boleh menutup ini — penyiaran berterusan di latar belakang.';

  @override
  String get crosspostDone => 'Siap';

  @override
  String get watermarkDownloadSavedToCameraRoll => 'Disimpan ke Rol Kamera';

  @override
  String get watermarkDownloadShare => 'Kongsi';

  @override
  String get watermarkDownloadDone => 'Siap';

  @override
  String get watermarkDownloadPhotosAccessNeeded => 'Akses Foto Diperlukan';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      'Untuk menyimpan video, benarkan akses Foto dalam Tetapan.';

  @override
  String get watermarkDownloadOpenSettings => 'Buka Tetapan';

  @override
  String get watermarkDownloadNotNow => 'Bukan Sekarang';

  @override
  String get watermarkDownloadFailed => 'Muat Turun Gagal';

  @override
  String get watermarkDownloadDismiss => 'Ketepikan';

  @override
  String get watermarkDownloadStageDownloading => 'Memuat Turun Video';

  @override
  String get watermarkDownloadStageWatermarking => 'Menambah Tera Air';

  @override
  String get watermarkDownloadStageSaving => 'Menyimpan ke Rol Kamera';

  @override
  String get watermarkDownloadStageDownloadingDesc =>
      'Mengambil video daripada rangkaian...';

  @override
  String get watermarkDownloadStageWatermarkingDesc =>
      'Mengenakan tera air Divine...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      'Menyimpan video tera air ke rol kamera anda...';

  @override
  String get shareMenuBookmarks => 'Penanda Buku';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    return '$count set ikutan tersedia';
  }

  @override
  String get peopleListsAddToList => 'Tambah ke senarai';

  @override
  String get peopleListsSheetTitle => 'Tambah ke senarai';

  @override
  String get peopleListsEmptyTitle => 'Belum ada senarai';

  @override
  String get peopleListsEmptySubtitle =>
      'Cipta senarai untuk mula mengumpulkan orang.';

  @override
  String get peopleListsCreateList => 'Cipta senarai';

  @override
  String get peopleListsNewListTitle => 'Senarai baharu';

  @override
  String get peopleListsRouteTitle => 'Senarai orang';

  @override
  String get peopleListsListNameLabel => 'Nama senarai';

  @override
  String get peopleListsListNameHint => 'Kawan rapat';

  @override
  String get peopleListsCreateButton => 'Cipta';

  @override
  String get peopleListsAddPeopleTitle => 'Tambah orang';

  @override
  String get peopleListsAddPeopleTooltip => 'Tambah orang';

  @override
  String get peopleListsAddPeopleSemanticLabel => 'Tambah orang ke senarai';

  @override
  String get peopleListsListNotFoundTitle => 'Senarai tidak ditemui';

  @override
  String get peopleListsListNotFoundSubtitle =>
      'Senarai tidak ditemui. Ia mungkin telah dipadam.';

  @override
  String get peopleListsListDeletedSubtitle =>
      'Senarai ini mungkin telah dipadam.';

  @override
  String get peopleListsNoPeopleTitle => 'Tiada orang dalam senarai ini';

  @override
  String get peopleListsNoPeopleSubtitle =>
      'Tambah beberapa orang untuk bermula';

  @override
  String get peopleListsNoVideosTitle => 'Belum ada video';

  @override
  String get peopleListsNoVideosSubtitle =>
      'Video daripada ahli senarai akan muncul di sini';

  @override
  String get peopleListsNoVideosAvailable => 'Tiada video tersedia';

  @override
  String get peopleListsFailedToLoadVideos => 'Gagal memuatkan video';

  @override
  String get peopleListsVideoNotAvailable => 'Video tidak tersedia';

  @override
  String get peopleListsBackToGridTooltip => 'Kembali ke grid';

  @override
  String get peopleListsErrorLoadingVideos => 'Ralat memuatkan video';

  @override
  String get peopleListsNoPeopleToAdd => 'Tiada orang tersedia untuk ditambah.';

  @override
  String peopleListsAddToListName(String name) {
    return 'Tambah ke $name';
  }

  @override
  String get peopleListsAddPeopleSearchHint => 'Cari orang';

  @override
  String get peopleListsAddPeopleError =>
      'Tidak dapat memuatkan orang. Sila cuba lagi.';

  @override
  String get peopleListsAddPeopleRetry => 'Cuba lagi';

  @override
  String get peopleListsAddButton => 'Tambah';

  @override
  String peopleListsAddButtonWithCount(int count) {
    return 'Tambah $count';
  }

  @override
  String peopleListsInNLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Dalam $count senarai',
      one: 'Dalam 1 senarai',
    );
    return '$_temp0';
  }

  @override
  String peopleListsRemoveConfirmTitle(String name) {
    return 'Alih keluar $name?';
  }

  @override
  String get peopleListsRemoveConfirmBody =>
      'Mereka akan dialih keluar daripada senarai ini.';

  @override
  String get peopleListsRemove => 'Alih Keluar';

  @override
  String peopleListsRemovedFromList(String name) {
    return '$name dialih keluar daripada senarai';
  }

  @override
  String get peopleListsUndo => 'Buat Asal';

  @override
  String peopleListsProfileLongPressHint(String name) {
    return 'Profil untuk $name. Tekan lama untuk mengalih keluar.';
  }

  @override
  String peopleListsViewProfileHint(String name) {
    return 'Lihat profil untuk $name';
  }

  @override
  String get shareMenuEditVideo => 'Sunting Video';

  @override
  String get shareMenuDeleteVideo => 'Padam Video';

  @override
  String shareMenuVideoCount(int count) {
    return '$count video';
  }

  @override
  String get shareMenuDeleteConfirmation =>
      'Ini akan memadam video ini secara kekal daripada Divine. Ia mungkin masih muncul pada klien Nostr pihak ketiga yang menggunakan relay lain.';

  @override
  String get shareMenuCancel => 'Batal';

  @override
  String get shareMenuDelete => 'Padam';

  @override
  String get shareMenuDeleteFailedNotInitialized =>
      'Pemadaman belum sedia. Cuba lagi sebentar nanti.';

  @override
  String get shareMenuDeleteFailedNotOwner =>
      'Anda hanya boleh memadam video anda sendiri.';

  @override
  String get shareMenuDeleteFailedNotAuthenticated =>
      'Log masuk semula, kemudian cuba memadam.';

  @override
  String get shareMenuDeleteFailedCouldNotSign =>
      'Tidak dapat menandatangani permintaan pemadaman. Cuba lagi.';

  @override
  String get shareMenuDeleteFailedRelayRejected =>
      'Relay tidak menerima permintaan pemadaman ini. Cuba lagi sebentar nanti.';

  @override
  String get shareMenuDeleteFailedAccountRestricted =>
      'Your account is restricted, so this delete request couldn\'t be sent. Contact support for help deleting it.';

  @override
  String get shareMenuDeleteFailedRelayNoResponse =>
      'Tidak dapat mencapai relay. Semak sambungan anda dan cuba lagi.';

  @override
  String get shareMenuDeletePartiallyConfirmed =>
      'Dipadam. Bukan semua relay mengesahkan, jadi ia mungkin masih muncul dalam apl lain.';

  @override
  String get shareMenuDeleteFailedGeneric =>
      'Tidak dapat memadam video ini. Cuba lagi.';

  @override
  String get shareMenuUpdate => 'Kemas Kini';

  @override
  String get shareMenuChangeCover => 'Tukar Muka Depan';

  @override
  String get shareMenuVideoUpdated => 'Video berjaya dikemas kini';

  @override
  String shareMenuVideoUpdatedWithInviteFailures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jemputan kolaborator tidak dihantar.',
      one: '1 jemputan kolaborator tidak dihantar.',
    );
    return 'Video dikemas kini, tetapi $_temp0';
  }

  @override
  String get videoUpdateErrorNotAuthenticated =>
      'Log masuk semula, kemudian cuba kemas kini.';

  @override
  String get videoUpdateErrorNoPlayableVideo =>
      'Video ini tiada sumber yang boleh dimainkan, jadi ia tidak boleh diedit.';

  @override
  String get videoUpdateErrorCouldNotSign =>
      'Gagal menandatangani kemas kini. Cuba lagi.';

  @override
  String get videoUpdateErrorPublishRejected =>
      'Relay tidak menerima kemas kini. Cuba lagi sebentar lagi.';

  @override
  String get videoUpdateErrorGeneric =>
      'Gagal mengemas kini video ini. Cuba lagi.';

  @override
  String get shareMenuOriginalVideoUnavailable =>
      'Couldn\'t load the original video. Try again in a moment.';

  @override
  String get shareMenuDeleteVideoQuestion => 'Padam Video?';

  @override
  String get shareMenuDeleteCleanupInProgress => 'Mengalih keluar video…';

  @override
  String get shareMenuDeleteCleanupConfirmed => 'Video dipadamkan.';

  @override
  String get shareMenuDeleteCleanupDelayed =>
      'Video dipadamkan. Ia mungkin mengambil sedikit masa untuk hilang dari semua tempat.';

  @override
  String get shareMenuDeleteCleanupFailed =>
      'Video dipadamkan, tetapi kami tidak dapat mengalih keluar setiap salinan. Hubungi sokongan.';

  @override
  String get authSessionExpired =>
      'Sesi anda telah tamat tempoh. Sila log masuk semula.';

  @override
  String get authAccountRestoreFailed =>
      'We couldn\'t unlock that account on this device. Sign in again.';

  @override
  String get authSignInFailed => 'Gagal log masuk. Sila cuba lagi.';

  @override
  String get webAuthNotSupportedSecureMode =>
      'Pengesahan web tidak disokong dalam mod selamat. Sila guna apl mudah alih untuk pengurusan kunci selamat.';

  @override
  String get webAuthEnterBunkerUri => 'Sila masukkan URI bunker';

  @override
  String get webAuthConnectTitle => 'Bersambung ke Divine';

  @override
  String get webAuthChooseMethod =>
      'Pilih kaedah pengesahan Nostr pilihan anda';

  @override
  String get webAuthBrowserExtension => 'Sambungan Pelayar';

  @override
  String get webAuthRecommended => 'DISYORKAN';

  @override
  String get webAuthNsecBunker => 'nsec bunker';

  @override
  String get webAuthConnectRemoteSigner => 'Bersambung ke penandatangan jauh';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => 'Tampal daripada papan klip';

  @override
  String get webAuthConnectToBunker => 'Bersambung ke Bunker';

  @override
  String get webAuthNewToNostr => 'Baharu dengan Nostr?';

  @override
  String get webAuthNostrHelp =>
      'Pasang sambungan pelayar seperti Alby atau nos2x untuk pengalaman paling mudah, atau guna nsec bunker untuk tandatangan jauh yang selamat.';

  @override
  String get soundsTitle => 'Bunyi';

  @override
  String get soundsSearchHint => 'Cari bunyi...';

  @override
  String get soundsSearchResults => 'Hasil Carian';

  @override
  String get soundsNoSoundsFound => 'Tiada bunyi ditemui';

  @override
  String get soundsNoSoundsFoundDescription => 'Cuba istilah carian lain';

  @override
  String get soundsSavedToLibrary => 'Disimpan ke Bunyi';

  @override
  String get soundsAlreadySavedToLibrary => 'Sudah ada dalam Bunyi';

  @override
  String get soundsSavedLibraryTitle => 'Bunyi Saya';

  @override
  String get soundsSavedEmptyTitle => 'Belum ada bunyi disimpan';

  @override
  String get soundsSavedEmptyDescription =>
      'Ketik Guna Bunyi pada video untuk menyimpannya di sini.';

  @override
  String get soundsRemoveSavedSound => 'Alih keluar bunyi';

  @override
  String get savedSoundSaveAction => 'Simpan';

  @override
  String get savedSoundPausePreviewAction => 'Jeda pratonton';

  @override
  String get savedSoundResumePreviewAction => 'Sambung pratonton';

  @override
  String get savedSoundDetailsSheetTitle => 'Butiran bunyi';

  @override
  String get savedSoundRemoveConfirmTitle => 'Alih keluar bunyi ini?';

  @override
  String get savedSoundRemoveConfirmMessage =>
      'Ia hilang daripada pustaka anda, tetapi anda boleh menyimpannya semula daripada mana-mana video yang menggunakannya.';

  @override
  String get soundsRemovedFromLibrary => 'Dialih keluar daripada Bunyi';

  @override
  String get soundsSaveFailed => 'Bunyi itu tidak dapat disimpan. Cuba lagi.';

  @override
  String get soundsRemoveFailed => 'Bunyi itu tidak dapat dibuang. Cuba lagi.';

  @override
  String get soundSyncStatusSyncing => 'Menyegerakkan bunyi anda…';

  @override
  String get soundSyncStatusSynced => 'Bunyi sudah terkini';

  @override
  String get soundSyncStatusFailed =>
      'Tidak dapat menyegerakkan bunyi anda. Kami akan cuba lagi.';

  @override
  String get soundSyncStatusLocked =>
      'Tidak dapat membuka pustaka tersegerak anda pada peranti ini.';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileMoreOptions => 'Lagi pilihan';

  @override
  String profileBlockedUser(String name) {
    return '$name disekat';
  }

  @override
  String profileUnblockedUser(String name) {
    return '$name dinyahsekat';
  }

  @override
  String profileUnfollowedUser(String name) {
    return '$name dinyahikut';
  }

  @override
  String get profileFeedError =>
      'Tidak dapat mencapai pelayan. Semak sambungan anda dan cuba lagi.';

  @override
  String get profileFeedLoadMoreError =>
      'Tidak dapat memuatkan lebih banyak video. Tarik untuk muat semula.';

  @override
  String get notificationsTabAll => 'Semua';

  @override
  String get notificationsTabLikes => 'Sukaan';

  @override
  String get notificationsTabComments => 'Komen';

  @override
  String get notificationsTabFollows => 'Ikutan';

  @override
  String get notificationsTabReposts => 'Siaran Semula';

  @override
  String get notificationsFailedToLoad => 'Gagal memuatkan pemberitahuan';

  @override
  String get notificationsRetry => 'Cuba Semula';

  @override
  String get notificationsRefreshError =>
      'Tidak dapat menyegarkan — menunjukkan apa yang anda ada';

  @override
  String get notificationsUnreadPrefix => 'Pemberitahuan belum dibaca';

  @override
  String notificationsBadgeUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pemberitahuan belum dibaca',
      one: '1 pemberitahuan belum dibaca',
    );
    return '$_temp0';
  }

  @override
  String notificationsViewProfileSemanticLabel(String displayName) {
    return 'Lihat profil $displayName';
  }

  @override
  String get notificationsViewProfilesSemanticLabel => 'Lihat profil';

  @override
  String notificationsVideoThumbnailFor(String title) {
    return 'Lakaran kecil video untuk $title';
  }

  @override
  String get notificationsVideoThumbnail => 'Lakaran kecil video';

  @override
  String get notificationsInviteSingular =>
      'Anda mempunyai 1 jemputan untuk dikongsi dengan rakan!';

  @override
  String notificationsInvitePlural(int count) {
    return 'Anda mempunyai $count jemputan untuk dikongsi dengan rakan-rakan!';
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
  String get notificationsVideoUnavailable => 'Video tidak tersedia';

  @override
  String get feedFailedToLoadVideos => 'Gagal memuatkan video';

  @override
  String get feedRetry => 'Cuba Semula';

  @override
  String get feedNoFollowedUsers =>
      'Tiada pengguna yang diikuti.\nIkut seseorang untuk melihat video mereka di sini.';

  @override
  String get feedModeForYou => 'Untuk Anda';

  @override
  String get feedModeNew => 'Baharu';

  @override
  String get feedModeFollowing => 'Mengikuti';

  @override
  String get feedModeClassics => 'Klasik';

  @override
  String feedModeSemanticLabel(String label) {
    return 'Mod suapan: $label';
  }

  @override
  String videoAuthorSemanticLabel(String displayName) {
    return 'Pengarang video: $displayName';
  }

  @override
  String get videoAuthorAvatarSemanticLabel => 'Avatar pengarang';

  @override
  String get feedForYouEmpty =>
      'Suapan Untuk Anda kosong.\nTerokai video dan ikut pencipta untuk membentuknya.';

  @override
  String get feedFollowingEmpty =>
      'Belum ada video daripada orang yang anda ikuti.\nCari pencipta yang anda suka dan ikuti mereka.';

  @override
  String get feedLatestEmpty =>
      'Belum ada video baharu.\nSemak semula tidak lama lagi.';

  @override
  String get feedClassicEmpty =>
      'Belum ada Vine klasik.\nSemak semula tidak lama lagi.';

  @override
  String get feedExploreVideos => 'Terokai Video';

  @override
  String get feedLoadingMore => 'Memuatkan lebih banyak video…';

  @override
  String get feedRefreshed => 'Suapan disegarkan';

  @override
  String get uploadUploadingVideo => 'Memuat naik video';

  @override
  String get postPublishConfirmationTitle => 'Diterbitkan ke profil anda';

  @override
  String get postPublishConfirmationView => 'Lihat';

  @override
  String get postPublishConfirmationShare => 'Kongsi';

  @override
  String get postPublishConfirmationThumbnailLabel =>
      'Lakaran kecil video yang baru anda terbitkan';

  @override
  String get userSearchNoResults => 'Tiada pengguna ditemui';

  @override
  String get userPickerFilterByNameHint => 'Tapis mengikut nama...';

  @override
  String get userPickerSearchByNameHint => 'Cari mengikut nama...';

  @override
  String get userPickerClearSearchSemantics => 'Kosongkan carian';

  @override
  String userPickerAlreadyAddedSemantics(String name) {
    return '$name sudah ditambah';
  }

  @override
  String userPickerSelectSemantics(String name) {
    return 'Pilih $name';
  }

  @override
  String userPickerRemoveSelectionSemantics(String name) {
    return 'Alih keluar $name';
  }

  @override
  String get userPickerEmptyFollowListTitle => 'Kumpulan anda ada di luar sana';

  @override
  String get userPickerEmptyFollowListBody =>
      'Ikut orang yang sekepala dengan anda. Apabila mereka mengikuti anda semula, anda boleh kolab.';

  @override
  String get userPickerGoBack => 'Kembali';

  @override
  String get userPickerTypeNameToSearch => 'Taip nama untuk mencari';

  @override
  String get userPickerUnavailable =>
      'Carian pengguna tidak tersedia. Sila cuba lagi nanti.';

  @override
  String get userPickerSearchFailedTryAgain => 'Carian gagal. Sila cuba lagi.';

  @override
  String get forgotPasswordTitle => 'Tetapkan Semula Kata Laluan';

  @override
  String get forgotPasswordDescription =>
      'Masukkan alamat e-mel anda dan kami akan menghantar pautan untuk menetapkan semula kata laluan anda.';

  @override
  String get forgotPasswordEmailLabel => 'Alamat E-mel';

  @override
  String get forgotPasswordCancel => 'Batal';

  @override
  String get forgotPasswordSendLink => 'E-mel Pautan Tetapan Semula';

  @override
  String get ageVerificationContentWarning => 'Amaran Kandungan';

  @override
  String get ageVerificationTitle => 'Pengesahan Umur';

  @override
  String get ageVerificationAdultDescription =>
      'Kandungan ini telah ditandakan sebagai berpotensi mengandungi bahan dewasa. Anda mestilah berumur 18 tahun ke atas untuk melihatnya.';

  @override
  String get ageVerificationCreationDescription =>
      'Untuk menggunakan kamera dan mencipta kandungan, anda mestilah berumur sekurang-kurangnya 16 tahun.';

  @override
  String get ageVerificationAdultQuestion =>
      'Adakah anda berumur 18 tahun ke atas?';

  @override
  String get ageVerificationCreationQuestion =>
      'Adakah anda berumur 16 tahun ke atas?';

  @override
  String get ageVerificationNo => 'Tidak';

  @override
  String get ageVerificationYes => 'Ya';

  @override
  String get navHome => 'Utama';

  @override
  String get navExplore => 'Terokai';

  @override
  String get navInbox => 'Peti Masuk';

  @override
  String get navProfile => 'Profil';

  @override
  String get navMyProfile => 'Profil Saya';

  @override
  String get navNotifications => 'Pemberitahuan';

  @override
  String get navOpenCamera => 'Buka kamera';

  @override
  String get navExploreClassics => 'Klasik';

  @override
  String get navExploreNewVideos => 'Video Baharu';

  @override
  String get navExploreTrending => 'Sedang Hangat';

  @override
  String get navExploreForYou => 'Untuk Anda';

  @override
  String get navExploreLists => 'Senarai';

  @override
  String get routeErrorTitle => 'Ralat';

  @override
  String get routeInvalidHashtag => 'Hashtag tidak sah';

  @override
  String get routeInvalidConversationId => 'ID perbualan tidak sah';

  @override
  String get routeInvalidRequestId => 'ID permintaan tidak sah';

  @override
  String get routeInvalidListId => 'ID senarai tidak sah';

  @override
  String get routeInvalidUserId => 'ID pengguna tidak sah';

  @override
  String get routeInvalidVideoId => 'ID video tidak sah';

  @override
  String get routeInvalidSoundId => 'ID bunyi tidak sah';

  @override
  String get routeInvalidCategory => 'Kategori tidak sah';

  @override
  String get routeNoVideosToDisplay => 'Tiada video untuk dipaparkan';

  @override
  String get routeGoHome => 'Ke laman utama';

  @override
  String get routeInvalidProfileId => 'ID profil tidak sah';

  @override
  String get routeUnknownPath => 'Halaman itu tiada dalam apl.';

  @override
  String get routeDefaultListName => 'Senarai';

  @override
  String get supportTitle => 'Pusat Sokongan';

  @override
  String get supportContactSupport => 'Hubungi Sokongan';

  @override
  String get supportContactSupportSubtitle =>
      'Mulakan perbualan atau lihat mesej lalu';

  @override
  String get supportReportBug => 'Laporkan Pepijat';

  @override
  String get supportReportBugSubtitle => 'Isu teknikal dengan apl';

  @override
  String get supportRequestFeature => 'Minta Ciri Baharu';

  @override
  String get supportRequestFeatureSubtitle =>
      'Cadangkan penambahbaikan atau ciri baharu';

  @override
  String get supportSaveLogs => 'Simpan Log';

  @override
  String get supportSaveLogsSubtitle =>
      'Eksport log ke fail untuk penghantaran manual';

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
  String get supportFaq => 'Soalan Lazim';

  @override
  String get supportFaqSubtitle => 'Soalan & jawapan lazim';

  @override
  String get supportFamily => 'Divine Family';

  @override
  String get supportFamilySubtitle =>
      'Membantu ibu bapa dan remaja membina tabiat sihat dalam talian';

  @override
  String get supportKids => 'Divine Kids';

  @override
  String get supportKidsSubtitle =>
      'Cara kami mengendalikan akaun mengikut umur';

  @override
  String get supportProofMode => 'ProofMode';

  @override
  String get supportProofModeSubtitle =>
      'Ketahui tentang pengesahan dan kesahihan';

  @override
  String get supportLoginRequired => 'Log masuk untuk menghubungi sokongan';

  @override
  String get supportExportingLogs => 'Mengeksport log...';

  @override
  String get supportExportLogsFailed => 'Gagal mengeksport log';

  @override
  String get supportNoLogsToExport =>
      'No logs yet — they start fresh each launch. Reproduce the problem, then come back without restarting.';

  @override
  String get supportExportLogsUnconfirmed =>
      'Logs handed off. Check the app you shared to.';

  @override
  String supportLogsSavedTo(String path) {
    return 'Log disimpan ke $path';
  }

  @override
  String get supportRevealLogsAction => 'Tunjuk dalam folder';

  @override
  String get supportChatNotAvailable => 'Sembang sokongan tidak tersedia';

  @override
  String get supportCouldNotOpenMessages =>
      'Tidak dapat membuka mesej sokongan';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return 'Tidak dapat membuka $pageName';
  }

  @override
  String get reportWhyReporting => 'Mengapa anda melaporkan kandungan ini?';

  @override
  String get reportPolicyNotice =>
      'Divine akan mengambil tindakan terhadap laporan kandungan dalam masa 24 jam dengan mengalih keluar kandungan itu dan mengeluarkan pengguna yang menyediakan kandungan yang melanggar.';

  @override
  String get reportBlockUser => 'Sekat pengguna ini';

  @override
  String get reportCancel => 'Batal';

  @override
  String get reportSubmit => 'Laporkan';

  @override
  String get reportSelectReason =>
      'Sila pilih sebab untuk melaporkan kandungan ini';

  @override
  String get reportOtherRequiresDetails =>
      'Sila terangkan isu itu apabila memilih Lain-lain';

  @override
  String get reportDetailsRequired => 'Sila terangkan isu itu';

  @override
  String get reportDetailsTextOnly =>
      'Teks sahaja — foto dan GIF tidak boleh dilampirkan di sini.';

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
  String get reportReasonSpam => 'Spam atau Kandungan Tidak Diingini';

  @override
  String get reportReasonSpamSubtitle =>
      'Kandungan tidak diingini atau berulang';

  @override
  String get reportReasonHarassment => 'Gangguan, Buli atau Ancaman';

  @override
  String get reportReasonHarassmentSubtitle =>
      'Balasan atau sebutan yang memudaratkan dan tidak diingini';

  @override
  String get reportReasonViolence => 'Kandungan Ganas atau Ekstremis';

  @override
  String get reportReasonViolenceSubtitle =>
      'Kandungan ganas, ekstremis atau memudaratkan';

  @override
  String get reportReasonSexualContent => 'Kandungan Seksual atau Dewasa';

  @override
  String get reportReasonSexualContentSubtitle =>
      'Kebogelan, lucah atau kandungan eksplisit';

  @override
  String get reportReasonCopyright => 'Pelanggaran Hak Cipta';

  @override
  String get reportReasonCopyrightSubtitle =>
      'Penggunaan harta intelek tanpa kebenaran';

  @override
  String get reportReasonFalseInfo => 'Maklumat Palsu';

  @override
  String get reportReasonFalseInfoSubtitle =>
      'Dakwaan yang mengelirukan atau palsu';

  @override
  String get reportReasonChildSafety => 'Pelanggaran Keselamatan Kanak-kanak';

  @override
  String get reportReasonChildSafetySubtitle =>
      'Kebimbangan umum tentang keselamatan kanak-kanak';

  @override
  String get reportReasonCsam => 'Penderaan Seksual Kanak-kanak';

  @override
  String get reportReasonCsamSubtitle =>
      'Kandungan yang memaparkan penderaan seksual kanak-kanak';

  @override
  String get reportReasonUnderageUser => 'Pengguna Kelihatan Bawah 16 Tahun';

  @override
  String get reportReasonUnderageUserSubtitle =>
      'Pemegang akaun kelihatan bawah umur';

  @override
  String get reportReasonAiGenerated => 'Kandungan Dijana AI';

  @override
  String get reportReasonAiGeneratedSubtitle =>
      'Kandungan yang disyaki dijana AI';

  @override
  String get reportReasonOther => 'Pelanggaran Dasar Lain';

  @override
  String get reportReasonOtherSubtitle =>
      'Pelanggaran yang tidak disenaraikan di atas';

  @override
  String get reportFailed => 'Gagal melaporkan kandungan. Sila cuba lagi.';

  @override
  String get reportNotSent =>
      'Laporan anda tidak dapat dihantar. Semak sambungan anda dan cuba lagi.';

  @override
  String get reportReceivedTitle => 'Laporan Diterima';

  @override
  String get reportReceivedThankYou =>
      'Terima kasih kerana membantu memastikan Divine selamat.';

  @override
  String get reportReceivedReviewNotice =>
      'Pasukan kami akan menyemak laporan anda dan mengambil tindakan yang sewajarnya. Anda mungkin menerima kemas kini melalui mesej langsung.';

  @override
  String get reportModerationDmDelayed =>
      'Kami tidak dapat menghubungi pasukan kesederhanaan secara langsung sekarang, tetapi laporan anda telah diterima dan akan disemak.';

  @override
  String get reportContactModeration =>
      'Hantar mesej kepada pasukan kesederhanaan';

  @override
  String get reportLearnMoreAt => 'Ketahui lebih lanjut di';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => 'Tutup';

  @override
  String get listAddToList => 'Tambah ke Senarai';

  @override
  String listVideoCount(int count) {
    return '$count video';
  }

  @override
  String listPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count orang',
      one: '1 orang',
    );
    return '$_temp0';
  }

  @override
  String get listByAuthorPrefix => 'Oleh ';

  @override
  String get listNewList => 'Senarai Baharu';

  @override
  String get listDone => 'Siap';

  @override
  String get listErrorLoading => 'Ralat memuatkan senarai';

  @override
  String listRemovedFrom(String name) {
    return 'Dialih keluar daripada $name';
  }

  @override
  String listAddedTo(String name) {
    return 'Ditambah ke $name';
  }

  @override
  String get listCreateNewList => 'Cipta Senarai Baharu';

  @override
  String get listNewPeopleList => 'Senarai orang baharu';

  @override
  String get listCollaboratorsNone => 'Tiada';

  @override
  String get listAddCollaboratorTitle => 'Tambah kolaborator';

  @override
  String get listCollaboratorSearchHint => 'Cari Divine...';

  @override
  String get listNameLabel => 'Nama Senarai';

  @override
  String get listDescriptionLabel => 'Keterangan (pilihan)';

  @override
  String get listPublicList => 'Senarai Awam';

  @override
  String get listPublicListSubtitle =>
      'Orang lain boleh mengikuti dan melihat senarai ini';

  @override
  String get listPrivateListSubtitle =>
      'Video kekal peribadi. Nama, keterangan, tag dan kulit kekal kelihatan.';

  @override
  String get listVisibilityPublic => 'Awam';

  @override
  String get listVisibilityPrivate => 'Peribadi';

  @override
  String get profileListsEmpty =>
      'Belum ada senarai. Buat satu untuk loop yang anda mahu simpan bersama.';

  @override
  String get listEditTitle => 'Edit senarai';

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
  String get listShareAction => 'Kongsi senarai';

  @override
  String get listShareFailed => 'Senarai ini tidak dapat dikongsi. Cuba lagi.';

  @override
  String get listSave => 'Simpan';

  @override
  String get listContinue => 'Teruskan';

  @override
  String get listPrivateFull =>
      'This private list is full. Remove something to add more.';

  @override
  String get listUpdateFailed =>
      'Senarai ini tidak dapat dikemas kini. Cuba lagi.';

  @override
  String get listMakePrivateTitle => 'Jadikan senarai ini peribadi?';

  @override
  String get listMakePrivateWarning =>
      'Video akan disulitkan supaya hanya anda yang boleh melihatnya. Nama, keterangan, tag dan kulit kekal kelihatan, dan salinan yang sudah dikongsi mungkin masih ada.';

  @override
  String get listMakePublicTitle => 'Jadikan senarai ini awam?';

  @override
  String get listMakePublicWarning =>
      'Sesiapa yang ada pautan boleh melihat senarai ini dan videonya.';

  @override
  String listShareText(String name, String url) {
    return 'Tengok $name di Divine: $url';
  }

  @override
  String listShareSubject(String name) {
    return '$name di Divine';
  }

  @override
  String get listCancel => 'Batal';

  @override
  String get listCreate => 'Cipta';

  @override
  String get listCreateFailed => 'Gagal mencipta senarai';

  @override
  String get keyManagementTitle => 'Kunci Nostr';

  @override
  String get keyManagementWhatAreKeys => 'Apakah kunci Nostr?';

  @override
  String get keyManagementExplanation =>
      'Identiti Nostr anda ialah pasangan kunci kriptografi:\n\n• Kunci awam anda (npub) adalah seperti nama pengguna anda - kongsi dengan bebas\n• Kunci peribadi anda (nsec) adalah seperti kata laluan anda - rahsiakannya!\n\nnsec anda membolehkan anda mengakses akaun anda pada mana-mana apl Nostr.';

  @override
  String get keyManagementImportTitle => 'Import Kunci Sedia Ada';

  @override
  String get keyManagementImportSubtitle =>
      'Sudah mempunyai akaun Nostr? Tampal kunci peribadi anda (nsec) untuk mengaksesnya di sini.';

  @override
  String get keyManagementImportButton => 'Import Kunci';

  @override
  String get keyManagementImportWarning =>
      'Ini akan menggantikan kunci semasa anda!';

  @override
  String get keyManagementBackupTitle => 'Sandar Kunci Anda';

  @override
  String get keyManagementBackupSubtitle =>
      'Simpan kunci peribadi anda (nsec) untuk menggunakan akaun anda dalam apl Nostr lain.';

  @override
  String get keyManagementCopyNsec => 'Salin Kunci Peribadi Saya (nsec)';

  @override
  String get keyManagementNeverShare =>
      'Jangan sesekali kongsi nsec anda dengan sesiapa!';

  @override
  String get keyManagementKeycastRemoteSigning =>
      'Kunci anda berada pada perkhidmatan log masuk Divine, bukan pada peranti ini. Sahkan kata laluan anda dan kami akan mengambilnya untuk anda.';

  @override
  String get keyManagementKeycastPasswordPrompt =>
      'Kunci anda disimpan oleh perkhidmatan log masuk Divine. Masukkan kata laluan akaun anda dan kami akan mengambilnya.';

  @override
  String get keyManagementKeycastCopyKey => 'Salin kunci';

  @override
  String get keyManagementKeycastCopyBlocked =>
      'Peranti anda menyekat penyalinan, jadi kunci anda tidak sampai ke papan klip.';

  @override
  String get keyManagementKeycastWrongPassword =>
      'Kata laluan itu tidak sepadan. Cuba lagi.';

  @override
  String get keyManagementKeycastTooManyAttempts =>
      'Terlalu banyak percubaan. Tutup ini dan mula semula.';

  @override
  String get keyManagementKeycastRateLimited =>
      'Terlalu banyak permintaan kunci. Tunggu beberapa minit dan cuba lagi.';

  @override
  String get keyManagementKeycastSignInAgain =>
      'Sesi anda telah tamat tempoh. Log masuk semula untuk menyalin kunci anda.';

  @override
  String get keyManagementKeycastEmailUnverified =>
      'Sahkan alamat e-mel anda sebelum menyalin kunci anda.';

  @override
  String get keyManagementKeycastDenied =>
      'Divine menguruskan kunci akaun ini, jadi ia tidak boleh disalin di sini.';

  @override
  String get keyManagementKeycastNoKey =>
      'Tiada kunci direkodkan untuk akaun ini.';

  @override
  String get keyManagementKeycastGenericFailure =>
      'Perkhidmatan log masuk tidak dapat dihubungi. Sila cuba lagi.';

  @override
  String get keyManagementRestrictedTitle => 'Kunci anda diuruskan oleh Divine';

  @override
  String get keyManagementRestrictedBody =>
      'Untuk memastikan akaun anda selamat, sandaran kunci dan pengimportan kunci lain tidak tersedia di sini.';

  @override
  String get keyManagementPasteKey => 'Sila tampal kunci peribadi anda';

  @override
  String get keyManagementInvalidFormat =>
      'Format kunci tidak sah. Mestilah bermula dengan \"nsec1\"';

  @override
  String get keyManagementConfirmImportTitle => 'Import Kunci Ini?';

  @override
  String get keyManagementConfirmImportBody =>
      'Ini akan menggantikan identiti semasa anda dengan yang diimport.\n\nKunci semasa anda akan hilang kecuali anda telah menyandarnya dahulu.';

  @override
  String get keyManagementImportConfirm => 'Import';

  @override
  String get keyManagementImportSuccess => 'Kunci berjaya diimport!';

  @override
  String get keyManagementImportFailed =>
      'Gagal mengimport kunci. Sila cuba lagi.';

  @override
  String get keyManagementExportSuccess =>
      'Kunci peribadi disalin ke papan klip!\n\nSimpannya di tempat yang selamat.';

  @override
  String get keyManagementExportFailed =>
      'Gagal mengeksport kunci. Sila cuba lagi.';

  @override
  String get keyManagementYourPublicKeyLabel => 'Kunci awam anda (npub)';

  @override
  String get keyManagementCopyPublicKeyTooltip => 'Salin kunci awam';

  @override
  String get keyManagementPublicKeyCopied => 'Kunci awam disalin';

  @override
  String get saveOriginalSavedToCameraRoll => 'Disimpan ke Rol Kamera';

  @override
  String get saveOriginalShare => 'Kongsi';

  @override
  String get saveOriginalDone => 'Siap';

  @override
  String get saveOriginalPhotosAccessNeeded => 'Akses Foto Diperlukan';

  @override
  String get saveOriginalPhotosAccessMessage =>
      'Untuk menyimpan video, benarkan akses Foto dalam Tetapan.';

  @override
  String get saveOriginalOpenSettings => 'Buka Tetapan';

  @override
  String get saveOriginalNotNow => 'Bukan Sekarang';

  @override
  String get saveOriginalDownloadFailed => 'Muat Turun Gagal';

  @override
  String get saveOriginalDismiss => 'Ketepikan';

  @override
  String get saveOriginalDownloadingVideo => 'Memuat Turun Video';

  @override
  String get saveOriginalSavingToCameraRoll => 'Menyimpan ke Rol Kamera';

  @override
  String get saveOriginalFetchingVideo =>
      'Mengambil video daripada rangkaian...';

  @override
  String get saveOriginalSavingVideo =>
      'Menyimpan video asal ke rol kamera anda...';

  @override
  String get soundTitle => 'Bunyi';

  @override
  String get soundOriginalSound => 'Bunyi asal';

  @override
  String get soundVideosUsingThisSound => 'Video menggunakan bunyi ini';

  @override
  String get soundSourceVideo => 'Video sumber';

  @override
  String get soundNoVideosYet => 'Belum ada video';

  @override
  String get soundBeFirstToUse => 'Jadilah yang pertama menggunakan bunyi ini!';

  @override
  String get soundFailedToLoadVideos => 'Gagal memuatkan video';

  @override
  String get soundRetry => 'Cuba Semula';

  @override
  String get soundVideosUnavailable => 'Video tidak tersedia';

  @override
  String get soundCouldNotLoadDetails => 'Tidak dapat memuatkan butiran video';

  @override
  String get soundPreview => 'Pratonton';

  @override
  String get soundStop => 'Berhenti';

  @override
  String get soundUseSound => 'Guna Bunyi';

  @override
  String get soundUntitled => 'Bunyi tanpa tajuk';

  @override
  String get soundStopPreview => 'Hentikan pratonton';

  @override
  String soundPreviewSemanticLabel(String title) {
    return 'Pratonton $title';
  }

  @override
  String soundViewDetailsSemanticLabel(String title) {
    return 'Lihat butiran untuk $title';
  }

  @override
  String get soundNoVideoCount => 'Belum ada video';

  @override
  String get soundOneVideo => '1 video';

  @override
  String soundVideoCount(int count) {
    return '$count video';
  }

  @override
  String get soundUnableToPreview =>
      'Tidak dapat pratonton bunyi - tiada audio tersedia';

  @override
  String get soundPreviewFailed => 'Gagal memainkan pratonton. Sila cuba lagi.';

  @override
  String get soundViewSource => 'Lihat sumber';

  @override
  String get soundCloseTooltip => 'Tutup';

  @override
  String get exploreNotExploreRoute => 'Bukan laluan terokai';

  @override
  String get legalTitle => 'Undang-undang';

  @override
  String get legalTermsOfService => 'Terma Perkhidmatan';

  @override
  String get legalTermsOfServiceSubtitle => 'Terma dan syarat penggunaan';

  @override
  String get legalPrivacyPolicy => 'Dasar Privasi';

  @override
  String get legalPrivacyPolicySubtitle =>
      'Bagaimana kami mengendalikan data anda';

  @override
  String get legalSafetyStandards => 'Piawaian Keselamatan';

  @override
  String get legalSafetyStandardsSubtitle =>
      'Garis panduan komuniti dan keselamatan';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle => 'Dasar hak cipta dan pemadaman';

  @override
  String get legalOpenSourceLicenses => 'Lesen Sumber Terbuka';

  @override
  String get legalOpenSourceLicensesSubtitle => 'Atribusi pakej pihak ketiga';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return 'Tidak dapat membuka $pageName';
  }

  @override
  String get categoryAction => 'Aksi';

  @override
  String get categoryAdventure => 'Pengembaraan';

  @override
  String get categoryAnimals => 'Haiwan';

  @override
  String get categoryAnimation => 'Animasi';

  @override
  String get categoryArchitecture => 'Seni Bina';

  @override
  String get categoryArt => 'Seni';

  @override
  String get categoryAutomotive => 'Automotif';

  @override
  String get categoryAwardShow => 'Majlis Anugerah';

  @override
  String get categoryAwards => 'Anugerah';

  @override
  String get categoryBaseball => 'Besbol';

  @override
  String get categoryBasketball => 'Bola Keranjang';

  @override
  String get categoryBeauty => 'Kecantikan';

  @override
  String get categoryBeverage => 'Minuman';

  @override
  String get categoryCars => 'Kereta';

  @override
  String get categoryCelebration => 'Sambutan';

  @override
  String get categoryCelebrities => 'Selebriti';

  @override
  String get categoryCelebrity => 'Selebriti';

  @override
  String get categoryCityscape => 'Pemandangan Bandar';

  @override
  String get categoryComedy => 'Komedi';

  @override
  String get categoryConcert => 'Konsert';

  @override
  String get categoryCooking => 'Masakan';

  @override
  String get categoryCostume => 'Kostum';

  @override
  String get categoryCrafts => 'Kraf';

  @override
  String get categoryCrime => 'Jenayah';

  @override
  String get categoryCulture => 'Budaya';

  @override
  String get categoryDance => 'Tarian';

  @override
  String get categoryDiy => 'DIY';

  @override
  String get categoryDrama => 'Drama';

  @override
  String get categoryEducation => 'Pendidikan';

  @override
  String get categoryEmotional => 'Menyentuh';

  @override
  String get categoryEmotions => 'Emosi';

  @override
  String get categoryEntertainment => 'Hiburan';

  @override
  String get categoryEvent => 'Acara';

  @override
  String get categoryFamily => 'Keluarga';

  @override
  String get categoryFans => 'Peminat';

  @override
  String get categoryFantasy => 'Fantasi';

  @override
  String get categoryFashion => 'Gaya';

  @override
  String get categoryFestival => 'Festival';

  @override
  String get categoryFilm => 'Filem';

  @override
  String get categoryFitness => 'Kecergasan';

  @override
  String get categoryFood => 'Makanan';

  @override
  String get categoryFootball => 'Bola Sepak';

  @override
  String get categoryFurniture => 'Perabot';

  @override
  String get categoryGaming => 'Gaming';

  @override
  String get categoryGolf => 'Golf';

  @override
  String get categoryGrooming => 'Dandanan';

  @override
  String get categoryGuitar => 'Gitar';

  @override
  String get categoryHalloween => 'Halloween';

  @override
  String get categoryHealth => 'Kesihatan';

  @override
  String get categoryHockey => 'Hoki';

  @override
  String get categoryHoliday => 'Percutian';

  @override
  String get categoryHome => 'Rumah';

  @override
  String get categoryHomeImprovement => 'Penambahbaikan Rumah';

  @override
  String get categoryHorror => 'Seram';

  @override
  String get categoryHospital => 'Hospital';

  @override
  String get categoryHumor => 'Jenaka';

  @override
  String get categoryInteriorDesign => 'Reka Bentuk Dalaman';

  @override
  String get categoryInterview => 'Temu Bual';

  @override
  String get categoryKids => 'Kanak-kanak';

  @override
  String get categoryLifestyle => 'Gaya Hidup';

  @override
  String get categoryMagic => 'Magis';

  @override
  String get categoryMakeup => 'Solekan';

  @override
  String get categoryMedical => 'Perubatan';

  @override
  String get categoryMusic => 'Muzik';

  @override
  String get categoryMystery => 'Misteri';

  @override
  String get categoryNature => 'Alam';

  @override
  String get categoryNews => 'Berita';

  @override
  String get categoryOutdoor => 'Aktiviti Luar';

  @override
  String get categoryParty => 'Parti';

  @override
  String get categoryPeople => 'Orang';

  @override
  String get categoryPerformance => 'Persembahan';

  @override
  String get categoryPets => 'Haiwan Peliharaan';

  @override
  String get categoryPolitics => 'Politik';

  @override
  String get categoryPrank => 'Prank';

  @override
  String get categoryPranks => 'Prank';

  @override
  String get categoryRealityShow => 'Rancangan Realiti';

  @override
  String get categoryRelationship => 'Hubungan';

  @override
  String get categoryRelationships => 'Hubungan';

  @override
  String get categoryRomance => 'Percintaan';

  @override
  String get categorySchool => 'Sekolah';

  @override
  String get categoryScienceFiction => 'Fiksyen Sains';

  @override
  String get categorySelfie => 'Swafoto';

  @override
  String get categoryShopping => 'Membeli-belah';

  @override
  String get categorySkateboarding => 'Papan Luncur';

  @override
  String get categorySkincare => 'Penjagaan Kulit';

  @override
  String get categorySoccer => 'Bola Sepak';

  @override
  String get categorySocialGathering => 'Perhimpunan Sosial';

  @override
  String get categorySocialMedia => 'Media Sosial';

  @override
  String get categorySports => 'Sukan';

  @override
  String get categoryTalkShow => 'Rancangan Bual Bicara';

  @override
  String get categoryTech => 'Teknologi';

  @override
  String get categoryTechnology => 'Teknologi';

  @override
  String get categoryTelevision => 'Televisyen';

  @override
  String get categoryToys => 'Mainan';

  @override
  String get categoryTransportation => 'Pengangkutan';

  @override
  String get categoryTravel => 'Pelancongan';

  @override
  String get categoryUrban => 'Bandar';

  @override
  String get categoryViolence => 'Keganasan';

  @override
  String get categoryVlog => 'Vlog';

  @override
  String get categoryVlogging => 'Vlogging';

  @override
  String get categoryWrestling => 'Gusti';

  @override
  String get profileSetupUploadStaged =>
      'Dimuat naik — ketik Simpan untuk menggunakan';

  @override
  String inboxReportedUser(String displayName) {
    return '$displayName dilaporkan';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return '$displayName disekat';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return '$displayName dinyahsekat';
  }

  @override
  String get inboxRemovedConversation => 'Perbualan dialih keluar';

  @override
  String get inboxRestorePausedTitle =>
      'Sesetengah sembang belum selesai dipulihkan';

  @override
  String get conversationRestorePausedTitle =>
      'Sembang ini belum selesai dipulihkan';

  @override
  String get inboxRestoreRetryAction => 'Cuba Semula';

  @override
  String get inboxRestoringMessages => 'Memulihkan mesej anda…';

  @override
  String get inboxEmptyTitle => 'Belum ada mesej';

  @override
  String get inboxEmptySubtitle => 'Butang + itu tidak menggigit.';

  @override
  String get inboxLoadErrorTitle => 'Mesej tidak dimuatkan';

  @override
  String get inboxLoadErrorSubtitle =>
      'Semak sambungan anda dan cuba sekali lagi.';

  @override
  String get inboxFilterAll => 'Semua';

  @override
  String get inboxFilterUnread => 'Belum dibaca';

  @override
  String get dmBlockedThreadTitle => 'Anda menyekat akaun ini';

  @override
  String get dmBlockedThreadBody =>
      'Mesej kekal di sini supaya anda boleh membacanya atau mengambil tangkap layar. Nyahsekat untuk membalas.';

  @override
  String get inboxFilterBlocked => 'Disekat';

  @override
  String get inboxBlockedEmptyTitle => 'Tiada sembang disekat';

  @override
  String get inboxBlockedEmptySubtitle =>
      'Akaun yang anda sekat akan muncul di sini.';

  @override
  String get inboxBlockedNoMessages => 'Tiada mesej';

  @override
  String get inboxUnreadEmptyTitle => 'Anda sudah baca semuanya';

  @override
  String get inboxUnreadEmptySubtitle => 'Tiada mesej belum dibaca sekarang.';

  @override
  String get inboxSearchHint => 'Cari mesej';

  @override
  String get inboxSupportRowTitle => 'Pemantauan Divine';

  @override
  String get inboxSupportRowSubtitle =>
      'Pepijat, kesederhanaan, hal akaun — kami mendengar.';

  @override
  String get inboxSearchEmptyTitle => 'Tiada padanan';

  @override
  String get inboxSearchEmptySubtitle => 'Cuba nama atau perkataan lain.';

  @override
  String get inboxActionMute => 'Senyapkan perbualan';

  @override
  String inboxActionReport(String displayName) {
    return 'Laporkan $displayName';
  }

  @override
  String inboxActionBlock(String displayName) {
    return 'Sekat $displayName';
  }

  @override
  String inboxActionUnblock(String displayName) {
    return 'Nyahsekat $displayName';
  }

  @override
  String get inboxActionRemove => 'Alih keluar perbualan';

  @override
  String get inboxRemoveConfirmTitle => 'Alih keluar perbualan?';

  @override
  String inboxRemoveConfirmBody(String displayName) {
    return 'Ini mengalih keluar perbualan anda dengan $displayName daripada peti masuk anda. Jika dia menghantar mesej lagi, perbualan baharu akan bermula.';
  }

  @override
  String get inboxRemoveConfirmBodyGroup =>
      'Ini mengalih keluar perbualan kumpulan daripada peti masuk anda. Jika sesiapa menghantar mesej lagi dalam kumpulan itu, perbualan baharu akan bermula.';

  @override
  String get inboxRemoveConfirmConfirm => 'Alih Keluar';

  @override
  String get inboxConversationMuted => 'Perbualan disenyapkan';

  @override
  String get inboxConversationUnmuted => 'Perbualan dinyahsenyap';

  @override
  String get inboxCollabInviteCardTitle => 'Jemputan kolaborator';

  @override
  String get inboxCollabInviteCardUntitledVideo => 'Video tanpa tajuk';

  @override
  String get clickableTextViewVideoLink => 'Lihat video';

  @override
  String get messageExternalLinkDialogTitle => 'Buka pautan luaran?';

  @override
  String messageExternalLinkDialogBody(String url) {
    return 'Pautan ini menuju ke tapak luaran dan mungkin tidak selamat:\n\n$url';
  }

  @override
  String get messageExternalLinkDialogOpen => 'Buka';

  @override
  String get inboxCollabInviteCoPostButton => 'Siar bersama';

  @override
  String get inboxCollabInviteNotMineButton => 'Bukan milik saya';

  @override
  String get inboxCollabInvitePreviewTitle => 'Jemputan siar bersama';

  @override
  String inboxCollabInvitePreviewTitleFrom(String displayName) {
    return 'Jemputan siar bersama daripada $displayName';
  }

  @override
  String get inboxCollabInviteTimelineConsequence =>
      'Menyiar bersama menambah video ini ke garis masa anda sebagai kolaborasi.';

  @override
  String get inboxCollabInviteAcceptedStatus => 'Diterima';

  @override
  String get inboxCollabInviteIgnoredStatus => 'Diabaikan';

  @override
  String get inboxCollabInviteAcceptError => 'Tidak dapat menerima. Cuba lagi.';

  @override
  String get inboxCollabInviteSentStatus => 'Jemputan dihantar';

  @override
  String get inboxConversationCollabInvitePreview => 'Jemputan kolaborator';

  @override
  String collaboratorInviteDmBody(String title, String url) {
    return 'Anda dijemput untuk berkolaborasi pada $title: $url\n\nOpen Divine to review and accept.';
  }

  @override
  String collaboratorInviteDmBodyUntitled(String url) {
    return 'Anda dijemput untuk berkolaborasi pada video: $url\n\nOpen Divine to review and accept.';
  }

  @override
  String videoPublishCollaboratorInviteWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jemputan kolaborator tidak dihantar.',
      one: '1 jemputan kolaborator tidak dihantar.',
    );
    return 'Video disiarkan, tetapi $_temp0';
  }

  @override
  String get dmSendNoRecipientMessage =>
      'Kami tidak dapat mengenal pasti dengan siapa perbualan ini. Buka semula dari peti masuk anda.';

  @override
  String get dmSendBlockedMessage =>
      'Anda hanya boleh menghantar mesej kepada akaun rasmi Divine';

  @override
  String get dmSendBlockedRetiredMessage =>
      'Tiada sesiapa membaca perbualan ini. Hantar mesej kepada Divine Moderation sebaliknya.';

  @override
  String get dmDeletePendingLabel => 'Deleting for everyone';

  @override
  String get dmDeleteRefusedMessage => 'Tidak dapat memadam untuk semua orang.';

  @override
  String get dmDeleteRefusedDetails =>
      'Sesetengah orang mungkin masih dapat melihat mesej ini.';

  @override
  String get dmRetiredThreadClosedTitle => 'Perbualan ini telah ditutup.';

  @override
  String get messageRequestModerationNoticeCannotBeRemoved =>
      'Notis Divine Moderation ini tidak boleh dialih keluar.';

  @override
  String get dmRetiredThreadClosedBody =>
      'Kami telah memindahkan Divine Moderation ke akaun baharu. Akaun ini tidak dibaca lagi.';

  @override
  String get dmRetiredThreadOpenSupport =>
      'Hantar mesej kepada Divine Moderation';

  @override
  String get dmSendTooLongMessage =>
      'That message is too long to send. Shorten it and try again.';

  @override
  String get dmSendFailedMessage => 'Mesej tidak dapat dihantar';

  @override
  String get dmResendFailedMessage => 'Masih tidak dapat dihantar';

  @override
  String get dmSendFailedSubtitle =>
      'Hantar semula sekarang, atau berhenti mencuba.';

  @override
  String get dmSendFailedRetry => 'Cuba Semula';

  @override
  String get dmSendPartialMessage =>
      'Dihantar, tetapi tidak disegerakkan ke peranti anda yang lain';

  @override
  String get dmConversationLoadError => 'Tidak dapat memuatkan mesej';

  @override
  String get dmMessageInputHint => 'Katakan sesuatu…';

  @override
  String get dmMessageBubbleSentHint => 'Mesej dihantar';

  @override
  String get dmMessageBubbleReceivedHint => 'Mesej diterima';

  @override
  String get dmMessageBubbleLongPressHint => 'Tindakan mesej';

  @override
  String get dmMessageBubbleFailedTapHint =>
      'Hantar semula atau padam mesej ini';

  @override
  String get dmMessageActionCopyText => 'Salin teks';

  @override
  String get dmMessageActionCopyVideoUrl => 'Salin URL video';

  @override
  String get dmMessageActionDeleteForEveryone => 'Padam untuk semua orang';

  @override
  String get dmMessageActionReport => 'Laporkan';

  @override
  String get dmMessageActionRetrySend => 'Hantar semula';

  @override
  String get dmMessageActionCancelSend => 'Berhenti mencuba';

  @override
  String get dmReactionAddCustomA11yLabel =>
      'Tambah tindak balas emoji tersuai';

  @override
  String dmReelReplyComposerHint(String name) {
    return 'Mesej $name…';
  }

  @override
  String get dmReelReplyComposerHintSelf => 'Balas kepada diri sendiri…';

  @override
  String get dmReelReplyComposerSemanticLabel => 'Balas kepada reel ini';

  @override
  String get dmReelReplyViewChat => 'Lihat sembang';

  @override
  String get dmReelReplySentAnnouncement => 'Balasan dihantar';

  @override
  String dmReelReactionSentAnnouncement(String emoji) {
    return 'Bertindak balas $emoji';
  }

  @override
  String get dmReelReplyFailed => 'Tidak dapat menghantar';

  @override
  String get dmReelReplyUnverified => 'Tidak dapat mengesahkan penghantaran';

  @override
  String dmReactionChipOwnA11yLabel(String emoji) {
    return 'Tindak balas anda: $emoji';
  }

  @override
  String dmReactionChipOtherA11yLabel(String name, String emoji) {
    return '$name bertindak balas dengan $emoji';
  }

  @override
  String dmReactionChipPendingA11yLabel(String emoji) {
    return 'Menghantar tindak balas: $emoji';
  }

  @override
  String get dmReactionChipFailedA11yLabel =>
      'Tindak balas gagal, ketik dua kali untuk cuba semula';

  @override
  String get dmReactionChipRetryAnnouncement => 'Mencuba semula tindak balas';

  @override
  String dmReactionRemovalRefusedA11yLabel(String emoji) {
    return 'Couldn\'t remove your $emoji reaction. Double tap to try again';
  }

  @override
  String get dmReactionRemovalRefusedTitle => 'Couldn\'t remove your reaction.';

  @override
  String get dmReactionAddBlockedByRemoval =>
      'Selesaikan pengalihan keluar reaksi terdahulu sebelum menambah reaksi lain.';

  @override
  String get dmReactionRemovalRefusedDetails =>
      'Some people may still be able to see this reaction.';

  @override
  String get dmReactionsSheetTitle => 'Tindak balas';

  @override
  String get dmReactionsViewA11yLabel => 'Lihat siapa yang bertindak balas';

  @override
  String get dmReactionRemoveAction => 'Alih Keluar';

  @override
  String get dmReactionRetryAction => 'Cuba Semula';

  @override
  String get dmFormatBold => 'Tebal';

  @override
  String get dmFormatItalic => 'Condong';

  @override
  String get dmFormatStrikethrough => 'Garis lorek';

  @override
  String get dmFormatCode => 'Kod';

  @override
  String get dmStatusFailed => 'Gagal menghantar';

  @override
  String get inboxConversationActionsSheetLabel => 'Tindakan perbualan';

  @override
  String inboxConversationTileLabel(String displayName) {
    return 'Perbualan $displayName';
  }

  @override
  String inboxConversationTileLabelUnread(String displayName) {
    return 'Belum dibaca, perbualan $displayName';
  }

  @override
  String inboxGroupConversationTitle(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count orang lain',
    );
    return '$name dan $_temp0';
  }

  @override
  String get inboxConversationTileLongPressHint => 'Tunjuk tindakan perbualan';

  @override
  String exploreVideoId(String id) {
    return 'ID: $id';
  }

  @override
  String exploreVideoTitle(String title) {
    return 'Tajuk: $title';
  }

  @override
  String exploreVideoCounter(int current, int total) {
    return 'Video $current/$total';
  }

  @override
  String get exploreSearchHint => 'Cari...';

  @override
  String categoryVideoCount(int countValue, String count) {
    return '$count video';
  }

  @override
  String get discoverListsFailedToUpdateSubscription =>
      'Gagal mengemas kini langganan. Sila cuba lagi.';

  @override
  String get discoverListsTitle => 'Terokai Senarai';

  @override
  String get discoverListsFailedToLoad => 'Gagal memuatkan senarai';

  @override
  String get discoverListsLoading => 'Menemui senarai awam...';

  @override
  String get discoverListsRelayTimeout =>
      'Relay tidak memulangkan senarai tepat pada masanya. Cuba lagi.';

  @override
  String get discoverListsServiceUnavailable => 'Perkhidmatan tidak tersedia.';

  @override
  String get discoverListsEmptyTitle => 'Tiada senarai awam ditemui';

  @override
  String get discoverListsEmptySubtitle =>
      'Semak semula nanti untuk senarai baharu';

  @override
  String get discoverListsByAuthorPrefix => 'oleh';

  @override
  String get curatedListEmptyTitle => 'Tiada video dalam senarai ini';

  @override
  String get curatedListEmptySubtitle => 'Tambah beberapa video untuk bermula';

  @override
  String get curatedListLoadingVideos => 'Memuatkan video...';

  @override
  String get curatedListFailedToLoad => 'Gagal memuatkan senarai';

  @override
  String get curatedListVideoNotAvailable => 'Video tidak tersedia';

  @override
  String get curatedListActionsTooltip => 'Tindakan senarai';

  @override
  String get curatedListDeleteConfirmTitle => 'Padam senarai?';

  @override
  String get curatedListDeleteConfirmBody =>
      'Ini mengalih keluar senarai daripada relay. Video dalam senarai tidak akan dipadam.';

  @override
  String get curatedListDeletedSnack => 'Senarai dipadam';

  @override
  String get curatedListDeleteFailed => 'Tidak dapat memadam senarai';

  @override
  String get peopleListsActionsTooltip => 'Tindakan senarai';

  @override
  String get listDeleteAction => 'Padam senarai';

  @override
  String get peopleListsDeleteConfirmTitle => 'Padam senarai?';

  @override
  String get peopleListsDeleteConfirmBody =>
      'Ini mengalih keluar senarai untuk semua orang. Orang di dalamnya tidak akan dinyahikut.';

  @override
  String get peopleListsDeleteFailed => 'Tidak dapat memadam senarai';

  @override
  String get commonRetry => 'Cuba Semula';

  @override
  String get commonSomethingWentWrong => 'Sesuatu telah berlaku';

  @override
  String get commonDelete => 'Padam';

  @override
  String get commonCancel => 'Batal';

  @override
  String get commonBack => 'Kembali';

  @override
  String get commonClose => 'Tutup';

  @override
  String get commonNotNow => 'Bukan Sekarang';

  @override
  String get commonLoading => 'Memuatkan';

  @override
  String get videoMetadataEditCoverFailedSnackbar =>
      'Tidak dapat mengemas kini muka depan. Cuba lagi.';

  @override
  String get videoMetadataEditCoverSuccessAnnouncement =>
      'Muka depan dikemas kini';

  @override
  String get videoMetadataC2paMissingTitle =>
      'Siarkan tanpa semakan buatan manusia?';

  @override
  String get videoMetadataC2paMissingBody =>
      'Kami tidak dapat menambah kelayakan kandungan, jadi video ini tidak akan disahkan sebagai Buatan Manusia. Jana semula untuk cuba lagi, atau siarkan seadanya.';

  @override
  String get videoMetadataC2paMissingNote =>
      'Kelayakan kandungan memerlukan sambungan internet.';

  @override
  String get videoMetadataC2paMissingNoteServiceUnavailable =>
      'Perkhidmatan kelayakan kandungan tidak menjawab. Ini bukan masalah sambungan anda.';

  @override
  String get videoMetadataC2paMissingRegenerate => 'Jana semula';

  @override
  String get videoMetadataC2paMissingSkip => 'Langkau';

  @override
  String get videoMetadataGenerationFailed => 'Penjanaan gagal';

  @override
  String get videoMetadataTags => 'Tag';

  @override
  String get videoMetadataExpiration => 'Tamat tempoh';

  @override
  String get videoMetadataExpirationNotExpire => 'Tidak tamat tempoh';

  @override
  String get videoMetadataExpirationOneDay => '1 hari';

  @override
  String get videoMetadataExpirationOneWeek => '1 minggu';

  @override
  String get videoMetadataExpirationOneMonth => '1 bulan';

  @override
  String get videoMetadataExpirationOneYear => '1 tahun';

  @override
  String get videoMetadataExpirationOneDecade => '1 dekad';

  @override
  String get videoMetadataContentWarnings => 'Amaran Kandungan';

  @override
  String get videoEditorStickers => 'Pelekat';

  @override
  String get trendingTitle => 'Sedang Hangat';

  @override
  String get libraryDeleteConfirm => 'Padam';

  @override
  String get libraryWebUnavailableHeadline =>
      'Pustaka tersedia dalam apl mudah alih';

  @override
  String get libraryWebUnavailableDescription =>
      'Draf dan klip disimpan pada peranti anda, jadi buka Divine pada telefon anda untuk mengurusnya.';

  @override
  String get libraryTabDrafts => 'Draf';

  @override
  String get libraryTabClips => 'Klip';

  @override
  String get libraryDeleteSelectedClipsTooltip => 'Padam klip dipilih';

  @override
  String get libraryCloseSemanticLabel => 'Tutup pustaka';

  @override
  String get libraryStopSelectingClipsSemanticLabel => 'Berhenti memilih klip';

  @override
  String get librarySelectClipsSemanticLabel => 'Pilih klip';

  @override
  String get libraryGridSizeLabel => 'Saiz grid';

  @override
  String get libraryDisplayOptionsLabel => 'Susunan & saiz grid';

  @override
  String get libraryMoreActionsSemanticLabel => 'Lagi tindakan pustaka';

  @override
  String libraryGridSizeColumns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lajur',
    );
    return '$_temp0';
  }

  @override
  String get librarySelect => 'Pilih';

  @override
  String get librarySortNewestCreation => 'Ciptaan Terbaharu';

  @override
  String get librarySortOldestCreation => 'Ciptaan Terlama';

  @override
  String get librarySortLongestClip => 'Klip Terpanjang';

  @override
  String get librarySortShortestClip => 'Klip Terpendek';

  @override
  String get librarySortSquareFirst => 'Segi Empat Dahulu';

  @override
  String get librarySortVerticalFirst => 'Menegak Dahulu';

  @override
  String get libraryDeleteClipsWarning =>
      'Tindakan ini tidak boleh dibuat asal. Fail video akan dialih keluar secara kekal daripada peranti anda.';

  @override
  String get libraryPreparingVideo => 'Menyediakan video...';

  @override
  String libraryCreateVideo(int count) {
    return 'Cipta Video ($count)';
  }

  @override
  String libraryClipsSavedToDestination(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klip',
      one: '1 klip',
    );
    return '$_temp0 disimpan ke $destination';
  }

  @override
  String libraryClipsSavePartialResult(int successCount, int failureCount) {
    return '$successCount disimpan, $failureCount gagal';
  }

  @override
  String libraryClipsSaveFailed(String destination) {
    return 'Tidak dapat menyimpan ke $destination';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return 'Kebenaran $destination ditolak';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klip dipadam',
      one: '1 klip dipadam',
    );
    return '$_temp0';
  }

  @override
  String get libraryClipsDeletedUndoLabel => 'Buat Asal';

  @override
  String libraryTrashAutoDeletes(int daysLeft) {
    String _temp0 = intl.Intl.pluralLogic(
      daysLeft,
      locale: localeName,
      other: 'Dipadam automatik dalam $daysLeft hari',
      one: 'Dipadam automatik esok',
      zero: 'Dipadam automatik hari ini',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts => 'Tidak dapat memuatkan draf';

  @override
  String get libraryCouldNotLoadClips => 'Tidak dapat memuatkan klip';

  @override
  String get libraryOpenErrorDescription =>
      'Sesuatu telah berlaku semasa membuka pustaka anda. Anda boleh cuba lagi.';

  @override
  String get libraryNoDraftsYetTitle => 'Belum Ada Draf';

  @override
  String get libraryNoDraftsYetSubtitle =>
      'Video yang anda simpan sebagai draf akan muncul di sini';

  @override
  String get libraryNoClipsYetTitle => 'Belum Ada Klip';

  @override
  String get libraryNoClipsYetSubtitle =>
      'Klip video yang anda rakam akan muncul di sini';

  @override
  String get libraryDraftDeletedSnackbar => 'Draf dipadam';

  @override
  String get libraryDraftDeleteFailedSnackbar => 'Gagal memadam draf';

  @override
  String get libraryDraftDuplicatedSnackbar => 'Draf diduplikasi';

  @override
  String get libraryDraftDuplicateFailedSnackbar => 'Gagal menduplikasi draf';

  @override
  String get libraryDraftInProgressBadge => 'Sedang berjalan';

  @override
  String get libraryDraftActionPost => 'Siarkan';

  @override
  String get libraryDraftActionEdit => 'Sunting';

  @override
  String get libraryDraftActionDuplicate => 'Duplikasi';

  @override
  String get libraryDraftActionDelete => 'Padam draf';

  @override
  String libraryDraftCopyTitle(String title, int number) {
    return '$title (salinan $number)';
  }

  @override
  String get libraryDeleteDraftTitle => 'Padam Draf';

  @override
  String libraryDeleteDraftMessage(String title) {
    return 'Adakah anda pasti mahu memadam \"$title\"?';
  }

  @override
  String get libraryDeleteClipTitle => 'Padam Klip';

  @override
  String get libraryDeleteClipMessage =>
      'Adakah anda pasti mahu memadam klip ini?';

  @override
  String libraryClipDuration(String seconds) {
    return '${seconds}s';
  }

  @override
  String get libraryRecordVideo => 'Rakam Video';

  @override
  String videoClipSemanticLabel(String duration) {
    return 'Klip video, $duration saat';
  }

  @override
  String videoClipArchivedSemanticLabel(String label) {
    return 'Diarkibkan. $label';
  }

  @override
  String videoClipStopMotionSemanticLabel(String frames) {
    return 'Klip stop-motion, $frames';
  }

  @override
  String videoClipSemanticValueSelectedAtPosition(int position) {
    return 'Dipilih, nombor $position';
  }

  @override
  String get videoClipSemanticValueSelected => 'Dipilih';

  @override
  String get videoClipSemanticValueNotSelected => 'Tidak dipilih';

  @override
  String get videoClipSemanticHintDisabled => 'Dilumpuhkan';

  @override
  String get videoClipSemanticHintSelect =>
      'Ketik untuk memilih, tekan lama untuk pratonton';

  @override
  String get videoClipSemanticHintDeselect =>
      'Ketik untuk menyahpilih, tekan lama untuk pratonton';

  @override
  String get routerInvalidCreator => 'Pencipta tidak sah';

  @override
  String get routerInvalidHashtagRoute => 'Laluan hashtag tidak sah';

  @override
  String get categoryGalleryCouldNotLoadVideos => 'Tidak dapat memuatkan video';

  @override
  String get categoryGalleryNoVideosInCategory =>
      'Tiada video dalam kategori ini';

  @override
  String get categoryGallerySortOptionsLabel => 'Pilihan isihan kategori';

  @override
  String get categoryGallerySortHot => 'Hangat';

  @override
  String get categoryGallerySortNew => 'Baharu';

  @override
  String get categoryGallerySortClassic => 'Klasik';

  @override
  String get categoryGallerySortForYou => 'Untuk Anda';

  @override
  String get categoriesCouldNotLoadCategories =>
      'Tidak dapat memuatkan kategori';

  @override
  String get categoriesNoCategoriesAvailable => 'Tiada kategori tersedia';

  @override
  String get notificationsEmptyTitle => 'Belum ada aktiviti';

  @override
  String get notificationsEmptySubtitle =>
      'Apabila orang berinteraksi dengan kandungan anda, anda akan melihatnya di sini';

  @override
  String get appsPermissionsTitle => 'Kebenaran Integrasi';

  @override
  String get appsPermissionsRevoke => 'Batalkan';

  @override
  String get appsPermissionsEmptyTitle => 'Tiada kebenaran integrasi disimpan';

  @override
  String get appsPermissionsEmptySubtitle =>
      'Integrasi yang diluluskan akan muncul di sini selepas anda mengingati kelulusan akses.';

  @override
  String nostrAppPermissionTitle(String appName) {
    return '$appName mahukan kelulusan anda';
  }

  @override
  String get nostrAppPermissionDescription =>
      'Apl ini meminta akses melalui kotak pasir Divine yang telah disemak.';

  @override
  String get nostrAppPermissionOrigin => 'Asal';

  @override
  String get nostrAppPermissionMethod => 'Kaedah';

  @override
  String get nostrAppPermissionCapability => 'Keupayaan';

  @override
  String get nostrAppPermissionEventKind => 'Jenis acara';

  @override
  String get nostrAppPermissionAllow => 'Benarkan';

  @override
  String get appsDetailDefaultTitle => 'Apl Bersepadu';

  @override
  String get appsDetailNotFoundTitle => 'Integrasi tidak ditemui';

  @override
  String get appsDetailNotFoundSubtitle =>
      'Integrasi yang diluluskan ini tidak lagi tersedia dalam Divine.';

  @override
  String get appsDetailHowItWorksTitle => 'Cara ia berfungsi';

  @override
  String get appsDetailHowItWorksBody =>
      'Ini ialah apl pihak ketiga yang diluluskan dan berjalan dalam Divine. Divine hanya memberikan keupayaan yang telah disemak untuk integrasi ini, dan menyekat navigasi di luar asal yang diluluskan.';

  @override
  String get appsDetailAboutTitle => 'Perihal';

  @override
  String get appsDetailPrimaryOriginTitle => 'Asal utama';

  @override
  String get appsDetailApprovedOriginsTitle => 'Asal yang diluluskan';

  @override
  String get appsDetailCapabilitiesTitle => 'Keupayaan tersedia';

  @override
  String get appsDetailAskBeforeTitle => 'Tanya sebelum';

  @override
  String get appsDetailOpenButton => 'Buka Integrasi';

  @override
  String get appsDetailNoneDeclared => 'Belum diisytiharkan';

  @override
  String get appsDirectoryTitle => 'Apl Bersepadu';

  @override
  String get appsDirectoryIntroTitle => 'Apl pihak ketiga yang diluluskan';

  @override
  String get appsDirectoryIntroBody =>
      'Apl pihak ketiga yang diluluskan dan berjalan dalam Divine';

  @override
  String get appsDirectoryErrorTitle => 'Tidak dapat memuatkan apl bersepadu';

  @override
  String get appsDirectoryErrorSubtitle =>
      'Tarik untuk mencuba integrasi yang diluluskan sekali lagi.';

  @override
  String get appsDirectoryEmptyTitle => 'Belum ada integrasi yang diluluskan';

  @override
  String get appsDirectoryEmptySubtitle =>
      'Apl pihak ketiga yang diluluskan akan muncul di sini apabila Divine menambahnya.';

  @override
  String get appsDirectoryRefresh => 'Muat semula';

  @override
  String get appsDirectoryUnsupportedTitle =>
      'Apl Bersepadu berjalan dalam Divine mudah alih';

  @override
  String get appsDirectoryUnsupportedSubtitle =>
      'Integrasi yang diluluskan hanya tersedia pada mudah alih buat masa ini.';

  @override
  String get appsSandboxUnavailableTitle => 'Integrasi tidak tersedia';

  @override
  String get appsSandboxUnavailableBody =>
      'Buka integrasi yang diluluskan daripada tab Apl Bersepadu supaya Divine dapat mengenakan dasar akses yang betul.';

  @override
  String get appsSandboxLoadingTitle => 'Memuatkan integrasi';

  @override
  String get appsSandboxLoadingSubtitle =>
      'Menyemak integrasi yang diluluskan sebelum pelancaran.';

  @override
  String get appsSandboxBlockedTitle => 'Disekat untuk keselamatan';

  @override
  String appsSandboxBlockedSubtitle(String uri) {
    return 'Integrasi ini cuba meninggalkan asal yang diluluskan.\n\n$uri';
  }

  @override
  String get shareCopiedPostLink => 'Pautan ke siaran disalin ke papan klip';

  @override
  String get shareCopiedEventJson => 'JSON acara Nostr disalin ke papan klip';

  @override
  String get shareCopiedEventId => 'ID acara Nostr disalin ke papan klip';

  @override
  String get authHeroTaglineAuthentic => 'Detik tulen.';

  @override
  String get authHeroTaglineHuman => 'Kreativiti manusia.';

  @override
  String get keyImportFailedToImport =>
      'Gagal mengimport kunci atau menyambung bunker';

  @override
  String get keyImportInvalidBunkerUrl => 'URL bunker tidak sah';

  @override
  String get keyImportInvalidFormat =>
      'Format tidak sah. Guna nsec..., hex, ncryptsec1... atau bunker://...';

  @override
  String get keyImportInvalidNsecFormat =>
      'Format nsec tidak sah. Sepatutnya 63 aksara';

  @override
  String get keyImportKeyFieldLabel => 'Kunci peribadi atau URL bunker';

  @override
  String get keyImportKeyRequired =>
      'Sila masukkan kunci peribadi atau URL bunker anda';

  @override
  String get keyImportPasswordRequired =>
      'Sila masukkan kata laluan untuk kunci tersulit ini';

  @override
  String get keyImportSecurityWarningBody =>
      'Jangan sesekali kongsi kunci peribadi anda dengan sesiapa. Kunci ini memberi akses penuh kepada identiti Nostr anda.';

  @override
  String get keyImportSecurityWarningTitle =>
      'Pastikan kunci peribadi anda selamat!';

  @override
  String get keyImportSubtitle =>
      'Import identiti Nostr sedia ada anda menggunakan kunci peribadi atau URL bunker.';

  @override
  String get keyImportTitle => 'Import identiti\nNostr anda';

  @override
  String get commentAuthorYouIndicator => 'Anda';

  @override
  String commentAuthorAvatarSemanticLabel(String name) {
    return 'Lihat profil $name';
  }

  @override
  String get commentOptionsDeleteSemanticLabel => 'Padam komen';

  @override
  String get commentOptionsEditSemanticLabel => 'Sunting komen';

  @override
  String get commentOptionsFlagContentLabel => 'Tandakan Kandungan';

  @override
  String get commentOptionsFlagContentSemanticLabel => 'Tandakan kandungan ini';

  @override
  String get commentOptionsFlagReasonPrompt =>
      'Pilih sebab untuk menandakan komen ini';

  @override
  String get commentOptionsFlagSubmit => 'Hantar';

  @override
  String get commentOptionsTitle => 'Pilihan';

  @override
  String get commentsEmptyClassicVineMessage =>
      'Kami masih berusaha mengimport komen lama daripada arkib. Ia belum sedia lagi.';

  @override
  String get commentsEmptyClassicVineTitle => 'Vine Klasik';

  @override
  String get commentsInputEditingLabel => 'Menyunting';

  @override
  String get commentsInputSemanticHint => 'Tambah komen';

  @override
  String get commentsInputSemanticHintEdit => 'Sunting komen';

  @override
  String get commentsInputSemanticHintReply => 'Tambah balasan';

  @override
  String get commentsInputSemanticLabel => 'Input komen';

  @override
  String get commentsInputSemanticLabelEdit => 'Input suntingan';

  @override
  String get commentsInputSemanticLabelReply => 'Input balasan';

  @override
  String classicVinersViewProfileSemanticLabel(String displayName) {
    return 'Lihat profil untuk $displayName';
  }

  @override
  String get classicsEmptyDescription => 'Arkib Klasik sedang dimuatkan';

  @override
  String get classicsEmptyTitle => 'Tiada Klasik Ditemui';

  @override
  String get classicsErrorTitle => 'Gagal memuatkan Klasik';

  @override
  String get classicsUnavailableDescription =>
      'Klasik hanya tersedia apabila bersambung ke relay Funnelcake.';

  @override
  String get classicsUnavailableSettingsHint =>
      'Tukar ke relay yang menyokong Funnelcake dalam Tetapan untuk mengakses arkib Klasik.';

  @override
  String get classicsUnavailableTitle => 'Klasik Tidak Tersedia';

  @override
  String get hashtagFeedEmptySubtitle =>
      'Jadilah yang pertama menyiarkan video dengan hashtag ini!';

  @override
  String hashtagFeedEmptyTitle(String hashtag) {
    return 'Tiada video ditemui untuk #$hashtag';
  }

  @override
  String get hashtagFeedLoadingSubtitle =>
      'Ini mungkin mengambil masa seketika';

  @override
  String hashtagFeedLoadingTitle(String hashtag) {
    return 'Memuatkan video tentang #$hashtag...';
  }

  @override
  String get hashtagInputHint => 'Tambah hashtag... #vine #nostr';

  @override
  String get newVideosTabEmptySubtitle =>
      'Semak semula nanti untuk kandungan baharu';

  @override
  String get newVideosTabEmptyTitle => 'Tiada video dalam Video Baharu';

  @override
  String get popularVideosContextTitle => 'Video Popular';

  @override
  String get popularVideosEmptySubtitle =>
      'Semak semula nanti untuk kandungan baharu';

  @override
  String get popularVideosEmptyTitle => 'Tiada video dalam Video Popular';

  @override
  String get popularVideosErrorTitle => 'Gagal memuatkan video trending';

  @override
  String get popularVideosFeedSourceLabel => 'Sumber suapan popular';

  @override
  String get trendingHashtagsLoading => 'Memuatkan hashtag...';

  @override
  String trendingHashtagsViewVideosTagged(String hashtag) {
    return 'Lihat video bertag $hashtag';
  }

  @override
  String videoGridAuthorSemanticLabel(String name) {
    return 'Pengarang video: $name';
  }

  @override
  String videoGridDescriptionSemanticLabel(String description) {
    return 'Keterangan video: $description';
  }

  @override
  String get forYouAlgorithmChoiceBody =>
      'Visi Divine ialah memberi anda pilihan algoritma yang sebenar. Daripada terkunci dalam satu algoritma kotak hitam, anda akan dapat memilih daripada pelbagai pendekatan cadangan:';

  @override
  String get forYouAlgorithmChoiceChronological =>
      'Garis masa kronologi daripada pencipta yang anda ikuti';

  @override
  String get forYouAlgorithmChoiceClosing =>
      'Ini meletakkan anda mengawal perhatian anda dan bukannya menyerahkannya kepada platform. Anda patut tahu bagaimana suapan anda diurus dan mempunyai kuasa untuk mengubahnya bila-bila masa anda mahu.';

  @override
  String get forYouAlgorithmChoiceCustomFeeds =>
      'Suapan tersuai ciptaan komuniti untuk topik seperti muzik, komedi atau seni';

  @override
  String get forYouAlgorithmChoicePersonalizedFeed =>
      'Suapan \"Untuk Anda\" yang diperibadikan';

  @override
  String get forYouAlgorithmChoiceTitle => 'Algoritma Anda, Pilihan Anda';

  @override
  String get forYouAlgorithmChoiceTrending => 'Kandungan trending dan popular';

  @override
  String get forYouAlgorithmCommentsDescription =>
      'Isyarat kuat — anda cukup terlibat untuk membalas';

  @override
  String get forYouAlgorithmHowItWorksBody =>
      'Divine mengambil perhatian tentang cara anda berinteraksi dengan kandungan untuk memahami apa yang anda suka. Setiap kali anda menonton video, memberi tindak balas, meninggalkan komen atau menyiarkan semula, sistem mengambil perhatian.';

  @override
  String get forYouAlgorithmHowItWorksTitle => 'Cara Ia Berfungsi';

  @override
  String get forYouAlgorithmInteractionsIntro =>
      'Tindakan berbeza menandakan tahap minat yang berbeza:';

  @override
  String get forYouAlgorithmNewToDivineBody1 =>
      'Jika anda belum membina sejarah tontonan, kami menunjukkan gabungan apa yang sedang popular dan trending bersama muat naik terkini. Ini memberi anda titik permulaan yang hebat untuk meneroka.';

  @override
  String get forYouAlgorithmNewToDivineBody2 =>
      'Apabila anda menonton, menyukai dan berinteraksi dengan kandungan, cadangan secara beransur-ansur menjadi lebih peribadi. Lama-kelamaan, suapan Untuk Anda memaparkan video daripada pencipta yang anda mungkin tidak pernah temui sendiri.';

  @override
  String get forYouAlgorithmNewToDivineTitle => 'Baharu dengan Divine?';

  @override
  String get forYouAlgorithmOpenSourceBody =>
      'Kami sedang membina sistem terbuka di mana pembangun boleh melaksanakan algoritma mereka sendiri, dan anda boleh memilih yang mana untuk digunakan — atau menarik diri sepenuhnya.';

  @override
  String get forYouAlgorithmOpenSourceTitle => 'Sumber Terbuka & Telus';

  @override
  String get forYouAlgorithmReactionsDescription =>
      'Isyarat sederhana — cara pantas untuk menunjukkan penghargaan';

  @override
  String get forYouAlgorithmReactionsTitle => 'Tindak balas';

  @override
  String get forYouAlgorithmRepostsDescription =>
      'Isyarat paling kuat — berkongsi dengan pengikut anda ialah sokongan yang berkuasa';

  @override
  String get forYouAlgorithmSubtitle =>
      'Dikuasakan oleh Gorse, enjin cadangan sumber terbuka';

  @override
  String get forYouAlgorithmTitle => 'Algoritma Divine';

  @override
  String get forYouAlgorithmViewsDescription =>
      'Isyarat ringan — menunjukkan minat asas';

  @override
  String get forYouEmptyDescription =>
      'Tonton dan sukai beberapa video untuk mendapatkan cadangan peribadi.';

  @override
  String get forYouEmptyTitle => 'Belum Ada Cadangan';

  @override
  String get forYouErrorTitle => 'Gagal memuatkan cadangan';

  @override
  String get forYouUnavailableDescription =>
      'Cadangan peribadi memerlukan sambungan ke Funnelcake.';

  @override
  String get forYouUnavailableTitle => 'Untuk Anda Tidak Tersedia';

  @override
  String get inboxConversationOptionsLabel => 'Pilihan';

  @override
  String get inboxConversationViewProfileButton => 'Lihat profil';

  @override
  String get inboxMessageRequestsEmpty => 'Tiada permintaan mesej';

  @override
  String inboxMessageRequestsSemanticLabel(int requestCount) {
    return 'Permintaan mesej, $requestCount belum selesai';
  }

  @override
  String get inboxMessageRequestsTitle => 'Permintaan mesej';

  @override
  String get inboxMessagesTab => 'Mesej';

  @override
  String inboxRequestTileLabel(String displayName) {
    return 'Permintaan mesej $displayName';
  }

  @override
  String get inboxRequestTileSubtitle => 'Menghantar permintaan mesej';

  @override
  String get inboxRequestsMarkAllRead =>
      'Tandakan semua permintaan sebagai dibaca';

  @override
  String get inboxRequestsRemoveAll => 'Alih keluar semua permintaan';

  @override
  String get messageRequestDeclineAndRemoveButton => 'Tolak dan alih keluar';

  @override
  String messageRequestDeclinedSnackbar(String displayName) {
    return 'Permintaan $displayName ditolak';
  }

  @override
  String get messageRequestLoadFailed =>
      'Permintaan ini tidak dapat dimuatkan.';

  @override
  String messageRequestFollowersCount(int countValue, String count) {
    return '$count Pengikut';
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
      other: '$count mesej',
      one: '1 mesej',
    );
    return '$_temp0';
  }

  @override
  String get messageRequestViewMessagesButton => 'Lihat mesej';

  @override
  String get messageRequestViewProfileButton => 'Lihat profil';

  @override
  String messageRequestWantsToMessageYou(
    String displayName,
    String messageText,
  ) {
    return '$displayName mahu menghantar mesej kepada anda, mereka telah menghantar $messageText.';
  }

  @override
  String get deleteAccountAccountChanged =>
      'Anda menukar akaun, jadi tiada apa yang dipadam. Buka semula pemadaman untuk akaun yang mahu anda alih keluar.';

  @override
  String get deleteAccountConfirmDeletePrompt => 'Untuk mengesahkan, taip:';

  @override
  String get deleteAccountConfirmUsernamePrompt =>
      'Untuk mengesahkan, taip nama pengguna anda:';

  @override
  String get deleteAccountConfirmationHint => 'Taip DELETE';

  @override
  String get deleteAccountConfirmationHintUsername => 'Taip nama pengguna anda';

  @override
  String get deleteAccountDeleteAllContentButton => 'Padam Semua Kandungan';

  @override
  String get accountDeletionRecoveryTitle => 'Akaun anda sedang dipadamkan';

  @override
  String get accountDeletionRecoveryBody =>
      'Kami tidak dapat melengkapkan pemadaman akaun anda. Nama pengguna anda masih ditempah untuk anda dan masih boleh dipulihkan.';

  @override
  String accountDeletionRecoveryBodyWithExpiry(String expiryDate) {
    return 'We couldn\'t finish deleting your account. Your username is reserved for you until $expiryDate and can still be restored.';
  }

  @override
  String get accountDeletionRestoreUsername => 'Pulihkan nama pengguna saya';

  @override
  String get accountDeletionFinishingBody =>
      'Permintaan pemadaman anda masih diproses. Anda boleh menggunakan akaun lain sementara kami menyelesaikannya.';

  @override
  String get accountDeletionOtherAccountPending =>
      'Pemadaman akaun lain masih diproses pada peranti ini. Tunggu sehingga selesai sebelum memadamkan akaun ini.';

  @override
  String get accountDeletionCancellingBody =>
      'Kami sedang membatalkan pemadaman anda. Semak semula sebelum anda meninggalkan skrin ini.';

  @override
  String get accountDeletionRecoveryFailed =>
      'Kami belum dapat memulihkan nama pengguna anda. Semak sambungan anda dan cuba lagi.';

  @override
  String get accountDeletionUsernameRestored =>
      'Nama pengguna anda telah dipulihkan. Akaun anda tidak dipadam.';

  @override
  String get accountDeletionRecoveryStatusFailed =>
      'Kami tidak dapat menyemak status pemadaman anda. Semak sambungan anda dan cuba lagi.';

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
      'Pemadaman akaun tidak tersedia buat masa ini. Tiada apa-apa yang dipadamkan.';

  @override
  String get deleteAccountDeletionIncomplete =>
      'Kami tidak dapat melengkapkan pemadaman akaun anda. Cuba lagi.';

  @override
  String get deleteAccountDeletionNotStarted =>
      'We couldn\'t start deleting your account. Nothing was deleted. Try again.';

  @override
  String get deleteAccountFinalConfirmationTitle => '⚠️ Pengesahan Akhir';

  @override
  String get deleteAccountKeyDeletionWarning =>
      'Permintaan pemadaman dihantar, tetapi kunci anda mungkin tidak dialih keluar sepenuhnya daripada peranti ini. Pergi ke Tetapan → Kunci Nostr → Alih Keluar Kunci untuk cuba semula.';

  @override
  String get deleteAccountLocalDataDeletionFailed =>
      'Permintaan pemadaman dihantar dan anda telah dilog keluar, tetapi sesetengah data setempat tidak dapat dialih keluar daripada peranti ini.';

  @override
  String get deleteAccountPreparingDeletion => 'Menyediakan pemadaman...';

  @override
  String deleteAccountProgressEvents(int current, int total) {
    return '$current / $total acara';
  }

  @override
  String get deleteAccountRemoveKeysBody =>
      'Ini mengalih keluar log masuk setempat untuk akaun ini daripada peranti ini. Ia tidak akan memadam akaun Divine atau identiti Nostr anda.\n\nDraf dan klip anda kekal disimpan pada peranti ini untuk akaun ini. Jika ini akaun setempat terakhir anda, anda akan kembali ke skrin log masuk.';

  @override
  String get deleteAccountRemoveKeysConfirm => 'Alih keluar daripada peranti';

  @override
  String get deleteAccountRemoveKeysTitle =>
      'Alih keluar akaun ini daripada peranti ini?';

  @override
  String get deleteAccountReauthRequired =>
      'Log masuk semula untuk memadam akaun anda. Tiada apa yang dipadam lagi.';

  @override
  String get deleteAccountServerDeletionFailed =>
      'Permintaan pemadaman dihantar untuk siaran anda, tetapi kami tidak dapat melengkapkan pemadaman akaun anda. Cuba lagi sebentar lagi.';

  @override
  String get deleteAccountSuccess =>
      'Akaun Divine anda telah dipadamkan. Permintaan pemadaman telah dihantar untuk siaran Nostr anda, tetapi sesetengah geganti, klien atau cache mungkin menyimpan salinannya.';

  @override
  String get deleteAccountSuccessContentUnverified =>
      'Pemadaman akaun diminta. Sesetengah siaran sedia ada tidak dapat disahkan secara individu untuk pemadaman.';

  @override
  String get deleteAccountWarningBody =>
      'Ini menghantar permintaan pemadaman untuk akaun dan kandungan anda, memadam akaun Divine anda apabila boleh, dan melog keluar anda pada peranti ini. Sesetengah relay, klien dan indeks carian mungkin menyimpan salinan. Peranti lain yang dilog masuk kekal aktif sehingga anda mengalih keluar kunci di situ.';

  @override
  String get findPeopleNoContacts =>
      'Tiada kenalan ditemui.\nMula mengikuti orang untuk melihat mereka di sini.';

  @override
  String get geoBlockedCityLabel => 'Bandar';

  @override
  String get geoBlockedCountryLabel => 'Negara';

  @override
  String get geoBlockedDefaultReason =>
      'Perkhidmatan ini tidak tersedia di wilayah anda kerana peraturan tempatan.';

  @override
  String get geoBlockedLegalNotice =>
      'Kami menghormati undang-undang dan peraturan tempatan anda. Sekatan ini berdasarkan lokasi alamat IP anda.';

  @override
  String get geoBlockedRegionLabel => 'Wilayah';

  @override
  String get geoBlockedTitle => 'Perkhidmatan Tidak Tersedia';

  @override
  String get likedVideosEmpty => 'Tiada video disukai';

  @override
  String get likedVideosInvalidRoute => 'Laluan tidak sah';

  @override
  String get likedVideosTitle => 'Video Disukai';

  @override
  String get uploadFailureSheetRetryingSnackbar => 'Mencuba semula muat naik…';

  @override
  String get uploadFailureSheetSaveToDraftsButton => 'Simpan ke Draf';

  @override
  String get uploadFailureSheetSavedToDraftsSnackbar => 'Disimpan ke draf';

  @override
  String get uploadFailureSheetTitle => 'Muat Naik Gagal';

  @override
  String get uploadFailureSheetTryAgainButton => 'Cuba Lagi';

  @override
  String get videoEditorAudioImportAudio => 'Import audio';

  @override
  String get videoEditorAudioImportFailed => 'Import audio gagal.';

  @override
  String get videoIconPlaceholderLabel => 'Video';

  @override
  String get publishErrorNotSignedIn =>
      'Sila log masuk untuk menerbitkan video.';

  @override
  String get publishErrorNoRetry => 'Tiada muat naik untuk dicuba semula.';

  @override
  String get publishErrorNoInternet =>
      'Tiada sambungan internet. Semak Wi-Fi atau data mudah alih anda dan cuba lagi.';

  @override
  String get publishErrorServerUnreachable =>
      'Tidak dapat mencapai pelayan. Sila cuba lagi sebentar nanti.';

  @override
  String get publishErrorTimeout =>
      'Muat naik tamat masa. Cuba sambungan yang lebih kuat atau video yang lebih kecil.';

  @override
  String get publishErrorTls =>
      'Sambungan selamat gagal. Semak rangkaian anda — Wi-Fi awam boleh menyekat muat naik.';

  @override
  String publishErrorServerNotFound(String serverName) {
    return 'Pelayan media ($serverName) tidak tersedia. Anda boleh memilih yang lain dalam tetapan anda.';
  }

  @override
  String get publishErrorFileTooLarge =>
      'Fail video terlalu besar untuk pelayan. Cuba memangkasnya atau mengurangkan kualiti.';

  @override
  String publishErrorServerInternalError(String serverName) {
    return 'Pelayan media ($serverName) mengalami ralat dalaman. Anda boleh memilih yang lain dalam tetapan anda.';
  }

  @override
  String publishErrorServerDown(String serverName) {
    return 'Pelayan media ($serverName) tidak berfungsi buat sementara. Cuba lagi sebentar nanti atau pilih yang lain dalam tetapan anda.';
  }

  @override
  String get publishErrorForbidden =>
      'Anda tidak mempunyai kebenaran untuk memuat naik ke pelayan ini.';

  @override
  String get publishErrorFileNotFound =>
      'Fail video tidak dapat ditemui. Ia mungkin telah dipadam. Rakam semula dan cuba lagi.';

  @override
  String get publishErrorLowStorage =>
      'Storan tidak mencukupi pada peranti anda. Kosongkan sedikit ruang dan cuba lagi.';

  @override
  String get publishErrorThumbnailFailed =>
      'Video dimuat naik, tetapi lakaran kecil tidak dapat disediakan. Sila cuba lagi.';

  @override
  String get publishErrorNostrPublishFailed =>
      'Video dimuat naik tetapi siaran tidak dapat diterbitkan. Semak tetapan relay anda dan cuba lagi.';

  @override
  String get publishErrorAccountRestricted =>
      'Your account is restricted, so this post couldn’t be published.';

  @override
  String get uploadFailureSheetAccountStatusButton => 'View Account Status';

  @override
  String get publishErrorAudioReuseNotPermitted =>
      'Video dimuat naik tetapi bunyinya tidak dibenarkan untuk digunakan semula. Pilih bunyi lain untuk menyiarkannya.';

  @override
  String get publishErrorInterrupted =>
      'Muat naik ini terganggu. Adakah anda mahu cuba lagi?';

  @override
  String get publishErrorAccountChanged =>
      'Video ini milik akaun lain. Tukar kembali ke akaun itu untuk menyiarkannya.';

  @override
  String get publishErrorGeneric => 'Sesuatu telah berlaku. Sila cuba lagi.';

  @override
  String get publishErrorRateLimited =>
      'Terlalu banyak muat naik sekarang. Tunggu sebentar dan cuba lagi.';

  @override
  String get publishErrorUploadSessionExpired =>
      'Sesi muat naik anda tamat tempoh. Sila cuba lagi.';

  @override
  String get publishErrorPermissionDenied =>
      'Divine tidak mempunyai kebenaran untuk memuat naik. Semak kebenaran apl dalam tetapan anda dan cuba lagi.';

  @override
  String get publishErrorOutOfMemory =>
      'Peranti anda kekurangan memori. Tutup beberapa apl dan cuba lagi.';

  @override
  String get publishErrorOverlaysUnavailable =>
      'Teks dan pelekat pada draf ini tidak dapat disediakan. Buka ia dalam penyunting, kemudian siarkan semula.';

  @override
  String get publishErrorUnknownServer => 'Pelayan tidak diketahui';

  @override
  String searchFilterPillSemanticLabel(String filter) {
    return 'Penapis: $filter';
  }

  @override
  String searchNoResultsFound(String query) {
    return 'Tiada hasil ditemui untuk \"$query\"';
  }

  @override
  String searchTagChipViewVideosTaggedLabel(String tag) {
    return 'Lihat video bertag $tag';
  }

  @override
  String audioAttributionRowSemanticLabel(
    String soundName,
    String creatorName,
  ) {
    return 'Bunyi: $soundName oleh $creatorName. Ketik untuk melihat butiran bunyi.';
  }

  @override
  String metadataSoundsOriginalSoundSemantics(String creatorName) {
    return 'Bunyi asal oleh $creatorName. Ketik untuk menggunakan bunyi ini.';
  }

  @override
  String metadataSoundsSharedSoundSemantics(
    String soundName,
    String creatorName,
  ) {
    return 'Bunyi: $soundName oleh $creatorName. Ketik untuk melihat butiran.';
  }

  @override
  String get soundDetailLoadError => 'Gagal memuatkan bunyi. Sila cuba lagi.';

  @override
  String get soundDetailNotFoundMessage => 'Bunyi ini tidak dapat ditemui';

  @override
  String get soundDetailNotFoundTitle => 'Bunyi Tidak Ditemui';

  @override
  String videoFeedLoopCountLabel(int count) {
    return '🔁 $count loop';
  }

  @override
  String get originalSoundUnavailableBody =>
      'Audio daripada video ini tidak tersedia secara berasingan.';

  @override
  String originalSoundByCreator(String creatorName) {
    return 'Bunyi asal - $creatorName';
  }

  @override
  String get ogVinerBadgeLabel => 'OG Viner';

  @override
  String get profileBadgeOgVinerBody =>
      'Orang ini pernah menyiarkan Vine asli yang ditemui Divine dalam arkib. Ini bukan lencana pengesahan akaun.';

  @override
  String get ogBetaTesterBadgeLabel => 'OG Beta Tester';

  @override
  String get profileBadgeOgBetaTesterBody =>
      'This person was testing Divine during the beta, before it opened to everyone. It is not an account verification badge.';

  @override
  String get profileBadgeCheckmarkTitle => 'Tanda semak profil';

  @override
  String get profileBadgeCheckmarkBody =>
      'Divine memberikan tanda semak ini kepada akaun pasukan. Ia berasingan daripada NIP-05, pautan akaun disahkan dan status OG Viner.';

  @override
  String get unfollowConfirmButton => 'Nyahikut';

  @override
  String get videoClipSaveFailed => 'Gagal menyimpan klip';

  @override
  String videoClipSaveTo(String destination) {
    return 'Simpan ke $destination';
  }

  @override
  String get videoClipDelete => 'Padam klip';

  @override
  String inspiredByAttributionMultipleSemanticLabel(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return 'Diilhamkan oleh $creatorName +$additionalCreatorCount. Ketik untuk melihat profil mereka.';
  }

  @override
  String inspiredByAttributionSemanticLabel(String creatorName) {
    return 'Diilhamkan oleh $creatorName. Ketik untuk melihat profil mereka.';
  }

  @override
  String get bugReportSendReport => 'Hantar Laporan';

  @override
  String get supportSubjectRequiredLabel => 'Subjek *';

  @override
  String get supportPublicSubmissionTitle => 'Siaran GitHub awam';

  @override
  String get supportPublicSubmissionMessage =>
      'Semua yang anda hantar di sini akan disiarkan dalam repositori sumber terbuka kami di GitHub supaya pembangun boleh mengendalikannya. Siaran ini dan akaun yang anda log masuk boleh dilihat oleh semua orang.';

  @override
  String get supportRequiredHelper => 'Diperlukan';

  @override
  String get supportFieldLimitReached =>
      'Itu panjang maksimum. Apa-apa selepas ini tidak ditambah.';

  @override
  String get bugReportSubjectHint => 'Ringkasan ringkas isu itu';

  @override
  String get bugReportDescriptionRequiredLabel => 'Apa yang berlaku? *';

  @override
  String get bugReportDescriptionHint => 'Terangkan isu yang anda hadapi';

  @override
  String get bugReportStepsLabel => 'Langkah untuk Menghasilkan Semula';

  @override
  String get bugReportStepsHint =>
      '1. Pergi ke...\n2. Ketik pada...\n3. Lihat ralat';

  @override
  String get bugReportExpectedBehaviorLabel => 'Kelakuan Dijangka';

  @override
  String get bugReportExpectedBehaviorHint => 'Apa yang sepatutnya berlaku?';

  @override
  String get bugReportDiagnosticsNotice =>
      'Maklumat peranti dan log akan disertakan secara automatik.';

  @override
  String get bugReportSuccessMessage =>
      'Terima kasih! Kami telah menerima laporan anda dan akan menggunakannya untuk menjadikan Divine lebih baik.';

  @override
  String get bugReportAttachImages => 'Lampirkan imej';

  @override
  String bugReportImagesCount(int count, int max) {
    return '$count daripada $max imej dipilih';
  }

  @override
  String get bugReportRemoveImage => 'Alih keluar imej';

  @override
  String get bugReportUploadFailed =>
      'Kami tidak dapat memuat naik imej yang dipilih. Cuba lagi atau hantar laporan tanpanya.';

  @override
  String get bugReportSendFailed =>
      'Gagal menghantar laporan pepijat. Sila cuba lagi nanti.';

  @override
  String get featureRequestSendRequest => 'Hantar Permintaan';

  @override
  String get featureRequestSubjectHint => 'Ringkasan ringkas idea anda';

  @override
  String get featureRequestDescriptionRequiredLabel =>
      'Apa yang anda inginkan? *';

  @override
  String get featureRequestDescriptionHint => 'Terangkan ciri yang anda mahu';

  @override
  String get featureRequestUsefulnessLabel => 'Bagaimana ini berguna?';

  @override
  String get featureRequestUsefulnessHint =>
      'Terangkan faedah yang ciri ini akan berikan';

  @override
  String get featureRequestWhenLabel => 'Bila anda akan menggunakan ini?';

  @override
  String get featureRequestWhenHint =>
      'Terangkan situasi di mana ini akan membantu';

  @override
  String get featureRequestSuccessMessage =>
      'Terima kasih! Kami telah menerima permintaan ciri anda dan akan menyemaknya.';

  @override
  String get featureRequestSendFailed =>
      'Gagal menghantar permintaan ciri. Sila cuba lagi nanti.';

  @override
  String get notificationFollowBack => 'Ikut balik';

  @override
  String get followingTitle => 'Mengikuti';

  @override
  String followingTitleForName(String displayName) {
    return 'Mengikuti $displayName';
  }

  @override
  String get followingFailedToLoadList => 'Gagal memuatkan senarai mengikuti';

  @override
  String get followingEmptyTitle => 'Belum mengikuti sesiapa';

  @override
  String get followersTitle => 'Pengikut';

  @override
  String followersTitleForName(String displayName) {
    return 'Pengikut $displayName';
  }

  @override
  String get followersFailedToLoadList => 'Gagal memuatkan senarai pengikut';

  @override
  String get followersEmptyTitle => 'Belum ada pengikut';

  @override
  String get followersUpdateFollowFailed =>
      'Gagal mengemas kini status ikutan. Sila cuba lagi.';

  @override
  String get followersSortSemanticLabel => 'Isih pengikut';

  @override
  String get followingSortSemanticLabel => 'Isih yang diikuti';

  @override
  String get followSortTitle => 'Isih mengikut';

  @override
  String get followSortNewest => 'Terbaharu dahulu';

  @override
  String get followSortOldest => 'Terlama dahulu';

  @override
  String get newMessageTitle => 'Mesej baharu';

  @override
  String get newMessageFindPeople => 'Cari orang';

  @override
  String get newMessageNoContacts =>
      'Tiada kenalan ditemui.\nIkut orang untuk melihat mereka di sini.';

  @override
  String get newMessageNoUsersFound => 'Tiada pengguna ditemui';

  @override
  String get hashtagSearchTitle => 'Cari hashtag';

  @override
  String get hashtagSearchSubtitle => 'Temui topik dan kandungan trending';

  @override
  String hashtagSearchNoResults(String query) {
    return 'Tiada hashtag ditemui untuk \"$query\"';
  }

  @override
  String get hashtagSearchFailed => 'Carian gagal';

  @override
  String get userNotAvailableTitle => 'Akaun tidak tersedia';

  @override
  String get userNotAvailableBody => 'Akaun ini tidak tersedia sekarang.';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String get blossomFailedToSaveSettings =>
      'Gagal menyimpan tetapan. Sila cuba lagi.';

  @override
  String get blossomValidServerUrl =>
      'Sila masukkan URL pelayan yang sah (cth. https://blossom.band)';

  @override
  String get blossomSettingsSaved => 'Tetapan Blossom disimpan';

  @override
  String get blossomSaveTooltip => 'Simpan';

  @override
  String get blossomAboutTitle => 'Perihal Blossom';

  @override
  String get blossomAboutDescription =>
      'Blossom ialah protokol storan media terdesentralisasi yang membolehkan anda memuat naik video ke mana-mana pelayan serasi. Secara lalai, video dimuat naik ke pelayan Blossom Divine. Dayakan pilihan di bawah untuk menggunakan pelayan tersuai sebaliknya.';

  @override
  String get blossomUseCustomServer => 'Guna Pelayan Blossom Tersuai';

  @override
  String get blossomCustomServerEnabledSubtitle =>
      'Video akan dimuat naik ke pelayan Blossom tersuai anda';

  @override
  String get blossomCustomServerDisabledSubtitle =>
      'Video anda sedang dimuat naik ke pelayan Blossom Divine';

  @override
  String get blossomCustomServerUrl => 'URL Pelayan Blossom Tersuai';

  @override
  String get blossomCustomServerHelper =>
      'Masukkan URL pelayan Blossom tersuai anda';

  @override
  String get blossomPopularServers => 'Pelayan Blossom Popular';

  @override
  String get blossomServerUrlMustUseHttps =>
      'URL pelayan Blossom mestilah menggunakan https://';

  @override
  String get blueskyFailedToUpdateCrosspost =>
      'Gagal mengemas kini tetapan siaran silang';

  @override
  String get blueskySignInRequired =>
      'Log masuk untuk mengurus tetapan Bluesky';

  @override
  String get blueskyPublishVideos => 'Terbitkan video ke Bluesky';

  @override
  String get blueskyEnabledSubtitle => 'Video anda akan diterbitkan ke Bluesky';

  @override
  String get blueskyDisabledSubtitle =>
      'Video anda tidak akan diterbitkan ke Bluesky';

  @override
  String get blueskyBackfillDisclosureTitle =>
      'Video lama anda juga akan disiarkan';

  @override
  String get blueskyBackfillDisclosureSubtitle =>
      'Apabila anda menghidupkan ini, Divine akan mula menghantar video lama anda ke Bluesky, yang paling lama dahulu, tanpa tergesa-gesa mengejar had harian.';

  @override
  String get blueskyHandle => 'Handle Bluesky';

  @override
  String get blueskyDid => 'DID Bluesky';

  @override
  String get blueskyStatus => 'Status';

  @override
  String get blueskyStatusReady => 'Akaun diperuntukkan dan sedia';

  @override
  String get blueskyStatusPending => 'Peruntukan akaun sedang berjalan...';

  @override
  String get blueskyStatusFailed => 'Peruntukan akaun gagal';

  @override
  String get blueskyStatusDisabled => 'Akaun dilumpuhkan';

  @override
  String get blueskyStatusNotLinked => 'Tiada akaun Bluesky dipautkan';

  @override
  String get blueskyUsernameRequired =>
      'Sediakan handle divine.video sebelum menerbitkan ke Bluesky';

  @override
  String get blueskyUsernameRequiredSubtitle =>
      'Penerbitan Bluesky memerlukan handle namapengguna.divine.video yang dituntut.';

  @override
  String get blueskyUsernameSyncPending =>
      'Handle Divine anda telah dituntut. Kami sedang memautkannya ke Bluesky - cuba lagi sebentar nanti.';

  @override
  String get blueskyStatusUnavailableRetry =>
      'Kami tidak dapat menyemak handle Divine anda. Cuba lagi.';

  @override
  String get blueskySetUpHandle => 'Sediakan';

  @override
  String get blueskyTemporarilyUnavailable =>
      'Penerbitan Bluesky tidak tersedia buat sementara. Sila cuba lagi.';

  @override
  String get invitesTitle => 'Jemput Rakan';

  @override
  String invitesGenerateCardTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jemputan sedia untuk dijana',
      one: '1 jemputan sedia untuk dijana',
    );
    return '$_temp0';
  }

  @override
  String get invitesGenerateCardSubtitle =>
      'Jana kod apabila anda bersedia untuk berkongsi.';

  @override
  String get invitesGenerateButtonLabel => 'Jana jemputan';

  @override
  String get invitesNoneAvailable => 'Tiada jemputan tersedia sekarang';

  @override
  String get invitesShareWithPeople =>
      'Kongsi Divine dengan orang yang anda kenali';

  @override
  String get invitesUsedInvites => 'Jemputan digunakan';

  @override
  String invitesShareMessage(String code) {
    return 'Sertai saya di Divine! Guna kod jemputan $code untuk bermula:\nhttps://divine.video/invite/$code';
  }

  @override
  String get invitesCopyInvite => 'Salin jemputan';

  @override
  String get invitesCopied => 'Jemputan disalin!';

  @override
  String get invitesShareInvite => 'Kongsi jemputan';

  @override
  String get invitesShareSubject => 'Sertai saya di Divine';

  @override
  String get invitesClaimed => 'Dituntut';

  @override
  String get invitesCouldNotLoad => 'Tidak dapat memuatkan jemputan';

  @override
  String get invitesRetry => 'Cuba Semula';

  @override
  String get searchSomethingWentWrong => 'Sesuatu telah berlaku';

  @override
  String get searchTryAgain => 'Cuba lagi';

  @override
  String get searchForLists => 'Cari senarai';

  @override
  String get searchFindCuratedVideoLists => 'Cari senarai video terpilih';

  @override
  String get searchEnterQuery => 'Masukkan pertanyaan carian';

  @override
  String get searchDiscoverSomethingInteresting => 'Temui sesuatu yang menarik';

  @override
  String get searchPeopleSectionHeader => 'Orang';

  @override
  String get searchPeopleLoadingLabel => 'Memuatkan hasil orang';

  @override
  String get searchTagsSectionHeader => 'Tag';

  @override
  String get searchTagsLoadingLabel => 'Memuatkan hasil tag';

  @override
  String get searchVideosSectionHeader => 'Video';

  @override
  String get searchVideosLoadingLabel => 'Memuatkan hasil video';

  @override
  String get searchVideosSortOptionsLabel => 'Isih hasil video';

  @override
  String get searchVideosSortTrending => 'Hangat';

  @override
  String get searchVideosSortLoops => 'Paling banyak loop';

  @override
  String get searchVideosSortEngagement => 'Paling banyak interaksi';

  @override
  String get searchVideosSortRecent => 'Terkini';

  @override
  String get searchListsSectionHeader => 'Senarai';

  @override
  String get searchListsLoadingLabel => 'Memuatkan hasil senarai';

  @override
  String get cameraAgeRestriction =>
      'Anda mestilah berumur 16 tahun ke atas untuk mencipta kandungan';

  @override
  String get keyImportInsecureBunkerRelay =>
      'Relay bunker mestilah menggunakan wss:// (ws:// dibenarkan untuk localhost sahaja)';

  @override
  String get timeNow => 'kini';

  @override
  String timeShortMinutes(int count) {
    return '${count}m';
  }

  @override
  String timeShortHours(int count) {
    return '${count}j';
  }

  @override
  String timeShortDays(int count) {
    return '${count}h';
  }

  @override
  String timeShortWeeks(int count) {
    return '${count}mgu';
  }

  @override
  String timeShortMonths(int count) {
    return '${count}bln';
  }

  @override
  String timeShortYears(int count) {
    return '${count}thn';
  }

  @override
  String get timeVerboseNow => 'Kini';

  @override
  String timeAgo(String time) {
    return '$time lalu';
  }

  @override
  String get timeToday => 'Hari ini';

  @override
  String get timeYesterday => 'Semalam';

  @override
  String get timeJustNow => 'baru sahaja';

  @override
  String timeMinutesAgo(int count) {
    return '${count}m lalu';
  }

  @override
  String timeHoursAgo(int count) {
    return '${count}j lalu';
  }

  @override
  String timeDaysAgo(int count) {
    return '${count}h lalu';
  }

  @override
  String get draftTimeJustNow => 'Baru sahaja';

  @override
  String get contentLabelNudity => 'Kebogelan';

  @override
  String get contentLabelSexualContent => 'Kandungan Seksual';

  @override
  String get contentLabelPornography => 'Pornografi';

  @override
  String get contentLabelGraphicMedia => 'Media Grafik';

  @override
  String get contentLabelViolence => 'Keganasan';

  @override
  String get contentLabelSelfHarm => 'Mencederakan Diri/Bunuh Diri';

  @override
  String get contentLabelDrugUse => 'Penggunaan Dadah';

  @override
  String get contentLabelAlcohol => 'Alkohol';

  @override
  String get contentLabelTobacco => 'Tembakau/Merokok';

  @override
  String get contentLabelGambling => 'Perjudian';

  @override
  String get contentLabelProfanity => 'Bahasa Kasar';

  @override
  String get contentLabelHateSpeech => 'Ucapan Kebencian';

  @override
  String get contentLabelHarassment => 'Gangguan';

  @override
  String get contentLabelFlashingLights => 'Cahaya Berkelip';

  @override
  String get contentLabelAiGenerated => 'Dijana AI';

  @override
  String get contentLabelDeepfake => 'Deepfake';

  @override
  String get contentLabelSpam => 'Spam';

  @override
  String get contentLabelScam => 'Penipuan/Scam';

  @override
  String get contentLabelSpoiler => 'Spoiler';

  @override
  String get contentLabelMisleading => 'Mengelirukan';

  @override
  String get contentLabelSensitiveContent => 'Kandungan Sensitif';

  @override
  String notificationLikedYourVideo(String actorName) {
    return '$actorName menyukai video anda';
  }

  @override
  String notificationLikedYourComment(String actorName) {
    return '$actorName menyukai komen anda';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return '$actorName mengomen video anda';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return '$actorName mula mengikuti anda';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return '$actorName menyebut anda';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return '$actorName menyiarkan semula video anda';
  }

  @override
  String notificationPostedNewVine(String actorName) {
    return '$actorName menyiarkan vine baharu';
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
      other: '$count vine anda',
      one: 'vine anda',
    );
    return '$actorName menambah $_temp0 ke $listName';
  }

  @override
  String notificationRepliedToYourComment(String actorName) {
    return '$actorName membalas komen anda';
  }

  @override
  String get notificationAndConnector => 'dan';

  @override
  String notificationOthersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count orang lain',
      one: '1 orang lain',
    );
    return '$_temp0';
  }

  @override
  String get notificationSystemUpdate => 'Anda mempunyai kemas kini baharu';

  @override
  String get commentReplyToPrefix => 'Balas:';

  @override
  String get commentHideKeyboard => 'Sembunyikan papan kekunci';

  @override
  String get commentsErrorLoadFailed => 'Gagal memuatkan komen';

  @override
  String get commentsErrorNotAuthenticatedComment =>
      'Sila log masuk untuk mengomen';

  @override
  String get commentsErrorPostCommentFailed => 'Gagal menyiarkan komen';

  @override
  String get commentsErrorPostReplyFailed => 'Gagal menyiarkan balasan';

  @override
  String get commentsErrorEditFailed => 'Gagal menyunting komen';

  @override
  String get commentsErrorNotAuthenticatedInteract =>
      'Sila log masuk untuk berinteraksi';

  @override
  String get commentsErrorVoteFailed => 'Gagal mengundi komen';

  @override
  String get commentsErrorReportFailed => 'Gagal melaporkan komen';

  @override
  String get commentsErrorBlockFailed => 'Gagal menyekat pengguna';

  @override
  String get commentsErrorDeleteFailed => 'Gagal memadam komen';

  @override
  String commentsHeaderCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Komen',
      one: '$count Komen',
    );
    return '$_temp0';
  }

  @override
  String get commentsVideoReplyPending => 'Menyiarkan…';

  @override
  String get commentsVideoReplyPendingSemanticLabel =>
      'Balasan video anda sedang disiarkan';

  @override
  String get commentsSortNew => 'Baharu';

  @override
  String get commentsSortTop => 'Teratas';

  @override
  String get commentsSortOld => 'Lama';

  @override
  String get commentsSortSemanticLabel => 'Isihan komen';

  @override
  String get commentReply => 'Balas';

  @override
  String get commentReplySemanticLabel => 'Balas kepada komen';

  @override
  String get commentUpvoteLabel => 'Undi atas komen';

  @override
  String get commentRemoveUpvoteLabel => 'Alih keluar undi atas';

  @override
  String get commentDownvoteLabel => 'Undi bawah komen';

  @override
  String get commentRemoveDownvoteLabel => 'Alih keluar undi bawah';

  @override
  String get commentsInputHint => 'Tambah komen...';

  @override
  String get commentsInputHintEdit => 'Sunting komen...';

  @override
  String get commentsEmptyTitle => 'Belum ada komen';

  @override
  String get commentsEmptySubtitle => 'Mulakan parti!';

  @override
  String get draftUntitled => 'Tanpa tajuk';

  @override
  String get contentWarningNone => 'Tiada';

  @override
  String get textBackgroundNone => 'Tiada';

  @override
  String get textBackgroundSolid => 'Padu';

  @override
  String get textBackgroundHighlight => 'Serlahan';

  @override
  String get textBackgroundTransparent => 'Lutsinar';

  @override
  String get textAlignLeft => 'Kiri';

  @override
  String get textAlignRight => 'Kanan';

  @override
  String get textAlignCenter => 'Tengah';

  @override
  String get cameraPermissionWebUnsupportedTitle =>
      'Kamera belum disokong di web';

  @override
  String get cameraPermissionWebUnsupportedDescription =>
      'Penangkapan dan rakaman kamera belum tersedia dalam versi web.';

  @override
  String get cameraPermissionBackToFeed => 'Kembali ke suapan';

  @override
  String get cameraCouldNotStart => 'Tidak dapat memulakan kamera';

  @override
  String get cameraUnsupportedPlatform =>
      'Kamera belum tersedia pada platform ini.\nAnda masih boleh melayari dan menonton video.';

  @override
  String get cameraPermissionErrorTitle => 'Ralat Kebenaran';

  @override
  String get cameraPermissionErrorDescription =>
      'Sesuatu telah berlaku semasa menyemak kebenaran.';

  @override
  String get cameraPermissionRetry => 'Cuba Semula';

  @override
  String get cameraPermissionAllowAccessTitle =>
      'Benarkan akses kamera & mikrofon';

  @override
  String get cameraPermissionAllowAccessDescription =>
      'Ini membolehkan anda merakam dan menyunting video terus dalam apl, tidak lebih daripada itu.';

  @override
  String get cameraPermissionGoToSettings => 'Pergi ke tetapan';

  @override
  String get videoRecorderWhySixSecondsTitle => 'Kenapa enam saat?';

  @override
  String get videoRecorderWhySixSecondsSubtitle =>
      'Klip ringkas memberi ruang untuk spontaniti. Format 6 saat membantu anda merakam detik tulen seadanya.';

  @override
  String get videoRecorderWhySixSecondsButton => 'Faham!';

  @override
  String get videoRecorderUploadTitle => 'Kenapa tiada muat naik?';

  @override
  String get videoRecorderUploadBody =>
      'Apa yang anda lihat di Divine adalah buatan manusia: mentah dan dirakam pada saat itu. Tidak seperti platform yang membenarkan muat naik yang dihasilkan secara rapi atau dijana AI, kami mengutamakan kesahihan pengalaman terus daripada kamera.';

  @override
  String get videoRecorderUploadBodyDetail =>
      'Dengan mengekalkan penciptaan di dalam apl, kami dapat lebih menjamin bahawa kandungan adalah tulen dan tidak disunting. Kami tidak membuka muat naik galeri luaran buat masa ini untuk melindungi ketulenan itu dan memastikan komuniti kami bebas daripada kandungan sintetik sebanyak yang kami mampu.';

  @override
  String get videoRecorderUploadBodyCta =>
      'Tukar ke Capture atau Classic untuk merakam sesuatu yang tulen.';

  @override
  String get videoRecorderUploadLearnMore =>
      'Ketahui cara pengesahan berfungsi';

  @override
  String get videoRecorderAutosaveFoundTitle =>
      'Kami menemui kerja yang belum siap';

  @override
  String get videoRecorderAutosaveFoundSubtitle =>
      'Adakah anda mahu meneruskan daripada tempat anda berhenti?';

  @override
  String get videoRecorderAutosaveContinueButton => 'Ya, teruskan';

  @override
  String get videoRecorderAutosaveDiscardButton =>
      'Tidak, mulakan video baharu';

  @override
  String get videoRecorderAutosaveRestoreFailure =>
      'Tidak dapat memulihkan draf anda';

  @override
  String get videoRecorderStopRecordingTooltip => 'Berhenti merakam';

  @override
  String get videoRecorderStartRecordingTooltip => 'Mula merakam';

  @override
  String get videoRecorderRecordingTapToStopLabel =>
      'Merakam. Ketik di mana saja untuk berhenti';

  @override
  String get videoRecorderTapToStartLabel =>
      'Ketik di mana saja untuk mula merakam';

  @override
  String get videoRecorderDeleteLastClipLabel => 'Padam klip terakhir';

  @override
  String get videoRecorderSwitchCameraLabel => 'Tukar kamera';

  @override
  String videoRecorderZoomLevelLabel(String zoom) {
    return 'Zum ke $zoom×';
  }

  @override
  String get videoRecorderToggleGridLabel => 'Togol grid';

  @override
  String get videoRecorderToggleGhostFrameLabel => 'Togol bingkai hantu';

  @override
  String get videoRecorderGhostFrameEnabled => 'Bingkai hantu didayakan';

  @override
  String get videoRecorderGhostFrameDisabled => 'Bingkai hantu dilumpuhkan';

  @override
  String get videoRecorderClipDeletedMessage => 'Klip dialihkan ke tong sampah';

  @override
  String get videoRecorderClipUndoLabel => 'Buat Asal';

  @override
  String get libraryTrashEmptyTitle => 'Tong sampah kosong';

  @override
  String get libraryTrashEmptySubtitle =>
      'Klip yang dipadam berada di sini selama 30 hari sebelum dialih keluar untuk selamanya.';

  @override
  String get libraryTrashRestoreLabel => 'Pulihkan';

  @override
  String get libraryTrashDeleteNowLabel => 'Padam sekarang';

  @override
  String get libraryTrashEmptyAllLabel => 'Kosongkan tong sampah';

  @override
  String get libraryTrashDeleteConfirmTitle => 'Padam klip sekarang?';

  @override
  String get libraryTrashDeleteConfirmMessage =>
      'Ini mengalih keluar klip daripada tong sampah serta-merta.';

  @override
  String get libraryTrashEmptyConfirmTitle => 'Kosongkan tong sampah?';

  @override
  String libraryTrashEmptyConfirmMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klip',
      one: '1 klip',
    );
    return 'Ini memadam $_temp0 secara kekal daripada tong sampah serta-merta.';
  }

  @override
  String get videoRecorderCloseLabel => 'Tutup perakam video';

  @override
  String get videoRecorderContinueToEditorLabel =>
      'Teruskan ke penyunting video';

  @override
  String get videoRecorderCameraPreviewLabel => 'Pratonton kamera';

  @override
  String get videoRecorderCameraPreviewFocusHint => 'Fokuskan kamera';

  @override
  String videoRecorderSwitchToModeLabel(String mode) {
    return 'Tukar kepada mod $mode';
  }

  @override
  String get videoRecorderLipSyncAddAudioFirst =>
      'Tambah audio sebelum merakam';

  @override
  String get videoRecorderStopMotionAssembleFailed =>
      'Tidak dapat mencipta video. Cuba lagi.';

  @override
  String videoRecorderStopMotionShotsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tinggal $count syot',
      zero: 'Tiada syot tinggal',
    );
    return '$_temp0';
  }

  @override
  String get videoRecorderToggleFlashLabel => 'Togol denyar';

  @override
  String get videoRecorderCycleTimerLabel => 'Tukar pemasa';

  @override
  String get videoRecorderToggleAspectRatioLabel => 'Togol nisbah aspek';

  @override
  String get videoRecorderStabilizationLabel => 'Penstabilan';

  @override
  String get videoRecorderStabilizationModeOff => 'Mati';

  @override
  String get videoRecorderStabilizationModeStandard => 'Standard';

  @override
  String get videoRecorderStabilizationModeCinematic => 'Sinematik';

  @override
  String get videoRecorderStabilizationModeCinematicExtended =>
      'Sinematik Lanjutan';

  @override
  String get videoRecorderStabilizationModePreviewOptimized =>
      'Pratonton Dioptimumkan';

  @override
  String get videoRecorderStabilizationModeLowLatency => 'Latensi Rendah';

  @override
  String get videoRecorderStabilizationModeAuto => 'Auto';

  @override
  String get videoRecorderFlashValueOff => 'Mati';

  @override
  String get videoRecorderFlashValueOn => 'Hidup';

  @override
  String get videoRecorderFlashValueAuto => 'Auto';

  @override
  String get videoRecorderTimerValueOff => 'Mati';

  @override
  String get videoRecorderTimerValueThreeSeconds => '3 saat';

  @override
  String get videoRecorderTimerValueTenSeconds => '10 saat';

  @override
  String get videoRecorderAspectRatioValueSquare => 'Segi empat sama';

  @override
  String get videoRecorderAspectRatioValueVertical => 'Menegak';

  @override
  String get videoRecorderCameraValueFront => 'Kamera hadapan';

  @override
  String get videoRecorderCameraValueBack => 'Kamera belakang';

  @override
  String get videoRecorderLibraryEmptyLabel => 'Pustaka klip, tiada klip';

  @override
  String videoRecorderLibraryOpenLabel(int clipCount) {
    String _temp0 = intl.Intl.pluralLogic(
      clipCount,
      locale: localeName,
      other: 'Buka pustaka klip, $clipCount klip',
      one: 'Buka pustaka klip, 1 klip',
    );
    return '$_temp0';
  }

  @override
  String videoRecorderLibraryOpenStopMotionLabel(int frameCount) {
    String _temp0 = intl.Intl.pluralLogic(
      frameCount,
      locale: localeName,
      other: 'Buka pustaka stop-motion, $frameCount bingkai',
      one: 'Buka pustaka stop-motion, 1 bingkai',
      zero: 'Buka pustaka stop-motion',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorCameraLabel => 'Kamera';

  @override
  String get videoEditorOpenCameraSemanticLabel => 'Buka kamera';

  @override
  String get videoEditorLibraryLabel => 'Pustaka';

  @override
  String get videoEditorTextLabel => 'Teks';

  @override
  String get videoEditorDrawLabel => 'Lukis';

  @override
  String get videoEditorFilterLabel => 'Tapis';

  @override
  String get videoEditorTuneLabel => 'Laras';

  @override
  String get videoEditorOpenTuneSemanticLabel => 'Buka penyunting pelarasan';

  @override
  String get videoEditorTuneBrightness => 'Kecerahan';

  @override
  String get videoEditorTuneContrast => 'Kontras';

  @override
  String get videoEditorTuneSaturation => 'Ketepuan';

  @override
  String get videoEditorTuneExposure => 'Pendedahan';

  @override
  String get videoEditorTuneHue => 'Rona';

  @override
  String get videoEditorTuneTemperature => 'Suhu';

  @override
  String get videoEditorTuneTint => 'Ton';

  @override
  String get videoEditorTuneFade => 'Pudar';

  @override
  String get videoEditorAudioLabel => 'Audio';

  @override
  String get videoEditorAddTitle => 'Tambah';

  @override
  String get videoEditorOpenLibrarySemanticLabel => 'Buka Pustaka';

  @override
  String get videoEditorOpenAudioSemanticLabel => 'Buka penyunting audio';

  @override
  String get videoEditorCaptionsLabel => 'Sarikata';

  @override
  String get videoEditorOpenCaptionsSemanticLabel => 'Buka penyunting sarikata';

  @override
  String get videoEditorCaptionsBurnInLabel => 'Bakar ke dalam video';

  @override
  String get videoEditorCaptionsPresetCustom => 'Tersuai';

  @override
  String get videoEditorCaptionsCustomStyleTitle => 'Gaya tersuai';

  @override
  String get videoEditorCaptionsCustomApply => 'Gunakan';

  @override
  String get videoEditorCaptionsCustomFont => 'Fon';

  @override
  String get videoEditorCaptionsCustomTextColor => 'Warna teks';

  @override
  String get videoEditorCaptionsCustomBackground => 'Latar belakang';

  @override
  String get videoEditorCaptionsCustomBackgroundColor => 'Warna latar belakang';

  @override
  String get videoEditorCaptionsCustomAnimation => 'Animasi';

  @override
  String get videoEditorCaptionsAnimationNone => 'Tiada';

  @override
  String get videoEditorCaptionsAnimationFade => 'Pudar';

  @override
  String get videoEditorCaptionsAnimationPop => 'Pop';

  @override
  String get videoEditorCaptionsAnimationSpring => 'Spring';

  @override
  String get videoEditorCaptionsEditTitle => 'Sarikata';

  @override
  String get videoEditorCaptionsGeneratingTitle => 'Mendengar pertuturan…';

  @override
  String get videoEditorCaptionsGeneratingSubtitle =>
      'Menukarkan audio anda kepada cadangan sarikata.';

  @override
  String get videoEditorCaptionsNoSpeechMessage =>
      'Kami tidak dapat mendengar sebarang pertuturan. Anda masih boleh menulis sarikata sendiri.';

  @override
  String get videoEditorCaptionsUnavailableMessage =>
      'Pengecaman pertuturan tidak tersedia pada peranti ini. Anda boleh menulis sarikata sendiri.';

  @override
  String get videoEditorCaptionsNotAuthorizedMessage =>
      'Pengecaman pertuturan tidak dibenarkan. Dayakannya dalam Tetapan atau tulis sarikata sendiri.';

  @override
  String get videoEditorCaptionsFailedMessage =>
      'Transkripsi tidak berjaya kali ini. Anda boleh menulis sarikata sendiri.';

  @override
  String get videoEditorCaptionsStartEmptyButton => 'Tulis sarikata sendiri';

  @override
  String get videoEditorCaptionsAddCue => 'Tambah sarikata';

  @override
  String get videoEditorCaptionsCueTextHint => 'Teks sarikata';

  @override
  String get videoEditorCaptionsCueDeleteSemanticLabel => 'Padam sarikata';

  @override
  String get videoEditorCaptionsDeleteTrack => 'Alih keluar semua sarikata';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmTitle =>
      'Alih keluar sarikata?';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmSubtitle =>
      'Semua teks dan masa sarikata akan hilang.';

  @override
  String get videoEditorCaptionsCloseSemanticLabel =>
      'Tutup penyunting sarikata';

  @override
  String get videoEditorCaptionsDoneSemanticLabel => 'Sahkan sarikata';

  @override
  String get videoEditorCaptionsPresetTitle => 'Gaya sarikata';

  @override
  String get videoEditorCaptionsPresetClassic => 'Klasik';

  @override
  String get videoEditorCaptionsPresetPop => 'Pop';

  @override
  String get videoEditorCaptionsPresetZoom => 'Zum';

  @override
  String get videoEditorCaptionsPresetSpring => 'Spring';

  @override
  String get videoEditorCaptionsPresetMono => 'Mono';

  @override
  String get videoEditorCaptionsPresetHeadline => 'Tajuk';

  @override
  String get videoEditorCaptionsPresetTypewriter => 'Mesin Taip';

  @override
  String get videoEditorCaptionsPresetMarker => 'Penanda';

  @override
  String get videoEditorCaptionsPresetScript => 'Skrip';

  @override
  String get videoEditorCaptionsPresetRetro => 'Retro';

  @override
  String get videoEditorCaptionsPresetElegant => 'Elegan';

  @override
  String get videoEditorCaptionsPresetBubble => 'Gelembung';

  @override
  String get videoEditorCaptionsPresetNeon => 'Neon';

  @override
  String get videoEditorCaptionsPresetBold => 'Tebal';

  @override
  String get videoEditorCaptionsPresetDreamy => 'Mimpi';

  @override
  String get videoEditorCaptionsPresetOcean => 'Lautan';

  @override
  String get videoEditorCaptionsPresetSunny => 'Cerah';

  @override
  String get videoEditorCaptionsPresetHandwritten => 'Tulisan Tangan';

  @override
  String get videoEditorCaptionsPresetSerif => 'Serif';

  @override
  String get videoEditorCaptionsPresetStamp => 'Setem';

  @override
  String get videoEditorOpenTextSemanticLabel => 'Buka penyunting teks';

  @override
  String get videoEditorOpenDrawSemanticLabel => 'Buka penyunting lukisan';

  @override
  String get videoEditorOpenFilterSemanticLabel => 'Buka penyunting penapis';

  @override
  String get videoEditorOpenStickerSemanticLabel => 'Buka penyunting pelekat';

  @override
  String get videoEditorSaveDraftTitle => 'Simpan draf anda?';

  @override
  String get videoEditorSaveDraftSubtitle =>
      'Simpan suntingan anda untuk kemudian, atau buangnya dan tinggalkan penyunting.';

  @override
  String get videoEditorSaveDraftButton => 'Simpan draf';

  @override
  String get videoEditorDiscardChangesButton => 'Buang perubahan';

  @override
  String get videoEditorKeepEditingButton => 'Terus menyunting';

  @override
  String get videoEditorDeleteLayerDropZone => 'Zon lepas padam lapisan';

  @override
  String get videoEditorReleaseToDeleteLayer =>
      'Lepaskan untuk memadam lapisan';

  @override
  String get videoEditorDoneLabel => 'Siap';

  @override
  String get videoEditorPlayPauseSemanticLabel => 'Main atau jeda video';

  @override
  String videoEditorSplitPositionInvalid(int minDurationMs) {
    return 'Kedudukan pemisahan tidak sah. Kedua-dua klip mestilah sekurang-kurangnya ${minDurationMs}ms.';
  }

  @override
  String get videoEditorSaveSelectedClip => 'Simpan klip dipilih';

  @override
  String get videoEditorSaveClip => 'Simpan klip';

  @override
  String get videoEditorClipSavedSuccess => 'Klip disimpan ke pustaka';

  @override
  String get videoEditorClipSaveFailed => 'Gagal menyimpan klip';

  @override
  String get videoEditorColorPickerSemanticLabel => 'Pemilih warna';

  @override
  String get videoEditorUndoSemanticLabel => 'Buat Asal';

  @override
  String get videoEditorRedoSemanticLabel => 'Buat Semula';

  @override
  String get videoEditorTextColorSemanticLabel => 'Warna teks';

  @override
  String get videoEditorTextAlignmentSemanticLabel => 'Penjajaran teks';

  @override
  String get videoEditorTextBackgroundSemanticLabel => 'Latar belakang teks';

  @override
  String get videoEditorFontSemanticLabel => 'Fon';

  @override
  String get videoEditorNoStickersFound => 'Tiada pelekat ditemui';

  @override
  String get videoEditorNoStickersAvailable => 'Tiada pelekat tersedia';

  @override
  String get videoEditorFailedLoadStickers => 'Gagal memuatkan pelekat';

  @override
  String get videoEditorVoiceOverLabel => 'Suara latar';

  @override
  String videoEditorVoiceOverTakeName(int number) {
    return 'Rakaman $number';
  }

  @override
  String get videoEditorOpenVoiceOverSemanticLabel => 'Rakam suara latar';

  @override
  String get videoEditorVoiceOverRecordSemanticLabel => 'Mula merakam';

  @override
  String get videoEditorVoiceOverStopSemanticLabel => 'Berhenti merakam';

  @override
  String get videoEditorVoiceOverHint =>
      'Ketik untuk merakam. Tambah seberapa banyak take yang anda suka.';

  @override
  String videoEditorVoiceOverRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rakaman',
      one: '1 rakaman',
      zero: 'Belum ada rakaman',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorVoiceOverDeleteLast => 'Padam rakaman terakhir';

  @override
  String get videoEditorVoiceOverPermissionTitle => 'Akses mikrofon diperlukan';

  @override
  String get videoEditorVoiceOverPermissionBody =>
      'Benarkan akses mikrofon untuk merakam suara latar.';

  @override
  String get videoEditorVoiceOverOpenSettings => 'Buka tetapan';

  @override
  String get videoEditorVoiceOverRecordingStarted => 'Rakaman bermula';

  @override
  String get videoEditorVoiceOverRecordingSaved => 'Rakaman disimpan';

  @override
  String get videoEditorVoiceOverTooLong =>
      'Rakaman lebih panjang daripada video anda';

  @override
  String get videoEditorPlaySemanticLabel => 'Main';

  @override
  String get videoEditorPauseSemanticLabel => 'Jeda';

  @override
  String get videoEditorVolumeSemanticLabel => 'Laras volum';

  @override
  String videoEditorTimelineVolumePreview(int percent) {
    return 'Volum $percent%';
  }

  @override
  String get videoEditorTimelineSlideToAdjust => 'Luncur untuk melaras';

  @override
  String get videoEditorChromaKeyLabel => 'Skrin hijau';

  @override
  String get videoEditorChromaKeyTitle => 'Skrin hijau';

  @override
  String get videoEditorChromaKeySemanticLabel =>
      'Sediakan skrin hijau untuk klip ini';

  @override
  String get videoEditorChromaKeyCloseSemanticLabel =>
      'Buang perubahan skrin hijau';

  @override
  String get videoEditorChromaKeyDoneSemanticLabel => 'Gunakan skrin hijau';

  @override
  String get videoEditorChromaKeyAutoDetect => 'Kesan automatik';

  @override
  String get videoEditorChromaKeyPresetGreen => 'Hijau';

  @override
  String get videoEditorChromaKeyPresetBlue => 'Biru';

  @override
  String get videoEditorChromaKeyScreenColorLabel => 'Warna skrin';

  @override
  String get videoEditorChromaKeyAmountLabel => 'Kekuatan';

  @override
  String get videoEditorChromaKeyAmountHint =>
      'Berapa banyak warna skrin yang hilang';

  @override
  String get videoEditorChromaKeyEdgeLabel => 'Tepi';

  @override
  String get videoEditorChromaKeyEdgeHint =>
      'Melembutkan potongan supaya rambut tidak bergerigi';

  @override
  String get videoEditorChromaKeySpillLabel => 'Limpahan';

  @override
  String get videoEditorChromaKeySpillHint =>
      'Menarik warna skrin keluar daripada subjek anda';

  @override
  String get videoEditorChromaKeyBackgroundLabel => 'Ganti dengan';

  @override
  String get videoEditorChromaKeyBackgroundNone => 'Tiada';

  @override
  String get videoEditorChromaKeyBackgroundColor => 'Warna';

  @override
  String get videoEditorChromaKeyBackgroundImage => 'Imej';

  @override
  String get videoEditorChromaKeyBackgroundVideo => 'Klip';

  @override
  String get videoEditorChromaKeyTransparentHint =>
      'Video tidak boleh menyimpan ketelusan, jadi ini dieksport sebagai hitam.';

  @override
  String get videoEditorChromaKeyDetectFailed =>
      'Skrin tidak ditemui. Ia perlu mencapai tepi bingkai — pilih warnanya secara manual.';

  @override
  String get videoEditorChromaKeyPickClipTitle => 'Pilih klip';

  @override
  String get videoEditorChromaKeyNoLibraryClips =>
      'Pustaka anda kosong. Simpan klip dahulu, kemudian gunakannya sebagai latar.';

  @override
  String get videoEditorChromaKeyImagePickFailed =>
      'Imej itu tidak dapat dimuatkan.';

  @override
  String get videoEditorChromaKeyRemove => 'Alih keluar skrin hijau';

  @override
  String get videoEditorChromaKeyFailed =>
      'Skrin hijau tidak dapat digunakan. Klip anda tidak berubah.';

  @override
  String get videoEditorChromaKeyRemoveFailed =>
      'Skrin hijau tidak dapat dialih keluar. Klip anda tidak berubah.';

  @override
  String get videoEditorChromaKeyApplying => 'Menggunakan skrin hijau…';

  @override
  String get videoEditorChromaKeyPreviewUnavailable =>
      'Peranti ini tidak dapat menunjukkan pratonton langsung. Tetapan anda tetap digunakan semasa eksport.';

  @override
  String videoEditorClipVolumeLabel(int index) {
    return 'Klip $index';
  }

  @override
  String get videoEditorDeleteLabel => 'Padam';

  @override
  String get videoEditorDeleteSelectedItemSemanticLabel => 'Padam item dipilih';

  @override
  String get videoEditorStopMotionFramesPerImageLabel => 'Bingkai setiap imej';

  @override
  String videoEditorStopMotionFramesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bingkai',
      one: '1 bingkai',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorStopMotionFramesPerImageButtonLabel => 'Bingkai';

  @override
  String videoEditorStopMotionFramesPerImageValueSemanticLabel(int count) {
    return '$count bingkai setiap imej';
  }

  @override
  String videoEditorStopMotionFrameSemanticLabel(int position, int total) {
    return 'Bingkai stop-motion $position daripada $total';
  }

  @override
  String get videoEditorEditLabel => 'Sunting';

  @override
  String get videoEditorEditSelectedItemSemanticLabel => 'Sunting item dipilih';

  @override
  String get videoEditorDuplicateLabel => 'Duplikasi';

  @override
  String get videoEditorDuplicateSelectedItemSemanticLabel =>
      'Duplikasi item dipilih';

  @override
  String get videoEditorCombineLabel => 'Gabungkan';

  @override
  String get videoEditorCombineDrawLayersSemanticLabel =>
      'Gabungkan lukisan dipilih menjadi satu lapisan';

  @override
  String get videoEditorSplitLabel => 'Pisahkan';

  @override
  String get videoEditorSplitSelectedClipSemanticLabel =>
      'Pisahkan klip dipilih';

  @override
  String get videoEditorExtractAudioLabel => 'Ekstrak Audio';

  @override
  String get videoEditorClipAudioTitle => 'Audio Klip';

  @override
  String get videoEditorExtractAudioFromClipSemanticLabel =>
      'Ekstrak audio daripada klip dan senyapkan yang asal';

  @override
  String get videoEditorExtractAudioNoLocalFile =>
      'Tidak dapat mengekstrak audio: klip tidak tersedia secara setempat.';

  @override
  String get videoEditorExtractAudioFailed =>
      'Tidak dapat mengekstrak audio. Sila cuba lagi.';

  @override
  String get videoEditorSpeedLabel => 'Kelajuan';

  @override
  String get videoEditorSetClipSpeedSemanticLabel =>
      'Tetapkan kelajuan main balik untuk klip dipilih';

  @override
  String get videoEditorReverseLabel => 'Songsang';

  @override
  String get videoEditorReverseClipSemanticLabel =>
      'Togol main balik songsang untuk klip dipilih';

  @override
  String get videoEditorReverseProgressLabel =>
      'Sebentar, kami sedang menyongsangkan klip anda';

  @override
  String get videoEditorTransformLabel => 'Ubah bentuk';

  @override
  String get videoEditorTransformSelectedClipSemanticLabel =>
      'Pangkas, putar atau terbalikkan klip dipilih';

  @override
  String get videoEditorTransformProgressLabel =>
      'Sebentar, kami sedang mengubah bentuk klip anda';

  @override
  String get videoEditorTransformFailed =>
      'Tidak dapat mengubah bentuk klip. Sila cuba lagi.';

  @override
  String get videoEditorTransformNoLocalFile =>
      'Tidak dapat mengubah bentuk: klip tidak tersedia secara setempat.';

  @override
  String get videoEditorTransformSelectedFrameSemanticLabel =>
      'Pangkas, putar atau balikkan bingkai dipilih';

  @override
  String get videoEditorTransformFrameProgressLabel =>
      'Sekejap, kami sedang mengubah bingkai anda';

  @override
  String get videoEditorTransformFrameFailed =>
      'Bingkai tidak dapat diubah. Sila cuba lagi.';

  @override
  String get videoEditorTransformRotateLabel => 'Putar';

  @override
  String get videoEditorTransformFlipLabel => 'Terbalikkan';

  @override
  String get videoEditorTransformResetLabel => 'Tetapkan semula';

  @override
  String get videoEditorTransformApplySemanticLabel => 'Gunakan ubah bentuk';

  @override
  String get videoEditorTransformCancelSemanticLabel => 'Batalkan ubah bentuk';

  @override
  String get videoEditorTransformPlayLabel => 'Main';

  @override
  String get videoEditorTransformPauseLabel => 'Jeda';

  @override
  String get videoEditorReverseNoLocalFile =>
      'Tidak dapat menyongsangkan: klip tidak tersedia secara setempat.';

  @override
  String get videoEditorReverseFailed =>
      'Tidak dapat menyongsangkan klip. Sila cuba lagi.';

  @override
  String get videoEditorSpeedSheetTitle => 'Kelajuan Klip';

  @override
  String get videoEditorTransitionSheetTitle => 'Peralihan';

  @override
  String get videoEditorTransitionNone => 'Tiada';

  @override
  String get videoEditorTransitionDissolve => 'Larut';

  @override
  String get videoEditorTransitionFadeToBlack => 'Pudar ke hitam';

  @override
  String get videoEditorTransitionFadeToWhite => 'Pudar ke putih';

  @override
  String get videoEditorTransitionSlide => 'Luncur';

  @override
  String get videoEditorTransitionPush => 'Tolak';

  @override
  String get videoEditorTransitionWipe => 'Sapu';

  @override
  String get videoEditorTransitionButtonSemanticLabel => 'Sunting peralihan';

  @override
  String get videoEditorLoopTransitionSheetTitle => 'Peralihan loop';

  @override
  String get videoEditorLoopTransitionButtonSemanticLabel =>
      'Sunting peralihan loop';

  @override
  String get videoEditorTransitionDuration => 'Tempoh';

  @override
  String get videoEditorTransitionDurationLimitedHint =>
      'Dipendekkan untuk mengelakkan pertindihan dengan peralihan bersebelahan.';

  @override
  String get videoEditorTransitionCurve => 'Lengkung';

  @override
  String get videoEditorTransitionDirection => 'Arah';

  @override
  String get videoEditorTransitionDirectionLeft => 'Kiri';

  @override
  String get videoEditorTransitionDirectionRight => 'Kanan';

  @override
  String get videoEditorTransitionDirectionUp => 'Atas';

  @override
  String get videoEditorTransitionDirectionDown => 'Bawah';

  @override
  String videoEditorTransitionCurveOptionSemanticLabel(int number) {
    return 'Lengkung reda $number';
  }

  @override
  String get videoEditorLayerAnimationLabel => 'Animasi';

  @override
  String get videoEditorLayerAnimationButtonSemanticLabel =>
      'Sunting animasi lapisan';

  @override
  String get videoEditorLayerAnimationEnter => 'Masuk';

  @override
  String get videoEditorLayerAnimationLeave => 'Keluar';

  @override
  String get videoEditorLayerAnimationFade => 'Pudar';

  @override
  String get videoEditorLayerAnimationScale => 'Skala';

  @override
  String get videoEditorLayerAnimationScaleFrom => 'Skala daripada';

  @override
  String get videoEditorFinishTimelineEditingSemanticLabel =>
      'Selesai menyunting garis masa';

  @override
  String get videoEditorAudioPlayPreviewSemanticLabel => 'Main pratonton';

  @override
  String get videoEditorAudioPausePreviewSemanticLabel => 'Jeda pratonton';

  @override
  String get videoEditorAudioUntitledSound => 'Bunyi tanpa tajuk';

  @override
  String get videoEditorAudioUntitled => 'Tanpa tajuk';

  @override
  String get videoEditorAudioAddAudio => 'Tambah audio';

  @override
  String get videoEditorAudioNoSoundsAvailableTitle => 'Tiada bunyi tersedia';

  @override
  String get videoEditorAudioNoSoundsAvailableSubtitle =>
      'Bunyi akan muncul di sini apabila pencipta berkongsi audio';

  @override
  String get videoEditorAudioFailedToLoadTitle => 'Gagal memuatkan bunyi';

  @override
  String get videoEditorAudioSegmentInstruction =>
      'Pilih segmen audio untuk video anda';

  @override
  String get videoEditorAudioCategoryDivine => 'Divine';

  @override
  String get videoEditorAudioCategoryCommunity => 'Komuniti';

  @override
  String get videoEditorAudioCategoryFeatured => 'Pilihan';

  @override
  String get videoEditorAudioCategoryMySounds => 'Bunyi Saya';

  @override
  String get videoEditorDrawToolArrowSemanticLabel => 'Alat anak panah';

  @override
  String get videoEditorDrawToolEraserSemanticLabel => 'Alat pemadam';

  @override
  String get videoEditorDrawToolMarkerSemanticLabel => 'Alat penanda';

  @override
  String get videoEditorDrawToolPencilSemanticLabel => 'Alat pensel';

  @override
  String get videoEditorShowTimelineSemanticLabel => 'Tunjuk garis masa';

  @override
  String get videoEditorHideTimelineSemanticLabel => 'Sembunyikan garis masa';

  @override
  String get videoEditorFeedPreviewContent =>
      'Elakkan meletakkan kandungan di belakang kawasan ini.';

  @override
  String get videoEditorStickersDivineOriginals => 'Divine Originals';

  @override
  String get videoEditorStickerSearchHint => 'Cari pelekat...';

  @override
  String get videoEditorSelectFontSemanticLabel => 'Pilih fon';

  @override
  String get videoEditorFontUnknown => 'Tidak diketahui';

  @override
  String get videoEditorSplitPlayheadOutsideClip =>
      'Kepala main mestilah berada dalam klip yang dipilih untuk memisahkan.';

  @override
  String get videoEditorTimelineTrimStartSemanticLabel => 'Pangkas permulaan';

  @override
  String get videoEditorTimelineTrimEndSemanticLabel => 'Pangkas penghujung';

  @override
  String get videoEditorTimelineTrimClipSemanticLabel => 'Pangkas klip';

  @override
  String get videoEditorTimelineTrimClipHint =>
      'Seret pemegang untuk melaras tempoh klip';

  @override
  String videoEditorTimelineDraggingClipSemanticLabel(int index) {
    return 'Menyeret klip $index';
  }

  @override
  String videoEditorTimelineClipSemanticLabel(
    int index,
    int total,
    String duration,
  ) {
    return 'Klip $index daripada $total, $duration saat';
  }

  @override
  String get videoEditorTimelineClipReorderHint =>
      'Tekan lama untuk menyusun semula';

  @override
  String get videoEditorTimelineClipMoveLeft => 'Alih ke kiri';

  @override
  String get videoEditorTimelineClipMoveRight => 'Alih ke kanan';

  @override
  String videoEditorTimelineClipSelectedSemanticLabel(int index, int total) {
    return 'Klip $index daripada $total, dipilih';
  }

  @override
  String videoEditorTimelineClipUnselectedSemanticLabel(int index, int total) {
    return 'Klip $index daripada $total, tidak dipilih';
  }

  @override
  String get videoEditorMultiSelectLabel => 'Pilih';

  @override
  String get videoEditorMultiSelectSemanticLabel => 'Pilih berbilang klip';

  @override
  String get videoEditorMultiSelectDoneSemanticLabel => 'Selesai memilih klip';

  @override
  String videoEditorMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klip dipilih',
      one: '1 klip dipilih',
      zero: 'Tiada klip dipilih',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorLayerMultiSelectSemanticLabel =>
      'Pilih berbilang lukisan';

  @override
  String get videoEditorLayerMultiSelectDoneSemanticLabel =>
      'Selesai memilih lukisan';

  @override
  String get videoEditorDeleteSelectedDrawingsSemanticLabel =>
      'Padam lukisan dipilih';

  @override
  String videoEditorLayerMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lukisan dipilih',
      one: '1 lukisan dipilih',
      zero: 'Tiada lukisan dipilih',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorMergeLabel => 'Gabungkan';

  @override
  String get videoEditorMergeSelectedClipsSemanticLabel =>
      'Gabungkan klip dipilih';

  @override
  String get videoEditorDeleteSelectedClipsSemanticLabel =>
      'Padam klip dipilih';

  @override
  String get videoEditorDeleteSelectedFramesSemanticLabel =>
      'Padam bingkai dipilih';

  @override
  String get videoEditorReverseSelectedFramesSemanticLabel =>
      'Songsangkan bingkai dipilih';

  @override
  String get videoEditorDuplicateSelectedFramesSemanticLabel =>
      'Duplikasi bingkai dipilih';

  @override
  String videoEditorStopMotionTooShortSnackbar(int seconds) {
    return 'Video anda memerlukan sekurang-kurangnya ${seconds}s — rakam beberapa bingkai lagi.';
  }

  @override
  String get videoEditorMergeProgressLabel =>
      'Sebentar, kami sedang menggabungkan klip anda';

  @override
  String get videoEditorMergeFailed =>
      'Tidak dapat menggabungkan klip. Sila cuba lagi.';

  @override
  String get videoEditorTimelineLongPressToDragHint =>
      'Tekan lama untuk menyeret';

  @override
  String get videoEditorVideoTimelineSemanticLabel => 'Garis masa video';

  @override
  String videoEditorTimelinePositionFormat(int minutes, String seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String videoEditorColorSelectedSemanticLabel(String colorName) {
    return '$colorName, dipilih';
  }

  @override
  String get videoEditorCloseColorPickerSemanticLabel => 'Tutup pemilih warna';

  @override
  String get videoEditorPickColorTitle => 'Pilih warna';

  @override
  String get videoEditorConfirmColorSemanticLabel => 'Sahkan warna';

  @override
  String get videoEditorSaturationBrightnessSemanticLabel =>
      'Ketepuan dan kecerahan';

  @override
  String videoEditorSaturationBrightnessValue(int saturation, int brightness) {
    return 'Ketepuan $saturation%, Kecerahan $brightness%';
  }

  @override
  String get videoEditorHueSemanticLabel => 'Rona';

  @override
  String get videoEditorAddElementSemanticLabel => 'Tambah elemen';

  @override
  String get videoEditorDoneSemanticLabel => 'Siap';

  @override
  String get videoEditorLevelSemanticLabel => 'Tahap';

  @override
  String get videoMetadataClosePostDetailsSemanticLabel =>
      'Tutup butiran siaran';

  @override
  String get videoMetadataDismissHelpDialogSemanticLabel =>
      'Ketepikan dialog bantuan';

  @override
  String get videoMetadataGotItButton => 'Faham!';

  @override
  String get videoMetadataLimitReachedWarning =>
      'Had 64KB dicapai. Alih keluar sesetengah kandungan untuk meneruskan.';

  @override
  String get videoMetadataExpirationLabel => 'Tamat tempoh';

  @override
  String get videoMetadataSelectExpirationSemanticLabel =>
      'Pilih masa tamat tempoh';

  @override
  String get videoMetadataTitleLabel => 'Tajuk';

  @override
  String get videoMetadataDescriptionLabel => 'Keterangan';

  @override
  String get videoMetadataTagsLabel => 'Tag';

  @override
  String videoMetadataDeleteTagHint(String tag) {
    return 'Padam Tag $tag';
  }

  @override
  String get videoMetadataContentWarningLabel => 'Tambah amaran kandungan';

  @override
  String get videoMetadataSelectContentWarningsSemanticLabel =>
      'Pilih amaran kandungan';

  @override
  String get videoMetadataContentWarningSelectAllThatApply =>
      'Pilih semua yang berkaitan';

  @override
  String get videoMetadataAudioReuseSubtitle =>
      'Benarkan orang lain menyimpan dan menggunakan semula audio video ini.';

  @override
  String get publishAudioReuseDegradedWarning =>
      'Video anda sudah naik, tetapi bunyinya tidak diterbitkan. Sunting video untuk berkongsi bunyi itu.';

  @override
  String get videoMetadataCollaboratorsLabel => 'Tambah kolaborator';

  @override
  String get videoMetadataAddCollaboratorSemanticLabel => 'Jemput kolaborator';

  @override
  String get videoMetadataMutualFollowersSearchText => 'Pengikut saling';

  @override
  String get videoMetadataInspiredByLabel => 'Tambah diilhamkan oleh';

  @override
  String get videoMetadataSetInspiredBySemanticLabel =>
      'Tetapkan diilhamkan oleh';

  @override
  String get videoMetadataCreatorCannotBeReferencedSnackbar =>
      'Pencipta ini tidak boleh dirujuk.';

  @override
  String get videoMetadataPostDetailsTitle => 'Butiran siaran';

  @override
  String get videoMetadataSavedToLibrarySnackbar => 'Disimpan ke pustaka';

  @override
  String get videoMetadataFailedToSaveSnackbar => 'Gagal menyimpan';

  @override
  String get videoMetadataGoToLibraryButton => 'Pergi ke Pustaka';

  @override
  String get videoMetadataSaveForLaterSemanticLabel =>
      'Butang simpan untuk kemudian';

  @override
  String get videoMetadataSavingVideoHint => 'Menyimpan video...';

  @override
  String videoMetadataSaveToDraftsHint(String destination) {
    return 'Simpan video ke draf dan $destination';
  }

  @override
  String videoMetadataSaveToDraftsWithoutGalleryHint(String destination) {
    return 'Simpan video ke draf. Belum ada video yang dirender, jadi tiada salinan dalam $destination.';
  }

  @override
  String get videoMetadataSaveForLaterButton => 'Simpan untuk Kemudian';

  @override
  String get videoMetadataPostSemanticLabel => 'Butang siarkan';

  @override
  String get videoMetadataPublishVideoHint => 'Terbitkan video ke suapan';

  @override
  String get videoMetadataShareReplyToFeedTitle => 'Juga kongsi ke suapan saya';

  @override
  String get videoMetadataShareReplyToFeedSubtitle =>
      'Mati mengekalkan video ini hanya dalam urusan komen.';

  @override
  String get videoMetadataFormNotReadyHint => 'Isi borang untuk mendayakan';

  @override
  String get videoMetadataPostButton => 'Siarkan';

  @override
  String get videoMetadataOpenPreviewSemanticLabel =>
      'Buka skrin pratonton siaran';

  @override
  String get videoMetadataShareTitle => 'Kongsi';

  @override
  String get videoMetadataVideoDetailsSubtitle => 'Butiran video';

  @override
  String get videoMetadataClassicDoneButton => 'Siap';

  @override
  String get videoMetadataPlayPreviewSemanticLabel => 'Main pratonton';

  @override
  String get videoMetadataPausePreviewSemanticLabel => 'Jeda pratonton';

  @override
  String get videoMetadataClosePreviewSemanticLabel => 'Tutup pratonton video';

  @override
  String get videoMetadataRemoveSemanticLabel => 'Alih Keluar';

  @override
  String get fullscreenFeedRemovedMessage => 'Video dialih keluar';

  @override
  String get fullscreenFeedEmptyMessage =>
      'Tiada apa-apa lagi untuk dimainkan di sini';

  @override
  String get settingsBadgesTitle => 'Lencana';

  @override
  String get settingsBadgesSubtitle =>
      'Terima anugerah dan semak status lencana yang dikeluarkan.';

  @override
  String get badgesTitle => 'Lencana';

  @override
  String get badgesLoadError => 'Tidak dapat memuatkan lencana';

  @override
  String get badgesUpdateError => 'Tidak dapat mengemas kini lencana';

  @override
  String get badgesAwardedEmptyTitle => 'Belum ada anugerah lencana';

  @override
  String get badgesAwardedEmptySubtitle =>
      'Apabila seseorang menganugerahkan anda lencana Nostr, ia akan tiba di sini.';

  @override
  String get badgesStatusAccepted => 'Diterima';

  @override
  String get badgesStatusNotAccepted => 'Tidak diterima';

  @override
  String get badgesActionRemove => 'Alih Keluar';

  @override
  String get badgesActionAccept => 'Terima';

  @override
  String get badgesActionReject => 'Tolak';

  @override
  String get badgesIssuedEmptyTitle => 'Belum ada lencana dikeluarkan';

  @override
  String get badgesIssuedEmptySubtitle =>
      'Lencana yang anda keluarkan akan menunjukkan status penerimaan di sini.';

  @override
  String get badgesIssuedNoRecipients =>
      'Tiada penerima ditemui untuk anugerah ini.';

  @override
  String get badgesRecipientAcceptedStatus => 'Diterima oleh penerima';

  @override
  String get badgesRecipientWaitingStatus => 'Menunggu penerima';

  @override
  String badgesHiddenSectionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Disembunyikan ($count)',
      one: 'Disembunyikan (1)',
    );
    return '$_temp0';
  }

  @override
  String get badgesActionRestore => 'Pulihkan';

  @override
  String get badgesHiddenSnackbar => 'Lencana disembunyikan';

  @override
  String get badgesHiddenSnackbarUndo => 'Buat asal';

  @override
  String get badgesTabAwarded => 'Diterima';

  @override
  String get badgesTabCreated => 'Dicipta';

  @override
  String get badgesTabIssued => 'Diberikan';

  @override
  String get badgesCreateAction => 'Lencana baharu';

  @override
  String get badgesCreatedEmptyTitle => 'Belum ada lencana ciptaan anda';

  @override
  String get badgesCreatedEmptySubtitle =>
      'Cipta satu dan berikan kepada orang yang layak.';

  @override
  String badgesCreatedAwardSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Diberikan kepada $count orang',
      one: 'Diberikan kepada 1 orang',
      zero: 'Belum diberikan',
    );
    return '$_temp0';
  }

  @override
  String get badgeEditorCreateTitle => 'Lencana baharu';

  @override
  String get badgeEditorEditTitle => 'Edit lencana';

  @override
  String get badgeEditorNameLabel => 'Nama';

  @override
  String get badgeEditorNameHint => 'Pencuri Tumpuan';

  @override
  String get badgeEditorIdentifierLabel => 'Pengecam';

  @override
  String get badgeEditorIdentifierHelp =>
      'Sebahagian daripada alamat lencana, jadi ia kekal selepas lencana wujud.';

  @override
  String get badgeEditorIdentifierTaken =>
      'Anda sudah ada lencana dengan pengecam ini. Edit yang itu — menerbitkan di sini akan menggantikannya.';

  @override
  String get badgeEditorIdentifierRequired =>
      'Setiap lencana perlukan pengecam — taip sendiri kalau nama tidak mengisinya.';

  @override
  String get badgeEditorDescriptionLabel => 'Penerangan';

  @override
  String get badgeEditorDescriptionHint =>
      'Untuk sesiapa yang mencuri tumpuan dengan satu loop sahaja.';

  @override
  String get badgeEditorArtworkLabel => 'Grafik';

  @override
  String get badgeEditorArtworkAdd => 'Tambah grafik';

  @override
  String get badgeEditorArtworkReplace => 'Ganti';

  @override
  String get badgeEditorArtworkError => 'Imej itu gagal dimuat naik';

  @override
  String get badgeEditorArtworkRequired => 'Setiap lencana perlukan grafik.';

  @override
  String get badgeEditorArtworkRemove => 'Buang grafik';

  @override
  String get badgeEditorArtworkSheetTitle => 'Grafik lencana';

  @override
  String get badgeDetailDeleteAction => 'Padam lencana';

  @override
  String get badgeDetailDeleteTitle => 'Padam lencana ini?';

  @override
  String get badgeDetailDeleteBody =>
      'Ini meminta geganti membuang lencana dan semua pemberian yang anda buat. Geganti boleh menolak, dan sesiapa yang menyematkannya akan mengekalkannya pada profil sehingga mereka membuangnya.';

  @override
  String get badgeDetailDeleteConfirm => 'Padam';

  @override
  String get badgeEditorSaveAction => 'Terbitkan lencana';

  @override
  String get badgeEditorSaveError => 'Lencana gagal diterbitkan';

  @override
  String get badgeEditorLoadError => 'Lencana ini gagal dimuatkan';

  @override
  String get badgeDetailTitle => 'Lencana';

  @override
  String get badgeDetailMadeBy => 'Dicipta oleh';

  @override
  String get badgeDetailRecipientsTitle => 'Diberikan kepada';

  @override
  String get badgeDetailNoRecipients => 'Belum ada sesiapa memilikinya.';

  @override
  String get badgeDetailAwardAction => 'Berikan lencana ini';

  @override
  String get badgeDetailEditAction => 'Edit lencana';

  @override
  String get badgeDetailShareAction => 'Kongsi';

  @override
  String badgeDetailShareMessage(String link) {
    return 'Tengok lencana ini di Divine: $link';
  }

  @override
  String get badgeDetailRevokeAction => 'Tarik balik lencana';

  @override
  String get badgeDetailRevokeTitle => 'Tarik balik lencana ini?';

  @override
  String get badgeDetailRevokeBody =>
      'Ini meminta geganti membuang pemberian yang anda buat kepada orang ini. Geganti boleh menolak, dan jika lencana itu sudah disematkan, ia kekal pada profil mereka sehingga mereka membuangnya. Apa pun, mereka tidak diberitahu.';

  @override
  String get badgeDetailRevokeSelfBody =>
      'Ini meminta geganti membuang pemberian yang anda buat kepada diri sendiri, dan menanggalkan lencana daripada profil anda. Jika geganti menolak pemadaman, tiada apa yang berubah.';

  @override
  String get badgeDetailRevokeConfirm => 'Tarik balik';

  @override
  String get badgeDetailRevokeSuccess => 'Lencana ditarik balik';

  @override
  String get badgeDetailBlockClaimantsAction => 'Sekat pemegang lencana';

  @override
  String get badgeDetailBlockClaimantsTitle => 'Sekat pemegang lencana';

  @override
  String get badgeDetailBlockClaimantsLoadError =>
      'Tidak dapat memuatkan pemegang lencana ini';

  @override
  String get badgeDetailBlockClaimantsEmptyTitle =>
      'Tiada sesiapa memegang lencana ini sekarang';

  @override
  String get badgeDetailBlockClaimantsEmptyBody =>
      'Kami tidak menemui sesiapa untuk disekat buat masa ini.';

  @override
  String badgeDetailBlockClaimantsHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sekat $count akaun?',
      one: 'Sekat 1 akaun?',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Ini menyekat $count akaun yang sedang memegang lencana ini. Siaran mereka tidak akan muncul dalam suapan anda dan mereka tidak akan diberitahu.',
      one:
          'Ini menyekat akaun yang sedang memegang lencana ini. Siaran mereka tidak akan muncul dalam suapan anda dan mereka tidak akan diberitahu.',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sekat $count akaun',
      one: 'Sekat 1 akaun',
    );
    return '$_temp0';
  }

  @override
  String get badgeDetailBlockClaimantsSuccess => 'Pemegang lencana disekat';

  @override
  String get badgeDetailBlockClaimantsFailure =>
      'Tidak dapat menyekat pemegang lencana';

  @override
  String get badgeDetailLoadError => 'Lencana ini gagal dimuatkan';

  @override
  String get badgeDetailMissing =>
      'Kami tidak jumpa lencana ini pada mana-mana geganti.';

  @override
  String get badgeDetailActionError => 'Itu tidak menjadi';

  @override
  String get badgeAwardTitle => 'Berikan lencana';

  @override
  String get badgeAwardPickAction => 'Pilih orang';

  @override
  String get badgeAwardManualLabel => 'Atau tampal kunci';

  @override
  String get badgeAwardManualHint => 'npub1…, npub1…';

  @override
  String get badgeAwardEmptyHint => 'Pilih sekurang-kurangnya seorang.';

  @override
  String badgeAwardSubmitAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Berikan kepada $count orang',
      one: 'Berikan kepada 1 orang',
      zero: 'Berikan lencana',
    );
    return '$_temp0';
  }

  @override
  String get profileBadgeAwardedBy => 'Dianugerahkan oleh';

  @override
  String get profileBadgeRecipients => 'Penerima';

  @override
  String profileBadgeMoreRecipients(int count) {
    return '+$count lagi';
  }

  @override
  String profileBadgeSemanticLabel(String name) {
    return 'Lencana $name';
  }

  @override
  String get profileBadgeFallbackSemanticLabel => 'Lencana';

  @override
  String get profileBadgeFooterBody =>
      'Lencana ialah anugerah kecil yang sesiapa sahaja boleh buat di Nostr. Berikan satu kepada rakan, pencipta, atau seseorang yang menceriakan hari anda.';

  @override
  String get profileBadgeFooterLink => 'Cipta lencana anda sendiri';

  @override
  String get minorAccountReviewWelcomePageTitle => 'Panduan keluarga';

  @override
  String get minorAccountReviewWelcomeTitle => 'Belum 16? Tidak mengapa.';

  @override
  String get minorAccountReviewWelcomeBody =>
      'Jika anda mengklik ke halaman ini dan bukannya hanya memilih jawapan yang memasukkan anda, itu bermakna sesuatu. Ia menunjukkan kejujuran, keteguhan dan keprihatinan sebenar terhadap orang di sekeliling anda.\n\nPeraturan untuk orang bawah 16 tahun berbeza mengikut tempat anda tinggal. Di Divine, kami mahu keluarga membincangkannya bersama dan memutuskan bagaimana penggunaan media sosial yang sihat itu sepatutnya.';

  @override
  String get minorAccountReviewModerationTitle =>
      'Kami perlukan satu langkah lagi';

  @override
  String get minorAccountReviewModerationBody =>
      'Kami diminta untuk menyemak akaun ini dengan lebih teliti kerana ia mungkin milik seseorang yang berumur bawah 16 tahun. Aliran ini memastikan langkah seterusnya peribadi dan menunjukkan laluan yang betul untuk umur anda.';

  @override
  String get minorAccountReviewRulesTitle =>
      'Peraturannya tidak sama di mana-mana';

  @override
  String get minorAccountReviewRulesBody =>
      'Negara dan wilayah berbeza melayan penggunaan media sosial remaja secara berbeza. Itulah sebabnya kami meminta keluarga untuk berhati-hati, menyemak fakta, dan memilih langkah seterusnya bersama.';

  @override
  String get minorAccountReviewApproachTitle =>
      'Bagaimana Divine memikirkannya';

  @override
  String get minorAccountReviewApproachBody =>
      'Kami percaya tabiat teknologi yang sihat datang daripada berhenti sejenak, berfikir dan mengalihkan perhatian kepada perkara yang lebih baik, bukan daripada mengintip kanak-kanak atau menjadikan ibu bapa pengawal. Penyelidikan juga menyokong perkara itu.';

  @override
  String get minorAccountReviewLearnMoreTitle => 'Lagi untuk keluarga';

  @override
  String get minorAccountReviewKidsPolicyCta => 'Baca dasar kanak-kanak Divine';

  @override
  String get minorAccountReviewChooseAgeBandTitle => 'Pilih laluan yang sesuai';

  @override
  String get minorAccountReviewUnder13Cta => 'Bawah 13';

  @override
  String get minorAccountReviewTeenCta => 'Umur 13-15';

  @override
  String get minorAccountReviewFamilyResourcesBody =>
      'Lawati panduan keluarga Divine untuk petua praktikal, alat perbualan dan sumber untuk membantu remaja menggunakan media sosial dengan lebih selamat.';

  @override
  String get minorAccountReviewFamilyResourcesCta =>
      'Dapatkan panduan dan petua keluarga';

  @override
  String get minorAccountReviewFooter =>
      'Jika anda berumur 16 tahun ke atas dan sampai ke sini secara tidak sengaja, hubungi sokongan Divine supaya orang sebenar dapat menyemaknya.';

  @override
  String get minorAccountReviewTitle => 'Semakan Akaun';

  @override
  String get minorAccountReviewCheckingStatusTitle =>
      'Menyemak status akaun...';

  @override
  String get minorAccountReviewCheckingStatusBody =>
      'Sila tunggu sementara kami mengesahkan status semakan semasa akaun ini.';

  @override
  String get minorAccountReviewDefaultTitle => 'Semakan akaun diperlukan';

  @override
  String get minorAccountReviewDefaultBody =>
      'Kami perlu menyemak akaun ini sebelum ia boleh menggunakan Divine seperti biasa.';

  @override
  String minorAccountReviewCaseId(String caseId) {
    return 'ID Kes: $caseId';
  }

  @override
  String get minorAccountReviewCaseIdShortLabel => 'ID Kes';

  @override
  String get minorAccountReviewRestrictionsTitle =>
      'Apa yang dihadkan sekarang';

  @override
  String get minorAccountReviewRestrictionPosting =>
      'Penyiaran dan penerbitan dijeda';

  @override
  String get minorAccountReviewRestrictionEngagement =>
      'Komen, sukaan, siaran semula dan ikutan dijeda';

  @override
  String get minorAccountReviewRestrictionMessaging =>
      'Memulakan atau membalas mesej biasa dijeda';

  @override
  String get minorAccountReviewRestrictionSupport =>
      'Sokongan dan mesej kesederhanaan anda kekal tersedia';

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
  String get minorAccountReviewOpenSupportCenter => 'Buka Pusat Sokongan';

  @override
  String get minorAccountReviewOpenModerationMessage =>
      'Buka Mesej Kesederhanaan';

  @override
  String get minorAccountReviewOpenReviewPage => 'Buka halaman semakan';

  @override
  String get minorAccountReviewCheckAgain => 'Semak Semula';

  @override
  String get minorAccountReviewLogOut => 'Log keluar';

  @override
  String get minorAccountReviewNextStepTitle => 'Langkah seterusnya';

  @override
  String get minorAccountReviewNextStepBody =>
      'Buka pusat sokongan atau mesej kesederhanaan anda jika anda perlukan bantuan dengan semakan ini.';

  @override
  String get minorAccountReviewInProgressTitle => 'Semakan sedang berjalan';

  @override
  String get minorAccountReviewInProgressBody =>
      'Kami mempunyai apa yang kami perlukan buat masa ini. Pasukan kami sedang menyemak kes ini sebelum memulihkan akses akaun biasa.';

  @override
  String get minorAccountReviewUnder13Title => 'Akaun bawah 13 tahun';

  @override
  String minorAccountReviewUnder13Body(String supportEmail) {
    return 'Jika akaun ini milik seseorang yang berumur bawah 13 tahun, ibu bapa atau penjaga mestilah menghantar e-mel ke $supportEmail dan menyertakan ID kes.';
  }

  @override
  String get minorAccountReviewUnder13PublicTitle =>
      'Kami belum dapat memberi anda akaun';

  @override
  String get minorAccountReviewUnder13PublicBody =>
      'Divine tidak dibina untuk kanak-kanak bawah 13 tahun dan peraturan media sosial di seluruh dunia mengikat tangan kami.\n\nBanyak perkara di internet mendorong anda untuk berbohong untuk mendapatkan apa yang anda mahu, dan kami membencinya. Itu pengajaran yang salah untuk kehidupan, dan kami tidak akan mengajarnya kepada anda di sini.';

  @override
  String get minorAccountReviewUnder13FamilyTitle =>
      'Apa yang keluarga anda boleh lakukan sebaliknya';

  @override
  String get minorAccountReviewUnder13FamilyBody =>
      'Ibu bapa atau penjaga boleh memegang akaun dan membuat penyiaran, dan anda semestinya boleh berada dalam video bersama mereka. Kami mahu keluarga menikmati Divine dengan cara apa pun yang sesuai untuk mereka.';

  @override
  String get minorAccountReviewUnder13ComeBackTitle =>
      'Apabila anda berusia 13 tahun';

  @override
  String get minorAccountReviewUnder13ComeBackBody =>
      'Bergantung pada peraturan di tempat anda tinggal, anda mungkin boleh kembali dan memohon akaun anda sendiri. Dalam kes itu, jika anda berumur antara 13 dan 15 tahun, anda memerlukan kebenaran daripada ibu bapa atau penjaga.';

  @override
  String get minorAccountReviewUnder13HonestyTitle =>
      'Kenapa kami tidak akan menyuruh anda kembali sahaja';

  @override
  String get minorAccountReviewUnder13HonestyBody =>
      'Kebanyakan internet disusun untuk memberi ganjaran kepada orang yang mengatakan apa sahaja yang membolehkan mereka masuk. Kami tidak fikir itu bagus. Ya, anda boleh kembali dan mengatakan anda lebih tua daripada umur anda, tetapi itu bukan jujur, dan kami tidak akan melatih anda untuk berbohong untuk mendapatkan apa yang anda mahu.';

  @override
  String get minorAccountReviewUnder13LegalBody =>
      'Kami cuba membantu golongan muda menggunakan Divine dengan cara yang sihat dan positif untuk mereka dan orang di sekeliling mereka. Kami juga perlu mematuhi undang-undang yang berbeza di tempat yang berbeza. Jadi, jika anda bawah 13 tahun, jawapannya ialah anda tidak boleh mempunyai akaun sendiri hari ini.';

  @override
  String get minorAccountReviewTeenBody =>
      'Jika akaun ini milik seseorang yang berumur 13 hingga 15 tahun, gunakan mesej kesederhanaan atau laluan sokongan untuk mengikut arahan kebenaran ibu bapa.';

  @override
  String get minorAccountReviewParentConsentTitle =>
      'Jika akaun akan menjadi milik seseorang yang berumur 13 hingga 15 tahun';

  @override
  String get minorAccountReviewParentConsentBody =>
      'Ibu bapa atau penjaga perlu menghantar e-mel kepada sokongan Divine dengan video peribadi yang ringkas. Pasukan kami akan menyemaknya dan membantu dengan langkah seterusnya.\n\nJika hubungan ibu bapa atau penjaga tidak mungkin atau akan membahayakan seseorang, hantar e-mel kepada sokongan Divine dan beritahu kami.';

  @override
  String get minorAccountReviewParentConsentPauseNote =>
      'Ini adalah jeda sementara pasukan sokongan Divine menyemak video itu. Jika ia diluluskan, mereka akan membimbing anda menyediakan akaun baharu.';

  @override
  String get minorAccountReviewParentConsentHonestyTitle =>
      'Kenapa kami meminta ibu bapa atau penjaga terlibat';

  @override
  String get minorAccountReviewParentConsentHonestyBody =>
      'Divine perlu mematuhi undang-undang berkaitan umur di seluruh dunia. Kami juga tahu bahawa kebanyakan pintu umur teknikal tidak sempurna. Daripada berpura-pura peraturan itu tidak wujud atau bahawa berbohong tentang umur anda itu keren, kami mahu remaja dan keluarga membuat keputusan yang bernas tentang cara terbaik menggunakan Divine. Itulah sebabnya, untuk remaja berumur 13-15 tahun, kami meminta ibu bapa menjadi sebahagian daripada proses penciptaan akaun.';

  @override
  String get minorAccountReviewParentConsentLegalBody =>
      'Kami juga perlu mematuhi undang-undang, dan peraturan itu berbeza bergantung pada tempat seseorang tinggal. Jadi, daripada berpura-pura peraturan itu tidak wujud, kami meminta ibu bapa atau penjaga menjadi sebahagian daripada proses itu.';

  @override
  String get minorAccountReviewParentConsentChecklist =>
      'Apa yang video itu patut tunjukkan';

  @override
  String get minorAccountReviewParentConsentChecklistKid =>
      'Remaja itu dalam video';

  @override
  String get minorAccountReviewParentConsentChecklistPermission =>
      'Ibu bapa atau penjaga bercakap di depan kamera';

  @override
  String get minorAccountReviewParentConsentChecklistAgeBand =>
      'Pernyataan jelas bahawa remaja itu berumur 13 hingga 15 tahun dan mempunyai kebenaran untuk menggunakan Divine';

  @override
  String get minorAccountReviewParentConsentChecklistSupervision =>
      'Pernyataan jelas bahawa ibu bapa atau penjaga mengetahui tentang akaun itu dan akan mengawasi penggunaannya';

  @override
  String get minorAccountReviewParentConsentPrivacy => 'Cara menghantarnya';

  @override
  String get minorAccountReviewParentConsentNeverPost =>
      'Lampirkan video apabila anda menghantar e-mel kepada sokongan Divine';

  @override
  String get minorAccountReviewParentConsentDoNotSave =>
      'Pastikan video itu peribadi dan jangan siarkannya dalam apl';

  @override
  String get minorAccountReviewParentConsentOneMove =>
      'Pasukan kami akan menyemaknya dan membalas dengan langkah seterusnya';

  @override
  String get minorAccountReviewParentConsentEmailCta => 'E-mel sokongan Divine';

  @override
  String get minorAccountReviewParentConsentEmailSubject =>
      'Bantuan semakan Divine Greenlight (umur 13-15)';

  @override
  String get minorAccountReviewParentConsentEmailBody =>
      'Hai sokongan Divine,\n\nSaya menghubungi Divine tentang Divine Greenlight untuk remaja berumur 13-15 tahun.\n\nSaya telah melampirkan video peribadi ringkas yang menunjukkan:\n- remaja itu\n- ibu bapa atau penjaga bercakap di depan kamera\n- bahawa remaja itu mempunyai kebenaran untuk menggunakan Divine\n- bahawa ibu bapa atau penjaga mengetahui tentang akaun itu dan akan mengawasi penggunaannya\n\nNegara tempat tinggal:\n\nKonteks berguna:\n\nTerima kasih.';

  @override
  String get minorAccountReviewParentSupportInstructions =>
      'Arahan Sokongan Ibu Bapa';

  @override
  String get minorAccountReviewContinue => 'Teruskan';

  @override
  String get minorAccountReviewErrorTitle =>
      'Kami tidak dapat memuatkan status semakan akaun anda.';

  @override
  String get minorAccountReviewErrorBody => 'Sila cuba lagi sebentar nanti.';

  @override
  String get minorAccountReviewTryAgain => 'Cuba Lagi';

  @override
  String get minorAccountReviewParentContactTitle => 'Hubungan Ibu Bapa';

  @override
  String get minorAccountReviewParentContactHeading =>
      'Tambah e-mel ibu bapa atau penjaga';

  @override
  String minorAccountReviewParentContactBody(String caseId) {
    return 'Kami akan menggunakan alamat ini untuk semakan kebenaran ibu bapa bagi kes $caseId.';
  }

  @override
  String get minorAccountReviewParentContactFieldLabel =>
      'E-mel ibu bapa atau penjaga';

  @override
  String get minorAccountReviewSubmitting => 'Menghantar...';

  @override
  String get minorAccountReviewSubmitEmail => 'Hantar E-mel';

  @override
  String get minorAccountReviewBackToReview => 'Kembali ke Semakan Akaun';

  @override
  String get minorAccountReviewSubmissionReceivedTitle => 'E-mel dihantar';

  @override
  String minorAccountReviewSubmissionReceivedBody(String email) {
    return 'Kami telah menghantar $email untuk disemak. Kami akan menghantar e-mel ke alamat ini untuk mengesahkan. Sebaik sahaja ibu bapa atau penjaga anda membalas, kes anda akan bergerak ke hadapan. Guna Semak Semula daripada skrin semakan akaun untuk kemas kini.';
  }

  @override
  String get minorAccountReviewSubmissionReceivedLocalBody =>
      'Kami telah menerima hubungan ibu bapa atau penjaga untuk akaun ini. Pasukan kami akan menyemaknya sebelum memulihkan akses.';

  @override
  String get minorAccountReviewMissingCase =>
      'Kami tidak dapat menemui kes semakan aktif untuk akaun ini.';

  @override
  String get minorAccountReviewParentContactError =>
      'Tidak dapat menghantar e-mel ibu bapa. Sila cuba lagi.';

  @override
  String get minorAccountReviewUnder13SupportTitle => 'Sokongan Ibu Bapa';

  @override
  String get minorAccountReviewUnder13Heading =>
      'Ibu bapa atau penjaga mestilah menghubungi Divine';

  @override
  String get minorAccountReviewUnder13SupportBody =>
      'Untuk akaun yang mungkin bawah 13 tahun, langkah seterusnya ialah hubungan ibu bapa atau penjaga melalui e-mel.';

  @override
  String get minorAccountReviewSupportEmailLabel => 'E-mel sokongan';

  @override
  String get minorAccountReviewCopySupportEmail => 'Salin e-mel sokongan';

  @override
  String get minorAccountReviewSupportEmailCopied => 'E-mel sokongan disalin';

  @override
  String get minorAccountReviewCopyCaseId => 'Salin ID kes';

  @override
  String get minorAccountReviewCaseIdCopied => 'ID kes disalin';

  @override
  String get minorAccountReviewUnavailable => 'Tidak tersedia';

  @override
  String get minorAccountReviewUnder13Instructions =>
      'Minta ibu bapa atau penjaga menyertakan ID kes dan menerangkan bahawa mereka menghubungi Divine tentang semakan akaun ini.';

  @override
  String minorAccountReviewUnder13EmailSubject(String caseId) {
    return 'Semakan akaun bawah 13 tahun untuk kes $caseId';
  }

  @override
  String minorAccountReviewUnder13EmailBody(String caseId) {
    return 'Hai sokongan Divine,\n\nSaya ialah ibu bapa atau penjaga untuk kanak-kanak bawah 13 tahun dan saya menghubungi Divine tentang kes semakan akaun $caseId.\n\nTerima kasih.';
  }

  @override
  String get devOptionsMinorReviewSimulationTitle =>
      'Simulasi Semakan Akaun Bawah Umur';

  @override
  String get devOptionsMinorReviewCurrentStateLabel => 'Keadaan semasa';

  @override
  String devOptionsMinorReviewStateRestricted(String state) {
    return 'Terhad ($state)';
  }

  @override
  String get devOptionsMinorReviewStateActive => 'Aktif';

  @override
  String get devOptionsMinorReviewStateLoading => 'Memuatkan...';

  @override
  String get devOptionsMinorReviewStateError => 'Ralat memuatkan keadaan';

  @override
  String get devOptionsMinorReviewClearTitle =>
      'Kosongkan penggantian simulasi';

  @override
  String get devOptionsMinorReviewClearSubtitle =>
      'Guna backend atau keadaan aktif lalai semula';

  @override
  String get devOptionsMinorReviewTeenTitle => 'Simulasikan kes semakan 13-15';

  @override
  String get devOptionsMinorReviewTeenSubtitle =>
      'Akaun terhad dengan laluan hubungan ibu bapa';

  @override
  String get devOptionsMinorReviewUnder13Title =>
      'Simulasikan kes sokongan bawah 13';

  @override
  String get devOptionsMinorReviewUnder13Subtitle =>
      'Akaun terhad dengan arahan e-mel ibu bapa sahaja';

  @override
  String get devOptionsMinorReviewClearedToast =>
      'Simulasi semakan akaun bawah umur dikosongkan';

  @override
  String get devOptionsMinorReviewUnder13EnabledToast =>
      'Kes sokongan bawah 13 simulasi didayakan';

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
      'Simulasi Bawah Umur Dilindungi';

  @override
  String get devOptionsProtectedMinorCurrentStateLabel => 'Keadaan semasa';

  @override
  String get devOptionsProtectedMinorStateProtected =>
      'Bawah umur dilindungi (13-15)';

  @override
  String get devOptionsProtectedMinorStateNotProtected => 'Tidak dilindungi';

  @override
  String get devOptionsProtectedMinorStateLoading => 'Memuatkan…';

  @override
  String get devOptionsProtectedMinorStateError => 'Ralat membaca keadaan';

  @override
  String get devOptionsProtectedMinorOverrideNone =>
      'Tiada penggantian (keadaan akaun sebenar)';

  @override
  String get devOptionsProtectedMinorOverrideProtected =>
      'Penggantian: paksa dilindungi';

  @override
  String get devOptionsProtectedMinorOverrideNotProtected =>
      'Penggantian: paksa tidak dilindungi';

  @override
  String get devOptionsProtectedMinorSimulateTitle =>
      'Simulasikan bawah umur dilindungi (13-15)';

  @override
  String get devOptionsProtectedMinorSimulateSubtitle =>
      'Paksa keadaan bawah umur dilindungi untuk QA perlindungan #175/#176';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorTitle =>
      'Simulasikan bukan bawah umur';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorSubtitle =>
      'Paksa tidak dilindungi (negatif eksplisit, berbeza daripada tiada penggantian)';

  @override
  String get devOptionsProtectedMinorClearTitle => 'Kosongkan penggantian';

  @override
  String get devOptionsProtectedMinorClearSubtitle =>
      'Kembali ke keadaan akaun sebenar dipacu Keycast';

  @override
  String get devOptionsProtectedMinorEnabledToast =>
      'Keadaan bawah umur dilindungi dipaksa hidup';

  @override
  String get devOptionsProtectedMinorNonMinorToast =>
      'Keadaan bawah umur dilindungi dipaksa mati';

  @override
  String get devOptionsProtectedMinorClearedToast =>
      'Penggantian bawah umur dilindungi dikosongkan';

  @override
  String get devOptionsInviteAvailabilityTitle => 'Jemputan pendaftaran';

  @override
  String get devOptionsInviteAvailabilityCurrentLabel => 'Keadaan semasa';

  @override
  String get devOptionsInviteAvailabilityServerLoading =>
      'Nilai pelayan: sedang dimuatkan';

  @override
  String get devOptionsInviteAvailabilityServerEnabled =>
      'Nilai pelayan: dihidupkan';

  @override
  String get devOptionsInviteAvailabilityServerDisabled =>
      'Nilai pelayan: dimatikan';

  @override
  String get devOptionsInviteAvailabilityServerUnknown =>
      'Nilai pelayan: tidak diketahui';

  @override
  String get devOptionsInviteAvailabilityOverrideNone =>
      'Tulis ganti: guna nilai pelayan';

  @override
  String get devOptionsInviteAvailabilityOverrideEnabled =>
      'Tulis ganti: paksa hidup';

  @override
  String get devOptionsInviteAvailabilityOverrideDisabled =>
      'Tulis ganti: paksa mati';

  @override
  String get devOptionsInviteAvailabilityUseServer => 'Guna nilai pelayan';

  @override
  String get devOptionsInviteAvailabilityUseServerSubtitle =>
      'Ikut onboardingMode perkhidmatan jemputan';

  @override
  String get devOptionsInviteAvailabilityForceEnabled => 'Paksa hidup';

  @override
  String get devOptionsInviteAvailabilityForceEnabledSubtitle =>
      'Tunjukkan get jemputan pendaftaran dan pengurusannya secara setempat';

  @override
  String get devOptionsInviteAvailabilityForceDisabled => 'Paksa mati';

  @override
  String get devOptionsInviteAvailabilityForceDisabledSubtitle =>
      'Sembunyikan UI jemputan pendaftaran secara setempat tanpa mengubah pelayan';

  @override
  String get devOptionsInviteAvailabilityUseServerToast =>
      'Jemputan pendaftaran kini mengikut pelayan';

  @override
  String get devOptionsInviteAvailabilityForceEnabledToast =>
      'Jemputan pendaftaran dipaksa hidup';

  @override
  String get devOptionsInviteAvailabilityForceDisabledToast =>
      'Jemputan pendaftaran dipaksa mati';

  @override
  String get commentsRecordVideoButtonLabel => 'Rakam komen video';

  @override
  String get commentsOpenVideoLabel => 'Buka komen video';

  @override
  String get commentsMuteVideoReplyLabel => 'Senyapkan balasan video';

  @override
  String get commentsUnmuteVideoReplyLabel => 'Nyahsenyap balasan video';

  @override
  String get commentsOpenReplyParentLabel => 'Buka video yang dibalas ini';

  @override
  String get commentsReplyParentSectionTitle => 'Membalas kepada';

  @override
  String commentsReplyParentLabel(String target) {
    return 'Balas kepada $target';
  }

  @override
  String get commentsReplyParentFallbackLabel => 'Balas kepada video';

  @override
  String verifiedAccountChipSemanticLabel(String platform, String identity) {
    return 'Akaun $platform disahkan: $identity';
  }

  @override
  String get profileEditVerifiedAccountsTitle => 'Akaun disahkan';

  @override
  String get profileEditGetVerifiedCta => 'Dapatkan pengesahan';

  @override
  String get profileEditGetVerifiedSubtitle =>
      'Pautkan akaun media sosial anda supaya orang tahu itu benar-benar anda.';

  @override
  String profileWebsiteSemanticLabel(String url) {
    return 'Lawati laman web: $url';
  }

  @override
  String get profileCouldNotOpenWebsite => 'Tidak dapat membuka laman web';

  @override
  String get videoMetadataEditCoverTitle => 'Sunting muka depan';

  @override
  String get videoMetadataEditCoverCloseSemanticLabel =>
      'Buang perubahan muka depan';

  @override
  String get videoMetadataEditCoverConfirmSemanticLabel =>
      'Gunakan bingkai dipilih sebagai muka depan video';

  @override
  String get videoMetadataEditCoverStripSemanticLabel =>
      'Gerak melalui video untuk memilih bingkai muka depan';

  @override
  String get videoMetadataTagsPickerSearchHint => 'Cari atau tambah tag';

  @override
  String get videoMetadataTagsPickerEmptyHint =>
      'Tambah tag untuk membantu orang menemui video anda';

  @override
  String get videoMetadataTagsPickerNoResults => 'Tiada tag sepadan';

  @override
  String videoMetadataTagsPickerAddTag(String tag) {
    return 'Tambah \"#$tag\"';
  }

  @override
  String get authMinAgeNotice => 'Divine Greenlight';

  @override
  String get authUnder16Prefix => 'Belum 16? Tidak mengapa. ';

  @override
  String get authUnder16ChoicesCta => 'Ini pilihan anda.';

  @override
  String get minorAccountReviewUnder13WhyTitle => 'Ini sebabnya';

  @override
  String get generalSettingsHoldToRecord => 'Tahan untuk merakam';

  @override
  String get generalSettingsHoldToRecordSubtitle =>
      'Mula merakam apabila anda tekan dan tahan, kemudian berhenti apabila anda lepaskan';

  @override
  String uploadPublishedCountMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count video diterbitkan ke profil anda',
      one: 'Video diterbitkan ke profil anda',
    );
    return '$_temp0';
  }

  @override
  String get dmMessageSendLabel => 'Hantar mesej';

  @override
  String get emojiPickerSearchHint => 'Cari';

  @override
  String get emojiCategoryRecent => 'Terkini';

  @override
  String get emojiCategorySmileys => 'Smiley & Orang';

  @override
  String get emojiCategoryAnimals => 'Haiwan & Alam';

  @override
  String get emojiCategoryFood => 'Makanan & Minuman';

  @override
  String get emojiCategoryActivities => 'Aktiviti';

  @override
  String get emojiCategoryTravel => 'Pelancongan & Tempat';

  @override
  String get emojiCategoryObjects => 'Objek';

  @override
  String get emojiCategorySymbols => 'Simbol';

  @override
  String get emojiCategoryFlags => 'Bendera';

  @override
  String get videoEditorMarkerLabel => 'Penanda';

  @override
  String get videoEditorAddTimelineMarkerSemanticLabel =>
      'Tambah penanda garis masa';

  @override
  String get videoEditorRemoveTimelineMarkerSemanticLabel =>
      'Alih keluar penanda garis masa';

  @override
  String get videoEditorRemoveTimelineMarkerAtPlayheadSemanticLabel =>
      'Alih keluar penanda pada kepala main';

  @override
  String get videoEditorDeleteTimelineMarkerTitle => 'Padam penanda?';

  @override
  String get videoEditorDeleteTimelineMarkerSubtitle =>
      'Ini mengalih keluar penanda daripada garis masa. Suntingan anda kekal utuh.';

  @override
  String get videoEditorVolumeLongPressHint =>
      'Senyapkan atau nyahsenyap semua trek';

  @override
  String get videoEditorSplitFailed => 'Pemisahan gagal. Sila cuba lagi.';

  @override
  String get videoEditEditSubtitles => 'Sunting sarikata';

  @override
  String get subtitleEditorTitle => 'Sunting sarikata';

  @override
  String get subtitleEditorSave => 'Simpan';

  @override
  String get subtitleEditorProcessing =>
      'Sarikata masih sedang dijana. Semak semula sebentar nanti.';

  @override
  String get subtitleEditorNoSpeech =>
      'Tiada pertuturan dikesan dalam video ini, jadi tiada apa-apa untuk disarikatakan.';

  @override
  String get subtitleEditorWriteOwn => 'Tulis sendiri';

  @override
  String get subtitleEditorAddCue => 'Tambah baris';

  @override
  String get subtitleEditorRemoveCue => 'Buang baris ini';

  @override
  String get subtitleEditorPreviewUnavailable =>
      'Video tidak dapat dimainkan sekarang, tetapi anda masih boleh membetulkan kapsyen.';

  @override
  String get subtitleEditorPlayPreview => 'Main video';

  @override
  String get subtitleEditorPausePreview => 'Jeda video';

  @override
  String get subtitleEditorInvalidHint =>
      'Setiap baris perlukan teks dan masa tamat selepas masa mula.';

  @override
  String get subtitleEditorLoadError =>
      'Tidak dapat memuatkan sarikata. Cuba lagi.';

  @override
  String get subtitleEditorSaveSuccess => 'Sarikata dikemas kini';

  @override
  String get subtitleEditorSaveError =>
      'Tidak dapat menyimpan sarikata. Cuba lagi.';

  @override
  String get subtitleEditorRetry => 'Cuba Semula';

  @override
  String get subtitleEditorCueHint => 'Teks sarikata';

  @override
  String get imageCropEditorRotateLabel => 'Putar';

  @override
  String get imageCropEditorFlipLabel => 'Terbalikkan';

  @override
  String get imageCropEditorResetLabel => 'Tetapkan semula';

  @override
  String get imageCropEditorCloseSemanticLabel => 'Batalkan pangkasan';

  @override
  String get imageCropEditorDoneSemanticLabel => 'Gunakan pangkasan';

  @override
  String get imageCropEditorProcessing => 'Menggunakan pangkasan…';

  @override
  String get backgroundUploadNotificationTitle => 'Memuat naik video';

  @override
  String get monetizationSettingsTitle => 'Sokongan Pencipta';

  @override
  String get monetizationSettingsSubtitle => 'Tambah pautan tip dan langganan';

  @override
  String get monetizationSettingsIntroTitle => 'Pautan keluar sahaja';

  @override
  String get monetizationSettingsIntroBody =>
      'Tambah destinasi yang dikawal pencipta. Divine tidak pernah mengendalikan pembayaran atau membuka kandungan dalam apl daripada pautan ini.';

  @override
  String monetizationSettingsConfiguredCount(int count) {
    return '$count pautan aktif pada profil anda';
  }

  @override
  String get monetizationSettingsTipSection => 'Hantar tip';

  @override
  String get monetizationSettingsSubscriptionSection => 'Langgan / sokong';

  @override
  String get monetizationSettingsSave => 'Simpan pautan sokongan';

  @override
  String get monetizationSettingsSaving => 'Menyimpan...';

  @override
  String get monetizationSettingsSaved => 'Pautan sokongan dikemas kini';

  @override
  String get monetizationSettingsSaveFailed =>
      'Tidak dapat menyimpan pautan sokongan. Semak sambungan anda dan cuba lagi.';

  @override
  String get monetizationSettingsErrorEmpty => 'Tambah handle atau URL.';

  @override
  String get monetizationSettingsErrorInvalid =>
      'Pautan itu tidak kelihatan betul.';

  @override
  String get monetizationSettingsErrorWrongProvider =>
      'Guna pautan untuk penyedia ini.';

  @override
  String get monetizationSettingsHintCashApp =>
      '\$cashtag atau pautan cash.app';

  @override
  String get monetizationSettingsHintPayPal => 'Handle PayPal.me atau pautan';

  @override
  String get monetizationSettingsHintVenmo => 'Handle Venmo atau pautan';

  @override
  String get monetizationSettingsHintPatreon => 'Handle Patreon atau pautan';

  @override
  String get monetizationSettingsHintSubstack => 'Domain Substack atau pautan';

  @override
  String get monetizationSettingsHintMedium => 'Handle Medium atau pautan';

  @override
  String get monetizationSettingsHintOpenCollective =>
      'Slug Open Collective atau pautan';

  @override
  String get profileSupportSheetTitle => 'Sokong pencipta ini';

  @override
  String get profileSupportSheetBody =>
      'Pautan ini dibuka di luar Divine. Tiada apa di sini yang membuka kandungan dalam apl.';

  @override
  String get profileSupportTipSection => 'Hantar tip';

  @override
  String get profileSupportSubscriptionSection => 'Langgan / sokong';

  @override
  String get profileSupportButtonLabel => 'Sokong';

  @override
  String get monetizationTipsSettingsTitle => 'Tip';

  @override
  String get monetizationTipsSettingsSubtitle => 'Tambah pautan tip pilihan';

  @override
  String get monetizationTipsSettingsIntroTitle => 'Tip pilihan sahaja';

  @override
  String get monetizationTipsSettingsIntroBody =>
      'Tip ialah hadiah pilihan pengguna-kepada-pengguna. Ia tidak membuka kandungan, langganan, ciri, kedudukan, penglihatan atau akses dalam Divine.';

  @override
  String monetizationTipsSettingsConfiguredCount(int count) {
    return '$count pautan tip aktif pada profil anda';
  }

  @override
  String get monetizationTipsSettingsSave => 'Simpan pautan tip';

  @override
  String get monetizationTipsSettingsSaved => 'Pautan tip dikemas kini';

  @override
  String get profileTipButtonLabel => 'Tip';

  @override
  String get profileTipSheetTitle => 'Tip pencipta ini';

  @override
  String get profileTipSheetBody =>
      'Tip dibuka di luar Divine. Ia adalah pilihan dan tidak membuka kandungan, langganan, ciri atau akses dalam Divine.';

  @override
  String get settingsStorageTitle => 'Storan';

  @override
  String get settingsStorageCacheSectionTitle => 'Media cache';

  @override
  String get settingsStorageCacheDescription =>
      'Video suapan cache, lakaran kecil dan render sementara. Mengosongkannya adalah selamat — ia dimuat turun semula atau dijana semula apabila diperlukan.';

  @override
  String get settingsStorageMeasuring => 'Mengukur…';

  @override
  String settingsStorageCacheInUse(String size) {
    return '$size digunakan';
  }

  @override
  String get settingsStorageClearButton => 'Kosongkan cache';

  @override
  String get settingsStorageClearConfirmTitle => 'Kosongkan media cache?';

  @override
  String settingsStorageClearConfirmMessage(String size) {
    return 'Ini mengosongkan $size. Pustaka klip anda tidak terjejas.';
  }

  @override
  String get settingsStorageClearConfirmAction => 'Kosongkan';

  @override
  String get settingsStorageCleared => 'Cache dikosongkan';

  @override
  String get settingsStorageLibrarySectionTitle => 'Pustaka klip';

  @override
  String get settingsStorageLibraryDescription =>
      'Semak klip rosak yang fail videonya hilang.';

  @override
  String get settingsStorageScanButton => 'Semak pustaka';

  @override
  String get settingsStorageLibraryHealthy => 'Tiada klip rosak ditemui';

  @override
  String settingsStorageBrokenClipsFound(int count) {
    return 'Klip rosak ditemui: $count';
  }

  @override
  String get settingsStorageRemoveBrokenButton => 'Alih keluar klip rosak';

  @override
  String get settingsStorageBrokenClipsRemoved => 'Klip rosak dialih keluar';

  @override
  String get settingsStorageError => 'Sesuatu telah berlaku';

  @override
  String get settingsStorageMaxVideoCacheLabel => 'Cache video maksimum';

  @override
  String settingsStorageApproxVideos(int count) {
    return '≈ $count video';
  }

  @override
  String get settingsStorageRemoveBrokenConfirmTitle =>
      'Alih keluar klip rosak?';

  @override
  String get settingsStorageRepairSectionTitle => 'Baiki pemasangan';

  @override
  String get settingsStorageRepairDescription =>
      'Kalau apl kerap crash atau berkelakuan pelik, set semula data setempat biasanya membantu. Klip dan draf anda kekal.';

  @override
  String get settingsStorageRepairButton => 'Set semula data apl';

  @override
  String get settingsStorageRepairConfirmTitle => 'Set semula data apl?';

  @override
  String get settingsStorageRepairConfirmMessage =>
      'Ini memadamkan data suapan dalam cache dan fail sementara. Klip, draf, tetapan dan log masuk anda kekal, tetapi anda perlu mulakan semula apl selepas itu.';

  @override
  String settingsStorageRepairFootprint(String size) {
    return '$size akan dipadam';
  }

  @override
  String get settingsStorageRepairConfirmAction => 'Set semula';

  @override
  String get settingsStorageRepairInProgress => 'Menetapkan semula…';

  @override
  String get settingsStorageRepairSuccess =>
      'Siap — mulakan semula apl untuk selesai.';

  @override
  String get settingsStorageRepairFailure =>
      'Tidak semua dapat diset semula. Cuba lagi selepas mulakan semula.';

  @override
  String get nostrSettingsSignatureVerification => 'Pengesahan tandatangan';

  @override
  String get nostrSettingsSignatureVerificationIntro =>
      'Pilih bila Divine menyemak tandatangan acara relay. ID acara sentiasa disahkan dahulu.';

  @override
  String get nostrSettingsSignatureVerificationAll => 'Semua relay';

  @override
  String get nostrSettingsSignatureVerificationAllSubtitle =>
      'Paling selamat. Sahkan setiap tandatangan acara relay.';

  @override
  String get nostrSettingsSignatureVerificationUntrusted =>
      'Relay tidak dipercayai';

  @override
  String get nostrSettingsSignatureVerificationUntrustedSubtitle =>
      'Langkau semakan untuk relay yang sudah berada dalam kumpulan terkonfigurasi anda.';

  @override
  String get nostrSettingsSignatureVerificationNonDivine =>
      'Relay bukan Divine';

  @override
  String get nostrSettingsSignatureVerificationNonDivineSubtitle =>
      'Percayai relay Divine, sahkan yang lain.';

  @override
  String get settingsCrosspostingTitle => 'Siaran silang';

  @override
  String get settingsCrosspostingSubtitle =>
      'Kongsi video anda ke platform lain';

  @override
  String get crosspostingSignInRequired =>
      'Log masuk dengan Divine untuk mengurus siaran silang';

  @override
  String get crosspostingLoadFailed =>
      'Tetapan siaran silang anda tidak dapat dimuatkan';

  @override
  String get crosspostingNoPlatforms =>
      'Tiada platform siaran silang tersedia buat masa ini';

  @override
  String get crosspostingRetry => 'Cuba Semula';

  @override
  String get crosspostingNotConnected => 'Tidak bersambung';

  @override
  String get crosspostingConnected => 'Bersambung';

  @override
  String get crosspostingNeedsReconnect => 'Perlu disambung semula';

  @override
  String get crosspostingConnect => 'Sambung';

  @override
  String get crosspostingReconnect => 'Sambung semula';

  @override
  String get crosspostingDisconnect => 'Putuskan sambungan';

  @override
  String get crosspostingModeOff => 'Mati';

  @override
  String get crosspostingModeManual => 'Manual';

  @override
  String get crosspostingModeManualSubtitle => 'Anda pilih untuk setiap video';

  @override
  String get crosspostingModeAutomatic => 'Automatik';

  @override
  String get crosspostingModeAutomaticSubtitle =>
      'Video akan datang disiarkan secara automatik — hanya video yang anda terbitkan selepas menghidupkan ini';

  @override
  String get crosspostingNotConnectedError =>
      'Sambungkan platform ini dahulu untuk menukar cara ia menyiarkan.';

  @override
  String get crosspostingGenericError =>
      'Ada sesuatu yang tidak kena. Cuba lagi.';

  @override
  String get crosspostingCallbackTimeoutError =>
      'Halaman log masuk tidak pernah membalas. Jika anda sudah selesai menyambung di sana, muat semula — akaun anda mungkin sudah dipautkan.';

  @override
  String crosspostingConnectionSuccess(String platform) {
    return '$platform disambungkan';
  }

  @override
  String crosspostingConnectionFailed(String platform) {
    return 'Tidak dapat menyambungkan $platform';
  }

  @override
  String crosspostingConnectionDenied(String platform) {
    return 'Sambungan dibatalkan pada $platform';
  }

  @override
  String get supporterTitle => 'Penyokong Divine';

  @override
  String get supporterTileSubtitle =>
      'Sokong Divine dengan langganan bulanan pilihan.';

  @override
  String get supporterHeroTitle => 'Pastikan Divine terus berjalan';

  @override
  String get supporterHeroBody =>
      'Divine adalah percuma dan akan sentiasa percuma. Jika anda mahu membantu kami memastikan loop terus berjalan, jadilah penyokong bulanan. Tiada apa yang dikunci — ia hanya memastikan lampu terus menyala dan mendapatkan penghargaan kami.';

  @override
  String get supporterActiveBadge =>
      'Anda ialah Penyokong Divine. Terima kasih kerana memastikan ini terus berjalan.';

  @override
  String get supporterPurchasePending =>
      'Pembelian anda sedang menunggu kelulusan.';

  @override
  String get supporterPurchaseConfirming => 'Mengesahkan sokongan anda…';

  @override
  String get supporterStoreChecking => 'Menyemak kedai…';

  @override
  String get supporterUnavailable =>
      'Langganan penyokong tidak tersedia di sini sekarang.';

  @override
  String get supporterRestorePurchases => 'Pulihkan pembelian';

  @override
  String get supporterDismissError => 'Ketepikan ralat';

  @override
  String get supporterErrorStoreUnavailable =>
      'Kedai tidak tersedia pada peranti ini.';

  @override
  String get supporterErrorPurchaseFailed =>
      'Pembelian tidak selesai. Anda tidak dikenakan bayaran.';

  @override
  String get supporterErrorPurchasePending =>
      'Pembelian anda sedang menunggu kelulusan.';

  @override
  String get supporterErrorRestoreFailed =>
      'Tiada langganan penyokong ditemui untuk dipulihkan.';

  @override
  String get supporterErrorOwnershipConflict =>
      'Pembelian ini dimiliki oleh akaun Divine lain.';

  @override
  String get supporterErrorVerificationUnavailable =>
      'Divine tidak dapat mengesahkan status penyokong sekarang.';

  @override
  String get supporterErrorUnknown => 'Sesuatu telah berlaku. Sila cuba lagi.';

  @override
  String get supporterDisclaimer =>
      'Divine mengesahkan status penyokong selepas kedai mengesahkan pembelian anda. Pengiktirafan adalah pilihan, dan halo itu bukan pengesahan.';

  @override
  String get profileNotifyBellOff => 'Beritahu saya tentang vine baharu';

  @override
  String get profileNotifyBellOn =>
      'Berhenti beritahu saya tentang vine baharu';

  @override
  String get profileNotifyUpdateFailed => 'Tidak dapat disimpan. Cuba lagi?';

  @override
  String get savedSoundYourLabel => 'Label anda';

  @override
  String get savedSoundAddHashtags => 'Tambah hashtag';

  @override
  String get savedSoundDeviceOnly => 'Disimpan pada peranti ini';

  @override
  String get savedSoundDetailsRetry =>
      'Butiran itu tidak dapat disimpan. Ketik untuk cuba lagi.';

  @override
  String get savedSoundFallbackTitle => 'Bunyi tersimpan';

  @override
  String get savedSoundPreviewAction => 'Dengar bunyi';

  @override
  String get savedSoundEditAction => 'Sunting butiran bunyi';

  @override
  String get savedSoundRemoveAction => 'Buang bunyi tersimpan';

  @override
  String get savedSoundClearHashtagFilter => 'Kosongkan penapis hashtag';

  @override
  String get soundAllowRemix => 'Benarkan orang lain me-remix bunyi ini';

  @override
  String get soundReuseUnavailable =>
      'Bunyi ini tidak boleh di-remix sekarang.';

  @override
  String get soundPublicCredit => 'Kredit bunyi awam';

  @override
  String get soundCreditRequired =>
      'Tambah kredit bunyi awam sebelum menyiarkan.';

  @override
  String get soundSharedAs => 'Dikongsi sebagai';

  @override
  String get soundOwnWork => 'Saya yang buat bunyi ini';

  @override
  String soundCreatorBy(String creator) {
    return 'Oleh $creator';
  }

  @override
  String soundSharedBy(String publisher) {
    return 'Dikongsi oleh $publisher';
  }

  @override
  String get soundRemixingAllowed => 'Remix dibenarkan';

  @override
  String get soundCreditOnly => 'Kredit sahaja';

  @override
  String get soundCreditTitleLabel => 'Tajuk bunyi';

  @override
  String get soundCreditCreatorLabel => 'Pencipta';

  @override
  String get soundCreditSourceUrlLabel => 'URL sumber';

  @override
  String get soundCreditPublicHashtagsLabel => 'Hashtag awam';

  @override
  String get videoMetadataTagsPickerCancelSemanticLabel =>
      'Batalkan pemilihan tag';

  @override
  String get videoMetadataTagsPickerConfirmSemanticLabel =>
      'Gunakan tag yang dipilih';

  @override
  String get userPickerCancelSemanticLabel => 'Batalkan pemilihan pengguna';

  @override
  String get userPickerConfirmSemanticLabel => 'Sahkan pengguna yang dipilih';

  @override
  String get userPickerClearSelectionSemanticLabel =>
      'Kosongkan pemilihan pengguna';

  @override
  String get videoMetadataContentWarningsPickerCancelSemanticLabel =>
      'Batalkan pemilihan amaran kandungan';

  @override
  String get videoMetadataContentWarningsPickerConfirmSemanticLabel =>
      'Gunakan amaran kandungan yang dipilih';

  @override
  String get videoEditorCloseEditorSemanticLabel => 'Tutup editor video';

  @override
  String get videoEditorContinueToPostDetailsSemanticLabel =>
      'Teruskan ke butiran siaran';

  @override
  String videoEditorDiscardToolChangesSemanticLabel(String tool) {
    return 'Buang perubahan dalam $tool';
  }

  @override
  String videoEditorApplyToolChangesSemanticLabel(String tool) {
    return 'Gunakan perubahan dalam $tool';
  }

  @override
  String get videoEditorRemoveAudioSemanticLabel => 'Alih keluar audio';

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
  String get verifyTitle => 'Akaun disahkan';

  @override
  String get verifySignedOutMessage => 'Log masuk untuk memautkan akaun anda.';

  @override
  String get verifyIntro =>
      'Pautkan akaun yang anda sudah ada, supaya orang tahu ini memang anda.';

  @override
  String get verifyLoadFailed => 'Pautan anda gagal dimuatkan.';

  @override
  String get verifyRetry => 'Cuba lagi';

  @override
  String get verifyLinkedSectionTitle => 'Dipautkan';

  @override
  String get verifyVerifierUnreachable =>
      'Pengesah tidak dapat dihubungi, jadi semuanya dipaparkan belum disemak.';

  @override
  String get verifyAddSectionTitle => 'Tambah akaun';

  @override
  String get verifyAllPlatformsLinked =>
      'Anda sudah memautkan semua yang kami sokong.';

  @override
  String get verifyStatusVerified => 'Disahkan';

  @override
  String get verifyStatusUnverified => 'Belum disahkan';

  @override
  String verifyUnlinkSemanticLabel(String platform, String identity) {
    return 'Nyahpaut akaun $platform $identity';
  }

  @override
  String verifyUnlinkConfirmTitle(String platform) {
    return 'Nyahpaut $platform?';
  }

  @override
  String verifyUnlinkConfirmSubtitle(String identity) {
    return '$identity tidak akan dipaparkan lagi pada profil anda. Anda boleh memautkannya semula kemudian, tetapi anda perlu log masuk atau menyiarkan bukti baharu.';
  }

  @override
  String get verifyUnlinkConfirmCta => 'Nyahpaut';

  @override
  String verifyLinkSemanticLabel(String platform) {
    return 'Pautkan akaun $platform anda';
  }

  @override
  String get verifyOneTapBadge => 'Satu ketik';

  @override
  String verifyConnectOauthExplainer(String platform) {
    return 'Log masuk ke $platform, kami uruskan yang selebihnya. Tiada apa-apa disiarkan.';
  }

  @override
  String verifyConnectOauthCta(String platform) {
    return 'Teruskan dengan $platform';
  }

  @override
  String get verifyConnectProofTitle => 'Atau siarkan bukti';

  @override
  String get verifyConnectProofExplainer =>
      'Siarkan npub anda pada akaun anda, kemudian tampal pautan ke siaran itu.';

  @override
  String get verifyNpubLabel => 'npub anda';

  @override
  String get verifyCopyNpubSemanticLabel => 'Salin npub anda';

  @override
  String get verifyNpubCopied => 'npub disalin';

  @override
  String get verifyIdentityLabel => 'Nama akaun';

  @override
  String get verifyProofLabel => 'Pautan ke siaran anda';

  @override
  String get verifyConnectProofCta => 'Semak dan pautkan';

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
      'Pengesah tidak dapat dihubungi. Cuba lagi sebentar.';

  @override
  String get verifyErrorOauthFailed => 'Tak menjadi. Cuba sekali lagi.';

  @override
  String get verifyErrorHandleRequired => 'Masukkan handle anda dahulu.';

  @override
  String get verifyErrorPublishFailed =>
      'Disahkan, tetapi tiada geganti menerima kemas kini. Cuba lagi.';

  @override
  String get verifyErrorOauthUnavailable =>
      'Log masuk satu ketik belum disediakan untuk yang ini. Gunakan bukti di bawah.';

  @override
  String get verifyConnectProofExplainerGithub =>
      'Buat gist awam dengan npub anda dalam fail pertama, kemudian tampal pautan gist.';

  @override
  String get verifyConnectProofExplainerDiscord =>
      'Siarkan npub anda dalam saluran Discord yang boleh dibaca bot kami, kemudian tampal pautan mesej. Jemputan pelayan tidak membuktikan apa-apa.';

  @override
  String get verifyConnectProofExplainerTwitter =>
      'Tweet npub anda dari akaun itu, kemudian tampal pautan tweet.';

  @override
  String get verifyConnectProofExplainerMastodon =>
      'Siarkan npub anda dari akaun itu, kemudian tampal pautannya. Nama akaun perlu instance — mastodon.social/@alice, bukan alice sahaja.';

  @override
  String get verifyConnectProofExplainerTelegram =>
      'Yang dipautkan ialah saluran, bukan akaun Telegram anda. Saluran perlu pautan awam dahulu (Telegram jadikan yang baharu peribadi). Siarkan npub anda di sana dan tampal pautan mesej.';

  @override
  String get verifyConnectProofExplainerBluesky =>
      'Sudah log masuk di atas? Tiada apa lagi diperlukan. Jika tidak, siarkan npub anda dan tampal pautan siaran itu.';

  @override
  String get verifyConnectProofExplainerTiktok =>
      'Letak npub anda dalam kapsyen video, kemudian tampal pautan video itu.';

  @override
  String get verifyConnectProofExplainerYoutube =>
      'Letak npub anda dalam penerangan video, kemudian tampal pautan video itu.';

  @override
  String verifyLinkedConfirmation(String platform) {
    return '$platform sudah dipautkan.';
  }

  @override
  String get verifyErrorTelegramNotPublic =>
      'Itu saluran peribadi atau jemputan. Beri saluran itu pautan awam, kemudian tampal pautan mesej.';

  @override
  String get verifyErrorRemoveFailed => 'Gagal menyahpaut. Cuba lagi.';

  @override
  String get verifyErrorLinksUnreadable =>
      'Kami tidak dapat membaca pautan semasa anda, jadi tiada apa yang diubah. Semak sambungan anda dan cuba lagi.';

  @override
  String get verifyChannelLabel => 'Nama saluran';

  @override
  String get verifyHowItWorksTitle => 'Bagaimana ia berfungsi?';

  @override
  String get verifyHowItWorksIntro =>
      'Anggap ia sebagai jabat tangan antara dua akaun:';

  @override
  String get verifyHowItWorksYourSide =>
      'Profil Divine anda berkata: “Saya @alice di Twitter.”';

  @override
  String get verifyHowItWorksOtherSide =>
      'Akaun Twitter anda mengesahkan: “Ya, profil Divine itu milik saya.”';

  @override
  String get verifyHowItWorksBothSides =>
      'Kami semak kedua-dua pihak. Jika sepadan, anda disahkan. Tiada siapa boleh memalsukannya — nama dan foto boleh disalin, menyiar dari akaun sebenar anda tidak.';

  @override
  String get verifyHowItWorksOwnership =>
      'Pautan ini berada pada identiti Nostr anda sendiri, jadi anda boleh membuangnya dari sini bila-bila masa.';

  @override
  String get generalSettingsSectionIdentity => 'Identiti';

  @override
  String get libraryFilterAll => 'Semua';

  @override
  String get libraryFilterArchive => 'Arkib';

  @override
  String get libraryFilterDeleted => 'Dipadam';

  @override
  String get libraryCategoryNewChipLabel => 'Baharu';

  @override
  String get libraryCategoryCreateSemanticLabel => 'Cipta kategori';

  @override
  String get libraryCategoryCreateTitle => 'Kategori baharu';

  @override
  String get libraryCategoryCreateAction => 'Cipta';

  @override
  String get libraryCategoryRenameTitle => 'Namakan semula kategori';

  @override
  String get libraryCategoryRenameAction => 'Namakan semula';

  @override
  String get libraryCategoryDeleteAction => 'Padam kategori';

  @override
  String get libraryCategoryNameLabel => 'Nama kategori';

  @override
  String libraryCategoryDeleteConfirmTitle(String name) {
    return 'Padam “$name”?';
  }

  @override
  String get libraryCategoryDeleteConfirmMessage =>
      'Klip anda kekal. Ia cuma kembali ke Semua.';

  @override
  String get libraryCategoryManageSemanticLabel =>
      'Namakan semula atau padam kategori ini';

  @override
  String get libraryCategoryMoveTitle => 'Alih ke';

  @override
  String get libraryCategoryMoveNone => 'Tiada kategori';

  @override
  String get libraryCategoryMoveNewCategory => 'Kategori baharu';

  @override
  String get libraryArchiveAction => 'Arkibkan';

  @override
  String get libraryUnarchiveAction => 'Nyaharkib';

  @override
  String libraryArchiveKeepCategoryTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Kekal dalam kategori ini?',
    );
    return '$_temp0';
  }

  @override
  String libraryArchiveKeepCategoryAction(String name) {
    return 'Kekal dalam $name';
  }

  @override
  String get libraryArchiveKeepCategoryActionMixed => 'Kekal dalam kategorinya';

  @override
  String libraryArchiveRemoveCategoryAction(String name) {
    return 'Keluarkan dari $name';
  }

  @override
  String get libraryArchiveRemoveCategoryActionMixed =>
      'Keluarkan dari kategorinya';

  @override
  String get libraryMoveSelectedClipsTooltip => 'Alih klip yang dipilih';

  @override
  String get libraryCategoryEmptyTitle => 'Belum ada apa-apa di sini';

  @override
  String get libraryCategoryEmptySubtitle =>
      'Pilih beberapa klip dan alihkannya ke kategori ini.';

  @override
  String get libraryArchiveEmptyTitle => 'Tiada apa-apa dalam arkib';

  @override
  String get libraryArchiveEmptySubtitle =>
      'Klip yang diarkibkan menunggu di sini, jauh daripada pustaka utama anda.';

  @override
  String libraryClipsMovedToCategory(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klip dialihkan ke $name',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsRemovedFromCategory(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klip dikeluarkan daripada kategorinya',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsArchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klip diarkibkan',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsUnarchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klip kembali ke pustaka anda',
    );
    return '$_temp0';
  }

  @override
  String get accountSettingsChangeEmail => 'Tukar e-mel';

  @override
  String get accountSettingsChangeEmailSubtitle =>
      'Pindahkan akaun anda ke alamat lain';

  @override
  String get accountSettingsChangePassword => 'Tukar kata laluan';

  @override
  String get accountSettingsChangePasswordSubtitle =>
      'Pilih kata laluan baharu untuk log masuk';

  @override
  String get accountCredentialsNeedsSignIn =>
      'Sesi anda tamat. Log masuk semula untuk buat perubahan ini.';

  @override
  String get accountCredentialsRateLimited =>
      'Terlalu banyak percubaan. Tunggu beberapa minit.';

  @override
  String get accountCredentialsNetwork =>
      'Tak dapat hubungi Divine. Semak sambungan anda dan cuba lagi.';

  @override
  String get accountCredentialsUnknown => 'Tak menjadi. Sila cuba lagi.';

  @override
  String get changePasswordSubtitle =>
      'Taip kata laluan semasa, kemudian pilih yang baharu.';

  @override
  String get changePasswordCurrentLabel => 'Kata laluan semasa';

  @override
  String get changePasswordWrongCurrent => 'Itu bukan kata laluan semasa anda.';

  @override
  String get changePasswordSuccess => 'Kata laluan ditukar.';

  @override
  String get changeEmailSubtitle =>
      'Kami hantar pautan pengesahan ke alamat baharu anda dan ke alamat dalam akaun anda. E-mel anda bertukar sebaik anda sahkan kedua-duanya.';

  @override
  String changeEmailCurrentAddress(String email) {
    return 'Dalam akaun anda: $email';
  }

  @override
  String get changeEmailNewLabel => 'E-mel baharu';

  @override
  String get changeEmailPasswordLabel => 'Kata laluan anda';

  @override
  String get changeEmailSameAsCurrent => 'Itu memang alamat e-mel anda.';

  @override
  String get changeEmailWrongPassword => 'Itu bukan kata laluan anda.';

  @override
  String get changeEmailSubmit => 'Hantar pautan pengesahan';

  @override
  String get changeEmailSentTitle => 'Dua pautan dalam perjalanan';

  @override
  String changeEmailSentMessage(String email) {
    return 'Sahkan dari $email dan dari alamat dalam akaun anda. E-mel anda bertukar sebaik kedua-duanya selesai.';
  }

  @override
  String get changeEmailSentExpiry => 'Pautan tamat selepas 24 jam.';

  @override
  String get changeEmailSentDone => 'Faham';

  @override
  String searchUserVideoCount(int count, String formattedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formattedCount video',
    );
    return '$_temp0';
  }

  @override
  String get socialProofMutual => 'Saling mengikuti';

  @override
  String get socialProofFollowsYou => 'Mengikuti anda';

  @override
  String get socialProofYouFollow => 'Anda ikuti';

  @override
  String socialProofFollowerCount(int count, String formattedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formattedCount pengikut',
    );
    return '$_temp0';
  }

  @override
  String get feedOutageMessage =>
      'Video tidak dapat dimuatkan sekarang.\nIni masalah kami, bukan anda — kami sedang membaikinya.';

  @override
  String get feedOfflineMessage =>
      'Anda di luar talian.\nSemak sambungan anda dan cuba lagi.';

  @override
  String get dbFailureTitle =>
      'tidak dapat membuka kunci pangkalan data setempat anda';

  @override
  String get dbFailureAdviceResettable =>
      'Memulakan semula tidak akan membaikinya. Menetapkan semula pangkalan data setempat di bawah memberi Divine permulaan yang bersih — akaun anda kekal.';

  @override
  String get dbFailureAdviceRestart =>
      'Mulakan semula Divine selepas membuka kunci peranti anda. Jika ini berterusan, kemas kini apl atau hubungi sokongan.';

  @override
  String get dbFailureAdviceHotJournal =>
      'Cuba mulakan semula Divine sekali. Jika ini berterusan, kemas kini apl atau hubungi sokongan. Data setempat anda masih ada.';

  @override
  String dbFailureDiagnostic(String code) {
    return 'Diagnostik: $code';
  }

  @override
  String get dbFailureCloseApp => 'tutup Divine';

  @override
  String get dbFailureResetAction => 'tetapkan semula pangkalan data setempat';

  @override
  String get dbFailureConfirmTitle =>
      'tetapkan semula pangkalan data setempat anda?';

  @override
  String get dbFailureConfirmBody =>
      'Akaun anda kekal. Draf dan klip yang disimpan pada peranti ini akan dipadamkan — mesej dan suapan kembali daripada rangkaian.';

  @override
  String get dbFailureResetConfirm =>
      'tetapkan semula pangkalan data setempat sekarang';

  @override
  String get dbFailureCancel => 'batal';

  @override
  String get dbFailureResetFailed =>
      'Itu tidak berjaya. Tutup Divine dan cuba lagi.';

  @override
  String get dbFailureResetDoneTitle =>
      'pangkalan data setempat ditetapkan semula';

  @override
  String get dbFailureResetDoneBody =>
      'Tutup Divine dan buka semula — pelancaran seterusnya membina pangkalan data setempat yang baharu.';

  @override
  String get authSignInOptionsInfo => 'Tentang pilihan log masuk';

  @override
  String get authShowPassword => 'Tunjukkan kata laluan';

  @override
  String get authHidePassword => 'Sembunyikan kata laluan';

  @override
  String get followUserSemanticLabel => 'Ikut pengguna';

  @override
  String get unfollowUserSemanticLabel => 'Nyahikut pengguna';

  @override
  String get commentsLoadingSemanticLabel => 'Memuatkan komen';

  @override
  String get analyticsWindowAll => 'Semua';

  @override
  String followUserIndexedSemanticLabel(String index) {
    return 'Ikut pengguna $index';
  }

  @override
  String unfollowUserIndexedSemanticLabel(String index) {
    return 'Nyahikut pengguna $index';
  }

  @override
  String supporterTierMonthlyLabel(String title, String price) {
    return '$title — $price / bulan';
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
      'Kemas kini baharu sudah tiba. Lihat sekarang →';

  @override
  String get updateModerateTitle =>
      'Terdapat kemas kini sejak semakan terakhir anda';

  @override
  String get updateUrgentTitle => 'Anda kehilangan pembaikan penting';

  @override
  String get updateNotNow => 'Bukan sekarang';

  @override
  String get updateAction => 'Kemas kini';

  @override
  String updateNewIn(String version) {
    return 'Baharu dalam $version:';
  }

  @override
  String get settingsUpdateAvailable => 'Kemas kini tersedia';
}

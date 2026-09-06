// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get devOptionsClipRecovery => 'Pemulihan klip';

  @override
  String get devOptionsClipRecoveryDescription =>
      'Menemukan rekaman yang tersimpan di akun lain dan file video yang tidak lagi dirujuk entri mana pun.';

  @override
  String get devOptionsClipRecoveryScan => 'Pindai';

  @override
  String get devOptionsClipRecoveryFailure => 'Pemulihan klip gagal';

  @override
  String devOptionsClipRecoveryVisible(int clips, int drafts) {
    return 'Terlihat sekarang: $clips klip, $drafts draf';
  }

  @override
  String get devOptionsClipRecoveryOtherAccounts => 'Tersembunyi di akun lain';

  @override
  String devOptionsClipRecoveryCounts(int clips, int drafts) {
    return '$clips klip, $drafts draf';
  }

  @override
  String get devOptionsClipRecoveryClaim => 'Pindahkan ke akun ini';

  @override
  String devOptionsClipRecoveryOrphanFiles(int count, String size) {
    return 'File tanpa rujukan: $count ($size)';
  }

  @override
  String get devOptionsClipRecoveryImport => 'Bangun ulang di pustaka';

  @override
  String get devOptionsClipRecoveryEmpty => 'Tidak ada yang bisa dipulihkan';

  @override
  String devOptionsClipRecoveryRecovered(int count) {
    return '$count klip dipulihkan';
  }

  @override
  String get devOptionsClipRecoveryCopied => 'Laporan pemulihan disalin';

  @override
  String get devOptionsStorageFootprint => 'Penggunaan penyimpanan';

  @override
  String get devOptionsStorageFootprintDescription =>
      'Setiap folder tempat aplikasi menulis. Menghapus cache hanya membebaskan sebagiannya.';

  @override
  String get devOptionsStorageFootprintMeasure => 'Ukur';

  @override
  String devOptionsStorageFootprintTotal(String size) {
    return 'Total: $size';
  }

  @override
  String get devOptionsStorageFootprintCopied => 'Laporan penyimpanan disalin';

  @override
  String get devOptionsStorageFootprintFailure =>
      'Tidak dapat mengukur penyimpanan';

  @override
  String get feedTuningMoreLabel => 'Lebih banyak seperti ini';

  @override
  String get feedTuningLessLabel => 'Lebih sedikit seperti ini';

  @override
  String get feedTuningUndo => 'Urungkan';

  @override
  String get dmMessageBubbleVideoReplyHint => 'Buka video yang dirujuk';

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => 'Pengaturan';

  @override
  String get settingsSecureAccount => 'Amankan Akunmu';

  @override
  String get settingsSessionExpired => 'Sesi Kedaluwarsa';

  @override
  String get settingsSessionExpiredSubtitle =>
      'Masuk lagi untuk memulihkan akses penuh';

  @override
  String get settingsAccountRestoreFailed => 'Account Restore Failed';

  @override
  String get settingsAccountRestoreFailedSwitchMessage =>
      'We couldn\'t unlock that account on this device. Signing back into it means signing out of the one you\'re on now.';

  @override
  String get settingsCreatorAnalytics => 'Analitik Kreator';

  @override
  String get settingsSupportCenter => 'Pusat Bantuan';

  @override
  String get settingsNotifications => 'Notifikasi';

  @override
  String get settingsBlueskyPublishing => 'Publikasi Bluesky';

  @override
  String get settingsBlueskyPublishingSubtitle =>
      'Atur crossposting ke Bluesky';

  @override
  String get settingsNostrSettings => 'Pengaturan Nostr';

  @override
  String get settingsIntegratedApps => 'Aplikasi Terintegrasi';

  @override
  String get settingsIntegratedAppsSubtitle =>
      'Aplikasi pihak ketiga yang disetujui dan berjalan di dalam Divine';

  @override
  String get settingsExperimentalFeatures => 'Fitur Eksperimental';

  @override
  String get settingsExperimentalFeaturesSubtitle =>
      'Penyesuaian yang bisa bermasalah—coba kalau penasaran.';

  @override
  String get settingsLegal => 'Legal';

  @override
  String get settingsIntegrationPermissions => 'Izin Integrasi';

  @override
  String get settingsIntegrationPermissionsSubtitle =>
      'Tinjau dan cabut izin integrasi yang disimpan';

  @override
  String settingsVersion(String version) {
    return 'Versi $version';
  }

  @override
  String get settingsVersionEmpty => 'Versi';

  @override
  String get settingsDeveloperModeAlreadyEnabled =>
      'Mode pengembang sudah aktif';

  @override
  String get settingsDeveloperModeEnabled => 'Mode pengembang aktif!';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    return '$count ketukan lagi untuk mengaktifkan mode pengembang';
  }

  @override
  String get settingsShareDivine => 'Bagikan Divine dengan teman-temanmu';

  @override
  String get settingsSwitchAccount => 'Ganti akun';

  @override
  String get settingsAddAnotherAccount => 'Tambah akun lain';

  @override
  String get settingsAccountSwitchFailed =>
      'Tidak dapat beralih akun. Coba lagi.';

  @override
  String get settingsUnsavedDraftsTitle => 'Draf Belum Tersimpan';

  @override
  String get settingsUploadInProgressTitle => 'Sedang mengunggah';

  @override
  String settingsUploadInProgressMessage(int count) {
    return 'Masih ada $count video yang sedang diunggah. Mengganti akun akan menghentikan unggahan — videomu tetap tersimpan sebagai draf di akun ini.';
  }

  @override
  String settingsUnsavedDraftsMessage(int count) {
    return 'Kamu punya $count draf yang belum disimpan. Mengganti akun akan tetap menyimpan drafmu, tapi mungkin kamu ingin mempublikasikan atau meninjaunya dulu.';
  }

  @override
  String get settingsCancel => 'Batal';

  @override
  String get settingsSwitchAnyway => 'Tetap Ganti';

  @override
  String get settingsSessionExpiredSwitchMessage =>
      'Sesi akun itu sudah habis. Masuk lagi ke sana berarti keluar dari akun yang kamu pakai sekarang.';

  @override
  String get settingsAppVersionLabel => 'Versi aplikasi';

  @override
  String get settingsAppLanguage => 'Bahasa Aplikasi';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language (bawaan perangkat)';
  }

  @override
  String get settingsAppLanguageTitle => 'Bahasa Aplikasi';

  @override
  String get settingsAppLanguageDescription =>
      'Pilih bahasa untuk antarmuka aplikasi';

  @override
  String get settingsAppLanguageUseDeviceLanguage => 'Pakai bahasa perangkat';

  @override
  String get settingsGeneralTitle => 'Pengaturan Umum';

  @override
  String get settingsContentSafetyTitle => 'Konten & Keamanan';

  @override
  String get generalSettingsSectionIntegrations => 'INTEGRASI';

  @override
  String get generalSettingsSectionViewing => 'MENONTON';

  @override
  String get generalSettingsSectionCreating => 'MEMBUAT';

  @override
  String get generalSettingsSectionApp => 'APLIKASI';

  @override
  String get appearanceSettingsTitle => 'Tampilan';

  @override
  String get appearanceSettingsSubtitle =>
      'Pilih tampilan Divine di perangkat ini';

  @override
  String get appearanceSettingsSystem => 'Default sistem';

  @override
  String get appearanceSettingsLight => 'Terang';

  @override
  String get appearanceSettingsDark => 'Gelap';

  @override
  String get generalSettingsClosedCaptions => 'Teks Tertutup';

  @override
  String get generalSettingsClosedCaptionsSubtitle =>
      'Tampilkan teks saat video menyertakannya';

  @override
  String get generalSettingsVideoShapeSquareOnly => 'Video persegi saja';

  @override
  String get generalSettingsVideoShapeSquareOnlySubtitle =>
      'Pertahankan feed dalam format persegi klasik';

  @override
  String get contentPreferencesTitle => 'Preferensi Konten';

  @override
  String get contentPreferencesContentFilters => 'Filter Konten';

  @override
  String get contentPreferencesContentFiltersSubtitle =>
      'Atur filter peringatan konten';

  @override
  String get contentPreferencesContentLanguage => 'Bahasa Konten';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language (bawaan perangkat)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      'Tandai videomu dengan bahasa supaya penonton bisa memfilter konten.';

  @override
  String get contentPreferencesUseDeviceLanguage =>
      'Pakai bahasa perangkat (bawaan)';

  @override
  String get contentPreferencesAudioSharing =>
      'Jadikan audioku bisa dipakai ulang';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      'Saat aktif, orang lain bisa memakai audio dari videomu';

  @override
  String get contentPreferencesMusicMode => 'Mode musik';

  @override
  String get contentPreferencesMusicModeSubtitle =>
      'Melewati pembersihan derau yang meredam alat musik. Lebih bagus untuk musik, lebih kasar untuk suara.';

  @override
  String get contentPreferencesAccountLabels => 'Label Akun';

  @override
  String get contentPreferencesAccountLabelsEmpty =>
      'Beri label sendiri pada kontenmu';

  @override
  String get contentPreferencesAccountContentLabels => 'Label Konten Akun';

  @override
  String get contentPreferencesClearAll => 'Hapus Semua';

  @override
  String get contentPreferencesSelectAllThatApply =>
      'Pilih semua yang sesuai dengan akunmu';

  @override
  String get contentPreferencesDoneNoLabels => 'Selesai (Tanpa Label)';

  @override
  String contentPreferencesDoneCount(int count) {
    return 'Selesai ($count dipilih)';
  }

  @override
  String get contentPreferencesAudioInputDevice => 'Perangkat Masukan Audio';

  @override
  String get contentPreferencesAutoRecommended => 'Otomatis (direkomendasikan)';

  @override
  String get contentPreferencesAutoSelectsBest =>
      'Pilih mikrofon terbaik secara otomatis';

  @override
  String get contentPreferencesSelectAudioInput => 'Pilih Masukan Audio';

  @override
  String get contentPreferencesUnknownMicrophone => 'Mikrofon Tidak Dikenal';

  @override
  String get contentFiltersAdultContent => 'KONTEN DEWASA';

  @override
  String get contentFiltersViolenceGore => 'KEKERASAN & SADIS';

  @override
  String get contentFiltersSubstances => 'ZAT TERLARANG';

  @override
  String get contentFiltersOther => 'LAINNYA';

  @override
  String get contentFiltersAgeGateMessage =>
      'Verifikasi usiamu di pengaturan Keamanan & Privasi untuk membuka filter konten dewasa';

  @override
  String get contentFiltersShow => 'Tampilkan';

  @override
  String get contentFiltersWarn => 'Peringatkan';

  @override
  String get contentFiltersFilterOut => 'Saring';

  @override
  String get profileBlockedAccountNotAvailable => 'Akun ini tidak tersedia';

  @override
  String get profileInvalidId => 'ID profil tidak valid';

  @override
  String profileShareText(String displayName, String npub) {
    return 'Lihat $displayName di Divine!\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return '$displayName di Divine';
  }

  @override
  String get profileShareFailed =>
      'Gagal membagikan profil. Silakan coba lagi.';

  @override
  String get profileCopyPublicKey => 'Salin kunci publik (npub)';

  @override
  String get profileGetEmbedCode => 'Dapatkan kode sematan';

  @override
  String get profilePublicKeyCopied => 'Kunci publik disalin ke clipboard';

  @override
  String get profileEmbedCodeCopied => 'Kode sematan disalin ke clipboard';

  @override
  String get profileMoreTooltip => 'Lainnya';

  @override
  String get profileMoreSemanticLabel => 'Opsi lainnya';

  @override
  String get profileAvatarLightboxBarrierLabel => 'Tutup avatar';

  @override
  String get profileAvatarLightboxCloseSemanticLabel =>
      'Tutup pratinjau avatar';

  @override
  String get profileFollowingLabel => 'Mengikuti';

  @override
  String get profileFollowLabel => 'Ikuti';

  @override
  String get profileBlockedLabel => 'Diblokir';

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
  String get profileRepostsLabel => 'Repost';

  @override
  String get profileListsLabel => 'Daftar';

  @override
  String get profileCommentsLabel => 'Komentar';

  @override
  String profileCollaboratorInvitePendingHeadline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count undangan kolaborator masih perlu dikirim',
      one: '1 undangan kolaborator masih perlu dikirim',
    );
    return '$_temp0';
  }

  @override
  String get profileCollaboratorInvitePendingDetail =>
      'Kami menyimpan undangannya dalam antrean. Coba kirim ulang di sini.';

  @override
  String profileCollaboratorInvitePendingDetailWithTitle(String title) {
    return 'Untuk \"$title\". Coba kirim ulang di sini.';
  }

  @override
  String get profileCollaboratorInviteRetryAction => 'Coba lagi';

  @override
  String get profileCollaboratorInviteRetryingAction => 'Mencoba lagi';

  @override
  String get profileCollaboratorInviteRetryUnavailable =>
      'Kirim ulang undangan kolaborator sedang tidak tersedia saat ini.';

  @override
  String profileCollaboratorInviteRetryResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count undangan kolaborator masih perlu dikirim.',
      one: '1 undangan kolaborator masih perlu dikirim.',
      zero: 'Undangan kolaborator terkirim.',
    );
    return '$_temp0';
  }

  @override
  String profileCollaboratorInviteBlockedResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kolaborator tidak bisa menerima undangan.',
      one: '1 kolaborator tidak bisa menerima undangan.',
    );
    return '$_temp0';
  }

  @override
  String profileFollowerCountUsers(int count) {
    return '$count pengguna';
  }

  @override
  String profileBlockTitle(String displayName) {
    return 'Blokir $displayName?';
  }

  @override
  String get profileBlockExplanation => 'Saat kamu memblokir pengguna:';

  @override
  String get profileBlockBulletHidePosts =>
      'Postingan mereka tidak akan muncul di feed-mu.';

  @override
  String get profileBlockBulletCantView =>
      'Mereka tidak bisa melihat profilmu, mengikutimu, atau melihat postinganmu.';

  @override
  String get profileBlockBulletNoNotify =>
      'Mereka tidak akan diberi tahu tentang perubahan ini.';

  @override
  String get profileBlockBulletYouCanView =>
      'Kamu tetap bisa melihat profil mereka.';

  @override
  String profileBlockConfirmButton(String displayName) {
    return 'Blokir $displayName';
  }

  @override
  String get profileCancelButton => 'Batal';

  @override
  String get profileLearnMore => 'Pelajari Lebih Lanjut';

  @override
  String profileUnblockTitle(String displayName) {
    return 'Buka blokir $displayName?';
  }

  @override
  String get profileUnblockExplanation =>
      'Saat kamu membuka blokir pengguna ini:';

  @override
  String get profileUnblockBulletShowPosts =>
      'Postingan mereka akan muncul di feed-mu.';

  @override
  String get profileUnblockBulletCanView =>
      'Mereka bisa melihat profilmu, mengikutimu, dan melihat postinganmu.';

  @override
  String get profileUnblockBulletNoNotify =>
      'Mereka tidak akan diberi tahu tentang perubahan ini.';

  @override
  String get profileLearnMoreAt => 'Pelajari lebih lanjut di ';

  @override
  String get profileUnblockButton => 'Buka Blokir';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return 'Berhenti mengikuti $displayName';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return 'Blokir $displayName';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return 'Buka blokir $displayName';
  }

  @override
  String profileReportDisplayName(String displayName) {
    return 'Laporkan $displayName';
  }

  @override
  String profileAddToListDisplayName(String displayName) {
    return 'Tambahkan $displayName ke daftar';
  }

  @override
  String get profileNoCollabsTitle => 'Belum Ada Kolaborasi';

  @override
  String get profileCollabsOwnEmpty =>
      'Video yang kamu kolaborasikan akan muncul di sini';

  @override
  String get profileCollabsOtherEmpty =>
      'Video yang mereka kolaborasikan akan muncul di sini';

  @override
  String get profileErrorLoadingCollabs => 'Gagal memuat video kolaborasi';

  @override
  String get profileNoSavedVideosTitle => 'Belum ada yang disimpan';

  @override
  String get profileSavedOwnEmpty =>
      'Bookmark video dari menu bagikan dan akan muncul di sini.';

  @override
  String get profileErrorLoadingSaved => 'Gagal memuat video tersimpan';

  @override
  String get profileNoCommentsOwnTitle => 'Belum Ada Komentar';

  @override
  String get profileNoCommentsOtherTitle => 'Tidak Ada Komentar';

  @override
  String get profileCommentsOwnEmpty =>
      'Komentar dan balasanmu akan muncul di sini';

  @override
  String get profileCommentsOtherEmpty =>
      'Komentar dan balasan mereka akan muncul di sini';

  @override
  String get profileErrorLoadingComments => 'Gagal memuat komentar';

  @override
  String get profileVideoRepliesSection => 'Balasan Video';

  @override
  String get profileCommentsSection => 'Komentar';

  @override
  String get profileEditLabel => 'Ubah';

  @override
  String get profileLibraryLabel => 'Pustaka';

  @override
  String get profileNoLikedVideosTitle => 'Belum Ada Video yang Disukai';

  @override
  String get profileLikedOwnEmpty =>
      'Video yang kamu sukai akan muncul di sini';

  @override
  String get profileLikedOtherEmpty =>
      'Video yang mereka sukai akan muncul di sini';

  @override
  String get profileErrorLoadingLiked => 'Gagal memuat video yang disukai';

  @override
  String get profileNoRepostsTitle => 'Belum Ada Repost';

  @override
  String get profileRepostsOwnEmpty =>
      'Video yang kamu repost akan muncul di sini';

  @override
  String get profileRepostsOtherEmpty =>
      'Video yang mereka repost akan muncul di sini';

  @override
  String get profileErrorLoadingReposts => 'Gagal memuat video yang di-repost';

  @override
  String get profileNoVideosTitle => 'Belum Ada Video';

  @override
  String get profileNoVideosOwnSubtitle =>
      'Bagikan video pertamamu untuk melihatnya di sini';

  @override
  String get profileNoVideosOtherSubtitle =>
      'Pengguna ini belum membagikan video apa pun';

  @override
  String profileVideoThumbnailLabel(int number) {
    return 'Thumbnail video $number';
  }

  @override
  String get profileShowMore => 'Tampilkan lebih banyak';

  @override
  String get profileShowLess => 'Tampilkan lebih sedikit';

  @override
  String get dmMessageDisplayLimitReached =>
      'Sisa pesan ini tidak ditampilkan.';

  @override
  String get profileCompleteYourProfile => 'Lengkapi Profilmu';

  @override
  String get profileCompleteSubtitle =>
      'Tambahkan nama, bio, dan foto untuk memulai';

  @override
  String get profilePleaseTryAgain => 'Silakan coba lagi';

  @override
  String get profileSecureYourAccount => 'Amankan Akunmu';

  @override
  String get profileSecureSubtitle =>
      'Tambahkan email & kata sandi untuk memulihkan akunmu di perangkat mana pun';

  @override
  String get profileRetryButton => 'Coba Lagi';

  @override
  String get profileSessionExpired => 'Sesi Kedaluwarsa';

  @override
  String get profileSignInToRestore =>
      'Masuk lagi untuk memulihkan akses penuh';

  @override
  String get profileSignInButton => 'Masuk';

  @override
  String get profileMaybeLaterLabel => 'Nanti Saja';

  @override
  String get profileSecurePrimaryButton => 'Tambah Email & Kata Sandi';

  @override
  String get profileCompletePrimaryButton => 'Perbarui Profilmu';

  @override
  String get profileLoopsLabel => 'Loop';

  @override
  String get profileLikesLabel => 'Suka';

  @override
  String get profileMyLibraryLabel => 'Pustakaku';

  @override
  String get profileMessageLabel => 'Pesan';

  @override
  String get profileShareLabel => 'Bagikan profil';

  @override
  String get profileDeletedAccountName => 'Akun dihapus';

  @override
  String get inboxActionReportVanishedAccount => 'Laporkan akun ini';

  @override
  String get inboxActionBlockVanishedAccount => 'Blokir akun ini';

  @override
  String get inboxActionUnblockVanishedAccount => 'Buka blokir akun ini';

  @override
  String get inboxReportedVanishedAccount => 'Akun ini dilaporkan';

  @override
  String get inboxBlockedVanishedAccount => 'Akun ini diblokir';

  @override
  String get inboxUnblockedVanishedAccount => 'Blokir akun ini dibuka';

  @override
  String get inboxRemoveConfirmBodyVanishedAccount =>
      'Ini menghapus percakapan dari kotak masukmu. Jika dia mengirim pesan lagi, percakapan baru dimulai.';

  @override
  String get inboxConversationDeletedAccountSubtitle =>
      'Akun ini telah dihapus';

  @override
  String get profileUserFallback => 'pengguna';

  @override
  String get profileLinkCopied => 'Tautan profil disalin';

  @override
  String get profileSetupEditProfileTitle => 'Ubah Profil';

  @override
  String get nostrSettingsNip05ProfileRequired =>
      'Siapkan profilmu sebelum menambahkan alamat NIP-05.';

  @override
  String get nostrSettingsNip05CreateProfileAction => 'Buat profil';

  @override
  String get profileSetupBackLabel => 'Kembali';

  @override
  String get profileSetupAboutNostr => 'Tentang Nostr';

  @override
  String get profileSetupProfilePublished => 'Profil berhasil dipublikasikan!';

  @override
  String get profileSetupUnsavedChangesTitle => 'Simpan perubahan?';

  @override
  String get profileSetupUnsavedChangesSubtitle =>
      'Simpan hasil editanmu sebelum keluar, atau buang saja dan lanjut.';

  @override
  String get profileSetupUnsavedChangesSaveButton => 'Simpan perubahan';

  @override
  String get profileSetupUnsavedChangesDiscardButton => 'Buang perubahan';

  @override
  String get profileSetupUnsavedChangesKeepButton => 'Lanjut mengedit';

  @override
  String get profileSetupCreateNewProfile => 'Buat profil baru?';

  @override
  String get profileSetupNoExistingProfile =>
      'Kami tidak menemukan profil yang ada di relay-mu. Mempublikasikan akan membuat profil baru. Lanjutkan?';

  @override
  String get profileSetupPublishButton => 'Publikasikan';

  @override
  String get profileSetupUsernameTaken =>
      'Username baru saja diambil. Pilih yang lain.';

  @override
  String get profileSetupClaimFailed =>
      'Gagal mengklaim username. Silakan coba lagi.';

  @override
  String get profileSetupPublishFailed =>
      'Gagal mempublikasikan profil. Silakan coba lagi.';

  @override
  String get profileSetupNoRelaysConnected =>
      'Tidak dapat menjangkau jaringan. Periksa koneksimu dan coba lagi.';

  @override
  String get profileSetupDisplayNameLabel => 'Nama Tampilan';

  @override
  String get profileSetupDisplayNameRequired =>
      'Silakan masukkan nama tampilan';

  @override
  String get profileSetupBioLabel => 'Bio (Opsional)';

  @override
  String get profileSetupWebsiteLabel => 'Situs web (opsional)';

  @override
  String get profileSetupPublicKeyLabel => 'Kunci publik (npub)';

  @override
  String get profileSetupUsernameLabel => 'Username (Opsional)';

  @override
  String get profileSetupUsernameHelper =>
      'Gunakan huruf, angka, atau tanda hubung. Nama pengguna menjadi alamat divine.video. Gunakan nama tampilan untuk spasi atau simbol.';

  @override
  String get profileSetupSaveButton => 'Simpan';

  @override
  String get profileSetupSavingButton => 'Menyimpan...';

  @override
  String get profileSetupImageUrlTitle => 'Tambah URL gambar';

  @override
  String get profileSetupImageSelectionFailed =>
      'Pemilihan gambar gagal. Silakan tempel URL gambar di bawah.';

  @override
  String get profileSetupImagesTypeGroup => 'gambar';

  @override
  String get cameraPickErrorPermissionDenied =>
      'Akses kamera mati. Nyalakan di Pengaturan untuk mengambil foto.';

  @override
  String get cameraPickErrorPermissionRestricted =>
      'Akses kamera tidak diizinkan di perangkat ini.';

  @override
  String get cameraPickErrorBusy =>
      'Pemilih sudah terbuka. Tutup lalu coba lagi.';

  @override
  String get cameraPickErrorGeneric => 'Gagal membuka kamera. Coba lagi.';

  @override
  String get profileSetupGotItButton => 'Mengerti';

  @override
  String get profileSetupUploadFailedGeneric =>
      'Gagal mengunggah gambar. Coba lagi nanti.';

  @override
  String get profileSetupUploadNetworkError =>
      'Kesalahan jaringan: Silakan cek koneksi internetmu dan coba lagi.';

  @override
  String get profileSetupUploadAuthError =>
      'Kesalahan autentikasi: Silakan keluar dan masuk kembali.';

  @override
  String get profileSetupUploadFileTooLarge =>
      'File terlalu besar: Pilih gambar yang lebih kecil (maks 10MB).';

  @override
  String get profileSetupUploadServerError =>
      'Gagal mengunggah gambar. Server kami sedang tidak tersedia untuk sementara. Coba lagi sebentar lagi.';

  @override
  String get profileSetupBannerClearButton => 'Hapus banner';

  @override
  String get profileSetupBannerChangeColor => 'Warna banner';

  @override
  String get profileSetupChangeBannerTitle => 'Ubah banner';

  @override
  String get profileSetupBannerColorPickerTitle => 'Ubah warna banner';

  @override
  String get profileSetupBannerColorCustom => 'Kustom';

  @override
  String get profileSetupBannerColorNone => 'Tanpa warna';

  @override
  String get profileSetupBannerColorLime => 'Hijau limau';

  @override
  String get profileSetupBannerColorYellow => 'Kuning';

  @override
  String get profileSetupBannerColorViolet => 'Violet';

  @override
  String get profileSetupBannerColorPink => 'Merah muda';

  @override
  String get profileSetupBannerColorOrange => 'Oranye';

  @override
  String get profileSetupBannerColorPurple => 'Ungu';

  @override
  String get profileSetupAvatarClearButton => 'Hapus foto';

  @override
  String get profileSetupImageTakePhoto => 'Ambil foto';

  @override
  String get profileSetupImageUploadFromCameraRoll => 'Unggah dari galeri';

  @override
  String get profileSetupImagePasteLink => 'Tempel tautan gambar';

  @override
  String get profileSetupEditAvatarLabel => 'Edit foto profil';

  @override
  String get profileSetupEditBannerLabel => 'Edit banner';

  @override
  String get profileSetupUsernameChecking => 'Mengecek ketersediaan...';

  @override
  String get profileSetupUsernameAvailable => 'Username tersedia!';

  @override
  String get profileSetupUsernameTakenIndicator => 'Username sudah diambil';

  @override
  String get profileSetupUsernameReserved => 'Username sudah dipesan';

  @override
  String get profileSetupContactSupport => 'Hubungi dukungan';

  @override
  String get profileSetupCheckAgain => 'Cek ulang';

  @override
  String get profileSetupUsernameBurned => 'Username ini tidak tersedia lagi';

  @override
  String get profileSetupUsernameInvalidFormat =>
      'Hanya huruf, angka, dan tanda hubung yang diperbolehkan';

  @override
  String get profileSetupUsernameInvalidHyphenPlacement =>
      'Nama pengguna tidak boleh diawali atau diakhiri tanda hubung';

  @override
  String get profileSetupUsernameInvalidLength =>
      'Username harus 3-63 karakter';

  @override
  String get profileSetupUsernameNetworkError =>
      'Tidak bisa mengecek ketersediaan. Silakan coba lagi.';

  @override
  String get profileSetupUsernameInvalidFormatGeneric =>
      'Format username tidak valid';

  @override
  String get profileSetupUsernameCheckFailed => 'Gagal mengecek ketersediaan';

  @override
  String get profileSetupUsernameReservedTitle => 'Username dipesan';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return 'Nama $username sudah dipesan. Beri tahu kami kenapa itu seharusnya jadi milikmu.';
  }

  @override
  String get profileSetupUsernameReservedHint =>
      'contoh: Ini nama merekku, nama panggungku, dll.';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      'Sudah menghubungi dukungan? Ketuk \"Cek ulang\" untuk melihat apakah sudah dirilis untukmu.';

  @override
  String get profileSetupSupportRequestSent =>
      'Permintaan dukungan terkirim! Kami akan segera menghubungi.';

  @override
  String get profileSetupCouldntOpenEmail =>
      'Tidak bisa membuka email. Kirim ke: names@divine.video';

  @override
  String get profileSetupSendRequest => 'Kirim permintaan';

  @override
  String get profileSetupUseOwnNip05 => 'Pakai alamat NIP-05 milikmu sendiri';

  @override
  String get profileSetupNip05AddressLabel => 'Alamat NIP-05';

  @override
  String get profileSetupExternalNip05InvalidFormat =>
      'Format NIP-05 tidak valid (contoh: nama@domain.com)';

  @override
  String get profileSetupExternalNip05DivineDomain =>
      'Pakai kolom username di atas untuk divine.video';

  @override
  String get nostrSettingsNip05Address => 'Alamat NIP-05';

  @override
  String get nostrSettingsNip05AddressSubtitle =>
      'Pakai nama pengguna divine.video kamu, atau arahkan handle kamu ke alamat NIP-05 di domain yang kamu kelola.';

  @override
  String get nostrSettingsNip05AddressHint => 'you@example.com';

  @override
  String get nostrSettingsNip05SaveAction => 'Simpan NIP-05';

  @override
  String get nostrSettingsNip05Saved => 'NIP-05 tersimpan';

  @override
  String get nostrSettingsNip05SaveFailed =>
      'NIP-05 gagal disimpan. Coba lagi.';

  @override
  String get profileSetupNip05ConfirmTitle => 'Pakai NIP-05 milikmu sendiri?';

  @override
  String get profileSetupNip05ConfirmBody =>
      'NIP-05 menghubungkan nama seperti kamu@domainmu.com dengan identitas Nostr kamu. Kamu harus mengelola domainnya dan menaruh berkas verifikasi di jalur yang benar. Kalau salah, orang tidak bisa menemukanmu dan handle terverifikasimu hilang. Lanjutkan hanya kalau kamu sudah menyiapkannya.';

  @override
  String get profileSetupNip05ConfirmContinue => 'Lanjut';

  @override
  String get profileSetupNip05ConfirmCancel => 'Batal';

  @override
  String get profileSetupProfilePicturePreview => 'Pratinjau foto profil';

  @override
  String get nostrInfoIntroBuiltOn => 'Divine dibangun di atas Nostr,';

  @override
  String get nostrInfoIntroDescription =>
      ' protokol terbuka yang tahan sensor, yang memungkinkan orang berkomunikasi online tanpa bergantung pada satu perusahaan atau platform. ';

  @override
  String get nostrInfoIntroIdentity =>
      'Saat kamu mendaftar di Divine, kamu mendapat identitas Nostr baru.';

  @override
  String get nostrInfoOwnership =>
      'Nostr memungkinkan kamu memiliki konten, identitas, dan grafik sosialmu, yang bisa kamu pakai di banyak aplikasi. Hasilnya adalah lebih banyak pilihan, lebih sedikit kunci platform, dan internet sosial yang lebih sehat dan tangguh.';

  @override
  String get nostrInfoLingo => 'Istilah Nostr:';

  @override
  String get nostrInfoNpubLabel => 'npub:';

  @override
  String get nostrInfoNpubDescription =>
      ' Alamat publik Nostr-mu. Aman untuk dibagikan dan memungkinkan orang lain menemukan, mengikuti, atau mengirim pesan kepadamu di berbagai aplikasi Nostr.';

  @override
  String get nostrInfoNsecLabel => 'nsec:';

  @override
  String get nostrInfoNsecDescription =>
      ' Kunci pribadi dan bukti kepemilikanmu. Ini memberi kendali penuh atas identitas Nostr-mu, jadi ';

  @override
  String get nostrInfoNsecWarning => 'selalu jaga kerahasiaannya!';

  @override
  String get nostrInfoUsernameLabel => 'Username Nostr:';

  @override
  String get nostrInfoUsernameDescription =>
      ' Nama yang mudah dibaca (seperti @name.divine.video) yang terhubung ke npub-mu. Ini memudahkan identitas Nostr-mu dikenali dan diverifikasi, mirip alamat email.';

  @override
  String get nostrInfoLearnMoreAt => 'Pelajari lebih lanjut di ';

  @override
  String get nostrInfoGotIt => 'Mengerti!';

  @override
  String get videoGridRefreshLabel => 'Mencari video lainnya';

  @override
  String get videoGridOptionsTitle => 'Opsi Video';

  @override
  String get videoGridEditVideo => 'Ubah Video';

  @override
  String get videoGridEditVideoSubtitle =>
      'Perbarui judul, deskripsi, dan hashtag';

  @override
  String get videoGridDeleteVideo => 'Hapus Video';

  @override
  String get videoGridDeleteVideoSubtitle =>
      'Hapus video ini dari Divine. Video ini mungkin masih muncul di klien Nostr lain.';

  @override
  String get videoGridDeletingContent => 'Menghapus konten...';

  @override
  String get exploreTabFeatured => 'Unggulan';

  @override
  String get exploreTabClassics => 'Klasik';

  @override
  String get exploreTabNew => 'Baru';

  @override
  String get exploreTabPopular => 'Populer';

  @override
  String get exploreTabCategories => 'Kategori';

  @override
  String get exploreTabForYou => 'Untukmu';

  @override
  String get exploreTabLists => 'Daftar';

  @override
  String get exploreTabIntegratedApps => 'Aplikasi Terintegrasi';

  @override
  String exploreFeaturedSponsoredBy(String sponsor) {
    return 'Sponsored by $sponsor';
  }

  @override
  String exploreFeaturedSponsoredPillSemanticLabel(String name) {
    return '$name, sponsored';
  }

  @override
  String get featuredTabEmpty => 'Belum ada apa-apa di sini. Cek lagi nanti.';

  @override
  String get featuredTabLoadFailed => 'Koleksi ini gagal dimuat.';

  @override
  String get featuredTabRetry => 'Coba lagi';

  @override
  String get exploreNoVideosAvailable => 'Tidak ada video tersedia';

  @override
  String get exploreDiscoverLists => 'Temukan Daftar';

  @override
  String get exploreAboutLists => 'Tentang Daftar';

  @override
  String get exploreAboutListsDescription =>
      'Daftar membantumu mengorganisir dan mengkurasi konten Divine dengan dua cara:';

  @override
  String get explorePeopleLists => 'Daftar Orang';

  @override
  String get explorePeopleListsDescription =>
      'Ikuti grup kreator dan lihat video terbaru mereka';

  @override
  String get exploreVideoLists => 'Daftar Video';

  @override
  String get exploreVideoListsDescription =>
      'Buat playlist video favoritmu untuk ditonton nanti';

  @override
  String get exploreMyLists => 'Daftarku';

  @override
  String get exploreSubscribedLists => 'Daftar yang Dilanggan';

  @override
  String get exploreErrorLoadingLists =>
      'Gagal memuat daftar. Silakan coba lagi.';

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count video baru',
    );
    return '$_temp0';
  }

  @override
  String exploreLoadNewVideosLabel(int count) {
    return 'Muat $count video baru';
  }

  @override
  String get videoPlayerPlayVideo => 'Putar video';

  @override
  String get videoPlayerMute => 'Bisukan video';

  @override
  String get videoPlayerUnmute => 'Aktifkan suara video';

  @override
  String get videoPlayerTapHint =>
      'Ketuk untuk memutar atau menjeda. Ketuk dua kali untuk menyukai.';

  @override
  String get videoSettingsMenuOpen => 'Buka pengaturan pemutaran';

  @override
  String get videoSettingsMenuClose => 'Tutup pengaturan pemutaran';

  @override
  String get videoSettingsCaptionsEnable => 'Aktifkan teks';

  @override
  String get videoSettingsCaptionsDisable => 'Nonaktifkan teks';

  @override
  String get videoSettingsAutoAdvanceOn => 'Lanjut otomatis aktif';

  @override
  String get videoSettingsAutoAdvanceOff => 'Lanjut otomatis nonaktif';

  @override
  String get videoSettingsCaptionsOn => 'Teks aktif';

  @override
  String get videoSettingsCaptionsOff => 'Teks nonaktif';

  @override
  String get videoSettingsCaptionsOnForVideo => 'Takarir aktif untuk video ini';

  @override
  String get videoSettingsCaptionsOffForVideo =>
      'Takarir nonaktif untuk video ini';

  @override
  String get contentWarningLabel => 'Peringatan Konten';

  @override
  String get contentWarningNudity => 'Ketelanjangan';

  @override
  String get contentWarningSexualContent => 'Konten Seksual';

  @override
  String get contentWarningPornography => 'Pornografi';

  @override
  String get contentWarningGraphicMedia => 'Media Grafis';

  @override
  String get contentWarningViolence => 'Kekerasan';

  @override
  String get contentWarningSelfHarm => 'Menyakiti Diri';

  @override
  String get contentWarningDrugUse => 'Penggunaan Narkoba';

  @override
  String get contentWarningAlcohol => 'Alkohol';

  @override
  String get contentWarningTobacco => 'Tembakau';

  @override
  String get contentWarningGambling => 'Judi';

  @override
  String get contentWarningProfanity => 'Kata Kasar';

  @override
  String get contentWarningFlashingLights => 'Lampu Berkedip';

  @override
  String get contentWarningAiGenerated => 'Dihasilkan AI';

  @override
  String get contentWarningSpoiler => 'Spoiler';

  @override
  String get contentWarningSensitiveContent => 'Konten Sensitif';

  @override
  String get contentWarningDescNudity =>
      'Mengandung ketelanjangan atau ketelanjangan sebagian';

  @override
  String get contentWarningDescSexual => 'Mengandung konten seksual';

  @override
  String get contentWarningDescPorn => 'Mengandung konten pornografi eksplisit';

  @override
  String get contentWarningDescGraphicMedia =>
      'Mengandung gambar grafis atau mengganggu';

  @override
  String get contentWarningDescViolence => 'Mengandung konten kekerasan';

  @override
  String get contentWarningDescSelfHarm =>
      'Mengandung referensi tentang menyakiti diri';

  @override
  String get contentWarningDescDrugs => 'Mengandung konten terkait narkoba';

  @override
  String get contentWarningDescAlcohol => 'Mengandung konten terkait alkohol';

  @override
  String get contentWarningDescTobacco => 'Mengandung konten terkait tembakau';

  @override
  String get contentWarningDescGambling => 'Mengandung konten terkait judi';

  @override
  String get contentWarningDescProfanity => 'Mengandung bahasa kasar';

  @override
  String get contentWarningDescFlashingLights =>
      'Mengandung lampu berkedip (peringatan fotosensitivitas)';

  @override
  String get contentWarningDescAiGenerated => 'Konten ini dihasilkan oleh AI';

  @override
  String get contentWarningDescSpoiler => 'Mengandung spoiler';

  @override
  String get contentWarningDescContentWarning =>
      'Kreator menandai ini sebagai sensitif';

  @override
  String get contentWarningDescDefault => 'Kreator menandai konten ini';

  @override
  String get contentWarningDetailsTitle => 'Peringatan Konten';

  @override
  String get contentWarningDetailsSubtitle => 'Kreator menerapkan label ini:';

  @override
  String get contentWarningManageFilters => 'Atur filter konten';

  @override
  String get contentWarningViewAnyway => 'Tetap Lihat';

  @override
  String get contentWarningReportContentTooltip => 'Laporkan Konten';

  @override
  String get contentWarningBlockUserTooltip => 'Blokir Pengguna';

  @override
  String get contentWarningBlockedTitle => 'Konten Diblokir';

  @override
  String get contentWarningBlockedPolicy =>
      'Konten ini diblokir karena melanggar kebijakan.';

  @override
  String get contentWarningNoticeTitle => 'Pemberitahuan Konten';

  @override
  String get contentWarningPotentiallyHarmfulTitle =>
      'Konten Berpotensi Berbahaya';

  @override
  String get contentWarningView => 'Lihat';

  @override
  String get contentWarningReportAction => 'Laporkan';

  @override
  String get contentWarningHideAllLikeThis =>
      'Sembunyikan semua konten seperti ini';

  @override
  String get contentWarningNoFilterYet =>
      'Belum ada filter tersimpan untuk peringatan ini.';

  @override
  String get contentWarningHiddenConfirmation =>
      'Kami akan menyembunyikan postingan seperti ini mulai sekarang.';

  @override
  String get communitySuggestTitle => 'Bantu klasifikasikan ini';

  @override
  String get communitySuggestSubtitle =>
      'Ada peringatan konten yang kurang? Saranmu bersifat publik, bertanda tangan, dan tidak bisa ditarik kembali.';

  @override
  String get communitySuggestSubmit => 'Sarankan';

  @override
  String get communitySuggestSuccess => 'Terima kasih. Saranmu terkirim.';

  @override
  String get communitySuggestFailure =>
      'Tidak bisa mengirim saranmu. Coba lagi.';

  @override
  String get communitySuggestAlready => 'Kamu sudah menyarankan ini';

  @override
  String get communitySuggestActionLabel => 'Klasifikasikan';

  @override
  String get videoErrorNotFound => 'Video tidak ditemukan';

  @override
  String get videoErrorPlayback => 'Kesalahan pemutaran video';

  @override
  String get videoErrorAgeRestricted => 'Konten dengan pembatasan usia';

  @override
  String get videoErrorUnavailable => 'Video tidak tersedia';

  @override
  String get videoErrorUnavailableBody => 'Video ini belum tersedia saat ini.';

  @override
  String get videoErrorRetry => 'Coba Lagi';

  @override
  String get videoErrorContentRestricted => 'Konten dibatasi';

  @override
  String get videoErrorContentRestrictedBody =>
      'Video ini dihapus karena melanggar aturan konten kami.';

  @override
  String get videoErrorVerifyAgeBody =>
      'Verifikasi usiamu untuk melihat video ini.';

  @override
  String get videoErrorSkip => 'Lewati';

  @override
  String get videoErrorVerifyAgeButton => 'Verifikasi usia';

  @override
  String get videoErrorVerifyAgeFailed =>
      'Tidak dapat memverifikasi usia kamu. Silakan coba lagi.';

  @override
  String get videoErrorVerifyAgeSignerUnreachable =>
      'Waktu verifikasi habis. Periksa koneksi kamu atau coba lagi sebentar lagi.';

  @override
  String get videoErrorAdultContentHiddenTitle =>
      'Konten dewasa sedang dimatikan';

  @override
  String get videoErrorAdultContentHiddenBody =>
      'Aktifkan di Filter Konten kamu untuk menonton video ini.';

  @override
  String get videoErrorAdultContentHiddenAction => 'Buka Filter Konten';

  @override
  String get videoDetailLoadError => 'Gagal memuat video';

  @override
  String get videoDetailLoadErrorBody =>
      'Ada yang meleset di jalan. Coba lagi, ya.';

  @override
  String get videoDetailNotFoundBody =>
      'Mungkin sudah dihapus, di luar jangkauan, atau disembunyikan sama pengaturanmu.';

  @override
  String get databaseCorruptionTitle => 'Data lokalmu rusak';

  @override
  String get databaseCorruptionBody =>
      'Tutup Divine lalu buka lagi — kami perbaiki otomatis. Kami simpan draf dan klipmu semampu kami, sisanya dimuat ulang.';

  @override
  String get databaseCorruptionCloseButton => 'Tutup Divine';

  @override
  String get videoDetailContextTitle => 'Video yang dibagikan';

  @override
  String get videoDetailCloseSemanticLabel => 'Tutup pemutar video';

  @override
  String get videoFollowButtonFollow => 'Ikuti';

  @override
  String get audioAttributionOriginalSound => 'Suara asli';

  @override
  String get audioAttributionUnavailableSound => 'Suara tidak tersedia';

  @override
  String videoInspiredByAttributionMultiple(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return 'Terinspirasi oleh @$creatorName +$additionalCreatorCount';
  }

  @override
  String videoInspiredByAttribution(String creatorName) {
    return 'Terinspirasi oleh @$creatorName';
  }

  @override
  String videoCollaboratorWithOne(String name) {
    return 'dengan @$name';
  }

  @override
  String videoCollaboratorWithMore(String name, int count) {
    return 'dengan @$name +$count';
  }

  @override
  String videoCollaboratorCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kolaborator',
    );
    return '$_temp0. Ketuk untuk melihat profil.';
  }

  @override
  String get videoCollaboratorPendingDecoration => 'Menunggu';

  @override
  String get videoCollaboratorPendingSemanticLabel =>
      'Kolaborator yang menunggu';

  @override
  String videoCollaboratorWithPendingSuffix(String label, int pending) {
    return '$label ($pending menunggu)';
  }

  @override
  String profileChipTapHint(String name) {
    return '$name. Ketuk untuk melihat profil.';
  }

  @override
  String metadataHashtagChipTapHint(String hashtag) {
    return '#$hashtag. Ketuk untuk melihat video dengan hashtag ini.';
  }

  @override
  String get listAttributionFallback => 'Daftar';

  @override
  String get shareVideoLabel => 'Bagikan video';

  @override
  String sharePostSharedWith(String recipientName) {
    return 'Postingan dibagikan dengan $recipientName';
  }

  @override
  String sharePostSharedWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Postingan dibagikan dengan $count orang',
    );
    return '$_temp0';
  }

  @override
  String get shareFailedToSend => 'Gagal mengirim video';

  @override
  String get shareAddedToBookmarks => 'Ditambahkan ke bookmark';

  @override
  String get shareRemovedFromBookmarks => 'Dihapus dari bookmark';

  @override
  String get shareFailedToAddBookmark => 'Gagal menambahkan bookmark';

  @override
  String get shareFailedToRemoveBookmark => 'Gagal menghapus bookmark';

  @override
  String get shareActionFailed => 'Aksi gagal';

  @override
  String get shareWithTitle => 'Bagikan dengan';

  @override
  String get shareFindPeople => 'Cari orang';

  @override
  String get shareFindPeopleMultiline => 'Cari\norang';

  @override
  String get shareSent => 'Terkirim';

  @override
  String shareSelectedRecipientAnnouncement(String name) {
    return '$name dipilih';
  }

  @override
  String get shareMessageHint => 'Tambahkan pesan opsional...';

  @override
  String get videoActionUnlike => 'Batalkan suka video';

  @override
  String get videoActionLike => 'Suka video';

  @override
  String get videoActionAutoLabel => 'Otomatis';

  @override
  String get videoActionLikeLabel => 'Suka';

  @override
  String get videoActionReplyLabel => 'Balas';

  @override
  String get videoActionRepostLabel => 'Repost';

  @override
  String get videoActionShareLabel => 'Bagikan';

  @override
  String get videoActionReportLabel => 'Laporkan';

  @override
  String get videoActionReport => 'Laporkan video';

  @override
  String get videoActionEditLabel => 'Edit';

  @override
  String get videoActionEdit => 'Edit video';

  @override
  String get videoActionAboutLabel => 'Tentang';

  @override
  String get videoActionEnableAutoAdvance => 'Aktifkan lanjut otomatis';

  @override
  String get videoActionDisableAutoAdvance => 'Nonaktifkan lanjut otomatis';

  @override
  String get videoActionRemoveRepost => 'Hapus repost';

  @override
  String get videoActionRepost => 'Repost video';

  @override
  String get videoActionViewComments => 'Lihat komentar';

  @override
  String get videoActionMoreOptions => 'Opsi lainnya';

  @override
  String get videoEngagementLikersTitle => 'Disukai oleh';

  @override
  String get videoEngagementRepostersTitle => 'Direpost oleh';

  @override
  String get videoEngagementLikersEmpty => 'Belum ada suka';

  @override
  String get videoEngagementRepostersEmpty => 'Belum ada repost';

  @override
  String get videoEngagementLoadFailed => 'Tidak dapat memuat daftar';

  @override
  String get videoOverlayOpenMetadataFromTitle => 'Buka detail video';

  @override
  String get videoOverlayOpenMetadataFromDescription => 'Buka detail video';

  @override
  String get videoOverlayCommentBarHint => 'Tambahkan komentar...';

  @override
  String get videoOverlayCommentBarSemanticLabel => 'Tambahkan komentar';

  @override
  String get videoOverlayCommentBarSendLabel => 'Kirim komentar';

  @override
  String get videoOverlayCommentPostedSnackbar => 'Komentar terkirim';

  @override
  String get videoOverlayCommentPostFailedSnackbar =>
      'Tidak bisa mengirim komentar';

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
  String get metadataSoundsLabel => 'Suara';

  @override
  String get metadataOriginalSound => 'Suara asli';

  @override
  String get metadataVerificationLabel => 'Verifikasi';

  @override
  String get metadataDeviceAttestation => 'Atestasi perangkat';

  @override
  String get metadataPgpSignature => 'Tanda tangan PGP';

  @override
  String get metadataC2paCredentials => 'Kredensial Konten C2PA';

  @override
  String get metadataProofManifest => 'Manifes bukti';

  @override
  String get metadataVerificationInfoTooltip => 'Apa arti pemeriksaan ini?';

  @override
  String metadataSectionInfoSemanticsLabel(String section, String question) {
    return '$section. $question';
  }

  @override
  String get metadataVerificationInfoTitle => 'Apa arti pemeriksaan ini';

  @override
  String get metadataVerificationInfoIntro =>
      'Sinyal ini berasal dari kamera dan dari berkas video itu sendiri. Makin banyak yang dibawa sebuah video, makin banyak yang bisa kami buktikan tentang asalnya.';

  @override
  String get metadataVerificationInfoDeviceAttestation =>
      'Sistem operasi ponsel menjamin aplikasi yang merekam ini. Bukti kuat bahwa ini berasal dari kamera, bukan file yang diunggah seseorang.';

  @override
  String get metadataVerificationInfoPgpSignature =>
      'Video ditandatangani secara kriptografis pada saat direkam. Ubah satu frame saja setelahnya, tanda tangannya rusak.';

  @override
  String get metadataVerificationInfoC2paCredentials =>
      'Catatan asal-usul berstandar industri yang ikut di dalam berkas — sehingga aplikasi selain Divine juga bisa memeriksanya.';

  @override
  String get metadataVerificationInfoProofManifest =>
      'Catatan ProofMode lengkap: sidik jari berkas, stempel waktu, dan konteks perekaman, menyatu dengan video.';

  @override
  String get metadataVerificationInfoFootnote =>
      'Pemeriksaan yang hilang tidak membuat video jadi palsu. Klip lama dan unggahan memang tidak pernah punya — itu hanya berarti bagian itu tidak bisa kami buktikan.';

  @override
  String metadataVerificationInfoLearnMore(String url) {
    return 'Pelajari selengkapnya di $url';
  }

  @override
  String get metadataCreatorLabel => 'Kreator';

  @override
  String get metadataCollaboratorsLabel => 'Kolaborator';

  @override
  String get metadataInspiredByLabel => 'Terinspirasi oleh';

  @override
  String get metadataRepostedByLabel => 'Di-repost oleh';

  @override
  String metadataMoreReposters(int count) {
    return '+$count lainnya';
  }

  @override
  String metadataLoopsLabel(int count) {
    return 'Loop';
  }

  @override
  String get metadataLikesLabel => 'Suka';

  @override
  String get metadataCommentsLabel => 'Komentar';

  @override
  String get metadataRepostsLabel => 'Repost';

  @override
  String get metadataVineStatsLabel => 'Di Vine';

  @override
  String metadataVineStatsLine(
    String loops,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$loops loop · $likes suka · $comments komentar · $reposts repost';
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
    return '$views tayangan · $likes suka · $comments komentar · $reposts repost';
  }

  @override
  String metadataPostedDateSemantics(String date) {
    return 'Diposting pada $date';
  }

  @override
  String get devOptionsTitle => 'Opsi Pengembang';

  @override
  String get devOptionsDisableDeveloperMode => 'Nonaktifkan Mode Pengembang';

  @override
  String get devOptionsDisableDeveloperModeSubtitle =>
      'Sembunyikan opsi pengembang dari pengaturan';

  @override
  String get devOptionsDisableDeveloperModeToast =>
      'Mode pengembang dinonaktifkan';

  @override
  String get devOptionsShorebirdTitle => 'Patch Shorebird';

  @override
  String get devOptionsShorebirdPatchLabel => 'Patch aktif';

  @override
  String get devOptionsShorebirdNoPatch => 'Tidak ada patch terpasang';

  @override
  String get devOptionsShorebirdUnavailable => 'Tidak tersedia di build ini';

  @override
  String get devOptionsShorebirdUnavailableSubtitle =>
      'Patch hanya berfungsi di build yang dibuat dengan shorebird release.';

  @override
  String get devOptionsShorebirdLoading => 'Membaca status patch…';

  @override
  String get devOptionsShorebirdNotChecked => 'Track staging belum diperiksa.';

  @override
  String get devOptionsShorebirdCheck => 'Periksa track staging';

  @override
  String get devOptionsShorebirdApply => 'Terapkan patch staging';

  @override
  String get devOptionsShorebirdUseStable => 'Kembali ke pembaruan stabil';

  @override
  String get devOptionsShorebirdChecking => 'Memeriksa track staging…';

  @override
  String get devOptionsShorebirdUpdateAvailable =>
      'Patch staging siap diterapkan.';

  @override
  String get devOptionsShorebirdUpToDate =>
      'Tidak ada patch staging untuk rilis ini.';

  @override
  String get devOptionsShorebirdRestartRequired =>
      'Sudah diunduh. Mulai ulang aplikasi untuk memuatnya.';

  @override
  String get devOptionsShorebirdRollbackRequired =>
      'Rollback siap. Mulai ulang untuk kembali ke rilis dasar.';

  @override
  String get devOptionsShorebirdApplying => 'Mengunduh dan memasang…';

  @override
  String get devOptionsShorebirdApplied =>
      'Terpasang. Mulai ulang aplikasi untuk memuatnya.';

  @override
  String get devOptionsShorebirdUnchanged =>
      'Tidak ada yang terpasang. Periksa track staging dan coba lagi.';

  @override
  String get devOptionsShorebirdSelectingStableTrack => 'Memilih jalur stabil…';

  @override
  String get devOptionsShorebirdStableRestored =>
      'Jalur stabil dipilih. Mulai ulang aplikasi untuk memeriksa patch stabil.';

  @override
  String get devOptionsShorebirdFailure =>
      'Tidak berhasil. Periksa log untuk detailnya.';

  @override
  String get devOptionsPageLoadTimes => 'Waktu Muat Halaman';

  @override
  String get devOptionsNoPageLoads =>
      'Belum ada pemuatan halaman yang tercatat.\nNavigasi ke seluruh aplikasi untuk melihat data waktu.';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return 'Terlihat: ${visibleMs}ms  |  Data: ${dataMs}ms';
  }

  @override
  String get devOptionsSlowestScreens => 'Layar Paling Lambat';

  @override
  String get devOptionsVideoPlaybackFormat => 'Format Pemutaran Video';

  @override
  String get devOptionsSwitchEnvironmentTitle => 'Ganti Lingkungan?';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return 'Ganti ke $envName?\n\nIni akan menghapus data video yang tersimpan di cache dan menghubungkan ulang ke relay baru.';
  }

  @override
  String get devOptionsCancel => 'Batal';

  @override
  String get devOptionsSwitch => 'Ganti';

  @override
  String devOptionsSwitchedTo(String envName) {
    return 'Diganti ke $envName';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return 'Diganti ke $formatName — cache dibersihkan';
  }

  @override
  String get featureFlagTitle => 'Feature Flags';

  @override
  String get featureFlagResetAllTooltip => 'Reset semua flag ke bawaan';

  @override
  String get featureFlagError => 'Kesalahan';

  @override
  String get relaySettingsTitle => 'Relay';

  @override
  String get relaySettingsInfoTitle =>
      'Divine adalah sistem terbuka - kamu mengontrol koneksimu';

  @override
  String get relaySettingsInfoDescription =>
      'Relay ini mendistribusikan kontenmu ke seluruh jaringan Nostr yang terdesentralisasi. Kamu bisa menambah atau menghapus relay sesukamu.';

  @override
  String get relaySettingsLearnMoreNostr =>
      'Pelajari lebih lanjut tentang Nostr →';

  @override
  String get relaySettingsFindPublicRelays =>
      'Temukan relay publik di nostr.co.uk →';

  @override
  String get relaySettingsAppNotFunctional => 'Aplikasi Tidak Berfungsi';

  @override
  String get relaySettingsRequiresRelay =>
      'Divine butuh minimal satu relay untuk memuat video, posting konten, dan sinkronisasi data.';

  @override
  String get relaySettingsRestoreDefaultRelay => 'Pulihkan Relay Bawaan';

  @override
  String get relaySettingsAddCustomRelay => 'Tambah Relay Kustom';

  @override
  String get relaySettingsAddRelay => 'Tambah Relay';

  @override
  String get relaySettingsRetry => 'Coba Lagi';

  @override
  String get relaySettingsNoStats => 'Belum ada statistik tersedia';

  @override
  String get relaySettingsConnection => 'Koneksi';

  @override
  String get relaySettingsConnected => 'Terhubung';

  @override
  String get relaySettingsDisconnected => 'Terputus';

  @override
  String get relaySettingsSessionDuration => 'Durasi Sesi';

  @override
  String get relaySettingsLastConnected => 'Terakhir Terhubung';

  @override
  String get relaySettingsDisconnectedLabel => 'Terputus';

  @override
  String get relaySettingsReason => 'Alasan';

  @override
  String get relaySettingsActiveSubscriptions => 'Langganan Aktif';

  @override
  String get relaySettingsTotalSubscriptions => 'Total Langganan';

  @override
  String get relaySettingsEventsReceived => 'Event Diterima';

  @override
  String get relaySettingsEventsSent => 'Event Dikirim';

  @override
  String get relaySettingsRequestsThisSession => 'Permintaan Sesi Ini';

  @override
  String get relaySettingsFailedRequests => 'Permintaan Gagal';

  @override
  String get relaySettingsLoadingRelayInfo => 'Memuat info relay...';

  @override
  String get relaySettingsAboutRelay => 'Tentang Relay';

  @override
  String get relaySettingsSupportedNips => 'NIP yang Didukung';

  @override
  String get relaySettingsSoftware => 'Perangkat Lunak';

  @override
  String get relaySettingsViewWebsite => 'Lihat Website';

  @override
  String get relaySettingsRemoveRelayTitle => 'Hapus Relay?';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return 'Yakin mau menghapus relay ini?\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveDefaultRelayTitle => 'Hapus relay Divine?';

  @override
  String relaySettingsRemoveDefaultRelayMessage(String relayUrl) {
    return 'Menghapus relay Divine bakal menurunkan pengalaman di app. Video, posting, dan sinkronisasi bisa jadi kurang andal. Ini sebaiknya cuma dilakukan pengguna Nostr yang berpengalaman.\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveRelayTooltip => 'Hapus relay';

  @override
  String get relaySettingsCancel => 'Batal';

  @override
  String get relaySettingsRemove => 'Hapus';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return 'Relay dihapus: $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay => 'Gagal menghapus relay';

  @override
  String get relaySettingsForcingReconnection =>
      'Memaksa koneksi ulang relay...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    return 'Terhubung ke $count relay!';
  }

  @override
  String get relaySettingsFailedToConnectCheck =>
      'Gagal terhubung ke relay. Silakan cek koneksi jaringanmu.';

  @override
  String get relaySettingsSavedLocallyPublishPending =>
      'Tersimpan di perangkat ini. Kami akan menyinkronkannya ke akunmu saat penerbitan berfungsi lagi.';

  @override
  String get relaySettingsAddRelayTitle => 'Tambah Relay';

  @override
  String get relaySettingsAddRelayPrompt =>
      'Masukkan URL WebSocket relay yang ingin kamu tambahkan:';

  @override
  String get relaySettingsBrowsePublicRelays =>
      'Jelajahi relay publik di nostr.co.uk';

  @override
  String get relaySettingsAdd => 'Tambah';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return 'Relay ditambahkan: $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      'Gagal menambah relay. Silakan cek URL dan coba lagi.';

  @override
  String get relaySettingsInvalidUrl =>
      'URL relay harus dimulai dengan wss:// atau ws://';

  @override
  String get relaySettingsInsecureUrl =>
      'URL relay harus pakai wss:// (ws:// hanya boleh untuk localhost)';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return 'Relay bawaan dipulihkan: $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      'Gagal memulihkan relay bawaan. Silakan cek koneksi jaringanmu.';

  @override
  String get relaySettingsCouldNotOpenBrowser => 'Tidak bisa membuka browser';

  @override
  String get relaySettingsFailedToOpenLink => 'Gagal membuka tautan';

  @override
  String get relaySettingsExternalRelay => 'Relay eksternal';

  @override
  String get relaySettingsNotConnected => 'Tidak terhubung';

  @override
  String relaySettingsDisconnectedAgo(String duration) {
    return 'Terputus $duration lalu';
  }

  @override
  String relaySettingsSubscriptionsSummary(int count) {
    return '$count sub';
  }

  @override
  String relaySettingsEventsSummary(int countValue, String count) {
    return '$count event';
  }

  @override
  String relaySettingsTimeAgo(String duration) {
    return '$duration lalu';
  }

  @override
  String get nostrSettingsIntro =>
      'Divine memakai protokol Nostr untuk publikasi terdesentralisasi. Kontenmu hidup di relay yang kamu pilih, dan kuncimu adalah identitasmu.';

  @override
  String get nostrSettingsSectionNetwork => 'Jaringan';

  @override
  String get nostrSettingsSectionAccount => 'Akun';

  @override
  String get nostrSettingsSectionDangerZone => 'Zona Berbahaya';

  @override
  String get nostrSettingsRelays => 'Relay';

  @override
  String get nostrSettingsRelaysSubtitle => 'Atur koneksi relay Nostr';

  @override
  String get nostrSettingsRelayDiagnostics => 'Diagnostik Relay';

  @override
  String get nostrSettingsRelayDiagnosticsSubtitle =>
      'Debug konektivitas relay dan masalah jaringan';

  @override
  String get nostrSettingsMediaServers => 'Server Media';

  @override
  String get nostrSettingsMediaServersSubtitle =>
      'Konfigurasi server upload Blossom';

  @override
  String get settingsDeveloperOptions => 'Opsi Pengembang';

  @override
  String get settingsDeveloperOptionsSubtitle =>
      'Pengubah environment dan pengaturan debug';

  @override
  String get nostrSettingsKeyManagement => 'Manajemen Kunci';

  @override
  String get nostrSettingsKeyManagementSubtitle =>
      'Ekspor, backup, dan pulihkan kunci Nostr-mu';

  @override
  String get nostrSettingsClientAttribution => 'Atribusi klien';

  @override
  String get nostrSettingsClientAttributionSubtitle =>
      'Tambahkan tag klien Divine ke event yang kamu publikasikan agar aplikasi Nostr lain bisa mengatribusikannya dengan benar. Tanpa itu, laporan yang kamu kirim punya bobot lebih kecil saat ditinjau moderator kami.';

  @override
  String get nostrSettingsMoveAccount => 'Pindahkan akunmu';

  @override
  String get nostrSettingsMoveAccountSubtitle =>
      'Unduh arsipmu dan pindahkan postingan serta videomu ke relay atau server media lain.';

  @override
  String get nostrSettingsRemoveKeys => 'Hapus Kunci dari Perangkat';

  @override
  String get nostrSettingsRemoveKeysSubtitle =>
      'Hapus kunci privatmu hanya dari perangkat ini. Kontenmu tetap di relay, tapi kamu butuh backup nsec untuk masuk lagi.';

  @override
  String get nostrSettingsCouldNotRemoveKeys =>
      'Gagal menghapus akun ini dari perangkat ini. Coba lagi.';

  @override
  String get nostrSettingsDeleteAccount => 'Hapus Akun dan Data';

  @override
  String get nostrSettingsDeleteAccountSubtitle =>
      'Mengirim permintaan penghapusan untuk kontenmu dan mengeluarkanmu dari akun di perangkat ini. Relay, klien, indeks pencarian, dan perangkat lain yang masih masuk mungkin menyimpan salinan.';

  @override
  String get relayDiagnosticTitle => 'Diagnostik Relay';

  @override
  String get relayDiagnosticRefreshTooltip => 'Segarkan diagnostik';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return 'Segar terakhir: $time';
  }

  @override
  String get relayDiagnosticRelayStatus => 'Status Relay';

  @override
  String get relayDiagnosticInitialized => 'Diinisialisasi';

  @override
  String get relayDiagnosticReady => 'Siap';

  @override
  String get relayDiagnosticNotInitialized => 'Belum diinisialisasi';

  @override
  String get relayDiagnosticDatabaseEvents => 'Event Database';

  @override
  String get relayDiagnosticActiveSubscriptions => 'Langganan Aktif';

  @override
  String get relayDiagnosticExternalRelays => 'Relay Eksternal';

  @override
  String get relayDiagnosticConfigured => 'Dikonfigurasi';

  @override
  String relayDiagnosticRelayCount(int count) {
    return '$count relay';
  }

  @override
  String get relayDiagnosticConnectedLabel => 'Terhubung';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => 'Event Video';

  @override
  String get relayDiagnosticHomeFeed => 'Feed Beranda';

  @override
  String relayDiagnosticVideosCount(int count) {
    return '$count video';
  }

  @override
  String get relayDiagnosticDiscovery => 'Penemuan';

  @override
  String get relayDiagnosticLoading => 'Memuat';

  @override
  String get relayDiagnosticYes => 'Ya';

  @override
  String get relayDiagnosticNo => 'Tidak';

  @override
  String get relayDiagnosticTestDirectQuery => 'Tes Query Langsung';

  @override
  String get relayDiagnosticNetworkConnectivity => 'Konektivitas Jaringan';

  @override
  String get relayDiagnosticRunNetworkTest => 'Jalankan Tes Jaringan';

  @override
  String get relayDiagnosticBlossomServer => 'Server Blossom';

  @override
  String get relayDiagnosticTestAllEndpoints => 'Tes Semua Endpoint';

  @override
  String get relayDiagnosticStatus => 'Status';

  @override
  String get relayDiagnosticUrl => 'URL';

  @override
  String get relayDiagnosticError => 'Kesalahan';

  @override
  String get relayDiagnosticFunnelCakeApi => 'FunnelCake API';

  @override
  String get relayDiagnosticBaseUrl => 'URL Dasar';

  @override
  String get relayDiagnosticSummary => 'Ringkasan';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount OK (rata-rata ${avgMs}ms)';
  }

  @override
  String get relayDiagnosticRetestAll => 'Tes Ulang Semua';

  @override
  String get relayDiagnosticRetrying => 'Mencoba lagi...';

  @override
  String get relayDiagnosticRetryConnection => 'Coba Sambung Ulang';

  @override
  String get relayDiagnosticTroubleshooting => 'Pemecahan Masalah';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• Status hijau = Terhubung dan bekerja\n• Status merah = Koneksi gagal\n• Kalau tes jaringan gagal, cek koneksi internet\n• Kalau relay dikonfigurasi tapi tidak terhubung, ketuk \"Coba Sambung Ulang\"\n• Screenshot layar ini untuk debugging';

  @override
  String get relayDiagnosticAllEndpointsHealthy => 'Semua endpoint REST sehat!';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      'Beberapa endpoint REST gagal - lihat detail di atas';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    return 'Ditemukan $count event video di database';
  }

  @override
  String get relayDiagnosticQueryFailed => 'Query gagal. Silakan coba lagi.';

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    return 'Terhubung ke $count relay!';
  }

  @override
  String get relayDiagnosticFailedToConnect =>
      'Gagal terhubung ke relay mana pun';

  @override
  String get relayDiagnosticConnectionRetryFailed =>
      'Percobaan koneksi ulang gagal. Silakan coba lagi.';

  @override
  String get relayDiagnosticConnectedAuthenticated =>
      'Terhubung & Terautentikasi';

  @override
  String get relayDiagnosticConnectedOnly => 'Terhubung';

  @override
  String get relayDiagnosticNotConnected => 'Tidak terhubung';

  @override
  String get relayDiagnosticNoRelaysConfigured =>
      'Tidak ada relay yang dikonfigurasi';

  @override
  String get relayDiagnosticFailed => 'Gagal';

  @override
  String get notificationSettingsTitle => 'Notifikasi';

  @override
  String get notificationSettingsResetTooltip => 'Reset ke bawaan';

  @override
  String get notificationSettingsTypes => 'Jenis Notifikasi';

  @override
  String get notificationSettingsLikes => 'Suka';

  @override
  String get notificationSettingsLikesSubtitle =>
      'Saat ada yang menyukai videomu';

  @override
  String get notificationSettingsComments => 'Komentar';

  @override
  String get notificationSettingsCommentsSubtitle =>
      'Saat ada yang mengomentari videomu';

  @override
  String get notificationSettingsFollows => 'Pengikut';

  @override
  String get notificationSettingsFollowsSubtitle => 'Saat ada yang mengikutimu';

  @override
  String get notificationSettingsMentions => 'Sebutan';

  @override
  String get notificationSettingsMentionsSubtitle => 'Saat kamu disebut';

  @override
  String get notificationSettingsReposts => 'Repost';

  @override
  String get notificationSettingsRepostsSubtitle =>
      'Saat ada yang me-repost videomu';

  @override
  String get notificationSettingsNewPosts => 'Vine Baru';

  @override
  String get notificationSettingsNewPostsSubtitle =>
      'Saat orang yang kamu pantau memposting';

  @override
  String get notificationSettingsActions => 'Aksi';

  @override
  String get notificationSettingsMarkAllAsRead => 'Tandai Semua Sudah Dibaca';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle =>
      'Tandai semua notifikasi sudah dibaca';

  @override
  String get notificationSettingsAllMarkedAsRead =>
      'Semua notifikasi ditandai sudah dibaca';

  @override
  String get notificationSettingsMarkAllAsReadFailed =>
      'Gagal menandai semua sudah dibaca';

  @override
  String get notificationSettingsResetToDefaults =>
      'Pengaturan direset ke bawaan';

  @override
  String get notificationSettingsAbout => 'Tentang Notifikasi';

  @override
  String get notificationSettingsAboutDescription =>
      'Notifikasi ditenagai oleh protokol Nostr. Pembaruan real-time bergantung pada koneksimu ke relay Nostr. Beberapa notifikasi mungkin tertunda.';

  @override
  String get safetySettingsWhatYouSee => 'YANG KAMU LIHAT';

  @override
  String get safetySettingsWhatYouPublish => 'YANG KAMU PUBLIKASIKAN';

  @override
  String get safetySettingsShowDivineHostedOnly =>
      'Hanya tampilkan video yang di-host Divine';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle =>
      'Sembunyikan video yang disajikan dari host media lain';

  @override
  String get safetySettingsModeration => 'MODERASI';

  @override
  String get safetySettingsBlockedUsers => 'PENGGUNA DIBLOKIR';

  @override
  String get safetySettingsAgeVerification => 'VERIFIKASI USIA';

  @override
  String get safetySettingsAgeConfirmation =>
      'Saya konfirmasi saya berusia 18 tahun atau lebih';

  @override
  String get safetySettingsAgeRequired =>
      'Diperlukan untuk melihat konten dewasa';

  @override
  String get safetySettingsAgeLockedForMinor => 'Terkunci untuk akunmu';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle =>
      'Layanan moderasi resmi (aktif secara bawaan)';

  @override
  String get safetySettingsPeopleIFollow => 'Orang yang saya ikuti';

  @override
  String get safetySettingsPeopleIFollowSubtitle =>
      'Berlangganan label dari orang yang kamu ikuti';

  @override
  String get safetySettingsAddCustomLabeler => 'Tambah Labeler Kustom';

  @override
  String get safetySettingsAddCustomLabelerHint => 'Masukkan npub...';

  @override
  String get safetySettingsAddCustomLabelerListTitle => 'Tambah labeler kustom';

  @override
  String get safetySettingsRemoveLabeler => 'Hapus labeler';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle =>
      'Masukkan alamat npub';

  @override
  String get safetySettingsNoBlockedUsers => 'Tidak ada pengguna yang diblokir';

  @override
  String get safetySettingsUnblock => 'Buka Blokir';

  @override
  String get safetySettingsUserUnblocked => 'Pengguna dibuka blokirnya';

  @override
  String get safetySettingsCancel => 'Batal';

  @override
  String get safetySettingsAdd => 'Tambah';

  @override
  String get analyticsTitle => 'Analitik Kreator';

  @override
  String get analyticsDiagnosticsTooltip => 'Diagnostik';

  @override
  String get analyticsDiagnosticsSemanticLabel => 'Toggle diagnostik';

  @override
  String get analyticsRetry => 'Coba Lagi';

  @override
  String get analyticsUnableToLoad => 'Tidak bisa memuat analitik.';

  @override
  String get analyticsServerUnavailable =>
      'Creator analytics is having server trouble. Please try again in a moment.';

  @override
  String get analyticsConnectionIssue =>
      'Creator analytics could not connect. Check your connection and try again.';

  @override
  String get analyticsSignInRequired => 'Masuk untuk melihat analitik kreator.';

  @override
  String get analyticsViewDataUnavailable =>
      'Data tontonan saat ini tidak tersedia dari relay untuk postingan ini. Metrik suka/komentar/repost masih akurat.';

  @override
  String get analyticsViewDataTitle => 'Data Tontonan';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return 'Diperbarui $time • Skor menggunakan suka, komentar, repost, dan tontonan/loop dari Funnelcake jika tersedia.';
  }

  @override
  String get analyticsVideos => 'Video';

  @override
  String get analyticsViews => 'Tontonan';

  @override
  String get analyticsInteractions => 'Interaksi';

  @override
  String get analyticsEngagement => 'Keterlibatan';

  @override
  String get analyticsFollowers => 'Pengikut';

  @override
  String get analyticsAvgPerPost => 'Rata-rata/Postingan';

  @override
  String get analyticsInteractionMix => 'Komposisi Interaksi';

  @override
  String get analyticsLikes => 'Suka';

  @override
  String get analyticsComments => 'Komentar';

  @override
  String get analyticsReposts => 'Repost';

  @override
  String get analyticsPerformanceHighlights => 'Sorotan Performa';

  @override
  String get analyticsMostViewed => 'Paling banyak ditonton';

  @override
  String get analyticsMostDiscussed => 'Paling banyak dibahas';

  @override
  String get analyticsMostReposted => 'Paling banyak di-repost';

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
    return '$count komentar';
  }

  @override
  String analyticsRepostsCount(int countValue, String count) {
    return '$count repost';
  }

  @override
  String get analyticsTopContent => 'Konten Teratas';

  @override
  String get analyticsPublishPrompt =>
      'Publikasikan beberapa video untuk melihat peringkat.';

  @override
  String get analyticsEngagementRateExplainer =>
      'Sisi kanan % = Tingkat Keterlibatan (interaksi dibagi tontonan).';

  @override
  String get analyticsEngagementRateNoViews =>
      'Tingkat Keterlibatan butuh data tontonan; nilai tampil sebagai N/A sampai tontonan tersedia.';

  @override
  String get analyticsEngagementLabel => 'Keterlibatan';

  @override
  String get analyticsViewsUnavailable => 'tontonan tidak tersedia';

  @override
  String analyticsInteractionsCount(int countValue, String count) {
    return '$count interaksi';
  }

  @override
  String get analyticsPostAnalytics => 'Analitik Postingan';

  @override
  String get analyticsOpenPost => 'Buka Postingan';

  @override
  String get analyticsRecentDailyInteractions => 'Interaksi Harian Terbaru';

  @override
  String get analyticsNoActivityYet => 'Belum ada aktivitas di rentang ini.';

  @override
  String get analyticsDailyInteractionsExplainer =>
      'Interaksi = suka + komentar + repost berdasarkan tanggal postingan.';

  @override
  String get analyticsDailyBarExplainer =>
      'Panjang batang relatif terhadap hari tertinggimu di jendela ini.';

  @override
  String get analyticsAudienceSnapshot => 'Snapshot Audiens';

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
      'Rincian sumber/geo/waktu audiens akan terisi saat Funnelcake menambah endpoint analitik audiens.';

  @override
  String get analyticsRetention => 'Retensi';

  @override
  String get analyticsRetentionWithViews =>
      'Kurva retensi dan rincian waktu tonton akan muncul setelah retensi per detik/per bucket tiba dari Funnelcake.';

  @override
  String get analyticsRetentionWithoutViews =>
      'Data retensi tidak tersedia sampai analitik tontonan+waktu tonton dikembalikan oleh Funnelcake.';

  @override
  String get analyticsDiagnostics => 'Diagnostik';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return 'Total video: $count';
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
    return 'Dihidrasi (massal): $count';
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
  String get analyticsDiagnosticsUseFixture => 'Pakai data fixture';

  @override
  String get analyticsNa => 'N/A';

  @override
  String get authCreateNewAccount => 'Buat akun Divine baru';

  @override
  String get authCreateNewAccountShort => 'Buat akun baru';

  @override
  String get authSignInDifferentAccount => 'Masuk dengan akun yang berbeda';

  @override
  String get authUseAnotherAccount => 'Pakai akun lain';

  @override
  String authContinueAs(String displayName) {
    return 'Lanjut sebagai $displayName';
  }

  @override
  String get authRecoveryDraftsOwner =>
      'Draf dan klip kamu tersimpan untuk akun ini';

  @override
  String get authRecoveryOtherAccountWarning =>
      'Masuk di sini akan menyembunyikan draf dan klip tersebut';

  @override
  String get authTermsPrefix =>
      'Dengan memilih salah satu opsi di bawah, kamu mengonfirmasi bahwa usiamu minimal 16 tahun (atau sudah menyelesaikan ';

  @override
  String get authTermsAgeAuthorizationCta => 'otorisasi usia Divine';

  @override
  String get authTermsAfterAgeAuthorization => ') dan menyetujui ';

  @override
  String get authTermsOfService => 'Ketentuan Layanan';

  @override
  String get authPrivacyPolicy => 'Kebijakan Privasi';

  @override
  String get authTermsAnd => ', dan ';

  @override
  String get authSafetyStandards => 'Standar Keamanan';

  @override
  String get authAmberNotInstalled => 'Aplikasi Amber tidak terpasang';

  @override
  String get authAmberConnectionFailed => 'Gagal terhubung dengan Amber';

  @override
  String get authPasswordResetSent =>
      'Jika akun dengan email itu ada, tautan reset kata sandi telah dikirim.';

  @override
  String get authSignInTitle => 'Masuk';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authPasswordLabel => 'Kata Sandi';

  @override
  String get authConfirmPasswordLabel => 'Konfirmasi kata sandi';

  @override
  String get authEmailRequired => 'Email wajib diisi';

  @override
  String get authEmailInvalid => 'Masukkan email yang valid';

  @override
  String get authPasswordRequired => 'Kata sandi wajib diisi';

  @override
  String get authConfirmPasswordRequired => 'Konfirmasikan kata sandi Anda';

  @override
  String get authPasswordsDoNotMatch => 'Kata sandi tidak cocok';

  @override
  String get authForgotPassword => 'Lupa kata sandi?';

  @override
  String get authImportNostrKey => 'Impor kunci Nostr';

  @override
  String get authConnectSignerApp => 'Hubungkan dengan aplikasi signer';

  @override
  String get authSignInWithAmber => 'Masuk dengan Amber';

  @override
  String get authSignInWithBrowserExtension => 'Masuk dengan ekstensi peramban';

  @override
  String get authNip07ConnectionFailed =>
      'Tidak dapat terhubung ke ekstensi peramban Anda.';

  @override
  String get authNip07ExtensionNotFound =>
      'Tidak ditemukan ekstensi peramban. Pasang Alby, nos2x, atau ekstensi lain yang kompatibel dengan NIP-07.';

  @override
  String get authSignInOptionsTitle => 'Opsi masuk';

  @override
  String get authInfoEmailPasswordTitle => 'Email & Kata Sandi';

  @override
  String get authInfoEmailPasswordDescription =>
      'Masuk dengan akun Divine-mu. Kalau kamu mendaftar dengan email dan kata sandi, gunakan di sini.';

  @override
  String get authInfoImportNostrKeyDescription =>
      'Sudah punya identitas Nostr? Impor kunci pribadi nsec-mu dari klien lain.';

  @override
  String get authInfoSignerAppTitle => 'Aplikasi Signer';

  @override
  String get authInfoSignerAppDescription =>
      'Hubungkan menggunakan signer jarak jauh yang kompatibel dengan NIP-46 seperti nsecBunker untuk keamanan kunci yang lebih baik.';

  @override
  String get authInfoAmberTitle => 'Amber';

  @override
  String get authInfoAmberDescription =>
      'Gunakan aplikasi signer Amber di Android untuk mengelola kunci Nostr-mu dengan aman.';

  @override
  String get authInfoBrowserExtensionTitle => 'Ekstensi Peramban';

  @override
  String get authInfoBrowserExtensionDescription =>
      'Masuk dengan ekstensi peramban NIP-07 seperti Alby atau nos2x. Kunci Anda tetap di ekstensi — Divine tidak pernah melihatnya.';

  @override
  String get authSignInErrorInvalidCredentials =>
      'Email atau kata sandi salah. Coba lagi.';

  @override
  String get authSignInErrorEmailNotVerified =>
      'Verifikasi emailmu sebelum masuk — cek kotak masuk untuk tautannya.';

  @override
  String get authSignInErrorInvalidEmail =>
      'Itu sepertinya bukan alamat email yang valid.';

  @override
  String get authSignInErrorNetwork =>
      'Tidak dapat menjangkau server. Periksa koneksimu dan coba lagi.';

  @override
  String get authSignInErrorGeneric => 'Ada yang salah. Coba lagi.';

  @override
  String get authSignInOptionsHintPrefix =>
      'Tidak yakin bagaimana kamu masuk terakhir kali? ';

  @override
  String get authSignInOptionsHintCta => 'Lihat semua opsi masuk';

  @override
  String get authCreateAccountTitle => 'Buat akun';

  @override
  String get authBackToInviteCode => 'Kembali ke kode undangan';

  @override
  String get authUseDivineNoBackup => 'Pakai Divine tanpa backup';

  @override
  String get authSkipConfirmTitle => 'Satu hal lagi...';

  @override
  String get authSkipConfirmKeyCreated =>
      'Kamu masuk! Kami akan membuat kunci aman yang menjalankan akun Divine-mu.';

  @override
  String get authSkipConfirmKeyOnly =>
      'Tanpa email, kuncimu adalah satu-satunya cara Divine mengetahui akun ini milikmu.';

  @override
  String get authSkipConfirmRecommendEmail =>
      'Kamu bisa mengakses kuncimu di aplikasi, tapi kalau kamu bukan orang teknis, kami menyarankan menambahkan email dan kata sandi sekarang. Ini memudahkan masuk dan memulihkan akunmu kalau kamu kehilangan atau mereset perangkat ini.';

  @override
  String get authAddEmailPassword => 'Tambah email & kata sandi';

  @override
  String get authUseThisDeviceOnly => 'Pakai perangkat ini saja';

  @override
  String get authCompleteRegistration => 'Lengkapi pendaftaranmu';

  @override
  String get authVerifying => 'Memverifikasi...';

  @override
  String get authVerificationLinkSent => 'Kami mengirim tautan verifikasi ke:';

  @override
  String get authClickVerificationLink =>
      'Silakan klik tautan di emailmu untuk\nmenyelesaikan pendaftaran.';

  @override
  String get authPleaseWaitVerifying =>
      'Mohon tunggu sementara kami memverifikasi emailmu...';

  @override
  String get authWaitingForVerification => 'Menunggu verifikasi';

  @override
  String get authOpenEmailApp => 'Buka aplikasi email';

  @override
  String get authVerificationPinPrompt =>
      'Atau masukkan kode 6 digit dari emailmu';

  @override
  String get authVerificationPinFieldLabel => 'Kode 6 digit';

  @override
  String get authVerificationPinSubmit => 'Verifikasi kode';

  @override
  String get authVerificationResendPrompt => 'Belum menerimanya?';

  @override
  String get authVerificationResend => 'Kirim ulang';

  @override
  String authVerificationResendCooldown(String time) {
    return 'Kirim ulang dalam $time';
  }

  @override
  String get authVerificationResendFailed =>
      'Kami tidak bisa mengirim ulang emailnya. Coba lagi.';

  @override
  String get authVerificationResendExpired =>
      'Pendaftaran itu sudah kedaluwarsa. Mulai lagi untuk mendapat kode baru.';

  @override
  String get authVerificationResendUnavailable =>
      'Pengiriman ulang belum tersedia sekarang. Pakai kode 6 digit dari email yang sudah kami kirim.';

  @override
  String get authVerificationPollingStopped =>
      'Kami berhenti mengecek untukmu. Masukkan kode 6 digit dari emailmu untuk menyelesaikan proses masuk.';

  @override
  String get authWelcomeToDivine => 'Selamat datang di Divine!';

  @override
  String get authEmailVerified => 'Emailmu telah diverifikasi.';

  @override
  String get authSigningYouIn => 'Memasukkanmu';

  @override
  String get authErrorTitle => 'Waduh.';

  @override
  String get authVerificationFailed =>
      'Kami gagal memverifikasi emailmu.\nSilakan coba lagi.';

  @override
  String get authStartOver => 'Mulai ulang';

  @override
  String get authEmailVerifiedLogin =>
      'Email diverifikasi! Silakan login untuk melanjutkan.';

  @override
  String get authVerificationLinkExpired =>
      'Tautan verifikasi ini sudah tidak berlaku.';

  @override
  String get authVerificationConnectionError =>
      'Tidak bisa memverifikasi email. Silakan cek koneksimu dan coba lagi.';

  @override
  String get authWaitlistConfirmTitle => 'Kamu masuk!';

  @override
  String authWaitlistUpdatesAt(String email) {
    return 'Kami akan membagikan pembaruan di $email.\nSaat kode undangan lebih banyak tersedia, kami akan mengirimnya untukmu.';
  }

  @override
  String get authOk => 'OK';

  @override
  String get authTryAgain => 'Coba lagi';

  @override
  String get authContactSupport => 'Hubungi dukungan';

  @override
  String authCouldNotOpenEmail(String email) {
    return 'Tidak bisa membuka $email';
  }

  @override
  String get authAddInviteCode => 'Tambahkan kode undanganmu';

  @override
  String get authInviteCodeLabel => 'Kode undangan';

  @override
  String get authEnterYourCode => 'Masukkan kodemu';

  @override
  String get authNext => 'Lanjut';

  @override
  String get authJoinWaitlist => 'Gabung daftar tunggu';

  @override
  String get authJoinWaitlistTitle => 'Gabung daftar tunggu';

  @override
  String get authJoinWaitlistDescription =>
      'Bagikan emailmu dan kami akan mengirim pembaruan saat akses terbuka.';

  @override
  String get authJoinWaitlistNewsletterOptIn =>
      'Kirimi aku inspirasi dari Divine';

  @override
  String get authInviteAccessHelp => 'Bantuan akses undangan';

  @override
  String get authGeneratingConnection => 'Membuat koneksi...';

  @override
  String get authConnectedAuthenticating => 'Terhubung! Mengautentikasi...';

  @override
  String get authConnectionTimedOut => 'Koneksi kedaluwarsa';

  @override
  String get authApproveConnection =>
      'Pastikan kamu menyetujui koneksi di aplikasi signer-mu.';

  @override
  String get authConnectionCancelled => 'Koneksi dibatalkan';

  @override
  String get authConnectionCancelledMessage => 'Koneksi dibatalkan.';

  @override
  String get authConnectionFailed => 'Koneksi gagal';

  @override
  String get authUnknownError => 'Terjadi kesalahan yang tidak diketahui.';

  @override
  String get authNostrConnectStartFailed =>
      'Tidak bisa menghubungi signer. Periksa koneksi kamu dan coba lagi.';

  @override
  String get authNostrConnectInvalidSession =>
      'Tautan koneksi ini sudah tidak valid lagi. Buat yang baru.';

  @override
  String get authNostrConnectSetupFailed =>
      'Hampir selesai — kami belum berhasil menyelesaikan proses masukmu. Coba lagi.';

  @override
  String get authUrlCopied => 'URL disalin ke clipboard';

  @override
  String get authConnectToDivine => 'Hubungkan ke Divine';

  @override
  String get authPasteBunkerUrl => 'Tempel URL bunker://';

  @override
  String get authBunkerUrlHint => 'URL bunker://';

  @override
  String get authInvalidBunkerUrl =>
      'URL bunker tidak valid. Harus dimulai dengan bunker://';

  @override
  String get authScanSignerApp =>
      'Scan dengan aplikasi\nsigner-mu untuk terhubung.';

  @override
  String authWaitingForConnection(int seconds) {
    return 'Menunggu koneksi... ${seconds}d';
  }

  @override
  String get authCopyUrl => 'Salin URL';

  @override
  String get authShare => 'Bagikan';

  @override
  String get authAddBunker => 'Tambah bunker';

  @override
  String get authCompatibleSignerApps => 'Aplikasi Signer yang kompatibel';

  @override
  String get authFailedToConnect => 'Gagal terhubung';

  @override
  String get authResetPasswordTitle => 'Reset Kata Sandi';

  @override
  String get authResetPasswordSubtitle =>
      'Masukkan kata sandi barumu. Harus minimal 8 karakter.';

  @override
  String get authNewPasswordLabel => 'Kata Sandi Baru';

  @override
  String get authConfirmNewPasswordLabel => 'Konfirmasi kata sandi baru';

  @override
  String get authPasswordTooShort => 'Kata sandi harus minimal 8 karakter';

  @override
  String get authPasswordResetSuccess =>
      'Reset kata sandi berhasil. Silakan login.';

  @override
  String get authPasswordResetFailed => 'Reset kata sandi gagal';

  @override
  String get authUnexpectedError =>
      'Terjadi kesalahan tak terduga. Silakan coba lagi.';

  @override
  String get authUpdatePassword => 'Perbarui kata sandi';

  @override
  String get authSecureAccountTitle => 'Amankan akun';

  @override
  String get authUnableToAccessKeys =>
      'Tidak bisa mengakses kuncimu. Silakan coba lagi.';

  @override
  String get authRegistrationFailed => 'Pendaftaran gagal';

  @override
  String get authRegistrationComplete =>
      'Pendaftaran selesai. Silakan cek emailmu.';

  @override
  String get authSecureAccountAlreadyRegistered =>
      'Looks like an account already exists. Try a different email, or sign in to the existing account with this email address. If neither works, contact support.';

  @override
  String get authFailedToSendResetEmail => 'Gagal mengirim email reset.';

  @override
  String get authSending => 'Mengirim...';

  @override
  String get authSignInButton => 'Masuk';

  @override
  String get authVerificationErrorTimeout =>
      'Verifikasi kedaluwarsa. Silakan coba daftar lagi.';

  @override
  String get authVerificationErrorMissingCode =>
      'Verifikasi gagal — kode otorisasi hilang.';

  @override
  String get authVerificationErrorPollFailed =>
      'Verifikasi gagal. Silakan coba lagi.';

  @override
  String get authVerificationErrorNetworkExchange =>
      'Kesalahan jaringan saat masuk. Silakan coba lagi.';

  @override
  String get authVerificationErrorOAuthExchange =>
      'Verifikasi gagal. Silakan coba daftar lagi.';

  @override
  String get authVerificationErrorSignInFailed =>
      'Masuk gagal. Silakan coba login manual.';

  @override
  String get authVerificationEmailAlreadyRegistered =>
      'Email ini sudah terdaftar. Masuk saja.';

  @override
  String get authVerificationErrorPinInvalid =>
      'Kode itu tidak cocok. Periksa lagi dan coba lagi.';

  @override
  String get authVerificationErrorPinExpired =>
      'Kode itu sudah kedaluwarsa. Ketuk kirim ulang untuk mendapatkan yang baru.';

  @override
  String get authVerificationErrorPinLocked =>
      'Terlalu banyak percobaan. Ketuk kirim ulang untuk mendapatkan kode baru.';

  @override
  String get authVerificationErrorPinFailed =>
      'Kami tidak bisa memverifikasi kode itu. Silakan coba lagi.';

  @override
  String get authVerificationErrorPinUnavailable =>
      'Input kode sedang tidak tersedia. Ketuk tautan di emailmu, atau kirim ulang untuk mendapatkan kode baru.';

  @override
  String get authInviteCodeErrorMalformed =>
      'Masukkan kode undangan seperti ABCD-EFGH.';

  @override
  String get authInviteCodeErrorNotFound =>
      'Kode undangan itu sepertinya tidak valid.';

  @override
  String get authInviteCodeErrorAlreadyUsed =>
      'Kode undangan itu sudah dipakai atau dicabut.';

  @override
  String get authInviteGateErrorCreatorFull =>
      'Undangan kreator ini sudah habis';

  @override
  String get authInviteGateErrorUnavailable =>
      'Kode undangan itu tidak tersedia. Gabung ke daftar tunggu dan kami akan mengirim undangan begitu ada tempat.';

  @override
  String get authInviteGateErrorCheckFailed =>
      'Kami tidak bisa memeriksa kode itu. Coba lagi.';

  @override
  String get authInviteGateErrorUnknown =>
      'Ada yang salah. Coba lagi dengan kode undanganmu.';

  @override
  String get authInviteErrorAlreadyUsed =>
      'Kode undangan itu sudah tidak tersedia. Kembali ke kode undanganmu, gabung daftar tunggu, atau hubungi dukungan.';

  @override
  String get authInviteErrorInvalid =>
      'Kode undangan itu tidak bisa digunakan sekarang. Kembali ke kode undanganmu, gabung daftar tunggu, atau hubungi dukungan.';

  @override
  String get authInviteErrorTemporary =>
      'Kami tidak bisa mengkonfirmasi undanganmu sekarang. Kembali ke kode undanganmu dan coba lagi, atau hubungi dukungan.';

  @override
  String get authInviteErrorUnknown =>
      'Kami tidak bisa mengaktifkan undanganmu. Kembali ke kode undanganmu, gabung daftar tunggu, atau hubungi dukungan.';

  @override
  String get shareSheetSave => 'Simpan';

  @override
  String get shareSheetRemoveFromSaved => 'Hapus dari tersimpan';

  @override
  String get shareSheetSaveToGallery => 'Simpan ke Galeri';

  @override
  String get shareSheetSaveWithWatermark => 'Simpan dengan Watermark';

  @override
  String get shareSheetSaveVideo => 'Simpan Video';

  @override
  String get shareSheetAddToClips => 'Tambahkan ke klip';

  @override
  String get shareSheetNameClipTitle => 'Beri nama klip ini';

  @override
  String get shareSheetNameClipSubtitle =>
      'Pilih nama yang mudah kamu kenali di pustakamu.';

  @override
  String get shareSheetClipTitleLabel => 'Judul klip';

  @override
  String get shareSheetSaveClip => 'Simpan klip';

  @override
  String shareSheetSavedClipToClips(String title) {
    return '\"$title\" disimpan ke klip';
  }

  @override
  String get shareSheetUntitledClip => 'Klip tanpa judul';

  @override
  String get shareSheetAddToClipsFailed => 'Tidak dapat menambahkan ke klip';

  @override
  String get shareSheetAddToList => 'Tambah ke Daftar';

  @override
  String get shareSheetCopy => 'Salin';

  @override
  String get shareSheetShareVia => 'Bagikan via';

  @override
  String get shareSheetEventJson => 'Event JSON';

  @override
  String get shareSheetEventId => 'ID Event';

  @override
  String get shareSheetMoreActions => 'Aksi lainnya';

  @override
  String get shareSheetCrosspost => 'Crosspost';

  @override
  String get crosspostSheetTitle => 'Crosspost video ini';

  @override
  String get crosspostSheetSubtitle =>
      'Kirim ke platform yang terhubung ke akunmu. Posting bisa butuh beberapa menit.';

  @override
  String get crosspostSubmit => 'Crosspost';

  @override
  String get crosspostStatusQueued => 'Dalam antrean';

  @override
  String get crosspostStatusUploading => 'Mengunggah';

  @override
  String get crosspostStatusProcessing => 'Memproses';

  @override
  String get crosspostStatusPosted => 'Diposting';

  @override
  String get crosspostStatusFailed => 'Gagal';

  @override
  String get crosspostStatusSkipped => 'Dilewati';

  @override
  String get crosspostStatusNeedsReauth => 'Perlu koneksi ulang';

  @override
  String get crosspostViewPost => 'Lihat postingan';

  @override
  String crosspostReconnectPrompt(String platform) {
    return 'Hubungkan ulang $platform di pengaturan crossposting untuk tetap bisa memposting.';
  }

  @override
  String get crosspostReconnect => 'Hubungkan ulang';

  @override
  String get crosspostErrorNotOwner =>
      'Hanya video milikmu yang bisa di-crosspost.';

  @override
  String get crosspostErrorNotEligible =>
      'Video ini tidak memenuhi syarat untuk crossposting.';

  @override
  String get crosspostErrorNotConnected => 'Platform itu belum terhubung.';

  @override
  String get crosspostErrorUnauthorized =>
      'Hubungkan ulang akunmu, lalu coba lagi.';

  @override
  String get crosspostErrorNetwork =>
      'Tidak dapat menjangkau crossposter. Coba lagi sebentar lagi.';

  @override
  String get crosspostFailedGeneric => 'Crosspost gagal.';

  @override
  String get crosspostStillWorking =>
      'Masih diproses. Kamu bisa menutup ini — posting berlanjut di latar belakang.';

  @override
  String get crosspostDone => 'Selesai';

  @override
  String get watermarkDownloadSavedToCameraRoll => 'Disimpan ke Camera Roll';

  @override
  String get watermarkDownloadShare => 'Bagikan';

  @override
  String get watermarkDownloadDone => 'Selesai';

  @override
  String get watermarkDownloadPhotosAccessNeeded => 'Butuh Akses Foto';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      'Untuk menyimpan video, izinkan akses Foto di Pengaturan.';

  @override
  String get watermarkDownloadOpenSettings => 'Buka Pengaturan';

  @override
  String get watermarkDownloadNotNow => 'Nanti Saja';

  @override
  String get watermarkDownloadFailed => 'Unduhan Gagal';

  @override
  String get watermarkDownloadDismiss => 'Tutup';

  @override
  String get watermarkDownloadStageDownloading => 'Mengunduh Video';

  @override
  String get watermarkDownloadStageWatermarking => 'Menambahkan Watermark';

  @override
  String get watermarkDownloadStageSaving => 'Menyimpan ke Camera Roll';

  @override
  String get watermarkDownloadStageDownloadingDesc =>
      'Mengambil video dari jaringan...';

  @override
  String get watermarkDownloadStageWatermarkingDesc =>
      'Menerapkan watermark Divine...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      'Menyimpan video ber-watermark ke camera roll-mu...';

  @override
  String get shareMenuBookmarks => 'Bookmark';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    return '$count set ikuti tersedia';
  }

  @override
  String get peopleListsAddToList => 'Tambahkan ke daftar';

  @override
  String get peopleListsSheetTitle => 'Tambahkan ke daftar';

  @override
  String get peopleListsEmptyTitle => 'Belum ada daftar';

  @override
  String get peopleListsEmptySubtitle =>
      'Buat daftar untuk mulai mengelompokkan orang.';

  @override
  String get peopleListsCreateList => 'Buat daftar';

  @override
  String get peopleListsNewListTitle => 'Daftar baru';

  @override
  String get peopleListsRouteTitle => 'Daftar orang';

  @override
  String get peopleListsListNameLabel => 'Nama daftar';

  @override
  String get peopleListsListNameHint => 'Teman dekat';

  @override
  String get peopleListsCreateButton => 'Buat';

  @override
  String get peopleListsAddPeopleTitle => 'Tambahkan orang';

  @override
  String get peopleListsAddPeopleTooltip => 'Tambahkan orang';

  @override
  String get peopleListsAddPeopleSemanticLabel => 'Tambahkan orang ke daftar';

  @override
  String get peopleListsListNotFoundTitle => 'Daftar tidak ditemukan';

  @override
  String get peopleListsListNotFoundSubtitle =>
      'Daftar tidak ditemukan. Mungkin sudah dihapus.';

  @override
  String get peopleListsListDeletedSubtitle =>
      'Daftar ini mungkin sudah dihapus.';

  @override
  String get peopleListsNoPeopleTitle => 'Tidak ada orang dalam daftar ini';

  @override
  String get peopleListsNoPeopleSubtitle => 'Tambahkan orang untuk memulai';

  @override
  String get peopleListsNoVideosTitle => 'Belum ada video';

  @override
  String get peopleListsNoVideosSubtitle =>
      'Video dari anggota daftar akan muncul di sini';

  @override
  String get peopleListsNoVideosAvailable => 'Tidak ada video tersedia';

  @override
  String get peopleListsFailedToLoadVideos => 'Gagal memuat video';

  @override
  String get peopleListsVideoNotAvailable => 'Video tidak tersedia';

  @override
  String get peopleListsBackToGridTooltip => 'Kembali ke tampilan kisi';

  @override
  String get peopleListsErrorLoadingVideos => 'Kesalahan saat memuat video';

  @override
  String get peopleListsNoPeopleToAdd =>
      'Tidak ada orang yang tersedia untuk ditambahkan.';

  @override
  String peopleListsAddToListName(String name) {
    return 'Tambahkan ke $name';
  }

  @override
  String get peopleListsAddPeopleSearchHint => 'Cari orang';

  @override
  String get peopleListsAddPeopleError =>
      'Tidak dapat memuat orang. Silakan coba lagi.';

  @override
  String get peopleListsAddPeopleRetry => 'Coba lagi';

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
      other: 'Di $count daftar',
    );
    return '$_temp0';
  }

  @override
  String peopleListsRemoveConfirmTitle(String name) {
    return 'Hapus $name?';
  }

  @override
  String get peopleListsRemoveConfirmBody =>
      'Mereka akan dihapus dari daftar ini.';

  @override
  String get peopleListsRemove => 'Hapus';

  @override
  String peopleListsRemovedFromList(String name) {
    return '$name dihapus dari daftar';
  }

  @override
  String get peopleListsUndo => 'Batalkan';

  @override
  String peopleListsProfileLongPressHint(String name) {
    return 'Profil untuk $name. Tekan lama untuk menghapus.';
  }

  @override
  String peopleListsViewProfileHint(String name) {
    return 'Lihat profil untuk $name';
  }

  @override
  String get shareMenuEditVideo => 'Ubah Video';

  @override
  String get shareMenuDeleteVideo => 'Hapus Video';

  @override
  String shareMenuVideoCount(int count) {
    return '$count video';
  }

  @override
  String get shareMenuDeleteConfirmation =>
      'Ini akan menghapus video ini secara permanen dari Divine. Video ini mungkin masih muncul di klien Nostr pihak ketiga yang menggunakan relay lain.';

  @override
  String get shareMenuCancel => 'Batal';

  @override
  String get shareMenuDelete => 'Hapus';

  @override
  String get shareMenuDeleteFailedNotInitialized =>
      'Penghapusan belum siap. Coba lagi sebentar lagi.';

  @override
  String get shareMenuDeleteFailedNotOwner =>
      'Kamu cuma bisa menghapus video milikmu sendiri.';

  @override
  String get shareMenuDeleteFailedNotAuthenticated =>
      'Masuk lagi, lalu coba hapus.';

  @override
  String get shareMenuDeleteFailedCouldNotSign =>
      'Tidak bisa menandatangani permintaan hapus. Coba lagi.';

  @override
  String get shareMenuDeleteFailedRelayRejected =>
      'Relay tidak menerima permintaan hapus ini. Coba lagi sebentar lagi.';

  @override
  String get shareMenuDeleteFailedAccountRestricted =>
      'Your account is restricted, so this delete request couldn\'t be sent. Contact support for help deleting it.';

  @override
  String get shareMenuDeleteFailedRelayNoResponse =>
      'Relay tidak bisa dihubungi. Periksa koneksimu dan coba lagi.';

  @override
  String get shareMenuDeletePartiallyConfirmed =>
      'Terhapus. Tidak semua relay mengonfirmasi, jadi ini mungkin masih muncul di aplikasi lain.';

  @override
  String get shareMenuDeleteFailedGeneric =>
      'Tidak bisa menghapus video ini. Coba lagi.';

  @override
  String get shareMenuUpdate => 'Perbarui';

  @override
  String get shareMenuChangeCover => 'Ubah Sampul';

  @override
  String get shareMenuVideoUpdated => 'Video berhasil diperbarui';

  @override
  String shareMenuVideoUpdatedWithInviteFailures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count undangan kolaborator tidak terkirim.',
      one: '1 undangan kolaborator tidak terkirim.',
    );
    return 'Video diperbarui, tetapi $_temp0';
  }

  @override
  String get videoUpdateErrorNotAuthenticated =>
      'Masuk lagi, lalu coba perbarui.';

  @override
  String get videoUpdateErrorNoPlayableVideo =>
      'Video ini tidak punya sumber yang bisa diputar, jadi tidak bisa diedit.';

  @override
  String get videoUpdateErrorCouldNotSign =>
      'Gagal menandatangani pembaruan. Coba lagi.';

  @override
  String get videoUpdateErrorPublishRejected =>
      'Relay tidak menerima pembaruan. Coba lagi sebentar lagi.';

  @override
  String get videoUpdateErrorGeneric =>
      'Gagal memperbarui video ini. Coba lagi.';

  @override
  String get shareMenuOriginalVideoUnavailable =>
      'Couldn\'t load the original video. Try again in a moment.';

  @override
  String get shareMenuDeleteVideoQuestion => 'Hapus Video?';

  @override
  String get shareMenuDeleteCleanupInProgress => 'Menghapus video…';

  @override
  String get shareMenuDeleteCleanupConfirmed => 'Video dihapus.';

  @override
  String get shareMenuDeleteCleanupDelayed =>
      'Video dihapus. Mungkin perlu waktu hingga video menghilang dari semua tempat.';

  @override
  String get shareMenuDeleteCleanupFailed =>
      'Video dihapus, tetapi kami tidak dapat menghapus semua salinannya. Hubungi dukungan.';

  @override
  String get authSessionExpired =>
      'Sesimu sudah kedaluwarsa. Silakan masuk lagi.';

  @override
  String get authAccountRestoreFailed =>
      'We couldn\'t unlock that account on this device. Sign in again.';

  @override
  String get authSignInFailed => 'Gagal masuk. Silakan coba lagi.';

  @override
  String get webAuthNotSupportedSecureMode =>
      'Autentikasi web tidak didukung dalam mode aman. Silakan pakai aplikasi seluler untuk manajemen kunci yang aman.';

  @override
  String get webAuthEnterBunkerUri => 'Silakan masukkan URI bunker';

  @override
  String get webAuthConnectTitle => 'Hubungkan ke Divine';

  @override
  String get webAuthChooseMethod => 'Pilih metode autentikasi Nostr pilihanmu';

  @override
  String get webAuthBrowserExtension => 'Ekstensi Browser';

  @override
  String get webAuthRecommended => 'DIREKOMENDASIKAN';

  @override
  String get webAuthNsecBunker => 'nsec bunker';

  @override
  String get webAuthConnectRemoteSigner => 'Hubungkan ke signer jarak jauh';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => 'Tempel dari clipboard';

  @override
  String get webAuthConnectToBunker => 'Hubungkan ke Bunker';

  @override
  String get webAuthNewToNostr => 'Baru di Nostr?';

  @override
  String get webAuthNostrHelp =>
      'Pasang ekstensi browser seperti Alby atau nos2x untuk pengalaman termudah, atau pakai nsec bunker untuk penandatanganan jarak jauh yang aman.';

  @override
  String get soundsTitle => 'Suara';

  @override
  String get soundsSearchHint => 'Cari suara...';

  @override
  String get soundsSearchResults => 'Hasil Pencarian';

  @override
  String get soundsNoSoundsFound => 'Tidak ada suara ditemukan';

  @override
  String get soundsNoSoundsFoundDescription => 'Coba istilah pencarian lain';

  @override
  String get soundsSavedToLibrary => 'Disimpan ke Suara';

  @override
  String get soundsAlreadySavedToLibrary => 'Sudah ada di Suara';

  @override
  String get soundsSavedLibraryTitle => 'Suara Saya';

  @override
  String get soundsSavedEmptyTitle => 'Belum ada suara yang tersimpan';

  @override
  String get soundsSavedEmptyDescription =>
      'Ketuk Gunakan Suara pada video untuk menyimpannya di sini.';

  @override
  String get soundsRemoveSavedSound => 'Hapus suara';

  @override
  String get savedSoundSaveAction => 'Simpan';

  @override
  String get savedSoundPausePreviewAction => 'Jeda pratinjau';

  @override
  String get savedSoundResumePreviewAction => 'Lanjutkan pratinjau';

  @override
  String get savedSoundDetailsSheetTitle => 'Detail suara';

  @override
  String get savedSoundRemoveConfirmTitle => 'Hapus suara ini?';

  @override
  String get savedSoundRemoveConfirmMessage =>
      'Suara ini hilang dari pustakamu, tapi kamu bisa menyimpannya lagi dari video mana pun yang memakainya.';

  @override
  String get soundsRemovedFromLibrary => 'Dihapus dari Suara';

  @override
  String get soundsSaveFailed => 'Suara itu gagal disimpan. Coba lagi.';

  @override
  String get soundsRemoveFailed => 'Suara itu gagal dihapus. Coba lagi.';

  @override
  String get soundSyncStatusSyncing => 'Menyinkronkan suaramu…';

  @override
  String get soundSyncStatusSynced => 'Suara sudah terbaru';

  @override
  String get soundSyncStatusFailed =>
      'Tidak bisa menyinkronkan suaramu. Kami akan coba lagi.';

  @override
  String get soundSyncStatusLocked =>
      'Tidak bisa membuka pustaka tersinkronmu di perangkat ini.';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileMoreOptions => 'Opsi lainnya';

  @override
  String profileBlockedUser(String name) {
    return 'Memblokir $name';
  }

  @override
  String profileUnblockedUser(String name) {
    return 'Membuka blokir $name';
  }

  @override
  String profileUnfollowedUser(String name) {
    return 'Berhenti mengikuti $name';
  }

  @override
  String get profileFeedError =>
      'Tidak dapat menjangkau server. Periksa koneksimu dan coba lagi.';

  @override
  String get profileFeedLoadMoreError =>
      'Video lainnya gagal dimuat. Tarik untuk menyegarkan.';

  @override
  String get notificationsTabAll => 'Semua';

  @override
  String get notificationsTabLikes => 'Suka';

  @override
  String get notificationsTabComments => 'Komentar';

  @override
  String get notificationsTabFollows => 'Pengikut';

  @override
  String get notificationsTabReposts => 'Repost';

  @override
  String get notificationsFailedToLoad => 'Gagal memuat notifikasi';

  @override
  String get notificationsRetry => 'Coba Lagi';

  @override
  String get notificationsRefreshError =>
      'Gagal menyegarkan — menampilkan yang tersedia';

  @override
  String get notificationsUnreadPrefix => 'Notifikasi belum dibaca';

  @override
  String notificationsBadgeUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notifikasi belum dibaca',
      one: '1 notifikasi belum dibaca',
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
    return 'Thumbnail video untuk $title';
  }

  @override
  String get notificationsVideoThumbnail => 'Thumbnail video';

  @override
  String get notificationsInviteSingular =>
      'Kamu punya 1 undangan untuk dibagikan ke teman!';

  @override
  String notificationsInvitePlural(int count) {
    return 'Kamu punya $count undangan untuk dibagikan ke teman!';
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
  String get feedFailedToLoadVideos => 'Gagal memuat video';

  @override
  String get feedRetry => 'Coba Lagi';

  @override
  String get feedNoFollowedUsers =>
      'Tidak ada pengguna yang diikuti.\nIkuti seseorang untuk melihat video mereka di sini.';

  @override
  String get feedModeForYou => 'Untukmu';

  @override
  String get feedModeNew => 'Baru';

  @override
  String get feedModeFollowing => 'Mengikuti';

  @override
  String get feedModeClassics => 'Klasik';

  @override
  String feedModeSemanticLabel(String label) {
    return 'Mode feed: $label';
  }

  @override
  String videoAuthorSemanticLabel(String displayName) {
    return 'Pembuat video: $displayName';
  }

  @override
  String get videoAuthorAvatarSemanticLabel => 'Avatar pembuat';

  @override
  String get feedForYouEmpty =>
      'Feed Untuk Anda kamu kosong.\nJelajahi video dan ikuti kreator untuk membentuknya.';

  @override
  String get feedFollowingEmpty =>
      'Belum ada video dari orang yang kamu ikuti.\nTemukan kreator yang kamu suka dan ikuti mereka.';

  @override
  String get feedLatestEmpty =>
      'Belum ada video baru.\nCek lagi sebentar lagi.';

  @override
  String get feedClassicEmpty => 'Belum ada klasik.\nCek lagi sebentar lagi.';

  @override
  String get feedExploreVideos => 'Jelajahi Video';

  @override
  String get feedLoadingMore => 'Memuat lebih banyak video…';

  @override
  String get feedRefreshed => 'Feed disegarkan';

  @override
  String get uploadUploadingVideo => 'Mengunggah video';

  @override
  String get postPublishConfirmationTitle => 'Dipublikasikan ke profilmu';

  @override
  String get postPublishConfirmationView => 'Lihat';

  @override
  String get postPublishConfirmationShare => 'Bagikan';

  @override
  String get postPublishConfirmationThumbnailLabel =>
      'Thumbnail video yang baru saja kamu publikasikan';

  @override
  String get userSearchNoResults => 'Tidak ada pengguna ditemukan';

  @override
  String get userPickerFilterByNameHint => 'Filter berdasarkan nama...';

  @override
  String get userPickerSearchByNameHint => 'Cari berdasarkan nama...';

  @override
  String get userPickerClearSearchSemantics => 'Hapus pencarian';

  @override
  String userPickerAlreadyAddedSemantics(String name) {
    return '$name sudah ditambahkan';
  }

  @override
  String userPickerSelectSemantics(String name) {
    return 'Pilih $name';
  }

  @override
  String userPickerRemoveSelectionSemantics(String name) {
    return 'Hapus $name';
  }

  @override
  String get userPickerEmptyFollowListTitle => 'Kru kamu ada di luar sana';

  @override
  String get userPickerEmptyFollowListBody =>
      'Ikuti orang yang cocok dengan vibe kamu. Saat mereka follow balik, kalian bisa kolaborasi.';

  @override
  String get userPickerGoBack => 'Kembali';

  @override
  String get userPickerTypeNameToSearch => 'Ketik nama untuk mencari';

  @override
  String get userPickerUnavailable =>
      'Pencarian pengguna tidak tersedia. Coba lagi nanti.';

  @override
  String get userPickerSearchFailedTryAgain => 'Pencarian gagal. Coba lagi.';

  @override
  String get forgotPasswordTitle => 'Reset Kata Sandi';

  @override
  String get forgotPasswordDescription =>
      'Masukkan alamat emailmu dan kami akan mengirim tautan untuk mereset kata sandimu.';

  @override
  String get forgotPasswordEmailLabel => 'Alamat Email';

  @override
  String get forgotPasswordCancel => 'Batal';

  @override
  String get forgotPasswordSendLink => 'Email Tautan Reset';

  @override
  String get ageVerificationContentWarning => 'Peringatan Konten';

  @override
  String get ageVerificationTitle => 'Verifikasi Usia';

  @override
  String get ageVerificationAdultDescription =>
      'Konten ini ditandai kemungkinan mengandung materi dewasa. Kamu harus berusia 18 tahun atau lebih untuk melihatnya.';

  @override
  String get ageVerificationCreationDescription =>
      'Untuk menggunakan kamera dan membuat konten, kamu harus berusia minimal 16 tahun.';

  @override
  String get ageVerificationAdultQuestion =>
      'Apakah kamu berusia 18 tahun atau lebih?';

  @override
  String get ageVerificationCreationQuestion =>
      'Apakah kamu berusia 16 tahun atau lebih?';

  @override
  String get ageVerificationNo => 'Tidak';

  @override
  String get ageVerificationYes => 'Ya';

  @override
  String get navHome => 'Beranda';

  @override
  String get navExplore => 'Jelajahi';

  @override
  String get navInbox => 'Kotak Masuk';

  @override
  String get navProfile => 'Profil';

  @override
  String get navMyProfile => 'Profilku';

  @override
  String get navNotifications => 'Notifikasi';

  @override
  String get navOpenCamera => 'Buka kamera';

  @override
  String get navExploreClassics => 'Klasik';

  @override
  String get navExploreNewVideos => 'Video Baru';

  @override
  String get navExploreTrending => 'Trending';

  @override
  String get navExploreForYou => 'Untukmu';

  @override
  String get navExploreLists => 'Daftar';

  @override
  String get routeErrorTitle => 'Kesalahan';

  @override
  String get routeInvalidHashtag => 'Hashtag tidak valid';

  @override
  String get routeInvalidConversationId => 'ID percakapan tidak valid';

  @override
  String get routeInvalidRequestId => 'ID permintaan tidak valid';

  @override
  String get routeInvalidListId => 'ID daftar tidak valid';

  @override
  String get routeInvalidUserId => 'ID pengguna tidak valid';

  @override
  String get routeInvalidVideoId => 'ID video tidak valid';

  @override
  String get routeInvalidSoundId => 'ID suara tidak valid';

  @override
  String get routeInvalidCategory => 'Kategori tidak valid';

  @override
  String get routeNoVideosToDisplay => 'Tidak ada video untuk ditampilkan';

  @override
  String get routeGoHome => 'Ke beranda';

  @override
  String get routeInvalidProfileId => 'ID profil tidak valid';

  @override
  String get routeUnknownPath => 'Halaman itu tidak ada di aplikasi.';

  @override
  String get routeDefaultListName => 'Daftar';

  @override
  String get supportTitle => 'Pusat Bantuan';

  @override
  String get supportContactSupport => 'Hubungi Dukungan';

  @override
  String get supportContactSupportSubtitle =>
      'Mulai percakapan atau lihat pesan sebelumnya';

  @override
  String get supportReportBug => 'Laporkan Bug';

  @override
  String get supportReportBugSubtitle => 'Masalah teknis dengan aplikasi';

  @override
  String get supportRequestFeature => 'Minta Fitur';

  @override
  String get supportRequestFeatureSubtitle =>
      'Sarankan perbaikan atau fitur baru';

  @override
  String get supportSaveLogs => 'Simpan Log';

  @override
  String get supportSaveLogsSubtitle =>
      'Ekspor log ke file untuk pengiriman manual';

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
  String get supportFaqSubtitle => 'Pertanyaan & jawaban umum';

  @override
  String get supportFamily => 'Divine Family';

  @override
  String get supportFamilySubtitle =>
      'Membantu orang tua dan remaja membangun kebiasaan sehat online';

  @override
  String get supportKids => 'Divine Kids';

  @override
  String get supportKidsSubtitle => 'Cara kami menangani akun berdasarkan usia';

  @override
  String get supportProofMode => 'ProofMode';

  @override
  String get supportProofModeSubtitle =>
      'Pelajari tentang verifikasi dan keaslian';

  @override
  String get supportLoginRequired => 'Login untuk menghubungi dukungan';

  @override
  String get supportExportingLogs => 'Mengekspor log...';

  @override
  String get supportExportLogsFailed => 'Gagal mengekspor log';

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
  String get supportRevealLogsAction => 'Tampilkan di folder';

  @override
  String get supportChatNotAvailable => 'Chat dukungan tidak tersedia';

  @override
  String get supportCouldNotOpenMessages => 'Tidak bisa membuka pesan dukungan';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return 'Tidak bisa membuka $pageName';
  }

  @override
  String get reportWhyReporting => 'Kenapa kamu melaporkan konten ini?';

  @override
  String get reportPolicyNotice =>
      'Divine akan menindak laporan konten dalam 24 jam dengan menghapus konten dan mengeluarkan pengguna yang memberikan konten yang melanggar.';

  @override
  String get reportBlockUser => 'Blokir pengguna ini';

  @override
  String get reportCancel => 'Batal';

  @override
  String get reportSubmit => 'Laporkan';

  @override
  String get reportSelectReason =>
      'Silakan pilih alasan untuk melaporkan konten ini';

  @override
  String get reportOtherRequiresDetails =>
      'Jelaskan masalahnya kalau memilih Lainnya';

  @override
  String get reportDetailsRequired => 'Jelaskan masalahnya';

  @override
  String get reportDetailsTextOnly =>
      'Hanya teks — foto dan GIF tidak dapat dilampirkan di sini.';

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
  String get reportReasonSpam => 'Spam atau Konten Tidak Diinginkan';

  @override
  String get reportReasonSpamSubtitle =>
      'Konten yang tidak diinginkan atau berulang';

  @override
  String get reportReasonHarassment => 'Pelecehan, Perundungan, atau Ancaman';

  @override
  String get reportReasonHarassmentSubtitle =>
      'Balasan atau sebutan berbahaya dan tidak diinginkan';

  @override
  String get reportReasonViolence => 'Konten Kekerasan atau Ekstremis';

  @override
  String get reportReasonViolenceSubtitle =>
      'Konten kekerasan, ekstremis, atau berbahaya';

  @override
  String get reportReasonSexualContent => 'Konten Seksual atau Dewasa';

  @override
  String get reportReasonSexualContentSubtitle =>
      'Ketelanjangan, porno, atau konten eksplisit';

  @override
  String get reportReasonCopyright => 'Pelanggaran Hak Cipta';

  @override
  String get reportReasonCopyrightSubtitle =>
      'Penggunaan kekayaan intelektual tanpa izin';

  @override
  String get reportReasonFalseInfo => 'Informasi Salah';

  @override
  String get reportReasonFalseInfoSubtitle => 'Klaim menyesatkan atau palsu';

  @override
  String get reportReasonChildSafety => 'Pelanggaran Keselamatan Anak';

  @override
  String get reportReasonChildSafetySubtitle =>
      'Kekhawatiran umum tentang keselamatan anak di bawah umur';

  @override
  String get reportReasonCsam => 'Pelecehan seksual terhadap anak';

  @override
  String get reportReasonCsamSubtitle =>
      'Konten yang menggambarkan pelecehan seksual terhadap anak di bawah umur';

  @override
  String get reportReasonUnderageUser => 'Pengguna Tampak di Bawah 16 Tahun';

  @override
  String get reportReasonUnderageUserSubtitle =>
      'Pemilik akun tampak masih di bawah umur';

  @override
  String get reportReasonAiGenerated => 'Konten Dihasilkan AI';

  @override
  String get reportReasonAiGeneratedSubtitle =>
      'Konten yang diduga dibuat oleh AI';

  @override
  String get reportReasonOther => 'Pelanggaran Kebijakan Lainnya';

  @override
  String get reportReasonOtherSubtitle =>
      'Pelanggaran yang tidak tercantum di atas';

  @override
  String get reportFailed => 'Gagal melaporkan konten. Silakan coba lagi.';

  @override
  String get reportNotSent =>
      'Laporanmu tidak terkirim. Periksa koneksimu dan coba lagi.';

  @override
  String get reportReceivedTitle => 'Laporan Diterima';

  @override
  String get reportReceivedThankYou =>
      'Terima kasih sudah membantu menjaga Divine tetap aman.';

  @override
  String get reportReceivedReviewNotice =>
      'Tim kami akan meninjau laporanmu dan mengambil tindakan yang sesuai. Kamu mungkin menerima pembaruan via pesan langsung.';

  @override
  String get reportModerationDmDelayed =>
      'Kami tidak bisa menjangkau tim moderasi secara langsung saat ini, tapi laporanmu sudah kami terima dan akan ditinjau.';

  @override
  String get reportContactModeration => 'Kirim pesan ke tim moderasi';

  @override
  String get reportLearnMoreAt => 'Pelajari lebih lanjut di';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => 'Tutup';

  @override
  String get listAddToList => 'Tambah ke Daftar';

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
  String get listNewList => 'Daftar Baru';

  @override
  String get listDone => 'Selesai';

  @override
  String get listErrorLoading => 'Kesalahan memuat daftar';

  @override
  String listRemovedFrom(String name) {
    return 'Dihapus dari $name';
  }

  @override
  String listAddedTo(String name) {
    return 'Ditambahkan ke $name';
  }

  @override
  String get listCreateNewList => 'Buat Daftar Baru';

  @override
  String get listNewPeopleList => 'Daftar orang baru';

  @override
  String get listCollaboratorsNone => 'Tidak ada';

  @override
  String get listAddCollaboratorTitle => 'Tambah kolaborator';

  @override
  String get listCollaboratorSearchHint => 'Cari di Divine...';

  @override
  String get listNameLabel => 'Nama Daftar';

  @override
  String get listDescriptionLabel => 'Deskripsi (opsional)';

  @override
  String get listPublicList => 'Daftar Publik';

  @override
  String get listPublicListSubtitle =>
      'Orang lain bisa mengikuti dan melihat daftar ini';

  @override
  String get listPrivateListSubtitle =>
      'Videonya tetap privat. Nama, deskripsi, tag, dan sampul tetap terlihat.';

  @override
  String get listVisibilityPublic => 'Publik';

  @override
  String get listVisibilityPrivate => 'Privat';

  @override
  String get profileListsEmpty =>
      'Belum ada daftar. Bikin satu untuk loop yang mau kamu simpan bareng.';

  @override
  String get listEditTitle => 'Edit daftar';

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
  String get listShareAction => 'Bagikan daftar';

  @override
  String get listShareFailed => 'Daftar ini gagal dibagikan. Coba lagi.';

  @override
  String get listSave => 'Simpan';

  @override
  String get listContinue => 'Lanjut';

  @override
  String get listPrivateFull =>
      'This private list is full. Remove something to add more.';

  @override
  String get listUpdateFailed => 'Daftar ini gagal diperbarui. Coba lagi.';

  @override
  String get listMakePrivateTitle => 'Jadikan daftar ini privat?';

  @override
  String get listMakePrivateWarning =>
      'Videonya dienkripsi jadi cuma kamu yang bisa lihat. Nama, deskripsi, tag, dan sampul tetap terlihat, dan salinan yang sudah dibagikan bisa tetap ada.';

  @override
  String get listMakePublicTitle => 'Jadikan daftar ini publik?';

  @override
  String get listMakePublicWarning =>
      'Siapa pun yang punya tautannya bisa melihat daftar ini dan videonya.';

  @override
  String listShareText(String name, String url) {
    return 'Lihat $name di Divine: $url';
  }

  @override
  String listShareSubject(String name) {
    return '$name di Divine';
  }

  @override
  String get listCancel => 'Batal';

  @override
  String get listCreate => 'Buat';

  @override
  String get listCreateFailed => 'Gagal membuat daftar';

  @override
  String get keyManagementTitle => 'Kunci Nostr';

  @override
  String get keyManagementWhatAreKeys => 'Apa itu kunci Nostr?';

  @override
  String get keyManagementExplanation =>
      'Identitas Nostr-mu adalah pasangan kunci kriptografis:\n\n• Kunci publikmu (npub) seperti username-mu - bagikan dengan bebas\n• Kunci privatmu (nsec) seperti kata sandimu - jaga kerahasiaannya!\n\nnsec-mu memungkinkanmu mengakses akunmu di aplikasi Nostr mana pun.';

  @override
  String get keyManagementImportTitle => 'Impor Kunci yang Ada';

  @override
  String get keyManagementImportSubtitle =>
      'Sudah punya akun Nostr? Tempel kunci privatmu (nsec) untuk mengaksesnya di sini.';

  @override
  String get keyManagementImportButton => 'Impor Kunci';

  @override
  String get keyManagementImportWarning =>
      'Ini akan mengganti kuncimu saat ini!';

  @override
  String get keyManagementBackupTitle => 'Backup Kuncimu';

  @override
  String get keyManagementBackupSubtitle =>
      'Simpan kunci privatmu (nsec) untuk menggunakan akunmu di aplikasi Nostr lain.';

  @override
  String get keyManagementCopyNsec => 'Salin Kunci Privatku (nsec)';

  @override
  String get keyManagementNeverShare =>
      'Jangan pernah bagikan nsec-mu ke siapa pun!';

  @override
  String get keyManagementKeycastRemoteSigning =>
      'Kuncimu tersimpan di layanan login Divine, bukan di perangkat ini. Konfirmasi kata sandimu dan kami akan mengambilnya.';

  @override
  String get keyManagementKeycastPasswordPrompt =>
      'Kuncimu disimpan oleh layanan login Divine. Masukkan kata sandi akunmu dan kami akan mengambilnya.';

  @override
  String get keyManagementKeycastCopyKey => 'Salin kunci';

  @override
  String get keyManagementKeycastCopyBlocked =>
      'Perangkatmu memblokir penyalinan, jadi kuncimu tidak sampai ke papan klip.';

  @override
  String get keyManagementKeycastWrongPassword =>
      'Kata sandi tidak cocok. Coba lagi.';

  @override
  String get keyManagementKeycastTooManyAttempts =>
      'Terlalu banyak percobaan. Tutup ini dan mulai lagi.';

  @override
  String get keyManagementKeycastRateLimited =>
      'Terlalu banyak permintaan kunci. Tunggu beberapa menit lalu coba lagi.';

  @override
  String get keyManagementKeycastSignInAgain =>
      'Sesimu telah berakhir. Masuk lagi untuk menyalin kuncimu.';

  @override
  String get keyManagementKeycastEmailUnverified =>
      'Verifikasi alamat emailmu sebelum menyalin kunci.';

  @override
  String get keyManagementKeycastDenied =>
      'Divine mengelola kunci akun ini, jadi kunci tidak bisa disalin di sini.';

  @override
  String get keyManagementKeycastNoKey =>
      'Tidak ada kunci yang tercatat untuk akun ini.';

  @override
  String get keyManagementKeycastGenericFailure =>
      'Layanan login tidak dapat dihubungi. Silakan coba lagi.';

  @override
  String get keyManagementRestrictedTitle => 'Kuncimu dikelola oleh Divine';

  @override
  String get keyManagementRestrictedBody =>
      'Demi keamanan akunmu, pencadangan kunci dan impor kunci lain tidak tersedia di sini.';

  @override
  String get keyManagementPasteKey => 'Silakan tempel kunci privatmu';

  @override
  String get keyManagementInvalidFormat =>
      'Format kunci tidak valid. Harus dimulai dengan \"nsec1\"';

  @override
  String get keyManagementConfirmImportTitle => 'Impor Kunci Ini?';

  @override
  String get keyManagementConfirmImportBody =>
      'Ini akan mengganti identitasmu saat ini dengan yang diimpor.\n\nKunci saat ini akan hilang kecuali kamu sudah mem-backup-nya.';

  @override
  String get keyManagementImportConfirm => 'Impor';

  @override
  String get keyManagementImportSuccess => 'Kunci berhasil diimpor!';

  @override
  String get keyManagementImportFailed =>
      'Gagal mengimpor kunci. Silakan coba lagi.';

  @override
  String get keyManagementExportSuccess =>
      'Kunci privat disalin ke clipboard!\n\nSimpan di tempat yang aman.';

  @override
  String get keyManagementExportFailed =>
      'Gagal mengekspor kunci. Silakan coba lagi.';

  @override
  String get keyManagementYourPublicKeyLabel => 'Kunci publikmu (npub)';

  @override
  String get keyManagementCopyPublicKeyTooltip => 'Salin kunci publik';

  @override
  String get keyManagementPublicKeyCopied => 'Kunci publik tersalin';

  @override
  String get saveOriginalSavedToCameraRoll => 'Disimpan ke Camera Roll';

  @override
  String get saveOriginalShare => 'Bagikan';

  @override
  String get saveOriginalDone => 'Selesai';

  @override
  String get saveOriginalPhotosAccessNeeded => 'Butuh Akses Foto';

  @override
  String get saveOriginalPhotosAccessMessage =>
      'Untuk menyimpan video, izinkan akses Foto di Pengaturan.';

  @override
  String get saveOriginalOpenSettings => 'Buka Pengaturan';

  @override
  String get saveOriginalNotNow => 'Nanti Saja';

  @override
  String get saveOriginalDownloadFailed => 'Unduhan Gagal';

  @override
  String get saveOriginalDismiss => 'Tutup';

  @override
  String get saveOriginalDownloadingVideo => 'Mengunduh Video';

  @override
  String get saveOriginalSavingToCameraRoll => 'Menyimpan ke Camera Roll';

  @override
  String get saveOriginalFetchingVideo => 'Mengambil video dari jaringan...';

  @override
  String get saveOriginalSavingVideo =>
      'Menyimpan video asli ke camera roll-mu...';

  @override
  String get soundTitle => 'Suara';

  @override
  String get soundOriginalSound => 'Suara asli';

  @override
  String get soundVideosUsingThisSound => 'Video yang memakai suara ini';

  @override
  String get soundSourceVideo => 'Video sumber';

  @override
  String get soundNoVideosYet => 'Belum ada video';

  @override
  String get soundBeFirstToUse => 'Jadilah yang pertama memakai suara ini!';

  @override
  String get soundFailedToLoadVideos => 'Gagal memuat video';

  @override
  String get soundRetry => 'Coba Lagi';

  @override
  String get soundVideosUnavailable => 'Video tidak tersedia';

  @override
  String get soundCouldNotLoadDetails => 'Tidak bisa memuat detail video';

  @override
  String get soundPreview => 'Pratinjau';

  @override
  String get soundStop => 'Berhenti';

  @override
  String get soundUseSound => 'Pakai Suara';

  @override
  String get soundUntitled => 'Suara tanpa judul';

  @override
  String get soundStopPreview => 'Hentikan pratinjau';

  @override
  String soundPreviewSemanticLabel(String title) {
    return 'Pratinjau $title';
  }

  @override
  String soundViewDetailsSemanticLabel(String title) {
    return 'Lihat detail untuk $title';
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
      'Tidak bisa pratinjau suara - tidak ada audio tersedia';

  @override
  String get soundPreviewFailed =>
      'Gagal memutar pratinjau. Silakan coba lagi.';

  @override
  String get soundViewSource => 'Lihat sumber';

  @override
  String get soundCloseTooltip => 'Tutup';

  @override
  String get exploreNotExploreRoute => 'Bukan rute jelajah';

  @override
  String get legalTitle => 'Legal';

  @override
  String get legalTermsOfService => 'Ketentuan Layanan';

  @override
  String get legalTermsOfServiceSubtitle => 'Syarat dan ketentuan penggunaan';

  @override
  String get legalPrivacyPolicy => 'Kebijakan Privasi';

  @override
  String get legalPrivacyPolicySubtitle => 'Bagaimana kami menangani datamu';

  @override
  String get legalSafetyStandards => 'Standar Keamanan';

  @override
  String get legalSafetyStandardsSubtitle => 'Pedoman komunitas dan keamanan';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle => 'Kebijakan hak cipta dan takedown';

  @override
  String get legalOpenSourceLicenses => 'Lisensi Open Source';

  @override
  String get legalOpenSourceLicensesSubtitle => 'Atribusi paket pihak ketiga';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return 'Tidak bisa membuka $pageName';
  }

  @override
  String get categoryAction => 'Aksi';

  @override
  String get categoryAdventure => 'Petualangan';

  @override
  String get categoryAnimals => 'Hewan';

  @override
  String get categoryAnimation => 'Animasi';

  @override
  String get categoryArchitecture => 'Arsitektur';

  @override
  String get categoryArt => 'Seni';

  @override
  String get categoryAutomotive => 'Otomotif';

  @override
  String get categoryAwardShow => 'Ajang Penghargaan';

  @override
  String get categoryAwards => 'Penghargaan';

  @override
  String get categoryBaseball => 'Bisbol';

  @override
  String get categoryBasketball => 'Basket';

  @override
  String get categoryBeauty => 'Kecantikan';

  @override
  String get categoryBeverage => 'Minuman';

  @override
  String get categoryCars => 'Mobil';

  @override
  String get categoryCelebration => 'Perayaan';

  @override
  String get categoryCelebrities => 'Selebriti';

  @override
  String get categoryCelebrity => 'Selebriti';

  @override
  String get categoryCityscape => 'Pemandangan Kota';

  @override
  String get categoryComedy => 'Komedi';

  @override
  String get categoryConcert => 'Konser';

  @override
  String get categoryCooking => 'Memasak';

  @override
  String get categoryCostume => 'Kostum';

  @override
  String get categoryCrafts => 'Kerajinan';

  @override
  String get categoryCrime => 'Kriminal';

  @override
  String get categoryCulture => 'Budaya';

  @override
  String get categoryDance => 'Tari';

  @override
  String get categoryDiy => 'DIY';

  @override
  String get categoryDrama => 'Drama';

  @override
  String get categoryEducation => 'Pendidikan';

  @override
  String get categoryEmotional => 'Emosional';

  @override
  String get categoryEmotions => 'Emosi';

  @override
  String get categoryEntertainment => 'Hiburan';

  @override
  String get categoryEvent => 'Acara';

  @override
  String get categoryFamily => 'Keluarga';

  @override
  String get categoryFans => 'Penggemar';

  @override
  String get categoryFantasy => 'Fantasi';

  @override
  String get categoryFashion => 'Mode';

  @override
  String get categoryFestival => 'Festival';

  @override
  String get categoryFilm => 'Film';

  @override
  String get categoryFitness => 'Kebugaran';

  @override
  String get categoryFood => 'Makanan';

  @override
  String get categoryFootball => 'Football';

  @override
  String get categoryFurniture => 'Furnitur';

  @override
  String get categoryGaming => 'Game';

  @override
  String get categoryGolf => 'Golf';

  @override
  String get categoryGrooming => 'Perawatan Diri';

  @override
  String get categoryGuitar => 'Gitar';

  @override
  String get categoryHalloween => 'Halloween';

  @override
  String get categoryHealth => 'Kesehatan';

  @override
  String get categoryHockey => 'Hoki';

  @override
  String get categoryHoliday => 'Liburan';

  @override
  String get categoryHome => 'Rumah';

  @override
  String get categoryHomeImprovement => 'Renovasi Rumah';

  @override
  String get categoryHorror => 'Horor';

  @override
  String get categoryHospital => 'Rumah Sakit';

  @override
  String get categoryHumor => 'Humor';

  @override
  String get categoryInteriorDesign => 'Desain Interior';

  @override
  String get categoryInterview => 'Wawancara';

  @override
  String get categoryKids => 'Anak-anak';

  @override
  String get categoryLifestyle => 'Gaya Hidup';

  @override
  String get categoryMagic => 'Sulap';

  @override
  String get categoryMakeup => 'Makeup';

  @override
  String get categoryMedical => 'Medis';

  @override
  String get categoryMusic => 'Musik';

  @override
  String get categoryMystery => 'Misteri';

  @override
  String get categoryNature => 'Alam';

  @override
  String get categoryNews => 'Berita';

  @override
  String get categoryOutdoor => 'Luar Ruang';

  @override
  String get categoryParty => 'Pesta';

  @override
  String get categoryPeople => 'Orang';

  @override
  String get categoryPerformance => 'Pertunjukan';

  @override
  String get categoryPets => 'Hewan Peliharaan';

  @override
  String get categoryPolitics => 'Politik';

  @override
  String get categoryPrank => 'Prank';

  @override
  String get categoryPranks => 'Prank';

  @override
  String get categoryRealityShow => 'Reality Show';

  @override
  String get categoryRelationship => 'Hubungan';

  @override
  String get categoryRelationships => 'Hubungan';

  @override
  String get categoryRomance => 'Romansa';

  @override
  String get categorySchool => 'Sekolah';

  @override
  String get categoryScienceFiction => 'Fiksi Ilmiah';

  @override
  String get categorySelfie => 'Selfie';

  @override
  String get categoryShopping => 'Belanja';

  @override
  String get categorySkateboarding => 'Skateboard';

  @override
  String get categorySkincare => 'Perawatan Kulit';

  @override
  String get categorySoccer => 'Sepak Bola';

  @override
  String get categorySocialGathering => 'Pertemuan Sosial';

  @override
  String get categorySocialMedia => 'Media Sosial';

  @override
  String get categorySports => 'Olahraga';

  @override
  String get categoryTalkShow => 'Talk Show';

  @override
  String get categoryTech => 'Tek';

  @override
  String get categoryTechnology => 'Teknologi';

  @override
  String get categoryTelevision => 'Televisi';

  @override
  String get categoryToys => 'Mainan';

  @override
  String get categoryTransportation => 'Transportasi';

  @override
  String get categoryTravel => 'Jalan-jalan';

  @override
  String get categoryUrban => 'Urban';

  @override
  String get categoryViolence => 'Kekerasan';

  @override
  String get categoryVlog => 'Vlog';

  @override
  String get categoryVlogging => 'Vlogging';

  @override
  String get categoryWrestling => 'Gulat';

  @override
  String get profileSetupUploadStaged =>
      'Diunggah — ketuk Simpan untuk menerapkan';

  @override
  String inboxReportedUser(String displayName) {
    return '$displayName dilaporkan';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return '$displayName diblokir';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return '$displayName tidak diblokir lagi';
  }

  @override
  String get inboxRemovedConversation => 'Percakapan dihapus';

  @override
  String get inboxRestorePausedTitle =>
      'Sebagian chat belum selesai dipulihkan';

  @override
  String get conversationRestorePausedTitle =>
      'Chat ini belum selesai dipulihkan';

  @override
  String get inboxRestoreRetryAction => 'Coba lagi';

  @override
  String get inboxRestoringMessages => 'Memulihkan pesan Anda…';

  @override
  String get inboxEmptyTitle => 'Belum ada pesan';

  @override
  String get inboxEmptySubtitle => 'Tombol + tidak menggigit kok.';

  @override
  String get inboxLoadErrorTitle => 'Pesan gagal dimuat';

  @override
  String get inboxLoadErrorSubtitle => 'Periksa koneksimu dan coba lagi.';

  @override
  String get inboxFilterAll => 'Semua';

  @override
  String get inboxFilterUnread => 'Belum dibaca';

  @override
  String get dmBlockedThreadTitle => 'Kamu memblokir akun ini';

  @override
  String get dmBlockedThreadBody =>
      'Pesan tetap ada di sini agar kamu bisa membacanya atau membuat tangkapan layar. Buka blokir untuk membalas.';

  @override
  String get inboxFilterBlocked => 'Diblokir';

  @override
  String get inboxBlockedEmptyTitle => 'Tidak ada obrolan yang diblokir';

  @override
  String get inboxBlockedEmptySubtitle =>
      'Akun yang kamu blokir muncul di sini.';

  @override
  String get inboxBlockedNoMessages => 'Tidak ada pesan';

  @override
  String get inboxUnreadEmptyTitle => 'Semua sudah kamu baca';

  @override
  String get inboxUnreadEmptySubtitle => 'Tidak ada pesan yang belum dibaca.';

  @override
  String get inboxSearchHint => 'Cari pesan';

  @override
  String get inboxSupportRowTitle => 'Moderasi Divine';

  @override
  String get inboxSupportRowSubtitle =>
      'Bug, moderasi, urusan akun — kami mendengarkan.';

  @override
  String get inboxSearchEmptyTitle => 'Tidak ada hasil';

  @override
  String get inboxSearchEmptySubtitle => 'Coba nama atau kata lain.';

  @override
  String get inboxActionMute => 'Bisukan percakapan';

  @override
  String inboxActionReport(String displayName) {
    return 'Laporkan $displayName';
  }

  @override
  String inboxActionBlock(String displayName) {
    return 'Blokir $displayName';
  }

  @override
  String inboxActionUnblock(String displayName) {
    return 'Buka blokir $displayName';
  }

  @override
  String get inboxActionRemove => 'Hapus percakapan';

  @override
  String get inboxRemoveConfirmTitle => 'Hapus percakapan?';

  @override
  String inboxRemoveConfirmBody(String displayName) {
    return 'Ini menghapus percakapanmu dengan $displayName dari kotak masukmu. Jika dia mengirim pesan lagi, percakapan baru dimulai.';
  }

  @override
  String get inboxRemoveConfirmBodyGroup =>
      'Ini menghapus percakapan grup dari kotak masukmu. Jika ada yang mengirim pesan lagi ke grup, percakapan baru dimulai.';

  @override
  String get inboxRemoveConfirmConfirm => 'Hapus';

  @override
  String get inboxConversationMuted => 'Percakapan dibisukan';

  @override
  String get inboxConversationUnmuted => 'Bisu percakapan dibatalkan';

  @override
  String get inboxCollabInviteCardTitle => 'Undangan kolaborasi';

  @override
  String get inboxCollabInviteCardUntitledVideo => 'Video tanpa judul';

  @override
  String get clickableTextViewVideoLink => 'Lihat video';

  @override
  String get messageExternalLinkDialogTitle => 'Buka tautan eksternal?';

  @override
  String messageExternalLinkDialogBody(String url) {
    return 'Tautan ini menuju situs eksternal dan mungkin tidak aman:\n\n$url';
  }

  @override
  String get messageExternalLinkDialogOpen => 'Buka';

  @override
  String get inboxCollabInviteCoPostButton => 'Posting bersama';

  @override
  String get inboxCollabInviteNotMineButton => 'Bukan milik saya';

  @override
  String get inboxCollabInvitePreviewTitle => 'Undangan posting bersama';

  @override
  String inboxCollabInvitePreviewTitleFrom(String displayName) {
    return 'Undangan posting bersama dari $displayName';
  }

  @override
  String get inboxCollabInviteTimelineConsequence =>
      'Posting bersama menambahkan video ini ke timeline Anda sebagai kolaborasi.';

  @override
  String get inboxCollabInviteAcceptedStatus => 'Diterima';

  @override
  String get inboxCollabInviteIgnoredStatus => 'Diabaikan';

  @override
  String get inboxCollabInviteAcceptError => 'Tidak bisa menerima. Coba lagi.';

  @override
  String get inboxCollabInviteSentStatus => 'Undangan terkirim';

  @override
  String get inboxConversationCollabInvitePreview => 'Undangan kolaborasi';

  @override
  String collaboratorInviteDmBody(String title, String url) {
    return 'Kamu diundang untuk berkolaborasi di $title: $url\n\nOpen Divine to review and accept.';
  }

  @override
  String collaboratorInviteDmBodyUntitled(String url) {
    return 'Kamu diundang untuk berkolaborasi pada sebuah video: $url\n\nOpen Divine to review and accept.';
  }

  @override
  String videoPublishCollaboratorInviteWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count undangan kolaborator tidak terkirim.',
      one: '1 undangan kolaborator tidak terkirim.',
    );
    return 'Video terposting, tapi $_temp0';
  }

  @override
  String get dmSendNoRecipientMessage =>
      'Kami tidak tahu percakapan ini dengan siapa. Buka lagi dari kotak masuk.';

  @override
  String get dmSendBlockedMessage =>
      'Kamu hanya bisa mengirim pesan ke akun resmi Divine';

  @override
  String get dmSendBlockedRetiredMessage =>
      'Tidak ada yang membaca percakapan ini. Kirim pesan ke Divine Moderation saja.';

  @override
  String get dmDeletePendingLabel => 'Deleting for everyone';

  @override
  String get dmDeleteRefusedMessage => 'Gagal menghapus untuk semua orang.';

  @override
  String get dmDeleteRefusedDetails =>
      'Beberapa orang mungkin masih dapat melihat pesan ini.';

  @override
  String get dmRetiredThreadClosedTitle => 'Percakapan ini sudah ditutup.';

  @override
  String get messageRequestModerationNoticeCannotBeRemoved =>
      'Pemberitahuan Divine Moderation ini tidak dapat dihapus.';

  @override
  String get dmRetiredThreadClosedBody =>
      'Kami memindahkan Divine Moderation ke akun baru. Akun ini tidak dibaca lagi.';

  @override
  String get dmRetiredThreadOpenSupport => 'Kirim pesan ke Divine Moderation';

  @override
  String get dmSendTooLongMessage =>
      'That message is too long to send. Shorten it and try again.';

  @override
  String get dmSendFailedMessage => 'Pesan gagal dikirim';

  @override
  String get dmResendFailedMessage => 'Masih gagal dikirim';

  @override
  String get dmSendFailedSubtitle =>
      'Kirim ulang sekarang, atau berhenti mencoba.';

  @override
  String get dmSendFailedRetry => 'Coba Lagi';

  @override
  String get dmSendPartialMessage =>
      'Terkirim, tapi tidak tersinkron ke perangkat lainmu';

  @override
  String get dmConversationLoadError => 'Pesan tidak dapat dimuat';

  @override
  String get dmMessageInputHint => 'Tulis sesuatu…';

  @override
  String get dmMessageBubbleSentHint => 'Pesan terkirim';

  @override
  String get dmMessageBubbleReceivedHint => 'Pesan diterima';

  @override
  String get dmMessageBubbleLongPressHint => 'Tindakan pesan';

  @override
  String get dmMessageBubbleFailedTapHint => 'Kirim ulang atau hapus pesan ini';

  @override
  String get dmMessageActionCopyText => 'Salin teks';

  @override
  String get dmMessageActionCopyVideoUrl => 'Salin URL video';

  @override
  String get dmMessageActionDeleteForEveryone => 'Hapus untuk semua orang';

  @override
  String get dmMessageActionReport => 'Laporkan';

  @override
  String get dmMessageActionRetrySend => 'Kirim ulang';

  @override
  String get dmMessageActionCancelSend => 'Berhenti mencoba';

  @override
  String get dmReactionAddCustomA11yLabel => 'Tambahkan reaksi emoji kustom';

  @override
  String dmReelReplyComposerHint(String name) {
    return 'Kirim pesan ke $name…';
  }

  @override
  String get dmReelReplyComposerHintSelf => 'Balas diri sendiri…';

  @override
  String get dmReelReplyComposerSemanticLabel => 'Balas reel ini';

  @override
  String get dmReelReplyViewChat => 'Lihat obrolan';

  @override
  String get dmReelReplySentAnnouncement => 'Balasan terkirim';

  @override
  String dmReelReactionSentAnnouncement(String emoji) {
    return 'Bereaksi $emoji';
  }

  @override
  String get dmReelReplyFailed => 'Tidak dapat mengirim';

  @override
  String get dmReelReplyUnverified => 'Tidak dapat memastikan terkirim';

  @override
  String dmReactionChipOwnA11yLabel(String emoji) {
    return 'Reaksimu: $emoji';
  }

  @override
  String dmReactionChipOtherA11yLabel(String name, String emoji) {
    return '$name bereaksi dengan $emoji';
  }

  @override
  String dmReactionChipPendingA11yLabel(String emoji) {
    return 'Mengirim reaksi: $emoji';
  }

  @override
  String get dmReactionChipFailedA11yLabel =>
      'Reaksi gagal, ketuk dua kali untuk mencoba lagi';

  @override
  String get dmReactionChipRetryAnnouncement => 'Mencoba reaksi lagi';

  @override
  String dmReactionRemovalRefusedA11yLabel(String emoji) {
    return 'Couldn\'t remove your $emoji reaction. Double tap to try again';
  }

  @override
  String get dmReactionRemovalRefusedTitle => 'Couldn\'t remove your reaction.';

  @override
  String get dmReactionAddBlockedByRemoval =>
      'Selesaikan penghapusan reaksi sebelumnya sebelum menambahkan reaksi lain.';

  @override
  String get dmReactionRemovalRefusedDetails =>
      'Some people may still be able to see this reaction.';

  @override
  String get dmReactionsSheetTitle => 'Reaksi';

  @override
  String get dmReactionsViewA11yLabel => 'Lihat siapa yang bereaksi';

  @override
  String get dmReactionRemoveAction => 'Hapus';

  @override
  String get dmReactionRetryAction => 'Coba lagi';

  @override
  String get dmFormatBold => 'Tebal';

  @override
  String get dmFormatItalic => 'Miring';

  @override
  String get dmFormatStrikethrough => 'Coret';

  @override
  String get dmFormatCode => 'Kode';

  @override
  String get dmStatusFailed => 'Gagal mengirim';

  @override
  String get inboxConversationActionsSheetLabel => 'Tindakan percakapan';

  @override
  String inboxConversationTileLabel(String displayName) {
    return 'Percakapan dengan $displayName';
  }

  @override
  String inboxConversationTileLabelUnread(String displayName) {
    return 'Belum dibaca, Percakapan dengan $displayName';
  }

  @override
  String inboxGroupConversationTitle(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count orang lainnya',
    );
    return '$name dan $_temp0';
  }

  @override
  String get inboxConversationTileLongPressHint =>
      'Tampilkan tindakan percakapan';

  @override
  String exploreVideoId(String id) {
    return 'ID: $id';
  }

  @override
  String exploreVideoTitle(String title) {
    return 'Judul: $title';
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
      'Gagal memperbarui langganan. Silakan coba lagi.';

  @override
  String get discoverListsTitle => 'Jelajahi Daftar';

  @override
  String get discoverListsFailedToLoad => 'Gagal memuat daftar';

  @override
  String get discoverListsLoading => 'Mencari daftar publik...';

  @override
  String get discoverListsRelayTimeout =>
      'Relay tidak mengembalikan daftar tepat waktu. Coba lagi.';

  @override
  String get discoverListsServiceUnavailable => 'Layanan tidak tersedia.';

  @override
  String get discoverListsEmptyTitle => 'Tidak ada daftar publik';

  @override
  String get discoverListsEmptySubtitle => 'Cek lagi nanti untuk daftar baru';

  @override
  String get discoverListsByAuthorPrefix => 'oleh';

  @override
  String get curatedListEmptyTitle => 'Belum ada video di daftar ini';

  @override
  String get curatedListEmptySubtitle =>
      'Tambahkan beberapa video untuk memulai';

  @override
  String get curatedListLoadingVideos => 'Memuat video...';

  @override
  String get curatedListFailedToLoad => 'Gagal memuat daftar';

  @override
  String get curatedListVideoNotAvailable => 'Video tidak tersedia';

  @override
  String get curatedListActionsTooltip => 'Tindakan daftar';

  @override
  String get curatedListDeleteConfirmTitle => 'Hapus daftar?';

  @override
  String get curatedListDeleteConfirmBody =>
      'Ini menghapus daftar dari relay. Video di dalam daftar tidak akan dihapus.';

  @override
  String get curatedListDeletedSnack => 'Daftar dihapus';

  @override
  String get curatedListDeleteFailed => 'Tidak bisa menghapus daftar';

  @override
  String get peopleListsActionsTooltip => 'Tindakan daftar';

  @override
  String get listDeleteAction => 'Hapus daftar';

  @override
  String get peopleListsDeleteConfirmTitle => 'Hapus daftar?';

  @override
  String get peopleListsDeleteConfirmBody =>
      'Ini menghapus daftar untuk semua orang. Orang-orang di dalamnya tidak akan berhenti kamu ikuti.';

  @override
  String get peopleListsDeleteFailed => 'Tidak bisa menghapus daftar';

  @override
  String get commonRetry => 'Coba lagi';

  @override
  String get commonSomethingWentWrong => 'Terjadi kesalahan';

  @override
  String get commonDelete => 'Hapus';

  @override
  String get commonCancel => 'Batal';

  @override
  String get commonBack => 'Kembali';

  @override
  String get commonClose => 'Tutup';

  @override
  String get commonNotNow => 'Nanti Saja';

  @override
  String get commonLoading => 'Memuat';

  @override
  String get videoMetadataEditCoverFailedSnackbar =>
      'Tidak dapat memperbarui sampul. Coba lagi.';

  @override
  String get videoMetadataEditCoverSuccessAnnouncement => 'Sampul diperbarui';

  @override
  String get videoMetadataC2paMissingTitle =>
      'Posting tanpa verifikasi keaslian?';

  @override
  String get videoMetadataC2paMissingBody =>
      'Kami tidak dapat menambahkan kredensial konten, jadi video ini tidak akan dikonfirmasi sebagai buatan manusia. Buat ulang untuk mencoba lagi, atau posting apa adanya.';

  @override
  String get videoMetadataC2paMissingNote =>
      'Kredensial konten memerlukan koneksi internet.';

  @override
  String get videoMetadataC2paMissingNoteServiceUnavailable =>
      'Layanan kredensial konten tidak merespons. Ini bukan masalah koneksimu.';

  @override
  String get videoMetadataC2paMissingRegenerate => 'Buat ulang';

  @override
  String get videoMetadataC2paMissingSkip => 'Lewati';

  @override
  String get videoMetadataGenerationFailed => 'Pembuatan gagal';

  @override
  String get videoMetadataTags => 'Tag';

  @override
  String get videoMetadataExpiration => 'Kedaluwarsa';

  @override
  String get videoMetadataExpirationNotExpire => 'Tidak kedaluwarsa';

  @override
  String get videoMetadataExpirationOneDay => '1 hari';

  @override
  String get videoMetadataExpirationOneWeek => '1 minggu';

  @override
  String get videoMetadataExpirationOneMonth => '1 bulan';

  @override
  String get videoMetadataExpirationOneYear => '1 tahun';

  @override
  String get videoMetadataExpirationOneDecade => '1 dekade';

  @override
  String get videoMetadataContentWarnings => 'Peringatan Konten';

  @override
  String get videoEditorStickers => 'Stiker';

  @override
  String get trendingTitle => 'Trending';

  @override
  String get libraryDeleteConfirm => 'Hapus';

  @override
  String get libraryWebUnavailableHeadline =>
      'Perpustakaan ada di aplikasi seluler';

  @override
  String get libraryWebUnavailableDescription =>
      'Draf dan klip disimpan di perangkatmu — buka Divine di ponsel untuk mengelolanya.';

  @override
  String get libraryTabDrafts => 'Draf';

  @override
  String get libraryTabClips => 'Klip';

  @override
  String get libraryDeleteSelectedClipsTooltip => 'Hapus klip terpilih';

  @override
  String get libraryCloseSemanticLabel => 'Tutup pustaka';

  @override
  String get libraryStopSelectingClipsSemanticLabel => 'Berhenti memilih klip';

  @override
  String get librarySelectClipsSemanticLabel => 'Pilih klip';

  @override
  String get libraryGridSizeLabel => 'Ukuran kisi';

  @override
  String get libraryDisplayOptionsLabel => 'Urutan & ukuran kisi';

  @override
  String get libraryMoreActionsSemanticLabel => 'Tindakan pustaka lainnya';

  @override
  String libraryGridSizeColumns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kolom',
    );
    return '$_temp0';
  }

  @override
  String get librarySelect => 'Pilih';

  @override
  String get librarySortNewestCreation => 'Paling baru dibuat';

  @override
  String get librarySortOldestCreation => 'Paling lama dibuat';

  @override
  String get librarySortLongestClip => 'Klip terpanjang';

  @override
  String get librarySortShortestClip => 'Klip terpendek';

  @override
  String get librarySortSquareFirst => 'Persegi terlebih dahulu';

  @override
  String get librarySortVerticalFirst => 'Vertikal terlebih dahulu';

  @override
  String get libraryDeleteClipsWarning =>
      'Tindakan ini tidak bisa dibatalkan. File video akan dihapus permanen dari perangkatmu.';

  @override
  String get libraryPreparingVideo => 'Menyiapkan video...';

  @override
  String libraryCreateVideo(int count) {
    return 'Buat video ($count)';
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
    return '$successCount tersimpan, $failureCount gagal';
  }

  @override
  String libraryClipsSaveFailed(String destination) {
    return 'Tidak bisa menyimpan ke $destination';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return 'Izin ditolak untuk $destination';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klip dihapus',
      one: '1 klip dihapus',
    );
    return '$_temp0';
  }

  @override
  String get libraryClipsDeletedUndoLabel => 'Urungkan';

  @override
  String libraryTrashAutoDeletes(int daysLeft) {
    String _temp0 = intl.Intl.pluralLogic(
      daysLeft,
      locale: localeName,
      other: 'Akan dihapus otomatis dalam $daysLeft hari',
      one: 'Akan dihapus otomatis besok',
      zero: 'Akan dihapus otomatis hari ini',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts => 'Tidak bisa memuat draf';

  @override
  String get libraryCouldNotLoadClips => 'Tidak bisa memuat klip';

  @override
  String get libraryOpenErrorDescription =>
      'Ada masalah saat membuka perpustakaan. Coba lagi.';

  @override
  String get libraryNoDraftsYetTitle => 'Belum ada draf';

  @override
  String get libraryNoDraftsYetSubtitle =>
      'Video yang kamu simpan sebagai draf akan muncul di sini';

  @override
  String get libraryNoClipsYetTitle => 'Belum ada klip';

  @override
  String get libraryNoClipsYetSubtitle =>
      'Klip video yang kamu rekam akan muncul di sini';

  @override
  String get libraryDraftDeletedSnackbar => 'Draf dihapus';

  @override
  String get libraryDraftDeleteFailedSnackbar => 'Gagal menghapus draf';

  @override
  String get libraryDraftDuplicatedSnackbar => 'Draf diduplikat';

  @override
  String get libraryDraftDuplicateFailedSnackbar => 'Gagal menduplikat draf';

  @override
  String get libraryDraftInProgressBadge => 'Sedang berjalan';

  @override
  String get libraryDraftActionPost => 'Posting';

  @override
  String get libraryDraftActionEdit => 'Edit';

  @override
  String get libraryDraftActionDuplicate => 'Duplikat';

  @override
  String get libraryDraftActionDelete => 'Hapus draf';

  @override
  String libraryDraftCopyTitle(String title, int number) {
    return '$title (salinan $number)';
  }

  @override
  String get libraryDeleteDraftTitle => 'Hapus draf';

  @override
  String libraryDeleteDraftMessage(String title) {
    return 'Yakin ingin menghapus \"$title\"?';
  }

  @override
  String get libraryDeleteClipTitle => 'Hapus klip';

  @override
  String get libraryDeleteClipMessage => 'Yakin ingin menghapus klip ini?';

  @override
  String libraryClipDuration(String seconds) {
    return '$seconds dtk';
  }

  @override
  String get libraryRecordVideo => 'Rekam video';

  @override
  String videoClipSemanticLabel(String duration) {
    return 'Klip video, $duration detik';
  }

  @override
  String videoClipArchivedSemanticLabel(String label) {
    return 'Diarsipkan. $label';
  }

  @override
  String videoClipStopMotionSemanticLabel(String frames) {
    return 'Klip stop-motion, $frames';
  }

  @override
  String videoClipSemanticValueSelectedAtPosition(int position) {
    return 'Dipilih, nomor $position';
  }

  @override
  String get videoClipSemanticValueSelected => 'Dipilih';

  @override
  String get videoClipSemanticValueNotSelected => 'Tidak dipilih';

  @override
  String get videoClipSemanticHintDisabled => 'Dinonaktifkan';

  @override
  String get videoClipSemanticHintSelect =>
      'Ketuk untuk memilih, tekan lama untuk pratinjau';

  @override
  String get videoClipSemanticHintDeselect =>
      'Ketuk untuk membatalkan pilihan, tekan lama untuk pratinjau';

  @override
  String get routerInvalidCreator => 'Kreator tidak valid';

  @override
  String get routerInvalidHashtagRoute => 'Rute hashtag tidak valid';

  @override
  String get categoryGalleryCouldNotLoadVideos => 'Tidak dapat memuat video';

  @override
  String get categoryGalleryNoVideosInCategory =>
      'Tidak ada video di kategori ini';

  @override
  String get categoryGallerySortOptionsLabel => 'Opsi urutan kategori';

  @override
  String get categoryGallerySortHot => 'Populer';

  @override
  String get categoryGallerySortNew => 'Baru';

  @override
  String get categoryGallerySortClassic => 'Klasik';

  @override
  String get categoryGallerySortForYou => 'Untukmu';

  @override
  String get categoriesCouldNotLoadCategories => 'Tidak dapat memuat kategori';

  @override
  String get categoriesNoCategoriesAvailable => 'Tidak ada kategori tersedia';

  @override
  String get notificationsEmptyTitle => 'Belum ada aktivitas';

  @override
  String get notificationsEmptySubtitle =>
      'Saat orang berinteraksi dengan kontenmu, kamu akan melihatnya di sini';

  @override
  String get appsPermissionsTitle => 'Izin Integrasi';

  @override
  String get appsPermissionsRevoke => 'Cabut';

  @override
  String get appsPermissionsEmptyTitle => 'Tidak ada izin integrasi tersimpan';

  @override
  String get appsPermissionsEmptySubtitle =>
      'Integrasi yang disetujui akan muncul di sini setelah kamu mengingat persetujuan akses.';

  @override
  String nostrAppPermissionTitle(String appName) {
    return '$appName meminta persetujuanmu';
  }

  @override
  String get nostrAppPermissionDescription =>
      'Aplikasi ini meminta akses lewat sandbox tervalidasi Divine.';

  @override
  String get nostrAppPermissionOrigin => 'Asal';

  @override
  String get nostrAppPermissionMethod => 'Metode';

  @override
  String get nostrAppPermissionCapability => 'Kapabilitas';

  @override
  String get nostrAppPermissionEventKind => 'Jenis event';

  @override
  String get nostrAppPermissionAllow => 'Izinkan';

  @override
  String get appsDetailDefaultTitle => 'Aplikasi Terintegrasi';

  @override
  String get appsDetailNotFoundTitle => 'Integrasi tidak ditemukan';

  @override
  String get appsDetailNotFoundSubtitle =>
      'Integrasi yang disetujui ini tidak lagi tersedia di Divine.';

  @override
  String get appsDetailHowItWorksTitle => 'Cara kerjanya';

  @override
  String get appsDetailHowItWorksBody =>
      'Ini adalah aplikasi pihak ketiga yang disetujui dan berjalan di dalam Divine. Divine hanya memberikan kemampuan yang sudah ditinjau untuk integrasi ini, dan memblokir navigasi keluar dari origin yang disetujui.';

  @override
  String get appsDetailAboutTitle => 'Tentang';

  @override
  String get appsDetailPrimaryOriginTitle => 'Origin utama';

  @override
  String get appsDetailApprovedOriginsTitle => 'Origin yang disetujui';

  @override
  String get appsDetailCapabilitiesTitle => 'Kemampuan yang tersedia';

  @override
  String get appsDetailAskBeforeTitle => 'Tanya sebelum';

  @override
  String get appsDetailOpenButton => 'Buka Integrasi';

  @override
  String get appsDetailNoneDeclared => 'Belum ada yang dideklarasikan';

  @override
  String get appsDirectoryTitle => 'Aplikasi Terintegrasi';

  @override
  String get appsDirectoryIntroTitle => 'Aplikasi pihak ketiga yang disetujui';

  @override
  String get appsDirectoryIntroBody =>
      'Aplikasi pihak ketiga yang disetujui dan berjalan di dalam Divine';

  @override
  String get appsDirectoryErrorTitle =>
      'Tidak bisa memuat aplikasi terintegrasi';

  @override
  String get appsDirectoryErrorSubtitle =>
      'Tarik untuk mencoba lagi integrasi yang disetujui.';

  @override
  String get appsDirectoryEmptyTitle => 'Belum ada integrasi yang disetujui';

  @override
  String get appsDirectoryEmptySubtitle =>
      'Aplikasi pihak ketiga yang disetujui akan muncul di sini seiring Divine menambahkannya.';

  @override
  String get appsDirectoryRefresh => 'Segarkan';

  @override
  String get appsDirectoryUnsupportedTitle =>
      'Aplikasi Terintegrasi berjalan di Divine mobile';

  @override
  String get appsDirectoryUnsupportedSubtitle =>
      'Integrasi yang disetujui baru tersedia di perangkat seluler untuk saat ini.';

  @override
  String get appsSandboxUnavailableTitle => 'Integrasi tidak tersedia';

  @override
  String get appsSandboxUnavailableBody =>
      'Buka integrasi yang disetujui dari tab Aplikasi Terintegrasi supaya Divine bisa menerapkan kebijakan akses yang tepat.';

  @override
  String get appsSandboxLoadingTitle => 'Memuat integrasi';

  @override
  String get appsSandboxLoadingSubtitle =>
      'Memeriksa integrasi yang disetujui sebelum diluncurkan.';

  @override
  String get appsSandboxBlockedTitle => 'Diblokir demi keamanan';

  @override
  String appsSandboxBlockedSubtitle(String uri) {
    return 'Integrasi ini mencoba keluar dari origin yang disetujui.\n\n$uri';
  }

  @override
  String get shareCopiedPostLink => 'Tautan ke postingan disalin ke clipboard';

  @override
  String get shareCopiedEventJson => 'JSON event Nostr disalin ke clipboard';

  @override
  String get shareCopiedEventId => 'ID event Nostr disalin ke clipboard';

  @override
  String get authHeroTaglineAuthentic => 'Momen autentik.';

  @override
  String get authHeroTaglineHuman => 'Kreativitas manusia.';

  @override
  String get keyImportFailedToImport =>
      'Gagal mengimpor kunci atau menyambungkan bunker';

  @override
  String get keyImportInvalidBunkerUrl => 'URL bunker tidak valid';

  @override
  String get keyImportInvalidFormat =>
      'Format tidak valid. Gunakan nsec..., hex, ncryptsec1..., atau bunker://...';

  @override
  String get keyImportInvalidNsecFormat =>
      'Format nsec tidak valid. Seharusnya 63 karakter';

  @override
  String get keyImportKeyFieldLabel => 'Kunci privat atau URL bunker';

  @override
  String get keyImportKeyRequired =>
      'Silakan masukkan kunci privat atau URL bunker-mu';

  @override
  String get keyImportPasswordRequired =>
      'Silakan masukkan kata sandi untuk kunci terenkripsi ini';

  @override
  String get keyImportSecurityWarningBody =>
      'Jangan pernah membagikan kunci privatmu ke siapa pun. Kunci ini memberi akses penuh ke identitas Nostr-mu.';

  @override
  String get keyImportSecurityWarningTitle => 'Jaga kunci privatmu tetap aman!';

  @override
  String get keyImportSubtitle =>
      'Impor identitas Nostr yang sudah kamu punya dengan kunci privat atau URL bunker.';

  @override
  String get keyImportTitle => 'Impor identitas\nNostr-mu';

  @override
  String get commentAuthorYouIndicator => 'Kamu';

  @override
  String commentAuthorAvatarSemanticLabel(String name) {
    return 'Lihat profil $name';
  }

  @override
  String get commentOptionsDeleteSemanticLabel => 'Hapus komentar';

  @override
  String get commentOptionsEditSemanticLabel => 'Edit komentar';

  @override
  String get commentOptionsFlagContentLabel => 'Tandai Konten';

  @override
  String get commentOptionsFlagContentSemanticLabel => 'Tandai konten ini';

  @override
  String get commentOptionsFlagReasonPrompt =>
      'Pilih alasan untuk menandai komentar ini';

  @override
  String get commentOptionsFlagSubmit => 'Kirim';

  @override
  String get commentOptionsTitle => 'Opsi';

  @override
  String get commentsEmptyClassicVineMessage =>
      'Kami masih mengerjakan impor komentar lama dari arsip. Belum siap sekarang.';

  @override
  String get commentsEmptyClassicVineTitle => 'Vine Klasik';

  @override
  String get commentsInputEditingLabel => 'Mengedit';

  @override
  String get commentsInputSemanticHint => 'Tambahkan komentar';

  @override
  String get commentsInputSemanticHintEdit => 'Edit komentar';

  @override
  String get commentsInputSemanticHintReply => 'Tambahkan balasan';

  @override
  String get commentsInputSemanticLabel => 'Input komentar';

  @override
  String get commentsInputSemanticLabelEdit => 'Input edit';

  @override
  String get commentsInputSemanticLabelReply => 'Input balasan';

  @override
  String classicVinersViewProfileSemanticLabel(String displayName) {
    return 'Lihat profil $displayName';
  }

  @override
  String get classicsEmptyDescription => 'Arsip Klasik sedang dimuat';

  @override
  String get classicsEmptyTitle => 'Tidak Ada Klasik yang Ditemukan';

  @override
  String get classicsErrorTitle => 'Gagal memuat Klasik';

  @override
  String get classicsUnavailableDescription =>
      'Klasik hanya tersedia saat terhubung ke relay Funnelcake.';

  @override
  String get classicsUnavailableSettingsHint =>
      'Beralih ke relay yang mendukung Funnelcake di Pengaturan untuk mengakses arsip Klasik.';

  @override
  String get classicsUnavailableTitle => 'Klasik Tidak Tersedia';

  @override
  String get hashtagFeedEmptySubtitle =>
      'Jadilah yang pertama memposting video dengan hashtag ini!';

  @override
  String hashtagFeedEmptyTitle(String hashtag) {
    return 'Tidak ada video untuk #$hashtag';
  }

  @override
  String get hashtagFeedLoadingSubtitle => 'Ini mungkin butuh beberapa saat';

  @override
  String hashtagFeedLoadingTitle(String hashtag) {
    return 'Memuat video tentang #$hashtag...';
  }

  @override
  String get hashtagInputHint => 'Tambahkan hashtag... #vine #nostr';

  @override
  String get newVideosTabEmptySubtitle => 'Cek lagi nanti untuk konten baru';

  @override
  String get newVideosTabEmptyTitle => 'Tidak ada video di Video Baru';

  @override
  String get popularVideosContextTitle => 'Video Populer';

  @override
  String get popularVideosEmptySubtitle => 'Cek lagi nanti untuk konten baru';

  @override
  String get popularVideosEmptyTitle => 'Tidak ada video di Video Populer';

  @override
  String get popularVideosErrorTitle => 'Gagal memuat video yang sedang tren';

  @override
  String get popularVideosFeedSourceLabel => 'Sumber feed populer';

  @override
  String get trendingHashtagsLoading => 'Memuat hashtag...';

  @override
  String trendingHashtagsViewVideosTagged(String hashtag) {
    return 'Lihat video bertanda $hashtag';
  }

  @override
  String videoGridAuthorSemanticLabel(String name) {
    return 'Pembuat video: $name';
  }

  @override
  String videoGridDescriptionSemanticLabel(String description) {
    return 'Deskripsi video: $description';
  }

  @override
  String get forYouAlgorithmChoiceBody =>
      'Visi Divine adalah memberimu pilihan algoritma yang sesungguhnya. Alih-alih terkunci pada satu algoritma kotak hitam, kamu akan bisa memilih dari beberapa pendekatan rekomendasi:';

  @override
  String get forYouAlgorithmChoiceChronological =>
      'Linimasa kronologis dari kreator yang kamu ikuti';

  @override
  String get forYouAlgorithmChoiceClosing =>
      'Ini menempatkanmu sebagai pengendali perhatianmu sendiri, bukan menyerahkannya ke platform. Kamu berhak tahu bagaimana feed-mu dikurasi dan punya kuasa untuk mengubahnya kapan pun kamu mau.';

  @override
  String get forYouAlgorithmChoiceCustomFeeds =>
      'Feed kustom buatan komunitas untuk topik seperti musik, komedi, atau seni';

  @override
  String get forYouAlgorithmChoicePersonalizedFeed =>
      'Feed \"Untukmu\" yang dipersonalisasi';

  @override
  String get forYouAlgorithmChoiceTitle => 'Algoritmamu, Pilihanmu';

  @override
  String get forYouAlgorithmChoiceTrending =>
      'Konten yang sedang tren dan populer';

  @override
  String get forYouAlgorithmCommentsDescription =>
      'Sinyal kuat — kamu cukup terlibat untuk menanggapi';

  @override
  String get forYouAlgorithmHowItWorksBody =>
      'Divine memperhatikan cara kamu berinteraksi dengan konten untuk memahami apa yang kamu sukai. Setiap kali kamu menonton video, memberi reaksi, meninggalkan komentar, atau me-repost-nya, sistem mencatatnya.';

  @override
  String get forYouAlgorithmHowItWorksTitle => 'Cara Kerjanya';

  @override
  String get forYouAlgorithmInteractionsIntro =>
      'Tindakan berbeda menandakan tingkat minat yang berbeda:';

  @override
  String get forYouAlgorithmNewToDivineBody1 =>
      'Kalau kamu belum punya riwayat menonton, kami menampilkan campuran konten yang sedang populer dan tren bersama unggahan terbaru. Ini memberimu titik awal yang bagus untuk menjelajah.';

  @override
  String get forYouAlgorithmNewToDivineBody2 =>
      'Seiring kamu menonton, menyukai, dan terlibat dengan konten, rekomendasi perlahan jadi lebih personal. Seiring waktu, feed Untukmu memunculkan video dari kreator yang mungkin tak pernah kamu temukan sendiri.';

  @override
  String get forYouAlgorithmNewToDivineTitle => 'Baru di Divine?';

  @override
  String get forYouAlgorithmOpenSourceBody =>
      'Kami membangun sistem terbuka tempat pengembang bisa menerapkan algoritma mereka sendiri, dan kamu bisa memilih mana yang mau dipakai — atau memilih untuk tidak memakainya sama sekali.';

  @override
  String get forYouAlgorithmOpenSourceTitle => 'Open Source & Transparan';

  @override
  String get forYouAlgorithmReactionsDescription =>
      'Sinyal sedang — cara cepat menunjukkan apresiasi';

  @override
  String get forYouAlgorithmReactionsTitle => 'Reaksi';

  @override
  String get forYouAlgorithmRepostsDescription =>
      'Sinyal terkuat — berbagi dengan pengikutmu adalah dukungan yang kuat';

  @override
  String get forYouAlgorithmSubtitle =>
      'Ditenagai oleh Gorse, mesin rekomendasi open-source';

  @override
  String get forYouAlgorithmTitle => 'Algoritma Divine';

  @override
  String get forYouAlgorithmViewsDescription =>
      'Sinyal ringan — menandakan minat dasar';

  @override
  String get forYouEmptyDescription =>
      'Tonton dan sukai beberapa video untuk mendapat rekomendasi yang dipersonalisasi.';

  @override
  String get forYouEmptyTitle => 'Belum Ada Rekomendasi';

  @override
  String get forYouErrorTitle => 'Gagal memuat rekomendasi';

  @override
  String get forYouUnavailableDescription =>
      'Rekomendasi yang dipersonalisasi memerlukan koneksi ke Funnelcake.';

  @override
  String get forYouUnavailableTitle => 'Untukmu Tidak Tersedia';

  @override
  String get inboxConversationOptionsLabel => 'Opsi';

  @override
  String get inboxConversationViewProfileButton => 'Lihat profil';

  @override
  String get inboxMessageRequestsEmpty => 'Tidak ada permintaan pesan';

  @override
  String inboxMessageRequestsSemanticLabel(int requestCount) {
    return 'Permintaan pesan, $requestCount menunggu';
  }

  @override
  String get inboxMessageRequestsTitle => 'Permintaan pesan';

  @override
  String get inboxMessagesTab => 'Pesan';

  @override
  String inboxRequestTileLabel(String displayName) {
    return 'Permintaan pesan dari $displayName';
  }

  @override
  String get inboxRequestTileSubtitle => 'Mengirim permintaan pesan';

  @override
  String get inboxRequestsMarkAllRead => 'Tandai semua permintaan sudah dibaca';

  @override
  String get inboxRequestsRemoveAll => 'Hapus semua permintaan';

  @override
  String get messageRequestDeclineAndRemoveButton => 'Tolak dan hapus';

  @override
  String messageRequestDeclinedSnackbar(String displayName) {
    return 'Permintaan $displayName ditolak';
  }

  @override
  String get messageRequestLoadFailed => 'Permintaan ini gagal dimuat.';

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
      other: '$count pesan',
      one: '1 pesan',
    );
    return '$_temp0';
  }

  @override
  String get messageRequestViewMessagesButton => 'Lihat pesan';

  @override
  String get messageRequestViewProfileButton => 'Lihat profil';

  @override
  String messageRequestWantsToMessageYou(
    String displayName,
    String messageText,
  ) {
    return '$displayName ingin mengirim pesan kepadamu, mereka mengirim $messageText.';
  }

  @override
  String get deleteAccountAccountChanged =>
      'Kamu beralih akun, jadi tidak ada yang dihapus. Buka lagi penghapusan untuk akun yang ingin kamu hapus.';

  @override
  String get deleteAccountConfirmDeletePrompt => 'Untuk konfirmasi, ketik:';

  @override
  String get deleteAccountConfirmUsernamePrompt =>
      'Untuk konfirmasi, ketik username-mu:';

  @override
  String get deleteAccountConfirmationHint => 'Ketik DELETE';

  @override
  String get deleteAccountConfirmationHintUsername => 'Ketik username-mu';

  @override
  String get deleteAccountDeleteAllContentButton => 'Hapus Semua Konten';

  @override
  String get accountDeletionRecoveryTitle => 'Akunmu sedang dihapus';

  @override
  String get accountDeletionRecoveryBody =>
      'Kami tidak bisa menyelesaikan penghapusan akunmu. Username-mu masih dipesan untukmu dan masih bisa dikembalikan.';

  @override
  String accountDeletionRecoveryBodyWithExpiry(String expiryDate) {
    return 'We couldn\'t finish deleting your account. Your username is reserved for you until $expiryDate and can still be restored.';
  }

  @override
  String get accountDeletionRestoreUsername => 'Kembalikan username saya';

  @override
  String get accountDeletionFinishingBody =>
      'Permintaan penghapusanmu masih diproses. Kamu bisa menggunakan akun lain sementara kami menyelesaikannya.';

  @override
  String get accountDeletionOtherAccountPending =>
      'Penghapusan akun lain masih diproses di perangkat ini. Tunggu hingga selesai sebelum menghapus akun ini.';

  @override
  String get accountDeletionCancellingBody =>
      'Kami sedang membatalkan penghapusanmu. Cek lagi sebelum kamu meninggalkan layar ini.';

  @override
  String get accountDeletionRecoveryFailed =>
      'Kami belum bisa mengembalikan username-mu. Periksa koneksimu dan coba lagi.';

  @override
  String get accountDeletionUsernameRestored =>
      'Username-mu sudah dikembalikan. Akunmu tidak jadi dihapus.';

  @override
  String get accountDeletionRecoveryStatusFailed =>
      'Kami tidak bisa memeriksa status penghapusanmu. Periksa koneksimu dan coba lagi.';

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
      'Penghapusan akun sedang tidak tersedia. Tidak ada yang dihapus.';

  @override
  String get deleteAccountDeletionIncomplete =>
      'Kami tidak bisa menyelesaikan penghapusan akunmu. Coba lagi.';

  @override
  String get deleteAccountDeletionNotStarted =>
      'We couldn\'t start deleting your account. Nothing was deleted. Try again.';

  @override
  String get deleteAccountFinalConfirmationTitle => '⚠️ Konfirmasi Terakhir';

  @override
  String get deleteAccountKeyDeletionWarning =>
      'Permintaan penghapusan terkirim, tapi kuncimu mungkin belum sepenuhnya terhapus dari perangkat ini. Buka Pengaturan → Kunci Nostr → Hapus Kunci untuk mencoba lagi.';

  @override
  String get deleteAccountLocalDataDeletionFailed =>
      'Permintaan penghapusan terkirim dan kamu keluar dari akun, tapi sebagian data lokal tidak bisa dihapus dari perangkat ini.';

  @override
  String get deleteAccountPreparingDeletion => 'Menyiapkan penghapusan...';

  @override
  String deleteAccountProgressEvents(int current, int total) {
    return '$current / $total event';
  }

  @override
  String get deleteAccountRemoveKeysBody =>
      'Ini menghapus login lokal untuk akun ini dari perangkat ini. Ini tidak akan menghapus akun Divine atau identitas Nostr-mu.\n\nDraf dan klipmu tetap tersimpan di perangkat ini untuk akun ini. Kalau ini akun lokal terakhirmu, kamu akan kembali ke layar login.';

  @override
  String get deleteAccountRemoveKeysConfirm => 'Hapus dari perangkat';

  @override
  String get deleteAccountRemoveKeysTitle =>
      'Hapus akun ini dari perangkat ini?';

  @override
  String get deleteAccountReauthRequired =>
      'Masuk lagi untuk menghapus akunmu. Belum ada yang dihapus.';

  @override
  String get deleteAccountServerDeletionFailed =>
      'Permintaan penghapusan untuk postinganmu sudah dikirim, tapi kami belum bisa menyelesaikan penghapusan akunmu. Coba lagi sebentar lagi.';

  @override
  String get deleteAccountSuccess =>
      'Akun Divine-mu telah dihapus. Permintaan penghapusan telah dikirim untuk postingan Nostr-mu, tetapi beberapa relay, klien, atau cache mungkin masih menyimpan salinannya.';

  @override
  String get deleteAccountSuccessContentUnverified =>
      'Penghapusan akun sudah diminta. Penghapusan beberapa postingan yang ada tidak bisa dikonfirmasi satu per satu.';

  @override
  String get deleteAccountWarningBody =>
      'Ini mengirim permintaan penghapusan untuk akun dan kontenmu, menghapus akun Divine-mu jika memungkinkan, dan mengeluarkanmu dari akun di perangkat ini. Beberapa relay, klien, dan indeks pencarian mungkin menyimpan salinan. Perangkat lain yang masih masuk tetap aktif sampai kamu menghapus kuncinya di sana.';

  @override
  String get findPeopleNoContacts =>
      'Tidak ada kontak ditemukan.\nMulai ikuti orang untuk melihat mereka di sini.';

  @override
  String get geoBlockedCityLabel => 'Kota';

  @override
  String get geoBlockedCountryLabel => 'Negara';

  @override
  String get geoBlockedDefaultReason =>
      'Layanan ini tidak tersedia di wilayahmu karena regulasi setempat.';

  @override
  String get geoBlockedLegalNotice =>
      'Kami menghormati hukum dan regulasi setempatmu. Pembatasan ini berdasarkan lokasi alamat IP-mu.';

  @override
  String get geoBlockedRegionLabel => 'Wilayah';

  @override
  String get geoBlockedTitle => 'Layanan Tidak Tersedia';

  @override
  String get likedVideosEmpty => 'Tidak ada video yang disukai';

  @override
  String get likedVideosInvalidRoute => 'Rute tidak valid';

  @override
  String get likedVideosTitle => 'Video yang Disukai';

  @override
  String get uploadFailureSheetRetryingSnackbar => 'Mencoba mengunggah lagi…';

  @override
  String get uploadFailureSheetSaveToDraftsButton => 'Simpan ke Draf';

  @override
  String get uploadFailureSheetSavedToDraftsSnackbar => 'Disimpan ke draf';

  @override
  String get uploadFailureSheetTitle => 'Unggahan Gagal';

  @override
  String get uploadFailureSheetTryAgainButton => 'Coba Lagi';

  @override
  String get videoEditorAudioImportAudio => 'Impor audio';

  @override
  String get videoEditorAudioImportFailed => 'Impor audio gagal.';

  @override
  String get videoIconPlaceholderLabel => 'Video';

  @override
  String get publishErrorNotSignedIn =>
      'Silakan masuk untuk mempublikasikan video.';

  @override
  String get publishErrorNoRetry => 'Tidak ada unggahan untuk dicoba ulang.';

  @override
  String get publishErrorNoInternet =>
      'Tidak ada koneksi internet. Periksa Wi-Fi atau data selulermu dan coba lagi.';

  @override
  String get publishErrorServerUnreachable =>
      'Tidak dapat menjangkau server. Silakan coba lagi sebentar lagi.';

  @override
  String get publishErrorTimeout =>
      'Waktu unggah habis. Coba pakai koneksi yang lebih kuat atau video yang lebih kecil.';

  @override
  String get publishErrorTls =>
      'Koneksi aman gagal. Periksa jaringanmu—Wi-Fi publik bisa memblokir unggahan.';

  @override
  String publishErrorServerNotFound(String serverName) {
    return 'Server media ($serverName) tidak tersedia. Kamu bisa memilih yang lain di pengaturan.';
  }

  @override
  String get publishErrorFileTooLarge =>
      'File video terlalu besar untuk server. Coba pangkas videonya atau turunkan kualitasnya.';

  @override
  String publishErrorServerInternalError(String serverName) {
    return 'Server media ($serverName) mengalami kesalahan internal. Kamu bisa memilih yang lain di pengaturan.';
  }

  @override
  String publishErrorServerDown(String serverName) {
    return 'Server media ($serverName) sedang tidak aktif sementara. Coba lagi sebentar lagi atau pilih yang lain di pengaturan.';
  }

  @override
  String get publishErrorForbidden =>
      'Kamu tidak punya izin untuk mengunggah ke server ini.';

  @override
  String get publishErrorFileNotFound =>
      'File video tidak ditemukan. Mungkin sudah terhapus. Rekam ulang lalu coba lagi.';

  @override
  String get publishErrorLowStorage =>
      'Penyimpanan di perangkatmu tidak cukup. Kosongkan sedikit ruang lalu coba lagi.';

  @override
  String get publishErrorThumbnailFailed =>
      'Video berhasil diunggah, tapi thumbnail tidak bisa disiapkan. Silakan coba lagi.';

  @override
  String get publishErrorNostrPublishFailed =>
      'Video berhasil diunggah, tapi posting tidak bisa dipublikasikan. Periksa pengaturan relay-mu dan coba lagi.';

  @override
  String get publishErrorAccountRestricted =>
      'Your account is restricted, so this post couldn’t be published.';

  @override
  String get uploadFailureSheetAccountStatusButton => 'View Account Status';

  @override
  String get publishErrorAudioReuseNotPermitted =>
      'Video berhasil diunggah, tapi suaranya tidak diizinkan untuk dipakai ulang. Pilih suara lain untuk memposting.';

  @override
  String get publishErrorInterrupted =>
      'Unggahan ini terganggu. Mau coba lagi?';

  @override
  String get publishErrorAccountChanged =>
      'Video ini milik akun lain. Balik ke akun itu untuk mempostingnya.';

  @override
  String get publishErrorGeneric => 'Terjadi kesalahan. Silakan coba lagi.';

  @override
  String get publishErrorRateLimited =>
      'Terlalu banyak unggahan saat ini. Tunggu sebentar lalu coba lagi.';

  @override
  String get publishErrorUploadSessionExpired =>
      'Sesi unggahanmu sudah berakhir. Silakan coba lagi.';

  @override
  String get publishErrorPermissionDenied =>
      'Divine tidak punya izin untuk mengunggah. Periksa izin aplikasi di pengaturanmu dan coba lagi.';

  @override
  String get publishErrorOutOfMemory =>
      'Memori perangkatmu menipis. Tutup beberapa aplikasi lalu coba lagi.';

  @override
  String get publishErrorOverlaysUnavailable =>
      'Teks dan stiker di draf ini tidak bisa disiapkan. Buka di editor, lalu posting lagi.';

  @override
  String get publishErrorUnknownServer => 'Server tidak dikenal';

  @override
  String searchFilterPillSemanticLabel(String filter) {
    return 'Filter: $filter';
  }

  @override
  String searchNoResultsFound(String query) {
    return 'Tidak ada hasil untuk \"$query\"';
  }

  @override
  String searchTagChipViewVideosTaggedLabel(String tag) {
    return 'Lihat video bertanda $tag';
  }

  @override
  String audioAttributionRowSemanticLabel(
    String soundName,
    String creatorName,
  ) {
    return 'Suara: $soundName oleh $creatorName. Ketuk untuk melihat detail suara.';
  }

  @override
  String metadataSoundsOriginalSoundSemantics(String creatorName) {
    return 'Suara asli oleh $creatorName. Ketuk untuk memakai suara ini.';
  }

  @override
  String metadataSoundsSharedSoundSemantics(
    String soundName,
    String creatorName,
  ) {
    return 'Suara: $soundName oleh $creatorName. Ketuk untuk melihat detail.';
  }

  @override
  String get soundDetailLoadError => 'Gagal memuat suara. Silakan coba lagi.';

  @override
  String get soundDetailNotFoundMessage => 'Suara ini tidak dapat ditemukan';

  @override
  String get soundDetailNotFoundTitle => 'Suara Tidak Ditemukan';

  @override
  String videoFeedLoopCountLabel(int count) {
    return '🔁 $count loop';
  }

  @override
  String get originalSoundUnavailableBody =>
      'Audio dari video ini tidak tersedia secara terpisah.';

  @override
  String originalSoundByCreator(String creatorName) {
    return 'Suara asli - $creatorName';
  }

  @override
  String get ogVinerBadgeLabel => 'OG Viner';

  @override
  String get profileBadgeOgVinerBody =>
      'Orang ini pernah memposting Vine asli yang ditemukan Divine di arsip. Ini bukan lencana verifikasi akun.';

  @override
  String get ogBetaTesterBadgeLabel => 'OG Beta Tester';

  @override
  String get profileBadgeOgBetaTesterBody =>
      'This person was testing Divine during the beta, before it opened to everyone. It is not an account verification badge.';

  @override
  String get profileBadgeCheckmarkTitle => 'Centang profil';

  @override
  String get profileBadgeCheckmarkBody =>
      'Divine memberikan centang ini kepada akun tim. Ini terpisah dari NIP-05, tautan akun terverifikasi, dan status OG Viner.';

  @override
  String get unfollowConfirmButton => 'Berhenti mengikuti';

  @override
  String get videoClipSaveFailed => 'Gagal menyimpan klip';

  @override
  String videoClipSaveTo(String destination) {
    return 'Simpan ke $destination';
  }

  @override
  String get videoClipDelete => 'Hapus klip';

  @override
  String inspiredByAttributionMultipleSemanticLabel(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return 'Terinspirasi oleh $creatorName +$additionalCreatorCount. Ketuk untuk melihat profil mereka.';
  }

  @override
  String inspiredByAttributionSemanticLabel(String creatorName) {
    return 'Terinspirasi oleh $creatorName. Ketuk untuk melihat profil mereka.';
  }

  @override
  String get bugReportSendReport => 'Kirim Laporan';

  @override
  String get supportSubjectRequiredLabel => 'Subjek *';

  @override
  String get supportPublicSubmissionTitle => 'Kiriman GitHub publik';

  @override
  String get supportPublicSubmissionMessage =>
      'Semua yang kamu kirim di sini akan diposting ke repositori sumber terbuka kami di GitHub agar pengembang dapat menanganinya. Kiriman tersebut dan akun yang kamu gunakan untuk masuk dapat dilihat secara publik oleh siapa saja.';

  @override
  String get supportRequiredHelper => 'Wajib';

  @override
  String get supportFieldLimitReached =>
      'Itu panjang maksimalnya. Sisanya tidak ikut ditambahkan.';

  @override
  String get bugReportSubjectHint => 'Ringkasan singkat masalahnya';

  @override
  String get bugReportDescriptionRequiredLabel => 'Apa yang terjadi? *';

  @override
  String get bugReportDescriptionHint => 'Jelaskan masalah yang kamu temui';

  @override
  String get bugReportStepsLabel => 'Langkah Reproduksi';

  @override
  String get bugReportStepsHint => '1. Buka...\n2. Tap...\n3. Lihat error';

  @override
  String get bugReportExpectedBehaviorLabel => 'Perilaku yang Diharapkan';

  @override
  String get bugReportExpectedBehaviorHint => 'Apa yang seharusnya terjadi?';

  @override
  String get bugReportDiagnosticsNotice =>
      'Info perangkat dan log akan disertakan otomatis.';

  @override
  String get bugReportSuccessMessage =>
      'Terima kasih! Laporanmu sudah kami terima dan akan kami pakai untuk membuat Divine lebih baik.';

  @override
  String get bugReportAttachImages => 'Lampirkan gambar';

  @override
  String bugReportImagesCount(int count, int max) {
    return '$count dari $max gambar dipilih';
  }

  @override
  String get bugReportRemoveImage => 'Hapus gambar';

  @override
  String get bugReportUploadFailed =>
      'Kami gagal mengunggah gambar yang dipilih. Coba lagi atau kirim laporannya tanpa gambar.';

  @override
  String get bugReportSendFailed =>
      'Gagal mengirim laporan bug. Coba lagi nanti.';

  @override
  String get featureRequestSendRequest => 'Kirim Permintaan';

  @override
  String get featureRequestSubjectHint => 'Ringkasan singkat idemu';

  @override
  String get featureRequestDescriptionRequiredLabel =>
      'Apa yang kamu inginkan? *';

  @override
  String get featureRequestDescriptionHint => 'Jelaskan fitur yang kamu mau';

  @override
  String get featureRequestUsefulnessLabel => 'Bagaimana ini berguna?';

  @override
  String get featureRequestUsefulnessHint => 'Jelaskan manfaat dari fitur ini';

  @override
  String get featureRequestWhenLabel => 'Kapan kamu akan memakainya?';

  @override
  String get featureRequestWhenHint =>
      'Jelaskan situasi di mana ini akan membantu';

  @override
  String get featureRequestSuccessMessage =>
      'Terima kasih! Permintaan fiturmu sudah kami terima dan akan kami tinjau.';

  @override
  String get featureRequestSendFailed =>
      'Gagal mengirim permintaan fitur. Coba lagi nanti.';

  @override
  String get notificationFollowBack => 'Ikuti balik';

  @override
  String get followingTitle => 'Mengikuti';

  @override
  String followingTitleForName(String displayName) {
    return 'Yang Diikuti $displayName';
  }

  @override
  String get followingFailedToLoadList => 'Gagal memuat daftar mengikuti';

  @override
  String get followingEmptyTitle => 'Belum mengikuti siapa pun';

  @override
  String get followersTitle => 'Pengikut';

  @override
  String followersTitleForName(String displayName) {
    return 'Pengikut $displayName';
  }

  @override
  String get followersFailedToLoadList => 'Gagal memuat daftar pengikut';

  @override
  String get followersEmptyTitle => 'Belum ada pengikut';

  @override
  String get followersUpdateFollowFailed =>
      'Gagal memperbarui status follow. Coba lagi.';

  @override
  String get followersSortSemanticLabel => 'Urutkan pengikut';

  @override
  String get followingSortSemanticLabel => 'Urutkan yang diikuti';

  @override
  String get followSortTitle => 'Urutkan menurut';

  @override
  String get followSortNewest => 'Terbaru dulu';

  @override
  String get followSortOldest => 'Terlama dulu';

  @override
  String get newMessageTitle => 'Pesan baru';

  @override
  String get newMessageFindPeople => 'Cari orang';

  @override
  String get newMessageNoContacts =>
      'Tidak ada kontak ditemukan.\nIkuti orang untuk melihat mereka di sini.';

  @override
  String get newMessageNoUsersFound => 'Pengguna tidak ditemukan';

  @override
  String get hashtagSearchTitle => 'Cari hashtag';

  @override
  String get hashtagSearchSubtitle => 'Temukan topik dan konten yang lagi tren';

  @override
  String hashtagSearchNoResults(String query) {
    return 'Tidak ada hashtag untuk \"$query\"';
  }

  @override
  String get hashtagSearchFailed => 'Pencarian gagal';

  @override
  String get userNotAvailableTitle => 'Akun tidak tersedia';

  @override
  String get userNotAvailableBody => 'Akun ini tidak tersedia saat ini.';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String get blossomFailedToSaveSettings =>
      'Gagal menyimpan pengaturan. Silakan coba lagi.';

  @override
  String get blossomValidServerUrl =>
      'Masukkan URL server yang valid (contoh: https://blossom.band)';

  @override
  String get blossomSettingsSaved => 'Pengaturan Blossom tersimpan';

  @override
  String get blossomSaveTooltip => 'Simpan';

  @override
  String get blossomAboutTitle => 'Tentang Blossom';

  @override
  String get blossomAboutDescription =>
      'Blossom adalah protokol penyimpanan media terdesentralisasi yang memungkinkanmu mengunggah video ke server kompatibel mana pun. Secara default, video diunggah ke server Blossom Divine. Aktifkan opsi di bawah untuk memakai server kustom.';

  @override
  String get blossomUseCustomServer => 'Pakai Server Blossom Kustom';

  @override
  String get blossomCustomServerEnabledSubtitle =>
      'Video akan diunggah ke server Blossom kustommu';

  @override
  String get blossomCustomServerDisabledSubtitle =>
      'Video kamu saat ini diunggah ke server Blossom Divine';

  @override
  String get blossomCustomServerUrl => 'URL Server Blossom Kustom';

  @override
  String get blossomCustomServerHelper =>
      'Masukkan URL server Blossom kustommu';

  @override
  String get blossomPopularServers => 'Server Blossom Populer';

  @override
  String get blossomServerUrlMustUseHttps =>
      'URL server Blossom harus pakai https://';

  @override
  String get blueskyFailedToUpdateCrosspost =>
      'Gagal memperbarui pengaturan crosspost';

  @override
  String get blueskySignInRequired => 'Masuk untuk mengatur pengaturan Bluesky';

  @override
  String get blueskyPublishVideos => 'Publikasikan video ke Bluesky';

  @override
  String get blueskyEnabledSubtitle =>
      'Video kamu akan dipublikasikan ke Bluesky';

  @override
  String get blueskyDisabledSubtitle =>
      'Video kamu tidak akan dipublikasikan ke Bluesky';

  @override
  String get blueskyBackfillDisclosureTitle =>
      'Video lamamu juga akan diposting';

  @override
  String get blueskyBackfillDisclosureSubtitle =>
      'Saat ini dinyalakan, Divine akan mulai mengirim video lamamu ke Bluesky, dari yang paling lama dulu, tanpa terburu-buru mengejar batas harian.';

  @override
  String get blueskyHandle => 'Handle Bluesky';

  @override
  String get blueskyDid => 'DID Bluesky';

  @override
  String get blueskyStatus => 'Status';

  @override
  String get blueskyStatusReady => 'Akun sudah disiapkan dan siap';

  @override
  String get blueskyStatusPending => 'Penyiapan akun sedang berjalan...';

  @override
  String get blueskyStatusFailed => 'Penyiapan akun gagal';

  @override
  String get blueskyStatusDisabled => 'Akun dinonaktifkan';

  @override
  String get blueskyStatusNotLinked => 'Belum ada akun Bluesky terhubung';

  @override
  String get blueskyUsernameRequired =>
      'Siapkan handle divine.video sebelum memposting ke Bluesky';

  @override
  String get blueskyUsernameRequiredSubtitle =>
      'Memposting ke Bluesky butuh handle namapengguna.divine.video yang sudah diklaim.';

  @override
  String get blueskyUsernameSyncPending =>
      'Handle Divine kamu sudah diklaim. Kami sedang menghubungkannya ke Bluesky — coba lagi sebentar lagi.';

  @override
  String get blueskyStatusUnavailableRetry =>
      'Kami tidak bisa memeriksa handle Divine kamu. Coba lagi.';

  @override
  String get blueskySetUpHandle => 'Siapkan';

  @override
  String get blueskyTemporarilyUnavailable =>
      'Memposting ke Bluesky sementara tidak tersedia. Coba lagi.';

  @override
  String get invitesTitle => 'Undang Teman';

  @override
  String invitesGenerateCardTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count undangan siap dibuat',
    );
    return '$_temp0';
  }

  @override
  String get invitesGenerateCardSubtitle =>
      'Buat kode kalau kamu sudah siap membagikannya.';

  @override
  String get invitesGenerateButtonLabel => 'Buat undangan';

  @override
  String get invitesNoneAvailable => 'Tidak ada undangan tersedia saat ini';

  @override
  String get invitesShareWithPeople =>
      'Bagikan Divine ke orang yang kamu kenal';

  @override
  String get invitesUsedInvites => 'Undangan terpakai';

  @override
  String invitesShareMessage(String code) {
    return 'Gabung dengan saya di Divine! Pakai kode undangan $code untuk mulai:\nhttps://divine.video/invite/$code';
  }

  @override
  String get invitesCopyInvite => 'Salin undangan';

  @override
  String get invitesCopied => 'Undangan tersalin!';

  @override
  String get invitesShareInvite => 'Bagikan undangan';

  @override
  String get invitesShareSubject => 'Gabung dengan saya di Divine';

  @override
  String get invitesClaimed => 'Sudah diklaim';

  @override
  String get invitesCouldNotLoad => 'Gagal memuat undangan';

  @override
  String get invitesRetry => 'Coba Lagi';

  @override
  String get searchSomethingWentWrong => 'Terjadi kesalahan';

  @override
  String get searchTryAgain => 'Coba lagi';

  @override
  String get searchForLists => 'Cari daftar';

  @override
  String get searchFindCuratedVideoLists => 'Temukan daftar video pilihan';

  @override
  String get searchEnterQuery => 'Masukkan kata pencarian';

  @override
  String get searchDiscoverSomethingInteresting =>
      'Temukan sesuatu yang menarik';

  @override
  String get searchPeopleSectionHeader => 'Orang';

  @override
  String get searchPeopleLoadingLabel => 'Memuat hasil orang';

  @override
  String get searchTagsSectionHeader => 'Tag';

  @override
  String get searchTagsLoadingLabel => 'Memuat hasil tag';

  @override
  String get searchVideosSectionHeader => 'Video';

  @override
  String get searchVideosLoadingLabel => 'Memuat hasil video';

  @override
  String get searchVideosSortOptionsLabel => 'Urutkan hasil video';

  @override
  String get searchVideosSortTrending => 'Hot';

  @override
  String get searchVideosSortLoops => 'Loop terbanyak';

  @override
  String get searchVideosSortEngagement => 'Paling banyak interaksi';

  @override
  String get searchVideosSortRecent => 'Terbaru';

  @override
  String get searchListsSectionHeader => 'Daftar';

  @override
  String get searchListsLoadingLabel => 'Memuat hasil daftar';

  @override
  String get cameraAgeRestriction =>
      'Kamu harus berusia 16 tahun atau lebih untuk membuat konten';

  @override
  String get keyImportInsecureBunkerRelay =>
      'Relay bunker harus pakai wss:// (ws:// hanya boleh untuk localhost)';

  @override
  String get timeNow => 'sekarang';

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
    return '${count}mg';
  }

  @override
  String timeShortMonths(int count) {
    return '${count}bl';
  }

  @override
  String timeShortYears(int count) {
    return '${count}th';
  }

  @override
  String get timeVerboseNow => 'Sekarang';

  @override
  String timeAgo(String time) {
    return '$time yang lalu';
  }

  @override
  String get timeToday => 'Hari ini';

  @override
  String get timeYesterday => 'Kemarin';

  @override
  String get timeJustNow => 'baru saja';

  @override
  String timeMinutesAgo(int count) {
    return '${count}m yang lalu';
  }

  @override
  String timeHoursAgo(int count) {
    return '${count}j yang lalu';
  }

  @override
  String timeDaysAgo(int count) {
    return '${count}h yang lalu';
  }

  @override
  String get draftTimeJustNow => 'Baru saja';

  @override
  String get contentLabelNudity => 'Ketelanjangan';

  @override
  String get contentLabelSexualContent => 'Konten Seksual';

  @override
  String get contentLabelPornography => 'Pornografi';

  @override
  String get contentLabelGraphicMedia => 'Media Grafis';

  @override
  String get contentLabelViolence => 'Kekerasan';

  @override
  String get contentLabelSelfHarm => 'Menyakiti Diri Sendiri/Bunuh Diri';

  @override
  String get contentLabelDrugUse => 'Penggunaan Narkoba';

  @override
  String get contentLabelAlcohol => 'Alkohol';

  @override
  String get contentLabelTobacco => 'Tembakau/Merokok';

  @override
  String get contentLabelGambling => 'Judi';

  @override
  String get contentLabelProfanity => 'Kata-kata Kasar';

  @override
  String get contentLabelHateSpeech => 'Ujaran Kebencian';

  @override
  String get contentLabelHarassment => 'Pelecehan';

  @override
  String get contentLabelFlashingLights => 'Cahaya Berkedip';

  @override
  String get contentLabelAiGenerated => 'Dibuat oleh AI';

  @override
  String get contentLabelDeepfake => 'Deepfake';

  @override
  String get contentLabelSpam => 'Spam';

  @override
  String get contentLabelScam => 'Penipuan';

  @override
  String get contentLabelSpoiler => 'Spoiler';

  @override
  String get contentLabelMisleading => 'Menyesatkan';

  @override
  String get contentLabelSensitiveContent => 'Konten Sensitif';

  @override
  String notificationLikedYourVideo(String actorName) {
    return '$actorName menyukai videomu';
  }

  @override
  String notificationLikedYourComment(String actorName) {
    return '$actorName menyukai komentarmu';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return '$actorName mengomentari videomu';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return '$actorName mulai mengikutimu';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return '$actorName menyebutmu';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return '$actorName membagikan ulang videomu';
  }

  @override
  String notificationPostedNewVine(String actorName) {
    return '$actorName memposting vine baru';
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
      other: '$count vine kamu',
    );
    return '$actorName menambahkan $_temp0 ke $listName';
  }

  @override
  String notificationRepliedToYourComment(String actorName) {
    return '$actorName membalas komentar Anda';
  }

  @override
  String get notificationAndConnector => 'dan';

  @override
  String notificationOthersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lainnya',
    );
    return '$_temp0';
  }

  @override
  String get notificationSystemUpdate => 'Kamu punya pembaruan baru';

  @override
  String get commentReplyToPrefix => 'Bls:';

  @override
  String get commentHideKeyboard => 'Sembunyikan papan ketik';

  @override
  String get commentsErrorLoadFailed => 'Komentar gagal dimuat';

  @override
  String get commentsErrorNotAuthenticatedComment =>
      'Masuk dulu untuk berkomentar';

  @override
  String get commentsErrorPostCommentFailed => 'Komentar gagal diposting';

  @override
  String get commentsErrorPostReplyFailed => 'Balasan gagal diposting';

  @override
  String get commentsErrorEditFailed => 'Komentar gagal diedit';

  @override
  String get commentsErrorNotAuthenticatedInteract =>
      'Masuk dulu untuk berinteraksi';

  @override
  String get commentsErrorVoteFailed => 'Gagal memberi suara pada komentar';

  @override
  String get commentsErrorReportFailed => 'Komentar gagal dilaporkan';

  @override
  String get commentsErrorBlockFailed => 'Pengguna gagal diblokir';

  @override
  String get commentsErrorDeleteFailed => 'Komentar gagal dihapus';

  @override
  String commentsHeaderCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Komentar',
    );
    return '$_temp0';
  }

  @override
  String get commentsVideoReplyPending => 'Memposting…';

  @override
  String get commentsVideoReplyPendingSemanticLabel =>
      'Balasan video Anda sedang diposting';

  @override
  String get commentsSortNew => 'Terbaru';

  @override
  String get commentsSortTop => 'Teratas';

  @override
  String get commentsSortOld => 'Terlama';

  @override
  String get commentsSortSemanticLabel => 'Urutan komentar';

  @override
  String get commentReply => 'Balas';

  @override
  String get commentReplySemanticLabel => 'Balas komentar';

  @override
  String get commentUpvoteLabel => 'Beri suara positif untuk komentar';

  @override
  String get commentRemoveUpvoteLabel => 'Hapus suara positif';

  @override
  String get commentDownvoteLabel => 'Beri suara negatif untuk komentar';

  @override
  String get commentRemoveDownvoteLabel => 'Hapus suara negatif';

  @override
  String get commentsInputHint => 'Tambahkan komentar...';

  @override
  String get commentsInputHintEdit => 'Edit komentar...';

  @override
  String get commentsEmptyTitle => 'Belum ada komentar';

  @override
  String get commentsEmptySubtitle => 'Ayo mulai keramaiannya!';

  @override
  String get draftUntitled => 'Tanpa judul';

  @override
  String get contentWarningNone => 'Tidak ada';

  @override
  String get textBackgroundNone => 'Tidak ada';

  @override
  String get textBackgroundSolid => 'Solid';

  @override
  String get textBackgroundHighlight => 'Sorotan';

  @override
  String get textBackgroundTransparent => 'Transparan';

  @override
  String get textAlignLeft => 'Kiri';

  @override
  String get textAlignRight => 'Kanan';

  @override
  String get textAlignCenter => 'Tengah';

  @override
  String get cameraPermissionWebUnsupportedTitle =>
      'Kamera belum didukung di web';

  @override
  String get cameraPermissionWebUnsupportedDescription =>
      'Pengambilan gambar dan perekaman kamera belum tersedia di versi web.';

  @override
  String get cameraPermissionBackToFeed => 'Kembali ke feed';

  @override
  String get cameraCouldNotStart => 'Tidak bisa memulai kamera';

  @override
  String get cameraUnsupportedPlatform =>
      'Kamera belum tersedia di platform ini.\nKamu tetap bisa menjelajah dan menonton video.';

  @override
  String get cameraPermissionErrorTitle => 'Kesalahan izin';

  @override
  String get cameraPermissionErrorDescription =>
      'Terjadi kesalahan saat memeriksa izin.';

  @override
  String get cameraPermissionRetry => 'Coba lagi';

  @override
  String get cameraPermissionAllowAccessTitle =>
      'Izinkan akses kamera & mikrofon';

  @override
  String get cameraPermissionAllowAccessDescription =>
      'Ini memungkinkan Anda merekam dan mengedit video langsung di aplikasi, tidak lebih.';

  @override
  String get cameraPermissionGoToSettings => 'Buka pengaturan';

  @override
  String get videoRecorderWhySixSecondsTitle => 'Mengapa enam detik?';

  @override
  String get videoRecorderWhySixSecondsSubtitle =>
      'Klip pendek memberi ruang untuk spontanitas. Format 6 detik membantu kamu menangkap momen autentik saat terjadi.';

  @override
  String get videoRecorderWhySixSecondsButton => 'Mengerti!';

  @override
  String get videoRecorderUploadTitle => 'Kenapa tidak ada unggahan?';

  @override
  String get videoRecorderUploadBody =>
      'Yang kamu lihat di Divine dibuat oleh manusia: mentah dan ditangkap pada momennya. Tidak seperti platform yang mengizinkan unggahan yang sangat diproduksi atau dihasilkan AI, kami memprioritaskan keaslian pengalaman kamera langsung.';

  @override
  String get videoRecorderUploadBodyDetail =>
      'Dengan menjaga kreasi tetap di dalam aplikasi, kami bisa lebih baik menjamin bahwa konten itu nyata dan tidak diedit. Kami tidak membuka unggahan dari galeri eksternal saat ini untuk melindungi keaslian itu dan menjaga komunitas kami bebas dari konten sintetis sebisa mungkin.';

  @override
  String get videoRecorderUploadBodyCta =>
      'Beralih ke Capture atau Classic untuk merekam sesuatu yang nyata.';

  @override
  String get videoRecorderUploadLearnMore => 'Pelajari cara kerja verifikasi';

  @override
  String get videoRecorderAutosaveFoundTitle =>
      'Kami menemukan pekerjaan yang belum selesai';

  @override
  String get videoRecorderAutosaveFoundSubtitle =>
      'Apakah kamu ingin melanjutkan dari tempat kamu berhenti?';

  @override
  String get videoRecorderAutosaveContinueButton => 'Ya, lanjutkan';

  @override
  String get videoRecorderAutosaveDiscardButton => 'Tidak, mulai video baru';

  @override
  String get videoRecorderAutosaveRestoreFailure =>
      'Tidak dapat memulihkan draf kamu';

  @override
  String get videoRecorderStopRecordingTooltip => 'Hentikan perekaman';

  @override
  String get videoRecorderStartRecordingTooltip => 'Mulai merekam';

  @override
  String get videoRecorderRecordingTapToStopLabel =>
      'Merekam. Ketuk di mana saja untuk berhenti';

  @override
  String get videoRecorderTapToStartLabel =>
      'Ketuk di mana saja untuk mulai merekam';

  @override
  String get videoRecorderDeleteLastClipLabel => 'Hapus klip terakhir';

  @override
  String get videoRecorderSwitchCameraLabel => 'Ganti kamera';

  @override
  String videoRecorderZoomLevelLabel(String zoom) {
    return 'Zoom ke $zoom×';
  }

  @override
  String get videoRecorderToggleGridLabel => 'Ganti grid';

  @override
  String get videoRecorderToggleGhostFrameLabel => 'Ganti frame hantu';

  @override
  String get videoRecorderGhostFrameEnabled => 'Frame hantu diaktifkan';

  @override
  String get videoRecorderGhostFrameDisabled => 'Frame hantu dinonaktifkan';

  @override
  String get videoRecorderClipDeletedMessage => 'Klip dipindahkan ke sampah';

  @override
  String get videoRecorderClipUndoLabel => 'Urungkan';

  @override
  String get libraryTrashEmptyTitle => 'Sampah kosong';

  @override
  String get libraryTrashEmptySubtitle =>
      'Klip yang dihapus tetap di sini selama 30 hari sebelum dihapus secara permanen.';

  @override
  String get libraryTrashRestoreLabel => 'Pulihkan';

  @override
  String get libraryTrashDeleteNowLabel => 'Hapus sekarang';

  @override
  String get libraryTrashEmptyAllLabel => 'Kosongkan sampah';

  @override
  String get libraryTrashDeleteConfirmTitle => 'Hapus klip sekarang?';

  @override
  String get libraryTrashDeleteConfirmMessage =>
      'Ini langsung menghapus klip dari sampah.';

  @override
  String get libraryTrashEmptyConfirmTitle => 'Kosongkan sampah?';

  @override
  String libraryTrashEmptyConfirmMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klip',
      one: '1 klip',
    );
    return 'Ini langsung menghapus permanen $_temp0 dari sampah.';
  }

  @override
  String get videoRecorderCloseLabel => 'Tutup perekam video';

  @override
  String get videoRecorderContinueToEditorLabel => 'Lanjutkan ke editor video';

  @override
  String get videoRecorderCameraPreviewLabel => 'Pratinjau kamera';

  @override
  String get videoRecorderCameraPreviewFocusHint => 'Fokuskan kamera';

  @override
  String videoRecorderSwitchToModeLabel(String mode) {
    return 'Beralih ke mode $mode';
  }

  @override
  String get videoRecorderLipSyncAddAudioFirst =>
      'Tambahkan audio sebelum merekam';

  @override
  String get videoRecorderStopMotionAssembleFailed =>
      'Tidak dapat membuat video. Coba lagi.';

  @override
  String videoRecorderStopMotionShotsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sisa $count jepretan',
      zero: 'Tidak ada jepretan tersisa',
    );
    return '$_temp0';
  }

  @override
  String get videoRecorderToggleFlashLabel => 'Ganti flash';

  @override
  String get videoRecorderCycleTimerLabel => 'Timer siklus';

  @override
  String get videoRecorderToggleAspectRatioLabel => 'Ganti rasio aspek';

  @override
  String get videoRecorderStabilizationLabel => 'Stabilisasi';

  @override
  String get videoRecorderStabilizationModeOff => 'Nonaktif';

  @override
  String get videoRecorderStabilizationModeStandard => 'Standar';

  @override
  String get videoRecorderStabilizationModeCinematic => 'Sinematik';

  @override
  String get videoRecorderStabilizationModeCinematicExtended =>
      'Sinematik Diperluas';

  @override
  String get videoRecorderStabilizationModePreviewOptimized =>
      'Dioptimalkan untuk pratinjau';

  @override
  String get videoRecorderStabilizationModeLowLatency => 'Latensi rendah';

  @override
  String get videoRecorderStabilizationModeAuto => 'Otomatis';

  @override
  String get videoRecorderFlashValueOff => 'Nonaktif';

  @override
  String get videoRecorderFlashValueOn => 'Aktif';

  @override
  String get videoRecorderFlashValueAuto => 'Otomatis';

  @override
  String get videoRecorderTimerValueOff => 'Nonaktif';

  @override
  String get videoRecorderTimerValueThreeSeconds => '3 detik';

  @override
  String get videoRecorderTimerValueTenSeconds => '10 detik';

  @override
  String get videoRecorderAspectRatioValueSquare => 'Persegi';

  @override
  String get videoRecorderAspectRatioValueVertical => 'Vertikal';

  @override
  String get videoRecorderCameraValueFront => 'Kamera depan';

  @override
  String get videoRecorderCameraValueBack => 'Kamera belakang';

  @override
  String get videoRecorderLibraryEmptyLabel =>
      'Perpustakaan klip, tidak ada klip';

  @override
  String videoRecorderLibraryOpenLabel(int clipCount) {
    String _temp0 = intl.Intl.pluralLogic(
      clipCount,
      locale: localeName,
      other: 'Buka perpustakaan klip, $clipCount klip',
      one: 'Buka perpustakaan klip, 1 klip',
    );
    return '$_temp0';
  }

  @override
  String videoRecorderLibraryOpenStopMotionLabel(int frameCount) {
    String _temp0 = intl.Intl.pluralLogic(
      frameCount,
      locale: localeName,
      other: 'Buka perpustakaan stop-motion, $frameCount bingkai',
      zero: 'Buka perpustakaan stop-motion',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorCameraLabel => 'Kamera';

  @override
  String get videoEditorOpenCameraSemanticLabel => 'Buka kamera';

  @override
  String get videoEditorLibraryLabel => 'Perpustakaan';

  @override
  String get videoEditorTextLabel => 'Teks';

  @override
  String get videoEditorDrawLabel => 'Gambar';

  @override
  String get videoEditorFilterLabel => 'Filter';

  @override
  String get videoEditorTuneLabel => 'Sesuaikan';

  @override
  String get videoEditorOpenTuneSemanticLabel => 'Buka editor penyesuaian';

  @override
  String get videoEditorTuneBrightness => 'Kecerahan';

  @override
  String get videoEditorTuneContrast => 'Kontras';

  @override
  String get videoEditorTuneSaturation => 'Saturasi';

  @override
  String get videoEditorTuneExposure => 'Eksposur';

  @override
  String get videoEditorTuneHue => 'Rona';

  @override
  String get videoEditorTuneTemperature => 'Suhu';

  @override
  String get videoEditorTuneTint => 'Semburat';

  @override
  String get videoEditorTuneFade => 'Pudar';

  @override
  String get videoEditorAudioLabel => 'Audio';

  @override
  String get videoEditorAddTitle => 'Tambah';

  @override
  String get videoEditorOpenLibrarySemanticLabel => 'Buka perpustakaan';

  @override
  String get videoEditorOpenAudioSemanticLabel => 'Buka editor audio';

  @override
  String get videoEditorCaptionsLabel => 'Subtitel';

  @override
  String get videoEditorOpenCaptionsSemanticLabel => 'Buka editor subtitel';

  @override
  String get videoEditorCaptionsBurnInLabel => 'Tanam ke video';

  @override
  String get videoEditorCaptionsPresetCustom => 'Kustom';

  @override
  String get videoEditorCaptionsCustomStyleTitle => 'Gaya kustom';

  @override
  String get videoEditorCaptionsCustomApply => 'Terapkan';

  @override
  String get videoEditorCaptionsCustomFont => 'Font';

  @override
  String get videoEditorCaptionsCustomTextColor => 'Warna teks';

  @override
  String get videoEditorCaptionsCustomBackground => 'Latar';

  @override
  String get videoEditorCaptionsCustomBackgroundColor => 'Warna latar';

  @override
  String get videoEditorCaptionsCustomAnimation => 'Animasi';

  @override
  String get videoEditorCaptionsAnimationNone => 'Tidak ada';

  @override
  String get videoEditorCaptionsAnimationFade => 'Pudar';

  @override
  String get videoEditorCaptionsAnimationPop => 'Pop';

  @override
  String get videoEditorCaptionsAnimationSpring => 'Pegas';

  @override
  String get videoEditorCaptionsEditTitle => 'Subtitel';

  @override
  String get videoEditorCaptionsGeneratingTitle => 'Mendengarkan…';

  @override
  String get videoEditorCaptionsGeneratingSubtitle =>
      'Mengubah audiomu jadi saran subtitel.';

  @override
  String get videoEditorCaptionsNoSpeechMessage =>
      'Kami tidak mendengar suara apa pun. Kamu tetap bisa menulis subtitel sendiri.';

  @override
  String get videoEditorCaptionsUnavailableMessage =>
      'Pengenalan suara tidak tersedia di perangkat ini. Kamu bisa menulis subtitel sendiri.';

  @override
  String get videoEditorCaptionsNotAuthorizedMessage =>
      'Pengenalan suara tidak diizinkan. Aktifkan di Pengaturan atau tulis subtitel sendiri.';

  @override
  String get videoEditorCaptionsFailedMessage =>
      'Transkripsi kali ini gagal. Kamu bisa menulis subtitel sendiri.';

  @override
  String get videoEditorCaptionsStartEmptyButton => 'Tulis subtitel sendiri';

  @override
  String get videoEditorCaptionsAddCue => 'Tambahkan subtitel';

  @override
  String get videoEditorCaptionsCueTextHint => 'Teks subtitel';

  @override
  String get videoEditorCaptionsCueDeleteSemanticLabel => 'Hapus subtitel';

  @override
  String get videoEditorCaptionsDeleteTrack => 'Hapus semua subtitel';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmTitle => 'Hapus subtitel?';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmSubtitle =>
      'Semua teks dan pengaturan waktu akan hilang.';

  @override
  String get videoEditorCaptionsCloseSemanticLabel => 'Tutup editor subtitel';

  @override
  String get videoEditorCaptionsDoneSemanticLabel => 'Konfirmasi subtitel';

  @override
  String get videoEditorCaptionsPresetTitle => 'Gaya subtitel';

  @override
  String get videoEditorCaptionsPresetClassic => 'Klasik';

  @override
  String get videoEditorCaptionsPresetPop => 'Pop';

  @override
  String get videoEditorCaptionsPresetZoom => 'Zoom';

  @override
  String get videoEditorCaptionsPresetSpring => 'Spring';

  @override
  String get videoEditorCaptionsPresetMono => 'Mono';

  @override
  String get videoEditorCaptionsPresetHeadline => 'Judul';

  @override
  String get videoEditorCaptionsPresetTypewriter => 'Mesin tik';

  @override
  String get videoEditorCaptionsPresetMarker => 'Spidol';

  @override
  String get videoEditorCaptionsPresetScript => 'Kaligrafi';

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
  String get videoEditorCaptionsPresetOcean => 'Samudra';

  @override
  String get videoEditorCaptionsPresetSunny => 'Cerah';

  @override
  String get videoEditorCaptionsPresetHandwritten => 'Tulisan tangan';

  @override
  String get videoEditorCaptionsPresetSerif => 'Serif';

  @override
  String get videoEditorCaptionsPresetStamp => 'Stempel';

  @override
  String get videoEditorOpenTextSemanticLabel => 'Buka editor teks';

  @override
  String get videoEditorOpenDrawSemanticLabel => 'Buka editor gambar';

  @override
  String get videoEditorOpenFilterSemanticLabel => 'Buka editor filter';

  @override
  String get videoEditorOpenStickerSemanticLabel => 'Buka editor stiker';

  @override
  String get videoEditorSaveDraftTitle => 'Simpan draf?';

  @override
  String get videoEditorSaveDraftSubtitle =>
      'Simpan editan untuk nanti, atau buang dan keluar dari editor.';

  @override
  String get videoEditorSaveDraftButton => 'Simpan draf';

  @override
  String get videoEditorDiscardChangesButton => 'Buang perubahan';

  @override
  String get videoEditorKeepEditingButton => 'Lanjutkan mengedit';

  @override
  String get videoEditorDeleteLayerDropZone =>
      'Area lepas untuk menghapus lapisan';

  @override
  String get videoEditorReleaseToDeleteLayer => 'Lepas untuk menghapus lapisan';

  @override
  String get videoEditorDoneLabel => 'Selesai';

  @override
  String get videoEditorPlayPauseSemanticLabel => 'Putar atau jeda video';

  @override
  String videoEditorSplitPositionInvalid(int minDurationMs) {
    return 'Posisi pembagian tidak valid. Setiap klip harus minimal ${minDurationMs}ms.';
  }

  @override
  String get videoEditorSaveSelectedClip => 'Simpan klip yang dipilih';

  @override
  String get videoEditorSaveClip => 'Simpan klip';

  @override
  String get videoEditorClipSavedSuccess => 'Klip disimpan ke perpustakaan';

  @override
  String get videoEditorClipSaveFailed => 'Gagal menyimpan klip';

  @override
  String get videoEditorColorPickerSemanticLabel => 'Pemilih warna';

  @override
  String get videoEditorUndoSemanticLabel => 'Batalkan';

  @override
  String get videoEditorRedoSemanticLabel => 'Ulangi';

  @override
  String get videoEditorTextColorSemanticLabel => 'Warna teks';

  @override
  String get videoEditorTextAlignmentSemanticLabel => 'Perataan teks';

  @override
  String get videoEditorTextBackgroundSemanticLabel => 'Latar belakang teks';

  @override
  String get videoEditorFontSemanticLabel => 'Font';

  @override
  String get videoEditorNoStickersFound => 'Stiker tidak ditemukan';

  @override
  String get videoEditorNoStickersAvailable => 'Tidak ada stiker tersedia';

  @override
  String get videoEditorFailedLoadStickers => 'Gagal memuat stiker';

  @override
  String get videoEditorVoiceOverLabel => 'Sulih suara';

  @override
  String videoEditorVoiceOverTakeName(int number) {
    return 'Rekaman $number';
  }

  @override
  String get videoEditorOpenVoiceOverSemanticLabel => 'Rekam sulih suara';

  @override
  String get videoEditorVoiceOverRecordSemanticLabel => 'Mulai merekam';

  @override
  String get videoEditorVoiceOverStopSemanticLabel => 'Hentikan rekaman';

  @override
  String get videoEditorVoiceOverHint =>
      'Ketuk untuk merekam. Tambahkan sebanyak yang kamu mau.';

  @override
  String videoEditorVoiceOverRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rekaman',
      one: '1 rekaman',
      zero: 'Belum ada rekaman',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorVoiceOverDeleteLast => 'Hapus rekaman terakhir';

  @override
  String get videoEditorVoiceOverPermissionTitle => 'Perlu akses mikrofon';

  @override
  String get videoEditorVoiceOverPermissionBody =>
      'Izinkan akses mikrofon untuk merekam sulih suara.';

  @override
  String get videoEditorVoiceOverOpenSettings => 'Buka pengaturan';

  @override
  String get videoEditorVoiceOverRecordingStarted => 'Rekaman dimulai';

  @override
  String get videoEditorVoiceOverRecordingSaved => 'Rekaman disimpan';

  @override
  String get videoEditorVoiceOverTooLong =>
      'Rekaman lebih panjang dari video Anda';

  @override
  String get videoEditorPlaySemanticLabel => 'Putar';

  @override
  String get videoEditorPauseSemanticLabel => 'Jeda';

  @override
  String get videoEditorVolumeSemanticLabel => 'Sesuaikan volume';

  @override
  String videoEditorTimelineVolumePreview(int percent) {
    return 'Volume $percent%';
  }

  @override
  String get videoEditorTimelineSlideToAdjust => 'Geser untuk menyesuaikan';

  @override
  String get videoEditorChromaKeyLabel => 'Layar hijau';

  @override
  String get videoEditorChromaKeyTitle => 'Layar hijau';

  @override
  String get videoEditorChromaKeySemanticLabel =>
      'Atur layar hijau untuk klip ini';

  @override
  String get videoEditorChromaKeyCloseSemanticLabel =>
      'Buang perubahan layar hijau';

  @override
  String get videoEditorChromaKeyDoneSemanticLabel => 'Terapkan layar hijau';

  @override
  String get videoEditorChromaKeyAutoDetect => 'Deteksi otomatis';

  @override
  String get videoEditorChromaKeyPresetGreen => 'Hijau';

  @override
  String get videoEditorChromaKeyPresetBlue => 'Biru';

  @override
  String get videoEditorChromaKeyScreenColorLabel => 'Warna layar';

  @override
  String get videoEditorChromaKeyAmountLabel => 'Kekuatan';

  @override
  String get videoEditorChromaKeyAmountHint =>
      'Seberapa banyak warna layar yang hilang';

  @override
  String get videoEditorChromaKeyEdgeLabel => 'Tepi';

  @override
  String get videoEditorChromaKeyEdgeHint =>
      'Melembutkan potongan agar rambut tidak bergerigi';

  @override
  String get videoEditorChromaKeySpillLabel => 'Rembesan';

  @override
  String get videoEditorChromaKeySpillHint =>
      'Menarik warna layar dari subjekmu';

  @override
  String get videoEditorChromaKeyBackgroundLabel => 'Ganti dengan';

  @override
  String get videoEditorChromaKeyBackgroundNone => 'Tidak ada';

  @override
  String get videoEditorChromaKeyBackgroundColor => 'Warna';

  @override
  String get videoEditorChromaKeyBackgroundImage => 'Gambar';

  @override
  String get videoEditorChromaKeyBackgroundVideo => 'Klip';

  @override
  String get videoEditorChromaKeyTransparentHint =>
      'Video tidak bisa menyimpan transparansi, jadi hasil ekspornya hitam.';

  @override
  String get videoEditorChromaKeyDetectFailed =>
      'Layar tidak ditemukan. Layar harus mencapai tepi bingkai — kalau tidak, pilih warnanya secara manual.';

  @override
  String get videoEditorChromaKeyPickClipTitle => 'Pilih klip';

  @override
  String get videoEditorChromaKeyNoLibraryClips =>
      'Pustakamu kosong. Simpan klip dulu, lalu pakai sebagai latar.';

  @override
  String get videoEditorChromaKeyImagePickFailed =>
      'Gambar itu tidak bisa dimuat.';

  @override
  String get videoEditorChromaKeyRemove => 'Hapus layar hijau';

  @override
  String get videoEditorChromaKeyFailed =>
      'Layar hijau tidak bisa diterapkan. Klipmu tidak berubah.';

  @override
  String get videoEditorChromaKeyRemoveFailed =>
      'Layar hijau tidak bisa dihapus. Klipmu tidak berubah.';

  @override
  String get videoEditorChromaKeyApplying => 'Menerapkan layar hijau…';

  @override
  String get videoEditorChromaKeyPreviewUnavailable =>
      'Perangkat ini tidak bisa menampilkan pratinjau langsung. Pengaturanmu tetap berlaku saat ekspor.';

  @override
  String videoEditorClipVolumeLabel(int index) {
    return 'Klip $index';
  }

  @override
  String get videoEditorDeleteLabel => 'Hapus';

  @override
  String get videoEditorDeleteSelectedItemSemanticLabel =>
      'Hapus item yang dipilih';

  @override
  String get videoEditorStopMotionFramesPerImageLabel => 'Bingkai per gambar';

  @override
  String videoEditorStopMotionFramesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bingkai',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorStopMotionFramesPerImageButtonLabel => 'Bingkai';

  @override
  String videoEditorStopMotionFramesPerImageValueSemanticLabel(int count) {
    return '$count bingkai per gambar';
  }

  @override
  String videoEditorStopMotionFrameSemanticLabel(int position, int total) {
    return 'Bingkai stop-motion $position dari $total';
  }

  @override
  String get videoEditorEditLabel => 'Edit';

  @override
  String get videoEditorEditSelectedItemSemanticLabel =>
      'Edit item yang dipilih';

  @override
  String get videoEditorDuplicateLabel => 'Duplikat';

  @override
  String get videoEditorDuplicateSelectedItemSemanticLabel =>
      'Duplikat item yang dipilih';

  @override
  String get videoEditorCombineLabel => 'Gabungkan';

  @override
  String get videoEditorCombineDrawLayersSemanticLabel =>
      'Gabungkan gambar terpilih menjadi satu lapisan';

  @override
  String get videoEditorSplitLabel => 'Bagi';

  @override
  String get videoEditorSplitSelectedClipSemanticLabel =>
      'Bagi klip yang dipilih';

  @override
  String get videoEditorExtractAudioLabel => 'Ekstrak audio';

  @override
  String get videoEditorClipAudioTitle => 'Audio klip';

  @override
  String get videoEditorExtractAudioFromClipSemanticLabel =>
      'Ekstrak audio dari klip dan bisukan aslinya';

  @override
  String get videoEditorExtractAudioNoLocalFile =>
      'Tidak dapat mengekstrak audio: klip tidak tersedia secara lokal.';

  @override
  String get videoEditorExtractAudioFailed =>
      'Tidak dapat mengekstrak audio. Silakan coba lagi.';

  @override
  String get videoEditorSpeedLabel => 'Kecepatan';

  @override
  String get videoEditorSetClipSpeedSemanticLabel =>
      'Atur kecepatan putar untuk klip yang dipilih';

  @override
  String get videoEditorReverseLabel => 'Balik';

  @override
  String get videoEditorReverseClipSemanticLabel =>
      'Aktifkan atau nonaktifkan pemutaran terbalik untuk klip yang dipilih';

  @override
  String get videoEditorReverseProgressLabel =>
      'Tunggu sebentar, kami sedang membalik klip Anda';

  @override
  String get videoEditorTransformLabel => 'Transformasi';

  @override
  String get videoEditorTransformSelectedClipSemanticLabel =>
      'Pangkas, putar, atau balik klip yang dipilih';

  @override
  String get videoEditorTransformProgressLabel =>
      'Sebentar, kami sedang mentransformasi klip Anda';

  @override
  String get videoEditorTransformFailed =>
      'Tidak dapat mentransformasi klip. Silakan coba lagi.';

  @override
  String get videoEditorTransformNoLocalFile =>
      'Tidak dapat mentransformasi: klip tidak tersedia secara lokal.';

  @override
  String get videoEditorTransformSelectedFrameSemanticLabel =>
      'Pangkas, putar, atau balik bingkai yang dipilih';

  @override
  String get videoEditorTransformFrameProgressLabel =>
      'Sebentar, kami sedang mengubah bingkaimu';

  @override
  String get videoEditorTransformFrameFailed =>
      'Bingkai tidak dapat diubah. Coba lagi.';

  @override
  String get videoEditorTransformRotateLabel => 'Putar';

  @override
  String get videoEditorTransformFlipLabel => 'Balik';

  @override
  String get videoEditorTransformResetLabel => 'Atur ulang';

  @override
  String get videoEditorTransformApplySemanticLabel => 'Terapkan transformasi';

  @override
  String get videoEditorTransformCancelSemanticLabel => 'Batalkan transformasi';

  @override
  String get videoEditorTransformPlayLabel => 'Putar';

  @override
  String get videoEditorTransformPauseLabel => 'Jeda';

  @override
  String get videoEditorReverseNoLocalFile =>
      'Tidak dapat membalik: klip tidak tersedia secara lokal.';

  @override
  String get videoEditorReverseFailed =>
      'Tidak dapat membalik klip. Silakan coba lagi.';

  @override
  String get videoEditorSpeedSheetTitle => 'Kecepatan Klip';

  @override
  String get videoEditorTransitionSheetTitle => 'Transisi';

  @override
  String get videoEditorTransitionNone => 'Tidak ada';

  @override
  String get videoEditorTransitionDissolve => 'Larut';

  @override
  String get videoEditorTransitionFadeToBlack => 'Pudar ke hitam';

  @override
  String get videoEditorTransitionFadeToWhite => 'Pudar ke putih';

  @override
  String get videoEditorTransitionSlide => 'Geser';

  @override
  String get videoEditorTransitionPush => 'Dorong';

  @override
  String get videoEditorTransitionWipe => 'Sapu';

  @override
  String get videoEditorTransitionButtonSemanticLabel => 'Edit transisi';

  @override
  String get videoEditorLoopTransitionSheetTitle => 'Transisi loop';

  @override
  String get videoEditorLoopTransitionButtonSemanticLabel =>
      'Edit transisi loop';

  @override
  String get videoEditorTransitionDuration => 'Durasi';

  @override
  String get videoEditorTransitionDurationLimitedHint =>
      'Dipendekkan agar tidak tumpang tindih dengan transisi di sebelahnya.';

  @override
  String get videoEditorTransitionCurve => 'Kurva';

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
    return 'Kurva animasi $number';
  }

  @override
  String get videoEditorLayerAnimationLabel => 'Animasi';

  @override
  String get videoEditorLayerAnimationButtonSemanticLabel =>
      'Edit animasi lapisan';

  @override
  String get videoEditorLayerAnimationEnter => 'Masuk';

  @override
  String get videoEditorLayerAnimationLeave => 'Keluar';

  @override
  String get videoEditorLayerAnimationFade => 'Pudar';

  @override
  String get videoEditorLayerAnimationScale => 'Skala';

  @override
  String get videoEditorLayerAnimationScaleFrom => 'Skala dari';

  @override
  String get videoEditorFinishTimelineEditingSemanticLabel =>
      'Selesai mengedit timeline';

  @override
  String get videoEditorAudioPlayPreviewSemanticLabel => 'Putar pratinjau';

  @override
  String get videoEditorAudioPausePreviewSemanticLabel => 'Jeda pratinjau';

  @override
  String get videoEditorAudioUntitledSound => 'Suara tanpa judul';

  @override
  String get videoEditorAudioUntitled => 'Tanpa judul';

  @override
  String get videoEditorAudioAddAudio => 'Tambah audio';

  @override
  String get videoEditorAudioNoSoundsAvailableTitle =>
      'Tidak ada suara tersedia';

  @override
  String get videoEditorAudioNoSoundsAvailableSubtitle =>
      'Suara akan muncul di sini saat kreator berbagi audio';

  @override
  String get videoEditorAudioFailedToLoadTitle => 'Gagal memuat suara';

  @override
  String get videoEditorAudioSegmentInstruction =>
      'Pilih segmen audio untuk videomu';

  @override
  String get videoEditorAudioCategoryDivine => 'Divine';

  @override
  String get videoEditorAudioCategoryCommunity => 'Komunitas';

  @override
  String get videoEditorAudioCategoryFeatured => 'Unggulan';

  @override
  String get videoEditorAudioCategoryMySounds => 'Suara Saya';

  @override
  String get videoEditorDrawToolArrowSemanticLabel => 'Alat panah';

  @override
  String get videoEditorDrawToolEraserSemanticLabel => 'Alat penghapus';

  @override
  String get videoEditorDrawToolMarkerSemanticLabel => 'Alat marker';

  @override
  String get videoEditorDrawToolPencilSemanticLabel => 'Alat pensil';

  @override
  String get videoEditorShowTimelineSemanticLabel => 'Tampilkan timeline';

  @override
  String get videoEditorHideTimelineSemanticLabel => 'Sembunyikan timeline';

  @override
  String get videoEditorFeedPreviewContent =>
      'Hindari menempatkan konten di belakang area ini.';

  @override
  String get videoEditorStickersDivineOriginals => 'Divine Orisinal';

  @override
  String get videoEditorStickerSearchHint => 'Cari stiker...';

  @override
  String get videoEditorSelectFontSemanticLabel => 'Pilih font';

  @override
  String get videoEditorFontUnknown => 'Tidak dikenal';

  @override
  String get videoEditorSplitPlayheadOutsideClip =>
      'Playhead harus berada di dalam klip yang dipilih untuk membagi.';

  @override
  String get videoEditorTimelineTrimStartSemanticLabel => 'Pangkas awal';

  @override
  String get videoEditorTimelineTrimEndSemanticLabel => 'Pangkas akhir';

  @override
  String get videoEditorTimelineTrimClipSemanticLabel => 'Pangkas klip';

  @override
  String get videoEditorTimelineTrimClipHint =>
      'Seret pegangan untuk mengatur durasi klip';

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
    return 'Klip $index dari $total, $duration detik';
  }

  @override
  String get videoEditorTimelineClipReorderHint =>
      'Tekan lama untuk mengurutkan ulang';

  @override
  String get videoEditorTimelineClipMoveLeft => 'Geser ke kiri';

  @override
  String get videoEditorTimelineClipMoveRight => 'Geser ke kanan';

  @override
  String videoEditorTimelineClipSelectedSemanticLabel(int index, int total) {
    return 'Klip $index dari $total, dipilih';
  }

  @override
  String videoEditorTimelineClipUnselectedSemanticLabel(int index, int total) {
    return 'Klip $index dari $total, tidak dipilih';
  }

  @override
  String get videoEditorMultiSelectLabel => 'Pilih';

  @override
  String get videoEditorMultiSelectSemanticLabel => 'Pilih beberapa klip';

  @override
  String get videoEditorMultiSelectDoneSemanticLabel => 'Selesai memilih';

  @override
  String videoEditorMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klip dipilih',
      one: '1 klip dipilih',
      zero: 'Tidak ada klip dipilih',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorLayerMultiSelectSemanticLabel =>
      'Pilih beberapa gambar';

  @override
  String get videoEditorLayerMultiSelectDoneSemanticLabel =>
      'Selesai memilih gambar';

  @override
  String get videoEditorDeleteSelectedDrawingsSemanticLabel =>
      'Hapus gambar yang dipilih';

  @override
  String videoEditorLayerMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gambar dipilih',
      one: '1 gambar dipilih',
      zero: 'Tidak ada gambar dipilih',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorMergeLabel => 'Gabungkan';

  @override
  String get videoEditorMergeSelectedClipsSemanticLabel =>
      'Gabungkan klip yang dipilih';

  @override
  String get videoEditorDeleteSelectedClipsSemanticLabel =>
      'Hapus klip yang dipilih';

  @override
  String get videoEditorDeleteSelectedFramesSemanticLabel =>
      'Hapus bingkai yang dipilih';

  @override
  String get videoEditorReverseSelectedFramesSemanticLabel =>
      'Balikkan bingkai yang dipilih';

  @override
  String get videoEditorDuplicateSelectedFramesSemanticLabel =>
      'Duplikat bingkai yang dipilih';

  @override
  String videoEditorStopMotionTooShortSnackbar(int seconds) {
    return 'Videomu harus minimal $seconds detik — ambil beberapa bingkai lagi.';
  }

  @override
  String get videoEditorMergeProgressLabel =>
      'Sebentar, kami sedang menggabungkan klipmu';

  @override
  String get videoEditorMergeFailed =>
      'Tidak dapat menggabungkan klip. Silakan coba lagi.';

  @override
  String get videoEditorTimelineLongPressToDragHint =>
      'Tekan lama untuk menyeret';

  @override
  String get videoEditorVideoTimelineSemanticLabel => 'Timeline video';

  @override
  String videoEditorTimelinePositionFormat(int minutes, String seconds) {
    return '${minutes}m ${seconds}d';
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
  String get videoEditorConfirmColorSemanticLabel => 'Konfirmasi warna';

  @override
  String get videoEditorSaturationBrightnessSemanticLabel =>
      'Saturasi dan kecerahan';

  @override
  String videoEditorSaturationBrightnessValue(int saturation, int brightness) {
    return 'Saturasi $saturation%, Kecerahan $brightness%';
  }

  @override
  String get videoEditorHueSemanticLabel => 'Rona';

  @override
  String get videoEditorAddElementSemanticLabel => 'Tambah elemen';

  @override
  String get videoEditorDoneSemanticLabel => 'Selesai';

  @override
  String get videoEditorLevelSemanticLabel => 'Level';

  @override
  String get videoMetadataClosePostDetailsSemanticLabel =>
      'Tutup detail postingan';

  @override
  String get videoMetadataDismissHelpDialogSemanticLabel =>
      'Tutup dialog bantuan';

  @override
  String get videoMetadataGotItButton => 'Mengerti!';

  @override
  String get videoMetadataLimitReachedWarning =>
      'Batas 64KB tercapai. Hapus beberapa konten untuk melanjutkan.';

  @override
  String get videoMetadataExpirationLabel => 'Kedaluwarsa';

  @override
  String get videoMetadataSelectExpirationSemanticLabel =>
      'Pilih waktu kedaluwarsa';

  @override
  String get videoMetadataTitleLabel => 'Judul';

  @override
  String get videoMetadataDescriptionLabel => 'Deskripsi';

  @override
  String get videoMetadataTagsLabel => 'Tag';

  @override
  String videoMetadataDeleteTagHint(String tag) {
    return 'Hapus tag $tag';
  }

  @override
  String get videoMetadataContentWarningLabel => 'Peringatan Konten';

  @override
  String get videoMetadataSelectContentWarningsSemanticLabel =>
      'Pilih peringatan konten';

  @override
  String get videoMetadataContentWarningSelectAllThatApply =>
      'Pilih semua yang berlaku untuk kontenmu';

  @override
  String get videoMetadataAudioReuseSubtitle =>
      'Izinkan orang lain menyimpan dan menggunakan kembali audio video ini.';

  @override
  String get publishAudioReuseDegradedWarning =>
      'Videomu sudah tayang, tapi suaranya belum terbit. Edit videonya untuk membagikan suaranya.';

  @override
  String get videoMetadataCollaboratorsLabel => 'Kolaborator';

  @override
  String get videoMetadataAddCollaboratorSemanticLabel => 'Tambah kolaborator';

  @override
  String get videoMetadataMutualFollowersSearchText =>
      'Pengikut saling mengikuti';

  @override
  String get videoMetadataInspiredByLabel => 'Terinspirasi oleh';

  @override
  String get videoMetadataSetInspiredBySemanticLabel => 'Atur inspirasi';

  @override
  String get videoMetadataCreatorCannotBeReferencedSnackbar =>
      'Kreator ini tidak dapat direferensikan.';

  @override
  String get videoMetadataPostDetailsTitle => 'Detail postingan';

  @override
  String get videoMetadataSavedToLibrarySnackbar => 'Disimpan ke perpustakaan';

  @override
  String get videoMetadataFailedToSaveSnackbar => 'Gagal menyimpan';

  @override
  String get videoMetadataGoToLibraryButton => 'Pergi ke Perpustakaan';

  @override
  String get videoMetadataSaveForLaterSemanticLabel =>
      'Tombol simpan untuk nanti';

  @override
  String get videoMetadataSavingVideoHint => 'Menyimpan video...';

  @override
  String videoMetadataSaveToDraftsHint(String destination) {
    return 'Simpan video ke draf dan $destination';
  }

  @override
  String videoMetadataSaveToDraftsWithoutGalleryHint(String destination) {
    return 'Simpan video ke draf. Belum ada video hasil render, jadi tidak ada salinan di $destination.';
  }

  @override
  String get videoMetadataSaveForLaterButton => 'Simpan untuk Nanti';

  @override
  String get videoMetadataPostSemanticLabel => 'Tombol posting';

  @override
  String get videoMetadataPublishVideoHint => 'Publikasikan video ke feed';

  @override
  String get videoMetadataShareReplyToFeedTitle => 'Bagikan juga ke feed saya';

  @override
  String get videoMetadataShareReplyToFeedSubtitle =>
      'Jika dimatikan, video ini hanya tetap di utas komentar.';

  @override
  String get videoMetadataFormNotReadyHint => 'Isi formulir untuk mengaktifkan';

  @override
  String get videoMetadataPostButton => 'Posting';

  @override
  String get videoMetadataOpenPreviewSemanticLabel =>
      'Buka layar pratinjau postingan';

  @override
  String get videoMetadataShareTitle => 'Bagikan';

  @override
  String get videoMetadataVideoDetailsSubtitle => 'Detail video';

  @override
  String get videoMetadataClassicDoneButton => 'Selesai';

  @override
  String get videoMetadataPlayPreviewSemanticLabel => 'Putar pratinjau';

  @override
  String get videoMetadataPausePreviewSemanticLabel => 'Jeda pratinjau';

  @override
  String get videoMetadataClosePreviewSemanticLabel => 'Tutup pratinjau video';

  @override
  String get videoMetadataRemoveSemanticLabel => 'Hapus';

  @override
  String get fullscreenFeedRemovedMessage => 'Video dihapus';

  @override
  String get fullscreenFeedEmptyMessage =>
      'Tidak ada lagi yang bisa diputar di sini';

  @override
  String get settingsBadgesTitle => 'Badge';

  @override
  String get settingsBadgesSubtitle =>
      'Terima penghargaan dan cek status badge yang diberikan.';

  @override
  String get badgesTitle => 'Badge';

  @override
  String get badgesLoadError => 'Gagal memuat badge';

  @override
  String get badgesUpdateError => 'Gagal memperbarui badge';

  @override
  String get badgesAwardedEmptyTitle => 'Belum ada badge yang diberikan';

  @override
  String get badgesAwardedEmptySubtitle =>
      'Saat seseorang memberimu badge Nostr, akan muncul di sini.';

  @override
  String get badgesStatusAccepted => 'Diterima';

  @override
  String get badgesStatusNotAccepted => 'Belum diterima';

  @override
  String get badgesActionRemove => 'Hapus';

  @override
  String get badgesActionAccept => 'Terima';

  @override
  String get badgesActionReject => 'Tolak';

  @override
  String get badgesIssuedEmptyTitle => 'Belum ada badge yang diberikan';

  @override
  String get badgesIssuedEmptySubtitle =>
      'Badge yang kamu berikan akan menampilkan status penerimaan di sini.';

  @override
  String get badgesIssuedNoRecipients =>
      'Tidak ada penerima untuk penghargaan ini.';

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
  String get badgesHiddenSnackbarUndo => 'Urungkan';

  @override
  String get badgesTabAwarded => 'Diterima';

  @override
  String get badgesTabCreated => 'Dibuat';

  @override
  String get badgesTabIssued => 'Diberikan';

  @override
  String get badgesCreateAction => 'Lencana baru';

  @override
  String get badgesCreatedEmptyTitle => 'Belum ada lencana buatanmu';

  @override
  String get badgesCreatedEmptySubtitle =>
      'Buat satu dan berikan ke orang yang pantas menerimanya.';

  @override
  String badgesCreatedAwardSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Diberikan ke $count orang',
      one: 'Diberikan ke 1 orang',
      zero: 'Belum diberikan',
    );
    return '$_temp0';
  }

  @override
  String get badgeEditorCreateTitle => 'Lencana baru';

  @override
  String get badgeEditorEditTitle => 'Ubah lencana';

  @override
  String get badgeEditorNameLabel => 'Nama';

  @override
  String get badgeEditorNameHint => 'Pencuri Panggung';

  @override
  String get badgeEditorIdentifierLabel => 'Pengenal';

  @override
  String get badgeEditorIdentifierHelp =>
      'Bagian dari alamat lencana, jadi tidak berubah setelah lencananya ada.';

  @override
  String get badgeEditorIdentifierTaken =>
      'Kamu sudah punya lencana dengan pengenal ini. Ubah yang itu — menerbitkan di sini akan menggantikannya.';

  @override
  String get badgeEditorIdentifierRequired =>
      'Setiap lencana butuh pengenal — ketik sendiri kalau nama tidak mengisinya.';

  @override
  String get badgeEditorDescriptionLabel => 'Deskripsi';

  @override
  String get badgeEditorDescriptionHint =>
      'Untuk yang mencuri perhatian lewat satu loop saja.';

  @override
  String get badgeEditorArtworkLabel => 'Gambar';

  @override
  String get badgeEditorArtworkAdd => 'Tambah gambar';

  @override
  String get badgeEditorArtworkReplace => 'Ganti';

  @override
  String get badgeEditorArtworkError => 'Gambar itu gagal diunggah';

  @override
  String get badgeEditorArtworkRequired => 'Setiap lencana butuh gambar.';

  @override
  String get badgeEditorArtworkRemove => 'Hapus gambar';

  @override
  String get badgeEditorArtworkSheetTitle => 'Gambar lencana';

  @override
  String get badgeDetailDeleteAction => 'Hapus lencana';

  @override
  String get badgeDetailDeleteTitle => 'Hapus lencana ini?';

  @override
  String get badgeDetailDeleteBody =>
      'Ini meminta relai menghapus lencana dan semua pemberian yang kamu lakukan. Relai boleh menolak, dan yang sudah menyematkannya tetap menyimpannya di profil sampai mereka melepasnya.';

  @override
  String get badgeDetailDeleteConfirm => 'Hapus';

  @override
  String get badgeEditorSaveAction => 'Terbitkan lencana';

  @override
  String get badgeEditorSaveError => 'Lencana gagal diterbitkan';

  @override
  String get badgeEditorLoadError => 'Lencana ini gagal dimuat';

  @override
  String get badgeDetailTitle => 'Lencana';

  @override
  String get badgeDetailMadeBy => 'Dibuat oleh';

  @override
  String get badgeDetailRecipientsTitle => 'Diberikan ke';

  @override
  String get badgeDetailNoRecipients => 'Belum ada yang punya ini.';

  @override
  String get badgeDetailAwardAction => 'Berikan lencana ini';

  @override
  String get badgeDetailEditAction => 'Ubah lencana';

  @override
  String get badgeDetailShareAction => 'Bagikan';

  @override
  String badgeDetailShareMessage(String link) {
    return 'Lihat lencana ini di Divine: $link';
  }

  @override
  String get badgeDetailRevokeAction => 'Tarik lencana';

  @override
  String get badgeDetailRevokeTitle => 'Tarik lencana ini?';

  @override
  String get badgeDetailRevokeBody =>
      'Ini meminta relai menghapus pemberian yang kamu lakukan untuk orang ini. Relai boleh menolak, dan kalau lencananya sudah disematkan, lencana itu tetap di profilnya sampai dia melepasnya. Bagaimanapun, dia tidak diberi tahu.';

  @override
  String get badgeDetailRevokeSelfBody =>
      'Ini meminta relai menghapus pemberian yang kamu buat untuk dirimu sendiri, dan melepas lencana dari profilmu. Kalau relai menolak penghapusan, tidak ada yang berubah.';

  @override
  String get badgeDetailRevokeConfirm => 'Tarik';

  @override
  String get badgeDetailRevokeSuccess => 'Lencana ditarik';

  @override
  String get badgeDetailBlockClaimantsAction => 'Blokir pengklaim lencana';

  @override
  String get badgeDetailBlockClaimantsTitle => 'Blokir pengklaim lencana';

  @override
  String get badgeDetailBlockClaimantsLoadError =>
      'Tidak bisa memuat pengklaim lencana ini';

  @override
  String get badgeDetailBlockClaimantsEmptyTitle =>
      'Belum ada yang mengklaim lencana ini';

  @override
  String get badgeDetailBlockClaimantsEmptyBody =>
      'Kami tidak menemukan pengklaim saat ini untuk diblokir.';

  @override
  String badgeDetailBlockClaimantsHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Blokir $count pengklaim?',
      one: 'Blokir 1 pengklaim?',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Ini memblokir $count akun yang sedang mengklaim lencana ini. Postingan mereka akan keluar dari feed-mu, dan mereka tidak akan diberi tahu.',
      one:
          'Ini memblokir akun yang sedang mengklaim lencana ini. Postingannya akan keluar dari feed-mu, dan mereka tidak akan diberi tahu.',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Blokir $count akun',
      one: 'Blokir 1 akun',
    );
    return '$_temp0';
  }

  @override
  String get badgeDetailBlockClaimantsSuccess => 'Pengklaim lencana diblokir';

  @override
  String get badgeDetailBlockClaimantsFailure =>
      'Tidak bisa memblokir pengklaim lencana';

  @override
  String get badgeDetailLoadError => 'Lencana ini gagal dimuat';

  @override
  String get badgeDetailMissing =>
      'Kami tidak menemukan lencana ini di relai mana pun.';

  @override
  String get badgeDetailActionError => 'Itu tidak berhasil';

  @override
  String get badgeAwardTitle => 'Berikan lencana';

  @override
  String get badgeAwardPickAction => 'Pilih orang';

  @override
  String get badgeAwardManualLabel => 'Atau tempel kunci';

  @override
  String get badgeAwardManualHint => 'npub1…, npub1…';

  @override
  String get badgeAwardEmptyHint => 'Pilih setidaknya satu orang.';

  @override
  String badgeAwardSubmitAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Berikan ke $count orang',
      one: 'Berikan ke 1 orang',
      zero: 'Berikan lencana',
    );
    return '$_temp0';
  }

  @override
  String get profileBadgeAwardedBy => 'Diberikan oleh';

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
      'Badge adalah penghargaan kecil yang bisa dibuat siapa saja di Nostr. Beri satu untuk teman, kreator, atau siapa pun yang membuat harimu.';

  @override
  String get profileBadgeFooterLink => 'Buat lencanamu sendiri';

  @override
  String get minorAccountReviewWelcomePageTitle => 'Panduan keluarga';

  @override
  String get minorAccountReviewWelcomeTitle => 'Belum 16 tahun? Nggak apa-apa.';

  @override
  String get minorAccountReviewWelcomeBody =>
      'Kamu membuka halaman ini alih-alih asal memilih jawaban yang bikin kamu langsung masuk — itu berarti. Itu menunjukkan kejujuran, keberanian, dan kepedulian nyata pada orang-orang di sekitarmu.\n\nAturan untuk orang di bawah 16 tahun berbeda-beda tergantung tempat kamu tinggal. Di Divine, kami ingin keluarga membicarakannya bersama dan memutuskan seperti apa penggunaan media sosial yang sehat.';

  @override
  String get minorAccountReviewModerationTitle =>
      'Kami butuh satu langkah lagi';

  @override
  String get minorAccountReviewModerationBody =>
      'Kami diminta memeriksa akun ini lebih teliti karena mungkin milik seseorang di bawah 16 tahun. Alur ini menjaga langkah berikutnya tetap privat dan menunjukkan jalur yang tepat untuk usiamu.';

  @override
  String get minorAccountReviewRulesTitle =>
      'Aturannya tidak sama di mana-mana';

  @override
  String get minorAccountReviewRulesBody =>
      'Setiap negara dan wilayah punya cara berbeda soal remaja memakai media sosial. Karena itu kami meminta keluarga untuk pelan-pelan, memeriksa faktanya, dan memilih langkah berikutnya bersama.';

  @override
  String get minorAccountReviewApproachTitle => 'Bagaimana Divine memandangnya';

  @override
  String get minorAccountReviewApproachBody =>
      'Menurut kami, kebiasaan sehat dengan teknologi lahir dari berhenti sejenak, merenung, dan mengalihkan perhatian ke hal yang lebih baik — bukan dari memata-matai anak atau menjadikan orang tua sebagai pengawas. Penelitian pun mendukung itu.';

  @override
  String get minorAccountReviewLearnMoreTitle => 'Lebih banyak untuk keluarga';

  @override
  String get minorAccountReviewKidsPolicyCta =>
      'Baca kebijakan Divine untuk anak';

  @override
  String get minorAccountReviewChooseAgeBandTitle => 'Pilih jalur yang cocok';

  @override
  String get minorAccountReviewUnder13Cta => 'Di bawah 13';

  @override
  String get minorAccountReviewTeenCta => 'Usia 13-15';

  @override
  String get minorAccountReviewFamilyResourcesBody =>
      'Kunjungi panduan keluarga Divine untuk tips praktis, alat percakapan, dan materi yang membantu remaja memakai media sosial dengan lebih aman.';

  @override
  String get minorAccountReviewFamilyResourcesCta =>
      'Dapatkan panduan dan tips keluarga';

  @override
  String get minorAccountReviewFooter =>
      'Kalau usiamu 16 tahun atau lebih dan kamu sampai ke sini karena keliru, hubungi dukungan Divine supaya orang sungguhan bisa memeriksanya.';

  @override
  String get minorAccountReviewTitle => 'Peninjauan akun';

  @override
  String get minorAccountReviewCheckingStatusTitle =>
      'Memeriksa status akun...';

  @override
  String get minorAccountReviewCheckingStatusBody =>
      'Tunggu sebentar sementara kami memastikan status peninjauan akun ini.';

  @override
  String get minorAccountReviewDefaultTitle => 'Peninjauan akun diperlukan';

  @override
  String get minorAccountReviewDefaultBody =>
      'Kami perlu meninjau akun ini sebelum bisa memakai Divine seperti biasa.';

  @override
  String minorAccountReviewCaseId(String caseId) {
    return 'ID kasus: $caseId';
  }

  @override
  String get minorAccountReviewCaseIdShortLabel => 'ID kasus';

  @override
  String get minorAccountReviewRestrictionsTitle => 'Yang dibatasi saat ini';

  @override
  String get minorAccountReviewRestrictionPosting =>
      'Memposting dan menerbitkan dihentikan sementara';

  @override
  String get minorAccountReviewRestrictionEngagement =>
      'Komentar, suka, repost, dan mengikuti dihentikan sementara';

  @override
  String get minorAccountReviewRestrictionMessaging =>
      'Memulai atau membalas pesan biasa dihentikan sementara';

  @override
  String get minorAccountReviewRestrictionSupport =>
      'Dukungan dan pesan moderasimu tetap tersedia';

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
  String get minorAccountReviewOpenSupportCenter => 'Buka pusat dukungan';

  @override
  String get minorAccountReviewOpenModerationMessage => 'Buka pesan moderasi';

  @override
  String get minorAccountReviewOpenReviewPage => 'Buka halaman peninjauan';

  @override
  String get minorAccountReviewCheckAgain => 'Periksa lagi';

  @override
  String get minorAccountReviewLogOut => 'Keluar';

  @override
  String get minorAccountReviewNextStepTitle => 'Langkah berikutnya';

  @override
  String get minorAccountReviewNextStepBody =>
      'Buka pusat dukungan atau pesan moderasimu kalau kamu butuh bantuan soal peninjauan ini.';

  @override
  String get minorAccountReviewInProgressTitle => 'Peninjauan sedang berjalan';

  @override
  String get minorAccountReviewInProgressBody =>
      'Untuk sekarang kami sudah punya yang dibutuhkan. Tim kami sedang meninjau kasus ini sebelum mengembalikan akses akun seperti biasa.';

  @override
  String get minorAccountReviewUnder13Title => 'Akun di bawah 13 tahun';

  @override
  String minorAccountReviewUnder13Body(String supportEmail) {
    return 'Kalau akun ini milik seseorang di bawah 13 tahun, orang tua atau wali harus mengirim email ke $supportEmail dan menyertakan ID kasus.';
  }

  @override
  String get minorAccountReviewUnder13PublicTitle =>
      'Kami belum bisa memberimu akun';

  @override
  String get minorAccountReviewUnder13PublicBody =>
      'Divine tidak dibuat untuk anak di bawah 13 tahun, dan aturan media sosial di berbagai negara mengikat tangan kami.\n\nBanyak hal di internet mendorongmu berbohong demi mendapat yang kamu mau, dan kami benci itu. Itu pelajaran yang salah untuk hidup, dan kami tidak akan mengajarkannya di sini.';

  @override
  String get minorAccountReviewUnder13FamilyTitle =>
      'Yang bisa dilakukan keluargamu sebagai gantinya';

  @override
  String get minorAccountReviewUnder13FamilyBody =>
      'Orang tua atau wali bisa memegang akunnya dan yang memposting, dan kamu tentu boleh ikut tampil di videonya bersama mereka. Kami ingin keluarga menikmati Divine dengan cara yang pas buat mereka.';

  @override
  String get minorAccountReviewUnder13ComeBackTitle => 'Saat kamu berusia 13';

  @override
  String get minorAccountReviewUnder13ComeBackBody =>
      'Tergantung aturan di tempat tinggalmu, kamu mungkin bisa kembali dan mengajukan akun sendiri. Kalau saat itu usiamu 13 sampai 15, kamu butuh izin dari orang tua atau wali.';

  @override
  String get minorAccountReviewUnder13HonestyTitle =>
      'Kenapa kami tidak akan menyuruhmu sekadar klik kembali';

  @override
  String get minorAccountReviewUnder13HonestyBody =>
      'Banyak bagian internet dirancang untuk memberi imbalan kepada orang yang mengatakan apa pun asal bisa lolos gerbang. Kami rasa itu tidak bagus. Ya, kamu bisa kembali dan bilang usiamu lebih tua dari sebenarnya, tapi itu tidak jujur, dan kami tidak akan mengarahkanmu untuk berbohong demi mendapat apa yang kamu mau.';

  @override
  String get minorAccountReviewUnder13LegalBody =>
      'Kami berusaha membantu anak muda memakai Divine dengan cara yang sehat dan positif untuk mereka dan orang-orang di sekitar mereka. Kami juga harus mengikuti hukum yang berbeda-beda di tiap tempat. Jadi, kalau kamu di bawah 13 tahun, jawabannya adalah kamu belum bisa punya akun sendiri hari ini.';

  @override
  String get minorAccountReviewTeenBody =>
      'Kalau akun ini milik seseorang berusia 13 sampai 15 tahun, pakai pesan moderasi atau jalur dukungan untuk mengikuti petunjuk izin orang tua.';

  @override
  String get minorAccountReviewParentConsentTitle =>
      'Kalau akunnya akan dipakai seseorang berusia 13 sampai 15';

  @override
  String get minorAccountReviewParentConsentBody =>
      'Orang tua atau wali harus mengirim email ke dukungan Divine dengan video pribadi singkat. Tim kami akan meninjaunya dan membantu langkah berikutnya.\n\nKalau menghubungi orang tua atau wali tidak memungkinkan atau justru membahayakan seseorang, kirim email ke dukungan Divine dan beri tahu kami.';

  @override
  String get minorAccountReviewParentConsentPauseNote =>
      'Ini jeda sementara tim dukungan Divine meninjau videonya. Kalau disetujui, mereka akan memandu kamu menyiapkan akun baru.';

  @override
  String get minorAccountReviewParentConsentHonestyTitle =>
      'Kenapa kami meminta orang tua atau wali untuk terlibat';

  @override
  String get minorAccountReviewParentConsentHonestyBody =>
      'Divine harus mengikuti hukum terkait usia di seluruh dunia. Kami juga tahu bahwa sebagian besar gerbang usia teknis tidak sempurna. Alih-alih berpura-pura aturan tidak ada atau bahwa berbohong soal usia itu keren, kami ingin remaja dan keluarga membuat keputusan yang bijak tentang cara terbaik memakai Divine. Itulah kenapa, untuk usia 13-15 tahun, kami meminta orang tua untuk menjadi bagian dari proses pembuatan akun.';

  @override
  String get minorAccountReviewParentConsentLegalBody =>
      'Kami juga harus mengikuti hukum, dan aturannya berbeda-beda tergantung tempat seseorang tinggal. Jadi alih-alih berpura-pura aturan tidak ada, kami meminta orang tua atau wali untuk menjadi bagian dari proses ini.';

  @override
  String get minorAccountReviewParentConsentChecklist =>
      'Yang harus terlihat di video';

  @override
  String get minorAccountReviewParentConsentChecklistKid =>
      'Remaja yang bersangkutan di video';

  @override
  String get minorAccountReviewParentConsentChecklistPermission =>
      'Orang tua atau wali yang berbicara di depan kamera';

  @override
  String get minorAccountReviewParentConsentChecklistAgeBand =>
      'Pernyataan jelas bahwa remaja tersebut berusia 13 sampai 15 dan diizinkan memakai Divine';

  @override
  String get minorAccountReviewParentConsentChecklistSupervision =>
      'Pernyataan jelas bahwa orang tua atau wali tahu soal akun ini dan akan mengawasi penggunaannya';

  @override
  String get minorAccountReviewParentConsentPrivacy => 'Cara mengirimnya';

  @override
  String get minorAccountReviewParentConsentNeverPost =>
      'Lampirkan videonya saat mengirim email ke dukungan Divine';

  @override
  String get minorAccountReviewParentConsentDoNotSave =>
      'Simpan videonya secara privat dan jangan diposting di aplikasi';

  @override
  String get minorAccountReviewParentConsentOneMove =>
      'Tim kami akan meninjaunya dan membalas dengan langkah berikutnya';

  @override
  String get minorAccountReviewParentConsentEmailCta => 'Email dukungan Divine';

  @override
  String get minorAccountReviewParentConsentEmailSubject =>
      'Bantuan peninjauan Divine Greenlight (usia 13-15)';

  @override
  String get minorAccountReviewParentConsentEmailBody =>
      'Halo tim dukungan Divine,\n\nsaya menghubungi Divine soal Divine Greenlight untuk remaja berusia 13-15.\n\nSaya melampirkan video privat singkat yang memperlihatkan:\n- remaja tersebut\n- orang tua atau wali yang berbicara di depan kamera\n- bahwa remaja tersebut diizinkan memakai Divine\n- bahwa orang tua atau wali tahu soal akun ini dan akan mengawasi penggunaannya\n\nNegara tempat tinggal:\n\nKonteks tambahan:\n\nTerima kasih.';

  @override
  String get minorAccountReviewParentSupportInstructions =>
      'Petunjuk dukungan untuk orang tua';

  @override
  String get minorAccountReviewContinue => 'Lanjut';

  @override
  String get minorAccountReviewErrorTitle =>
      'Kami tidak bisa memuat status peninjauan akunmu.';

  @override
  String get minorAccountReviewErrorBody => 'Coba lagi sebentar lagi.';

  @override
  String get minorAccountReviewTryAgain => 'Coba lagi';

  @override
  String get minorAccountReviewParentContactTitle => 'Kontak orang tua';

  @override
  String get minorAccountReviewParentContactHeading =>
      'Tambahkan email orang tua atau wali';

  @override
  String minorAccountReviewParentContactBody(String caseId) {
    return 'Kami akan memakai alamat ini untuk peninjauan izin orang tua pada kasus $caseId.';
  }

  @override
  String get minorAccountReviewParentContactFieldLabel =>
      'Email orang tua atau wali';

  @override
  String get minorAccountReviewSubmitting => 'Mengirim...';

  @override
  String get minorAccountReviewSubmitEmail => 'Kirim email';

  @override
  String get minorAccountReviewBackToReview => 'Kembali ke peninjauan akun';

  @override
  String get minorAccountReviewSubmissionReceivedTitle => 'Email terkirim';

  @override
  String minorAccountReviewSubmissionReceivedBody(String email) {
    return 'Kami mengirim $email untuk ditinjau. Kami akan mengirim email konfirmasi ke alamat itu. Begitu orang tua atau walimu membalas, kasusmu berlanjut. Pakai Periksa lagi di layar peninjauan akun untuk melihat perkembangannya.';
  }

  @override
  String get minorAccountReviewSubmissionReceivedLocalBody =>
      'Kami sudah menerima kontak orang tua atau wali untuk akun ini. Tim kami akan meninjaunya sebelum mengembalikan akses.';

  @override
  String get minorAccountReviewMissingCase =>
      'Kami tidak menemukan kasus peninjauan yang aktif untuk akun ini.';

  @override
  String get minorAccountReviewParentContactError =>
      'Email orang tua gagal dikirim. Coba lagi.';

  @override
  String get minorAccountReviewUnder13SupportTitle => 'Dukungan orang tua';

  @override
  String get minorAccountReviewUnder13Heading =>
      'Orang tua atau wali harus menghubungi Divine';

  @override
  String get minorAccountReviewUnder13SupportBody =>
      'Untuk akun yang kemungkinan di bawah 13 tahun, langkah berikutnya adalah orang tua atau wali menghubungi lewat email.';

  @override
  String get minorAccountReviewSupportEmailLabel => 'Email dukungan';

  @override
  String get minorAccountReviewCopySupportEmail => 'Salin email dukungan';

  @override
  String get minorAccountReviewSupportEmailCopied => 'Email dukungan disalin';

  @override
  String get minorAccountReviewCopyCaseId => 'Salin ID kasus';

  @override
  String get minorAccountReviewCaseIdCopied => 'ID kasus disalin';

  @override
  String get minorAccountReviewUnavailable => 'Tidak tersedia';

  @override
  String get minorAccountReviewUnder13Instructions =>
      'Minta orang tua atau wali menyertakan ID kasus dan menjelaskan bahwa mereka menghubungi Divine soal peninjauan akun ini.';

  @override
  String minorAccountReviewUnder13EmailSubject(String caseId) {
    return 'Peninjauan akun di bawah 13 untuk kasus $caseId';
  }

  @override
  String minorAccountReviewUnder13EmailBody(String caseId) {
    return 'Halo tim dukungan Divine,\n\nsaya orang tua atau wali dari anak di bawah 13 tahun dan menghubungi Divine soal kasus peninjauan akun $caseId.\n\nTerima kasih.';
  }

  @override
  String get devOptionsMinorReviewSimulationTitle =>
      'Simulasi peninjauan akun anak di bawah umur';

  @override
  String get devOptionsMinorReviewCurrentStateLabel => 'Status saat ini';

  @override
  String devOptionsMinorReviewStateRestricted(String state) {
    return 'Dibatasi ($state)';
  }

  @override
  String get devOptionsMinorReviewStateActive => 'Aktif';

  @override
  String get devOptionsMinorReviewStateLoading => 'Memuat...';

  @override
  String get devOptionsMinorReviewStateError => 'Gagal memuat status';

  @override
  String get devOptionsMinorReviewClearTitle =>
      'Bersihkan penggantian simulasi';

  @override
  String get devOptionsMinorReviewClearSubtitle =>
      'Pakai lagi backend atau status aktif bawaan';

  @override
  String get devOptionsMinorReviewTeenTitle =>
      'Simulasikan kasus peninjauan 13-15';

  @override
  String get devOptionsMinorReviewTeenSubtitle =>
      'Akun dibatasi dengan jalur kontak orang tua';

  @override
  String get devOptionsMinorReviewUnder13Title =>
      'Simulasikan kasus dukungan di bawah 13';

  @override
  String get devOptionsMinorReviewUnder13Subtitle =>
      'Akun dibatasi dengan petunjuk hanya lewat email orang tua';

  @override
  String get devOptionsMinorReviewClearedToast =>
      'Simulasi peninjauan akun anak di bawah umur dibersihkan';

  @override
  String get devOptionsMinorReviewUnder13EnabledToast =>
      'Simulasi kasus dukungan di bawah 13 diaktifkan';

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
      'Simulasi anak di bawah umur yang dilindungi';

  @override
  String get devOptionsProtectedMinorCurrentStateLabel => 'Status saat ini';

  @override
  String get devOptionsProtectedMinorStateProtected =>
      'Anak di bawah umur yang dilindungi (13-15)';

  @override
  String get devOptionsProtectedMinorStateNotProtected => 'Tidak dilindungi';

  @override
  String get devOptionsProtectedMinorStateLoading => 'Memuat…';

  @override
  String get devOptionsProtectedMinorStateError => 'Gagal membaca status';

  @override
  String get devOptionsProtectedMinorOverrideNone =>
      'Tanpa penggantian (status akun sebenarnya)';

  @override
  String get devOptionsProtectedMinorOverrideProtected =>
      'Penggantian: dipaksa dilindungi';

  @override
  String get devOptionsProtectedMinorOverrideNotProtected =>
      'Penggantian: dipaksa tidak dilindungi';

  @override
  String get devOptionsProtectedMinorSimulateTitle =>
      'Simulasikan anak di bawah umur yang dilindungi (13-15)';

  @override
  String get devOptionsProtectedMinorSimulateSubtitle =>
      'Paksa status anak-dilindungi untuk menguji proteksi #175/#176';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorTitle =>
      'Simulasikan orang dewasa';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorSubtitle =>
      'Paksa tidak dilindungi (penolakan eksplisit, beda dengan tanpa penggantian)';

  @override
  String get devOptionsProtectedMinorClearTitle => 'Bersihkan penggantian';

  @override
  String get devOptionsProtectedMinorClearSubtitle =>
      'Kembali ke status akun sebenarnya dari Keycast';

  @override
  String get devOptionsProtectedMinorEnabledToast =>
      'Status anak-dilindungi dipaksa aktif';

  @override
  String get devOptionsProtectedMinorNonMinorToast =>
      'Status anak-dilindungi dipaksa nonaktif';

  @override
  String get devOptionsProtectedMinorClearedToast =>
      'Penggantian anak-dilindungi dibersihkan';

  @override
  String get devOptionsInviteAvailabilityTitle => 'Undangan pendaftaran';

  @override
  String get devOptionsInviteAvailabilityCurrentLabel => 'Status saat ini';

  @override
  String get devOptionsInviteAvailabilityServerLoading =>
      'Nilai server: memuat';

  @override
  String get devOptionsInviteAvailabilityServerEnabled => 'Nilai server: aktif';

  @override
  String get devOptionsInviteAvailabilityServerDisabled =>
      'Nilai server: nonaktif';

  @override
  String get devOptionsInviteAvailabilityServerUnknown =>
      'Nilai server: tidak diketahui';

  @override
  String get devOptionsInviteAvailabilityOverrideNone =>
      'Penggantian: pakai nilai server';

  @override
  String get devOptionsInviteAvailabilityOverrideEnabled =>
      'Penggantian: paksa aktif';

  @override
  String get devOptionsInviteAvailabilityOverrideDisabled =>
      'Penggantian: paksa nonaktif';

  @override
  String get devOptionsInviteAvailabilityUseServer => 'Pakai nilai server';

  @override
  String get devOptionsInviteAvailabilityUseServerSubtitle =>
      'Ikuti onboardingMode dari layanan undangan';

  @override
  String get devOptionsInviteAvailabilityForceEnabled => 'Paksa aktif';

  @override
  String get devOptionsInviteAvailabilityForceEnabledSubtitle =>
      'Tampilkan gerbang undangan pendaftaran dan pengelolaannya secara lokal';

  @override
  String get devOptionsInviteAvailabilityForceDisabled => 'Paksa nonaktif';

  @override
  String get devOptionsInviteAvailabilityForceDisabledSubtitle =>
      'Sembunyikan antarmuka undangan pendaftaran secara lokal tanpa mengubah server';

  @override
  String get devOptionsInviteAvailabilityUseServerToast =>
      'Undangan pendaftaran kini mengikuti server';

  @override
  String get devOptionsInviteAvailabilityForceEnabledToast =>
      'Undangan pendaftaran dipaksa aktif';

  @override
  String get devOptionsInviteAvailabilityForceDisabledToast =>
      'Undangan pendaftaran dipaksa nonaktif';

  @override
  String get commentsRecordVideoButtonLabel => 'Rekam komentar video';

  @override
  String get commentsOpenVideoLabel => 'Buka komentar video';

  @override
  String get commentsMuteVideoReplyLabel => 'Bisukan balasan video';

  @override
  String get commentsUnmuteVideoReplyLabel => 'Aktifkan suara balasan video';

  @override
  String get commentsOpenReplyParentLabel => 'Buka video yang dibalas ini';

  @override
  String get commentsReplyParentSectionTitle => 'Menanggapi';

  @override
  String commentsReplyParentLabel(String target) {
    return 'Balas $target';
  }

  @override
  String get commentsReplyParentFallbackLabel => 'Balas video';

  @override
  String verifiedAccountChipSemanticLabel(String platform, String identity) {
    return 'Akun $platform terverifikasi: $identity';
  }

  @override
  String get profileEditVerifiedAccountsTitle => 'Akun terverifikasi';

  @override
  String get profileEditGetVerifiedCta => 'Verifikasi diri';

  @override
  String get profileEditGetVerifiedSubtitle =>
      'Hubungkan akun media sosialmu biar orang tahu ini memang kamu.';

  @override
  String profileWebsiteSemanticLabel(String url) {
    return 'Kunjungi situs web: $url';
  }

  @override
  String get profileCouldNotOpenWebsite => 'Situs web tidak bisa dibuka';

  @override
  String get videoMetadataEditCoverTitle => 'Edit sampul';

  @override
  String get videoMetadataEditCoverCloseSemanticLabel =>
      'Buang perubahan sampul';

  @override
  String get videoMetadataEditCoverConfirmSemanticLabel =>
      'Gunakan bingkai yang dipilih sebagai sampul video';

  @override
  String get videoMetadataEditCoverStripSemanticLabel =>
      'Gulir video untuk memilih bingkai sampul';

  @override
  String get videoMetadataTagsPickerSearchHint => 'Cari atau tambahkan tag';

  @override
  String get videoMetadataTagsPickerEmptyHint =>
      'Tambahkan tag agar orang menemukan videomu';

  @override
  String get videoMetadataTagsPickerNoResults => 'Tidak ada tag yang cocok';

  @override
  String videoMetadataTagsPickerAddTag(String tag) {
    return 'Tambahkan \"#$tag\"';
  }

  @override
  String get authMinAgeNotice => 'Divine Greenlight';

  @override
  String get authUnder16Prefix => 'Belum 16 tahun? Tidak apa-apa. ';

  @override
  String get authUnder16ChoicesCta => 'Ini pilihan-pilihanmu.';

  @override
  String get minorAccountReviewUnder13WhyTitle => 'Ini alasannya';

  @override
  String get generalSettingsHoldToRecord => 'Tahan untuk merekam';

  @override
  String get generalSettingsHoldToRecordSubtitle =>
      'Rekaman dimulai saat menahan dan berhenti saat dilepas';

  @override
  String uploadPublishedCountMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count video dipublikasikan ke profilmu',
      one: 'Video dipublikasikan ke profilmu',
    );
    return '$_temp0';
  }

  @override
  String get dmMessageSendLabel => 'Kirim pesan';

  @override
  String get emojiPickerSearchHint => 'Cari';

  @override
  String get emojiCategoryRecent => 'Terbaru';

  @override
  String get emojiCategorySmileys => 'Smiley & Orang';

  @override
  String get emojiCategoryAnimals => 'Hewan & Alam';

  @override
  String get emojiCategoryFood => 'Makanan & Minuman';

  @override
  String get emojiCategoryActivities => 'Aktivitas';

  @override
  String get emojiCategoryTravel => 'Perjalanan & Tempat';

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
      'Tambahkan penanda timeline';

  @override
  String get videoEditorRemoveTimelineMarkerSemanticLabel =>
      'Hapus penanda timeline';

  @override
  String get videoEditorRemoveTimelineMarkerAtPlayheadSemanticLabel =>
      'Hapus penanda di posisi pemutaran';

  @override
  String get videoEditorDeleteTimelineMarkerTitle => 'Hapus penanda?';

  @override
  String get videoEditorDeleteTimelineMarkerSubtitle =>
      'Ini menghapus penanda dari timeline. Editan Anda tetap utuh.';

  @override
  String get videoEditorVolumeLongPressHint =>
      'Bisukan atau aktifkan semua trek';

  @override
  String get videoEditorSplitFailed => 'Pembagian gagal. Silakan coba lagi.';

  @override
  String get videoEditEditSubtitles => 'Edit subtitle';

  @override
  String get subtitleEditorTitle => 'Edit subtitle';

  @override
  String get subtitleEditorSave => 'Simpan';

  @override
  String get subtitleEditorProcessing =>
      'Subtitle masih dibuat. Cek lagi sebentar.';

  @override
  String get subtitleEditorNoSpeech =>
      'Tidak ada percakapan yang terdeteksi di video ini, jadi tidak ada yang perlu disubtitle.';

  @override
  String get subtitleEditorWriteOwn => 'Tulis sendiri';

  @override
  String get subtitleEditorAddCue => 'Tambah baris';

  @override
  String get subtitleEditorRemoveCue => 'Hapus baris ini';

  @override
  String get subtitleEditorPreviewUnavailable =>
      'Video tidak bisa diputar sekarang, tapi kamu tetap bisa memperbaiki takarirnya.';

  @override
  String get subtitleEditorPlayPreview => 'Putar video';

  @override
  String get subtitleEditorPausePreview => 'Jeda video';

  @override
  String get subtitleEditorInvalidHint =>
      'Setiap baris butuh teks dan waktu selesai setelah waktu mulai.';

  @override
  String get subtitleEditorLoadError =>
      'Tidak bisa memuat subtitle. Coba lagi.';

  @override
  String get subtitleEditorSaveSuccess => 'Subtitle diperbarui';

  @override
  String get subtitleEditorSaveError =>
      'Tidak bisa menyimpan subtitle. Coba lagi.';

  @override
  String get subtitleEditorRetry => 'Coba lagi';

  @override
  String get subtitleEditorCueHint => 'Teks keterangan';

  @override
  String get imageCropEditorRotateLabel => 'Putar';

  @override
  String get imageCropEditorFlipLabel => 'Balik';

  @override
  String get imageCropEditorResetLabel => 'Atur ulang';

  @override
  String get imageCropEditorCloseSemanticLabel => 'Batalkan pemangkasan';

  @override
  String get imageCropEditorDoneSemanticLabel => 'Terapkan pemangkasan';

  @override
  String get imageCropEditorProcessing => 'Menerapkan pemangkasan…';

  @override
  String get backgroundUploadNotificationTitle => 'Mengunggah video';

  @override
  String get monetizationSettingsTitle => 'Dukungan kreator';

  @override
  String get monetizationSettingsSubtitle =>
      'Tambahkan tautan tip dan langganan';

  @override
  String get monetizationSettingsIntroTitle => 'Hanya tautan keluar';

  @override
  String get monetizationSettingsIntroBody =>
      'Tambahkan tujuan yang kamu kelola sendiri. Divine tidak pernah memproses pembayaran dan tidak membuka konten di aplikasi lewat tautan ini.';

  @override
  String monetizationSettingsConfiguredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tautan aktif di profilmu',
    );
    return '$_temp0';
  }

  @override
  String get monetizationSettingsTipSection => 'Kirim tip';

  @override
  String get monetizationSettingsSubscriptionSection => 'Langganan / dukung';

  @override
  String get monetizationSettingsSave => 'Simpan tautan dukungan';

  @override
  String get monetizationSettingsSaving => 'Menyimpan...';

  @override
  String get monetizationSettingsSaved => 'Tautan dukungan diperbarui';

  @override
  String get monetizationSettingsSaveFailed =>
      'Tautan dukungan gagal disimpan. Periksa koneksimu dan coba lagi.';

  @override
  String get monetizationSettingsErrorEmpty => 'Tambahkan handle atau URL.';

  @override
  String get monetizationSettingsErrorInvalid =>
      'Tautan itu sepertinya tidak benar.';

  @override
  String get monetizationSettingsErrorWrongProvider =>
      'Pakai tautan untuk penyedia ini.';

  @override
  String get monetizationSettingsHintCashApp =>
      '\$cashtag atau tautan cash.app';

  @override
  String get monetizationSettingsHintPayPal => 'Handle atau tautan PayPal.me';

  @override
  String get monetizationSettingsHintVenmo => 'Handle atau tautan Venmo';

  @override
  String get monetizationSettingsHintPatreon => 'Handle atau tautan Patreon';

  @override
  String get monetizationSettingsHintSubstack => 'Domain atau tautan Substack';

  @override
  String get monetizationSettingsHintMedium => 'Handle atau tautan Medium';

  @override
  String get monetizationSettingsHintOpenCollective =>
      'Slug atau tautan Open Collective';

  @override
  String get profileSupportSheetTitle => 'Dukung kreator ini';

  @override
  String get profileSupportSheetBody =>
      'Tautan ini terbuka di luar Divine. Tidak ada di sini yang membuka konten di aplikasi.';

  @override
  String get profileSupportTipSection => 'Kirim tip';

  @override
  String get profileSupportSubscriptionSection => 'Langganan / dukung';

  @override
  String get profileSupportButtonLabel => 'Dukung';

  @override
  String get monetizationTipsSettingsTitle => 'Tip';

  @override
  String get monetizationTipsSettingsSubtitle =>
      'Tambahkan tautan tip yang bersifat opsional';

  @override
  String get monetizationTipsSettingsIntroTitle => 'Hanya tip opsional';

  @override
  String get monetizationTipsSettingsIntroBody =>
      'Tip adalah hadiah opsional antarpengguna. Tip tidak membuka konten, langganan, fitur, peringkat, visibilitas, atau akses di Divine.';

  @override
  String monetizationTipsSettingsConfiguredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tautan tip aktif di profilmu',
    );
    return '$_temp0';
  }

  @override
  String get monetizationTipsSettingsSave => 'Simpan tautan tip';

  @override
  String get monetizationTipsSettingsSaved => 'Tautan tip diperbarui';

  @override
  String get profileTipButtonLabel => 'Tip';

  @override
  String get profileTipSheetTitle => 'Beri tip ke kreator ini';

  @override
  String get profileTipSheetBody =>
      'Tautan tip terbuka di luar Divine. Sifatnya opsional dan tidak membuka konten, langganan, fitur, atau akses di Divine.';

  @override
  String get settingsStorageTitle => 'Penyimpanan';

  @override
  String get settingsStorageCacheSectionTitle => 'Media tersimpan';

  @override
  String get settingsStorageCacheDescription =>
      'Video feed, thumbnail, dan render sementara yang tersimpan. Menghapusnya aman — akan diunduh atau dibuat ulang saat diperlukan.';

  @override
  String get settingsStorageMeasuring => 'Menghitung…';

  @override
  String settingsStorageCacheInUse(String size) {
    return '$size terpakai';
  }

  @override
  String get settingsStorageClearButton => 'Hapus cache';

  @override
  String get settingsStorageClearConfirmTitle => 'Hapus media tersimpan?';

  @override
  String settingsStorageClearConfirmMessage(String size) {
    return 'Ini mengosongkan $size. Pustaka klipmu tidak terpengaruh.';
  }

  @override
  String get settingsStorageClearConfirmAction => 'Hapus';

  @override
  String get settingsStorageCleared => 'Cache dihapus';

  @override
  String get settingsStorageLibrarySectionTitle => 'Pustaka klip';

  @override
  String get settingsStorageLibraryDescription =>
      'Periksa klip rusak yang berkas videonya hilang.';

  @override
  String get settingsStorageScanButton => 'Periksa pustaka';

  @override
  String get settingsStorageLibraryHealthy => 'Tidak ada klip rusak ditemukan';

  @override
  String settingsStorageBrokenClipsFound(int count) {
    return 'Klip rusak ditemukan: $count';
  }

  @override
  String get settingsStorageRemoveBrokenButton => 'Hapus klip rusak';

  @override
  String get settingsStorageBrokenClipsRemoved => 'Klip rusak dihapus';

  @override
  String get settingsStorageError => 'Terjadi kesalahan';

  @override
  String get settingsStorageMaxVideoCacheLabel => 'Cache video maksimum';

  @override
  String settingsStorageApproxVideos(int count) {
    return '≈ $count video';
  }

  @override
  String get settingsStorageRemoveBrokenConfirmTitle => 'Hapus klip rusak?';

  @override
  String get settingsStorageRepairSectionTitle => 'Perbaiki instalasi';

  @override
  String get settingsStorageRepairDescription =>
      'Kalau aplikasi sering crash atau berperilaku aneh, reset data lokalnya biasanya menyelesaikan masalah. Klip dan draf kamu tetap aman.';

  @override
  String get settingsStorageRepairButton => 'Reset data aplikasi';

  @override
  String get settingsStorageRepairConfirmTitle => 'Reset data aplikasi?';

  @override
  String get settingsStorageRepairConfirmMessage =>
      'Ini menghapus data feed di cache dan file sementara. Klip, draf, pengaturan, dan sesi login kamu tetap ada, tapi setelahnya kamu harus memulai ulang aplikasi.';

  @override
  String settingsStorageRepairFootprint(String size) {
    return '$size akan dihapus';
  }

  @override
  String get settingsStorageRepairConfirmAction => 'Reset';

  @override
  String get settingsStorageRepairInProgress => 'Mereset…';

  @override
  String get settingsStorageRepairSuccess =>
      'Selesai — mulai ulang aplikasi untuk menuntaskan.';

  @override
  String get settingsStorageRepairFailure =>
      'Tidak semuanya bisa direset. Coba lagi setelah memulai ulang.';

  @override
  String get nostrSettingsSignatureVerification => 'Verifikasi tanda tangan';

  @override
  String get nostrSettingsSignatureVerificationIntro =>
      'Pilih kapan Divine memeriksa tanda tangan event relay. ID event selalu divalidasi terlebih dahulu.';

  @override
  String get nostrSettingsSignatureVerificationAll => 'Semua relay';

  @override
  String get nostrSettingsSignatureVerificationAllSubtitle =>
      'Paling aman. Verifikasi tanda tangan setiap event relay.';

  @override
  String get nostrSettingsSignatureVerificationUntrusted =>
      'Relay tidak tepercaya';

  @override
  String get nostrSettingsSignatureVerificationUntrustedSubtitle =>
      'Lewati pemeriksaan untuk relay yang sudah ada di pool yang kamu konfigurasi.';

  @override
  String get nostrSettingsSignatureVerificationNonDivine => 'Relay non-Divine';

  @override
  String get nostrSettingsSignatureVerificationNonDivineSubtitle =>
      'Percayai relay Divine, verifikasi sisanya.';

  @override
  String get settingsCrosspostingTitle => 'Crossposting';

  @override
  String get settingsCrosspostingSubtitle => 'Bagikan videomu ke platform lain';

  @override
  String get crosspostingSignInRequired =>
      'Masuk dengan Divine untuk mengatur crossposting';

  @override
  String get crosspostingLoadFailed =>
      'Nggak bisa memuat pengaturan crosspostingmu';

  @override
  String get crosspostingNoPlatforms =>
      'Belum ada platform crossposting yang tersedia sekarang';

  @override
  String get crosspostingRetry => 'Coba lagi';

  @override
  String get crosspostingNotConnected => 'Tidak terhubung';

  @override
  String get crosspostingConnected => 'Terhubung';

  @override
  String get crosspostingNeedsReconnect => 'Perlu dihubungkan ulang';

  @override
  String get crosspostingConnect => 'Hubungkan';

  @override
  String get crosspostingReconnect => 'Hubungkan ulang';

  @override
  String get crosspostingDisconnect => 'Putuskan';

  @override
  String get crosspostingModeOff => 'Nonaktif';

  @override
  String get crosspostingModeManual => 'Manual';

  @override
  String get crosspostingModeManualSubtitle => 'Kamu pilih per video';

  @override
  String get crosspostingModeAutomatic => 'Otomatis';

  @override
  String get crosspostingModeAutomaticSubtitle =>
      'Video berikutnya diposting otomatis — hanya video yang kamu publikasikan setelah ini diaktifkan';

  @override
  String get crosspostingNotConnectedError =>
      'Hubungkan platform ini dulu untuk mengubah cara postingnya.';

  @override
  String get crosspostingGenericError => 'Ada yang salah. Coba lagi.';

  @override
  String get crosspostingCallbackTimeoutError =>
      'Halaman masuk nggak pernah merespons. Kalau kamu sudah selesai menghubungkan di sana, muat ulang — akunmu mungkin sudah tertaut.';

  @override
  String crosspostingConnectionSuccess(String platform) {
    return '$platform terhubung';
  }

  @override
  String crosspostingConnectionFailed(String platform) {
    return 'Nggak bisa menghubungkan $platform';
  }

  @override
  String crosspostingConnectionDenied(String platform) {
    return 'Koneksi dibatalkan di $platform';
  }

  @override
  String get supporterTitle => 'Pendukung Divine';

  @override
  String get supporterTileSubtitle =>
      'Dukung Divine dengan langganan bulanan opsional.';

  @override
  String get supporterHeroTitle => 'Bantu Divine tetap berjalan';

  @override
  String get supporterHeroBody =>
      'Divine gratis dan akan selalu gratis. Kalau kamu ingin membantu kami menjaga loop tetap berjalan, jadilah pendukung bulanan. Tidak ada yang dikunci — cuma menjaga lampu tetap menyala dan membuat kami berterima kasih.';

  @override
  String get supporterActiveBadge =>
      'Kamu Pendukung Divine. Terima kasih sudah menjaga ini tetap berjalan.';

  @override
  String get supporterPurchasePending => 'Pembelianmu menunggu persetujuan.';

  @override
  String get supporterPurchaseConfirming => 'Mengonfirmasi dukunganmu…';

  @override
  String get supporterStoreChecking => 'Memeriksa toko…';

  @override
  String get supporterUnavailable =>
      'Langganan pendukung tidak tersedia di sini saat ini.';

  @override
  String get supporterRestorePurchases => 'Pulihkan pembelian';

  @override
  String get supporterDismissError => 'Tutup kesalahan';

  @override
  String get supporterErrorStoreUnavailable =>
      'Toko tidak tersedia di perangkat ini.';

  @override
  String get supporterErrorPurchaseFailed =>
      'Pembelian tidak selesai. Kamu tidak ditagih.';

  @override
  String get supporterErrorPurchasePending =>
      'Pembelianmu menunggu persetujuan.';

  @override
  String get supporterErrorRestoreFailed =>
      'Tidak ada langganan pendukung yang ditemukan untuk dipulihkan.';

  @override
  String get supporterErrorOwnershipConflict =>
      'Pembelian ini milik akun Divine lain.';

  @override
  String get supporterErrorVerificationUnavailable =>
      'Divine belum bisa mengonfirmasi status pendukungmu saat ini.';

  @override
  String get supporterErrorUnknown => 'Terjadi kesalahan. Silakan coba lagi.';

  @override
  String get supporterDisclaimer =>
      'Divine mengonfirmasi status pendukung setelah toko memverifikasi pembelianmu. Pengakuan bersifat opsional, dan halo bukan verifikasi.';

  @override
  String get profileNotifyBellOff => 'Beri tahu tentang vine baru';

  @override
  String get profileNotifyBellOn => 'Hentikan pemberitahuan vine baru';

  @override
  String get profileNotifyUpdateFailed => 'Gagal menyimpan. Coba lagi?';

  @override
  String get savedSoundYourLabel => 'Labelmu';

  @override
  String get savedSoundAddHashtags => 'Tambahkan tagar';

  @override
  String get savedSoundDeviceOnly => 'Tersimpan di perangkat ini';

  @override
  String get savedSoundDetailsRetry =>
      'Detail itu gagal disimpan. Ketuk untuk mencoba lagi.';

  @override
  String get savedSoundFallbackTitle => 'Suara tersimpan';

  @override
  String get savedSoundPreviewAction => 'Dengarkan suaranya';

  @override
  String get savedSoundEditAction => 'Edit detail suara';

  @override
  String get savedSoundRemoveAction => 'Hapus suara tersimpan';

  @override
  String get savedSoundClearHashtagFilter => 'Bersihkan filter tagar';

  @override
  String get soundAllowRemix => 'Izinkan orang lain me-remix suara ini';

  @override
  String get soundReuseUnavailable => 'Suara ini belum bisa di-remix sekarang.';

  @override
  String get soundPublicCredit => 'Kredit suara publik';

  @override
  String get soundCreditRequired =>
      'Tambahkan kredit suara publik sebelum memposting.';

  @override
  String get soundSharedAs => 'Dibagikan sebagai';

  @override
  String get soundOwnWork => 'Suara ini buatanku';

  @override
  String soundCreatorBy(String creator) {
    return 'Oleh $creator';
  }

  @override
  String soundSharedBy(String publisher) {
    return 'Dibagikan oleh $publisher';
  }

  @override
  String get soundRemixingAllowed => 'Remix diizinkan';

  @override
  String get soundCreditOnly => 'Hanya kredit';

  @override
  String get soundCreditTitleLabel => 'Judul suara';

  @override
  String get soundCreditCreatorLabel => 'Kreator';

  @override
  String get soundCreditSourceUrlLabel => 'URL sumber';

  @override
  String get soundCreditPublicHashtagsLabel => 'Tagar publik';

  @override
  String get videoMetadataTagsPickerCancelSemanticLabel =>
      'Batalkan pemilihan tag';

  @override
  String get videoMetadataTagsPickerConfirmSemanticLabel =>
      'Terapkan tag yang dipilih';

  @override
  String get userPickerCancelSemanticLabel => 'Batalkan pemilihan pengguna';

  @override
  String get userPickerConfirmSemanticLabel =>
      'Konfirmasi pengguna yang dipilih';

  @override
  String get userPickerClearSelectionSemanticLabel => 'Hapus pilihan pengguna';

  @override
  String get videoMetadataContentWarningsPickerCancelSemanticLabel =>
      'Batalkan pemilihan peringatan konten';

  @override
  String get videoMetadataContentWarningsPickerConfirmSemanticLabel =>
      'Terapkan peringatan konten yang dipilih';

  @override
  String get videoEditorCloseEditorSemanticLabel => 'Tutup editor video';

  @override
  String get videoEditorContinueToPostDetailsSemanticLabel =>
      'Lanjutkan ke detail postingan';

  @override
  String videoEditorDiscardToolChangesSemanticLabel(String tool) {
    return 'Buang perubahan di $tool';
  }

  @override
  String videoEditorApplyToolChangesSemanticLabel(String tool) {
    return 'Terapkan perubahan di $tool';
  }

  @override
  String get videoEditorRemoveAudioSemanticLabel => 'Hapus audio';

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
  String get verifyTitle => 'Akun terverifikasi';

  @override
  String get verifySignedOutMessage => 'Masuk dulu untuk menautkan akunmu.';

  @override
  String get verifyIntro =>
      'Tautkan akun yang sudah kamu punya, biar orang tahu ini memang kamu.';

  @override
  String get verifyLoadFailed => 'Tautanmu gagal dimuat.';

  @override
  String get verifyRetry => 'Coba lagi';

  @override
  String get verifyLinkedSectionTitle => 'Tertaut';

  @override
  String get verifyVerifierUnreachable =>
      'Verifier tidak bisa dihubungi, jadi semuanya tampil belum dicek.';

  @override
  String get verifyAddSectionTitle => 'Tambah akun';

  @override
  String get verifyAllPlatformsLinked =>
      'Kamu sudah menautkan semua yang kami dukung.';

  @override
  String get verifyStatusVerified => 'Terverifikasi';

  @override
  String get verifyStatusUnverified => 'Belum terverifikasi';

  @override
  String verifyUnlinkSemanticLabel(String platform, String identity) {
    return 'Lepas tautan akun $platform $identity';
  }

  @override
  String verifyUnlinkConfirmTitle(String platform) {
    return 'Lepas tautan $platform?';
  }

  @override
  String verifyUnlinkConfirmSubtitle(String identity) {
    return '$identity tidak akan muncul lagi di profilmu. Kamu bisa menautkannya lagi nanti, tapi kamu harus masuk lagi atau memposting bukti baru.';
  }

  @override
  String get verifyUnlinkConfirmCta => 'Lepas tautan';

  @override
  String verifyLinkSemanticLabel(String platform) {
    return 'Tautkan akun $platform kamu';
  }

  @override
  String get verifyOneTapBadge => 'Sekali ketuk';

  @override
  String verifyConnectOauthExplainer(String platform) {
    return 'Masuk ke $platform, sisanya kami yang urus. Tidak ada yang diposting.';
  }

  @override
  String verifyConnectOauthCta(String platform) {
    return 'Lanjut dengan $platform';
  }

  @override
  String get verifyConnectProofTitle => 'Atau posting bukti';

  @override
  String get verifyConnectProofExplainer =>
      'Posting npub-mu di akunmu, lalu tempel tautan ke postingan itu.';

  @override
  String get verifyNpubLabel => 'npub kamu';

  @override
  String get verifyCopyNpubSemanticLabel => 'Salin npub kamu';

  @override
  String get verifyNpubCopied => 'npub disalin';

  @override
  String get verifyIdentityLabel => 'Nama akun';

  @override
  String get verifyProofLabel => 'Tautan ke postinganmu';

  @override
  String get verifyConnectProofCta => 'Cek dan tautkan';

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
      'Verifier tidak bisa dihubungi. Coba lagi sebentar lagi.';

  @override
  String get verifyErrorOauthFailed => 'Gagal. Coba sekali lagi.';

  @override
  String get verifyErrorHandleRequired => 'Isi handle kamu dulu.';

  @override
  String get verifyErrorPublishFailed =>
      'Terverifikasi, tapi tidak ada relay yang menerima pembaruan. Coba lagi.';

  @override
  String get verifyErrorOauthUnavailable =>
      'Masuk sekali ketuk belum disiapkan untuk yang ini. Pakai bukti di bawah.';

  @override
  String get verifyConnectProofExplainerGithub =>
      'Buat gist publik dengan npub-mu di file pertama, lalu tempel tautan gist-nya.';

  @override
  String get verifyConnectProofExplainerDiscord =>
      'Posting npub-mu di channel Discord yang bisa dibaca bot kami, lalu tempel tautan pesannya. Undangan server tidak membuktikan apa pun.';

  @override
  String get verifyConnectProofExplainerTwitter =>
      'Tweet npub-mu dari akun itu, lalu tempel tautan tweet-nya.';

  @override
  String get verifyConnectProofExplainerMastodon =>
      'Posting npub-mu dari akun itu, lalu tempel tautannya. Nama akun harus menyertakan instance — mastodon.social/@alice, bukan cuma alice.';

  @override
  String get verifyConnectProofExplainerTelegram =>
      'Yang ditautkan adalah channel-nya, bukan akun Telegram-mu. Channel perlu tautan publik dulu (Telegram membuat yang baru jadi privat). Posting npub-mu di sana dan tempel tautan pesannya.';

  @override
  String get verifyConnectProofExplainerBluesky =>
      'Sudah masuk di atas? Tidak perlu apa-apa lagi. Kalau belum, posting npub-mu dan tempel tautan postingannya.';

  @override
  String get verifyConnectProofExplainerTiktok =>
      'Taruh npub-mu di caption video, lalu tempel tautan video itu.';

  @override
  String get verifyConnectProofExplainerYoutube =>
      'Taruh npub-mu di deskripsi video, lalu tempel tautan video itu.';

  @override
  String verifyLinkedConfirmation(String platform) {
    return '$platform sudah tertaut.';
  }

  @override
  String get verifyErrorTelegramNotPublic =>
      'Itu channel privat atau undangan. Beri channel itu tautan publik, lalu tempel tautan pesannya.';

  @override
  String get verifyErrorRemoveFailed => 'Gagal melepas tautan. Coba lagi.';

  @override
  String get verifyErrorLinksUnreadable =>
      'Kami tidak bisa membaca tautanmu saat ini, jadi tidak ada yang diubah. Cek koneksimu dan coba lagi.';

  @override
  String get verifyChannelLabel => 'Nama channel';

  @override
  String get verifyHowItWorksTitle => 'Bagaimana cara kerjanya?';

  @override
  String get verifyHowItWorksIntro =>
      'Anggap saja ini jabat tangan antara dua akun:';

  @override
  String get verifyHowItWorksYourSide =>
      'Profil Divine-mu bilang: “Aku @alice di Twitter.”';

  @override
  String get verifyHowItWorksOtherSide =>
      'Akun Twitter-mu membenarkan: “Ya, profil Divine itu punyaku.”';

  @override
  String get verifyHowItWorksBothSides =>
      'Kami cek kedua sisi. Kalau cocok, kamu terverifikasi. Tidak bisa dipalsukan — nama dan foto bisa disalin, memposting dari akun aslimu tidak.';

  @override
  String get verifyHowItWorksOwnership =>
      'Tautannya ada di identitas Nostr-mu sendiri, jadi kamu bisa menghapusnya dari sini kapan saja.';

  @override
  String get generalSettingsSectionIdentity => 'Identitas';

  @override
  String get libraryFilterAll => 'Semua';

  @override
  String get libraryFilterArchive => 'Arsip';

  @override
  String get libraryFilterDeleted => 'Dihapus';

  @override
  String get libraryCategoryNewChipLabel => 'Baru';

  @override
  String get libraryCategoryCreateSemanticLabel => 'Buat kategori';

  @override
  String get libraryCategoryCreateTitle => 'Kategori baru';

  @override
  String get libraryCategoryCreateAction => 'Buat';

  @override
  String get libraryCategoryRenameTitle => 'Ganti nama kategori';

  @override
  String get libraryCategoryRenameAction => 'Ganti nama';

  @override
  String get libraryCategoryDeleteAction => 'Hapus kategori';

  @override
  String get libraryCategoryNameLabel => 'Nama kategori';

  @override
  String libraryCategoryDeleteConfirmTitle(String name) {
    return 'Hapus “$name”?';
  }

  @override
  String get libraryCategoryDeleteConfirmMessage =>
      'Klipmu tetap ada. Semuanya hanya kembali ke Semua.';

  @override
  String get libraryCategoryManageSemanticLabel =>
      'Ganti nama atau hapus kategori ini';

  @override
  String get libraryCategoryMoveTitle => 'Pindahkan ke';

  @override
  String get libraryCategoryMoveNone => 'Tanpa kategori';

  @override
  String get libraryCategoryMoveNewCategory => 'Kategori baru';

  @override
  String get libraryArchiveAction => 'Arsipkan';

  @override
  String get libraryUnarchiveAction => 'Batalkan arsip';

  @override
  String libraryArchiveKeepCategoryTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tetap di kategori ini?',
    );
    return '$_temp0';
  }

  @override
  String libraryArchiveKeepCategoryAction(String name) {
    return 'Tetap di $name';
  }

  @override
  String get libraryArchiveKeepCategoryActionMixed => 'Tetap di kategorinya';

  @override
  String libraryArchiveRemoveCategoryAction(String name) {
    return 'Keluarkan dari $name';
  }

  @override
  String get libraryArchiveRemoveCategoryActionMixed =>
      'Keluarkan dari kategorinya';

  @override
  String get libraryMoveSelectedClipsTooltip => 'Pindahkan klip terpilih';

  @override
  String get libraryCategoryEmptyTitle => 'Belum ada apa-apa di sini';

  @override
  String get libraryCategoryEmptySubtitle =>
      'Pilih beberapa klip dan pindahkan ke kategori ini.';

  @override
  String get libraryArchiveEmptyTitle => 'Belum ada arsip';

  @override
  String get libraryArchiveEmptySubtitle =>
      'Klip yang diarsipkan menunggu di sini, terpisah dari pustaka utamamu.';

  @override
  String libraryClipsMovedToCategory(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klip dipindahkan ke $name',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsRemovedFromCategory(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klip dikeluarkan dari kategorinya',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsArchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klip diarsipkan',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsUnarchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klip kembali ke pustakamu',
    );
    return '$_temp0';
  }

  @override
  String get accountSettingsChangeEmail => 'Ubah email';

  @override
  String get accountSettingsChangeEmailSubtitle =>
      'Pindahkan akunmu ke alamat lain';

  @override
  String get accountSettingsChangePassword => 'Ubah kata sandi';

  @override
  String get accountSettingsChangePasswordSubtitle =>
      'Pilih kata sandi baru untuk masuk';

  @override
  String get accountCredentialsNeedsSignIn =>
      'Sesimu habis. Masuk lagi untuk melakukan perubahan ini.';

  @override
  String get accountCredentialsRateLimited =>
      'Terlalu banyak percobaan. Tunggu beberapa menit.';

  @override
  String get accountCredentialsNetwork =>
      'Tidak bisa menghubungi Divine. Cek koneksimu dan coba lagi.';

  @override
  String get accountCredentialsUnknown => 'Tidak berhasil. Coba lagi.';

  @override
  String get changePasswordSubtitle =>
      'Ketik kata sandi saat ini, lalu pilih yang baru.';

  @override
  String get changePasswordCurrentLabel => 'Kata sandi saat ini';

  @override
  String get changePasswordWrongCurrent => 'Itu bukan kata sandimu saat ini.';

  @override
  String get changePasswordSuccess => 'Kata sandi diubah.';

  @override
  String get changeEmailSubtitle =>
      'Kami mengirim tautan konfirmasi ke alamat barumu dan ke alamat di akunmu. Emailmu berubah setelah kamu konfirmasi dari keduanya.';

  @override
  String changeEmailCurrentAddress(String email) {
    return 'Di akunmu: $email';
  }

  @override
  String get changeEmailNewLabel => 'Email baru';

  @override
  String get changeEmailPasswordLabel => 'Kata sandimu';

  @override
  String get changeEmailSameAsCurrent => 'Itu sudah jadi alamat emailmu.';

  @override
  String get changeEmailWrongPassword => 'Itu bukan kata sandimu.';

  @override
  String get changeEmailSubmit => 'Kirim tautan konfirmasi';

  @override
  String get changeEmailSentTitle => 'Dua tautan sedang dikirim';

  @override
  String changeEmailSentMessage(String email) {
    return 'Konfirmasi dari $email dan dari alamat di akunmu. Emailmu berganti setelah keduanya selesai.';
  }

  @override
  String get changeEmailSentExpiry => 'Tautan berhenti berlaku setelah 24 jam.';

  @override
  String get changeEmailSentDone => 'Oke';

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
  String get socialProofFollowsYou => 'Mengikuti kamu';

  @override
  String get socialProofYouFollow => 'Kamu ikuti';

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
      'Video sedang tidak bisa dimuat.\nIni dari kami, bukan kamu — sedang kami perbaiki.';

  @override
  String get feedOfflineMessage =>
      'Kamu sedang offline.\nPeriksa koneksimu lalu coba lagi.';

  @override
  String get dbFailureTitle => 'tidak dapat membuka basis data lokalmu';

  @override
  String get dbFailureAdviceResettable =>
      'Memulai ulang tidak akan memperbaikinya. Mengatur ulang basis data lokal di bawah memberi Divine awal yang bersih — akunmu tetap ada.';

  @override
  String get dbFailureAdviceRestart =>
      'Mulai ulang Divine setelah membuka kunci perangkatmu. Jika ini terus terjadi, perbarui aplikasi atau hubungi dukungan.';

  @override
  String get dbFailureAdviceHotJournal =>
      'Coba mulai ulang Divine satu kali. Jika ini terus terjadi, perbarui aplikasi atau hubungi dukungan. Data lokal Anda masih ada.';

  @override
  String dbFailureDiagnostic(String code) {
    return 'Diagnostik: $code';
  }

  @override
  String get dbFailureCloseApp => 'tutup Divine';

  @override
  String get dbFailureResetAction => 'atur ulang basis data lokal';

  @override
  String get dbFailureConfirmTitle => 'atur ulang basis data lokalmu?';

  @override
  String get dbFailureConfirmBody =>
      'Akunmu tetap ada. Draf dan klip yang tersimpan di perangkat ini akan dihapus — pesan dan feed kembali dari jaringan.';

  @override
  String get dbFailureResetConfirm => 'atur ulang basis data lokal sekarang';

  @override
  String get dbFailureCancel => 'batal';

  @override
  String get dbFailureResetFailed =>
      'Itu tidak berhasil. Tutup Divine dan coba lagi.';

  @override
  String get dbFailureResetDoneTitle => 'basis data lokal telah diatur ulang';

  @override
  String get dbFailureResetDoneBody =>
      'Tutup Divine lalu buka lagi — peluncuran berikutnya membangun basis data lokal yang baru.';

  @override
  String get authSignInOptionsInfo => 'Tentang opsi masuk';

  @override
  String get authShowPassword => 'Tampilkan sandi';

  @override
  String get authHidePassword => 'Sembunyikan sandi';

  @override
  String get followUserSemanticLabel => 'Ikuti pengguna';

  @override
  String get unfollowUserSemanticLabel => 'Berhenti mengikuti pengguna';

  @override
  String get commentsLoadingSemanticLabel => 'Memuat komentar';

  @override
  String get analyticsWindowAll => 'Semua';

  @override
  String followUserIndexedSemanticLabel(String index) {
    return 'Ikuti pengguna $index';
  }

  @override
  String unfollowUserIndexedSemanticLabel(String index) {
    return 'Berhenti mengikuti pengguna $index';
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
      'Pembaruan baru saja hadir. Lihat sekarang →';

  @override
  String get updateModerateTitle =>
      'Ada pembaruan sejak terakhir kali Anda memeriksa';

  @override
  String get updateUrgentTitle => 'Anda melewatkan perbaikan penting';

  @override
  String get updateNotNow => 'Nanti saja';

  @override
  String get updateAction => 'Perbarui';

  @override
  String updateNewIn(String version) {
    return 'Yang baru di $version:';
  }

  @override
  String get settingsUpdateAvailable => 'Pembaruan tersedia';
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get devOptionsClipRecovery => 'Klip kurtarma';

  @override
  String get devOptionsClipRecoveryDescription =>
      'Başka bir hesap altında saklanan kayıtları ve artık hiçbir kaydın işaret etmediği video dosyalarını bulur.';

  @override
  String get devOptionsClipRecoveryScan => 'Tara';

  @override
  String get devOptionsClipRecoveryFailure => 'Klip kurtarma başarısız oldu';

  @override
  String devOptionsClipRecoveryVisible(int clips, int drafts) {
    return 'Şu anda görünen: $clips klip, $drafts taslak';
  }

  @override
  String get devOptionsClipRecoveryOtherAccounts => 'Diğer hesaplarda gizli';

  @override
  String devOptionsClipRecoveryCounts(int clips, int drafts) {
    return '$clips klip, $drafts taslak';
  }

  @override
  String get devOptionsClipRecoveryClaim => 'Bu hesaba taşı';

  @override
  String devOptionsClipRecoveryOrphanFiles(int count, String size) {
    return 'Referans verilmeyen dosyalar: $count ($size)';
  }

  @override
  String get devOptionsClipRecoveryImport => 'Kitaplıkta yeniden oluştur';

  @override
  String get devOptionsClipRecoveryEmpty => 'Kurtarılacak bir şey yok';

  @override
  String devOptionsClipRecoveryRecovered(int count) {
    return '$count klip kurtarıldı';
  }

  @override
  String get devOptionsClipRecoveryCopied => 'Kurtarma raporu kopyalandı';

  @override
  String get devOptionsStorageFootprint => 'Depolama kullanımı';

  @override
  String get devOptionsStorageFootprintDescription =>
      'Uygulamanın yazdığı her klasör. Önbelleği temizlemek bunun yalnızca bir kısmını boşaltır.';

  @override
  String get devOptionsStorageFootprintMeasure => 'Ölç';

  @override
  String devOptionsStorageFootprintTotal(String size) {
    return 'Toplam: $size';
  }

  @override
  String get devOptionsStorageFootprintCopied => 'Depolama raporu kopyalandı';

  @override
  String get devOptionsStorageFootprintFailure => 'Depolama ölçülemedi';

  @override
  String get feedTuningMoreLabel => 'Bunun gibi daha fazla';

  @override
  String get feedTuningLessLabel => 'Bunun gibi daha az';

  @override
  String get feedTuningUndo => 'Geri al';

  @override
  String get dmMessageBubbleVideoReplyHint => 'Atıfta bulunulan videoyu aç';

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => 'Ayarlar';

  @override
  String get settingsSecureAccount => 'Hesabını Güvenceye Al';

  @override
  String get settingsSessionExpired => 'Oturum Sona Erdi';

  @override
  String get settingsSessionExpiredSubtitle =>
      'Tam erişimi geri almak için tekrar giriş yap';

  @override
  String get settingsAccountRestoreFailed => 'Account Restore Failed';

  @override
  String get settingsAccountRestoreFailedSwitchMessage =>
      'We couldn\'t unlock that account on this device. Signing back into it means signing out of the one you\'re on now.';

  @override
  String get settingsCreatorAnalytics => 'İçerik Üretici Analitikleri';

  @override
  String get settingsSupportCenter => 'Destek Merkezi';

  @override
  String get settingsNotifications => 'Bildirimler';

  @override
  String get settingsBlueskyPublishing => 'Bluesky Yayınlama';

  @override
  String get settingsBlueskyPublishingSubtitle =>
      'Bluesky\'a çapraz paylaşımı yönet';

  @override
  String get settingsNostrSettings => 'Nostr Ayarları';

  @override
  String get settingsIntegratedApps => 'Entegre Uygulamalar';

  @override
  String get settingsIntegratedAppsSubtitle =>
      'Divine içinde çalışan onaylı üçüncü taraf uygulamalar';

  @override
  String get settingsExperimentalFeatures => 'Deneysel Özellikler';

  @override
  String get settingsExperimentalFeaturesSubtitle =>
      'Takılabilecek düzenlemeler—meraklıysan deneyebilirsin.';

  @override
  String get settingsLegal => 'Yasal';

  @override
  String get settingsIntegrationPermissions => 'Entegrasyon İzinleri';

  @override
  String get settingsIntegrationPermissionsSubtitle =>
      'Hatırlanan entegrasyon onaylarını gözden geçir ve iptal et';

  @override
  String settingsVersion(String version) {
    return 'Sürüm $version';
  }

  @override
  String get settingsVersionEmpty => 'Sürüm';

  @override
  String get settingsDeveloperModeAlreadyEnabled =>
      'Geliştirici modu zaten etkin';

  @override
  String get settingsDeveloperModeEnabled =>
      'Geliştirici modu etkinleştirildi!';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    return 'Geliştirici modunu etkinleştirmek için $count dokunuş daha';
  }

  @override
  String get settingsShareDivine => 'Divine\'ı arkadaşlarınla paylaş';

  @override
  String get settingsSwitchAccount => 'Hesap değiştir';

  @override
  String get settingsAddAnotherAccount => 'Başka hesap ekle';

  @override
  String get settingsAccountSwitchFailed =>
      'Hesaplar değiştirilemedi. Lütfen tekrar dene.';

  @override
  String get settingsUnsavedDraftsTitle => 'Kaydedilmemiş Taslaklar';

  @override
  String get settingsUploadInProgressTitle => 'Yükleme sürüyor';

  @override
  String settingsUploadInProgressMessage(int count) {
    return 'Hâlâ $count video yükleniyor. Hesap değiştirmek yüklemeyi durdurur — videoların bu hesapta taslak olarak kalır.';
  }

  @override
  String settingsUnsavedDraftsMessage(int count) {
    return '$count kaydedilmemiş taslağınız var. Hesap değiştirmek taslağınızı saklayacaktır, ancak önce yayınlamak veya gözden geçirmek isteyebilirsiniz.';
  }

  @override
  String get settingsCancel => 'İptal';

  @override
  String get settingsSwitchAnyway => 'Yine de Değiştir';

  @override
  String get settingsSessionExpiredSwitchMessage =>
      'O hesabın oturumu doldu. Yeniden giriş yapmak, şu an kullandığın hesaptan çıkmak demek.';

  @override
  String get settingsAppVersionLabel => 'Uygulama sürümü';

  @override
  String get settingsAppLanguage => 'Uygulama Dili';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language (cihaz varsayılanı)';
  }

  @override
  String get settingsAppLanguageTitle => 'Uygulama Dili';

  @override
  String get settingsAppLanguageDescription => 'Uygulama arayüzü için dili seç';

  @override
  String get settingsAppLanguageUseDeviceLanguage => 'Cihaz dilini kullan';

  @override
  String get settingsGeneralTitle => 'Genel Ayarlar';

  @override
  String get settingsContentSafetyTitle => 'İçerik ve Güvenlik';

  @override
  String get generalSettingsSectionIntegrations => 'ENTEGRASYONLAR';

  @override
  String get generalSettingsSectionViewing => 'İZLEME';

  @override
  String get generalSettingsSectionCreating => 'OLUŞTURMA';

  @override
  String get generalSettingsSectionApp => 'UYGULAMA';

  @override
  String get appearanceSettingsTitle => 'Görünüm';

  @override
  String get appearanceSettingsSubtitle =>
      'Divine\'ın bu cihazda nasıl görüneceğini seç';

  @override
  String get appearanceSettingsSystem => 'Sistem varsayılanı';

  @override
  String get appearanceSettingsLight => 'Açık';

  @override
  String get appearanceSettingsDark => 'Koyu';

  @override
  String get generalSettingsClosedCaptions => 'Altyazılar';

  @override
  String get generalSettingsClosedCaptionsSubtitle =>
      'Videolarda altyazı varsa göster';

  @override
  String get generalSettingsVideoShapeSquareOnly => 'Sadece kare videolar';

  @override
  String get generalSettingsVideoShapeSquareOnlySubtitle =>
      'Akışları klasik kare formatta tut';

  @override
  String get contentPreferencesTitle => 'İçerik Tercihleri';

  @override
  String get contentPreferencesContentFilters => 'İçerik Filtreleri';

  @override
  String get contentPreferencesContentFiltersSubtitle =>
      'İçerik uyarı filtrelerini yönet';

  @override
  String get contentPreferencesContentLanguage => 'İçerik Dili';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language (cihaz varsayılanı)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      'İzleyicilerin içeriği filtreleyebilmesi için videolarını bir dille etiketle.';

  @override
  String get contentPreferencesUseDeviceLanguage =>
      'Cihaz dilini kullan (varsayılan)';

  @override
  String get contentPreferencesAudioSharing => 'Sesimi yeniden kullanıma aç';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      'Etkinleştirildiğinde başkaları videolarındaki sesi kullanabilir';

  @override
  String get contentPreferencesMusicMode => 'Müzik modu';

  @override
  String get contentPreferencesMusicModeSubtitle =>
      'Enstrümanları ezen gürültü temizlemesini kapatır. Müzik için daha iyi, sesler için daha ham.';

  @override
  String get contentPreferencesAccountLabels => 'Hesap Etiketleri';

  @override
  String get contentPreferencesAccountLabelsEmpty =>
      'İçeriğini kendin etiketle';

  @override
  String get contentPreferencesAccountContentLabels =>
      'Hesap İçerik Etiketleri';

  @override
  String get contentPreferencesClearAll => 'Tümünü Temizle';

  @override
  String get contentPreferencesSelectAllThatApply =>
      'Hesabın için geçerli olanların hepsini seç';

  @override
  String get contentPreferencesDoneNoLabels => 'Bitti (Etiket Yok)';

  @override
  String contentPreferencesDoneCount(int count) {
    return 'Bitti ($count seçildi)';
  }

  @override
  String get contentPreferencesAudioInputDevice => 'Ses Giriş Cihazı';

  @override
  String get contentPreferencesAutoRecommended => 'Otomatik (önerilen)';

  @override
  String get contentPreferencesAutoSelectsBest =>
      'En iyi mikrofonu otomatik olarak seçer';

  @override
  String get contentPreferencesSelectAudioInput => 'Ses Girişi Seç';

  @override
  String get contentPreferencesUnknownMicrophone => 'Bilinmeyen Mikrofon';

  @override
  String get contentFiltersAdultContent => 'YETİŞKİN İÇERİĞİ';

  @override
  String get contentFiltersViolenceGore => 'ŞİDDET VE KAN';

  @override
  String get contentFiltersSubstances => 'MADDELER';

  @override
  String get contentFiltersOther => 'DİĞER';

  @override
  String get contentFiltersAgeGateMessage =>
      'Yetişkin içerik filtrelerini açmak için yaşını Güvenlik ve Gizlilik ayarlarında doğrula';

  @override
  String get contentFiltersShow => 'Göster';

  @override
  String get contentFiltersWarn => 'Uyar';

  @override
  String get contentFiltersFilterOut => 'Filtrele';

  @override
  String get profileBlockedAccountNotAvailable => 'Bu hesap kullanılamıyor';

  @override
  String get profileInvalidId => 'Geçersiz profil kimliği';

  @override
  String profileShareText(String displayName, String npub) {
    return '$displayName adlı kişiye Divine\'de göz at!\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return 'Divine\'de $displayName';
  }

  @override
  String get profileShareFailed => 'Profil paylaşılamadı. Lütfen tekrar dene.';

  @override
  String get profileCopyPublicKey => 'Açık anahtarı (npub) kopyala';

  @override
  String get profileGetEmbedCode => 'Gömme kodunu al';

  @override
  String get profilePublicKeyCopied => 'Açık anahtar panoya kopyalandı';

  @override
  String get profileEmbedCodeCopied => 'Gömme kodu panoya kopyalandı';

  @override
  String get profileMoreTooltip => 'Daha fazla';

  @override
  String get profileMoreSemanticLabel => 'Daha fazla seçenek';

  @override
  String get profileAvatarLightboxBarrierLabel => 'Avatarı kapat';

  @override
  String get profileAvatarLightboxCloseSemanticLabel =>
      'Avatar önizlemesini kapat';

  @override
  String get profileFollowingLabel => 'Takip ediliyor';

  @override
  String get profileFollowLabel => 'Takip et';

  @override
  String get profileBlockedLabel => 'Engellendi';

  @override
  String get profileFollowersLabel => 'Takipçiler';

  @override
  String get profileFollowingStatLabel => 'Takip edilen';

  @override
  String get profileVideosLabel => 'Videolar';

  @override
  String get profileCollabsLabel => 'İşbirlikleri';

  @override
  String get profileLikedLabel => 'Beğenilenler';

  @override
  String get profileRepostsLabel => 'Yeniden Paylaşımlar';

  @override
  String get profileListsLabel => 'Listeler';

  @override
  String get profileCommentsLabel => 'Yorumlar';

  @override
  String profileCollaboratorInvitePendingHeadline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count iş birlikçi daveti hâlâ gönderilmeyi bekliyor',
      one: '1 iş birlikçi daveti hâlâ gönderilmeyi bekliyor',
    );
    return '$_temp0';
  }

  @override
  String get profileCollaboratorInvitePendingDetail =>
      'Daveti kuyrukta tuttuk. Buradan tekrar dene.';

  @override
  String profileCollaboratorInvitePendingDetailWithTitle(String title) {
    return '\"$title\" için. Buradan tekrar dene.';
  }

  @override
  String get profileCollaboratorInviteRetryAction => 'Tekrar dene';

  @override
  String get profileCollaboratorInviteRetryingAction => 'Tekrar deneniyor';

  @override
  String get profileCollaboratorInviteRetryUnavailable =>
      'İş birlikçi davetini tekrar deneme şu anda kullanılamıyor.';

  @override
  String profileCollaboratorInviteRetryResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count iş birlikçi daveti hâlâ gönderilmeyi bekliyor.',
      one: '1 iş birlikçi daveti hâlâ gönderilmeyi bekliyor.',
      zero: 'İş birlikçi davetleri gönderildi.',
    );
    return '$_temp0';
  }

  @override
  String profileCollaboratorInviteBlockedResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count iş birlikçi davet alamıyor.',
      one: '1 iş birlikçi davet alamıyor.',
    );
    return '$_temp0';
  }

  @override
  String profileFollowerCountUsers(int count) {
    return '$count kullanıcı';
  }

  @override
  String profileBlockTitle(String displayName) {
    return '$displayName engellensin mi?';
  }

  @override
  String get profileBlockExplanation => 'Bir kullanıcıyı engellediğinde:';

  @override
  String get profileBlockBulletHidePosts =>
      'Gönderileri akışında görünmeyecek.';

  @override
  String get profileBlockBulletCantView =>
      'Profilini görüntüleyemeyecek, seni takip edemeyecek veya gönderilerini göremeyecek.';

  @override
  String get profileBlockBulletNoNotify =>
      'Bu değişiklik hakkında bilgilendirilmeyecek.';

  @override
  String get profileBlockBulletYouCanView =>
      'Onun profilini görüntülemeye devam edebileceksin.';

  @override
  String profileBlockConfirmButton(String displayName) {
    return '$displayName engelle';
  }

  @override
  String get profileCancelButton => 'İptal';

  @override
  String get profileLearnMore => 'Daha Fazla Bilgi';

  @override
  String profileUnblockTitle(String displayName) {
    return '$displayName engeli kaldırılsın mı?';
  }

  @override
  String get profileUnblockExplanation =>
      'Bu kullanıcının engelini kaldırdığında:';

  @override
  String get profileUnblockBulletShowPosts => 'Gönderileri akışında görünecek.';

  @override
  String get profileUnblockBulletCanView =>
      'Profilini görüntüleyebilecek, seni takip edebilecek ve gönderilerini görebilecek.';

  @override
  String get profileUnblockBulletNoNotify =>
      'Bu değişiklik hakkında bilgilendirilmeyecek.';

  @override
  String get profileLearnMoreAt => 'Daha fazla bilgi: ';

  @override
  String get profileUnblockButton => 'Engeli kaldır';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return '$displayName takipten çık';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return '$displayName engelle';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return '$displayName engelini kaldır';
  }

  @override
  String profileReportDisplayName(String displayName) {
    return '$displayName adlı kullanıcıyı bildir';
  }

  @override
  String profileAddToListDisplayName(String displayName) {
    return '$displayName kişisini listeye ekle';
  }

  @override
  String get profileNoCollabsTitle => 'Henüz İşbirliği Yok';

  @override
  String get profileCollabsOwnEmpty =>
      'İşbirliği yaptığın videolar burada görünecek';

  @override
  String get profileCollabsOtherEmpty =>
      'İşbirliği yaptıkları videolar burada görünecek';

  @override
  String get profileErrorLoadingCollabs =>
      'İşbirliği videoları yüklenirken hata';

  @override
  String get profileNoSavedVideosTitle => 'Henüz kaydedilmiş bir şey yok';

  @override
  String get profileSavedOwnEmpty =>
      'Paylaşım menüsünden videoları yer imlerine ekle, burada görünsünler.';

  @override
  String get profileErrorLoadingSaved => 'Kaydedilen videolar yüklenirken hata';

  @override
  String get profileNoCommentsOwnTitle => 'Henüz Yorum Yok';

  @override
  String get profileNoCommentsOtherTitle => 'Yorum Yok';

  @override
  String get profileCommentsOwnEmpty =>
      'Yorumların ve yanıtların burada görünecek';

  @override
  String get profileCommentsOtherEmpty =>
      'Yorumları ve yanıtları burada görünecek';

  @override
  String get profileErrorLoadingComments => 'Yorumlar yüklenirken hata';

  @override
  String get profileVideoRepliesSection => 'Video Yanıtları';

  @override
  String get profileCommentsSection => 'Yorumlar';

  @override
  String get profileEditLabel => 'Düzenle';

  @override
  String get profileLibraryLabel => 'Kütüphane';

  @override
  String get profileNoLikedVideosTitle => 'Henüz Beğenilen Video Yok';

  @override
  String get profileLikedOwnEmpty => 'Beğendiğin videolar burada görünecek';

  @override
  String get profileLikedOtherEmpty => 'Beğendikleri videolar burada görünecek';

  @override
  String get profileErrorLoadingLiked => 'Beğenilen videolar yüklenirken hata';

  @override
  String get profileNoRepostsTitle => 'Henüz Yeniden Paylaşım Yok';

  @override
  String get profileRepostsOwnEmpty =>
      'Yeniden paylaştığın videolar burada görünecek';

  @override
  String get profileRepostsOtherEmpty =>
      'Yeniden paylaştıkları videolar burada görünecek';

  @override
  String get profileErrorLoadingReposts =>
      'Yeniden paylaşılan videolar yüklenirken hata';

  @override
  String get profileNoVideosTitle => 'Henüz Video Yok';

  @override
  String get profileNoVideosOwnSubtitle =>
      'İlk videonu paylaş ki burada görelim';

  @override
  String get profileNoVideosOtherSubtitle =>
      'Bu kullanıcı henüz video paylaşmadı';

  @override
  String profileVideoThumbnailLabel(int number) {
    return 'Video küçük resmi $number';
  }

  @override
  String get profileShowMore => 'Daha fazla göster';

  @override
  String get profileShowLess => 'Daha az göster';

  @override
  String get dmMessageDisplayLimitReached =>
      'Bu mesajın geri kalanı gösterilmiyor.';

  @override
  String get profileCompleteYourProfile => 'Profilini Tamamla';

  @override
  String get profileCompleteSubtitle =>
      'Başlamak için adını, biyografini ve resmini ekle';

  @override
  String get profilePleaseTryAgain => 'Lütfen tekrar dene';

  @override
  String get profileSecureYourAccount => 'Hesabını Güvenceye Al';

  @override
  String get profileSecureSubtitle =>
      'Hesabını her cihazdan kurtarmak için e-posta ve parola ekle';

  @override
  String get profileRetryButton => 'Tekrar Dene';

  @override
  String get profileSessionExpired => 'Oturum Sona Erdi';

  @override
  String get profileSignInToRestore =>
      'Tam erişimi geri almak için tekrar giriş yap';

  @override
  String get profileSignInButton => 'Giriş yap';

  @override
  String get profileMaybeLaterLabel => 'Belki Sonra';

  @override
  String get profileSecurePrimaryButton => 'E-posta ve Şifre Ekle';

  @override
  String get profileCompletePrimaryButton => 'Profilini Güncelle';

  @override
  String get profileLoopsLabel => 'Loop\'lar';

  @override
  String get profileLikesLabel => 'Beğeniler';

  @override
  String get profileMyLibraryLabel => 'Kütüphanem';

  @override
  String get profileMessageLabel => 'Mesaj';

  @override
  String get profileShareLabel => 'Profili paylaş';

  @override
  String get profileDeletedAccountName => 'Silinmiş hesap';

  @override
  String get inboxActionReportVanishedAccount => 'Bu hesabı bildir';

  @override
  String get inboxActionBlockVanishedAccount => 'Bu hesabı engelle';

  @override
  String get inboxActionUnblockVanishedAccount => 'Bu hesabın engelini kaldır';

  @override
  String get inboxReportedVanishedAccount => 'Bu hesap bildirildi';

  @override
  String get inboxBlockedVanishedAccount => 'Bu hesap engellendi';

  @override
  String get inboxUnblockedVanishedAccount => 'Bu hesabın engeli kaldırıldı';

  @override
  String get inboxRemoveConfirmBodyVanishedAccount =>
      'Bu, sohbeti gelen kutundan kaldırır. Sana tekrar yazarsa yeni bir sohbet başlar.';

  @override
  String get inboxConversationDeletedAccountSubtitle => 'Bu hesap silindi';

  @override
  String get profileUserFallback => 'kullanıcı';

  @override
  String get profileLinkCopied => 'Profil bağlantısı kopyalandı';

  @override
  String get profileSetupEditProfileTitle => 'Profili Düzenle';

  @override
  String get nostrSettingsNip05ProfileRequired =>
      'NIP-05 adresi eklemeden önce profilini oluştur.';

  @override
  String get nostrSettingsNip05CreateProfileAction => 'Profil oluştur';

  @override
  String get profileSetupBackLabel => 'Geri';

  @override
  String get profileSetupAboutNostr => 'Nostr Hakkında';

  @override
  String get profileSetupProfilePublished => 'Profil başarıyla yayınlandı!';

  @override
  String get profileSetupUnsavedChangesTitle => 'Değişiklikler kaydedilsin mi?';

  @override
  String get profileSetupUnsavedChangesSubtitle =>
      'Çıkmadan önce düzenlemelerini kaydet ya da at ve yoluna devam et.';

  @override
  String get profileSetupUnsavedChangesSaveButton => 'Değişiklikleri kaydet';

  @override
  String get profileSetupUnsavedChangesDiscardButton => 'Değişiklikleri at';

  @override
  String get profileSetupUnsavedChangesKeepButton => 'Düzenlemeye devam et';

  @override
  String get profileSetupCreateNewProfile => 'Yeni profil oluşturulsun mu?';

  @override
  String get profileSetupNoExistingProfile =>
      'Rölelerinizde mevcut bir profil bulamadık. Yayınlamak yeni bir profil oluşturacak. Devam edilsin mi?';

  @override
  String get profileSetupPublishButton => 'Yayınla';

  @override
  String get profileSetupUsernameTaken =>
      'Kullanıcı adı az önce alındı. Lütfen başka birini seç.';

  @override
  String get profileSetupClaimFailed =>
      'Kullanıcı adı alınamadı. Lütfen tekrar dene.';

  @override
  String get profileSetupPublishFailed =>
      'Profil yayınlanamadı. Lütfen tekrar dene.';

  @override
  String get profileSetupNoRelaysConnected =>
      'Ağa ulaşılamadı. Bağlantını kontrol et ve tekrar dene.';

  @override
  String get profileSetupDisplayNameLabel => 'Görünen Ad';

  @override
  String get profileSetupDisplayNameRequired => 'Lütfen bir görünen ad gir';

  @override
  String get profileSetupBioLabel => 'Biyografi (Opsiyonel)';

  @override
  String get profileSetupWebsiteLabel => 'Web sitesi (isteğe bağlı)';

  @override
  String get profileSetupPublicKeyLabel => 'Açık anahtar (npub)';

  @override
  String get profileSetupUsernameLabel => 'Kullanıcı Adı (Opsiyonel)';

  @override
  String get profileSetupUsernameHelper =>
      'Harf, rakam veya tire kullan. Kullanıcı adın bir divine.video adresine dönüşür. Boşluk veya simgeler için görünen adını kullan.';

  @override
  String get profileSetupSaveButton => 'Kaydet';

  @override
  String get profileSetupSavingButton => 'Kaydediliyor...';

  @override
  String get profileSetupImageUrlTitle => 'Görsel URL\'si ekle';

  @override
  String get profileSetupImageSelectionFailed =>
      'Görsel seçimi başarısız oldu. Lütfen aşağıya bir görsel URL\'si yapıştır.';

  @override
  String get profileSetupImagesTypeGroup => 'görseller';

  @override
  String get cameraPickErrorPermissionDenied =>
      'Kamera erişimi kapalı. Fotoğraf çekmek için Ayarlar\'dan aç.';

  @override
  String get cameraPickErrorPermissionRestricted =>
      'Bu cihazda kamera erişimine izin verilmiyor.';

  @override
  String get cameraPickErrorBusy => 'Seçici zaten açık. Kapat ve tekrar dene.';

  @override
  String get cameraPickErrorGeneric => 'Kamera açılamadı. Tekrar dene.';

  @override
  String get profileSetupGotItButton => 'Anlaşıldı';

  @override
  String get profileSetupUploadFailedGeneric =>
      'Görsel yüklenemedi. Lütfen daha sonra tekrar dene.';

  @override
  String get profileSetupUploadNetworkError =>
      'Ağ hatası: Lütfen internet bağlantını kontrol et ve tekrar dene.';

  @override
  String get profileSetupUploadAuthError =>
      'Kimlik doğrulama hatası: Lütfen çıkış yapıp tekrar giriş yap.';

  @override
  String get profileSetupUploadFileTooLarge =>
      'Dosya çok büyük: Lütfen daha küçük bir görsel seç (maks. 10MB).';

  @override
  String get profileSetupUploadServerError =>
      'Görsel yüklenemedi. Sunucularımız geçici olarak kullanılamıyor. Lütfen birazdan tekrar dene.';

  @override
  String get profileSetupBannerClearButton => 'Afişi temizle';

  @override
  String get profileSetupBannerChangeColor => 'Afiş rengi';

  @override
  String get profileSetupChangeBannerTitle => 'Afişi değiştir';

  @override
  String get profileSetupBannerColorPickerTitle => 'Afiş rengini değiştir';

  @override
  String get profileSetupBannerColorCustom => 'Özel';

  @override
  String get profileSetupBannerColorNone => 'Renk yok';

  @override
  String get profileSetupBannerColorLime => 'Misket limonu';

  @override
  String get profileSetupBannerColorYellow => 'Sarı';

  @override
  String get profileSetupBannerColorViolet => 'Menekşe';

  @override
  String get profileSetupBannerColorPink => 'Pembe';

  @override
  String get profileSetupBannerColorOrange => 'Turuncu';

  @override
  String get profileSetupBannerColorPurple => 'Mor';

  @override
  String get profileSetupAvatarClearButton => 'Fotoğrafı kaldır';

  @override
  String get profileSetupImageTakePhoto => 'Fotoğraf çek';

  @override
  String get profileSetupImageUploadFromCameraRoll => 'Galeriden yükle';

  @override
  String get profileSetupImagePasteLink => 'Görsel bağlantısı yapıştır';

  @override
  String get profileSetupEditAvatarLabel => 'Profil fotoğrafını düzenle';

  @override
  String get profileSetupEditBannerLabel => 'Afişi düzenle';

  @override
  String get profileSetupUsernameChecking => 'Uygunluk kontrol ediliyor...';

  @override
  String get profileSetupUsernameAvailable => 'Kullanıcı adı uygun!';

  @override
  String get profileSetupUsernameTakenIndicator =>
      'Kullanıcı adı zaten alınmış';

  @override
  String get profileSetupUsernameReserved => 'Kullanıcı adı ayrılmış';

  @override
  String get profileSetupContactSupport => 'Destek ile iletişime geç';

  @override
  String get profileSetupCheckAgain => 'Tekrar kontrol et';

  @override
  String get profileSetupUsernameBurned =>
      'Bu kullanıcı adı artık kullanılamıyor';

  @override
  String get profileSetupUsernameInvalidFormat =>
      'Sadece harfler, rakamlar ve tire kullanılabilir';

  @override
  String get profileSetupUsernameInvalidHyphenPlacement =>
      'Kullanıcı adı tireyle başlayamaz veya bitemez';

  @override
  String get profileSetupUsernameInvalidLength =>
      'Kullanıcı adı 3-63 karakter olmalı';

  @override
  String get profileSetupUsernameNetworkError =>
      'Uygunluk kontrol edilemedi. Lütfen tekrar dene.';

  @override
  String get profileSetupUsernameInvalidFormatGeneric =>
      'Geçersiz kullanıcı adı formatı';

  @override
  String get profileSetupUsernameCheckFailed => 'Uygunluk kontrolü başarısız';

  @override
  String get profileSetupUsernameReservedTitle => 'Kullanıcı adı ayrılmış';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return '$username adı ayrılmış. Neden senin olması gerektiğini anlat.';
  }

  @override
  String get profileSetupUsernameReservedHint =>
      'örn. Marka adım, sahne adım vb.';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      'Desteğe zaten başvurdun mu? Sana verilip verilmediğini görmek için \"Tekrar kontrol et\"e dokun.';

  @override
  String get profileSetupSupportRequestSent =>
      'Destek talebi gönderildi! Kısa sürede döneriz.';

  @override
  String get profileSetupCouldntOpenEmail =>
      'E-posta açılamadı. Şuraya gönder: names@divine.video';

  @override
  String get profileSetupSendRequest => 'Talebi gönder';

  @override
  String get profileSetupUseOwnNip05 => 'Kendi NIP-05 adresini kullan';

  @override
  String get profileSetupNip05AddressLabel => 'NIP-05 Adresi';

  @override
  String get profileSetupExternalNip05InvalidFormat =>
      'Geçersiz NIP-05 formatı (örn. ad@alanadi.com)';

  @override
  String get profileSetupExternalNip05DivineDomain =>
      'divine.video için yukarıdaki kullanıcı adı alanını kullan';

  @override
  String get nostrSettingsNip05Address => 'NIP-05 adresi';

  @override
  String get nostrSettingsNip05AddressSubtitle =>
      'divine.video kullanıcı adını kullan ya da kullanıcı adını kontrol ettiğin bir alan adındaki NIP-05 adresine yönlendir.';

  @override
  String get nostrSettingsNip05AddressHint => 'you@example.com';

  @override
  String get nostrSettingsNip05SaveAction => 'NIP-05\'i kaydet';

  @override
  String get nostrSettingsNip05Saved => 'NIP-05 kaydedildi';

  @override
  String get nostrSettingsNip05SaveFailed =>
      'NIP-05 kaydedilemedi. Lütfen tekrar dene.';

  @override
  String get profileSetupNip05ConfirmTitle =>
      'Kendi NIP-05\'ini mi kullanacaksın?';

  @override
  String get profileSetupNip05ConfirmBody =>
      'NIP-05, you@yourdomain.com gibi bir adı Nostr kimliğinle eşleştirir. Alan adını kontrol etmen ve doğru yola bir doğrulama dosyası koyman gerekir. Yanlış olursa insanlar seni bulamaz ve doğrulanmış kullanıcı adın kaybolur. Yalnızca bunu ayarladıysan devam et.';

  @override
  String get profileSetupNip05ConfirmContinue => 'Devam';

  @override
  String get profileSetupNip05ConfirmCancel => 'İptal';

  @override
  String get profileSetupProfilePicturePreview => 'Profil resmi önizlemesi';

  @override
  String get nostrInfoIntroBuiltOn => 'Divine Nostr üzerine kuruludur,';

  @override
  String get nostrInfoIntroDescription =>
      ' tek bir şirkete veya platforma bağlı kalmadan insanların çevrimiçi iletişim kurmasını sağlayan, sansüre dayanıklı açık bir protokoldür. ';

  @override
  String get nostrInfoIntroIdentity =>
      'Divine\'e kaydolduğunda yeni bir Nostr kimliği alırsın.';

  @override
  String get nostrInfoOwnership =>
      'Nostr, içeriğine, kimliğine ve sosyal grafiğine sahip olmana izin verir ve bunları birçok uygulamada kullanabilirsin. Sonuç: daha fazla seçenek, daha az kilitlenme ve daha sağlıklı, dayanıklı bir sosyal internet.';

  @override
  String get nostrInfoLingo => 'Nostr terimleri:';

  @override
  String get nostrInfoNpubLabel => 'npub:';

  @override
  String get nostrInfoNpubDescription =>
      ' Genel Nostr adresin. Paylaşmak güvenlidir; başkalarının seni bulmasını, takip etmesini veya mesaj göndermesini sağlar.';

  @override
  String get nostrInfoNsecLabel => 'nsec:';

  @override
  String get nostrInfoNsecDescription =>
      ' Özel anahtarın ve sahiplik kanıtın. Nostr kimliğin üzerinde tam kontrol verir, bu yüzden ';

  @override
  String get nostrInfoNsecWarning => 'her zaman gizli tut!';

  @override
  String get nostrInfoUsernameLabel => 'Nostr kullanıcı adı:';

  @override
  String get nostrInfoUsernameDescription =>
      ' Npub\'ına bağlanan insan tarafından okunabilir bir ad (örneğin @ad.divine.video). Nostr kimliğini tanımayı ve doğrulamayı kolaylaştırır, tıpkı bir e-posta adresi gibi.';

  @override
  String get nostrInfoLearnMoreAt => 'Daha fazla bilgi: ';

  @override
  String get nostrInfoGotIt => 'Anlaşıldı!';

  @override
  String get videoGridRefreshLabel => 'Daha fazla video aranıyor';

  @override
  String get videoGridOptionsTitle => 'Video Seçenekleri';

  @override
  String get videoGridEditVideo => 'Videoyu Düzenle';

  @override
  String get videoGridEditVideoSubtitle =>
      'Başlık, açıklama ve etiketleri güncelle';

  @override
  String get videoGridDeleteVideo => 'Videoyu Sil';

  @override
  String get videoGridDeleteVideoSubtitle =>
      'Bu videoyu Divine\'dan kaldır. Diğer Nostr istemcilerinde hâlâ görünebilir.';

  @override
  String get videoGridDeletingContent => 'İçerik siliniyor...';

  @override
  String get exploreTabFeatured => 'Öne çıkanlar';

  @override
  String get exploreTabClassics => 'Klasikler';

  @override
  String get exploreTabNew => 'Yeni';

  @override
  String get exploreTabPopular => 'Popüler';

  @override
  String get exploreTabCategories => 'Kategoriler';

  @override
  String get exploreTabForYou => 'Sana Özel';

  @override
  String get exploreTabLists => 'Listeler';

  @override
  String get exploreTabIntegratedApps => 'Entegre Uygulamalar';

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
      'Burada henüz bir şey yok. Yakında tekrar bak.';

  @override
  String get featuredTabLoadFailed => 'Bu koleksiyon yüklenemedi.';

  @override
  String get featuredTabRetry => 'Tekrar dene';

  @override
  String get exploreNoVideosAvailable => 'Hiç video yok';

  @override
  String get exploreDiscoverLists => 'Listeleri Keşfet';

  @override
  String get exploreAboutLists => 'Listeler Hakkında';

  @override
  String get exploreAboutListsDescription =>
      'Listeler, Divine içeriğini iki şekilde düzenlemene ve derlemene yardımcı olur:';

  @override
  String get explorePeopleLists => 'Kişi Listeleri';

  @override
  String get explorePeopleListsDescription =>
      'İçerik üretici gruplarını takip et ve en son videolarını gör';

  @override
  String get exploreVideoLists => 'Video Listeleri';

  @override
  String get exploreVideoListsDescription =>
      'Sonra izlemek için favori videolarından oynatma listeleri oluştur';

  @override
  String get exploreMyLists => 'Listelerim';

  @override
  String get exploreSubscribedLists => 'Abone Olunan Listeler';

  @override
  String get exploreErrorLoadingLists =>
      'Listeler yüklenirken hata. Lütfen tekrar dene.';

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count yeni video',
      one: '1 yeni video',
    );
    return '$_temp0';
  }

  @override
  String exploreLoadNewVideosLabel(int count) {
    return '$count yeni video yükle';
  }

  @override
  String get videoPlayerPlayVideo => 'Videoyu oynat';

  @override
  String get videoPlayerMute => 'Videoyu sessize al';

  @override
  String get videoPlayerUnmute => 'Videonun sesini aç';

  @override
  String get videoPlayerTapHint =>
      'Oynatmak veya duraklatmak için dokunun. Beğenmek için çift dokunun.';

  @override
  String get videoSettingsMenuOpen => 'Oynatma ayarlarını aç';

  @override
  String get videoSettingsMenuClose => 'Oynatma ayarlarını kapat';

  @override
  String get videoSettingsCaptionsEnable => 'Altyazıyı etkinleştir';

  @override
  String get videoSettingsCaptionsDisable => 'Altyazıyı devre dışı bırak';

  @override
  String get videoSettingsAutoAdvanceOn => 'Otomatik ilerleme açık';

  @override
  String get videoSettingsAutoAdvanceOff => 'Otomatik ilerleme kapalı';

  @override
  String get videoSettingsCaptionsOn => 'Altyazı açık';

  @override
  String get videoSettingsCaptionsOff => 'Altyazı kapalı';

  @override
  String get videoSettingsCaptionsOnForVideo => 'Bu video için altyazılar açık';

  @override
  String get videoSettingsCaptionsOffForVideo =>
      'Bu video için altyazılar kapalı';

  @override
  String get contentWarningLabel => 'İçerik Uyarısı';

  @override
  String get contentWarningNudity => 'Çıplaklık';

  @override
  String get contentWarningSexualContent => 'Cinsel İçerik';

  @override
  String get contentWarningPornography => 'Pornografi';

  @override
  String get contentWarningGraphicMedia => 'Açık Görüntüler';

  @override
  String get contentWarningViolence => 'Şiddet';

  @override
  String get contentWarningSelfHarm => 'Kendine Zarar Verme';

  @override
  String get contentWarningDrugUse => 'Uyuşturucu Kullanımı';

  @override
  String get contentWarningAlcohol => 'Alkol';

  @override
  String get contentWarningTobacco => 'Tütün';

  @override
  String get contentWarningGambling => 'Kumar';

  @override
  String get contentWarningProfanity => 'Küfür';

  @override
  String get contentWarningFlashingLights => 'Yanıp Sönen Işıklar';

  @override
  String get contentWarningAiGenerated => 'Yapay Zeka Üretimi';

  @override
  String get contentWarningSpoiler => 'Spoiler';

  @override
  String get contentWarningSensitiveContent => 'Hassas İçerik';

  @override
  String get contentWarningDescNudity =>
      'Çıplaklık veya kısmi çıplaklık içerir';

  @override
  String get contentWarningDescSexual => 'Cinsel içerik barındırır';

  @override
  String get contentWarningDescPorn => 'Açık pornografik içerik barındırır';

  @override
  String get contentWarningDescGraphicMedia =>
      'Açık veya rahatsız edici görüntüler içerir';

  @override
  String get contentWarningDescViolence => 'Şiddet içeriği barındırır';

  @override
  String get contentWarningDescSelfHarm =>
      'Kendine zarar verme referansları içerir';

  @override
  String get contentWarningDescDrugs =>
      'Uyuşturucuyla ilgili içerik barındırır';

  @override
  String get contentWarningDescAlcohol => 'Alkolle ilgili içerik barındırır';

  @override
  String get contentWarningDescTobacco => 'Tütünle ilgili içerik barındırır';

  @override
  String get contentWarningDescGambling => 'Kumarla ilgili içerik barındırır';

  @override
  String get contentWarningDescProfanity => 'Ağır dil içerir';

  @override
  String get contentWarningDescFlashingLights =>
      'Yanıp sönen ışıklar içerir (fotosensitivite uyarısı)';

  @override
  String get contentWarningDescAiGenerated =>
      'Bu içerik yapay zeka tarafından oluşturulmuştur';

  @override
  String get contentWarningDescSpoiler => 'Spoiler içerir';

  @override
  String get contentWarningDescContentWarning =>
      'İçerik üretici bunu hassas olarak işaretledi';

  @override
  String get contentWarningDescDefault =>
      'İçerik üretici bu içeriği işaretledi';

  @override
  String get contentWarningDetailsTitle => 'İçerik Uyarıları';

  @override
  String get contentWarningDetailsSubtitle =>
      'İçerik üretici bu etiketleri uyguladı:';

  @override
  String get contentWarningManageFilters => 'İçerik filtrelerini yönet';

  @override
  String get contentWarningViewAnyway => 'Yine de Görüntüle';

  @override
  String get contentWarningReportContentTooltip => 'İçeriği Bildir';

  @override
  String get contentWarningBlockUserTooltip => 'Kullanıcıyı Engelle';

  @override
  String get contentWarningBlockedTitle => 'İçerik Engellendi';

  @override
  String get contentWarningBlockedPolicy =>
      'Bu içerik politika ihlalleri nedeniyle engellendi.';

  @override
  String get contentWarningNoticeTitle => 'İçerik Bildirimi';

  @override
  String get contentWarningPotentiallyHarmfulTitle =>
      'Potansiyel Olarak Zararlı İçerik';

  @override
  String get contentWarningView => 'Görüntüle';

  @override
  String get contentWarningReportAction => 'Bildir';

  @override
  String get contentWarningHideAllLikeThis => 'Bunun gibi tüm içerikleri gizle';

  @override
  String get contentWarningNoFilterYet =>
      'Bu uyarı için henüz kayıtlı filtre yok.';

  @override
  String get contentWarningHiddenConfirmation =>
      'Bundan sonra böyle gönderileri gizleyeceğiz.';

  @override
  String get communitySuggestTitle => 'Bunu sınıflandırmaya yardım et';

  @override
  String get communitySuggestSubtitle =>
      'İçerik uyarısı mı eksik? Önerin herkese açık, imzalı ve geri alınamaz.';

  @override
  String get communitySuggestSubmit => 'Öner';

  @override
  String get communitySuggestSuccess => 'Teşekkürler. Önerin gönderildi.';

  @override
  String get communitySuggestFailure => 'Önerin gönderilemedi. Tekrar dene.';

  @override
  String get communitySuggestAlready => 'Bunu önerdin';

  @override
  String get communitySuggestActionLabel => 'Sınıflandır';

  @override
  String get videoErrorNotFound => 'Video bulunamadı';

  @override
  String get videoErrorPlayback => 'Video oynatma hatası';

  @override
  String get videoErrorAgeRestricted => 'Yaş kısıtlamalı içerik';

  @override
  String get videoErrorUnavailable => 'Video kullanılamıyor';

  @override
  String get videoErrorUnavailableBody => 'Bu video şu anda kullanılamıyor.';

  @override
  String get videoErrorRetry => 'Tekrar Dene';

  @override
  String get videoErrorContentRestricted => 'İçerik kısıtlandı';

  @override
  String get videoErrorContentRestrictedBody =>
      'Bu video, içerik kurallarımızı ihlal ettiği için kaldırıldı.';

  @override
  String get videoErrorVerifyAgeBody =>
      'Bu videoyu görüntülemek için yaşını doğrula.';

  @override
  String get videoErrorSkip => 'Atla';

  @override
  String get videoErrorVerifyAgeButton => 'Yaşı doğrula';

  @override
  String get videoErrorVerifyAgeFailed =>
      'Yaşın doğrulanamadı. Lütfen tekrar dene.';

  @override
  String get videoErrorVerifyAgeSignerUnreachable =>
      'Doğrulama zaman aşımına uğradı. Bağlantını kontrol et ya da birazdan tekrar dene.';

  @override
  String get videoErrorAdultContentHiddenTitle => 'Yetişkin içeriği kapalı';

  @override
  String get videoErrorAdultContentHiddenBody =>
      'Bu videoyu izlemek için İçerik Filtreleri\'nden aç.';

  @override
  String get videoErrorAdultContentHiddenAction => 'İçerik Filtreleri\'ni aç';

  @override
  String get videoDetailLoadError => 'Video yüklenemedi';

  @override
  String get videoDetailLoadErrorBody =>
      'Yolda bir şeyler ters gitti. Bir daha dene.';

  @override
  String get videoDetailNotFoundBody =>
      'Silinmiş, ulaşılamıyor ya da ayarların yüzünden gizlenmiş olabilir.';

  @override
  String get databaseCorruptionTitle => 'Yerel verilerin bozuldu';

  @override
  String get databaseCorruptionBody =>
      'Divine\'ı kapatıp yeniden aç — bunu otomatik olarak onarıyoruz. Taslaklarından ve kliplerinden kurtarabildiğimizi saklıyoruz, gerisi yeniden yükleniyor.';

  @override
  String get databaseCorruptionCloseButton => 'Divine\'ı kapat';

  @override
  String get videoDetailContextTitle => 'Paylaşılan video';

  @override
  String get videoDetailCloseSemanticLabel => 'Video oynatıcıyı kapat';

  @override
  String get videoFollowButtonFollow => 'Takip et';

  @override
  String get audioAttributionOriginalSound => 'Orijinal ses';

  @override
  String get audioAttributionUnavailableSound => 'Ses kullanılamıyor';

  @override
  String videoInspiredByAttributionMultiple(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return '@$creatorName +$additionalCreatorCount tarafından ilham alındı';
  }

  @override
  String videoInspiredByAttribution(String creatorName) {
    return '@$creatorName tarafından ilham alındı';
  }

  @override
  String videoCollaboratorWithOne(String name) {
    return '@$name ile';
  }

  @override
  String videoCollaboratorWithMore(String name, int count) {
    return '@$name +$count ile';
  }

  @override
  String videoCollaboratorCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count işbirlikçi',
      one: '1 işbirlikçi',
    );
    return '$_temp0. Profili görmek için dokun.';
  }

  @override
  String get videoCollaboratorPendingDecoration => 'Beklemede';

  @override
  String get videoCollaboratorPendingSemanticLabel => 'Bekleyen ortak yapımcı';

  @override
  String videoCollaboratorWithPendingSuffix(String label, int pending) {
    return '$label ($pending beklemede)';
  }

  @override
  String profileChipTapHint(String name) {
    return '$name. Profili görmek için dokun.';
  }

  @override
  String metadataHashtagChipTapHint(String hashtag) {
    return '#$hashtag. Bu hashtag\'e sahip videoları görmek için dokun.';
  }

  @override
  String get listAttributionFallback => 'Liste';

  @override
  String get shareVideoLabel => 'Videoyu paylaş';

  @override
  String sharePostSharedWith(String recipientName) {
    return 'Gönderi $recipientName ile paylaşıldı';
  }

  @override
  String sharePostSharedWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Gönderi $count kişiyle paylaşıldı',
      one: 'Gönderi $count kişiyle paylaşıldı',
    );
    return '$_temp0';
  }

  @override
  String get shareFailedToSend => 'Video gönderilemedi';

  @override
  String get shareAddedToBookmarks => 'Yer imlerine eklendi';

  @override
  String get shareRemovedFromBookmarks => 'Yer imlerinden kaldırıldı';

  @override
  String get shareFailedToAddBookmark => 'Yer imi eklenemedi';

  @override
  String get shareFailedToRemoveBookmark => 'Yer imi kaldırılamadı';

  @override
  String get shareActionFailed => 'İşlem başarısız';

  @override
  String get shareWithTitle => 'Şununla paylaş';

  @override
  String get shareFindPeople => 'Kişi bul';

  @override
  String get shareFindPeopleMultiline => 'Kişi\nbul';

  @override
  String get shareSent => 'Gönderildi';

  @override
  String shareSelectedRecipientAnnouncement(String name) {
    return '$name seçildi';
  }

  @override
  String get shareMessageHint => 'Opsiyonel mesaj ekle...';

  @override
  String get videoActionUnlike => 'Beğenmekten vazgeç';

  @override
  String get videoActionLike => 'Videoyu beğen';

  @override
  String get videoActionAutoLabel => 'Otomatik';

  @override
  String get videoActionLikeLabel => 'Beğen';

  @override
  String get videoActionReplyLabel => 'Yanıtla';

  @override
  String get videoActionRepostLabel => 'Yeniden Paylaş';

  @override
  String get videoActionShareLabel => 'Paylaş';

  @override
  String get videoActionReportLabel => 'Bildir';

  @override
  String get videoActionReport => 'Videoyu bildir';

  @override
  String get videoActionEditLabel => 'Düzenle';

  @override
  String get videoActionEdit => 'Videoyu düzenle';

  @override
  String get videoActionAboutLabel => 'Hakkında';

  @override
  String get videoActionEnableAutoAdvance => 'Otomatik ilerlemeyi etkinleştir';

  @override
  String get videoActionDisableAutoAdvance =>
      'Otomatik ilerlemeyi devre dışı bırak';

  @override
  String get videoActionRemoveRepost => 'Yeniden paylaşımı kaldır';

  @override
  String get videoActionRepost => 'Videoyu yeniden paylaş';

  @override
  String get videoActionViewComments => 'Yorumları görüntüle';

  @override
  String get videoActionMoreOptions => 'Daha fazla seçenek';

  @override
  String get videoEngagementLikersTitle => 'Beğenenler';

  @override
  String get videoEngagementRepostersTitle => 'Repost edenler';

  @override
  String get videoEngagementLikersEmpty => 'Henüz beğeni yok';

  @override
  String get videoEngagementRepostersEmpty => 'Henüz repost yok';

  @override
  String get videoEngagementLoadFailed => 'Liste yüklenemedi';

  @override
  String get videoOverlayOpenMetadataFromTitle => 'Video detaylarını aç';

  @override
  String get videoOverlayOpenMetadataFromDescription => 'Video detaylarını aç';

  @override
  String get videoOverlayCommentBarHint => 'Yorum ekle...';

  @override
  String get videoOverlayCommentBarSemanticLabel => 'Yorum ekle';

  @override
  String get videoOverlayCommentBarSendLabel => 'Yorumu gönder';

  @override
  String get videoOverlayCommentPostedSnackbar => 'Yorum yayınlandı';

  @override
  String get videoOverlayCommentPostFailedSnackbar => 'Yorum yayınlanamadı';

  @override
  String videoFeedLoopCountLine(String compactCount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'döngüler',
      one: 'döngü',
    );
    return '$compactCount $_temp0';
  }

  @override
  String get metadataBadgeNotDivine => 'Divine Değil';

  @override
  String get metadataBadgeHumanMade => 'İnsan Yapımı';

  @override
  String get metadataSoundsLabel => 'Sesler';

  @override
  String get metadataOriginalSound => 'Orijinal ses';

  @override
  String get metadataVerificationLabel => 'Doğrulama';

  @override
  String get metadataDeviceAttestation => 'Cihaz tasdik';

  @override
  String get metadataPgpSignature => 'PGP imzası';

  @override
  String get metadataC2paCredentials => 'C2PA İçerik Kimlik Bilgileri';

  @override
  String get metadataProofManifest => 'Kanıt manifestosu';

  @override
  String get metadataVerificationInfoTooltip =>
      'Bu kontroller ne anlama geliyor?';

  @override
  String metadataSectionInfoSemanticsLabel(String section, String question) {
    return '$section. $question';
  }

  @override
  String get metadataVerificationInfoTitle => 'Bu kontroller ne anlama geliyor';

  @override
  String get metadataVerificationInfoIntro =>
      'Bu sinyaller kameradan ve video dosyasının kendisinden gelir. Bir video ne kadar çok sinyal taşırsa, nereden geldiğine dair o kadar çok şey kanıtlayabiliriz.';

  @override
  String get metadataVerificationInfoDeviceAttestation =>
      'Telefonun işletim sistemi, bunu kaydeden uygulamaya kefil oldu. Bunun bir kameradan geldiğine, yüklenmiş bir dosya olmadığına dair güçlü bir kanıt.';

  @override
  String get metadataVerificationInfoPgpSignature =>
      'Video, çekildiği anda kriptografik olarak imzalandı. Sonrasında tek bir kare değişse imza bozulur.';

  @override
  String get metadataVerificationInfoC2paCredentials =>
      'Dosyanın içinde taşınan, sektör standardında bir köken kaydı — böylece Divine dışındaki uygulamalar da doğrulayabilir.';

  @override
  String get metadataVerificationInfoProofManifest =>
      'Tam ProofMode kaydı: dosya parmak izi, zaman damgası ve çekim bağlamı, videoyla birlikte.';

  @override
  String get metadataVerificationInfoFootnote =>
      'Eksik bir kontrol videoyu sahte yapmaz. Eski klipler ve yüklemeler hiç almadı — yalnızca o kısmı kanıtlayamadığımız anlamına gelir.';

  @override
  String metadataVerificationInfoLearnMore(String url) {
    return 'Daha fazla bilgi: $url';
  }

  @override
  String get metadataCreatorLabel => 'İçerik üretici';

  @override
  String get metadataCollaboratorsLabel => 'İşbirlikçiler';

  @override
  String get metadataInspiredByLabel => 'İlham alındı';

  @override
  String get metadataRepostedByLabel => 'Yeniden paylaşan';

  @override
  String metadataMoreReposters(int count) {
    return '+$count daha';
  }

  @override
  String metadataLoopsLabel(int count) {
    return 'Döngüler';
  }

  @override
  String get metadataLikesLabel => 'Beğeniler';

  @override
  String get metadataCommentsLabel => 'Yorumlar';

  @override
  String get metadataRepostsLabel => 'Yeniden Paylaşımlar';

  @override
  String get metadataVineStatsLabel => 'Vine\'da';

  @override
  String metadataVineStatsLine(
    String loops,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$loops döngü · $likes beğeni · $comments yorum · $reposts yeniden paylaşım';
  }

  @override
  String get metadataDivineStatsLabel => 'Divine\'da';

  @override
  String metadataDivineStatsLine(
    String views,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$views görüntüleme · $likes beğeni · $comments yorum · $reposts yeniden paylaşım';
  }

  @override
  String metadataPostedDateSemantics(String date) {
    return '$date tarihinde paylaşıldı';
  }

  @override
  String get devOptionsTitle => 'Geliştirici Seçenekleri';

  @override
  String get devOptionsDisableDeveloperMode =>
      'Geliştirici Modunu Devre Dışı Bırak';

  @override
  String get devOptionsDisableDeveloperModeSubtitle =>
      'Geliştirici seçeneklerini ayarlardan gizle';

  @override
  String get devOptionsDisableDeveloperModeToast =>
      'Geliştirici modu devre dışı bırakıldı';

  @override
  String get devOptionsShorebirdTitle => 'Shorebird yamaları';

  @override
  String get devOptionsShorebirdPatchLabel => 'Çalışan yama';

  @override
  String get devOptionsShorebirdNoPatch => 'Yüklü yama yok';

  @override
  String get devOptionsShorebirdUnavailable => 'Bu derlemede kullanılamıyor';

  @override
  String get devOptionsShorebirdUnavailableSubtitle =>
      'Yamalar yalnızca shorebird release ile oluşturulan derlemelerde çalışır.';

  @override
  String get devOptionsShorebirdLoading => 'Yama durumu okunuyor…';

  @override
  String get devOptionsShorebirdNotChecked =>
      'Hazırlama kanalı henüz kontrol edilmedi.';

  @override
  String get devOptionsShorebirdCheck => 'Hazırlama kanalını kontrol et';

  @override
  String get devOptionsShorebirdApply => 'Hazırlama yamasını uygula';

  @override
  String get devOptionsShorebirdUseStable => 'Kararlı güncellemelere dön';

  @override
  String get devOptionsShorebirdChecking =>
      'Hazırlama kanalı kontrol ediliyor…';

  @override
  String get devOptionsShorebirdUpdateAvailable =>
      'Uygulanmaya hazır bir hazırlama yaması var.';

  @override
  String get devOptionsShorebirdUpToDate =>
      'Bu sürüm için hazırlama yaması yok.';

  @override
  String get devOptionsShorebirdRestartRequired =>
      'İndirildi. Yüklemek için uygulamayı yeniden başlatın.';

  @override
  String get devOptionsShorebirdRollbackRequired =>
      'Bir geri alma hazır. Temel sürüme dönmek için yeniden başlatın.';

  @override
  String get devOptionsShorebirdApplying => 'İndiriliyor ve yükleniyor…';

  @override
  String get devOptionsShorebirdApplied =>
      'Yüklendi. Çalıştırmak için uygulamayı yeniden başlatın.';

  @override
  String get devOptionsShorebirdUnchanged =>
      'Hiçbir şey yüklenmedi. Hazırlama kanalını kontrol edip tekrar deneyin.';

  @override
  String get devOptionsShorebirdSelectingStableTrack =>
      'Kararlı kanal seçiliyor…';

  @override
  String get devOptionsShorebirdStableRestored =>
      'Kararlı kanal seçildi. Kararlı bir yamayı kontrol etmek için uygulamayı yeniden başlat.';

  @override
  String get devOptionsShorebirdFailure =>
      'İşlem başarısız oldu. Ayrıntılar için günlükleri kontrol edin.';

  @override
  String get devOptionsPageLoadTimes => 'Sayfa Yükleme Süreleri';

  @override
  String get devOptionsNoPageLoads =>
      'Henüz sayfa yüklemesi kaydedilmedi.\nZamanlama verisini görmek için uygulamada gezin.';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return 'Görünür: ${visibleMs}ms  |  Veri: ${dataMs}ms';
  }

  @override
  String get devOptionsSlowestScreens => 'En Yavaş Ekranlar';

  @override
  String get devOptionsVideoPlaybackFormat => 'Video Oynatma Formatı';

  @override
  String get devOptionsSwitchEnvironmentTitle => 'Ortam Değiştirilsin mi?';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return '$envName ortamına geçilsin mi?\n\nBu işlem önbelleğe alınmış video verisini temizleyecek ve yeni röleye bağlanacaktır.';
  }

  @override
  String get devOptionsCancel => 'İptal';

  @override
  String get devOptionsSwitch => 'Değiştir';

  @override
  String devOptionsSwitchedTo(String envName) {
    return '$envName ortamına geçildi';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return '$formatName formatına geçildi — önbellek temizlendi';
  }

  @override
  String get featureFlagTitle => 'Özellik Bayrakları';

  @override
  String get featureFlagResetAllTooltip =>
      'Tüm bayrakları varsayılanlara sıfırla';

  @override
  String get featureFlagError => 'Hata';

  @override
  String get relaySettingsTitle => 'Röleler';

  @override
  String get relaySettingsInfoTitle =>
      'Divine açık bir sistemdir - bağlantılarını sen kontrol edersin';

  @override
  String get relaySettingsInfoDescription =>
      'Bu röleler içeriğini merkeziyetsiz Nostr ağı üzerinde dağıtır. İstediğin kadar röle ekleyebilir veya kaldırabilirsin.';

  @override
  String get relaySettingsLearnMoreNostr => 'Nostr hakkında daha fazla bilgi →';

  @override
  String get relaySettingsFindPublicRelays =>
      'Herkese açık röleleri nostr.co.uk adresinde bul →';

  @override
  String get relaySettingsAppNotFunctional => 'Uygulama Çalışmıyor';

  @override
  String get relaySettingsRequiresRelay =>
      'Divine, videoları yüklemek, içerik paylaşmak ve veriyi senkronize etmek için en az bir röleye ihtiyaç duyar.';

  @override
  String get relaySettingsRestoreDefaultRelay => 'Varsayılan Röleyi Geri Yükle';

  @override
  String get relaySettingsAddCustomRelay => 'Özel Röle Ekle';

  @override
  String get relaySettingsAddRelay => 'Röle Ekle';

  @override
  String get relaySettingsRetry => 'Tekrar Dene';

  @override
  String get relaySettingsNoStats => 'Henüz istatistik mevcut değil';

  @override
  String get relaySettingsConnection => 'Bağlantı';

  @override
  String get relaySettingsConnected => 'Bağlı';

  @override
  String get relaySettingsDisconnected => 'Bağlantı Kesildi';

  @override
  String get relaySettingsSessionDuration => 'Oturum Süresi';

  @override
  String get relaySettingsLastConnected => 'Son Bağlantı';

  @override
  String get relaySettingsDisconnectedLabel => 'Bağlantı Kesildi';

  @override
  String get relaySettingsReason => 'Sebep';

  @override
  String get relaySettingsActiveSubscriptions => 'Aktif Abonelikler';

  @override
  String get relaySettingsTotalSubscriptions => 'Toplam Abonelikler';

  @override
  String get relaySettingsEventsReceived => 'Alınan Olaylar';

  @override
  String get relaySettingsEventsSent => 'Gönderilen Olaylar';

  @override
  String get relaySettingsRequestsThisSession => 'Bu Oturumdaki İstekler';

  @override
  String get relaySettingsFailedRequests => 'Başarısız İstekler';

  @override
  String get relaySettingsLoadingRelayInfo => 'Röle bilgisi yükleniyor...';

  @override
  String get relaySettingsAboutRelay => 'Röle Hakkında';

  @override
  String get relaySettingsSupportedNips => 'Desteklenen NIP\'ler';

  @override
  String get relaySettingsSoftware => 'Yazılım';

  @override
  String get relaySettingsViewWebsite => 'Web Sitesini Görüntüle';

  @override
  String get relaySettingsRemoveRelayTitle => 'Röle Kaldırılsın mı?';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return 'Bu röleyi kaldırmak istediğinden emin misin?\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveDefaultRelayTitle =>
      'Divine rölesi kaldırılsın mı?';

  @override
  String relaySettingsRemoveDefaultRelayMessage(String relayUrl) {
    return 'Divine\'ın rölesini kaldırmak uygulama deneyimini kötüleştirir. Videolar, paylaşım ve senkronizasyon daha az güvenilir olabilir. Bunu yalnızca deneyimli Nostr kullanıcıları yapmalı.\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveRelayTooltip => 'Röleyi kaldır';

  @override
  String get relaySettingsCancel => 'İptal';

  @override
  String get relaySettingsRemove => 'Kaldır';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return 'Röle kaldırıldı: $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay => 'Röle kaldırılamadı';

  @override
  String get relaySettingsForcingReconnection =>
      'Röle yeniden bağlantısı zorlanıyor...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    return '$count röleye bağlandı!';
  }

  @override
  String get relaySettingsFailedToConnectCheck =>
      'Rölelere bağlanılamadı. Lütfen ağ bağlantını kontrol et.';

  @override
  String get relaySettingsSavedLocallyPublishPending =>
      'Bu cihazda kaydedildi. Yayınlama tekrar çalıştığında hesabınla eşitleyeceğiz.';

  @override
  String get relaySettingsAddRelayTitle => 'Röle Ekle';

  @override
  String get relaySettingsAddRelayPrompt =>
      'Eklemek istediğin rölenin WebSocket URL\'sini gir:';

  @override
  String get relaySettingsBrowsePublicRelays =>
      'Herkese açık rölelere nostr.co.uk adresinden göz at';

  @override
  String get relaySettingsAdd => 'Ekle';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return 'Röle eklendi: $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      'Röle eklenemedi. Lütfen URL\'yi kontrol et ve tekrar dene.';

  @override
  String get relaySettingsInvalidUrl =>
      'Röle URL\'si wss:// veya ws:// ile başlamalı';

  @override
  String get relaySettingsInsecureUrl =>
      'Röle URL\'si wss:// kullanmalı (ws:// sadece localhost için izinli)';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return 'Varsayılan röle geri yüklendi: $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      'Varsayılan röle geri yüklenemedi. Lütfen ağ bağlantını kontrol et.';

  @override
  String get relaySettingsCouldNotOpenBrowser => 'Tarayıcı açılamadı';

  @override
  String get relaySettingsFailedToOpenLink => 'Bağlantı açılamadı';

  @override
  String get relaySettingsExternalRelay => 'Harici röle';

  @override
  String get relaySettingsNotConnected => 'Bağlı değil';

  @override
  String relaySettingsDisconnectedAgo(String duration) {
    return '$duration önce bağlantı kesildi';
  }

  @override
  String relaySettingsSubscriptionsSummary(int count) {
    return '$count abonelik';
  }

  @override
  String relaySettingsEventsSummary(int countValue, String count) {
    return '$count olay';
  }

  @override
  String relaySettingsTimeAgo(String duration) {
    return '$duration önce';
  }

  @override
  String get nostrSettingsIntro =>
      'Divine, merkeziyetsiz yayıncılık için Nostr protokolünü kullanır. İçeriğin seçtiğin rölelerde yaşar ve anahtarların senin kimliğindir.';

  @override
  String get nostrSettingsSectionNetwork => 'Ağ';

  @override
  String get nostrSettingsSectionAccount => 'Hesap';

  @override
  String get nostrSettingsSectionDangerZone => 'Tehlikeli Bölge';

  @override
  String get nostrSettingsRelays => 'Röleler';

  @override
  String get nostrSettingsRelaysSubtitle => 'Nostr röle bağlantılarını yönet';

  @override
  String get nostrSettingsRelayDiagnostics => 'Röle Tanılaması';

  @override
  String get nostrSettingsRelayDiagnosticsSubtitle =>
      'Röle bağlantısı ve ağ sorunlarını ayıkla';

  @override
  String get nostrSettingsMediaServers => 'Medya Sunucuları';

  @override
  String get nostrSettingsMediaServersSubtitle =>
      'Blossom yükleme sunucularını yapılandır';

  @override
  String get settingsDeveloperOptions => 'Geliştirici Seçenekleri';

  @override
  String get settingsDeveloperOptionsSubtitle =>
      'Ortam değiştirici ve hata ayıklama ayarları';

  @override
  String get nostrSettingsKeyManagement => 'Anahtar Yönetimi';

  @override
  String get nostrSettingsKeyManagementSubtitle =>
      'Nostr anahtarlarını dışa aktar, yedekle ve geri yükle';

  @override
  String get nostrSettingsClientAttribution => 'İstemci Atfı';

  @override
  String get nostrSettingsClientAttributionSubtitle =>
      'Yayınladığın etkinliklere Divine istemci etiketini ekle, böylece diğer Nostr uygulamaları bunları doğru şekilde atfedebilir. O olmadan gönderdiğin bildirimler, moderatörlerimiz incelerken daha az ağırlık taşır.';

  @override
  String get nostrSettingsMoveAccount => 'Hesabını taşı';

  @override
  String get nostrSettingsMoveAccountSubtitle =>
      'Arşivini indir ve gönderilerini ve videolarını başka bir relay\'e veya medya sunucusuna taşı.';

  @override
  String get nostrSettingsRemoveKeys => 'Anahtarları Cihazdan Kaldır';

  @override
  String get nostrSettingsRemoveKeysSubtitle =>
      'Özel anahtarını yalnızca bu cihazdan sil. İçeriğin rölelerde kalır, ancak hesabına tekrar erişmek için nsec yedeğine ihtiyacın olur.';

  @override
  String get nostrSettingsCouldNotRemoveKeys =>
      'Bu hesap bu cihazdan kaldırılamadı. Lütfen tekrar dene.';

  @override
  String get nostrSettingsDeleteAccount => 'Hesabı ve Verileri Sil';

  @override
  String get nostrSettingsDeleteAccountSubtitle =>
      'İçeriğin için silme istekleri gönderir ve bu cihazda oturumunu kapatır. Röleler, istemciler, arama dizinleri ve oturum açmış diğer cihazlar kopyaları saklayabilir.';

  @override
  String get relayDiagnosticTitle => 'Röle Tanılamaları';

  @override
  String get relayDiagnosticRefreshTooltip => 'Tanılamaları yenile';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return 'Son yenileme: $time';
  }

  @override
  String get relayDiagnosticRelayStatus => 'Röle Durumu';

  @override
  String get relayDiagnosticInitialized => 'Başlatıldı';

  @override
  String get relayDiagnosticReady => 'Hazır';

  @override
  String get relayDiagnosticNotInitialized => 'Başlatılmadı';

  @override
  String get relayDiagnosticDatabaseEvents => 'Veritabanı Olayları';

  @override
  String get relayDiagnosticActiveSubscriptions => 'Aktif Abonelikler';

  @override
  String get relayDiagnosticExternalRelays => 'Harici Röleler';

  @override
  String get relayDiagnosticConfigured => 'Yapılandırıldı';

  @override
  String relayDiagnosticRelayCount(int count) {
    return '$count röle';
  }

  @override
  String get relayDiagnosticConnectedLabel => 'Bağlı';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => 'Video Olayları';

  @override
  String get relayDiagnosticHomeFeed => 'Ana Akış';

  @override
  String relayDiagnosticVideosCount(int count) {
    return '$count video';
  }

  @override
  String get relayDiagnosticDiscovery => 'Keşif';

  @override
  String get relayDiagnosticLoading => 'Yükleniyor';

  @override
  String get relayDiagnosticYes => 'Evet';

  @override
  String get relayDiagnosticNo => 'Hayır';

  @override
  String get relayDiagnosticTestDirectQuery => 'Doğrudan Sorguyu Test Et';

  @override
  String get relayDiagnosticNetworkConnectivity => 'Ağ Bağlantısı';

  @override
  String get relayDiagnosticRunNetworkTest => 'Ağ Testini Çalıştır';

  @override
  String get relayDiagnosticBlossomServer => 'Blossom Sunucusu';

  @override
  String get relayDiagnosticTestAllEndpoints => 'Tüm Uç Noktaları Test Et';

  @override
  String get relayDiagnosticStatus => 'Durum';

  @override
  String get relayDiagnosticUrl => 'URL';

  @override
  String get relayDiagnosticError => 'Hata';

  @override
  String get relayDiagnosticFunnelCakeApi => 'FunnelCake API';

  @override
  String get relayDiagnosticBaseUrl => 'Temel URL';

  @override
  String get relayDiagnosticSummary => 'Özet';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount başarılı (ort. ${avgMs}ms)';
  }

  @override
  String get relayDiagnosticRetestAll => 'Hepsini Yeniden Test Et';

  @override
  String get relayDiagnosticRetrying => 'Yeniden deneniyor...';

  @override
  String get relayDiagnosticRetryConnection => 'Bağlantıyı Yeniden Dene';

  @override
  String get relayDiagnosticTroubleshooting => 'Sorun Giderme';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• Yeşil durum = Bağlı ve çalışıyor\n• Kırmızı durum = Bağlantı başarısız\n• Ağ testi başarısız olursa, internet bağlantısını kontrol et\n• Röleler yapılandırılmış ancak bağlı değilse \"Bağlantıyı Yeniden Dene\"ye dokun\n• Hata ayıklama için bu ekranın ekran görüntüsünü al';

  @override
  String get relayDiagnosticAllEndpointsHealthy =>
      'Tüm REST uç noktaları sağlıklı!';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      'Bazı REST uç noktaları başarısız oldu - ayrıntıları yukarıda gör';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    return 'Veritabanında $count video olayı bulundu';
  }

  @override
  String get relayDiagnosticQueryFailed =>
      'Sorgu başarısız. Lütfen tekrar dene.';

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    return '$count röleye bağlandı!';
  }

  @override
  String get relayDiagnosticFailedToConnect => 'Hiçbir röleye bağlanılamadı';

  @override
  String get relayDiagnosticConnectionRetryFailed =>
      'Bağlantı yeniden denemesi başarısız. Lütfen tekrar dene.';

  @override
  String get relayDiagnosticConnectedAuthenticated =>
      'Bağlı ve Kimlik Doğrulandı';

  @override
  String get relayDiagnosticConnectedOnly => 'Bağlı';

  @override
  String get relayDiagnosticNotConnected => 'Bağlı değil';

  @override
  String get relayDiagnosticNoRelaysConfigured => 'Yapılandırılmış röle yok';

  @override
  String get relayDiagnosticFailed => 'Başarısız';

  @override
  String get notificationSettingsTitle => 'Bildirimler';

  @override
  String get notificationSettingsResetTooltip => 'Varsayılanlara sıfırla';

  @override
  String get notificationSettingsTypes => 'Bildirim Türleri';

  @override
  String get notificationSettingsLikes => 'Beğeniler';

  @override
  String get notificationSettingsLikesSubtitle =>
      'Biri videolarını beğendiğinde';

  @override
  String get notificationSettingsComments => 'Yorumlar';

  @override
  String get notificationSettingsCommentsSubtitle =>
      'Biri videolarına yorum yaptığında';

  @override
  String get notificationSettingsFollows => 'Takipler';

  @override
  String get notificationSettingsFollowsSubtitle => 'Biri seni takip ettiğinde';

  @override
  String get notificationSettingsMentions => 'Bahsetmeler';

  @override
  String get notificationSettingsMentionsSubtitle => 'Senden bahsedildiğinde';

  @override
  String get notificationSettingsReposts => 'Yeniden Paylaşımlar';

  @override
  String get notificationSettingsRepostsSubtitle =>
      'Biri videolarını yeniden paylaştığında';

  @override
  String get notificationSettingsNewPosts => 'Yeni vine\'lar';

  @override
  String get notificationSettingsNewPostsSubtitle =>
      'İzlediğin biri paylaştığında';

  @override
  String get notificationSettingsActions => 'İşlemler';

  @override
  String get notificationSettingsMarkAllAsRead =>
      'Tümünü Okundu Olarak İşaretle';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle =>
      'Tüm bildirimleri okundu olarak işaretle';

  @override
  String get notificationSettingsAllMarkedAsRead =>
      'Tüm bildirimler okundu olarak işaretlendi';

  @override
  String get notificationSettingsMarkAllAsReadFailed =>
      'Tümünü okundu olarak işaretleme başarısız';

  @override
  String get notificationSettingsResetToDefaults =>
      'Ayarlar varsayılanlara sıfırlandı';

  @override
  String get notificationSettingsAbout => 'Bildirimler Hakkında';

  @override
  String get notificationSettingsAboutDescription =>
      'Bildirimler Nostr protokolüyle desteklenir. Gerçek zamanlı güncellemeler Nostr rölelerine olan bağlantına bağlıdır. Bazı bildirimler gecikebilir.';

  @override
  String get safetySettingsWhatYouSee => 'GÖRDÜKLERİN';

  @override
  String get safetySettingsWhatYouPublish => 'PAYLAŞTIKLARIN';

  @override
  String get safetySettingsShowDivineHostedOnly =>
      'Yalnızca Divine\'de barındırılan videoları göster';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle =>
      'Diğer medya sunucularından sunulan videoları gizle';

  @override
  String get safetySettingsModeration => 'MODERASYON';

  @override
  String get safetySettingsBlockedUsers => 'ENGELLENEN KULLANICILAR';

  @override
  String get safetySettingsAgeVerification => 'YAŞ DOĞRULAMA';

  @override
  String get safetySettingsAgeConfirmation =>
      '18 yaş veya üzerinde olduğumu onaylıyorum';

  @override
  String get safetySettingsAgeRequired =>
      'Yetişkin içeriği görüntülemek için gereklidir';

  @override
  String get safetySettingsAgeLockedForMinor => 'Hesabın için kilitli';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle =>
      'Resmi moderasyon hizmeti (varsayılan olarak açık)';

  @override
  String get safetySettingsPeopleIFollow => 'Takip ettiğim kişiler';

  @override
  String get safetySettingsPeopleIFollowSubtitle =>
      'Takip ettiğin kişilerin etiketlerine abone ol';

  @override
  String get safetySettingsAddCustomLabeler => 'Özel Etiketleyici Ekle';

  @override
  String get safetySettingsAddCustomLabelerHint => 'npub gir...';

  @override
  String get safetySettingsAddCustomLabelerListTitle =>
      'Özel etiketleyici ekle';

  @override
  String get safetySettingsRemoveLabeler => 'Etiketleyiciyi kaldır';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle => 'npub adresi gir';

  @override
  String get safetySettingsNoBlockedUsers => 'Engellenmiş kullanıcı yok';

  @override
  String get safetySettingsUnblock => 'Engeli kaldır';

  @override
  String get safetySettingsUserUnblocked => 'Kullanıcının engeli kaldırıldı';

  @override
  String get safetySettingsCancel => 'İptal';

  @override
  String get safetySettingsAdd => 'Ekle';

  @override
  String get analyticsTitle => 'İçerik Üretici Analitikleri';

  @override
  String get analyticsDiagnosticsTooltip => 'Tanılamalar';

  @override
  String get analyticsDiagnosticsSemanticLabel => 'Tanılamaları aç/kapat';

  @override
  String get analyticsRetry => 'Tekrar Dene';

  @override
  String get analyticsUnableToLoad => 'Analitikler yüklenemiyor.';

  @override
  String get analyticsServerUnavailable =>
      'Creator analytics is having server trouble. Please try again in a moment.';

  @override
  String get analyticsConnectionIssue =>
      'Creator analytics could not connect. Check your connection and try again.';

  @override
  String get analyticsSignInRequired =>
      'İçerik üretici analitiklerini görmek için giriş yap.';

  @override
  String get analyticsViewDataUnavailable =>
      'Görüntüleme verileri bu gönderiler için röleden şu anda alınamıyor. Beğeni/yorum/yeniden paylaşım metrikleri hala doğrudur.';

  @override
  String get analyticsViewDataTitle => 'Görüntüleme Verileri';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return 'Güncellendi $time • Skorlar mümkün olduğunda Funnelcake\'ten gelen beğeni, yorum, yeniden paylaşım ve görüntüleme/döngü verilerini kullanır.';
  }

  @override
  String get analyticsVideos => 'Videolar';

  @override
  String get analyticsViews => 'Görüntülenme';

  @override
  String get analyticsInteractions => 'Etkileşimler';

  @override
  String get analyticsEngagement => 'Etkileşim Oranı';

  @override
  String get analyticsFollowers => 'Takipçiler';

  @override
  String get analyticsAvgPerPost => 'Gönderi Ort.';

  @override
  String get analyticsInteractionMix => 'Etkileşim Dağılımı';

  @override
  String get analyticsLikes => 'Beğeniler';

  @override
  String get analyticsComments => 'Yorumlar';

  @override
  String get analyticsReposts => 'Yeniden Paylaşımlar';

  @override
  String get analyticsPerformanceHighlights => 'Performans Öne Çıkanları';

  @override
  String get analyticsMostViewed => 'En çok görüntülenen';

  @override
  String get analyticsMostDiscussed => 'En çok tartışılan';

  @override
  String get analyticsMostReposted => 'En çok yeniden paylaşılan';

  @override
  String get analyticsNoVideosYet => 'Henüz video yok';

  @override
  String get analyticsViewDataUnavailableShort => 'Görüntüleme verileri yok';

  @override
  String analyticsViewsCount(int countValue, String count) {
    return '$count görüntülenme';
  }

  @override
  String analyticsCommentsCount(int countValue, String count) {
    return '$count yorum';
  }

  @override
  String analyticsRepostsCount(int countValue, String count) {
    return '$count yeniden paylaşım';
  }

  @override
  String get analyticsTopContent => 'En İyi İçerik';

  @override
  String get analyticsPublishPrompt =>
      'Sıralamaları görmek için birkaç video yayınla.';

  @override
  String get analyticsEngagementRateExplainer =>
      'Sağ taraftaki % = Etkileşim Oranı (etkileşimlerin görüntülenmeye bölümü).';

  @override
  String get analyticsEngagementRateNoViews =>
      'Etkileşim Oranı görüntüleme verisi gerektirir; değerler görüntüleme mevcut olana kadar Yok olarak görünür.';

  @override
  String get analyticsEngagementLabel => 'Etkileşim';

  @override
  String get analyticsViewsUnavailable => 'görüntüleme yok';

  @override
  String analyticsInteractionsCount(int countValue, String count) {
    return '$count etkileşim';
  }

  @override
  String get analyticsPostAnalytics => 'Gönderi Analitikleri';

  @override
  String get analyticsOpenPost => 'Gönderiyi Aç';

  @override
  String get analyticsRecentDailyInteractions => 'Son Günlük Etkileşimler';

  @override
  String get analyticsNoActivityYet => 'Bu aralıkta henüz etkinlik yok.';

  @override
  String get analyticsDailyInteractionsExplainer =>
      'Etkileşimler = gönderi tarihine göre beğeni + yorum + yeniden paylaşım.';

  @override
  String get analyticsDailyBarExplainer =>
      'Çubuk uzunluğu bu penceredeki en yüksek gününe göredir.';

  @override
  String get analyticsAudienceSnapshot => 'Kitle Özeti';

  @override
  String analyticsFollowersCount(String count) {
    return 'Takipçiler: $count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return 'Takip edilenler: $count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      'Kaynak/coğrafya/zaman ayrıntıları, Funnelcake kitle analitik uç noktalarını ekledikçe doldurulacak.';

  @override
  String get analyticsRetention => 'Elde Tutma';

  @override
  String get analyticsRetentionWithViews =>
      'Elde tutma eğrisi ve izleme süresi dağılımı, Funnelcake\'ten saniye/kova başına elde tutma geldiğinde görünecek.';

  @override
  String get analyticsRetentionWithoutViews =>
      'Elde tutma verileri, Funnelcake tarafından görüntüleme + izleme süresi analitikleri dönene kadar mevcut değildir.';

  @override
  String get analyticsDiagnostics => 'Tanılamalar';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return 'Toplam video: $count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return 'Görüntülenmeli: $count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return 'Görüntülenme eksik: $count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return 'Beslenmiş (toplu): $count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return 'Beslenmiş (/views): $count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return 'Kaynaklar: $sources';
  }

  @override
  String analyticsDiagnosticsFailedSources(String sources) {
    return 'Failed sources: $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => 'Sabit test verisini kullan';

  @override
  String get analyticsNa => 'Yok';

  @override
  String get authCreateNewAccount => 'Yeni bir Divine hesabı oluştur';

  @override
  String get authCreateNewAccountShort => 'Yeni hesap oluştur';

  @override
  String get authSignInDifferentAccount => 'Farklı bir hesapla giriş yap';

  @override
  String get authUseAnotherAccount => 'Başka bir hesap kullan';

  @override
  String authContinueAs(String displayName) {
    return '$displayName olarak devam et';
  }

  @override
  String get authRecoveryDraftsOwner =>
      'Taslakların ve kliplerin bu hesaba kaydedildi';

  @override
  String get authRecoveryOtherAccountWarning =>
      'Buradan giriş yaparsan o taslaklar ve klipler gizlenir';

  @override
  String get authTermsPrefix =>
      'Aşağıdaki seçeneklerden birini seçerek en az 16 yaşında olduğunu (ya da ';

  @override
  String get authTermsAgeAuthorizationCta => 'Divine yaş doğrulamasını';

  @override
  String get authTermsAfterAgeAuthorization =>
      ' tamamladığını) onaylıyor ve şunları kabul ediyorsun: ';

  @override
  String get authTermsOfService => 'Hizmet Şartları';

  @override
  String get authPrivacyPolicy => 'Gizlilik Politikası';

  @override
  String get authTermsAnd => ' ve ';

  @override
  String get authSafetyStandards => 'Güvenlik Standartları';

  @override
  String get authAmberNotInstalled => 'Amber uygulaması yüklü değil';

  @override
  String get authAmberConnectionFailed => 'Amber ile bağlanılamadı';

  @override
  String get authPasswordResetSent =>
      'Bu e-posta ile bir hesap varsa, bir parola sıfırlama bağlantısı gönderildi.';

  @override
  String get authSignInTitle => 'Giriş yap';

  @override
  String get authEmailLabel => 'E-posta';

  @override
  String get authPasswordLabel => 'Parola';

  @override
  String get authConfirmPasswordLabel => 'Parolayı onayla';

  @override
  String get authEmailRequired => 'E-posta gereklidir';

  @override
  String get authEmailInvalid => 'Geçerli bir e-posta girin';

  @override
  String get authPasswordRequired => 'Parola gereklidir';

  @override
  String get authConfirmPasswordRequired => 'Lütfen parolanızı onaylayın';

  @override
  String get authPasswordsDoNotMatch => 'Parolalar eşleşmiyor';

  @override
  String get authForgotPassword => 'Parolanı mı unuttun?';

  @override
  String get authImportNostrKey => 'Nostr anahtarını içe aktar';

  @override
  String get authConnectSignerApp => 'Bir imzalama uygulaması ile bağlan';

  @override
  String get authSignInWithAmber => 'Amber ile giriş yap';

  @override
  String get authSignInWithBrowserExtension =>
      'Tarayıcı uzantısı ile giriş yap';

  @override
  String get authNip07ConnectionFailed => 'Tarayıcı uzantınıza bağlanılamadı.';

  @override
  String get authNip07ExtensionNotFound =>
      'Tarayıcı uzantısı bulunamadı. Alby, nos2x veya NIP-07 uyumlu başka bir uzantı yükleyin.';

  @override
  String get authSignInOptionsTitle => 'Giriş seçenekleri';

  @override
  String get authInfoEmailPasswordTitle => 'E-posta ve Parola';

  @override
  String get authInfoEmailPasswordDescription =>
      'Divine hesabınla giriş yap. E-posta ve parolayla kaydoldunsa onları burada kullan.';

  @override
  String get authInfoImportNostrKeyDescription =>
      'Zaten bir Nostr kimliğin var mı? nsec özel anahtarını başka bir istemciden içe aktar.';

  @override
  String get authInfoSignerAppTitle => 'İmzalama Uygulaması';

  @override
  String get authInfoSignerAppDescription =>
      'Geliştirilmiş anahtar güvenliği için nsecBunker gibi NIP-46 uyumlu bir uzaktan imzalayıcı kullanarak bağlan.';

  @override
  String get authInfoAmberTitle => 'Amber';

  @override
  String get authInfoAmberDescription =>
      'Nostr anahtarlarını güvenli şekilde yönetmek için Android\'deki Amber imzalama uygulamasını kullan.';

  @override
  String get authInfoBrowserExtensionTitle => 'Tarayıcı Uzantısı';

  @override
  String get authInfoBrowserExtensionDescription =>
      'Alby veya nos2x gibi bir NIP-07 tarayıcı uzantısıyla giriş yapın. Anahtarlarınız uzantıda kalır — Divine bunları asla görmez.';

  @override
  String get authSignInErrorInvalidCredentials =>
      'E-posta veya şifre yanlış. Tekrar dene.';

  @override
  String get authSignInErrorEmailNotVerified =>
      'Giriş yapmadan önce e-postanı doğrula — bağlantı için gelen kutunu kontrol et.';

  @override
  String get authSignInErrorInvalidEmail =>
      'Bu geçerli bir e-posta adresi gibi görünmüyor.';

  @override
  String get authSignInErrorNetwork =>
      'Sunucuya ulaşılamıyor. Bağlantını kontrol edip tekrar dene.';

  @override
  String get authSignInErrorGeneric =>
      'Bir şeyler ters gitti. Lütfen tekrar dene.';

  @override
  String get authSignInOptionsHintPrefix =>
      'Geçen sefer nasıl giriş yaptığını hatırlamıyor musun? ';

  @override
  String get authSignInOptionsHintCta => 'Tüm giriş seçeneklerini gör';

  @override
  String get authCreateAccountTitle => 'Hesap oluştur';

  @override
  String get authBackToInviteCode => 'Davet koduna geri dön';

  @override
  String get authUseDivineNoBackup => 'Yedek olmadan Divine kullan';

  @override
  String get authSkipConfirmTitle => 'Son bir şey...';

  @override
  String get authSkipConfirmKeyCreated =>
      'İçerisin! Divine hesabını güçlendirecek güvenli bir anahtar oluşturalım.';

  @override
  String get authSkipConfirmKeyOnly =>
      'E-posta olmadan, anahtarın Divine\'ın bu hesabın sana ait olduğunu anlayabileceği tek yoldur.';

  @override
  String get authSkipConfirmRecommendEmail =>
      'Anahtarına uygulama içinden ulaşabilirsin, ancak teknik değilsen şimdi bir e-posta ve parola eklemeni öneririz. Bu cihazı kaybeder veya sıfırlarsan hesabına giriş yapmayı ve geri yüklemeyi kolaylaştırır.';

  @override
  String get authAddEmailPassword => 'E-posta ve parola ekle';

  @override
  String get authUseThisDeviceOnly => 'Yalnızca bu cihazı kullan';

  @override
  String get authCompleteRegistration => 'Kaydını tamamla';

  @override
  String get authVerifying => 'Doğrulanıyor...';

  @override
  String get authVerificationLinkSent =>
      'Şu adrese doğrulama bağlantısı gönderdik:';

  @override
  String get authClickVerificationLink =>
      'Kaydı tamamlamak için\nlütfen e-postandaki bağlantıya tıkla.';

  @override
  String get authPleaseWaitVerifying =>
      'Lütfen e-postan doğrulanırken bekle...';

  @override
  String get authWaitingForVerification => 'Doğrulama bekleniyor';

  @override
  String get authOpenEmailApp => 'E-posta uygulamasını aç';

  @override
  String get authVerificationPinPrompt =>
      'Ya da e-postana gelen 6 haneli kodu gir';

  @override
  String get authVerificationPinFieldLabel => '6 haneli kod';

  @override
  String get authVerificationPinSubmit => 'Kodu doğrula';

  @override
  String get authVerificationResendPrompt => 'Kod gelmedi mi?';

  @override
  String get authVerificationResend => 'Tekrar Gönder';

  @override
  String authVerificationResendCooldown(String time) {
    return '$time sonra tekrar gönder';
  }

  @override
  String get authVerificationResendFailed =>
      'E-posta tekrar gönderilemedi. Yeniden dene.';

  @override
  String get authVerificationResendExpired =>
      'Bu kayıt süresi doldu. Yeni bir kod almak için baştan başla.';

  @override
  String get authVerificationResendUnavailable =>
      'Şu anda yeniden gönderme yapılamıyor. Sana zaten gönderdiğimiz e-postadaki 6 haneli kodu kullan.';

  @override
  String get authVerificationPollingStopped =>
      'Senin için kontrol etmeyi bıraktık. Girişi tamamlamak için e-postandaki 6 haneli kodu gir.';

  @override
  String get authWelcomeToDivine => 'Divine\'a Hoş Geldin!';

  @override
  String get authEmailVerified => 'E-postan doğrulandı.';

  @override
  String get authSigningYouIn => 'Giriş yapılıyor';

  @override
  String get authErrorTitle => 'Olamaz.';

  @override
  String get authVerificationFailed =>
      'E-postanı doğrulayamadık.\nLütfen tekrar dene.';

  @override
  String get authStartOver => 'Baştan başla';

  @override
  String get authEmailVerifiedLogin =>
      'E-posta doğrulandı! Devam etmek için giriş yap.';

  @override
  String get authVerificationLinkExpired =>
      'Bu doğrulama bağlantısı artık geçerli değil.';

  @override
  String get authVerificationConnectionError =>
      'E-posta doğrulanamıyor. Lütfen bağlantını kontrol et ve tekrar dene.';

  @override
  String get authWaitlistConfirmTitle => 'İçerisin!';

  @override
  String authWaitlistUpdatesAt(String email) {
    return 'Güncellemeleri $email adresine göndereceğiz.\nDaha fazla davet kodu çıktığında sana göndereceğiz.';
  }

  @override
  String get authOk => 'Tamam';

  @override
  String get authTryAgain => 'Tekrar dene';

  @override
  String get authContactSupport => 'Destekle iletişime geç';

  @override
  String authCouldNotOpenEmail(String email) {
    return '$email açılamadı';
  }

  @override
  String get authAddInviteCode => 'Davet kodunu ekle';

  @override
  String get authInviteCodeLabel => 'Davet kodu';

  @override
  String get authEnterYourCode => 'Kodunu gir';

  @override
  String get authNext => 'İleri';

  @override
  String get authJoinWaitlist => 'Bekleme listesine katıl';

  @override
  String get authJoinWaitlistTitle => 'Bekleme listesine katıl';

  @override
  String get authJoinWaitlistDescription =>
      'E-postanı paylaş, erişim açıldıkça güncelleme gönderelim.';

  @override
  String get authJoinWaitlistNewsletterOptIn => 'Bana Divine ilhamı gönderin';

  @override
  String get authInviteAccessHelp => 'Davet erişimi yardımı';

  @override
  String get authGeneratingConnection => 'Bağlantı oluşturuluyor...';

  @override
  String get authConnectedAuthenticating => 'Bağlandı! Kimlik doğrulanıyor...';

  @override
  String get authConnectionTimedOut => 'Bağlantı zaman aşımı';

  @override
  String get authApproveConnection =>
      'İmzalama uygulamanda bağlantıyı onayladığından emin ol.';

  @override
  String get authConnectionCancelled => 'Bağlantı iptal edildi';

  @override
  String get authConnectionCancelledMessage => 'Bağlantı iptal edildi.';

  @override
  String get authConnectionFailed => 'Bağlantı başarısız';

  @override
  String get authUnknownError => 'Bilinmeyen bir hata oluştu.';

  @override
  String get authNostrConnectStartFailed =>
      'İmzalama uygulamasına ulaşılamadı. Bağlantını kontrol et ve tekrar dene.';

  @override
  String get authNostrConnectInvalidSession =>
      'Bu bağlantı artık geçerli değil. Yeni bir tane oluştur.';

  @override
  String get authNostrConnectSetupFailed =>
      'Az kaldı — girişini tamamlayamadık. Tekrar dene.';

  @override
  String get authUrlCopied => 'URL panoya kopyalandı';

  @override
  String get authConnectToDivine => 'Divine\'a Bağlan';

  @override
  String get authPasteBunkerUrl => 'bunker:// URL\'sini yapıştır';

  @override
  String get authBunkerUrlHint => 'bunker:// URL';

  @override
  String get authInvalidBunkerUrl =>
      'Geçersiz bunker URL\'si. bunker:// ile başlamalıdır';

  @override
  String get authScanSignerApp => 'Bağlanmak için\nimzalama uygulamanla tara.';

  @override
  String authWaitingForConnection(int seconds) {
    return 'Bağlantı bekleniyor... ${seconds}sn';
  }

  @override
  String get authCopyUrl => 'URL\'yi Kopyala';

  @override
  String get authShare => 'Paylaş';

  @override
  String get authAddBunker => 'Bunker ekle';

  @override
  String get authCompatibleSignerApps => 'Uyumlu imzalama uygulamaları';

  @override
  String get authFailedToConnect => 'Bağlanılamadı';

  @override
  String get authResetPasswordTitle => 'Parolayı Sıfırla';

  @override
  String get authResetPasswordSubtitle =>
      'Lütfen yeni parolanı gir. En az 8 karakter olmalıdır.';

  @override
  String get authNewPasswordLabel => 'Yeni Parola';

  @override
  String get authConfirmNewPasswordLabel => 'Yeni parolayı onayla';

  @override
  String get authPasswordTooShort => 'Parola en az 8 karakter olmalı';

  @override
  String get authPasswordResetSuccess =>
      'Parola sıfırlama başarılı. Lütfen giriş yap.';

  @override
  String get authPasswordResetFailed => 'Parola sıfırlama başarısız';

  @override
  String get authUnexpectedError =>
      'Beklenmeyen bir hata oluştu. Lütfen tekrar dene.';

  @override
  String get authUpdatePassword => 'Parolayı güncelle';

  @override
  String get authSecureAccountTitle => 'Güvenli hesap';

  @override
  String get authUnableToAccessKeys =>
      'Anahtarlarına erişilemiyor. Lütfen tekrar dene.';

  @override
  String get authRegistrationFailed => 'Kayıt başarısız';

  @override
  String get authRegistrationComplete =>
      'Kayıt tamamlandı. Lütfen e-postanı kontrol et.';

  @override
  String get authSecureAccountAlreadyRegistered =>
      'Looks like an account already exists. Try a different email, or sign in to the existing account with this email address. If neither works, contact support.';

  @override
  String get authFailedToSendResetEmail => 'Sıfırlama e-postası gönderilemedi.';

  @override
  String get authSending => 'Gönderiliyor...';

  @override
  String get authSignInButton => 'Giriş yap';

  @override
  String get authVerificationErrorTimeout =>
      'Doğrulama zaman aşımına uğradı. Lütfen tekrar kaydolmayı dene.';

  @override
  String get authVerificationErrorMissingCode =>
      'Doğrulama başarısız — yetkilendirme kodu eksik.';

  @override
  String get authVerificationErrorPollFailed =>
      'Doğrulama başarısız. Lütfen tekrar dene.';

  @override
  String get authVerificationErrorNetworkExchange =>
      'Giriş sırasında ağ hatası. Lütfen tekrar dene.';

  @override
  String get authVerificationErrorOAuthExchange =>
      'Doğrulama başarısız. Lütfen tekrar kaydolmayı dene.';

  @override
  String get authVerificationErrorSignInFailed =>
      'Giriş başarısız. Lütfen manuel olarak giriş yapmayı dene.';

  @override
  String get authVerificationEmailAlreadyRegistered =>
      'Bu e-posta zaten kayıtlı. Bunun yerine giriş yap.';

  @override
  String get authVerificationErrorPinInvalid =>
      'Kod eşleşmedi. Kontrol edip tekrar dene.';

  @override
  String get authVerificationErrorPinExpired =>
      'Kodun süresi doldu. Yeni kod almak için Tekrar Gönder\'e dokun.';

  @override
  String get authVerificationErrorPinLocked =>
      'Çok fazla deneme. Yeni kod almak için Tekrar Gönder\'e dokun.';

  @override
  String get authVerificationErrorPinFailed =>
      'Kod doğrulanamadı. Lütfen tekrar dene.';

  @override
  String get authVerificationErrorPinUnavailable =>
      'Kod girişi şu anda kullanılamıyor. E-postandaki bağlantıya dokun ya da yenisini almak için tekrar gönder.';

  @override
  String get authInviteCodeErrorMalformed =>
      'ABCD-EFGH gibi bir davet kodu gir.';

  @override
  String get authInviteCodeErrorNotFound => 'Bu davet kodu geçerli görünmüyor.';

  @override
  String get authInviteCodeErrorAlreadyUsed =>
      'Bu davet kodu zaten kullanılmış ya da iptal edilmiş.';

  @override
  String get authInviteGateErrorCreatorFull =>
      'Bu içerik üreticisinin davetleri tükendi';

  @override
  String get authInviteGateErrorUnavailable =>
      'Bu davet kodu kullanılamıyor. Bekleme listesine katıl, yer açılınca sana davet göndereceğiz.';

  @override
  String get authInviteGateErrorCheckFailed =>
      'Bu kodu kontrol edemedik. Tekrar dene.';

  @override
  String get authInviteGateErrorUnknown =>
      'Bir şeyler ters gitti. Davet kodunu tekrar dene.';

  @override
  String get authInviteErrorAlreadyUsed =>
      'Bu davet kodu artık kullanılamıyor. Davet koduna geri dön, bekleme listesine katıl veya destekle iletişime geç.';

  @override
  String get authInviteErrorInvalid =>
      'Bu davet kodu şu anda kullanılamıyor. Davet koduna geri dön, bekleme listesine katıl veya destekle iletişime geç.';

  @override
  String get authInviteErrorTemporary =>
      'Davetini şu anda doğrulayamadık. Davet koduna geri dönüp tekrar dene veya destekle iletişime geç.';

  @override
  String get authInviteErrorUnknown =>
      'Davetini etkinleştiremedik. Davet koduna geri dön, bekleme listesine katıl veya destekle iletişime geç.';

  @override
  String get shareSheetSave => 'Kaydet';

  @override
  String get shareSheetRemoveFromSaved => 'Kaydı kaldır';

  @override
  String get shareSheetSaveToGallery => 'Galeriye Kaydet';

  @override
  String get shareSheetSaveWithWatermark => 'Filigranlı Kaydet';

  @override
  String get shareSheetSaveVideo => 'Videoyu Kaydet';

  @override
  String get shareSheetAddToClips => 'Kliplere ekle';

  @override
  String get shareSheetNameClipTitle => 'Bu klibi adlandır';

  @override
  String get shareSheetNameClipSubtitle =>
      'Kütüphanende tanıyacağın bir ad seç.';

  @override
  String get shareSheetClipTitleLabel => 'Klip başlığı';

  @override
  String get shareSheetSaveClip => 'Klibi kaydet';

  @override
  String shareSheetSavedClipToClips(String title) {
    return '\"$title\" kliplere kaydedildi';
  }

  @override
  String get shareSheetUntitledClip => 'Başlıksız klip';

  @override
  String get shareSheetAddToClipsFailed => 'Kliplere eklenemedi';

  @override
  String get shareSheetAddToList => 'Listeye Ekle';

  @override
  String get shareSheetCopy => 'Kopyala';

  @override
  String get shareSheetShareVia => 'Şununla paylaş';

  @override
  String get shareSheetEventJson => 'Olay JSON\'u';

  @override
  String get shareSheetEventId => 'Olay Kimliği';

  @override
  String get shareSheetMoreActions => 'Daha fazla işlem';

  @override
  String get shareSheetCrosspost => 'Çapraz Paylaş';

  @override
  String get crosspostSheetTitle => 'Bu videoyu çapraz paylaş';

  @override
  String get crosspostSheetSubtitle =>
      'Bağlı platformlarına gönder. Paylaşım birkaç dakika sürebilir.';

  @override
  String get crosspostSubmit => 'Çapraz Paylaş';

  @override
  String get crosspostStatusQueued => 'Sırada';

  @override
  String get crosspostStatusUploading => 'Yükleniyor';

  @override
  String get crosspostStatusProcessing => 'İşleniyor';

  @override
  String get crosspostStatusPosted => 'Paylaşıldı';

  @override
  String get crosspostStatusFailed => 'Başarısız';

  @override
  String get crosspostStatusSkipped => 'Atlandı';

  @override
  String get crosspostStatusNeedsReauth => 'Yeniden bağlantı gerekli';

  @override
  String get crosspostViewPost => 'Gönderiyi görüntüle';

  @override
  String crosspostReconnectPrompt(String platform) {
    return 'Paylaşmaya devam etmek için çapraz paylaşım ayarlarından $platform hesabını yeniden bağla.';
  }

  @override
  String get crosspostReconnect => 'Yeniden Bağla';

  @override
  String get crosspostErrorNotOwner =>
      'Yalnızca kendi videoların çapraz paylaşılabilir.';

  @override
  String get crosspostErrorNotEligible =>
      'Bu video çapraz paylaşım için uygun değil.';

  @override
  String get crosspostErrorNotConnected => 'Bu platform bağlı değil.';

  @override
  String get crosspostErrorUnauthorized =>
      'Hesabını yeniden bağla, sonra tekrar dene.';

  @override
  String get crosspostErrorNetwork =>
      'Çapraz paylaşım servisine ulaşılamadı. Birazdan tekrar dene.';

  @override
  String get crosspostFailedGeneric => 'Çapraz paylaşım başarısız oldu.';

  @override
  String get crosspostStillWorking =>
      'Hâlâ çalışıyoruz. Bunu kapatabilirsin — paylaşım arka planda devam edecek.';

  @override
  String get crosspostDone => 'Bitti';

  @override
  String get watermarkDownloadSavedToCameraRoll => 'Kamera Rulosuna Kaydedildi';

  @override
  String get watermarkDownloadShare => 'Paylaş';

  @override
  String get watermarkDownloadDone => 'Bitti';

  @override
  String get watermarkDownloadPhotosAccessNeeded =>
      'Fotoğraf Erişimi Gerekiyor';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      'Videoları kaydetmek için Ayarlar\'dan Fotoğraf erişimine izin ver.';

  @override
  String get watermarkDownloadOpenSettings => 'Ayarları Aç';

  @override
  String get watermarkDownloadNotNow => 'Şimdi Değil';

  @override
  String get watermarkDownloadFailed => 'İndirme Başarısız';

  @override
  String get watermarkDownloadDismiss => 'Kapat';

  @override
  String get watermarkDownloadStageDownloading => 'Video İndiriliyor';

  @override
  String get watermarkDownloadStageWatermarking => 'Filigran Ekleniyor';

  @override
  String get watermarkDownloadStageSaving => 'Kamera Rulosuna Kaydediliyor';

  @override
  String get watermarkDownloadStageDownloadingDesc => 'Video ağdan alınıyor...';

  @override
  String get watermarkDownloadStageWatermarkingDesc =>
      'Divine filigranı uygulanıyor...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      'Filigranlı video kamera rulosuna kaydediliyor...';

  @override
  String get shareMenuBookmarks => 'Yer İmleri';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    return '$count takip seti mevcut';
  }

  @override
  String get peopleListsAddToList => 'Listeye ekle';

  @override
  String get peopleListsSheetTitle => 'Listeye ekle';

  @override
  String get peopleListsEmptyTitle => 'Henüz liste yok';

  @override
  String get peopleListsEmptySubtitle =>
      'Kişileri gruplamaya başlamak için bir liste oluştur.';

  @override
  String get peopleListsCreateList => 'Liste oluştur';

  @override
  String get peopleListsNewListTitle => 'Yeni liste';

  @override
  String get peopleListsRouteTitle => 'Kişi listesi';

  @override
  String get peopleListsListNameLabel => 'Liste adı';

  @override
  String get peopleListsListNameHint => 'Yakın arkadaşlar';

  @override
  String get peopleListsCreateButton => 'Oluştur';

  @override
  String get peopleListsAddPeopleTitle => 'Kişi ekle';

  @override
  String get peopleListsAddPeopleTooltip => 'Kişi ekle';

  @override
  String get peopleListsAddPeopleSemanticLabel => 'Listeye kişi ekle';

  @override
  String get peopleListsListNotFoundTitle => 'Liste bulunamadı';

  @override
  String get peopleListsListNotFoundSubtitle =>
      'Liste bulunamadı. Silinmiş olabilir.';

  @override
  String get peopleListsListDeletedSubtitle => 'Bu liste silinmiş olabilir.';

  @override
  String get peopleListsNoPeopleTitle => 'Bu listede kişi yok';

  @override
  String get peopleListsNoPeopleSubtitle => 'Başlamak için kişi ekle';

  @override
  String get peopleListsNoVideosTitle => 'Henüz video yok';

  @override
  String get peopleListsNoVideosSubtitle =>
      'Liste üyelerinin videoları burada görünecek';

  @override
  String get peopleListsNoVideosAvailable => 'Kullanılabilir video yok';

  @override
  String get peopleListsFailedToLoadVideos => 'Videolar yüklenemedi';

  @override
  String get peopleListsVideoNotAvailable => 'Video kullanılamıyor';

  @override
  String get peopleListsBackToGridTooltip => 'Izgaraya dön';

  @override
  String get peopleListsErrorLoadingVideos =>
      'Videolar yüklenirken hata oluştu';

  @override
  String get peopleListsNoPeopleToAdd => 'Eklenecek kişi bulunamadı.';

  @override
  String peopleListsAddToListName(String name) {
    return '$name listesine ekle';
  }

  @override
  String get peopleListsAddPeopleSearchHint => 'Kişi ara';

  @override
  String get peopleListsAddPeopleError =>
      'Kişiler yüklenemedi. Lütfen tekrar dene.';

  @override
  String get peopleListsAddPeopleRetry => 'Tekrar dene';

  @override
  String get peopleListsAddButton => 'Ekle';

  @override
  String peopleListsAddButtonWithCount(int count) {
    return '$count ekle';
  }

  @override
  String peopleListsInNLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count listede',
      one: '1 listede',
    );
    return '$_temp0';
  }

  @override
  String peopleListsRemoveConfirmTitle(String name) {
    return '$name kaldırılsın mı?';
  }

  @override
  String get peopleListsRemoveConfirmBody => 'Bu kişi listeden kaldırılacak.';

  @override
  String get peopleListsRemove => 'Kaldır';

  @override
  String peopleListsRemovedFromList(String name) {
    return '$name listeden kaldırıldı';
  }

  @override
  String get peopleListsUndo => 'Geri al';

  @override
  String peopleListsProfileLongPressHint(String name) {
    return '$name profili. Kaldırmak için uzun bas.';
  }

  @override
  String peopleListsViewProfileHint(String name) {
    return '$name profilini görüntüle';
  }

  @override
  String get shareMenuEditVideo => 'Videoyu Düzenle';

  @override
  String get shareMenuDeleteVideo => 'Videoyu Sil';

  @override
  String shareMenuVideoCount(int count) {
    return '$count video';
  }

  @override
  String get shareMenuDeleteConfirmation =>
      'Bu video Divine\'dan kalıcı olarak silinir. Diğer röleleri kullanan üçüncü taraf Nostr istemcilerinde hâlâ görünebilir.';

  @override
  String get shareMenuCancel => 'İptal';

  @override
  String get shareMenuDelete => 'Sil';

  @override
  String get shareMenuDeleteFailedNotInitialized =>
      'Silme henüz hazır değil. Birazdan tekrar dene.';

  @override
  String get shareMenuDeleteFailedNotOwner =>
      'Yalnızca kendi videolarını silebilirsin.';

  @override
  String get shareMenuDeleteFailedNotAuthenticated =>
      'Tekrar giriş yap, sonra silmeyi dene.';

  @override
  String get shareMenuDeleteFailedCouldNotSign =>
      'Silme isteği imzalanamadı. Tekrar dene.';

  @override
  String get shareMenuDeleteFailedRelayRejected =>
      'Röle bu silme isteğini kabul etmedi. Birazdan tekrar dene.';

  @override
  String get shareMenuDeleteFailedAccountRestricted =>
      'Your account is restricted, so this delete request couldn\'t be sent. Contact support for help deleting it.';

  @override
  String get shareMenuDeleteFailedRelayNoResponse =>
      'Röleye ulaşılamadı. Bağlantını kontrol edip tekrar dene.';

  @override
  String get shareMenuDeletePartiallyConfirmed =>
      'Silindi. Tüm relay\'ler onaylamadı, bu yüzden başka uygulamalarda hâlâ görünebilir.';

  @override
  String get shareMenuDeleteFailedGeneric =>
      'Bu video silinemedi. Tekrar dene.';

  @override
  String get shareMenuUpdate => 'Güncelle';

  @override
  String get shareMenuChangeCover => 'Kapağı Değiştir';

  @override
  String get shareMenuVideoUpdated => 'Video başarıyla güncellendi';

  @override
  String shareMenuVideoUpdatedWithInviteFailures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count katılımcı daveti gönderilmedi.',
      one: '1 katılımcı daveti gönderilmedi.',
    );
    return 'Video güncellendi, ancak $_temp0';
  }

  @override
  String get videoUpdateErrorNotAuthenticated =>
      'Tekrar giriş yap, sonra yeniden dene.';

  @override
  String get videoUpdateErrorNoPlayableVideo =>
      'Bu videonun oynatılabilir bir kaynağı yok, bu yüzden düzenlenemiyor.';

  @override
  String get videoUpdateErrorCouldNotSign =>
      'Değişiklik imzalanamadı. Tekrar dene.';

  @override
  String get videoUpdateErrorPublishRejected =>
      'Relay değişikliği kabul etmedi. Birazdan tekrar dene.';

  @override
  String get videoUpdateErrorGeneric => 'Bu video güncellenemedi. Tekrar dene.';

  @override
  String get shareMenuOriginalVideoUnavailable =>
      'Couldn\'t load the original video. Try again in a moment.';

  @override
  String get shareMenuDeleteVideoQuestion => 'Video Silinsin mi?';

  @override
  String get shareMenuDeleteCleanupInProgress => 'Video kaldırılıyor…';

  @override
  String get shareMenuDeleteCleanupConfirmed => 'Video silindi.';

  @override
  String get shareMenuDeleteCleanupDelayed =>
      'Video silindi. Her yerden kaybolması biraz zaman alabilir.';

  @override
  String get shareMenuDeleteCleanupFailed =>
      'Video silindi ancak her kopyayı kaldıramadık. Lütfen destek ekibiyle iletişime geç.';

  @override
  String get authSessionExpired =>
      'Oturumun sona erdi. Lütfen tekrar giriş yap.';

  @override
  String get authAccountRestoreFailed =>
      'We couldn\'t unlock that account on this device. Sign in again.';

  @override
  String get authSignInFailed => 'Giriş başarısız. Lütfen tekrar dene.';

  @override
  String get webAuthNotSupportedSecureMode =>
      'Web kimlik doğrulaması güvenli modda desteklenmiyor. Güvenli anahtar yönetimi için lütfen mobil uygulamayı kullan.';

  @override
  String get webAuthEnterBunkerUri => 'Lütfen bir bunker URI\'si gir';

  @override
  String get webAuthConnectTitle => 'Divine\'a Bağlan';

  @override
  String get webAuthChooseMethod =>
      'Tercih ettiğin Nostr kimlik doğrulama yöntemini seç';

  @override
  String get webAuthBrowserExtension => 'Tarayıcı Uzantısı';

  @override
  String get webAuthRecommended => 'ÖNERİLEN';

  @override
  String get webAuthNsecBunker => 'nsec bunker';

  @override
  String get webAuthConnectRemoteSigner => 'Uzak bir imzalayıcıya bağlan';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => 'Panodan yapıştır';

  @override
  String get webAuthConnectToBunker => 'Bunker\'a Bağlan';

  @override
  String get webAuthNewToNostr => 'Nostr\'da yeni misin?';

  @override
  String get webAuthNostrHelp =>
      'En kolay deneyim için Alby veya nos2x gibi bir tarayıcı uzantısı yükle veya güvenli uzaktan imzalama için nsec bunker kullan.';

  @override
  String get soundsTitle => 'Sesler';

  @override
  String get soundsSearchHint => 'Ses ara...';

  @override
  String get soundsSearchResults => 'Arama Sonuçları';

  @override
  String get soundsNoSoundsFound => 'Hiç ses bulunamadı';

  @override
  String get soundsNoSoundsFoundDescription => 'Farklı bir arama terimi dene';

  @override
  String get soundsSavedToLibrary => 'Seslere kaydedildi';

  @override
  String get soundsAlreadySavedToLibrary => 'Zaten Seslerde';

  @override
  String get soundsSavedLibraryTitle => 'Seslerim';

  @override
  String get soundsSavedEmptyTitle => 'Henüz kaydedilmiş ses yok';

  @override
  String get soundsSavedEmptyDescription =>
      'Bir videoda Sesi Kullan\'a dokunarak burada kaydedin.';

  @override
  String get soundsRemoveSavedSound => 'Sesi kaldır';

  @override
  String get savedSoundSaveAction => 'Kaydet';

  @override
  String get savedSoundPausePreviewAction => 'Önizlemeyi duraklat';

  @override
  String get savedSoundResumePreviewAction => 'Önizlemeye devam et';

  @override
  String get savedSoundDetailsSheetTitle => 'Ses ayrıntıları';

  @override
  String get savedSoundRemoveConfirmTitle => 'Bu ses kaldırılsın mı?';

  @override
  String get savedSoundRemoveConfirmMessage =>
      'Kitaplığından kaybolur, ama onu kullanan herhangi bir videodan tekrar kaydedebilirsin.';

  @override
  String get soundsRemovedFromLibrary => 'Seslerden kaldırıldı';

  @override
  String get soundsSaveFailed => 'O ses kaydedilemedi. Tekrar dene.';

  @override
  String get soundsRemoveFailed => 'O ses kaldırılamadı. Tekrar dene.';

  @override
  String get soundSyncStatusSyncing => 'Sesleriniz eşitleniyor…';

  @override
  String get soundSyncStatusSynced => 'Sesler güncel';

  @override
  String get soundSyncStatusFailed =>
      'Sesleriniz eşitlenemedi. Tekrar deneyeceğiz.';

  @override
  String get soundSyncStatusLocked =>
      'Eşitlenen kitaplığınız bu cihazda açılamıyor.';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileMoreOptions => 'Daha fazla seçenek';

  @override
  String profileBlockedUser(String name) {
    return '$name engellendi';
  }

  @override
  String profileUnblockedUser(String name) {
    return '$name engeli kaldırıldı';
  }

  @override
  String profileUnfollowedUser(String name) {
    return '$name takipten çıkarıldı';
  }

  @override
  String get profileFeedError =>
      'Sunucuya ulaşılamıyor. Bağlantını kontrol edip tekrar dene.';

  @override
  String get profileFeedLoadMoreError =>
      'Daha fazla video yüklenemedi. Yenilemek için aşağı çek.';

  @override
  String get notificationsTabAll => 'Tümü';

  @override
  String get notificationsTabLikes => 'Beğeniler';

  @override
  String get notificationsTabComments => 'Yorumlar';

  @override
  String get notificationsTabFollows => 'Takipler';

  @override
  String get notificationsTabReposts => 'Yeniden Paylaşımlar';

  @override
  String get notificationsFailedToLoad => 'Bildirimler yüklenemedi';

  @override
  String get notificationsRetry => 'Tekrar Dene';

  @override
  String get notificationsRefreshError =>
      'Yenileme başarısız — mevcut olanlar gösteriliyor';

  @override
  String get notificationsUnreadPrefix => 'Okunmamış bildirim';

  @override
  String notificationsBadgeUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count okunmamış bildirim',
      one: '1 okunmamış bildirim',
    );
    return '$_temp0';
  }

  @override
  String notificationsViewProfileSemanticLabel(String displayName) {
    return '$displayName profilini görüntüle';
  }

  @override
  String get notificationsViewProfilesSemanticLabel => 'Profilleri görüntüle';

  @override
  String notificationsVideoThumbnailFor(String title) {
    return '$title için video küçük resmi';
  }

  @override
  String get notificationsVideoThumbnail => 'Video küçük resmi';

  @override
  String get notificationsInviteSingular =>
      'Bir arkadaşınla paylaşacak 1 davetin var!';

  @override
  String notificationsInvitePlural(int count) {
    return 'Arkadaşlarınla paylaşacak $count davetin var!';
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
  String get notificationsVideoUnavailable => 'Video kullanılamıyor';

  @override
  String get feedFailedToLoadVideos => 'Videolar yüklenemedi';

  @override
  String get feedRetry => 'Tekrar Dene';

  @override
  String get feedNoFollowedUsers =>
      'Takip edilen kullanıcı yok.\nVideolarını burada görmek için birini takip et.';

  @override
  String get feedModeForYou => 'Senin için';

  @override
  String get feedModeNew => 'Yeni';

  @override
  String get feedModeFollowing => 'Takip';

  @override
  String get feedModeClassics => 'Klasikler';

  @override
  String feedModeSemanticLabel(String label) {
    return 'Akış modu: $label';
  }

  @override
  String videoAuthorSemanticLabel(String displayName) {
    return 'Video yazarı: $displayName';
  }

  @override
  String get videoAuthorAvatarSemanticLabel => 'Yazar avatarı';

  @override
  String get feedForYouEmpty =>
      'Sana Özel akışın boş.\nVideolar keşfet ve içerik üreticileri takip ederek akışını şekillendir.';

  @override
  String get feedFollowingEmpty =>
      'Takip ettiğin kişilerden henüz video yok.\nBeğendiğin içerik üreticilerini bulup takip et.';

  @override
  String get feedLatestEmpty =>
      'Henüz yeni video yok.\nYakında tekrar kontrol et.';

  @override
  String get feedClassicEmpty =>
      'Henüz klasik yok.\nYakında tekrar kontrol et.';

  @override
  String get feedExploreVideos => 'Videoları Keşfet';

  @override
  String get feedLoadingMore => 'Daha fazla video yükleniyor…';

  @override
  String get feedRefreshed => 'Akış yenilendi';

  @override
  String get uploadUploadingVideo => 'Video yükleniyor';

  @override
  String get postPublishConfirmationTitle => 'Profiline yayınlandı';

  @override
  String get postPublishConfirmationView => 'Görüntüle';

  @override
  String get postPublishConfirmationShare => 'Paylaş';

  @override
  String get postPublishConfirmationThumbnailLabel =>
      'Az önce yayınladığın videonun küçük resmi';

  @override
  String get userSearchNoResults => 'Kullanıcı bulunamadı';

  @override
  String get userPickerFilterByNameHint => 'Ada göre filtrele...';

  @override
  String get userPickerSearchByNameHint => 'Ada göre ara...';

  @override
  String get userPickerClearSearchSemantics => 'Aramayı temizle';

  @override
  String userPickerAlreadyAddedSemantics(String name) {
    return '$name zaten eklendi';
  }

  @override
  String userPickerSelectSemantics(String name) {
    return '$name seç';
  }

  @override
  String userPickerRemoveSelectionSemantics(String name) {
    return '$name kaldır';
  }

  @override
  String get userPickerEmptyFollowListTitle => 'Ekibin dışarıda';

  @override
  String get userPickerEmptyFollowListBody =>
      'Aynı frekansta olduğun kişileri takip et. Onlar da seni takip ettiğinde birlikte üretim yapabilirsiniz.';

  @override
  String get userPickerGoBack => 'Geri dön';

  @override
  String get userPickerTypeNameToSearch => 'Aramak için bir isim yaz';

  @override
  String get userPickerUnavailable =>
      'Kullanıcı araması kullanılamıyor. Lütfen daha sonra tekrar dene.';

  @override
  String get userPickerSearchFailedTryAgain =>
      'Arama başarısız oldu. Lütfen tekrar dene.';

  @override
  String get forgotPasswordTitle => 'Parolayı Sıfırla';

  @override
  String get forgotPasswordDescription =>
      'E-posta adresini gir, parolanı sıfırlamak için sana bir bağlantı gönderelim.';

  @override
  String get forgotPasswordEmailLabel => 'E-posta Adresi';

  @override
  String get forgotPasswordCancel => 'İptal';

  @override
  String get forgotPasswordSendLink => 'Sıfırlama Bağlantısı Gönder';

  @override
  String get ageVerificationContentWarning => 'İçerik Uyarısı';

  @override
  String get ageVerificationTitle => 'Yaş Doğrulama';

  @override
  String get ageVerificationAdultDescription =>
      'Bu içerik potansiyel olarak yetişkin içeriği barındırmak üzere işaretlendi. Görüntülemek için 18 yaş veya üzerinde olmalısın.';

  @override
  String get ageVerificationCreationDescription =>
      'Kamerayı kullanmak ve içerik oluşturmak için en az 16 yaşında olmalısın.';

  @override
  String get ageVerificationAdultQuestion => '18 yaşında veya üzerinde misin?';

  @override
  String get ageVerificationCreationQuestion =>
      '16 yaşında veya üzerinde misin?';

  @override
  String get ageVerificationNo => 'Hayır';

  @override
  String get ageVerificationYes => 'Evet';

  @override
  String get navHome => 'Ana Sayfa';

  @override
  String get navExplore => 'Keşfet';

  @override
  String get navInbox => 'Gelen Kutusu';

  @override
  String get navProfile => 'Profil';

  @override
  String get navMyProfile => 'Profilim';

  @override
  String get navNotifications => 'Bildirimler';

  @override
  String get navOpenCamera => 'Kamerayı aç';

  @override
  String get navExploreClassics => 'Klasikler';

  @override
  String get navExploreNewVideos => 'Yeni Videolar';

  @override
  String get navExploreTrending => 'Trend';

  @override
  String get navExploreForYou => 'Sana Özel';

  @override
  String get navExploreLists => 'Listeler';

  @override
  String get routeErrorTitle => 'Hata';

  @override
  String get routeInvalidHashtag => 'Geçersiz etiket';

  @override
  String get routeInvalidConversationId => 'Geçersiz sohbet kimliği';

  @override
  String get routeInvalidRequestId => 'Geçersiz istek kimliği';

  @override
  String get routeInvalidListId => 'Geçersiz liste kimliği';

  @override
  String get routeInvalidUserId => 'Geçersiz kullanıcı kimliği';

  @override
  String get routeInvalidVideoId => 'Geçersiz video kimliği';

  @override
  String get routeInvalidSoundId => 'Geçersiz ses kimliği';

  @override
  String get routeInvalidCategory => 'Geçersiz kategori';

  @override
  String get routeNoVideosToDisplay => 'Gösterilecek video yok';

  @override
  String get routeGoHome => 'Ana sayfaya git';

  @override
  String get routeInvalidProfileId => 'Geçersiz profil kimliği';

  @override
  String get routeUnknownPath => 'Bu sayfa uygulamada yok.';

  @override
  String get routeDefaultListName => 'Liste';

  @override
  String get supportTitle => 'Destek Merkezi';

  @override
  String get supportContactSupport => 'Destekle İletişime Geç';

  @override
  String get supportContactSupportSubtitle =>
      'Bir sohbet başlat veya geçmiş mesajları gör';

  @override
  String get supportReportBug => 'Hata Bildir';

  @override
  String get supportReportBugSubtitle => 'Uygulamayla ilgili teknik sorunlar';

  @override
  String get supportRequestFeature => 'Özellik İste';

  @override
  String get supportRequestFeatureSubtitle =>
      'Bir iyileştirme veya yeni özellik öner';

  @override
  String get supportSaveLogs => 'Günlükleri Kaydet';

  @override
  String get supportSaveLogsSubtitle =>
      'Manuel göndermek için günlükleri dosyaya aktar';

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
  String get supportFaq => 'SSS';

  @override
  String get supportFaqSubtitle => 'Sık sorulan sorular ve cevapları';

  @override
  String get supportFamily => 'Divine Family';

  @override
  String get supportFamilySubtitle =>
      'Ebeveynlerin ve gençlerin sağlıklı çevrimiçi alışkanlıklar kazanmasına yardımcı oluyoruz';

  @override
  String get supportKids => 'Divine Kids';

  @override
  String get supportKidsSubtitle => 'Hesapları yaşa göre nasıl ele alıyoruz';

  @override
  String get supportProofMode => 'ProofMode';

  @override
  String get supportProofModeSubtitle =>
      'Doğrulama ve gerçeklik hakkında bilgi edin';

  @override
  String get supportLoginRequired => 'Destekle iletişime geçmek için giriş yap';

  @override
  String get supportExportingLogs => 'Günlükler dışa aktarılıyor...';

  @override
  String get supportExportLogsFailed => 'Günlükler dışa aktarılamadı';

  @override
  String get supportNoLogsToExport =>
      'No logs yet — they start fresh each launch. Reproduce the problem, then come back without restarting.';

  @override
  String get supportExportLogsUnconfirmed =>
      'Logs handed off. Check the app you shared to.';

  @override
  String supportLogsSavedTo(String path) {
    return 'Günlükler $path konumuna kaydedildi';
  }

  @override
  String get supportRevealLogsAction => 'Klasörde göster';

  @override
  String get supportChatNotAvailable => 'Destek sohbeti kullanılamıyor';

  @override
  String get supportCouldNotOpenMessages => 'Destek mesajları açılamadı';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return '$pageName açılamadı';
  }

  @override
  String get reportWhyReporting => 'Bu içeriği neden bildiriyorsun?';

  @override
  String get reportPolicyNotice =>
      'Divine, içerik bildirimlerine 24 saat içinde içeriği kaldırarak ve söz konusu içeriği sağlayan kullanıcıyı çıkararak işlem yapar.';

  @override
  String get reportBlockUser => 'Bu kullanıcıyı engelle';

  @override
  String get reportCancel => 'İptal';

  @override
  String get reportSubmit => 'Bildir';

  @override
  String get reportSelectReason =>
      'Lütfen bu içeriği bildirmek için bir sebep seç';

  @override
  String get reportOtherRequiresDetails =>
      '«Diğer»i seçtiğinde lütfen sorunu açıkla';

  @override
  String get reportDetailsRequired => 'Lütfen sorunu açıkla';

  @override
  String get reportDetailsTextOnly =>
      'Yalnızca metin — buraya fotoğraf veya GIF eklenemez.';

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
  String get reportReasonSpam => 'Spam veya İstenmeyen İçerik';

  @override
  String get reportReasonSpamSubtitle => 'İstenmeyen veya tekrarlayan içerik';

  @override
  String get reportReasonHarassment => 'Taciz, Zorbalık veya Tehdit';

  @override
  String get reportReasonHarassmentSubtitle =>
      'Zararlı ve istenmeyen yanıtlar veya bahsetmeler';

  @override
  String get reportReasonViolence => 'Şiddet veya Aşırı İçerik';

  @override
  String get reportReasonViolenceSubtitle =>
      'Şiddet, aşırılıkçı veya zararlı içerik';

  @override
  String get reportReasonSexualContent => 'Cinsel veya Yetişkin İçerik';

  @override
  String get reportReasonSexualContentSubtitle =>
      'Çıplaklık, porno veya müstehcen içerik';

  @override
  String get reportReasonCopyright => 'Telif Hakkı İhlali';

  @override
  String get reportReasonCopyrightSubtitle =>
      'Fikri mülkiyetin izinsiz kullanımı';

  @override
  String get reportReasonFalseInfo => 'Yanlış Bilgi';

  @override
  String get reportReasonFalseInfoSubtitle => 'Yanıltıcı veya yanlış iddialar';

  @override
  String get reportReasonChildSafety => 'Çocuk Güvenliği İhlali';

  @override
  String get reportReasonChildSafetySubtitle =>
      'Reşit olmayanların güvenliğiyle ilgili genel endişeler';

  @override
  String get reportReasonCsam => 'Çocuğa yönelik cinsel istismar';

  @override
  String get reportReasonCsamSubtitle =>
      'Reşit olmayanlara yönelik cinsel istismarı gösteren içerik';

  @override
  String get reportReasonUnderageUser =>
      'Kullanıcı 16 Yaşından Küçük Görünüyor';

  @override
  String get reportReasonUnderageUserSubtitle =>
      'Hesap sahibi reşit değil gibi görünüyor';

  @override
  String get reportReasonAiGenerated => 'Yapay Zeka Üretimi İçerik';

  @override
  String get reportReasonAiGeneratedSubtitle =>
      'Yapay zeka tarafından oluşturulduğundan şüphelenilen içerik';

  @override
  String get reportReasonOther => 'Diğer Politika İhlali';

  @override
  String get reportReasonOtherSubtitle => 'Yukarıda listelenmeyen ihlaller';

  @override
  String get reportFailed => 'İçerik bildirilemedi. Lütfen tekrar dene.';

  @override
  String get reportNotSent =>
      'Bildirimin gönderilemedi. Bağlantını kontrol et ve tekrar dene.';

  @override
  String get reportReceivedTitle => 'Bildirim Alındı';

  @override
  String get reportReceivedThankYou =>
      'Divine\'ı güvenli tutmaya yardımcı olduğun için teşekkürler.';

  @override
  String get reportReceivedReviewNotice =>
      'Ekibimiz bildirimini inceleyecek ve uygun adımı atacak. Direkt mesaj yoluyla güncelleme alabilirsin.';

  @override
  String get reportModerationDmDelayed =>
      'Moderasyon ekibine şu an doğrudan ulaşamadık ama bildirimin alındı ve incelenecek.';

  @override
  String get reportContactModeration => 'Moderasyon ekibine mesaj gönder';

  @override
  String get reportLearnMoreAt => 'Daha fazla bilgi:';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => 'Kapat';

  @override
  String get listAddToList => 'Listeye Ekle';

  @override
  String listVideoCount(int count) {
    return '$count video';
  }

  @override
  String listPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kişi',
      one: '1 kişi',
    );
    return '$_temp0';
  }

  @override
  String get listByAuthorPrefix => 'Yazan ';

  @override
  String get listNewList => 'Yeni Liste';

  @override
  String get listDone => 'Bitti';

  @override
  String get listErrorLoading => 'Listeler yüklenirken hata';

  @override
  String listRemovedFrom(String name) {
    return '$name listesinden kaldırıldı';
  }

  @override
  String listAddedTo(String name) {
    return '$name listesine eklendi';
  }

  @override
  String get listCreateNewList => 'Yeni Liste Oluştur';

  @override
  String get listNewPeopleList => 'Yeni kişi listesi';

  @override
  String get listCollaboratorsNone => 'Yok';

  @override
  String get listAddCollaboratorTitle => 'Ortak ekle';

  @override
  String get listCollaboratorSearchHint => 'Divine\'da ara...';

  @override
  String get listNameLabel => 'Liste Adı';

  @override
  String get listDescriptionLabel => 'Açıklama (opsiyonel)';

  @override
  String get listPublicList => 'Herkese Açık Liste';

  @override
  String get listPublicListSubtitle =>
      'Diğerleri bu listeyi takip edebilir ve görebilir';

  @override
  String get listPrivateListSubtitle =>
      'Videolar gizli kalır. Ad, açıklama, etiketler ve kapak görünür kalır.';

  @override
  String get listVisibilityPublic => 'Herkese açık';

  @override
  String get listVisibilityPrivate => 'Özel';

  @override
  String get profileListsEmpty =>
      'Henüz liste yok. Bir arada tutmak istediğin döngüler için bir tane oluştur.';

  @override
  String get listEditTitle => 'Listeyi düzenle';

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
  String get listShareAction => 'Listeyi paylaş';

  @override
  String get listShareFailed => 'Bu liste paylaşılamadı. Tekrar dene.';

  @override
  String get listSave => 'Kaydet';

  @override
  String get listContinue => 'Devam';

  @override
  String get listPrivateFull =>
      'This private list is full. Remove something to add more.';

  @override
  String get listUpdateFailed => 'Bu liste güncellenemedi. Tekrar dene.';

  @override
  String get listMakePrivateTitle => 'Bu liste özel yapılsın mı?';

  @override
  String get listMakePrivateWarning =>
      'Videolar şifrelenir, böylece onları yalnızca sen görürsün. Ad, açıklama, etiketler ve kapak görünür kalır; daha önce paylaşılan kopyalar kalabilir.';

  @override
  String get listMakePublicTitle => 'Bu liste herkese açık yapılsın mı?';

  @override
  String get listMakePublicWarning =>
      'Bağlantıya sahip herkes bu listeyi ve videolarını görebilir.';

  @override
  String listShareText(String name, String url) {
    return '$name listesine Divine\'da göz at: $url';
  }

  @override
  String listShareSubject(String name) {
    return 'Divine\'da $name';
  }

  @override
  String get listCancel => 'İptal';

  @override
  String get listCreate => 'Oluştur';

  @override
  String get listCreateFailed => 'Liste oluşturulamadı';

  @override
  String get keyManagementTitle => 'Nostr Anahtarları';

  @override
  String get keyManagementWhatAreKeys => 'Nostr anahtarları nedir?';

  @override
  String get keyManagementExplanation =>
      'Nostr kimliğin bir kriptografik anahtar çiftidir:\n\n• Açık anahtarın (npub) kullanıcı adın gibidir - gönül rahatlığıyla paylaş\n• Özel anahtarın (nsec) parolan gibidir - gizli tut!\n\nnsec\'in herhangi bir Nostr uygulamasında hesabına erişmeni sağlar.';

  @override
  String get keyManagementImportTitle => 'Mevcut Anahtarı İçe Aktar';

  @override
  String get keyManagementImportSubtitle =>
      'Zaten bir Nostr hesabın mı var? Özel anahtarını (nsec) yapıştırarak burada eriş.';

  @override
  String get keyManagementImportButton => 'Anahtarı İçe Aktar';

  @override
  String get keyManagementImportWarning => 'Bu mevcut anahtarını değiştirecek!';

  @override
  String get keyManagementBackupTitle => 'Anahtarını Yedekle';

  @override
  String get keyManagementBackupSubtitle =>
      'Hesabını diğer Nostr uygulamalarında kullanmak için özel anahtarını (nsec) kaydet.';

  @override
  String get keyManagementCopyNsec => 'Özel Anahtarımı (nsec) Kopyala';

  @override
  String get keyManagementNeverShare => 'nsec\'ini asla kimseyle paylaşma!';

  @override
  String get keyManagementKeycastRemoteSigning =>
      'Anahtarın bu cihazda değil, Divine\'ın giriş servisinde tutuluyor. Şifreni onayla, biz de anahtarı getirelim.';

  @override
  String get keyManagementKeycastPasswordPrompt =>
      'Anahtarın Divine\'ın giriş servisinde tutuluyor. Hesap şifreni gir, biz de getirelim.';

  @override
  String get keyManagementKeycastCopyKey => 'Anahtarı kopyala';

  @override
  String get keyManagementKeycastCopyBlocked =>
      'Cihazın kopyalamayı engelledi, bu yüzden anahtarın panoya ulaşmadı.';

  @override
  String get keyManagementKeycastWrongPassword =>
      'Şifre eşleşmiyor. Tekrar dene.';

  @override
  String get keyManagementKeycastTooManyAttempts =>
      'Çok fazla deneme oldu. Bunu kapat ve baştan başla.';

  @override
  String get keyManagementKeycastRateLimited =>
      'Çok fazla anahtar isteği oldu. Birkaç dakika bekleyip tekrar dene.';

  @override
  String get keyManagementKeycastSignInAgain =>
      'Oturumun sona erdi. Anahtarını kopyalamak için tekrar giriş yap.';

  @override
  String get keyManagementKeycastEmailUnverified =>
      'Anahtarını kopyalamadan önce e-posta adresini doğrula.';

  @override
  String get keyManagementKeycastDenied =>
      'Bu hesabın anahtarlarını Divine yönetiyor, bu yüzden burada kopyalanamaz.';

  @override
  String get keyManagementKeycastNoKey =>
      'Bu hesap için kayıtlı bir anahtar yok.';

  @override
  String get keyManagementKeycastGenericFailure =>
      'Giriş servisine ulaşılamadı. Lütfen tekrar dene.';

  @override
  String get keyManagementRestrictedTitle =>
      'Anahtarların Divine tarafından yönetiliyor';

  @override
  String get keyManagementRestrictedBody =>
      'Hesabını güvende tutmak için anahtar yedekleme ve farklı bir anahtar içe aktarma burada kullanılamıyor.';

  @override
  String get keyManagementPasteKey => 'Lütfen özel anahtarını yapıştır';

  @override
  String get keyManagementInvalidFormat =>
      'Geçersiz anahtar formatı. \"nsec1\" ile başlamalı';

  @override
  String get keyManagementConfirmImportTitle => 'Bu Anahtar İçe Aktarılsın mı?';

  @override
  String get keyManagementConfirmImportBody =>
      'Bu mevcut kimliğini içe aktarılan kimlikle değiştirecek.\n\nÖnce yedeklemediysen mevcut anahtarın kaybolacak.';

  @override
  String get keyManagementImportConfirm => 'İçe Aktar';

  @override
  String get keyManagementImportSuccess => 'Anahtar başarıyla içe aktarıldı!';

  @override
  String get keyManagementImportFailed =>
      'Anahtar içe aktarılamadı. Lütfen tekrar dene.';

  @override
  String get keyManagementExportSuccess =>
      'Özel anahtar panoya kopyalandı!\n\nGüvenli bir yerde sakla.';

  @override
  String get keyManagementExportFailed =>
      'Anahtar dışa aktarılamadı. Lütfen tekrar dene.';

  @override
  String get keyManagementYourPublicKeyLabel => 'Açık anahtarın (npub)';

  @override
  String get keyManagementCopyPublicKeyTooltip => 'Açık anahtarı kopyala';

  @override
  String get keyManagementPublicKeyCopied => 'Açık anahtar kopyalandı';

  @override
  String get saveOriginalSavedToCameraRoll => 'Kamera Rulosuna Kaydedildi';

  @override
  String get saveOriginalShare => 'Paylaş';

  @override
  String get saveOriginalDone => 'Bitti';

  @override
  String get saveOriginalPhotosAccessNeeded => 'Fotoğraf Erişimi Gerekiyor';

  @override
  String get saveOriginalPhotosAccessMessage =>
      'Videoları kaydetmek için Ayarlar\'dan Fotoğraf erişimine izin ver.';

  @override
  String get saveOriginalOpenSettings => 'Ayarları Aç';

  @override
  String get saveOriginalNotNow => 'Şimdi Değil';

  @override
  String get saveOriginalDownloadFailed => 'İndirme Başarısız';

  @override
  String get saveOriginalDismiss => 'Kapat';

  @override
  String get saveOriginalDownloadingVideo => 'Video İndiriliyor';

  @override
  String get saveOriginalSavingToCameraRoll => 'Kamera Rulosuna Kaydediliyor';

  @override
  String get saveOriginalFetchingVideo => 'Video ağdan alınıyor...';

  @override
  String get saveOriginalSavingVideo =>
      'Orijinal video kamera rulosuna kaydediliyor...';

  @override
  String get soundTitle => 'Ses';

  @override
  String get soundOriginalSound => 'Orijinal ses';

  @override
  String get soundVideosUsingThisSound => 'Bu sesi kullanan videolar';

  @override
  String get soundSourceVideo => 'Kaynak video';

  @override
  String get soundNoVideosYet => 'Henüz video yok';

  @override
  String get soundBeFirstToUse => 'Bu sesi kullanan ilk kişi ol!';

  @override
  String get soundFailedToLoadVideos => 'Videolar yüklenemedi';

  @override
  String get soundRetry => 'Tekrar Dene';

  @override
  String get soundVideosUnavailable => 'Videolar kullanılamıyor';

  @override
  String get soundCouldNotLoadDetails => 'Video ayrıntıları yüklenemedi';

  @override
  String get soundPreview => 'Önizleme';

  @override
  String get soundStop => 'Durdur';

  @override
  String get soundUseSound => 'Sesi Kullan';

  @override
  String get soundUntitled => 'Adsız ses';

  @override
  String get soundStopPreview => 'Ön izlemeyi durdur';

  @override
  String soundPreviewSemanticLabel(String title) {
    return '$title ön izle';
  }

  @override
  String soundViewDetailsSemanticLabel(String title) {
    return '$title detaylarını görüntüle';
  }

  @override
  String get soundNoVideoCount => 'Henüz video yok';

  @override
  String get soundOneVideo => '1 video';

  @override
  String soundVideoCount(int count) {
    return '$count video';
  }

  @override
  String get soundUnableToPreview => 'Ses önizlenemiyor - ses mevcut değil';

  @override
  String get soundPreviewFailed => 'Önizleme oynatılamadı. Lütfen tekrar dene.';

  @override
  String get soundViewSource => 'Kaynağı gör';

  @override
  String get soundCloseTooltip => 'Kapat';

  @override
  String get exploreNotExploreRoute => 'Keşif rotası değil';

  @override
  String get legalTitle => 'Yasal';

  @override
  String get legalTermsOfService => 'Hizmet Şartları';

  @override
  String get legalTermsOfServiceSubtitle => 'Kullanım şartları ve koşulları';

  @override
  String get legalPrivacyPolicy => 'Gizlilik Politikası';

  @override
  String get legalPrivacyPolicySubtitle => 'Verilerini nasıl ele alıyoruz';

  @override
  String get legalSafetyStandards => 'Güvenlik Standartları';

  @override
  String get legalSafetyStandardsSubtitle => 'Topluluk kuralları ve güvenlik';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle => 'Telif hakkı ve kaldırma politikası';

  @override
  String get legalOpenSourceLicenses => 'Açık Kaynak Lisansları';

  @override
  String get legalOpenSourceLicensesSubtitle => 'Üçüncü taraf paket atıfları';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return '$pageName açılamadı';
  }

  @override
  String get categoryAction => 'Aksiyon';

  @override
  String get categoryAdventure => 'Macera';

  @override
  String get categoryAnimals => 'Hayvanlar';

  @override
  String get categoryAnimation => 'Animasyon';

  @override
  String get categoryArchitecture => 'Mimari';

  @override
  String get categoryArt => 'Sanat';

  @override
  String get categoryAutomotive => 'Otomotiv';

  @override
  String get categoryAwardShow => 'Ödül Töreni';

  @override
  String get categoryAwards => 'Ödüller';

  @override
  String get categoryBaseball => 'Beyzbol';

  @override
  String get categoryBasketball => 'Basketbol';

  @override
  String get categoryBeauty => 'Güzellik';

  @override
  String get categoryBeverage => 'İçecek';

  @override
  String get categoryCars => 'Arabalar';

  @override
  String get categoryCelebration => 'Kutlama';

  @override
  String get categoryCelebrities => 'Ünlüler';

  @override
  String get categoryCelebrity => 'Ünlü';

  @override
  String get categoryCityscape => 'Şehir Manzarası';

  @override
  String get categoryComedy => 'Komedi';

  @override
  String get categoryConcert => 'Konser';

  @override
  String get categoryCooking => 'Yemek Pişirme';

  @override
  String get categoryCostume => 'Kostüm';

  @override
  String get categoryCrafts => 'El Sanatları';

  @override
  String get categoryCrime => 'Suç';

  @override
  String get categoryCulture => 'Kültür';

  @override
  String get categoryDance => 'Dans';

  @override
  String get categoryDiy => 'Kendin Yap';

  @override
  String get categoryDrama => 'Dram';

  @override
  String get categoryEducation => 'Eğitim';

  @override
  String get categoryEmotional => 'Duygusal';

  @override
  String get categoryEmotions => 'Duygular';

  @override
  String get categoryEntertainment => 'Eğlence';

  @override
  String get categoryEvent => 'Etkinlik';

  @override
  String get categoryFamily => 'Aile';

  @override
  String get categoryFans => 'Hayranlar';

  @override
  String get categoryFantasy => 'Fantastik';

  @override
  String get categoryFashion => 'Moda';

  @override
  String get categoryFestival => 'Festival';

  @override
  String get categoryFilm => 'Film';

  @override
  String get categoryFitness => 'Fitness';

  @override
  String get categoryFood => 'Yemek';

  @override
  String get categoryFootball => 'Amerikan Futbolu';

  @override
  String get categoryFurniture => 'Mobilya';

  @override
  String get categoryGaming => 'Oyun';

  @override
  String get categoryGolf => 'Golf';

  @override
  String get categoryGrooming => 'Bakım';

  @override
  String get categoryGuitar => 'Gitar';

  @override
  String get categoryHalloween => 'Cadılar Bayramı';

  @override
  String get categoryHealth => 'Sağlık';

  @override
  String get categoryHockey => 'Hokey';

  @override
  String get categoryHoliday => 'Tatil';

  @override
  String get categoryHome => 'Ev';

  @override
  String get categoryHomeImprovement => 'Ev Tadilatı';

  @override
  String get categoryHorror => 'Korku';

  @override
  String get categoryHospital => 'Hastane';

  @override
  String get categoryHumor => 'Mizah';

  @override
  String get categoryInteriorDesign => 'İç Tasarım';

  @override
  String get categoryInterview => 'Röportaj';

  @override
  String get categoryKids => 'Çocuklar';

  @override
  String get categoryLifestyle => 'Yaşam Tarzı';

  @override
  String get categoryMagic => 'Sihir';

  @override
  String get categoryMakeup => 'Makyaj';

  @override
  String get categoryMedical => 'Tıbbi';

  @override
  String get categoryMusic => 'Müzik';

  @override
  String get categoryMystery => 'Gizem';

  @override
  String get categoryNature => 'Doğa';

  @override
  String get categoryNews => 'Haberler';

  @override
  String get categoryOutdoor => 'Açık Hava';

  @override
  String get categoryParty => 'Parti';

  @override
  String get categoryPeople => 'İnsanlar';

  @override
  String get categoryPerformance => 'Performans';

  @override
  String get categoryPets => 'Evcil Hayvanlar';

  @override
  String get categoryPolitics => 'Siyaset';

  @override
  String get categoryPrank => 'Şaka';

  @override
  String get categoryPranks => 'Şakalar';

  @override
  String get categoryRealityShow => 'Reality Şov';

  @override
  String get categoryRelationship => 'İlişki';

  @override
  String get categoryRelationships => 'İlişkiler';

  @override
  String get categoryRomance => 'Romantik';

  @override
  String get categorySchool => 'Okul';

  @override
  String get categoryScienceFiction => 'Bilim Kurgu';

  @override
  String get categorySelfie => 'Selfie';

  @override
  String get categoryShopping => 'Alışveriş';

  @override
  String get categorySkateboarding => 'Kaykay';

  @override
  String get categorySkincare => 'Cilt Bakımı';

  @override
  String get categorySoccer => 'Futbol';

  @override
  String get categorySocialGathering => 'Sosyal Toplantı';

  @override
  String get categorySocialMedia => 'Sosyal Medya';

  @override
  String get categorySports => 'Spor';

  @override
  String get categoryTalkShow => 'Talk Şov';

  @override
  String get categoryTech => 'Tek';

  @override
  String get categoryTechnology => 'Teknoloji';

  @override
  String get categoryTelevision => 'Televizyon';

  @override
  String get categoryToys => 'Oyuncaklar';

  @override
  String get categoryTransportation => 'Ulaşım';

  @override
  String get categoryTravel => 'Seyahat';

  @override
  String get categoryUrban => 'Şehir';

  @override
  String get categoryViolence => 'Şiddet';

  @override
  String get categoryVlog => 'Vlog';

  @override
  String get categoryVlogging => 'Vlog';

  @override
  String get categoryWrestling => 'Güreş';

  @override
  String get profileSetupUploadStaged =>
      'Yüklendi — uygulamak için Kaydet\'e dokunun';

  @override
  String inboxReportedUser(String displayName) {
    return '$displayName bildirildi';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return '$displayName engellendi';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return '$displayName engeli kaldırıldı';
  }

  @override
  String get inboxRemovedConversation => 'Sohbet kaldırıldı';

  @override
  String get inboxRestorePausedTitle => 'Bazı sohbetler tam geri yüklenmedi';

  @override
  String get conversationRestorePausedTitle => 'Bu sohbet tam geri yüklenmedi';

  @override
  String get inboxRestoreRetryAction => 'Yeniden dene';

  @override
  String get inboxRestoringMessages => 'Mesajların geri yükleniyor…';

  @override
  String get inboxEmptyTitle => 'Henüz mesaj yok';

  @override
  String get inboxEmptySubtitle => '+ tuşu ısırmaz.';

  @override
  String get inboxLoadErrorTitle => 'Mesajlar yüklenemedi';

  @override
  String get inboxLoadErrorSubtitle => 'Bağlantını kontrol edip tekrar dene.';

  @override
  String get inboxFilterAll => 'Tümü';

  @override
  String get inboxFilterUnread => 'Okunmamış';

  @override
  String get dmBlockedThreadTitle => 'Bu hesabı engelledin';

  @override
  String get dmBlockedThreadBody =>
      'Mesajlar burada kalır, böylece okuyabilir veya ekran görüntüsü alabilirsin. Yanıtlamak için engeli kaldır.';

  @override
  String get inboxFilterBlocked => 'Engellenenler';

  @override
  String get inboxBlockedEmptyTitle => 'Engellenmiş sohbet yok';

  @override
  String get inboxBlockedEmptySubtitle =>
      'Engellediğin hesaplar burada görünür.';

  @override
  String get inboxBlockedNoMessages => 'Mesaj yok';

  @override
  String get inboxUnreadEmptyTitle => 'Her şeyi okudun';

  @override
  String get inboxUnreadEmptySubtitle => 'Şu anda okunmamış mesaj yok.';

  @override
  String get inboxSearchHint => 'Mesajlarda ara';

  @override
  String get inboxSupportRowTitle => 'Divine Moderasyonu';

  @override
  String get inboxSupportRowSubtitle =>
      'Hatalar, moderasyon, hesap meseleleri — dinliyoruz.';

  @override
  String get inboxSearchEmptyTitle => 'Sonuç yok';

  @override
  String get inboxSearchEmptySubtitle => 'Başka bir isim veya kelime dene.';

  @override
  String get inboxActionMute => 'Sohbeti sessize al';

  @override
  String inboxActionReport(String displayName) {
    return '$displayName kullanıcısını bildir';
  }

  @override
  String inboxActionBlock(String displayName) {
    return '$displayName kullanıcısını engelle';
  }

  @override
  String inboxActionUnblock(String displayName) {
    return '$displayName kullanıcısının engelini kaldır';
  }

  @override
  String get inboxActionRemove => 'Sohbeti kaldır';

  @override
  String get inboxRemoveConfirmTitle => 'Sohbet kaldırılsın mı?';

  @override
  String inboxRemoveConfirmBody(String displayName) {
    return 'Bu, $displayName ile olan sohbetini gelen kutundan kaldırır. Sana tekrar yazarsa yeni bir sohbet başlar.';
  }

  @override
  String get inboxRemoveConfirmBodyGroup =>
      'Bu, grup sohbetini gelen kutundan kaldırır. Biri gruba tekrar yazarsa yeni bir sohbet başlar.';

  @override
  String get inboxRemoveConfirmConfirm => 'Kaldır';

  @override
  String get inboxConversationMuted => 'Sohbet sessize alındı';

  @override
  String get inboxConversationUnmuted => 'Sohbet sessizden çıkarıldı';

  @override
  String get inboxCollabInviteCardTitle => 'İşbirliği daveti';

  @override
  String get inboxCollabInviteCardUntitledVideo => 'Başlıksız video';

  @override
  String get clickableTextViewVideoLink => 'Videoyu görüntüle';

  @override
  String get messageExternalLinkDialogTitle => 'Harici bağlantı açılsın mı?';

  @override
  String messageExternalLinkDialogBody(String url) {
    return 'Bu bağlantı harici bir siteye gidiyor ve güvenli olmayabilir:\n\n$url';
  }

  @override
  String get messageExternalLinkDialogOpen => 'Aç';

  @override
  String get inboxCollabInviteCoPostButton => 'Birlikte paylaş';

  @override
  String get inboxCollabInviteNotMineButton => 'Benim değil';

  @override
  String get inboxCollabInvitePreviewTitle => 'Birlikte paylaşma daveti';

  @override
  String inboxCollabInvitePreviewTitleFrom(String displayName) {
    return '$displayName tarafından birlikte paylaşma daveti';
  }

  @override
  String get inboxCollabInviteTimelineConsequence =>
      'Birlikte paylaşmak bu videoyu iş birliği olarak zaman çizelgene ekler.';

  @override
  String get inboxCollabInviteAcceptedStatus => 'Kabul edildi';

  @override
  String get inboxCollabInviteIgnoredStatus => 'Yoksayıldı';

  @override
  String get inboxCollabInviteAcceptError => 'Kabul edilemedi. Tekrar dene.';

  @override
  String get inboxCollabInviteSentStatus => 'Davet gönderildi';

  @override
  String get inboxConversationCollabInvitePreview => 'İşbirliği daveti';

  @override
  String collaboratorInviteDmBody(String title, String url) {
    return '$title üzerinde işbirliği yapmaya davet edildin: $url\n\nOpen Divine to review and accept.';
  }

  @override
  String collaboratorInviteDmBodyUntitled(String url) {
    return 'Bir videoda işbirliği yapmaya davet edildin: $url\n\nOpen Divine to review and accept.';
  }

  @override
  String videoPublishCollaboratorInviteWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count iş birlikçi daveti gönderilemedi.',
      one: '1 iş birlikçi daveti gönderilemedi.',
    );
    return 'Video paylaşıldı ama $_temp0';
  }

  @override
  String get dmSendNoRecipientMessage =>
      'Bu sohbetin kiminle olduğunu anlayamadık. Gelen kutundan tekrar aç.';

  @override
  String get dmSendBlockedMessage =>
      'Yalnızca resmi Divine hesaplarına mesaj gönderebilirsin';

  @override
  String get dmSendBlockedRetiredMessage =>
      'Bu sohbeti kimse okumuyor. Bunun yerine Divine Moderation\'a yazın.';

  @override
  String get dmDeletePendingLabel => 'Deleting for everyone';

  @override
  String get dmDeleteRefusedMessage => 'Herkesten silinemedi.';

  @override
  String get dmDeleteRefusedDetails => 'Bazı kişiler bu mesajı hâlâ görebilir.';

  @override
  String get dmRetiredThreadClosedTitle => 'Bu sohbet kapatıldı.';

  @override
  String get messageRequestModerationNoticeCannotBeRemoved =>
      'Bu Divine Moderation bildirimi kaldırılamaz.';

  @override
  String get dmRetiredThreadClosedBody =>
      'Divine Moderation\'ı yeni bir hesaba taşıdık. Bu hesabı artık kimse okumuyor.';

  @override
  String get dmRetiredThreadOpenSupport => 'Divine Moderation\'a mesaj gönder';

  @override
  String get dmSendTooLongMessage =>
      'That message is too long to send. Shorten it and try again.';

  @override
  String get dmSendFailedMessage => 'Mesaj gönderilemedi';

  @override
  String get dmResendFailedMessage => 'Yine gönderilemedi';

  @override
  String get dmSendFailedSubtitle =>
      'Şimdi tekrar gönder ya da denemeyi durdur.';

  @override
  String get dmSendFailedRetry => 'Tekrar Dene';

  @override
  String get dmSendPartialMessage =>
      'Gönderildi, ama diğer cihazlarınla eşitlenmedi';

  @override
  String get dmConversationLoadError => 'Mesajlar yüklenemedi';

  @override
  String get dmMessageInputHint => 'Bir şeyler yaz…';

  @override
  String get dmMessageBubbleSentHint => 'Gönderilen mesaj';

  @override
  String get dmMessageBubbleReceivedHint => 'Alınan mesaj';

  @override
  String get dmMessageBubbleLongPressHint => 'Mesaj işlemleri';

  @override
  String get dmMessageBubbleFailedTapHint =>
      'Bu mesajı yeniden gönder veya sil';

  @override
  String get dmMessageActionCopyText => 'Metni kopyala';

  @override
  String get dmMessageActionCopyVideoUrl => 'Video URL\'sini kopyala';

  @override
  String get dmMessageActionDeleteForEveryone => 'Herkes için sil';

  @override
  String get dmMessageActionReport => 'Bildir';

  @override
  String get dmMessageActionRetrySend => 'Yeniden gönder';

  @override
  String get dmMessageActionCancelSend => 'Denemeyi durdur';

  @override
  String get dmReactionAddCustomA11yLabel => 'Özel emoji tepkisi ekle';

  @override
  String dmReelReplyComposerHint(String name) {
    return '$name kişisine mesaj…';
  }

  @override
  String get dmReelReplyComposerHintSelf => 'Kendine yanıt ver…';

  @override
  String get dmReelReplyComposerSemanticLabel => 'Bu reel\'e yanıt ver';

  @override
  String get dmReelReplyViewChat => 'Sohbeti gör';

  @override
  String get dmReelReplySentAnnouncement => 'Yanıt gönderildi';

  @override
  String dmReelReactionSentAnnouncement(String emoji) {
    return '$emoji ile tepki verildi';
  }

  @override
  String get dmReelReplyFailed => 'Gönderilemedi';

  @override
  String get dmReelReplyUnverified => 'Gönderim doğrulanamadı';

  @override
  String dmReactionChipOwnA11yLabel(String emoji) {
    return 'Senin tepkin: $emoji';
  }

  @override
  String dmReactionChipOtherA11yLabel(String name, String emoji) {
    return '$name $emoji ile tepki verdi';
  }

  @override
  String dmReactionChipPendingA11yLabel(String emoji) {
    return 'Tepki gönderiliyor: $emoji';
  }

  @override
  String get dmReactionChipFailedA11yLabel =>
      'Tepki başarısız, tekrar denemek için çift dokun';

  @override
  String get dmReactionChipRetryAnnouncement => 'Tepki yeniden deneniyor';

  @override
  String dmReactionRemovalRefusedA11yLabel(String emoji) {
    return 'Couldn\'t remove your $emoji reaction. Double tap to try again';
  }

  @override
  String get dmReactionRemovalRefusedTitle => 'Couldn\'t remove your reaction.';

  @override
  String get dmReactionAddBlockedByRemoval =>
      'Başka bir tepki eklemeden önce önceki tepkinizi kaldırmayı tamamlayın.';

  @override
  String get dmReactionRemovalRefusedDetails =>
      'Some people may still be able to see this reaction.';

  @override
  String get dmReactionsSheetTitle => 'Tepkiler';

  @override
  String get dmReactionsViewA11yLabel => 'Kimlerin tepki verdiğini gör';

  @override
  String get dmReactionRemoveAction => 'Kaldır';

  @override
  String get dmReactionRetryAction => 'Yeniden dene';

  @override
  String get dmFormatBold => 'Kalın';

  @override
  String get dmFormatItalic => 'İtalik';

  @override
  String get dmFormatStrikethrough => 'Üstü çizili';

  @override
  String get dmFormatCode => 'Kod';

  @override
  String get dmStatusFailed => 'Gönderilemedi';

  @override
  String get inboxConversationActionsSheetLabel => 'Sohbet işlemleri';

  @override
  String inboxConversationTileLabel(String displayName) {
    return '$displayName ile sohbet';
  }

  @override
  String inboxConversationTileLabelUnread(String displayName) {
    return 'Okunmamış, $displayName ile sohbet';
  }

  @override
  String inboxGroupConversationTitle(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kişi daha',
    );
    return '$name ve $_temp0';
  }

  @override
  String get inboxConversationTileLongPressHint => 'Sohbet işlemlerini göster';

  @override
  String exploreVideoId(String id) {
    return 'ID: $id';
  }

  @override
  String exploreVideoTitle(String title) {
    return 'Başlık: $title';
  }

  @override
  String exploreVideoCounter(int current, int total) {
    return 'Video $current/$total';
  }

  @override
  String get exploreSearchHint => 'Ara...';

  @override
  String categoryVideoCount(int countValue, String count) {
    return '$count video';
  }

  @override
  String get discoverListsFailedToUpdateSubscription =>
      'Abonelik güncellenemedi. Lütfen tekrar dene.';

  @override
  String get discoverListsTitle => 'Listeleri Keşfet';

  @override
  String get discoverListsFailedToLoad => 'Listeler yüklenemedi';

  @override
  String get discoverListsLoading => 'Herkese açık listeler keşfediliyor...';

  @override
  String get discoverListsRelayTimeout =>
      'Relay listeleri zamanında döndürmedi. Tekrar dene.';

  @override
  String get discoverListsServiceUnavailable => 'Hizmet kullanılamıyor.';

  @override
  String get discoverListsEmptyTitle => 'Herkese açık liste bulunamadı';

  @override
  String get discoverListsEmptySubtitle =>
      'Yeni listeler için sonra tekrar bak';

  @override
  String get discoverListsByAuthorPrefix => 'yazan';

  @override
  String get curatedListEmptyTitle => 'Bu listede video yok';

  @override
  String get curatedListEmptySubtitle => 'Başlamak için birkaç video ekle';

  @override
  String get curatedListLoadingVideos => 'Videolar yükleniyor...';

  @override
  String get curatedListFailedToLoad => 'Liste yüklenemedi';

  @override
  String get curatedListVideoNotAvailable => 'Video mevcut değil';

  @override
  String get curatedListActionsTooltip => 'Liste işlemleri';

  @override
  String get curatedListDeleteConfirmTitle => 'Liste silinsin mi?';

  @override
  String get curatedListDeleteConfirmBody =>
      'Bu, listeyi rölelerden kaldırır. Listedeki videolar silinmez.';

  @override
  String get curatedListDeletedSnack => 'Liste silindi';

  @override
  String get curatedListDeleteFailed => 'Liste silinemedi';

  @override
  String get peopleListsActionsTooltip => 'Liste işlemleri';

  @override
  String get listDeleteAction => 'Listeyi sil';

  @override
  String get peopleListsDeleteConfirmTitle => 'Liste silinsin mi?';

  @override
  String get peopleListsDeleteConfirmBody =>
      'Bu, listeyi herkes için kaldırır. Listedeki kişiler takipten çıkarılmaz.';

  @override
  String get peopleListsDeleteFailed => 'Liste silinemedi';

  @override
  String get commonRetry => 'Tekrar dene';

  @override
  String get commonSomethingWentWrong => 'Bir hata oluştu';

  @override
  String get commonDelete => 'Sil';

  @override
  String get commonCancel => 'İptal';

  @override
  String get commonBack => 'Geri';

  @override
  String get commonClose => 'Kapat';

  @override
  String get commonNotNow => 'Şimdi Değil';

  @override
  String get commonLoading => 'Yükleniyor';

  @override
  String get videoMetadataEditCoverFailedSnackbar =>
      'Kapak güncellenemedi. Tekrar dene.';

  @override
  String get videoMetadataEditCoverSuccessAnnouncement => 'Kapak güncellendi';

  @override
  String get videoMetadataC2paMissingTitle =>
      'Gerçeklik doğrulaması olmadan paylaşılsın mı?';

  @override
  String get videoMetadataC2paMissingBody =>
      'İçerik kimlik bilgilerini ekleyemedik, bu nedenle bu video insan yapımı olarak doğrulanmayacak. Yeniden denemek için yeniden oluştur ya da olduğu gibi paylaş.';

  @override
  String get videoMetadataC2paMissingNote =>
      'İçerik kimlik bilgileri internet bağlantısı gerektirir.';

  @override
  String get videoMetadataC2paMissingNoteServiceUnavailable =>
      'İçerik kimlik bilgisi servisi yanıt vermedi. Sorun senin bağlantında değil.';

  @override
  String get videoMetadataC2paMissingRegenerate => 'Yeniden oluştur';

  @override
  String get videoMetadataC2paMissingSkip => 'Atla';

  @override
  String get videoMetadataGenerationFailed => 'Oluşturma başarısız';

  @override
  String get videoMetadataTags => 'Etiketler';

  @override
  String get videoMetadataExpiration => 'Son Kullanma';

  @override
  String get videoMetadataExpirationNotExpire => 'Süresi dolmaz';

  @override
  String get videoMetadataExpirationOneDay => '1 gün';

  @override
  String get videoMetadataExpirationOneWeek => '1 hafta';

  @override
  String get videoMetadataExpirationOneMonth => '1 ay';

  @override
  String get videoMetadataExpirationOneYear => '1 yıl';

  @override
  String get videoMetadataExpirationOneDecade => '1 on yıl';

  @override
  String get videoMetadataContentWarnings => 'İçerik Uyarıları';

  @override
  String get videoEditorStickers => 'Çıkartmalar';

  @override
  String get trendingTitle => 'Gündemde';

  @override
  String get libraryDeleteConfirm => 'Sil';

  @override
  String get libraryWebUnavailableHeadline => 'Kitaplık mobil uygulamada';

  @override
  String get libraryWebUnavailableDescription =>
      'Taslaklar ve klipler cihazında saklanır; yönetmek için Divine’ı telefonda aç.';

  @override
  String get libraryTabDrafts => 'Taslaklar';

  @override
  String get libraryTabClips => 'Klipler';

  @override
  String get libraryDeleteSelectedClipsTooltip => 'Seçili klipleri sil';

  @override
  String get libraryCloseSemanticLabel => 'Kitaplığı kapat';

  @override
  String get libraryStopSelectingClipsSemanticLabel => 'Klip seçimini bitir';

  @override
  String get librarySelectClipsSemanticLabel => 'Klip seç';

  @override
  String get libraryGridSizeLabel => 'Izgara boyutu';

  @override
  String get libraryDisplayOptionsLabel => 'Sıralama ve ızgara boyutu';

  @override
  String get libraryMoreActionsSemanticLabel => 'Diğer kütüphane işlemleri';

  @override
  String libraryGridSizeColumns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sütun',
    );
    return '$_temp0';
  }

  @override
  String get librarySelect => 'Seç';

  @override
  String get librarySortNewestCreation => 'En yeni oluşturulan';

  @override
  String get librarySortOldestCreation => 'En eski oluşturulan';

  @override
  String get librarySortLongestClip => 'En uzun klip';

  @override
  String get librarySortShortestClip => 'En kısa klip';

  @override
  String get librarySortSquareFirst => 'Önce kare';

  @override
  String get librarySortVerticalFirst => 'Önce dikey';

  @override
  String get libraryDeleteClipsWarning =>
      'Geri alınamaz. Video dosyaları cihazından kalıcı olarak silinir.';

  @override
  String get libraryPreparingVideo => 'Video hazırlanıyor...';

  @override
  String libraryCreateVideo(int count) {
    return 'Video oluştur ($count)';
  }

  @override
  String libraryClipsSavedToDestination(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klip',
      one: '1 klip',
    );
    return '$_temp0 $destination konumuna kaydedildi';
  }

  @override
  String libraryClipsSavePartialResult(int successCount, int failureCount) {
    return '$successCount kaydedildi, $failureCount başarısız';
  }

  @override
  String libraryClipsSaveFailed(String destination) {
    return '$destination konumuna kaydedilemedi';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return '$destination izni reddedildi';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klip silindi',
      one: '1 klip silindi',
    );
    return '$_temp0';
  }

  @override
  String get libraryClipsDeletedUndoLabel => 'Geri al';

  @override
  String libraryTrashAutoDeletes(int daysLeft) {
    String _temp0 = intl.Intl.pluralLogic(
      daysLeft,
      locale: localeName,
      other: '$daysLeft gün içinde otomatik olarak silinir',
      one: 'Yarın otomatik olarak silinir',
      zero: 'Bugün otomatik olarak silinir',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts => 'Taslaklar yüklenemedi';

  @override
  String get libraryCouldNotLoadClips => 'Klipler yüklenemedi';

  @override
  String get libraryOpenErrorDescription =>
      'Kitaplık açılırken bir sorun oldu. Tekrar deneyebilirsin.';

  @override
  String get libraryNoDraftsYetTitle => 'Henüz taslak yok';

  @override
  String get libraryNoDraftsYetSubtitle =>
      'Taslak olarak kaydettiğin videolar burada görünür';

  @override
  String get libraryNoClipsYetTitle => 'Henüz klip yok';

  @override
  String get libraryNoClipsYetSubtitle => 'Kaydettiğin videolar burada görünür';

  @override
  String get libraryDraftDeletedSnackbar => 'Taslak silindi';

  @override
  String get libraryDraftDeleteFailedSnackbar => 'Taslak silinemedi';

  @override
  String get libraryDraftDuplicatedSnackbar => 'Taslak çoğaltıldı';

  @override
  String get libraryDraftDuplicateFailedSnackbar => 'Taslak çoğaltılamadı';

  @override
  String get libraryDraftInProgressBadge => 'Devam ediyor';

  @override
  String get libraryDraftActionPost => 'Paylaş';

  @override
  String get libraryDraftActionEdit => 'Düzenle';

  @override
  String get libraryDraftActionDuplicate => 'Çoğalt';

  @override
  String get libraryDraftActionDelete => 'Taslağı sil';

  @override
  String libraryDraftCopyTitle(String title, int number) {
    return '$title (kopya $number)';
  }

  @override
  String get libraryDeleteDraftTitle => 'Taslağı sil';

  @override
  String libraryDeleteDraftMessage(String title) {
    return '\"$title\" silinsin mi?';
  }

  @override
  String get libraryDeleteClipTitle => 'Klibi sil';

  @override
  String get libraryDeleteClipMessage => 'Bu klibi silmek istiyor musun?';

  @override
  String libraryClipDuration(String seconds) {
    return '$seconds sn';
  }

  @override
  String get libraryRecordVideo => 'Video kaydet';

  @override
  String videoClipSemanticLabel(String duration) {
    return 'Video klibi, $duration saniye';
  }

  @override
  String videoClipArchivedSemanticLabel(String label) {
    return 'Arşivlendi. $label';
  }

  @override
  String videoClipStopMotionSemanticLabel(String frames) {
    return 'Stop motion klibi, $frames';
  }

  @override
  String videoClipSemanticValueSelectedAtPosition(int position) {
    return 'Seçildi, numara $position';
  }

  @override
  String get videoClipSemanticValueSelected => 'Seçildi';

  @override
  String get videoClipSemanticValueNotSelected => 'Seçilmedi';

  @override
  String get videoClipSemanticHintDisabled => 'Devre dışı';

  @override
  String get videoClipSemanticHintSelect =>
      'Seçmek için dokun, önizlemek için uzun bas';

  @override
  String get videoClipSemanticHintDeselect =>
      'Seçimi kaldırmak için dokun, önizlemek için uzun bas';

  @override
  String get routerInvalidCreator => 'Geçersiz içerik üretici';

  @override
  String get routerInvalidHashtagRoute => 'Geçersiz hashtag rotası';

  @override
  String get categoryGalleryCouldNotLoadVideos => 'Videolar yüklenemedi';

  @override
  String get categoryGalleryNoVideosInCategory => 'Bu kategoride video yok';

  @override
  String get categoryGallerySortOptionsLabel => 'Kategori sıralama seçenekleri';

  @override
  String get categoryGallerySortHot => 'Popüler';

  @override
  String get categoryGallerySortNew => 'Yeni';

  @override
  String get categoryGallerySortClassic => 'Klasik';

  @override
  String get categoryGallerySortForYou => 'Sana Özel';

  @override
  String get categoriesCouldNotLoadCategories => 'Kategoriler yüklenemedi';

  @override
  String get categoriesNoCategoriesAvailable => 'Kategori yok';

  @override
  String get notificationsEmptyTitle => 'Henüz hareket yok';

  @override
  String get notificationsEmptySubtitle =>
      'İnsanlar içeriğinle etkileşime geçtiğinde burada göreceksin';

  @override
  String get appsPermissionsTitle => 'Entegrasyon İzinleri';

  @override
  String get appsPermissionsRevoke => 'İptal Et';

  @override
  String get appsPermissionsEmptyTitle => 'Kayıtlı entegrasyon izni yok';

  @override
  String get appsPermissionsEmptySubtitle =>
      'Onaylanmış entegrasyonlar bir erişim onayını hatırladıktan sonra burada görünecek.';

  @override
  String nostrAppPermissionTitle(String appName) {
    return '$appName onayını istiyor';
  }

  @override
  String get nostrAppPermissionDescription =>
      'Bu uygulama Divine\'in onaylı sandbox\'ı üzerinden erişim talep ediyor.';

  @override
  String get nostrAppPermissionOrigin => 'Kaynak';

  @override
  String get nostrAppPermissionMethod => 'Yöntem';

  @override
  String get nostrAppPermissionCapability => 'Yetenek';

  @override
  String get nostrAppPermissionEventKind => 'Olay türü';

  @override
  String get nostrAppPermissionAllow => 'İzin Ver';

  @override
  String get appsDetailDefaultTitle => 'Entegre Uygulama';

  @override
  String get appsDetailNotFoundTitle => 'Entegrasyon bulunamadı';

  @override
  String get appsDetailNotFoundSubtitle =>
      'Bu onaylı entegrasyon artık Divine\'de kullanılamıyor.';

  @override
  String get appsDetailHowItWorksTitle => 'Nasıl çalışır';

  @override
  String get appsDetailHowItWorksBody =>
      'Bu, Divine içinde çalışan onaylı bir üçüncü taraf uygulamasıdır. Divine bu entegrasyona yalnızca incelenmiş yetenekler tanır ve onaylı kaynaklarının dışına gitmeyi engeller.';

  @override
  String get appsDetailAboutTitle => 'Hakkında';

  @override
  String get appsDetailPrimaryOriginTitle => 'Birincil kaynak';

  @override
  String get appsDetailApprovedOriginsTitle => 'Onaylı kaynaklar';

  @override
  String get appsDetailCapabilitiesTitle => 'Kullanılabilir yetenekler';

  @override
  String get appsDetailAskBeforeTitle => 'Önce sor';

  @override
  String get appsDetailOpenButton => 'Entegrasyonu Aç';

  @override
  String get appsDetailNoneDeclared => 'Henüz hiçbiri belirtilmedi';

  @override
  String get appsDirectoryTitle => 'Entegre Uygulamalar';

  @override
  String get appsDirectoryIntroTitle => 'Onaylı üçüncü taraf uygulamalar';

  @override
  String get appsDirectoryIntroBody =>
      'Divine içinde çalışan onaylı üçüncü taraf uygulamalar';

  @override
  String get appsDirectoryErrorTitle => 'Entegre uygulamalar yüklenemedi';

  @override
  String get appsDirectoryErrorSubtitle =>
      'Onaylı entegrasyonları tekrar denemek için çek.';

  @override
  String get appsDirectoryEmptyTitle => 'Henüz onaylı entegrasyon yok';

  @override
  String get appsDirectoryEmptySubtitle =>
      'Onaylı üçüncü taraf uygulamalar, Divine ekledikçe burada görünecek.';

  @override
  String get appsDirectoryRefresh => 'Yenile';

  @override
  String get appsDirectoryUnsupportedTitle =>
      'Entegre Uygulamalar Divine mobilde çalışır';

  @override
  String get appsDirectoryUnsupportedSubtitle =>
      'Onaylı entegrasyonlar şimdilik yalnızca mobilde kullanılabilir.';

  @override
  String get appsSandboxUnavailableTitle => 'Entegrasyon kullanılamıyor';

  @override
  String get appsSandboxUnavailableBody =>
      'Onaylı entegrasyonları Entegre Uygulamalar sekmesinden aç ki Divine doğru erişim politikasını uygulayabilsin.';

  @override
  String get appsSandboxLoadingTitle => 'Entegrasyon yükleniyor';

  @override
  String get appsSandboxLoadingSubtitle =>
      'Başlatmadan önce onaylı entegrasyon kontrol ediliyor.';

  @override
  String get appsSandboxBlockedTitle => 'Güvenlik için engellendi';

  @override
  String appsSandboxBlockedSubtitle(String uri) {
    return 'Bu entegrasyon onaylı kaynağının dışına çıkmayı denedi.\n\n$uri';
  }

  @override
  String get shareCopiedPostLink => 'Gönderi bağlantısı panoya kopyalandı';

  @override
  String get shareCopiedEventJson => 'Nostr olay JSON\'u panoya kopyalandı';

  @override
  String get shareCopiedEventId => 'Nostr olay kimliği panoya kopyalandı';

  @override
  String get authHeroTaglineAuthentic => 'Gerçek anlar.';

  @override
  String get authHeroTaglineHuman => 'İnsan yaratıcılığı.';

  @override
  String get keyImportFailedToImport =>
      'Anahtar içe aktarılamadı veya bunker\'a bağlanılamadı';

  @override
  String get keyImportInvalidBunkerUrl => 'Geçersiz bunker URL\'si';

  @override
  String get keyImportInvalidFormat =>
      'Geçersiz biçim. nsec..., hex, ncryptsec1... veya bunker://... kullan';

  @override
  String get keyImportInvalidNsecFormat =>
      'Geçersiz nsec biçimi. 63 karakter olmalı';

  @override
  String get keyImportKeyFieldLabel => 'Özel anahtar veya bunker URL\'si';

  @override
  String get keyImportKeyRequired =>
      'Lütfen özel anahtarını veya bunker URL\'ni gir';

  @override
  String get keyImportPasswordRequired =>
      'Lütfen bu şifreli anahtarın parolasını gir';

  @override
  String get keyImportSecurityWarningBody =>
      'Özel anahtarını asla kimseyle paylaşma. Bu anahtar, Nostr kimliğine tam erişim sağlar.';

  @override
  String get keyImportSecurityWarningTitle => 'Özel anahtarını güvende tut!';

  @override
  String get keyImportSubtitle =>
      'Mevcut Nostr kimliğini özel anahtarını veya bir bunker URL\'sini kullanarak içe aktar.';

  @override
  String get keyImportTitle => 'Nostr kimliğini\niçe aktar';

  @override
  String get commentAuthorYouIndicator => 'Sen';

  @override
  String commentAuthorAvatarSemanticLabel(String name) {
    return '$name kullanıcısının profilini görüntüle';
  }

  @override
  String get commentOptionsDeleteSemanticLabel => 'Yorumu sil';

  @override
  String get commentOptionsEditSemanticLabel => 'Yorumu düzenle';

  @override
  String get commentOptionsFlagContentLabel => 'İçeriği İşaretle';

  @override
  String get commentOptionsFlagContentSemanticLabel => 'Bu içeriği işaretle';

  @override
  String get commentOptionsFlagReasonPrompt =>
      'Bu yorumu işaretlemek için bir neden seç';

  @override
  String get commentOptionsFlagSubmit => 'Gönder';

  @override
  String get commentOptionsTitle => 'Seçenekler';

  @override
  String get commentsEmptyClassicVineMessage =>
      'Arşivden eski yorumları içe aktarmaya hâlâ çalışıyoruz. Henüz hazır değiller.';

  @override
  String get commentsEmptyClassicVineTitle => 'Klasik Vine';

  @override
  String get commentsInputEditingLabel => 'Düzenleniyor';

  @override
  String get commentsInputSemanticHint => 'Yorum ekle';

  @override
  String get commentsInputSemanticHintEdit => 'Yorumu düzenle';

  @override
  String get commentsInputSemanticHintReply => 'Yanıt ekle';

  @override
  String get commentsInputSemanticLabel => 'Yorum girişi';

  @override
  String get commentsInputSemanticLabelEdit => 'Düzenleme girişi';

  @override
  String get commentsInputSemanticLabelReply => 'Yanıt girişi';

  @override
  String classicVinersViewProfileSemanticLabel(String displayName) {
    return '$displayName profilini görüntüle';
  }

  @override
  String get classicsEmptyDescription => 'Klasikler arşivi yükleniyor';

  @override
  String get classicsEmptyTitle => 'Klasik Bulunamadı';

  @override
  String get classicsErrorTitle => 'Klasikler yüklenemedi';

  @override
  String get classicsUnavailableDescription =>
      'Klasikler yalnızca Funnelcake rölelerine bağlıyken kullanılabilir.';

  @override
  String get classicsUnavailableSettingsHint =>
      'Klasikler arşivine erişmek için Ayarlar\'dan Funnelcake destekli bir röleye geç.';

  @override
  String get classicsUnavailableTitle => 'Klasikler Kullanılamıyor';

  @override
  String get hashtagFeedEmptySubtitle =>
      'Bu hashtag\'le ilk videoyu sen paylaş!';

  @override
  String hashtagFeedEmptyTitle(String hashtag) {
    return '#$hashtag için video bulunamadı';
  }

  @override
  String get hashtagFeedLoadingSubtitle => 'Bu birkaç dakika sürebilir';

  @override
  String hashtagFeedLoadingTitle(String hashtag) {
    return '#$hashtag hakkındaki videolar yükleniyor...';
  }

  @override
  String get hashtagInputHint => 'Hashtag ekle... #vine #nostr';

  @override
  String get newVideosTabEmptySubtitle =>
      'Yeni içerik için daha sonra tekrar bak';

  @override
  String get newVideosTabEmptyTitle => 'Yeni Videolar\'da video yok';

  @override
  String get popularVideosContextTitle => 'Popüler Videolar';

  @override
  String get popularVideosEmptySubtitle =>
      'Yeni içerik için daha sonra tekrar bak';

  @override
  String get popularVideosEmptyTitle => 'Popüler Videolar\'da video yok';

  @override
  String get popularVideosErrorTitle => 'Trend videolar yüklenemedi';

  @override
  String get popularVideosFeedSourceLabel => 'Popüler akış kaynağı';

  @override
  String get trendingHashtagsLoading => 'Hashtag\'ler yükleniyor...';

  @override
  String trendingHashtagsViewVideosTagged(String hashtag) {
    return '$hashtag etiketli videoları görüntüle';
  }

  @override
  String videoGridAuthorSemanticLabel(String name) {
    return 'Video sahibi: $name';
  }

  @override
  String videoGridDescriptionSemanticLabel(String description) {
    return 'Video açıklaması: $description';
  }

  @override
  String get forYouAlgorithmChoiceBody =>
      'Divine\'ın vizyonu sana gerçek algoritmik seçim sunmak. Tek bir kara kutu algoritmasına hapsolmak yerine, birden fazla öneri yaklaşımı arasından seçim yapabileceksin:';

  @override
  String get forYouAlgorithmChoiceChronological =>
      'Takip ettiğin içerik üreticilerden kronolojik zaman çizelgesi';

  @override
  String get forYouAlgorithmChoiceClosing =>
      'Bu, dikkatinin kontrolünü platforma bırakmak yerine sana verir. Akışının nasıl düzenlendiğini bilmeli ve istediğin zaman değiştirebilme gücüne sahip olmalısın.';

  @override
  String get forYouAlgorithmChoiceCustomFeeds =>
      'Müzik, komedi veya sanat gibi konular için toplulukça oluşturulmuş özel akışlar';

  @override
  String get forYouAlgorithmChoicePersonalizedFeed =>
      'Kişiselleştirilmiş \"Senin İçin\" akışı';

  @override
  String get forYouAlgorithmChoiceTitle => 'Senin Algoritman, Senin Seçimin';

  @override
  String get forYouAlgorithmChoiceTrending => 'Trend ve popüler içerik';

  @override
  String get forYouAlgorithmCommentsDescription =>
      'Güçlü sinyal — yanıt verecek kadar ilgilendin';

  @override
  String get forYouAlgorithmHowItWorksBody =>
      'Divine, neyden hoşlandığını anlamak için içerikle nasıl etkileşim kurduğuna dikkat eder. Bir videoyu her izlediğinde, ona tepki verdiğinde, yorum yaptığında veya yeniden paylaştığında sistem bunu not eder.';

  @override
  String get forYouAlgorithmHowItWorksTitle => 'Nasıl Çalışır';

  @override
  String get forYouAlgorithmInteractionsIntro =>
      'Farklı eylemler farklı ilgi düzeylerini işaret eder:';

  @override
  String get forYouAlgorithmNewToDivineBody1 =>
      'Henüz bir izleme geçmişin yoksa, şu anda popüler ve trend olanların yanında son yüklemelerden oluşan bir karışım gösteririz. Bu, keşfetmeye başlaman için harika bir başlangıç noktası verir.';

  @override
  String get forYouAlgorithmNewToDivineBody2 =>
      'İzledikçe, beğendikçe ve içerikle etkileştikçe öneriler yavaş yavaş daha kişiselleşir. Zamanla, Senin İçin akışın kendi başına asla keşfedemeyeceğin içerik üreticilerden videolar çıkarır.';

  @override
  String get forYouAlgorithmNewToDivineTitle => 'Divine\'da yeni misin?';

  @override
  String get forYouAlgorithmOpenSourceBody =>
      'Geliştiricilerin kendi algoritmalarını uygulayabileceği açık bir sistem inşa ediyoruz; sen de hangilerini kullanacağını seçebilir ya da tamamen vazgeçebilirsin.';

  @override
  String get forYouAlgorithmOpenSourceTitle => 'Açık Kaynak ve Şeffaf';

  @override
  String get forYouAlgorithmReactionsDescription =>
      'Orta sinyal — takdirini göstermenin hızlı bir yolu';

  @override
  String get forYouAlgorithmReactionsTitle => 'Tepkiler';

  @override
  String get forYouAlgorithmRepostsDescription =>
      'En güçlü sinyal — takipçilerinle paylaşmak güçlü bir onaydır';

  @override
  String get forYouAlgorithmSubtitle =>
      'Açık kaynaklı bir öneri motoru olan Gorse tarafından desteklenir';

  @override
  String get forYouAlgorithmTitle => 'Divine Algoritması';

  @override
  String get forYouAlgorithmViewsDescription =>
      'Hafif sinyal — temel ilgiyi gösterir';

  @override
  String get forYouEmptyDescription =>
      'Kişiselleştirilmiş öneriler almak için birkaç video izle ve beğen.';

  @override
  String get forYouEmptyTitle => 'Henüz Öneri Yok';

  @override
  String get forYouErrorTitle => 'Öneriler yüklenemedi';

  @override
  String get forYouUnavailableDescription =>
      'Kişiselleştirilmiş öneriler Funnelcake bağlantısı gerektirir.';

  @override
  String get forYouUnavailableTitle => 'Senin İçin Kullanılamıyor';

  @override
  String get inboxConversationOptionsLabel => 'Seçenekler';

  @override
  String get inboxConversationViewProfileButton => 'Profili görüntüle';

  @override
  String get inboxMessageRequestsEmpty => 'Mesaj isteği yok';

  @override
  String inboxMessageRequestsSemanticLabel(int requestCount) {
    return 'Mesaj istekleri, $requestCount beklemede';
  }

  @override
  String get inboxMessageRequestsTitle => 'Mesaj istekleri';

  @override
  String get inboxMessagesTab => 'Mesajlar';

  @override
  String inboxRequestTileLabel(String displayName) {
    return '$displayName mesaj isteği';
  }

  @override
  String get inboxRequestTileSubtitle => 'Bir mesaj isteği gönderdi';

  @override
  String get inboxRequestsMarkAllRead => 'Tüm istekleri okundu olarak işaretle';

  @override
  String get inboxRequestsRemoveAll => 'Tüm istekleri kaldır';

  @override
  String get messageRequestDeclineAndRemoveButton => 'Reddet ve kaldır';

  @override
  String messageRequestDeclinedSnackbar(String displayName) {
    return '$displayName kişisinin isteği reddedildi';
  }

  @override
  String get messageRequestLoadFailed => 'Bu istek yüklenemedi.';

  @override
  String messageRequestFollowersCount(int countValue, String count) {
    return '$count Takipçi';
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
      other: '$count mesaj',
      one: '1 mesaj',
    );
    return '$_temp0';
  }

  @override
  String get messageRequestViewMessagesButton => 'Mesajları görüntüle';

  @override
  String get messageRequestViewProfileButton => 'Profili görüntüle';

  @override
  String messageRequestWantsToMessageYou(
    String displayName,
    String messageText,
  ) {
    return '$displayName sana mesaj göndermek istiyor, $messageText gönderdi.';
  }

  @override
  String get deleteAccountAccountChanged =>
      'Hesap değiştirdin, bu yüzden hiçbir şey silinmedi. Kaldırmak istediğin hesap için silme ekranını yeniden aç.';

  @override
  String get deleteAccountConfirmDeletePrompt => 'Onaylamak için yaz:';

  @override
  String get deleteAccountConfirmUsernamePrompt =>
      'Onaylamak için kullanıcı adını yaz:';

  @override
  String get deleteAccountConfirmationHint => 'DELETE yaz';

  @override
  String get deleteAccountConfirmationHintUsername => 'Kullanıcı adını yaz';

  @override
  String get deleteAccountDeleteAllContentButton => 'Tüm İçeriği Sil';

  @override
  String get accountDeletionRecoveryTitle => 'Hesabın siliniyor';

  @override
  String get accountDeletionRecoveryBody =>
      'Hesabını silme işlemini tamamlayamadık. Kullanıcı adın senin için ayrılmış durumda ve hâlâ geri alınabilir.';

  @override
  String accountDeletionRecoveryBodyWithExpiry(String expiryDate) {
    return 'We couldn\'t finish deleting your account. Your username is reserved for you until $expiryDate and can still be restored.';
  }

  @override
  String get accountDeletionRestoreUsername => 'Kullanıcı adımı geri al';

  @override
  String get accountDeletionFinishingBody =>
      'Silme isteğin hâlâ işleniyor. Biz işlemi tamamlarken başka bir hesap kullanabilirsin.';

  @override
  String get accountDeletionOtherAccountPending =>
      'Bu cihazda başka bir hesabın silme işlemi hâlâ devam ediyor. Bu hesabı silmeden önce işlemin tamamlanmasını bekle.';

  @override
  String get accountDeletionCancellingBody =>
      'Silme işlemini iptal ediyoruz. Bu ekrandan çıkmadan önce tekrar kontrol et.';

  @override
  String get accountDeletionRecoveryFailed =>
      'Kullanıcı adını henüz geri alamadık. Bağlantını kontrol edip tekrar dene.';

  @override
  String get accountDeletionUsernameRestored =>
      'Kullanıcı adın geri alındı. Hesabın silinmedi.';

  @override
  String get accountDeletionRecoveryStatusFailed =>
      'Silme durumunu kontrol edemedik. Bağlantını kontrol edip tekrar dene.';

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
      'Hesap silme şu anda kullanılamıyor. Hiçbir şey silinmedi.';

  @override
  String get deleteAccountDeletionIncomplete =>
      'Hesabını silme işlemini tamamlayamadık. Tekrar dene.';

  @override
  String get deleteAccountDeletionNotStarted =>
      'We couldn\'t start deleting your account. Nothing was deleted. Try again.';

  @override
  String get deleteAccountFinalConfirmationTitle => '⚠️ Son Onay';

  @override
  String get deleteAccountKeyDeletionWarning =>
      'Silme istekleri gönderildi ama anahtarların bu cihazdan tamamen kaldırılmamış olabilir. Tekrar denemek için Ayarlar → Nostr Anahtarları → Anahtarları Kaldır\'a git.';

  @override
  String get deleteAccountLocalDataDeletionFailed =>
      'Silme istekleri gönderildi ve oturumun kapatıldı ama bazı yerel veriler bu cihazdan kaldırılamadı.';

  @override
  String get deleteAccountPreparingDeletion => 'Silme hazırlanıyor...';

  @override
  String deleteAccountProgressEvents(int current, int total) {
    return '$current / $total olay';
  }

  @override
  String get deleteAccountRemoveKeysBody =>
      'Bu, bu hesabın yerel girişini bu cihazdan kaldırır. Divine hesabını veya Nostr kimliğini silmez.\n\nTaslakların ve kliplerin bu hesap için bu cihazda kayıtlı kalır. Bu son yerel hesabınsa, giriş ekranına döneceksin.';

  @override
  String get deleteAccountRemoveKeysConfirm => 'Cihazdan kaldır';

  @override
  String get deleteAccountRemoveKeysTitle =>
      'Bu hesap bu cihazdan kaldırılsın mı?';

  @override
  String get deleteAccountReauthRequired =>
      'Hesabını silmek için tekrar giriş yap. Henüz hiçbir şey silinmedi.';

  @override
  String get deleteAccountServerDeletionFailed =>
      'Gönderilerin için silme istekleri gönderildi ama hesabını silme işlemini tamamlayamadık. Birazdan tekrar dene.';

  @override
  String get deleteAccountSuccess =>
      'Divine hesabın silindi. Nostr gönderilerin için silme istekleri gönderildi ancak bazı röleler, istemciler veya önbellekler kopyaları saklayabilir.';

  @override
  String get deleteAccountSuccessContentUnverified =>
      'Hesap silme isteği gönderildi. Mevcut bazı gönderilerin silinmesi tek tek doğrulanamadı.';

  @override
  String get deleteAccountWarningBody =>
      'Bu, hesabın ve içeriğin için silme istekleri gönderir, mümkün olduğunda Divine hesabını siler ve bu cihazda oturumunu kapatır. Bazı röleler, istemciler ve arama dizinleri kopyaları saklayabilir. Oturum açmış diğer cihazlar, oradaki anahtarları kaldırana kadar aktif kalır.';

  @override
  String get findPeopleNoContacts =>
      'Kişi bulunamadı.\nBurada görmek için insanları takip etmeye başla.';

  @override
  String get geoBlockedCityLabel => 'Şehir';

  @override
  String get geoBlockedCountryLabel => 'Ülke';

  @override
  String get geoBlockedDefaultReason =>
      'Bu hizmet, yerel düzenlemeler nedeniyle bulunduğun bölgede kullanılamıyor.';

  @override
  String get geoBlockedLegalNotice =>
      'Yerel yasalarına ve düzenlemelerine saygı duyuyoruz. Bu kısıtlama, IP adresi konumuna göre uygulanır.';

  @override
  String get geoBlockedRegionLabel => 'Bölge';

  @override
  String get geoBlockedTitle => 'Hizmet Kullanılamıyor';

  @override
  String get likedVideosEmpty => 'Beğenilen video yok';

  @override
  String get likedVideosInvalidRoute => 'Geçersiz rota';

  @override
  String get likedVideosTitle => 'Beğenilen Videolar';

  @override
  String get uploadFailureSheetRetryingSnackbar => 'Yükleme tekrar deneniyor…';

  @override
  String get uploadFailureSheetSaveToDraftsButton => 'Taslaklara Kaydet';

  @override
  String get uploadFailureSheetSavedToDraftsSnackbar => 'Taslaklara kaydedildi';

  @override
  String get uploadFailureSheetTitle => 'Yükleme Başarısız';

  @override
  String get uploadFailureSheetTryAgainButton => 'Tekrar Dene';

  @override
  String get videoEditorAudioImportAudio => 'Ses içe aktar';

  @override
  String get videoEditorAudioImportFailed => 'Ses içe aktarma başarısız.';

  @override
  String get videoIconPlaceholderLabel => 'Video';

  @override
  String get publishErrorNotSignedIn =>
      'Video yayınlamak için lütfen giriş yap.';

  @override
  String get publishErrorNoRetry => 'Yeniden denenecek bir yükleme yok.';

  @override
  String get publishErrorNoInternet =>
      'İnternet bağlantısı yok. Wi-Fi\'ını veya mobil verini kontrol edip tekrar dene.';

  @override
  String get publishErrorServerUnreachable =>
      'Sunucuya ulaşılamadı. Lütfen birazdan tekrar dene.';

  @override
  String get publishErrorTimeout =>
      'Yükleme zaman aşımına uğradı. Daha güçlü bir bağlantı ya da daha küçük bir video dene.';

  @override
  String get publishErrorTls =>
      'Güvenli bağlantı kurulamadı. Ağını kontrol et — herkese açık Wi-Fi yüklemeleri engelleyebilir.';

  @override
  String publishErrorServerNotFound(String serverName) {
    return 'Medya sunucusu ($serverName) kullanılamıyor. Ayarlarından başka birini seçebilirsin.';
  }

  @override
  String get publishErrorFileTooLarge =>
      'Video dosyası sunucu için fazla büyük. Kırpmayı ya da kaliteyi düşürmeyi dene.';

  @override
  String publishErrorServerInternalError(String serverName) {
    return 'Medya sunucusunda ($serverName) dahili bir hata oluştu. Ayarlarından başka birini seçebilirsin.';
  }

  @override
  String publishErrorServerDown(String serverName) {
    return 'Medya sunucusu ($serverName) geçici olarak çalışmıyor. Birazdan tekrar dene ya da ayarlarından başka birini seç.';
  }

  @override
  String get publishErrorForbidden => 'Bu sunucuya yükleme yapma iznin yok.';

  @override
  String get publishErrorFileNotFound =>
      'Video dosyası bulunamadı. Silinmiş olabilir. Yeniden kaydedip tekrar dene.';

  @override
  String get publishErrorLowStorage =>
      'Cihazında yeterli depolama alanı yok. Biraz yer açıp tekrar dene.';

  @override
  String get publishErrorThumbnailFailed =>
      'Video yüklendi ama küçük resim hazırlanamadı. Lütfen tekrar dene.';

  @override
  String get publishErrorNostrPublishFailed =>
      'Video yüklendi ama gönderi yayınlanamadı. Röle ayarlarını kontrol edip tekrar dene.';

  @override
  String get publishErrorAccountRestricted =>
      'Your account is restricted, so this post couldn’t be published.';

  @override
  String get uploadFailureSheetAccountStatusButton => 'View Account Status';

  @override
  String get publishErrorAudioReuseNotPermitted =>
      'Video yüklendi ama bu ses yeniden kullanıma açık değil. Paylaşmak için başka bir ses seç.';

  @override
  String get publishErrorInterrupted =>
      'Bu yükleme yarıda kaldı. Tekrar denemek ister misin?';

  @override
  String get publishErrorAccountChanged =>
      'Bu video başka bir hesaba ait. Paylaşmak için o hesaba geri dön.';

  @override
  String get publishErrorGeneric =>
      'Bir şeyler ters gitti. Lütfen tekrar dene.';

  @override
  String get publishErrorRateLimited =>
      'Şu anda çok fazla yükleme var. Biraz bekleyip tekrar dene.';

  @override
  String get publishErrorUploadSessionExpired =>
      'Yükleme oturumun sona erdi. Lütfen tekrar dene.';

  @override
  String get publishErrorPermissionDenied =>
      'Divine\'in yükleme izni yok. Ayarlarından uygulama izinlerini kontrol edip tekrar dene.';

  @override
  String get publishErrorOutOfMemory =>
      'Cihazının belleği azaldı. Bazı uygulamaları kapatıp tekrar dene.';

  @override
  String get publishErrorOverlaysUnavailable =>
      'Bu taslaktaki yazı ve çıkartmalar hazırlanamadı. Düzenleyicide aç ve tekrar paylaş.';

  @override
  String get publishErrorUnknownServer => 'Bilinmeyen sunucu';

  @override
  String searchFilterPillSemanticLabel(String filter) {
    return 'Filtre: $filter';
  }

  @override
  String searchNoResultsFound(String query) {
    return '\"$query\" için sonuç bulunamadı';
  }

  @override
  String searchTagChipViewVideosTaggedLabel(String tag) {
    return '$tag etiketli videoları görüntüle';
  }

  @override
  String audioAttributionRowSemanticLabel(
    String soundName,
    String creatorName,
  ) {
    return 'Ses: $creatorName tarafından $soundName. Ses ayrıntılarını görmek için dokun.';
  }

  @override
  String metadataSoundsOriginalSoundSemantics(String creatorName) {
    return '$creatorName tarafından orijinal ses. Bu sesi kullanmak için dokun.';
  }

  @override
  String metadataSoundsSharedSoundSemantics(
    String soundName,
    String creatorName,
  ) {
    return 'Ses: $creatorName tarafından $soundName. Ayrıntıları görmek için dokun.';
  }

  @override
  String get soundDetailLoadError => 'Ses yüklenemedi. Lütfen tekrar dene.';

  @override
  String get soundDetailNotFoundMessage => 'Bu ses bulunamadı';

  @override
  String get soundDetailNotFoundTitle => 'Ses Bulunamadı';

  @override
  String videoFeedLoopCountLabel(int count) {
    return '🔁 $count döngü';
  }

  @override
  String get originalSoundUnavailableBody =>
      'Bu videonun sesi ayrı olarak kullanılamıyor.';

  @override
  String originalSoundByCreator(String creatorName) {
    return 'Orijinal ses - $creatorName';
  }

  @override
  String get ogVinerBadgeLabel => 'OG Viner';

  @override
  String get profileBadgeOgVinerBody =>
      'Bu kişi, Divine\'ın arşivde bulduğu orijinal bir Vine paylaşmış. Bu bir hesap doğrulama rozeti değil.';

  @override
  String get ogBetaTesterBadgeLabel => 'OG Beta Tester';

  @override
  String get profileBadgeOgBetaTesterBody =>
      'This person was testing Divine during the beta, before it opened to everyone. It is not an account verification badge.';

  @override
  String get profileBadgeCheckmarkTitle => 'Profil onay işareti';

  @override
  String get profileBadgeCheckmarkBody =>
      'Divine bu onay işaretini ekip hesaplarına veriyor. NIP-05\'ten, doğrulanmış hesap bağlantılarından ve OG Viner durumundan ayrıdır.';

  @override
  String get unfollowConfirmButton => 'Takipten çık';

  @override
  String get videoClipSaveFailed => 'Klip kaydedilemedi';

  @override
  String videoClipSaveTo(String destination) {
    return '$destination konumuna kaydet';
  }

  @override
  String get videoClipDelete => 'Klibi sil';

  @override
  String inspiredByAttributionMultipleSemanticLabel(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return '$creatorName +$additionalCreatorCount tarafından ilham alındı. Profilini görüntülemek için dokun.';
  }

  @override
  String inspiredByAttributionSemanticLabel(String creatorName) {
    return '$creatorName tarafından ilham alındı. Profilini görüntülemek için dokun.';
  }

  @override
  String get bugReportSendReport => 'Raporu Gönder';

  @override
  String get supportSubjectRequiredLabel => 'Konu *';

  @override
  String get supportPublicSubmissionTitle => 'Herkese açık GitHub gönderisi';

  @override
  String get supportPublicSubmissionMessage =>
      'Buraya gönderdiğin her şey, geliştiricilerin ilgilenebilmesi için GitHub\'daki açık kaynak depomuzda yayınlanacak. Gönderi ve giriş yaptığın hesap herkes tarafından görülebilecek.';

  @override
  String get supportRequiredHelper => 'Zorunlu';

  @override
  String get supportFieldLimitReached =>
      'Bu, izin verilen en fazla uzunluk. Bundan sonrası eklenmedi.';

  @override
  String get bugReportSubjectHint => 'Sorunun kısa özeti';

  @override
  String get bugReportDescriptionRequiredLabel => 'Ne oldu? *';

  @override
  String get bugReportDescriptionHint => 'Karşılaştığın sorunu anlat';

  @override
  String get bugReportStepsLabel => 'Yeniden Üretme Adımları';

  @override
  String get bugReportStepsHint =>
      '1. Şuraya git...\n2. Şuna dokun...\n3. Hatayı gör';

  @override
  String get bugReportExpectedBehaviorLabel => 'Beklenen Davranış';

  @override
  String get bugReportExpectedBehaviorHint => 'Bunun yerine ne olmalıydı?';

  @override
  String get bugReportDiagnosticsNotice =>
      'Cihaz bilgileri ve günlükler otomatik olarak eklenecek.';

  @override
  String get bugReportSuccessMessage =>
      'Teşekkürler! Raporunu aldık ve Divine\'i daha iyi yapmak için kullanacağız.';

  @override
  String get bugReportAttachImages => 'Görsel ekle';

  @override
  String bugReportImagesCount(int count, int max) {
    return '$max görselden $count tanesi seçildi';
  }

  @override
  String get bugReportRemoveImage => 'Görseli kaldır';

  @override
  String get bugReportUploadFailed =>
      'Seçilen görseli yükleyemedik. Tekrar dene ya da raporu görselsiz gönder.';

  @override
  String get bugReportSendFailed =>
      'Hata raporu gönderilemedi. Lütfen daha sonra tekrar dene.';

  @override
  String get featureRequestSendRequest => 'İsteği Gönder';

  @override
  String get featureRequestSubjectHint => 'Fikrinin kısa özeti';

  @override
  String get featureRequestDescriptionRequiredLabel => 'Ne istersin? *';

  @override
  String get featureRequestDescriptionHint => 'İstediğin özelliği anlat';

  @override
  String get featureRequestUsefulnessLabel => 'Bu nasıl faydalı olur?';

  @override
  String get featureRequestUsefulnessHint =>
      'Bu özelliğin sağlayacağı faydayı açıkla';

  @override
  String get featureRequestWhenLabel => 'Bunu ne zaman kullanırsın?';

  @override
  String get featureRequestWhenHint => 'Bunun işe yarayacağı durumları anlat';

  @override
  String get featureRequestSuccessMessage =>
      'Teşekkürler! Özellik isteğini aldık ve gözden geçireceğiz.';

  @override
  String get featureRequestSendFailed =>
      'Özellik isteği gönderilemedi. Lütfen daha sonra tekrar dene.';

  @override
  String get notificationFollowBack => 'Geri takip et';

  @override
  String get followingTitle => 'Takip Edilen';

  @override
  String followingTitleForName(String displayName) {
    return '$displayName kullanıcısının takipleri';
  }

  @override
  String get followingFailedToLoadList => 'Takip edilen listesi yüklenemedi';

  @override
  String get followingEmptyTitle => 'Henüz kimseyi takip etmiyorsun';

  @override
  String get followersTitle => 'Takipçiler';

  @override
  String followersTitleForName(String displayName) {
    return '$displayName kullanıcısının takipçileri';
  }

  @override
  String get followersFailedToLoadList => 'Takipçi listesi yüklenemedi';

  @override
  String get followersEmptyTitle => 'Henüz takipçi yok';

  @override
  String get followersUpdateFollowFailed =>
      'Takip durumu güncellenemedi. Lütfen tekrar dene.';

  @override
  String get followersSortSemanticLabel => 'Takipçileri sırala';

  @override
  String get followingSortSemanticLabel => 'Takip edilenleri sırala';

  @override
  String get followSortTitle => 'Sıralama ölçütü';

  @override
  String get followSortNewest => 'Önce en yeniler';

  @override
  String get followSortOldest => 'Önce en eskiler';

  @override
  String get newMessageTitle => 'Yeni mesaj';

  @override
  String get newMessageFindPeople => 'İnsan bul';

  @override
  String get newMessageNoContacts =>
      'Kişi bulunamadı.\nBurada görmek için insanları takip et.';

  @override
  String get newMessageNoUsersFound => 'Kullanıcı bulunamadı';

  @override
  String get hashtagSearchTitle => 'Etiket ara';

  @override
  String get hashtagSearchSubtitle =>
      'Trend olan konuları ve içerikleri keşfet';

  @override
  String hashtagSearchNoResults(String query) {
    return '\"$query\" için etiket bulunamadı';
  }

  @override
  String get hashtagSearchFailed => 'Arama başarısız';

  @override
  String get userNotAvailableTitle => 'Hesap kullanılamıyor';

  @override
  String get userNotAvailableBody => 'Bu hesap şu anda kullanılamıyor.';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String get blossomFailedToSaveSettings =>
      'Ayarlar kaydedilemedi. Lütfen tekrar dene.';

  @override
  String get blossomValidServerUrl =>
      'Lütfen geçerli bir sunucu URL\'si gir (örn. https://blossom.band)';

  @override
  String get blossomSettingsSaved => 'Blossom ayarları kaydedildi';

  @override
  String get blossomSaveTooltip => 'Kaydet';

  @override
  String get blossomAboutTitle => 'Blossom Hakkında';

  @override
  String get blossomAboutDescription =>
      'Blossom, videoları herhangi bir uyumlu sunucuya yüklemene olanak tanıyan merkeziyetsiz bir medya depolama protokolüdür. Varsayılan olarak videolar Divine\'in Blossom sunucusuna yüklenir. Onun yerine özel bir sunucu kullanmak için aşağıdaki seçeneği etkinleştir.';

  @override
  String get blossomUseCustomServer => 'Özel Blossom Sunucusu Kullan';

  @override
  String get blossomCustomServerEnabledSubtitle =>
      'Videoların özel Blossom sunucuna yüklenecek';

  @override
  String get blossomCustomServerDisabledSubtitle =>
      'Videoların şu anda Divine\'in Blossom sunucusuna yükleniyor';

  @override
  String get blossomCustomServerUrl => 'Özel Blossom Sunucu URL\'si';

  @override
  String get blossomCustomServerHelper =>
      'Özel Blossom sunucunun URL\'sini gir';

  @override
  String get blossomPopularServers => 'Popüler Blossom Sunucuları';

  @override
  String get blossomServerUrlMustUseHttps =>
      'Blossom sunucu URL\'si https:// kullanmalı';

  @override
  String get blueskyFailedToUpdateCrosspost =>
      'Çapraz gönderi ayarı güncellenemedi';

  @override
  String get blueskySignInRequired =>
      'Bluesky ayarlarını yönetmek için giriş yap';

  @override
  String get blueskyPublishVideos => 'Videoları Bluesky\'a yayınla';

  @override
  String get blueskyEnabledSubtitle => 'Videoların Bluesky\'a yayınlanacak';

  @override
  String get blueskyDisabledSubtitle => 'Videoların Bluesky\'a yayınlanmayacak';

  @override
  String get blueskyBackfillDisclosureTitle =>
      'Geçmiş videoların da paylaşılacak';

  @override
  String get blueskyBackfillDisclosureSubtitle =>
      'Bunu açtığında Divine eski videolarını Bluesky’ye göndermeye başlar; en eskilerden başlar ve günlük sınırı aceleye getirmez.';

  @override
  String get blueskyHandle => 'Bluesky Kullanıcı Adı';

  @override
  String get blueskyDid => 'Bluesky DID';

  @override
  String get blueskyStatus => 'Durum';

  @override
  String get blueskyStatusReady => 'Hesap hazırlandı ve kullanıma hazır';

  @override
  String get blueskyStatusPending => 'Hesap hazırlanıyor...';

  @override
  String get blueskyStatusFailed => 'Hesap hazırlama başarısız';

  @override
  String get blueskyStatusDisabled => 'Hesap devre dışı';

  @override
  String get blueskyStatusNotLinked => 'Bağlı Bluesky hesabı yok';

  @override
  String get blueskyUsernameRequired =>
      'Bluesky\'da paylaşmadan önce bir divine.video kullanıcı adı ayarla';

  @override
  String get blueskyUsernameRequiredSubtitle =>
      'Bluesky\'da paylaşım için alınmış bir kullaniciadi.divine.video adresi gerekir.';

  @override
  String get blueskyUsernameSyncPending =>
      'Divine kullanıcı adın alındı. Bluesky ile bağlıyoruz — birazdan tekrar dene.';

  @override
  String get blueskyStatusUnavailableRetry =>
      'Divine kullanıcı adını kontrol edemedik. Tekrar dene.';

  @override
  String get blueskySetUpHandle => 'Ayarla';

  @override
  String get blueskyTemporarilyUnavailable =>
      'Bluesky\'da paylaşım geçici olarak kullanılamıyor. Lütfen tekrar dene.';

  @override
  String get invitesTitle => 'Arkadaşları Davet Et';

  @override
  String invitesGenerateCardTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Oluşturulmaya hazır $count davet',
      one: 'Oluşturulmaya hazır 1 davet',
    );
    return '$_temp0';
  }

  @override
  String get invitesGenerateCardSubtitle =>
      'Paylaşmaya hazır olduğunda bir kod oluştur.';

  @override
  String get invitesGenerateButtonLabel => 'Davet oluştur';

  @override
  String get invitesNoneAvailable => 'Şu anda kullanılabilir davet yok';

  @override
  String get invitesShareWithPeople => 'Divine\'i tanıdığın insanlarla paylaş';

  @override
  String get invitesUsedInvites => 'Kullanılmış davetler';

  @override
  String invitesShareMessage(String code) {
    return 'Divine\'de bana katıl! Başlamak için $code davet kodunu kullan:\nhttps://divine.video/invite/$code';
  }

  @override
  String get invitesCopyInvite => 'Daveti kopyala';

  @override
  String get invitesCopied => 'Davet kopyalandı!';

  @override
  String get invitesShareInvite => 'Daveti paylaş';

  @override
  String get invitesShareSubject => 'Divine\'de bana katıl';

  @override
  String get invitesClaimed => 'Kullanıldı';

  @override
  String get invitesCouldNotLoad => 'Davetler yüklenemedi';

  @override
  String get invitesRetry => 'Tekrar dene';

  @override
  String get searchSomethingWentWrong => 'Bir şeyler ters gitti';

  @override
  String get searchTryAgain => 'Tekrar dene';

  @override
  String get searchForLists => 'Liste ara';

  @override
  String get searchFindCuratedVideoLists => 'Küratörlü video listelerini bul';

  @override
  String get searchEnterQuery => 'Bir arama terimi girin';

  @override
  String get searchDiscoverSomethingInteresting => 'İlginç bir şey keşfet';

  @override
  String get searchPeopleSectionHeader => 'Kişiler';

  @override
  String get searchPeopleLoadingLabel => 'Kişi sonuçları yükleniyor';

  @override
  String get searchTagsSectionHeader => 'Etiketler';

  @override
  String get searchTagsLoadingLabel => 'Etiket sonuçları yükleniyor';

  @override
  String get searchVideosSectionHeader => 'Videolar';

  @override
  String get searchVideosLoadingLabel => 'Video sonuçları yükleniyor';

  @override
  String get searchVideosSortOptionsLabel => 'Video sonuçlarını sırala';

  @override
  String get searchVideosSortTrending => 'Popüler';

  @override
  String get searchVideosSortLoops => 'En çok döngü';

  @override
  String get searchVideosSortEngagement => 'En çok etkileşim';

  @override
  String get searchVideosSortRecent => 'En yeni';

  @override
  String get searchListsSectionHeader => 'Listeler';

  @override
  String get searchListsLoadingLabel => 'Liste sonuçları yükleniyor';

  @override
  String get cameraAgeRestriction =>
      'İçerik oluşturmak için 16 yaşında veya daha büyük olmalısın';

  @override
  String get keyImportInsecureBunkerRelay =>
      'Bunker rölesi wss:// kullanmalı (ws:// sadece localhost için izinli)';

  @override
  String get timeNow => 'şimdi';

  @override
  String timeShortMinutes(int count) {
    return '${count}dk';
  }

  @override
  String timeShortHours(int count) {
    return '${count}sa';
  }

  @override
  String timeShortDays(int count) {
    return '${count}g';
  }

  @override
  String timeShortWeeks(int count) {
    return '${count}hf';
  }

  @override
  String timeShortMonths(int count) {
    return '${count}ay';
  }

  @override
  String timeShortYears(int count) {
    return '${count}yıl';
  }

  @override
  String get timeVerboseNow => 'Şimdi';

  @override
  String timeAgo(String time) {
    return '$time önce';
  }

  @override
  String get timeToday => 'Bugün';

  @override
  String get timeYesterday => 'Dün';

  @override
  String get timeJustNow => 'az önce';

  @override
  String timeMinutesAgo(int count) {
    return '${count}dk önce';
  }

  @override
  String timeHoursAgo(int count) {
    return '${count}sa önce';
  }

  @override
  String timeDaysAgo(int count) {
    return '${count}g önce';
  }

  @override
  String get draftTimeJustNow => 'Az önce';

  @override
  String get contentLabelNudity => 'Çıplaklık';

  @override
  String get contentLabelSexualContent => 'Cinsel İçerik';

  @override
  String get contentLabelPornography => 'Pornografi';

  @override
  String get contentLabelGraphicMedia => 'Rahatsız Edici İçerik';

  @override
  String get contentLabelViolence => 'Şiddet';

  @override
  String get contentLabelSelfHarm => 'Kendine Zarar Verme/İntihar';

  @override
  String get contentLabelDrugUse => 'Uyuşturucu Kullanımı';

  @override
  String get contentLabelAlcohol => 'Alkol';

  @override
  String get contentLabelTobacco => 'Tütün/Sigara';

  @override
  String get contentLabelGambling => 'Kumar';

  @override
  String get contentLabelProfanity => 'Küfür';

  @override
  String get contentLabelHateSpeech => 'Nefret Söylemi';

  @override
  String get contentLabelHarassment => 'Taciz';

  @override
  String get contentLabelFlashingLights => 'Yanıp Sönen Işıklar';

  @override
  String get contentLabelAiGenerated => 'Yapay Zekâ Üretimi';

  @override
  String get contentLabelDeepfake => 'Deepfake';

  @override
  String get contentLabelSpam => 'Spam';

  @override
  String get contentLabelScam => 'Dolandırıcılık';

  @override
  String get contentLabelSpoiler => 'Spoiler';

  @override
  String get contentLabelMisleading => 'Yanıltıcı';

  @override
  String get contentLabelSensitiveContent => 'Hassas İçerik';

  @override
  String notificationLikedYourVideo(String actorName) {
    return '$actorName videonu beğendi';
  }

  @override
  String notificationLikedYourComment(String actorName) {
    return '$actorName yorumunu beğendi';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return '$actorName videona yorum yaptı';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return '$actorName seni takip etmeye başladı';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return '$actorName senden bahsetti';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return '$actorName videonu paylaştı';
  }

  @override
  String notificationPostedNewVine(String actorName) {
    return '$actorName yeni bir vine paylaştı';
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
      other: '$count vine\'ını',
      one: 'vine\'ını',
    );
    return '$actorName, $_temp0 $listName listesine ekledi';
  }

  @override
  String notificationRepliedToYourComment(String actorName) {
    return '$actorName yorumuna yanıt verdi';
  }

  @override
  String get notificationAndConnector => 've';

  @override
  String notificationOthersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kişi daha',
      one: '1 kişi daha',
    );
    return '$_temp0';
  }

  @override
  String get notificationSystemUpdate => 'Yeni bir güncellemen var';

  @override
  String get commentReplyToPrefix => 'Yan:';

  @override
  String get commentHideKeyboard => 'Klavyeyi gizle';

  @override
  String get commentsErrorLoadFailed => 'Yorumlar yüklenemedi';

  @override
  String get commentsErrorNotAuthenticatedComment =>
      'Yorum yapmak için giriş yap';

  @override
  String get commentsErrorPostCommentFailed => 'Yorum paylaşılamadı';

  @override
  String get commentsErrorPostReplyFailed => 'Yanıt paylaşılamadı';

  @override
  String get commentsErrorEditFailed => 'Yorum düzenlenemedi';

  @override
  String get commentsErrorNotAuthenticatedInteract => 'Katılmak için giriş yap';

  @override
  String get commentsErrorVoteFailed => 'Yoruma oy verilemedi';

  @override
  String get commentsErrorReportFailed => 'Yorum bildirilemedi';

  @override
  String get commentsErrorBlockFailed => 'Kullanıcı engellenemedi';

  @override
  String get commentsErrorDeleteFailed => 'Yorum silinemedi';

  @override
  String commentsHeaderCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Yorum',
      one: '$count Yorum',
    );
    return '$_temp0';
  }

  @override
  String get commentsVideoReplyPending => 'Gönderiliyor…';

  @override
  String get commentsVideoReplyPendingSemanticLabel =>
      'Video yanıtınız gönderiliyor';

  @override
  String get commentsSortNew => 'Yeni';

  @override
  String get commentsSortTop => 'En iyi';

  @override
  String get commentsSortOld => 'Eski';

  @override
  String get commentsSortSemanticLabel => 'Yorum sıralaması';

  @override
  String get commentReply => 'Yanıtla';

  @override
  String get commentReplySemanticLabel => 'Yorumu yanıtla';

  @override
  String get commentUpvoteLabel => 'Yorumu beğen';

  @override
  String get commentRemoveUpvoteLabel => 'Beğeniyi kaldır';

  @override
  String get commentDownvoteLabel => 'Yorumu beğenme';

  @override
  String get commentRemoveDownvoteLabel => 'Beğenmemeyi kaldır';

  @override
  String get commentsInputHint => 'Yorum ekle...';

  @override
  String get commentsInputHintEdit => 'Yorumu düzenle...';

  @override
  String get commentsEmptyTitle => 'Henüz yorum yok';

  @override
  String get commentsEmptySubtitle => 'Partiyi sen başlat!';

  @override
  String get draftUntitled => 'Başlıksız';

  @override
  String get contentWarningNone => 'Yok';

  @override
  String get textBackgroundNone => 'Yok';

  @override
  String get textBackgroundSolid => 'Opak';

  @override
  String get textBackgroundHighlight => 'Vurgulama';

  @override
  String get textBackgroundTransparent => 'Saydam';

  @override
  String get textAlignLeft => 'Sol';

  @override
  String get textAlignRight => 'Sağ';

  @override
  String get textAlignCenter => 'Ortala';

  @override
  String get cameraPermissionWebUnsupportedTitle =>
      'Kamera henüz web\'de desteklenmiyor';

  @override
  String get cameraPermissionWebUnsupportedDescription =>
      'Kamera ile çekim ve kayıt henüz web sürümünde kullanılamıyor.';

  @override
  String get cameraPermissionBackToFeed => 'Akışa geri dön';

  @override
  String get cameraCouldNotStart => 'Kamera başlatılamadı';

  @override
  String get cameraUnsupportedPlatform =>
      'Kamera bu platformda henüz kullanılamıyor.\nYine de videolara göz atıp izleyebilirsin.';

  @override
  String get cameraPermissionErrorTitle => 'İzin hatası';

  @override
  String get cameraPermissionErrorDescription =>
      'İzinler kontrol edilirken bir sorun oluştu.';

  @override
  String get cameraPermissionRetry => 'Tekrar dene';

  @override
  String get cameraPermissionAllowAccessTitle =>
      'Kamera ve mikrofona erişime izin ver';

  @override
  String get cameraPermissionAllowAccessDescription =>
      'Bu, videoları doğrudan uygulama içinde çekip düzenlemeni sağlar, daha fazlasını değil.';

  @override
  String get cameraPermissionGoToSettings => 'Ayarlara git';

  @override
  String get videoRecorderWhySixSecondsTitle => 'Neden altı saniye?';

  @override
  String get videoRecorderWhySixSecondsSubtitle =>
      'Kısa klipler kendiliğindenlik için alan yaratır. 6 saniyelik format, anların gerçekleştiği anda otantik anları yakalamanıza yardımcı olur.';

  @override
  String get videoRecorderWhySixSecondsButton => 'Anladım!';

  @override
  String get videoRecorderUploadTitle => 'Neden yükleme yok?';

  @override
  String get videoRecorderUploadBody =>
      'Divine\'da gördüğün şey insan yapımı: ham ve o an yakalanmış. Çok yapımcı veya yapay zekâ tarafından üretilmiş yüklemelere izin veren platformların aksine, doğrudan kamera deneyiminin özgünlüğüne öncelik veriyoruz.';

  @override
  String get videoRecorderUploadBodyDetail =>
      'Yaratımı uygulama içinde tutarak, içeriğin gerçek ve düzenlenmemiş olduğunu daha iyi garanti edebiliyoruz. Şu anda harici galeriden yüklemelere açmıyoruz; bu özgünlüğü korumak ve topluluğumuzu sentetik içerikten mümkün olduğunca uzak tutmak için.';

  @override
  String get videoRecorderUploadBodyCta =>
      'Gerçek bir şey çekmek için Capture veya Classic\'e geç.';

  @override
  String get videoRecorderUploadLearnMore =>
      'Doğrulamanın nasıl çalıştığını öğren';

  @override
  String get videoRecorderAutosaveFoundTitle => 'Devam eden bir çalışma bulduk';

  @override
  String get videoRecorderAutosaveFoundSubtitle =>
      'Kaldığınız yerden devam etmek ister misiniz?';

  @override
  String get videoRecorderAutosaveContinueButton => 'Evet, devam et';

  @override
  String get videoRecorderAutosaveDiscardButton => 'Hayır, yeni video başlat';

  @override
  String get videoRecorderAutosaveRestoreFailure =>
      'Taslağınız geri yüklenemedi';

  @override
  String get videoRecorderStopRecordingTooltip => 'Kaydı durdur';

  @override
  String get videoRecorderStartRecordingTooltip => 'Kaydı başlat';

  @override
  String get videoRecorderRecordingTapToStopLabel =>
      'Kaydediliyor. Durdurmak için herhangi bir yere dokunun';

  @override
  String get videoRecorderTapToStartLabel =>
      'Kaydı başlatmak için herhangi bir yere dokunun';

  @override
  String get videoRecorderDeleteLastClipLabel => 'Son klibi sil';

  @override
  String get videoRecorderSwitchCameraLabel => 'Kamerayı değiştir';

  @override
  String videoRecorderZoomLevelLabel(String zoom) {
    return '$zoom× yakınlaştır';
  }

  @override
  String get videoRecorderToggleGridLabel => 'Izgarayı değiştir';

  @override
  String get videoRecorderToggleGhostFrameLabel => 'Hayalet kareyi değiştir';

  @override
  String get videoRecorderGhostFrameEnabled => 'Hayalet kare etkin';

  @override
  String get videoRecorderGhostFrameDisabled => 'Hayalet kare devre dışı';

  @override
  String get videoRecorderClipDeletedMessage => 'Klip çöp kutusuna taşındı';

  @override
  String get videoRecorderClipUndoLabel => 'Geri al';

  @override
  String get libraryTrashEmptyTitle => 'Çöp kutusu boş';

  @override
  String get libraryTrashEmptySubtitle =>
      'Silinen klipler kalıcı olarak kaldırılmadan önce 30 gün burada tutulur.';

  @override
  String get libraryTrashRestoreLabel => 'Geri yükle';

  @override
  String get libraryTrashDeleteNowLabel => 'Şimdi sil';

  @override
  String get libraryTrashEmptyAllLabel => 'Çöp kutusunu boşalt';

  @override
  String get libraryTrashDeleteConfirmTitle => 'Klip şimdi silinsin mi?';

  @override
  String get libraryTrashDeleteConfirmMessage =>
      'Bu işlem klibi hemen çöp kutusundan kaldırır.';

  @override
  String get libraryTrashEmptyConfirmTitle => 'Çöp kutusu boşaltılsın mı?';

  @override
  String libraryTrashEmptyConfirmMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klibi',
      one: '1 klibi',
    );
    return 'Bu işlem $_temp0 hemen çöp kutusundan kalıcı olarak siler.';
  }

  @override
  String get videoRecorderCloseLabel => 'Video kaydediciyi kapat';

  @override
  String get videoRecorderContinueToEditorLabel =>
      'Video düzenleyiciye devam et';

  @override
  String get videoRecorderCameraPreviewLabel => 'Kamera önizlemesi';

  @override
  String get videoRecorderCameraPreviewFocusHint => 'Kamerayı odakla';

  @override
  String videoRecorderSwitchToModeLabel(String mode) {
    return '$mode moduna geç';
  }

  @override
  String get videoRecorderLipSyncAddAudioFirst => 'Kayıttan önce ses ekleyin';

  @override
  String get videoRecorderStopMotionAssembleFailed =>
      'Video oluşturulamadı. Tekrar deneyin.';

  @override
  String videoRecorderStopMotionShotsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count çekim kaldı',
      zero: 'Kalan çekim yok',
    );
    return '$_temp0';
  }

  @override
  String get videoRecorderToggleFlashLabel => 'Flaşı değiştir';

  @override
  String get videoRecorderCycleTimerLabel => 'Zamanlayıcıyı değiştir';

  @override
  String get videoRecorderToggleAspectRatioLabel => 'En-boy oranını değiştir';

  @override
  String get videoRecorderStabilizationLabel => 'Sabitleme';

  @override
  String get videoRecorderStabilizationModeOff => 'Kapalı';

  @override
  String get videoRecorderStabilizationModeStandard => 'Standart';

  @override
  String get videoRecorderStabilizationModeCinematic => 'Sinematik';

  @override
  String get videoRecorderStabilizationModeCinematicExtended =>
      'Sinematik Genişletilmiş';

  @override
  String get videoRecorderStabilizationModePreviewOptimized =>
      'Önizleme için optimize';

  @override
  String get videoRecorderStabilizationModeLowLatency => 'Düşük gecikme';

  @override
  String get videoRecorderStabilizationModeAuto => 'Otomatik';

  @override
  String get videoRecorderFlashValueOff => 'Kapalı';

  @override
  String get videoRecorderFlashValueOn => 'Açık';

  @override
  String get videoRecorderFlashValueAuto => 'Otomatik';

  @override
  String get videoRecorderTimerValueOff => 'Kapalı';

  @override
  String get videoRecorderTimerValueThreeSeconds => '3 saniye';

  @override
  String get videoRecorderTimerValueTenSeconds => '10 saniye';

  @override
  String get videoRecorderAspectRatioValueSquare => 'Kare';

  @override
  String get videoRecorderAspectRatioValueVertical => 'Dikey';

  @override
  String get videoRecorderCameraValueFront => 'Ön kamera';

  @override
  String get videoRecorderCameraValueBack => 'Arka kamera';

  @override
  String get videoRecorderLibraryEmptyLabel => 'Klip kütüphanesi, klip yok';

  @override
  String videoRecorderLibraryOpenLabel(int clipCount) {
    String _temp0 = intl.Intl.pluralLogic(
      clipCount,
      locale: localeName,
      other: 'Klip kütüphanesini aç, $clipCount klip',
      one: 'Klip kütüphanesini aç, 1 klip',
    );
    return '$_temp0';
  }

  @override
  String videoRecorderLibraryOpenStopMotionLabel(int frameCount) {
    String _temp0 = intl.Intl.pluralLogic(
      frameCount,
      locale: localeName,
      other: 'Stop motion kütüphanesini aç, $frameCount kare',
      one: 'Stop motion kütüphanesini aç, 1 kare',
      zero: 'Stop motion kütüphanesini aç',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorCameraLabel => 'Kamera';

  @override
  String get videoEditorOpenCameraSemanticLabel => 'Kamerayı aç';

  @override
  String get videoEditorLibraryLabel => 'Kütüphane';

  @override
  String get videoEditorTextLabel => 'Metin';

  @override
  String get videoEditorDrawLabel => 'Çiz';

  @override
  String get videoEditorFilterLabel => 'Filtre';

  @override
  String get videoEditorTuneLabel => 'Ayarla';

  @override
  String get videoEditorOpenTuneSemanticLabel => 'Ayarlar düzenleyicisini aç';

  @override
  String get videoEditorTuneBrightness => 'Parlaklık';

  @override
  String get videoEditorTuneContrast => 'Kontrast';

  @override
  String get videoEditorTuneSaturation => 'Doygunluk';

  @override
  String get videoEditorTuneExposure => 'Pozlama';

  @override
  String get videoEditorTuneHue => 'Renk tonu';

  @override
  String get videoEditorTuneTemperature => 'Sıcaklık';

  @override
  String get videoEditorTuneTint => 'Ton';

  @override
  String get videoEditorTuneFade => 'Solma';

  @override
  String get videoEditorAudioLabel => 'Ses';

  @override
  String get videoEditorAddTitle => 'Ekle';

  @override
  String get videoEditorOpenLibrarySemanticLabel => 'Kütüphaneyi aç';

  @override
  String get videoEditorOpenAudioSemanticLabel => 'Ses düzenleyiciyi aç';

  @override
  String get videoEditorCaptionsLabel => 'Altyazılar';

  @override
  String get videoEditorOpenCaptionsSemanticLabel =>
      'Altyazı düzenleyicisini aç';

  @override
  String get videoEditorCaptionsBurnInLabel => 'Videoya göm';

  @override
  String get videoEditorCaptionsPresetCustom => 'Özel';

  @override
  String get videoEditorCaptionsCustomStyleTitle => 'Özel stil';

  @override
  String get videoEditorCaptionsCustomApply => 'Uygula';

  @override
  String get videoEditorCaptionsCustomFont => 'Yazı tipi';

  @override
  String get videoEditorCaptionsCustomTextColor => 'Metin rengi';

  @override
  String get videoEditorCaptionsCustomBackground => 'Arka plan';

  @override
  String get videoEditorCaptionsCustomBackgroundColor => 'Arka plan rengi';

  @override
  String get videoEditorCaptionsCustomAnimation => 'Animasyon';

  @override
  String get videoEditorCaptionsAnimationNone => 'Yok';

  @override
  String get videoEditorCaptionsAnimationFade => 'Solma';

  @override
  String get videoEditorCaptionsAnimationPop => 'Pop';

  @override
  String get videoEditorCaptionsAnimationSpring => 'Yay';

  @override
  String get videoEditorCaptionsEditTitle => 'Altyazılar';

  @override
  String get videoEditorCaptionsGeneratingTitle => 'Dinliyoruz…';

  @override
  String get videoEditorCaptionsGeneratingSubtitle =>
      'Sesini altyazı önerilerine dönüştürüyoruz.';

  @override
  String get videoEditorCaptionsNoSpeechMessage =>
      'Hiç konuşma duyamadık. Altyazıları yine de kendin yazabilirsin.';

  @override
  String get videoEditorCaptionsUnavailableMessage =>
      'Konuşma tanıma bu cihazda kullanılamıyor. Altyazıları kendin yazabilirsin.';

  @override
  String get videoEditorCaptionsNotAuthorizedMessage =>
      'Konuşma tanımaya izin verilmiyor. Ayarlar\'dan aç ya da altyazıları kendin yaz.';

  @override
  String get videoEditorCaptionsFailedMessage =>
      'Yazıya dökme bu sefer işe yaramadı. Altyazıları kendin yazabilirsin.';

  @override
  String get videoEditorCaptionsStartEmptyButton =>
      'Altyazıları kendim yazacağım';

  @override
  String get videoEditorCaptionsAddCue => 'Altyazı ekle';

  @override
  String get videoEditorCaptionsCueTextHint => 'Altyazı metni';

  @override
  String get videoEditorCaptionsCueDeleteSemanticLabel => 'Altyazıyı sil';

  @override
  String get videoEditorCaptionsDeleteTrack => 'Tüm altyazıları kaldır';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmTitle =>
      'Altyazılar kaldırılsın mı?';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmSubtitle =>
      'Tüm metin ve zamanlamalar silinecek.';

  @override
  String get videoEditorCaptionsCloseSemanticLabel =>
      'Altyazı düzenleyicisini kapat';

  @override
  String get videoEditorCaptionsDoneSemanticLabel => 'Altyazıları onayla';

  @override
  String get videoEditorCaptionsPresetTitle => 'Altyazı stili';

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
  String get videoEditorCaptionsPresetHeadline => 'Manşet';

  @override
  String get videoEditorCaptionsPresetTypewriter => 'Daktilo';

  @override
  String get videoEditorCaptionsPresetMarker => 'Marker';

  @override
  String get videoEditorCaptionsPresetScript => 'Kaligrafi';

  @override
  String get videoEditorCaptionsPresetRetro => 'Retro';

  @override
  String get videoEditorCaptionsPresetElegant => 'Zarif';

  @override
  String get videoEditorCaptionsPresetBubble => 'Baloncuk';

  @override
  String get videoEditorCaptionsPresetNeon => 'Neon';

  @override
  String get videoEditorCaptionsPresetBold => 'Kalın';

  @override
  String get videoEditorCaptionsPresetDreamy => 'Rüya gibi';

  @override
  String get videoEditorCaptionsPresetOcean => 'Okyanus';

  @override
  String get videoEditorCaptionsPresetSunny => 'Güneşli';

  @override
  String get videoEditorCaptionsPresetHandwritten => 'El yazısı';

  @override
  String get videoEditorCaptionsPresetSerif => 'Serif';

  @override
  String get videoEditorCaptionsPresetStamp => 'Damga';

  @override
  String get videoEditorOpenTextSemanticLabel => 'Metin düzenleyiciyi aç';

  @override
  String get videoEditorOpenDrawSemanticLabel => 'Çizim düzenleyiciyi aç';

  @override
  String get videoEditorOpenFilterSemanticLabel => 'Filtre düzenleyiciyi aç';

  @override
  String get videoEditorOpenStickerSemanticLabel => 'Stiker düzenleyiciyi aç';

  @override
  String get videoEditorSaveDraftTitle => 'Taslağınızı kaydedin?';

  @override
  String get videoEditorSaveDraftSubtitle =>
      'Düzenlemelerinizi sonraya kaydedin veya atıp düzenleyiciden çıkın.';

  @override
  String get videoEditorSaveDraftButton => 'Taslağı kaydet';

  @override
  String get videoEditorDiscardChangesButton => 'Değişiklikleri sil';

  @override
  String get videoEditorKeepEditingButton => 'Düzenlemeye devam et';

  @override
  String get videoEditorDeleteLayerDropZone => 'Katman silme bırakma alanı';

  @override
  String get videoEditorReleaseToDeleteLayer => 'Katmanı silmek için bırak';

  @override
  String get videoEditorDoneLabel => 'Bitti';

  @override
  String get videoEditorPlayPauseSemanticLabel => 'Videoyu oynat veya duraklat';

  @override
  String videoEditorSplitPositionInvalid(int minDurationMs) {
    return 'Bölme konumu geçersiz. Her iki klip de en az ${minDurationMs}ms uzunluğunda olmalıdır.';
  }

  @override
  String get videoEditorSaveSelectedClip => 'Seçili klibi kaydet';

  @override
  String get videoEditorSaveClip => 'Klibi kaydet';

  @override
  String get videoEditorClipSavedSuccess => 'Klip kütüphaneye kaydedildi';

  @override
  String get videoEditorClipSaveFailed => 'Klip kaydedilemedi';

  @override
  String get videoEditorColorPickerSemanticLabel => 'Renk seçici';

  @override
  String get videoEditorUndoSemanticLabel => 'Geri al';

  @override
  String get videoEditorRedoSemanticLabel => 'Yinele';

  @override
  String get videoEditorTextColorSemanticLabel => 'Metin rengi';

  @override
  String get videoEditorTextAlignmentSemanticLabel => 'Metin hizalama';

  @override
  String get videoEditorTextBackgroundSemanticLabel => 'Metin arka planı';

  @override
  String get videoEditorFontSemanticLabel => 'Yazı tipi';

  @override
  String get videoEditorNoStickersFound => 'Çıkartma bulunamadı';

  @override
  String get videoEditorNoStickersAvailable => 'Kullanılabilir çıkartma yok';

  @override
  String get videoEditorFailedLoadStickers => 'Çıkartmalar yüklenemedi';

  @override
  String get videoEditorVoiceOverLabel => 'Dış ses';

  @override
  String videoEditorVoiceOverTakeName(int number) {
    return 'Kayıt $number';
  }

  @override
  String get videoEditorOpenVoiceOverSemanticLabel => 'Dış ses kaydet';

  @override
  String get videoEditorVoiceOverRecordSemanticLabel => 'Kaydı başlat';

  @override
  String get videoEditorVoiceOverStopSemanticLabel => 'Kaydı durdur';

  @override
  String get videoEditorVoiceOverHint =>
      'Kaydetmek için dokun. İstediğin kadar çekim ekle.';

  @override
  String videoEditorVoiceOverRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kayıt',
      one: '1 kayıt',
      zero: 'Henüz kayıt yok',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorVoiceOverDeleteLast => 'Son kaydı sil';

  @override
  String get videoEditorVoiceOverPermissionTitle => 'Mikrofon erişimi gerekli';

  @override
  String get videoEditorVoiceOverPermissionBody =>
      'Dış ses kaydetmek için mikrofon erişimine izin ver.';

  @override
  String get videoEditorVoiceOverOpenSettings => 'Ayarları aç';

  @override
  String get videoEditorVoiceOverRecordingStarted => 'Kayıt başladı';

  @override
  String get videoEditorVoiceOverRecordingSaved => 'Kayıt kaydedildi';

  @override
  String get videoEditorVoiceOverTooLong => 'Kayıt videonuzdan daha uzun';

  @override
  String get videoEditorPlaySemanticLabel => 'Oynat';

  @override
  String get videoEditorPauseSemanticLabel => 'Duraklat';

  @override
  String get videoEditorVolumeSemanticLabel => 'Sesi ayarla';

  @override
  String videoEditorTimelineVolumePreview(int percent) {
    return 'Ses seviyesi $percent%';
  }

  @override
  String get videoEditorTimelineSlideToAdjust => 'Ayarlamak için kaydır';

  @override
  String get videoEditorChromaKeyLabel => 'Yeşil perde';

  @override
  String get videoEditorChromaKeyTitle => 'Yeşil perde';

  @override
  String get videoEditorChromaKeySemanticLabel =>
      'Bu klip için yeşil perdeyi ayarla';

  @override
  String get videoEditorChromaKeyCloseSemanticLabel =>
      'Yeşil perde değişikliklerini iptal et';

  @override
  String get videoEditorChromaKeyDoneSemanticLabel => 'Yeşil perdeyi uygula';

  @override
  String get videoEditorChromaKeyAutoDetect => 'Otomatik algıla';

  @override
  String get videoEditorChromaKeyPresetGreen => 'Yeşil';

  @override
  String get videoEditorChromaKeyPresetBlue => 'Mavi';

  @override
  String get videoEditorChromaKeyScreenColorLabel => 'Perde rengi';

  @override
  String get videoEditorChromaKeyAmountLabel => 'Miktar';

  @override
  String get videoEditorChromaKeyAmountHint =>
      'Perde renginin ne kadarı kaybolacak';

  @override
  String get videoEditorChromaKeyEdgeLabel => 'Kenar';

  @override
  String get videoEditorChromaKeyEdgeHint =>
      'Kesiti yumuşatır, saçlar tırtıklı çıkmaz';

  @override
  String get videoEditorChromaKeySpillLabel => 'Renk taşması';

  @override
  String get videoEditorChromaKeySpillHint =>
      'Perdenin rengini öznenin üzerinden çeker';

  @override
  String get videoEditorChromaKeyBackgroundLabel => 'Şununla değiştir';

  @override
  String get videoEditorChromaKeyBackgroundNone => 'Hiçbir şey';

  @override
  String get videoEditorChromaKeyBackgroundColor => 'Renk';

  @override
  String get videoEditorChromaKeyBackgroundImage => 'Görsel';

  @override
  String get videoEditorChromaKeyBackgroundVideo => 'Klip';

  @override
  String get videoEditorChromaKeyTransparentHint =>
      'Video saydamlık tutamaz, bu yüzden dışa aktarımda siyah olur.';

  @override
  String get videoEditorChromaKeyDetectFailed =>
      'Perde bulunamadı. Karenin kenarlarına kadar ulaşması gerekir — yoksa rengi elle seç.';

  @override
  String get videoEditorChromaKeyPickClipTitle => 'Bir klip seç';

  @override
  String get videoEditorChromaKeyNoLibraryClips =>
      'Kitaplığın boş. Önce bir klip kaydet, sonra onu arka plan olarak kullan.';

  @override
  String get videoEditorChromaKeyImagePickFailed => 'Bu görsel yüklenemedi.';

  @override
  String get videoEditorChromaKeyRemove => 'Yeşil perdeyi kaldır';

  @override
  String get videoEditorChromaKeyFailed =>
      'Yeşil perde uygulanamadı. Klibin değişmedi.';

  @override
  String get videoEditorChromaKeyRemoveFailed =>
      'Yeşil perde kaldırılamadı. Klibin değişmedi.';

  @override
  String get videoEditorChromaKeyApplying => 'Yeşil perde uygulanıyor…';

  @override
  String get videoEditorChromaKeyPreviewUnavailable =>
      'Bu cihaz canlı önizlemeyi gösteremiyor. Ayarların dışa aktarımda yine de geçerli.';

  @override
  String videoEditorClipVolumeLabel(int index) {
    return 'Klip $index';
  }

  @override
  String get videoEditorDeleteLabel => 'Sil';

  @override
  String get videoEditorDeleteSelectedItemSemanticLabel => 'Seçili öğeyi sil';

  @override
  String get videoEditorStopMotionFramesPerImageLabel => 'Görüntü başına kare';

  @override
  String videoEditorStopMotionFramesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kare',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorStopMotionFramesPerImageButtonLabel => 'Kare';

  @override
  String videoEditorStopMotionFramesPerImageValueSemanticLabel(int count) {
    return 'Görüntü başına $count kare';
  }

  @override
  String videoEditorStopMotionFrameSemanticLabel(int position, int total) {
    return 'Stop motion karesi $position/$total';
  }

  @override
  String get videoEditorEditLabel => 'Düzenle';

  @override
  String get videoEditorEditSelectedItemSemanticLabel => 'Seçili öğeyi düzenle';

  @override
  String get videoEditorDuplicateLabel => 'Çoğalt';

  @override
  String get videoEditorDuplicateSelectedItemSemanticLabel =>
      'Seçili öğeyi çoğalt';

  @override
  String get videoEditorCombineLabel => 'Birleştir';

  @override
  String get videoEditorCombineDrawLayersSemanticLabel =>
      'Seçili çizimleri tek katmanda birleştir';

  @override
  String get videoEditorSplitLabel => 'Böl';

  @override
  String get videoEditorSplitSelectedClipSemanticLabel => 'Seçili klibi böl';

  @override
  String get videoEditorExtractAudioLabel => 'Sesi çıkar';

  @override
  String get videoEditorClipAudioTitle => 'Klip sesi';

  @override
  String get videoEditorExtractAudioFromClipSemanticLabel =>
      'Klipten sesi çıkar ve orijinali sessize al';

  @override
  String get videoEditorExtractAudioNoLocalFile =>
      'Ses çıkarılamıyor: klip yerel olarak kullanılamıyor.';

  @override
  String get videoEditorExtractAudioFailed =>
      'Ses çıkarılamadı. Lütfen tekrar deneyin.';

  @override
  String get videoEditorSpeedLabel => 'Hız';

  @override
  String get videoEditorSetClipSpeedSemanticLabel =>
      'Seçili klip için oynatma hızını ayarla';

  @override
  String get videoEditorReverseLabel => 'Tersine Çevir';

  @override
  String get videoEditorReverseClipSemanticLabel =>
      'Seçili klip için ters oynatmayı aç veya kapat';

  @override
  String get videoEditorReverseProgressLabel =>
      'Bir saniye, klibini tersine çeviriyoruz';

  @override
  String get videoEditorTransformLabel => 'Dönüştür';

  @override
  String get videoEditorTransformSelectedClipSemanticLabel =>
      'Seçili klibi kırp, döndür veya çevir';

  @override
  String get videoEditorTransformProgressLabel =>
      'Bir saniye, klibini dönüştürüyoruz';

  @override
  String get videoEditorTransformFailed =>
      'Klip dönüştürülemedi. Lütfen tekrar deneyin.';

  @override
  String get videoEditorTransformNoLocalFile =>
      'Dönüştürülemiyor: klip yerel olarak mevcut değil.';

  @override
  String get videoEditorTransformSelectedFrameSemanticLabel =>
      'Seçili kareyi kırp, döndür veya çevir';

  @override
  String get videoEditorTransformFrameProgressLabel =>
      'Bir saniye, kareni dönüştürüyoruz';

  @override
  String get videoEditorTransformFrameFailed =>
      'Kare dönüştürülemedi. Lütfen tekrar dene.';

  @override
  String get videoEditorTransformRotateLabel => 'Döndür';

  @override
  String get videoEditorTransformFlipLabel => 'Çevir';

  @override
  String get videoEditorTransformResetLabel => 'Sıfırla';

  @override
  String get videoEditorTransformApplySemanticLabel => 'Dönüşümü uygula';

  @override
  String get videoEditorTransformCancelSemanticLabel => 'Dönüşümü iptal et';

  @override
  String get videoEditorTransformPlayLabel => 'Oynat';

  @override
  String get videoEditorTransformPauseLabel => 'Duraklat';

  @override
  String get videoEditorReverseNoLocalFile =>
      'Tersine çevrilemiyor: klip yerel olarak kullanılamıyor.';

  @override
  String get videoEditorReverseFailed =>
      'Klip tersine çevrilemedi. Lütfen tekrar deneyin.';

  @override
  String get videoEditorSpeedSheetTitle => 'Klip Hızı';

  @override
  String get videoEditorTransitionSheetTitle => 'Geçiş';

  @override
  String get videoEditorTransitionNone => 'Yok';

  @override
  String get videoEditorTransitionDissolve => 'Erime';

  @override
  String get videoEditorTransitionFadeToBlack => 'Siyaha solma';

  @override
  String get videoEditorTransitionFadeToWhite => 'Beyaza solma';

  @override
  String get videoEditorTransitionSlide => 'Kaydırma';

  @override
  String get videoEditorTransitionPush => 'İtme';

  @override
  String get videoEditorTransitionWipe => 'Silme';

  @override
  String get videoEditorTransitionButtonSemanticLabel => 'Geçişi düzenle';

  @override
  String get videoEditorLoopTransitionSheetTitle => 'Döngü geçişi';

  @override
  String get videoEditorLoopTransitionButtonSemanticLabel =>
      'Döngü geçişini düzenle';

  @override
  String get videoEditorTransitionDuration => 'Süre';

  @override
  String get videoEditorTransitionDurationLimitedHint =>
      'Komşu geçişle çakışmaması için kısaltıldı.';

  @override
  String get videoEditorTransitionCurve => 'Eğri';

  @override
  String get videoEditorTransitionDirection => 'Yön';

  @override
  String get videoEditorTransitionDirectionLeft => 'Sol';

  @override
  String get videoEditorTransitionDirectionRight => 'Sağ';

  @override
  String get videoEditorTransitionDirectionUp => 'Yukarı';

  @override
  String get videoEditorTransitionDirectionDown => 'Aşağı';

  @override
  String videoEditorTransitionCurveOptionSemanticLabel(int number) {
    return 'Animasyon eğrisi $number';
  }

  @override
  String get videoEditorLayerAnimationLabel => 'Animasyon';

  @override
  String get videoEditorLayerAnimationButtonSemanticLabel =>
      'Katman animasyonunu düzenle';

  @override
  String get videoEditorLayerAnimationEnter => 'Giriş';

  @override
  String get videoEditorLayerAnimationLeave => 'Çıkış';

  @override
  String get videoEditorLayerAnimationFade => 'Solma';

  @override
  String get videoEditorLayerAnimationScale => 'Ölçek';

  @override
  String get videoEditorLayerAnimationScaleFrom => 'Ölçek başlangıcı';

  @override
  String get videoEditorFinishTimelineEditingSemanticLabel =>
      'Zaman çizelgesi düzenlemeyi bitir';

  @override
  String get videoEditorAudioPlayPreviewSemanticLabel => 'Önizlemeyi oynat';

  @override
  String get videoEditorAudioPausePreviewSemanticLabel => 'Önizlemeyi duraklat';

  @override
  String get videoEditorAudioUntitledSound => 'Başlıksız ses';

  @override
  String get videoEditorAudioUntitled => 'Başlıksız';

  @override
  String get videoEditorAudioAddAudio => 'Ses ekle';

  @override
  String get videoEditorAudioNoSoundsAvailableTitle => 'Kullanılabilir ses yok';

  @override
  String get videoEditorAudioNoSoundsAvailableSubtitle =>
      'İçerik üreticileri ses paylaştığında burada görünür';

  @override
  String get videoEditorAudioFailedToLoadTitle => 'Sesler yüklenemedi';

  @override
  String get videoEditorAudioSegmentInstruction =>
      'Videon için ses bölümünü seç';

  @override
  String get videoEditorAudioCategoryDivine => 'Divine';

  @override
  String get videoEditorAudioCategoryCommunity => 'Topluluk';

  @override
  String get videoEditorAudioCategoryFeatured => 'Öne çıkanlar';

  @override
  String get videoEditorAudioCategoryMySounds => 'Seslerim';

  @override
  String get videoEditorDrawToolArrowSemanticLabel => 'Ok aracı';

  @override
  String get videoEditorDrawToolEraserSemanticLabel => 'Silgi aracı';

  @override
  String get videoEditorDrawToolMarkerSemanticLabel => 'İşaretleyici aracı';

  @override
  String get videoEditorDrawToolPencilSemanticLabel => 'Kalem aracı';

  @override
  String get videoEditorShowTimelineSemanticLabel => 'Zaman çizelgesini göster';

  @override
  String get videoEditorHideTimelineSemanticLabel => 'Zaman çizelgesini gizle';

  @override
  String get videoEditorFeedPreviewContent =>
      'Bu alanların arkasına içerik yerleştirmekten kaçının.';

  @override
  String get videoEditorStickersDivineOriginals => 'Divine Orijinaller';

  @override
  String get videoEditorStickerSearchHint => 'Çıkartma ara...';

  @override
  String get videoEditorSelectFontSemanticLabel => 'Yazı tipi seç';

  @override
  String get videoEditorFontUnknown => 'Bilinmiyor';

  @override
  String get videoEditorSplitPlayheadOutsideClip =>
      'Bölmek için oynatma kafası seçili klip içinde olmalıdır.';

  @override
  String get videoEditorTimelineTrimStartSemanticLabel => 'Başlangıcı kırp';

  @override
  String get videoEditorTimelineTrimEndSemanticLabel => 'Sonu kırp';

  @override
  String get videoEditorTimelineTrimClipSemanticLabel => 'Klibi kırp';

  @override
  String get videoEditorTimelineTrimClipHint =>
      'Klip süresini ayarlamak için tutamaçları sürükleyin';

  @override
  String videoEditorTimelineDraggingClipSemanticLabel(int index) {
    return '$index. klip sürükleniyor';
  }

  @override
  String videoEditorTimelineClipSemanticLabel(
    int index,
    int total,
    String duration,
  ) {
    return '$total klipten $index. klip, $duration saniye';
  }

  @override
  String get videoEditorTimelineClipReorderHint =>
      'Yeniden sıralamak için uzun basın';

  @override
  String get videoEditorTimelineClipMoveLeft => 'Sola taşı';

  @override
  String get videoEditorTimelineClipMoveRight => 'Sağa taşı';

  @override
  String videoEditorTimelineClipSelectedSemanticLabel(int index, int total) {
    return 'Klip $index/$total, seçili';
  }

  @override
  String videoEditorTimelineClipUnselectedSemanticLabel(int index, int total) {
    return 'Klip $index/$total, seçili değil';
  }

  @override
  String get videoEditorMultiSelectLabel => 'Seç';

  @override
  String get videoEditorMultiSelectSemanticLabel => 'Birden çok klip seç';

  @override
  String get videoEditorMultiSelectDoneSemanticLabel => 'Seçimi tamamla';

  @override
  String videoEditorMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klip seçildi',
      one: '1 klip seçildi',
      zero: 'Hiç klip seçilmedi',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorLayerMultiSelectSemanticLabel =>
      'Birden fazla çizim seç';

  @override
  String get videoEditorLayerMultiSelectDoneSemanticLabel =>
      'Çizim seçimini bitir';

  @override
  String get videoEditorDeleteSelectedDrawingsSemanticLabel =>
      'Seçili çizimleri sil';

  @override
  String videoEditorLayerMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count çizim seçildi',
      one: '1 çizim seçildi',
      zero: 'Hiç çizim seçilmedi',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorMergeLabel => 'Birleştir';

  @override
  String get videoEditorMergeSelectedClipsSemanticLabel =>
      'Seçili klipleri birleştir';

  @override
  String get videoEditorDeleteSelectedClipsSemanticLabel =>
      'Seçili klipleri sil';

  @override
  String get videoEditorDeleteSelectedFramesSemanticLabel =>
      'Seçili kareleri sil';

  @override
  String get videoEditorReverseSelectedFramesSemanticLabel =>
      'Seçili kareleri ters çevir';

  @override
  String get videoEditorDuplicateSelectedFramesSemanticLabel =>
      'Seçili kareleri çoğalt';

  @override
  String videoEditorStopMotionTooShortSnackbar(int seconds) {
    return 'Videon en az ${seconds}sn olmalı — birkaç kare daha çek.';
  }

  @override
  String get videoEditorMergeProgressLabel =>
      'Bir saniye, kliplerini birleştiriyoruz';

  @override
  String get videoEditorMergeFailed =>
      'Klipler birleştirilemedi. Lütfen tekrar dene.';

  @override
  String get videoEditorTimelineLongPressToDragHint =>
      'Sürüklemek için uzun basın';

  @override
  String get videoEditorVideoTimelineSemanticLabel => 'Video zaman çizelgesi';

  @override
  String videoEditorTimelinePositionFormat(int minutes, String seconds) {
    return '${minutes}d ${seconds}s';
  }

  @override
  String videoEditorColorSelectedSemanticLabel(String colorName) {
    return '$colorName, seçildi';
  }

  @override
  String get videoEditorCloseColorPickerSemanticLabel => 'Renk seçiciyi kapat';

  @override
  String get videoEditorPickColorTitle => 'Renk seç';

  @override
  String get videoEditorConfirmColorSemanticLabel => 'Rengi onayla';

  @override
  String get videoEditorSaturationBrightnessSemanticLabel =>
      'Doygunluk ve parlaklık';

  @override
  String videoEditorSaturationBrightnessValue(int saturation, int brightness) {
    return 'Doygunluk $saturation%, Parlaklık $brightness%';
  }

  @override
  String get videoEditorHueSemanticLabel => 'Ton';

  @override
  String get videoEditorAddElementSemanticLabel => 'Öğe ekle';

  @override
  String get videoEditorDoneSemanticLabel => 'Bitti';

  @override
  String get videoEditorLevelSemanticLabel => 'Seviye';

  @override
  String get videoMetadataClosePostDetailsSemanticLabel =>
      'Gönderi ayrıntılarını kapat';

  @override
  String get videoMetadataDismissHelpDialogSemanticLabel =>
      'Yardım iletişim kutusunu kapat';

  @override
  String get videoMetadataGotItButton => 'Anladım!';

  @override
  String get videoMetadataLimitReachedWarning =>
      '64KB sınırına ulaşıldı. Devam etmek için bazı içerikleri kaldırın.';

  @override
  String get videoMetadataExpirationLabel => 'Son kullanma tarihi';

  @override
  String get videoMetadataSelectExpirationSemanticLabel =>
      'Son kullanma zamanını seç';

  @override
  String get videoMetadataTitleLabel => 'Başlık';

  @override
  String get videoMetadataDescriptionLabel => 'Açıklama';

  @override
  String get videoMetadataTagsLabel => 'Etiketler';

  @override
  String videoMetadataDeleteTagHint(String tag) {
    return '$tag etiketini sil';
  }

  @override
  String get videoMetadataContentWarningLabel => 'İçerik Uyarısı';

  @override
  String get videoMetadataSelectContentWarningsSemanticLabel =>
      'İçerik uyarılarını seç';

  @override
  String get videoMetadataContentWarningSelectAllThatApply =>
      'İçeriğinize uyanların hepsini seçin';

  @override
  String get videoMetadataAudioReuseSubtitle =>
      'Başkalarının bu videonun sesini kaydedip yeniden kullanmasına izin ver.';

  @override
  String get publishAudioReuseDegradedWarning =>
      'Videon yayında ama ses yayınlanmadı. Sesi paylaşmak için videoyu düzenle.';

  @override
  String get videoMetadataCollaboratorsLabel => 'Ortak çalışanlar';

  @override
  String get videoMetadataAddCollaboratorSemanticLabel => 'Ortak çalışan ekle';

  @override
  String get videoMetadataMutualFollowersSearchText => 'Karşılıklı takipçiler';

  @override
  String get videoMetadataInspiredByLabel => 'İlham kaynağı';

  @override
  String get videoMetadataSetInspiredBySemanticLabel =>
      'İlham kaynağını ayarla';

  @override
  String get videoMetadataCreatorCannotBeReferencedSnackbar =>
      'Bu içerik üreticisi referans alınamaz.';

  @override
  String get videoMetadataPostDetailsTitle => 'Gönderi ayrıntıları';

  @override
  String get videoMetadataSavedToLibrarySnackbar => 'Kütüphaneye kaydedildi';

  @override
  String get videoMetadataFailedToSaveSnackbar => 'Kaydedilemedi';

  @override
  String get videoMetadataGoToLibraryButton => 'Kütüphaneye git';

  @override
  String get videoMetadataSaveForLaterSemanticLabel => 'Sonra kaydet düğmesi';

  @override
  String get videoMetadataSavingVideoHint => 'Video kaydediliyor...';

  @override
  String videoMetadataSaveToDraftsHint(String destination) {
    return 'Videoyu taslağa ve $destination\'a kaydet';
  }

  @override
  String videoMetadataSaveToDraftsWithoutGalleryHint(String destination) {
    return 'Videoyu taslaklara kaydet. Henüz işlenmiş video yok, bu yüzden $destination içine kopya eklenmez.';
  }

  @override
  String get videoMetadataSaveForLaterButton => 'Sonra Kaydet';

  @override
  String get videoMetadataPostSemanticLabel => 'Paylaş düğmesi';

  @override
  String get videoMetadataPublishVideoHint => 'Videoyu akışa yayınla';

  @override
  String get videoMetadataShareReplyToFeedTitle => 'Akışımda da paylaş';

  @override
  String get videoMetadataShareReplyToFeedSubtitle =>
      'Kapalı olduğunda bu video yalnızca yorum dizisinde kalır.';

  @override
  String get videoMetadataFormNotReadyHint =>
      'Etkinleştirmek için formu doldurun';

  @override
  String get videoMetadataPostButton => 'Paylaş';

  @override
  String get videoMetadataOpenPreviewSemanticLabel =>
      'Gönderi önizleme ekranını aç';

  @override
  String get videoMetadataShareTitle => 'Paylaş';

  @override
  String get videoMetadataVideoDetailsSubtitle => 'Video ayrıntıları';

  @override
  String get videoMetadataClassicDoneButton => 'Bitti';

  @override
  String get videoMetadataPlayPreviewSemanticLabel => 'Önizlemeyi oynat';

  @override
  String get videoMetadataPausePreviewSemanticLabel => 'Önizlemeyi duraklat';

  @override
  String get videoMetadataClosePreviewSemanticLabel =>
      'Video önizlemesini kapat';

  @override
  String get videoMetadataRemoveSemanticLabel => 'Kaldır';

  @override
  String get fullscreenFeedRemovedMessage => 'Video kaldırıldı';

  @override
  String get fullscreenFeedEmptyMessage =>
      'Burada oynatılacak başka bir şey yok';

  @override
  String get settingsBadgesTitle => 'Rozetler';

  @override
  String get settingsBadgesSubtitle =>
      'Ödülleri kabul et ve verilen rozet durumunu kontrol et.';

  @override
  String get badgesTitle => 'Rozetler';

  @override
  String get badgesLoadError => 'Rozetler yüklenemedi';

  @override
  String get badgesUpdateError => 'Rozet güncellenemedi';

  @override
  String get badgesAwardedEmptyTitle => 'Henüz rozet ödülü yok';

  @override
  String get badgesAwardedEmptySubtitle =>
      'Biri sana bir Nostr rozeti verdiğinde burada görünecek.';

  @override
  String get badgesStatusAccepted => 'Kabul edildi';

  @override
  String get badgesStatusNotAccepted => 'Kabul edilmedi';

  @override
  String get badgesActionRemove => 'Kaldır';

  @override
  String get badgesActionAccept => 'Kabul Et';

  @override
  String get badgesActionReject => 'Reddet';

  @override
  String get badgesIssuedEmptyTitle => 'Henüz verilmiş rozet yok';

  @override
  String get badgesIssuedEmptySubtitle =>
      'Verdiğin rozetlerin kabul durumu burada görünecek.';

  @override
  String get badgesIssuedNoRecipients => 'Bu ödül için alıcı bulunamadı.';

  @override
  String get badgesRecipientAcceptedStatus => 'Alıcı tarafından kabul edildi';

  @override
  String get badgesRecipientWaitingStatus => 'Alıcı bekleniyor';

  @override
  String badgesHiddenSectionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Gizli ($count)',
      one: 'Gizli (1)',
    );
    return '$_temp0';
  }

  @override
  String get badgesActionRestore => 'Geri getir';

  @override
  String get badgesHiddenSnackbar => 'Rozet gizlendi';

  @override
  String get badgesHiddenSnackbarUndo => 'Geri al';

  @override
  String get badgesTabAwarded => 'Alınan';

  @override
  String get badgesTabCreated => 'Oluşturulan';

  @override
  String get badgesTabIssued => 'Verilen';

  @override
  String get badgesCreateAction => 'Yeni rozet';

  @override
  String get badgesCreatedEmptyTitle => 'Henüz rozet yapmadın';

  @override
  String get badgesCreatedEmptySubtitle =>
      'Bir tane yap ve hak eden birine ver.';

  @override
  String badgesCreatedAwardSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kişiye verildi',
      one: '1 kişiye verildi',
      zero: 'Henüz verilmedi',
    );
    return '$_temp0';
  }

  @override
  String get badgeEditorCreateTitle => 'Yeni rozet';

  @override
  String get badgeEditorEditTitle => 'Rozeti düzenle';

  @override
  String get badgeEditorNameLabel => 'Ad';

  @override
  String get badgeEditorNameHint => 'Sahne Hırsızı';

  @override
  String get badgeEditorIdentifierLabel => 'Tanımlayıcı';

  @override
  String get badgeEditorIdentifierHelp =>
      'Rozetin adresinin bir parçası, o yüzden rozet oluştuktan sonra değişmez.';

  @override
  String get badgeEditorIdentifierTaken =>
      'Bu tanımlayıcıyla zaten bir rozetin var. Onu düzenle — burada yayınlamak onun yerine geçer.';

  @override
  String get badgeEditorIdentifierRequired =>
      'Her rozetin bir tanımlayıcısı olmalı — ad doldurmadıysa kendin yaz.';

  @override
  String get badgeEditorDescriptionLabel => 'Açıklama';

  @override
  String get badgeEditorDescriptionHint =>
      'Tek bir loop\'la sahneyi çalan kişi için.';

  @override
  String get badgeEditorArtworkLabel => 'Görsel';

  @override
  String get badgeEditorArtworkAdd => 'Görsel ekle';

  @override
  String get badgeEditorArtworkReplace => 'Değiştir';

  @override
  String get badgeEditorArtworkError => 'Bu görsel yüklenemedi';

  @override
  String get badgeEditorArtworkRequired => 'Her rozetin bir görseli olmalı.';

  @override
  String get badgeEditorArtworkRemove => 'Görseli kaldır';

  @override
  String get badgeEditorArtworkSheetTitle => 'Rozet görseli';

  @override
  String get badgeDetailDeleteAction => 'Rozeti sil';

  @override
  String get badgeDetailDeleteTitle => 'Bu rozet silinsin mi?';

  @override
  String get badgeDetailDeleteBody =>
      'Bu, relaylerden rozeti ve senin verdiğin tüm ödülleri kaldırmalarını ister. Relayler reddedebilir, rozeti profiline sabitleyenler ise kendileri kaldırana kadar tutmaya devam eder.';

  @override
  String get badgeDetailDeleteConfirm => 'Sil';

  @override
  String get badgeEditorSaveAction => 'Rozeti yayınla';

  @override
  String get badgeEditorSaveError => 'Rozet yayınlanamadı';

  @override
  String get badgeEditorLoadError => 'Bu rozet yüklenemedi';

  @override
  String get badgeDetailTitle => 'Rozet';

  @override
  String get badgeDetailMadeBy => 'Yapan';

  @override
  String get badgeDetailRecipientsTitle => 'Verildiği kişiler';

  @override
  String get badgeDetailNoRecipients => 'Bu rozet henüz kimsede yok.';

  @override
  String get badgeDetailAwardAction => 'Bu rozeti ver';

  @override
  String get badgeDetailEditAction => 'Rozeti düzenle';

  @override
  String get badgeDetailShareAction => 'Paylaş';

  @override
  String badgeDetailShareMessage(String link) {
    return 'Divine\'da bu rozete bak: $link';
  }

  @override
  String get badgeDetailRevokeAction => 'Rozeti geri al';

  @override
  String get badgeDetailRevokeTitle => 'Bu rozet geri alınsın mı?';

  @override
  String get badgeDetailRevokeBody =>
      'Bu, relaylerden bu kişiye verdiğin ödülü kaldırmalarını ister. Relayler reddedebilir, rozeti profiline sabitlediyse kendisi kaldırana kadar orada kalır. Her hâlükârda kendisine bildirim gitmez.';

  @override
  String get badgeDetailRevokeSelfBody =>
      'Bu, relaylerden kendine verdiğin ödülü kaldırmalarını ister ve rozeti profilinden alır. Relayler silmeyi reddederse hiçbir şey değişmez.';

  @override
  String get badgeDetailRevokeConfirm => 'Geri al';

  @override
  String get badgeDetailRevokeSuccess => 'Rozet geri alındı';

  @override
  String get badgeDetailBlockClaimantsAction => 'Rozeti taşıyanları engelle';

  @override
  String get badgeDetailBlockClaimantsTitle => 'Rozeti taşıyanları engelle';

  @override
  String get badgeDetailBlockClaimantsLoadError =>
      'Bu rozeti taşıyanlar yüklenemedi';

  @override
  String get badgeDetailBlockClaimantsEmptyTitle =>
      'Şu anda bu rozeti taşıyan yok';

  @override
  String get badgeDetailBlockClaimantsEmptyBody =>
      'Şu anda engellenecek kimse bulamadık.';

  @override
  String badgeDetailBlockClaimantsHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hesap engellensin mi?',
      one: '1 hesap engellensin mi?',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Bu, şu anda bu rozeti taşıyan $count hesabı engeller. Gönderileri akışında görünmez ve bu değişiklik hakkında bilgilendirilmezler.',
      one:
          'Bu, şu anda bu rozeti taşıyan hesabı engeller. Gönderileri akışında görünmez ve bu değişiklik hakkında bilgilendirilmez.',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hesabı engelle',
      one: '1 hesabı engelle',
    );
    return '$_temp0';
  }

  @override
  String get badgeDetailBlockClaimantsSuccess => 'Rozeti taşıyanlar engellendi';

  @override
  String get badgeDetailBlockClaimantsFailure =>
      'Rozeti taşıyanlar engellenemedi';

  @override
  String get badgeDetailLoadError => 'Bu rozet yüklenemedi';

  @override
  String get badgeDetailMissing => 'Bu rozeti hiçbir relayde bulamadık.';

  @override
  String get badgeDetailActionError => 'Bu işlem gerçekleşmedi';

  @override
  String get badgeAwardTitle => 'Rozet ver';

  @override
  String get badgeAwardPickAction => 'Kişi seç';

  @override
  String get badgeAwardManualLabel => 'Ya da anahtar yapıştır';

  @override
  String get badgeAwardManualHint => 'npub1…, npub1…';

  @override
  String get badgeAwardEmptyHint => 'En az bir kişi seç.';

  @override
  String badgeAwardSubmitAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kişiye ver',
      one: '1 kişiye ver',
      zero: 'Rozeti ver',
    );
    return '$_temp0';
  }

  @override
  String get profileBadgeAwardedBy => 'Veren';

  @override
  String get profileBadgeRecipients => 'Alanlar';

  @override
  String profileBadgeMoreRecipients(int count) {
    return '+$count kişi daha';
  }

  @override
  String profileBadgeSemanticLabel(String name) {
    return '$name rozeti';
  }

  @override
  String get profileBadgeFallbackSemanticLabel => 'Rozet';

  @override
  String get profileBadgeFooterBody =>
      'Rozetler, Nostr\'da herkesin oluşturabileceği küçük ödüllerdir. Bir arkadaşına, bir içerik üreticisine ya da gününü güzelleştiren birine ver.';

  @override
  String get profileBadgeFooterLink => 'Kendi rozetini yap';

  @override
  String get minorAccountReviewWelcomePageTitle => 'Aile rehberi';

  @override
  String get minorAccountReviewWelcomeTitle =>
      'Henüz 16 değil misin? Sorun değil.';

  @override
  String get minorAccountReviewWelcomeBody =>
      'Seni içeri alacak cevabı seçmek yerine bu sayfaya kadar gelmiş olman önemli. Dürüstlüğü, karakteri ve çevrendeki insanlara gerçek bir özeni gösteriyor.\n\n16 yaşın altındakiler için kurallar yaşadığın yere göre değişiyor. Divine olarak ailelerin bunu birlikte konuşmasını ve sağlıklı sosyal medya kullanımının nasıl olduğuna birlikte karar vermesini istiyoruz.';

  @override
  String get minorAccountReviewModerationTitle => 'Bir adım daha gerekiyor';

  @override
  String get minorAccountReviewModerationBody =>
      'Bu hesabın 16 yaşından küçük birine ait olabileceği için daha yakından bakmamız istendi. Bu akış sonraki adımları özel tutar ve yaşına uygun yolu gösterir.';

  @override
  String get minorAccountReviewRulesTitle => 'Kurallar her yerde aynı değil';

  @override
  String get minorAccountReviewRulesBody =>
      'Farklı ülkeler ve bölgeler gençlerin sosyal medya kullanımına farklı yaklaşıyor. Bu yüzden ailelerden biraz yavaşlamalarını, bilgileri kontrol etmelerini ve sonraki adımı birlikte seçmelerini istiyoruz.';

  @override
  String get minorAccountReviewApproachTitle => 'Divine bu konuda ne düşünüyor';

  @override
  String get minorAccountReviewApproachBody =>
      'Sağlıklı teknoloji alışkanlıklarının; durup düşünmekten ve dikkati daha iyi şeylere yöneltmekten geldiğine inanıyoruz, çocukları gözetlemekten ya da ebeveynleri bekçiye dönüştürmekten değil. Araştırmalar da bunu destekliyor.';

  @override
  String get minorAccountReviewLearnMoreTitle => 'Aileler için daha fazlası';

  @override
  String get minorAccountReviewKidsPolicyCta =>
      'Divine\'ın çocuk politikasını oku';

  @override
  String get minorAccountReviewChooseAgeBandTitle => 'Sana uyan yolu seç';

  @override
  String get minorAccountReviewUnder13Cta => '13 yaş altı';

  @override
  String get minorAccountReviewTeenCta => '13-15 yaş';

  @override
  String get minorAccountReviewFamilyResourcesBody =>
      'Gençlerin sosyal medyayı daha güvenli kullanmasına yardımcı olacak pratik ipuçları, konuşma araçları ve kaynaklar için Divine aile rehberine göz at.';

  @override
  String get minorAccountReviewFamilyResourcesCta =>
      'Aile rehberlerini ve ipuçlarını al';

  @override
  String get minorAccountReviewFooter =>
      '16 yaşında veya daha büyüksen ve buraya yanlışlıkla geldiysen, gerçek bir kişinin incelemesi için Divine desteğiyle iletişime geç.';

  @override
  String get minorAccountReviewTitle => 'Hesap incelemesi';

  @override
  String get minorAccountReviewCheckingStatusTitle =>
      'Hesap durumu kontrol ediliyor...';

  @override
  String get minorAccountReviewCheckingStatusBody =>
      'Bu hesabın mevcut inceleme durumunu doğrularken lütfen bekle.';

  @override
  String get minorAccountReviewDefaultTitle => 'Hesap incelemesi gerekli';

  @override
  String get minorAccountReviewDefaultBody =>
      'Bu hesabın Divine\'ı normal şekilde kullanabilmesi için önce incelememiz gerekiyor.';

  @override
  String minorAccountReviewCaseId(String caseId) {
    return 'Vaka kimliği: $caseId';
  }

  @override
  String get minorAccountReviewCaseIdShortLabel => 'Vaka kimliği';

  @override
  String get minorAccountReviewRestrictionsTitle => 'Şu anda neler kısıtlı';

  @override
  String get minorAccountReviewRestrictionPosting =>
      'Paylaşım ve yayınlama duraklatıldı';

  @override
  String get minorAccountReviewRestrictionEngagement =>
      'Yorumlar, beğeniler, repostlar ve takipler duraklatıldı';

  @override
  String get minorAccountReviewRestrictionMessaging =>
      'Normal mesaj başlatma ve yanıtlama duraklatıldı';

  @override
  String get minorAccountReviewRestrictionSupport =>
      'Destek ve moderasyon mesajın kullanılabilir durumda';

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
  String get minorAccountReviewOpenSupportCenter => 'Destek merkezini aç';

  @override
  String get minorAccountReviewOpenModerationMessage =>
      'Moderasyon mesajını aç';

  @override
  String get minorAccountReviewOpenReviewPage => 'İnceleme sayfasını aç';

  @override
  String get minorAccountReviewCheckAgain => 'Tekrar kontrol et';

  @override
  String get minorAccountReviewLogOut => 'Çıkış yap';

  @override
  String get minorAccountReviewNextStepTitle => 'Sonraki adım';

  @override
  String get minorAccountReviewNextStepBody =>
      'Bu incelemeyle ilgili yardıma ihtiyacın olursa destek merkezini ya da moderasyon mesajını aç.';

  @override
  String get minorAccountReviewInProgressTitle => 'İnceleme sürüyor';

  @override
  String get minorAccountReviewInProgressBody =>
      'Şimdilik ihtiyacımız olan bilgi elimizde. Ekibimiz, hesabın normal erişimini geri vermeden önce bu vakayı inceliyor.';

  @override
  String get minorAccountReviewUnder13Title => '13 yaş altı hesaplar';

  @override
  String minorAccountReviewUnder13Body(String supportEmail) {
    return 'Bu hesap 13 yaşından küçük birine aitse, bir ebeveyn veya vasi $supportEmail adresine e-posta göndermeli ve vaka kimliğini eklemeli.';
  }

  @override
  String get minorAccountReviewUnder13PublicTitle =>
      'Sana henüz hesap veremiyoruz';

  @override
  String get minorAccountReviewUnder13PublicBody =>
      'Divine 13 yaşından küçük çocuklar için tasarlanmadı ve dünyadaki sosyal medya kuralları da elimizi bağlıyor.\n\nİnternette birçok şey istediğini elde etmek için yalan söylemeye itiyor; bundan hiç hoşlanmıyoruz. Bu, hayat için yanlış bir ders ve burada sana onu öğretmeyeceğiz.';

  @override
  String get minorAccountReviewUnder13FamilyTitle =>
      'Ailen bunun yerine ne yapabilir';

  @override
  String get minorAccountReviewUnder13FamilyBody =>
      'Bir ebeveyn veya vasi hesabı tutabilir ve paylaşımları yapabilir; sen de kesinlikle onlarla birlikte videolarda olabilirsin. Ailelerin Divine\'ı kendilerine uyan şekilde kullanmasını istiyoruz.';

  @override
  String get minorAccountReviewUnder13ComeBackTitle => '13 yaşına geldiğinde';

  @override
  String get minorAccountReviewUnder13ComeBackBody =>
      'Yaşadığın yerdeki kurallara bağlı olarak geri gelip kendi hesabın için başvurabilirsin. O durumda 13-15 yaş arasındaysan bir ebeveyn veya vasinin onayı gerekir.';

  @override
  String get minorAccountReviewUnder13HonestyTitle =>
      'Neden sana \"geri git\" demeyeceğiz';

  @override
  String get minorAccountReviewUnder13HonestyBody =>
      'İnternetin büyük bir kısmı, insanları kapıdan geçmek için ne söylemeleri gerekiyorsa onu söylediklerinde ödüllendirmek üzere kurulmuş. Bunun iyi olduğunu düşünmüyoruz. Evet, geri dönüp olduğundan büyük olduğunu söyleyebilirsin ama bu dürüst olmazdı ve istediğini elde etmek için sana yalan söylemeyi öğretmeyeceğiz.';

  @override
  String get minorAccountReviewUnder13LegalBody =>
      'Genç insanların Divine\'ı kendileri ve çevrelerindekiler için sağlıklı ve olumlu şekillerde kullanmalarına yardımcı olmaya çalışıyoruz. Ayrıca farklı yerlerde farklı olan yasalara uymak zorundayız. Yani 13 yaşından küçüksen, cevap bugün kendi hesabına sahip olamayacağın.';

  @override
  String get minorAccountReviewTeenBody =>
      'Bu hesap 13-15 yaş arası birine aitse, ebeveyn onayı talimatları için moderasyon mesajını ya da destek yolunu kullan.';

  @override
  String get minorAccountReviewParentConsentTitle =>
      'Hesap 13-15 yaş arası birine ait olacaksa';

  @override
  String get minorAccountReviewParentConsentBody =>
      'Bir ebeveyn ya da vasi, kısa ve özel bir videoyla Divine desteğine e-posta göndermeli. Ekibimiz inceleyip sonraki adımlarda yardımcı olacak.\n\nEbeveyn ya da vasiyle iletişim kurmak mümkün değilse veya bu birini riske atacaksa, Divine desteğine e-posta gönder ve bize bildir.';

  @override
  String get minorAccountReviewParentConsentPauseNote =>
      'Bu, Divine destek ekibi videoyu incelerken verilen bir mola. Onaylanırsa, yeni hesabı kurma sürecinde sana yol gösterecekler.';

  @override
  String get minorAccountReviewParentConsentHonestyTitle =>
      'Neden bir ebeveynin ya da vasinin dahil olmasını istiyoruz';

  @override
  String get minorAccountReviewParentConsentHonestyBody =>
      'Divine, dünya çapındaki yaşla ilgili yasalara uymak zorunda. Ayrıca çoğu teknik yaş kapısının kusurlu olduğunu da biliyoruz. Kuralların yokmuş gibi davranmak ya da yaşın hakkında yalan söylemenin havalı olduğunu düşünmek yerine, gençlerin ve ailelerin Divine\'ı en iyi nasıl kullanacaklarına dair düşünceli kararlar vermelerini istiyoruz. Bu yüzden 13-15 yaş arası kişiler için ebeveynlerin hesap oluşturma sürecinin bir parçası olmasını istiyoruz.';

  @override
  String get minorAccountReviewParentConsentLegalBody =>
      'Ayrıca yasalara da uymak zorundayız ve bu kurallar kişinin yaşadığı yere göre değişir. Bu yüzden kuralların yokmuş gibi davranmak yerine, bir ebeveynin ya da vasinin sürecin bir parçası olmasını istiyoruz.';

  @override
  String get minorAccountReviewParentConsentChecklist =>
      'Video neyi göstermeli';

  @override
  String get minorAccountReviewParentConsentChecklistKid => 'Videodaki genci';

  @override
  String get minorAccountReviewParentConsentChecklistPermission =>
      'Kamera karşısında konuşan bir ebeveyn veya vasi';

  @override
  String get minorAccountReviewParentConsentChecklistAgeBand =>
      'Gencin 13-15 yaş arasında olduğunu ve Divine\'ı kullanma izni olduğunu açıkça belirten bir ifade';

  @override
  String get minorAccountReviewParentConsentChecklistSupervision =>
      'Ebeveyn veya vasinin hesaptan haberdar olduğunu ve kullanımını denetleyeceğini açıkça belirten bir ifade';

  @override
  String get minorAccountReviewParentConsentPrivacy => 'Nasıl gönderilir';

  @override
  String get minorAccountReviewParentConsentNeverPost =>
      'Divine desteğine e-posta gönderirken videoyu ekle';

  @override
  String get minorAccountReviewParentConsentDoNotSave =>
      'Videoyu özel tut ve uygulamada paylaşma';

  @override
  String get minorAccountReviewParentConsentOneMove =>
      'Ekibimiz inceleyip sonraki adımlarla dönüş yapacak';

  @override
  String get minorAccountReviewParentConsentEmailCta =>
      'Divine desteğine e-posta gönder';

  @override
  String get minorAccountReviewParentConsentEmailSubject =>
      'Divine Greenlight inceleme yardımı (13-15 yaş)';

  @override
  String get minorAccountReviewParentConsentEmailBody =>
      'Merhaba Divine destek ekibi,\n\n13-15 yaş arası bir genç için Divine Greenlight hakkında yazıyorum.\n\nŞunları gösteren kısa ve özel bir video ekledim:\n- genci\n- kamera karşısında konuşan bir ebeveyn veya vasiyi\n- gencin Divine\'ı kullanma izni olduğunu\n- ebeveyn veya vasinin hesaptan haberdar olduğunu ve kullanımını denetleyeceğini\n\nİkamet edilen ülke/ülkeler:\n\nFaydalı bilgiler:\n\nTeşekkürler.';

  @override
  String get minorAccountReviewParentSupportInstructions =>
      'Ebeveyn destek talimatları';

  @override
  String get minorAccountReviewContinue => 'Devam';

  @override
  String get minorAccountReviewErrorTitle =>
      'Hesap inceleme durumunu yükleyemedik.';

  @override
  String get minorAccountReviewErrorBody => 'Lütfen birazdan tekrar dene.';

  @override
  String get minorAccountReviewTryAgain => 'Tekrar dene';

  @override
  String get minorAccountReviewParentContactTitle => 'Ebeveyn iletişimi';

  @override
  String get minorAccountReviewParentContactHeading =>
      'Bir ebeveyn veya vasi e-postası ekle';

  @override
  String minorAccountReviewParentContactBody(String caseId) {
    return 'Bu adresi $caseId numaralı vakadaki ebeveyn onayı incelemesi için kullanacağız.';
  }

  @override
  String get minorAccountReviewParentContactFieldLabel =>
      'Ebeveyn veya vasi e-postası';

  @override
  String get minorAccountReviewSubmitting => 'Gönderiliyor...';

  @override
  String get minorAccountReviewSubmitEmail => 'E-postayı gönder';

  @override
  String get minorAccountReviewBackToReview => 'Hesap incelemesine dön';

  @override
  String get minorAccountReviewSubmissionReceivedTitle => 'E-posta gönderildi';

  @override
  String minorAccountReviewSubmissionReceivedBody(String email) {
    return '$email adresini incelemeye gönderdik. Onay için bu adrese e-posta atacağız. Ebeveynin veya vasin yanıt verdiğinde vakan ilerleyecek. Güncellemeler için hesap inceleme ekranındaki «Tekrar kontrol et»i kullan.';
  }

  @override
  String get minorAccountReviewSubmissionReceivedLocalBody =>
      'Bu hesap için ebeveyn veya vasi iletişim bilgisini aldık. Erişimi geri vermeden önce ekibimiz inceleyecek.';

  @override
  String get minorAccountReviewMissingCase =>
      'Bu hesap için aktif bir inceleme vakası bulamadık.';

  @override
  String get minorAccountReviewParentContactError =>
      'Ebeveyn e-postası gönderilemedi. Lütfen tekrar dene.';

  @override
  String get minorAccountReviewUnder13SupportTitle => 'Ebeveyn desteği';

  @override
  String get minorAccountReviewUnder13Heading =>
      'Bir ebeveyn veya vasi Divine ile iletişime geçmeli';

  @override
  String get minorAccountReviewUnder13SupportBody =>
      '13 yaşından küçük olma ihtimali olan hesaplarda sonraki adım, ebeveyn veya vasinin e-posta ile iletişime geçmesidir.';

  @override
  String get minorAccountReviewSupportEmailLabel => 'Destek e-postası';

  @override
  String get minorAccountReviewCopySupportEmail => 'Destek e-postasını kopyala';

  @override
  String get minorAccountReviewSupportEmailCopied =>
      'Destek e-postası kopyalandı';

  @override
  String get minorAccountReviewCopyCaseId => 'Vaka kimliğini kopyala';

  @override
  String get minorAccountReviewCaseIdCopied => 'Vaka kimliği kopyalandı';

  @override
  String get minorAccountReviewUnavailable => 'Kullanılamıyor';

  @override
  String get minorAccountReviewUnder13Instructions =>
      'Ebeveyn veya vasiden vaka kimliğini eklemesini ve bu hesap incelemesi hakkında Divine ile iletişime geçtiğini belirtmesini iste.';

  @override
  String minorAccountReviewUnder13EmailSubject(String caseId) {
    return '$caseId vakası için 13 yaş altı hesap incelemesi';
  }

  @override
  String minorAccountReviewUnder13EmailBody(String caseId) {
    return 'Merhaba Divine destek ekibi,\n\n13 yaşından küçük bir çocuğun ebeveyni veya vasisiyim ve $caseId numaralı hesap inceleme vakası hakkında yazıyorum.\n\nTeşekkürler.';
  }

  @override
  String get devOptionsMinorReviewSimulationTitle =>
      'Reşit olmayan hesap incelemesi simülasyonu';

  @override
  String get devOptionsMinorReviewCurrentStateLabel => 'Mevcut durum';

  @override
  String devOptionsMinorReviewStateRestricted(String state) {
    return 'Kısıtlı ($state)';
  }

  @override
  String get devOptionsMinorReviewStateActive => 'Aktif';

  @override
  String get devOptionsMinorReviewStateLoading => 'Yükleniyor...';

  @override
  String get devOptionsMinorReviewStateError => 'Durum yüklenirken hata';

  @override
  String get devOptionsMinorReviewClearTitle =>
      'Simülasyon geçersiz kılmasını temizle';

  @override
  String get devOptionsMinorReviewClearSubtitle =>
      'Yine sunucuyu ya da varsayılan aktif durumu kullan';

  @override
  String get devOptionsMinorReviewTeenTitle =>
      '13-15 inceleme vakasını simüle et';

  @override
  String get devOptionsMinorReviewTeenSubtitle =>
      'Ebeveyn iletişim yolu olan kısıtlı hesap';

  @override
  String get devOptionsMinorReviewUnder13Title =>
      '13 yaş altı destek vakasını simüle et';

  @override
  String get devOptionsMinorReviewUnder13Subtitle =>
      'Yalnızca ebeveyn e-postası talimatı olan kısıtlı hesap';

  @override
  String get devOptionsMinorReviewClearedToast =>
      'Reşit olmayan hesap incelemesi simülasyonu temizlendi';

  @override
  String get devOptionsMinorReviewUnder13EnabledToast =>
      'Simüle edilmiş 13 yaş altı destek vakası açıldı';

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
      'Korunan reşit olmayan simülasyonu';

  @override
  String get devOptionsProtectedMinorCurrentStateLabel => 'Mevcut durum';

  @override
  String get devOptionsProtectedMinorStateProtected =>
      'Korunan reşit olmayan (13-15)';

  @override
  String get devOptionsProtectedMinorStateNotProtected => 'Korunmuyor';

  @override
  String get devOptionsProtectedMinorStateLoading => 'Yükleniyor…';

  @override
  String get devOptionsProtectedMinorStateError => 'Durum okunurken hata';

  @override
  String get devOptionsProtectedMinorOverrideNone =>
      'Geçersiz kılma yok (gerçek hesap durumu)';

  @override
  String get devOptionsProtectedMinorOverrideProtected =>
      'Geçersiz kılma: korunuyor olarak zorla';

  @override
  String get devOptionsProtectedMinorOverrideNotProtected =>
      'Geçersiz kılma: korunmuyor olarak zorla';

  @override
  String get devOptionsProtectedMinorSimulateTitle =>
      'Korunan reşit olmayanı simüle et (13-15)';

  @override
  String get devOptionsProtectedMinorSimulateSubtitle =>
      '#175/#176 korumalarını test etmek için korunan-reşit olmayan durumunu zorla';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorTitle =>
      'Yetişkini simüle et';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorSubtitle =>
      'Korunmuyor olarak zorla (açık bir hayır; geçersiz kılma yokluğundan farklı)';

  @override
  String get devOptionsProtectedMinorClearTitle => 'Geçersiz kılmayı temizle';

  @override
  String get devOptionsProtectedMinorClearSubtitle =>
      'Keycast\'in belirlediği gerçek hesap durumuna dön';

  @override
  String get devOptionsProtectedMinorEnabledToast =>
      'Korunan-reşit olmayan durumu zorlandı';

  @override
  String get devOptionsProtectedMinorNonMinorToast =>
      'Korunan-reşit olmayan durumu kapatıldı';

  @override
  String get devOptionsProtectedMinorClearedToast =>
      'Korunan-reşit olmayan geçersiz kılması temizlendi';

  @override
  String get devOptionsInviteAvailabilityTitle => 'Kayıt davetleri';

  @override
  String get devOptionsInviteAvailabilityCurrentLabel => 'Mevcut durum';

  @override
  String get devOptionsInviteAvailabilityServerLoading =>
      'Sunucu değeri: yükleniyor';

  @override
  String get devOptionsInviteAvailabilityServerEnabled => 'Sunucu değeri: açık';

  @override
  String get devOptionsInviteAvailabilityServerDisabled =>
      'Sunucu değeri: kapalı';

  @override
  String get devOptionsInviteAvailabilityServerUnknown =>
      'Sunucu değeri: bilinmiyor';

  @override
  String get devOptionsInviteAvailabilityOverrideNone =>
      'Geçersiz kılma: sunucu değerini kullan';

  @override
  String get devOptionsInviteAvailabilityOverrideEnabled =>
      'Geçersiz kılma: açık olarak zorla';

  @override
  String get devOptionsInviteAvailabilityOverrideDisabled =>
      'Geçersiz kılma: kapalı olarak zorla';

  @override
  String get devOptionsInviteAvailabilityUseServer => 'Sunucu değerini kullan';

  @override
  String get devOptionsInviteAvailabilityUseServerSubtitle =>
      'Davet servisinin onboardingMode değerini izle';

  @override
  String get devOptionsInviteAvailabilityForceEnabled => 'Açık olarak zorla';

  @override
  String get devOptionsInviteAvailabilityForceEnabledSubtitle =>
      'Kayıt daveti kapılarını ve yönetimini yerelde göster';

  @override
  String get devOptionsInviteAvailabilityForceDisabled => 'Kapalı olarak zorla';

  @override
  String get devOptionsInviteAvailabilityForceDisabledSubtitle =>
      'Sunucuyu değiştirmeden kayıt daveti arayüzünü yerelde gizle';

  @override
  String get devOptionsInviteAvailabilityUseServerToast =>
      'Kayıt davetleri artık sunucuyu izliyor';

  @override
  String get devOptionsInviteAvailabilityForceEnabledToast =>
      'Kayıt davetleri zorla açıldı';

  @override
  String get devOptionsInviteAvailabilityForceDisabledToast =>
      'Kayıt davetleri zorla kapatıldı';

  @override
  String get commentsRecordVideoButtonLabel => 'Video yorum kaydet';

  @override
  String get commentsOpenVideoLabel => 'Video yorumu aç';

  @override
  String get commentsMuteVideoReplyLabel => 'Video yanıtını sessize al';

  @override
  String get commentsUnmuteVideoReplyLabel => 'Video yanıtının sesini aç';

  @override
  String get commentsOpenReplyParentLabel => 'Bunun yanıt verdiği videoyu aç';

  @override
  String get commentsReplyParentSectionTitle => 'Yanıt olarak';

  @override
  String commentsReplyParentLabel(String target) {
    return '$target için yanıt';
  }

  @override
  String get commentsReplyParentFallbackLabel => 'Videoya yanıt';

  @override
  String verifiedAccountChipSemanticLabel(String platform, String identity) {
    return 'Doğrulanmış $platform hesabı: $identity';
  }

  @override
  String get profileEditVerifiedAccountsTitle => 'Doğrulanmış hesaplar';

  @override
  String get profileEditGetVerifiedCta => 'Hesabını doğrula';

  @override
  String get profileEditGetVerifiedSubtitle =>
      'Sosyal medya hesaplarını bağla ki insanlar gerçekten sen olduğunu bilsin.';

  @override
  String profileWebsiteSemanticLabel(String url) {
    return 'Web sitesini ziyaret et: $url';
  }

  @override
  String get profileCouldNotOpenWebsite => 'Web sitesi açılamadı';

  @override
  String get videoMetadataEditCoverTitle => 'Kapağı düzenle';

  @override
  String get videoMetadataEditCoverCloseSemanticLabel =>
      'Kapak değişikliklerini iptal et';

  @override
  String get videoMetadataEditCoverConfirmSemanticLabel =>
      'Seçili kareyi video kapağı olarak kullan';

  @override
  String get videoMetadataEditCoverStripSemanticLabel =>
      'Kapak karesi seçmek için videoda gezin';

  @override
  String get videoMetadataTagsPickerSearchHint => 'Etiket ara veya ekle';

  @override
  String get videoMetadataTagsPickerEmptyHint =>
      'İnsanların videonu keşfetmesi için etiket ekle';

  @override
  String get videoMetadataTagsPickerNoResults => 'Eşleşen etiket yok';

  @override
  String videoMetadataTagsPickerAddTag(String tag) {
    return '\"#$tag\" ekle';
  }

  @override
  String get authMinAgeNotice => 'Divine Greenlight';

  @override
  String get authUnder16Prefix => 'Henüz 16 değil misin? Sorun değil. ';

  @override
  String get authUnder16ChoicesCta => 'İşte seçeneklerin.';

  @override
  String get minorAccountReviewUnder13WhyTitle => 'Nedeni şu';

  @override
  String get generalSettingsHoldToRecord => 'Kayıt için basılı tut';

  @override
  String get generalSettingsHoldToRecordSubtitle =>
      'Basılı tuttuğunuzda kayıt başlar, bıraktığınızda durur';

  @override
  String uploadPublishedCountMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count video profiline yayınlandı',
      one: 'Video profiline yayınlandı',
    );
    return '$_temp0';
  }

  @override
  String get dmMessageSendLabel => 'Mesaj gönder';

  @override
  String get emojiPickerSearchHint => 'Ara';

  @override
  String get emojiCategoryRecent => 'Son Kullanılanlar';

  @override
  String get emojiCategorySmileys => 'İfadeler ve İnsanlar';

  @override
  String get emojiCategoryAnimals => 'Hayvanlar ve Doğa';

  @override
  String get emojiCategoryFood => 'Yiyecek ve İçecek';

  @override
  String get emojiCategoryActivities => 'Etkinlikler';

  @override
  String get emojiCategoryTravel => 'Seyahat ve Yerler';

  @override
  String get emojiCategoryObjects => 'Nesneler';

  @override
  String get emojiCategorySymbols => 'Semboller';

  @override
  String get emojiCategoryFlags => 'Bayraklar';

  @override
  String get videoEditorMarkerLabel => 'İşaretçi';

  @override
  String get videoEditorAddTimelineMarkerSemanticLabel =>
      'Zaman çizelgesi işaretçisi ekle';

  @override
  String get videoEditorRemoveTimelineMarkerSemanticLabel =>
      'Zaman çizelgesi işaretçisini kaldır';

  @override
  String get videoEditorRemoveTimelineMarkerAtPlayheadSemanticLabel =>
      'Oynatma başlığındaki işaretçiyi kaldır';

  @override
  String get videoEditorDeleteTimelineMarkerTitle => 'İşaretçi silinsin mi?';

  @override
  String get videoEditorDeleteTimelineMarkerSubtitle =>
      'Bu, işaretçiyi zaman çizelgesinden kaldırır. Düzenlemeniz olduğu gibi kalır.';

  @override
  String get videoEditorVolumeLongPressHint =>
      'Tüm parçaları sessize al veya aç';

  @override
  String get videoEditorSplitFailed =>
      'Bölme başarısız oldu. Lütfen tekrar deneyin.';

  @override
  String get videoEditEditSubtitles => 'Altyazıları düzenle';

  @override
  String get subtitleEditorTitle => 'Altyazıları düzenle';

  @override
  String get subtitleEditorSave => 'Kaydet';

  @override
  String get subtitleEditorProcessing =>
      'Altyazılar hâlâ oluşturuluyor. Birazdan tekrar bak.';

  @override
  String get subtitleEditorNoSpeech =>
      'Bu videoda konuşma algılanmadı, yani altyazı yapılacak bir şey yok.';

  @override
  String get subtitleEditorWriteOwn => 'Kendin yaz';

  @override
  String get subtitleEditorAddCue => 'Satır ekle';

  @override
  String get subtitleEditorRemoveCue => 'Bu satırı kaldır';

  @override
  String get subtitleEditorPreviewUnavailable =>
      'Video şu an oynatılamıyor ama altyazıları yine de düzeltebilirsin.';

  @override
  String get subtitleEditorPlayPreview => 'Videoyu oynat';

  @override
  String get subtitleEditorPausePreview => 'Videoyu duraklat';

  @override
  String get subtitleEditorInvalidHint =>
      'Her satırda metin ve başlangıçtan sonra gelen bir bitiş olmalı.';

  @override
  String get subtitleEditorLoadError => 'Altyazılar yüklenemedi. Tekrar dene.';

  @override
  String get subtitleEditorSaveSuccess => 'Altyazılar güncellendi';

  @override
  String get subtitleEditorSaveError =>
      'Altyazılar kaydedilemedi. Tekrar dene.';

  @override
  String get subtitleEditorRetry => 'Tekrar dene';

  @override
  String get subtitleEditorCueHint => 'Altyazı metni';

  @override
  String get imageCropEditorRotateLabel => 'Döndür';

  @override
  String get imageCropEditorFlipLabel => 'Çevir';

  @override
  String get imageCropEditorResetLabel => 'Sıfırla';

  @override
  String get imageCropEditorCloseSemanticLabel => 'Kırpmayı iptal et';

  @override
  String get imageCropEditorDoneSemanticLabel => 'Kırpmayı uygula';

  @override
  String get imageCropEditorProcessing => 'Kırpma uygulanıyor…';

  @override
  String get backgroundUploadNotificationTitle => 'Video yükleniyor';

  @override
  String get monetizationSettingsTitle => 'Üretici desteği';

  @override
  String get monetizationSettingsSubtitle =>
      'Bahşiş ve abonelik bağlantıları ekle';

  @override
  String get monetizationSettingsIntroTitle => 'Yalnızca dış bağlantılar';

  @override
  String get monetizationSettingsIntroBody =>
      'Kendi kontrol ettiğin adresleri ekle. Divine ödemeyi hiçbir zaman işlemez ve bu bağlantılarla uygulama içi içerik açılmaz.';

  @override
  String monetizationSettingsConfiguredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Profilinde $count aktif bağlantı',
      one: 'Profilinde 1 aktif bağlantı',
    );
    return '$_temp0';
  }

  @override
  String get monetizationSettingsTipSection => 'Bahşiş gönder';

  @override
  String get monetizationSettingsSubscriptionSection => 'Abone ol / destekle';

  @override
  String get monetizationSettingsSave => 'Destek bağlantılarını kaydet';

  @override
  String get monetizationSettingsSaving => 'Kaydediliyor...';

  @override
  String get monetizationSettingsSaved => 'Destek bağlantıları güncellendi';

  @override
  String get monetizationSettingsSaveFailed =>
      'Destek bağlantıları kaydedilemedi. Bağlantını kontrol edip tekrar dene.';

  @override
  String get monetizationSettingsErrorEmpty =>
      'Bir kullanıcı adı veya URL ekle.';

  @override
  String get monetizationSettingsErrorInvalid =>
      'Bu bağlantı doğru görünmüyor.';

  @override
  String get monetizationSettingsErrorWrongProvider =>
      'Bu sağlayıcıya ait bir bağlantı kullan.';

  @override
  String get monetizationSettingsHintCashApp =>
      '\$cashtag veya cash.app bağlantısı';

  @override
  String get monetizationSettingsHintPayPal =>
      'PayPal.me kullanıcı adı veya bağlantısı';

  @override
  String get monetizationSettingsHintVenmo =>
      'Venmo kullanıcı adı veya bağlantısı';

  @override
  String get monetizationSettingsHintPatreon =>
      'Patreon kullanıcı adı veya bağlantısı';

  @override
  String get monetizationSettingsHintSubstack =>
      'Substack alan adı veya bağlantısı';

  @override
  String get monetizationSettingsHintMedium =>
      'Medium kullanıcı adı veya bağlantısı';

  @override
  String get monetizationSettingsHintOpenCollective =>
      'Open Collective kısa adı veya bağlantısı';

  @override
  String get profileSupportSheetTitle => 'Bu üreticiyi destekle';

  @override
  String get profileSupportSheetBody =>
      'Bu bağlantılar Divine dışında açılır. Buradaki hiçbir şey uygulamada içerik açmaz.';

  @override
  String get profileSupportTipSection => 'Bahşiş gönder';

  @override
  String get profileSupportSubscriptionSection => 'Abone ol / destekle';

  @override
  String get profileSupportButtonLabel => 'Destekle';

  @override
  String get monetizationTipsSettingsTitle => 'Bahşişler';

  @override
  String get monetizationTipsSettingsSubtitle =>
      'İsteğe bağlı bahşiş bağlantıları ekle';

  @override
  String get monetizationTipsSettingsIntroTitle =>
      'Yalnızca isteğe bağlı bahşiş';

  @override
  String get monetizationTipsSettingsIntroBody =>
      'Bahşişler kullanıcıdan kullanıcıya isteğe bağlı hediyelerdir. Divine\'da içerik, abonelik, özellik, sıralama, görünürlük veya erişim açmazlar.';

  @override
  String monetizationTipsSettingsConfiguredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Profilinde $count aktif bahşiş bağlantısı',
      one: 'Profilinde 1 aktif bahşiş bağlantısı',
    );
    return '$_temp0';
  }

  @override
  String get monetizationTipsSettingsSave => 'Bahşiş bağlantılarını kaydet';

  @override
  String get monetizationTipsSettingsSaved => 'Bahşiş bağlantıları güncellendi';

  @override
  String get profileTipButtonLabel => 'Bahşiş';

  @override
  String get profileTipSheetTitle => 'Bu üreticiye bahşiş ver';

  @override
  String get profileTipSheetBody =>
      'Bahşiş bağlantıları Divine dışında açılır. İsteğe bağlıdır ve Divine\'da içerik, abonelik, özellik veya erişim açmaz.';

  @override
  String get settingsStorageTitle => 'Depolama';

  @override
  String get settingsStorageCacheSectionTitle => 'Önbelleğe alınan medya';

  @override
  String get settingsStorageCacheDescription =>
      'Önbelleğe alınan akış videoları, küçük resimler ve geçici işlemeler. Bunları temizlemek güvenlidir – gerektiğinde yeniden indirilir veya oluşturulur.';

  @override
  String get settingsStorageMeasuring => 'Hesaplanıyor…';

  @override
  String settingsStorageCacheInUse(String size) {
    return '$size kullanımda';
  }

  @override
  String get settingsStorageClearButton => 'Önbelleği temizle';

  @override
  String get settingsStorageClearConfirmTitle =>
      'Önbelleğe alınan medya temizlensin mi?';

  @override
  String settingsStorageClearConfirmMessage(String size) {
    return 'Bu, $size yer açar. Klip kitaplığın etkilenmez.';
  }

  @override
  String get settingsStorageClearConfirmAction => 'Temizle';

  @override
  String get settingsStorageCleared => 'Önbellek temizlendi';

  @override
  String get settingsStorageLibrarySectionTitle => 'Klip kitaplığı';

  @override
  String get settingsStorageLibraryDescription =>
      'Video dosyası eksik olan bozuk klipleri denetle.';

  @override
  String get settingsStorageScanButton => 'Kitaplığı denetle';

  @override
  String get settingsStorageLibraryHealthy => 'Bozuk klip bulunamadı';

  @override
  String settingsStorageBrokenClipsFound(int count) {
    return 'Bulunan bozuk klipler: $count';
  }

  @override
  String get settingsStorageRemoveBrokenButton => 'Bozuk klipleri kaldır';

  @override
  String get settingsStorageBrokenClipsRemoved => 'Bozuk klipler kaldırıldı';

  @override
  String get settingsStorageError => 'Bir şeyler ters gitti';

  @override
  String get settingsStorageMaxVideoCacheLabel => 'Maksimum video önbelleği';

  @override
  String settingsStorageApproxVideos(int count) {
    return '≈ $count video';
  }

  @override
  String get settingsStorageRemoveBrokenConfirmTitle =>
      'Bozuk klipler kaldırılsın mı?';

  @override
  String get settingsStorageRepairSectionTitle => 'Kurulumu onar';

  @override
  String get settingsStorageRepairDescription =>
      'Uygulama sürekli çöküyor ya da tuhaf davranıyorsa yerel verileri sıfırlamak genelde çözer. Kliplerin ve taslakların kalır.';

  @override
  String get settingsStorageRepairButton => 'Uygulama verilerini sıfırla';

  @override
  String get settingsStorageRepairConfirmTitle =>
      'Uygulama verileri sıfırlansın mı?';

  @override
  String get settingsStorageRepairConfirmMessage =>
      'Bu; önbellekteki akış verilerini ve geçici dosyaları siler. Kliplerin, taslakların, ayarların ve oturumun kalır ama sonrasında uygulamayı yeniden başlatman gerekir.';

  @override
  String settingsStorageRepairFootprint(String size) {
    return '$size silinecek';
  }

  @override
  String get settingsStorageRepairConfirmAction => 'Sıfırla';

  @override
  String get settingsStorageRepairInProgress => 'Sıfırlanıyor…';

  @override
  String get settingsStorageRepairSuccess =>
      'Bitti — tamamlamak için uygulamayı yeniden başlat.';

  @override
  String get settingsStorageRepairFailure =>
      'Her şey sıfırlanamadı. Yeniden başlattıktan sonra tekrar dene.';

  @override
  String get nostrSettingsSignatureVerification => 'İmza doğrulaması';

  @override
  String get nostrSettingsSignatureVerificationIntro =>
      'Divine\'ın relay etkinlik imzalarını ne zaman kontrol edeceğini seç. Etkinlik ID\'leri her zaman önce doğrulanır.';

  @override
  String get nostrSettingsSignatureVerificationAll => 'Tüm relay\'ler';

  @override
  String get nostrSettingsSignatureVerificationAllSubtitle =>
      'En güvenlisi. Her relay etkinlik imzasını doğrula.';

  @override
  String get nostrSettingsSignatureVerificationUntrusted =>
      'Güvenilmeyen relay\'ler';

  @override
  String get nostrSettingsSignatureVerificationUntrustedSubtitle =>
      'Yapılandırılmış havuzunda zaten bulunan relay\'ler için kontrolleri atla.';

  @override
  String get nostrSettingsSignatureVerificationNonDivine =>
      'Divine dışı relay\'ler';

  @override
  String get nostrSettingsSignatureVerificationNonDivineSubtitle =>
      'Divine relay\'lerine güven, geri kalanını doğrula.';

  @override
  String get settingsCrosspostingTitle => 'Çapraz paylaşım';

  @override
  String get settingsCrosspostingSubtitle =>
      'Videolarını başka platformlarda paylaş';

  @override
  String get crosspostingSignInRequired =>
      'Çapraz paylaşımı yönetmek için Divine ile giriş yap';

  @override
  String get crosspostingLoadFailed => 'Çapraz paylaşım ayarların yüklenemedi';

  @override
  String get crosspostingNoPlatforms =>
      'Şu anda kullanılabilir çapraz paylaşım platformu yok';

  @override
  String get crosspostingRetry => 'Tekrar dene';

  @override
  String get crosspostingNotConnected => 'Bağlı değil';

  @override
  String get crosspostingConnected => 'Bağlı';

  @override
  String get crosspostingNeedsReconnect => 'Yeniden bağlanması gerekiyor';

  @override
  String get crosspostingConnect => 'Bağlan';

  @override
  String get crosspostingReconnect => 'Yeniden Bağla';

  @override
  String get crosspostingDisconnect => 'Bağlantıyı kes';

  @override
  String get crosspostingModeOff => 'Kapalı';

  @override
  String get crosspostingModeManual => 'Manuel';

  @override
  String get crosspostingModeManualSubtitle => 'Her videoda sen seçersin';

  @override
  String get crosspostingModeAutomatic => 'Otomatik';

  @override
  String get crosspostingModeAutomaticSubtitle =>
      'Sonraki videolar otomatik paylaşılır — sadece bunu açtıktan sonra yayınladıkların';

  @override
  String get crosspostingNotConnectedError =>
      'Nasıl paylaştığını değiştirmek için önce bu platformu bağla.';

  @override
  String get crosspostingGenericError => 'Bir şeyler ters gitti. Tekrar dene.';

  @override
  String get crosspostingCallbackTimeoutError =>
      'Giriş sayfasından hiç yanıt gelmedi. Orada bağlanmayı bitirdiysen yenile — hesabın çoktan bağlanmış olabilir.';

  @override
  String crosspostingConnectionSuccess(String platform) {
    return '$platform bağlandı';
  }

  @override
  String crosspostingConnectionFailed(String platform) {
    return '$platform bağlanamadı';
  }

  @override
  String crosspostingConnectionDenied(String platform) {
    return 'Bağlantı $platform üzerinde iptal edildi';
  }

  @override
  String get supporterTitle => 'Divine Destekçileri';

  @override
  String get supporterTileSubtitle =>
      'İsteğe bağlı aylık abonelikle Divine\'ı destekle.';

  @override
  String get supporterHeroTitle => 'Divine\'ı ayakta tut';

  @override
  String get supporterHeroBody =>
      'Divine ücretsiz ve hep öyle kalacak. Döngülerin devam etmesine yardım etmek istersen aylık destekçi ol. Hiçbir şey kilitli değil — sadece ışıkları açık tutar ve teşekkürlerimizi kazandırır.';

  @override
  String get supporterActiveBadge =>
      'Divine Destekçisisin. Bunu sürdürdüğün için teşekkürler.';

  @override
  String get supporterPurchasePending => 'Satın alımın onay bekliyor.';

  @override
  String get supporterPurchaseConfirming => 'Desteğin onaylanıyor…';

  @override
  String get supporterStoreChecking => 'Mağaza kontrol ediliyor…';

  @override
  String get supporterUnavailable =>
      'Destekçi abonelikleri şu anda burada kullanılamıyor.';

  @override
  String get supporterRestorePurchases => 'Satın alımları geri yükle';

  @override
  String get supporterDismissError => 'Hatayı kapat';

  @override
  String get supporterErrorStoreUnavailable =>
      'Mağaza bu cihazda kullanılamıyor.';

  @override
  String get supporterErrorPurchaseFailed =>
      'Satın alma tamamlanamadı. Senden ücret alınmadı.';

  @override
  String get supporterErrorPurchasePending => 'Satın alımın onay bekliyor.';

  @override
  String get supporterErrorRestoreFailed =>
      'Geri yüklenecek bir destekçi aboneliği bulunamadı.';

  @override
  String get supporterErrorOwnershipConflict =>
      'Bu satın alım başka bir Divine hesabına ait.';

  @override
  String get supporterErrorVerificationUnavailable =>
      'Divine destekçi durumunu şu anda onaylayamadı.';

  @override
  String get supporterErrorUnknown =>
      'Bir şeyler ters gitti. Lütfen tekrar dene.';

  @override
  String get supporterDisclaimer =>
      'Divine, mağaza satın alımını doğruladıktan sonra destekçi durumunu onaylar. Tanınma isteğe bağlıdır ve hale bir doğrulama değildir.';

  @override
  String get profileNotifyBellOff => 'Yeni vine\'lardan haberdar et';

  @override
  String get profileNotifyBellOn => 'Yeni vine bildirimlerini kapat';

  @override
  String get profileNotifyUpdateFailed => 'Kaydedilemedi. Tekrar denensin mi?';

  @override
  String get savedSoundYourLabel => 'Senin etiketin';

  @override
  String get savedSoundAddHashtags => 'Hashtag ekle';

  @override
  String get savedSoundDeviceOnly => 'Bu cihazda kaydedildi';

  @override
  String get savedSoundDetailsRetry =>
      'Bu bilgiler kaydedilemedi. Tekrar denemek için dokun.';

  @override
  String get savedSoundFallbackTitle => 'Kaydedilen ses';

  @override
  String get savedSoundPreviewAction => 'Sesi dinle';

  @override
  String get savedSoundEditAction => 'Ses bilgilerini düzenle';

  @override
  String get savedSoundRemoveAction => 'Kaydedilen sesi kaldır';

  @override
  String get savedSoundClearHashtagFilter => 'Hashtag filtresini temizle';

  @override
  String get soundAllowRemix => 'Başkalarının bu sesi remikslemesine izin ver';

  @override
  String get soundReuseUnavailable => 'Bu ses şu anda remikslenemiyor.';

  @override
  String get soundPublicCredit => 'Herkese açık ses künyesi';

  @override
  String get soundCreditRequired =>
      'Paylaşmadan önce herkese açık ses künyesi ekle.';

  @override
  String get soundSharedAs => 'Şu adla paylaşıldı';

  @override
  String get soundOwnWork => 'Bu sesi ben yaptım';

  @override
  String soundCreatorBy(String creator) {
    return '$creator tarafından';
  }

  @override
  String soundSharedBy(String publisher) {
    return '$publisher tarafından paylaşıldı';
  }

  @override
  String get soundRemixingAllowed => 'Remikslemeye izin veriliyor';

  @override
  String get soundCreditOnly => 'Yalnızca künye';

  @override
  String get soundCreditTitleLabel => 'Ses başlığı';

  @override
  String get soundCreditCreatorLabel => 'Üretici';

  @override
  String get soundCreditSourceUrlLabel => 'Kaynak URL';

  @override
  String get soundCreditPublicHashtagsLabel => 'Herkese açık hashtagler';

  @override
  String get videoMetadataTagsPickerCancelSemanticLabel =>
      'Etiket seçimini iptal et';

  @override
  String get videoMetadataTagsPickerConfirmSemanticLabel =>
      'Seçili etiketleri uygula';

  @override
  String get userPickerCancelSemanticLabel => 'Kullanıcı seçimini iptal et';

  @override
  String get userPickerConfirmSemanticLabel => 'Seçili kullanıcıları onayla';

  @override
  String get userPickerClearSelectionSemanticLabel =>
      'Kullanıcı seçimini temizle';

  @override
  String get videoMetadataContentWarningsPickerCancelSemanticLabel =>
      'İçerik uyarısı seçimini iptal et';

  @override
  String get videoMetadataContentWarningsPickerConfirmSemanticLabel =>
      'Seçili içerik uyarılarını uygula';

  @override
  String get videoEditorCloseEditorSemanticLabel => 'Video düzenleyiciyi kapat';

  @override
  String get videoEditorContinueToPostDetailsSemanticLabel =>
      'Gönderi ayrıntılarına devam et';

  @override
  String videoEditorDiscardToolChangesSemanticLabel(String tool) {
    return '$tool içindeki değişiklikleri iptal et';
  }

  @override
  String videoEditorApplyToolChangesSemanticLabel(String tool) {
    return '$tool içindeki değişiklikleri uygula';
  }

  @override
  String get videoEditorRemoveAudioSemanticLabel => 'Sesi kaldır';

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
  String get verifyTitle => 'Doğrulanmış hesaplar';

  @override
  String get verifySignedOutMessage => 'Hesaplarını bağlamak için giriş yap.';

  @override
  String get verifyIntro =>
      'Zaten sahip olduğun hesapları bağla ki gerçekten sen olduğun anlaşılsın.';

  @override
  String get verifyLoadFailed => 'Bağlantıların yüklenemedi.';

  @override
  String get verifyRetry => 'Tekrar dene';

  @override
  String get verifyLinkedSectionTitle => 'Bağlı';

  @override
  String get verifyVerifierUnreachable =>
      'Doğrulayıcıya ulaşılamadı, bu yüzden hepsi kontrol edilmemiş görünüyor.';

  @override
  String get verifyAddSectionTitle => 'Hesap ekle';

  @override
  String get verifyAllPlatformsLinked => 'Desteklediğimiz her şeyi bağladın.';

  @override
  String get verifyStatusVerified => 'Doğrulandı';

  @override
  String get verifyStatusUnverified => 'Doğrulanmadı';

  @override
  String verifyUnlinkSemanticLabel(String platform, String identity) {
    return '$platform hesabı $identity bağlantısını kaldır';
  }

  @override
  String verifyUnlinkConfirmTitle(String platform) {
    return '$platform bağlantısı kaldırılsın mı?';
  }

  @override
  String verifyUnlinkConfirmSubtitle(String identity) {
    return '$identity artık profilinde görünmeyecek. Daha sonra tekrar bağlayabilirsin ama yeniden giriş yapman ya da yeni bir kanıt paylaşman gerekecek.';
  }

  @override
  String get verifyUnlinkConfirmCta => 'Bağlantıyı kaldır';

  @override
  String verifyLinkSemanticLabel(String platform) {
    return '$platform hesabını bağla';
  }

  @override
  String get verifyOneTapBadge => 'Tek dokunuş';

  @override
  String verifyConnectOauthExplainer(String platform) {
    return '$platform hesabına giriş yap, gerisini biz hallederiz. Hiçbir şey paylaşılmaz.';
  }

  @override
  String verifyConnectOauthCta(String platform) {
    return '$platform ile devam et';
  }

  @override
  String get verifyConnectProofTitle => 'Ya da bir kanıt paylaş';

  @override
  String get verifyConnectProofExplainer =>
      'npub\'ını hesabında paylaş, sonra o gönderinin bağlantısını yapıştır.';

  @override
  String get verifyNpubLabel => 'npub\'ın';

  @override
  String get verifyCopyNpubSemanticLabel => 'npub\'ını kopyala';

  @override
  String get verifyNpubCopied => 'npub kopyalandı';

  @override
  String get verifyIdentityLabel => 'Hesap adı';

  @override
  String get verifyProofLabel => 'Gönderinin bağlantısı';

  @override
  String get verifyConnectProofCta => 'Kontrol et ve bağla';

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
      'Doğrulayıcıya ulaşılamadı. Birazdan tekrar dene.';

  @override
  String get verifyErrorOauthFailed => 'Olmadı. Bir daha dene.';

  @override
  String get verifyErrorHandleRequired => 'Önce kullanıcı adını gir.';

  @override
  String get verifyErrorPublishFailed =>
      'Doğrulandı ama hiçbir röle güncellemeyi kabul etmedi. Tekrar dene.';

  @override
  String get verifyErrorOauthUnavailable =>
      'Tek dokunuşla giriş bunun için henüz ayarlı değil. Aşağıdaki kanıtı kullan.';

  @override
  String get verifyConnectProofExplainerGithub =>
      'npub\'ın ilk dosyada olacak şekilde herkese açık bir gist oluştur ve gist bağlantısını yapıştır.';

  @override
  String get verifyConnectProofExplainerDiscord =>
      'npub\'ını botumuzun okuyabildiği bir Discord kanalında paylaş ve mesaj bağlantısını yapıştır. Sunucu daveti hiçbir şeyi kanıtlamaz.';

  @override
  String get verifyConnectProofExplainerTwitter =>
      'npub\'ını o hesaptan tweetle ve tweetin bağlantısını yapıştır.';

  @override
  String get verifyConnectProofExplainerMastodon =>
      'npub\'ını o hesaptan paylaş ve bağlantıyı yapıştır. Hesap adı sunucuyu da içermeli — mastodon.social/@alice, sadece alice değil.';

  @override
  String get verifyConnectProofExplainerTelegram =>
      'Bağlanan kanal, Telegram hesabın değil. Önce herkese açık bir bağlantısı olmalı (Telegram yenileri özel oluşturur). npub\'ını orada paylaş ve mesaj bağlantısını yapıştır.';

  @override
  String get verifyConnectProofExplainerBluesky =>
      'Yukarıdan giriş yaptın mı? Başka bir şey gerekmiyor. Yoksa npub\'ını paylaş ve gönderinin bağlantısını yapıştır.';

  @override
  String get verifyConnectProofExplainerTiktok =>
      'npub\'ını bir video açıklamasına yaz ve o videonun bağlantısını yapıştır.';

  @override
  String get verifyConnectProofExplainerYoutube =>
      'npub\'ını bir video açıklamasına yaz ve o videonun bağlantısını yapıştır.';

  @override
  String verifyLinkedConfirmation(String platform) {
    return '$platform bağlandı.';
  }

  @override
  String get verifyErrorTelegramNotPublic =>
      'O özel bir kanal ya da davet. Kanala herkese açık bir bağlantı ver, sonra mesaj bağlantısını yapıştır.';

  @override
  String get verifyErrorRemoveFailed => 'Bağlantı kaldırılamadı. Tekrar dene.';

  @override
  String get verifyErrorLinksUnreadable =>
      'Mevcut bağlantılarını okuyamadık, bu yüzden hiçbir şey değişmedi. Bağlantını kontrol edip tekrar dene.';

  @override
  String get verifyChannelLabel => 'Kanal adı';

  @override
  String get verifyHowItWorksTitle => 'Bu nasıl çalışıyor?';

  @override
  String get verifyHowItWorksIntro =>
      'Bunu iki hesap arasındaki bir el sıkışma gibi düşün:';

  @override
  String get verifyHowItWorksYourSide =>
      'Divine profilin diyor ki: “Twitter\'da @alice benim.”';

  @override
  String get verifyHowItWorksOtherSide =>
      'Twitter hesabın onaylıyor: “Evet, o Divine profili bana ait.”';

  @override
  String get verifyHowItWorksBothSides =>
      'İki tarafı da kontrol ediyoruz. Uyuşuyorsa doğrulanmış olursun. Taklit edilemez — adını ve fotoğrafını kopyalayabilirler, gerçek hesabından paylaşamazlar.';

  @override
  String get verifyHowItWorksOwnership =>
      'Bağlantılar kendi Nostr kimliğinde duruyor, yani buradan istediğin zaman kaldırabilirsin.';

  @override
  String get generalSettingsSectionIdentity => 'Kimlik';

  @override
  String get libraryFilterAll => 'Tümü';

  @override
  String get libraryFilterArchive => 'Arşiv';

  @override
  String get libraryFilterDeleted => 'Silinenler';

  @override
  String get libraryCategoryNewChipLabel => 'Yeni';

  @override
  String get libraryCategoryCreateSemanticLabel => 'Kategori oluştur';

  @override
  String get libraryCategoryCreateTitle => 'Yeni kategori';

  @override
  String get libraryCategoryCreateAction => 'Oluştur';

  @override
  String get libraryCategoryRenameTitle => 'Kategoriyi yeniden adlandır';

  @override
  String get libraryCategoryRenameAction => 'Yeniden adlandır';

  @override
  String get libraryCategoryDeleteAction => 'Kategoriyi sil';

  @override
  String get libraryCategoryNameLabel => 'Kategori adı';

  @override
  String libraryCategoryDeleteConfirmTitle(String name) {
    return '“$name” silinsin mi?';
  }

  @override
  String get libraryCategoryDeleteConfirmMessage =>
      'Klipler yerinde kalır, sadece Tümü\'ne geri döner.';

  @override
  String get libraryCategoryManageSemanticLabel =>
      'Bu kategoriyi yeniden adlandır veya sil';

  @override
  String get libraryCategoryMoveTitle => 'Şuraya taşı';

  @override
  String get libraryCategoryMoveNone => 'Kategorisiz';

  @override
  String get libraryCategoryMoveNewCategory => 'Yeni kategori';

  @override
  String get libraryArchiveAction => 'Arşivle';

  @override
  String get libraryUnarchiveAction => 'Arşivden çıkar';

  @override
  String libraryArchiveKeepCategoryTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Bu kategorilerde kalsın mı?',
      one: 'Bu kategoride kalsın mı?',
    );
    return '$_temp0';
  }

  @override
  String libraryArchiveKeepCategoryAction(String name) {
    return '$name içinde kalsın';
  }

  @override
  String get libraryArchiveKeepCategoryActionMixed => 'Kategorilerinde kalsın';

  @override
  String libraryArchiveRemoveCategoryAction(String name) {
    return '$name içinden çıkar';
  }

  @override
  String get libraryArchiveRemoveCategoryActionMixed =>
      'Kategorilerinden çıkar';

  @override
  String get libraryMoveSelectedClipsTooltip => 'Seçili klipleri taşı';

  @override
  String get libraryCategoryEmptyTitle => 'Burada henüz bir şey yok';

  @override
  String get libraryCategoryEmptySubtitle =>
      'Birkaç klip seç ve bu kategoriye taşı.';

  @override
  String get libraryArchiveEmptyTitle => 'Arşivde bir şey yok';

  @override
  String get libraryArchiveEmptySubtitle =>
      'Arşivlenen klipler ana kitaplığının dışında burada bekler.';

  @override
  String libraryClipsMovedToCategory(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klip $name kategorisine taşındı',
      one: '1 klip $name kategorisine taşındı',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsRemovedFromCategory(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klip kategorisinden çıkarıldı',
      one: '1 klip kategorisinden çıkarıldı',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsArchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klip arşivlendi',
      one: '1 klip arşivlendi',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsUnarchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klip kitaplığına geri döndü',
      one: '1 klip kitaplığına geri döndü',
    );
    return '$_temp0';
  }

  @override
  String get accountSettingsChangeEmail => 'E-postayı değiştir';

  @override
  String get accountSettingsChangeEmailSubtitle =>
      'Hesabını başka bir adrese taşı';

  @override
  String get accountSettingsChangePassword => 'Şifreyi değiştir';

  @override
  String get accountSettingsChangePasswordSubtitle =>
      'Giriş için yeni bir şifre seç';

  @override
  String get accountCredentialsNeedsSignIn =>
      'Oturumun doldu. Bu değişikliği yapmak için tekrar giriş yap.';

  @override
  String get accountCredentialsRateLimited =>
      'Çok fazla deneme. Birkaç dakika bekle.';

  @override
  String get accountCredentialsNetwork =>
      'Divine\'a ulaşamadık. Bağlantını kontrol edip tekrar dene.';

  @override
  String get accountCredentialsUnknown => 'Olmadı. Lütfen tekrar dene.';

  @override
  String get changePasswordSubtitle =>
      'Mevcut şifreni yaz, sonra yeni bir tane seç.';

  @override
  String get changePasswordCurrentLabel => 'Mevcut şifre';

  @override
  String get changePasswordWrongCurrent => 'Bu senin mevcut şifren değil.';

  @override
  String get changePasswordSuccess => 'Şifre değişti.';

  @override
  String get changeEmailSubtitle =>
      'Yeni adresine ve hesabındaki adrese birer onay bağlantısı yolluyoruz. E-postan ikisini de onaylayınca değişir.';

  @override
  String changeEmailCurrentAddress(String email) {
    return 'Hesabında: $email';
  }

  @override
  String get changeEmailNewLabel => 'Yeni e-posta';

  @override
  String get changeEmailPasswordLabel => 'Şifren';

  @override
  String get changeEmailSameAsCurrent => 'Bu zaten senin e-posta adresin.';

  @override
  String get changeEmailWrongPassword => 'Bu senin şifren değil.';

  @override
  String get changeEmailSubmit => 'Onay bağlantılarını gönder';

  @override
  String get changeEmailSentTitle => 'İki bağlantı yolda';

  @override
  String changeEmailSentMessage(String email) {
    return '$email adresinden ve hesabındaki adresten onayla. İkisi de bitince e-postan değişir.';
  }

  @override
  String get changeEmailSentExpiry =>
      'Bağlantılar 24 saat sonra geçersiz olur.';

  @override
  String get changeEmailSentDone => 'Anladım';

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
  String get socialProofMutual => 'Karşılıklı';

  @override
  String get socialProofFollowsYou => 'Seni takip ediyor';

  @override
  String get socialProofYouFollow => 'Takip ediyorsun';

  @override
  String socialProofFollowerCount(int count, String formattedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formattedCount takipçi',
    );
    return '$_temp0';
  }

  @override
  String get feedOutageMessage =>
      'Videolar şu anda yüklenmiyor.\nSorun bizde, sende değil — üzerinde çalışıyoruz.';

  @override
  String get feedOfflineMessage =>
      'Çevrimdışısın.\nBağlantını kontrol edip tekrar dene.';

  @override
  String get dbFailureTitle => 'yerel veritabanınız açılamadı';

  @override
  String get dbFailureAdviceResettable =>
      'Yeniden başlatmak bunu düzeltmez. Aşağıdaki yerel veritabanını sıfırlamak Divine’a temiz bir başlangıç verir — hesabınız kalır.';

  @override
  String get dbFailureAdviceRestart =>
      'Cihazınızın kilidini açtıktan sonra Divine’ı yeniden başlatın. Bu sürerse uygulamayı güncelleyin veya destekle iletişime geçin.';

  @override
  String get dbFailureAdviceHotJournal =>
      'Divine’ı bir kez yeniden başlatmayı deneyin. Bu durum devam ederse uygulamayı güncelleyin veya destek ekibiyle iletişime geçin. Yerel verileriniz hâlâ burada.';

  @override
  String dbFailureDiagnostic(String code) {
    return 'Tanılama: $code';
  }

  @override
  String get dbFailureCloseApp => 'Divine’ı kapat';

  @override
  String get dbFailureResetAction => 'yerel veritabanını sıfırla';

  @override
  String get dbFailureConfirmTitle => 'yerel veritabanınız sıfırlansın mı?';

  @override
  String get dbFailureConfirmBody =>
      'Hesabınız kalır. Bu cihazda kayıtlı taslaklar ve klipler silinir — mesajlar ve akışlar ağdan geri gelir.';

  @override
  String get dbFailureResetConfirm => 'yerel veritabanını şimdi sıfırla';

  @override
  String get dbFailureCancel => 'iptal';

  @override
  String get dbFailureResetFailed =>
      'Bu işe yaramadı. Divine’ı kapatıp tekrar deneyin.';

  @override
  String get dbFailureResetDoneTitle => 'yerel veritabanı sıfırlandı';

  @override
  String get dbFailureResetDoneBody =>
      'Divine’ı kapatıp yeniden açın — sonraki başlatmada yeni bir yerel veritabanı oluşturulur.';

  @override
  String get authSignInOptionsInfo => 'Oturum açma seçenekleri hakkında';

  @override
  String get authShowPassword => 'Şifreyi göster';

  @override
  String get authHidePassword => 'Şifreyi gizle';

  @override
  String get followUserSemanticLabel => 'Kullanıcıyı takip et';

  @override
  String get unfollowUserSemanticLabel => 'Kullanıcıyı takipten çık';

  @override
  String get commentsLoadingSemanticLabel => 'Yorumlar yükleniyor';

  @override
  String get analyticsWindowAll => 'Tümü';

  @override
  String followUserIndexedSemanticLabel(String index) {
    return 'Kullanıcıyı takip et $index';
  }

  @override
  String unfollowUserIndexedSemanticLabel(String index) {
    return 'Kullanıcıyı takipten çık $index';
  }

  @override
  String supporterTierMonthlyLabel(String title, String price) {
    return '$title — $price / ay';
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
  String get updateGentleBanner => 'Yeni bir güncelleme çıktı. Göz atın →';

  @override
  String get updateModerateTitle =>
      'Son kontrolünüzden bu yana bir güncelleme var';

  @override
  String get updateUrgentTitle => 'Önemli düzeltmeleri kaçırıyorsunuz';

  @override
  String get updateNotNow => 'Şimdi değil';

  @override
  String get updateAction => 'Güncelle';

  @override
  String updateNewIn(String version) {
    return '$version sürümündeki yenilikler:';
  }

  @override
  String get settingsUpdateAvailable => 'Güncelleme mevcut';
}

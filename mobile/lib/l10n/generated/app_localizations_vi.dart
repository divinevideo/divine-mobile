// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get devOptionsClipRecovery => 'Khôi phục clip';

  @override
  String get devOptionsClipRecoveryDescription =>
      'Tìm các bản ghi được lưu dưới tài khoản khác và các tệp video không còn mục nào tham chiếu tới.';

  @override
  String get devOptionsClipRecoveryScan => 'Quét';

  @override
  String get devOptionsClipRecoveryFailure => 'Khôi phục clip không thành công';

  @override
  String devOptionsClipRecoveryVisible(int clips, int drafts) {
    return 'Đang hiển thị: $clips clip, $drafts bản nháp';
  }

  @override
  String get devOptionsClipRecoveryOtherAccounts => 'Bị ẩn dưới tài khoản khác';

  @override
  String devOptionsClipRecoveryCounts(int clips, int drafts) {
    return '$clips clip, $drafts bản nháp';
  }

  @override
  String get devOptionsClipRecoveryClaim => 'Chuyển sang tài khoản này';

  @override
  String devOptionsClipRecoveryOrphanFiles(int count, String size) {
    return 'Tệp không được tham chiếu: $count ($size)';
  }

  @override
  String get devOptionsClipRecoveryImport => 'Dựng lại trong thư viện';

  @override
  String get devOptionsClipRecoveryEmpty => 'Không có gì để khôi phục';

  @override
  String devOptionsClipRecoveryRecovered(int count) {
    return 'Đã khôi phục $count clip';
  }

  @override
  String get devOptionsClipRecoveryCopied => 'Đã sao chép báo cáo khôi phục';

  @override
  String get devOptionsStorageFootprint => 'Dung lượng đã dùng';

  @override
  String get devOptionsStorageFootprintDescription =>
      'Mọi thư mục ứng dụng ghi vào. Xóa bộ nhớ đệm chỉ giải phóng một phần trong đó.';

  @override
  String get devOptionsStorageFootprintMeasure => 'Đo';

  @override
  String devOptionsStorageFootprintTotal(String size) {
    return 'Tổng: $size';
  }

  @override
  String get devOptionsStorageFootprintCopied =>
      'Đã sao chép báo cáo dung lượng';

  @override
  String get devOptionsStorageFootprintFailure => 'Không đo được dung lượng';

  @override
  String get feedTuningMoreLabel => 'Thêm kiểu này';

  @override
  String get feedTuningLessLabel => 'Bớt kiểu này';

  @override
  String get feedTuningUndo => 'Hoàn tác';

  @override
  String get dmMessageBubbleVideoReplyHint => 'Mở video được nhắc tới';

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => 'Cài đặt';

  @override
  String get settingsSecureAccount => 'Bảo mật tài khoản của bạn';

  @override
  String get settingsSessionExpired => 'Phiên đăng nhập đã hết hạn';

  @override
  String get settingsSessionExpiredSubtitle =>
      'Đăng nhập lại để khôi phục toàn bộ quyền truy cập';

  @override
  String get settingsAccountRestoreFailed => 'Account Restore Failed';

  @override
  String get settingsAccountRestoreFailedSwitchMessage =>
      'We couldn\'t unlock that account on this device. Signing back into it means signing out of the one you\'re on now.';

  @override
  String get settingsCreatorAnalytics => 'Phân tích nhà sáng tạo';

  @override
  String get settingsSupportCenter => 'Trung tâm hỗ trợ';

  @override
  String get settingsNotifications => 'Thông báo';

  @override
  String get settingsBlueskyPublishing => 'Đăng lên Bluesky';

  @override
  String get settingsBlueskyPublishingSubtitle =>
      'Quản lý việc đăng chéo lên Bluesky';

  @override
  String get settingsNostrSettings => 'Cài đặt Nostr';

  @override
  String get settingsIntegratedApps => 'Ứng dụng tích hợp';

  @override
  String get settingsIntegratedAppsSubtitle =>
      'Các ứng dụng bên thứ ba đã được duyệt chạy bên trong Divine';

  @override
  String get settingsExperimentalFeatures => 'Tính năng thử nghiệm';

  @override
  String get settingsExperimentalFeaturesSubtitle =>
      'Mấy tinh chỉnh có thể hơi \"khựng\"—tò mò thì thử nhé.';

  @override
  String get settingsLegal => 'Pháp lý';

  @override
  String get settingsIntegrationPermissions => 'Quyền tích hợp';

  @override
  String get settingsIntegrationPermissionsSubtitle =>
      'Xem lại và thu hồi các phê duyệt tích hợp đã lưu';

  @override
  String settingsVersion(String version) {
    return 'Phiên bản $version';
  }

  @override
  String get settingsVersionEmpty => 'Phiên bản';

  @override
  String get settingsDeveloperModeAlreadyEnabled =>
      'Chế độ nhà phát triển đã được bật sẵn';

  @override
  String get settingsDeveloperModeEnabled => 'Đã bật chế độ nhà phát triển!';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    return 'Chạm thêm $count lần nữa để bật chế độ nhà phát triển';
  }

  @override
  String get settingsShareDivine => 'Chia sẻ Divine với bạn bè';

  @override
  String get settingsSwitchAccount => 'Chuyển tài khoản';

  @override
  String get settingsAddAnotherAccount => 'Thêm tài khoản khác';

  @override
  String get settingsAccountSwitchFailed =>
      'Không thể chuyển tài khoản. Vui lòng thử lại.';

  @override
  String get settingsUnsavedDraftsTitle => 'Bản nháp chưa lưu';

  @override
  String get settingsUploadInProgressTitle => 'Đang tải lên';

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
      other: 'các video của bạn sẽ ở lại dưới dạng bản nháp',
      one: 'video của bạn sẽ ở lại dưới dạng bản nháp',
    );
    return 'Bạn vẫn còn $count $_temp0 đang tải lên. Chuyển tài khoản sẽ dừng việc tải lên — $_temp1 trong tài khoản này.';
  }

  @override
  String settingsUnsavedDraftsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'bản nháp',
      one: 'bản nháp',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'bản nháp',
      one: 'bản nháp',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'chúng',
      one: 'nó',
    );
    return 'Bạn có $count $_temp0 chưa lưu. Chuyển tài khoản sẽ giữ lại $_temp1 của bạn, nhưng có thể bạn muốn đăng hoặc xem lại $_temp2 trước.';
  }

  @override
  String get settingsCancel => 'Hủy';

  @override
  String get settingsSwitchAnyway => 'Vẫn chuyển';

  @override
  String get settingsSessionExpiredSwitchMessage =>
      'Phiên của tài khoản đó đã hết hạn. Đăng nhập lại vào đó nghĩa là bạn sẽ đăng xuất khỏi tài khoản đang dùng.';

  @override
  String get settingsAppVersionLabel => 'Phiên bản ứng dụng';

  @override
  String get settingsAppLanguage => 'Ngôn ngữ ứng dụng';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language (mặc định của thiết bị)';
  }

  @override
  String get settingsAppLanguageTitle => 'Ngôn ngữ ứng dụng';

  @override
  String get settingsAppLanguageDescription =>
      'Chọn ngôn ngữ cho giao diện ứng dụng';

  @override
  String get settingsAppLanguageUseDeviceLanguage =>
      'Dùng ngôn ngữ của thiết bị';

  @override
  String get settingsGeneralTitle => 'Cài đặt chung';

  @override
  String get settingsContentSafetyTitle => 'Nội dung & An toàn';

  @override
  String get generalSettingsSectionIntegrations => 'TÍCH HỢP';

  @override
  String get generalSettingsSectionViewing => 'XEM';

  @override
  String get generalSettingsSectionCreating => 'SÁNG TẠO';

  @override
  String get generalSettingsSectionApp => 'ỨNG DỤNG';

  @override
  String get appearanceSettingsTitle => 'Giao diện';

  @override
  String get appearanceSettingsSubtitle =>
      'Chọn kiểu hiển thị của Divine trên thiết bị này';

  @override
  String get appearanceSettingsSystem => 'Theo hệ thống';

  @override
  String get appearanceSettingsLight => 'Sáng';

  @override
  String get appearanceSettingsDark => 'Tối';

  @override
  String get generalSettingsClosedCaptions => 'Phụ đề';

  @override
  String get generalSettingsClosedCaptionsSubtitle =>
      'Hiện phụ đề khi video có sẵn';

  @override
  String get generalSettingsVideoShapeSquareOnly => 'Chỉ video vuông';

  @override
  String get generalSettingsVideoShapeSquareOnlySubtitle =>
      'Giữ bảng tin ở định dạng vuông cổ điển';

  @override
  String get contentPreferencesTitle => 'Tùy chọn nội dung';

  @override
  String get contentPreferencesContentFilters => 'Bộ lọc nội dung';

  @override
  String get contentPreferencesContentFiltersSubtitle =>
      'Quản lý bộ lọc cảnh báo nội dung';

  @override
  String get contentPreferencesContentLanguage => 'Ngôn ngữ nội dung';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language (mặc định của thiết bị)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      'Gắn thẻ ngôn ngữ cho video của bạn để người xem có thể lọc nội dung.';

  @override
  String get contentPreferencesUseDeviceLanguage =>
      'Dùng ngôn ngữ thiết bị (mặc định)';

  @override
  String get contentPreferencesAudioSharing =>
      'Cho phép dùng lại âm thanh của tôi';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      'Khi bật, người khác có thể sử dụng âm thanh từ video của bạn';

  @override
  String get contentPreferencesMusicMode => 'Chế độ âm nhạc';

  @override
  String get contentPreferencesMusicModeSubtitle =>
      'Tắt bộ lọc tiếng ồn vốn làm bẹp tiếng nhạc cụ. Hợp với âm nhạc, thô hơn với giọng nói.';

  @override
  String get contentPreferencesAccountLabels => 'Nhãn tài khoản';

  @override
  String get contentPreferencesAccountLabelsEmpty =>
      'Tự gắn nhãn nội dung của bạn';

  @override
  String get contentPreferencesAccountContentLabels =>
      'Nhãn nội dung tài khoản';

  @override
  String get contentPreferencesClearAll => 'Xóa tất cả';

  @override
  String get contentPreferencesSelectAllThatApply =>
      'Chọn tất cả những gì áp dụng cho tài khoản của bạn';

  @override
  String get contentPreferencesDoneNoLabels => 'Xong (Không có nhãn)';

  @override
  String contentPreferencesDoneCount(int count) {
    return 'Xong (đã chọn $count)';
  }

  @override
  String get contentPreferencesAudioInputDevice => 'Thiết bị thu âm';

  @override
  String get contentPreferencesAutoRecommended => 'Tự động (khuyên dùng)';

  @override
  String get contentPreferencesAutoSelectsBest => 'Tự động chọn micro tốt nhất';

  @override
  String get contentPreferencesSelectAudioInput => 'Chọn nguồn âm thanh';

  @override
  String get contentPreferencesUnknownMicrophone => 'Micro không xác định';

  @override
  String get contentFiltersAdultContent => 'NỘI DUNG NGƯỜI LỚN';

  @override
  String get contentFiltersViolenceGore => 'BẠO LỰC & MÁU ME';

  @override
  String get contentFiltersSubstances => 'CHẤT KÍCH THÍCH';

  @override
  String get contentFiltersOther => 'KHÁC';

  @override
  String get contentFiltersAgeGateMessage =>
      'Xác minh tuổi của bạn trong cài đặt An toàn & Quyền riêng tư để mở khóa bộ lọc nội dung người lớn';

  @override
  String get contentFiltersShow => 'Hiện';

  @override
  String get contentFiltersWarn => 'Cảnh báo';

  @override
  String get contentFiltersFilterOut => 'Lọc bỏ';

  @override
  String get profileBlockedAccountNotAvailable =>
      'Tài khoản này không khả dụng';

  @override
  String get profileInvalidId => 'ID hồ sơ không hợp lệ';

  @override
  String profileShareText(String displayName, String npub) {
    return 'Xem $displayName trên Divine nè!\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return '$displayName trên Divine';
  }

  @override
  String get profileShareFailed => 'Không thể chia sẻ hồ sơ. Vui lòng thử lại.';

  @override
  String get profileCopyPublicKey => 'Sao chép khóa công khai (npub)';

  @override
  String get profileGetEmbedCode => 'Lấy mã nhúng';

  @override
  String get profilePublicKeyCopied =>
      'Đã sao chép khóa công khai vào khay nhớ tạm';

  @override
  String get profileEmbedCodeCopied => 'Đã sao chép mã nhúng vào khay nhớ tạm';

  @override
  String get profileMoreTooltip => 'Thêm';

  @override
  String get profileMoreSemanticLabel => 'Tùy chọn khác';

  @override
  String get profileAvatarLightboxBarrierLabel => 'Đóng ảnh đại diện';

  @override
  String get profileAvatarLightboxCloseSemanticLabel =>
      'Đóng xem trước ảnh đại diện';

  @override
  String get profileFollowingLabel => 'Đang theo dõi';

  @override
  String get profileFollowLabel => 'Theo dõi';

  @override
  String get profileBlockedLabel => 'Đã chặn';

  @override
  String get profileFollowersLabel => 'Người theo dõi';

  @override
  String get profileFollowingStatLabel => 'Đang theo dõi';

  @override
  String get profileVideosLabel => 'Video';

  @override
  String get profileCollabsLabel => 'Cộng tác';

  @override
  String get profileLikedLabel => 'Đã thích';

  @override
  String get profileRepostsLabel => 'Lượt đăng lại';

  @override
  String get profileListsLabel => 'Danh sách';

  @override
  String get profileCommentsLabel => 'Bình luận';

  @override
  String profileCollaboratorInvitePendingHeadline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vẫn còn $count lời mời cộng tác chưa gửi được',
      one: 'Vẫn còn 1 lời mời cộng tác chưa gửi được',
    );
    return '$_temp0';
  }

  @override
  String get profileCollaboratorInvitePendingDetail =>
      'Bọn mình đã giữ lời mời trong hàng chờ. Thử gửi lại tại đây nhé.';

  @override
  String profileCollaboratorInvitePendingDetailWithTitle(String title) {
    return 'Cho \"$title\". Thử gửi lại tại đây nhé.';
  }

  @override
  String get profileCollaboratorInviteRetryAction => 'Thử lại';

  @override
  String get profileCollaboratorInviteRetryingAction => 'Đang thử lại';

  @override
  String get profileCollaboratorInviteRetryUnavailable =>
      'Hiện chưa thể gửi lại lời mời cộng tác.';

  @override
  String profileCollaboratorInviteRetryResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vẫn còn $count lời mời cộng tác chưa gửi được.',
      one: 'Vẫn còn 1 lời mời cộng tác chưa gửi được.',
      zero: 'Đã gửi lời mời cộng tác.',
    );
    return '$_temp0';
  }

  @override
  String profileCollaboratorInviteBlockedResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cộng tác viên không thể nhận lời mời.',
      one: '1 cộng tác viên không thể nhận lời mời.',
    );
    return '$_temp0';
  }

  @override
  String profileFollowerCountUsers(int count) {
    return '$count người dùng';
  }

  @override
  String profileBlockTitle(String displayName) {
    return 'Chặn $displayName?';
  }

  @override
  String get profileBlockExplanation => 'Khi bạn chặn một người dùng:';

  @override
  String get profileBlockBulletHidePosts =>
      'Bài đăng của họ sẽ không xuất hiện trong bảng tin của bạn.';

  @override
  String get profileBlockBulletCantView =>
      'Họ sẽ không thể xem hồ sơ, theo dõi bạn hoặc xem bài đăng của bạn.';

  @override
  String get profileBlockBulletNoNotify =>
      'Họ sẽ không được thông báo về thay đổi này.';

  @override
  String get profileBlockBulletYouCanView => 'Bạn vẫn có thể xem hồ sơ của họ.';

  @override
  String profileBlockConfirmButton(String displayName) {
    return 'Chặn $displayName';
  }

  @override
  String get profileCancelButton => 'Hủy';

  @override
  String get profileLearnMore => 'Tìm hiểu thêm';

  @override
  String profileUnblockTitle(String displayName) {
    return 'Bỏ chặn $displayName?';
  }

  @override
  String get profileUnblockExplanation => 'Khi bạn bỏ chặn người dùng này:';

  @override
  String get profileUnblockBulletShowPosts =>
      'Bài đăng của họ sẽ xuất hiện trong bảng tin của bạn.';

  @override
  String get profileUnblockBulletCanView =>
      'Họ sẽ có thể xem hồ sơ, theo dõi bạn và xem bài đăng của bạn.';

  @override
  String get profileUnblockBulletNoNotify =>
      'Họ sẽ không được thông báo về thay đổi này.';

  @override
  String get profileLearnMoreAt => 'Tìm hiểu thêm tại ';

  @override
  String get profileUnblockButton => 'Bỏ chặn';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return 'Bỏ theo dõi $displayName';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return 'Chặn $displayName';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return 'Bỏ chặn $displayName';
  }

  @override
  String profileReportDisplayName(String displayName) {
    return 'Báo cáo $displayName';
  }

  @override
  String profileAddToListDisplayName(String displayName) {
    return 'Thêm $displayName vào danh sách';
  }

  @override
  String get profileNoCollabsTitle => 'Chưa có video cộng tác nào';

  @override
  String get profileCollabsOwnEmpty =>
      'Những video bạn cộng tác sẽ xuất hiện ở đây.';

  @override
  String get profileCollabsOtherEmpty =>
      'Những video họ cộng tác sẽ xuất hiện ở đây.';

  @override
  String get profileErrorLoadingCollabs => 'Lỗi khi tải video cộng tác';

  @override
  String get profileNoSavedVideosTitle => 'Chưa lưu gì cả';

  @override
  String get profileSavedOwnEmpty =>
      'Lưu video từ bảng chia sẻ và chúng sẽ xuất hiện ở đây.';

  @override
  String get profileErrorLoadingSaved => 'Lỗi khi tải video đã lưu';

  @override
  String get profileNoCommentsOwnTitle => 'Chưa có bình luận nào';

  @override
  String get profileNoCommentsOtherTitle => 'Chưa có bình luận nào';

  @override
  String get profileCommentsOwnEmpty =>
      'Bình luận và câu trả lời của bạn sẽ xuất hiện ở đây.';

  @override
  String get profileCommentsOtherEmpty =>
      'Bình luận và câu trả lời của họ sẽ xuất hiện ở đây.';

  @override
  String get profileErrorLoadingComments => 'Lỗi khi tải bình luận';

  @override
  String get profileVideoRepliesSection => 'Video phản hồi';

  @override
  String get profileCommentsSection => 'Bình luận';

  @override
  String get profileEditLabel => 'Chỉnh sửa';

  @override
  String get profileLibraryLabel => 'Thư viện';

  @override
  String get profileNoLikedVideosTitle => 'Chưa có lượt thích nào';

  @override
  String get profileLikedOwnEmpty =>
      'Khi có gì đó đập vào mắt bạn, hãy chạm vào trái tim. Các lượt thích của bạn sẽ xuất hiện ở đây.';

  @override
  String get profileLikedOtherEmpty =>
      'Chưa có gì lọt vào mắt xanh của họ. Kiên nhẫn chờ nhé.';

  @override
  String get profileErrorLoadingLiked => 'Lỗi khi tải video đã thích';

  @override
  String get profileNoRepostsTitle => 'Chưa có bài đăng lại nào';

  @override
  String get profileRepostsOwnEmpty =>
      'Thấy gì đáng chia sẻ không? Đăng lại và nó sẽ xuất hiện ở đây.';

  @override
  String get profileRepostsOtherEmpty =>
      'Họ chưa chia sẻ lại gì cả. Khi nào có, bạn sẽ thấy ở đây.';

  @override
  String get profileErrorLoadingReposts => 'Lỗi khi tải video đã đăng lại';

  @override
  String get profileNoVideosTitle => 'Chưa có video nào';

  @override
  String get profileNoVideosOwnSubtitle =>
      'Sân khấu đã dựng xong. Bắt đầu đăng và video của bạn sẽ ở đây.';

  @override
  String get profileNoVideosOtherSubtitle =>
      'Cả thế giới đang chờ. Theo dõi họ để không bỏ lỡ nhé.';

  @override
  String profileVideoThumbnailLabel(int number) {
    return 'Ảnh thu nhỏ video $number';
  }

  @override
  String get profileShowMore => 'Xem thêm';

  @override
  String get profileShowLess => 'Thu gọn';

  @override
  String get dmMessageDisplayLimitReached =>
      'Phần còn lại của tin nhắn này không được hiển thị.';

  @override
  String get profileCompleteYourProfile => 'Hoàn thiện hồ sơ của bạn';

  @override
  String get profileCompleteSubtitle => 'Thêm tên, tiểu sử và ảnh để bắt đầu';

  @override
  String get profilePleaseTryAgain => 'Vui lòng thử lại';

  @override
  String get profileSecureYourAccount => 'Bảo mật tài khoản của bạn';

  @override
  String get profileSecureSubtitle =>
      'Thêm email & mật khẩu để khôi phục tài khoản trên mọi thiết bị';

  @override
  String get profileRetryButton => 'Thử lại';

  @override
  String get profileSessionExpired => 'Phiên đăng nhập đã hết hạn';

  @override
  String get profileSignInToRestore =>
      'Đăng nhập lại để khôi phục toàn bộ quyền truy cập';

  @override
  String get profileSignInButton => 'Đăng nhập';

  @override
  String get profileMaybeLaterLabel => 'Để sau';

  @override
  String get profileSecurePrimaryButton => 'Thêm email & mật khẩu';

  @override
  String get profileCompletePrimaryButton => 'Cập nhật hồ sơ của bạn';

  @override
  String get profileLoopsLabel => 'Loop';

  @override
  String get profileLikesLabel => 'Lượt thích';

  @override
  String get profileMyLibraryLabel => 'Thư viện của tôi';

  @override
  String get profileMessageLabel => 'Tin nhắn';

  @override
  String get profileShareLabel => 'Chia sẻ hồ sơ';

  @override
  String get profileDeletedAccountName => 'Tài khoản đã xóa';

  @override
  String get inboxActionReportVanishedAccount => 'Báo cáo tài khoản này';

  @override
  String get inboxActionBlockVanishedAccount => 'Chặn tài khoản này';

  @override
  String get inboxActionUnblockVanishedAccount => 'Bỏ chặn tài khoản này';

  @override
  String get inboxReportedVanishedAccount => 'Đã báo cáo tài khoản này';

  @override
  String get inboxBlockedVanishedAccount => 'Đã chặn tài khoản này';

  @override
  String get inboxUnblockedVanishedAccount => 'Đã bỏ chặn tài khoản này';

  @override
  String get inboxRemoveConfirmBodyVanishedAccount =>
      'Thao tác này xóa cuộc trò chuyện khỏi hộp thư đến. Nếu họ nhắn tin cho bạn lần nữa, một cuộc trò chuyện mới sẽ bắt đầu.';

  @override
  String get inboxConversationDeletedAccountSubtitle =>
      'Tài khoản này đã bị xóa';

  @override
  String get profileUserFallback => 'người dùng';

  @override
  String get profileLinkCopied => 'Đã sao chép liên kết hồ sơ';

  @override
  String get profileSetupEditProfileTitle => 'Chỉnh sửa hồ sơ';

  @override
  String get nostrSettingsNip05ProfileRequired =>
      'Hãy thiết lập hồ sơ trước khi thêm địa chỉ NIP-05.';

  @override
  String get nostrSettingsNip05CreateProfileAction => 'Tạo hồ sơ';

  @override
  String get profileSetupBackLabel => 'Quay lại';

  @override
  String get profileSetupAboutNostr => 'Về Nostr';

  @override
  String get profileSetupProfilePublished => 'Đã đăng hồ sơ thành công!';

  @override
  String get profileSetupUnsavedChangesTitle => 'Lưu thay đổi?';

  @override
  String get profileSetupUnsavedChangesSubtitle =>
      'Lưu chỉnh sửa của bạn trước khi rời đi, hoặc bỏ chúng và đi tiếp.';

  @override
  String get profileSetupUnsavedChangesSaveButton => 'Lưu thay đổi';

  @override
  String get profileSetupUnsavedChangesDiscardButton => 'Bỏ thay đổi';

  @override
  String get profileSetupUnsavedChangesKeepButton => 'Tiếp tục chỉnh sửa';

  @override
  String get profileSetupCreateNewProfile => 'Tạo hồ sơ mới?';

  @override
  String get profileSetupNoExistingProfile =>
      'Bọn mình không tìm thấy hồ sơ nào trên các relay của bạn. Đăng bây giờ sẽ tạo một hồ sơ mới. Tiếp tục chứ?';

  @override
  String get profileSetupPublishButton => 'Đăng';

  @override
  String get profileSetupUsernameTaken =>
      'Tên người dùng vừa bị người khác lấy mất. Hãy chọn tên khác nhé.';

  @override
  String get profileSetupClaimFailed =>
      'Không thể đăng ký tên người dùng. Vui lòng thử lại.';

  @override
  String get profileSetupPublishFailed =>
      'Không thể đăng hồ sơ. Vui lòng thử lại.';

  @override
  String get profileSetupNoRelaysConnected =>
      'Không kết nối được với mạng. Kiểm tra kết nối của bạn rồi thử lại nhé.';

  @override
  String get profileSetupDisplayNameLabel => 'Tên hiển thị';

  @override
  String get profileSetupDisplayNameRequired => 'Vui lòng nhập tên hiển thị';

  @override
  String get profileSetupBioLabel => 'Tiểu sử (Không bắt buộc)';

  @override
  String get profileSetupWebsiteLabel => 'Website (Không bắt buộc)';

  @override
  String get profileSetupPublicKeyLabel => 'Khóa công khai (npub)';

  @override
  String get profileSetupUsernameLabel => 'Tên người dùng (Không bắt buộc)';

  @override
  String get profileSetupUsernameHelper =>
      'Dùng chữ cái, chữ số hoặc dấu gạch nối. Tên người dùng sẽ trở thành địa chỉ divine.video. Dùng tên hiển thị cho khoảng trắng hoặc ký hiệu.';

  @override
  String get profileSetupSaveButton => 'Lưu';

  @override
  String get profileSetupSavingButton => 'Đang lưu...';

  @override
  String get profileSetupImageUrlTitle => 'Thêm URL hình ảnh';

  @override
  String get profileSetupImageSelectionFailed =>
      'Không chọn được ảnh. Hãy dán URL hình ảnh vào bên dưới nhé.';

  @override
  String get profileSetupImagesTypeGroup => 'hình ảnh';

  @override
  String get cameraPickErrorPermissionDenied =>
      'Quyền camera đang tắt. Bật trong Cài đặt để chụp ảnh.';

  @override
  String get cameraPickErrorPermissionRestricted =>
      'Thiết bị này không cho phép truy cập camera.';

  @override
  String get cameraPickErrorBusy =>
      'Bộ chọn đang mở rồi. Đóng lại rồi thử lại.';

  @override
  String get cameraPickErrorGeneric => 'Không mở được camera. Thử lại nhé.';

  @override
  String get profileSetupGotItButton => 'Đã hiểu';

  @override
  String get profileSetupUploadFailedGeneric =>
      'Tải lên thất bại. Vui lòng thử lại sau.';

  @override
  String get profileSetupUploadNetworkError =>
      'Lỗi mạng: Hãy kiểm tra kết nối internet của bạn rồi thử lại.';

  @override
  String get profileSetupUploadAuthError =>
      'Lỗi xác thực: Hãy thử đăng xuất rồi đăng nhập lại.';

  @override
  String get profileSetupUploadFileTooLarge =>
      'Tệp quá lớn: Hãy chọn ảnh nhỏ hơn (tối đa 10MB).';

  @override
  String get profileSetupUploadServerError =>
      'Tải lên thất bại. Máy chủ của bọn mình đang tạm thời không khả dụng. Vui lòng thử lại sau ít phút.';

  @override
  String get profileSetupBannerClearButton => 'Xóa ảnh bìa';

  @override
  String get profileSetupBannerChangeColor => 'Màu biểu ngữ';

  @override
  String get profileSetupChangeBannerTitle => 'Đổi biểu ngữ';

  @override
  String get profileSetupBannerColorPickerTitle => 'Đổi màu biểu ngữ';

  @override
  String get profileSetupBannerColorCustom => 'Tùy chỉnh';

  @override
  String get profileSetupBannerColorNone => 'Không màu';

  @override
  String get profileSetupBannerColorLime => 'Xanh chanh';

  @override
  String get profileSetupBannerColorYellow => 'Vàng';

  @override
  String get profileSetupBannerColorViolet => 'Tím nhạt';

  @override
  String get profileSetupBannerColorPink => 'Hồng';

  @override
  String get profileSetupBannerColorOrange => 'Cam';

  @override
  String get profileSetupBannerColorPurple => 'Tím';

  @override
  String get profileSetupAvatarClearButton => 'Xóa ảnh';

  @override
  String get profileSetupImageTakePhoto => 'Chụp ảnh';

  @override
  String get profileSetupImageUploadFromCameraRoll => 'Tải lên từ thư viện ảnh';

  @override
  String get profileSetupImagePasteLink => 'Dán liên kết hình ảnh';

  @override
  String get profileSetupEditAvatarLabel => 'Chỉnh sửa ảnh đại diện';

  @override
  String get profileSetupEditBannerLabel => 'Chỉnh sửa biểu ngữ';

  @override
  String get profileSetupUsernameChecking => 'Đang kiểm tra...';

  @override
  String get profileSetupUsernameAvailable => 'Tên người dùng còn trống!';

  @override
  String get profileSetupUsernameTakenIndicator =>
      'Tên người dùng đã có người dùng';

  @override
  String get profileSetupUsernameReserved => 'Tên người dùng đã được giữ';

  @override
  String get profileSetupContactSupport => 'Liên hệ hỗ trợ';

  @override
  String get profileSetupCheckAgain => 'Kiểm tra lại';

  @override
  String get profileSetupUsernameBurned =>
      'Tên người dùng này không còn khả dụng';

  @override
  String get profileSetupUsernameInvalidFormat =>
      'Chỉ được dùng chữ cái, số và dấu gạch ngang';

  @override
  String get profileSetupUsernameInvalidHyphenPlacement =>
      'Tên người dùng không thể bắt đầu hoặc kết thúc bằng dấu gạch nối';

  @override
  String get profileSetupUsernameInvalidLength =>
      'Tên người dùng phải dài 3-63 ký tự';

  @override
  String get profileSetupUsernameNetworkError =>
      'Không kiểm tra được. Vui lòng thử lại.';

  @override
  String get profileSetupUsernameInvalidFormatGeneric =>
      'Định dạng tên người dùng không hợp lệ';

  @override
  String get profileSetupUsernameCheckFailed => 'Không kiểm tra được tên này';

  @override
  String get profileSetupUsernameReservedTitle => 'Tên người dùng đã được giữ';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return 'Tên $username đã được giữ. Hãy cho bọn mình biết tại sao nó nên thuộc về bạn.';
  }

  @override
  String get profileSetupUsernameReservedHint =>
      'VD: Đó là tên thương hiệu, nghệ danh của tôi...';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      'Đã liên hệ hỗ trợ rồi? Chạm \"Kiểm tra lại\" để xem tên đã được nhả cho bạn chưa.';

  @override
  String get profileSetupSupportRequestSent =>
      'Đã gửi yêu cầu hỗ trợ! Bọn mình sẽ phản hồi sớm.';

  @override
  String get profileSetupCouldntOpenEmail =>
      'Không mở được email. Hãy gửi tới: names@divine.video';

  @override
  String get profileSetupSendRequest => 'Gửi yêu cầu';

  @override
  String get profileSetupUseOwnNip05 => 'Dùng địa chỉ NIP-05 của riêng bạn';

  @override
  String get profileSetupNip05AddressLabel => 'Địa chỉ NIP-05';

  @override
  String get profileSetupExternalNip05InvalidFormat =>
      'Định dạng NIP-05 không hợp lệ (VD: name@domain.com)';

  @override
  String get profileSetupExternalNip05DivineDomain =>
      'Hãy dùng ô tên người dùng ở trên cho divine.video';

  @override
  String get nostrSettingsNip05Address => 'Địa chỉ NIP-05';

  @override
  String get nostrSettingsNip05AddressSubtitle =>
      'Dùng tên người dùng divine.video của bạn, hoặc trỏ tên định danh tới một địa chỉ NIP-05 trên tên miền bạn kiểm soát.';

  @override
  String get nostrSettingsNip05AddressHint => 'ban@example.com';

  @override
  String get nostrSettingsNip05SaveAction => 'Lưu NIP-05';

  @override
  String get nostrSettingsNip05Saved => 'Đã lưu NIP-05';

  @override
  String get nostrSettingsNip05SaveFailed =>
      'Không lưu được NIP-05. Vui lòng thử lại.';

  @override
  String get profileSetupNip05ConfirmTitle => 'Dùng NIP-05 của riêng bạn?';

  @override
  String get profileSetupNip05ConfirmBody =>
      'NIP-05 liên kết một tên như ban@tenmiencuaban.com với danh tính Nostr của bạn. Bạn cần kiểm soát tên miền đó và lưu một tệp xác minh ở đúng đường dẫn. Nếu làm sai, mọi người sẽ không tìm thấy bạn và tên định danh đã xác minh của bạn sẽ biến mất. Chỉ tiếp tục nếu bạn đã thiết lập xong.';

  @override
  String get profileSetupNip05ConfirmContinue => 'Tiếp tục';

  @override
  String get profileSetupNip05ConfirmCancel => 'Hủy';

  @override
  String get profileSetupProfilePicturePreview => 'Xem trước ảnh đại diện';

  @override
  String get nostrInfoIntroBuiltOn => 'Divine được xây dựng trên Nostr,';

  @override
  String get nostrInfoIntroDescription =>
      ' một giao thức mở chống kiểm duyệt, cho phép mọi người giao tiếp trực tuyến mà không phụ thuộc vào một công ty hay nền tảng duy nhất. ';

  @override
  String get nostrInfoIntroIdentity =>
      'Khi bạn đăng ký Divine, bạn sẽ có một danh tính Nostr mới.';

  @override
  String get nostrInfoOwnership =>
      'Nostr cho phép bạn sở hữu nội dung, danh tính và đồ thị xã hội của mình, và mang chúng đi qua nhiều ứng dụng khác nhau. Kết quả là nhiều lựa chọn hơn, ít bị trói buộc hơn, và một internet xã hội lành mạnh, bền vững hơn.';

  @override
  String get nostrInfoLingo => 'Thuật ngữ Nostr:';

  @override
  String get nostrInfoNpubLabel => 'npub:';

  @override
  String get nostrInfoNpubDescription =>
      ' Địa chỉ Nostr công khai của bạn. Có thể chia sẻ thoải mái và giúp người khác tìm, theo dõi hoặc nhắn tin cho bạn trên các ứng dụng Nostr.';

  @override
  String get nostrInfoNsecLabel => 'nsec:';

  @override
  String get nostrInfoNsecDescription =>
      ' Khóa riêng tư và bằng chứng sở hữu của bạn. Nó cho quyền kiểm soát toàn bộ danh tính Nostr của bạn, vì vậy ';

  @override
  String get nostrInfoNsecWarning => 'hãy luôn giữ kín nó!';

  @override
  String get nostrInfoUsernameLabel => 'Tên người dùng Nostr:';

  @override
  String get nostrInfoUsernameDescription =>
      ' Một tên dễ đọc (như @name.divine.video) liên kết tới npub của bạn. Nó giúp danh tính Nostr của bạn dễ nhận ra và dễ xác minh hơn, giống như địa chỉ email vậy.';

  @override
  String get nostrInfoLearnMoreAt => 'Tìm hiểu thêm tại ';

  @override
  String get nostrInfoGotIt => 'Đã hiểu!';

  @override
  String get videoGridRefreshLabel => 'Đang tìm thêm video';

  @override
  String get videoGridOptionsTitle => 'Tùy chọn video';

  @override
  String get videoGridEditVideo => 'Chỉnh sửa video';

  @override
  String get videoGridEditVideoSubtitle => 'Cập nhật tiêu đề, mô tả và hashtag';

  @override
  String get videoGridDeleteVideo => 'Xóa video';

  @override
  String get videoGridDeleteVideoSubtitle =>
      'Gỡ video này khỏi Divine. Nó vẫn có thể xuất hiện trên các ứng dụng Nostr khác.';

  @override
  String get videoGridDeletingContent => 'Đang xóa nội dung...';

  @override
  String get exploreTabFeatured => 'Nổi bật';

  @override
  String get exploreTabClassics => 'Kinh điển';

  @override
  String get exploreTabNew => 'Mới';

  @override
  String get exploreTabPopular => 'Phổ biến';

  @override
  String get exploreTabCategories => 'Danh mục';

  @override
  String get exploreTabForYou => 'Dành cho bạn';

  @override
  String get exploreTabLists => 'Danh sách';

  @override
  String get exploreTabIntegratedApps => 'Ứng dụng tích hợp';

  @override
  String exploreFeaturedSponsoredBy(String sponsor) {
    return 'Sponsored by $sponsor';
  }

  @override
  String exploreFeaturedSponsoredPillSemanticLabel(String name) {
    return '$name, sponsored';
  }

  @override
  String get featuredTabEmpty => 'Chưa có gì ở đây. Quay lại sau nhé.';

  @override
  String get featuredTabLoadFailed => 'Không tải được bộ sưu tập này.';

  @override
  String get featuredTabRetry => 'Thử lại';

  @override
  String get exploreNoVideosAvailable => 'Không có video nào';

  @override
  String get exploreDiscoverLists => 'Khám phá danh sách';

  @override
  String get exploreAboutLists => 'Về danh sách';

  @override
  String get exploreAboutListsDescription =>
      'Danh sách giúp bạn sắp xếp và tuyển chọn nội dung Divine theo hai cách:';

  @override
  String get explorePeopleLists => 'Danh sách người';

  @override
  String get explorePeopleListsDescription =>
      'Theo dõi nhóm nhà sáng tạo và xem video mới nhất của họ';

  @override
  String get exploreVideoLists => 'Danh sách video';

  @override
  String get exploreVideoListsDescription =>
      'Tạo danh sách phát từ những video yêu thích để xem sau';

  @override
  String get exploreMyLists => 'Danh sách của tôi';

  @override
  String get exploreSubscribedLists => 'Danh sách đã đăng ký';

  @override
  String get exploreErrorLoadingLists =>
      'Lỗi khi tải danh sách. Vui lòng thử lại.';

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count video mới',
      one: '1 video mới',
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
    return 'Tải $count $_temp0 mới';
  }

  @override
  String get videoPlayerPlayVideo => 'Phát video';

  @override
  String get videoPlayerMute => 'Tắt tiếng video';

  @override
  String get videoPlayerUnmute => 'Bật tiếng video';

  @override
  String get videoPlayerTapHint =>
      'Chạm để phát hoặc tạm dừng. Chạm hai lần để thích.';

  @override
  String get videoSettingsMenuOpen => 'Mở cài đặt phát lại';

  @override
  String get videoSettingsMenuClose => 'Đóng cài đặt phát lại';

  @override
  String get videoSettingsCaptionsEnable => 'Bật phụ đề';

  @override
  String get videoSettingsCaptionsDisable => 'Tắt phụ đề';

  @override
  String get videoSettingsAutoAdvanceOn => 'Đã bật tự động chuyển video';

  @override
  String get videoSettingsAutoAdvanceOff => 'Đã tắt tự động chuyển video';

  @override
  String get videoSettingsCaptionsOn => 'Đã bật phụ đề';

  @override
  String get videoSettingsCaptionsOff => 'Đã tắt phụ đề';

  @override
  String get videoSettingsCaptionsOnForVideo => 'Đã bật phụ đề cho video này';

  @override
  String get videoSettingsCaptionsOffForVideo => 'Đã tắt phụ đề cho video này';

  @override
  String get contentWarningLabel => 'Cảnh báo nội dung';

  @override
  String get contentWarningNudity => 'Khỏa thân';

  @override
  String get contentWarningSexualContent => 'Nội dung tình dục';

  @override
  String get contentWarningPornography => 'Nội dung khiêu dâm';

  @override
  String get contentWarningGraphicMedia => 'Hình ảnh rùng rợn';

  @override
  String get contentWarningViolence => 'Bạo lực';

  @override
  String get contentWarningSelfHarm => 'Tự gây hại';

  @override
  String get contentWarningDrugUse => 'Sử dụng ma túy';

  @override
  String get contentWarningAlcohol => 'Rượu bia';

  @override
  String get contentWarningTobacco => 'Thuốc lá';

  @override
  String get contentWarningGambling => 'Cờ bạc';

  @override
  String get contentWarningProfanity => 'Ngôn từ thô tục';

  @override
  String get contentWarningFlashingLights => 'Ánh sáng nhấp nháy';

  @override
  String get contentWarningAiGenerated => 'Do AI tạo ra';

  @override
  String get contentWarningSpoiler => 'Tiết lộ nội dung';

  @override
  String get contentWarningSensitiveContent => 'Nội dung nhạy cảm';

  @override
  String get contentWarningDescNudity =>
      'Chứa cảnh khỏa thân hoàn toàn hoặc một phần';

  @override
  String get contentWarningDescSexual => 'Chứa nội dung tình dục';

  @override
  String get contentWarningDescPorn => 'Chứa nội dung khiêu dâm lộ liễu';

  @override
  String get contentWarningDescGraphicMedia =>
      'Chứa hình ảnh rùng rợn hoặc gây khó chịu';

  @override
  String get contentWarningDescViolence => 'Chứa nội dung bạo lực';

  @override
  String get contentWarningDescSelfHarm =>
      'Chứa nội dung liên quan đến tự gây hại';

  @override
  String get contentWarningDescDrugs => 'Chứa nội dung liên quan đến ma túy';

  @override
  String get contentWarningDescAlcohol =>
      'Chứa nội dung liên quan đến rượu bia';

  @override
  String get contentWarningDescTobacco =>
      'Chứa nội dung liên quan đến thuốc lá';

  @override
  String get contentWarningDescGambling => 'Chứa nội dung liên quan đến cờ bạc';

  @override
  String get contentWarningDescProfanity => 'Chứa ngôn từ thô tục';

  @override
  String get contentWarningDescFlashingLights =>
      'Chứa ánh sáng nhấp nháy (cảnh báo cho người nhạy cảm với ánh sáng)';

  @override
  String get contentWarningDescAiGenerated => 'Nội dung này do AI tạo ra';

  @override
  String get contentWarningDescSpoiler => 'Chứa tiết lộ nội dung';

  @override
  String get contentWarningDescContentWarning =>
      'Nhà sáng tạo đã đánh dấu nội dung này là nhạy cảm';

  @override
  String get contentWarningDescDefault => 'Nhà sáng tạo đã gắn cờ nội dung này';

  @override
  String get contentWarningDetailsTitle => 'Cảnh báo nội dung';

  @override
  String get contentWarningDetailsSubtitle =>
      'Nhà sáng tạo đã áp dụng các nhãn này:';

  @override
  String get contentWarningManageFilters => 'Quản lý bộ lọc nội dung';

  @override
  String get contentWarningViewAnyway => 'Vẫn xem';

  @override
  String get contentWarningReportContentTooltip => 'Báo cáo nội dung';

  @override
  String get contentWarningBlockUserTooltip => 'Chặn người dùng';

  @override
  String get contentWarningBlockedTitle => 'Nội dung bị chặn';

  @override
  String get contentWarningBlockedPolicy =>
      'Nội dung này đã bị chặn do vi phạm chính sách.';

  @override
  String get contentWarningNoticeTitle => 'Lưu ý về nội dung';

  @override
  String get contentWarningPotentiallyHarmfulTitle => 'Nội dung có thể gây hại';

  @override
  String get contentWarningView => 'Xem';

  @override
  String get contentWarningReportAction => 'Báo cáo';

  @override
  String get contentWarningHideAllLikeThis => 'Ẩn tất cả nội dung kiểu này';

  @override
  String get contentWarningNoFilterYet =>
      'Chưa có bộ lọc nào cho cảnh báo này.';

  @override
  String get contentWarningHiddenConfirmation =>
      'Từ giờ bọn mình sẽ ẩn các bài đăng như thế này.';

  @override
  String get communitySuggestTitle => 'Giúp phân loại video này';

  @override
  String get communitySuggestSubtitle =>
      'Thiếu cảnh báo nội dung? Gợi ý của bạn là công khai, có chữ ký và không thể rút lại.';

  @override
  String get communitySuggestSubmit => 'Gợi ý';

  @override
  String get communitySuggestSuccess => 'Cảm ơn bạn. Gợi ý đã được gửi.';

  @override
  String get communitySuggestFailure =>
      'Không gửi được gợi ý của bạn. Thử lại nhé.';

  @override
  String get communitySuggestAlready => 'Bạn đã gợi ý nhãn này';

  @override
  String get communitySuggestActionLabel => 'Phân loại';

  @override
  String get videoErrorNotFound => 'Không tìm thấy video';

  @override
  String get videoErrorPlayback => 'Lỗi phát video';

  @override
  String get videoErrorAgeRestricted => 'Nội dung giới hạn độ tuổi';

  @override
  String get videoErrorUnavailable => 'Video không khả dụng';

  @override
  String get videoErrorUnavailableBody => 'Video này hiện không khả dụng.';

  @override
  String get videoErrorRetry => 'Thử lại';

  @override
  String get videoErrorContentRestricted => 'Nội dung bị hạn chế';

  @override
  String get videoErrorContentRestrictedBody =>
      'Video này đã bị gỡ vì vi phạm quy tắc nội dung của bọn mình.';

  @override
  String get videoErrorVerifyAgeBody =>
      'Xác minh tuổi của bạn để xem video này.';

  @override
  String get videoErrorSkip => 'Bỏ qua';

  @override
  String get videoErrorVerifyAgeButton => 'Xác minh tuổi';

  @override
  String get videoErrorVerifyAgeFailed =>
      'Không xác minh được tuổi của bạn. Vui lòng thử lại.';

  @override
  String get videoErrorVerifyAgeSignerUnreachable =>
      'Xác minh đã hết thời gian chờ. Kiểm tra kết nối của bạn hoặc thử lại sau ít phút.';

  @override
  String get videoErrorAdultContentHiddenTitle => 'Nội dung người lớn đang tắt';

  @override
  String get videoErrorAdultContentHiddenBody =>
      'Bật trong bộ lọc nội dung để xem video này.';

  @override
  String get videoErrorAdultContentHiddenAction => 'Mở bộ lọc nội dung';

  @override
  String get videoDetailLoadError => 'Không thể tải video';

  @override
  String get videoDetailLoadErrorBody =>
      'Có gì đó trục trặc trên đường tới đây. Thử lại nhé.';

  @override
  String get videoDetailNotFoundBody =>
      'Có thể nó đã bị xoá, ngoài tầm với, hoặc bị ẩn bởi cài đặt của bạn.';

  @override
  String get databaseCorruptionTitle => 'Dữ liệu cục bộ của bạn bị rối tung';

  @override
  String get databaseCorruptionBody =>
      'Đóng Divine rồi mở lại — bọn mình sẽ tự động vá nó. Bọn mình sẽ cứu những bản nháp và clip nào cứu được, mọi thứ khác sẽ được tải lại.';

  @override
  String get databaseCorruptionCloseButton => 'Đóng Divine';

  @override
  String get videoDetailContextTitle => 'Video được chia sẻ';

  @override
  String get videoDetailCloseSemanticLabel => 'Đóng trình phát video';

  @override
  String get videoFollowButtonFollow => 'Theo dõi';

  @override
  String get audioAttributionOriginalSound => 'Âm thanh gốc';

  @override
  String get audioAttributionUnavailableSound => 'Âm thanh không khả dụng';

  @override
  String videoInspiredByAttributionMultiple(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return 'Lấy cảm hứng từ @$creatorName +$additionalCreatorCount';
  }

  @override
  String videoInspiredByAttribution(String creatorName) {
    return 'Lấy cảm hứng từ @$creatorName';
  }

  @override
  String videoCollaboratorWithOne(String name) {
    return 'cùng @$name';
  }

  @override
  String videoCollaboratorWithMore(String name, int count) {
    return 'cùng @$name +$count';
  }

  @override
  String videoCollaboratorCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cộng tác viên',
      one: '1 cộng tác viên',
    );
    return '$_temp0. Chạm để xem hồ sơ.';
  }

  @override
  String get videoCollaboratorPendingDecoration => 'Đang chờ';

  @override
  String get videoCollaboratorPendingSemanticLabel => 'Cộng tác viên đang chờ';

  @override
  String videoCollaboratorWithPendingSuffix(String label, int pending) {
    return '$label ($pending đang chờ)';
  }

  @override
  String profileChipTapHint(String name) {
    return '$name. Chạm để xem hồ sơ.';
  }

  @override
  String metadataHashtagChipTapHint(String hashtag) {
    return '#$hashtag. Chạm để xem video với hashtag này.';
  }

  @override
  String get listAttributionFallback => 'Danh sách';

  @override
  String get shareVideoLabel => 'Chia sẻ video';

  @override
  String sharePostSharedWith(String recipientName) {
    return 'Đã chia sẻ bài đăng với $recipientName';
  }

  @override
  String sharePostSharedWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Đã chia sẻ bài đăng với $count người',
      one: 'Đã chia sẻ bài đăng với $count người',
    );
    return '$_temp0';
  }

  @override
  String get shareFailedToSend => 'Không gửi được video';

  @override
  String get shareAddedToBookmarks => 'Đã thêm vào dấu trang';

  @override
  String get shareRemovedFromBookmarks => 'Đã xóa khỏi dấu trang';

  @override
  String get shareFailedToAddBookmark => 'Không thêm được dấu trang';

  @override
  String get shareFailedToRemoveBookmark => 'Không xóa được dấu trang';

  @override
  String get shareActionFailed => 'Thao tác thất bại';

  @override
  String get shareWithTitle => 'Chia sẻ với';

  @override
  String get shareFindPeople => 'Tìm người';

  @override
  String get shareFindPeopleMultiline => 'Tìm\nngười';

  @override
  String get shareSent => 'Đã gửi';

  @override
  String shareSelectedRecipientAnnouncement(String name) {
    return 'Đã chọn $name';
  }

  @override
  String get shareMessageHint => 'Thêm tin nhắn (không bắt buộc)...';

  @override
  String get videoActionUnlike => 'Bỏ thích video';

  @override
  String get videoActionLike => 'Thích video';

  @override
  String get videoActionAutoLabel => 'Tuyển tập';

  @override
  String get videoActionLikeLabel => 'Thích';

  @override
  String get videoActionReplyLabel => 'Trả lời';

  @override
  String get videoActionRepostLabel => 'Revine';

  @override
  String get videoActionShareLabel => 'Chia sẻ';

  @override
  String get videoActionReportLabel => 'Báo cáo';

  @override
  String get videoActionReport => 'Báo cáo video';

  @override
  String get videoActionEditLabel => 'Sửa';

  @override
  String get videoActionEdit => 'Chỉnh sửa video';

  @override
  String get videoActionAboutLabel => 'Giới thiệu';

  @override
  String get videoActionEnableAutoAdvance => 'Bật tự động chuyển video';

  @override
  String get videoActionDisableAutoAdvance => 'Tắt tự động chuyển video';

  @override
  String get videoActionRemoveRepost => 'Gỡ bài đăng lại';

  @override
  String get videoActionRepost => 'Đăng lại video';

  @override
  String get videoActionViewComments => 'Xem bình luận';

  @override
  String get videoActionMoreOptions => 'Tùy chọn khác';

  @override
  String get videoEngagementLikersTitle => 'Người đã thích';

  @override
  String get videoEngagementRepostersTitle => 'Người đã đăng lại';

  @override
  String get videoEngagementLikersEmpty => 'Chưa có lượt thích nào';

  @override
  String get videoEngagementRepostersEmpty => 'Chưa có bài đăng lại nào';

  @override
  String get videoEngagementLoadFailed => 'Không tải được danh sách đó';

  @override
  String get videoOverlayOpenMetadataFromTitle => 'Mở chi tiết video';

  @override
  String get videoOverlayOpenMetadataFromDescription => 'Mở chi tiết video';

  @override
  String get videoOverlayCommentBarHint => 'Thêm bình luận...';

  @override
  String get videoOverlayCommentBarSemanticLabel => 'Thêm bình luận';

  @override
  String get videoOverlayCommentBarSendLabel => 'Gửi bình luận';

  @override
  String get videoOverlayCommentPostedSnackbar => 'Đã đăng bình luận';

  @override
  String get videoOverlayCommentPostFailedSnackbar =>
      'Không đăng được bình luận';

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
  String get metadataBadgeNotDivine => 'Không phải Divine';

  @override
  String get metadataBadgeHumanMade => 'Do người làm';

  @override
  String get metadataSoundsLabel => 'Âm thanh';

  @override
  String get metadataOriginalSound => 'Âm thanh gốc';

  @override
  String get metadataVerificationLabel => 'Xác minh';

  @override
  String get metadataDeviceAttestation => 'Chứng thực thiết bị';

  @override
  String get metadataPgpSignature => 'Chữ ký PGP';

  @override
  String get metadataC2paCredentials => 'Chứng nhận nội dung C2PA';

  @override
  String get metadataProofManifest => 'Tệp chứng minh';

  @override
  String get metadataVerificationInfoTooltip =>
      'Những kiểm tra này nghĩa là gì?';

  @override
  String metadataSectionInfoSemanticsLabel(String section, String question) {
    return '$section. $question';
  }

  @override
  String get metadataVerificationInfoTitle => 'Ý nghĩa của những kiểm tra này';

  @override
  String get metadataVerificationInfoIntro =>
      'Các tín hiệu này đến từ máy ảnh và từ chính tệp video. Video mang càng nhiều tín hiệu, chúng tôi càng chứng minh được nhiều điều về nguồn gốc của nó.';

  @override
  String get metadataVerificationInfoDeviceAttestation =>
      'Hệ điều hành của điện thoại đã bảo chứng cho ứng dụng đã quay video này. Bằng chứng mạnh cho thấy nó đến từ camera, không phải tệp ai đó tải lên.';

  @override
  String get metadataVerificationInfoPgpSignature =>
      'Video được ký bằng mật mã ngay khoảnh khắc quay. Sau đó chỉ cần đổi một khung hình là chữ ký hỏng.';

  @override
  String get metadataVerificationInfoC2paCredentials =>
      'Bản ghi nguồn gốc theo chuẩn ngành, đi kèm bên trong tệp — nên các ứng dụng khác ngoài Divine cũng kiểm tra được.';

  @override
  String get metadataVerificationInfoProofManifest =>
      'Bản ghi ProofMode đầy đủ: dấu vân tay tệp, dấu thời gian và bối cảnh quay, đi cùng video.';

  @override
  String get metadataVerificationInfoFootnote =>
      'Thiếu một kiểm tra không có nghĩa video là giả. Các clip cũ và video tải lên vốn chưa từng có — chỉ là chúng tôi không chứng minh được phần đó.';

  @override
  String metadataVerificationInfoLearnMore(String url) {
    return 'Tìm hiểu thêm tại $url';
  }

  @override
  String get metadataCreatorLabel => 'Nhà sáng tạo';

  @override
  String get metadataCollaboratorsLabel => 'Cộng tác viên';

  @override
  String get metadataInspiredByLabel => 'Lấy cảm hứng từ';

  @override
  String get metadataRepostedByLabel => 'Được đăng lại bởi';

  @override
  String metadataMoreReposters(int count) {
    return '+$count người nữa';
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
  String get metadataLikesLabel => 'Lượt thích';

  @override
  String get metadataCommentsLabel => 'Bình luận';

  @override
  String get metadataRepostsLabel => 'Lượt đăng lại';

  @override
  String get metadataVineStatsLabel => 'Trên Vine';

  @override
  String metadataVineStatsLine(
    String loops,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$loops loop · $likes lượt thích · $comments bình luận · $reposts lượt đăng lại';
  }

  @override
  String get metadataDivineStatsLabel => 'Trên Divine';

  @override
  String metadataDivineStatsLine(
    String views,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$views lượt xem · $likes lượt thích · $comments bình luận · $reposts lượt đăng lại';
  }

  @override
  String metadataPostedDateSemantics(String date) {
    return 'Đã đăng vào $date';
  }

  @override
  String get devOptionsTitle => 'Tùy chọn nhà phát triển';

  @override
  String get devOptionsDisableDeveloperMode => 'Tắt chế độ nhà phát triển';

  @override
  String get devOptionsDisableDeveloperModeSubtitle =>
      'Ẩn tùy chọn nhà phát triển khỏi cài đặt';

  @override
  String get devOptionsDisableDeveloperModeToast =>
      'Đã tắt chế độ nhà phát triển';

  @override
  String get devOptionsShorebirdTitle => 'Bản vá Shorebird';

  @override
  String get devOptionsShorebirdPatchLabel => 'Bản vá đang chạy';

  @override
  String get devOptionsShorebirdNoPatch => 'Chưa cài bản vá';

  @override
  String get devOptionsShorebirdUnavailable => 'Không có trong bản dựng này';

  @override
  String get devOptionsShorebirdUnavailableSubtitle =>
      'Bản vá chỉ hoạt động trong bản dựng được tạo bằng shorebird release.';

  @override
  String get devOptionsShorebirdLoading => 'Đang đọc trạng thái bản vá…';

  @override
  String get devOptionsShorebirdNotChecked => 'Chưa kiểm tra kênh thử nghiệm.';

  @override
  String get devOptionsShorebirdCheck => 'Kiểm tra kênh thử nghiệm';

  @override
  String get devOptionsShorebirdApply => 'Áp dụng bản vá thử nghiệm';

  @override
  String get devOptionsShorebirdUseStable => 'Quay lại cập nhật ổn định';

  @override
  String get devOptionsShorebirdChecking => 'Đang kiểm tra kênh thử nghiệm…';

  @override
  String get devOptionsShorebirdUpdateAvailable =>
      'Có bản vá thử nghiệm sẵn sàng áp dụng.';

  @override
  String get devOptionsShorebirdUpToDate =>
      'Không có bản vá thử nghiệm cho bản phát hành này.';

  @override
  String get devOptionsShorebirdRestartRequired =>
      'Đã tải xuống. Khởi động lại ứng dụng để tải bản vá.';

  @override
  String get devOptionsShorebirdRollbackRequired =>
      'Đã sẵn sàng hoàn tác. Khởi động lại để trở về bản phát hành gốc.';

  @override
  String get devOptionsShorebirdApplying => 'Đang tải xuống và cài đặt…';

  @override
  String get devOptionsShorebirdApplied =>
      'Đã cài đặt. Khởi động lại ứng dụng để tải bản vá.';

  @override
  String get devOptionsShorebirdUnchanged =>
      'Không có gì được cài đặt. Hãy kiểm tra kênh thử nghiệm và thử lại.';

  @override
  String get devOptionsShorebirdSelectingStableTrack =>
      'Đang chọn kênh ổn định…';

  @override
  String get devOptionsShorebirdStableRestored =>
      'Đã chọn kênh ổn định. Khởi động lại ứng dụng để kiểm tra bản vá ổn định.';

  @override
  String get devOptionsShorebirdFailure =>
      'Không thành công. Hãy xem nhật ký để biết chi tiết.';

  @override
  String get devOptionsPageLoadTimes => 'Thời gian tải trang';

  @override
  String get devOptionsNoPageLoads =>
      'Chưa ghi nhận lần tải trang nào.\nĐiều hướng quanh ứng dụng để xem dữ liệu thời gian.';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return 'Hiển thị: ${visibleMs}ms  |  Dữ liệu: ${dataMs}ms';
  }

  @override
  String get devOptionsSlowestScreens => 'Màn hình chậm nhất';

  @override
  String get devOptionsVideoPlaybackFormat => 'Định dạng phát video';

  @override
  String get devOptionsSwitchEnvironmentTitle => 'Chuyển môi trường?';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return 'Chuyển sang $envName?\n\nThao tác này sẽ xóa dữ liệu video đã lưu và kết nối lại với relay mới.';
  }

  @override
  String get devOptionsCancel => 'Hủy';

  @override
  String get devOptionsSwitch => 'Chuyển';

  @override
  String devOptionsSwitchedTo(String envName) {
    return 'Đã chuyển sang $envName';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return 'Đã chuyển sang $formatName — đã xóa bộ nhớ đệm';
  }

  @override
  String get featureFlagTitle => 'Cờ tính năng';

  @override
  String get featureFlagResetAllTooltip => 'Đặt lại tất cả cờ về mặc định';

  @override
  String get featureFlagError => 'Lỗi';

  @override
  String get relaySettingsTitle => 'Relay';

  @override
  String get relaySettingsInfoTitle =>
      'Divine là một hệ thống mở - bạn kiểm soát kết nối của mình';

  @override
  String get relaySettingsInfoDescription =>
      'Các relay này phân phối nội dung của bạn trên mạng Nostr phi tập trung. Bạn có thể thêm hoặc bớt relay tùy thích.';

  @override
  String get relaySettingsLearnMoreNostr => 'Tìm hiểu thêm về Nostr →';

  @override
  String get relaySettingsFindPublicRelays =>
      'Tìm relay công khai tại nostr.co.uk →';

  @override
  String get relaySettingsAppNotFunctional => 'Ứng dụng không hoạt động';

  @override
  String get relaySettingsRequiresRelay =>
      'Divine cần ít nhất một relay để tải video, đăng nội dung và đồng bộ dữ liệu.';

  @override
  String get relaySettingsRestoreDefaultRelay => 'Khôi phục relay mặc định';

  @override
  String get relaySettingsAddCustomRelay => 'Thêm relay tùy chỉnh';

  @override
  String get relaySettingsAddRelay => 'Thêm relay';

  @override
  String get relaySettingsRetry => 'Thử lại';

  @override
  String get relaySettingsNoStats => 'Chưa có số liệu thống kê';

  @override
  String get relaySettingsConnection => 'Kết nối';

  @override
  String get relaySettingsConnected => 'Đã kết nối';

  @override
  String get relaySettingsDisconnected => 'Đã ngắt kết nối';

  @override
  String get relaySettingsSessionDuration => 'Thời lượng phiên';

  @override
  String get relaySettingsLastConnected => 'Kết nối gần nhất';

  @override
  String get relaySettingsDisconnectedLabel => 'Đã ngắt kết nối';

  @override
  String get relaySettingsReason => 'Lý do';

  @override
  String get relaySettingsActiveSubscriptions => 'Đăng ký đang hoạt động';

  @override
  String get relaySettingsTotalSubscriptions => 'Tổng số đăng ký';

  @override
  String get relaySettingsEventsReceived => 'Sự kiện đã nhận';

  @override
  String get relaySettingsEventsSent => 'Sự kiện đã gửi';

  @override
  String get relaySettingsRequestsThisSession => 'Yêu cầu trong phiên này';

  @override
  String get relaySettingsFailedRequests => 'Yêu cầu thất bại';

  @override
  String get relaySettingsLoadingRelayInfo => 'Đang tải thông tin relay...';

  @override
  String get relaySettingsAboutRelay => 'Về relay';

  @override
  String get relaySettingsSupportedNips => 'Các NIP được hỗ trợ';

  @override
  String get relaySettingsSoftware => 'Phần mềm';

  @override
  String get relaySettingsViewWebsite => 'Xem website';

  @override
  String get relaySettingsRemoveRelayTitle => 'Xóa relay?';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return 'Bạn có chắc muốn xóa relay này không?\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveDefaultRelayTitle => 'Xoá relay của Divine?';

  @override
  String relaySettingsRemoveDefaultRelayMessage(String relayUrl) {
    return 'Xoá relay của Divine sẽ làm giảm trải nghiệm trong ứng dụng. Video, đăng bài và đồng bộ có thể kém ổn định hơn. Chỉ nên làm điều này nếu bạn đã quen dùng Nostr.\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveRelayTooltip => 'Xoá relay';

  @override
  String get relaySettingsCancel => 'Hủy';

  @override
  String get relaySettingsRemove => 'Xóa';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return 'Đã xóa relay: $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay => 'Không xóa được relay';

  @override
  String get relaySettingsForcingReconnection =>
      'Đang buộc kết nối lại relay...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    return 'Đã kết nối tới $count relay!';
  }

  @override
  String get relaySettingsFailedToConnectCheck =>
      'Không kết nối được với relay. Vui lòng kiểm tra kết nối mạng của bạn.';

  @override
  String get relaySettingsSavedLocallyPublishPending =>
      'Đã lưu trên thiết bị này. Chúng tôi sẽ đồng bộ với tài khoản của bạn khi việc đăng lại hoạt động.';

  @override
  String get relaySettingsAddRelayTitle => 'Thêm relay';

  @override
  String get relaySettingsAddRelayPrompt =>
      'Nhập URL WebSocket của relay bạn muốn thêm:';

  @override
  String get relaySettingsBrowsePublicRelays =>
      'Duyệt relay công khai tại nostr.co.uk';

  @override
  String get relaySettingsAdd => 'Thêm';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return 'Đã thêm relay: $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      'Không thêm được relay. Vui lòng kiểm tra URL rồi thử lại.';

  @override
  String get relaySettingsInvalidUrl =>
      'URL relay phải bắt đầu bằng wss:// hoặc ws://';

  @override
  String get relaySettingsInsecureUrl =>
      'URL relay phải dùng wss:// (ws:// chỉ được phép cho localhost)';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return 'Đã khôi phục relay mặc định: $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      'Không khôi phục được relay mặc định. Vui lòng kiểm tra kết nối mạng của bạn.';

  @override
  String get relaySettingsCouldNotOpenBrowser => 'Không mở được trình duyệt';

  @override
  String get relaySettingsFailedToOpenLink => 'Không mở được liên kết';

  @override
  String get relaySettingsExternalRelay => 'Relay bên ngoài';

  @override
  String get relaySettingsNotConnected => 'Chưa kết nối';

  @override
  String relaySettingsDisconnectedAgo(String duration) {
    return 'Đã ngắt kết nối $duration trước';
  }

  @override
  String relaySettingsSubscriptionsSummary(int count) {
    return '$count đăng ký';
  }

  @override
  String relaySettingsEventsSummary(int countValue, String count) {
    return '$count sự kiện';
  }

  @override
  String relaySettingsTimeAgo(String duration) {
    return '$duration trước';
  }

  @override
  String get nostrSettingsIntro =>
      'Divine dùng giao thức Nostr để xuất bản phi tập trung. Nội dung của bạn nằm trên các relay do bạn chọn, và khóa của bạn chính là danh tính của bạn.';

  @override
  String get nostrSettingsSectionNetwork => 'Mạng';

  @override
  String get nostrSettingsSectionAccount => 'Tài khoản';

  @override
  String get nostrSettingsSectionDangerZone => 'Vùng nguy hiểm';

  @override
  String get nostrSettingsRelays => 'Relay';

  @override
  String get nostrSettingsRelaysSubtitle => 'Quản lý kết nối relay Nostr';

  @override
  String get nostrSettingsRelayDiagnostics => 'Chẩn đoán relay';

  @override
  String get nostrSettingsRelayDiagnosticsSubtitle =>
      'Gỡ lỗi kết nối relay và sự cố mạng';

  @override
  String get nostrSettingsMediaServers => 'Máy chủ media';

  @override
  String get nostrSettingsMediaServersSubtitle =>
      'Cấu hình máy chủ tải lên Blossom';

  @override
  String get settingsDeveloperOptions => 'Tùy chọn nhà phát triển';

  @override
  String get settingsDeveloperOptionsSubtitle =>
      'Chuyển môi trường và cài đặt gỡ lỗi';

  @override
  String get nostrSettingsKeyManagement => 'Quản lý khóa';

  @override
  String get nostrSettingsKeyManagementSubtitle =>
      'Xuất, sao lưu và khôi phục khóa Nostr của bạn';

  @override
  String get nostrSettingsClientAttribution => 'Ghi nhận ứng dụng';

  @override
  String get nostrSettingsClientAttributionSubtitle =>
      'Gắn thẻ ứng dụng Divine lên các sự kiện bạn xuất bản để các ứng dụng Nostr khác ghi nhận đúng nguồn. Không có nó, các báo cáo bạn gửi sẽ có ít trọng lượng hơn khi người kiểm duyệt của chúng tôi xem xét.';

  @override
  String get nostrSettingsMoveAccount => 'Di chuyển tài khoản của bạn';

  @override
  String get nostrSettingsMoveAccountSubtitle =>
      'Tải xuống kho lưu trữ của bạn và chuyển bài đăng cùng video sang relay hoặc máy chủ media khác.';

  @override
  String get nostrSettingsRemoveKeys => 'Xóa tài khoản này khỏi thiết bị này';

  @override
  String get nostrSettingsRemoveKeysSubtitle =>
      'Xóa đăng nhập cục bộ của tài khoản này khỏi thiết bị. Các bản nháp và clip cục bộ của tài khoản này vẫn được giữ.';

  @override
  String get nostrSettingsCouldNotRemoveKeys =>
      'Không xóa được tài khoản này khỏi thiết bị. Vui lòng thử lại.';

  @override
  String get nostrSettingsDeleteAccount => 'Xóa tài khoản và dữ liệu';

  @override
  String get nostrSettingsDeleteAccountSubtitle =>
      'Gửi yêu cầu xóa nội dung của bạn và đăng xuất bạn trên thiết bị này. Các relay, ứng dụng khác, chỉ mục tìm kiếm và thiết bị đã đăng nhập khác có thể vẫn giữ bản sao.';

  @override
  String get relayDiagnosticTitle => 'Chẩn đoán relay';

  @override
  String get relayDiagnosticRefreshTooltip => 'Làm mới chẩn đoán';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return 'Làm mới gần nhất: $time';
  }

  @override
  String get relayDiagnosticRelayStatus => 'Trạng thái relay';

  @override
  String get relayDiagnosticInitialized => 'Đã khởi tạo';

  @override
  String get relayDiagnosticReady => 'Sẵn sàng';

  @override
  String get relayDiagnosticNotInitialized => 'Chưa khởi tạo';

  @override
  String get relayDiagnosticDatabaseEvents => 'Sự kiện cơ sở dữ liệu';

  @override
  String get relayDiagnosticActiveSubscriptions => 'Đăng ký đang hoạt động';

  @override
  String get relayDiagnosticExternalRelays => 'Relay bên ngoài';

  @override
  String get relayDiagnosticConfigured => 'Đã cấu hình';

  @override
  String relayDiagnosticRelayCount(int count) {
    return '$count relay';
  }

  @override
  String get relayDiagnosticConnectedLabel => 'Đã kết nối';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => 'Sự kiện video';

  @override
  String get relayDiagnosticHomeFeed => 'Bảng tin chính';

  @override
  String relayDiagnosticVideosCount(int count) {
    return '$count video';
  }

  @override
  String get relayDiagnosticDiscovery => 'Khám phá';

  @override
  String get relayDiagnosticLoading => 'Đang tải';

  @override
  String get relayDiagnosticYes => 'Có';

  @override
  String get relayDiagnosticNo => 'Không';

  @override
  String get relayDiagnosticTestDirectQuery => 'Kiểm tra truy vấn trực tiếp';

  @override
  String get relayDiagnosticNetworkConnectivity => 'Kết nối mạng';

  @override
  String get relayDiagnosticRunNetworkTest => 'Chạy kiểm tra mạng';

  @override
  String get relayDiagnosticBlossomServer => 'Máy chủ Blossom';

  @override
  String get relayDiagnosticTestAllEndpoints => 'Kiểm tra tất cả endpoint';

  @override
  String get relayDiagnosticStatus => 'Trạng thái';

  @override
  String get relayDiagnosticUrl => 'URL';

  @override
  String get relayDiagnosticError => 'Lỗi';

  @override
  String get relayDiagnosticFunnelCakeApi => 'FunnelCake API';

  @override
  String get relayDiagnosticBaseUrl => 'URL gốc';

  @override
  String get relayDiagnosticSummary => 'Tóm tắt';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount OK (TB ${avgMs}ms)';
  }

  @override
  String get relayDiagnosticRetestAll => 'Kiểm tra lại tất cả';

  @override
  String get relayDiagnosticRetrying => 'Đang thử lại...';

  @override
  String get relayDiagnosticRetryConnection => 'Thử kết nối lại';

  @override
  String get relayDiagnosticTroubleshooting => 'Xử lý sự cố';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• Trạng thái xanh lá = Đã kết nối và hoạt động\n• Trạng thái đỏ = Kết nối thất bại\n• Nếu kiểm tra mạng thất bại, hãy kiểm tra kết nối internet\n• Nếu relay đã cấu hình nhưng chưa kết nối, chạm \"Thử kết nối lại\"\n• Chụp màn hình này để gỡ lỗi';

  @override
  String get relayDiagnosticAllEndpointsHealthy =>
      'Tất cả endpoint REST đều khỏe mạnh!';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      'Một số endpoint REST thất bại - xem chi tiết ở trên';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    return 'Tìm thấy $count sự kiện video trong cơ sở dữ liệu';
  }

  @override
  String get relayDiagnosticQueryFailed =>
      'Truy vấn thất bại. Vui lòng thử lại.';

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    return 'Đã kết nối tới $count relay!';
  }

  @override
  String get relayDiagnosticFailedToConnect =>
      'Không kết nối được với relay nào';

  @override
  String get relayDiagnosticConnectionRetryFailed =>
      'Thử kết nối lại thất bại. Vui lòng thử lại.';

  @override
  String get relayDiagnosticConnectedAuthenticated => 'Đã kết nối & xác thực';

  @override
  String get relayDiagnosticConnectedOnly => 'Đã kết nối';

  @override
  String get relayDiagnosticNotConnected => 'Chưa kết nối';

  @override
  String get relayDiagnosticNoRelaysConfigured => 'Chưa cấu hình relay nào';

  @override
  String get relayDiagnosticFailed => 'Thất bại';

  @override
  String get notificationSettingsTitle => 'Thông báo';

  @override
  String get notificationSettingsResetTooltip => 'Đặt lại về mặc định';

  @override
  String get notificationSettingsTypes => 'Loại thông báo';

  @override
  String get notificationSettingsLikes => 'Lượt thích';

  @override
  String get notificationSettingsLikesSubtitle =>
      'Khi có người thích video của bạn';

  @override
  String get notificationSettingsComments => 'Bình luận';

  @override
  String get notificationSettingsCommentsSubtitle =>
      'Khi có người bình luận video của bạn';

  @override
  String get notificationSettingsFollows => 'Lượt theo dõi';

  @override
  String get notificationSettingsFollowsSubtitle => 'Khi có người theo dõi bạn';

  @override
  String get notificationSettingsMentions => 'Lượt nhắc đến';

  @override
  String get notificationSettingsMentionsSubtitle => 'Khi bạn được nhắc đến';

  @override
  String get notificationSettingsReposts => 'Bài đăng lại';

  @override
  String get notificationSettingsRepostsSubtitle =>
      'Khi có người đăng lại video của bạn';

  @override
  String get notificationSettingsNewPosts => 'Vine mới';

  @override
  String get notificationSettingsNewPostsSubtitle =>
      'Khi người bạn theo dõi đăng bài';

  @override
  String get notificationSettingsActions => 'Thao tác';

  @override
  String get notificationSettingsMarkAllAsRead => 'Đánh dấu tất cả là đã đọc';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle =>
      'Đánh dấu tất cả thông báo là đã đọc';

  @override
  String get notificationSettingsAllMarkedAsRead =>
      'Đã đánh dấu tất cả thông báo là đã đọc';

  @override
  String get notificationSettingsMarkAllAsReadFailed =>
      'Không đánh dấu được tất cả là đã đọc';

  @override
  String get notificationSettingsResetToDefaults =>
      'Đã đặt lại cài đặt về mặc định';

  @override
  String get notificationSettingsAbout => 'Về thông báo';

  @override
  String get notificationSettingsAboutDescription =>
      'Thông báo chạy trên giao thức Nostr. Cập nhật thời gian thực phụ thuộc vào kết nối của bạn tới các relay Nostr. Một số thông báo có thể đến chậm.';

  @override
  String get safetySettingsWhatYouSee => 'NHỮNG GÌ BẠN THẤY';

  @override
  String get safetySettingsWhatYouPublish => 'NHỮNG GÌ BẠN ĐĂNG';

  @override
  String get safetySettingsShowDivineHostedOnly =>
      'Chỉ hiện video do Divine lưu trữ';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle =>
      'Ẩn video phát từ máy chủ media khác';

  @override
  String get safetySettingsModeration => 'KIỂM DUYỆT';

  @override
  String get safetySettingsBlockedUsers => 'NGƯỜI DÙNG BỊ CHẶN';

  @override
  String get safetySettingsAgeVerification => 'XÁC MINH ĐỘ TUỔI';

  @override
  String get safetySettingsAgeConfirmation =>
      'Tôi xác nhận tôi đủ 18 tuổi trở lên';

  @override
  String get safetySettingsAgeRequired => 'Bắt buộc để xem nội dung người lớn';

  @override
  String get safetySettingsAgeLockedForMinor => 'Đã khóa cho tài khoản của bạn';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle =>
      'Dịch vụ kiểm duyệt chính thức (bật mặc định)';

  @override
  String get safetySettingsPeopleIFollow => 'Người tôi theo dõi';

  @override
  String get safetySettingsPeopleIFollowSubtitle =>
      'Đăng ký nhãn từ những người bạn theo dõi';

  @override
  String get safetySettingsAddCustomLabeler => 'Thêm bên gắn nhãn tùy chỉnh';

  @override
  String get safetySettingsAddCustomLabelerHint => 'Nhập npub...';

  @override
  String get safetySettingsAddCustomLabelerListTitle =>
      'Thêm bên gắn nhãn tùy chỉnh';

  @override
  String get safetySettingsRemoveLabeler => 'Xóa bên gắn nhãn';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle => 'Nhập địa chỉ npub';

  @override
  String get safetySettingsNoBlockedUsers => 'Không có người dùng bị chặn';

  @override
  String get safetySettingsUnblock => 'Bỏ chặn';

  @override
  String get safetySettingsUserUnblocked => 'Đã bỏ chặn người dùng';

  @override
  String get safetySettingsCancel => 'Hủy';

  @override
  String get safetySettingsAdd => 'Thêm';

  @override
  String get analyticsTitle => 'Phân tích nhà sáng tạo';

  @override
  String get analyticsDiagnosticsTooltip => 'Chẩn đoán';

  @override
  String get analyticsDiagnosticsSemanticLabel => 'Bật/tắt chẩn đoán';

  @override
  String get analyticsRetry => 'Thử lại';

  @override
  String get analyticsUnableToLoad => 'Không thể tải phân tích.';

  @override
  String get analyticsServerUnavailable =>
      'Creator analytics is having server trouble. Please try again in a moment.';

  @override
  String get analyticsConnectionIssue =>
      'Creator analytics could not connect. Check your connection and try again.';

  @override
  String get analyticsSignInRequired =>
      'Đăng nhập để xem phân tích nhà sáng tạo.';

  @override
  String get analyticsViewDataUnavailable =>
      'Hiện relay chưa có dữ liệu lượt xem cho các bài đăng này. Số liệu thích/bình luận/đăng lại vẫn chính xác.';

  @override
  String get analyticsViewDataTitle => 'Dữ liệu lượt xem';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return 'Cập nhật $time • Điểm số dùng lượt thích, bình luận, đăng lại và lượt xem/loop từ Funnelcake khi có sẵn.';
  }

  @override
  String get analyticsVideos => 'Video';

  @override
  String get analyticsViews => 'Lượt xem';

  @override
  String get analyticsInteractions => 'Tương tác';

  @override
  String get analyticsEngagement => 'Mức độ tương tác';

  @override
  String get analyticsFollowers => 'Người theo dõi';

  @override
  String get analyticsAvgPerPost => 'TB/Bài đăng';

  @override
  String get analyticsInteractionMix => 'Tỷ trọng tương tác';

  @override
  String get analyticsLikes => 'Lượt thích';

  @override
  String get analyticsComments => 'Bình luận';

  @override
  String get analyticsReposts => 'Bài đăng lại';

  @override
  String get analyticsPerformanceHighlights => 'Điểm nổi bật hiệu suất';

  @override
  String get analyticsMostViewed => 'Được xem nhiều nhất';

  @override
  String get analyticsMostDiscussed => 'Được bàn luận nhiều nhất';

  @override
  String get analyticsMostReposted => 'Được đăng lại nhiều nhất';

  @override
  String get analyticsNoVideosYet => 'Chưa có video nào';

  @override
  String get analyticsViewDataUnavailableShort => 'Chưa có dữ liệu lượt xem';

  @override
  String analyticsViewsCount(int countValue, String count) {
    return '$count lượt xem';
  }

  @override
  String analyticsCommentsCount(int countValue, String count) {
    return '$count bình luận';
  }

  @override
  String analyticsRepostsCount(int countValue, String count) {
    return '$count lượt đăng lại';
  }

  @override
  String get analyticsTopContent => 'Nội dung hàng đầu';

  @override
  String get analyticsPublishPrompt => 'Đăng vài video để xem bảng xếp hạng.';

  @override
  String get analyticsEngagementRateExplainer =>
      '% bên phải = Tỷ lệ tương tác (tương tác chia cho lượt xem).';

  @override
  String get analyticsEngagementRateNoViews =>
      'Tỷ lệ tương tác cần dữ liệu lượt xem; giá trị sẽ hiện N/A cho đến khi có dữ liệu lượt xem.';

  @override
  String get analyticsEngagementLabel => 'Mức độ tương tác';

  @override
  String get analyticsViewsUnavailable => 'chưa có dữ liệu lượt xem';

  @override
  String analyticsInteractionsCount(int countValue, String count) {
    return '$count tương tác';
  }

  @override
  String get analyticsPostAnalytics => 'Phân tích bài đăng';

  @override
  String get analyticsOpenPost => 'Mở bài đăng';

  @override
  String get analyticsRecentDailyInteractions => 'Tương tác hằng ngày gần đây';

  @override
  String get analyticsNoActivityYet =>
      'Chưa có hoạt động nào trong khoảng này.';

  @override
  String get analyticsDailyInteractionsExplainer =>
      'Tương tác = lượt thích + bình luận + đăng lại theo ngày đăng.';

  @override
  String get analyticsDailyBarExplainer =>
      'Độ dài thanh tương đối với ngày cao nhất của bạn trong khoảng này.';

  @override
  String get analyticsAudienceSnapshot => 'Bức tranh khán giả';

  @override
  String analyticsFollowersCount(String count) {
    return 'Người theo dõi: $count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return 'Đang theo dõi: $count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      'Phân tích nguồn/vùng/thời gian của khán giả sẽ xuất hiện khi Funnelcake bổ sung endpoint phân tích khán giả.';

  @override
  String get analyticsRetention => 'Tỷ lệ giữ chân';

  @override
  String get analyticsRetentionWithViews =>
      'Đường cong giữ chân và phân tích thời gian xem sẽ xuất hiện khi Funnelcake trả về dữ liệu giữ chân theo giây/theo nhóm.';

  @override
  String get analyticsRetentionWithoutViews =>
      'Chưa có dữ liệu giữ chân cho đến khi Funnelcake trả về phân tích lượt xem + thời gian xem.';

  @override
  String get analyticsDiagnostics => 'Chẩn đoán';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return 'Tổng số video: $count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return 'Có lượt xem: $count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return 'Thiếu lượt xem: $count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return 'Đã nạp (hàng loạt): $count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return 'Đã nạp (/views): $count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return 'Nguồn: $sources';
  }

  @override
  String analyticsDiagnosticsFailedSources(String sources) {
    return 'Failed sources: $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => 'Dùng dữ liệu mẫu';

  @override
  String get analyticsNa => 'Không có';

  @override
  String get authCreateNewAccount => 'Tạo tài khoản Divine mới';

  @override
  String get authCreateNewAccountShort => 'Tạo tài khoản mới';

  @override
  String get authSignInDifferentAccount => 'Đăng nhập bằng tài khoản hiện có';

  @override
  String get authUseAnotherAccount => 'Dùng tài khoản khác';

  @override
  String authContinueAs(String displayName) {
    return 'Tiếp tục với $displayName';
  }

  @override
  String get authRecoveryDraftsOwner =>
      'Các bản nháp và clip của bạn đang được lưu cho tài khoản này';

  @override
  String get authRecoveryOtherAccountWarning =>
      'Đăng nhập ở đây sẽ ẩn các bản nháp và clip đó';

  @override
  String get authTermsPrefix =>
      'Khi chọn một tùy chọn bên dưới, bạn xác nhận bạn đã đủ 16 tuổi (hoặc đã hoàn tất ';

  @override
  String get authTermsAgeAuthorizationCta => 'xác minh độ tuổi Divine';

  @override
  String get authTermsAfterAgeAuthorization => ') và đồng ý với ';

  @override
  String get authTermsOfService => 'Điều khoản dịch vụ';

  @override
  String get authPrivacyPolicy => 'Chính sách quyền riêng tư';

  @override
  String get authTermsAnd => ', và ';

  @override
  String get authSafetyStandards => 'Tiêu chuẩn an toàn';

  @override
  String get authAmberNotInstalled => 'Chưa cài đặt ứng dụng Amber';

  @override
  String get authAmberConnectionFailed => 'Không kết nối được với Amber';

  @override
  String get authPasswordResetSent =>
      'Nếu có tài khoản với email đó, liên kết đặt lại mật khẩu đã được gửi.';

  @override
  String get authSignInTitle => 'Đăng nhập';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authPasswordLabel => 'Mật khẩu';

  @override
  String get authConfirmPasswordLabel => 'Xác nhận mật khẩu';

  @override
  String get authEmailRequired => 'Email là bắt buộc';

  @override
  String get authEmailInvalid => 'Vui lòng nhập email hợp lệ';

  @override
  String get authPasswordRequired => 'Mật khẩu là bắt buộc';

  @override
  String get authConfirmPasswordRequired =>
      'Vui lòng xác nhận mật khẩu của bạn';

  @override
  String get authPasswordsDoNotMatch => 'Mật khẩu không khớp';

  @override
  String get authForgotPassword => 'Quên mật khẩu?';

  @override
  String get authImportNostrKey => 'Nhập khóa Nostr';

  @override
  String get authConnectSignerApp => 'Kết nối với ứng dụng ký';

  @override
  String get authSignInWithAmber => 'Đăng nhập bằng Amber';

  @override
  String get authSignInWithBrowserExtension =>
      'Đăng nhập bằng tiện ích trình duyệt';

  @override
  String get authNip07ConnectionFailed =>
      'Không kết nối được với tiện ích trình duyệt của bạn.';

  @override
  String get authNip07ExtensionNotFound =>
      'Không tìm thấy tiện ích trình duyệt nào. Hãy cài Alby, nos2x hoặc tiện ích tương thích NIP-07 khác.';

  @override
  String get authSignInOptionsTitle => 'Tùy chọn đăng nhập';

  @override
  String get authInfoEmailPasswordTitle => 'Email & Mật khẩu';

  @override
  String get authInfoEmailPasswordDescription =>
      'Đăng nhập bằng tài khoản Divine của bạn. Nếu bạn đã đăng ký bằng email và mật khẩu, hãy dùng chúng ở đây.';

  @override
  String get authInfoImportNostrKeyDescription =>
      'Đã có danh tính Nostr? Hãy nhập khóa riêng tư nsec của bạn từ ứng dụng khác.';

  @override
  String get authInfoSignerAppTitle => 'Ứng dụng ký';

  @override
  String get authInfoSignerAppDescription =>
      'Kết nối bằng trình ký từ xa tương thích NIP-46 như nsecBunker để bảo mật khóa tốt hơn.';

  @override
  String get authInfoAmberTitle => 'Amber';

  @override
  String get authInfoAmberDescription =>
      'Dùng ứng dụng ký Amber trên Android để quản lý khóa Nostr của bạn an toàn.';

  @override
  String get authInfoBrowserExtensionTitle => 'Tiện ích trình duyệt';

  @override
  String get authInfoBrowserExtensionDescription =>
      'Đăng nhập bằng tiện ích trình duyệt NIP-07 như Alby hoặc nos2x. Khóa của bạn nằm trong tiện ích — Divine không bao giờ nhìn thấy chúng.';

  @override
  String get authSignInErrorInvalidCredentials =>
      'Sai email hoặc mật khẩu. Thử lại nhé.';

  @override
  String get authSignInErrorEmailNotVerified =>
      'Hãy xác minh email trước khi đăng nhập — kiểm tra hộp thư để lấy liên kết.';

  @override
  String get authSignInErrorInvalidEmail =>
      'Trông không giống địa chỉ email hợp lệ lắm.';

  @override
  String get authSignInErrorNetwork =>
      'Không kết nối được với máy chủ. Kiểm tra kết nối của bạn rồi thử lại nhé.';

  @override
  String get authSignInErrorGeneric => 'Có gì đó không ổn. Vui lòng thử lại.';

  @override
  String get authSignInOptionsHintPrefix =>
      'Không nhớ lần trước bạn vào bằng cách nào? ';

  @override
  String get authSignInOptionsHintCta => 'Xem mọi cách đăng nhập';

  @override
  String get authCreateAccountTitle => 'Tạo tài khoản';

  @override
  String get authBackToInviteCode => 'Quay lại mã mời';

  @override
  String get authUseDivineNoBackup => 'Dùng Divine không cần sao lưu';

  @override
  String get authSkipConfirmTitle => 'Một điều cuối nữa thôi...';

  @override
  String get authSkipConfirmKeyCreated =>
      'Bạn vào được rồi! Bọn mình sẽ tạo một khóa bảo mật để vận hành tài khoản Divine của bạn.';

  @override
  String get authSkipConfirmKeyOnly =>
      'Không có email, khóa là cách duy nhất để Divine biết tài khoản này là của bạn.';

  @override
  String get authSkipConfirmRecommendEmail =>
      'Bạn có thể xem khóa trong ứng dụng, nhưng nếu bạn không rành kỹ thuật, bọn mình khuyên thêm email và mật khẩu ngay bây giờ. Nó giúp đăng nhập và khôi phục tài khoản dễ hơn nếu bạn mất hoặc đặt lại thiết bị này.';

  @override
  String get authAddEmailPassword => 'Thêm email & mật khẩu';

  @override
  String get authUseThisDeviceOnly => 'Chỉ dùng thiết bị này';

  @override
  String get authCompleteRegistration => 'Hoàn tất đăng ký của bạn';

  @override
  String get authVerifying => 'Đang xác minh...';

  @override
  String get authVerificationLinkSent =>
      'Bọn mình đã gửi liên kết xác minh tới:';

  @override
  String get authClickVerificationLink =>
      'Hãy bấm vào liên kết trong email để\nhoàn tất đăng ký của bạn.';

  @override
  String get authPleaseWaitVerifying =>
      'Vui lòng chờ trong khi bọn mình xác minh email của bạn...';

  @override
  String get authWaitingForVerification => 'Đang chờ xác minh';

  @override
  String get authOpenEmailApp => 'Mở ứng dụng email';

  @override
  String get authVerificationPinPrompt => 'Hoặc nhập mã 6 số từ email của bạn';

  @override
  String get authVerificationPinFieldLabel => 'Mã 6 số';

  @override
  String get authVerificationPinSubmit => 'Xác minh mã';

  @override
  String get authVerificationResendPrompt => 'Chưa nhận được?';

  @override
  String get authVerificationResend => 'Gửi lại';

  @override
  String authVerificationResendCooldown(String time) {
    return 'Gửi lại sau $time';
  }

  @override
  String get authVerificationResendFailed =>
      'Bọn mình không gửi lại được email. Thử lại nhé.';

  @override
  String get authVerificationResendExpired =>
      'Lượt đăng ký đó đã hết hạn. Bắt đầu lại để nhận mã mới.';

  @override
  String get authVerificationResendUnavailable =>
      'Hiện không gửi lại được. Hãy dùng mã 6 chữ số trong email chúng tôi đã gửi cho bạn.';

  @override
  String get authVerificationPollingStopped =>
      'Chúng tôi đã ngừng kiểm tra giúp bạn. Nhập mã 6 chữ số trong email để hoàn tất đăng nhập.';

  @override
  String get authWelcomeToDivine => 'Chào mừng đến với Divine!';

  @override
  String get authEmailVerified => 'Email của bạn đã được xác minh.';

  @override
  String get authSigningYouIn => 'Đang đăng nhập cho bạn';

  @override
  String get authErrorTitle => 'Ối.';

  @override
  String get authVerificationFailed =>
      'Bọn mình không xác minh được email của bạn.\nVui lòng thử lại.';

  @override
  String get authStartOver => 'Bắt đầu lại';

  @override
  String get authEmailVerifiedLogin =>
      'Email đã xác minh! Vui lòng đăng nhập để tiếp tục.';

  @override
  String get authVerificationLinkExpired =>
      'Liên kết xác minh này không còn hợp lệ.';

  @override
  String get authVerificationConnectionError =>
      'Không xác minh được email. Kiểm tra kết nối của bạn rồi thử lại nhé.';

  @override
  String get authWaitlistConfirmTitle => 'Bạn vào được rồi!';

  @override
  String authWaitlistUpdatesAt(String email) {
    return 'Bọn mình sẽ gửi cập nhật tới $email.\nKhi có thêm mã mời, bọn mình sẽ gửi cho bạn.';
  }

  @override
  String get authOk => 'OK';

  @override
  String get authTryAgain => 'Thử lại';

  @override
  String get authContactSupport => 'Liên hệ hỗ trợ';

  @override
  String authCouldNotOpenEmail(String email) {
    return 'Không mở được $email';
  }

  @override
  String get authAddInviteCode => 'Nhập mã mời của bạn';

  @override
  String get authInviteCodeLabel => 'Mã mời';

  @override
  String get authEnterYourCode => 'Nhập mã của bạn';

  @override
  String get authNext => 'Tiếp';

  @override
  String get authJoinWaitlist => 'Tham gia danh sách chờ';

  @override
  String get authJoinWaitlistTitle => 'Tham gia danh sách chờ';

  @override
  String get authJoinWaitlistDescription =>
      'Chia sẻ email của bạn và bọn mình sẽ gửi mã mời khi mở thêm quyền truy cập.';

  @override
  String get authJoinWaitlistNewsletterOptIn => 'Gửi cho tôi cảm hứng Divine';

  @override
  String get authInviteAccessHelp => 'Trợ giúp về truy cập bằng mã mời';

  @override
  String get authGeneratingConnection => 'Đang tạo kết nối...';

  @override
  String get authConnectedAuthenticating => 'Đã kết nối! Đang xác thực...';

  @override
  String get authConnectionTimedOut => 'Kết nối hết thời gian chờ';

  @override
  String get authApproveConnection =>
      'Hãy chắc chắn bạn đã duyệt kết nối trong ứng dụng ký của mình.';

  @override
  String get authConnectionCancelled => 'Đã hủy kết nối';

  @override
  String get authConnectionCancelledMessage => 'Kết nối đã bị hủy.';

  @override
  String get authConnectionFailed => 'Kết nối thất bại';

  @override
  String get authUnknownError => 'Đã xảy ra lỗi không xác định.';

  @override
  String get authNostrConnectStartFailed =>
      'Không kết nối được với trình ký. Kiểm tra kết nối của bạn rồi thử lại.';

  @override
  String get authNostrConnectInvalidSession =>
      'Liên kết kết nối này không còn hợp lệ. Hãy tạo liên kết mới.';

  @override
  String get authNostrConnectSetupFailed =>
      'Gần xong rồi — bọn mình chưa hoàn tất đăng nhập cho bạn được. Thử lại nhé.';

  @override
  String get authUrlCopied => 'Đã sao chép URL vào khay nhớ tạm';

  @override
  String get authConnectToDivine => 'Kết nối với Divine';

  @override
  String get authPasteBunkerUrl => 'Dán URL bunker://';

  @override
  String get authBunkerUrlHint => 'URL bunker://';

  @override
  String get authInvalidBunkerUrl =>
      'URL bunker không hợp lệ. Nó phải bắt đầu bằng bunker://';

  @override
  String get authScanSignerApp => 'Quét bằng ứng dụng ký\ncủa bạn để kết nối.';

  @override
  String authWaitingForConnection(int seconds) {
    return 'Đang chờ kết nối... ${seconds}s';
  }

  @override
  String get authCopyUrl => 'Sao chép URL';

  @override
  String get authShare => 'Chia sẻ';

  @override
  String get authAddBunker => 'Thêm bunker';

  @override
  String get authCompatibleSignerApps => 'Ứng dụng ký tương thích';

  @override
  String get authFailedToConnect => 'Kết nối thất bại';

  @override
  String get authResetPasswordTitle => 'Đặt lại mật khẩu';

  @override
  String get authResetPasswordSubtitle =>
      'Vui lòng nhập mật khẩu mới. Mật khẩu phải dài ít nhất 8 ký tự.';

  @override
  String get authNewPasswordLabel => 'Mật khẩu mới';

  @override
  String get authConfirmNewPasswordLabel => 'Xác nhận mật khẩu mới';

  @override
  String get authPasswordTooShort => 'Mật khẩu phải dài ít nhất 8 ký tự';

  @override
  String get authPasswordResetSuccess =>
      'Đặt lại mật khẩu thành công. Vui lòng đăng nhập.';

  @override
  String get authPasswordResetFailed => 'Đặt lại mật khẩu thất bại';

  @override
  String get authUnexpectedError => 'Đã xảy ra lỗi bất ngờ. Vui lòng thử lại.';

  @override
  String get authUpdatePassword => 'Cập nhật mật khẩu';

  @override
  String get authSecureAccountTitle => 'Bảo mật tài khoản';

  @override
  String get authUnableToAccessKeys =>
      'Không truy cập được khóa của bạn. Vui lòng thử lại.';

  @override
  String get authRegistrationFailed => 'Đăng ký thất bại';

  @override
  String get authRegistrationComplete =>
      'Đăng ký hoàn tất. Vui lòng kiểm tra email của bạn.';

  @override
  String get authSecureAccountAlreadyRegistered =>
      'Looks like an account already exists. Try a different email, or sign in to the existing account with this email address. If neither works, contact support.';

  @override
  String get authFailedToSendResetEmail => 'Không gửi được email đặt lại.';

  @override
  String get authSending => 'Đang gửi...';

  @override
  String get authSignInButton => 'Đăng nhập';

  @override
  String get authVerificationErrorTimeout =>
      'Xác minh hết thời gian chờ. Vui lòng đăng ký lại.';

  @override
  String get authVerificationErrorMissingCode =>
      'Xác minh thất bại — thiếu mã ủy quyền.';

  @override
  String get authVerificationErrorPollFailed =>
      'Xác minh thất bại. Vui lòng thử lại.';

  @override
  String get authVerificationErrorNetworkExchange =>
      'Lỗi mạng trong lúc đăng nhập. Vui lòng thử lại.';

  @override
  String get authVerificationErrorOAuthExchange =>
      'Xác minh thất bại. Vui lòng đăng ký lại.';

  @override
  String get authVerificationErrorSignInFailed =>
      'Đăng nhập thất bại. Vui lòng thử đăng nhập thủ công.';

  @override
  String get authVerificationEmailAlreadyRegistered =>
      'Email này đã được đăng ký. Hãy đăng nhập nhé.';

  @override
  String get authVerificationErrorPinInvalid =>
      'Mã đó không khớp. Kiểm tra lại rồi thử lại nhé.';

  @override
  String get authVerificationErrorPinExpired =>
      'Mã đó đã hết hạn. Chạm gửi lại để lấy mã mới.';

  @override
  String get authVerificationErrorPinLocked =>
      'Thử sai quá nhiều lần. Chạm gửi lại để lấy mã mới.';

  @override
  String get authVerificationErrorPinFailed =>
      'Bọn mình không xác minh được mã đó. Vui lòng thử lại.';

  @override
  String get authVerificationErrorPinUnavailable =>
      'Hiện không nhập mã được. Hãy bấm liên kết trong email, hoặc gửi lại để lấy mã mới.';

  @override
  String get authInviteCodeErrorMalformed => 'Nhập mã mời dạng ABCD-EFGH.';

  @override
  String get authInviteCodeErrorNotFound => 'Mã mời đó có vẻ không hợp lệ.';

  @override
  String get authInviteCodeErrorAlreadyUsed =>
      'Mã mời đó đã được dùng hoặc đã bị thu hồi.';

  @override
  String get authInviteGateErrorCreatorFull =>
      'Nhà sáng tạo này đã hết lời mời';

  @override
  String get authInviteGateErrorUnavailable =>
      'Mã mời đó không khả dụng. Hãy tham gia danh sách chờ, chúng tôi sẽ gửi lời mời khi còn chỗ.';

  @override
  String get authInviteGateErrorCheckFailed =>
      'Chúng tôi không kiểm tra được mã đó. Hãy thử lại.';

  @override
  String get authInviteGateErrorUnknown =>
      'Đã xảy ra lỗi. Hãy thử lại mã mời của bạn.';

  @override
  String get authInviteErrorAlreadyUsed =>
      'Mã mời đó không còn khả dụng. Quay lại mã mời của bạn, tham gia danh sách chờ, hoặc liên hệ hỗ trợ.';

  @override
  String get authInviteErrorInvalid =>
      'Mã mời đó hiện không dùng được. Quay lại mã mời của bạn, tham gia danh sách chờ, hoặc liên hệ hỗ trợ.';

  @override
  String get authInviteErrorTemporary =>
      'Bọn mình chưa xác nhận được mã mời của bạn. Quay lại mã mời và thử lại, hoặc liên hệ hỗ trợ.';

  @override
  String get authInviteErrorUnknown =>
      'Bọn mình không kích hoạt được mã mời của bạn. Quay lại mã mời, tham gia danh sách chờ, hoặc liên hệ hỗ trợ.';

  @override
  String get shareSheetSave => 'Lưu';

  @override
  String get shareSheetRemoveFromSaved => 'Xóa khỏi mục đã lưu';

  @override
  String get shareSheetSaveToGallery => 'Lưu vào thư viện ảnh';

  @override
  String get shareSheetSaveWithWatermark => 'Lưu kèm watermark';

  @override
  String get shareSheetSaveVideo => 'Lưu video';

  @override
  String get shareSheetAddToClips => 'Thêm vào clip';

  @override
  String get shareSheetNameClipTitle => 'Đặt tên clip này';

  @override
  String get shareSheetNameClipSubtitle =>
      'Chọn một cái tên dễ nhận ra trong thư viện của bạn.';

  @override
  String get shareSheetClipTitleLabel => 'Tên clip';

  @override
  String get shareSheetSaveClip => 'Lưu clip';

  @override
  String shareSheetSavedClipToClips(String title) {
    return 'Đã lưu \"$title\" vào clip';
  }

  @override
  String get shareSheetUntitledClip => 'Clip chưa đặt tên';

  @override
  String get shareSheetAddToClipsFailed => 'Không thêm được vào clip';

  @override
  String get shareSheetAddToList => 'Thêm vào danh sách';

  @override
  String get shareSheetCopy => 'Sao chép';

  @override
  String get shareSheetShareVia => 'Chia sẻ qua';

  @override
  String get shareSheetEventJson => 'JSON sự kiện';

  @override
  String get shareSheetEventId => 'ID sự kiện';

  @override
  String get shareSheetMoreActions => 'Thao tác khác';

  @override
  String get shareSheetCrosspost => 'Đăng chéo';

  @override
  String get crosspostSheetTitle => 'Đăng chéo video này';

  @override
  String get crosspostSheetSubtitle =>
      'Gửi nó tới các nền tảng bạn đã kết nối. Việc đăng có thể mất vài phút.';

  @override
  String get crosspostSubmit => 'Đăng chéo';

  @override
  String get crosspostStatusQueued => 'Đang chờ';

  @override
  String get crosspostStatusUploading => 'Đang tải lên';

  @override
  String get crosspostStatusProcessing => 'Đang xử lý';

  @override
  String get crosspostStatusPosted => 'Đã đăng';

  @override
  String get crosspostStatusFailed => 'Thất bại';

  @override
  String get crosspostStatusSkipped => 'Đã bỏ qua';

  @override
  String get crosspostStatusNeedsReauth => 'Cần kết nối lại';

  @override
  String get crosspostViewPost => 'Xem bài đăng';

  @override
  String crosspostReconnectPrompt(String platform) {
    return 'Kết nối lại $platform trong cài đặt đăng chéo để tiếp tục đăng.';
  }

  @override
  String get crosspostReconnect => 'Kết nối lại';

  @override
  String get crosspostErrorNotOwner =>
      'Chỉ có video của chính bạn mới đăng chéo được.';

  @override
  String get crosspostErrorNotEligible =>
      'Video này không đủ điều kiện đăng chéo.';

  @override
  String get crosspostErrorNotConnected => 'Nền tảng đó chưa được kết nối.';

  @override
  String get crosspostErrorUnauthorized =>
      'Hãy kết nối lại tài khoản của bạn rồi thử lại.';

  @override
  String get crosspostErrorNetwork =>
      'Không kết nối được với dịch vụ đăng chéo. Thử lại sau ít phút.';

  @override
  String get crosspostFailedGeneric => 'Đăng chéo thất bại.';

  @override
  String get crosspostStillWorking =>
      'Vẫn đang xử lý. Bạn có thể đóng cái này — việc đăng tiếp tục chạy ngầm.';

  @override
  String get crosspostDone => 'Xong';

  @override
  String get watermarkDownloadSavedToCameraRoll => 'Đã lưu vào thư viện ảnh';

  @override
  String get watermarkDownloadShare => 'Chia sẻ';

  @override
  String get watermarkDownloadDone => 'Xong';

  @override
  String get watermarkDownloadPhotosAccessNeeded => 'Cần quyền truy cập Ảnh';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      'Để lưu video, hãy cho phép truy cập Ảnh trong Cài đặt.';

  @override
  String get watermarkDownloadOpenSettings => 'Mở Cài đặt';

  @override
  String get watermarkDownloadNotNow => 'Để sau';

  @override
  String get watermarkDownloadFailed => 'Tải xuống thất bại';

  @override
  String get watermarkDownloadDismiss => 'Bỏ qua';

  @override
  String get watermarkDownloadStageDownloading => 'Đang tải video xuống';

  @override
  String get watermarkDownloadStageWatermarking => 'Đang thêm watermark';

  @override
  String get watermarkDownloadStageSaving => 'Đang lưu vào thư viện ảnh';

  @override
  String get watermarkDownloadStageDownloadingDesc =>
      'Đang lấy video từ mạng...';

  @override
  String get watermarkDownloadStageWatermarkingDesc =>
      'Đang áp watermark Divine...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      'Đang lưu video đã gắn watermark vào thư viện ảnh của bạn...';

  @override
  String get shareMenuBookmarks => 'Dấu trang';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    return 'Có $count nhóm theo dõi';
  }

  @override
  String get peopleListsAddToList => 'Thêm vào danh sách';

  @override
  String get peopleListsSheetTitle => 'Thêm vào danh sách';

  @override
  String get peopleListsEmptyTitle => 'Chưa có danh sách nào';

  @override
  String get peopleListsEmptySubtitle =>
      'Tạo một danh sách để bắt đầu nhóm mọi người.';

  @override
  String get peopleListsCreateList => 'Tạo danh sách';

  @override
  String get peopleListsNewListTitle => 'Danh sách mới';

  @override
  String get peopleListsRouteTitle => 'Danh sách người';

  @override
  String get peopleListsListNameLabel => 'Tên danh sách';

  @override
  String get peopleListsListNameHint => 'Bạn thân';

  @override
  String get peopleListsCreateButton => 'Tạo';

  @override
  String get peopleListsAddPeopleTitle => 'Thêm người';

  @override
  String get peopleListsAddPeopleTooltip => 'Thêm người';

  @override
  String get peopleListsAddPeopleSemanticLabel => 'Thêm người vào danh sách';

  @override
  String get peopleListsListNotFoundTitle => 'Không tìm thấy danh sách';

  @override
  String get peopleListsListNotFoundSubtitle =>
      'Không tìm thấy danh sách. Có thể nó đã bị xóa.';

  @override
  String get peopleListsListDeletedSubtitle =>
      'Danh sách này có thể đã bị xóa.';

  @override
  String get peopleListsNoPeopleTitle => 'Chưa có ai trong danh sách này';

  @override
  String get peopleListsNoPeopleSubtitle => 'Thêm vài người để bắt đầu';

  @override
  String get peopleListsNoVideosTitle => 'Chưa có video nào';

  @override
  String get peopleListsNoVideosSubtitle =>
      'Video từ các thành viên trong danh sách sẽ xuất hiện ở đây';

  @override
  String get peopleListsNoVideosAvailable => 'Không có video nào';

  @override
  String get peopleListsFailedToLoadVideos => 'Không tải được video';

  @override
  String get peopleListsVideoNotAvailable => 'Video không khả dụng';

  @override
  String get peopleListsBackToGridTooltip => 'Quay lại lưới';

  @override
  String get peopleListsErrorLoadingVideos => 'Lỗi khi tải video';

  @override
  String get peopleListsNoPeopleToAdd => 'Không có ai để thêm.';

  @override
  String peopleListsAddToListName(String name) {
    return 'Thêm vào $name';
  }

  @override
  String get peopleListsAddPeopleSearchHint => 'Tìm người';

  @override
  String get peopleListsAddPeopleError =>
      'Không tải được danh sách người. Vui lòng thử lại.';

  @override
  String get peopleListsAddPeopleRetry => 'Thử lại';

  @override
  String get peopleListsAddButton => 'Thêm';

  @override
  String peopleListsAddButtonWithCount(int count) {
    return 'Thêm $count';
  }

  @override
  String peopleListsInNLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Trong $count danh sách',
      one: 'Trong 1 danh sách',
    );
    return '$_temp0';
  }

  @override
  String peopleListsRemoveConfirmTitle(String name) {
    return 'Xóa $name?';
  }

  @override
  String get peopleListsRemoveConfirmBody => 'Họ sẽ bị xóa khỏi danh sách này.';

  @override
  String get peopleListsRemove => 'Xóa';

  @override
  String peopleListsRemovedFromList(String name) {
    return 'Đã xóa $name khỏi danh sách';
  }

  @override
  String get peopleListsUndo => 'Hoàn tác';

  @override
  String peopleListsProfileLongPressHint(String name) {
    return 'Hồ sơ của $name. Nhấn giữ để xóa.';
  }

  @override
  String peopleListsViewProfileHint(String name) {
    return 'Xem hồ sơ của $name';
  }

  @override
  String get shareMenuEditVideo => 'Chỉnh sửa video';

  @override
  String get shareMenuDeleteVideo => 'Xóa video';

  @override
  String shareMenuVideoCount(int count) {
    return '$count video';
  }

  @override
  String get shareMenuDeleteConfirmation =>
      'Video này sẽ bị xóa vĩnh viễn khỏi Divine. Nó vẫn có thể xuất hiện trên các ứng dụng Nostr bên thứ ba dùng relay khác.';

  @override
  String get shareMenuCancel => 'Hủy';

  @override
  String get shareMenuDelete => 'Xóa';

  @override
  String get shareMenuDeleteFailedNotInitialized =>
      'Chức năng xóa chưa sẵn sàng. Thử lại sau ít phút.';

  @override
  String get shareMenuDeleteFailedNotOwner =>
      'Bạn chỉ có thể xóa video của chính mình.';

  @override
  String get shareMenuDeleteFailedNotAuthenticated =>
      'Hãy đăng nhập lại rồi thử xóa.';

  @override
  String get shareMenuDeleteFailedCouldNotSign =>
      'Không ký được yêu cầu xóa. Thử lại nhé.';

  @override
  String get shareMenuDeleteFailedRelayRejected =>
      'Relay không chấp nhận yêu cầu xóa này. Thử lại sau ít phút.';

  @override
  String get shareMenuDeleteFailedAccountRestricted =>
      'Your account is restricted, so this delete request couldn\'t be sent. Contact support for help deleting it.';

  @override
  String get shareMenuDeleteFailedRelayNoResponse =>
      'Không kết nối được với relay. Kiểm tra kết nối của bạn rồi thử lại.';

  @override
  String get shareMenuDeletePartiallyConfirmed =>
      'Đã xoá. Không phải relay nào cũng xác nhận, nên nó có thể vẫn hiện ở app khác.';

  @override
  String get shareMenuDeleteFailedGeneric =>
      'Không xóa được video này. Thử lại nhé.';

  @override
  String get shareMenuUpdate => 'Cập nhật';

  @override
  String get shareMenuChangeCover => 'Đổi ảnh bìa';

  @override
  String get shareMenuVideoUpdated => 'Đã cập nhật video thành công';

  @override
  String shareMenuVideoUpdatedWithInviteFailures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lời mời cộng tác không gửi được.',
      one: '1 lời mời cộng tác không gửi được.',
    );
    return 'Đã cập nhật video, nhưng $_temp0';
  }

  @override
  String get videoUpdateErrorNotAuthenticated => 'Đăng nhập lại rồi thử lại.';

  @override
  String get videoUpdateErrorNoPlayableVideo =>
      'Video này không có nguồn phát được nên không thể chỉnh sửa.';

  @override
  String get videoUpdateErrorCouldNotSign =>
      'Không ký được bản cập nhật. Thử lại nhé.';

  @override
  String get videoUpdateErrorPublishRejected =>
      'Relay không chấp nhận bản cập nhật. Thử lại sau giây lát.';

  @override
  String get videoUpdateErrorGeneric =>
      'Không cập nhật được video này. Thử lại nhé.';

  @override
  String get shareMenuOriginalVideoUnavailable =>
      'Couldn\'t load the original video. Try again in a moment.';

  @override
  String get shareMenuDeleteVideoQuestion => 'Xóa video?';

  @override
  String get shareMenuDeleteCleanupInProgress => 'Đang xóa video…';

  @override
  String get shareMenuDeleteCleanupConfirmed => 'Đã xóa video.';

  @override
  String get shareMenuDeleteCleanupDelayed =>
      'Đã xóa video. Có thể mất một lúc để video biến mất ở mọi nơi.';

  @override
  String get shareMenuDeleteCleanupFailed =>
      'Đã xóa video nhưng chúng tôi không thể xóa mọi bản sao. Hãy liên hệ bộ phận hỗ trợ.';

  @override
  String get authSessionExpired =>
      'Phiên đăng nhập của bạn đã hết hạn. Vui lòng đăng nhập lại.';

  @override
  String get authAccountRestoreFailed =>
      'We couldn\'t unlock that account on this device. Sign in again.';

  @override
  String get authSignInFailed => 'Đăng nhập thất bại. Vui lòng thử lại.';

  @override
  String get webAuthNotSupportedSecureMode =>
      'Không hỗ trợ xác thực web ở chế độ bảo mật. Hãy dùng ứng dụng di động để quản lý khóa an toàn.';

  @override
  String get webAuthEnterBunkerUri => 'Vui lòng nhập URI bunker';

  @override
  String get webAuthConnectTitle => 'Kết nối với Divine';

  @override
  String get webAuthChooseMethod => 'Chọn phương thức xác thực Nostr bạn thích';

  @override
  String get webAuthBrowserExtension => 'Tiện ích trình duyệt';

  @override
  String get webAuthRecommended => 'KHUYÊN DÙNG';

  @override
  String get webAuthNsecBunker => 'nsec bunker';

  @override
  String get webAuthConnectRemoteSigner => 'Kết nối tới trình ký từ xa';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => 'Dán từ khay nhớ tạm';

  @override
  String get webAuthConnectToBunker => 'Kết nối tới Bunker';

  @override
  String get webAuthNewToNostr => 'Mới dùng Nostr?';

  @override
  String get webAuthNostrHelp =>
      'Cài tiện ích trình duyệt như Alby hoặc nos2x cho trải nghiệm dễ nhất, hoặc dùng nsec bunker để ký từ xa an toàn.';

  @override
  String get soundsTitle => 'Âm thanh';

  @override
  String get soundsSearchHint => 'Tìm âm thanh...';

  @override
  String get soundsSearchResults => 'Kết quả tìm kiếm';

  @override
  String get soundsNoSoundsFound => 'Không tìm thấy âm thanh nào';

  @override
  String get soundsNoSoundsFoundDescription => 'Thử từ khóa khác nhé';

  @override
  String get soundsSavedToLibrary => 'Đã lưu vào Âm thanh';

  @override
  String get soundsAlreadySavedToLibrary => 'Đã có trong Âm thanh';

  @override
  String get soundsSavedLibraryTitle => 'Âm thanh của tôi';

  @override
  String get soundsSavedEmptyTitle => 'Chưa có âm thanh đã lưu';

  @override
  String get soundsSavedEmptyDescription =>
      'Chạm Dùng âm thanh trên một video để lưu nó vào đây.';

  @override
  String get soundsRemoveSavedSound => 'Xóa âm thanh';

  @override
  String get savedSoundSaveAction => 'Lưu';

  @override
  String get savedSoundPausePreviewAction => 'Tạm dừng nghe thử';

  @override
  String get savedSoundResumePreviewAction => 'Tiếp tục nghe thử';

  @override
  String get savedSoundDetailsSheetTitle => 'Chi tiết âm thanh';

  @override
  String get savedSoundRemoveConfirmTitle => 'Xóa âm thanh này?';

  @override
  String get savedSoundRemoveConfirmMessage =>
      'Nó biến mất khỏi thư viện của bạn, nhưng bạn có thể lưu lại từ bất kỳ video nào dùng nó.';

  @override
  String get soundsRemovedFromLibrary => 'Đã xóa khỏi Âm thanh';

  @override
  String get soundsSaveFailed => 'Không lưu được âm thanh đó. Thử lại nhé.';

  @override
  String get soundsRemoveFailed => 'Không gỡ được âm thanh đó. Thử lại nhé.';

  @override
  String get soundSyncStatusSyncing => 'Đang đồng bộ âm thanh của bạn…';

  @override
  String get soundSyncStatusSynced => 'Âm thanh đã được cập nhật';

  @override
  String get soundSyncStatusFailed =>
      'Không đồng bộ được âm thanh của bạn. Chúng tôi sẽ thử lại.';

  @override
  String get soundSyncStatusLocked =>
      'Không thể mở khoá thư viện đã đồng bộ trên thiết bị này.';

  @override
  String get profileTitle => 'Hồ sơ';

  @override
  String get profileMoreOptions => 'Tùy chọn khác';

  @override
  String profileBlockedUser(String name) {
    return 'Đã chặn $name';
  }

  @override
  String profileUnblockedUser(String name) {
    return 'Đã bỏ chặn $name';
  }

  @override
  String profileUnfollowedUser(String name) {
    return 'Đã bỏ theo dõi $name';
  }

  @override
  String get profileFeedError =>
      'Không kết nối được với máy chủ. Kiểm tra kết nối của bạn rồi thử lại nhé.';

  @override
  String get profileFeedLoadMoreError =>
      'Không tải thêm được video. Kéo để làm mới.';

  @override
  String get notificationsTabAll => 'Tất cả';

  @override
  String get notificationsTabLikes => 'Lượt thích';

  @override
  String get notificationsTabComments => 'Bình luận';

  @override
  String get notificationsTabFollows => 'Lượt theo dõi';

  @override
  String get notificationsTabReposts => 'Bài đăng lại';

  @override
  String get notificationsFailedToLoad => 'Không tải được thông báo';

  @override
  String get notificationsRetry => 'Thử lại';

  @override
  String get notificationsRefreshError =>
      'Không làm mới được — hiện những gì bạn đang có';

  @override
  String get notificationsUnreadPrefix => 'Thông báo chưa đọc';

  @override
  String notificationsBadgeUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count thông báo chưa đọc',
      one: '1 thông báo chưa đọc',
    );
    return '$_temp0';
  }

  @override
  String notificationsViewProfileSemanticLabel(String displayName) {
    return 'Xem hồ sơ của $displayName';
  }

  @override
  String get notificationsViewProfilesSemanticLabel => 'Xem hồ sơ';

  @override
  String notificationsVideoThumbnailFor(String title) {
    return 'Ảnh thu nhỏ video của $title';
  }

  @override
  String get notificationsVideoThumbnail => 'Ảnh thu nhỏ video';

  @override
  String get notificationsInviteSingular =>
      'Bạn có 1 lời mời để chia sẻ với bạn bè!';

  @override
  String notificationsInvitePlural(int count) {
    return 'Bạn có $count lời mời để chia sẻ với bạn bè!';
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
  String get notificationsVideoUnavailable => 'Video không khả dụng';

  @override
  String get feedFailedToLoadVideos => 'Không tải được video';

  @override
  String get feedRetry => 'Thử lại';

  @override
  String get feedNoFollowedUsers =>
      'Chưa theo dõi ai.\nTheo dõi ai đó để xem video của họ ở đây.';

  @override
  String get feedModeForYou => 'Dành cho bạn';

  @override
  String get feedModeNew => 'Mới';

  @override
  String get feedModeFollowing => 'Đang theo dõi';

  @override
  String get feedModeClassics => 'Kinh điển';

  @override
  String feedModeSemanticLabel(String label) {
    return 'Chế độ bảng tin: $label';
  }

  @override
  String videoAuthorSemanticLabel(String displayName) {
    return 'Tác giả video: $displayName';
  }

  @override
  String get videoAuthorAvatarSemanticLabel => 'Ảnh đại diện tác giả';

  @override
  String get feedForYouEmpty =>
      'Bảng tin Dành cho bạn đang trống.\nKhám phá video và theo dõi nhà sáng tạo để định hình nó.';

  @override
  String get feedFollowingEmpty =>
      'Chưa có video từ người bạn theo dõi.\nTìm nhà sáng tạo bạn thích và theo dõi họ nhé.';

  @override
  String get feedLatestEmpty => 'Chưa có video mới.\nQuay lại sau nhé.';

  @override
  String get feedClassicEmpty =>
      'Chưa có Vine kinh điển nào.\nQuay lại sau nhé.';

  @override
  String get feedExploreVideos => 'Khám phá video';

  @override
  String get feedLoadingMore => 'Đang tải thêm video…';

  @override
  String get feedRefreshed => 'Đã làm mới bảng tin';

  @override
  String get uploadUploadingVideo => 'Đang tải video lên';

  @override
  String get postPublishConfirmationTitle => 'Đã được đăng lên hồ sơ của bạn';

  @override
  String get postPublishConfirmationView => 'Xem';

  @override
  String get postPublishConfirmationShare => 'Chia sẻ';

  @override
  String get postPublishConfirmationThumbnailLabel =>
      'Ảnh thu nhỏ của video bạn vừa đăng';

  @override
  String get userSearchNoResults => 'Không tìm thấy người dùng nào';

  @override
  String get userPickerFilterByNameHint => 'Lọc theo tên...';

  @override
  String get userPickerSearchByNameHint => 'Tìm theo tên...';

  @override
  String get userPickerClearSearchSemantics => 'Xóa tìm kiếm';

  @override
  String userPickerAlreadyAddedSemantics(String name) {
    return '$name đã được thêm';
  }

  @override
  String userPickerSelectSemantics(String name) {
    return 'Chọn $name';
  }

  @override
  String userPickerRemoveSelectionSemantics(String name) {
    return 'Xóa $name';
  }

  @override
  String get userPickerEmptyFollowListTitle => 'Hội của bạn đang ở ngoài kia';

  @override
  String get userPickerEmptyFollowListBody =>
      'Theo dõi những người hợp gu với bạn. Khi họ theo dõi lại, bạn có thể cộng tác.';

  @override
  String get userPickerGoBack => 'Quay lại';

  @override
  String get userPickerTypeNameToSearch => 'Gõ tên để tìm kiếm';

  @override
  String get userPickerUnavailable =>
      'Tìm kiếm người dùng hiện không khả dụng. Vui lòng thử lại sau.';

  @override
  String get userPickerSearchFailedTryAgain =>
      'Tìm kiếm thất bại. Vui lòng thử lại.';

  @override
  String get forgotPasswordTitle => 'Đặt lại mật khẩu';

  @override
  String get forgotPasswordDescription =>
      'Nhập địa chỉ email của bạn và bọn mình sẽ gửi liên kết để đặt lại mật khẩu.';

  @override
  String get forgotPasswordEmailLabel => 'Địa chỉ email';

  @override
  String get forgotPasswordCancel => 'Hủy';

  @override
  String get forgotPasswordSendLink => 'Gửi liên kết đặt lại qua email';

  @override
  String get ageVerificationContentWarning => 'Cảnh báo nội dung';

  @override
  String get ageVerificationTitle => 'Xác minh độ tuổi';

  @override
  String get ageVerificationAdultDescription =>
      'Nội dung này đã bị gắn cờ là có thể chứa tài liệu người lớn. Bạn phải đủ 18 tuổi để xem.';

  @override
  String get ageVerificationCreationDescription =>
      'Để dùng camera và tạo nội dung, bạn phải đủ 16 tuổi.';

  @override
  String get ageVerificationAdultQuestion => 'Bạn đã đủ 18 tuổi chưa?';

  @override
  String get ageVerificationCreationQuestion => 'Bạn đã đủ 16 tuổi chưa?';

  @override
  String get ageVerificationNo => 'Chưa';

  @override
  String get ageVerificationYes => 'Rồi';

  @override
  String get navHome => 'Trang chủ';

  @override
  String get navExplore => 'Khám phá';

  @override
  String get navInbox => 'Hộp thư';

  @override
  String get navProfile => 'Hồ sơ';

  @override
  String get navMyProfile => 'Hồ sơ của tôi';

  @override
  String get navNotifications => 'Thông báo';

  @override
  String get navOpenCamera => 'Mở camera';

  @override
  String get navExploreClassics => 'Kinh điển';

  @override
  String get navExploreNewVideos => 'Video mới';

  @override
  String get navExploreTrending => 'Thịnh hành';

  @override
  String get navExploreForYou => 'Dành cho bạn';

  @override
  String get navExploreLists => 'Danh sách';

  @override
  String get routeErrorTitle => 'Lỗi';

  @override
  String get routeInvalidHashtag => 'Hashtag không hợp lệ';

  @override
  String get routeInvalidConversationId => 'ID cuộc trò chuyện không hợp lệ';

  @override
  String get routeInvalidRequestId => 'ID yêu cầu không hợp lệ';

  @override
  String get routeInvalidListId => 'ID danh sách không hợp lệ';

  @override
  String get routeInvalidUserId => 'ID người dùng không hợp lệ';

  @override
  String get routeInvalidVideoId => 'ID video không hợp lệ';

  @override
  String get routeInvalidSoundId => 'ID âm thanh không hợp lệ';

  @override
  String get routeInvalidCategory => 'Danh mục không hợp lệ';

  @override
  String get routeNoVideosToDisplay => 'Không có video nào để hiển thị';

  @override
  String get routeGoHome => 'Về trang chủ';

  @override
  String get routeInvalidProfileId => 'ID hồ sơ không hợp lệ';

  @override
  String get routeUnknownPath => 'Trang đó không có trong ứng dụng.';

  @override
  String get routeDefaultListName => 'Danh sách';

  @override
  String get supportTitle => 'Trung tâm hỗ trợ';

  @override
  String get supportContactSupport => 'Liên hệ hỗ trợ';

  @override
  String get supportContactSupportSubtitle =>
      'Bắt đầu cuộc trò chuyện hoặc xem tin nhắn cũ';

  @override
  String get supportReportBug => 'Báo lỗi';

  @override
  String get supportReportBugSubtitle => 'Sự cố kỹ thuật của ứng dụng';

  @override
  String get supportRequestFeature => 'Yêu cầu tính năng';

  @override
  String get supportRequestFeatureSubtitle =>
      'Đề xuất cải tiến hoặc tính năng mới';

  @override
  String get supportSaveLogs => 'Lưu nhật ký';

  @override
  String get supportSaveLogsSubtitle => 'Xuất nhật ký ra tệp để gửi thủ công';

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
  String get supportFaq => 'Câu hỏi thường gặp';

  @override
  String get supportFaqSubtitle => 'Câu hỏi & câu trả lời phổ biến';

  @override
  String get supportFamily => 'Divine Family';

  @override
  String get supportFamilySubtitle =>
      'Giúp phụ huynh và thanh thiếu niên xây dựng thói quen lành mạnh trực tuyến';

  @override
  String get supportKids => 'Divine Kids';

  @override
  String get supportKidsSubtitle =>
      'Cách chúng tôi xử lý tài khoản theo độ tuổi';

  @override
  String get supportProofMode => 'ProofMode';

  @override
  String get supportProofModeSubtitle =>
      'Tìm hiểu về xác minh và tính xác thực';

  @override
  String get supportLoginRequired => 'Đăng nhập để liên hệ hỗ trợ';

  @override
  String get supportExportingLogs => 'Đang xuất nhật ký...';

  @override
  String get supportExportLogsFailed => 'Không xuất được nhật ký';

  @override
  String get supportNoLogsToExport =>
      'No logs yet — they start fresh each launch. Reproduce the problem, then come back without restarting.';

  @override
  String get supportExportLogsUnconfirmed =>
      'Logs handed off. Check the app you shared to.';

  @override
  String supportLogsSavedTo(String path) {
    return 'Đã lưu nhật ký vào $path';
  }

  @override
  String get supportRevealLogsAction => 'Hiện trong thư mục';

  @override
  String get supportChatNotAvailable => 'Chat hỗ trợ không khả dụng';

  @override
  String get supportCouldNotOpenMessages => 'Không mở được tin nhắn hỗ trợ';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return 'Không mở được $pageName';
  }

  @override
  String get reportWhyReporting => 'Tại sao bạn báo cáo nội dung này?';

  @override
  String get reportPolicyNotice =>
      'Divine sẽ xử lý báo cáo nội dung trong vòng 24 giờ bằng cách gỡ nội dung và loại người dùng đăng nội dung vi phạm.';

  @override
  String get reportBlockUser => 'Chặn người dùng này';

  @override
  String get reportCancel => 'Hủy';

  @override
  String get reportSubmit => 'Báo cáo';

  @override
  String get reportSelectReason => 'Vui lòng chọn lý do báo cáo nội dung này';

  @override
  String get reportOtherRequiresDetails =>
      'Vui lòng mô tả vấn đề khi chọn Khác';

  @override
  String get reportDetailsRequired => 'Vui lòng mô tả vấn đề';

  @override
  String get reportDetailsTextOnly =>
      'Chỉ văn bản — không thể đính kèm ảnh hoặc GIF ở đây.';

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
  String get reportReasonSpam => 'Spam hoặc nội dung không mong muốn';

  @override
  String get reportReasonSpamSubtitle =>
      'Nội dung không mong muốn hoặc lặp lại';

  @override
  String get reportReasonHarassment => 'Quấy rối, bắt nạt hoặc đe dọa';

  @override
  String get reportReasonHarassmentSubtitle =>
      'Trả lời hoặc nhắc đến có hại và không mong muốn';

  @override
  String get reportReasonViolence => 'Nội dung bạo lực hoặc cực đoan';

  @override
  String get reportReasonViolenceSubtitle =>
      'Nội dung bạo lực, cực đoan hoặc có hại';

  @override
  String get reportReasonSexualContent => 'Nội dung tình dục hoặc người lớn';

  @override
  String get reportReasonSexualContentSubtitle =>
      'Khỏa thân, khiêu dâm hoặc nội dung lộ liễu';

  @override
  String get reportReasonCopyright => 'Vi phạm bản quyền';

  @override
  String get reportReasonCopyrightSubtitle =>
      'Sử dụng tài sản trí tuệ trái phép';

  @override
  String get reportReasonFalseInfo => 'Thông tin sai lệch';

  @override
  String get reportReasonFalseInfoSubtitle =>
      'Tuyên bố gây hiểu lầm hoặc sai sự thật';

  @override
  String get reportReasonChildSafety => 'Vi phạm an toàn trẻ em';

  @override
  String get reportReasonChildSafetySubtitle =>
      'Lo ngại chung về an toàn của trẻ vị thành niên';

  @override
  String get reportReasonCsam => 'Xâm hại tình dục trẻ em';

  @override
  String get reportReasonCsamSubtitle =>
      'Nội dung mô tả hành vi xâm hại tình dục trẻ vị thành niên';

  @override
  String get reportReasonUnderageUser => 'Người dùng có vẻ dưới 16 tuổi';

  @override
  String get reportReasonUnderageUserSubtitle =>
      'Chủ tài khoản có vẻ chưa đủ tuổi';

  @override
  String get reportReasonAiGenerated => 'Nội dung do AI tạo ra';

  @override
  String get reportReasonAiGeneratedSubtitle =>
      'Nghi ngờ nội dung do AI tạo ra';

  @override
  String get reportReasonOther => 'Vi phạm chính sách khác';

  @override
  String get reportReasonOtherSubtitle =>
      'Các vi phạm không có trong danh sách trên';

  @override
  String get reportFailed => 'Không báo cáo được nội dung. Vui lòng thử lại.';

  @override
  String get reportNotSent =>
      'Không gửi được báo cáo của bạn. Kiểm tra kết nối của bạn rồi thử lại nhé.';

  @override
  String get reportReceivedTitle => 'Đã nhận báo cáo';

  @override
  String get reportReceivedThankYou => 'Cảm ơn bạn đã giúp giữ Divine an toàn.';

  @override
  String get reportReceivedReviewNotice =>
      'Đội ngũ của bọn mình sẽ xem xét báo cáo của bạn và có hành động phù hợp. Bạn có thể nhận được cập nhật qua tin nhắn trực tiếp.';

  @override
  String get reportModerationDmDelayed =>
      'Bọn mình chưa liên hệ trực tiếp được với đội kiểm duyệt lúc này, nhưng báo cáo của bạn đã được nhận và sẽ được xem xét.';

  @override
  String get reportContactModeration => 'Nhắn tin cho đội kiểm duyệt';

  @override
  String get reportLearnMoreAt => 'Tìm hiểu thêm tại';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => 'Đóng';

  @override
  String get listAddToList => 'Thêm vào danh sách';

  @override
  String listVideoCount(int count) {
    return '$count video';
  }

  @override
  String listPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count người',
      one: '1 người',
    );
    return '$_temp0';
  }

  @override
  String get listByAuthorPrefix => 'Bởi ';

  @override
  String get listNewList => 'Danh sách mới';

  @override
  String get listDone => 'Xong';

  @override
  String get listErrorLoading => 'Lỗi khi tải danh sách';

  @override
  String listRemovedFrom(String name) {
    return 'Đã xóa khỏi $name';
  }

  @override
  String listAddedTo(String name) {
    return 'Đã thêm vào $name';
  }

  @override
  String get listCreateNewList => 'Tạo danh sách mới';

  @override
  String get listNewPeopleList => 'Danh sách người mới';

  @override
  String get listCollaboratorsNone => 'Không có';

  @override
  String get listAddCollaboratorTitle => 'Thêm cộng tác viên';

  @override
  String get listCollaboratorSearchHint => 'Tìm trên Divine...';

  @override
  String get listNameLabel => 'Tên danh sách';

  @override
  String get listDescriptionLabel => 'Mô tả (không bắt buộc)';

  @override
  String get listPublicList => 'Danh sách công khai';

  @override
  String get listPublicListSubtitle =>
      'Người khác có thể theo dõi và xem danh sách này';

  @override
  String get listPrivateListSubtitle =>
      'Video vẫn riêng tư. Tên, mô tả, thẻ và ảnh bìa vẫn hiển thị.';

  @override
  String get listVisibilityPublic => 'Công khai';

  @override
  String get listVisibilityPrivate => 'Riêng tư';

  @override
  String get profileListsEmpty =>
      'Chưa có danh sách nào. Tạo một cái cho những loop bạn muốn để chung.';

  @override
  String get listEditTitle => 'Sửa danh sách';

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
  String get listShareAction => 'Chia sẻ danh sách';

  @override
  String get listShareFailed =>
      'Không chia sẻ được danh sách này. Thử lại nhé.';

  @override
  String get listSave => 'Lưu';

  @override
  String get listContinue => 'Tiếp tục';

  @override
  String get listPrivateFull =>
      'This private list is full. Remove something to add more.';

  @override
  String get listUpdateFailed =>
      'Không cập nhật được danh sách này. Thử lại nhé.';

  @override
  String get listMakePrivateTitle => 'Chuyển danh sách này thành riêng tư?';

  @override
  String get listMakePrivateWarning =>
      'Video sẽ được mã hóa nên chỉ mình bạn xem được. Tên, mô tả, thẻ và ảnh bìa vẫn hiển thị, và những bản đã chia sẻ trước đó vẫn có thể còn.';

  @override
  String get listMakePublicTitle => 'Chuyển danh sách này thành công khai?';

  @override
  String get listMakePublicWarning =>
      'Bất kỳ ai có liên kết đều xem được danh sách này và các video trong đó.';

  @override
  String listShareText(String name, String url) {
    return 'Xem $name trên Divine: $url';
  }

  @override
  String listShareSubject(String name) {
    return '$name trên Divine';
  }

  @override
  String get listCancel => 'Hủy';

  @override
  String get listCreate => 'Tạo';

  @override
  String get listCreateFailed => 'Không tạo được danh sách';

  @override
  String get keyManagementTitle => 'Khóa Nostr';

  @override
  String get keyManagementWhatAreKeys => 'Khóa Nostr là gì?';

  @override
  String get keyManagementExplanation =>
      'Danh tính Nostr của bạn là một cặp khóa mã hóa:\n\n• Khóa công khai (npub) giống tên người dùng của bạn - chia sẻ thoải mái\n• Khóa riêng tư (nsec) giống mật khẩu của bạn - hãy giữ kín!\n\nnsec của bạn cho phép truy cập tài khoản trên bất kỳ ứng dụng Nostr nào.';

  @override
  String get keyManagementImportTitle => 'Nhập khóa hiện có';

  @override
  String get keyManagementImportSubtitle =>
      'Đã có tài khoản Nostr? Dán khóa riêng tư (nsec) của bạn để truy cập tại đây.';

  @override
  String get keyManagementImportButton => 'Nhập khóa';

  @override
  String get keyManagementImportWarning =>
      'Việc này sẽ thay thế khóa hiện tại của bạn!';

  @override
  String get keyManagementBackupTitle => 'Sao lưu khóa của bạn';

  @override
  String get keyManagementBackupSubtitle =>
      'Lưu khóa riêng tư (nsec) để dùng tài khoản của bạn trong các ứng dụng Nostr khác.';

  @override
  String get keyManagementCopyNsec => 'Sao chép khóa riêng tư của tôi (nsec)';

  @override
  String get keyManagementNeverShare =>
      'Đừng bao giờ chia sẻ nsec của bạn với bất kỳ ai!';

  @override
  String get keyManagementKeycastRemoteSigning =>
      'Khóa của bạn nằm trên dịch vụ đăng nhập của Divine, không phải trên thiết bị này. Xác nhận bằng mật khẩu của bạn, rồi bọn mình sẽ lấy khóa về cho bạn.';

  @override
  String get keyManagementKeycastPasswordPrompt =>
      'Khóa của bạn do dịch vụ đăng nhập của Divine giữ. Nhập mật khẩu tài khoản và bọn mình sẽ lấy khóa về.';

  @override
  String get keyManagementKeycastCopyKey => 'Sao chép khóa';

  @override
  String get keyManagementKeycastCopyBlocked =>
      'Thiết bị của bạn đã chặn thao tác sao chép, nên khóa của bạn chưa vào được khay nhớ tạm.';

  @override
  String get keyManagementKeycastWrongPassword =>
      'Mật khẩu đó không khớp. Thử lại nhé.';

  @override
  String get keyManagementKeycastTooManyAttempts =>
      'Thử sai quá nhiều lần. Đóng lại rồi bắt đầu lại nhé.';

  @override
  String get keyManagementKeycastRateLimited =>
      'Quá nhiều yêu cầu lấy khóa. Chờ vài phút rồi thử lại.';

  @override
  String get keyManagementKeycastSignInAgain =>
      'Phiên đăng nhập của bạn đã hết hạn. Đăng nhập lại để sao chép khóa.';

  @override
  String get keyManagementKeycastEmailUnverified =>
      'Hãy xác minh địa chỉ email của bạn trước khi sao chép khóa.';

  @override
  String get keyManagementKeycastDenied =>
      'Khóa của tài khoản này do Divine quản lý, nên không sao chép được ở đây.';

  @override
  String get keyManagementKeycastNoKey =>
      'Không có khóa nào được lưu cho tài khoản này.';

  @override
  String get keyManagementKeycastGenericFailure =>
      'Không kết nối được với dịch vụ đăng nhập. Vui lòng thử lại.';

  @override
  String get keyManagementRestrictedTitle => 'Khóa của bạn do Divine quản lý';

  @override
  String get keyManagementRestrictedBody =>
      'Để giữ an toàn cho tài khoản của bạn, sao lưu khóa và nhập khóa khác không khả dụng ở đây.';

  @override
  String get keyManagementPasteKey => 'Vui lòng dán khóa riêng tư của bạn';

  @override
  String get keyManagementInvalidFormat =>
      'Định dạng khóa không hợp lệ. Phải bắt đầu bằng \"nsec1\"';

  @override
  String get keyManagementConfirmImportTitle => 'Nhập khóa này?';

  @override
  String get keyManagementConfirmImportBody =>
      'Việc này sẽ thay thế danh tính hiện tại của bạn bằng danh tính được nhập.\n\nKhóa hiện tại của bạn sẽ mất trừ khi bạn đã sao lưu trước.';

  @override
  String get keyManagementImportConfirm => 'Nhập';

  @override
  String get keyManagementImportSuccess => 'Đã nhập khóa thành công!';

  @override
  String get keyManagementImportFailed =>
      'Không nhập được khóa. Vui lòng thử lại.';

  @override
  String get keyManagementExportSuccess =>
      'Đã sao chép khóa riêng tư vào khay nhớ tạm!\n\nHãy cất nó ở nơi an toàn.';

  @override
  String get keyManagementExportFailed =>
      'Không xuất được khóa. Vui lòng thử lại.';

  @override
  String get keyManagementYourPublicKeyLabel => 'Khóa công khai của bạn (npub)';

  @override
  String get keyManagementCopyPublicKeyTooltip => 'Sao chép khóa công khai';

  @override
  String get keyManagementPublicKeyCopied => 'Đã sao chép khóa công khai';

  @override
  String get saveOriginalSavedToCameraRoll => 'Đã lưu vào thư viện ảnh';

  @override
  String get saveOriginalShare => 'Chia sẻ';

  @override
  String get saveOriginalDone => 'Xong';

  @override
  String get saveOriginalPhotosAccessNeeded => 'Cần quyền truy cập Ảnh';

  @override
  String get saveOriginalPhotosAccessMessage =>
      'Để lưu video, hãy cho phép truy cập Ảnh trong Cài đặt.';

  @override
  String get saveOriginalOpenSettings => 'Mở Cài đặt';

  @override
  String get saveOriginalNotNow => 'Để sau';

  @override
  String get saveOriginalDownloadFailed => 'Tải xuống thất bại';

  @override
  String get saveOriginalDismiss => 'Bỏ qua';

  @override
  String get saveOriginalDownloadingVideo => 'Đang tải video xuống';

  @override
  String get saveOriginalSavingToCameraRoll => 'Đang lưu vào thư viện ảnh';

  @override
  String get saveOriginalFetchingVideo => 'Đang lấy video từ mạng...';

  @override
  String get saveOriginalSavingVideo =>
      'Đang lưu video gốc vào thư viện ảnh của bạn...';

  @override
  String get soundTitle => 'Âm thanh';

  @override
  String get soundOriginalSound => 'Âm thanh gốc';

  @override
  String get soundVideosUsingThisSound => 'Video dùng âm thanh này';

  @override
  String get soundSourceVideo => 'Video nguồn';

  @override
  String get soundNoVideosYet => 'Chưa có video nào';

  @override
  String get soundBeFirstToUse => 'Hãy là người đầu tiên dùng âm thanh này!';

  @override
  String get soundFailedToLoadVideos => 'Không tải được video';

  @override
  String get soundRetry => 'Thử lại';

  @override
  String get soundVideosUnavailable => 'Video không khả dụng';

  @override
  String get soundCouldNotLoadDetails => 'Không tải được chi tiết video';

  @override
  String get soundPreview => 'Nghe thử';

  @override
  String get soundStop => 'Dừng';

  @override
  String get soundUseSound => 'Dùng âm thanh';

  @override
  String get soundUntitled => 'Âm thanh chưa đặt tên';

  @override
  String get soundStopPreview => 'Dừng nghe thử';

  @override
  String soundPreviewSemanticLabel(String title) {
    return 'Nghe thử $title';
  }

  @override
  String soundViewDetailsSemanticLabel(String title) {
    return 'Xem chi tiết của $title';
  }

  @override
  String get soundNoVideoCount => 'Chưa có video nào';

  @override
  String get soundOneVideo => '1 video';

  @override
  String soundVideoCount(int count) {
    return '$count video';
  }

  @override
  String get soundUnableToPreview => 'Không nghe thử được - không có audio';

  @override
  String get soundPreviewFailed =>
      'Không phát được bản nghe thử. Vui lòng thử lại.';

  @override
  String get soundViewSource => 'Xem nguồn';

  @override
  String get soundCloseTooltip => 'Đóng';

  @override
  String get exploreNotExploreRoute => 'Không phải tuyến khám phá';

  @override
  String get legalTitle => 'Pháp lý';

  @override
  String get legalTermsOfService => 'Điều khoản dịch vụ';

  @override
  String get legalTermsOfServiceSubtitle => 'Điều khoản và điều kiện sử dụng';

  @override
  String get legalPrivacyPolicy => 'Chính sách quyền riêng tư';

  @override
  String get legalPrivacyPolicySubtitle =>
      'Cách bọn mình xử lý dữ liệu của bạn';

  @override
  String get legalSafetyStandards => 'Tiêu chuẩn an toàn';

  @override
  String get legalSafetyStandardsSubtitle => 'Hướng dẫn cộng đồng và an toàn';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle => 'Chính sách bản quyền và gỡ nội dung';

  @override
  String get legalOpenSourceLicenses => 'Giấy phép mã nguồn mở';

  @override
  String get legalOpenSourceLicensesSubtitle => 'Ghi nhận gói bên thứ ba';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return 'Không mở được $pageName';
  }

  @override
  String get categoryAction => 'Hành động';

  @override
  String get categoryAdventure => 'Phiêu lưu';

  @override
  String get categoryAnimals => 'Động vật';

  @override
  String get categoryAnimation => 'Hoạt hình';

  @override
  String get categoryArchitecture => 'Kiến trúc';

  @override
  String get categoryArt => 'Nghệ thuật';

  @override
  String get categoryAutomotive => 'Ô tô';

  @override
  String get categoryAwardShow => 'Lễ trao giải';

  @override
  String get categoryAwards => 'Giải thưởng';

  @override
  String get categoryBaseball => 'Bóng chày';

  @override
  String get categoryBasketball => 'Bóng rổ';

  @override
  String get categoryBeauty => 'Làm đẹp';

  @override
  String get categoryBeverage => 'Đồ uống';

  @override
  String get categoryCars => 'Xe hơi';

  @override
  String get categoryCelebration => 'Ăn mừng';

  @override
  String get categoryCelebrities => 'Người nổi tiếng';

  @override
  String get categoryCelebrity => 'Người nổi tiếng';

  @override
  String get categoryCityscape => 'Cảnh đô thị';

  @override
  String get categoryComedy => 'Hài';

  @override
  String get categoryConcert => 'Hòa nhạc';

  @override
  String get categoryCooking => 'Nấu ăn';

  @override
  String get categoryCostume => 'Trang phục';

  @override
  String get categoryCrafts => 'Thủ công';

  @override
  String get categoryCrime => 'Tội phạm';

  @override
  String get categoryCulture => 'Văn hóa';

  @override
  String get categoryDance => 'Khiêu vũ';

  @override
  String get categoryDiy => 'DIY';

  @override
  String get categoryDrama => 'Chính kịch';

  @override
  String get categoryEducation => 'Giáo dục';

  @override
  String get categoryEmotional => 'Cảm xúc';

  @override
  String get categoryEmotions => 'Cảm xúc';

  @override
  String get categoryEntertainment => 'Giải trí';

  @override
  String get categoryEvent => 'Sự kiện';

  @override
  String get categoryFamily => 'Gia đình';

  @override
  String get categoryFans => 'Người hâm mộ';

  @override
  String get categoryFantasy => 'Giả tưởng';

  @override
  String get categoryFashion => 'Thời trang';

  @override
  String get categoryFestival => 'Lễ hội';

  @override
  String get categoryFilm => 'Điện ảnh';

  @override
  String get categoryFitness => 'Thể hình';

  @override
  String get categoryFood => 'Ẩm thực';

  @override
  String get categoryFootball => 'Bóng đá';

  @override
  String get categoryFurniture => 'Nội thất';

  @override
  String get categoryGaming => 'Game';

  @override
  String get categoryGolf => 'Golf';

  @override
  String get categoryGrooming => 'Chải chuốt';

  @override
  String get categoryGuitar => 'Guitar';

  @override
  String get categoryHalloween => 'Halloween';

  @override
  String get categoryHealth => 'Sức khỏe';

  @override
  String get categoryHockey => 'Khúc côn cầu';

  @override
  String get categoryHoliday => 'Ngày lễ';

  @override
  String get categoryHome => 'Nhà cửa';

  @override
  String get categoryHomeImprovement => 'Cải tạo nhà';

  @override
  String get categoryHorror => 'Kinh dị';

  @override
  String get categoryHospital => 'Bệnh viện';

  @override
  String get categoryHumor => 'Hài hước';

  @override
  String get categoryInteriorDesign => 'Thiết kế nội thất';

  @override
  String get categoryInterview => 'Phỏng vấn';

  @override
  String get categoryKids => 'Trẻ em';

  @override
  String get categoryLifestyle => 'Lối sống';

  @override
  String get categoryMagic => 'Ảo thuật';

  @override
  String get categoryMakeup => 'Trang điểm';

  @override
  String get categoryMedical => 'Y khoa';

  @override
  String get categoryMusic => 'Âm nhạc';

  @override
  String get categoryMystery => 'Bí ẩn';

  @override
  String get categoryNature => 'Thiên nhiên';

  @override
  String get categoryNews => 'Tin tức';

  @override
  String get categoryOutdoor => 'Ngoài trời';

  @override
  String get categoryParty => 'Tiệc tùng';

  @override
  String get categoryPeople => 'Con người';

  @override
  String get categoryPerformance => 'Biểu diễn';

  @override
  String get categoryPets => 'Thú cưng';

  @override
  String get categoryPolitics => 'Chính trị';

  @override
  String get categoryPrank => 'Trò chơi khăm';

  @override
  String get categoryPranks => 'Trò chơi khăm';

  @override
  String get categoryRealityShow => 'Truyền hình thực tế';

  @override
  String get categoryRelationship => 'Mối quan hệ';

  @override
  String get categoryRelationships => 'Mối quan hệ';

  @override
  String get categoryRomance => 'Lãng mạn';

  @override
  String get categorySchool => 'Trường học';

  @override
  String get categoryScienceFiction => 'Khoa học viễn tưởng';

  @override
  String get categorySelfie => 'Selfie';

  @override
  String get categoryShopping => 'Mua sắm';

  @override
  String get categorySkateboarding => 'Trượt ván';

  @override
  String get categorySkincare => 'Chăm sóc da';

  @override
  String get categorySoccer => 'Bóng đá';

  @override
  String get categorySocialGathering => 'Tụ họp';

  @override
  String get categorySocialMedia => 'Mạng xã hội';

  @override
  String get categorySports => 'Thể thao';

  @override
  String get categoryTalkShow => 'Talk show';

  @override
  String get categoryTech => 'Công nghệ';

  @override
  String get categoryTechnology => 'Công nghệ';

  @override
  String get categoryTelevision => 'Truyền hình';

  @override
  String get categoryToys => 'Đồ chơi';

  @override
  String get categoryTransportation => 'Giao thông';

  @override
  String get categoryTravel => 'Du lịch';

  @override
  String get categoryUrban => 'Đô thị';

  @override
  String get categoryViolence => 'Bạo lực';

  @override
  String get categoryVlog => 'Vlog';

  @override
  String get categoryVlogging => 'Vlogging';

  @override
  String get categoryWrestling => 'Đấu vật';

  @override
  String get profileSetupUploadStaged => 'Đã tải lên — chạm Lưu để áp dụng';

  @override
  String inboxReportedUser(String displayName) {
    return 'Đã báo cáo $displayName';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return 'Đã chặn $displayName';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return 'Đã bỏ chặn $displayName';
  }

  @override
  String get inboxRemovedConversation => 'Đã xóa cuộc trò chuyện';

  @override
  String get inboxRestorePausedTitle =>
      'Một số cuộc trò chuyện chưa khôi phục xong';

  @override
  String get conversationRestorePausedTitle =>
      'Cuộc trò chuyện này chưa khôi phục xong';

  @override
  String get inboxRestoreRetryAction => 'Thử lại';

  @override
  String get inboxRestoringMessages => 'Đang khôi phục tin nhắn của bạn…';

  @override
  String get inboxEmptyTitle => 'Chưa có tin nhắn nào';

  @override
  String get inboxEmptySubtitle => 'Nút + kia không cắn đâu.';

  @override
  String get inboxLoadErrorTitle => 'Tin nhắn không tải được';

  @override
  String get inboxLoadErrorSubtitle => 'Kiểm tra kết nối rồi thử lại nhé.';

  @override
  String get inboxFilterAll => 'Tất cả';

  @override
  String get inboxFilterUnread => 'Chưa đọc';

  @override
  String get dmBlockedThreadTitle => 'Bạn đã chặn tài khoản này';

  @override
  String get dmBlockedThreadBody =>
      'Tin nhắn vẫn ở đây để bạn có thể đọc hoặc chụp màn hình. Bỏ chặn để trả lời.';

  @override
  String get inboxFilterBlocked => 'Đã chặn';

  @override
  String get inboxBlockedEmptyTitle => 'Không có cuộc trò chuyện bị chặn';

  @override
  String get inboxBlockedEmptySubtitle =>
      'Các tài khoản bạn chặn sẽ xuất hiện ở đây.';

  @override
  String get inboxBlockedNoMessages => 'Không có tin nhắn';

  @override
  String get inboxUnreadEmptyTitle => 'Bạn đã đọc hết rồi';

  @override
  String get inboxUnreadEmptySubtitle => 'Hiện không có tin nhắn chưa đọc.';

  @override
  String get inboxSearchHint => 'Tìm tin nhắn';

  @override
  String get inboxSupportRowTitle => 'Kiểm duyệt Divine';

  @override
  String get inboxSupportRowSubtitle =>
      'Lỗi, kiểm duyệt, chuyện tài khoản — bọn mình đang lắng nghe.';

  @override
  String get inboxSearchEmptyTitle => 'Không có kết quả';

  @override
  String get inboxSearchEmptySubtitle => 'Thử một tên hoặc từ khác nhé.';

  @override
  String get inboxActionMute => 'Tắt thông báo cuộc trò chuyện';

  @override
  String inboxActionReport(String displayName) {
    return 'Báo cáo $displayName';
  }

  @override
  String inboxActionBlock(String displayName) {
    return 'Chặn $displayName';
  }

  @override
  String inboxActionUnblock(String displayName) {
    return 'Bỏ chặn $displayName';
  }

  @override
  String get inboxActionRemove => 'Xóa cuộc trò chuyện';

  @override
  String get inboxRemoveConfirmTitle => 'Xóa cuộc trò chuyện?';

  @override
  String inboxRemoveConfirmBody(String displayName) {
    return 'Thao tác này xóa cuộc trò chuyện của bạn với $displayName khỏi hộp thư đến. Nếu họ nhắn tin cho bạn lần nữa, một cuộc trò chuyện mới sẽ bắt đầu.';
  }

  @override
  String get inboxRemoveConfirmBodyGroup =>
      'Thao tác này xóa cuộc trò chuyện nhóm khỏi hộp thư đến. Nếu có ai nhắn tin vào nhóm lần nữa, một cuộc trò chuyện mới sẽ bắt đầu.';

  @override
  String get inboxRemoveConfirmConfirm => 'Xóa';

  @override
  String get inboxConversationMuted => 'Đã tắt thông báo cuộc trò chuyện';

  @override
  String get inboxConversationUnmuted => 'Đã bật lại thông báo cuộc trò chuyện';

  @override
  String get inboxCollabInviteCardTitle => 'Lời mời cộng tác';

  @override
  String get inboxCollabInviteCardUntitledVideo => 'Video chưa đặt tên';

  @override
  String get clickableTextViewVideoLink => 'Xem video';

  @override
  String get messageExternalLinkDialogTitle => 'Mở liên kết ngoài?';

  @override
  String messageExternalLinkDialogBody(String url) {
    return 'Liên kết này dẫn tới một trang bên ngoài và có thể không an toàn:\n\n$url';
  }

  @override
  String get messageExternalLinkDialogOpen => 'Mở';

  @override
  String get inboxCollabInviteCoPostButton => 'Đăng chung';

  @override
  String get inboxCollabInviteNotMineButton => 'Không phải của tôi';

  @override
  String get inboxCollabInvitePreviewTitle => 'Lời mời đăng chung';

  @override
  String inboxCollabInvitePreviewTitleFrom(String displayName) {
    return 'Lời mời đăng chung từ $displayName';
  }

  @override
  String get inboxCollabInviteTimelineConsequence =>
      'Đăng chung sẽ thêm video này vào dòng thời gian của bạn như một video cộng tác.';

  @override
  String get inboxCollabInviteAcceptedStatus => 'Đã chấp nhận';

  @override
  String get inboxCollabInviteIgnoredStatus => 'Đã bỏ qua';

  @override
  String get inboxCollabInviteAcceptError =>
      'Không chấp nhận được. Thử lại nhé.';

  @override
  String get inboxCollabInviteSentStatus => 'Đã gửi lời mời';

  @override
  String get inboxConversationCollabInvitePreview => 'Lời mời cộng tác';

  @override
  String collaboratorInviteDmBody(String title, String url) {
    return 'Bạn được mời cộng tác vào $title: $url\n\nOpen Divine to review and accept.';
  }

  @override
  String collaboratorInviteDmBodyUntitled(String url) {
    return 'Bạn được mời cộng tác vào một video: $url\n\nOpen Divine to review and accept.';
  }

  @override
  String videoPublishCollaboratorInviteWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lời mời cộng tác không gửi được.',
      one: '1 lời mời cộng tác không gửi được.',
    );
    return 'Đã đăng video, nhưng $_temp0';
  }

  @override
  String get dmSendNoRecipientMessage =>
      'Không xác định được cuộc trò chuyện này với ai. Hãy mở lại từ hộp thư đến.';

  @override
  String get dmSendBlockedMessage =>
      'Bạn chỉ có thể nhắn tin cho các tài khoản Divine chính thức';

  @override
  String get dmSendBlockedRetiredMessage =>
      'Không ai đọc cuộc trò chuyện này. Hãy nhắn cho Divine Moderation.';

  @override
  String get dmDeletePendingLabel => 'Deleting for everyone';

  @override
  String get dmDeleteRefusedMessage => 'Không xóa được với mọi người.';

  @override
  String get dmDeleteRefusedDetails =>
      'Một số người vẫn có thể nhìn thấy tin nhắn này.';

  @override
  String get dmRetiredThreadClosedTitle => 'Cuộc trò chuyện này đã đóng.';

  @override
  String get messageRequestModerationNoticeCannotBeRemoved =>
      'Không thể xóa thông báo Divine Moderation này.';

  @override
  String get dmRetiredThreadClosedBody =>
      'Chúng tôi đã chuyển Divine Moderation sang một tài khoản mới. Không còn ai đọc tài khoản này nữa.';

  @override
  String get dmRetiredThreadOpenSupport => 'Nhắn tin cho Divine Moderation';

  @override
  String get dmSendTooLongMessage =>
      'That message is too long to send. Shorten it and try again.';

  @override
  String get dmSendFailedMessage => 'Tin nhắn không gửi được';

  @override
  String get dmResendFailedMessage => 'Vẫn không gửi được';

  @override
  String get dmSendFailedSubtitle => 'Gửi lại ngay, hoặc ngừng thử.';

  @override
  String get dmSendFailedRetry => 'Thử lại';

  @override
  String get dmSendPartialMessage =>
      'Đã gửi, nhưng chưa đồng bộ sang các thiết bị khác của bạn';

  @override
  String get dmConversationLoadError => 'Không tải được tin nhắn';

  @override
  String get dmMessageInputHint => 'Nói gì đó đi…';

  @override
  String get dmMessageBubbleSentHint => 'Tin nhắn đã gửi';

  @override
  String get dmMessageBubbleReceivedHint => 'Tin nhắn đã nhận';

  @override
  String get dmMessageBubbleLongPressHint => 'Thao tác với tin nhắn';

  @override
  String get dmMessageBubbleFailedTapHint => 'Gửi lại hoặc xóa tin nhắn này';

  @override
  String get dmMessageActionCopyText => 'Sao chép văn bản';

  @override
  String get dmMessageActionCopyVideoUrl => 'Sao chép URL video';

  @override
  String get dmMessageActionDeleteForEveryone => 'Xóa cho mọi người';

  @override
  String get dmMessageActionReport => 'Báo cáo';

  @override
  String get dmMessageActionRetrySend => 'Gửi lại';

  @override
  String get dmMessageActionCancelSend => 'Ngừng thử';

  @override
  String get dmReactionAddCustomA11yLabel => 'Thêm cảm xúc tùy chỉnh';

  @override
  String dmReelReplyComposerHint(String name) {
    return 'Nhắn cho $name…';
  }

  @override
  String get dmReelReplyComposerHintSelf => 'Trả lời chính mình…';

  @override
  String get dmReelReplyComposerSemanticLabel => 'Trả lời reel này';

  @override
  String get dmReelReplyViewChat => 'Xem trò chuyện';

  @override
  String get dmReelReplySentAnnouncement => 'Đã gửi câu trả lời';

  @override
  String dmReelReactionSentAnnouncement(String emoji) {
    return 'Đã thả cảm xúc $emoji';
  }

  @override
  String get dmReelReplyFailed => 'Không gửi được';

  @override
  String get dmReelReplyUnverified => 'Không xác nhận được đã gửi';

  @override
  String dmReactionChipOwnA11yLabel(String emoji) {
    return 'Cảm xúc của bạn: $emoji';
  }

  @override
  String dmReactionChipOtherA11yLabel(String name, String emoji) {
    return '$name đã thả cảm xúc $emoji';
  }

  @override
  String dmReactionChipPendingA11yLabel(String emoji) {
    return 'Đang gửi cảm xúc: $emoji';
  }

  @override
  String get dmReactionChipFailedA11yLabel =>
      'Cảm xúc thất bại, chạm hai lần để thử lại';

  @override
  String get dmReactionChipRetryAnnouncement => 'Đang thử lại cảm xúc';

  @override
  String dmReactionRemovalRefusedA11yLabel(String emoji) {
    return 'Couldn\'t remove your $emoji reaction. Double tap to try again';
  }

  @override
  String get dmReactionRemovalRefusedTitle => 'Couldn\'t remove your reaction.';

  @override
  String get dmReactionAddBlockedByRemoval =>
      'Hãy hoàn tất việc xóa cảm xúc trước đó trước khi thêm cảm xúc khác.';

  @override
  String get dmReactionRemovalRefusedDetails =>
      'Some people may still be able to see this reaction.';

  @override
  String get dmReactionsSheetTitle => 'Cảm xúc';

  @override
  String get dmReactionsViewA11yLabel => 'Xem ai đã thả cảm xúc';

  @override
  String get dmReactionRemoveAction => 'Xóa';

  @override
  String get dmReactionRetryAction => 'Thử lại';

  @override
  String get dmFormatBold => 'Đậm';

  @override
  String get dmFormatItalic => 'Nghiêng';

  @override
  String get dmFormatStrikethrough => 'Gạch ngang';

  @override
  String get dmFormatCode => 'Mã';

  @override
  String get dmStatusFailed => 'Gửi thất bại';

  @override
  String get inboxConversationActionsSheetLabel =>
      'Thao tác với cuộc trò chuyện';

  @override
  String inboxConversationTileLabel(String displayName) {
    return 'Cuộc trò chuyện với $displayName';
  }

  @override
  String inboxConversationTileLabelUnread(String displayName) {
    return 'Chưa đọc, cuộc trò chuyện với $displayName';
  }

  @override
  String inboxGroupConversationTitle(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count người khác',
    );
    return '$name và $_temp0';
  }

  @override
  String get inboxConversationTileLongPressHint =>
      'Hiện thao tác với cuộc trò chuyện';

  @override
  String exploreVideoId(String id) {
    return 'ID: $id';
  }

  @override
  String exploreVideoTitle(String title) {
    return 'Tiêu đề: $title';
  }

  @override
  String exploreVideoCounter(int current, int total) {
    return 'Video $current/$total';
  }

  @override
  String get exploreSearchHint => 'Tìm kiếm...';

  @override
  String categoryVideoCount(int countValue, String count) {
    return '$count video';
  }

  @override
  String get discoverListsFailedToUpdateSubscription =>
      'Không cập nhật được đăng ký. Vui lòng thử lại.';

  @override
  String get discoverListsTitle => 'Khám phá danh sách';

  @override
  String get discoverListsFailedToLoad => 'Không tải được danh sách';

  @override
  String get discoverListsLoading => 'Đang khám phá danh sách công khai...';

  @override
  String get discoverListsRelayTimeout =>
      'Relay không trả về danh sách kịp lúc. Thử lại nhé.';

  @override
  String get discoverListsServiceUnavailable => 'Dịch vụ không khả dụng.';

  @override
  String get discoverListsEmptyTitle =>
      'Không tìm thấy danh sách công khai nào';

  @override
  String get discoverListsEmptySubtitle =>
      'Quay lại sau để xem danh sách mới nhé';

  @override
  String get discoverListsByAuthorPrefix => 'bởi';

  @override
  String get curatedListEmptyTitle => 'Chưa có video nào trong danh sách này';

  @override
  String get curatedListEmptySubtitle => 'Thêm vài video để bắt đầu';

  @override
  String get curatedListLoadingVideos => 'Đang tải video...';

  @override
  String get curatedListFailedToLoad => 'Không tải được danh sách';

  @override
  String get curatedListVideoNotAvailable => 'Video không khả dụng';

  @override
  String get curatedListActionsTooltip => 'Thao tác với danh sách';

  @override
  String get curatedListDeleteConfirmTitle => 'Xóa danh sách?';

  @override
  String get curatedListDeleteConfirmBody =>
      'Thao tác này xóa danh sách khỏi các relay. Video trong danh sách sẽ không bị xóa.';

  @override
  String get curatedListDeletedSnack => 'Đã xóa danh sách';

  @override
  String get curatedListDeleteFailed => 'Không xóa được danh sách';

  @override
  String get peopleListsActionsTooltip => 'Thao tác với danh sách';

  @override
  String get listDeleteAction => 'Xóa danh sách';

  @override
  String get peopleListsDeleteConfirmTitle => 'Xóa danh sách?';

  @override
  String get peopleListsDeleteConfirmBody =>
      'Thao tác này xóa danh sách cho tất cả mọi người. Những người trong danh sách sẽ không bị bỏ theo dõi.';

  @override
  String get peopleListsDeleteFailed => 'Không xóa được danh sách';

  @override
  String get commonRetry => 'Thử lại';

  @override
  String get commonSomethingWentWrong => 'Có gì đó không ổn';

  @override
  String get commonDelete => 'Xóa';

  @override
  String get commonCancel => 'Hủy';

  @override
  String get commonBack => 'Quay lại';

  @override
  String get commonClose => 'Đóng';

  @override
  String get commonNotNow => 'Để sau';

  @override
  String get commonLoading => 'Đang tải';

  @override
  String get videoMetadataEditCoverFailedSnackbar =>
      'Không cập nhật được ảnh bìa. Thử lại nhé.';

  @override
  String get videoMetadataEditCoverSuccessAnnouncement => 'Đã cập nhật ảnh bìa';

  @override
  String get videoMetadataC2paMissingTitle =>
      'Đăng mà không có xác nhận do người làm?';

  @override
  String get videoMetadataC2paMissingBody =>
      'Bọn mình không thêm được chứng nhận nội dung, nên video này sẽ không được xác nhận là Do người làm. Tạo lại để thử lần nữa, hoặc đăng nguyên trạng.';

  @override
  String get videoMetadataC2paMissingNote =>
      'Chứng nhận nội dung cần kết nối internet.';

  @override
  String get videoMetadataC2paMissingNoteServiceUnavailable =>
      'Dịch vụ chứng nhận nội dung không phản hồi. Đây không phải lỗi kết nối của bạn.';

  @override
  String get videoMetadataC2paMissingRegenerate => 'Tạo lại';

  @override
  String get videoMetadataC2paMissingSkip => 'Bỏ qua';

  @override
  String get videoMetadataGenerationFailed => 'Tạo thất bại';

  @override
  String get videoMetadataTags => 'Thẻ';

  @override
  String get videoMetadataExpiration => 'Hết hạn';

  @override
  String get videoMetadataExpirationNotExpire => 'Không hết hạn';

  @override
  String get videoMetadataExpirationOneDay => '1 ngày';

  @override
  String get videoMetadataExpirationOneWeek => '1 tuần';

  @override
  String get videoMetadataExpirationOneMonth => '1 tháng';

  @override
  String get videoMetadataExpirationOneYear => '1 năm';

  @override
  String get videoMetadataExpirationOneDecade => '1 thập kỷ';

  @override
  String get videoMetadataContentWarnings => 'Cảnh báo nội dung';

  @override
  String get videoEditorStickers => 'Nhãn dán';

  @override
  String get trendingTitle => 'Thịnh hành';

  @override
  String get libraryDeleteConfirm => 'Xóa';

  @override
  String get libraryWebUnavailableHeadline =>
      'Thư viện có trong ứng dụng di động';

  @override
  String get libraryWebUnavailableDescription =>
      'Bản nháp và clip được lưu trên thiết bị của bạn, nên hãy mở Divine trên điện thoại để quản lý chúng.';

  @override
  String get libraryTabDrafts => 'Bản nháp';

  @override
  String get libraryTabClips => 'Clip';

  @override
  String get libraryDeleteSelectedClipsTooltip => 'Xóa clip đã chọn';

  @override
  String get libraryCloseSemanticLabel => 'Đóng thư viện';

  @override
  String get libraryStopSelectingClipsSemanticLabel => 'Dừng chọn clip';

  @override
  String get librarySelectClipsSemanticLabel => 'Chọn clip';

  @override
  String get libraryGridSizeLabel => 'Kích thước lưới';

  @override
  String get libraryDisplayOptionsLabel => 'Sắp xếp và cỡ lưới';

  @override
  String get libraryMoreActionsSemanticLabel => 'Thao tác thư viện khác';

  @override
  String libraryGridSizeColumns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cột',
    );
    return '$_temp0';
  }

  @override
  String get librarySelect => 'Chọn';

  @override
  String get librarySortNewestCreation => 'Mới tạo nhất';

  @override
  String get librarySortOldestCreation => 'Cũ nhất';

  @override
  String get librarySortLongestClip => 'Clip dài nhất';

  @override
  String get librarySortShortestClip => 'Clip ngắn nhất';

  @override
  String get librarySortSquareFirst => 'Vuông trước';

  @override
  String get librarySortVerticalFirst => 'Dọc trước';

  @override
  String get libraryDeleteClipsWarning =>
      'Không thể hoàn tác thao tác này. Các tệp video sẽ bị xóa vĩnh viễn khỏi thiết bị của bạn.';

  @override
  String get libraryPreparingVideo => 'Đang chuẩn bị video...';

  @override
  String libraryCreateVideo(int count) {
    return 'Tạo video ($count)';
  }

  @override
  String libraryClipsSavedToDestination(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clip',
      one: '1 clip',
    );
    return 'Đã lưu $_temp0 vào $destination';
  }

  @override
  String libraryClipsSavePartialResult(int successCount, int failureCount) {
    return 'Đã lưu $successCount, thất bại $failureCount';
  }

  @override
  String libraryClipsSaveFailed(String destination) {
    return 'Không lưu được vào $destination';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return 'Quyền truy cập $destination bị từ chối';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Đã xóa $count clip',
      one: 'Đã xóa 1 clip',
    );
    return '$_temp0';
  }

  @override
  String get libraryClipsDeletedUndoLabel => 'Hoàn tác';

  @override
  String libraryTrashAutoDeletes(int daysLeft) {
    String _temp0 = intl.Intl.pluralLogic(
      daysLeft,
      locale: localeName,
      other: 'Tự động xóa sau $daysLeft ngày',
      one: 'Tự động xóa ngày mai',
      zero: 'Tự động xóa hôm nay',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts => 'Không tải được bản nháp';

  @override
  String get libraryCouldNotLoadClips => 'Không tải được clip';

  @override
  String get libraryOpenErrorDescription =>
      'Có gì đó không ổn khi mở thư viện của bạn. Bạn có thể thử lại.';

  @override
  String get libraryNoDraftsYetTitle => 'Chưa có bản nháp nào';

  @override
  String get libraryNoDraftsYetSubtitle =>
      'Video bạn lưu nháp sẽ xuất hiện ở đây';

  @override
  String get libraryNoClipsYetTitle => 'Chưa có clip nào';

  @override
  String get libraryNoClipsYetSubtitle =>
      'Các clip video bạn quay sẽ xuất hiện ở đây';

  @override
  String get libraryDraftDeletedSnackbar => 'Đã xóa bản nháp';

  @override
  String get libraryDraftDeleteFailedSnackbar => 'Không xóa được bản nháp';

  @override
  String get libraryDraftDuplicatedSnackbar => 'Đã nhân bản bản nháp';

  @override
  String get libraryDraftDuplicateFailedSnackbar =>
      'Không nhân bản được bản nháp';

  @override
  String get libraryDraftInProgressBadge => 'Đang thực hiện';

  @override
  String get libraryDraftActionPost => 'Đăng';

  @override
  String get libraryDraftActionEdit => 'Sửa';

  @override
  String get libraryDraftActionDuplicate => 'Nhân bản';

  @override
  String get libraryDraftActionDelete => 'Xóa bản nháp';

  @override
  String libraryDraftCopyTitle(String title, int number) {
    return '$title (bản sao $number)';
  }

  @override
  String get libraryDeleteDraftTitle => 'Xóa bản nháp';

  @override
  String libraryDeleteDraftMessage(String title) {
    return 'Bạn có chắc muốn xóa \"$title\" không?';
  }

  @override
  String get libraryDeleteClipTitle => 'Xóa clip';

  @override
  String get libraryDeleteClipMessage => 'Bạn có chắc muốn xóa clip này không?';

  @override
  String libraryClipDuration(String seconds) {
    return '$seconds giây';
  }

  @override
  String get libraryRecordVideo => 'Quay video';

  @override
  String videoClipSemanticLabel(String duration) {
    return 'Clip video, $duration giây';
  }

  @override
  String videoClipArchivedSemanticLabel(String label) {
    return 'Đã lưu trữ. $label';
  }

  @override
  String videoClipStopMotionSemanticLabel(String frames) {
    return 'Đoạn stop-motion, $frames';
  }

  @override
  String videoClipSemanticValueSelectedAtPosition(int position) {
    return 'Đã chọn, số $position';
  }

  @override
  String get videoClipSemanticValueSelected => 'Đã chọn';

  @override
  String get videoClipSemanticValueNotSelected => 'Chưa chọn';

  @override
  String get videoClipSemanticHintDisabled => 'Đã tắt';

  @override
  String get videoClipSemanticHintSelect => 'Chạm để chọn, nhấn giữ để xem thử';

  @override
  String get videoClipSemanticHintDeselect =>
      'Chạm để bỏ chọn, nhấn giữ để xem thử';

  @override
  String get routerInvalidCreator => 'Nhà sáng tạo không hợp lệ';

  @override
  String get routerInvalidHashtagRoute => 'Tuyến hashtag không hợp lệ';

  @override
  String get categoryGalleryCouldNotLoadVideos => 'Không tải được video';

  @override
  String get categoryGalleryNoVideosInCategory =>
      'Không có video nào trong danh mục này';

  @override
  String get categoryGallerySortOptionsLabel => 'Tùy chọn sắp xếp danh mục';

  @override
  String get categoryGallerySortHot => 'Nổi bật';

  @override
  String get categoryGallerySortNew => 'Mới';

  @override
  String get categoryGallerySortClassic => 'Kinh điển';

  @override
  String get categoryGallerySortForYou => 'Dành cho bạn';

  @override
  String get categoriesCouldNotLoadCategories => 'Không tải được danh mục';

  @override
  String get categoriesNoCategoriesAvailable => 'Không có danh mục nào';

  @override
  String get notificationsEmptyTitle => 'Chưa có hoạt động nào';

  @override
  String get notificationsEmptySubtitle =>
      'Khi mọi người tương tác với nội dung của bạn, bạn sẽ thấy ở đây';

  @override
  String get appsPermissionsTitle => 'Quyền tích hợp';

  @override
  String get appsPermissionsRevoke => 'Thu hồi';

  @override
  String get appsPermissionsEmptyTitle => 'Chưa có quyền tích hợp nào được lưu';

  @override
  String get appsPermissionsEmptySubtitle =>
      'Các tích hợp đã duyệt sẽ xuất hiện ở đây sau khi bạn lưu một phê duyệt truy cập.';

  @override
  String nostrAppPermissionTitle(String appName) {
    return '$appName muốn xin phê duyệt của bạn';
  }

  @override
  String get nostrAppPermissionDescription =>
      'Ứng dụng này đang yêu cầu quyền truy cập qua sandbox đã kiểm duyệt của Divine.';

  @override
  String get nostrAppPermissionOrigin => 'Nguồn gốc';

  @override
  String get nostrAppPermissionMethod => 'Phương thức';

  @override
  String get nostrAppPermissionCapability => 'Quyền năng';

  @override
  String get nostrAppPermissionEventKind => 'Loại sự kiện';

  @override
  String get nostrAppPermissionAllow => 'Cho phép';

  @override
  String get appsDetailDefaultTitle => 'Ứng dụng tích hợp';

  @override
  String get appsDetailNotFoundTitle => 'Không tìm thấy tích hợp';

  @override
  String get appsDetailNotFoundSubtitle =>
      'Tích hợp đã duyệt này không còn khả dụng trong Divine.';

  @override
  String get appsDetailHowItWorksTitle => 'Cách hoạt động';

  @override
  String get appsDetailHowItWorksBody =>
      'Đây là ứng dụng bên thứ ba đã duyệt chạy bên trong Divine. Divine chỉ cấp các quyền năng đã xem xét cho tích hợp này, và chặn điều hướng ra ngoài các nguồn gốc đã duyệt.';

  @override
  String get appsDetailAboutTitle => 'Giới thiệu';

  @override
  String get appsDetailPrimaryOriginTitle => 'Nguồn gốc chính';

  @override
  String get appsDetailApprovedOriginsTitle => 'Nguồn gốc đã duyệt';

  @override
  String get appsDetailCapabilitiesTitle => 'Quyền năng khả dụng';

  @override
  String get appsDetailAskBeforeTitle => 'Hỏi trước khi';

  @override
  String get appsDetailOpenButton => 'Mở tích hợp';

  @override
  String get appsDetailNoneDeclared => 'Chưa khai báo gì';

  @override
  String get appsDirectoryTitle => 'Ứng dụng tích hợp';

  @override
  String get appsDirectoryIntroTitle => 'Ứng dụng bên thứ ba đã duyệt';

  @override
  String get appsDirectoryIntroBody =>
      'Các ứng dụng bên thứ ba đã duyệt chạy bên trong Divine';

  @override
  String get appsDirectoryErrorTitle => 'Không tải được ứng dụng tích hợp';

  @override
  String get appsDirectoryErrorSubtitle =>
      'Kéo để thử lại các tích hợp đã duyệt.';

  @override
  String get appsDirectoryEmptyTitle => 'Chưa có tích hợp đã duyệt nào';

  @override
  String get appsDirectoryEmptySubtitle =>
      'Các ứng dụng bên thứ ba đã duyệt sẽ xuất hiện ở đây khi Divine bổ sung.';

  @override
  String get appsDirectoryRefresh => 'Làm mới';

  @override
  String get appsDirectoryUnsupportedTitle =>
      'Ứng dụng tích hợp chạy trong Divine mobile';

  @override
  String get appsDirectoryUnsupportedSubtitle =>
      'Các tích hợp đã duyệt hiện chỉ có trên di động.';

  @override
  String get appsSandboxUnavailableTitle => 'Tích hợp không khả dụng';

  @override
  String get appsSandboxUnavailableBody =>
      'Hãy mở các tích hợp đã duyệt từ tab Ứng dụng tích hợp để Divine áp dụng đúng chính sách truy cập.';

  @override
  String get appsSandboxLoadingTitle => 'Đang tải tích hợp';

  @override
  String get appsSandboxLoadingSubtitle =>
      'Đang kiểm tra tích hợp đã duyệt trước khi khởi chạy.';

  @override
  String get appsSandboxBlockedTitle => 'Đã chặn vì an toàn';

  @override
  String appsSandboxBlockedSubtitle(String uri) {
    return 'Tích hợp này đã cố rời khỏi nguồn gốc đã duyệt của nó.\n\n$uri';
  }

  @override
  String get shareCopiedPostLink =>
      'Đã sao chép liên kết bài đăng vào khay nhớ tạm';

  @override
  String get shareCopiedEventJson =>
      'Đã sao chép JSON sự kiện Nostr vào khay nhớ tạm';

  @override
  String get shareCopiedEventId =>
      'Đã sao chép ID sự kiện Nostr vào khay nhớ tạm';

  @override
  String get authHeroTaglineAuthentic => 'Khoảnh khắc chân thật.';

  @override
  String get authHeroTaglineHuman => 'Sáng tạo của con người.';

  @override
  String get keyImportFailedToImport =>
      'Không nhập được khóa hoặc không kết nối được bunker';

  @override
  String get keyImportInvalidBunkerUrl => 'URL bunker không hợp lệ';

  @override
  String get keyImportInvalidFormat =>
      'Định dạng không hợp lệ. Dùng nsec..., hex, ncryptsec1..., hoặc bunker://...';

  @override
  String get keyImportInvalidNsecFormat =>
      'Định dạng nsec không hợp lệ. Phải dài 63 ký tự';

  @override
  String get keyImportKeyFieldLabel => 'Khóa riêng tư hoặc URL bunker';

  @override
  String get keyImportKeyRequired =>
      'Vui lòng nhập khóa riêng tư hoặc URL bunker của bạn';

  @override
  String get keyImportPasswordRequired =>
      'Vui lòng nhập mật khẩu cho khóa đã mã hóa này';

  @override
  String get keyImportSecurityWarningBody =>
      'Đừng bao giờ chia sẻ khóa riêng tư với bất kỳ ai. Khóa này cho quyền truy cập toàn bộ danh tính Nostr của bạn.';

  @override
  String get keyImportSecurityWarningTitle =>
      'Giữ an toàn cho khóa riêng tư của bạn!';

  @override
  String get keyImportSubtitle =>
      'Nhập danh tính Nostr hiện có của bạn bằng khóa riêng tư hoặc URL bunker.';

  @override
  String get keyImportTitle => 'Nhập danh tính\nNostr của bạn';

  @override
  String get commentAuthorYouIndicator => 'Bạn';

  @override
  String commentAuthorAvatarSemanticLabel(String name) {
    return 'Xem hồ sơ của $name';
  }

  @override
  String get commentOptionsDeleteSemanticLabel => 'Xóa bình luận';

  @override
  String get commentOptionsEditSemanticLabel => 'Sửa bình luận';

  @override
  String get commentOptionsFlagContentLabel => 'Gắn cờ nội dung';

  @override
  String get commentOptionsFlagContentSemanticLabel => 'Gắn cờ nội dung này';

  @override
  String get commentOptionsFlagReasonPrompt =>
      'Chọn lý do gắn cờ bình luận này';

  @override
  String get commentOptionsFlagSubmit => 'Gửi';

  @override
  String get commentOptionsTitle => 'Tùy chọn';

  @override
  String get commentsEmptyClassicVineMessage =>
      'Bọn mình vẫn đang nhập các bình luận cũ từ kho lưu trữ. Chưa xong đâu.';

  @override
  String get commentsEmptyClassicVineTitle => 'Vine kinh điển';

  @override
  String get commentsInputEditingLabel => 'Đang sửa';

  @override
  String get commentsInputSemanticHint => 'Thêm bình luận';

  @override
  String get commentsInputSemanticHintEdit => 'Sửa bình luận';

  @override
  String get commentsInputSemanticHintReply => 'Thêm câu trả lời';

  @override
  String get commentsInputSemanticLabel => 'Ô nhập bình luận';

  @override
  String get commentsInputSemanticLabelEdit => 'Ô nhập chỉnh sửa';

  @override
  String get commentsInputSemanticLabelReply => 'Ô nhập trả lời';

  @override
  String classicVinersViewProfileSemanticLabel(String displayName) {
    return 'Xem hồ sơ của $displayName';
  }

  @override
  String get classicsEmptyDescription => 'Kho lưu trữ Kinh điển đang được tải';

  @override
  String get classicsEmptyTitle => 'Không tìm thấy Kinh điển nào';

  @override
  String get classicsErrorTitle => 'Không tải được Kinh điển';

  @override
  String get classicsUnavailableDescription =>
      'Kinh điển chỉ khả dụng khi kết nối với relay Funnelcake.';

  @override
  String get classicsUnavailableSettingsHint =>
      'Chuyển sang relay hỗ trợ Funnelcake trong Cài đặt để truy cập kho lưu trữ Kinh điển.';

  @override
  String get classicsUnavailableTitle => 'Kinh điển không khả dụng';

  @override
  String get hashtagFeedEmptySubtitle =>
      'Hãy là người đầu tiên đăng video với hashtag này!';

  @override
  String hashtagFeedEmptyTitle(String hashtag) {
    return 'Không tìm thấy video nào cho #$hashtag';
  }

  @override
  String get hashtagFeedLoadingSubtitle => 'Có thể mất vài giây';

  @override
  String hashtagFeedLoadingTitle(String hashtag) {
    return 'Đang tải video về #$hashtag...';
  }

  @override
  String get hashtagInputHint => 'Thêm hashtag... #vine #nostr';

  @override
  String get newVideosTabEmptySubtitle =>
      'Quay lại sau để xem nội dung mới nhé';

  @override
  String get newVideosTabEmptyTitle => 'Chưa có video trong Video mới';

  @override
  String get popularVideosContextTitle => 'Video phổ biến';

  @override
  String get popularVideosEmptySubtitle =>
      'Quay lại sau để xem nội dung mới nhé';

  @override
  String get popularVideosEmptyTitle => 'Chưa có video trong Video phổ biến';

  @override
  String get popularVideosErrorTitle => 'Không tải được video thịnh hành';

  @override
  String get popularVideosFeedSourceLabel => 'Nguồn bảng tin phổ biến';

  @override
  String get trendingHashtagsLoading => 'Đang tải hashtag...';

  @override
  String trendingHashtagsViewVideosTagged(String hashtag) {
    return 'Xem video gắn thẻ $hashtag';
  }

  @override
  String videoGridAuthorSemanticLabel(String name) {
    return 'Tác giả video: $name';
  }

  @override
  String videoGridDescriptionSemanticLabel(String description) {
    return 'Mô tả video: $description';
  }

  @override
  String get forYouAlgorithmChoiceBody =>
      'Tầm nhìn của Divine là cho bạn quyền chọn thuật toán thật sự. Thay vì bị khóa vào một thuật toán hộp đen duy nhất, bạn sẽ có thể chọn giữa nhiều cách gợi ý:';

  @override
  String get forYouAlgorithmChoiceChronological =>
      'Dòng thời gian theo thứ tự thời gian từ những nhà sáng tạo bạn theo dõi';

  @override
  String get forYouAlgorithmChoiceClosing =>
      'Điều này trao cho bạn quyền kiểm soát sự chú ý của chính mình thay vì để nền tảng quyết định. Bạn xứng đáng biết bảng tin của mình được tuyển chọn thế nào và có quyền thay đổi nó bất cứ lúc nào.';

  @override
  String get forYouAlgorithmChoiceCustomFeeds =>
      'Bảng tin tùy chỉnh do cộng đồng tạo cho các chủ đề như nhạc, hài, hoặc nghệ thuật';

  @override
  String get forYouAlgorithmChoicePersonalizedFeed =>
      'Bảng tin \"Dành cho bạn\" được cá nhân hóa';

  @override
  String get forYouAlgorithmChoiceTitle =>
      'Thuật toán của bạn, lựa chọn của bạn';

  @override
  String get forYouAlgorithmChoiceTrending => 'Nội dung thịnh hành và phổ biến';

  @override
  String get forYouAlgorithmCommentsDescription =>
      'Tín hiệu mạnh — bạn đã đủ hứng thú để phản hồi';

  @override
  String get forYouAlgorithmHowItWorksBody =>
      'Divine để ý cách bạn tương tác với nội dung để hiểu bạn thích gì. Mỗi lần bạn xem video, thả cảm xúc, bình luận hay đăng lại, hệ thống đều ghi nhận.';

  @override
  String get forYouAlgorithmHowItWorksTitle => 'Cách hoạt động';

  @override
  String get forYouAlgorithmInteractionsIntro =>
      'Mỗi hành động thể hiện mức độ hứng thú khác nhau:';

  @override
  String get forYouAlgorithmNewToDivineBody1 =>
      'Nếu bạn chưa có lịch sử xem, bọn mình sẽ hiện hỗn hợp gồm nội dung đang phổ biến, thịnh hành và các video mới đăng. Đây là điểm khởi đầu tốt để khám phá.';

  @override
  String get forYouAlgorithmNewToDivineBody2 =>
      'Khi bạn xem, thích và tương tác với nội dung, gợi ý sẽ dần cá nhân hóa hơn. Theo thời gian, bảng tin Dành cho bạn sẽ đưa lên video từ những nhà sáng tạo mà có lẽ bạn không bao giờ tự tìm ra.';

  @override
  String get forYouAlgorithmNewToDivineTitle => 'Mới dùng Divine?';

  @override
  String get forYouAlgorithmOpenSourceBody =>
      'Bọn mình đang xây dựng một hệ thống mở nơi nhà phát triển có thể tự viết thuật toán của họ, và bạn có thể chọn dùng cái nào — hoặc không dùng gì cả.';

  @override
  String get forYouAlgorithmOpenSourceTitle => 'Mã nguồn mở & Minh bạch';

  @override
  String get forYouAlgorithmReactionsDescription =>
      'Tín hiệu vừa — cách nhanh để bày tỏ sự yêu thích';

  @override
  String get forYouAlgorithmReactionsTitle => 'Cảm xúc';

  @override
  String get forYouAlgorithmRepostsDescription =>
      'Tín hiệu mạnh nhất — chia sẻ với người theo dõi bạn là một lời tán thưởng lớn';

  @override
  String get forYouAlgorithmSubtitle =>
      'Chạy bằng Gorse, một công cụ gợi ý mã nguồn mở';

  @override
  String get forYouAlgorithmTitle => 'Thuật toán Divine';

  @override
  String get forYouAlgorithmViewsDescription =>
      'Tín hiệu nhẹ — cho thấy sự quan tâm cơ bản';

  @override
  String get forYouEmptyDescription =>
      'Xem và thích vài video để nhận gợi ý cá nhân hóa.';

  @override
  String get forYouEmptyTitle => 'Chưa có gợi ý nào';

  @override
  String get forYouErrorTitle => 'Không tải được gợi ý';

  @override
  String get forYouUnavailableDescription =>
      'Gợi ý cá nhân hóa cần kết nối với Funnelcake.';

  @override
  String get forYouUnavailableTitle => 'Dành cho bạn không khả dụng';

  @override
  String get inboxConversationOptionsLabel => 'Tùy chọn';

  @override
  String get inboxConversationViewProfileButton => 'Xem hồ sơ';

  @override
  String get inboxMessageRequestsEmpty => 'Không có yêu cầu nhắn tin nào';

  @override
  String inboxMessageRequestsSemanticLabel(int requestCount) {
    return 'Yêu cầu nhắn tin, $requestCount đang chờ';
  }

  @override
  String get inboxMessageRequestsTitle => 'Yêu cầu nhắn tin';

  @override
  String get inboxMessagesTab => 'Tin nhắn';

  @override
  String inboxRequestTileLabel(String displayName) {
    return 'Yêu cầu nhắn tin từ $displayName';
  }

  @override
  String get inboxRequestTileSubtitle => 'Đã gửi yêu cầu nhắn tin';

  @override
  String get inboxRequestsMarkAllRead => 'Đánh dấu tất cả yêu cầu là đã đọc';

  @override
  String get inboxRequestsRemoveAll => 'Xóa tất cả yêu cầu';

  @override
  String get messageRequestDeclineAndRemoveButton => 'Từ chối và xóa';

  @override
  String messageRequestDeclinedSnackbar(String displayName) {
    return 'Đã từ chối yêu cầu của $displayName';
  }

  @override
  String get messageRequestLoadFailed => 'Không tải được yêu cầu này.';

  @override
  String messageRequestFollowersCount(int countValue, String count) {
    return '$count người theo dõi';
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
      other: '$count tin nhắn',
      one: '1 tin nhắn',
    );
    return '$_temp0';
  }

  @override
  String get messageRequestViewMessagesButton => 'Xem tin nhắn';

  @override
  String get messageRequestViewProfileButton => 'Xem hồ sơ';

  @override
  String messageRequestWantsToMessageYou(
    String displayName,
    String messageText,
  ) {
    return '$displayName muốn nhắn tin cho bạn, họ đã gửi $messageText.';
  }

  @override
  String get deleteAccountAccountChanged =>
      'Bạn đã chuyển tài khoản nên không có gì bị xóa. Hãy mở lại mục xóa cho tài khoản bạn muốn gỡ.';

  @override
  String get deleteAccountConfirmDeletePrompt => 'Để xác nhận, gõ:';

  @override
  String get deleteAccountConfirmUsernamePrompt =>
      'Để xác nhận, gõ tên người dùng của bạn:';

  @override
  String get deleteAccountConfirmationHint => 'Gõ DELETE';

  @override
  String get deleteAccountConfirmationHintUsername =>
      'Gõ tên người dùng của bạn';

  @override
  String get deleteAccountDeleteAllContentButton => 'Xóa tất cả nội dung';

  @override
  String get accountDeletionRecoveryTitle => 'Đang xóa tài khoản của bạn';

  @override
  String get accountDeletionRecoveryBody =>
      'Bọn mình chưa xóa xong tài khoản của bạn. Tên người dùng vẫn được giữ cho bạn và vẫn có thể lấy lại.';

  @override
  String accountDeletionRecoveryBodyWithExpiry(String expiryDate) {
    return 'We couldn\'t finish deleting your account. Your username is reserved for you until $expiryDate and can still be restored.';
  }

  @override
  String get accountDeletionRestoreUsername =>
      'Lấy lại tên người dùng của mình';

  @override
  String get accountDeletionFinishingBody =>
      'Yêu cầu xóa tài khoản của bạn vẫn đang được xử lý. Bạn có thể dùng một tài khoản khác trong lúc chúng tôi hoàn tất.';

  @override
  String get accountDeletionOtherAccountPending =>
      'Việc xóa một tài khoản khác vẫn đang được xử lý trên thiết bị này. Hãy đợi quá trình đó hoàn tất trước khi xóa tài khoản này.';

  @override
  String get accountDeletionCancellingBody =>
      'Chúng tôi đang hủy yêu cầu xóa của bạn. Kiểm tra lại trước khi rời màn hình này nhé.';

  @override
  String get accountDeletionRecoveryFailed =>
      'Bọn mình chưa lấy lại được tên người dùng của bạn. Kiểm tra kết nối và thử lại.';

  @override
  String get accountDeletionUsernameRestored =>
      'Tên người dùng của bạn đã được lấy lại. Tài khoản của bạn chưa bị xóa.';

  @override
  String get accountDeletionRecoveryStatusFailed =>
      'Bọn mình không kiểm tra được trạng thái xóa của bạn. Kiểm tra kết nối và thử lại.';

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
      'Hiện chưa thể xóa tài khoản. Chưa có gì bị xóa.';

  @override
  String get deleteAccountDeletionIncomplete =>
      'Bọn mình chưa xóa xong tài khoản của bạn. Thử lại nhé.';

  @override
  String get deleteAccountDeletionNotStarted =>
      'We couldn\'t start deleting your account. Nothing was deleted. Try again.';

  @override
  String get deleteAccountFinalConfirmationTitle => '⚠️ Xác nhận lần cuối';

  @override
  String get deleteAccountKeyDeletionWarning =>
      'Đã gửi yêu cầu xóa, nhưng khóa của bạn có thể chưa được gỡ hết khỏi thiết bị này. Vào Cài đặt → Khóa Nostr → Xóa khóa để thử lại.';

  @override
  String get deleteAccountLocalDataDeletionFailed =>
      'Đã gửi yêu cầu xóa và bạn đã đăng xuất, nhưng một số dữ liệu cục bộ không gỡ được khỏi thiết bị này.';

  @override
  String get deleteAccountPreparingDeletion => 'Đang chuẩn bị xóa...';

  @override
  String deleteAccountProgressEvents(int current, int total) {
    return '$current / $total sự kiện';
  }

  @override
  String get deleteAccountRemoveKeysBody =>
      'Thao tác này gỡ đăng nhập cục bộ của tài khoản này khỏi thiết bị. Nó không xóa tài khoản Divine hay danh tính Nostr của bạn.\n\nCác bản nháp và clip của tài khoản này vẫn được lưu trên thiết bị. Nếu đây là tài khoản cục bộ cuối cùng, bạn sẽ quay về màn hình đăng nhập.';

  @override
  String get deleteAccountRemoveKeysConfirm => 'Gỡ khỏi thiết bị';

  @override
  String get deleteAccountRemoveKeysTitle =>
      'Gỡ tài khoản này khỏi thiết bị này?';

  @override
  String get deleteAccountReauthRequired =>
      'Đăng nhập lại để xóa tài khoản của bạn. Chưa có gì bị xóa cả.';

  @override
  String get deleteAccountServerDeletionFailed =>
      'Đã gửi yêu cầu xóa cho các bài đăng của bạn, nhưng bọn mình chưa xóa xong tài khoản của bạn. Thử lại sau một lát nhé.';

  @override
  String get deleteAccountSuccess =>
      'Tài khoản Divine của bạn đã bị xóa. Yêu cầu xóa các bài đăng Nostr của bạn đã được gửi, nhưng một số relay, ứng dụng khách hoặc bộ nhớ đệm có thể vẫn giữ bản sao.';

  @override
  String get deleteAccountSuccessContentUnverified =>
      'Đã yêu cầu xóa tài khoản. Không thể xác nhận riêng việc xóa một số bài đăng hiện có.';

  @override
  String get deleteAccountWarningBody =>
      'Thao tác này gửi yêu cầu xóa cho tài khoản và nội dung của bạn, xóa tài khoản Divine của bạn khi có thể, và đăng xuất bạn trên thiết bị này. Một số relay, ứng dụng và chỉ mục tìm kiếm có thể vẫn giữ bản sao. Các thiết bị đã đăng nhập khác vẫn hoạt động cho đến khi bạn gỡ khóa ở đó.';

  @override
  String get findPeopleNoContacts =>
      'Không tìm thấy liên hệ nào.\nBắt đầu theo dõi mọi người để thấy họ ở đây.';

  @override
  String get geoBlockedCityLabel => 'Thành phố';

  @override
  String get geoBlockedCountryLabel => 'Quốc gia';

  @override
  String get geoBlockedDefaultReason =>
      'Dịch vụ này không khả dụng tại khu vực của bạn do quy định địa phương.';

  @override
  String get geoBlockedLegalNotice =>
      'Bọn mình tôn trọng luật và quy định địa phương của bạn. Giới hạn này dựa trên vị trí địa chỉ IP của bạn.';

  @override
  String get geoBlockedRegionLabel => 'Khu vực';

  @override
  String get geoBlockedTitle => 'Dịch vụ không khả dụng';

  @override
  String get likedVideosEmpty => 'Chưa có video đã thích';

  @override
  String get likedVideosInvalidRoute => 'Tuyến không hợp lệ';

  @override
  String get likedVideosTitle => 'Video đã thích';

  @override
  String get uploadFailureSheetRetryingSnackbar => 'Đang thử tải lên lại…';

  @override
  String get uploadFailureSheetSaveToDraftsButton => 'Lưu vào bản nháp';

  @override
  String get uploadFailureSheetSavedToDraftsSnackbar => 'Đã lưu vào bản nháp';

  @override
  String get uploadFailureSheetTitle => 'Tải lên thất bại';

  @override
  String get uploadFailureSheetTryAgainButton => 'Thử lại';

  @override
  String get videoEditorAudioImportAudio => 'Nhập âm thanh';

  @override
  String get videoEditorAudioImportFailed => 'Nhập âm thanh thất bại.';

  @override
  String get videoIconPlaceholderLabel => 'Video';

  @override
  String get publishErrorNotSignedIn => 'Vui lòng đăng nhập để đăng video.';

  @override
  String get publishErrorNoRetry => 'Không có lần tải lên nào để thử lại.';

  @override
  String get publishErrorNoInternet =>
      'Không có kết nối internet. Kiểm tra Wi-Fi hoặc dữ liệu di động rồi thử lại.';

  @override
  String get publishErrorServerUnreachable =>
      'Không kết nối được với máy chủ. Vui lòng thử lại sau ít phút.';

  @override
  String get publishErrorTimeout =>
      'Tải lên hết thời gian chờ. Thử kết nối mạnh hơn hoặc video nhỏ hơn.';

  @override
  String get publishErrorTls =>
      'Kết nối bảo mật thất bại. Kiểm tra mạng của bạn — Wi-Fi công cộng có thể chặn tải lên.';

  @override
  String publishErrorServerNotFound(String serverName) {
    return 'Máy chủ media ($serverName) không khả dụng. Bạn có thể chọn máy chủ khác trong cài đặt.';
  }

  @override
  String get publishErrorFileTooLarge =>
      'Tệp video quá lớn so với máy chủ. Thử cắt ngắn hoặc giảm chất lượng.';

  @override
  String publishErrorServerInternalError(String serverName) {
    return 'Máy chủ media ($serverName) gặp lỗi nội bộ. Bạn có thể chọn máy chủ khác trong cài đặt.';
  }

  @override
  String publishErrorServerDown(String serverName) {
    return 'Máy chủ media ($serverName) đang tạm thời sập. Thử lại sau ít phút hoặc chọn máy chủ khác trong cài đặt.';
  }

  @override
  String get publishErrorForbidden => 'Bạn không có quyền tải lên máy chủ này.';

  @override
  String get publishErrorFileNotFound =>
      'Không tìm thấy tệp video. Có thể nó đã bị xóa. Quay lại rồi thử lại nhé.';

  @override
  String get publishErrorLowStorage =>
      'Thiết bị của bạn không đủ dung lượng. Giải phóng bớt chỗ rồi thử lại nhé.';

  @override
  String get publishErrorThumbnailFailed =>
      'Video đã tải lên nhưng không chuẩn bị được ảnh thu nhỏ. Vui lòng thử lại.';

  @override
  String get publishErrorNostrPublishFailed =>
      'Video đã tải lên nhưng không đăng được bài. Kiểm tra cài đặt relay rồi thử lại.';

  @override
  String get publishErrorAccountRestricted =>
      'Your account is restricted, so this post couldn’t be published.';

  @override
  String get uploadFailureSheetAccountStatusButton => 'View Account Status';

  @override
  String get publishErrorAudioReuseNotPermitted =>
      'Video đã tải lên nhưng âm thanh này không được phép dùng lại. Chọn âm thanh khác để đăng nhé.';

  @override
  String get publishErrorInterrupted =>
      'Lần tải lên này đã bị gián đoạn. Bạn có muốn thử lại không?';

  @override
  String get publishErrorAccountChanged =>
      'Video này thuộc về một tài khoản khác. Chuyển lại tài khoản đó để đăng nhé.';

  @override
  String get publishErrorGeneric => 'Có gì đó không ổn. Vui lòng thử lại.';

  @override
  String get publishErrorRateLimited =>
      'Hiện đang có quá nhiều lượt tải lên. Chờ một chút rồi thử lại.';

  @override
  String get publishErrorUploadSessionExpired =>
      'Phiên tải lên của bạn đã hết hạn. Vui lòng thử lại.';

  @override
  String get publishErrorPermissionDenied =>
      'Divine không có quyền tải lên. Kiểm tra quyền ứng dụng trong cài đặt của bạn rồi thử lại.';

  @override
  String get publishErrorOutOfMemory =>
      'Thiết bị của bạn sắp hết bộ nhớ. Đóng bớt ứng dụng rồi thử lại nhé.';

  @override
  String get publishErrorOverlaysUnavailable =>
      'Không chuẩn bị được chữ và nhãn dán trên bản nháp này. Mở nó trong trình chỉnh sửa rồi đăng lại.';

  @override
  String get publishErrorUnknownServer => 'Máy chủ không xác định';

  @override
  String searchFilterPillSemanticLabel(String filter) {
    return 'Bộ lọc: $filter';
  }

  @override
  String searchNoResultsFound(String query) {
    return 'Không tìm thấy kết quả cho \"$query\"';
  }

  @override
  String searchTagChipViewVideosTaggedLabel(String tag) {
    return 'Xem video gắn thẻ $tag';
  }

  @override
  String audioAttributionRowSemanticLabel(
    String soundName,
    String creatorName,
  ) {
    return 'Âm thanh: $soundName của $creatorName. Chạm để xem chi tiết âm thanh.';
  }

  @override
  String metadataSoundsOriginalSoundSemantics(String creatorName) {
    return 'Âm thanh gốc của $creatorName. Chạm để dùng âm thanh này.';
  }

  @override
  String metadataSoundsSharedSoundSemantics(
    String soundName,
    String creatorName,
  ) {
    return 'Âm thanh: $soundName của $creatorName. Chạm để xem chi tiết.';
  }

  @override
  String get soundDetailLoadError =>
      'Không tải được âm thanh. Vui lòng thử lại.';

  @override
  String get soundDetailNotFoundMessage => 'Không tìm thấy âm thanh này';

  @override
  String get soundDetailNotFoundTitle => 'Không tìm thấy âm thanh';

  @override
  String videoFeedLoopCountLabel(int count) {
    return '🔁 $count loop';
  }

  @override
  String get originalSoundUnavailableBody =>
      'Âm thanh từ video này không có sẵn riêng.';

  @override
  String originalSoundByCreator(String creatorName) {
    return 'Âm thanh gốc - $creatorName';
  }

  @override
  String get ogVinerBadgeLabel => 'OG Viner';

  @override
  String get profileBadgeOgVinerBody =>
      'Người này đã đăng một Vine gốc mà Divine tìm thấy trong kho lưu trữ. Đây không phải huy hiệu xác minh tài khoản.';

  @override
  String get ogBetaTesterBadgeLabel => 'OG Beta Tester';

  @override
  String get profileBadgeOgBetaTesterBody =>
      'This person was testing Divine during the beta, before it opened to everyone. It is not an account verification badge.';

  @override
  String get profileBadgeCheckmarkTitle => 'Dấu tích hồ sơ';

  @override
  String get profileBadgeCheckmarkBody =>
      'Divine trao dấu tích này cho các tài khoản của đội ngũ. Nó tách biệt với NIP-05, liên kết tài khoản đã xác minh và trạng thái OG Viner.';

  @override
  String get unfollowConfirmButton => 'Bỏ theo dõi';

  @override
  String get videoClipSaveFailed => 'Không lưu được clip';

  @override
  String videoClipSaveTo(String destination) {
    return 'Lưu vào $destination';
  }

  @override
  String get videoClipDelete => 'Xóa clip';

  @override
  String inspiredByAttributionMultipleSemanticLabel(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return 'Lấy cảm hứng từ $creatorName +$additionalCreatorCount. Chạm để xem hồ sơ của họ.';
  }

  @override
  String inspiredByAttributionSemanticLabel(String creatorName) {
    return 'Lấy cảm hứng từ $creatorName. Chạm để xem hồ sơ của họ.';
  }

  @override
  String get bugReportSendReport => 'Gửi báo cáo';

  @override
  String get supportSubjectRequiredLabel => 'Chủ đề *';

  @override
  String get supportPublicSubmissionTitle => 'Bài đăng GitHub công khai';

  @override
  String get supportPublicSubmissionMessage =>
      'Mọi nội dung bạn gửi tại đây sẽ được đăng lên kho mã nguồn mở của chúng tôi trên GitHub để các nhà phát triển có thể xử lý. Bài đăng và tài khoản bạn đang đăng nhập sẽ hiển thị công khai với tất cả mọi người.';

  @override
  String get supportRequiredHelper => 'Bắt buộc';

  @override
  String get supportFieldLimitReached =>
      'Đó là độ dài tối đa. Phần vượt quá đã không được thêm vào.';

  @override
  String get bugReportSubjectHint => 'Tóm tắt ngắn gọn vấn đề';

  @override
  String get bugReportDescriptionRequiredLabel => 'Chuyện gì đã xảy ra? *';

  @override
  String get bugReportDescriptionHint => 'Mô tả vấn đề bạn gặp phải';

  @override
  String get bugReportStepsLabel => 'Các bước tái hiện';

  @override
  String get bugReportStepsHint => '1. Vào...\n2. Chạm vào...\n3. Thấy lỗi';

  @override
  String get bugReportExpectedBehaviorLabel => 'Hành vi mong đợi';

  @override
  String get bugReportExpectedBehaviorHint => 'Đáng lẽ phải xảy ra điều gì?';

  @override
  String get bugReportDiagnosticsNotice =>
      'Thông tin thiết bị và nhật ký sẽ được đính kèm tự động.';

  @override
  String get bugReportSuccessMessage =>
      'Cảm ơn bạn! Bọn mình đã nhận được báo cáo và sẽ dùng nó để làm Divine tốt hơn.';

  @override
  String get bugReportAttachImages => 'Đính kèm hình ảnh';

  @override
  String bugReportImagesCount(int count, int max) {
    return 'Đã chọn $count/$max hình ảnh';
  }

  @override
  String get bugReportRemoveImage => 'Xóa hình ảnh';

  @override
  String get bugReportUploadFailed =>
      'Bọn mình không tải được hình ảnh đã chọn. Thử lại hoặc gửi báo cáo không kèm nó.';

  @override
  String get bugReportSendFailed =>
      'Không gửi được báo cáo lỗi. Vui lòng thử lại sau.';

  @override
  String get featureRequestSendRequest => 'Gửi yêu cầu';

  @override
  String get featureRequestSubjectHint => 'Tóm tắt ngắn gọn ý tưởng của bạn';

  @override
  String get featureRequestDescriptionRequiredLabel => 'Bạn muốn gì? *';

  @override
  String get featureRequestDescriptionHint => 'Mô tả tính năng bạn muốn';

  @override
  String get featureRequestUsefulnessLabel => 'Nó sẽ hữu ích thế nào?';

  @override
  String get featureRequestUsefulnessHint =>
      'Giải thích lợi ích mà tính năng này mang lại';

  @override
  String get featureRequestWhenLabel => 'Khi nào bạn sẽ dùng nó?';

  @override
  String get featureRequestWhenHint =>
      'Mô tả những tình huống mà nó sẽ giúp ích';

  @override
  String get featureRequestSuccessMessage =>
      'Cảm ơn bạn! Bọn mình đã nhận được yêu cầu tính năng và sẽ xem xét.';

  @override
  String get featureRequestSendFailed =>
      'Không gửi được yêu cầu tính năng. Vui lòng thử lại sau.';

  @override
  String get notificationFollowBack => 'Theo dõi lại';

  @override
  String get followingTitle => 'Đang theo dõi';

  @override
  String followingTitleForName(String displayName) {
    return '$displayName đang theo dõi';
  }

  @override
  String get followingFailedToLoadList =>
      'Không tải được danh sách đang theo dõi';

  @override
  String get followingEmptyTitle => 'Chưa theo dõi ai';

  @override
  String get followersTitle => 'Người theo dõi';

  @override
  String followersTitleForName(String displayName) {
    return 'Người theo dõi $displayName';
  }

  @override
  String get followersFailedToLoadList =>
      'Không tải được danh sách người theo dõi';

  @override
  String get followersEmptyTitle => 'Chưa có người theo dõi';

  @override
  String get followersUpdateFollowFailed =>
      'Không cập nhật được trạng thái theo dõi. Vui lòng thử lại.';

  @override
  String get followersSortSemanticLabel => 'Sắp xếp người theo dõi';

  @override
  String get followingSortSemanticLabel => 'Sắp xếp đang theo dõi';

  @override
  String get followSortTitle => 'Sắp xếp theo';

  @override
  String get followSortNewest => 'Mới nhất trước';

  @override
  String get followSortOldest => 'Cũ nhất trước';

  @override
  String get newMessageTitle => 'Tin nhắn mới';

  @override
  String get newMessageFindPeople => 'Tìm người';

  @override
  String get newMessageNoContacts =>
      'Không tìm thấy liên hệ nào.\nTheo dõi mọi người để thấy họ ở đây.';

  @override
  String get newMessageNoUsersFound => 'Không tìm thấy người dùng nào';

  @override
  String get hashtagSearchTitle => 'Tìm hashtag';

  @override
  String get hashtagSearchSubtitle => 'Khám phá chủ đề và nội dung thịnh hành';

  @override
  String hashtagSearchNoResults(String query) {
    return 'Không tìm thấy hashtag nào cho \"$query\"';
  }

  @override
  String get hashtagSearchFailed => 'Tìm kiếm thất bại';

  @override
  String get userNotAvailableTitle => 'Tài khoản không khả dụng';

  @override
  String get userNotAvailableBody => 'Tài khoản này hiện không khả dụng.';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String get blossomFailedToSaveSettings =>
      'Không lưu được cài đặt. Vui lòng thử lại.';

  @override
  String get blossomValidServerUrl =>
      'Vui lòng nhập URL máy chủ hợp lệ (VD: https://blossom.band)';

  @override
  String get blossomSettingsSaved => 'Đã lưu cài đặt Blossom';

  @override
  String get blossomSaveTooltip => 'Lưu';

  @override
  String get blossomAboutTitle => 'Về Blossom';

  @override
  String get blossomAboutDescription =>
      'Blossom là giao thức lưu trữ media phi tập trung cho phép bạn tải video lên bất kỳ máy chủ tương thích nào. Mặc định, video được tải lên máy chủ Blossom của Divine. Bật tùy chọn bên dưới để dùng máy chủ tùy chỉnh.';

  @override
  String get blossomUseCustomServer => 'Dùng máy chủ Blossom tùy chỉnh';

  @override
  String get blossomCustomServerEnabledSubtitle =>
      'Video sẽ được tải lên máy chủ Blossom tùy chỉnh của bạn';

  @override
  String get blossomCustomServerDisabledSubtitle =>
      'Video của bạn hiện đang được tải lên máy chủ Blossom của Divine';

  @override
  String get blossomCustomServerUrl => 'URL máy chủ Blossom tùy chỉnh';

  @override
  String get blossomCustomServerHelper =>
      'Nhập URL máy chủ Blossom tùy chỉnh của bạn';

  @override
  String get blossomPopularServers => 'Máy chủ Blossom phổ biến';

  @override
  String get blossomServerUrlMustUseHttps =>
      'URL máy chủ Blossom phải dùng https://';

  @override
  String get blueskyFailedToUpdateCrosspost =>
      'Không cập nhật được cài đặt đăng chéo';

  @override
  String get blueskySignInRequired => 'Đăng nhập để quản lý cài đặt Bluesky';

  @override
  String get blueskyPublishVideos => 'Đăng video lên Bluesky';

  @override
  String get blueskyEnabledSubtitle => 'Video của bạn sẽ được đăng lên Bluesky';

  @override
  String get blueskyDisabledSubtitle =>
      'Video của bạn sẽ không được đăng lên Bluesky';

  @override
  String get blueskyBackfillDisclosureTitle =>
      'Video cũ của bạn cũng sẽ được đăng';

  @override
  String get blueskyBackfillDisclosureSubtitle =>
      'Khi bật tính năng này, Divine sẽ bắt đầu gửi các video cũ hơn của bạn lên Bluesky, từ cũ nhất trước, không vội chạm giới hạn hằng ngày.';

  @override
  String get blueskyHandle => 'Tên định danh Bluesky';

  @override
  String get blueskyDid => 'DID Bluesky';

  @override
  String get blueskyStatus => 'Trạng thái';

  @override
  String get blueskyStatusReady => 'Tài khoản đã cấp và sẵn sàng';

  @override
  String get blueskyStatusPending => 'Đang cấp tài khoản...';

  @override
  String get blueskyStatusFailed => 'Cấp tài khoản thất bại';

  @override
  String get blueskyStatusDisabled => 'Tài khoản đã tắt';

  @override
  String get blueskyStatusNotLinked => 'Chưa liên kết tài khoản Bluesky';

  @override
  String get blueskyUsernameRequired =>
      'Thiết lập tên định danh divine.video trước khi đăng lên Bluesky';

  @override
  String get blueskyUsernameRequiredSubtitle =>
      'Đăng lên Bluesky cần một tên định danh username.divine.video đã đăng ký.';

  @override
  String get blueskyUsernameSyncPending =>
      'Tên định danh Divine của bạn đã đăng ký. Bọn mình đang liên kết nó với Bluesky - thử lại sau ít phút.';

  @override
  String get blueskyStatusUnavailableRetry =>
      'Bọn mình không kiểm tra được tên định danh Divine của bạn. Thử lại nhé.';

  @override
  String get blueskySetUpHandle => 'Thiết lập';

  @override
  String get blueskyTemporarilyUnavailable =>
      'Đăng lên Bluesky tạm thời không khả dụng. Vui lòng thử lại.';

  @override
  String get invitesTitle => 'Mời bạn bè';

  @override
  String invitesGenerateCardTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lời mời sẵn sàng tạo',
      one: '1 lời mời sẵn sàng tạo',
    );
    return '$_temp0';
  }

  @override
  String get invitesGenerateCardSubtitle => 'Tạo mã khi bạn sẵn sàng chia sẻ.';

  @override
  String get invitesGenerateButtonLabel => 'Tạo lời mời';

  @override
  String get invitesNoneAvailable => 'Hiện chưa có lời mời nào';

  @override
  String get invitesShareWithPeople =>
      'Chia sẻ Divine với những người bạn quen';

  @override
  String get invitesUsedInvites => 'Lời mời đã dùng';

  @override
  String invitesShareMessage(String code) {
    return 'Tham gia Divine cùng tôi nhé! Dùng mã mời $code để bắt đầu:\nhttps://divine.video/invite/$code';
  }

  @override
  String get invitesCopyInvite => 'Sao chép lời mời';

  @override
  String get invitesCopied => 'Đã sao chép lời mời!';

  @override
  String get invitesShareInvite => 'Chia sẻ lời mời';

  @override
  String get invitesShareSubject => 'Tham gia Divine cùng tôi nhé';

  @override
  String get invitesClaimed => 'Đã dùng';

  @override
  String get invitesCouldNotLoad => 'Không tải được lời mời';

  @override
  String get invitesRetry => 'Thử lại';

  @override
  String get searchSomethingWentWrong => 'Có gì đó không ổn';

  @override
  String get searchTryAgain => 'Thử lại';

  @override
  String get searchForLists => 'Tìm danh sách';

  @override
  String get searchFindCuratedVideoLists => 'Tìm danh sách video tuyển chọn';

  @override
  String get searchEnterQuery => 'Nhập từ khóa tìm kiếm';

  @override
  String get searchDiscoverSomethingInteresting => 'Khám phá điều gì đó thú vị';

  @override
  String get searchPeopleSectionHeader => 'Mọi người';

  @override
  String get searchPeopleLoadingLabel => 'Đang tải kết quả người';

  @override
  String get searchTagsSectionHeader => 'Thẻ';

  @override
  String get searchTagsLoadingLabel => 'Đang tải kết quả thẻ';

  @override
  String get searchVideosSectionHeader => 'Video';

  @override
  String get searchVideosLoadingLabel => 'Đang tải kết quả video';

  @override
  String get searchVideosSortOptionsLabel => 'Sắp xếp kết quả video';

  @override
  String get searchVideosSortTrending => 'Nổi bật';

  @override
  String get searchVideosSortLoops => 'Nhiều loop nhất';

  @override
  String get searchVideosSortEngagement => 'Nhiều tương tác nhất';

  @override
  String get searchVideosSortRecent => 'Gần đây';

  @override
  String get searchListsSectionHeader => 'Danh sách';

  @override
  String get searchListsLoadingLabel => 'Đang tải kết quả danh sách';

  @override
  String get cameraAgeRestriction => 'Bạn phải đủ 16 tuổi để tạo nội dung';

  @override
  String get keyImportInsecureBunkerRelay =>
      'Relay bunker phải dùng wss:// (ws:// chỉ được phép cho localhost)';

  @override
  String get timeNow => 'vừa xong';

  @override
  String timeShortMinutes(int count) {
    return '${count}p';
  }

  @override
  String timeShortHours(int count) {
    return '${count}g';
  }

  @override
  String timeShortDays(int count) {
    return '$count ng';
  }

  @override
  String timeShortWeeks(int count) {
    return '${count}t';
  }

  @override
  String timeShortMonths(int count) {
    return '$count th';
  }

  @override
  String timeShortYears(int count) {
    return '$count n';
  }

  @override
  String get timeVerboseNow => 'Bây giờ';

  @override
  String timeAgo(String time) {
    return '$time trước';
  }

  @override
  String get timeToday => 'Hôm nay';

  @override
  String get timeYesterday => 'Hôm qua';

  @override
  String get timeJustNow => 'vừa xong';

  @override
  String timeMinutesAgo(int count) {
    return '$count phút trước';
  }

  @override
  String timeHoursAgo(int count) {
    return '$count giờ trước';
  }

  @override
  String timeDaysAgo(int count) {
    return '$count ngày trước';
  }

  @override
  String get draftTimeJustNow => 'Vừa xong';

  @override
  String get contentLabelNudity => 'Khỏa thân';

  @override
  String get contentLabelSexualContent => 'Nội dung tình dục';

  @override
  String get contentLabelPornography => 'Nội dung khiêu dâm';

  @override
  String get contentLabelGraphicMedia => 'Hình ảnh rùng rợn';

  @override
  String get contentLabelViolence => 'Bạo lực';

  @override
  String get contentLabelSelfHarm => 'Tự gây hại/Tự tử';

  @override
  String get contentLabelDrugUse => 'Sử dụng ma túy';

  @override
  String get contentLabelAlcohol => 'Rượu bia';

  @override
  String get contentLabelTobacco => 'Thuốc lá/Hút thuốc';

  @override
  String get contentLabelGambling => 'Cờ bạc';

  @override
  String get contentLabelProfanity => 'Ngôn từ thô tục';

  @override
  String get contentLabelHateSpeech => 'Ngôn từ thù ghét';

  @override
  String get contentLabelHarassment => 'Quấy rối';

  @override
  String get contentLabelFlashingLights => 'Ánh sáng nhấp nháy';

  @override
  String get contentLabelAiGenerated => 'Do AI tạo ra';

  @override
  String get contentLabelDeepfake => 'Deepfake';

  @override
  String get contentLabelSpam => 'Spam';

  @override
  String get contentLabelScam => 'Lừa đảo/Gian lận';

  @override
  String get contentLabelSpoiler => 'Tiết lộ nội dung';

  @override
  String get contentLabelMisleading => 'Gây hiểu lầm';

  @override
  String get contentLabelSensitiveContent => 'Nội dung nhạy cảm';

  @override
  String notificationLikedYourVideo(String actorName) {
    return '$actorName đã thích video của bạn';
  }

  @override
  String notificationLikedYourComment(String actorName) {
    return '$actorName đã thích bình luận của bạn';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return '$actorName đã bình luận video của bạn';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return '$actorName đã bắt đầu theo dõi bạn';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return '$actorName đã nhắc đến bạn';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return '$actorName đã đăng lại video của bạn';
  }

  @override
  String notificationPostedNewVine(String actorName) {
    return '$actorName đã đăng một vine mới';
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
      other: '$count vine của bạn',
      one: 'vine của bạn',
    );
    return '$actorName đã thêm $_temp0 vào $listName';
  }

  @override
  String notificationRepliedToYourComment(String actorName) {
    return '$actorName đã trả lời bình luận của bạn';
  }

  @override
  String get notificationAndConnector => 'và';

  @override
  String notificationOthersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count người khác',
      one: '1 người khác',
    );
    return '$_temp0';
  }

  @override
  String get notificationSystemUpdate => 'Bạn có cập nhật mới';

  @override
  String get commentReplyToPrefix => 'Trả lời:';

  @override
  String get commentHideKeyboard => 'Ẩn bàn phím';

  @override
  String get commentsErrorLoadFailed => 'Không tải được bình luận';

  @override
  String get commentsErrorNotAuthenticatedComment =>
      'Vui lòng đăng nhập để bình luận';

  @override
  String get commentsErrorPostCommentFailed => 'Không đăng được bình luận';

  @override
  String get commentsErrorPostReplyFailed => 'Không đăng được câu trả lời';

  @override
  String get commentsErrorEditFailed => 'Không sửa được bình luận';

  @override
  String get commentsErrorNotAuthenticatedInteract =>
      'Vui lòng đăng nhập để tương tác';

  @override
  String get commentsErrorVoteFailed => 'Không bình chọn được bình luận';

  @override
  String get commentsErrorReportFailed => 'Không báo cáo được bình luận';

  @override
  String get commentsErrorBlockFailed => 'Không chặn được người dùng';

  @override
  String get commentsErrorDeleteFailed => 'Không xóa được bình luận';

  @override
  String commentsHeaderCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bình luận',
      one: '$count bình luận',
    );
    return '$_temp0';
  }

  @override
  String get commentsVideoReplyPending => 'Đang đăng…';

  @override
  String get commentsVideoReplyPendingSemanticLabel =>
      'Câu trả lời video của bạn đang được đăng';

  @override
  String get commentsSortNew => 'Mới';

  @override
  String get commentsSortTop => 'Nổi bật';

  @override
  String get commentsSortOld => 'Cũ';

  @override
  String get commentsSortSemanticLabel => 'Sắp xếp bình luận';

  @override
  String get commentReply => 'Trả lời';

  @override
  String get commentReplySemanticLabel => 'Trả lời bình luận';

  @override
  String get commentUpvoteLabel => 'Upvote bình luận';

  @override
  String get commentRemoveUpvoteLabel => 'Bỏ upvote';

  @override
  String get commentDownvoteLabel => 'Downvote bình luận';

  @override
  String get commentRemoveDownvoteLabel => 'Bỏ downvote';

  @override
  String get commentsInputHint => 'Thêm bình luận...';

  @override
  String get commentsInputHintEdit => 'Sửa bình luận...';

  @override
  String get commentsEmptyTitle => 'Chưa có bình luận nào';

  @override
  String get commentsEmptySubtitle => 'Khai tiệc đi nào!';

  @override
  String get draftUntitled => 'Chưa đặt tên';

  @override
  String get contentWarningNone => 'Không có';

  @override
  String get textBackgroundNone => 'Không có';

  @override
  String get textBackgroundSolid => 'Đặc';

  @override
  String get textBackgroundHighlight => 'Tô sáng';

  @override
  String get textBackgroundTransparent => 'Trong suốt';

  @override
  String get textAlignLeft => 'Trái';

  @override
  String get textAlignRight => 'Phải';

  @override
  String get textAlignCenter => 'Giữa';

  @override
  String get cameraPermissionWebUnsupportedTitle =>
      'Chưa hỗ trợ camera trên web';

  @override
  String get cameraPermissionWebUnsupportedDescription =>
      'Chưa thể quay và ghi hình trong phiên bản web.';

  @override
  String get cameraPermissionBackToFeed => 'Quay lại bảng tin';

  @override
  String get cameraCouldNotStart => 'Không khởi động được máy ảnh';

  @override
  String get cameraUnsupportedPlatform =>
      'Máy ảnh chưa khả dụng trên nền tảng này.\nBạn vẫn có thể duyệt và xem video.';

  @override
  String get cameraPermissionErrorTitle => 'Lỗi quyền truy cập';

  @override
  String get cameraPermissionErrorDescription =>
      'Có gì đó không ổn khi kiểm tra quyền.';

  @override
  String get cameraPermissionRetry => 'Thử lại';

  @override
  String get cameraPermissionAllowAccessTitle =>
      'Cho phép truy cập camera & micro';

  @override
  String get cameraPermissionAllowAccessDescription =>
      'Điều này cho phép bạn quay và chỉnh sửa video ngay trong ứng dụng, không gì hơn.';

  @override
  String get cameraPermissionGoToSettings => 'Đi tới cài đặt';

  @override
  String get videoRecorderWhySixSecondsTitle => 'Tại sao 6 giây?';

  @override
  String get videoRecorderWhySixSecondsSubtitle =>
      'Clip ngắn tạo chỗ cho sự ngẫu hứng. Định dạng 6 giây giúp bạn bắt trọn những khoảnh khắc chân thật khi chúng xảy ra.';

  @override
  String get videoRecorderWhySixSecondsButton => 'Đã hiểu!';

  @override
  String get videoRecorderUploadTitle => 'Sao không cho tải lên?';

  @override
  String get videoRecorderUploadBody =>
      'Những gì bạn thấy trên Divine đều do người làm: mộc mạc và được ghi lại trong khoảnh khắc. Khác với các nền tảng cho phép tải lên nội dung dàn dựng kỹ hoặc do AI tạo ra, bọn mình ưu tiên sự chân thật của trải nghiệm quay trực tiếp từ camera.';

  @override
  String get videoRecorderUploadBodyDetail =>
      'Bằng cách giữ việc sáng tạo trong ứng dụng, bọn mình có thể đảm bảo tốt hơn rằng nội dung là thật và chưa qua chỉnh sửa. Hiện bọn mình chưa mở tải lên từ thư viện ngoài để bảo vệ sự chân thật đó và giữ cộng đồng không có nội dung tổng hợp nhất có thể.';

  @override
  String get videoRecorderUploadBodyCta =>
      'Chuyển sang Capture hoặc Classic để quay thứ gì đó thật sự.';

  @override
  String get videoRecorderUploadLearnMore => 'Tìm hiểu cách xác minh hoạt động';

  @override
  String get videoRecorderAutosaveFoundTitle =>
      'Bọn mình tìm thấy nội dung đang làm dở';

  @override
  String get videoRecorderAutosaveFoundSubtitle =>
      'Bạn có muốn tiếp tục từ chỗ đã dừng không?';

  @override
  String get videoRecorderAutosaveContinueButton => 'Có, tiếp tục';

  @override
  String get videoRecorderAutosaveDiscardButton => 'Không, làm video mới';

  @override
  String get videoRecorderAutosaveRestoreFailure =>
      'Không khôi phục được bản nháp của bạn';

  @override
  String get videoRecorderStopRecordingTooltip => 'Dừng quay';

  @override
  String get videoRecorderStartRecordingTooltip => 'Bắt đầu quay';

  @override
  String get videoRecorderRecordingTapToStopLabel =>
      'Đang quay. Chạm bất cứ đâu để dừng';

  @override
  String get videoRecorderTapToStartLabel => 'Chạm bất cứ đâu để bắt đầu quay';

  @override
  String get videoRecorderDeleteLastClipLabel => 'Xóa clip cuối';

  @override
  String get videoRecorderSwitchCameraLabel => 'Đổi camera';

  @override
  String videoRecorderZoomLevelLabel(String zoom) {
    return 'Thu phóng tới $zoom×';
  }

  @override
  String get videoRecorderToggleGridLabel => 'Bật/tắt lưới';

  @override
  String get videoRecorderToggleGhostFrameLabel => 'Bật/tắt khung ma';

  @override
  String get videoRecorderGhostFrameEnabled => 'Đã bật khung ma';

  @override
  String get videoRecorderGhostFrameDisabled => 'Đã tắt khung ma';

  @override
  String get videoRecorderClipDeletedMessage => 'Đã chuyển clip vào thùng rác';

  @override
  String get videoRecorderClipUndoLabel => 'Hoàn tác';

  @override
  String get libraryTrashEmptyTitle => 'Thùng rác trống';

  @override
  String get libraryTrashEmptySubtitle =>
      'Clip đã xóa nằm ở đây 30 ngày trước khi bị xóa hẳn.';

  @override
  String get libraryTrashRestoreLabel => 'Khôi phục';

  @override
  String get libraryTrashDeleteNowLabel => 'Xóa ngay';

  @override
  String get libraryTrashEmptyAllLabel => 'Dọn sạch thùng rác';

  @override
  String get libraryTrashDeleteConfirmTitle => 'Xóa clip ngay?';

  @override
  String get libraryTrashDeleteConfirmMessage =>
      'Thao tác này xóa clip khỏi thùng rác ngay lập tức.';

  @override
  String get libraryTrashEmptyConfirmTitle => 'Dọn sạch thùng rác?';

  @override
  String libraryTrashEmptyConfirmMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clip',
      one: '1 clip',
    );
    return 'Thao tác này xóa vĩnh viễn $_temp0 khỏi thùng rác ngay lập tức.';
  }

  @override
  String get videoRecorderCloseLabel => 'Đóng máy quay';

  @override
  String get videoRecorderContinueToEditorLabel =>
      'Tiếp tục tới trình chỉnh sửa video';

  @override
  String get videoRecorderCameraPreviewLabel => 'Bản xem trước camera';

  @override
  String get videoRecorderCameraPreviewFocusHint => 'Lấy nét camera';

  @override
  String videoRecorderSwitchToModeLabel(String mode) {
    return 'Chuyển sang chế độ $mode';
  }

  @override
  String get videoRecorderLipSyncAddAudioFirst =>
      'Thêm âm thanh trước khi quay';

  @override
  String get videoRecorderStopMotionAssembleFailed =>
      'Không tạo được video. Thử lại nhé.';

  @override
  String videoRecorderStopMotionShotsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Còn $count lượt chụp',
      zero: 'Hết lượt chụp',
    );
    return '$_temp0';
  }

  @override
  String get videoRecorderToggleFlashLabel => 'Bật/tắt đèn flash';

  @override
  String get videoRecorderCycleTimerLabel => 'Chuyển hẹn giờ';

  @override
  String get videoRecorderToggleAspectRatioLabel => 'Đổi tỷ lệ khung hình';

  @override
  String get videoRecorderStabilizationLabel => 'Chống rung';

  @override
  String get videoRecorderStabilizationModeOff => 'Tắt';

  @override
  String get videoRecorderStabilizationModeStandard => 'Chuẩn';

  @override
  String get videoRecorderStabilizationModeCinematic => 'Điện ảnh';

  @override
  String get videoRecorderStabilizationModeCinematicExtended =>
      'Điện ảnh mở rộng';

  @override
  String get videoRecorderStabilizationModePreviewOptimized =>
      'Tối ưu xem trước';

  @override
  String get videoRecorderStabilizationModeLowLatency => 'Độ trễ thấp';

  @override
  String get videoRecorderStabilizationModeAuto => 'Tự động';

  @override
  String get videoRecorderFlashValueOff => 'Tắt';

  @override
  String get videoRecorderFlashValueOn => 'Bật';

  @override
  String get videoRecorderFlashValueAuto => 'Tự động';

  @override
  String get videoRecorderTimerValueOff => 'Tắt';

  @override
  String get videoRecorderTimerValueThreeSeconds => '3 giây';

  @override
  String get videoRecorderTimerValueTenSeconds => '10 giây';

  @override
  String get videoRecorderAspectRatioValueSquare => 'Vuông';

  @override
  String get videoRecorderAspectRatioValueVertical => 'Dọc';

  @override
  String get videoRecorderCameraValueFront => 'Camera trước';

  @override
  String get videoRecorderCameraValueBack => 'Camera sau';

  @override
  String get videoRecorderLibraryEmptyLabel => 'Thư viện clip, không có clip';

  @override
  String videoRecorderLibraryOpenLabel(int clipCount) {
    String _temp0 = intl.Intl.pluralLogic(
      clipCount,
      locale: localeName,
      other: 'Mở thư viện clip, $clipCount clip',
      one: 'Mở thư viện clip, 1 clip',
    );
    return '$_temp0';
  }

  @override
  String videoRecorderLibraryOpenStopMotionLabel(int frameCount) {
    String _temp0 = intl.Intl.pluralLogic(
      frameCount,
      locale: localeName,
      other: 'Mở thư viện stop-motion, $frameCount khung hình',
      one: 'Mở thư viện stop-motion, 1 khung hình',
      zero: 'Mở thư viện stop-motion',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorCameraLabel => 'Máy quay';

  @override
  String get videoEditorOpenCameraSemanticLabel => 'Mở camera';

  @override
  String get videoEditorLibraryLabel => 'Thư viện';

  @override
  String get videoEditorTextLabel => 'Chữ';

  @override
  String get videoEditorDrawLabel => 'Vẽ';

  @override
  String get videoEditorFilterLabel => 'Bộ lọc';

  @override
  String get videoEditorTuneLabel => 'Điều chỉnh';

  @override
  String get videoEditorOpenTuneSemanticLabel =>
      'Mở trình chỉnh sửa điều chỉnh';

  @override
  String get videoEditorTuneBrightness => 'Độ sáng';

  @override
  String get videoEditorTuneContrast => 'Độ tương phản';

  @override
  String get videoEditorTuneSaturation => 'Độ bão hòa';

  @override
  String get videoEditorTuneExposure => 'Phơi sáng';

  @override
  String get videoEditorTuneHue => 'Tông màu';

  @override
  String get videoEditorTuneTemperature => 'Nhiệt độ màu';

  @override
  String get videoEditorTuneTint => 'Sắc màu';

  @override
  String get videoEditorTuneFade => 'Mờ dần';

  @override
  String get videoEditorAudioLabel => 'Âm thanh';

  @override
  String get videoEditorAddTitle => 'Thêm';

  @override
  String get videoEditorOpenLibrarySemanticLabel => 'Mở thư viện';

  @override
  String get videoEditorOpenAudioSemanticLabel => 'Mở trình chỉnh sửa âm thanh';

  @override
  String get videoEditorCaptionsLabel => 'Phụ đề';

  @override
  String get videoEditorOpenCaptionsSemanticLabel =>
      'Mở trình chỉnh sửa phụ đề';

  @override
  String get videoEditorCaptionsBurnInLabel => 'Ghi cứng vào video';

  @override
  String get videoEditorCaptionsPresetCustom => 'Tùy chỉnh';

  @override
  String get videoEditorCaptionsCustomStyleTitle => 'Kiểu tùy chỉnh';

  @override
  String get videoEditorCaptionsCustomApply => 'Áp dụng';

  @override
  String get videoEditorCaptionsCustomFont => 'Phông chữ';

  @override
  String get videoEditorCaptionsCustomTextColor => 'Màu chữ';

  @override
  String get videoEditorCaptionsCustomBackground => 'Nền';

  @override
  String get videoEditorCaptionsCustomBackgroundColor => 'Màu nền';

  @override
  String get videoEditorCaptionsCustomAnimation => 'Hiệu ứng';

  @override
  String get videoEditorCaptionsAnimationNone => 'Không có';

  @override
  String get videoEditorCaptionsAnimationFade => 'Mờ dần';

  @override
  String get videoEditorCaptionsAnimationPop => 'Pop';

  @override
  String get videoEditorCaptionsAnimationSpring => 'Nảy';

  @override
  String get videoEditorCaptionsEditTitle => 'Phụ đề';

  @override
  String get videoEditorCaptionsGeneratingTitle => 'Đang nghe giọng nói…';

  @override
  String get videoEditorCaptionsGeneratingSubtitle =>
      'Đang chuyển âm thanh của bạn thành gợi ý phụ đề.';

  @override
  String get videoEditorCaptionsNoSpeechMessage =>
      'Bọn mình không nghe thấy giọng nói nào. Bạn vẫn có thể tự viết phụ đề.';

  @override
  String get videoEditorCaptionsUnavailableMessage =>
      'Thiết bị này không có nhận diện giọng nói. Bạn có thể tự viết phụ đề.';

  @override
  String get videoEditorCaptionsNotAuthorizedMessage =>
      'Nhận diện giọng nói chưa được cho phép. Bật nó trong Cài đặt hoặc tự viết phụ đề.';

  @override
  String get videoEditorCaptionsFailedMessage =>
      'Lần này phiên âm không thành công. Bạn có thể tự viết phụ đề.';

  @override
  String get videoEditorCaptionsStartEmptyButton => 'Tự viết phụ đề';

  @override
  String get videoEditorCaptionsAddCue => 'Thêm phụ đề';

  @override
  String get videoEditorCaptionsCueTextHint => 'Nội dung phụ đề';

  @override
  String get videoEditorCaptionsCueDeleteSemanticLabel => 'Xóa phụ đề';

  @override
  String get videoEditorCaptionsDeleteTrack => 'Xóa tất cả phụ đề';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmTitle => 'Xóa phụ đề?';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmSubtitle =>
      'Tất cả nội dung và thời điểm phụ đề sẽ mất.';

  @override
  String get videoEditorCaptionsCloseSemanticLabel =>
      'Đóng trình chỉnh sửa phụ đề';

  @override
  String get videoEditorCaptionsDoneSemanticLabel => 'Xác nhận phụ đề';

  @override
  String get videoEditorCaptionsPresetTitle => 'Kiểu phụ đề';

  @override
  String get videoEditorCaptionsPresetClassic => 'Cổ điển';

  @override
  String get videoEditorCaptionsPresetPop => 'Pop';

  @override
  String get videoEditorCaptionsPresetZoom => 'Zoom';

  @override
  String get videoEditorCaptionsPresetSpring => 'Nảy';

  @override
  String get videoEditorCaptionsPresetMono => 'Mono';

  @override
  String get videoEditorCaptionsPresetHeadline => 'Tiêu đề';

  @override
  String get videoEditorCaptionsPresetTypewriter => 'Máy đánh chữ';

  @override
  String get videoEditorCaptionsPresetMarker => 'Bút dạ';

  @override
  String get videoEditorCaptionsPresetScript => 'Thư pháp';

  @override
  String get videoEditorCaptionsPresetRetro => 'Retro';

  @override
  String get videoEditorCaptionsPresetElegant => 'Thanh lịch';

  @override
  String get videoEditorCaptionsPresetBubble => 'Bong bóng';

  @override
  String get videoEditorCaptionsPresetNeon => 'Neon';

  @override
  String get videoEditorCaptionsPresetBold => 'Đậm';

  @override
  String get videoEditorCaptionsPresetDreamy => 'Mơ mộng';

  @override
  String get videoEditorCaptionsPresetOcean => 'Đại dương';

  @override
  String get videoEditorCaptionsPresetSunny => 'Nắng';

  @override
  String get videoEditorCaptionsPresetHandwritten => 'Chữ viết tay';

  @override
  String get videoEditorCaptionsPresetSerif => 'Serif';

  @override
  String get videoEditorCaptionsPresetStamp => 'Con dấu';

  @override
  String get videoEditorOpenTextSemanticLabel => 'Mở trình chỉnh sửa chữ';

  @override
  String get videoEditorOpenDrawSemanticLabel => 'Mở trình chỉnh sửa vẽ';

  @override
  String get videoEditorOpenFilterSemanticLabel => 'Mở trình chỉnh sửa bộ lọc';

  @override
  String get videoEditorOpenStickerSemanticLabel =>
      'Mở trình chỉnh sửa nhãn dán';

  @override
  String get videoEditorSaveDraftTitle => 'Lưu bản nháp của bạn?';

  @override
  String get videoEditorSaveDraftSubtitle =>
      'Giữ các chỉnh sửa để làm sau, hoặc bỏ chúng và rời trình chỉnh sửa.';

  @override
  String get videoEditorSaveDraftButton => 'Lưu bản nháp';

  @override
  String get videoEditorDiscardChangesButton => 'Bỏ các thay đổi';

  @override
  String get videoEditorKeepEditingButton => 'Tiếp tục chỉnh sửa';

  @override
  String get videoEditorDeleteLayerDropZone => 'Vùng thả để xóa lớp';

  @override
  String get videoEditorReleaseToDeleteLayer => 'Thả ra để xóa lớp';

  @override
  String get videoEditorDoneLabel => 'Xong';

  @override
  String get videoEditorPlayPauseSemanticLabel => 'Phát hoặc tạm dừng video';

  @override
  String videoEditorSplitPositionInvalid(int minDurationMs) {
    return 'Vị trí tách không hợp lệ. Cả hai clip phải dài ít nhất ${minDurationMs}ms.';
  }

  @override
  String get videoEditorSaveSelectedClip => 'Lưu clip đã chọn';

  @override
  String get videoEditorSaveClip => 'Lưu clip';

  @override
  String get videoEditorClipSavedSuccess => 'Đã lưu clip vào thư viện';

  @override
  String get videoEditorClipSaveFailed => 'Không lưu được clip';

  @override
  String get videoEditorColorPickerSemanticLabel => 'Bộ chọn màu';

  @override
  String get videoEditorUndoSemanticLabel => 'Hoàn tác';

  @override
  String get videoEditorRedoSemanticLabel => 'Làm lại';

  @override
  String get videoEditorTextColorSemanticLabel => 'Màu chữ';

  @override
  String get videoEditorTextAlignmentSemanticLabel => 'Căn chỉnh chữ';

  @override
  String get videoEditorTextBackgroundSemanticLabel => 'Nền chữ';

  @override
  String get videoEditorFontSemanticLabel => 'Phông chữ';

  @override
  String get videoEditorNoStickersFound => 'Không tìm thấy nhãn dán nào';

  @override
  String get videoEditorNoStickersAvailable => 'Không có nhãn dán nào';

  @override
  String get videoEditorFailedLoadStickers => 'Không tải được nhãn dán';

  @override
  String get videoEditorVoiceOverLabel => 'Lồng tiếng';

  @override
  String videoEditorVoiceOverTakeName(int number) {
    return 'Bản ghi $number';
  }

  @override
  String get videoEditorOpenVoiceOverSemanticLabel => 'Ghi lồng tiếng';

  @override
  String get videoEditorVoiceOverRecordSemanticLabel => 'Bắt đầu ghi';

  @override
  String get videoEditorVoiceOverStopSemanticLabel => 'Dừng ghi';

  @override
  String get videoEditorVoiceOverHint =>
      'Chạm để ghi. Thêm bao nhiêu bản tùy thích.';

  @override
  String videoEditorVoiceOverRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bản ghi',
      one: '1 bản ghi',
      zero: 'Chưa có bản ghi nào',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorVoiceOverDeleteLast => 'Xóa bản ghi cuối';

  @override
  String get videoEditorVoiceOverPermissionTitle => 'Cần quyền truy cập micro';

  @override
  String get videoEditorVoiceOverPermissionBody =>
      'Cho phép truy cập micro để ghi lồng tiếng.';

  @override
  String get videoEditorVoiceOverOpenSettings => 'Mở cài đặt';

  @override
  String get videoEditorVoiceOverRecordingStarted => 'Đã bắt đầu ghi';

  @override
  String get videoEditorVoiceOverRecordingSaved => 'Đã lưu bản ghi';

  @override
  String get videoEditorVoiceOverTooLong => 'Bản ghi dài hơn video của bạn';

  @override
  String get videoEditorPlaySemanticLabel => 'Phát';

  @override
  String get videoEditorPauseSemanticLabel => 'Tạm dừng';

  @override
  String get videoEditorVolumeSemanticLabel => 'Điều chỉnh âm lượng';

  @override
  String videoEditorTimelineVolumePreview(int percent) {
    return 'Âm lượng $percent%';
  }

  @override
  String get videoEditorTimelineSlideToAdjust => 'Trượt để điều chỉnh';

  @override
  String get videoEditorChromaKeyLabel => 'Phông xanh';

  @override
  String get videoEditorChromaKeyTitle => 'Phông xanh';

  @override
  String get videoEditorChromaKeySemanticLabel =>
      'Thiết lập phông xanh cho clip này';

  @override
  String get videoEditorChromaKeyCloseSemanticLabel =>
      'Bỏ các thay đổi phông xanh';

  @override
  String get videoEditorChromaKeyDoneSemanticLabel => 'Áp dụng phông xanh';

  @override
  String get videoEditorChromaKeyAutoDetect => 'Tự động nhận diện';

  @override
  String get videoEditorChromaKeyPresetGreen => 'Xanh lá';

  @override
  String get videoEditorChromaKeyPresetBlue => 'Xanh dương';

  @override
  String get videoEditorChromaKeyScreenColorLabel => 'Màu phông';

  @override
  String get videoEditorChromaKeyAmountLabel => 'Mức độ';

  @override
  String get videoEditorChromaKeyAmountHint => 'Xóa bao nhiêu phần màu phông';

  @override
  String get videoEditorChromaKeyEdgeLabel => 'Viền';

  @override
  String get videoEditorChromaKeyEdgeHint =>
      'Làm mềm phần cắt để tóc không bị răng cưa';

  @override
  String get videoEditorChromaKeySpillLabel => 'Ám màu';

  @override
  String get videoEditorChromaKeySpillHint =>
      'Kéo màu phông ra khỏi chủ thể của bạn';

  @override
  String get videoEditorChromaKeyBackgroundLabel => 'Thay bằng';

  @override
  String get videoEditorChromaKeyBackgroundNone => 'Không gì cả';

  @override
  String get videoEditorChromaKeyBackgroundColor => 'Màu';

  @override
  String get videoEditorChromaKeyBackgroundImage => 'Ảnh';

  @override
  String get videoEditorChromaKeyBackgroundVideo => 'Clip';

  @override
  String get videoEditorChromaKeyTransparentHint =>
      'Video không giữ được độ trong suốt, nên phần này sẽ xuất ra màu đen.';

  @override
  String get videoEditorChromaKeyDetectFailed =>
      'Không tìm thấy phông. Phông phải chạm tới các cạnh khung hình — nếu không, hãy tự chọn màu.';

  @override
  String get videoEditorChromaKeyPickClipTitle => 'Chọn một clip';

  @override
  String get videoEditorChromaKeyNoLibraryClips =>
      'Thư viện của bạn đang trống. Lưu một clip trước đã, rồi dùng nó làm nền.';

  @override
  String get videoEditorChromaKeyImagePickFailed => 'Không tải được ảnh đó.';

  @override
  String get videoEditorChromaKeyRemove => 'Gỡ phông xanh';

  @override
  String get videoEditorChromaKeyFailed =>
      'Không áp dụng được phông xanh. Clip của bạn vẫn nguyên.';

  @override
  String get videoEditorChromaKeyRemoveFailed =>
      'Không gỡ được phông xanh. Clip của bạn vẫn nguyên.';

  @override
  String get videoEditorChromaKeyApplying => 'Đang áp dụng phông xanh…';

  @override
  String get videoEditorChromaKeyPreviewUnavailable =>
      'Thiết bị này không hiển thị được bản xem trước trực tiếp. Cài đặt của bạn vẫn được áp dụng khi xuất.';

  @override
  String videoEditorClipVolumeLabel(int index) {
    return 'Clip $index';
  }

  @override
  String get videoEditorDeleteLabel => 'Xóa';

  @override
  String get videoEditorDeleteSelectedItemSemanticLabel => 'Xóa mục đã chọn';

  @override
  String get videoEditorStopMotionFramesPerImageLabel =>
      'Số khung hình mỗi ảnh';

  @override
  String videoEditorStopMotionFramesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count khung hình',
      one: '1 khung hình',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorStopMotionFramesPerImageButtonLabel => 'Khung hình';

  @override
  String videoEditorStopMotionFramesPerImageValueSemanticLabel(int count) {
    return '$count khung hình mỗi ảnh';
  }

  @override
  String videoEditorStopMotionFrameSemanticLabel(int position, int total) {
    return 'Khung hình stop-motion $position/$total';
  }

  @override
  String get videoEditorEditLabel => 'Sửa';

  @override
  String get videoEditorEditSelectedItemSemanticLabel => 'Sửa mục đã chọn';

  @override
  String get videoEditorDuplicateLabel => 'Nhân bản';

  @override
  String get videoEditorDuplicateSelectedItemSemanticLabel =>
      'Nhân bản mục đã chọn';

  @override
  String get videoEditorCombineLabel => 'Kết hợp';

  @override
  String get videoEditorCombineDrawLayersSemanticLabel =>
      'Kết hợp các hình vẽ đã chọn thành một lớp';

  @override
  String get videoEditorSplitLabel => 'Tách';

  @override
  String get videoEditorSplitSelectedClipSemanticLabel => 'Tách clip đã chọn';

  @override
  String get videoEditorExtractAudioLabel => 'Tách âm thanh';

  @override
  String get videoEditorClipAudioTitle => 'Âm thanh clip';

  @override
  String get videoEditorExtractAudioFromClipSemanticLabel =>
      'Tách âm thanh khỏi clip và tắt tiếng bản gốc';

  @override
  String get videoEditorExtractAudioNoLocalFile =>
      'Không thể tách âm thanh: clip không có sẵn trên máy.';

  @override
  String get videoEditorExtractAudioFailed =>
      'Không tách được âm thanh. Vui lòng thử lại.';

  @override
  String get videoEditorSpeedLabel => 'Tốc độ';

  @override
  String get videoEditorSetClipSpeedSemanticLabel =>
      'Đặt tốc độ phát cho clip đã chọn';

  @override
  String get videoEditorReverseLabel => 'Đảo ngược';

  @override
  String get videoEditorReverseClipSemanticLabel =>
      'Bật/tắt phát ngược cho clip đã chọn';

  @override
  String get videoEditorReverseProgressLabel =>
      'Một chút thôi, bọn mình đang đảo ngược clip của bạn';

  @override
  String get videoEditorTransformLabel => 'Biến đổi';

  @override
  String get videoEditorTransformSelectedClipSemanticLabel =>
      'Cắt, xoay hoặc lật clip đã chọn';

  @override
  String get videoEditorTransformProgressLabel =>
      'Một chút thôi, bọn mình đang biến đổi clip của bạn';

  @override
  String get videoEditorTransformFailed =>
      'Không biến đổi được clip. Vui lòng thử lại.';

  @override
  String get videoEditorTransformNoLocalFile =>
      'Không thể biến đổi: clip không có sẵn trên máy.';

  @override
  String get videoEditorTransformSelectedFrameSemanticLabel =>
      'Cắt, xoay hoặc lật khung hình đã chọn';

  @override
  String get videoEditorTransformFrameProgressLabel =>
      'Chờ chút, chúng tôi đang biến đổi khung hình của bạn';

  @override
  String get videoEditorTransformFrameFailed =>
      'Không thể biến đổi khung hình. Vui lòng thử lại.';

  @override
  String get videoEditorTransformRotateLabel => 'Xoay';

  @override
  String get videoEditorTransformFlipLabel => 'Lật';

  @override
  String get videoEditorTransformResetLabel => 'Đặt lại';

  @override
  String get videoEditorTransformApplySemanticLabel => 'Áp dụng biến đổi';

  @override
  String get videoEditorTransformCancelSemanticLabel => 'Hủy biến đổi';

  @override
  String get videoEditorTransformPlayLabel => 'Phát';

  @override
  String get videoEditorTransformPauseLabel => 'Tạm dừng';

  @override
  String get videoEditorReverseNoLocalFile =>
      'Không thể đảo ngược: clip không có sẵn trên máy.';

  @override
  String get videoEditorReverseFailed =>
      'Không đảo ngược được clip. Vui lòng thử lại.';

  @override
  String get videoEditorSpeedSheetTitle => 'Tốc độ clip';

  @override
  String get videoEditorTransitionSheetTitle => 'Chuyển cảnh';

  @override
  String get videoEditorTransitionNone => 'Không có';

  @override
  String get videoEditorTransitionDissolve => 'Hòa tan';

  @override
  String get videoEditorTransitionFadeToBlack => 'Mờ về đen';

  @override
  String get videoEditorTransitionFadeToWhite => 'Mờ về trắng';

  @override
  String get videoEditorTransitionSlide => 'Trượt';

  @override
  String get videoEditorTransitionPush => 'Đẩy';

  @override
  String get videoEditorTransitionWipe => 'Quét';

  @override
  String get videoEditorTransitionButtonSemanticLabel => 'Sửa chuyển cảnh';

  @override
  String get videoEditorLoopTransitionSheetTitle => 'Chuyển cảnh loop';

  @override
  String get videoEditorLoopTransitionButtonSemanticLabel =>
      'Sửa chuyển cảnh loop';

  @override
  String get videoEditorTransitionDuration => 'Thời lượng';

  @override
  String get videoEditorTransitionDurationLimitedHint =>
      'Đã rút ngắn để tránh chồng lấn chuyển cảnh bên cạnh.';

  @override
  String get videoEditorTransitionCurve => 'Đường cong';

  @override
  String get videoEditorTransitionDirection => 'Hướng';

  @override
  String get videoEditorTransitionDirectionLeft => 'Trái';

  @override
  String get videoEditorTransitionDirectionRight => 'Phải';

  @override
  String get videoEditorTransitionDirectionUp => 'Lên';

  @override
  String get videoEditorTransitionDirectionDown => 'Xuống';

  @override
  String videoEditorTransitionCurveOptionSemanticLabel(int number) {
    return 'Đường cong easing $number';
  }

  @override
  String get videoEditorLayerAnimationLabel => 'Hiệu ứng';

  @override
  String get videoEditorLayerAnimationButtonSemanticLabel => 'Sửa hiệu ứng lớp';

  @override
  String get videoEditorLayerAnimationEnter => 'Xuất hiện';

  @override
  String get videoEditorLayerAnimationLeave => 'Biến mất';

  @override
  String get videoEditorLayerAnimationFade => 'Mờ dần';

  @override
  String get videoEditorLayerAnimationScale => 'Thu phóng';

  @override
  String get videoEditorLayerAnimationScaleFrom => 'Thu phóng từ';

  @override
  String get videoEditorFinishTimelineEditingSemanticLabel =>
      'Hoàn tất chỉnh sửa timeline';

  @override
  String get videoEditorAudioPlayPreviewSemanticLabel => 'Phát thử';

  @override
  String get videoEditorAudioPausePreviewSemanticLabel => 'Tạm dừng nghe thử';

  @override
  String get videoEditorAudioUntitledSound => 'Âm thanh chưa đặt tên';

  @override
  String get videoEditorAudioUntitled => 'Chưa đặt tên';

  @override
  String get videoEditorAudioAddAudio => 'Thêm âm thanh';

  @override
  String get videoEditorAudioNoSoundsAvailableTitle => 'Không có âm thanh nào';

  @override
  String get videoEditorAudioNoSoundsAvailableSubtitle =>
      'Âm thanh sẽ xuất hiện ở đây khi nhà sáng tạo chia sẻ audio';

  @override
  String get videoEditorAudioFailedToLoadTitle => 'Không tải được âm thanh';

  @override
  String get videoEditorAudioSegmentInstruction =>
      'Chọn đoạn âm thanh cho video của bạn';

  @override
  String get videoEditorAudioCategoryDivine => 'Divine';

  @override
  String get videoEditorAudioCategoryCommunity => 'Cộng đồng';

  @override
  String get videoEditorAudioCategoryFeatured => 'Nổi bật';

  @override
  String get videoEditorAudioCategoryMySounds => 'Âm thanh của tôi';

  @override
  String get videoEditorDrawToolArrowSemanticLabel => 'Công cụ mũi tên';

  @override
  String get videoEditorDrawToolEraserSemanticLabel => 'Công cụ tẩy';

  @override
  String get videoEditorDrawToolMarkerSemanticLabel => 'Công cụ bút dạ';

  @override
  String get videoEditorDrawToolPencilSemanticLabel => 'Công cụ bút chì';

  @override
  String get videoEditorShowTimelineSemanticLabel => 'Hiện timeline';

  @override
  String get videoEditorHideTimelineSemanticLabel => 'Ẩn timeline';

  @override
  String get videoEditorFeedPreviewContent =>
      'Tránh đặt nội dung sau những khu vực này.';

  @override
  String get videoEditorStickersDivineOriginals => 'Divine Originals';

  @override
  String get videoEditorStickerSearchHint => 'Tìm nhãn dán...';

  @override
  String get videoEditorSelectFontSemanticLabel => 'Chọn phông chữ';

  @override
  String get videoEditorFontUnknown => 'Không xác định';

  @override
  String get videoEditorSplitPlayheadOutsideClip =>
      'Đầu phát phải nằm trong clip đã chọn để tách.';

  @override
  String get videoEditorTimelineTrimStartSemanticLabel => 'Cắt đầu';

  @override
  String get videoEditorTimelineTrimEndSemanticLabel => 'Cắt cuối';

  @override
  String get videoEditorTimelineTrimClipSemanticLabel => 'Cắt clip';

  @override
  String get videoEditorTimelineTrimClipHint =>
      'Kéo các tay cầm để điều chỉnh thời lượng clip';

  @override
  String videoEditorTimelineDraggingClipSemanticLabel(int index) {
    return 'Đang kéo clip $index';
  }

  @override
  String videoEditorTimelineClipSemanticLabel(
    int index,
    int total,
    String duration,
  ) {
    return 'Clip $index/$total, $duration giây';
  }

  @override
  String get videoEditorTimelineClipReorderHint => 'Nhấn giữ để sắp xếp lại';

  @override
  String get videoEditorTimelineClipMoveLeft => 'Dời sang trái';

  @override
  String get videoEditorTimelineClipMoveRight => 'Dời sang phải';

  @override
  String videoEditorTimelineClipSelectedSemanticLabel(int index, int total) {
    return 'Clip $index/$total, đã chọn';
  }

  @override
  String videoEditorTimelineClipUnselectedSemanticLabel(int index, int total) {
    return 'Clip $index/$total, chưa chọn';
  }

  @override
  String get videoEditorMultiSelectLabel => 'Chọn';

  @override
  String get videoEditorMultiSelectSemanticLabel => 'Chọn nhiều clip';

  @override
  String get videoEditorMultiSelectDoneSemanticLabel => 'Chọn clip xong';

  @override
  String videoEditorMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Đã chọn $count clip',
      one: 'Đã chọn 1 clip',
      zero: 'Chưa chọn clip nào',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorLayerMultiSelectSemanticLabel => 'Chọn nhiều hình vẽ';

  @override
  String get videoEditorLayerMultiSelectDoneSemanticLabel =>
      'Chọn hình vẽ xong';

  @override
  String get videoEditorDeleteSelectedDrawingsSemanticLabel =>
      'Xóa các hình vẽ đã chọn';

  @override
  String videoEditorLayerMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Đã chọn $count hình vẽ',
      one: 'Đã chọn 1 hình vẽ',
      zero: 'Chưa chọn hình vẽ nào',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorMergeLabel => 'Ghép';

  @override
  String get videoEditorMergeSelectedClipsSemanticLabel =>
      'Ghép các clip đã chọn';

  @override
  String get videoEditorDeleteSelectedClipsSemanticLabel =>
      'Xóa các clip đã chọn';

  @override
  String get videoEditorDeleteSelectedFramesSemanticLabel =>
      'Xóa các khung hình đã chọn';

  @override
  String get videoEditorReverseSelectedFramesSemanticLabel =>
      'Đảo ngược các khung hình đã chọn';

  @override
  String get videoEditorDuplicateSelectedFramesSemanticLabel =>
      'Nhân bản các khung hình đã chọn';

  @override
  String videoEditorStopMotionTooShortSnackbar(int seconds) {
    return 'Video của bạn cần ít nhất ${seconds}s — hãy chụp thêm vài khung hình.';
  }

  @override
  String get videoEditorMergeProgressLabel =>
      'Một chút thôi, bọn mình đang ghép các clip của bạn';

  @override
  String get videoEditorMergeFailed =>
      'Không ghép được các clip. Vui lòng thử lại.';

  @override
  String get videoEditorTimelineLongPressToDragHint => 'Nhấn giữ để kéo';

  @override
  String get videoEditorVideoTimelineSemanticLabel => 'Timeline video';

  @override
  String videoEditorTimelinePositionFormat(int minutes, String seconds) {
    return '$minutes phút $seconds giây';
  }

  @override
  String videoEditorColorSelectedSemanticLabel(String colorName) {
    return '$colorName, đã chọn';
  }

  @override
  String get videoEditorCloseColorPickerSemanticLabel => 'Đóng bộ chọn màu';

  @override
  String get videoEditorPickColorTitle => 'Chọn màu';

  @override
  String get videoEditorConfirmColorSemanticLabel => 'Xác nhận màu';

  @override
  String get videoEditorSaturationBrightnessSemanticLabel =>
      'Độ bão hòa và độ sáng';

  @override
  String videoEditorSaturationBrightnessValue(int saturation, int brightness) {
    return 'Độ bão hòa $saturation%, Độ sáng $brightness%';
  }

  @override
  String get videoEditorHueSemanticLabel => 'Tông màu';

  @override
  String get videoEditorAddElementSemanticLabel => 'Thêm phần tử';

  @override
  String get videoEditorDoneSemanticLabel => 'Xong';

  @override
  String get videoEditorLevelSemanticLabel => 'Mức';

  @override
  String get videoMetadataClosePostDetailsSemanticLabel =>
      'Đóng chi tiết bài đăng';

  @override
  String get videoMetadataDismissHelpDialogSemanticLabel =>
      'Đóng hộp thoại trợ giúp';

  @override
  String get videoMetadataGotItButton => 'Đã hiểu!';

  @override
  String get videoMetadataLimitReachedWarning =>
      'Đã đạt giới hạn 64KB. Bớt nội dung để tiếp tục.';

  @override
  String get videoMetadataExpirationLabel => 'Hết hạn';

  @override
  String get videoMetadataSelectExpirationSemanticLabel =>
      'Chọn thời gian hết hạn';

  @override
  String get videoMetadataTitleLabel => 'Tiêu đề';

  @override
  String get videoMetadataDescriptionLabel => 'Mô tả';

  @override
  String get videoMetadataTagsLabel => 'Thẻ';

  @override
  String videoMetadataDeleteTagHint(String tag) {
    return 'Xóa thẻ $tag';
  }

  @override
  String get videoMetadataContentWarningLabel => 'Thêm cảnh báo nội dung';

  @override
  String get videoMetadataSelectContentWarningsSemanticLabel =>
      'Chọn cảnh báo nội dung';

  @override
  String get videoMetadataContentWarningSelectAllThatApply =>
      'Chọn tất cả những gì áp dụng';

  @override
  String get videoMetadataAudioReuseSubtitle =>
      'Cho phép người khác lưu và dùng lại âm thanh của video này.';

  @override
  String get publishAudioReuseDegradedWarning =>
      'Video của bạn đã lên, nhưng âm thanh chưa đăng được. Chỉnh sửa video để chia sẻ âm thanh.';

  @override
  String get videoMetadataCollaboratorsLabel => 'Thêm cộng tác viên';

  @override
  String get videoMetadataAddCollaboratorSemanticLabel => 'Mời cộng tác viên';

  @override
  String get videoMetadataMutualFollowersSearchText =>
      'Người theo dõi lẫn nhau';

  @override
  String get videoMetadataInspiredByLabel => 'Thêm lấy cảm hứng từ';

  @override
  String get videoMetadataSetInspiredBySemanticLabel => 'Đặt lấy cảm hứng từ';

  @override
  String get videoMetadataCreatorCannotBeReferencedSnackbar =>
      'Không thể tham chiếu nhà sáng tạo này.';

  @override
  String get videoMetadataPostDetailsTitle => 'Chi tiết bài đăng';

  @override
  String get videoMetadataSavedToLibrarySnackbar => 'Đã lưu vào thư viện';

  @override
  String get videoMetadataFailedToSaveSnackbar => 'Không lưu được';

  @override
  String get videoMetadataGoToLibraryButton => 'Đi tới Thư viện';

  @override
  String get videoMetadataSaveForLaterSemanticLabel => 'Nút lưu để làm sau';

  @override
  String get videoMetadataSavingVideoHint => 'Đang lưu video...';

  @override
  String videoMetadataSaveToDraftsHint(String destination) {
    return 'Lưu video vào bản nháp và $destination';
  }

  @override
  String videoMetadataSaveToDraftsWithoutGalleryHint(String destination) {
    return 'Lưu video vào bản nháp. Chưa có video đã kết xuất nên không có bản sao trong $destination.';
  }

  @override
  String get videoMetadataSaveForLaterButton => 'Lưu để làm sau';

  @override
  String get videoMetadataPostSemanticLabel => 'Nút đăng';

  @override
  String get videoMetadataPublishVideoHint => 'Đăng video lên bảng tin';

  @override
  String get videoMetadataShareReplyToFeedTitle =>
      'Cũng chia sẻ lên bảng tin của tôi';

  @override
  String get videoMetadataShareReplyToFeedSubtitle =>
      'Tắt sẽ giữ video này chỉ trong chuỗi bình luận.';

  @override
  String get videoMetadataFormNotReadyHint => 'Điền vào biểu mẫu để bật';

  @override
  String get videoMetadataPostButton => 'Đăng';

  @override
  String get videoMetadataOpenPreviewSemanticLabel =>
      'Mở màn hình xem trước bài đăng';

  @override
  String get videoMetadataShareTitle => 'Chia sẻ';

  @override
  String get videoMetadataVideoDetailsSubtitle => 'Chi tiết video';

  @override
  String get videoMetadataClassicDoneButton => 'Xong';

  @override
  String get videoMetadataPlayPreviewSemanticLabel => 'Phát thử';

  @override
  String get videoMetadataPausePreviewSemanticLabel => 'Tạm dừng xem thử';

  @override
  String get videoMetadataClosePreviewSemanticLabel => 'Đóng xem trước video';

  @override
  String get videoMetadataRemoveSemanticLabel => 'Xóa';

  @override
  String get fullscreenFeedRemovedMessage => 'Video đã bị gỡ';

  @override
  String get fullscreenFeedEmptyMessage => 'Không còn gì để phát ở đây';

  @override
  String get settingsBadgesTitle => 'Huy hiệu';

  @override
  String get settingsBadgesSubtitle =>
      'Nhận giải thưởng và kiểm tra trạng thái huy hiệu đã phát.';

  @override
  String get badgesTitle => 'Huy hiệu';

  @override
  String get badgesLoadError => 'Không tải được huy hiệu';

  @override
  String get badgesUpdateError => 'Không cập nhật được huy hiệu';

  @override
  String get badgesAwardedEmptyTitle => 'Chưa có huy hiệu nào';

  @override
  String get badgesAwardedEmptySubtitle =>
      'Khi ai đó trao cho bạn một huy hiệu Nostr, nó sẽ xuất hiện ở đây.';

  @override
  String get badgesStatusAccepted => 'Đã chấp nhận';

  @override
  String get badgesStatusNotAccepted => 'Chưa chấp nhận';

  @override
  String get badgesActionRemove => 'Gỡ';

  @override
  String get badgesActionAccept => 'Chấp nhận';

  @override
  String get badgesActionReject => 'Từ chối';

  @override
  String get badgesIssuedEmptyTitle => 'Chưa phát huy hiệu nào';

  @override
  String get badgesIssuedEmptySubtitle =>
      'Huy hiệu bạn phát sẽ hiện trạng thái chấp nhận ở đây.';

  @override
  String get badgesIssuedNoRecipients =>
      'Không tìm thấy người nhận cho giải này.';

  @override
  String get badgesRecipientAcceptedStatus => 'Người nhận đã chấp nhận';

  @override
  String get badgesRecipientWaitingStatus => 'Đang chờ người nhận';

  @override
  String badgesHiddenSectionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Đã ẩn ($count)',
      one: 'Đã ẩn (1)',
    );
    return '$_temp0';
  }

  @override
  String get badgesActionRestore => 'Khôi phục';

  @override
  String get badgesHiddenSnackbar => 'Đã ẩn huy hiệu';

  @override
  String get badgesHiddenSnackbarUndo => 'Hoàn tác';

  @override
  String get badgesTabAwarded => 'Đã nhận';

  @override
  String get badgesTabCreated => 'Đã tạo';

  @override
  String get badgesTabIssued => 'Đã trao';

  @override
  String get badgesCreateAction => 'Huy hiệu mới';

  @override
  String get badgesCreatedEmptyTitle => 'Bạn chưa tạo huy hiệu nào';

  @override
  String get badgesCreatedEmptySubtitle =>
      'Tạo một cái và trao cho người xứng đáng.';

  @override
  String badgesCreatedAwardSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Đã trao cho $count người',
      one: 'Đã trao cho 1 người',
      zero: 'Chưa trao cho ai',
    );
    return '$_temp0';
  }

  @override
  String get badgeEditorCreateTitle => 'Huy hiệu mới';

  @override
  String get badgeEditorEditTitle => 'Sửa huy hiệu';

  @override
  String get badgeEditorNameLabel => 'Tên';

  @override
  String get badgeEditorNameHint => 'Kẻ cướp spotlight';

  @override
  String get badgeEditorIdentifierLabel => 'Định danh';

  @override
  String get badgeEditorIdentifierHelp =>
      'Đây là một phần địa chỉ của huy hiệu, nên nó cố định sau khi huy hiệu được tạo.';

  @override
  String get badgeEditorIdentifierTaken =>
      'Bạn đã có một huy hiệu với định danh này. Hãy sửa cái đó — đăng ở đây sẽ thay thế nó.';

  @override
  String get badgeEditorIdentifierRequired =>
      'Mỗi huy hiệu cần một định danh — hãy tự nhập nếu tên không điền giúp.';

  @override
  String get badgeEditorDescriptionLabel => 'Mô tả';

  @override
  String get badgeEditorDescriptionHint =>
      'Dành cho người cướp spotlight chỉ với một vòng lặp.';

  @override
  String get badgeEditorArtworkLabel => 'Hình ảnh';

  @override
  String get badgeEditorArtworkAdd => 'Thêm hình';

  @override
  String get badgeEditorArtworkReplace => 'Thay hình';

  @override
  String get badgeEditorArtworkError => 'Không tải lên được hình đó';

  @override
  String get badgeEditorArtworkRequired => 'Mỗi huy hiệu đều cần một hình ảnh.';

  @override
  String get badgeEditorArtworkRemove => 'Gỡ hình ảnh';

  @override
  String get badgeEditorArtworkSheetTitle => 'Hình ảnh huy hiệu';

  @override
  String get badgeDetailDeleteAction => 'Xoá huy hiệu';

  @override
  String get badgeDetailDeleteTitle => 'Xoá huy hiệu này?';

  @override
  String get badgeDetailDeleteBody =>
      'Thao tác này yêu cầu các relay bỏ huy hiệu và mọi lần trao mà bạn đã thực hiện. Relay có thể từ chối, và ai đã ghim nó vẫn giữ trên hồ sơ cho đến khi tự gỡ.';

  @override
  String get badgeDetailDeleteConfirm => 'Xoá';

  @override
  String get badgeEditorSaveAction => 'Đăng huy hiệu';

  @override
  String get badgeEditorSaveError => 'Không đăng được huy hiệu';

  @override
  String get badgeEditorLoadError => 'Không tải được huy hiệu này';

  @override
  String get badgeDetailTitle => 'Huy hiệu';

  @override
  String get badgeDetailMadeBy => 'Người tạo';

  @override
  String get badgeDetailRecipientsTitle => 'Đã trao cho';

  @override
  String get badgeDetailNoRecipients => 'Chưa ai có huy hiệu này.';

  @override
  String get badgeDetailAwardAction => 'Trao huy hiệu này';

  @override
  String get badgeDetailEditAction => 'Sửa huy hiệu';

  @override
  String get badgeDetailShareAction => 'Chia sẻ';

  @override
  String badgeDetailShareMessage(String link) {
    return 'Xem huy hiệu này trên Divine: $link';
  }

  @override
  String get badgeDetailRevokeAction => 'Thu hồi huy hiệu';

  @override
  String get badgeDetailRevokeTitle => 'Thu hồi huy hiệu này?';

  @override
  String get badgeDetailRevokeBody =>
      'Thao tác này yêu cầu các relay bỏ lần trao mà bạn đã dành cho người này. Relay có thể từ chối, và nếu họ đã ghim huy hiệu thì nó vẫn nằm trên hồ sơ cho đến khi họ tự gỡ. Dù thế nào, họ cũng không được báo.';

  @override
  String get badgeDetailRevokeSelfBody =>
      'Thao tác này yêu cầu các relay bỏ lần trao mà bạn đã dành cho chính mình, và gỡ huy hiệu khỏi hồ sơ của bạn. Nếu relay từ chối xoá, sẽ không có gì thay đổi.';

  @override
  String get badgeDetailRevokeConfirm => 'Thu hồi';

  @override
  String get badgeDetailRevokeSuccess => 'Đã thu hồi huy hiệu';

  @override
  String get badgeDetailBlockClaimantsAction => 'Chặn những người gắn huy hiệu';

  @override
  String get badgeDetailBlockClaimantsTitle => 'Chặn những người gắn huy hiệu';

  @override
  String get badgeDetailBlockClaimantsLoadError =>
      'Không tải được những người gắn huy hiệu này';

  @override
  String get badgeDetailBlockClaimantsEmptyTitle =>
      'Hiện chưa ai gắn huy hiệu này';

  @override
  String get badgeDetailBlockClaimantsEmptyBody =>
      'Chúng tôi không tìm thấy ai để chặn lúc này.';

  @override
  String badgeDetailBlockClaimantsHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Chặn $count tài khoản?',
      one: 'Chặn 1 tài khoản?',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Thao tác này chặn $count tài khoản đang gắn huy hiệu này. Bài đăng của họ sẽ không xuất hiện trong bảng tin của bạn và họ sẽ không được thông báo.',
      one:
          'Thao tác này chặn tài khoản đang gắn huy hiệu này. Bài đăng của họ sẽ không xuất hiện trong bảng tin của bạn và họ sẽ không được thông báo.',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Chặn $count tài khoản',
      one: 'Chặn 1 tài khoản',
    );
    return '$_temp0';
  }

  @override
  String get badgeDetailBlockClaimantsSuccess =>
      'Đã chặn những người gắn huy hiệu';

  @override
  String get badgeDetailBlockClaimantsFailure =>
      'Không chặn được những người gắn huy hiệu';

  @override
  String get badgeDetailLoadError => 'Không tải được huy hiệu này';

  @override
  String get badgeDetailMissing =>
      'Chúng tôi không tìm thấy huy hiệu này trên relay nào.';

  @override
  String get badgeDetailActionError => 'Thao tác không thành công';

  @override
  String get badgeAwardTitle => 'Trao huy hiệu';

  @override
  String get badgeAwardPickAction => 'Chọn người';

  @override
  String get badgeAwardManualLabel => 'Hoặc dán khoá';

  @override
  String get badgeAwardManualHint => 'npub1…, npub1…';

  @override
  String get badgeAwardEmptyHint => 'Chọn ít nhất một người.';

  @override
  String badgeAwardSubmitAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Trao cho $count người',
      one: 'Trao cho 1 người',
      zero: 'Trao huy hiệu',
    );
    return '$_temp0';
  }

  @override
  String get profileBadgeAwardedBy => 'Trao bởi';

  @override
  String get profileBadgeRecipients => 'Người nhận';

  @override
  String profileBadgeMoreRecipients(int count) {
    return '+$count người nữa';
  }

  @override
  String profileBadgeSemanticLabel(String name) {
    return 'Huy hiệu $name';
  }

  @override
  String get profileBadgeFallbackSemanticLabel => 'Huy hiệu';

  @override
  String get profileBadgeFooterBody =>
      'Huy hiệu là những phần thưởng nhỏ mà bất kỳ ai cũng có thể tạo trên Nostr. Tặng một huy hiệu cho bạn bè, nhà sáng tạo, hoặc người đã làm bừng sáng ngày của bạn.';

  @override
  String get profileBadgeFooterLink => 'Tạo huy hiệu của riêng bạn';

  @override
  String get minorAccountReviewWelcomePageTitle => 'Hướng dẫn gia đình';

  @override
  String get minorAccountReviewWelcomeTitle => 'Chưa đủ 16? Không sao cả.';

  @override
  String get minorAccountReviewWelcomeBody =>
      'Nếu bạn bấm vào trang này thay vì chỉ chọn câu trả lời giúp mình vào được, điều đó rất đáng quý. Nó cho thấy sự trung thực, bản lĩnh và sự quan tâm thật sự tới những người xung quanh.\n\nQuy định cho người dưới 16 tuổi khác nhau tùy nơi bạn sống. Ở Divine, bọn mình muốn các gia đình cùng nhau trò chuyện và quyết định thế nào là dùng mạng xã hội lành mạnh.';

  @override
  String get minorAccountReviewModerationTitle =>
      'Bọn mình cần thêm một bước nữa';

  @override
  String get minorAccountReviewModerationBody =>
      'Bọn mình được yêu cầu xem xét kỹ hơn tài khoản này vì nó có thể thuộc về người dưới 16 tuổi. Quy trình này giữ riêng tư các bước tiếp theo và chỉ cho bạn con đường phù hợp với độ tuổi của mình.';

  @override
  String get minorAccountReviewRulesTitle =>
      'Quy định không giống nhau ở mọi nơi';

  @override
  String get minorAccountReviewRulesBody =>
      'Các quốc gia và khu vực khác nhau có cách khác nhau với việc dùng mạng xã hội của thanh thiếu niên. Đó là lý do bọn mình đề nghị các gia đình chậm lại, kiểm tra thông tin, và cùng nhau chọn bước tiếp theo.';

  @override
  String get minorAccountReviewApproachTitle =>
      'Divine nghĩ về việc này thế nào';

  @override
  String get minorAccountReviewApproachBody =>
      'Bọn mình tin thói quen công nghệ lành mạnh đến từ việc dừng lại, suy ngẫm và hướng sự chú ý tới những điều tốt hơn, chứ không phải từ việc do thám trẻ em hay biến cha mẹ thành người giám sát hành lang. Nghiên cứu cũng ủng hộ điều đó.';

  @override
  String get minorAccountReviewLearnMoreTitle => 'Thêm cho gia đình';

  @override
  String get minorAccountReviewKidsPolicyCta =>
      'Đọc chính sách trẻ em của Divine';

  @override
  String get minorAccountReviewChooseAgeBandTitle => 'Chọn con đường phù hợp';

  @override
  String get minorAccountReviewUnder13Cta => 'Dưới 13';

  @override
  String get minorAccountReviewTeenCta => '13-15 tuổi';

  @override
  String get minorAccountReviewFamilyResourcesBody =>
      'Ghé hướng dẫn gia đình Divine để có mẹo thực tế, công cụ trò chuyện và tài nguyên giúp thanh thiếu niên dùng mạng xã hội an toàn hơn.';

  @override
  String get minorAccountReviewFamilyResourcesCta =>
      'Xem hướng dẫn và mẹo cho gia đình';

  @override
  String get minorAccountReviewFooter =>
      'Nếu bạn đủ 16 tuổi và bị đưa tới đây do nhầm lẫn, hãy liên hệ hỗ trợ Divine để một người thật xem xét.';

  @override
  String get minorAccountReviewTitle => 'Xem xét tài khoản';

  @override
  String get minorAccountReviewCheckingStatusTitle =>
      'Đang kiểm tra trạng thái tài khoản...';

  @override
  String get minorAccountReviewCheckingStatusBody =>
      'Vui lòng chờ trong khi bọn mình xác nhận trạng thái xem xét hiện tại của tài khoản này.';

  @override
  String get minorAccountReviewDefaultTitle => 'Cần xem xét tài khoản';

  @override
  String get minorAccountReviewDefaultBody =>
      'Bọn mình cần xem xét tài khoản này trước khi nó có thể dùng Divine bình thường.';

  @override
  String minorAccountReviewCaseId(String caseId) {
    return 'Mã hồ sơ: $caseId';
  }

  @override
  String get minorAccountReviewCaseIdShortLabel => 'Mã hồ sơ';

  @override
  String get minorAccountReviewRestrictionsTitle => 'Những gì đang bị hạn chế';

  @override
  String get minorAccountReviewRestrictionPosting =>
      'Đăng và xuất bản đang tạm dừng';

  @override
  String get minorAccountReviewRestrictionEngagement =>
      'Bình luận, thích, đăng lại và theo dõi đang tạm dừng';

  @override
  String get minorAccountReviewRestrictionMessaging =>
      'Bắt đầu hoặc trả lời tin nhắn thường đang tạm dừng';

  @override
  String get minorAccountReviewRestrictionSupport =>
      'Hỗ trợ và tin nhắn kiểm duyệt của bạn vẫn khả dụng';

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
  String get minorAccountReviewOpenSupportCenter => 'Mở Trung tâm hỗ trợ';

  @override
  String get minorAccountReviewOpenModerationMessage =>
      'Mở tin nhắn kiểm duyệt';

  @override
  String get minorAccountReviewOpenReviewPage => 'Mở trang xem xét';

  @override
  String get minorAccountReviewCheckAgain => 'Kiểm tra lại';

  @override
  String get minorAccountReviewLogOut => 'Đăng xuất';

  @override
  String get minorAccountReviewNextStepTitle => 'Bước tiếp theo';

  @override
  String get minorAccountReviewNextStepBody =>
      'Mở trung tâm hỗ trợ hoặc tin nhắn kiểm duyệt của bạn nếu cần giúp với việc xem xét này.';

  @override
  String get minorAccountReviewInProgressTitle => 'Đang xem xét';

  @override
  String get minorAccountReviewInProgressBody =>
      'Bọn mình đã có đủ thông tin cần thiết. Đội ngũ của bọn mình đang xem xét hồ sơ này trước khi khôi phục quyền truy cập bình thường.';

  @override
  String get minorAccountReviewUnder13Title => 'Tài khoản dưới 13';

  @override
  String minorAccountReviewUnder13Body(String supportEmail) {
    return 'Nếu tài khoản này thuộc về người dưới 13, cha mẹ hoặc người giám hộ phải email $supportEmail kèm mã hồ sơ.';
  }

  @override
  String get minorAccountReviewUnder13PublicTitle =>
      'Bọn mình chưa thể cấp tài khoản cho bạn';

  @override
  String get minorAccountReviewUnder13PublicBody =>
      'Divine không được xây cho trẻ dưới 13 và các quy định mạng xã hội trên thế giới buộc bọn mình phải tuân theo.\n\nNhiều thứ trên internet xúi bạn nói dối để có được thứ mình muốn, và bọn mình ghét điều đó. Đó là bài học sai cho cuộc sống, và bọn mình sẽ không dạy bạn điều đó ở đây.';

  @override
  String get minorAccountReviewUnder13FamilyTitle =>
      'Gia đình bạn có thể làm gì thay thế';

  @override
  String get minorAccountReviewUnder13FamilyBody =>
      'Cha mẹ hoặc người giám hộ có thể giữ tài khoản và đăng bài, và bạn hoàn toàn có thể xuất hiện trong video cùng họ. Bọn mình muốn các gia đình tận hưởng Divine theo cách phù hợp với họ.';

  @override
  String get minorAccountReviewUnder13ComeBackTitle => 'Khi bạn tròn 13';

  @override
  String get minorAccountReviewUnder13ComeBackBody =>
      'Tùy quy định nơi bạn sống, bạn có thể quay lại và đăng ký tài khoản riêng. Trong trường hợp đó, nếu bạn từ 13 đến 15 tuổi, bạn sẽ cần sự đồng ý của cha mẹ hoặc người giám hộ.';

  @override
  String get minorAccountReviewUnder13HonestyTitle =>
      'Tại sao bọn mình không bảo bạn cứ bấm quay lại';

  @override
  String get minorAccountReviewUnder13HonestyBody =>
      'Phần lớn internet được thiết kế để thưởng cho những người nói bất cứ gì giúp họ qua được cổng. Bọn mình không thấy điều đó hay. Vâng, bạn có thể quay lại và nói mình lớn tuổi hơn thật, nhưng điều đó không trung thực, và bọn mình sẽ không hướng dẫn bạn nói dối để có được thứ mình muốn.';

  @override
  String get minorAccountReviewUnder13LegalBody =>
      'Bọn mình đang cố giúp người trẻ dùng Divine theo cách lành mạnh và tích cực cho họ và những người xung quanh. Bọn mình cũng phải tuân theo luật vốn khác nhau tùy nơi. Vì vậy, nếu bạn dưới 13, câu trả lời là hôm nay bạn chưa thể có tài khoản riêng.';

  @override
  String get minorAccountReviewTeenBody =>
      'Nếu tài khoản này thuộc về người từ 13 đến 15, hãy dùng tin nhắn kiểm duyệt hoặc đường hỗ trợ để làm theo hướng dẫn về sự đồng ý của phụ huynh.';

  @override
  String get minorAccountReviewParentConsentTitle =>
      'Nếu tài khoản sẽ thuộc về người từ 13 đến 15';

  @override
  String get minorAccountReviewParentConsentBody =>
      'Cha mẹ hoặc người giám hộ nên email hỗ trợ Divine kèm một video riêng tư ngắn. Đội ngũ của bọn mình sẽ xem xét và hướng dẫn các bước tiếp theo.\n\nNếu không thể liên hệ cha mẹ hoặc người giám hộ, hoặc việc đó sẽ khiến ai đó gặp nguy hiểm, hãy email hỗ trợ Divine và cho bọn mình biết.';

  @override
  String get minorAccountReviewParentConsentPauseNote =>
      'Đây là khoảng tạm dừng trong khi đội hỗ trợ Divine xem xét video. Nếu được duyệt, họ sẽ hướng dẫn bạn thiết lập tài khoản mới.';

  @override
  String get minorAccountReviewParentConsentHonestyTitle =>
      'Tại sao bọn mình mời cha mẹ hoặc người giám hộ tham gia';

  @override
  String get minorAccountReviewParentConsentHonestyBody =>
      'Divine phải tuân theo các luật về độ tuổi trên thế giới. Bọn mình cũng biết rằng hầu hết các cổng tuổi kỹ thuật đều không hoàn hảo. Thay vì giả vờ quy định không tồn tại hay cho rằng nói dối tuổi là ngầu, bọn mình muốn thanh thiếu niên và gia đình đưa ra quyết định chu đáo về cách dùng Divine tốt nhất. Đó là lý do, với các bạn 13-15 tuổi, bọn mình mời cha mẹ tham gia vào quá trình tạo tài khoản.';

  @override
  String get minorAccountReviewParentConsentLegalBody =>
      'Bọn mình cũng phải tuân theo luật, và những quy định đó khác nhau tùy nơi người đó sống. Vì vậy, thay vì giả vờ quy định không tồn tại, bọn mình đề nghị cha mẹ hoặc người giám hộ tham gia vào quá trình.';

  @override
  String get minorAccountReviewParentConsentChecklist =>
      'Video cần thể hiện gì';

  @override
  String get minorAccountReviewParentConsentChecklistKid =>
      'Bạn teen trong video';

  @override
  String get minorAccountReviewParentConsentChecklistPermission =>
      'Cha mẹ hoặc người giám hộ nói trên camera';

  @override
  String get minorAccountReviewParentConsentChecklistAgeBand =>
      'Tuyên bố rõ ràng rằng bạn teen từ 13 đến 15 và được phép dùng Divine';

  @override
  String get minorAccountReviewParentConsentChecklistSupervision =>
      'Tuyên bố rõ ràng rằng cha mẹ hoặc người giám hộ biết về tài khoản này và sẽ giám sát việc sử dụng';

  @override
  String get minorAccountReviewParentConsentPrivacy => 'Cách gửi';

  @override
  String get minorAccountReviewParentConsentNeverPost =>
      'Đính kèm video khi bạn email hỗ trợ Divine';

  @override
  String get minorAccountReviewParentConsentDoNotSave =>
      'Giữ video riêng tư và không đăng nó trong ứng dụng';

  @override
  String get minorAccountReviewParentConsentOneMove =>
      'Đội ngũ của bọn mình sẽ xem xét và trả lời các bước tiếp theo';

  @override
  String get minorAccountReviewParentConsentEmailCta => 'Email hỗ trợ Divine';

  @override
  String get minorAccountReviewParentConsentEmailSubject =>
      'Trợ giúp xem xét Divine Greenlight (13-15 tuổi)';

  @override
  String get minorAccountReviewParentConsentEmailBody =>
      'Chào đội hỗ trợ Divine,\n\nTôi liên hệ Divine về Divine Greenlight cho một bạn teen 13-15 tuổi.\n\nTôi đã đính kèm một video riêng tư ngắn thể hiện:\n- bạn teen\n- cha mẹ hoặc người giám hộ nói trên camera\n- rằng bạn teen được phép dùng Divine\n- rằng cha mẹ hoặc người giám hộ biết về tài khoản này và sẽ giám sát việc sử dụng\n\nQuốc gia cư trú:\n\nBối cảnh hữu ích:\n\nCảm ơn.';

  @override
  String get minorAccountReviewParentSupportInstructions =>
      'Hướng dẫn hỗ trợ phụ huynh';

  @override
  String get minorAccountReviewContinue => 'Tiếp tục';

  @override
  String get minorAccountReviewErrorTitle =>
      'Bọn mình không tải được trạng thái xem xét tài khoản của bạn.';

  @override
  String get minorAccountReviewErrorBody => 'Vui lòng thử lại sau ít phút.';

  @override
  String get minorAccountReviewTryAgain => 'Thử lại';

  @override
  String get minorAccountReviewParentContactTitle => 'Liên hệ phụ huynh';

  @override
  String get minorAccountReviewParentContactHeading =>
      'Thêm email cha mẹ hoặc người giám hộ';

  @override
  String minorAccountReviewParentContactBody(String caseId) {
    return 'Bọn mình sẽ dùng địa chỉ này cho việc xem xét sự đồng ý của phụ huynh cho hồ sơ $caseId.';
  }

  @override
  String get minorAccountReviewParentContactFieldLabel =>
      'Email cha mẹ hoặc người giám hộ';

  @override
  String get minorAccountReviewSubmitting => 'Đang gửi...';

  @override
  String get minorAccountReviewSubmitEmail => 'Gửi email';

  @override
  String get minorAccountReviewBackToReview => 'Quay lại Xem xét tài khoản';

  @override
  String get minorAccountReviewSubmissionReceivedTitle => 'Đã gửi email';

  @override
  String minorAccountReviewSubmissionReceivedBody(String email) {
    return 'Bọn mình đã gửi $email để xem xét. Bọn mình sẽ email địa chỉ này để xác nhận. Khi cha mẹ hoặc người giám hộ của bạn phản hồi, hồ sơ của bạn sẽ tiến triển. Dùng Kiểm tra lại từ màn hình xem xét tài khoản để cập nhật.';
  }

  @override
  String get minorAccountReviewSubmissionReceivedLocalBody =>
      'Bọn mình đã nhận được liên hệ cha mẹ hoặc người giám hộ cho tài khoản này. Đội ngũ của bọn mình sẽ xem xét trước khi khôi phục quyền truy cập.';

  @override
  String get minorAccountReviewMissingCase =>
      'Bọn mình không tìm thấy hồ sơ xem xét đang hoạt động cho tài khoản này.';

  @override
  String get minorAccountReviewParentContactError =>
      'Không gửi được email phụ huynh. Vui lòng thử lại.';

  @override
  String get minorAccountReviewUnder13SupportTitle => 'Hỗ trợ phụ huynh';

  @override
  String get minorAccountReviewUnder13Heading =>
      'Cha mẹ hoặc người giám hộ phải liên hệ Divine';

  @override
  String get minorAccountReviewUnder13SupportBody =>
      'Với các tài khoản có khả năng dưới 13, bước tiếp theo là cha mẹ hoặc người giám hộ liên hệ qua email.';

  @override
  String get minorAccountReviewSupportEmailLabel => 'Email hỗ trợ';

  @override
  String get minorAccountReviewCopySupportEmail => 'Sao chép email hỗ trợ';

  @override
  String get minorAccountReviewSupportEmailCopied => 'Đã sao chép email hỗ trợ';

  @override
  String get minorAccountReviewCopyCaseId => 'Sao chép mã hồ sơ';

  @override
  String get minorAccountReviewCaseIdCopied => 'Đã sao chép mã hồ sơ';

  @override
  String get minorAccountReviewUnavailable => 'Không khả dụng';

  @override
  String get minorAccountReviewUnder13Instructions =>
      'Nhờ cha mẹ hoặc người giám hộ ghi kèm mã hồ sơ và giải thích rằng họ đang liên hệ Divine về việc xem xét tài khoản này.';

  @override
  String minorAccountReviewUnder13EmailSubject(String caseId) {
    return 'Xem xét tài khoản dưới 13 cho hồ sơ $caseId';
  }

  @override
  String minorAccountReviewUnder13EmailBody(String caseId) {
    return 'Chào đội hỗ trợ Divine,\n\nTôi là cha mẹ hoặc người giám hộ của một bé dưới 13 tuổi và tôi liên hệ Divine về hồ sơ xem xét tài khoản $caseId.\n\nCảm ơn.';
  }

  @override
  String get devOptionsMinorReviewSimulationTitle =>
      'Mô phỏng xem xét tài khoản vị thành niên';

  @override
  String get devOptionsMinorReviewCurrentStateLabel => 'Trạng thái hiện tại';

  @override
  String devOptionsMinorReviewStateRestricted(String state) {
    return 'Bị hạn chế ($state)';
  }

  @override
  String get devOptionsMinorReviewStateActive => 'Đang hoạt động';

  @override
  String get devOptionsMinorReviewStateLoading => 'Đang tải...';

  @override
  String get devOptionsMinorReviewStateError => 'Lỗi khi tải trạng thái';

  @override
  String get devOptionsMinorReviewClearTitle => 'Xóa ghi đè mô phỏng';

  @override
  String get devOptionsMinorReviewClearSubtitle =>
      'Dùng lại trạng thái backend hoặc mặc định';

  @override
  String get devOptionsMinorReviewTeenTitle => 'Mô phỏng hồ sơ xem xét 13-15';

  @override
  String get devOptionsMinorReviewTeenSubtitle =>
      'Tài khoản bị hạn chế với đường liên hệ phụ huynh';

  @override
  String get devOptionsMinorReviewUnder13Title =>
      'Mô phỏng hồ sơ hỗ trợ dưới 13';

  @override
  String get devOptionsMinorReviewUnder13Subtitle =>
      'Tài khoản bị hạn chế chỉ với hướng dẫn email phụ huynh';

  @override
  String get devOptionsMinorReviewClearedToast =>
      'Đã xóa mô phỏng xem xét tài khoản vị thành niên';

  @override
  String get devOptionsMinorReviewUnder13EnabledToast =>
      'Đã bật mô phỏng hồ sơ hỗ trợ dưới 13';

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
      'Mô phỏng vị thành niên được bảo vệ';

  @override
  String get devOptionsProtectedMinorCurrentStateLabel => 'Trạng thái hiện tại';

  @override
  String get devOptionsProtectedMinorStateProtected =>
      'Vị thành niên được bảo vệ (13-15)';

  @override
  String get devOptionsProtectedMinorStateNotProtected => 'Không được bảo vệ';

  @override
  String get devOptionsProtectedMinorStateLoading => 'Đang tải…';

  @override
  String get devOptionsProtectedMinorStateError => 'Lỗi khi đọc trạng thái';

  @override
  String get devOptionsProtectedMinorOverrideNone =>
      'Không ghi đè (trạng thái tài khoản thật)';

  @override
  String get devOptionsProtectedMinorOverrideProtected =>
      'Ghi đè: ép được bảo vệ';

  @override
  String get devOptionsProtectedMinorOverrideNotProtected =>
      'Ghi đè: ép không được bảo vệ';

  @override
  String get devOptionsProtectedMinorSimulateTitle =>
      'Mô phỏng vị thành niên được bảo vệ (13-15)';

  @override
  String get devOptionsProtectedMinorSimulateSubtitle =>
      'Ép trạng thái vị thành niên được bảo vệ để QA các biện pháp bảo vệ #175/#176';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorTitle =>
      'Mô phỏng không phải vị thành niên';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorSubtitle =>
      'Ép không được bảo vệ (phủ định rõ ràng, khác với không ghi đè)';

  @override
  String get devOptionsProtectedMinorClearTitle => 'Xóa ghi đè';

  @override
  String get devOptionsProtectedMinorClearSubtitle =>
      'Quay về trạng thái tài khoản thật do Keycast điều khiển';

  @override
  String get devOptionsProtectedMinorEnabledToast =>
      'Đã ép bật trạng thái vị thành niên được bảo vệ';

  @override
  String get devOptionsProtectedMinorNonMinorToast =>
      'Đã ép tắt trạng thái vị thành niên được bảo vệ';

  @override
  String get devOptionsProtectedMinorClearedToast =>
      'Đã xóa ghi đè vị thành niên được bảo vệ';

  @override
  String get devOptionsInviteAvailabilityTitle => 'Lời mời đăng ký';

  @override
  String get devOptionsInviteAvailabilityCurrentLabel => 'Trạng thái hiện tại';

  @override
  String get devOptionsInviteAvailabilityServerLoading =>
      'Giá trị máy chủ: đang tải';

  @override
  String get devOptionsInviteAvailabilityServerEnabled =>
      'Giá trị máy chủ: đã bật';

  @override
  String get devOptionsInviteAvailabilityServerDisabled =>
      'Giá trị máy chủ: đã tắt';

  @override
  String get devOptionsInviteAvailabilityServerUnknown =>
      'Giá trị máy chủ: không rõ';

  @override
  String get devOptionsInviteAvailabilityOverrideNone =>
      'Ghi đè: dùng giá trị máy chủ';

  @override
  String get devOptionsInviteAvailabilityOverrideEnabled => 'Ghi đè: buộc bật';

  @override
  String get devOptionsInviteAvailabilityOverrideDisabled => 'Ghi đè: buộc tắt';

  @override
  String get devOptionsInviteAvailabilityUseServer => 'Dùng giá trị máy chủ';

  @override
  String get devOptionsInviteAvailabilityUseServerSubtitle =>
      'Theo onboardingMode của dịch vụ lời mời';

  @override
  String get devOptionsInviteAvailabilityForceEnabled => 'Buộc bật';

  @override
  String get devOptionsInviteAvailabilityForceEnabledSubtitle =>
      'Hiển thị cổng lời mời đăng ký và phần quản lý ở máy này';

  @override
  String get devOptionsInviteAvailabilityForceDisabled => 'Buộc tắt';

  @override
  String get devOptionsInviteAvailabilityForceDisabledSubtitle =>
      'Ẩn giao diện lời mời đăng ký ở máy này mà không đổi máy chủ';

  @override
  String get devOptionsInviteAvailabilityUseServerToast =>
      'Lời mời đăng ký giờ theo máy chủ';

  @override
  String get devOptionsInviteAvailabilityForceEnabledToast =>
      'Đã buộc bật lời mời đăng ký';

  @override
  String get devOptionsInviteAvailabilityForceDisabledToast =>
      'Đã buộc tắt lời mời đăng ký';

  @override
  String get commentsRecordVideoButtonLabel => 'Quay bình luận video';

  @override
  String get commentsOpenVideoLabel => 'Mở bình luận video';

  @override
  String get commentsMuteVideoReplyLabel => 'Tắt tiếng video phản hồi';

  @override
  String get commentsUnmuteVideoReplyLabel => 'Bật tiếng video phản hồi';

  @override
  String get commentsOpenReplyParentLabel =>
      'Mở video mà nội dung này phản hồi';

  @override
  String get commentsReplyParentSectionTitle => 'Phản hồi';

  @override
  String commentsReplyParentLabel(String target) {
    return 'Phản hồi $target';
  }

  @override
  String get commentsReplyParentFallbackLabel => 'Phản hồi video';

  @override
  String verifiedAccountChipSemanticLabel(String platform, String identity) {
    return 'Tài khoản $platform đã xác minh: $identity';
  }

  @override
  String get profileEditVerifiedAccountsTitle => 'Tài khoản đã xác minh';

  @override
  String get profileEditGetVerifiedCta => 'Được xác minh';

  @override
  String get profileEditGetVerifiedSubtitle =>
      'Liên kết tài khoản mạng xã hội của bạn để mọi người biết đó thật sự là bạn.';

  @override
  String profileWebsiteSemanticLabel(String url) {
    return 'Ghé website: $url';
  }

  @override
  String get profileCouldNotOpenWebsite => 'Không mở được website';

  @override
  String get videoMetadataEditCoverTitle => 'Chỉnh sửa ảnh bìa';

  @override
  String get videoMetadataEditCoverCloseSemanticLabel => 'Hủy thay đổi ảnh bìa';

  @override
  String get videoMetadataEditCoverConfirmSemanticLabel =>
      'Dùng khung hình đã chọn làm ảnh bìa video';

  @override
  String get videoMetadataEditCoverStripSemanticLabel =>
      'Tua video để chọn khung hình làm ảnh bìa';

  @override
  String get videoMetadataTagsPickerSearchHint => 'Tìm hoặc thêm thẻ';

  @override
  String get videoMetadataTagsPickerEmptyHint =>
      'Thêm thẻ để giúp mọi người khám phá video của bạn';

  @override
  String get videoMetadataTagsPickerNoResults => 'Không có thẻ phù hợp';

  @override
  String videoMetadataTagsPickerAddTag(String tag) {
    return 'Thêm \"#$tag\"';
  }

  @override
  String get authMinAgeNotice => 'Divine Greenlight';

  @override
  String get authUnder16Prefix => 'Chưa đủ 16? Không sao. ';

  @override
  String get authUnder16ChoicesCta => 'Đây là các lựa chọn của bạn.';

  @override
  String get minorAccountReviewUnder13WhyTitle => 'Đây là lý do';

  @override
  String get generalSettingsHoldToRecord => 'Giữ để quay';

  @override
  String get generalSettingsHoldToRecordSubtitle =>
      'Bắt đầu quay khi bạn nhấn giữ, dừng khi bạn thả ra';

  @override
  String uploadPublishedCountMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Đã đăng $count video lên hồ sơ của bạn',
      one: 'Đã đăng video lên hồ sơ của bạn',
    );
    return '$_temp0';
  }

  @override
  String get dmMessageSendLabel => 'Gửi tin nhắn';

  @override
  String get emojiPickerSearchHint => 'Tìm kiếm';

  @override
  String get emojiCategoryRecent => 'Gần đây';

  @override
  String get emojiCategorySmileys => 'Mặt cười & Con người';

  @override
  String get emojiCategoryAnimals => 'Động vật & Thiên nhiên';

  @override
  String get emojiCategoryFood => 'Đồ ăn & Thức uống';

  @override
  String get emojiCategoryActivities => 'Hoạt động';

  @override
  String get emojiCategoryTravel => 'Du lịch & Địa điểm';

  @override
  String get emojiCategoryObjects => 'Đồ vật';

  @override
  String get emojiCategorySymbols => 'Biểu tượng';

  @override
  String get emojiCategoryFlags => 'Cờ';

  @override
  String get videoEditorMarkerLabel => 'Đánh dấu';

  @override
  String get videoEditorAddTimelineMarkerSemanticLabel =>
      'Thêm đánh dấu timeline';

  @override
  String get videoEditorRemoveTimelineMarkerSemanticLabel =>
      'Xóa đánh dấu timeline';

  @override
  String get videoEditorRemoveTimelineMarkerAtPlayheadSemanticLabel =>
      'Xóa đánh dấu tại đầu phát';

  @override
  String get videoEditorDeleteTimelineMarkerTitle => 'Xóa đánh dấu?';

  @override
  String get videoEditorDeleteTimelineMarkerSubtitle =>
      'Thao tác này xóa đánh dấu khỏi timeline. Chỉnh sửa của bạn vẫn nguyên vẹn.';

  @override
  String get videoEditorVolumeLongPressHint =>
      'Tắt hoặc bật tiếng tất cả các rãnh';

  @override
  String get videoEditorSplitFailed => 'Tách thất bại. Vui lòng thử lại.';

  @override
  String get videoEditEditSubtitles => 'Chỉnh sửa phụ đề';

  @override
  String get subtitleEditorTitle => 'Chỉnh sửa phụ đề';

  @override
  String get subtitleEditorSave => 'Lưu';

  @override
  String get subtitleEditorProcessing =>
      'Phụ đề vẫn đang được tạo. Quay lại sau ít phút.';

  @override
  String get subtitleEditorNoSpeech =>
      'Không phát hiện giọng nói nào trong video này, nên không có gì để làm phụ đề.';

  @override
  String get subtitleEditorWriteOwn => 'Tự viết phụ đề';

  @override
  String get subtitleEditorAddCue => 'Thêm một dòng';

  @override
  String get subtitleEditorRemoveCue => 'Xoá dòng này';

  @override
  String get subtitleEditorPreviewUnavailable =>
      'Hiện không phát được video, nhưng bạn vẫn có thể sửa phụ đề.';

  @override
  String get subtitleEditorPlayPreview => 'Phát video';

  @override
  String get subtitleEditorPausePreview => 'Tạm dừng video';

  @override
  String get subtitleEditorInvalidHint =>
      'Mỗi dòng cần có nội dung và thời điểm kết thúc sau lúc bắt đầu.';

  @override
  String get subtitleEditorLoadError => 'Không tải được phụ đề. Thử lại nhé.';

  @override
  String get subtitleEditorSaveSuccess => 'Đã cập nhật phụ đề';

  @override
  String get subtitleEditorSaveError => 'Không lưu được phụ đề. Thử lại nhé.';

  @override
  String get subtitleEditorRetry => 'Thử lại';

  @override
  String get subtitleEditorCueHint => 'Nội dung phụ đề';

  @override
  String get imageCropEditorRotateLabel => 'Xoay';

  @override
  String get imageCropEditorFlipLabel => 'Lật';

  @override
  String get imageCropEditorResetLabel => 'Đặt lại';

  @override
  String get imageCropEditorCloseSemanticLabel => 'Hủy cắt';

  @override
  String get imageCropEditorDoneSemanticLabel => 'Áp dụng cắt';

  @override
  String get imageCropEditorProcessing => 'Đang áp dụng cắt…';

  @override
  String get backgroundUploadNotificationTitle => 'Đang tải video lên';

  @override
  String get monetizationSettingsTitle => 'Hỗ trợ nhà sáng tạo';

  @override
  String get monetizationSettingsSubtitle => 'Thêm liên kết tip và đăng ký';

  @override
  String get monetizationSettingsIntroTitle => 'Chỉ liên kết ra ngoài';

  @override
  String get monetizationSettingsIntroBody =>
      'Thêm các điểm đến do nhà sáng tạo kiểm soát. Divine không bao giờ xử lý thanh toán hay mở khóa nội dung trong ứng dụng từ các liên kết này.';

  @override
  String monetizationSettingsConfiguredCount(int count) {
    return '$count liên kết đang hoạt động trên hồ sơ của bạn';
  }

  @override
  String get monetizationSettingsTipSection => 'Gửi tip';

  @override
  String get monetizationSettingsSubscriptionSection => 'Đăng ký / ủng hộ';

  @override
  String get monetizationSettingsSave => 'Lưu liên kết hỗ trợ';

  @override
  String get monetizationSettingsSaving => 'Đang lưu...';

  @override
  String get monetizationSettingsSaved => 'Đã cập nhật liên kết hỗ trợ';

  @override
  String get monetizationSettingsSaveFailed =>
      'Không lưu được liên kết hỗ trợ. Kiểm tra kết nối của bạn rồi thử lại.';

  @override
  String get monetizationSettingsErrorEmpty => 'Thêm tên định danh hoặc URL.';

  @override
  String get monetizationSettingsErrorInvalid =>
      'Liên kết đó trông không đúng lắm.';

  @override
  String get monetizationSettingsErrorWrongProvider =>
      'Dùng liên kết của nhà cung cấp này.';

  @override
  String get monetizationSettingsHintCashApp =>
      '\$cashtag hoặc liên kết cash.app';

  @override
  String get monetizationSettingsHintPayPal =>
      'Tên định danh hoặc liên kết PayPal.me';

  @override
  String get monetizationSettingsHintVenmo =>
      'Tên định danh hoặc liên kết Venmo';

  @override
  String get monetizationSettingsHintPatreon =>
      'Tên định danh hoặc liên kết Patreon';

  @override
  String get monetizationSettingsHintSubstack =>
      'Tên miền hoặc liên kết Substack';

  @override
  String get monetizationSettingsHintMedium =>
      'Tên định danh hoặc liên kết Medium';

  @override
  String get monetizationSettingsHintOpenCollective =>
      'Slug hoặc liên kết Open Collective';

  @override
  String get profileSupportSheetTitle => 'Ủng hộ nhà sáng tạo này';

  @override
  String get profileSupportSheetBody =>
      'Các liên kết này mở bên ngoài Divine. Không có gì ở đây mở khóa nội dung trong ứng dụng.';

  @override
  String get profileSupportTipSection => 'Gửi tip';

  @override
  String get profileSupportSubscriptionSection => 'Đăng ký / ủng hộ';

  @override
  String get profileSupportButtonLabel => 'Ủng hộ';

  @override
  String get monetizationTipsSettingsTitle => 'Tip';

  @override
  String get monetizationTipsSettingsSubtitle => 'Thêm liên kết tip tùy chọn';

  @override
  String get monetizationTipsSettingsIntroTitle => 'Chỉ tip tùy chọn';

  @override
  String get monetizationTipsSettingsIntroBody =>
      'Tip là quà tùy chọn giữa người dùng với nhau. Chúng không mở khóa nội dung, đăng ký, tính năng, thứ hạng, khả năng hiển thị hay quyền truy cập trong Divine.';

  @override
  String monetizationTipsSettingsConfiguredCount(int count) {
    return '$count liên kết tip đang hoạt động trên hồ sơ của bạn';
  }

  @override
  String get monetizationTipsSettingsSave => 'Lưu liên kết tip';

  @override
  String get monetizationTipsSettingsSaved => 'Đã cập nhật liên kết tip';

  @override
  String get profileTipButtonLabel => 'Ủng hộ';

  @override
  String get profileTipSheetTitle => 'Tip nhà sáng tạo này';

  @override
  String get profileTipSheetBody =>
      'Tip mở bên ngoài Divine. Chúng là tùy chọn và không mở khóa nội dung, đăng ký, tính năng hay quyền truy cập trong Divine.';

  @override
  String get settingsStorageTitle => 'Dung lượng';

  @override
  String get settingsStorageCacheSectionTitle => 'Media đã lưu đệm';

  @override
  String get settingsStorageCacheDescription =>
      'Video bảng tin, ảnh thu nhỏ và bản kết xuất tạm đã lưu đệm. Xóa chúng là an toàn — chúng sẽ được tải lại hoặc tạo lại khi cần.';

  @override
  String get settingsStorageMeasuring => 'Đang đo…';

  @override
  String settingsStorageCacheInUse(String size) {
    return 'Đang dùng $size';
  }

  @override
  String get settingsStorageClearButton => 'Xóa bộ nhớ đệm';

  @override
  String get settingsStorageClearConfirmTitle => 'Xóa media đã lưu đệm?';

  @override
  String settingsStorageClearConfirmMessage(String size) {
    return 'Thao tác này giải phóng $size. Thư viện clip của bạn không bị ảnh hưởng.';
  }

  @override
  String get settingsStorageClearConfirmAction => 'Xóa';

  @override
  String get settingsStorageCleared => 'Đã xóa bộ nhớ đệm';

  @override
  String get settingsStorageLibrarySectionTitle => 'Thư viện clip';

  @override
  String get settingsStorageLibraryDescription =>
      'Kiểm tra các clip hỏng bị thiếu tệp video.';

  @override
  String get settingsStorageScanButton => 'Kiểm tra thư viện';

  @override
  String get settingsStorageLibraryHealthy => 'Không tìm thấy clip hỏng';

  @override
  String settingsStorageBrokenClipsFound(int count) {
    return 'Tìm thấy clip hỏng: $count';
  }

  @override
  String get settingsStorageRemoveBrokenButton => 'Xóa clip hỏng';

  @override
  String get settingsStorageBrokenClipsRemoved => 'Đã xóa clip hỏng';

  @override
  String get settingsStorageError => 'Có gì đó không ổn';

  @override
  String get settingsStorageMaxVideoCacheLabel => 'Bộ nhớ đệm video tối đa';

  @override
  String settingsStorageApproxVideos(int count) {
    return '≈ $count video';
  }

  @override
  String get settingsStorageRemoveBrokenConfirmTitle => 'Xóa các clip hỏng?';

  @override
  String get settingsStorageRepairSectionTitle => 'Sửa bản cài đặt';

  @override
  String get settingsStorageRepairDescription =>
      'Nếu ứng dụng cứ bị lỗi hoặc chạy lạ, đặt lại dữ liệu cục bộ thường sẽ khắc phục được. Clip và bản nháp của bạn vẫn còn.';

  @override
  String get settingsStorageRepairButton => 'Đặt lại dữ liệu ứng dụng';

  @override
  String get settingsStorageRepairConfirmTitle => 'Đặt lại dữ liệu ứng dụng?';

  @override
  String get settingsStorageRepairConfirmMessage =>
      'Thao tác này xóa dữ liệu bảng tin đã lưu tạm và tệp tạm. Clip, bản nháp, cài đặt và phiên đăng nhập của bạn vẫn còn, nhưng sau đó bạn phải khởi động lại ứng dụng.';

  @override
  String settingsStorageRepairFootprint(String size) {
    return 'Sẽ xóa $size';
  }

  @override
  String get settingsStorageRepairConfirmAction => 'Đặt lại';

  @override
  String get settingsStorageRepairInProgress => 'Đang đặt lại…';

  @override
  String get settingsStorageRepairSuccess =>
      'Xong — khởi động lại ứng dụng để hoàn tất.';

  @override
  String get settingsStorageRepairFailure =>
      'Không đặt lại được tất cả. Thử lại sau khi khởi động lại.';

  @override
  String get nostrSettingsSignatureVerification => 'Xác minh chữ ký';

  @override
  String get nostrSettingsSignatureVerificationIntro =>
      'Chọn khi nào Divine kiểm tra chữ ký sự kiện của relay. ID sự kiện luôn được xác thực trước.';

  @override
  String get nostrSettingsSignatureVerificationAll => 'Tất cả relay';

  @override
  String get nostrSettingsSignatureVerificationAllSubtitle =>
      'An toàn nhất. Xác minh chữ ký của mọi sự kiện relay.';

  @override
  String get nostrSettingsSignatureVerificationUntrusted =>
      'Relay không tin cậy';

  @override
  String get nostrSettingsSignatureVerificationUntrustedSubtitle =>
      'Bỏ qua kiểm tra cho các relay đã có trong nhóm cấu hình của bạn.';

  @override
  String get nostrSettingsSignatureVerificationNonDivine =>
      'Relay không phải Divine';

  @override
  String get nostrSettingsSignatureVerificationNonDivineSubtitle =>
      'Tin tưởng relay Divine, xác minh phần còn lại.';

  @override
  String get settingsCrosspostingTitle => 'Đăng chéo';

  @override
  String get settingsCrosspostingSubtitle =>
      'Chia sẻ video của bạn lên các nền tảng khác';

  @override
  String get crosspostingSignInRequired =>
      'Đăng nhập bằng Divine để quản lý đăng chéo';

  @override
  String get crosspostingLoadFailed =>
      'Không tải được cài đặt đăng chéo của bạn';

  @override
  String get crosspostingNoPlatforms =>
      'Hiện chưa có nền tảng đăng chéo nào khả dụng';

  @override
  String get crosspostingRetry => 'Thử lại';

  @override
  String get crosspostingNotConnected => 'Chưa kết nối';

  @override
  String get crosspostingConnected => 'Đã kết nối';

  @override
  String get crosspostingNeedsReconnect => 'Cần kết nối lại';

  @override
  String get crosspostingConnect => 'Kết nối';

  @override
  String get crosspostingReconnect => 'Kết nối lại';

  @override
  String get crosspostingDisconnect => 'Ngắt kết nối';

  @override
  String get crosspostingModeOff => 'Tắt';

  @override
  String get crosspostingModeManual => 'Thủ công';

  @override
  String get crosspostingModeManualSubtitle => 'Bạn chọn cho từng video';

  @override
  String get crosspostingModeAutomatic => 'Tự động';

  @override
  String get crosspostingModeAutomaticSubtitle =>
      'Các video sau sẽ tự đăng — chỉ những video bạn đăng sau khi bật cái này';

  @override
  String get crosspostingNotConnectedError =>
      'Kết nối nền tảng này trước đã để đổi cách nó đăng.';

  @override
  String get crosspostingGenericError => 'Có gì đó không ổn. Thử lại nhé.';

  @override
  String get crosspostingCallbackTimeoutError =>
      'Trang đăng nhập không phản hồi. Nếu bạn đã kết nối xong ở đó, hãy làm mới — tài khoản của bạn có thể đã được liên kết rồi.';

  @override
  String crosspostingConnectionSuccess(String platform) {
    return 'Đã kết nối $platform';
  }

  @override
  String crosspostingConnectionFailed(String platform) {
    return 'Không kết nối được $platform';
  }

  @override
  String crosspostingConnectionDenied(String platform) {
    return 'Kết nối đã bị hủy trên $platform';
  }

  @override
  String get supporterTitle => 'Người ủng hộ Divine';

  @override
  String get supporterTileSubtitle =>
      'Ủng hộ Divine bằng gói đăng ký hàng tháng tùy chọn.';

  @override
  String get supporterHeroTitle => 'Giữ Divine hoạt động';

  @override
  String get supporterHeroBody =>
      'Divine miễn phí và sẽ luôn như vậy. Nếu bạn muốn giúp bọn mình giữ những vòng loop chạy tiếp, hãy trở thành người ủng hộ hàng tháng. Không có gì bị khóa — chỉ là giúp duy trì hoạt động và nhận lời cảm ơn của bọn mình.';

  @override
  String get supporterActiveBadge =>
      'Bạn là Người ủng hộ Divine. Cảm ơn bạn đã giữ cho điều này tiếp tục.';

  @override
  String get supporterPurchasePending =>
      'Giao dịch mua của bạn đang chờ phê duyệt.';

  @override
  String get supporterPurchaseConfirming => 'Đang xác nhận sự ủng hộ của bạn…';

  @override
  String get supporterStoreChecking => 'Đang kiểm tra cửa hàng…';

  @override
  String get supporterUnavailable =>
      'Gói đăng ký ủng hộ hiện không khả dụng ở đây.';

  @override
  String get supporterRestorePurchases => 'Khôi phục giao dịch mua';

  @override
  String get supporterDismissError => 'Bỏ qua lỗi';

  @override
  String get supporterErrorStoreUnavailable =>
      'Cửa hàng không khả dụng trên thiết bị này.';

  @override
  String get supporterErrorPurchaseFailed =>
      'Giao dịch mua không hoàn tất. Bạn không bị trừ tiền.';

  @override
  String get supporterErrorPurchasePending =>
      'Giao dịch mua của bạn đang chờ phê duyệt.';

  @override
  String get supporterErrorRestoreFailed =>
      'Không tìm thấy gói đăng ký ủng hộ nào để khôi phục.';

  @override
  String get supporterErrorOwnershipConflict =>
      'Giao dịch mua này thuộc về một tài khoản Divine khác.';

  @override
  String get supporterErrorVerificationUnavailable =>
      'Divine hiện không xác nhận được trạng thái người ủng hộ.';

  @override
  String get supporterErrorUnknown => 'Có gì đó không ổn. Vui lòng thử lại.';

  @override
  String get supporterDisclaimer =>
      'Divine xác nhận trạng thái người ủng hộ sau khi cửa hàng xác minh giao dịch mua của bạn. Việc ghi nhận là tùy chọn, và vòng hào quang không phải là xác minh danh tính.';

  @override
  String get profileNotifyBellOff => 'Nhận thông báo về vine mới';

  @override
  String get profileNotifyBellOn => 'Ngừng thông báo về vine mới';

  @override
  String get profileNotifyUpdateFailed => 'Không lưu được. Thử lại nhé?';

  @override
  String get savedSoundYourLabel => 'Nhãn của bạn';

  @override
  String get savedSoundAddHashtags => 'Thêm hashtag';

  @override
  String get savedSoundDeviceOnly => 'Đã lưu trên thiết bị này';

  @override
  String get savedSoundDetailsRetry =>
      'Không lưu được các chi tiết đó. Chạm để thử lại.';

  @override
  String get savedSoundFallbackTitle => 'Âm thanh đã lưu';

  @override
  String get savedSoundPreviewAction => 'Nghe thử âm thanh';

  @override
  String get savedSoundEditAction => 'Chỉnh sửa chi tiết âm thanh';

  @override
  String get savedSoundRemoveAction => 'Gỡ âm thanh đã lưu';

  @override
  String get savedSoundClearHashtagFilter => 'Xóa bộ lọc hashtag';

  @override
  String get soundAllowRemix => 'Cho phép người khác remix âm thanh này';

  @override
  String get soundReuseUnavailable => 'Hiện chưa thể remix âm thanh này.';

  @override
  String get soundPublicCredit => 'Ghi công âm thanh công khai';

  @override
  String get soundCreditRequired =>
      'Thêm ghi công âm thanh công khai trước khi đăng.';

  @override
  String get soundSharedAs => 'Chia sẻ dưới dạng';

  @override
  String get soundOwnWork => 'Tôi tạo ra âm thanh này';

  @override
  String soundCreatorBy(String creator) {
    return 'Bởi $creator';
  }

  @override
  String soundSharedBy(String publisher) {
    return 'Chia sẻ bởi $publisher';
  }

  @override
  String get soundRemixingAllowed => 'Cho phép remix';

  @override
  String get soundCreditOnly => 'Chỉ ghi công';

  @override
  String get soundCreditTitleLabel => 'Tên âm thanh';

  @override
  String get soundCreditCreatorLabel => 'Người tạo';

  @override
  String get soundCreditSourceUrlLabel => 'URL nguồn';

  @override
  String get soundCreditPublicHashtagsLabel => 'Hashtag công khai';

  @override
  String get videoMetadataTagsPickerCancelSemanticLabel => 'Hủy chọn thẻ';

  @override
  String get videoMetadataTagsPickerConfirmSemanticLabel =>
      'Áp dụng các thẻ đã chọn';

  @override
  String get userPickerCancelSemanticLabel => 'Hủy chọn người dùng';

  @override
  String get userPickerConfirmSemanticLabel => 'Xác nhận người dùng đã chọn';

  @override
  String get userPickerClearSelectionSemanticLabel => 'Xóa lựa chọn người dùng';

  @override
  String get videoMetadataContentWarningsPickerCancelSemanticLabel =>
      'Hủy chọn cảnh báo nội dung';

  @override
  String get videoMetadataContentWarningsPickerConfirmSemanticLabel =>
      'Áp dụng các cảnh báo nội dung đã chọn';

  @override
  String get videoEditorCloseEditorSemanticLabel =>
      'Đóng trình chỉnh sửa video';

  @override
  String get videoEditorContinueToPostDetailsSemanticLabel =>
      'Tiếp tục đến chi tiết bài đăng';

  @override
  String videoEditorDiscardToolChangesSemanticLabel(String tool) {
    return 'Hủy thay đổi trong $tool';
  }

  @override
  String videoEditorApplyToolChangesSemanticLabel(String tool) {
    return 'Áp dụng thay đổi trong $tool';
  }

  @override
  String get videoEditorRemoveAudioSemanticLabel => 'Xóa âm thanh';

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
  String get verifyTitle => 'Tài khoản đã xác minh';

  @override
  String get verifySignedOutMessage =>
      'Đăng nhập để liên kết tài khoản của bạn.';

  @override
  String get verifyIntro =>
      'Liên kết những tài khoản bạn đã có, để mọi người biết đúng là bạn.';

  @override
  String get verifyLoadFailed => 'Không tải được các liên kết của bạn.';

  @override
  String get verifyRetry => 'Thử lại';

  @override
  String get verifyLinkedSectionTitle => 'Đã liên kết';

  @override
  String get verifyVerifierUnreachable =>
      'Không liên hệ được dịch vụ xác minh, nên tất cả hiện là chưa kiểm tra.';

  @override
  String get verifyAddSectionTitle => 'Thêm tài khoản';

  @override
  String get verifyAllPlatformsLinked =>
      'Bạn đã liên kết mọi nền tảng chúng tôi hỗ trợ.';

  @override
  String get verifyStatusVerified => 'Đã xác minh';

  @override
  String get verifyStatusUnverified => 'Chưa xác minh';

  @override
  String verifyUnlinkSemanticLabel(String platform, String identity) {
    return 'Hủy liên kết tài khoản $platform $identity';
  }

  @override
  String verifyUnlinkConfirmTitle(String platform) {
    return 'Hủy liên kết $platform?';
  }

  @override
  String verifyUnlinkConfirmSubtitle(String identity) {
    return '$identity sẽ không còn hiển thị trên hồ sơ của bạn. Bạn có thể liên kết lại sau, nhưng sẽ phải đăng nhập lại hoặc đăng một bằng chứng mới.';
  }

  @override
  String get verifyUnlinkConfirmCta => 'Hủy liên kết';

  @override
  String verifyLinkSemanticLabel(String platform) {
    return 'Liên kết tài khoản $platform của bạn';
  }

  @override
  String get verifyOneTapBadge => 'Một chạm';

  @override
  String verifyConnectOauthExplainer(String platform) {
    return 'Đăng nhập $platform, phần còn lại để chúng tôi lo. Không đăng gì cả.';
  }

  @override
  String verifyConnectOauthCta(String platform) {
    return 'Tiếp tục với $platform';
  }

  @override
  String get verifyConnectProofTitle => 'Hoặc đăng một bằng chứng';

  @override
  String get verifyConnectProofExplainer =>
      'Đăng npub của bạn trên tài khoản đó, rồi dán liên kết tới bài đăng.';

  @override
  String get verifyNpubLabel => 'npub của bạn';

  @override
  String get verifyCopyNpubSemanticLabel => 'Sao chép npub của bạn';

  @override
  String get verifyNpubCopied => 'Đã sao chép npub';

  @override
  String get verifyIdentityLabel => 'Tên tài khoản';

  @override
  String get verifyProofLabel => 'Liên kết tới bài đăng';

  @override
  String get verifyConnectProofCta => 'Kiểm tra và liên kết';

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
      'Không liên hệ được dịch vụ xác minh. Thử lại sau chút.';

  @override
  String get verifyErrorOauthFailed => 'Chưa xong. Thử lại lần nữa nhé.';

  @override
  String get verifyErrorHandleRequired => 'Nhập handle của bạn trước đã.';

  @override
  String get verifyErrorPublishFailed =>
      'Đã xác minh, nhưng không relay nào nhận cập nhật. Thử lại.';

  @override
  String get verifyErrorOauthUnavailable =>
      'Đăng nhập một chạm chưa được thiết lập cho mục này. Dùng bằng chứng bên dưới.';

  @override
  String get verifyConnectProofExplainerGithub =>
      'Tạo một gist công khai với npub của bạn ở tệp đầu tiên, rồi dán liên kết gist.';

  @override
  String get verifyConnectProofExplainerDiscord =>
      'Đăng npub của bạn trong kênh Discord mà bot của chúng tôi đọc được, rồi dán liên kết tin nhắn. Lời mời máy chủ không chứng minh được gì.';

  @override
  String get verifyConnectProofExplainerTwitter =>
      'Đăng npub của bạn từ tài khoản đó, rồi dán liên kết tới tweet.';

  @override
  String get verifyConnectProofExplainerMastodon =>
      'Đăng npub của bạn từ tài khoản đó, rồi dán liên kết. Tên tài khoản phải kèm máy chủ — mastodon.social/@alice, không chỉ alice.';

  @override
  String get verifyConnectProofExplainerTelegram =>
      'Cái được liên kết là kênh, không phải tài khoản Telegram của bạn. Kênh cần liên kết công khai trước (Telegram tạo kênh mới ở chế độ riêng tư). Đăng npub ở đó rồi dán liên kết tin nhắn.';

  @override
  String get verifyConnectProofExplainerBluesky =>
      'Đã đăng nhập ở trên? Không cần gì thêm. Nếu chưa, đăng npub và dán liên kết bài đăng.';

  @override
  String get verifyConnectProofExplainerTiktok =>
      'Đặt npub của bạn vào chú thích video, rồi dán liên kết video đó.';

  @override
  String get verifyConnectProofExplainerYoutube =>
      'Đặt npub của bạn vào mô tả video, rồi dán liên kết video đó.';

  @override
  String verifyLinkedConfirmation(String platform) {
    return 'Đã liên kết $platform.';
  }

  @override
  String get verifyErrorTelegramNotPublic =>
      'Đó là kênh riêng tư hoặc lời mời. Hãy đặt liên kết công khai cho kênh, rồi dán liên kết tin nhắn.';

  @override
  String get verifyErrorRemoveFailed => 'Không hủy liên kết được. Thử lại nhé.';

  @override
  String get verifyErrorLinksUnreadable =>
      'Chúng tôi không đọc được các liên kết hiện tại của bạn, nên không thay đổi gì cả. Kiểm tra kết nối rồi thử lại.';

  @override
  String get verifyChannelLabel => 'Tên kênh';

  @override
  String get verifyHowItWorksTitle => 'Cái này hoạt động thế nào?';

  @override
  String get verifyHowItWorksIntro =>
      'Hãy hình dung như một cái bắt tay giữa hai tài khoản:';

  @override
  String get verifyHowItWorksYourSide =>
      'Hồ sơ Divine của bạn nói: “Tôi là @alice trên Twitter.”';

  @override
  String get verifyHowItWorksOtherSide =>
      'Tài khoản Twitter của bạn xác nhận: “Đúng, hồ sơ Divine đó là của tôi.”';

  @override
  String get verifyHowItWorksBothSides =>
      'Chúng tôi kiểm tra cả hai phía. Khớp nhau là bạn được xác minh. Không ai giả được — tên và ảnh thì sao chép được, đăng từ tài khoản thật của bạn thì không.';

  @override
  String get verifyHowItWorksOwnership =>
      'Các liên kết nằm trên chính danh tính Nostr của bạn, nên bạn có thể gỡ chúng ở đây bất cứ lúc nào.';

  @override
  String get generalSettingsSectionIdentity => 'Danh tính';

  @override
  String get libraryFilterAll => 'Tất cả';

  @override
  String get libraryFilterArchive => 'Lưu trữ';

  @override
  String get libraryFilterDeleted => 'Đã xoá';

  @override
  String get libraryCategoryNewChipLabel => 'Mới';

  @override
  String get libraryCategoryCreateSemanticLabel => 'Tạo danh mục';

  @override
  String get libraryCategoryCreateTitle => 'Danh mục mới';

  @override
  String get libraryCategoryCreateAction => 'Tạo';

  @override
  String get libraryCategoryRenameTitle => 'Đổi tên danh mục';

  @override
  String get libraryCategoryRenameAction => 'Đổi tên';

  @override
  String get libraryCategoryDeleteAction => 'Xoá danh mục';

  @override
  String get libraryCategoryNameLabel => 'Tên danh mục';

  @override
  String libraryCategoryDeleteConfirmTitle(String name) {
    return 'Xoá “$name”?';
  }

  @override
  String get libraryCategoryDeleteConfirmMessage =>
      'Các clip vẫn còn đó. Chúng chỉ quay lại mục Tất cả.';

  @override
  String get libraryCategoryManageSemanticLabel =>
      'Đổi tên hoặc xoá danh mục này';

  @override
  String get libraryCategoryMoveTitle => 'Chuyển tới';

  @override
  String get libraryCategoryMoveNone => 'Không có danh mục';

  @override
  String get libraryCategoryMoveNewCategory => 'Danh mục mới';

  @override
  String get libraryArchiveAction => 'Lưu trữ';

  @override
  String get libraryUnarchiveAction => 'Bỏ lưu trữ';

  @override
  String libraryArchiveKeepCategoryTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Giữ trong các danh mục này?',
      one: 'Giữ trong danh mục này?',
    );
    return '$_temp0';
  }

  @override
  String libraryArchiveKeepCategoryAction(String name) {
    return 'Giữ trong $name';
  }

  @override
  String get libraryArchiveKeepCategoryActionMixed =>
      'Giữ trong danh mục của chúng';

  @override
  String libraryArchiveRemoveCategoryAction(String name) {
    return 'Xóa khỏi $name';
  }

  @override
  String get libraryArchiveRemoveCategoryActionMixed =>
      'Xóa khỏi danh mục của chúng';

  @override
  String get libraryMoveSelectedClipsTooltip => 'Chuyển các clip đã chọn';

  @override
  String get libraryCategoryEmptyTitle => 'Chưa có gì ở đây';

  @override
  String get libraryCategoryEmptySubtitle =>
      'Chọn vài clip rồi chuyển vào danh mục này.';

  @override
  String get libraryArchiveEmptyTitle => 'Chưa lưu trữ gì';

  @override
  String get libraryArchiveEmptySubtitle =>
      'Clip đã lưu trữ nằm chờ ở đây, tách khỏi thư viện chính của bạn.';

  @override
  String libraryClipsMovedToCategory(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Đã chuyển $count clip tới $name',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsRemovedFromCategory(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Đã đưa $count clip ra khỏi danh mục',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsArchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Đã lưu trữ $count clip',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsUnarchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clip đã trở lại thư viện',
    );
    return '$_temp0';
  }

  @override
  String get accountSettingsChangeEmail => 'Đổi email';

  @override
  String get accountSettingsChangeEmailSubtitle =>
      'Chuyển tài khoản sang địa chỉ khác';

  @override
  String get accountSettingsChangePassword => 'Đổi mật khẩu';

  @override
  String get accountSettingsChangePasswordSubtitle =>
      'Chọn mật khẩu mới để đăng nhập';

  @override
  String get accountCredentialsNeedsSignIn =>
      'Phiên đăng nhập đã hết hạn. Đăng nhập lại để thực hiện thay đổi này.';

  @override
  String get accountCredentialsRateLimited =>
      'Thử quá nhiều lần. Đợi vài phút nhé.';

  @override
  String get accountCredentialsNetwork =>
      'Không kết nối được với Divine. Kiểm tra kết nối rồi thử lại.';

  @override
  String get accountCredentialsUnknown => 'Chưa được. Thử lại nhé.';

  @override
  String get changePasswordSubtitle =>
      'Nhập mật khẩu hiện tại, rồi chọn mật khẩu mới.';

  @override
  String get changePasswordCurrentLabel => 'Mật khẩu hiện tại';

  @override
  String get changePasswordWrongCurrent =>
      'Đó không phải mật khẩu hiện tại của bạn.';

  @override
  String get changePasswordSuccess => 'Đã đổi mật khẩu.';

  @override
  String get changeEmailSubtitle =>
      'Chúng tôi gửi liên kết xác nhận tới địa chỉ mới và tới địa chỉ trong tài khoản của bạn. Email sẽ đổi khi bạn xác nhận ở cả hai.';

  @override
  String changeEmailCurrentAddress(String email) {
    return 'Trong tài khoản: $email';
  }

  @override
  String get changeEmailNewLabel => 'Email mới';

  @override
  String get changeEmailPasswordLabel => 'Mật khẩu của bạn';

  @override
  String get changeEmailSameAsCurrent => 'Đó đã là địa chỉ email của bạn.';

  @override
  String get changeEmailWrongPassword => 'Đó không phải mật khẩu của bạn.';

  @override
  String get changeEmailSubmit => 'Gửi liên kết xác nhận';

  @override
  String get changeEmailSentTitle => 'Hai liên kết đang trên đường tới';

  @override
  String changeEmailSentMessage(String email) {
    return 'Xác nhận từ $email và từ địa chỉ trong tài khoản của bạn. Email đổi khi xong cả hai.';
  }

  @override
  String get changeEmailSentExpiry => 'Liên kết hết hạn sau 24 giờ.';

  @override
  String get changeEmailSentDone => 'Đã hiểu';

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
  String get socialProofMutual => 'Theo dõi lẫn nhau';

  @override
  String get socialProofFollowsYou => 'Đang theo dõi bạn';

  @override
  String get socialProofYouFollow => 'Bạn đang theo dõi';

  @override
  String socialProofFollowerCount(int count, String formattedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formattedCount người theo dõi',
    );
    return '$_temp0';
  }

  @override
  String get feedOutageMessage =>
      'Hiện không tải được video.\nLỗi từ phía chúng tôi — chúng tôi đang khắc phục.';

  @override
  String get feedOfflineMessage =>
      'Bạn đang ngoại tuyến.\nKiểm tra kết nối rồi thử lại.';

  @override
  String get dbFailureTitle => 'không thể mở khóa cơ sở dữ liệu cục bộ của bạn';

  @override
  String get dbFailureAdviceResettable =>
      'Khởi động lại sẽ không khắc phục được. Đặt lại cơ sở dữ liệu cục bộ bên dưới giúp Divine bắt đầu lại từ đầu — tài khoản của bạn vẫn còn.';

  @override
  String get dbFailureAdviceRestart =>
      'Khởi động lại Divine sau khi mở khóa thiết bị. Nếu vẫn tiếp diễn, hãy cập nhật ứng dụng hoặc liên hệ bộ phận hỗ trợ.';

  @override
  String get dbFailureAdviceHotJournal =>
      'Hãy thử khởi động lại Divine một lần. Nếu tình trạng này vẫn tiếp diễn, hãy cập nhật ứng dụng hoặc liên hệ bộ phận hỗ trợ. Dữ liệu cục bộ của bạn vẫn còn nguyên.';

  @override
  String dbFailureDiagnostic(String code) {
    return 'Chẩn đoán: $code';
  }

  @override
  String get dbFailureCloseApp => 'đóng Divine';

  @override
  String get dbFailureResetAction => 'đặt lại cơ sở dữ liệu cục bộ';

  @override
  String get dbFailureConfirmTitle => 'đặt lại cơ sở dữ liệu cục bộ của bạn?';

  @override
  String get dbFailureConfirmBody =>
      'Tài khoản của bạn vẫn còn. Bản nháp và clip đã lưu trên thiết bị này sẽ bị xóa — tin nhắn và bảng tin sẽ được tải lại từ mạng.';

  @override
  String get dbFailureResetConfirm => 'đặt lại cơ sở dữ liệu cục bộ ngay';

  @override
  String get dbFailureCancel => 'hủy';

  @override
  String get dbFailureResetFailed =>
      'Không thành công. Hãy đóng Divine và thử lại.';

  @override
  String get dbFailureResetDoneTitle => 'đã đặt lại cơ sở dữ liệu cục bộ';

  @override
  String get dbFailureResetDoneBody =>
      'Đóng Divine rồi mở lại — lần khởi chạy tiếp theo sẽ tạo cơ sở dữ liệu cục bộ mới.';

  @override
  String get authSignInOptionsInfo => 'Giới thiệu về tùy chọn đăng nhập';

  @override
  String get authShowPassword => 'Hiện mật khẩu';

  @override
  String get authHidePassword => 'Ẩn mật khẩu';

  @override
  String get followUserSemanticLabel => 'Theo dõi người dùng';

  @override
  String get unfollowUserSemanticLabel => 'Bỏ theo dõi người dùng';

  @override
  String get commentsLoadingSemanticLabel => 'Đang tải bình luận';

  @override
  String get analyticsWindowAll => 'Tất cả';

  @override
  String followUserIndexedSemanticLabel(String index) {
    return 'Theo dõi người dùng $index';
  }

  @override
  String unfollowUserIndexedSemanticLabel(String index) {
    return 'Bỏ theo dõi người dùng $index';
  }

  @override
  String supporterTierMonthlyLabel(String title, String price) {
    return '$title — $price / tháng';
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
  String get updateGentleBanner => 'Vừa có bản cập nhật mới. Xem ngay →';

  @override
  String get updateModerateTitle =>
      'Đã có bản cập nhật kể từ lần cuối bạn kiểm tra';

  @override
  String get updateUrgentTitle => 'Bạn đang thiếu các bản sửa lỗi quan trọng';

  @override
  String get updateNotNow => 'Để sau';

  @override
  String get updateAction => 'Cập nhật';

  @override
  String updateNewIn(String version) {
    return 'Điểm mới trong $version:';
  }

  @override
  String get settingsUpdateAvailable => 'Có bản cập nhật';
}

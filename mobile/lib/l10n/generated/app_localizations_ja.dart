// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get devOptionsClipRecovery => 'クリップの復旧';

  @override
  String get devOptionsClipRecoveryDescription =>
      '別のアカウントに保存された録画と、どの項目からも参照されていない動画ファイルを探します。';

  @override
  String get devOptionsClipRecoveryScan => 'スキャン';

  @override
  String get devOptionsClipRecoveryFailure => 'クリップの復旧に失敗しました';

  @override
  String devOptionsClipRecoveryVisible(int clips, int drafts) {
    return '現在表示中: クリップ $clips 件、下書き $drafts 件';
  }

  @override
  String get devOptionsClipRecoveryOtherAccounts => '他のアカウントに隠れています';

  @override
  String devOptionsClipRecoveryCounts(int clips, int drafts) {
    return 'クリップ $clips 件、下書き $drafts 件';
  }

  @override
  String get devOptionsClipRecoveryClaim => 'このアカウントに移動';

  @override
  String devOptionsClipRecoveryOrphanFiles(int count, String size) {
    return '参照されていないファイル: $count 件 ($size)';
  }

  @override
  String get devOptionsClipRecoveryImport => 'ライブラリに復元';

  @override
  String get devOptionsClipRecoveryEmpty => '復旧するものはありません';

  @override
  String devOptionsClipRecoveryRecovered(int count) {
    return '$count 件のクリップを復旧しました';
  }

  @override
  String get devOptionsClipRecoveryCopied => '復旧レポートをコピーしました';

  @override
  String get devOptionsStorageFootprint => 'ストレージ使用量';

  @override
  String get devOptionsStorageFootprintDescription =>
      'アプリが書き込むすべてのディレクトリ。キャッシュ削除で解放されるのはその一部だけです。';

  @override
  String get devOptionsStorageFootprintMeasure => '計測';

  @override
  String devOptionsStorageFootprintTotal(String size) {
    return '合計: $size';
  }

  @override
  String get devOptionsStorageFootprintCopied => 'ストレージレポートをコピーしました';

  @override
  String get devOptionsStorageFootprintFailure => 'ストレージを計測できませんでした';

  @override
  String get feedTuningMoreLabel => 'もっと見たい';

  @override
  String get feedTuningLessLabel => 'あまり見たくない';

  @override
  String get feedTuningUndo => '元に戻す';

  @override
  String get dmMessageBubbleVideoReplyHint => '参照先の動画を開く';

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsSecureAccount => 'アカウントを守る';

  @override
  String get settingsSessionExpired => 'セッション切れちゃった';

  @override
  String get settingsSessionExpiredSubtitle => 'もう一回サインインして、フルアクセスを取り戻そう';

  @override
  String get settingsAccountRestoreFailed => 'Account Restore Failed';

  @override
  String get settingsAccountRestoreFailedSwitchMessage =>
      'We couldn\'t unlock that account on this device. Signing back into it means signing out of the one you\'re on now.';

  @override
  String get settingsCreatorAnalytics => 'クリエイター分析';

  @override
  String get settingsSupportCenter => 'サポート';

  @override
  String get settingsNotifications => '通知';

  @override
  String get settingsBlueskyPublishing => 'Bluesky 公開';

  @override
  String get settingsBlueskyPublishingSubtitle => 'Bluesky へのクロス投稿を管理';

  @override
  String get settingsNostrSettings => 'Nostr 設定';

  @override
  String get settingsIntegratedApps => '連携アプリ';

  @override
  String get settingsIntegratedAppsSubtitle => 'Divine で使える承認済みサードパーティアプリ';

  @override
  String get settingsExperimentalFeatures => '実験的機能';

  @override
  String get settingsExperimentalFeaturesSubtitle => 'バグるかもしれないけど、気になったら試してみて。';

  @override
  String get settingsLegal => '法的情報';

  @override
  String get settingsIntegrationPermissions => '連携の権限';

  @override
  String get settingsIntegrationPermissionsSubtitle => '記憶された連携の承認を確認・取り消しできるよ';

  @override
  String settingsVersion(String version) {
    return 'バージョン $version';
  }

  @override
  String get settingsVersionEmpty => 'バージョン';

  @override
  String get settingsDeveloperModeAlreadyEnabled => '開発者モードはもう有効だよ';

  @override
  String get settingsDeveloperModeEnabled => '開発者モード、オン！';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    return 'あと$count回タップで開発者モードが開くよ';
  }

  @override
  String get settingsShareDivine => 'Divineを友だちと共有';

  @override
  String get settingsSwitchAccount => 'アカウントを切り替え';

  @override
  String get settingsAddAnotherAccount => '別のアカウントを追加';

  @override
  String get settingsAccountSwitchFailed => 'アカウントを切り替えられませんでした。もう一度お試しください。';

  @override
  String get settingsUnsavedDraftsTitle => '未保存の下書きがあるよ';

  @override
  String get settingsUploadInProgressTitle => 'アップロード中';

  @override
  String settingsUploadInProgressMessage(int count) {
    return 'まだ$count件の動画をアップロード中だよ。アカウントを切り替えるとアップロードは止まって、動画はこのアカウントの下書きに残るよ。';
  }

  @override
  String settingsUnsavedDraftsMessage(int count) {
    return '未保存の下書きが$count件あるよ。切り替えても下書きは残るけど、先に公開か確認しておくのがおすすめ。';
  }

  @override
  String get settingsCancel => 'キャンセル';

  @override
  String get settingsSwitchAnyway => 'それでも切り替える';

  @override
  String get settingsSessionExpiredSwitchMessage =>
      'そのアカウントのセッションは切れています。もう一度サインインすると、今使っているアカウントからサインアウトされます。';

  @override
  String get settingsAppVersionLabel => 'アプリのバージョン';

  @override
  String get settingsAppLanguage => 'アプリの言語';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language (デバイスの既定)';
  }

  @override
  String get settingsAppLanguageTitle => 'アプリの言語';

  @override
  String get settingsAppLanguageDescription => 'インターフェースの言語を選んでね';

  @override
  String get settingsAppLanguageUseDeviceLanguage => 'デバイスの言語を使う';

  @override
  String get settingsGeneralTitle => '一般設定';

  @override
  String get settingsContentSafetyTitle => 'コンテンツと安全';

  @override
  String get generalSettingsSectionIntegrations => '連携';

  @override
  String get generalSettingsSectionViewing => '視聴';

  @override
  String get generalSettingsSectionCreating => '作成';

  @override
  String get generalSettingsSectionApp => 'アプリ';

  @override
  String get appearanceSettingsTitle => '外観';

  @override
  String get appearanceSettingsSubtitle => 'このデバイスでの Divine の見た目を選択';

  @override
  String get appearanceSettingsSystem => 'システムのデフォルト';

  @override
  String get appearanceSettingsLight => 'ライト';

  @override
  String get appearanceSettingsDark => 'ダーク';

  @override
  String get generalSettingsClosedCaptions => '字幕';

  @override
  String get generalSettingsClosedCaptionsSubtitle => '動画に字幕がある場合に表示するよ';

  @override
  String get generalSettingsVideoShapeSquareOnly => '正方形の動画のみ';

  @override
  String get generalSettingsVideoShapeSquareOnlySubtitle =>
      'クラシックな正方形フォーマットでフィードを保つ';

  @override
  String get contentPreferencesTitle => 'コンテンツ設定';

  @override
  String get contentPreferencesContentFilters => 'コンテンツフィルター';

  @override
  String get contentPreferencesContentFiltersSubtitle => 'コンテンツ警告フィルターを管理';

  @override
  String get contentPreferencesContentLanguage => 'コンテンツの言語';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language (デバイスの既定)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      '動画に言語タグを付けると、視聴者がコンテンツをフィルターできるよ。';

  @override
  String get contentPreferencesUseDeviceLanguage => 'デバイスの言語を使う (既定)';

  @override
  String get contentPreferencesAudioSharing => '自分の音声を再利用可能にする';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      'オンにすると、他の人があなたの動画の音声を使えるよ';

  @override
  String get contentPreferencesMusicMode => '音楽モード';

  @override
  String get contentPreferencesMusicModeSubtitle =>
      '楽器の音を潰してしまうノイズ除去をオフにします。音楽向きですが、声には少し粗くなります。';

  @override
  String get contentPreferencesAccountLabels => 'アカウントラベル';

  @override
  String get contentPreferencesAccountLabelsEmpty => '自分のコンテンツにラベルを付けよう';

  @override
  String get contentPreferencesAccountContentLabels => 'アカウントのコンテンツラベル';

  @override
  String get contentPreferencesClearAll => 'すべてクリア';

  @override
  String get contentPreferencesSelectAllThatApply => 'あなたのアカウントに当てはまるものを全部選んでね';

  @override
  String get contentPreferencesDoneNoLabels => '完了 (ラベルなし)';

  @override
  String contentPreferencesDoneCount(int count) {
    return '完了 ($count件選択)';
  }

  @override
  String get contentPreferencesAudioInputDevice => '音声入力デバイス';

  @override
  String get contentPreferencesAutoRecommended => '自動 (おすすめ)';

  @override
  String get contentPreferencesAutoSelectsBest => '最適なマイクを自動で選ぶよ';

  @override
  String get contentPreferencesSelectAudioInput => '音声入力を選ぶ';

  @override
  String get contentPreferencesUnknownMicrophone => '不明なマイク';

  @override
  String get contentFiltersAdultContent => 'アダルトコンテンツ';

  @override
  String get contentFiltersViolenceGore => '暴力とグロテスク';

  @override
  String get contentFiltersSubstances => '薬物';

  @override
  String get contentFiltersOther => 'その他';

  @override
  String get contentFiltersAgeGateMessage =>
      'アダルトコンテンツのフィルターを使うには、[安全とプライバシー] 設定で年齢を確認してね';

  @override
  String get contentFiltersShow => '表示';

  @override
  String get contentFiltersWarn => '警告';

  @override
  String get contentFiltersFilterOut => 'フィルターで除外';

  @override
  String get profileBlockedAccountNotAvailable => 'このアカウントは見れないよ';

  @override
  String get profileInvalidId => '無効なプロフィール ID';

  @override
  String profileShareText(String displayName, String npub) {
    return 'Divine の $displayName をチェックしてみて!\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return 'Divine の $displayName';
  }

  @override
  String get profileShareFailed => 'プロフィールの共有がうまくいかなかった。もう一回試してみて。';

  @override
  String get profileCopyPublicKey => '公開鍵 (npub) をコピー';

  @override
  String get profileGetEmbedCode => '埋め込みコードを取得';

  @override
  String get profilePublicKeyCopied => '公開鍵をコピーしたよ';

  @override
  String get profileEmbedCodeCopied => '埋め込みコードをコピーしたよ';

  @override
  String get profileMoreTooltip => 'その他';

  @override
  String get profileMoreSemanticLabel => 'その他のオプション';

  @override
  String get profileAvatarLightboxBarrierLabel => 'アバターを閉じる';

  @override
  String get profileAvatarLightboxCloseSemanticLabel => 'アバタープレビューを閉じる';

  @override
  String get profileFollowingLabel => 'フォロー中';

  @override
  String get profileFollowLabel => 'フォロー';

  @override
  String get profileBlockedLabel => 'ブロック済み';

  @override
  String get profileFollowersLabel => 'フォロワー';

  @override
  String get profileFollowingStatLabel => 'フォロー中';

  @override
  String get profileVideosLabel => '動画';

  @override
  String get profileCollabsLabel => 'コラボ';

  @override
  String get profileLikedLabel => 'いいね済み';

  @override
  String get profileRepostsLabel => 'リポスト';

  @override
  String get profileListsLabel => 'リスト';

  @override
  String get profileCommentsLabel => 'コメント';

  @override
  String profileCollaboratorInvitePendingHeadline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'コラボの招待が$count件まだ送信されてないよ',
      one: 'コラボの招待が1件まだ送信されてないよ',
    );
    return '$_temp0';
  }

  @override
  String get profileCollaboratorInvitePendingDetail =>
      '招待はキューに入れておいたよ。ここから再送信してね。';

  @override
  String profileCollaboratorInvitePendingDetailWithTitle(String title) {
    return '「$title」への招待だよ。ここから再送信してね。';
  }

  @override
  String get profileCollaboratorInviteRetryAction => '再送信';

  @override
  String get profileCollaboratorInviteRetryingAction => '再送信中';

  @override
  String get profileCollaboratorInviteRetryUnavailable => '今はコラボ招待の再送信ができないよ。';

  @override
  String profileCollaboratorInviteRetryResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'コラボの招待が$count件まだ送信されてないよ。',
      one: 'コラボの招待が1件まだ送信されてないよ。',
      zero: 'コラボの招待を送信したよ。',
    );
    return '$_temp0';
  }

  @override
  String profileCollaboratorInviteBlockedResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'コラボ相手$count人が招待を受け取れないよ。',
      one: 'コラボ相手1人が招待を受け取れないよ。',
    );
    return '$_temp0';
  }

  @override
  String profileFollowerCountUsers(int count) {
    return '$count人';
  }

  @override
  String profileBlockTitle(String displayName) {
    return '$displayNameをブロックする?';
  }

  @override
  String get profileBlockExplanation => 'ブロックするとこうなるよ:';

  @override
  String get profileBlockBulletHidePosts => 'その人の投稿はフィードに出なくなる。';

  @override
  String get profileBlockBulletCantView =>
      'その人はあなたのプロフィール閲覧、フォロー、投稿の閲覧ができなくなる。';

  @override
  String get profileBlockBulletNoNotify => '相手には通知されないよ。';

  @override
  String get profileBlockBulletYouCanView => 'あなたはその人のプロフィールを引き続き見れるよ。';

  @override
  String profileBlockConfirmButton(String displayName) {
    return '$displayNameをブロック';
  }

  @override
  String get profileCancelButton => 'キャンセル';

  @override
  String get profileLearnMore => 'もっと詳しく';

  @override
  String profileUnblockTitle(String displayName) {
    return '$displayNameのブロックを解除する?';
  }

  @override
  String get profileUnblockExplanation => 'ブロックを解除するとこうなるよ:';

  @override
  String get profileUnblockBulletShowPosts => 'その人の投稿がフィードに表示されるようになる。';

  @override
  String get profileUnblockBulletCanView =>
      'その人はあなたのプロフィール閲覧、フォロー、投稿の閲覧ができるようになる。';

  @override
  String get profileUnblockBulletNoNotify => '相手には通知されないよ。';

  @override
  String get profileLearnMoreAt => '詳しくはこちら: ';

  @override
  String get profileUnblockButton => 'ブロック解除';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return '$displayNameのフォローを解除';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return '$displayNameをブロック';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return '$displayNameのブロックを解除';
  }

  @override
  String profileReportDisplayName(String displayName) {
    return '$displayNameを報告';
  }

  @override
  String profileAddToListDisplayName(String displayName) {
    return '$displayNameをリストに追加';
  }

  @override
  String get profileNoCollabsTitle => 'コラボ動画はまだないよ';

  @override
  String get profileCollabsOwnEmpty => 'あなたがコラボした動画がここに表示されるよ';

  @override
  String get profileCollabsOtherEmpty => 'この人がコラボした動画がここに表示されるよ';

  @override
  String get profileErrorLoadingCollabs => 'コラボ動画の読み込みに失敗';

  @override
  String get profileNoSavedVideosTitle => '保存した動画はまだないよ';

  @override
  String get profileSavedOwnEmpty => 'シェアシートから動画をブックマークすると、ここに出るよ。';

  @override
  String get profileErrorLoadingSaved => '保存した動画の読み込みに失敗';

  @override
  String get profileNoCommentsOwnTitle => 'コメントはまだないよ';

  @override
  String get profileNoCommentsOtherTitle => 'コメントなし';

  @override
  String get profileCommentsOwnEmpty => 'あなたのコメントと返信がここに出るよ';

  @override
  String get profileCommentsOtherEmpty => 'この人のコメントと返信がここに出るよ';

  @override
  String get profileErrorLoadingComments => 'コメントの読み込みに失敗';

  @override
  String get profileVideoRepliesSection => '動画の返信';

  @override
  String get profileCommentsSection => 'コメント';

  @override
  String get profileEditLabel => '編集';

  @override
  String get profileLibraryLabel => 'ライブラリ';

  @override
  String get profileNoLikedVideosTitle => 'いいねした動画はまだないよ';

  @override
  String get profileLikedOwnEmpty => 'あなたがいいねした動画がここに出るよ';

  @override
  String get profileLikedOtherEmpty => 'この人がいいねした動画がここに出るよ';

  @override
  String get profileErrorLoadingLiked => 'いいね動画の読み込みに失敗';

  @override
  String get profileNoRepostsTitle => 'リポストはまだないよ';

  @override
  String get profileRepostsOwnEmpty => 'あなたがリポストした動画がここに出るよ';

  @override
  String get profileRepostsOtherEmpty => 'この人がリポストした動画がここに出るよ';

  @override
  String get profileErrorLoadingReposts => 'リポスト動画の読み込みに失敗';

  @override
  String get profileNoVideosTitle => '動画はまだないよ';

  @override
  String get profileNoVideosOwnSubtitle => '最初の動画を投稿してここに表示しよう';

  @override
  String get profileNoVideosOtherSubtitle => 'このユーザーはまだ動画を投稿してないよ';

  @override
  String profileVideoThumbnailLabel(int number) {
    return '動画サムネイル $number';
  }

  @override
  String get profileShowMore => 'もっと見る';

  @override
  String get profileShowLess => '閉じる';

  @override
  String get dmMessageDisplayLimitReached => 'このメッセージの残りは表示されません。';

  @override
  String get profileCompleteYourProfile => 'プロフィールを完成させよう';

  @override
  String get profileCompleteSubtitle => '名前、自己紹介、画像を追加して始めよう';

  @override
  String get profilePleaseTryAgain => 'もう一回試してみて';

  @override
  String get profileSecureYourAccount => 'アカウントを守ろう';

  @override
  String get profileSecureSubtitle => 'メールとパスワードを追加すれば、どのデバイスからでもアカウントを復元できるよ';

  @override
  String get profileRetryButton => 'もう一回';

  @override
  String get profileSessionExpired => 'セッション切れちゃった';

  @override
  String get profileSignInToRestore => 'もう一回サインインして、フルアクセスを取り戻そう';

  @override
  String get profileSignInButton => 'サインイン';

  @override
  String get profileMaybeLaterLabel => 'あとで';

  @override
  String get profileSecurePrimaryButton => 'メールとパスワードを追加';

  @override
  String get profileCompletePrimaryButton => 'プロフィールを更新';

  @override
  String get profileLoopsLabel => 'ループ';

  @override
  String get profileLikesLabel => 'いいね';

  @override
  String get profileMyLibraryLabel => 'マイライブラリ';

  @override
  String get profileMessageLabel => 'メッセージ';

  @override
  String get profileShareLabel => 'プロフィールを共有';

  @override
  String get profileDeletedAccountName => '削除されたアカウント';

  @override
  String get inboxActionReportVanishedAccount => 'このアカウントを報告';

  @override
  String get inboxActionBlockVanishedAccount => 'このアカウントをブロック';

  @override
  String get inboxActionUnblockVanishedAccount => 'このアカウントのブロックを解除';

  @override
  String get inboxReportedVanishedAccount => 'このアカウントを報告したよ';

  @override
  String get inboxBlockedVanishedAccount => 'このアカウントをブロックしたよ';

  @override
  String get inboxUnblockedVanishedAccount => 'このアカウントのブロックを解除したよ';

  @override
  String get inboxRemoveConfirmBodyVanishedAccount =>
      'この会話が受信トレイから削除されます。相手からまたメッセージが届くと、新しい会話が始まります。';

  @override
  String get inboxConversationDeletedAccountSubtitle => 'このアカウントは削除されました';

  @override
  String get profileUserFallback => 'ユーザー';

  @override
  String get profileLinkCopied => 'プロフィールのリンクをコピーしたよ';

  @override
  String get profileSetupEditProfileTitle => 'プロフィールを編集';

  @override
  String get nostrSettingsNip05ProfileRequired =>
      'NIP-05アドレスを追加する前にプロフィールを設定してください。';

  @override
  String get nostrSettingsNip05CreateProfileAction => 'プロフィールを作成';

  @override
  String get profileSetupBackLabel => '戻る';

  @override
  String get profileSetupAboutNostr => 'Nostr について';

  @override
  String get profileSetupProfilePublished => 'プロフィールを公開したよ！';

  @override
  String get profileSetupUnsavedChangesTitle => '変更を保存しますか？';

  @override
  String get profileSetupUnsavedChangesSubtitle =>
      '離れる前に編集内容を保存するか、破棄して先に進みましょう。';

  @override
  String get profileSetupUnsavedChangesSaveButton => '変更を保存';

  @override
  String get profileSetupUnsavedChangesDiscardButton => '変更を破棄';

  @override
  String get profileSetupUnsavedChangesKeepButton => '編集を続ける';

  @override
  String get profileSetupCreateNewProfile => '新しいプロフィールを作る?';

  @override
  String get profileSetupNoExistingProfile =>
      'リレーに既存のプロフィールが見つからなかった。公開すると新しいプロフィールが作られるよ。続ける?';

  @override
  String get profileSetupPublishButton => '公開';

  @override
  String get profileSetupUsernameTaken => 'そのユーザー名はたった今取られちゃった。別の名前にしてみて。';

  @override
  String get profileSetupClaimFailed => 'ユーザー名の取得がうまくいかなかった。もう一回試してみて。';

  @override
  String get profileSetupPublishFailed => 'プロフィールの公開がうまくいかなかった。もう一回試してみて。';

  @override
  String get profileSetupNoRelaysConnected =>
      'ネットワークに接続できなかった。接続を確認してもう一回試してみて。';

  @override
  String get profileSetupDisplayNameLabel => '表示名';

  @override
  String get profileSetupDisplayNameRequired => '表示名を入力してね';

  @override
  String get profileSetupBioLabel => '自己紹介 (任意)';

  @override
  String get profileSetupWebsiteLabel => 'ウェブサイト（任意）';

  @override
  String get profileSetupPublicKeyLabel => '公開鍵 (npub)';

  @override
  String get profileSetupUsernameLabel => 'ユーザー名 (任意)';

  @override
  String get profileSetupUsernameHelper =>
      '英数字とハイフンが使えるよ。ユーザー名は divine.video のアドレスになるよ。スペースや記号は表示名で使ってね。';

  @override
  String get profileSetupSaveButton => '保存';

  @override
  String get profileSetupSavingButton => '保存中...';

  @override
  String get profileSetupImageUrlTitle => '画像 URL を追加';

  @override
  String get profileSetupImageSelectionFailed =>
      '画像の選択がうまくいかなかった。代わりに下に画像 URL を貼り付けてね。';

  @override
  String get profileSetupImagesTypeGroup => '画像';

  @override
  String get cameraPickErrorPermissionDenied =>
      'カメラへのアクセスがオフになってる。設定でオンにすると写真を撮れるよ。';

  @override
  String get cameraPickErrorPermissionRestricted =>
      'このデバイスではカメラへのアクセスが許可されてない。';

  @override
  String get cameraPickErrorBusy => 'ピッカーはもう開いてる。閉じてからもう一回試してみて。';

  @override
  String get cameraPickErrorGeneric => 'カメラを開けなかった。もう一回試してみて。';

  @override
  String get profileSetupGotItButton => '了解！';

  @override
  String get profileSetupUploadFailedGeneric => '画像をアップロードできなかった。あとでもう一度試してみて。';

  @override
  String get profileSetupUploadNetworkError =>
      'ネットワークエラー: ネット接続を確認してもう一回試してみて。';

  @override
  String get profileSetupUploadAuthError => '認証エラー: 一度ログアウトしてもう一回ログインしてみて。';

  @override
  String get profileSetupUploadFileTooLarge =>
      'ファイルが大きすぎる: もっと小さい画像を選んでね (最大 10MB)。';

  @override
  String get profileSetupUploadServerError =>
      '画像をアップロードできなかった。サーバーが一時的に利用できないよ。少し待ってからもう一度試してみて。';

  @override
  String get profileSetupBannerClearButton => 'バナーをクリア';

  @override
  String get profileSetupBannerChangeColor => 'バナーの色';

  @override
  String get profileSetupChangeBannerTitle => 'バナーを変更';

  @override
  String get profileSetupBannerColorPickerTitle => 'バナーの色を変更';

  @override
  String get profileSetupBannerColorCustom => 'カスタム';

  @override
  String get profileSetupBannerColorNone => '色なし';

  @override
  String get profileSetupBannerColorLime => 'ライム';

  @override
  String get profileSetupBannerColorYellow => 'イエロー';

  @override
  String get profileSetupBannerColorViolet => 'バイオレット';

  @override
  String get profileSetupBannerColorPink => 'ピンク';

  @override
  String get profileSetupBannerColorOrange => 'オレンジ';

  @override
  String get profileSetupBannerColorPurple => 'パープル';

  @override
  String get profileSetupAvatarClearButton => '写真を削除';

  @override
  String get profileSetupImageTakePhoto => '写真を撮る';

  @override
  String get profileSetupImageUploadFromCameraRoll => 'カメラロールからアップロード';

  @override
  String get profileSetupImagePasteLink => '画像リンクを貼り付け';

  @override
  String get profileSetupEditAvatarLabel => 'プロフィール画像を編集';

  @override
  String get profileSetupEditBannerLabel => 'バナーを編集';

  @override
  String get profileSetupUsernameChecking => '使えるか確認中...';

  @override
  String get profileSetupUsernameAvailable => 'このユーザー名、使えるよ！';

  @override
  String get profileSetupUsernameTakenIndicator => 'このユーザー名はもう使われてる';

  @override
  String get profileSetupUsernameReserved => 'このユーザー名は予約済み';

  @override
  String get profileSetupContactSupport => 'サポートに連絡';

  @override
  String get profileSetupCheckAgain => 'もう一回確認';

  @override
  String get profileSetupUsernameBurned => 'このユーザー名はもう使えないよ';

  @override
  String get profileSetupUsernameInvalidFormat => '使えるのは英数字とハイフンだけだよ';

  @override
  String get profileSetupUsernameInvalidHyphenPlacement =>
      'ユーザー名の最初や最後にハイフンは使えないよ';

  @override
  String get profileSetupUsernameInvalidLength => 'ユーザー名は3〜63文字にしてね';

  @override
  String get profileSetupUsernameNetworkError => '使えるか確認できなかった。もう一回試してみて。';

  @override
  String get profileSetupUsernameInvalidFormatGeneric => 'ユーザー名の形式が正しくないよ';

  @override
  String get profileSetupUsernameCheckFailed => '使えるか確認できなかった';

  @override
  String get profileSetupUsernameReservedTitle => '予約済みのユーザー名';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return '$username は予約済みだよ。なぜあなたのものかを教えてね。';
  }

  @override
  String get profileSetupUsernameReservedHint => '例: ブランド名、アーティスト名など。';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      'もうサポートに連絡した? [もう一度確認] をタップして、解放されたか見てみてね。';

  @override
  String get profileSetupSupportRequestSent => 'サポートリクエストを送ったよ！ すぐに連絡するね。';

  @override
  String get profileSetupCouldntOpenEmail =>
      'メールアプリが開けなかった。送信先: names@divine.video';

  @override
  String get profileSetupSendRequest => 'リクエストを送る';

  @override
  String get profileSetupUseOwnNip05 => '自分の NIP-05 アドレスを使う';

  @override
  String get profileSetupNip05AddressLabel => 'NIP-05 アドレス';

  @override
  String get profileSetupExternalNip05InvalidFormat =>
      'NIP-05 の形式が正しくないよ (例: name@domain.com)';

  @override
  String get profileSetupExternalNip05DivineDomain =>
      'divine.video の場合は上のユーザー名欄を使ってね';

  @override
  String get nostrSettingsNip05Address => 'NIP-05 アドレス';

  @override
  String get nostrSettingsNip05AddressSubtitle =>
      'divine.video のユーザー名を使うか、自分が管理するドメインの NIP-05 アドレスにハンドルを向けてください。';

  @override
  String get nostrSettingsNip05AddressHint => 'you@example.com';

  @override
  String get nostrSettingsNip05SaveAction => 'NIP-05 を保存';

  @override
  String get nostrSettingsNip05Saved => 'NIP-05 を保存しました';

  @override
  String get nostrSettingsNip05SaveFailed => 'NIP-05 を保存できませんでした。もう一度お試しください。';

  @override
  String get profileSetupNip05ConfirmTitle => '自分の NIP-05 を使いますか？';

  @override
  String get profileSetupNip05ConfirmBody =>
      'NIP-05 は you@yourdomain.com のような名前をあなたの Nostr ID に結び付けます。ドメインを管理し、正しいパスに検証ファイルを置く必要があります。設定が間違っていると、あなたを見つけてもらえず、認証済みハンドルも消えます。設定済みの場合のみ続けてください。';

  @override
  String get profileSetupNip05ConfirmContinue => '続ける';

  @override
  String get profileSetupNip05ConfirmCancel => 'キャンセル';

  @override
  String get profileSetupProfilePicturePreview => 'プロフィール画像のプレビュー';

  @override
  String get nostrInfoIntroBuiltOn => 'Divine は Nostr の上に作られてるよ。';

  @override
  String get nostrInfoIntroDescription =>
      ' 検閲に強いオープンなプロトコルで、特定の企業やプラットフォームに縛られずにコミュニケーションできるんだ。 ';

  @override
  String get nostrInfoIntroIdentity => 'Divine にサインアップすると、新しい Nostr ID が作られるよ。';

  @override
  String get nostrInfoOwnership =>
      'Nostr なら自分のコンテンツ、ID、ソーシャルグラフを自分のものにできて、いろんなアプリで使い回せる。選択肢が増えてロックインが減って、もっと健全なソーシャルインターネットになるんだ。';

  @override
  String get nostrInfoLingo => 'Nostr 用語:';

  @override
  String get nostrInfoNpubLabel => 'npub:';

  @override
  String get nostrInfoNpubDescription =>
      ' あなたの公開 Nostr アドレス。共有しても安全で、他の Nostr アプリであなたを見つけたり、フォローしたり、メッセージを送れるようになるよ。';

  @override
  String get nostrInfoNsecLabel => 'nsec:';

  @override
  String get nostrInfoNsecDescription =>
      ' あなたの秘密鍵で、所有権の証明。これで Nostr ID を完全にコントロールできるから、';

  @override
  String get nostrInfoNsecWarning => '絶対に秘密にしておいて！';

  @override
  String get nostrInfoUsernameLabel => 'Nostr ユーザー名:';

  @override
  String get nostrInfoUsernameDescription =>
      ' 人間が読める名前 (例: @name.divine.video) で、npub にリンクしてる。メールアドレスみたいに、Nostr ID を認識・確認しやすくしてくれるよ。';

  @override
  String get nostrInfoLearnMoreAt => 'もっと詳しく: ';

  @override
  String get nostrInfoGotIt => '了解！';

  @override
  String get videoGridRefreshLabel => 'さらに動画を探し中';

  @override
  String get videoGridOptionsTitle => '動画オプション';

  @override
  String get videoGridEditVideo => '動画を編集';

  @override
  String get videoGridEditVideoSubtitle => 'タイトル、説明、ハッシュタグを更新';

  @override
  String get videoGridDeleteVideo => '動画を削除';

  @override
  String get videoGridDeleteVideoSubtitle =>
      'この動画をDivineから削除します。他のNostrクライアントには、まだ表示される場合があります。';

  @override
  String get videoGridDeletingContent => 'コンテンツを削除中...';

  @override
  String get exploreTabFeatured => 'おすすめ';

  @override
  String get exploreTabClassics => 'クラシック';

  @override
  String get exploreTabNew => '新着';

  @override
  String get exploreTabPopular => '人気';

  @override
  String get exploreTabCategories => 'カテゴリ';

  @override
  String get exploreTabForYou => 'おすすめ';

  @override
  String get exploreTabLists => 'リスト';

  @override
  String get exploreTabIntegratedApps => '連携アプリ';

  @override
  String exploreFeaturedSponsoredBy(String sponsor) {
    return 'Sponsored by $sponsor';
  }

  @override
  String exploreFeaturedSponsoredPillSemanticLabel(String name) {
    return '$name, sponsored';
  }

  @override
  String get featuredTabEmpty => 'まだ何もありません。またのぞいてみてください。';

  @override
  String get featuredTabLoadFailed => 'このコレクションを読み込めませんでした。';

  @override
  String get featuredTabRetry => 'もう一度試す';

  @override
  String get exploreNoVideosAvailable => '動画がないよ';

  @override
  String get exploreDiscoverLists => 'リストを見つけよう';

  @override
  String get exploreAboutLists => 'リストについて';

  @override
  String get exploreAboutListsDescription =>
      'リストを使うと、Divine のコンテンツを2つの方法で整理・キュレーションできるよ:';

  @override
  String get explorePeopleLists => 'ピープルリスト';

  @override
  String get explorePeopleListsDescription =>
      'クリエイターのグループをフォローして、最新の動画をチェックしよう';

  @override
  String get exploreVideoLists => 'ビデオリスト';

  @override
  String get exploreVideoListsDescription => 'お気に入りの動画をプレイリストにまとめて、あとで見よう';

  @override
  String get exploreMyLists => 'マイリスト';

  @override
  String get exploreSubscribedLists => '購読中のリスト';

  @override
  String get exploreErrorLoadingLists => 'リストの読み込みに失敗。もう一回試してみて。';

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count本の新着動画',
    );
    return '$_temp0';
  }

  @override
  String exploreLoadNewVideosLabel(int count) {
    return '$count本の新着動画を読み込む';
  }

  @override
  String get videoPlayerPlayVideo => '動画を再生';

  @override
  String get videoPlayerMute => '動画をミュート';

  @override
  String get videoPlayerUnmute => '動画のミュートを解除';

  @override
  String get videoPlayerTapHint => 'タップで再生・一時停止。ダブルタップでいいね。';

  @override
  String get videoSettingsMenuOpen => '再生設定を開く';

  @override
  String get videoSettingsMenuClose => '再生設定を閉じる';

  @override
  String get videoSettingsCaptionsEnable => '字幕を有効にする';

  @override
  String get videoSettingsCaptionsDisable => '字幕を無効にする';

  @override
  String get videoSettingsAutoAdvanceOn => '自動送りオン';

  @override
  String get videoSettingsAutoAdvanceOff => '自動送りオフ';

  @override
  String get videoSettingsCaptionsOn => '字幕オン';

  @override
  String get videoSettingsCaptionsOff => '字幕オフ';

  @override
  String get videoSettingsCaptionsOnForVideo => 'この動画の字幕をオンにしました';

  @override
  String get videoSettingsCaptionsOffForVideo => 'この動画の字幕をオフにしました';

  @override
  String get contentWarningLabel => 'コンテンツ警告';

  @override
  String get contentWarningNudity => 'ヌード';

  @override
  String get contentWarningSexualContent => '性的コンテンツ';

  @override
  String get contentWarningPornography => 'ポルノ';

  @override
  String get contentWarningGraphicMedia => '刺激的なメディア';

  @override
  String get contentWarningViolence => '暴力';

  @override
  String get contentWarningSelfHarm => '自傷行為';

  @override
  String get contentWarningDrugUse => '薬物使用';

  @override
  String get contentWarningAlcohol => 'アルコール';

  @override
  String get contentWarningTobacco => 'タバコ';

  @override
  String get contentWarningGambling => 'ギャンブル';

  @override
  String get contentWarningProfanity => '汚い言葉';

  @override
  String get contentWarningFlashingLights => '点滅する光';

  @override
  String get contentWarningAiGenerated => 'AI 生成';

  @override
  String get contentWarningSpoiler => 'ネタバレ';

  @override
  String get contentWarningSensitiveContent => 'センシティブなコンテンツ';

  @override
  String get contentWarningDescNudity => 'ヌードや部分的なヌードが含まれてるよ';

  @override
  String get contentWarningDescSexual => '性的なコンテンツが含まれてるよ';

  @override
  String get contentWarningDescPorn => '露骨なポルノコンテンツが含まれてるよ';

  @override
  String get contentWarningDescGraphicMedia => '刺激的・不快な映像が含まれてるよ';

  @override
  String get contentWarningDescViolence => '暴力的なコンテンツが含まれてるよ';

  @override
  String get contentWarningDescSelfHarm => '自傷行為への言及が含まれてるよ';

  @override
  String get contentWarningDescDrugs => '薬物関連のコンテンツが含まれてるよ';

  @override
  String get contentWarningDescAlcohol => 'アルコール関連のコンテンツが含まれてるよ';

  @override
  String get contentWarningDescTobacco => 'タバコ関連のコンテンツが含まれてるよ';

  @override
  String get contentWarningDescGambling => 'ギャンブル関連のコンテンツが含まれてるよ';

  @override
  String get contentWarningDescProfanity => '強い表現が含まれてるよ';

  @override
  String get contentWarningDescFlashingLights => '点滅する光が含まれてるよ (光過敏症注意)';

  @override
  String get contentWarningDescAiGenerated => 'このコンテンツは AI で作られたよ';

  @override
  String get contentWarningDescSpoiler => 'ネタバレが含まれてるよ';

  @override
  String get contentWarningDescContentWarning => 'クリエイターがセンシティブとしてマークしたよ';

  @override
  String get contentWarningDescDefault => 'クリエイターがこのコンテンツにフラグを付けたよ';

  @override
  String get contentWarningDetailsTitle => 'コンテンツ警告';

  @override
  String get contentWarningDetailsSubtitle => 'クリエイターが付けたラベル:';

  @override
  String get contentWarningManageFilters => 'コンテンツフィルターを管理';

  @override
  String get contentWarningViewAnyway => 'それでも見る';

  @override
  String get contentWarningReportContentTooltip => 'コンテンツを報告';

  @override
  String get contentWarningBlockUserTooltip => 'ユーザーをブロック';

  @override
  String get contentWarningBlockedTitle => 'ブロック済みのコンテンツ';

  @override
  String get contentWarningBlockedPolicy => 'このコンテンツはポリシー違反でブロックされたよ。';

  @override
  String get contentWarningNoticeTitle => 'コンテンツに関するお知らせ';

  @override
  String get contentWarningPotentiallyHarmfulTitle => '有害な可能性があるコンテンツ';

  @override
  String get contentWarningView => '表示';

  @override
  String get contentWarningReportAction => '報告';

  @override
  String get contentWarningHideAllLikeThis => 'こういうの全部隠す';

  @override
  String get contentWarningNoFilterYet => 'この警告のフィルターはまだ保存されてないよ。';

  @override
  String get contentWarningHiddenConfirmation => 'これからはこういう投稿を隠すね。';

  @override
  String get communitySuggestTitle => 'この動画の分類を手伝ってね';

  @override
  String get communitySuggestSubtitle => 'コンテンツ警告が足りない? 提案は公開・署名付きで、取り消せないよ。';

  @override
  String get communitySuggestSubmit => '提案';

  @override
  String get communitySuggestSuccess => 'ありがとう。提案を送ったよ。';

  @override
  String get communitySuggestFailure => '提案を送れなかったよ。もう一回試してみて。';

  @override
  String get communitySuggestAlready => '提案済み';

  @override
  String get communitySuggestActionLabel => '分類';

  @override
  String get videoErrorNotFound => '動画が見つからない';

  @override
  String get videoErrorPlayback => '動画の再生エラー';

  @override
  String get videoErrorAgeRestricted => '年齢制限のあるコンテンツ';

  @override
  String get videoErrorUnavailable => '動画を見れないよ';

  @override
  String get videoErrorUnavailableBody => 'この動画は現在利用できません。';

  @override
  String get videoErrorRetry => 'もう一回';

  @override
  String get videoErrorContentRestricted => 'コンテンツが制限されてる';

  @override
  String get videoErrorContentRestrictedBody => 'この動画はコンテンツルール違反のため削除されました。';

  @override
  String get videoErrorVerifyAgeBody => 'この動画を見るには年齢確認が必要だよ。';

  @override
  String get videoErrorSkip => 'スキップ';

  @override
  String get videoErrorVerifyAgeButton => '年齢を確認';

  @override
  String get videoErrorVerifyAgeFailed => '年齢を確認できませんでした。もう一回試してみて';

  @override
  String get videoErrorVerifyAgeSignerUnreachable =>
      '確認がタイムアウトしました。接続を確認するか、少し時間をおいてもう一回試してみて';

  @override
  String get videoErrorAdultContentHiddenTitle => 'アダルトコンテンツはオフになってるよ';

  @override
  String get videoErrorAdultContentHiddenBody => 'この動画を見るには、コンテンツフィルターでオンにしてね。';

  @override
  String get videoErrorAdultContentHiddenAction => 'コンテンツフィルターを開く';

  @override
  String get videoDetailLoadError => '動画の読み込みに失敗したよ';

  @override
  String get videoDetailLoadErrorBody => '途中で何かがうまくいきませんでした。もう一度お試しください。';

  @override
  String get videoDetailNotFoundBody =>
      '削除されたか、こちらから届かないか、設定で非表示になっているのかもしれません。';

  @override
  String get databaseCorruptionTitle => 'ローカルデータが壊れちゃった';

  @override
  String get databaseCorruptionBody =>
      'Divine を閉じてもう一度開いてね。自動で直すよ。下書きとクリップはできるだけ残すよ。ほかは読み込み直すよ。';

  @override
  String get databaseCorruptionCloseButton => 'Divine を閉じる';

  @override
  String get videoDetailContextTitle => '共有された動画';

  @override
  String get videoDetailCloseSemanticLabel => '動画プレーヤーを閉じる';

  @override
  String get videoFollowButtonFollow => 'フォロー';

  @override
  String get audioAttributionOriginalSound => 'オリジナルサウンド';

  @override
  String get audioAttributionUnavailableSound => 'サウンドが見つからないよ';

  @override
  String videoInspiredByAttributionMultiple(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return '@$creatorName +$additionalCreatorCount にインスパイアされた';
  }

  @override
  String videoInspiredByAttribution(String creatorName) {
    return '@$creatorName にインスパイアされた';
  }

  @override
  String videoCollaboratorWithOne(String name) {
    return '@$name と';
  }

  @override
  String videoCollaboratorWithMore(String name, int count) {
    return '@$name 他 +$count人と';
  }

  @override
  String videoCollaboratorCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count人のコラボレーター',
    );
    return '$_temp0。タップしてプロフィールを見てね。';
  }

  @override
  String get videoCollaboratorPendingDecoration => '保留中';

  @override
  String get videoCollaboratorPendingSemanticLabel => '保留中のコラボレーター';

  @override
  String videoCollaboratorWithPendingSuffix(String label, int pending) {
    return '$label（$pending 件保留中）';
  }

  @override
  String profileChipTapHint(String name) {
    return '$name。タップしてプロフィールを表示。';
  }

  @override
  String metadataHashtagChipTapHint(String hashtag) {
    return '#$hashtag。タップするとこのハッシュタグの動画を見れるよ。';
  }

  @override
  String get listAttributionFallback => 'リスト';

  @override
  String get shareVideoLabel => '動画を共有';

  @override
  String sharePostSharedWith(String recipientName) {
    return '$recipientNameに投稿を共有したよ';
  }

  @override
  String sharePostSharedWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count人に投稿を共有したよ',
    );
    return '$_temp0';
  }

  @override
  String get shareFailedToSend => '動画の送信がうまくいかなかった';

  @override
  String get shareAddedToBookmarks => 'ブックマークに追加したよ';

  @override
  String get shareRemovedFromBookmarks => 'ブックマークから外したよ';

  @override
  String get shareFailedToAddBookmark => 'ブックマークの追加がうまくいかなかった';

  @override
  String get shareFailedToRemoveBookmark => 'ブックマークを外せなかった';

  @override
  String get shareActionFailed => '操作がうまくいかなかった';

  @override
  String get shareWithTitle => '共有先';

  @override
  String get shareFindPeople => 'ユーザーを検索';

  @override
  String get shareFindPeopleMultiline => 'ユーザーを\n検索';

  @override
  String get shareSent => '送信済み';

  @override
  String shareSelectedRecipientAnnouncement(String name) {
    return '$nameを選択しました';
  }

  @override
  String get shareMessageHint => 'メッセージを追加 (任意)...';

  @override
  String get videoActionUnlike => 'いいねを取り消す';

  @override
  String get videoActionLike => 'いいね';

  @override
  String get videoActionAutoLabel => '自動';

  @override
  String get videoActionLikeLabel => 'いいね';

  @override
  String get videoActionReplyLabel => '返信';

  @override
  String get videoActionRepostLabel => 'リポスト';

  @override
  String get videoActionShareLabel => 'シェア';

  @override
  String get videoActionReportLabel => '報告';

  @override
  String get videoActionReport => '動画を報告';

  @override
  String get videoActionEditLabel => '編集';

  @override
  String get videoActionEdit => '動画を編集';

  @override
  String get videoActionAboutLabel => '詳細';

  @override
  String get videoActionEnableAutoAdvance => '自動送りを有効にする';

  @override
  String get videoActionDisableAutoAdvance => '自動送りを無効にする';

  @override
  String get videoActionRemoveRepost => 'リポストを取り消す';

  @override
  String get videoActionRepost => 'リポスト';

  @override
  String get videoActionViewComments => 'コメントを見る';

  @override
  String get videoActionMoreOptions => 'その他のオプション';

  @override
  String get videoEngagementLikersTitle => 'いいねしたユーザー';

  @override
  String get videoEngagementRepostersTitle => 'リポストしたユーザー';

  @override
  String get videoEngagementLikersEmpty => 'まだいいねがありません';

  @override
  String get videoEngagementRepostersEmpty => 'まだリポストがありません';

  @override
  String get videoEngagementLoadFailed => 'リストを読み込めませんでした';

  @override
  String get videoOverlayOpenMetadataFromTitle => '動画の詳細を開く';

  @override
  String get videoOverlayOpenMetadataFromDescription => '動画の詳細を開く';

  @override
  String get videoOverlayCommentBarHint => 'コメントを追加...';

  @override
  String get videoOverlayCommentBarSemanticLabel => 'コメントを追加';

  @override
  String get videoOverlayCommentBarSendLabel => 'コメントを送信';

  @override
  String get videoOverlayCommentPostedSnackbar => 'コメントを投稿したよ';

  @override
  String get videoOverlayCommentPostFailedSnackbar => 'コメントを投稿できなかったよ';

  @override
  String videoFeedLoopCountLine(String compactCount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ループ',
    );
    return '$compactCount$_temp0';
  }

  @override
  String get metadataBadgeNotDivine => 'Divine 以外';

  @override
  String get metadataBadgeHumanMade => '人間が制作';

  @override
  String get metadataSoundsLabel => 'サウンド';

  @override
  String get metadataOriginalSound => 'オリジナルサウンド';

  @override
  String get metadataVerificationLabel => '認証';

  @override
  String get metadataDeviceAttestation => 'デバイスの認証';

  @override
  String get metadataPgpSignature => 'PGP 署名';

  @override
  String get metadataC2paCredentials => 'C2PA コンテンツ認証情報';

  @override
  String get metadataProofManifest => '証明マニフェスト';

  @override
  String get metadataVerificationInfoTooltip => 'これらのチェックの意味は？';

  @override
  String metadataSectionInfoSemanticsLabel(String section, String question) {
    return '$section。$question';
  }

  @override
  String get metadataVerificationInfoTitle => 'これらのチェックの意味';

  @override
  String get metadataVerificationInfoIntro =>
      'これらのシグナルは、カメラと動画ファイル自体から得られます。動画が持つシグナルが多いほど、その出どころについて証明できることが増えます。';

  @override
  String get metadataVerificationInfoDeviceAttestation =>
      '端末のOSが、撮影したアプリを保証しました。誰かがアップロードしたファイルではなく、カメラから来たことを強く裏づけます。';

  @override
  String get metadataVerificationInfoPgpSignature =>
      '動画は撮影されたその瞬間に暗号署名されました。あとから1フレームでも変えると署名は壊れます。';

  @override
  String get metadataVerificationInfoC2paCredentials =>
      '業界標準の来歴記録がファイルの中に同梱されます。Divine以外のアプリでも確認できます。';

  @override
  String get metadataVerificationInfoProofManifest =>
      'ProofModeの完全な記録：ファイルのフィンガープリント、タイムスタンプ、撮影時の状況が動画と一緒に保存されます。';

  @override
  String get metadataVerificationInfoFootnote =>
      'チェックが欠けていても、その動画が偽物というわけではありません。古いクリップやアップロードには元々ありません。その部分を証明できない、というだけです。';

  @override
  String metadataVerificationInfoLearnMore(String url) {
    return '詳しくは $url をご覧ください';
  }

  @override
  String get metadataCreatorLabel => 'クリエイター';

  @override
  String get metadataCollaboratorsLabel => 'コラボレーター';

  @override
  String get metadataInspiredByLabel => 'インスパイア元';

  @override
  String get metadataRepostedByLabel => 'リポスト元';

  @override
  String metadataMoreReposters(int count) {
    return '他$count人';
  }

  @override
  String metadataLoopsLabel(int count) {
    return 'ループ';
  }

  @override
  String get metadataLikesLabel => 'いいね';

  @override
  String get metadataCommentsLabel => 'コメント';

  @override
  String get metadataRepostsLabel => 'リポスト';

  @override
  String get metadataVineStatsLabel => 'Vineで';

  @override
  String metadataVineStatsLine(
    String loops,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$loopsループ · $likes件のいいね · $comments件のコメント · $reposts件のリポスト';
  }

  @override
  String get metadataDivineStatsLabel => 'Divineで';

  @override
  String metadataDivineStatsLine(
    String views,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$views回再生 · $likes件のいいね · $comments件のコメント · $reposts件のリポスト';
  }

  @override
  String metadataPostedDateSemantics(String date) {
    return '$dateに投稿';
  }

  @override
  String get devOptionsTitle => '開発者オプション';

  @override
  String get devOptionsDisableDeveloperMode => '開発者モードを無効にする';

  @override
  String get devOptionsDisableDeveloperModeSubtitle => '設定から開発者オプションを非表示にする';

  @override
  String get devOptionsDisableDeveloperModeToast => '開発者モードを無効にしました';

  @override
  String get devOptionsShorebirdTitle => 'Shorebirdパッチ';

  @override
  String get devOptionsShorebirdPatchLabel => '実行中のパッチ';

  @override
  String get devOptionsShorebirdNoPatch => 'パッチはインストールされていません';

  @override
  String get devOptionsShorebirdUnavailable => 'このビルドでは利用できません';

  @override
  String get devOptionsShorebirdUnavailableSubtitle =>
      'パッチはshorebird releaseで作成したビルドでのみ動作します。';

  @override
  String get devOptionsShorebirdLoading => 'パッチの状態を読み込み中…';

  @override
  String get devOptionsShorebirdNotChecked => 'ステージングトラックはまだ確認されていません。';

  @override
  String get devOptionsShorebirdCheck => 'ステージングトラックを確認';

  @override
  String get devOptionsShorebirdApply => 'ステージングパッチを適用';

  @override
  String get devOptionsShorebirdUseStable => '安定版アップデートに戻す';

  @override
  String get devOptionsShorebirdChecking => 'ステージングトラックを確認中…';

  @override
  String get devOptionsShorebirdUpdateAvailable => '適用できるステージングパッチがあります。';

  @override
  String get devOptionsShorebirdUpToDate => 'このリリース用のステージングパッチはありません。';

  @override
  String get devOptionsShorebirdRestartRequired =>
      'ダウンロード済みです。読み込むにはアプリを再起動してください。';

  @override
  String get devOptionsShorebirdRollbackRequired =>
      'ロールバックの準備ができました。ベースリリースに戻すには再起動してください。';

  @override
  String get devOptionsShorebirdApplying => 'ダウンロードしてインストール中…';

  @override
  String get devOptionsShorebirdApplied => 'インストール済みです。読み込むにはアプリを再起動してください。';

  @override
  String get devOptionsShorebirdUnchanged =>
      '何もインストールされませんでした。ステージングトラックを確認して再試行してください。';

  @override
  String get devOptionsShorebirdSelectingStableTrack => '安定版トラックを選択中…';

  @override
  String get devOptionsShorebirdStableRestored =>
      '安定版トラックを選択しました。再起動して安定版パッチを確認してください。';

  @override
  String get devOptionsShorebirdFailure => '処理に失敗しました。詳細はログを確認してください。';

  @override
  String get devOptionsPageLoadTimes => 'ページ読み込み時間';

  @override
  String get devOptionsNoPageLoads =>
      'まだページ読み込みの記録がないよ。\nアプリ内を移動するとタイミングデータが出るよ。';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return '表示: ${visibleMs}ms  |  データ: ${dataMs}ms';
  }

  @override
  String get devOptionsSlowestScreens => '最も遅い画面';

  @override
  String get devOptionsVideoPlaybackFormat => '動画再生フォーマット';

  @override
  String get devOptionsSwitchEnvironmentTitle => '環境を切り替える?';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return '$envNameに切り替える?\n\nキャッシュされた動画データがクリアされて、新しいリレーに再接続するよ。';
  }

  @override
  String get devOptionsCancel => 'キャンセル';

  @override
  String get devOptionsSwitch => '切り替え';

  @override
  String devOptionsSwitchedTo(String envName) {
    return '$envNameに切り替えたよ';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return '$formatNameに切り替えた — キャッシュもクリアしたよ';
  }

  @override
  String get featureFlagTitle => '機能フラグ';

  @override
  String get featureFlagResetAllTooltip => 'すべてのフラグを既定値にリセット';

  @override
  String get featureFlagError => 'エラー';

  @override
  String get relaySettingsTitle => 'リレー';

  @override
  String get relaySettingsInfoTitle => 'Divine はオープンなシステム——接続はあなたがコントロールできるよ';

  @override
  String get relaySettingsInfoDescription =>
      'これらのリレーが、あなたのコンテンツを分散型の Nostr ネットワークに届けてくれる。リレーは自由に追加・削除できるよ。';

  @override
  String get relaySettingsLearnMoreNostr => 'Nostr についてもっと詳しく →';

  @override
  String get relaySettingsFindPublicRelays => 'nostr.co.uk でパブリックリレーを探す →';

  @override
  String get relaySettingsAppNotFunctional => 'アプリが動かないよ';

  @override
  String get relaySettingsRequiresRelay =>
      'Divine では、動画の読み込み、コンテンツの投稿、データの同期に少なくとも1つのリレーが必要だよ。';

  @override
  String get relaySettingsRestoreDefaultRelay => '既定のリレーを復元';

  @override
  String get relaySettingsAddCustomRelay => 'カスタムリレーを追加';

  @override
  String get relaySettingsAddRelay => 'リレーを追加';

  @override
  String get relaySettingsRetry => 'もう一回';

  @override
  String get relaySettingsNoStats => 'まだ統計情報がないよ';

  @override
  String get relaySettingsConnection => '接続';

  @override
  String get relaySettingsConnected => '接続済み';

  @override
  String get relaySettingsDisconnected => '切断';

  @override
  String get relaySettingsSessionDuration => 'セッション時間';

  @override
  String get relaySettingsLastConnected => '最終接続';

  @override
  String get relaySettingsDisconnectedLabel => '切断';

  @override
  String get relaySettingsReason => '理由';

  @override
  String get relaySettingsActiveSubscriptions => 'アクティブなサブスクリプション';

  @override
  String get relaySettingsTotalSubscriptions => 'サブスクリプション合計';

  @override
  String get relaySettingsEventsReceived => '受信したイベント';

  @override
  String get relaySettingsEventsSent => '送信したイベント';

  @override
  String get relaySettingsRequestsThisSession => 'このセッションのリクエスト';

  @override
  String get relaySettingsFailedRequests => '失敗したリクエスト';

  @override
  String get relaySettingsLoadingRelayInfo => 'リレー情報を読み込み中...';

  @override
  String get relaySettingsAboutRelay => 'リレーについて';

  @override
  String get relaySettingsSupportedNips => '対応 NIP';

  @override
  String get relaySettingsSoftware => 'ソフトウェア';

  @override
  String get relaySettingsViewWebsite => 'ウェブサイトを見る';

  @override
  String get relaySettingsRemoveRelayTitle => 'リレーを削除する?';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return 'このリレーを本当に削除する?\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveDefaultRelayTitle => 'Divine のリレーを削除する？';

  @override
  String relaySettingsRemoveDefaultRelayMessage(String relayUrl) {
    return 'Divine のリレーを削除すると、アプリの使い心地が悪くなるよ。動画の読み込みや投稿、同期が不安定になることがある。Nostr に慣れている人だけにおすすめだよ。\n\n$relayUrl';
  }

  @override
  String get relaySettingsRemoveRelayTooltip => 'リレーを削除';

  @override
  String get relaySettingsCancel => 'キャンセル';

  @override
  String get relaySettingsRemove => '削除';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return 'リレーを削除したよ: $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay => 'リレーの削除がうまくいかなかった';

  @override
  String get relaySettingsForcingReconnection => 'リレーに再接続中...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    return '$count個のリレーに接続したよ！';
  }

  @override
  String get relaySettingsFailedToConnectCheck => 'リレーに接続できなかった。ネット接続を確認してみて。';

  @override
  String get relaySettingsSavedLocallyPublishPending =>
      'この端末に保存しました。公開がまた動くようになったらアカウントに同期します。';

  @override
  String get relaySettingsAddRelayTitle => 'リレーを追加';

  @override
  String get relaySettingsAddRelayPrompt => '追加したいリレーの WebSocket URL を入力してね:';

  @override
  String get relaySettingsBrowsePublicRelays => 'nostr.co.uk でパブリックリレーを見る';

  @override
  String get relaySettingsAdd => '追加';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return 'リレーを追加したよ: $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      'リレーの追加がうまくいかなかった。URL を確認してもう一回試してみて。';

  @override
  String get relaySettingsInvalidUrl => 'リレー URL は wss:// か ws:// で始める必要があるよ';

  @override
  String get relaySettingsInsecureUrl =>
      'リレー URL は wss:// を使ってね (ws:// は localhost のみ可)';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return '既定のリレーを復元したよ: $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      '既定リレーの復元がうまくいかなかった。ネット接続を確認してみて。';

  @override
  String get relaySettingsCouldNotOpenBrowser => 'ブラウザが開けなかった';

  @override
  String get relaySettingsFailedToOpenLink => 'リンクが開けなかった';

  @override
  String get relaySettingsExternalRelay => '外部リレー';

  @override
  String get relaySettingsNotConnected => '未接続';

  @override
  String relaySettingsDisconnectedAgo(String duration) {
    return '$duration前に切断';
  }

  @override
  String relaySettingsSubscriptionsSummary(int count) {
    return '$count件のサブスク';
  }

  @override
  String relaySettingsEventsSummary(int countValue, String count) {
    return '$count件のイベント';
  }

  @override
  String relaySettingsTimeAgo(String duration) {
    return '$duration前';
  }

  @override
  String get nostrSettingsIntro =>
      'Divine は分散型パブリッシングに Nostr プロトコルを使ってるよ。コンテンツは選んだリレーに置かれて、鍵があなたの ID になる。';

  @override
  String get nostrSettingsSectionNetwork => 'ネットワーク';

  @override
  String get nostrSettingsSectionAccount => 'アカウント';

  @override
  String get nostrSettingsSectionDangerZone => '危険ゾーン';

  @override
  String get nostrSettingsRelays => 'リレー';

  @override
  String get nostrSettingsRelaysSubtitle => 'Nostr リレー接続を管理';

  @override
  String get nostrSettingsRelayDiagnostics => 'リレー診断';

  @override
  String get nostrSettingsRelayDiagnosticsSubtitle => 'リレー接続とネットワークの問題をデバッグ';

  @override
  String get nostrSettingsMediaServers => 'メディアサーバー';

  @override
  String get nostrSettingsMediaServersSubtitle => 'Blossom アップロードサーバーを設定';

  @override
  String get settingsDeveloperOptions => '開発者オプション';

  @override
  String get settingsDeveloperOptionsSubtitle => '環境スイッチャーとデバッグ設定';

  @override
  String get nostrSettingsKeyManagement => '鍵の管理';

  @override
  String get nostrSettingsKeyManagementSubtitle => 'Nostr 鍵をエクスポート、バックアップ、復元';

  @override
  String get nostrSettingsClientAttribution => 'クライアント表記';

  @override
  String get nostrSettingsClientAttributionSubtitle =>
      '公開するイベントに Divine のクライアントタグを含めて、他の Nostr アプリが正しく出典を示せるようにするよ。これがないと、送った報告はモデレーターが確認するときの重みが小さくなるよ。';

  @override
  String get nostrSettingsMoveAccount => 'アカウントを移す';

  @override
  String get nostrSettingsMoveAccountSubtitle =>
      'アーカイブをダウンロードして、投稿や動画を別のリレーまたはメディアサーバーへ移します。';

  @override
  String get nostrSettingsRemoveKeys => 'このデバイスから鍵を削除';

  @override
  String get nostrSettingsRemoveKeysSubtitle =>
      'このデバイスから秘密鍵だけを消すよ。コンテンツはリレーに残るけど、もう一回アカウントを使うには nsec のバックアップが必要になるよ。';

  @override
  String get nostrSettingsCouldNotRemoveKeys =>
      'このデバイスからこのアカウントを削除できなかった。もう一回試してみて。';

  @override
  String get nostrSettingsDeleteAccount => 'アカウントとデータを削除';

  @override
  String get nostrSettingsDeleteAccountSubtitle =>
      'コンテンツの削除リクエストを送信して、このデバイスからサインアウトするよ。リレーやクライアント、検索インデックス、ほかのサインイン中のデバイスにはコピーが残ることがあるよ。';

  @override
  String get relayDiagnosticTitle => 'リレー診断';

  @override
  String get relayDiagnosticRefreshTooltip => '診断を更新';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return '最終更新: $time';
  }

  @override
  String get relayDiagnosticRelayStatus => 'リレーの状態';

  @override
  String get relayDiagnosticInitialized => '初期化済み';

  @override
  String get relayDiagnosticReady => '準備OK';

  @override
  String get relayDiagnosticNotInitialized => '未初期化';

  @override
  String get relayDiagnosticDatabaseEvents => 'データベースイベント';

  @override
  String get relayDiagnosticActiveSubscriptions => 'アクティブなサブスクリプション';

  @override
  String get relayDiagnosticExternalRelays => '外部リレー';

  @override
  String get relayDiagnosticConfigured => '設定済み';

  @override
  String relayDiagnosticRelayCount(int count) {
    return '$count個のリレー';
  }

  @override
  String get relayDiagnosticConnectedLabel => '接続済み';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => '動画イベント';

  @override
  String get relayDiagnosticHomeFeed => 'ホームフィード';

  @override
  String relayDiagnosticVideosCount(int count) {
    return '$count本の動画';
  }

  @override
  String get relayDiagnosticDiscovery => '発見';

  @override
  String get relayDiagnosticLoading => '読み込み中';

  @override
  String get relayDiagnosticYes => 'はい';

  @override
  String get relayDiagnosticNo => 'いいえ';

  @override
  String get relayDiagnosticTestDirectQuery => 'ダイレクトクエリをテスト';

  @override
  String get relayDiagnosticNetworkConnectivity => 'ネットワーク接続';

  @override
  String get relayDiagnosticRunNetworkTest => 'ネットワークテストを実行';

  @override
  String get relayDiagnosticBlossomServer => 'Blossom サーバー';

  @override
  String get relayDiagnosticTestAllEndpoints => 'すべてのエンドポイントをテスト';

  @override
  String get relayDiagnosticStatus => 'ステータス';

  @override
  String get relayDiagnosticUrl => 'URL';

  @override
  String get relayDiagnosticError => 'エラー';

  @override
  String get relayDiagnosticFunnelCakeApi => 'FunnelCake API';

  @override
  String get relayDiagnosticBaseUrl => 'ベース URL';

  @override
  String get relayDiagnosticSummary => 'サマリー';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount OK (平均 ${avgMs}ms)';
  }

  @override
  String get relayDiagnosticRetestAll => 'すべて再テスト';

  @override
  String get relayDiagnosticRetrying => '再試行中...';

  @override
  String get relayDiagnosticRetryConnection => '接続を再試行';

  @override
  String get relayDiagnosticTroubleshooting => 'トラブルシューティング';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• 緑 = 接続済み・動いてるよ\n• 赤 = 接続に失敗\n• ネットワークテストが失敗するなら、ネット接続を確認してね\n• リレーが設定されてるのに繋がらないなら [接続を再試行] をタップしてみて\n• デバッグ用にこの画面をスクショしておくといいよ';

  @override
  String get relayDiagnosticAllEndpointsHealthy => 'すべての REST エンドポイントが正常だよ！';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      '一部の REST エンドポイントが失敗してる - 上の詳細を見てね';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    return 'データベースで$count件の動画イベントが見つかったよ';
  }

  @override
  String get relayDiagnosticQueryFailed => 'クエリがうまくいかなかった。もう一回試してみて。';

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    return '$count個のリレーに接続したよ！';
  }

  @override
  String get relayDiagnosticFailedToConnect => 'どのリレーにも接続できなかった';

  @override
  String get relayDiagnosticConnectionRetryFailed =>
      '接続の再試行がうまくいかなかった。もう一回試してみて。';

  @override
  String get relayDiagnosticConnectedAuthenticated => '接続・認証済み';

  @override
  String get relayDiagnosticConnectedOnly => '接続済み';

  @override
  String get relayDiagnosticNotConnected => '未接続';

  @override
  String get relayDiagnosticNoRelaysConfigured => 'リレーが設定されてないよ';

  @override
  String get relayDiagnosticFailed => '失敗';

  @override
  String get notificationSettingsTitle => '通知';

  @override
  String get notificationSettingsResetTooltip => '既定値にリセット';

  @override
  String get notificationSettingsTypes => '通知の種類';

  @override
  String get notificationSettingsLikes => 'いいね';

  @override
  String get notificationSettingsLikesSubtitle => '誰かがあなたの動画にいいねした時';

  @override
  String get notificationSettingsComments => 'コメント';

  @override
  String get notificationSettingsCommentsSubtitle => '誰かがあなたの動画にコメントした時';

  @override
  String get notificationSettingsFollows => 'フォロー';

  @override
  String get notificationSettingsFollowsSubtitle => '誰かがあなたをフォローした時';

  @override
  String get notificationSettingsMentions => 'メンション';

  @override
  String get notificationSettingsMentionsSubtitle => 'あなたがメンションされた時';

  @override
  String get notificationSettingsReposts => 'リポスト';

  @override
  String get notificationSettingsRepostsSubtitle => '誰かがあなたの動画をリポストした時';

  @override
  String get notificationSettingsNewPosts => '新しい動画';

  @override
  String get notificationSettingsNewPostsSubtitle => 'フォロー中の人が投稿した時';

  @override
  String get notificationSettingsActions => 'アクション';

  @override
  String get notificationSettingsMarkAllAsRead => 'すべて既読にする';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle => 'すべての通知を既読にするよ';

  @override
  String get notificationSettingsAllMarkedAsRead => 'すべての通知を既読にしたよ';

  @override
  String get notificationSettingsMarkAllAsReadFailed => 'すべて既読にできなかったよ';

  @override
  String get notificationSettingsResetToDefaults => '設定を既定値にリセットしたよ';

  @override
  String get notificationSettingsAbout => '通知について';

  @override
  String get notificationSettingsAboutDescription =>
      '通知は Nostr プロトコルで動いてるよ。リアルタイム更新は Nostr リレーへの接続に依存するから、遅れることもあるよ。';

  @override
  String get safetySettingsWhatYouSee => 'あなたが見るもの';

  @override
  String get safetySettingsWhatYouPublish => 'あなたが公開するもの';

  @override
  String get safetySettingsShowDivineHostedOnly => 'Divine ホスト動画だけ表示';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle => '他のメディアホストの動画を隠す';

  @override
  String get safetySettingsModeration => 'モデレーション';

  @override
  String get safetySettingsBlockedUsers => 'ブロック済みユーザー';

  @override
  String get safetySettingsAgeVerification => '年齢確認';

  @override
  String get safetySettingsAgeConfirmation => '18歳以上であることを確認する';

  @override
  String get safetySettingsAgeRequired => 'アダルトコンテンツの閲覧に必要だよ';

  @override
  String get safetySettingsAgeLockedForMinor => 'あなたのアカウントではロックされてるよ';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle => '公式モデレーションサービス (既定でオン)';

  @override
  String get safetySettingsPeopleIFollow => 'フォロー中のユーザー';

  @override
  String get safetySettingsPeopleIFollowSubtitle => 'フォローしてる人のラベルを購読';

  @override
  String get safetySettingsAddCustomLabeler => 'カスタムラベラーを追加';

  @override
  String get safetySettingsAddCustomLabelerHint => 'npub を入力...';

  @override
  String get safetySettingsAddCustomLabelerListTitle => 'カスタムラベラーを追加';

  @override
  String get safetySettingsRemoveLabeler => 'ラベラーを削除';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle => 'npub アドレスを入力してね';

  @override
  String get safetySettingsNoBlockedUsers => 'ブロック済みユーザーはいないよ';

  @override
  String get safetySettingsUnblock => 'ブロック解除';

  @override
  String get safetySettingsUserUnblocked => 'ブロックを解除したよ';

  @override
  String get safetySettingsCancel => 'キャンセル';

  @override
  String get safetySettingsAdd => '追加';

  @override
  String get analyticsTitle => 'クリエイター分析';

  @override
  String get analyticsDiagnosticsTooltip => '診断';

  @override
  String get analyticsDiagnosticsSemanticLabel => '診断を切り替え';

  @override
  String get analyticsRetry => 'もう一回';

  @override
  String get analyticsUnableToLoad => '分析データを読み込めなかった。';

  @override
  String get analyticsServerUnavailable =>
      'Creator analytics is having server trouble. Please try again in a moment.';

  @override
  String get analyticsConnectionIssue =>
      'Creator analytics could not connect. Check your connection and try again.';

  @override
  String get analyticsSignInRequired => 'クリエイター分析を見るにはサインインしてね。';

  @override
  String get analyticsViewDataUnavailable =>
      'これらの投稿の視聴データは今のところリレーから取得できないよ。いいね・コメント・リポストの数値は正確だよ。';

  @override
  String get analyticsViewDataTitle => '視聴データ';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return '更新 $time • スコアは Funnelcake で利用可能な場合、いいね、コメント、リポスト、視聴/ループを使ってるよ。';
  }

  @override
  String get analyticsVideos => '動画';

  @override
  String get analyticsViews => '視聴';

  @override
  String get analyticsInteractions => 'インタラクション';

  @override
  String get analyticsEngagement => 'エンゲージメント';

  @override
  String get analyticsFollowers => 'フォロワー';

  @override
  String get analyticsAvgPerPost => '投稿あたり平均';

  @override
  String get analyticsInteractionMix => 'インタラクション構成';

  @override
  String get analyticsLikes => 'いいね';

  @override
  String get analyticsComments => 'コメント';

  @override
  String get analyticsReposts => 'リポスト';

  @override
  String get analyticsPerformanceHighlights => 'パフォーマンスハイライト';

  @override
  String get analyticsMostViewed => '最も見られた';

  @override
  String get analyticsMostDiscussed => '最も話題になった';

  @override
  String get analyticsMostReposted => '最もリポストされた';

  @override
  String get analyticsNoVideosYet => '動画はまだないよ';

  @override
  String get analyticsViewDataUnavailableShort => '視聴データなし';

  @override
  String analyticsViewsCount(int countValue, String count) {
    return '$count回視聴';
  }

  @override
  String analyticsCommentsCount(int countValue, String count) {
    return '$count件のコメント';
  }

  @override
  String analyticsRepostsCount(int countValue, String count) {
    return '$count件のリポスト';
  }

  @override
  String get analyticsTopContent => 'トップコンテンツ';

  @override
  String get analyticsPublishPrompt => 'ランキングを見るには動画をいくつか公開してみて。';

  @override
  String get analyticsEngagementRateExplainer =>
      '右の % = エンゲージメント率 (インタラクション数 ÷ 視聴数)。';

  @override
  String get analyticsEngagementRateNoViews =>
      'エンゲージメント率には視聴データが必要。視聴データが揃うまで N/A と出るよ。';

  @override
  String get analyticsEngagementLabel => 'エンゲージメント';

  @override
  String get analyticsViewsUnavailable => '視聴データなし';

  @override
  String analyticsInteractionsCount(int countValue, String count) {
    return '$count件のインタラクション';
  }

  @override
  String get analyticsPostAnalytics => '投稿の分析';

  @override
  String get analyticsOpenPost => '投稿を開く';

  @override
  String get analyticsRecentDailyInteractions => '最近の日別インタラクション';

  @override
  String get analyticsNoActivityYet => 'この期間のアクティビティはまだないよ。';

  @override
  String get analyticsDailyInteractionsExplainer =>
      'インタラクション = 投稿日ごとの いいね + コメント + リポスト。';

  @override
  String get analyticsDailyBarExplainer => 'バーの長さはこの期間で最も多かった日を基準にした相対値だよ。';

  @override
  String get analyticsAudienceSnapshot => 'オーディエンスの概要';

  @override
  String analyticsFollowersCount(String count) {
    return 'フォロワー: $count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return 'フォロー中: $count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      'Funnelcake がオーディエンス分析エンドポイントを追加したら、ソース/地域/時間帯の内訳がここに入るよ。';

  @override
  String get analyticsRetention => 'リテンション';

  @override
  String get analyticsRetentionWithViews =>
      'Funnelcake からリテンションデータが届いたら、リテンションカーブと視聴時間の内訳がここに出るよ。';

  @override
  String get analyticsRetentionWithoutViews =>
      'Funnelcake から視聴+視聴時間の分析が返されるまで、リテンションデータは使えないよ。';

  @override
  String get analyticsDiagnostics => '診断';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return '動画合計: $count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return '視聴ありの動画: $count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return '視聴なしの動画: $count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return '取得済み (bulk): $count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return '取得済み (/views): $count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return 'ソース: $sources';
  }

  @override
  String analyticsDiagnosticsFailedSources(String sources) {
    return 'Failed sources: $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => 'フィクスチャデータを使う';

  @override
  String get analyticsNa => 'N/A';

  @override
  String get authCreateNewAccount => '新しい Divine アカウントを作ろう';

  @override
  String get authCreateNewAccountShort => '新しいアカウントを作成';

  @override
  String get authSignInDifferentAccount => '別のアカウントでサインイン';

  @override
  String get authUseAnotherAccount => '別のアカウントを使う';

  @override
  String authContinueAs(String displayName) {
    return '$displayName として続ける';
  }

  @override
  String get authRecoveryDraftsOwner => '下書きとクリップはこのアカウントに保存されています';

  @override
  String get authRecoveryOtherAccountWarning => 'ここでサインインするとそれらが非表示になります';

  @override
  String get authTermsPrefix => '下のオプションを選ぶことで、あなたは16歳以上である（または';

  @override
  String get authTermsAgeAuthorizationCta => 'Divine の年齢認証';

  @override
  String get authTermsAfterAgeAuthorization => 'を完了した）ことを確認し、次に同意します: ';

  @override
  String get authTermsOfService => '利用規約';

  @override
  String get authPrivacyPolicy => 'プライバシーポリシー';

  @override
  String get authTermsAnd => '、そして ';

  @override
  String get authSafetyStandards => '安全基準';

  @override
  String get authAmberNotInstalled => 'Amber アプリがインストールされてないよ';

  @override
  String get authAmberConnectionFailed => 'Amber との接続がうまくいかなかった';

  @override
  String get authPasswordResetSent => 'そのメールアドレスのアカウントがあれば、パスワードリセットリンクを送ったよ。';

  @override
  String get authSignInTitle => 'サインイン';

  @override
  String get authEmailLabel => 'メールアドレス';

  @override
  String get authPasswordLabel => 'パスワード';

  @override
  String get authConfirmPasswordLabel => 'パスワードの確認';

  @override
  String get authEmailRequired => 'メールは必須だよ';

  @override
  String get authEmailInvalid => '有効なメールアドレスを入力してね';

  @override
  String get authPasswordRequired => 'パスワードは必須だよ';

  @override
  String get authConfirmPasswordRequired => 'パスワードを確認してね';

  @override
  String get authPasswordsDoNotMatch => 'パスワードが一致しないよ';

  @override
  String get authForgotPassword => 'パスワードを忘れた?';

  @override
  String get authImportNostrKey => 'Nostr 鍵をインポート';

  @override
  String get authConnectSignerApp => '署名アプリで接続';

  @override
  String get authSignInWithAmber => 'Amber でサインイン';

  @override
  String get authSignInWithBrowserExtension => 'ブラウザ拡張機能でサインイン';

  @override
  String get authNip07ConnectionFailed => 'ブラウザ拡張機能に接続できませんでした。';

  @override
  String get authNip07ExtensionNotFound =>
      'ブラウザ拡張機能が見つかりません。Alby、nos2x、またはその他の NIP-07 対応拡張機能をインストールしてください。';

  @override
  String get authSignInOptionsTitle => 'サインインオプション';

  @override
  String get authInfoEmailPasswordTitle => 'メールとパスワード';

  @override
  String get authInfoEmailPasswordDescription =>
      'Divine アカウントでサインインするよ。メールとパスワードで登録した人はそれを使ってね。';

  @override
  String get authInfoImportNostrKeyDescription =>
      'もう Nostr ID を持ってる? 別のクライアントから nsec 秘密鍵をインポートしてね。';

  @override
  String get authInfoSignerAppTitle => '署名アプリ';

  @override
  String get authInfoSignerAppDescription =>
      'nsecBunker みたいな NIP-46 対応のリモート署名アプリで接続すれば、鍵のセキュリティを強化できるよ。';

  @override
  String get authInfoAmberTitle => 'Amber';

  @override
  String get authInfoAmberDescription =>
      'Android 向けの Amber 署名アプリで、Nostr 鍵を安全に管理できるよ。';

  @override
  String get authInfoBrowserExtensionTitle => 'ブラウザ拡張機能';

  @override
  String get authInfoBrowserExtensionDescription =>
      'Alby や nos2x のような NIP-07 ブラウザ拡張機能でサインインします。鍵は拡張機能内に保持され、Divine からは見えません。';

  @override
  String get authSignInErrorInvalidCredentials =>
      'メールアドレスまたはパスワードが違います。もう一度お試しください。';

  @override
  String get authSignInErrorEmailNotVerified =>
      'サインインする前にメールを認証してください。受信トレイのリンクを確認してください。';

  @override
  String get authSignInErrorInvalidEmail => '有効なメールアドレスではないようです。';

  @override
  String get authSignInErrorNetwork => 'サーバーに接続できません。接続を確認してもう一度お試しください。';

  @override
  String get authSignInErrorGeneric => '問題が発生しました。もう一度お試しください。';

  @override
  String get authSignInOptionsHintPrefix => '前回どうやってログインしたか分かりませんか? ';

  @override
  String get authSignInOptionsHintCta => 'すべてのサインイン方法を見る';

  @override
  String get authCreateAccountTitle => 'アカウントを作ろう';

  @override
  String get authBackToInviteCode => '招待コードに戻る';

  @override
  String get authUseDivineNoBackup => 'バックアップなしで Divine を使う';

  @override
  String get authSkipConfirmTitle => '最後にひとつだけ...';

  @override
  String get authSkipConfirmKeyCreated => 'やった！ Divine アカウントを動かす安全な鍵を作るよ。';

  @override
  String get authSkipConfirmKeyOnly => 'メールなしだと、この鍵がアカウントがあなたのものだと知る唯一の手段になるよ。';

  @override
  String get authSkipConfirmRecommendEmail =>
      'アプリ内で鍵にアクセスできるけど、技術に詳しくないなら今すぐメールとパスワードを追加するのがおすすめ。サインインが楽になるし、デバイスを失くしたりリセットした時にアカウントを復元しやすくなるよ。';

  @override
  String get authAddEmailPassword => 'メールとパスワードを追加';

  @override
  String get authUseThisDeviceOnly => 'このデバイスのみ使う';

  @override
  String get authCompleteRegistration => '登録を完了';

  @override
  String get authVerifying => '確認中...';

  @override
  String get authVerificationLinkSent => '認証リンクを送ったよ:';

  @override
  String get authClickVerificationLink => '登録を完了するには、メール内のリンクをクリックしてね。';

  @override
  String get authPleaseWaitVerifying => 'メールを確認中。ちょっと待ってね...';

  @override
  String get authWaitingForVerification => '認証を待ってるよ';

  @override
  String get authOpenEmailApp => 'メールアプリを開く';

  @override
  String get authVerificationPinPrompt => 'または、メールに届いた6桁のコードを入力';

  @override
  String get authVerificationPinFieldLabel => '6桁のコード';

  @override
  String get authVerificationPinSubmit => 'コードを確認';

  @override
  String get authVerificationResendPrompt => '届かなかった?';

  @override
  String get authVerificationResend => '再送信';

  @override
  String authVerificationResendCooldown(String time) {
    return '再送信まで $time';
  }

  @override
  String get authVerificationResendFailed => 'メールを再送信できなかったよ。もう一回試してみて。';

  @override
  String get authVerificationResendExpired =>
      'その登録は期限切れです。新しいコードを受け取るには最初からやり直してください。';

  @override
  String get authVerificationResendUnavailable =>
      '今は再送信できません。すでにお送りしたメールに記載の6桁のコードをお使いください。';

  @override
  String get authVerificationPollingStopped =>
      '自動確認を停止しました。ログインを完了するには、メールに記載の6桁のコードを入力してください。';

  @override
  String get authWelcomeToDivine => 'やった！入れたよ！';

  @override
  String get authEmailVerified => 'メールアドレスを確認したよ。';

  @override
  String get authSigningYouIn => 'サインイン中';

  @override
  String get authErrorTitle => 'おっと。';

  @override
  String get authVerificationFailed => 'メールの確認がうまくいかなかった。\nもう一回試してみて。';

  @override
  String get authStartOver => '最初からやり直す';

  @override
  String get authEmailVerifiedLogin => 'メールを確認したよ！ ログインして続けてね。';

  @override
  String get authVerificationLinkExpired => 'この認証リンクはもう使えないよ。';

  @override
  String get authVerificationConnectionError =>
      'メールを確認できなかった。接続を確認してもう一回試してみて。';

  @override
  String get authWaitlistConfirmTitle => '登録完了！';

  @override
  String authWaitlistUpdatesAt(String email) {
    return 'アップデートは $email に送るね。\n招待コードが使えるようになったら、すぐお知らせするよ。';
  }

  @override
  String get authOk => 'OK';

  @override
  String get authTryAgain => 'もう一回';

  @override
  String get authContactSupport => 'サポートに連絡';

  @override
  String authCouldNotOpenEmail(String email) {
    return '$email が開けなかった';
  }

  @override
  String get authAddInviteCode => '招待コードを入力';

  @override
  String get authInviteCodeLabel => '招待コード';

  @override
  String get authEnterYourCode => 'コードを入力';

  @override
  String get authNext => '次へ';

  @override
  String get authJoinWaitlist => 'ウェイトリストに参加';

  @override
  String get authJoinWaitlistTitle => 'ウェイトリストに参加';

  @override
  String get authJoinWaitlistDescription =>
      'メールアドレスを教えてね。アクセス開放に合わせてアップデートを送るよ。';

  @override
  String get authJoinWaitlistNewsletterOptIn => 'Divine のインスピレーションを送ってほしい';

  @override
  String get authInviteAccessHelp => '招待アクセスのヘルプ';

  @override
  String get authGeneratingConnection => '接続を生成中...';

  @override
  String get authConnectedAuthenticating => '接続OK！認証中...';

  @override
  String get authConnectionTimedOut => '接続がタイムアウトした';

  @override
  String get authApproveConnection => '署名アプリで接続を承認したか確認してね。';

  @override
  String get authConnectionCancelled => '接続がキャンセルされた';

  @override
  String get authConnectionCancelledMessage => '接続はキャンセルされたよ。';

  @override
  String get authConnectionFailed => '接続がうまくいかなかった';

  @override
  String get authUnknownError => '不明なエラーが起きた。';

  @override
  String get authNostrConnectStartFailed => '署名アプリにつながらなかった。接続を確認してもう一回試してみて。';

  @override
  String get authNostrConnectInvalidSession => 'この接続リンクはもう使えないよ。新しいリンクで始めてね。';

  @override
  String get authNostrConnectSetupFailed => 'あと少し——サインインを完了できなかったよ。もう一回試してみて。';

  @override
  String get authUrlCopied => 'URL をコピーしたよ';

  @override
  String get authConnectToDivine => 'Divine に接続';

  @override
  String get authPasteBunkerUrl => 'bunker:// URL を貼り付け';

  @override
  String get authBunkerUrlHint => 'bunker:// URL';

  @override
  String get authInvalidBunkerUrl => '無効な bunker URL だよ。bunker:// で始めてね';

  @override
  String get authScanSignerApp => '署名アプリで\nスキャンして接続してね。';

  @override
  String authWaitingForConnection(int seconds) {
    return '接続を待ってるよ... $seconds秒';
  }

  @override
  String get authCopyUrl => 'URL をコピー';

  @override
  String get authShare => '共有';

  @override
  String get authAddBunker => 'bunker を追加';

  @override
  String get authCompatibleSignerApps => '対応する署名アプリ';

  @override
  String get authFailedToConnect => '接続がうまくいかなかった';

  @override
  String get authResetPasswordTitle => 'パスワードをリセット';

  @override
  String get authResetPasswordSubtitle => '新しいパスワードを入れてね。8文字以上にしてね。';

  @override
  String get authNewPasswordLabel => '新しいパスワード';

  @override
  String get authConfirmNewPasswordLabel => '新しいパスワードの確認';

  @override
  String get authPasswordTooShort => 'パスワードは8文字以上にしてね';

  @override
  String get authPasswordResetSuccess => 'パスワードをリセットしたよ。ログインしてね。';

  @override
  String get authPasswordResetFailed => 'パスワードのリセットがうまくいかなかった';

  @override
  String get authUnexpectedError => '予期しないエラーが起きた。もう一回試してみて。';

  @override
  String get authUpdatePassword => 'パスワードを更新';

  @override
  String get authSecureAccountTitle => 'アカウントを守ろう';

  @override
  String get authUnableToAccessKeys => '鍵にアクセスできなかった。もう一回試してみて。';

  @override
  String get authRegistrationFailed => '登録がうまくいかなかった';

  @override
  String get authRegistrationComplete => '登録完了。メールを確認してね。';

  @override
  String get authSecureAccountAlreadyRegistered =>
      'Looks like an account already exists. Try a different email, or sign in to the existing account with this email address. If neither works, contact support.';

  @override
  String get authFailedToSendResetEmail => 'リセットメールの送信がうまくいかなかった。';

  @override
  String get authSending => '送信中...';

  @override
  String get authSignInButton => 'サインイン';

  @override
  String get authVerificationErrorTimeout => '認証がタイムアウトした。もう一回登録を試してみて。';

  @override
  String get authVerificationErrorMissingCode => '認証がうまくいかなかった — 認可コードがないよ。';

  @override
  String get authVerificationErrorPollFailed => '認証がうまくいかなかった。もう一回試してみて。';

  @override
  String get authVerificationErrorNetworkExchange =>
      'サインイン中にネットワークエラーが起きた。もう一回試してみて。';

  @override
  String get authVerificationErrorOAuthExchange => '認証がうまくいかなかった。もう一回登録を試してみて。';

  @override
  String get authVerificationErrorSignInFailed =>
      'サインインがうまくいかなかった。手動でログインしてみて。';

  @override
  String get authVerificationEmailAlreadyRegistered =>
      'このメールアドレスはすでに登録されているよ。代わりにログインしてね。';

  @override
  String get authVerificationErrorPinInvalid => 'コードが一致しなかったよ。もう一度確認して試してみて。';

  @override
  String get authVerificationErrorPinExpired =>
      'そのコードは期限切れだよ。再送信をタップして新しいのをもらってね。';

  @override
  String get authVerificationErrorPinLocked =>
      '試行回数が多すぎるよ。再送信をタップして新しいコードをもらってね。';

  @override
  String get authVerificationErrorPinFailed => 'そのコードを確認できなかったよ。もう一回試してみて。';

  @override
  String get authVerificationErrorPinUnavailable =>
      '今はコード入力が使えないよ。メールのリンクをタップするか、再送信で新しいのをもらってね。';

  @override
  String get authInviteCodeErrorMalformed => 'ABCD-EFGH のような招待コードを入力してください。';

  @override
  String get authInviteCodeErrorNotFound => 'その招待コードは有効ではないようです。';

  @override
  String get authInviteCodeErrorAlreadyUsed => 'その招待コードはすでに使用済みか、無効になっています。';

  @override
  String get authInviteGateErrorCreatorFull => 'このクリエイターの招待枠はいっぱいです';

  @override
  String get authInviteGateErrorUnavailable =>
      'その招待コードは利用できません。順番待ちリストに登録すると、空きが出しだい招待をお送りします。';

  @override
  String get authInviteGateErrorCheckFailed => 'そのコードを確認できませんでした。もう一度お試しください。';

  @override
  String get authInviteGateErrorUnknown => '問題が発生しました。招待コードをもう一度お試しください。';

  @override
  String get authInviteErrorAlreadyUsed =>
      'その招待コードはもう使えないよ。招待コードに戻るか、ウェイトリストに参加するか、サポートに連絡してね。';

  @override
  String get authInviteErrorInvalid =>
      'その招待コードは今は使えないよ。招待コードに戻るか、ウェイトリストに参加するか、サポートに連絡してね。';

  @override
  String get authInviteErrorTemporary =>
      '今は招待を確認できなかった。招待コードに戻ってもう一回試すか、サポートに連絡してね。';

  @override
  String get authInviteErrorUnknown =>
      '招待を有効にできなかった。招待コードに戻るか、ウェイトリストに参加するか、サポートに連絡してね。';

  @override
  String get shareSheetSave => '保存';

  @override
  String get shareSheetRemoveFromSaved => '保存を外す';

  @override
  String get shareSheetSaveToGallery => 'ギャラリーに保存';

  @override
  String get shareSheetSaveWithWatermark => 'ウォーターマーク付きで保存';

  @override
  String get shareSheetSaveVideo => '動画を保存';

  @override
  String get shareSheetAddToClips => 'クリップに追加';

  @override
  String get shareSheetNameClipTitle => 'このクリップに名前を付ける';

  @override
  String get shareSheetNameClipSubtitle => 'ライブラリで見つけやすい名前を付けてね。';

  @override
  String get shareSheetClipTitleLabel => 'クリップのタイトル';

  @override
  String get shareSheetSaveClip => 'クリップを保存';

  @override
  String shareSheetSavedClipToClips(String title) {
    return '「$title」をクリップに保存したよ';
  }

  @override
  String get shareSheetUntitledClip => '無題のクリップ';

  @override
  String get shareSheetAddToClipsFailed => 'クリップに追加できませんでした';

  @override
  String get shareSheetAddToList => 'リストに追加';

  @override
  String get shareSheetCopy => 'コピー';

  @override
  String get shareSheetShareVia => '他のアプリで共有';

  @override
  String get shareSheetEventJson => 'イベント JSON';

  @override
  String get shareSheetEventId => 'イベント ID';

  @override
  String get shareSheetMoreActions => 'その他のアクション';

  @override
  String get shareSheetCrosspost => 'クロス投稿';

  @override
  String get crosspostSheetTitle => 'この動画をクロス投稿';

  @override
  String get crosspostSheetSubtitle => '連携中のプラットフォームに送るよ。投稿には数分かかることがあるよ。';

  @override
  String get crosspostSubmit => 'クロス投稿';

  @override
  String get crosspostStatusQueued => '待機中';

  @override
  String get crosspostStatusUploading => 'アップロード中';

  @override
  String get crosspostStatusProcessing => '処理中';

  @override
  String get crosspostStatusPosted => '投稿済み';

  @override
  String get crosspostStatusFailed => '失敗';

  @override
  String get crosspostStatusSkipped => 'スキップ';

  @override
  String get crosspostStatusNeedsReauth => '再接続が必要';

  @override
  String get crosspostViewPost => '投稿を見る';

  @override
  String crosspostReconnectPrompt(String platform) {
    return '投稿を続けるには、クロス投稿設定で $platform を接続し直してね。';
  }

  @override
  String get crosspostReconnect => '再接続';

  @override
  String get crosspostErrorNotOwner => 'クロス投稿できるのは自分の動画だけだよ。';

  @override
  String get crosspostErrorNotEligible => 'この動画はクロス投稿の対象外だよ。';

  @override
  String get crosspostErrorNotConnected => 'そのプラットフォームは連携されていないよ。';

  @override
  String get crosspostErrorUnauthorized => 'アカウントを接続し直して、もう一回試してね。';

  @override
  String get crosspostErrorNetwork => 'クロス投稿サービスに接続できなかったよ。少し待ってからもう一回試してみて。';

  @override
  String get crosspostFailedGeneric => 'クロス投稿に失敗したよ。';

  @override
  String get crosspostStillWorking => 'まだ処理中だよ。これは閉じても大丈夫 — 投稿はバックグラウンドで続くよ。';

  @override
  String get crosspostDone => '完了';

  @override
  String get watermarkDownloadSavedToCameraRoll => 'カメラロールに保存したよ';

  @override
  String get watermarkDownloadShare => '共有';

  @override
  String get watermarkDownloadDone => '完了';

  @override
  String get watermarkDownloadPhotosAccessNeeded => '写真へのアクセスが必要';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      '動画を保存するには、設定で写真へのアクセスを許可してね。';

  @override
  String get watermarkDownloadOpenSettings => '設定を開く';

  @override
  String get watermarkDownloadNotNow => '今はいい';

  @override
  String get watermarkDownloadFailed => 'ダウンロードがうまくいかなかった';

  @override
  String get watermarkDownloadDismiss => '閉じる';

  @override
  String get watermarkDownloadStageDownloading => '動画をダウンロード中';

  @override
  String get watermarkDownloadStageWatermarking => 'ウォーターマークを追加中';

  @override
  String get watermarkDownloadStageSaving => 'カメラロールに保存中';

  @override
  String get watermarkDownloadStageDownloadingDesc => 'ネットワークから動画を取ってるよ...';

  @override
  String get watermarkDownloadStageWatermarkingDesc =>
      'Divine ウォーターマークを追加してるよ...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      'ウォーターマーク付き動画をカメラロールに保存してるよ...';

  @override
  String get shareMenuBookmarks => 'ブックマーク';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    return 'フォローセット$count個あるよ';
  }

  @override
  String get peopleListsAddToList => 'リストに追加';

  @override
  String get peopleListsSheetTitle => 'リストに追加';

  @override
  String get peopleListsEmptyTitle => 'リストがありません';

  @override
  String get peopleListsEmptySubtitle => 'リストを作成して人々をグループ化しましょう。';

  @override
  String get peopleListsCreateList => 'リストを作成';

  @override
  String get peopleListsNewListTitle => '新しいリスト';

  @override
  String get peopleListsRouteTitle => 'ピープルリスト';

  @override
  String get peopleListsListNameLabel => 'リスト名';

  @override
  String get peopleListsListNameHint => '仲の良い友達';

  @override
  String get peopleListsCreateButton => '作成';

  @override
  String get peopleListsAddPeopleTitle => 'ユーザーを追加';

  @override
  String get peopleListsAddPeopleTooltip => 'ユーザーを追加';

  @override
  String get peopleListsAddPeopleSemanticLabel => 'リストにユーザーを追加';

  @override
  String get peopleListsListNotFoundTitle => 'リストが見つかりません';

  @override
  String get peopleListsListNotFoundSubtitle => 'リストが見つかりません。削除された可能性があります。';

  @override
  String get peopleListsListDeletedSubtitle => 'このリストは削除された可能性があります。';

  @override
  String get peopleListsNoPeopleTitle => 'このリストにユーザーはいません';

  @override
  String get peopleListsNoPeopleSubtitle => '始めるにはユーザーを追加してください';

  @override
  String get peopleListsNoVideosTitle => 'まだ動画がありません';

  @override
  String get peopleListsNoVideosSubtitle => 'リストメンバーの動画がここに表示されます';

  @override
  String get peopleListsNoVideosAvailable => '利用可能な動画がありません';

  @override
  String get peopleListsFailedToLoadVideos => '動画の読み込みに失敗しました';

  @override
  String get peopleListsVideoNotAvailable => '動画は利用できません';

  @override
  String get peopleListsBackToGridTooltip => 'グリッドに戻る';

  @override
  String get peopleListsErrorLoadingVideos => '動画の読み込みエラー';

  @override
  String get peopleListsNoPeopleToAdd => '追加できるユーザーがいません。';

  @override
  String peopleListsAddToListName(String name) {
    return '$nameに追加';
  }

  @override
  String get peopleListsAddPeopleSearchHint => 'ユーザーを検索';

  @override
  String get peopleListsAddPeopleError => 'ユーザーを読み込めませんでした。もう一度お試しください。';

  @override
  String get peopleListsAddPeopleRetry => '再試行';

  @override
  String get peopleListsAddButton => '追加';

  @override
  String peopleListsAddButtonWithCount(int count) {
    return '$count人追加';
  }

  @override
  String peopleListsInNLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件のリストに含まれています',
    );
    return '$_temp0';
  }

  @override
  String peopleListsRemoveConfirmTitle(String name) {
    return '$nameを削除しますか？';
  }

  @override
  String get peopleListsRemoveConfirmBody => 'このリストから削除されます。';

  @override
  String get peopleListsRemove => '削除';

  @override
  String peopleListsRemovedFromList(String name) {
    return '$nameをリストから削除しました';
  }

  @override
  String get peopleListsUndo => '元に戻す';

  @override
  String peopleListsProfileLongPressHint(String name) {
    return '$nameのプロフィール。長押しで削除。';
  }

  @override
  String peopleListsViewProfileHint(String name) {
    return '$nameのプロフィールを表示';
  }

  @override
  String get shareMenuEditVideo => '動画を編集';

  @override
  String get shareMenuDeleteVideo => '動画を削除';

  @override
  String shareMenuVideoCount(int count) {
    return '$count本の動画';
  }

  @override
  String get shareMenuDeleteConfirmation =>
      'この動画はDivineから完全に削除されます。他のリレーを使うサードパーティのNostrクライアントには、まだ表示される場合があります。';

  @override
  String get shareMenuCancel => 'キャンセル';

  @override
  String get shareMenuDelete => '削除';

  @override
  String get shareMenuDeleteFailedNotInitialized =>
      '削除の準備がまだだよ。少し待ってからもう一度試してね。';

  @override
  String get shareMenuDeleteFailedNotOwner => '自分の動画だけ削除できるよ。';

  @override
  String get shareMenuDeleteFailedNotAuthenticated => 'もう一度ログインしてから削除してね。';

  @override
  String get shareMenuDeleteFailedCouldNotSign => '削除リクエストに署名できなかったよ。もう一度試してね。';

  @override
  String get shareMenuDeleteFailedRelayRejected =>
      'リレーがこの削除リクエストを受け付けませんでした。少し待ってからもう一度お試しください。';

  @override
  String get shareMenuDeleteFailedAccountRestricted =>
      'Your account is restricted, so this delete request couldn\'t be sent. Contact support for help deleting it.';

  @override
  String get shareMenuDeleteFailedRelayNoResponse =>
      'リレーに接続できませんでした。接続を確認してもう一度お試しください。';

  @override
  String get shareMenuDeletePartiallyConfirmed =>
      '削除しました。すべてのリレーが確認したわけではないので、他のアプリではまだ表示されることがあります。';

  @override
  String get shareMenuDeleteFailedGeneric => 'この動画を削除できなかったよ。もう一度試してね。';

  @override
  String get shareMenuUpdate => '更新';

  @override
  String get shareMenuChangeCover => 'カバーを変更';

  @override
  String get shareMenuVideoUpdated => '動画を更新したよ';

  @override
  String shareMenuVideoUpdatedWithInviteFailures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件のコラボレーター招待が送信されませんでした。',
      one: '1件のコラボレーター招待が送信されませんでした。',
    );
    return '動画を更新しましたが、$_temp0';
  }

  @override
  String get videoUpdateErrorNotAuthenticated => 'もう一度ログインしてから試してみて。';

  @override
  String get videoUpdateErrorNoPlayableVideo => 'この動画には再生できるソースがないから、編集できない。';

  @override
  String get videoUpdateErrorCouldNotSign => '更新に署名できなかった。もう一回試してみて。';

  @override
  String get videoUpdateErrorPublishRejected =>
      'リレーが更新を受け付けなかった。少ししてからもう一回試してみて。';

  @override
  String get videoUpdateErrorGeneric => 'この動画を更新できなかった。もう一回試してみて。';

  @override
  String get shareMenuOriginalVideoUnavailable =>
      'Couldn\'t load the original video. Try again in a moment.';

  @override
  String get shareMenuDeleteVideoQuestion => '動画を削除する?';

  @override
  String get shareMenuDeleteCleanupInProgress => '動画を削除しています…';

  @override
  String get shareMenuDeleteCleanupConfirmed => '動画を削除しました。';

  @override
  String get shareMenuDeleteCleanupDelayed =>
      '動画を削除しました。すべての場所から消えるまで少し時間がかかる場合があります。';

  @override
  String get shareMenuDeleteCleanupFailed =>
      '動画を削除しましたが、すべてのコピーを削除できませんでした。サポートにお問い合わせください。';

  @override
  String get authSessionExpired => 'セッションが切れちゃった。もう一回サインインしてね。';

  @override
  String get authAccountRestoreFailed =>
      'We couldn\'t unlock that account on this device. Sign in again.';

  @override
  String get authSignInFailed => 'サインインがうまくいかなかった。もう一回試してみて。';

  @override
  String get webAuthNotSupportedSecureMode =>
      'セキュアモードではウェブ認証は対応してないよ。安全な鍵管理にはモバイルアプリを使ってね。';

  @override
  String get webAuthEnterBunkerUri => 'bunker URI を入れてね';

  @override
  String get webAuthConnectTitle => 'Divine に接続';

  @override
  String get webAuthChooseMethod => 'Nostr 認証方法を選んでね';

  @override
  String get webAuthBrowserExtension => 'ブラウザ拡張機能';

  @override
  String get webAuthRecommended => 'おすすめ';

  @override
  String get webAuthNsecBunker => 'nsec bunker';

  @override
  String get webAuthConnectRemoteSigner => 'リモート署名に接続';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => 'クリップボードから貼り付け';

  @override
  String get webAuthConnectToBunker => 'Bunker に接続';

  @override
  String get webAuthNewToNostr => 'Nostr は初めて?';

  @override
  String get webAuthNostrHelp =>
      '一番簡単なのは Alby や nos2x みたいなブラウザ拡張をインストールする方法だよ。安全なリモート署名なら nsec bunker を使ってね。';

  @override
  String get soundsTitle => 'サウンド';

  @override
  String get soundsSearchHint => 'サウンドを検索...';

  @override
  String get soundsSearchResults => '検索結果';

  @override
  String get soundsNoSoundsFound => 'サウンドが見つからない';

  @override
  String get soundsNoSoundsFoundDescription => '別のキーワードで検索してみて';

  @override
  String get soundsSavedToLibrary => 'サウンドに保存しました';

  @override
  String get soundsAlreadySavedToLibrary => 'すでにサウンドにあります';

  @override
  String get soundsSavedLibraryTitle => 'マイサウンド';

  @override
  String get soundsSavedEmptyTitle => '保存されたサウンドはまだありません';

  @override
  String get soundsSavedEmptyDescription => '動画でサウンドを使用をタップして、ここに保存します。';

  @override
  String get soundsRemoveSavedSound => 'サウンドを削除';

  @override
  String get savedSoundSaveAction => '保存';

  @override
  String get savedSoundPausePreviewAction => 'プレビューを一時停止';

  @override
  String get savedSoundResumePreviewAction => 'プレビューを再開';

  @override
  String get savedSoundDetailsSheetTitle => 'サウンドの詳細';

  @override
  String get savedSoundRemoveConfirmTitle => 'このサウンドを削除しますか？';

  @override
  String get savedSoundRemoveConfirmMessage =>
      'ライブラリから消えますが、このサウンドを使っている動画からいつでも保存し直せます。';

  @override
  String get soundsRemovedFromLibrary => 'サウンドから削除しました';

  @override
  String get soundsSaveFailed => 'そのサウンドを保存できませんでした。もう一度お試しください。';

  @override
  String get soundsRemoveFailed => 'そのサウンドを削除できませんでした。もう一度お試しください。';

  @override
  String get soundSyncStatusSyncing => 'サウンドを同期しています…';

  @override
  String get soundSyncStatusSynced => 'サウンドは最新です';

  @override
  String get soundSyncStatusFailed => 'サウンドを同期できませんでした。もう一度試します。';

  @override
  String get soundSyncStatusLocked => 'この端末では同期済みライブラリのロックを解除できません。';

  @override
  String get profileTitle => 'プロフィール';

  @override
  String get profileMoreOptions => 'その他のオプション';

  @override
  String profileBlockedUser(String name) {
    return '$nameをブロックしたよ';
  }

  @override
  String profileUnblockedUser(String name) {
    return '$nameのブロックを解除したよ';
  }

  @override
  String profileUnfollowedUser(String name) {
    return '$nameのフォローを解除したよ';
  }

  @override
  String get profileFeedError => 'サーバーに接続できません。接続を確認してもう一度お試しください。';

  @override
  String get profileFeedLoadMoreError => 'これ以上の動画を読み込めませんでした。引っ張って更新してください。';

  @override
  String get notificationsTabAll => 'すべて';

  @override
  String get notificationsTabLikes => 'いいね';

  @override
  String get notificationsTabComments => 'コメント';

  @override
  String get notificationsTabFollows => 'フォロー';

  @override
  String get notificationsTabReposts => 'リポスト';

  @override
  String get notificationsFailedToLoad => '通知の読み込みがうまくいかなかった';

  @override
  String get notificationsRetry => 'もう一回';

  @override
  String get notificationsRefreshError => '更新できませんでした — 既存の通知を表示しています';

  @override
  String get notificationsUnreadPrefix => '未読の通知';

  @override
  String notificationsBadgeUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '未読の通知が$count件',
      one: '未読の通知が1件',
    );
    return '$_temp0';
  }

  @override
  String notificationsViewProfileSemanticLabel(String displayName) {
    return '$displayNameさんのプロフィールを開く';
  }

  @override
  String get notificationsViewProfilesSemanticLabel => 'プロフィールを開く';

  @override
  String notificationsVideoThumbnailFor(String title) {
    return '$titleの動画サムネイル';
  }

  @override
  String get notificationsVideoThumbnail => '動画のサムネイル';

  @override
  String get notificationsInviteSingular => '友達に送れる招待が1つあるよ！';

  @override
  String notificationsInvitePlural(int count) {
    return '友達に送れる招待が$count個あるよ！';
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
  String get notificationsVideoUnavailable => '動画を見れないよ';

  @override
  String get feedFailedToLoadVideos => '動画の読み込みがうまくいかなかった';

  @override
  String get feedRetry => 'もう一回';

  @override
  String get feedNoFollowedUsers => 'まだ誰もフォローしてないよ。\n誰かをフォローすると、ここに動画が出るよ。';

  @override
  String get feedModeForYou => 'おすすめ';

  @override
  String get feedModeNew => '新着';

  @override
  String get feedModeFollowing => 'フォロー中';

  @override
  String get feedModeClassics => 'クラシック';

  @override
  String feedModeSemanticLabel(String label) {
    return 'フィードモード: $label';
  }

  @override
  String videoAuthorSemanticLabel(String displayName) {
    return '動画の作者: $displayName';
  }

  @override
  String get videoAuthorAvatarSemanticLabel => '作者のアバター';

  @override
  String get feedForYouEmpty =>
      'おすすめフィードはまだ空です。\n動画を見つけてクリエイターをフォローし、あなた向けに育てましょう。';

  @override
  String get feedFollowingEmpty =>
      'フォロー中の人の動画はまだありません。\n気に入ったクリエイターを見つけてフォローしましょう。';

  @override
  String get feedLatestEmpty => '新しい動画はまだありません。\nしばらくしてからもう一度確認してください。';

  @override
  String get feedClassicEmpty => 'クラシック動画はまだありません。\nしばらくしてからもう一度確認してください。';

  @override
  String get feedExploreVideos => '動画を探しに行こう';

  @override
  String get feedLoadingMore => '動画をもっと読み込んでるよ…';

  @override
  String get feedRefreshed => 'フィードを更新しました';

  @override
  String get uploadUploadingVideo => '動画をアップロード中';

  @override
  String get postPublishConfirmationTitle => 'プロフィールに公開したよ';

  @override
  String get postPublishConfirmationView => '表示';

  @override
  String get postPublishConfirmationShare => '共有';

  @override
  String get postPublishConfirmationThumbnailLabel => '公開したばかりの動画のサムネイル';

  @override
  String get userSearchNoResults => 'ユーザーが見つからない';

  @override
  String get userPickerFilterByNameHint => '名前で絞り込み...';

  @override
  String get userPickerSearchByNameHint => '名前で検索...';

  @override
  String get userPickerClearSearchSemantics => '検索をクリア';

  @override
  String userPickerAlreadyAddedSemantics(String name) {
    return '$name はすでに追加済みです';
  }

  @override
  String userPickerSelectSemantics(String name) {
    return '$name を選択';
  }

  @override
  String userPickerRemoveSelectionSemantics(String name) {
    return '$nameを削除';
  }

  @override
  String get userPickerEmptyFollowListTitle => 'あなたの仲間は外にいる';

  @override
  String get userPickerEmptyFollowListBody =>
      '気の合う人をフォローしよう。相互フォローになればコラボできます。';

  @override
  String get userPickerGoBack => '戻る';

  @override
  String get userPickerTypeNameToSearch => '検索する名前を入力';

  @override
  String get userPickerUnavailable => 'ユーザー検索は現在利用できません。後でもう一度お試しください。';

  @override
  String get userPickerSearchFailedTryAgain => '検索に失敗しました。もう一度お試しください。';

  @override
  String get forgotPasswordTitle => 'パスワードをリセット';

  @override
  String get forgotPasswordDescription => 'メールアドレスを入れてね。パスワードをリセットするリンクを送るよ。';

  @override
  String get forgotPasswordEmailLabel => 'メールアドレス';

  @override
  String get forgotPasswordCancel => 'キャンセル';

  @override
  String get forgotPasswordSendLink => 'リセットリンクを送る';

  @override
  String get ageVerificationContentWarning => 'コンテンツ警告';

  @override
  String get ageVerificationTitle => '年齢確認';

  @override
  String get ageVerificationAdultDescription =>
      'このコンテンツは成人向け素材が含まれる可能性があるよ。閲覧には18歳以上である必要があるよ。';

  @override
  String get ageVerificationCreationDescription =>
      'カメラでコンテンツを作るには、16歳以上である必要があるよ。';

  @override
  String get ageVerificationAdultQuestion => '18歳以上?';

  @override
  String get ageVerificationCreationQuestion => '16歳以上?';

  @override
  String get ageVerificationNo => 'いいえ';

  @override
  String get ageVerificationYes => 'はい';

  @override
  String get navHome => 'ホーム';

  @override
  String get navExplore => '探索';

  @override
  String get navInbox => '受信箱';

  @override
  String get navProfile => 'プロフィール';

  @override
  String get navMyProfile => 'マイプロフィール';

  @override
  String get navNotifications => '通知';

  @override
  String get navOpenCamera => 'カメラを開く';

  @override
  String get navExploreClassics => 'クラシック';

  @override
  String get navExploreNewVideos => '新着動画';

  @override
  String get navExploreTrending => 'トレンド';

  @override
  String get navExploreForYou => 'おすすめ';

  @override
  String get navExploreLists => 'リスト';

  @override
  String get routeErrorTitle => 'エラー';

  @override
  String get routeInvalidHashtag => '無効なハッシュタグ';

  @override
  String get routeInvalidConversationId => '無効な会話 ID';

  @override
  String get routeInvalidRequestId => '無効なリクエスト ID';

  @override
  String get routeInvalidListId => '無効なリスト ID';

  @override
  String get routeInvalidUserId => '無効なユーザー ID';

  @override
  String get routeInvalidVideoId => '無効な動画 ID';

  @override
  String get routeInvalidSoundId => '無効なサウンド ID';

  @override
  String get routeInvalidCategory => '無効なカテゴリ';

  @override
  String get routeNoVideosToDisplay => '表示する動画がないよ';

  @override
  String get routeGoHome => 'ホームに戻る';

  @override
  String get routeInvalidProfileId => '無効なプロフィール ID';

  @override
  String get routeUnknownPath => 'このページはアプリ内にありません。';

  @override
  String get routeDefaultListName => 'リスト';

  @override
  String get supportTitle => 'サポート';

  @override
  String get supportContactSupport => 'サポートに連絡';

  @override
  String get supportContactSupportSubtitle => '会話を始めたり、過去のメッセージを確認するよ';

  @override
  String get supportReportBug => 'バグを報告';

  @override
  String get supportReportBugSubtitle => 'アプリの技術的な問題';

  @override
  String get supportRequestFeature => '機能リクエスト';

  @override
  String get supportRequestFeatureSubtitle => '改善や新機能の提案';

  @override
  String get supportSaveLogs => 'ログを保存';

  @override
  String get supportSaveLogsSubtitle => '手動送信用にログをファイルにエクスポート';

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
  String get supportFaq => 'よくある質問';

  @override
  String get supportFaqSubtitle => 'よくある質問と回答';

  @override
  String get supportFamily => 'Divine Family';

  @override
  String get supportFamilySubtitle => '保護者とティーンが健全なオンライン習慣を築くために';

  @override
  String get supportKids => 'Divine Kids';

  @override
  String get supportKidsSubtitle => '年齢に応じたアカウントの扱いについて';

  @override
  String get supportProofMode => 'ProofMode';

  @override
  String get supportProofModeSubtitle => '検証と真正性について学ぼう';

  @override
  String get supportLoginRequired => 'サポートに連絡するにはログインしてね';

  @override
  String get supportExportingLogs => 'ログをエクスポート中...';

  @override
  String get supportExportLogsFailed => 'ログのエクスポートがうまくいかなかった';

  @override
  String get supportNoLogsToExport =>
      'No logs yet — they start fresh each launch. Reproduce the problem, then come back without restarting.';

  @override
  String get supportExportLogsUnconfirmed =>
      'Logs handed off. Check the app you shared to.';

  @override
  String supportLogsSavedTo(String path) {
    return 'ログを$pathに保存しました';
  }

  @override
  String get supportRevealLogsAction => 'フォルダで表示';

  @override
  String get supportChatNotAvailable => 'サポートチャットは今使えないよ';

  @override
  String get supportCouldNotOpenMessages => 'サポートメッセージが開けなかった';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return '$pageNameが開けなかった';
  }

  @override
  String get reportWhyReporting => 'このコンテンツを報告する理由は?';

  @override
  String get reportPolicyNotice =>
      'Divine はコンテンツの報告に24時間以内に対応して、問題のあるコンテンツを削除し、違反ユーザーを排除するよ。';

  @override
  String get reportBlockUser => 'このユーザーをブロック';

  @override
  String get reportCancel => 'キャンセル';

  @override
  String get reportSubmit => '報告';

  @override
  String get reportSelectReason => '報告する理由を選んでね';

  @override
  String get reportOtherRequiresDetails => '「その他」を選んだ場合は問題の内容を記入してください';

  @override
  String get reportDetailsRequired => '問題の内容を記入してください';

  @override
  String get reportDetailsTextOnly => 'テキストのみです。ここには写真やGIFを添付できません。';

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
  String get reportReasonSpam => 'スパムや迷惑なコンテンツ';

  @override
  String get reportReasonSpamSubtitle => '迷惑または繰り返しのコンテンツ';

  @override
  String get reportReasonHarassment => '嫌がらせ、いじめ、脅迫';

  @override
  String get reportReasonHarassmentSubtitle => '有害で望まない返信やメンション';

  @override
  String get reportReasonViolence => '暴力的・過激なコンテンツ';

  @override
  String get reportReasonViolenceSubtitle => '暴力的、過激、または有害なコンテンツ';

  @override
  String get reportReasonSexualContent => '性的・成人向けコンテンツ';

  @override
  String get reportReasonSexualContentSubtitle => 'ヌード、ポルノ、または露骨なコンテンツ';

  @override
  String get reportReasonCopyright => '著作権侵害';

  @override
  String get reportReasonCopyrightSubtitle => '知的財産の無許可使用';

  @override
  String get reportReasonFalseInfo => '虚偽の情報';

  @override
  String get reportReasonFalseInfoSubtitle => '誤解を招くまたは虚偽の主張';

  @override
  String get reportReasonChildSafety => '子どもの安全に関する違反';

  @override
  String get reportReasonChildSafetySubtitle => '未成年の安全に関する一般的な懸念';

  @override
  String get reportReasonCsam => '児童性的虐待';

  @override
  String get reportReasonCsamSubtitle => '未成年者への性的虐待を描写したコンテンツ';

  @override
  String get reportReasonUnderageUser => 'ユーザーが16歳未満に見える';

  @override
  String get reportReasonUnderageUserSubtitle => 'アカウント所有者が未成年に見える';

  @override
  String get reportReasonAiGenerated => 'AI 生成コンテンツ';

  @override
  String get reportReasonAiGeneratedSubtitle => 'AI生成と疑われるコンテンツ';

  @override
  String get reportReasonOther => 'その他のポリシー違反';

  @override
  String get reportReasonOtherSubtitle => '上記に記載されていない違反';

  @override
  String get reportFailed => 'コンテンツの報告がうまくいかなかった。もう一回試してみて。';

  @override
  String get reportNotSent => '報告を送信できなかった。接続を確認してもう一回試してみて。';

  @override
  String get reportReceivedTitle => '報告を受け付けたよ';

  @override
  String get reportReceivedThankYou => 'Divine を安全に保つために協力してくれてありがとう。';

  @override
  String get reportReceivedReviewNotice =>
      'チームが報告を確認して、適切に対応するね。ダイレクトメッセージでアップデートが届くかも。';

  @override
  String get reportModerationDmDelayed =>
      '今はモデレーションチームに直接連絡できなかったけど、あなたの報告は受け取ったから、あとで確認するね。';

  @override
  String get reportContactModeration => 'モデレーションチームにメッセージを送る';

  @override
  String get reportLearnMoreAt => '詳しくはこちら';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => '閉じる';

  @override
  String get listAddToList => 'リストに追加';

  @override
  String listVideoCount(int count) {
    return '$count本の動画';
  }

  @override
  String listPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count人',
      one: '1人',
    );
    return '$_temp0';
  }

  @override
  String get listByAuthorPrefix => '作成者: ';

  @override
  String get listNewList => '新しいリスト';

  @override
  String get listDone => '完了';

  @override
  String get listErrorLoading => 'リストの読み込みに失敗';

  @override
  String listRemovedFrom(String name) {
    return '$nameから削除したよ';
  }

  @override
  String listAddedTo(String name) {
    return '$nameに追加したよ';
  }

  @override
  String get listCreateNewList => '新しいリストを作る';

  @override
  String get listNewPeopleList => '新しい人リスト';

  @override
  String get listCollaboratorsNone => 'なし';

  @override
  String get listAddCollaboratorTitle => 'コラボレーターを追加';

  @override
  String get listCollaboratorSearchHint => 'Divineを検索...';

  @override
  String get listNameLabel => 'リスト名';

  @override
  String get listDescriptionLabel => '説明 (任意)';

  @override
  String get listPublicList => '公開リスト';

  @override
  String get listPublicListSubtitle => 'みんながフォロー・閲覧できるよ';

  @override
  String get listPrivateListSubtitle => '動画は非公開のまま。名前、説明、タグ、カバーは表示されたままです。';

  @override
  String get listVisibilityPublic => '公開';

  @override
  String get listVisibilityPrivate => '非公開';

  @override
  String get profileListsEmpty => 'まだリストがないよ。まとめておきたいループでひとつ作ってみて。';

  @override
  String get listEditTitle => 'リストを編集';

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
  String get listShareAction => 'リストを共有';

  @override
  String get listShareFailed => 'リストを共有できなかった。もう一度試してね。';

  @override
  String get listSave => '保存';

  @override
  String get listContinue => '続ける';

  @override
  String get listPrivateFull =>
      'This private list is full. Remove something to add more.';

  @override
  String get listUpdateFailed => 'リストを更新できなかった。もう一度試してね。';

  @override
  String get listMakePrivateTitle => 'このリストを非公開にする？';

  @override
  String get listMakePrivateWarning =>
      '動画は暗号化されて、見られるのはあなただけになるよ。名前、説明、タグ、カバーは見えたままで、すでに共有したコピーは残ることがあるよ。';

  @override
  String get listMakePublicTitle => 'このリストを公開する？';

  @override
  String get listMakePublicWarning => 'リンクを知っている人なら誰でも、このリストと動画を見られるよ。';

  @override
  String listShareText(String name, String url) {
    return 'Divineで$nameをチェックしてみて: $url';
  }

  @override
  String listShareSubject(String name) {
    return 'Divineの$name';
  }

  @override
  String get listCancel => 'キャンセル';

  @override
  String get listCreate => '作成';

  @override
  String get listCreateFailed => 'リストの作成がうまくいかなかった';

  @override
  String get keyManagementTitle => 'Nostr 鍵';

  @override
  String get keyManagementWhatAreKeys => 'Nostr 鍵って何?';

  @override
  String get keyManagementExplanation =>
      'あなたの Nostr ID は暗号鍵のペアだよ:\n\n• 公開鍵 (npub) はユーザー名みたいなもの - 自由に共有してOK\n• 秘密鍵 (nsec) はパスワードみたいなもの - 秘密にしておいて！\n\nnsec があれば、どの Nostr アプリでもあなたのアカウントにアクセスできるよ。';

  @override
  String get keyManagementImportTitle => '既存の鍵をインポート';

  @override
  String get keyManagementImportSubtitle =>
      'もう Nostr アカウントを持ってる? 秘密鍵 (nsec) を貼り付けてここからアクセスしてね。';

  @override
  String get keyManagementImportButton => '鍵をインポート';

  @override
  String get keyManagementImportWarning => '現在の鍵が置き換えられるよ！';

  @override
  String get keyManagementBackupTitle => '鍵をバックアップ';

  @override
  String get keyManagementBackupSubtitle =>
      '秘密鍵 (nsec) を保存して、他の Nostr アプリでもこのアカウントを使えるようにしよう。';

  @override
  String get keyManagementCopyNsec => '秘密鍵 (nsec) をコピー';

  @override
  String get keyManagementNeverShare => 'nsec は誰にも共有しないで！';

  @override
  String get keyManagementKeycastRemoteSigning =>
      '鍵はこの端末ではなく、Divine のログインサービスに保管されています。パスワードを確認すれば取得できます。';

  @override
  String get keyManagementKeycastPasswordPrompt =>
      '鍵は Divine のログインサービスが保管しています。アカウントのパスワードを入力すれば取得します。';

  @override
  String get keyManagementKeycastCopyKey => '鍵をコピー';

  @override
  String get keyManagementKeycastCopyBlocked =>
      '端末がコピーをブロックしたため、鍵はクリップボードに届きませんでした。';

  @override
  String get keyManagementKeycastWrongPassword => 'パスワードが一致しません。もう一度お試しください。';

  @override
  String get keyManagementKeycastTooManyAttempts =>
      '試行が多すぎるよ。これを閉じて最初からやり直してね。';

  @override
  String get keyManagementKeycastRateLimited =>
      '鍵の取得リクエストが多すぎるよ。数分待ってからもう一度試してね。';

  @override
  String get keyManagementKeycastSignInAgain =>
      'セッションの有効期限が切れました。鍵をコピーするには再度サインインしてください。';

  @override
  String get keyManagementKeycastEmailUnverified =>
      '鍵をコピーする前にメールアドレスを確認してください。';

  @override
  String get keyManagementKeycastDenied =>
      'このアカウントの鍵は Divine が管理しているため、ここではコピーできません。';

  @override
  String get keyManagementKeycastNoKey => 'このアカウントに登録されている鍵はありません。';

  @override
  String get keyManagementKeycastGenericFailure =>
      'ログインサービスに接続できなかった。もう一回試してみて。';

  @override
  String get keyManagementRestrictedTitle => '鍵は Divine が管理しています';

  @override
  String get keyManagementRestrictedBody =>
      'アカウントを安全に保つため、鍵のバックアップと別の鍵のインポートはここでは利用できません。';

  @override
  String get keyManagementPasteKey => '秘密鍵を貼り付けてね';

  @override
  String get keyManagementInvalidFormat => '鍵の形式が正しくないよ。「nsec1」で始める必要があるよ';

  @override
  String get keyManagementConfirmImportTitle => 'この鍵をインポートする?';

  @override
  String get keyManagementConfirmImportBody =>
      '現在のアイデンティティがインポートした鍵に置き換わるよ。\n\n先にバックアップしておかないと、現在の鍵がなくなっちゃうよ。';

  @override
  String get keyManagementImportConfirm => 'インポート';

  @override
  String get keyManagementImportSuccess => '鍵をインポートしたよ！';

  @override
  String get keyManagementImportFailed => '鍵のインポートがうまくいかなかった。もう一回試してみて。';

  @override
  String get keyManagementExportSuccess => '秘密鍵をコピーしたよ！\n\n安全な場所に保管してね。';

  @override
  String get keyManagementExportFailed => '鍵のエクスポートがうまくいかなかった。もう一回試してみて。';

  @override
  String get keyManagementYourPublicKeyLabel => 'あなたの公開鍵 (npub)';

  @override
  String get keyManagementCopyPublicKeyTooltip => '公開鍵をコピー';

  @override
  String get keyManagementPublicKeyCopied => '公開鍵をコピーしたよ';

  @override
  String get saveOriginalSavedToCameraRoll => 'カメラロールに保存したよ';

  @override
  String get saveOriginalShare => '共有';

  @override
  String get saveOriginalDone => '完了';

  @override
  String get saveOriginalPhotosAccessNeeded => '写真へのアクセスが必要';

  @override
  String get saveOriginalPhotosAccessMessage => '動画を保存するには、設定で写真へのアクセスを許可してね。';

  @override
  String get saveOriginalOpenSettings => '設定を開く';

  @override
  String get saveOriginalNotNow => '今はいい';

  @override
  String get saveOriginalDownloadFailed => 'ダウンロードがうまくいかなかった';

  @override
  String get saveOriginalDismiss => '閉じる';

  @override
  String get saveOriginalDownloadingVideo => '動画をダウンロード中';

  @override
  String get saveOriginalSavingToCameraRoll => 'カメラロールに保存中';

  @override
  String get saveOriginalFetchingVideo => 'ネットワークから動画を取ってるよ...';

  @override
  String get saveOriginalSavingVideo => 'オリジナル動画をカメラロールに保存してるよ...';

  @override
  String get soundTitle => 'サウンド';

  @override
  String get soundOriginalSound => 'オリジナルサウンド';

  @override
  String get soundVideosUsingThisSound => 'このサウンドを使ってる動画';

  @override
  String get soundSourceVideo => '元動画';

  @override
  String get soundNoVideosYet => '動画はまだないよ';

  @override
  String get soundBeFirstToUse => 'このサウンドを最初に使おう！';

  @override
  String get soundFailedToLoadVideos => '動画の読み込みがうまくいかなかった';

  @override
  String get soundRetry => 'もう一回';

  @override
  String get soundVideosUnavailable => '動画を見れないよ';

  @override
  String get soundCouldNotLoadDetails => '動画の詳細を読み込めなかった';

  @override
  String get soundPreview => 'プレビュー';

  @override
  String get soundStop => '停止';

  @override
  String get soundUseSound => 'サウンドを使う';

  @override
  String get soundUntitled => '無題のサウンド';

  @override
  String get soundStopPreview => 'プレビューを停止';

  @override
  String soundPreviewSemanticLabel(String title) {
    return '$titleをプレビュー';
  }

  @override
  String soundViewDetailsSemanticLabel(String title) {
    return '$titleの詳細を表示';
  }

  @override
  String get soundNoVideoCount => '動画はまだないよ';

  @override
  String get soundOneVideo => '1本の動画';

  @override
  String soundVideoCount(int count) {
    return '$count本の動画';
  }

  @override
  String get soundUnableToPreview => 'サウンドをプレビューできない - 音声がないよ';

  @override
  String get soundPreviewFailed => 'プレビューの再生がうまくいかなかった。もう一回試してみて。';

  @override
  String get soundViewSource => '元動画を見る';

  @override
  String get soundCloseTooltip => '閉じる';

  @override
  String get exploreNotExploreRoute => '探索ルートじゃないよ';

  @override
  String get legalTitle => '法的情報';

  @override
  String get legalTermsOfService => '利用規約';

  @override
  String get legalTermsOfServiceSubtitle => 'ご利用条件';

  @override
  String get legalPrivacyPolicy => 'プライバシーポリシー';

  @override
  String get legalPrivacyPolicySubtitle => 'データの取り扱いについて';

  @override
  String get legalSafetyStandards => '安全基準';

  @override
  String get legalSafetyStandardsSubtitle => 'コミュニティガイドラインと安全について';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle => '著作権とテイクダウンポリシー';

  @override
  String get legalOpenSourceLicenses => 'オープンソースライセンス';

  @override
  String get legalOpenSourceLicensesSubtitle => 'サードパーティパッケージのクレジット';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return '$pageNameが開けなかった';
  }

  @override
  String get categoryAction => 'アクション';

  @override
  String get categoryAdventure => 'アドベンチャー';

  @override
  String get categoryAnimals => '動物';

  @override
  String get categoryAnimation => 'アニメ';

  @override
  String get categoryArchitecture => '建築';

  @override
  String get categoryArt => 'アート';

  @override
  String get categoryAutomotive => '自動車';

  @override
  String get categoryAwardShow => '授賞式';

  @override
  String get categoryAwards => 'アワード';

  @override
  String get categoryBaseball => '野球';

  @override
  String get categoryBasketball => 'バスケ';

  @override
  String get categoryBeauty => '美容';

  @override
  String get categoryBeverage => '飲み物';

  @override
  String get categoryCars => '車';

  @override
  String get categoryCelebration => 'お祝い';

  @override
  String get categoryCelebrities => 'セレブ';

  @override
  String get categoryCelebrity => 'セレブ';

  @override
  String get categoryCityscape => '街並み';

  @override
  String get categoryComedy => 'コメディ';

  @override
  String get categoryConcert => 'コンサート';

  @override
  String get categoryCooking => '料理';

  @override
  String get categoryCostume => 'コスチューム';

  @override
  String get categoryCrafts => 'クラフト';

  @override
  String get categoryCrime => '犯罪';

  @override
  String get categoryCulture => '文化';

  @override
  String get categoryDance => 'ダンス';

  @override
  String get categoryDiy => 'DIY';

  @override
  String get categoryDrama => 'ドラマ';

  @override
  String get categoryEducation => '教育';

  @override
  String get categoryEmotional => '感動';

  @override
  String get categoryEmotions => '感情';

  @override
  String get categoryEntertainment => 'エンタメ';

  @override
  String get categoryEvent => 'イベント';

  @override
  String get categoryFamily => '家族';

  @override
  String get categoryFans => 'ファン';

  @override
  String get categoryFantasy => 'ファンタジー';

  @override
  String get categoryFashion => 'ファッション';

  @override
  String get categoryFestival => 'フェス';

  @override
  String get categoryFilm => '映画';

  @override
  String get categoryFitness => 'フィットネス';

  @override
  String get categoryFood => '料理';

  @override
  String get categoryFootball => 'フットボール';

  @override
  String get categoryFurniture => '家具';

  @override
  String get categoryGaming => 'ゲーム';

  @override
  String get categoryGolf => 'ゴルフ';

  @override
  String get categoryGrooming => '身だしなみ';

  @override
  String get categoryGuitar => 'ギター';

  @override
  String get categoryHalloween => 'ハロウィン';

  @override
  String get categoryHealth => '健康';

  @override
  String get categoryHockey => 'ホッケー';

  @override
  String get categoryHoliday => '休日';

  @override
  String get categoryHome => 'ホーム';

  @override
  String get categoryHomeImprovement => 'DIYリフォーム';

  @override
  String get categoryHorror => 'ホラー';

  @override
  String get categoryHospital => '病院';

  @override
  String get categoryHumor => 'ユーモア';

  @override
  String get categoryInteriorDesign => 'インテリア';

  @override
  String get categoryInterview => 'インタビュー';

  @override
  String get categoryKids => 'キッズ';

  @override
  String get categoryLifestyle => 'ライフスタイル';

  @override
  String get categoryMagic => 'マジック';

  @override
  String get categoryMakeup => 'メイク';

  @override
  String get categoryMedical => '医療';

  @override
  String get categoryMusic => '音楽';

  @override
  String get categoryMystery => 'ミステリー';

  @override
  String get categoryNature => '自然';

  @override
  String get categoryNews => 'ニュース';

  @override
  String get categoryOutdoor => 'アウトドア';

  @override
  String get categoryParty => 'パーティー';

  @override
  String get categoryPeople => '人物';

  @override
  String get categoryPerformance => 'パフォーマンス';

  @override
  String get categoryPets => 'ペット';

  @override
  String get categoryPolitics => '政治';

  @override
  String get categoryPrank => 'ドッキリ';

  @override
  String get categoryPranks => 'ドッキリ';

  @override
  String get categoryRealityShow => 'リアリティ番組';

  @override
  String get categoryRelationship => '関係';

  @override
  String get categoryRelationships => '人間関係';

  @override
  String get categoryRomance => 'ロマンス';

  @override
  String get categorySchool => '学校';

  @override
  String get categoryScienceFiction => 'SF';

  @override
  String get categorySelfie => '自撮り';

  @override
  String get categoryShopping => 'ショッピング';

  @override
  String get categorySkateboarding => 'スケボー';

  @override
  String get categorySkincare => 'スキンケア';

  @override
  String get categorySoccer => 'サッカー';

  @override
  String get categorySocialGathering => '集まり';

  @override
  String get categorySocialMedia => 'SNS';

  @override
  String get categorySports => 'スポーツ';

  @override
  String get categoryTalkShow => 'トークショー';

  @override
  String get categoryTech => 'テック';

  @override
  String get categoryTechnology => 'テクノロジー';

  @override
  String get categoryTelevision => 'テレビ';

  @override
  String get categoryToys => 'おもちゃ';

  @override
  String get categoryTransportation => '交通';

  @override
  String get categoryTravel => '旅行';

  @override
  String get categoryUrban => '都市';

  @override
  String get categoryViolence => '暴力';

  @override
  String get categoryVlog => 'ブイログ';

  @override
  String get categoryVlogging => 'ブイログ';

  @override
  String get categoryWrestling => 'プロレス';

  @override
  String get profileSetupUploadStaged => 'アップロードしたよ — 適用するには「保存」をタップしてね';

  @override
  String inboxReportedUser(String displayName) {
    return '$displayNameを報告したよ';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return '$displayNameをブロックしたよ';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return '$displayNameのブロックを解除したよ';
  }

  @override
  String get inboxRemovedConversation => '会話を削除したよ';

  @override
  String get inboxRestorePausedTitle => '一部のチャットの復元が終わっていないよ';

  @override
  String get conversationRestorePausedTitle => 'このチャットの復元が終わっていないよ';

  @override
  String get inboxRestoreRetryAction => '再試行';

  @override
  String get inboxRestoringMessages => 'メッセージを復元中…';

  @override
  String get inboxEmptyTitle => 'まだメッセージはないよ';

  @override
  String get inboxEmptySubtitle => 'この+ボタン、噛まないよ。';

  @override
  String get inboxLoadErrorTitle => 'メッセージを読み込めませんでした';

  @override
  String get inboxLoadErrorSubtitle => '接続を確認してもう一度お試しください。';

  @override
  String get inboxFilterAll => 'すべて';

  @override
  String get inboxFilterUnread => '未読';

  @override
  String get dmBlockedThreadTitle => 'このアカウントをブロックしました';

  @override
  String get dmBlockedThreadBody =>
      'メッセージはここに残るので、読んだりスクリーンショットを撮ったりできます。返信するにはブロックを解除してください。';

  @override
  String get inboxFilterBlocked => 'ブロック済み';

  @override
  String get inboxBlockedEmptyTitle => 'ブロックしたチャットはありません';

  @override
  String get inboxBlockedEmptySubtitle => 'ブロックしたアカウントがここに表示されます。';

  @override
  String get inboxBlockedNoMessages => 'メッセージなし';

  @override
  String get inboxUnreadEmptyTitle => 'すべて既読です';

  @override
  String get inboxUnreadEmptySubtitle => '未読メッセージはありません。';

  @override
  String get inboxSearchHint => 'メッセージを検索';

  @override
  String get inboxSupportRowTitle => 'Divine モデレーション';

  @override
  String get inboxSupportRowSubtitle => '不具合、モデレーション、アカウントのこと — お聞きします。';

  @override
  String get inboxSearchEmptyTitle => '一致なし';

  @override
  String get inboxSearchEmptySubtitle => '別の名前や言葉で試してください。';

  @override
  String get inboxActionMute => '会話をミュート';

  @override
  String inboxActionReport(String displayName) {
    return '$displayNameを報告';
  }

  @override
  String inboxActionBlock(String displayName) {
    return '$displayNameをブロック';
  }

  @override
  String inboxActionUnblock(String displayName) {
    return '$displayNameのブロックを解除';
  }

  @override
  String get inboxActionRemove => '会話を削除';

  @override
  String get inboxRemoveConfirmTitle => '会話を削除する？';

  @override
  String inboxRemoveConfirmBody(String displayName) {
    return '$displayNameとの会話が受信トレイから削除されます。相手からまたメッセージが届くと、新しい会話が始まります。';
  }

  @override
  String get inboxRemoveConfirmBodyGroup =>
      'このグループの会話が受信トレイから削除されます。誰かがまたグループにメッセージを送ると、新しい会話が始まります。';

  @override
  String get inboxRemoveConfirmConfirm => '削除';

  @override
  String get inboxConversationMuted => '会話をミュートしたよ';

  @override
  String get inboxConversationUnmuted => '会話のミュートを解除したよ';

  @override
  String get inboxCollabInviteCardTitle => 'コラボ招待';

  @override
  String get inboxCollabInviteCardUntitledVideo => '無題の動画';

  @override
  String get clickableTextViewVideoLink => '動画を見る';

  @override
  String get messageExternalLinkDialogTitle => '外部リンクを開きますか？';

  @override
  String messageExternalLinkDialogBody(String url) {
    return 'このリンクは外部サイトに移動します。安全ではない可能性があります:\n\n$url';
  }

  @override
  String get messageExternalLinkDialogOpen => '開く';

  @override
  String get inboxCollabInviteCoPostButton => '共同投稿';

  @override
  String get inboxCollabInviteNotMineButton => '自分のものではない';

  @override
  String get inboxCollabInvitePreviewTitle => '共同投稿の招待';

  @override
  String inboxCollabInvitePreviewTitleFrom(String displayName) {
    return '$displayNameからの共同投稿の招待';
  }

  @override
  String get inboxCollabInviteTimelineConsequence =>
      '共同投稿すると、この動画がコラボレーションとしてあなたのタイムラインに追加されます。';

  @override
  String get inboxCollabInviteAcceptedStatus => '承認済み';

  @override
  String get inboxCollabInviteIgnoredStatus => '無視済み';

  @override
  String get inboxCollabInviteAcceptError => '承認できなかったよ。もう一度試してね。';

  @override
  String get inboxCollabInviteSentStatus => '招待を送ったよ';

  @override
  String get inboxConversationCollabInvitePreview => 'コラボ招待';

  @override
  String collaboratorInviteDmBody(String title, String url) {
    return '$titleのコラボに招待されたよ：$url\n\nOpen Divine to review and accept.';
  }

  @override
  String collaboratorInviteDmBodyUntitled(String url) {
    return '動画のコラボに招待されたよ：$url\n\nOpen Divine to review and accept.';
  }

  @override
  String videoPublishCollaboratorInviteWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'コラボの招待が$count件送信されなかったよ。',
      one: 'コラボの招待が1件送信されなかったよ。',
    );
    return '動画を投稿したよ。でも$_temp0';
  }

  @override
  String get dmSendNoRecipientMessage => 'この会話の相手がわかりませんでした。受信トレイから開き直してください。';

  @override
  String get dmSendBlockedMessage => 'メッセージを送れるのは公式 Divine アカウントのみです';

  @override
  String get dmSendBlockedRetiredMessage =>
      'このスレッドは誰も読んでいません。Divine Moderation にメッセージを送ってください。';

  @override
  String get dmDeletePendingLabel => 'Deleting for everyone';

  @override
  String get dmDeleteRefusedMessage => '全員から削除できませんでした。';

  @override
  String get dmDeleteRefusedDetails => '一部の人には、このメッセージがまだ表示されている可能性があります。';

  @override
  String get dmRetiredThreadClosedTitle => 'このスレッドは終了しました。';

  @override
  String get messageRequestModerationNoticeCannotBeRemoved =>
      'このDivine Moderationのお知らせは削除できません。';

  @override
  String get dmRetiredThreadClosedBody =>
      'Divine Moderation は新しいアカウントに移りました。こちらはもう誰も読んでいません。';

  @override
  String get dmRetiredThreadOpenSupport => 'Divine Moderation にメッセージを送る';

  @override
  String get dmSendTooLongMessage =>
      'That message is too long to send. Shorten it and try again.';

  @override
  String get dmSendFailedMessage => 'メッセージを送信できなかった';

  @override
  String get dmResendFailedMessage => 'まだ送信できなかった';

  @override
  String get dmSendFailedSubtitle => '今すぐ再送するか、送信を中止してね。';

  @override
  String get dmSendFailedRetry => 'もう一回';

  @override
  String get dmSendPartialMessage => '送信したけど、ほかのデバイスには同期できなかった';

  @override
  String get dmConversationLoadError => 'メッセージを読み込めなかった';

  @override
  String get dmMessageInputHint => '何か書いてみましょう…';

  @override
  String get dmMessageBubbleSentHint => '送信したメッセージ';

  @override
  String get dmMessageBubbleReceivedHint => '受信したメッセージ';

  @override
  String get dmMessageBubbleLongPressHint => 'メッセージの操作';

  @override
  String get dmMessageBubbleFailedTapHint => 'このメッセージを再送信または削除';

  @override
  String get dmMessageActionCopyText => 'テキストをコピー';

  @override
  String get dmMessageActionCopyVideoUrl => '動画のURLをコピー';

  @override
  String get dmMessageActionDeleteForEveryone => '全員から削除';

  @override
  String get dmMessageActionReport => '報告';

  @override
  String get dmMessageActionRetrySend => '再送信';

  @override
  String get dmMessageActionCancelSend => '送信を中止';

  @override
  String get dmReactionAddCustomA11yLabel => 'カスタム絵文字リアクションを追加';

  @override
  String dmReelReplyComposerHint(String name) {
    return '$nameさんにメッセージ…';
  }

  @override
  String get dmReelReplyComposerHintSelf => '自分に返信…';

  @override
  String get dmReelReplyComposerSemanticLabel => 'このリールに返信';

  @override
  String get dmReelReplyViewChat => 'チャットを見る';

  @override
  String get dmReelReplySentAnnouncement => '返信を送信しました';

  @override
  String dmReelReactionSentAnnouncement(String emoji) {
    return '$emojiでリアクションしました';
  }

  @override
  String get dmReelReplyFailed => '送信できませんでした';

  @override
  String get dmReelReplyUnverified => '送信を確認できませんでした';

  @override
  String dmReactionChipOwnA11yLabel(String emoji) {
    return 'あなたのリアクション: $emoji';
  }

  @override
  String dmReactionChipOtherA11yLabel(String name, String emoji) {
    return '$name が $emoji でリアクションしました';
  }

  @override
  String dmReactionChipPendingA11yLabel(String emoji) {
    return 'リアクションを送信中: $emoji';
  }

  @override
  String get dmReactionChipFailedA11yLabel => 'リアクションに失敗しました。ダブルタップで再試行';

  @override
  String get dmReactionChipRetryAnnouncement => 'リアクションを再試行中';

  @override
  String dmReactionRemovalRefusedA11yLabel(String emoji) {
    return 'Couldn\'t remove your $emoji reaction. Double tap to try again';
  }

  @override
  String get dmReactionRemovalRefusedTitle => 'Couldn\'t remove your reaction.';

  @override
  String get dmReactionAddBlockedByRemoval =>
      '別のリアクションを追加する前に、前のリアクションの削除を完了してください。';

  @override
  String get dmReactionRemovalRefusedDetails =>
      'Some people may still be able to see this reaction.';

  @override
  String get dmReactionsSheetTitle => 'リアクション';

  @override
  String get dmReactionsViewA11yLabel => 'リアクションした人を見る';

  @override
  String get dmReactionRemoveAction => '削除';

  @override
  String get dmReactionRetryAction => '再試行';

  @override
  String get dmFormatBold => '太字';

  @override
  String get dmFormatItalic => '斜体';

  @override
  String get dmFormatStrikethrough => '取り消し線';

  @override
  String get dmFormatCode => 'コード';

  @override
  String get dmStatusFailed => '送信できなかった';

  @override
  String get inboxConversationActionsSheetLabel => '会話の操作';

  @override
  String inboxConversationTileLabel(String displayName) {
    return '$displayNameとの会話';
  }

  @override
  String inboxConversationTileLabelUnread(String displayName) {
    return '未読、$displayNameとの会話';
  }

  @override
  String inboxGroupConversationTitle(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count人',
    );
    return '$nameさん他$_temp0';
  }

  @override
  String get inboxConversationTileLongPressHint => '会話の操作を表示';

  @override
  String exploreVideoId(String id) {
    return 'ID: $id';
  }

  @override
  String exploreVideoTitle(String title) {
    return 'タイトル: $title';
  }

  @override
  String exploreVideoCounter(int current, int total) {
    return '動画 $current/$total';
  }

  @override
  String get exploreSearchHint => '検索...';

  @override
  String categoryVideoCount(int countValue, String count) {
    return '$count本の動画';
  }

  @override
  String get discoverListsFailedToUpdateSubscription =>
      'サブスクリプションの更新がうまくいかなかった。もう一回試してみて。';

  @override
  String get discoverListsTitle => 'リストを見つける';

  @override
  String get discoverListsFailedToLoad => 'リストの読み込みに失敗';

  @override
  String get discoverListsLoading => '公開リストを探してるよ...';

  @override
  String get discoverListsRelayTimeout => 'リレーが時間内にリストを返さなかったよ。もう一度試してね。';

  @override
  String get discoverListsServiceUnavailable => 'サービスを利用できません。';

  @override
  String get discoverListsEmptyTitle => '公開リストが見つからなかった';

  @override
  String get discoverListsEmptySubtitle => 'あとでまたチェックしてみてね';

  @override
  String get discoverListsByAuthorPrefix => '作成者:';

  @override
  String get curatedListEmptyTitle => 'このリストには動画がないよ';

  @override
  String get curatedListEmptySubtitle => '動画を追加してみよう';

  @override
  String get curatedListLoadingVideos => '動画を読み込み中...';

  @override
  String get curatedListFailedToLoad => 'リストの読み込みに失敗';

  @override
  String get curatedListVideoNotAvailable => '動画は利用できないよ';

  @override
  String get curatedListActionsTooltip => 'リストの操作';

  @override
  String get curatedListDeleteConfirmTitle => 'リストを削除する?';

  @override
  String get curatedListDeleteConfirmBody => 'リストをリレーから削除するよ。リスト内の動画は削除されないよ。';

  @override
  String get curatedListDeletedSnack => 'リストを削除したよ';

  @override
  String get curatedListDeleteFailed => 'リストを削除できなかったよ';

  @override
  String get peopleListsActionsTooltip => 'リストの操作';

  @override
  String get listDeleteAction => 'リストを削除';

  @override
  String get peopleListsDeleteConfirmTitle => 'リストを削除する?';

  @override
  String get peopleListsDeleteConfirmBody =>
      'リストを全員から削除するよ。リストの人たちのフォローは解除されないよ。';

  @override
  String get peopleListsDeleteFailed => 'リストを削除できなかったよ';

  @override
  String get commonRetry => 'もう一回';

  @override
  String get commonSomethingWentWrong => '問題が発生しました';

  @override
  String get commonDelete => '削除';

  @override
  String get commonCancel => 'キャンセル';

  @override
  String get commonBack => '戻る';

  @override
  String get commonClose => '閉じる';

  @override
  String get commonNotNow => '今はいい';

  @override
  String get commonLoading => '読み込み中';

  @override
  String get videoMetadataEditCoverFailedSnackbar =>
      'カバーを更新できませんでした。もう一度お試しください。';

  @override
  String get videoMetadataEditCoverSuccessAnnouncement => 'カバーを更新しました';

  @override
  String get videoMetadataC2paMissingTitle => '本物確認なしで投稿しますか？';

  @override
  String get videoMetadataC2paMissingBody =>
      'コンテンツ認証情報を追加できなかったため、この動画は人間が作成したものとして確認されません。もう一度試すには再生成するか、このまま投稿してください。';

  @override
  String get videoMetadataC2paMissingNote => 'コンテンツ認証情報にはインターネット接続が必要です。';

  @override
  String get videoMetadataC2paMissingNoteServiceUnavailable =>
      'コンテンツ認証情報サービスが応答しませんでした。あなたの接続の問題ではありません。';

  @override
  String get videoMetadataC2paMissingRegenerate => '再生成';

  @override
  String get videoMetadataC2paMissingSkip => 'スキップ';

  @override
  String get videoMetadataGenerationFailed => '生成に失敗しました';

  @override
  String get videoMetadataTags => 'タグ';

  @override
  String get videoMetadataExpiration => '有効期限';

  @override
  String get videoMetadataExpirationNotExpire => '期限なし';

  @override
  String get videoMetadataExpirationOneDay => '1日';

  @override
  String get videoMetadataExpirationOneWeek => '1週間';

  @override
  String get videoMetadataExpirationOneMonth => '1か月';

  @override
  String get videoMetadataExpirationOneYear => '1年';

  @override
  String get videoMetadataExpirationOneDecade => '10年';

  @override
  String get videoMetadataContentWarnings => 'コンテンツ警告';

  @override
  String get videoEditorStickers => 'ステッカー';

  @override
  String get trendingTitle => 'トレンド';

  @override
  String get libraryDeleteConfirm => '削除';

  @override
  String get libraryWebUnavailableHeadline => 'ライブラリはモバイルアプリで利用できます';

  @override
  String get libraryWebUnavailableDescription =>
      '下書きとクリップは端末に保存されます。管理するにはスマートフォンでDivineを開いてください。';

  @override
  String get libraryTabDrafts => '下書き';

  @override
  String get libraryTabClips => 'クリップ';

  @override
  String get libraryDeleteSelectedClipsTooltip => '選択したクリップを削除';

  @override
  String get libraryCloseSemanticLabel => 'ライブラリを閉じる';

  @override
  String get libraryStopSelectingClipsSemanticLabel => 'クリップの選択を終了';

  @override
  String get librarySelectClipsSemanticLabel => 'クリップを選択';

  @override
  String get libraryGridSizeLabel => 'グリッドのサイズ';

  @override
  String get libraryDisplayOptionsLabel => '並び替えとグリッドサイズ';

  @override
  String get libraryMoreActionsSemanticLabel => 'ライブラリのその他の操作';

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
  String get librarySelect => '選択';

  @override
  String get librarySortNewestCreation => '作成日が新しい順';

  @override
  String get librarySortOldestCreation => '作成日が古い順';

  @override
  String get librarySortLongestClip => '長いクリップ順';

  @override
  String get librarySortShortestClip => '短いクリップ順';

  @override
  String get librarySortSquareFirst => '正方形を先に';

  @override
  String get librarySortVerticalFirst => '縦長を先に';

  @override
  String get libraryDeleteClipsWarning => 'この操作は取り消せません。動画ファイルは端末から完全に削除されます。';

  @override
  String get libraryPreparingVideo => '動画を準備しています…';

  @override
  String libraryCreateVideo(int count) {
    return '動画を作成 ($count)';
  }

  @override
  String libraryClipsSavedToDestination(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$destinationに$count件のクリップを保存しました',
      one: '$destinationに1件のクリップを保存しました',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsSavePartialResult(int successCount, int failureCount) {
    return '保存 $successCount、失敗 $failureCount';
  }

  @override
  String libraryClipsSaveFailed(String destination) {
    return '$destinationに保存できませんでした';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return '$destinationの権限が拒否されました';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件のクリップを削除しました',
    );
    return '$_temp0';
  }

  @override
  String get libraryClipsDeletedUndoLabel => '元に戻す';

  @override
  String libraryTrashAutoDeletes(int daysLeft) {
    String _temp0 = intl.Intl.pluralLogic(
      daysLeft,
      locale: localeName,
      other: '$daysLeft日後に自動削除',
      one: '明日自動削除',
      zero: '今日自動削除',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts => '下書きを読み込めませんでした';

  @override
  String get libraryCouldNotLoadClips => 'クリップを読み込めませんでした';

  @override
  String get libraryOpenErrorDescription => 'ライブラリを開くときに問題が発生しました。もう一度お試しください。';

  @override
  String get libraryNoDraftsYetTitle => 'まだ下書きがありません';

  @override
  String get libraryNoDraftsYetSubtitle => '下書きとして保存した動画がここに表示されます';

  @override
  String get libraryNoClipsYetTitle => 'まだクリップがありません';

  @override
  String get libraryNoClipsYetSubtitle => '録画したクリップがここに表示されます';

  @override
  String get libraryDraftDeletedSnackbar => '下書きを削除しました';

  @override
  String get libraryDraftDeleteFailedSnackbar => '下書きを削除できませんでした';

  @override
  String get libraryDraftDuplicatedSnackbar => '下書きを複製しました';

  @override
  String get libraryDraftDuplicateFailedSnackbar => '下書きを複製できませんでした';

  @override
  String get libraryDraftInProgressBadge => '作業中';

  @override
  String get libraryDraftActionPost => '投稿';

  @override
  String get libraryDraftActionEdit => '編集';

  @override
  String get libraryDraftActionDuplicate => '複製';

  @override
  String get libraryDraftActionDelete => '下書きを削除';

  @override
  String libraryDraftCopyTitle(String title, int number) {
    return '$title（コピー $number）';
  }

  @override
  String get libraryDeleteDraftTitle => '下書きを削除';

  @override
  String libraryDeleteDraftMessage(String title) {
    return '「$title」を削除しますか？';
  }

  @override
  String get libraryDeleteClipTitle => 'クリップを削除';

  @override
  String get libraryDeleteClipMessage => 'このクリップを削除しますか？';

  @override
  String libraryClipDuration(String seconds) {
    return '$seconds秒';
  }

  @override
  String get libraryRecordVideo => '動画を録画';

  @override
  String videoClipSemanticLabel(String duration) {
    return '動画クリップ、$duration秒';
  }

  @override
  String videoClipArchivedSemanticLabel(String label) {
    return 'アーカイブ済み。$label';
  }

  @override
  String videoClipStopMotionSemanticLabel(String frames) {
    return 'ストップモーションクリップ、$frames';
  }

  @override
  String videoClipSemanticValueSelectedAtPosition(int position) {
    return '選択済み、$position 番目';
  }

  @override
  String get videoClipSemanticValueSelected => '選択済み';

  @override
  String get videoClipSemanticValueNotSelected => '未選択';

  @override
  String get videoClipSemanticHintDisabled => '無効';

  @override
  String get videoClipSemanticHintSelect => 'タップして選択、長押しでプレビュー';

  @override
  String get videoClipSemanticHintDeselect => 'タップして選択解除、長押しでプレビュー';

  @override
  String get routerInvalidCreator => '無効なクリエイター';

  @override
  String get routerInvalidHashtagRoute => '無効なハッシュタグルート';

  @override
  String get categoryGalleryCouldNotLoadVideos => '動画を読み込めなかった';

  @override
  String get categoryGalleryNoVideosInCategory => 'このカテゴリーには動画がないよ';

  @override
  String get categoryGallerySortOptionsLabel => 'カテゴリーの並び替えオプション';

  @override
  String get categoryGallerySortHot => '人気';

  @override
  String get categoryGallerySortNew => '新着';

  @override
  String get categoryGallerySortClassic => 'クラシック';

  @override
  String get categoryGallerySortForYou => 'おすすめ';

  @override
  String get categoriesCouldNotLoadCategories => 'カテゴリを読み込めなかった';

  @override
  String get categoriesNoCategoriesAvailable => 'カテゴリーがないよ';

  @override
  String get notificationsEmptyTitle => 'アクティビティはまだないよ';

  @override
  String get notificationsEmptySubtitle => 'あなたのコンテンツに反応があると、ここに出るよ';

  @override
  String get appsPermissionsTitle => '連携の権限';

  @override
  String get appsPermissionsRevoke => '取り消す';

  @override
  String get appsPermissionsEmptyTitle => '保存された連携の権限はないよ';

  @override
  String get appsPermissionsEmptySubtitle => 'アクセス承認を記憶した連携アプリは、ここに表示されるよ。';

  @override
  String nostrAppPermissionTitle(String appName) {
    return '$appNameが承認をリクエストしてるよ';
  }

  @override
  String get nostrAppPermissionDescription =>
      'このアプリは Divine の審査済みサンドボックス経由でアクセスをリクエストしてるよ。';

  @override
  String get nostrAppPermissionOrigin => 'オリジン';

  @override
  String get nostrAppPermissionMethod => 'メソッド';

  @override
  String get nostrAppPermissionCapability => '機能';

  @override
  String get nostrAppPermissionEventKind => 'イベントの種類';

  @override
  String get nostrAppPermissionAllow => '許可';

  @override
  String get appsDetailDefaultTitle => '連携アプリ';

  @override
  String get appsDetailNotFoundTitle => '連携が見つからないよ';

  @override
  String get appsDetailNotFoundSubtitle => 'この承認済みの連携は、もう Divine で利用できないよ。';

  @override
  String get appsDetailHowItWorksTitle => '仕組み';

  @override
  String get appsDetailHowItWorksBody =>
      'これは Divine の中で動く承認済みのサードパーティアプリだよ。Divine はこの連携に対して審査済みの機能だけを許可して、承認済みのオリジン以外への移動はブロックするよ。';

  @override
  String get appsDetailAboutTitle => '詳細';

  @override
  String get appsDetailPrimaryOriginTitle => 'メインのオリジン';

  @override
  String get appsDetailApprovedOriginsTitle => '承認済みのオリジン';

  @override
  String get appsDetailCapabilitiesTitle => '使える機能';

  @override
  String get appsDetailAskBeforeTitle => '確認するもの';

  @override
  String get appsDetailOpenButton => '連携を開く';

  @override
  String get appsDetailNoneDeclared => 'まだ宣言されてないよ';

  @override
  String get appsDirectoryTitle => '連携アプリ';

  @override
  String get appsDirectoryIntroTitle => '承認済みのサードパーティアプリ';

  @override
  String get appsDirectoryIntroBody => 'Divine の中で動く承認済みのサードパーティアプリ';

  @override
  String get appsDirectoryErrorTitle => '連携アプリを読み込めなかったよ';

  @override
  String get appsDirectoryErrorSubtitle => '引っ張って承認済みの連携をもう一回試してね。';

  @override
  String get appsDirectoryEmptyTitle => '承認済みの連携はまだないよ';

  @override
  String get appsDirectoryEmptySubtitle =>
      'Divine が追加していくと、承認済みのサードパーティアプリがここに表示されるよ。';

  @override
  String get appsDirectoryRefresh => '更新';

  @override
  String get appsDirectoryUnsupportedTitle => '連携アプリは Divine モバイルで動くよ';

  @override
  String get appsDirectoryUnsupportedSubtitle => '承認済みの連携は今のところモバイルだけで使えるよ。';

  @override
  String get appsSandboxUnavailableTitle => '連携が利用できないよ';

  @override
  String get appsSandboxUnavailableBody =>
      '[連携アプリ]タブから承認済みの連携を開いてね。そうすると Divine が正しいアクセスポリシーを適用できるよ。';

  @override
  String get appsSandboxLoadingTitle => '連携を読み込み中';

  @override
  String get appsSandboxLoadingSubtitle => '起動前に承認済みの連携を確認してるよ。';

  @override
  String get appsSandboxBlockedTitle => '安全のためにブロックしたよ';

  @override
  String appsSandboxBlockedSubtitle(String uri) {
    return 'この連携が承認済みのオリジンから出ようとしたよ。\n\n$uri';
  }

  @override
  String get shareCopiedPostLink => '投稿へのリンクをクリップボードにコピーしたよ';

  @override
  String get shareCopiedEventJson => 'Nostr イベントの JSON をクリップボードにコピーしたよ';

  @override
  String get shareCopiedEventId => 'Nostr イベント ID をクリップボードにコピーしたよ';

  @override
  String get authHeroTaglineAuthentic => 'ありのままの瞬間。';

  @override
  String get authHeroTaglineHuman => '人間の創造性。';

  @override
  String get keyImportFailedToImport => '鍵のインポートまたはバンカーへの接続に失敗したよ';

  @override
  String get keyImportInvalidBunkerUrl => '無効なバンカー URL だよ';

  @override
  String get keyImportInvalidFormat =>
      '無効な形式だよ。nsec...、hex、ncryptsec1...、または bunker://... を使ってね';

  @override
  String get keyImportInvalidNsecFormat => '無効な nsec 形式だよ。63文字である必要があるよ';

  @override
  String get keyImportKeyFieldLabel => '秘密鍵またはバンカー URL';

  @override
  String get keyImportKeyRequired => '秘密鍵またはバンカー URL を入力してね';

  @override
  String get keyImportPasswordRequired => 'この暗号化された鍵のパスワードを入力してね';

  @override
  String get keyImportSecurityWarningBody =>
      '秘密鍵は絶対に誰にも教えないでね。この鍵があるとあなたの Nostr アイデンティティにフルアクセスできちゃうよ。';

  @override
  String get keyImportSecurityWarningTitle => '秘密鍵は大切に守ってね！';

  @override
  String get keyImportSubtitle =>
      '秘密鍵かバンカー URL を使って、あなたの既存の Nostr アイデンティティをインポートしよう。';

  @override
  String get keyImportTitle => 'Nostr アイデンティティを\nインポート';

  @override
  String get commentAuthorYouIndicator => 'あなた';

  @override
  String commentAuthorAvatarSemanticLabel(String name) {
    return '$nameのプロフィールを表示';
  }

  @override
  String get commentOptionsDeleteSemanticLabel => 'コメントを削除';

  @override
  String get commentOptionsEditSemanticLabel => 'コメントを編集';

  @override
  String get commentOptionsFlagContentLabel => 'コンテンツにフラグを付ける';

  @override
  String get commentOptionsFlagContentSemanticLabel => 'このコンテンツにフラグを付ける';

  @override
  String get commentOptionsFlagReasonPrompt => 'このコメントにフラグを付ける理由を選んでね';

  @override
  String get commentOptionsFlagSubmit => '送信';

  @override
  String get commentOptionsTitle => 'オプション';

  @override
  String get commentsEmptyClassicVineMessage =>
      'アーカイブから昔のコメントをインポートする作業をまだ進めてるよ。まだ準備できてないんだ。';

  @override
  String get commentsEmptyClassicVineTitle => 'クラシック Vine';

  @override
  String get commentsInputEditingLabel => '編集中';

  @override
  String get commentsInputSemanticHint => 'コメントを追加';

  @override
  String get commentsInputSemanticHintEdit => 'コメントを編集';

  @override
  String get commentsInputSemanticHintReply => '返信を追加';

  @override
  String get commentsInputSemanticLabel => 'コメント入力';

  @override
  String get commentsInputSemanticLabelEdit => '編集入力';

  @override
  String get commentsInputSemanticLabelReply => '返信入力';

  @override
  String classicVinersViewProfileSemanticLabel(String displayName) {
    return '$displayNameのプロフィールを表示';
  }

  @override
  String get classicsEmptyDescription => 'クラシックのアーカイブを読み込んでるよ';

  @override
  String get classicsEmptyTitle => 'クラシックが見つからないよ';

  @override
  String get classicsErrorTitle => 'クラシックの読み込みに失敗したよ';

  @override
  String get classicsUnavailableDescription =>
      'クラシックは Funnelcake リレーに接続してるときだけ利用できるよ。';

  @override
  String get classicsUnavailableSettingsHint =>
      '設定で Funnelcake 対応のリレーに切り替えると、クラシックのアーカイブにアクセスできるよ。';

  @override
  String get classicsUnavailableTitle => 'クラシックは利用できないよ';

  @override
  String get hashtagFeedEmptySubtitle => 'このハッシュタグで最初の動画を投稿しよう！';

  @override
  String hashtagFeedEmptyTitle(String hashtag) {
    return '#$hashtag の動画は見つからなかったよ';
  }

  @override
  String get hashtagFeedLoadingSubtitle => '少し時間がかかるかも';

  @override
  String hashtagFeedLoadingTitle(String hashtag) {
    return '#$hashtag の動画を読み込み中...';
  }

  @override
  String get hashtagInputHint => 'ハッシュタグを追加... #vine #nostr';

  @override
  String get newVideosTabEmptySubtitle => '新しいコンテンツはまたあとでチェックしてね';

  @override
  String get newVideosTabEmptyTitle => '新着動画に動画はないよ';

  @override
  String get popularVideosContextTitle => '人気の動画';

  @override
  String get popularVideosEmptySubtitle => '新しいコンテンツはまたあとでチェックしてね';

  @override
  String get popularVideosEmptyTitle => '人気の動画に動画はないよ';

  @override
  String get popularVideosErrorTitle => 'トレンド動画の読み込みに失敗したよ';

  @override
  String get popularVideosFeedSourceLabel => '人気フィードのソース';

  @override
  String get trendingHashtagsLoading => 'ハッシュタグを読み込み中...';

  @override
  String trendingHashtagsViewVideosTagged(String hashtag) {
    return '$hashtag が付いた動画を見る';
  }

  @override
  String videoGridAuthorSemanticLabel(String name) {
    return '動画の作者: $name';
  }

  @override
  String videoGridDescriptionSemanticLabel(String description) {
    return '動画の説明: $description';
  }

  @override
  String get forYouAlgorithmChoiceBody =>
      'Divine が目指すのは、本当の意味でアルゴリズムを選べるようにすること。ひとつのブラックボックスなアルゴリズムに縛られるんじゃなくて、いくつかのおすすめの方法から選べるようになるよ:';

  @override
  String get forYouAlgorithmChoiceChronological => 'フォロー中のクリエイターの時系列タイムライン';

  @override
  String get forYouAlgorithmChoiceClosing =>
      'これで、注目のコントロールをプラットフォームに任せるんじゃなくて、あなた自身が握れるようになるよ。フィードがどう組み立てられてるかを知って、いつでも好きに変えられる力を持つべきなんだ。';

  @override
  String get forYouAlgorithmChoiceCustomFeeds =>
      '音楽、コメディ、アートみたいなテーマ別の、コミュニティが作ったカスタムフィード';

  @override
  String get forYouAlgorithmChoicePersonalizedFeed => 'あなた専用の「おすすめ」フィード';

  @override
  String get forYouAlgorithmChoiceTitle => 'アルゴリズムはあなたが選ぶ';

  @override
  String get forYouAlgorithmChoiceTrending => 'トレンドや人気のコンテンツ';

  @override
  String get forYouAlgorithmCommentsDescription =>
      '強いシグナル — 反応したくなるくらい引き込まれたってこと';

  @override
  String get forYouAlgorithmHowItWorksBody =>
      'Divine は、あなたがコンテンツとどうやりとりするかに注目して、何が好きかを理解するよ。動画を見たり、リアクションしたり、コメントを残したり、リポストするたびに、システムはそれを覚えていくんだ。';

  @override
  String get forYouAlgorithmHowItWorksTitle => '仕組み';

  @override
  String get forYouAlgorithmInteractionsIntro => 'アクションによって、興味の強さのシグナルが違うよ:';

  @override
  String get forYouAlgorithmNewToDivineBody1 =>
      'まだ視聴履歴がたまってないときは、今人気やトレンドのものと最近のアップロードをミックスして見せるよ。探索を始めるのにぴったりのスタート地点になるよ。';

  @override
  String get forYouAlgorithmNewToDivineBody2 =>
      '動画を見たり、いいねしたり、コンテンツに関わっていくうちに、おすすめはだんだんあなた好みになっていくよ。そのうち、おすすめフィードには自分だけじゃ見つけられなかったクリエイターの動画が出てくるようになるよ。';

  @override
  String get forYouAlgorithmNewToDivineTitle => 'Divine は初めて?';

  @override
  String get forYouAlgorithmOpenSourceBody =>
      '私たちは、開発者が自分のアルゴリズムを実装できて、あなたがどれを使うか選べる（または完全にオプトアウトできる）オープンなシステムを作ってるよ。';

  @override
  String get forYouAlgorithmOpenSourceTitle => 'オープンソースで透明';

  @override
  String get forYouAlgorithmReactionsDescription => '中くらいのシグナル — サクッと好意を示す方法';

  @override
  String get forYouAlgorithmReactionsTitle => 'リアクション';

  @override
  String get forYouAlgorithmRepostsDescription =>
      '最も強いシグナル — フォロワーにシェアするのは強力な推薦だよ';

  @override
  String get forYouAlgorithmSubtitle => 'オープンソースのおすすめエンジン Gorse を使ってるよ';

  @override
  String get forYouAlgorithmTitle => 'Divine のアルゴリズム';

  @override
  String get forYouAlgorithmViewsDescription => '軽いシグナル — 基本的な興味を示すよ';

  @override
  String get forYouEmptyDescription => '動画を見たりいいねしたりすると、あなた好みのおすすめが表示されるよ。';

  @override
  String get forYouEmptyTitle => 'おすすめはまだないよ';

  @override
  String get forYouErrorTitle => 'おすすめの読み込みに失敗したよ';

  @override
  String get forYouUnavailableDescription =>
      'あなた好みのおすすめには Funnelcake への接続が必要だよ。';

  @override
  String get forYouUnavailableTitle => 'おすすめは利用できないよ';

  @override
  String get inboxConversationOptionsLabel => 'オプション';

  @override
  String get inboxConversationViewProfileButton => 'プロフィールを表示';

  @override
  String get inboxMessageRequestsEmpty => 'メッセージリクエストはないよ';

  @override
  String inboxMessageRequestsSemanticLabel(int requestCount) {
    return 'メッセージリクエスト、$requestCount件保留中';
  }

  @override
  String get inboxMessageRequestsTitle => 'メッセージリクエスト';

  @override
  String get inboxMessagesTab => 'メッセージ';

  @override
  String inboxRequestTileLabel(String displayName) {
    return '$displayNameからのメッセージリクエスト';
  }

  @override
  String get inboxRequestTileSubtitle => 'メッセージリクエストを送信したよ';

  @override
  String get inboxRequestsMarkAllRead => 'すべてのリクエストを既読にする';

  @override
  String get inboxRequestsRemoveAll => 'すべてのリクエストを削除';

  @override
  String get messageRequestDeclineAndRemoveButton => '拒否して削除';

  @override
  String messageRequestDeclinedSnackbar(String displayName) {
    return '$displayNameのリクエストを拒否したよ';
  }

  @override
  String get messageRequestLoadFailed => 'このリクエストを読み込めませんでした。';

  @override
  String messageRequestFollowersCount(int countValue, String count) {
    return '$count人のフォロワー';
  }

  @override
  String messageRequestVideosCount(int countValue, String count) {
    return '$count本の動画';
  }

  @override
  String messageRequestMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件のメッセージ',
      one: '1件のメッセージ',
    );
    return '$_temp0';
  }

  @override
  String get messageRequestViewMessagesButton => 'メッセージを表示';

  @override
  String get messageRequestViewProfileButton => 'プロフィールを表示';

  @override
  String messageRequestWantsToMessageYou(
    String displayName,
    String messageText,
  ) {
    return '$displayNameがあなたにメッセージを送りたがってるよ。$messageTextを送信済みだよ。';
  }

  @override
  String get deleteAccountAccountChanged =>
      'アカウントが切り替わったから、何も削除されていないよ。削除したいアカウントで削除画面を開き直してね。';

  @override
  String get deleteAccountConfirmDeletePrompt => '確認のため、次を入力してね:';

  @override
  String get deleteAccountConfirmUsernamePrompt => '確認のため、ユーザー名を入力してね:';

  @override
  String get deleteAccountConfirmationHint => 'DELETE と入力してね';

  @override
  String get deleteAccountConfirmationHintUsername => 'ユーザー名を入力してね';

  @override
  String get deleteAccountDeleteAllContentButton => 'すべてのコンテンツを削除';

  @override
  String get accountDeletionRecoveryTitle => 'アカウントを削除中';

  @override
  String get accountDeletionRecoveryBody =>
      'アカウントの削除を完了できませんでした。ユーザー名はあなたのために確保されていて、まだ元に戻せます。';

  @override
  String accountDeletionRecoveryBodyWithExpiry(String expiryDate) {
    return 'We couldn\'t finish deleting your account. Your username is reserved for you until $expiryDate and can still be restored.';
  }

  @override
  String get accountDeletionRestoreUsername => 'ユーザー名を元に戻す';

  @override
  String get accountDeletionFinishingBody =>
      '削除リクエストはまだ処理中です。処理が完了するまで、別のアカウントを使用できます。';

  @override
  String get accountDeletionOtherAccountPending =>
      'このデバイスでは、別のアカウントの削除がまだ処理中です。処理が完了してから、このアカウントを削除してください。';

  @override
  String get accountDeletionCancellingBody =>
      '削除をキャンセルしています。この画面を離れる前にもう一度確認してください。';

  @override
  String get accountDeletionRecoveryFailed =>
      'ユーザー名をまだ元に戻せませんでした。接続を確認してもう一度お試しください。';

  @override
  String get accountDeletionUsernameRestored =>
      'ユーザー名を元に戻しました。アカウントは削除されていません。';

  @override
  String get accountDeletionRecoveryStatusFailed =>
      '削除の状況を確認できませんでした。接続を確認してもう一度お試しください。';

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
      'アカウント削除は現在利用できません。何も削除されていません。';

  @override
  String get deleteAccountDeletionIncomplete => 'アカウントの削除を完了できなかったよ。もう一回試してね。';

  @override
  String get deleteAccountDeletionNotStarted =>
      'We couldn\'t start deleting your account. Nothing was deleted. Try again.';

  @override
  String get deleteAccountFinalConfirmationTitle => '⚠️ 最終確認';

  @override
  String get deleteAccountKeyDeletionWarning =>
      '削除リクエストを送信したよ。でも、鍵がこのデバイスから完全には消えてないかもしれないよ。[設定]→[Nostr 鍵]→[鍵を削除]でもう一回試してね。';

  @override
  String get deleteAccountLocalDataDeletionFailed =>
      '削除リクエストを送信してサインアウトしたよ。でも、一部のローカルデータはこのデバイスから削除できなかったよ。';

  @override
  String get deleteAccountPreparingDeletion => '削除の準備中...';

  @override
  String deleteAccountProgressEvents(int current, int total) {
    return '$current / $total 件のイベント';
  }

  @override
  String get deleteAccountRemoveKeysBody =>
      'このアカウントのローカルログインをこのデバイスから削除するよ。Divine アカウントや Nostr アイデンティティは削除されないよ。\n\nこのアカウントの下書きとクリップは、このデバイスに保存されたまま残るよ。これが最後のローカルアカウントなら、ログイン画面に戻るよ。';

  @override
  String get deleteAccountRemoveKeysConfirm => 'デバイスから削除';

  @override
  String get deleteAccountRemoveKeysTitle => 'このアカウントをこのデバイスから削除する?';

  @override
  String get deleteAccountReauthRequired =>
      'アカウントを削除するには、もう一度サインインしてね。まだ何も削除されていないよ。';

  @override
  String get deleteAccountServerDeletionFailed =>
      '投稿の削除リクエストは送ったけど、アカウントの削除を完了できなかったよ。少ししてからもう一回試してね。';

  @override
  String get deleteAccountSuccess =>
      'Divineアカウントは削除されました。Nostrの投稿についても削除リクエストを送信しましたが、一部のリレー、クライアント、キャッシュにはコピーが残る場合があります。';

  @override
  String get deleteAccountSuccessContentUnverified =>
      'アカウントの削除をリクエストしたよ。既存の投稿の一部は、個別に削除を確認できなかったよ。';

  @override
  String get deleteAccountWarningBody =>
      'これはアカウントとコンテンツの削除リクエストを送信して、可能なら Divine アカウントを削除し、このデバイスからサインアウトするよ。一部のリレーやクライアント、検索インデックスにはコピーが残ることがあるよ。ほかのサインイン中のデバイスは、そこで鍵を削除するまで有効なままだよ。';

  @override
  String get findPeopleNoContacts => '連絡先が見つからないよ。\n誰かをフォローすると、ここに表示されるよ。';

  @override
  String get geoBlockedCityLabel => '市区町村';

  @override
  String get geoBlockedCountryLabel => '国';

  @override
  String get geoBlockedDefaultReason => '現地の規制により、このサービスはお住まいの地域では利用できないよ。';

  @override
  String get geoBlockedLegalNotice =>
      '私たちはあなたの地域の法律や規制を尊重してるよ。この制限は、あなたの IP アドレスの位置情報に基づいてるよ。';

  @override
  String get geoBlockedRegionLabel => '地域';

  @override
  String get geoBlockedTitle => 'サービスは利用できないよ';

  @override
  String get likedVideosEmpty => 'いいねした動画はないよ';

  @override
  String get likedVideosInvalidRoute => '無効なルート';

  @override
  String get likedVideosTitle => 'いいねした動画';

  @override
  String get uploadFailureSheetRetryingSnackbar => 'アップロードを再試行中…';

  @override
  String get uploadFailureSheetSaveToDraftsButton => '下書きに保存';

  @override
  String get uploadFailureSheetSavedToDraftsSnackbar => '下書きに保存したよ';

  @override
  String get uploadFailureSheetTitle => 'アップロードに失敗したよ';

  @override
  String get uploadFailureSheetTryAgainButton => 'もう一回試す';

  @override
  String get videoEditorAudioImportAudio => '音声をインポート';

  @override
  String get videoEditorAudioImportFailed => '音声のインポートに失敗したよ。';

  @override
  String get videoIconPlaceholderLabel => '動画';

  @override
  String get publishErrorNotSignedIn => '動画を投稿するにはサインインしてね。';

  @override
  String get publishErrorNoRetry => 'やり直せるアップロードがないよ。';

  @override
  String get publishErrorNoInternet =>
      'ネットに接続できないよ。Wi-Fi かモバイルデータを確認して、もう一回試してみて。';

  @override
  String get publishErrorServerUnreachable =>
      'サーバーに接続できなかったよ。少し待ってからもう一回試してみて。';

  @override
  String get publishErrorTimeout =>
      'アップロードがタイムアウトしたよ。接続のいい場所に移るか、もっと小さい動画で試してみて。';

  @override
  String get publishErrorTls =>
      'セキュア接続に失敗したよ。ネットワークを確認してみて。公共の Wi-Fi だとアップロードがブロックされることがあるよ。';

  @override
  String publishErrorServerNotFound(String serverName) {
    return 'メディアサーバー（$serverName）が利用できないよ。設定で別のサーバーを選べるよ。';
  }

  @override
  String get publishErrorFileTooLarge =>
      '動画ファイルがサーバーには大きすぎるよ。トリミングするか、画質を下げて試してみて。';

  @override
  String publishErrorServerInternalError(String serverName) {
    return 'メディアサーバー（$serverName）で内部エラーが起きたよ。設定で別のサーバーを選べるよ。';
  }

  @override
  String publishErrorServerDown(String serverName) {
    return 'メディアサーバー（$serverName）が一時的にダウンしてるよ。少し待ってからもう一回試すか、設定で別のサーバーを選んでみて。';
  }

  @override
  String get publishErrorForbidden => 'このサーバーにアップロードする権限がないよ。';

  @override
  String get publishErrorFileNotFound =>
      '動画ファイルが見つからなかったよ。削除されたのかもしれない。もう一回撮影して試してみて。';

  @override
  String get publishErrorLowStorage => '端末の空き容量が足りないよ。容量を空けてもう一回試してみて。';

  @override
  String get publishErrorThumbnailFailed =>
      '動画はアップロードできたけど、サムネイルを準備できなかったよ。もう一回試してみて。';

  @override
  String get publishErrorNostrPublishFailed =>
      '動画はアップロードできたけど、投稿を公開できなかったよ。リレー設定を確認して、もう一回試してみて。';

  @override
  String get publishErrorAccountRestricted =>
      'Your account is restricted, so this post couldn’t be published.';

  @override
  String get uploadFailureSheetAccountStatusButton => 'View Account Status';

  @override
  String get publishErrorAudioReuseNotPermitted =>
      '動画はアップロードできたけど、この音源は再利用が許可されてないよ。別の音源を選んで投稿してね。';

  @override
  String get publishErrorInterrupted => 'アップロードが中断されたよ。もう一回試す？';

  @override
  String get publishErrorAccountChanged =>
      'この動画は別のアカウントのものだよ。投稿するにはそのアカウントに戻ってね。';

  @override
  String get publishErrorGeneric => '問題が発生したよ。もう一回試してみて。';

  @override
  String get publishErrorRateLimited => '今はアップロードが多すぎるよ。少し待ってからもう一回試してみて。';

  @override
  String get publishErrorUploadSessionExpired =>
      'アップロードのセッションが切れちゃったよ。もう一回試してみて。';

  @override
  String get publishErrorPermissionDenied =>
      'Divine にアップロードの権限がないよ。設定でアプリの権限を確認して、もう一回試してみて。';

  @override
  String get publishErrorOutOfMemory => '端末のメモリが足りないよ。アプリをいくつか閉じて、もう一回試してみて。';

  @override
  String get publishErrorOverlaysUnavailable =>
      'この下書きのテキストとステッカーを準備できなかったよ。エディタで開いてから、もう一回投稿してみて。';

  @override
  String get publishErrorUnknownServer => '不明なサーバー';

  @override
  String searchFilterPillSemanticLabel(String filter) {
    return 'フィルター: $filter';
  }

  @override
  String searchNoResultsFound(String query) {
    return '「$query」の結果は見つからなかったよ';
  }

  @override
  String searchTagChipViewVideosTaggedLabel(String tag) {
    return '$tag が付いた動画を見る';
  }

  @override
  String audioAttributionRowSemanticLabel(
    String soundName,
    String creatorName,
  ) {
    return 'サウンド: $creatorNameの$soundName。タップするとサウンドの詳細を見れるよ。';
  }

  @override
  String metadataSoundsOriginalSoundSemantics(String creatorName) {
    return '$creatorNameのオリジナルサウンド。タップするとこのサウンドを使えるよ。';
  }

  @override
  String metadataSoundsSharedSoundSemantics(
    String soundName,
    String creatorName,
  ) {
    return 'サウンド: $creatorNameの$soundName。タップすると詳細を見れるよ。';
  }

  @override
  String get soundDetailLoadError => 'サウンドの読み込みに失敗したよ。もう一回試してみて。';

  @override
  String get soundDetailNotFoundMessage => 'このサウンドは見つからなかったよ';

  @override
  String get soundDetailNotFoundTitle => 'サウンドが見つからないよ';

  @override
  String videoFeedLoopCountLabel(int count) {
    return '🔁 $countループ';
  }

  @override
  String get originalSoundUnavailableBody => 'この動画の音声は個別には利用できないよ。';

  @override
  String originalSoundByCreator(String creatorName) {
    return 'オリジナルサウンド - $creatorName';
  }

  @override
  String get ogVinerBadgeLabel => 'OG Viner';

  @override
  String get profileBadgeOgVinerBody =>
      'この人はオリジナルの Vine を投稿していて、Divine がアーカイブで見つけたよ。アカウントの認証バッジではないので注意。';

  @override
  String get ogBetaTesterBadgeLabel => 'OG Beta Tester';

  @override
  String get profileBadgeOgBetaTesterBody =>
      'This person was testing Divine during the beta, before it opened to everyone. It is not an account verification badge.';

  @override
  String get profileBadgeCheckmarkTitle => 'プロフィールのチェックマーク';

  @override
  String get profileBadgeCheckmarkBody =>
      'Divine はこのチェックマークをチームのアカウントに付けてるよ。 NIP-05、認証済みアカウントのリンク、OG Viner ステータスとは別物だよ。';

  @override
  String get unfollowConfirmButton => 'フォロー解除';

  @override
  String get videoClipSaveFailed => 'クリップの保存に失敗したよ';

  @override
  String videoClipSaveTo(String destination) {
    return '$destinationに保存';
  }

  @override
  String get videoClipDelete => 'クリップを削除';

  @override
  String inspiredByAttributionMultipleSemanticLabel(
    String creatorName,
    int additionalCreatorCount,
  ) {
    return '$creatorName +$additionalCreatorCountにインスパイアされたよ。タップするとプロフィールを見れるよ。';
  }

  @override
  String inspiredByAttributionSemanticLabel(String creatorName) {
    return '$creatorNameにインスパイアされたよ。タップするとプロフィールを見れるよ。';
  }

  @override
  String get bugReportSendReport => 'レポートを送信';

  @override
  String get supportSubjectRequiredLabel => '件名 *';

  @override
  String get supportPublicSubmissionTitle => '公開 GitHub 投稿';

  @override
  String get supportPublicSubmissionMessage =>
      'ここで送信した内容はすべて、開発者が対応できるよう GitHub 上のオープンソースリポジトリに投稿されます。投稿とログイン中のアカウントは誰でも閲覧できます。';

  @override
  String get supportRequiredHelper => '必須';

  @override
  String get supportFieldLimitReached => 'これが上限の文字数です。これを超えた分は追加されていません。';

  @override
  String get bugReportSubjectHint => '問題の概要';

  @override
  String get bugReportDescriptionRequiredLabel => '何が起きた? *';

  @override
  String get bugReportDescriptionHint => '起きた問題を教えてね';

  @override
  String get bugReportStepsLabel => '再現手順';

  @override
  String get bugReportStepsHint => '1. ...に移動\n2. ...をタップ\n3. エラーが出る';

  @override
  String get bugReportExpectedBehaviorLabel => '期待していた動作';

  @override
  String get bugReportExpectedBehaviorHint => '本来どうなるはずだった?';

  @override
  String get bugReportDiagnosticsNotice => 'デバイス情報とログは自動で添付されるよ。';

  @override
  String get bugReportSuccessMessage => 'ありがとう！レポートを受け取ったよ。Divine をよくするのに使うね。';

  @override
  String get bugReportAttachImages => '画像を添付';

  @override
  String bugReportImagesCount(int count, int max) {
    return '$max 枚中 $count 枚を選択';
  }

  @override
  String get bugReportRemoveImage => '画像を削除';

  @override
  String get bugReportUploadFailed =>
      '選択した画像をアップロードできませんでした。もう一度試すか、画像なしでレポートを送ってください。';

  @override
  String get bugReportSendFailed => 'バグレポートの送信に失敗。あとでもう一回試してみて。';

  @override
  String get featureRequestSendRequest => 'リクエストを送信';

  @override
  String get featureRequestSubjectHint => 'アイデアの概要';

  @override
  String get featureRequestDescriptionRequiredLabel => 'どんな機能がほしい? *';

  @override
  String get featureRequestDescriptionHint => 'ほしい機能を教えてね';

  @override
  String get featureRequestUsefulnessLabel => 'どう役に立つ?';

  @override
  String get featureRequestUsefulnessHint => 'この機能のメリットを教えてね';

  @override
  String get featureRequestWhenLabel => 'どんなときに使う?';

  @override
  String get featureRequestWhenHint => 'この機能が役立つシーンを教えてね';

  @override
  String get featureRequestSuccessMessage => 'ありがとう！機能リクエストを受け取ったよ。チェックするね。';

  @override
  String get featureRequestSendFailed => '機能リクエストの送信に失敗。あとでもう一回試してみて。';

  @override
  String get notificationFollowBack => 'フォローバック';

  @override
  String get followingTitle => 'フォロー中';

  @override
  String followingTitleForName(String displayName) {
    return '$displayNameのフォロー中';
  }

  @override
  String get followingFailedToLoadList => 'フォロー中リストの読み込みがうまくいかなかった';

  @override
  String get followingEmptyTitle => 'まだ誰もフォローしてないよ';

  @override
  String get followersTitle => 'フォロワー';

  @override
  String followersTitleForName(String displayName) {
    return '$displayNameのフォロワー';
  }

  @override
  String get followersFailedToLoadList => 'フォロワーリストの読み込みがうまくいかなかった';

  @override
  String get followersEmptyTitle => 'フォロワーはまだいないよ';

  @override
  String get followersUpdateFollowFailed => 'フォロー状態の更新に失敗。もう一回試してみて。';

  @override
  String get followersSortSemanticLabel => 'フォロワーを並べ替え';

  @override
  String get followingSortSemanticLabel => 'フォロー中を並べ替え';

  @override
  String get followSortTitle => '並べ替え';

  @override
  String get followSortNewest => '新しい順';

  @override
  String get followSortOldest => '古い順';

  @override
  String get newMessageTitle => '新しいメッセージ';

  @override
  String get newMessageFindPeople => '人を探す';

  @override
  String get newMessageNoContacts => '連絡先が見つからなかった。\n人をフォローするとここに出るよ。';

  @override
  String get newMessageNoUsersFound => 'ユーザーが見つからなかった';

  @override
  String get hashtagSearchTitle => 'ハッシュタグを検索';

  @override
  String get hashtagSearchSubtitle => 'トレンドのトピックとコンテンツを見つけよう';

  @override
  String hashtagSearchNoResults(String query) {
    return '「$query」のハッシュタグは見つからなかった';
  }

  @override
  String get hashtagSearchFailed => '検索に失敗';

  @override
  String get userNotAvailableTitle => 'アカウントは利用できないよ';

  @override
  String get userNotAvailableBody => 'このアカウントは今は利用できないよ。';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String get blossomFailedToSaveSettings => '設定の保存がうまくいかなかった。もう一回試してみて。';

  @override
  String get blossomValidServerUrl =>
      '有効なサーバー URL を入力してね (例: https://blossom.band)';

  @override
  String get blossomSettingsSaved => 'Blossom の設定を保存したよ';

  @override
  String get blossomSaveTooltip => '保存';

  @override
  String get blossomAboutTitle => 'Blossom について';

  @override
  String get blossomAboutDescription =>
      'Blossom は分散型のメディアストレージプロトコルで、対応する任意のサーバーに動画をアップロードできるよ。デフォルトでは Divine の Blossom サーバーにアップロードされる。下のオプションを有効にすると、カスタムサーバーが使えるよ。';

  @override
  String get blossomUseCustomServer => 'カスタム Blossom サーバーを使う';

  @override
  String get blossomCustomServerEnabledSubtitle =>
      '動画はカスタム Blossom サーバーにアップロードされるよ';

  @override
  String get blossomCustomServerDisabledSubtitle =>
      '現在、動画は Divine の Blossom サーバーにアップロードされてるよ';

  @override
  String get blossomCustomServerUrl => 'カスタム Blossom サーバー URL';

  @override
  String get blossomCustomServerHelper => 'カスタム Blossom サーバーの URL を入力してね';

  @override
  String get blossomPopularServers => '人気の Blossom サーバー';

  @override
  String get blossomServerUrlMustUseHttps =>
      'Blossom サーバー URL は https:// を使ってね';

  @override
  String get blueskyFailedToUpdateCrosspost => 'クロスポスト設定の更新がうまくいかなかった';

  @override
  String get blueskySignInRequired => 'Bluesky 設定を管理するにはサインインしてね';

  @override
  String get blueskyPublishVideos => '動画を Bluesky に公開';

  @override
  String get blueskyEnabledSubtitle => '動画は Bluesky に公開されるよ';

  @override
  String get blueskyDisabledSubtitle => '動画は Bluesky には公開されないよ';

  @override
  String get blueskyBackfillDisclosureTitle => '過去の動画も投稿されます';

  @override
  String get blueskyBackfillDisclosureSubtitle =>
      'これをオンにすると、Divine は古い動画から順に、1日の上限を急がず Bluesky へ送り始めます。';

  @override
  String get blueskyHandle => 'Bluesky ハンドル';

  @override
  String get blueskyDid => 'Bluesky DID';

  @override
  String get blueskyStatus => 'ステータス';

  @override
  String get blueskyStatusReady => 'アカウント準備完了';

  @override
  String get blueskyStatusPending => 'アカウントを準備中...';

  @override
  String get blueskyStatusFailed => 'アカウントの準備に失敗';

  @override
  String get blueskyStatusDisabled => 'アカウントは無効';

  @override
  String get blueskyStatusNotLinked => 'Bluesky アカウントが連携されてないよ';

  @override
  String get blueskyUsernameRequired =>
      'Bluesky に投稿する前に divine.video ハンドルを設定してください';

  @override
  String get blueskyUsernameRequiredSubtitle =>
      'Bluesky への投稿には取得済みの username.divine.video ハンドルが必要です。';

  @override
  String get blueskyUsernameSyncPending =>
      'Divine ハンドルを取得しました。Bluesky と連携中です。少し待ってからもう一度お試しください。';

  @override
  String get blueskyStatusUnavailableRetry =>
      'Divine ハンドルを確認できませんでした。もう一度お試しください。';

  @override
  String get blueskySetUpHandle => '設定する';

  @override
  String get blueskyTemporarilyUnavailable =>
      'Bluesky への投稿は一時的に利用できません。もう一度お試しください。';

  @override
  String get invitesTitle => '友達を招待しよう';

  @override
  String invitesGenerateCardTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件の招待を作成できます',
    );
    return '$_temp0';
  }

  @override
  String get invitesGenerateCardSubtitle => '共有する準備ができたらコードを作成しましょう。';

  @override
  String get invitesGenerateButtonLabel => '招待を作成';

  @override
  String get invitesNoneAvailable => '今は使える招待がないよ';

  @override
  String get invitesShareWithPeople => 'Divine を周りの人にシェアしよう';

  @override
  String get invitesUsedInvites => '使用済みの招待';

  @override
  String invitesShareMessage(String code) {
    return 'Divine に参加しよう！招待コード $code で始められるよ:\nhttps://divine.video/invite/$code';
  }

  @override
  String get invitesCopyInvite => '招待をコピー';

  @override
  String get invitesCopied => '招待をコピーしたよ！';

  @override
  String get invitesShareInvite => '招待をシェア';

  @override
  String get invitesShareSubject => 'Divine に参加しよう';

  @override
  String get invitesClaimed => '受け取り済み';

  @override
  String get invitesCouldNotLoad => '招待の読み込みに失敗';

  @override
  String get invitesRetry => 'もう一回';

  @override
  String get searchSomethingWentWrong => 'なんかうまくいかなかった';

  @override
  String get searchTryAgain => 'もう一回';

  @override
  String get searchForLists => 'リストを検索';

  @override
  String get searchFindCuratedVideoLists => 'キュレーションされた動画リストを探そう';

  @override
  String get searchEnterQuery => '検索キーワードを入力';

  @override
  String get searchDiscoverSomethingInteresting => '面白いものを見つけよう';

  @override
  String get searchPeopleSectionHeader => 'ユーザー';

  @override
  String get searchPeopleLoadingLabel => 'ユーザーの検索結果を読み込み中';

  @override
  String get searchTagsSectionHeader => 'タグ';

  @override
  String get searchTagsLoadingLabel => 'タグの検索結果を読み込み中';

  @override
  String get searchVideosSectionHeader => '動画';

  @override
  String get searchVideosLoadingLabel => '動画の検索結果を読み込み中';

  @override
  String get searchVideosSortOptionsLabel => '動画の検索結果を並び替え';

  @override
  String get searchVideosSortTrending => '話題';

  @override
  String get searchVideosSortLoops => 'ループが多い順';

  @override
  String get searchVideosSortEngagement => '反応が多い順';

  @override
  String get searchVideosSortRecent => '新着';

  @override
  String get searchListsSectionHeader => 'リスト';

  @override
  String get searchListsLoadingLabel => 'リスト結果を読み込み中';

  @override
  String get cameraAgeRestriction => 'コンテンツを作るには16歳以上である必要があるよ';

  @override
  String get keyImportInsecureBunkerRelay =>
      'Bunker リレーは wss:// を使ってね (ws:// は localhost のみ可)';

  @override
  String get timeNow => '今';

  @override
  String timeShortMinutes(int count) {
    return '$count分';
  }

  @override
  String timeShortHours(int count) {
    return '$count時間';
  }

  @override
  String timeShortDays(int count) {
    return '$count日';
  }

  @override
  String timeShortWeeks(int count) {
    return '$count週';
  }

  @override
  String timeShortMonths(int count) {
    return '$countヶ月';
  }

  @override
  String timeShortYears(int count) {
    return '$count年';
  }

  @override
  String get timeVerboseNow => '今';

  @override
  String timeAgo(String time) {
    return '$time前';
  }

  @override
  String get timeToday => '今日';

  @override
  String get timeYesterday => '昨日';

  @override
  String get timeJustNow => 'たった今';

  @override
  String timeMinutesAgo(int count) {
    return '$count分前';
  }

  @override
  String timeHoursAgo(int count) {
    return '$count時間前';
  }

  @override
  String timeDaysAgo(int count) {
    return '$count日前';
  }

  @override
  String get draftTimeJustNow => 'たった今';

  @override
  String get contentLabelNudity => 'ヌード';

  @override
  String get contentLabelSexualContent => '性的な内容';

  @override
  String get contentLabelPornography => 'ポルノ';

  @override
  String get contentLabelGraphicMedia => '過激なメディア';

  @override
  String get contentLabelViolence => '暴力';

  @override
  String get contentLabelSelfHarm => '自傷行為/自殺';

  @override
  String get contentLabelDrugUse => '薬物使用';

  @override
  String get contentLabelAlcohol => 'アルコール';

  @override
  String get contentLabelTobacco => 'タバコ/喫煙';

  @override
  String get contentLabelGambling => 'ギャンブル';

  @override
  String get contentLabelProfanity => '不適切な言葉';

  @override
  String get contentLabelHateSpeech => 'ヘイトスピーチ';

  @override
  String get contentLabelHarassment => 'ハラスメント';

  @override
  String get contentLabelFlashingLights => '点滅する光';

  @override
  String get contentLabelAiGenerated => 'AI生成';

  @override
  String get contentLabelDeepfake => 'ディープフェイク';

  @override
  String get contentLabelSpam => 'スパム';

  @override
  String get contentLabelScam => '詐欺';

  @override
  String get contentLabelSpoiler => 'ネタバレ';

  @override
  String get contentLabelMisleading => '誤解を招く内容';

  @override
  String get contentLabelSensitiveContent => 'センシティブな内容';

  @override
  String notificationLikedYourVideo(String actorName) {
    return '$actorNameさんがあなたの動画にいいねしました';
  }

  @override
  String notificationLikedYourComment(String actorName) {
    return '$actorNameさんがあなたのコメントにいいねしました';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return '$actorNameさんがあなたの動画にコメントしました';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return '$actorNameさんがあなたをフォローしました';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return '$actorNameさんがあなたをメンションしました';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return '$actorNameさんがあなたの動画をリポストしました';
  }

  @override
  String notificationPostedNewVine(String actorName) {
    return '$actorNameが新しい動画を投稿しました';
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
      other: ' vine $count 件',
    );
    return '$actorName があなたの$_temp0を $listName に追加しました';
  }

  @override
  String notificationRepliedToYourComment(String actorName) {
    return '$actorNameさんがあなたのコメントに返信しました';
  }

  @override
  String get notificationAndConnector => 'と';

  @override
  String notificationOthersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '他$count人',
    );
    return '$_temp0';
  }

  @override
  String get notificationSystemUpdate => '新しいお知らせがあります';

  @override
  String get commentReplyToPrefix => 'Re:';

  @override
  String get commentHideKeyboard => 'キーボードを隠す';

  @override
  String get commentsErrorLoadFailed => 'コメントを読み込めませんでした';

  @override
  String get commentsErrorNotAuthenticatedComment => 'コメントするにはログインしてください';

  @override
  String get commentsErrorPostCommentFailed => 'コメントを投稿できませんでした';

  @override
  String get commentsErrorPostReplyFailed => '返信を投稿できませんでした';

  @override
  String get commentsErrorEditFailed => 'コメントを編集できませんでした';

  @override
  String get commentsErrorNotAuthenticatedInteract => '参加するにはログインしてください';

  @override
  String get commentsErrorVoteFailed => 'コメントへの投票に失敗しました';

  @override
  String get commentsErrorReportFailed => 'コメントを報告できませんでした';

  @override
  String get commentsErrorBlockFailed => 'ユーザーをブロックできませんでした';

  @override
  String get commentsErrorDeleteFailed => 'コメントを削除できませんでした';

  @override
  String commentsHeaderCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'コメント $count 件',
    );
    return '$_temp0';
  }

  @override
  String get commentsVideoReplyPending => '投稿中…';

  @override
  String get commentsVideoReplyPendingSemanticLabel => '動画返信を投稿しています';

  @override
  String get commentsSortNew => '新着';

  @override
  String get commentsSortTop => '人気';

  @override
  String get commentsSortOld => '古い順';

  @override
  String get commentsSortSemanticLabel => 'コメントの並び替え';

  @override
  String get commentReply => '返信';

  @override
  String get commentReplySemanticLabel => 'コメントに返信';

  @override
  String get commentUpvoteLabel => 'コメントに賛成票';

  @override
  String get commentRemoveUpvoteLabel => '賛成票を取り消す';

  @override
  String get commentDownvoteLabel => 'コメントに反対票';

  @override
  String get commentRemoveDownvoteLabel => '反対票を取り消す';

  @override
  String get commentsInputHint => 'コメントを追加...';

  @override
  String get commentsInputHintEdit => 'コメントを編集...';

  @override
  String get commentsEmptyTitle => 'まだコメントはありません';

  @override
  String get commentsEmptySubtitle => '最初のひとことをどうぞ！';

  @override
  String get draftUntitled => '無題';

  @override
  String get contentWarningNone => 'なし';

  @override
  String get textBackgroundNone => 'なし';

  @override
  String get textBackgroundSolid => '塗りつぶし';

  @override
  String get textBackgroundHighlight => 'ハイライト';

  @override
  String get textBackgroundTransparent => '透明';

  @override
  String get textAlignLeft => '左';

  @override
  String get textAlignRight => '右';

  @override
  String get textAlignCenter => '中央';

  @override
  String get cameraPermissionWebUnsupportedTitle => 'カメラはまだWebでサポートされていません';

  @override
  String get cameraPermissionWebUnsupportedDescription =>
      'カメラでの撮影と録画は、Web版ではまだ利用できません。';

  @override
  String get cameraPermissionBackToFeed => 'フィードに戻る';

  @override
  String get cameraCouldNotStart => 'カメラを起動できませんでした';

  @override
  String get cameraUnsupportedPlatform =>
      'このプラットフォームではカメラをまだ利用できません。\n動画の閲覧と視聴はできます。';

  @override
  String get cameraPermissionErrorTitle => '権限エラー';

  @override
  String get cameraPermissionErrorDescription => '権限の確認中に問題が発生しました。';

  @override
  String get cameraPermissionRetry => '再試行';

  @override
  String get cameraPermissionAllowAccessTitle => 'カメラとマイクへのアクセスを許可';

  @override
  String get cameraPermissionAllowAccessDescription =>
      'これにより、アプリ内で動画の撮影と編集ができるようになります。それ以外の用途はありません。';

  @override
  String get cameraPermissionGoToSettings => '設定に移動';

  @override
  String get videoRecorderWhySixSecondsTitle => 'なぜ6秒なの？';

  @override
  String get videoRecorderWhySixSecondsSubtitle =>
      '短いクリップは自発性のための空間を作ります。6秒フォーマットは起きた瞬間の本物の瞬間を捉えるのに役立ちます。';

  @override
  String get videoRecorderWhySixSecondsButton => 'わかりました！';

  @override
  String get videoRecorderUploadTitle => 'なぜアップロードできないの?';

  @override
  String get videoRecorderUploadBody =>
      'Divineで見るものは人間が作ったもの。生のまま、その瞬間に撮影されたものです。高度に加工された動画やAI生成のアップロードを許可するプラットフォームとは違い、私たちはカメラ直撮りの体験の本物らしさを優先します。';

  @override
  String get videoRecorderUploadBodyDetail =>
      '作成をアプリ内に留めることで、コンテンツが本物で未編集であることをより確実に保証できます。今のところ外部ギャラリーからのアップロードは開放していません。その本物らしさを守り、コミュニティを合成コンテンツからできる限り守るためです。';

  @override
  String get videoRecorderUploadBodyCta => '本物を撮るならCaptureかClassicに切り替えてね。';

  @override
  String get videoRecorderUploadLearnMore => '認証の仕組みを見る';

  @override
  String get videoRecorderAutosaveFoundTitle => '作業中のものが見つかりました';

  @override
  String get videoRecorderAutosaveFoundSubtitle => '続きから再開しますか？';

  @override
  String get videoRecorderAutosaveContinueButton => 'はい、続ける';

  @override
  String get videoRecorderAutosaveDiscardButton => 'いいえ、新しい動画を開始';

  @override
  String get videoRecorderAutosaveRestoreFailure => '下書きを復元できませんでした';

  @override
  String get videoRecorderStopRecordingTooltip => '録画を停止';

  @override
  String get videoRecorderStartRecordingTooltip => '録画を開始';

  @override
  String get videoRecorderRecordingTapToStopLabel => '録画中。どこかタップして停止';

  @override
  String get videoRecorderTapToStartLabel => 'どこかタップして録画を開始';

  @override
  String get videoRecorderDeleteLastClipLabel => '最後のクリップを削除';

  @override
  String get videoRecorderSwitchCameraLabel => 'カメラを切り替え';

  @override
  String videoRecorderZoomLevelLabel(String zoom) {
    return '$zoom× にズーム';
  }

  @override
  String get videoRecorderToggleGridLabel => 'グリッドを切り替え';

  @override
  String get videoRecorderToggleGhostFrameLabel => 'ゴーストフレームを切り替え';

  @override
  String get videoRecorderGhostFrameEnabled => 'ゴーストフレームを有効化';

  @override
  String get videoRecorderGhostFrameDisabled => 'ゴーストフレームを無効化';

  @override
  String get videoRecorderClipDeletedMessage => 'クリップをゴミ箱に移動しました';

  @override
  String get videoRecorderClipUndoLabel => '元に戻す';

  @override
  String get libraryTrashEmptyTitle => 'ゴミ箱は空です';

  @override
  String get libraryTrashEmptySubtitle => '削除されたクリップは30日間ここに保管され、その後完全に削除されます。';

  @override
  String get libraryTrashRestoreLabel => '復元';

  @override
  String get libraryTrashDeleteNowLabel => '今すぐ削除';

  @override
  String get libraryTrashEmptyAllLabel => 'ゴミ箱を空にする';

  @override
  String get libraryTrashDeleteConfirmTitle => '今すぐクリップを削除しますか？';

  @override
  String get libraryTrashDeleteConfirmMessage => 'これでクリップはゴミ箱からすぐに削除されます。';

  @override
  String get libraryTrashEmptyConfirmTitle => 'ゴミ箱を空にしますか？';

  @override
  String libraryTrashEmptyConfirmMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件のクリップ',
      one: '1件のクリップ',
    );
    return 'これでゴミ箱から$_temp0がすぐに完全に削除されます。';
  }

  @override
  String get videoRecorderCloseLabel => '動画レコーダーを閉じる';

  @override
  String get videoRecorderContinueToEditorLabel => '動画エディタへ進む';

  @override
  String get videoRecorderCameraPreviewLabel => 'カメラプレビュー';

  @override
  String get videoRecorderCameraPreviewFocusHint => 'カメラの焦点を合わせる';

  @override
  String videoRecorderSwitchToModeLabel(String mode) {
    return '$modeモードに切り替える';
  }

  @override
  String get videoRecorderLipSyncAddAudioFirst => '録画する前にオーディオを追加してください';

  @override
  String get videoRecorderStopMotionAssembleFailed =>
      '動画を作成できませんでした。もう一度お試しください。';

  @override
  String videoRecorderStopMotionShotsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '残り$count枚',
      zero: '残り0枚',
    );
    return '$_temp0';
  }

  @override
  String get videoRecorderToggleFlashLabel => 'フラッシュを切り替え';

  @override
  String get videoRecorderCycleTimerLabel => 'タイマーを切り替え';

  @override
  String get videoRecorderToggleAspectRatioLabel => 'アスペクト比を切り替え';

  @override
  String get videoRecorderStabilizationLabel => '手ぶれ補正';

  @override
  String get videoRecorderStabilizationModeOff => 'オフ';

  @override
  String get videoRecorderStabilizationModeStandard => '標準';

  @override
  String get videoRecorderStabilizationModeCinematic => 'シネマティック';

  @override
  String get videoRecorderStabilizationModeCinematicExtended => 'シネマティック拡張';

  @override
  String get videoRecorderStabilizationModePreviewOptimized => 'プレビュー最適化';

  @override
  String get videoRecorderStabilizationModeLowLatency => '低遅延';

  @override
  String get videoRecorderStabilizationModeAuto => '自動';

  @override
  String get videoRecorderFlashValueOff => 'オフ';

  @override
  String get videoRecorderFlashValueOn => 'オン';

  @override
  String get videoRecorderFlashValueAuto => '自動';

  @override
  String get videoRecorderTimerValueOff => 'オフ';

  @override
  String get videoRecorderTimerValueThreeSeconds => '3秒';

  @override
  String get videoRecorderTimerValueTenSeconds => '10秒';

  @override
  String get videoRecorderAspectRatioValueSquare => '正方形';

  @override
  String get videoRecorderAspectRatioValueVertical => '縦型';

  @override
  String get videoRecorderCameraValueFront => '前面カメラ';

  @override
  String get videoRecorderCameraValueBack => '背面カメラ';

  @override
  String get videoRecorderLibraryEmptyLabel => 'クリップライブラリ、クリップなし';

  @override
  String videoRecorderLibraryOpenLabel(int clipCount) {
    String _temp0 = intl.Intl.pluralLogic(
      clipCount,
      locale: localeName,
      other: 'クリップライブラリを開く、$clipCountクリップ',
    );
    return '$_temp0';
  }

  @override
  String videoRecorderLibraryOpenStopMotionLabel(int frameCount) {
    String _temp0 = intl.Intl.pluralLogic(
      frameCount,
      locale: localeName,
      other: 'ストップモーションライブラリを開く、$frameCountフレーム',
      zero: 'ストップモーションライブラリを開く',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorCameraLabel => 'カメラ';

  @override
  String get videoEditorOpenCameraSemanticLabel => 'カメラを開く';

  @override
  String get videoEditorLibraryLabel => 'ライブラリ';

  @override
  String get videoEditorTextLabel => 'テキスト';

  @override
  String get videoEditorDrawLabel => '描画';

  @override
  String get videoEditorFilterLabel => 'フィルター';

  @override
  String get videoEditorTuneLabel => '調整';

  @override
  String get videoEditorOpenTuneSemanticLabel => '調整エディターを開く';

  @override
  String get videoEditorTuneBrightness => '明るさ';

  @override
  String get videoEditorTuneContrast => 'コントラスト';

  @override
  String get videoEditorTuneSaturation => '彩度';

  @override
  String get videoEditorTuneExposure => '露出';

  @override
  String get videoEditorTuneHue => '色相';

  @override
  String get videoEditorTuneTemperature => '色温度';

  @override
  String get videoEditorTuneTint => '色かぶり';

  @override
  String get videoEditorTuneFade => 'フェード';

  @override
  String get videoEditorAudioLabel => 'オーディオ';

  @override
  String get videoEditorAddTitle => '追加';

  @override
  String get videoEditorOpenLibrarySemanticLabel => 'ライブラリを開く';

  @override
  String get videoEditorOpenAudioSemanticLabel => 'オーディオエディタを開く';

  @override
  String get videoEditorCaptionsLabel => '字幕';

  @override
  String get videoEditorOpenCaptionsSemanticLabel => '字幕エディタを開く';

  @override
  String get videoEditorCaptionsBurnInLabel => '動画に焼き込む';

  @override
  String get videoEditorCaptionsPresetCustom => 'カスタム';

  @override
  String get videoEditorCaptionsCustomStyleTitle => 'カスタムスタイル';

  @override
  String get videoEditorCaptionsCustomApply => '適用';

  @override
  String get videoEditorCaptionsCustomFont => 'フォント';

  @override
  String get videoEditorCaptionsCustomTextColor => '文字色';

  @override
  String get videoEditorCaptionsCustomBackground => '背景';

  @override
  String get videoEditorCaptionsCustomBackgroundColor => '背景色';

  @override
  String get videoEditorCaptionsCustomAnimation => 'アニメーション';

  @override
  String get videoEditorCaptionsAnimationNone => 'なし';

  @override
  String get videoEditorCaptionsAnimationFade => 'フェード';

  @override
  String get videoEditorCaptionsAnimationPop => 'ポップ';

  @override
  String get videoEditorCaptionsAnimationSpring => 'スプリング';

  @override
  String get videoEditorCaptionsEditTitle => '字幕';

  @override
  String get videoEditorCaptionsGeneratingTitle => '音声を聞き取っています…';

  @override
  String get videoEditorCaptionsGeneratingSubtitle => '音声から字幕の候補を作成しています。';

  @override
  String get videoEditorCaptionsNoSpeechMessage =>
      '音声が聞き取れませんでした。字幕は自分で書くこともできます。';

  @override
  String get videoEditorCaptionsUnavailableMessage =>
      'この端末では音声認識を利用できません。字幕は自分で書けます。';

  @override
  String get videoEditorCaptionsNotAuthorizedMessage =>
      '音声認識が許可されていません。設定で有効にするか、字幕を自分で書いてください。';

  @override
  String get videoEditorCaptionsFailedMessage =>
      '今回は文字起こしができませんでした。字幕は自分で書けます。';

  @override
  String get videoEditorCaptionsStartEmptyButton => '自分で字幕を書く';

  @override
  String get videoEditorCaptionsAddCue => '字幕を追加';

  @override
  String get videoEditorCaptionsCueTextHint => '字幕テキスト';

  @override
  String get videoEditorCaptionsCueDeleteSemanticLabel => '字幕を削除';

  @override
  String get videoEditorCaptionsDeleteTrack => 'すべての字幕を削除';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmTitle => '字幕を削除しますか?';

  @override
  String get videoEditorCaptionsDeleteTrackConfirmSubtitle =>
      'すべてのテキストとタイミングが失われます。';

  @override
  String get videoEditorCaptionsCloseSemanticLabel => '字幕エディタを閉じる';

  @override
  String get videoEditorCaptionsDoneSemanticLabel => '字幕を確定';

  @override
  String get videoEditorCaptionsPresetTitle => '字幕スタイル';

  @override
  String get videoEditorCaptionsPresetClassic => 'クラシック';

  @override
  String get videoEditorCaptionsPresetPop => 'ポップ';

  @override
  String get videoEditorCaptionsPresetZoom => 'Zoom';

  @override
  String get videoEditorCaptionsPresetSpring => 'スプリング';

  @override
  String get videoEditorCaptionsPresetMono => 'モノ';

  @override
  String get videoEditorCaptionsPresetHeadline => 'ヘッドライン';

  @override
  String get videoEditorCaptionsPresetTypewriter => 'タイプライター';

  @override
  String get videoEditorCaptionsPresetMarker => 'マーカー';

  @override
  String get videoEditorCaptionsPresetScript => 'カリグラフィー';

  @override
  String get videoEditorCaptionsPresetRetro => 'レトロ';

  @override
  String get videoEditorCaptionsPresetElegant => 'エレガント';

  @override
  String get videoEditorCaptionsPresetBubble => 'バブル';

  @override
  String get videoEditorCaptionsPresetNeon => 'ネオン';

  @override
  String get videoEditorCaptionsPresetBold => '太字';

  @override
  String get videoEditorCaptionsPresetDreamy => 'ドリーミー';

  @override
  String get videoEditorCaptionsPresetOcean => 'オーシャン';

  @override
  String get videoEditorCaptionsPresetSunny => 'サニー';

  @override
  String get videoEditorCaptionsPresetHandwritten => '手書き';

  @override
  String get videoEditorCaptionsPresetSerif => 'セリフ';

  @override
  String get videoEditorCaptionsPresetStamp => 'スタンプ';

  @override
  String get videoEditorOpenTextSemanticLabel => 'テキストエディタを開く';

  @override
  String get videoEditorOpenDrawSemanticLabel => '描画エディタを開く';

  @override
  String get videoEditorOpenFilterSemanticLabel => 'フィルターエディタを開く';

  @override
  String get videoEditorOpenStickerSemanticLabel => 'スタンプエディタを開く';

  @override
  String get videoEditorSaveDraftTitle => '下書きを保存しますか？';

  @override
  String get videoEditorSaveDraftSubtitle => '編集内容を後で保存するか、破棄してエディタを終了します。';

  @override
  String get videoEditorSaveDraftButton => '下書きを保存';

  @override
  String get videoEditorDiscardChangesButton => '変更を破棄';

  @override
  String get videoEditorKeepEditingButton => '編集を続ける';

  @override
  String get videoEditorDeleteLayerDropZone => 'レイヤー削除のドロップゾーン';

  @override
  String get videoEditorReleaseToDeleteLayer => '離してレイヤーを削除';

  @override
  String get videoEditorDoneLabel => '完了';

  @override
  String get videoEditorPlayPauseSemanticLabel => '動画を再生または一時停止';

  @override
  String videoEditorSplitPositionInvalid(int minDurationMs) {
    return '分割位置が無効です。各クリップは最低${minDurationMs}ms必要です。';
  }

  @override
  String get videoEditorSaveSelectedClip => '選択したクリップを保存';

  @override
  String get videoEditorSaveClip => 'クリップを保存';

  @override
  String get videoEditorClipSavedSuccess => 'クリップをライブラリに保存しました';

  @override
  String get videoEditorClipSaveFailed => 'クリップの保存に失敗しました';

  @override
  String get videoEditorColorPickerSemanticLabel => 'カラーピッカー';

  @override
  String get videoEditorUndoSemanticLabel => '元に戻す';

  @override
  String get videoEditorRedoSemanticLabel => 'やり直し';

  @override
  String get videoEditorTextColorSemanticLabel => 'テキストの色';

  @override
  String get videoEditorTextAlignmentSemanticLabel => 'テキストの配置';

  @override
  String get videoEditorTextBackgroundSemanticLabel => 'テキストの背景';

  @override
  String get videoEditorFontSemanticLabel => 'フォント';

  @override
  String get videoEditorNoStickersFound => 'ステッカーが見つかりません';

  @override
  String get videoEditorNoStickersAvailable => 'ステッカーがありません';

  @override
  String get videoEditorFailedLoadStickers => 'ステッカーの読み込みに失敗しました';

  @override
  String get videoEditorVoiceOverLabel => 'ナレーション';

  @override
  String videoEditorVoiceOverTakeName(int number) {
    return '録音 $number';
  }

  @override
  String get videoEditorOpenVoiceOverSemanticLabel => 'ナレーションを録音';

  @override
  String get videoEditorVoiceOverRecordSemanticLabel => '録音を開始';

  @override
  String get videoEditorVoiceOverStopSemanticLabel => '録音を停止';

  @override
  String get videoEditorVoiceOverHint => 'タップして録音。好きなだけテイクを追加できます。';

  @override
  String videoEditorVoiceOverRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '録音$count件',
      one: '録音1件',
      zero: 'まだ録音はありません',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorVoiceOverDeleteLast => '最後の録音を削除';

  @override
  String get videoEditorVoiceOverPermissionTitle => 'マイクへのアクセスが必要です';

  @override
  String get videoEditorVoiceOverPermissionBody =>
      'ナレーションを録音するにはマイクへのアクセスを許可してください。';

  @override
  String get videoEditorVoiceOverOpenSettings => '設定を開く';

  @override
  String get videoEditorVoiceOverRecordingStarted => '録音を開始しました';

  @override
  String get videoEditorVoiceOverRecordingSaved => '録音を保存しました';

  @override
  String get videoEditorVoiceOverTooLong => '録音が動画より長くなっています';

  @override
  String get videoEditorPlaySemanticLabel => '再生';

  @override
  String get videoEditorPauseSemanticLabel => '一時停止';

  @override
  String get videoEditorVolumeSemanticLabel => '音量を調整';

  @override
  String videoEditorTimelineVolumePreview(int percent) {
    return '音量 $percent%';
  }

  @override
  String get videoEditorTimelineSlideToAdjust => 'スライドして調整';

  @override
  String get videoEditorChromaKeyLabel => 'グリーンバック';

  @override
  String get videoEditorChromaKeyTitle => 'グリーンバック';

  @override
  String get videoEditorChromaKeySemanticLabel => 'このクリップのグリーンバックを設定';

  @override
  String get videoEditorChromaKeyCloseSemanticLabel => 'グリーンバックの変更を破棄';

  @override
  String get videoEditorChromaKeyDoneSemanticLabel => 'グリーンバックを適用';

  @override
  String get videoEditorChromaKeyAutoDetect => '自動検出';

  @override
  String get videoEditorChromaKeyPresetGreen => 'グリーン';

  @override
  String get videoEditorChromaKeyPresetBlue => 'ブルー';

  @override
  String get videoEditorChromaKeyScreenColorLabel => '背景の色';

  @override
  String get videoEditorChromaKeyAmountLabel => '強さ';

  @override
  String get videoEditorChromaKeyAmountHint => '背景の色をどれだけ消すか';

  @override
  String get videoEditorChromaKeyEdgeLabel => 'エッジ';

  @override
  String get videoEditorChromaKeyEdgeHint => '切り抜きをなめらかにして髪のギザつきを防ぎます';

  @override
  String get videoEditorChromaKeySpillLabel => '色かぶり';

  @override
  String get videoEditorChromaKeySpillHint => '背景の色みを被写体から取り除きます';

  @override
  String get videoEditorChromaKeyBackgroundLabel => '置き換える';

  @override
  String get videoEditorChromaKeyBackgroundNone => 'なし';

  @override
  String get videoEditorChromaKeyBackgroundColor => '色';

  @override
  String get videoEditorChromaKeyBackgroundImage => '画像';

  @override
  String get videoEditorChromaKeyBackgroundVideo => 'クリップ';

  @override
  String get videoEditorChromaKeyTransparentHint =>
      '動画は透明を保持できないため、書き出すと黒くなります。';

  @override
  String get videoEditorChromaKeyDetectFailed =>
      '背景が見つかりませんでした。画面の端まで届いている必要があります。届いていない場合は手動で色を選んでください。';

  @override
  String get videoEditorChromaKeyPickClipTitle => 'クリップを選ぶ';

  @override
  String get videoEditorChromaKeyNoLibraryClips =>
      'ライブラリが空です。先にクリップを保存すると、背景として使えます。';

  @override
  String get videoEditorChromaKeyImagePickFailed => 'その画像を読み込めませんでした。';

  @override
  String get videoEditorChromaKeyRemove => 'グリーンバックを削除';

  @override
  String get videoEditorChromaKeyFailed => 'グリーンバックを適用できませんでした。クリップは変更されていません。';

  @override
  String get videoEditorChromaKeyRemoveFailed =>
      'グリーンバックを削除できませんでした。クリップは変更されていません。';

  @override
  String get videoEditorChromaKeyApplying => 'グリーンバックを適用しています…';

  @override
  String get videoEditorChromaKeyPreviewUnavailable =>
      'この端末ではライブプレビューを表示できません。設定は書き出し時にきちんと反映されます。';

  @override
  String videoEditorClipVolumeLabel(int index) {
    return 'クリップ $index';
  }

  @override
  String get videoEditorDeleteLabel => '削除';

  @override
  String get videoEditorDeleteSelectedItemSemanticLabel => '選択したアイテムを削除';

  @override
  String get videoEditorStopMotionFramesPerImageLabel => '1枚あたりのフレーム数';

  @override
  String videoEditorStopMotionFramesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countフレーム',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorStopMotionFramesPerImageButtonLabel => 'フレーム';

  @override
  String videoEditorStopMotionFramesPerImageValueSemanticLabel(int count) {
    return '1枚あたり$countフレーム';
  }

  @override
  String videoEditorStopMotionFrameSemanticLabel(int position, int total) {
    return 'ストップモーションのフレーム $total枚中$position枚目';
  }

  @override
  String get videoEditorEditLabel => '編集';

  @override
  String get videoEditorEditSelectedItemSemanticLabel => '選択したアイテムを編集';

  @override
  String get videoEditorDuplicateLabel => '複製';

  @override
  String get videoEditorDuplicateSelectedItemSemanticLabel => '選択したアイテムを複製';

  @override
  String get videoEditorCombineLabel => '結合';

  @override
  String get videoEditorCombineDrawLayersSemanticLabel => '選択した描画を1つのレイヤーに結合';

  @override
  String get videoEditorSplitLabel => '分割';

  @override
  String get videoEditorSplitSelectedClipSemanticLabel => '選択したクリップを分割';

  @override
  String get videoEditorExtractAudioLabel => '音声を抽出';

  @override
  String get videoEditorClipAudioTitle => 'クリップ音声';

  @override
  String get videoEditorExtractAudioFromClipSemanticLabel =>
      'クリップから音声を抽出してオリジナルをミュート';

  @override
  String get videoEditorExtractAudioNoLocalFile =>
      '音声を抽出できません：クリップがローカルで利用できません。';

  @override
  String get videoEditorExtractAudioFailed => '音声を抽出できませんでした。もう一度お試しください。';

  @override
  String get videoEditorSpeedLabel => '速度';

  @override
  String get videoEditorSetClipSpeedSemanticLabel => '選択したクリップの再生速度を設定';

  @override
  String get videoEditorReverseLabel => '逆再生';

  @override
  String get videoEditorReverseClipSemanticLabel => '選択したクリップの逆再生を切り替え';

  @override
  String get videoEditorReverseProgressLabel => '少々お待ちください。クリップを逆再生用に処理しています';

  @override
  String get videoEditorTransformLabel => '変形';

  @override
  String get videoEditorTransformSelectedClipSemanticLabel =>
      '選択したクリップをトリミング、回転、または反転';

  @override
  String get videoEditorTransformProgressLabel => 'クリップを変形しています。少々お待ちください';

  @override
  String get videoEditorTransformFailed => 'クリップを変形できませんでした。もう一度お試しください。';

  @override
  String get videoEditorTransformNoLocalFile => '変形できません：クリップがローカルに利用できません。';

  @override
  String get videoEditorTransformSelectedFrameSemanticLabel =>
      '選択したフレームをトリミング、回転、反転';

  @override
  String get videoEditorTransformFrameProgressLabel => '少々お待ちください。フレームを変換しています';

  @override
  String get videoEditorTransformFrameFailed => 'フレームを変換できませんでした。もう一度お試しください。';

  @override
  String get videoEditorTransformRotateLabel => '回転';

  @override
  String get videoEditorTransformFlipLabel => '反転';

  @override
  String get videoEditorTransformResetLabel => 'リセット';

  @override
  String get videoEditorTransformApplySemanticLabel => '変形を適用';

  @override
  String get videoEditorTransformCancelSemanticLabel => '変形をキャンセル';

  @override
  String get videoEditorTransformPlayLabel => '再生';

  @override
  String get videoEditorTransformPauseLabel => '一時停止';

  @override
  String get videoEditorReverseNoLocalFile => '逆再生できません：クリップがローカルで利用できません。';

  @override
  String get videoEditorReverseFailed => 'クリップを逆再生できませんでした。もう一度お試しください。';

  @override
  String get videoEditorSpeedSheetTitle => 'クリップの速度';

  @override
  String get videoEditorTransitionSheetTitle => 'トランジション';

  @override
  String get videoEditorTransitionNone => 'なし';

  @override
  String get videoEditorTransitionDissolve => 'ディゾルブ';

  @override
  String get videoEditorTransitionFadeToBlack => '黒にフェード';

  @override
  String get videoEditorTransitionFadeToWhite => '白にフェード';

  @override
  String get videoEditorTransitionSlide => 'スライド';

  @override
  String get videoEditorTransitionPush => 'プッシュ';

  @override
  String get videoEditorTransitionWipe => 'ワイプ';

  @override
  String get videoEditorTransitionButtonSemanticLabel => 'トランジションを編集';

  @override
  String get videoEditorLoopTransitionSheetTitle => 'ループトランジション';

  @override
  String get videoEditorLoopTransitionButtonSemanticLabel => 'ループトランジションを編集';

  @override
  String get videoEditorTransitionDuration => '長さ';

  @override
  String get videoEditorTransitionDurationLimitedHint =>
      '隣接するトランジションと重ならないように短縮されました。';

  @override
  String get videoEditorTransitionCurve => 'カーブ';

  @override
  String get videoEditorTransitionDirection => '方向';

  @override
  String get videoEditorTransitionDirectionLeft => '左';

  @override
  String get videoEditorTransitionDirectionRight => '右';

  @override
  String get videoEditorTransitionDirectionUp => '上';

  @override
  String get videoEditorTransitionDirectionDown => '下';

  @override
  String videoEditorTransitionCurveOptionSemanticLabel(int number) {
    return 'アニメーションカーブ $number';
  }

  @override
  String get videoEditorLayerAnimationLabel => 'アニメーション';

  @override
  String get videoEditorLayerAnimationButtonSemanticLabel => 'レイヤーアニメーションを編集';

  @override
  String get videoEditorLayerAnimationEnter => 'イン';

  @override
  String get videoEditorLayerAnimationLeave => 'アウト';

  @override
  String get videoEditorLayerAnimationFade => 'フェード';

  @override
  String get videoEditorLayerAnimationScale => 'スケール';

  @override
  String get videoEditorLayerAnimationScaleFrom => '開始スケール';

  @override
  String get videoEditorFinishTimelineEditingSemanticLabel => 'タイムライン編集を終了';

  @override
  String get videoEditorAudioPlayPreviewSemanticLabel => 'プレビューを再生';

  @override
  String get videoEditorAudioPausePreviewSemanticLabel => 'プレビューを一時停止';

  @override
  String get videoEditorAudioUntitledSound => 'タイトルなしのサウンド';

  @override
  String get videoEditorAudioUntitled => 'タイトルなし';

  @override
  String get videoEditorAudioAddAudio => 'オーディオを追加';

  @override
  String get videoEditorAudioNoSoundsAvailableTitle => '利用可能なサウンドなし';

  @override
  String get videoEditorAudioNoSoundsAvailableSubtitle =>
      'クリエイターがオーディオを共有するとここに表示されます';

  @override
  String get videoEditorAudioFailedToLoadTitle => 'サウンドの読み込みに失敗';

  @override
  String get videoEditorAudioSegmentInstruction => '動画に使うオーディオ範囲を選択';

  @override
  String get videoEditorAudioCategoryDivine => 'Divine';

  @override
  String get videoEditorAudioCategoryCommunity => 'コミュニティ';

  @override
  String get videoEditorAudioCategoryFeatured => 'おすすめ';

  @override
  String get videoEditorAudioCategoryMySounds => 'マイサウンド';

  @override
  String get videoEditorDrawToolArrowSemanticLabel => '矢印ツール';

  @override
  String get videoEditorDrawToolEraserSemanticLabel => '消しゴムツール';

  @override
  String get videoEditorDrawToolMarkerSemanticLabel => 'マーカーツール';

  @override
  String get videoEditorDrawToolPencilSemanticLabel => '鉛筆ツール';

  @override
  String get videoEditorShowTimelineSemanticLabel => 'タイムラインを表示';

  @override
  String get videoEditorHideTimelineSemanticLabel => 'タイムラインを非表示';

  @override
  String get videoEditorFeedPreviewContent => 'これらのエリアの後ろにコンテンツを配置しないでください。';

  @override
  String get videoEditorStickersDivineOriginals => 'Divine オリジナル';

  @override
  String get videoEditorStickerSearchHint => 'ステッカーを検索...';

  @override
  String get videoEditorSelectFontSemanticLabel => 'フォントを選択';

  @override
  String get videoEditorFontUnknown => '不明';

  @override
  String get videoEditorSplitPlayheadOutsideClip =>
      '分割するには再生ヘッドを選択したクリップ内に置いてください。';

  @override
  String get videoEditorTimelineTrimStartSemanticLabel => '始端をトリム';

  @override
  String get videoEditorTimelineTrimEndSemanticLabel => '終端をトリム';

  @override
  String get videoEditorTimelineTrimClipSemanticLabel => 'クリップをトリム';

  @override
  String get videoEditorTimelineTrimClipHint => 'ハンドルをドラッグしてクリップの長さを調整';

  @override
  String videoEditorTimelineDraggingClipSemanticLabel(int index) {
    return 'クリップ$indexをドラッグ中';
  }

  @override
  String videoEditorTimelineClipSemanticLabel(
    int index,
    int total,
    String duration,
  ) {
    return '$total個中$index番目のクリップ、$duration秒';
  }

  @override
  String get videoEditorTimelineClipReorderHint => '長押しして並べ替え';

  @override
  String get videoEditorTimelineClipMoveLeft => '左に移動';

  @override
  String get videoEditorTimelineClipMoveRight => '右に移動';

  @override
  String videoEditorTimelineClipSelectedSemanticLabel(int index, int total) {
    return 'クリップ $index/$total、選択中';
  }

  @override
  String videoEditorTimelineClipUnselectedSemanticLabel(int index, int total) {
    return 'クリップ $index/$total、未選択';
  }

  @override
  String get videoEditorMultiSelectLabel => '選択';

  @override
  String get videoEditorMultiSelectSemanticLabel => '複数のクリップを選択';

  @override
  String get videoEditorMultiSelectDoneSemanticLabel => '選択を完了';

  @override
  String videoEditorMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件のクリップを選択中',
      one: '1 件のクリップを選択中',
      zero: 'クリップが選択されていません',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorLayerMultiSelectSemanticLabel => '複数の描画を選択';

  @override
  String get videoEditorLayerMultiSelectDoneSemanticLabel => '描画の選択を完了';

  @override
  String get videoEditorDeleteSelectedDrawingsSemanticLabel => '選択した描画を削除';

  @override
  String videoEditorLayerMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件の描画を選択中',
      one: '1件の描画を選択中',
      zero: '描画が選択されていません',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorMergeLabel => '結合';

  @override
  String get videoEditorMergeSelectedClipsSemanticLabel => '選択したクリップを結合';

  @override
  String get videoEditorDeleteSelectedClipsSemanticLabel => '選択したクリップを削除';

  @override
  String get videoEditorDeleteSelectedFramesSemanticLabel => '選択したフレームを削除';

  @override
  String get videoEditorReverseSelectedFramesSemanticLabel => '選択したフレームを逆順にする';

  @override
  String get videoEditorDuplicateSelectedFramesSemanticLabel => '選択したフレームを複製';

  @override
  String videoEditorStopMotionTooShortSnackbar(int seconds) {
    return '動画は$seconds秒以上必要です。もう少しフレームを撮影してください。';
  }

  @override
  String get videoEditorMergeProgressLabel => '少々お待ちください。クリップを結合しています';

  @override
  String get videoEditorMergeFailed => 'クリップを結合できませんでした。もう一度お試しください。';

  @override
  String get videoEditorTimelineLongPressToDragHint => '長押しでドラッグ';

  @override
  String get videoEditorVideoTimelineSemanticLabel => '動画タイムライン';

  @override
  String videoEditorTimelinePositionFormat(int minutes, String seconds) {
    return '$minutes分$seconds秒';
  }

  @override
  String videoEditorColorSelectedSemanticLabel(String colorName) {
    return '$colorName、選択済み';
  }

  @override
  String get videoEditorCloseColorPickerSemanticLabel => 'カラーピッカーを閉じる';

  @override
  String get videoEditorPickColorTitle => '色を選択';

  @override
  String get videoEditorConfirmColorSemanticLabel => '色を確定';

  @override
  String get videoEditorSaturationBrightnessSemanticLabel => '彩度と明度';

  @override
  String videoEditorSaturationBrightnessValue(int saturation, int brightness) {
    return '彩度 $saturation%、明度 $brightness%';
  }

  @override
  String get videoEditorHueSemanticLabel => '色相';

  @override
  String get videoEditorAddElementSemanticLabel => '要素を追加';

  @override
  String get videoEditorDoneSemanticLabel => '完了';

  @override
  String get videoEditorLevelSemanticLabel => 'レベル';

  @override
  String get videoMetadataClosePostDetailsSemanticLabel => '投稿の詳細を閉じる';

  @override
  String get videoMetadataDismissHelpDialogSemanticLabel => 'ヘルプダイアログを閉じる';

  @override
  String get videoMetadataGotItButton => 'わかりました！';

  @override
  String get videoMetadataLimitReachedWarning =>
      '64KBの上限に達しました。続けるにはコンテンツを削除してください。';

  @override
  String get videoMetadataExpirationLabel => '有効期限';

  @override
  String get videoMetadataSelectExpirationSemanticLabel => '有効期限を選択';

  @override
  String get videoMetadataTitleLabel => 'タイトル';

  @override
  String get videoMetadataDescriptionLabel => '説明';

  @override
  String get videoMetadataTagsLabel => 'タグ';

  @override
  String videoMetadataDeleteTagHint(String tag) {
    return 'タグ$tagを削除';
  }

  @override
  String get videoMetadataContentWarningLabel => 'コンテンツ警告';

  @override
  String get videoMetadataSelectContentWarningsSemanticLabel => 'コンテンツ警告を選択';

  @override
  String get videoMetadataContentWarningSelectAllThatApply =>
      'コンテンツに該当するものをすべて選択';

  @override
  String get videoMetadataAudioReuseSubtitle =>
      '他のユーザーがこの動画の音声を保存して再利用できるようにします。';

  @override
  String get publishAudioReuseDegradedWarning =>
      '動画は公開されましたが、サウンドは公開されませんでした。共有するには動画を編集してください。';

  @override
  String get videoMetadataCollaboratorsLabel => 'コラボレーター';

  @override
  String get videoMetadataAddCollaboratorSemanticLabel => 'コラボレーターを追加';

  @override
  String get videoMetadataMutualFollowersSearchText => '相互フォロワー';

  @override
  String get videoMetadataInspiredByLabel => 'インスパイア元';

  @override
  String get videoMetadataSetInspiredBySemanticLabel => 'インスパイア元を設定';

  @override
  String get videoMetadataCreatorCannotBeReferencedSnackbar =>
      'このクリエイターは参照できません。';

  @override
  String get videoMetadataPostDetailsTitle => '投稿の詳細';

  @override
  String get videoMetadataSavedToLibrarySnackbar => 'ライブラリに保存しました';

  @override
  String get videoMetadataFailedToSaveSnackbar => '保存に失敗しました';

  @override
  String get videoMetadataGoToLibraryButton => 'ライブラリへ';

  @override
  String get videoMetadataSaveForLaterSemanticLabel => '後で保存ボタン';

  @override
  String get videoMetadataSavingVideoHint => '動画を保存中...';

  @override
  String videoMetadataSaveToDraftsHint(String destination) {
    return '動画を下書きと$destinationに保存';
  }

  @override
  String videoMetadataSaveToDraftsWithoutGalleryHint(String destination) {
    return '動画を下書きに保存します。レンダリング済みの動画がまだないため、$destinationにはコピーされません。';
  }

  @override
  String get videoMetadataSaveForLaterButton => '後で保存';

  @override
  String get videoMetadataPostSemanticLabel => '投稿ボタン';

  @override
  String get videoMetadataPublishVideoHint => 'フィードに動画を公開';

  @override
  String get videoMetadataShareReplyToFeedTitle => '自分のフィードにも共有';

  @override
  String get videoMetadataShareReplyToFeedSubtitle =>
      'オフにすると、この動画はコメントスレッド内にのみ表示されます。';

  @override
  String get videoMetadataFormNotReadyHint => '有効にするにはフォームを入力してください';

  @override
  String get videoMetadataPostButton => '投稿';

  @override
  String get videoMetadataOpenPreviewSemanticLabel => '投稿プレビュー画面を開く';

  @override
  String get videoMetadataShareTitle => 'シェア';

  @override
  String get videoMetadataVideoDetailsSubtitle => '動画の詳細';

  @override
  String get videoMetadataClassicDoneButton => '完了';

  @override
  String get videoMetadataPlayPreviewSemanticLabel => 'プレビューを再生';

  @override
  String get videoMetadataPausePreviewSemanticLabel => 'プレビューを一時停止';

  @override
  String get videoMetadataClosePreviewSemanticLabel => '動画プレビューを閉じる';

  @override
  String get videoMetadataRemoveSemanticLabel => '削除';

  @override
  String get fullscreenFeedRemovedMessage => '動画を削除しました';

  @override
  String get fullscreenFeedEmptyMessage => 'ここに再生できる動画はもうありません';

  @override
  String get settingsBadgesTitle => 'バッジ';

  @override
  String get settingsBadgesSubtitle => '受賞を承認したり、発行したバッジの状態を確認できるよ。';

  @override
  String get badgesTitle => 'バッジ';

  @override
  String get badgesLoadError => 'バッジの読み込みに失敗';

  @override
  String get badgesUpdateError => 'バッジの更新に失敗';

  @override
  String get badgesAwardedEmptyTitle => 'バッジの受賞はまだないよ';

  @override
  String get badgesAwardedEmptySubtitle => '誰かが Nostr バッジを贈ってくれたら、ここに届くよ。';

  @override
  String get badgesStatusAccepted => '承認済み';

  @override
  String get badgesStatusNotAccepted => '未承認';

  @override
  String get badgesActionRemove => '削除';

  @override
  String get badgesActionAccept => '承認';

  @override
  String get badgesActionReject => '拒否';

  @override
  String get badgesIssuedEmptyTitle => '発行したバッジはまだないよ';

  @override
  String get badgesIssuedEmptySubtitle => 'あなたが発行したバッジの承認状況がここに出るよ。';

  @override
  String get badgesIssuedNoRecipients => 'この受賞には受信者が見つからないよ。';

  @override
  String get badgesRecipientAcceptedStatus => '受信者が承認';

  @override
  String get badgesRecipientWaitingStatus => '受信者の承認待ち';

  @override
  String badgesHiddenSectionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '非表示（$count）',
    );
    return '$_temp0';
  }

  @override
  String get badgesActionRestore => '元に戻す';

  @override
  String get badgesHiddenSnackbar => 'バッジを非表示にしました';

  @override
  String get badgesHiddenSnackbarUndo => '取り消す';

  @override
  String get badgesTabAwarded => 'もらった';

  @override
  String get badgesTabCreated => 'つくった';

  @override
  String get badgesTabIssued => '贈った';

  @override
  String get badgesCreateAction => 'バッジを作る';

  @override
  String get badgesCreatedEmptyTitle => 'まだバッジを作っていません';

  @override
  String get badgesCreatedEmptySubtitle => 'ひとつ作って、ふさわしい人に贈りましょう。';

  @override
  String badgesCreatedAwardSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count人に贈りました',
      zero: 'まだ誰にも贈っていません',
    );
    return '$_temp0';
  }

  @override
  String get badgeEditorCreateTitle => 'バッジを作る';

  @override
  String get badgeEditorEditTitle => 'バッジを編集';

  @override
  String get badgeEditorNameLabel => '名前';

  @override
  String get badgeEditorNameHint => 'シーンを奪う人';

  @override
  String get badgeEditorIdentifierLabel => '識別子';

  @override
  String get badgeEditorIdentifierHelp => 'バッジのアドレスの一部なので、作成後は変更できません。';

  @override
  String get badgeEditorIdentifierTaken =>
      'この識別子のバッジはすでにあります。ここで公開すると置き換わるので、そちらを編集してください。';

  @override
  String get badgeEditorIdentifierRequired =>
      'バッジには識別子が必要です。名前から入らなかったときは自分で入力してください。';

  @override
  String get badgeEditorDescriptionLabel => '説明';

  @override
  String get badgeEditorDescriptionHint => 'たった1本のループで場をさらった人へ。';

  @override
  String get badgeEditorArtworkLabel => '画像';

  @override
  String get badgeEditorArtworkAdd => '画像を追加';

  @override
  String get badgeEditorArtworkReplace => '差し替え';

  @override
  String get badgeEditorArtworkError => 'その画像をアップロードできませんでした';

  @override
  String get badgeEditorArtworkRequired => 'バッジには必ず画像が必要です。';

  @override
  String get badgeEditorArtworkRemove => '画像を削除';

  @override
  String get badgeEditorArtworkSheetTitle => 'バッジの画像';

  @override
  String get badgeDetailDeleteAction => 'バッジを削除';

  @override
  String get badgeDetailDeleteTitle => 'このバッジを削除しますか？';

  @override
  String get badgeDetailDeleteBody =>
      'リレーにバッジと、あなたが贈ったすべての授与の削除を依頼します。リレーは拒否できますし、プロフィールに固定した人は自分で外すまで表示されたままです。';

  @override
  String get badgeDetailDeleteConfirm => '削除';

  @override
  String get badgeEditorSaveAction => 'バッジを公開';

  @override
  String get badgeEditorSaveError => 'バッジを公開できませんでした';

  @override
  String get badgeEditorLoadError => 'このバッジを読み込めませんでした';

  @override
  String get badgeDetailTitle => 'バッジ';

  @override
  String get badgeDetailMadeBy => '作った人';

  @override
  String get badgeDetailRecipientsTitle => '贈った相手';

  @override
  String get badgeDetailNoRecipients => 'まだ誰も持っていません。';

  @override
  String get badgeDetailAwardAction => 'このバッジを贈る';

  @override
  String get badgeDetailEditAction => 'バッジを編集';

  @override
  String get badgeDetailShareAction => 'シェア';

  @override
  String badgeDetailShareMessage(String link) {
    return 'Divine でこのバッジを見てみて: $link';
  }

  @override
  String get badgeDetailRevokeAction => 'バッジを取り消す';

  @override
  String get badgeDetailRevokeTitle => 'このバッジを取り消しますか？';

  @override
  String get badgeDetailRevokeBody =>
      'この人に贈った授与の削除をリレーに依頼します。リレーは拒否できますし、すでにプロフィールに固定されている場合は本人が外すまで残ります。いずれにしても通知はされません。';

  @override
  String get badgeDetailRevokeSelfBody =>
      '自分に贈った授与の削除をリレーに依頼し、バッジをあなたのプロフィールから外します。リレーが削除を拒否した場合は、何も変わりません。';

  @override
  String get badgeDetailRevokeConfirm => '取り消す';

  @override
  String get badgeDetailRevokeSuccess => 'バッジを取り消しました';

  @override
  String get badgeDetailBlockClaimantsAction => 'バッジの申請者をブロック';

  @override
  String get badgeDetailBlockClaimantsTitle => 'バッジの申請者をブロック';

  @override
  String get badgeDetailBlockClaimantsLoadError => 'このバッジの申請者を読み込めませんでした';

  @override
  String get badgeDetailBlockClaimantsEmptyTitle => '今このバッジを申請している人はいません';

  @override
  String get badgeDetailBlockClaimantsEmptyBody => 'ブロックできる現在の申請者は見つかりませんでした。';

  @override
  String badgeDetailBlockClaimantsHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count人をブロックしますか？',
      one: '1人をブロックしますか？',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'このバッジを今申請している$count件のアカウントをブロックします。投稿はあなたのフィードから消え、相手に通知は届きません。',
      one: 'このバッジを今申請しているアカウントをブロックします。投稿はあなたのフィードから消え、相手に通知は届きません。',
    );
    return '$_temp0';
  }

  @override
  String badgeDetailBlockClaimantsConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件のアカウントをブロック',
      one: '1件のアカウントをブロック',
    );
    return '$_temp0';
  }

  @override
  String get badgeDetailBlockClaimantsSuccess => 'バッジ申請者をブロックしました';

  @override
  String get badgeDetailBlockClaimantsFailure => 'バッジ申請者をブロックできませんでした';

  @override
  String get badgeDetailLoadError => 'このバッジを読み込めませんでした';

  @override
  String get badgeDetailMissing => 'どのリレーにもこのバッジが見つかりません。';

  @override
  String get badgeDetailActionError => 'うまくいきませんでした';

  @override
  String get badgeAwardTitle => 'バッジを贈る';

  @override
  String get badgeAwardPickAction => '人を選ぶ';

  @override
  String get badgeAwardManualLabel => 'または鍵を貼り付け';

  @override
  String get badgeAwardManualHint => 'npub1…, npub1…';

  @override
  String get badgeAwardEmptyHint => '少なくとも1人を選んでください。';

  @override
  String badgeAwardSubmitAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count人に贈る',
      zero: 'バッジを贈る',
    );
    return '$_temp0';
  }

  @override
  String get profileBadgeAwardedBy => '贈った人';

  @override
  String get profileBadgeRecipients => '受け取った人';

  @override
  String profileBadgeMoreRecipients(int count) {
    return '他 $count 人';
  }

  @override
  String profileBadgeSemanticLabel(String name) {
    return '$name バッジ';
  }

  @override
  String get profileBadgeFallbackSemanticLabel => 'バッジ';

  @override
  String get profileBadgeFooterBody =>
      'バッジは Nostr で誰でも作れる小さな賞。友だちやクリエイター、今日をいい日にしてくれた人に贈ってみて。';

  @override
  String get profileBadgeFooterLink => '自分のバッジを作る';

  @override
  String get minorAccountReviewWelcomePageTitle => 'ファミリーガイド';

  @override
  String get minorAccountReviewWelcomeTitle => 'まだ16歳じゃない？大丈夫。';

  @override
  String get minorAccountReviewWelcomeBody =>
      '入れる答えを選ぶんじゃなくて、このページまで来てくれたこと。それって大事なことだよ。誠実さと芯の強さ、そして周りの人への本当の思いやりが表れてる。\n\n16歳未満の人に関するルールは、住んでいる場所によって違うんだ。Divine では、家族で一緒に話し合って、健全なソーシャルメディアの使い方って何かを決めてほしいと思ってるよ。';

  @override
  String get minorAccountReviewModerationTitle => 'もう一歩だけ必要です';

  @override
  String get minorAccountReviewModerationBody =>
      'このアカウントは16歳未満の方のものである可能性があるため、詳しく確認するよう依頼がありました。この手順では次のステップを非公開に保ち、あなたの年齢に合った道筋を案内します。';

  @override
  String get minorAccountReviewRulesTitle => 'ルールは場所によって違います';

  @override
  String get minorAccountReviewRulesBody =>
      '国や地域によって、10代のソーシャルメディア利用の扱いは異なります。だからこそ、ご家族には少し立ち止まって事実を確認し、次のステップを一緒に選んでほしいのです。';

  @override
  String get minorAccountReviewApproachTitle => 'Divine の考え方';

  @override
  String get minorAccountReviewApproachBody =>
      '健全なテクノロジーとの付き合い方は、立ち止まり、振り返り、より良いものへ注意を向け直すことから生まれると考えています。子どもを監視したり、親を見張り役にしたりすることからではありません。研究もそれを裏づけています。';

  @override
  String get minorAccountReviewLearnMoreTitle => 'ご家族向けの情報';

  @override
  String get minorAccountReviewKidsPolicyCta => 'Divine の子ども向けポリシーを読む';

  @override
  String get minorAccountReviewChooseAgeBandTitle => '合う道を選んでください';

  @override
  String get minorAccountReviewUnder13Cta => '13歳未満';

  @override
  String get minorAccountReviewTeenCta => '13〜15歳';

  @override
  String get minorAccountReviewFamilyResourcesBody =>
      '10代がソーシャルメディアをより安全に使えるようにする実践的なヒント、会話のためのツール、資料は Divine ファミリーガイドをご覧ください。';

  @override
  String get minorAccountReviewFamilyResourcesCta => 'ファミリーガイドとヒントを見る';

  @override
  String get minorAccountReviewFooter =>
      '16歳以上なのに間違ってここに来てしまった場合は、Divine サポートにご連絡ください。担当者が確認します。';

  @override
  String get minorAccountReviewTitle => 'アカウント審査';

  @override
  String get minorAccountReviewCheckingStatusTitle => 'アカウントの状態を確認中...';

  @override
  String get minorAccountReviewCheckingStatusBody =>
      'このアカウントの現在の審査状況を確認しています。少々お待ちください。';

  @override
  String get minorAccountReviewDefaultTitle => 'アカウント審査が必要です';

  @override
  String get minorAccountReviewDefaultBody =>
      'このアカウントが Divine を通常どおり使えるようになる前に、審査が必要です。';

  @override
  String minorAccountReviewCaseId(String caseId) {
    return 'ケース ID: $caseId';
  }

  @override
  String get minorAccountReviewCaseIdShortLabel => 'ケース ID';

  @override
  String get minorAccountReviewRestrictionsTitle => '現在制限されていること';

  @override
  String get minorAccountReviewRestrictionPosting => '投稿と公開は停止中です';

  @override
  String get minorAccountReviewRestrictionEngagement =>
      'コメント、いいね、リポスト、フォローは停止中です';

  @override
  String get minorAccountReviewRestrictionMessaging => '通常のメッセージの送信と返信は停止中です';

  @override
  String get minorAccountReviewRestrictionSupport =>
      'サポートとモデレーションメッセージは引き続き利用できます';

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
  String get minorAccountReviewOpenSupportCenter => 'サポートセンターを開く';

  @override
  String get minorAccountReviewOpenModerationMessage => 'モデレーションメッセージを開く';

  @override
  String get minorAccountReviewOpenReviewPage => '審査ページを開く';

  @override
  String get minorAccountReviewCheckAgain => 'もう一度確認';

  @override
  String get minorAccountReviewLogOut => 'ログアウト';

  @override
  String get minorAccountReviewNextStepTitle => '次のステップ';

  @override
  String get minorAccountReviewNextStepBody =>
      'この審査についてサポートが必要な場合は、サポートセンターまたはモデレーションメッセージを開いてください。';

  @override
  String get minorAccountReviewInProgressTitle => '審査中です';

  @override
  String get minorAccountReviewInProgressBody =>
      '今のところ必要な情報はそろっています。通常のアカウント利用を再開する前に、チームがこのケースを確認しています。';

  @override
  String get minorAccountReviewUnder13Title => '13歳未満のアカウント';

  @override
  String minorAccountReviewUnder13Body(String supportEmail) {
    return 'このアカウントが13歳未満の方のものである場合、保護者の方が $supportEmail にメールを送り、ケース ID を記載してください。';
  }

  @override
  String get minorAccountReviewUnder13PublicTitle => 'まだアカウントをお渡しできません';

  @override
  String get minorAccountReviewUnder13PublicBody =>
      'Divine は13歳未満の子ども向けには作られておらず、世界各国のソーシャルメディアのルールもそれを許していません。\n\nインターネットには、望むものを得るために嘘をつくよう仕向けるものがたくさんあります。私たちはそれが嫌いです。人生にとって間違った教えですし、ここであなたに教えるつもりはありません。';

  @override
  String get minorAccountReviewUnder13FamilyTitle => '代わりにご家族ができること';

  @override
  String get minorAccountReviewUnder13FamilyBody =>
      '保護者の方がアカウントを持って投稿することができ、あなたも一緒に動画に出て大丈夫です。ご家族それぞれに合ったかたちで Divine を楽しんでほしいと思っています。';

  @override
  String get minorAccountReviewUnder13ComeBackTitle => '13歳になったら';

  @override
  String get minorAccountReviewUnder13ComeBackBody =>
      'お住まいの地域のルールによっては、戻ってきて自分のアカウントを申請できるかもしれません。その際、13〜15歳の場合は保護者の同意が必要です。';

  @override
  String get minorAccountReviewUnder13HonestyTitle => '「とりあえず戻って」って言わない理由';

  @override
  String get minorAccountReviewUnder13HonestyBody =>
      'ネットの多くは、ゲートを通るためなら何とでも言えるように仕向けられてるよね。それって良くないと思うんだ。確かに、戻って本当の年齢よりも上だって言うこともできるけど、それは正直じゃないし、欲しいものを手に入れるために嘘をつくよう仕向けるつもりはないよ。';

  @override
  String get minorAccountReviewUnder13LegalBody =>
      '私たちは、若い人たちが自分自身や周りの人にとって健康的でポジティブな形で Divine を使えるよう手助けしたいと思ってるよ。それに、場所によって違う法律も守らなきゃいけないんだ。だから、もし13歳未満なら、今は自分のアカウントを持つことはできないよ。';

  @override
  String get minorAccountReviewTeenBody =>
      'このアカウントが13〜15歳の方のものである場合は、モデレーションメッセージまたはサポート経由で保護者の同意手順に従ってください。';

  @override
  String get minorAccountReviewParentConsentTitle => 'アカウントが13〜15歳の方のものになる場合';

  @override
  String get minorAccountReviewParentConsentBody =>
      '保護者の方から Divine サポートに、短いプライベート動画を添えてメールしてください。チームが確認し、次のステップをお手伝いします。\n\n保護者に連絡できない場合や、連絡することで誰かが危険にさらされる場合は、Divine サポートにメールで知らせてください。';

  @override
  String get minorAccountReviewParentConsentPauseNote =>
      'これは Divine サポートチームが動画を確認するあいだの一時停止です。承認されたら、新しいアカウントの設定を案内します。';

  @override
  String get minorAccountReviewParentConsentHonestyTitle =>
      '保護者に関わってもらうようお願いする理由';

  @override
  String get minorAccountReviewParentConsentHonestyBody =>
      'Divine は世界中の年齢に関する法律を守らなきゃいけないよ。それに、技術的な年齢確認のほとんどが完璧じゃないこともわかってる。ルールなんてないふりをしたり、年齢について嘘をつくのがカッコいいみたいにするんじゃなくて、10代の人や家族に Divine の一番いい使い方を一緒に考えてほしいんだ。だから13〜15歳の人には、アカウント作成に保護者が参加するようお願いしてるよ。';

  @override
  String get minorAccountReviewParentConsentLegalBody =>
      '私たちは法律も守らなきゃいけなくて、そのルールは住んでる場所によって違うんだ。だから、ルールなんてないふりをするんじゃなくて、保護者にこのプロセスに参加してもらうようお願いしてるよ。';

  @override
  String get minorAccountReviewParentConsentChecklist => '動画に映すべき内容';

  @override
  String get minorAccountReviewParentConsentChecklistKid => '動画に映る本人';

  @override
  String get minorAccountReviewParentConsentChecklistPermission =>
      'カメラの前で話す保護者';

  @override
  String get minorAccountReviewParentConsentChecklistAgeBand =>
      '本人が13〜15歳であり、Divine の利用許可を得ているという明確な説明';

  @override
  String get minorAccountReviewParentConsentChecklistSupervision =>
      '保護者がアカウントを把握し、利用を見守るという明確な説明';

  @override
  String get minorAccountReviewParentConsentPrivacy => '送り方';

  @override
  String get minorAccountReviewParentConsentNeverPost =>
      'Divine サポートへのメールに動画を添付してください';

  @override
  String get minorAccountReviewParentConsentDoNotSave =>
      '動画は非公開のままにし、アプリには投稿しないでください';

  @override
  String get minorAccountReviewParentConsentOneMove => 'チームが確認し、次のステップをお返事します';

  @override
  String get minorAccountReviewParentConsentEmailCta => 'Divine サポートにメール';

  @override
  String get minorAccountReviewParentConsentEmailSubject =>
      'Divine Greenlight 審査のお問い合わせ（13〜15歳）';

  @override
  String get minorAccountReviewParentConsentEmailBody =>
      'Divine サポートご担当者さま\n\n13〜15歳の子どもについて、Divine Greenlight の件でご連絡します。\n\n以下が映った短い非公開の動画を添付しました:\n- 本人\n- カメラの前で話す保護者\n- 本人が Divine の利用許可を得ていること\n- 保護者がアカウントを把握し、利用を見守ること\n\n居住国:\n\n補足情報:\n\nよろしくお願いします。';

  @override
  String get minorAccountReviewParentSupportInstructions => '保護者向けサポート手順';

  @override
  String get minorAccountReviewContinue => '続ける';

  @override
  String get minorAccountReviewErrorTitle => 'アカウント審査の状況を読み込めませんでした。';

  @override
  String get minorAccountReviewErrorBody => '少し待ってからもう一度お試しください。';

  @override
  String get minorAccountReviewTryAgain => 'もう一度試す';

  @override
  String get minorAccountReviewParentContactTitle => '保護者の連絡先';

  @override
  String get minorAccountReviewParentContactHeading => '保護者のメールアドレスを追加';

  @override
  String minorAccountReviewParentContactBody(String caseId) {
    return 'このアドレスはケース $caseId の保護者同意の審査に使用します。';
  }

  @override
  String get minorAccountReviewParentContactFieldLabel => '保護者のメールアドレス';

  @override
  String get minorAccountReviewSubmitting => '送信中...';

  @override
  String get minorAccountReviewSubmitEmail => 'メールを送信';

  @override
  String get minorAccountReviewBackToReview => 'アカウント審査に戻る';

  @override
  String get minorAccountReviewSubmissionReceivedTitle => 'メールを送信しました';

  @override
  String minorAccountReviewSubmissionReceivedBody(String email) {
    return '$email を審査に送信しました。確認のためこのアドレスにメールをお送りします。保護者の方から返信があり次第、ケースが進みます。最新の状況はアカウント審査画面の「もう一度確認」からご覧ください。';
  }

  @override
  String get minorAccountReviewSubmissionReceivedLocalBody =>
      'このアカウントの保護者の連絡先を受け取りました。アクセスを再開する前にチームが確認します。';

  @override
  String get minorAccountReviewMissingCase => 'このアカウントに有効な審査ケースが見つかりませんでした。';

  @override
  String get minorAccountReviewParentContactError =>
      '保護者のメールアドレスを送信できませんでした。もう一度お試しください。';

  @override
  String get minorAccountReviewUnder13SupportTitle => '保護者向けサポート';

  @override
  String get minorAccountReviewUnder13Heading => '保護者の方が Divine に連絡する必要があります';

  @override
  String get minorAccountReviewUnder13SupportBody =>
      '13歳未満と思われるアカウントの場合、次のステップは保護者の方からのメール連絡です。';

  @override
  String get minorAccountReviewSupportEmailLabel => 'サポートのメールアドレス';

  @override
  String get minorAccountReviewCopySupportEmail => 'サポートのメールアドレスをコピー';

  @override
  String get minorAccountReviewSupportEmailCopied => 'サポートのメールアドレスをコピーしました';

  @override
  String get minorAccountReviewCopyCaseId => 'ケース ID をコピー';

  @override
  String get minorAccountReviewCaseIdCopied => 'ケース ID をコピーしました';

  @override
  String get minorAccountReviewUnavailable => '利用できません';

  @override
  String get minorAccountReviewUnder13Instructions =>
      '保護者の方に、ケース ID を記載し、このアカウント審査の件で Divine に連絡していることを伝えてもらってください。';

  @override
  String minorAccountReviewUnder13EmailSubject(String caseId) {
    return 'ケース $caseId の13歳未満アカウント審査';
  }

  @override
  String minorAccountReviewUnder13EmailBody(String caseId) {
    return 'Divine サポートご担当者さま\n\n13歳未満の子どもの保護者です。アカウント審査ケース $caseId の件でご連絡します。\n\nよろしくお願いします。';
  }

  @override
  String get devOptionsMinorReviewSimulationTitle => '未成年アカウント審査のシミュレーション';

  @override
  String get devOptionsMinorReviewCurrentStateLabel => '現在の状態';

  @override
  String devOptionsMinorReviewStateRestricted(String state) {
    return '制限中（$state）';
  }

  @override
  String get devOptionsMinorReviewStateActive => 'アクティブ';

  @override
  String get devOptionsMinorReviewStateLoading => '読み込み中...';

  @override
  String get devOptionsMinorReviewStateError => '状態の読み込みエラー';

  @override
  String get devOptionsMinorReviewClearTitle => 'シミュレーションの上書きを解除';

  @override
  String get devOptionsMinorReviewClearSubtitle => '再びバックエンドまたは既定のアクティブ状態を使う';

  @override
  String get devOptionsMinorReviewTeenTitle => '13〜15歳の審査ケースをシミュレート';

  @override
  String get devOptionsMinorReviewTeenSubtitle => '保護者連絡フロー付きの制限アカウント';

  @override
  String get devOptionsMinorReviewUnder13Title => '13歳未満のサポートケースをシミュレート';

  @override
  String get devOptionsMinorReviewUnder13Subtitle => '保護者メールのみの案内が付く制限アカウント';

  @override
  String get devOptionsMinorReviewClearedToast => '未成年アカウント審査のシミュレーションを解除しました';

  @override
  String get devOptionsMinorReviewUnder13EnabledToast =>
      '13歳未満のサポートケースのシミュレーションを有効にしました';

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
  String get devOptionsProtectedMinorSimulationTitle => '保護対象の未成年シミュレーション';

  @override
  String get devOptionsProtectedMinorCurrentStateLabel => '現在の状態';

  @override
  String get devOptionsProtectedMinorStateProtected => '保護対象の未成年（13〜15歳）';

  @override
  String get devOptionsProtectedMinorStateNotProtected => '保護対象外';

  @override
  String get devOptionsProtectedMinorStateLoading => '読み込み中…';

  @override
  String get devOptionsProtectedMinorStateError => '状態の読み取りエラー';

  @override
  String get devOptionsProtectedMinorOverrideNone => '上書きなし（実際のアカウント状態）';

  @override
  String get devOptionsProtectedMinorOverrideProtected => '上書き: 保護対象を強制';

  @override
  String get devOptionsProtectedMinorOverrideNotProtected => '上書き: 保護対象外を強制';

  @override
  String get devOptionsProtectedMinorSimulateTitle => '保護対象の未成年をシミュレート（13〜15歳）';

  @override
  String get devOptionsProtectedMinorSimulateSubtitle =>
      '#175/#176 の保護機能を検証するため、保護対象の未成年状態を強制します';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorTitle => '成人をシミュレート';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorSubtitle =>
      '保護対象外を強制（明示的な否定で、上書きなしとは異なります）';

  @override
  String get devOptionsProtectedMinorClearTitle => '上書きを解除';

  @override
  String get devOptionsProtectedMinorClearSubtitle =>
      'Keycast による実際のアカウント状態に戻す';

  @override
  String get devOptionsProtectedMinorEnabledToast => '保護対象の未成年状態を強制しました';

  @override
  String get devOptionsProtectedMinorNonMinorToast => '保護対象の未成年状態を解除しました';

  @override
  String get devOptionsProtectedMinorClearedToast => '保護対象の未成年の上書きを解除しました';

  @override
  String get devOptionsInviteAvailabilityTitle => '登録招待';

  @override
  String get devOptionsInviteAvailabilityCurrentLabel => '現在の状態';

  @override
  String get devOptionsInviteAvailabilityServerLoading => 'サーバー値: 読み込み中';

  @override
  String get devOptionsInviteAvailabilityServerEnabled => 'サーバー値: 有効';

  @override
  String get devOptionsInviteAvailabilityServerDisabled => 'サーバー値: 無効';

  @override
  String get devOptionsInviteAvailabilityServerUnknown => 'サーバー値: 不明';

  @override
  String get devOptionsInviteAvailabilityOverrideNone => '上書き: サーバー値を使う';

  @override
  String get devOptionsInviteAvailabilityOverrideEnabled => '上書き: 有効を強制';

  @override
  String get devOptionsInviteAvailabilityOverrideDisabled => '上書き: 無効を強制';

  @override
  String get devOptionsInviteAvailabilityUseServer => 'サーバー値を使う';

  @override
  String get devOptionsInviteAvailabilityUseServerSubtitle =>
      '招待サービスの onboardingMode に従う';

  @override
  String get devOptionsInviteAvailabilityForceEnabled => '有効を強制';

  @override
  String get devOptionsInviteAvailabilityForceEnabledSubtitle =>
      '登録招待のゲートと管理画面をローカルで表示';

  @override
  String get devOptionsInviteAvailabilityForceDisabled => '無効を強制';

  @override
  String get devOptionsInviteAvailabilityForceDisabledSubtitle =>
      'サーバーを変更せずに登録招待の UI をローカルで非表示';

  @override
  String get devOptionsInviteAvailabilityUseServerToast =>
      '登録招待はサーバーに従うようになりました';

  @override
  String get devOptionsInviteAvailabilityForceEnabledToast =>
      '登録招待を強制的に有効にしました';

  @override
  String get devOptionsInviteAvailabilityForceDisabledToast =>
      '登録招待を強制的に無効にしました';

  @override
  String get commentsRecordVideoButtonLabel => '動画コメントを録画';

  @override
  String get commentsOpenVideoLabel => '動画コメントを開く';

  @override
  String get commentsMuteVideoReplyLabel => '動画返信をミュート';

  @override
  String get commentsUnmuteVideoReplyLabel => '動画返信のミュートを解除';

  @override
  String get commentsOpenReplyParentLabel => '返信先の動画を開く';

  @override
  String get commentsReplyParentSectionTitle => '返信先';

  @override
  String commentsReplyParentLabel(String target) {
    return '$target への返信';
  }

  @override
  String get commentsReplyParentFallbackLabel => '動画への返信';

  @override
  String verifiedAccountChipSemanticLabel(String platform, String identity) {
    return '認証済み$platformアカウント: $identity';
  }

  @override
  String get profileEditVerifiedAccountsTitle => '認証済みアカウント';

  @override
  String get profileEditGetVerifiedCta => '認証を受ける';

  @override
  String get profileEditGetVerifiedSubtitle =>
      'ソーシャルメディアのアカウントをつないで、本物のあなただと伝えよう。';

  @override
  String profileWebsiteSemanticLabel(String url) {
    return 'ウェブサイトを開く: $url';
  }

  @override
  String get profileCouldNotOpenWebsite => 'ウェブサイトを開けませんでした';

  @override
  String get videoMetadataEditCoverTitle => 'カバーを編集';

  @override
  String get videoMetadataEditCoverCloseSemanticLabel => 'カバーの変更を破棄';

  @override
  String get videoMetadataEditCoverConfirmSemanticLabel => '選択したフレームを動画のカバーに使用';

  @override
  String get videoMetadataEditCoverStripSemanticLabel =>
      'カバーフレームを選択するために動画をシーク';

  @override
  String get videoMetadataTagsPickerSearchHint => 'タグを検索または追加';

  @override
  String get videoMetadataTagsPickerEmptyHint => 'タグを追加して動画を見つけてもらおう';

  @override
  String get videoMetadataTagsPickerNoResults => '一致するタグがありません';

  @override
  String videoMetadataTagsPickerAddTag(String tag) {
    return '「#$tag」を追加';
  }

  @override
  String get authMinAgeNotice => 'Divine Greenlight';

  @override
  String get authUnder16Prefix => 'まだ16歳じゃない? 大丈夫だよ。 ';

  @override
  String get authUnder16ChoicesCta => 'あなたの選択肢はこちら。';

  @override
  String get minorAccountReviewUnder13WhyTitle => 'その理由';

  @override
  String get generalSettingsHoldToRecord => '長押しで録画';

  @override
  String get generalSettingsHoldToRecordSubtitle => '長押しすると録画が始まり、離すと止まります';

  @override
  String uploadPublishedCountMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count本の動画をプロフィールに公開したよ',
      one: '動画をプロフィールに公開したよ',
    );
    return '$_temp0';
  }

  @override
  String get dmMessageSendLabel => 'メッセージを送信';

  @override
  String get emojiPickerSearchHint => '検索';

  @override
  String get emojiCategoryRecent => '最近使った絵文字';

  @override
  String get emojiCategorySmileys => 'スマイリーと人々';

  @override
  String get emojiCategoryAnimals => '動物と自然';

  @override
  String get emojiCategoryFood => '食べ物と飲み物';

  @override
  String get emojiCategoryActivities => 'アクティビティ';

  @override
  String get emojiCategoryTravel => '旅行と場所';

  @override
  String get emojiCategoryObjects => '物';

  @override
  String get emojiCategorySymbols => '記号';

  @override
  String get emojiCategoryFlags => '旗';

  @override
  String get videoEditorMarkerLabel => 'マーカー';

  @override
  String get videoEditorAddTimelineMarkerSemanticLabel => 'タイムラインマーカーを追加';

  @override
  String get videoEditorRemoveTimelineMarkerSemanticLabel => 'タイムラインマーカーを削除';

  @override
  String get videoEditorRemoveTimelineMarkerAtPlayheadSemanticLabel =>
      '再生ヘッド位置のマーカーを削除';

  @override
  String get videoEditorDeleteTimelineMarkerTitle => 'マーカーを削除しますか？';

  @override
  String get videoEditorDeleteTimelineMarkerSubtitle =>
      'タイムラインからマーカーを削除します。編集内容はそのまま残ります。';

  @override
  String get videoEditorVolumeLongPressHint => 'すべてのトラックをミュートまたはミュート解除';

  @override
  String get videoEditorSplitFailed => '分割に失敗しました。もう一度お試しください。';

  @override
  String get videoEditEditSubtitles => '字幕を編集';

  @override
  String get subtitleEditorTitle => '字幕を編集';

  @override
  String get subtitleEditorSave => '保存';

  @override
  String get subtitleEditorProcessing => '字幕はまだ生成中だよ。少し待ってからもう一回見てね。';

  @override
  String get subtitleEditorNoSpeech => 'この動画からは話し声が見つからなかったよ。字幕にするものがないみたい。';

  @override
  String get subtitleEditorWriteOwn => '自分で書く';

  @override
  String get subtitleEditorAddCue => '行を追加';

  @override
  String get subtitleEditorRemoveCue => 'この行を削除';

  @override
  String get subtitleEditorPreviewUnavailable => 'いま動画を再生できないけど、字幕はこのまま直せるよ。';

  @override
  String get subtitleEditorPlayPreview => '動画を再生';

  @override
  String get subtitleEditorPausePreview => '動画を一時停止';

  @override
  String get subtitleEditorInvalidHint => 'どの行にもテキストと、開始より後の終了時間が必要だよ。';

  @override
  String get subtitleEditorLoadError => '字幕を読み込めなかったよ。もう一回試してね。';

  @override
  String get subtitleEditorSaveSuccess => '字幕を更新したよ';

  @override
  String get subtitleEditorSaveError => '字幕を保存できなかったよ。もう一回試してね。';

  @override
  String get subtitleEditorRetry => '再試行';

  @override
  String get subtitleEditorCueHint => 'キャプションのテキスト';

  @override
  String get imageCropEditorRotateLabel => '回転';

  @override
  String get imageCropEditorFlipLabel => '反転';

  @override
  String get imageCropEditorResetLabel => 'リセット';

  @override
  String get imageCropEditorCloseSemanticLabel => '切り抜きをキャンセル';

  @override
  String get imageCropEditorDoneSemanticLabel => '切り抜きを適用';

  @override
  String get imageCropEditorProcessing => '切り抜きを適用中…';

  @override
  String get backgroundUploadNotificationTitle => '動画をアップロード中';

  @override
  String get monetizationSettingsTitle => 'クリエイター支援';

  @override
  String get monetizationSettingsSubtitle => '投げ銭とサブスクのリンクを追加';

  @override
  String get monetizationSettingsIntroTitle => '外部リンクのみ';

  @override
  String get monetizationSettingsIntroBody =>
      '自分で管理するリンク先を追加してください。Divine が支払いを扱うことはなく、これらのリンクでアプリ内のコンテンツが解放されることもありません。';

  @override
  String monetizationSettingsConfiguredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'プロフィールに有効なリンクが $count 件',
    );
    return '$_temp0';
  }

  @override
  String get monetizationSettingsTipSection => '投げ銭を送る';

  @override
  String get monetizationSettingsSubscriptionSection => '登録・支援';

  @override
  String get monetizationSettingsSave => '支援リンクを保存';

  @override
  String get monetizationSettingsSaving => '保存中...';

  @override
  String get monetizationSettingsSaved => '支援リンクを更新しました';

  @override
  String get monetizationSettingsSaveFailed =>
      '支援リンクを保存できませんでした。接続を確認してもう一度お試しください。';

  @override
  String get monetizationSettingsErrorEmpty => 'ハンドルまたは URL を追加してください。';

  @override
  String get monetizationSettingsErrorInvalid => 'このリンクは正しくないようです。';

  @override
  String get monetizationSettingsErrorWrongProvider => 'このサービス用のリンクを使ってください。';

  @override
  String get monetizationSettingsHintCashApp => '\$cashtag または cash.app のリンク';

  @override
  String get monetizationSettingsHintPayPal => 'PayPal.me のハンドルまたはリンク';

  @override
  String get monetizationSettingsHintVenmo => 'Venmo のハンドルまたはリンク';

  @override
  String get monetizationSettingsHintPatreon => 'Patreon のハンドルまたはリンク';

  @override
  String get monetizationSettingsHintSubstack => 'Substack のドメインまたはリンク';

  @override
  String get monetizationSettingsHintMedium => 'Medium のハンドルまたはリンク';

  @override
  String get monetizationSettingsHintOpenCollective =>
      'Open Collective のスラッグまたはリンク';

  @override
  String get profileSupportSheetTitle => 'このクリエイターを支援';

  @override
  String get profileSupportSheetBody =>
      'これらのリンクは Divine の外で開きます。ここからアプリ内のコンテンツが解放されることはありません。';

  @override
  String get profileSupportTipSection => '投げ銭を送る';

  @override
  String get profileSupportSubscriptionSection => '登録・支援';

  @override
  String get profileSupportButtonLabel => '支援する';

  @override
  String get monetizationTipsSettingsTitle => '投げ銭';

  @override
  String get monetizationTipsSettingsSubtitle => '任意の投げ銭リンクを追加';

  @override
  String get monetizationTipsSettingsIntroTitle => '任意の投げ銭のみ';

  @override
  String get monetizationTipsSettingsIntroBody =>
      '投げ銭はユーザー同士の任意の贈り物です。Divine 内でコンテンツ、サブスク、機能、ランキング、表示、アクセスが解放されることはありません。';

  @override
  String monetizationTipsSettingsConfiguredCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'プロフィールに有効な投げ銭リンクが $count 件',
    );
    return '$_temp0';
  }

  @override
  String get monetizationTipsSettingsSave => '投げ銭リンクを保存';

  @override
  String get monetizationTipsSettingsSaved => '投げ銭リンクを更新しました';

  @override
  String get profileTipButtonLabel => '投げ銭';

  @override
  String get profileTipSheetTitle => 'このクリエイターに投げ銭';

  @override
  String get profileTipSheetBody =>
      '投げ銭リンクは Divine の外で開きます。任意であり、Divine 内でコンテンツ、サブスク、機能、アクセスが解放されることはありません。';

  @override
  String get settingsStorageTitle => 'ストレージ';

  @override
  String get settingsStorageCacheSectionTitle => 'キャッシュされたメディア';

  @override
  String get settingsStorageCacheDescription =>
      'キャッシュされたフィード動画、サムネイル、一時レンダー。削除しても安全です。必要なときに再ダウンロードまたは再生成されます。';

  @override
  String get settingsStorageMeasuring => '計算中…';

  @override
  String settingsStorageCacheInUse(String size) {
    return '$size 使用中';
  }

  @override
  String get settingsStorageClearButton => 'キャッシュを消去';

  @override
  String get settingsStorageClearConfirmTitle => 'キャッシュされたメディアを消去しますか？';

  @override
  String settingsStorageClearConfirmMessage(String size) {
    return '$size を解放します。クリップライブラリには影響しません。';
  }

  @override
  String get settingsStorageClearConfirmAction => '消去';

  @override
  String get settingsStorageCleared => 'キャッシュを消去しました';

  @override
  String get settingsStorageLibrarySectionTitle => 'クリップライブラリ';

  @override
  String get settingsStorageLibraryDescription => '動画ファイルが見つからない壊れたクリップを確認します。';

  @override
  String get settingsStorageScanButton => 'ライブラリを確認';

  @override
  String get settingsStorageLibraryHealthy => '壊れたクリップは見つかりませんでした';

  @override
  String settingsStorageBrokenClipsFound(int count) {
    return '見つかった壊れたクリップ: $count';
  }

  @override
  String get settingsStorageRemoveBrokenButton => '壊れたクリップを削除';

  @override
  String get settingsStorageBrokenClipsRemoved => '壊れたクリップを削除しました';

  @override
  String get settingsStorageError => '問題が発生しました';

  @override
  String get settingsStorageMaxVideoCacheLabel => '最大動画キャッシュ';

  @override
  String settingsStorageApproxVideos(int count) {
    return '≈ $count 本の動画';
  }

  @override
  String get settingsStorageRemoveBrokenConfirmTitle => '壊れたクリップを削除しますか？';

  @override
  String get settingsStorageRepairSectionTitle => 'インストールを修復';

  @override
  String get settingsStorageRepairDescription =>
      'アプリが落ちたり動きがおかしいときは、ローカルデータをリセットすると直ることが多いよ。クリップと下書きはそのまま残る。';

  @override
  String get settingsStorageRepairButton => 'アプリデータをリセット';

  @override
  String get settingsStorageRepairConfirmTitle => 'アプリデータをリセットする?';

  @override
  String get settingsStorageRepairConfirmMessage =>
      'キャッシュ済みのフィードデータと一時ファイルを消すよ。クリップ、下書き、設定、ログインは残るけど、あとでアプリを再起動してね。';

  @override
  String settingsStorageRepairFootprint(String size) {
    return '$size を削除するよ';
  }

  @override
  String get settingsStorageRepairConfirmAction => 'リセット';

  @override
  String get settingsStorageRepairInProgress => 'リセット中…';

  @override
  String get settingsStorageRepairSuccess => '完了 — 仕上げにアプリを再起動してね。';

  @override
  String get settingsStorageRepairFailure => '全部はリセットできなかった。再起動してからもう一度試してね。';

  @override
  String get nostrSettingsSignatureVerification => '署名の検証';

  @override
  String get nostrSettingsSignatureVerificationIntro =>
      'Divine がリレーイベントの署名をチェックするタイミングを選択します。イベント ID は常に先に検証されます。';

  @override
  String get nostrSettingsSignatureVerificationAll => 'すべてのリレー';

  @override
  String get nostrSettingsSignatureVerificationAllSubtitle =>
      '最も安全です。すべてのリレーイベント署名を検証します。';

  @override
  String get nostrSettingsSignatureVerificationUntrusted => '信頼されていないリレー';

  @override
  String get nostrSettingsSignatureVerificationUntrustedSubtitle =>
      '設定済みのプールにあるリレーのチェックをスキップします。';

  @override
  String get nostrSettingsSignatureVerificationNonDivine => 'Divine 以外のリレー';

  @override
  String get nostrSettingsSignatureVerificationNonDivineSubtitle =>
      'Divine リレーを信頼し、それ以外を検証します。';

  @override
  String get settingsCrosspostingTitle => 'クロス投稿';

  @override
  String get settingsCrosspostingSubtitle => '動画を他のプラットフォームにシェア';

  @override
  String get crosspostingSignInRequired => 'クロス投稿を管理するには Divine でログインしてね';

  @override
  String get crosspostingLoadFailed => 'クロス投稿の設定を読み込めなかったよ';

  @override
  String get crosspostingNoPlatforms => '今は使えるクロス投稿プラットフォームがないよ';

  @override
  String get crosspostingRetry => 'もう一回';

  @override
  String get crosspostingNotConnected => '未接続';

  @override
  String get crosspostingConnected => '接続済み';

  @override
  String get crosspostingNeedsReconnect => '再接続が必要';

  @override
  String get crosspostingConnect => '接続';

  @override
  String get crosspostingReconnect => '再接続';

  @override
  String get crosspostingDisconnect => '接続を解除';

  @override
  String get crosspostingModeOff => 'オフ';

  @override
  String get crosspostingModeManual => '手動';

  @override
  String get crosspostingModeManualSubtitle => '動画ごとに選べるよ';

  @override
  String get crosspostingModeAutomatic => '自動';

  @override
  String get crosspostingModeAutomaticSubtitle =>
      'これからの動画は自動で投稿されるよ — オンにしたあとに公開した動画だけね';

  @override
  String get crosspostingNotConnectedError => '投稿方法を変えるには、まずこのプラットフォームを接続してね。';

  @override
  String get crosspostingGenericError => '何かがうまくいかなかったよ。もう一回試してね。';

  @override
  String get crosspostingCallbackTimeoutError =>
      'ログインページから返事がなかったよ。あっちで接続を終えていたら、更新してみて — もう連携できてるかも。';

  @override
  String crosspostingConnectionSuccess(String platform) {
    return '$platform に接続したよ';
  }

  @override
  String crosspostingConnectionFailed(String platform) {
    return '$platform に接続できなかったよ';
  }

  @override
  String crosspostingConnectionDenied(String platform) {
    return '$platform で接続がキャンセルされたよ';
  }

  @override
  String get supporterTitle => 'Divine サポーター';

  @override
  String get supporterTileSubtitle => '任意の月額サブスクで Divine を応援。';

  @override
  String get supporterHeroTitle => 'Divine を走らせ続けよう';

  @override
  String get supporterHeroBody =>
      'Divine は無料だよ。これからもずっと。ループを回し続ける手伝いがしたかったら、月額サポーターになってね。ロックされるものは何もないよ — ただ灯りを灯し続けるだけ。そして私たちの感謝付き。';

  @override
  String get supporterActiveBadge => 'あなたは Divine サポーターだよ。続けてくれてありがとう。';

  @override
  String get supporterPurchasePending => '購入は承認待ちだよ。';

  @override
  String get supporterPurchaseConfirming => 'サポートを確認中…';

  @override
  String get supporterStoreChecking => 'ストアを確認中…';

  @override
  String get supporterUnavailable => '今はここでサポーターサブスクは利用できないよ。';

  @override
  String get supporterRestorePurchases => '購入を復元';

  @override
  String get supporterDismissError => 'エラーを閉じる';

  @override
  String get supporterErrorStoreUnavailable => 'このデバイスではストアを利用できないよ。';

  @override
  String get supporterErrorPurchaseFailed => '購入が完了しなかったよ。課金はされていないよ。';

  @override
  String get supporterErrorPurchasePending => '購入は承認待ちだよ。';

  @override
  String get supporterErrorRestoreFailed => '復元できるサポーターサブスクが見つからなかったよ。';

  @override
  String get supporterErrorOwnershipConflict => 'この購入は別の Divine アカウントに紐付いているよ。';

  @override
  String get supporterErrorVerificationUnavailable =>
      '今は Divine でサポーター状態を確認できないよ。';

  @override
  String get supporterErrorUnknown => '問題が発生したよ。もう一回試してみて。';

  @override
  String get supporterDisclaimer =>
      'ストアが購入を確認した後、Divine がサポーター状態を確定するよ。表示は任意だし、ハローは認証マークじゃないよ。';

  @override
  String get profileNotifyBellOff => '新しい動画を通知する';

  @override
  String get profileNotifyBellOn => '新しい動画の通知を停止';

  @override
  String get profileNotifyUpdateFailed => '保存できませんでした。もう一度試しますか？';

  @override
  String get savedSoundYourLabel => 'あなたのラベル';

  @override
  String get savedSoundAddHashtags => 'ハッシュタグを追加';

  @override
  String get savedSoundDeviceOnly => 'この端末に保存済み';

  @override
  String get savedSoundDetailsRetry => 'この内容を保存できませんでした。タップして再試行。';

  @override
  String get savedSoundFallbackTitle => '保存したサウンド';

  @override
  String get savedSoundPreviewAction => 'サウンドを試聴';

  @override
  String get savedSoundEditAction => 'サウンドの詳細を編集';

  @override
  String get savedSoundRemoveAction => '保存したサウンドを削除';

  @override
  String get savedSoundClearHashtagFilter => 'ハッシュタグの絞り込みを解除';

  @override
  String get soundAllowRemix => '他の人がこのサウンドをリミックスするのを許可';

  @override
  String get soundReuseUnavailable => 'このサウンドは今はリミックスできません。';

  @override
  String get soundPublicCredit => '公開サウンドクレジット';

  @override
  String get soundCreditRequired => '投稿する前に公開サウンドクレジットを追加してください。';

  @override
  String get soundSharedAs => '共有名';

  @override
  String get soundOwnWork => 'このサウンドは自分が作りました';

  @override
  String soundCreatorBy(String creator) {
    return '作成者: $creator';
  }

  @override
  String soundSharedBy(String publisher) {
    return '$publisher が共有';
  }

  @override
  String get soundRemixingAllowed => 'リミックス可';

  @override
  String get soundCreditOnly => 'クレジットのみ';

  @override
  String get soundCreditTitleLabel => 'サウンドのタイトル';

  @override
  String get soundCreditCreatorLabel => '作成者';

  @override
  String get soundCreditSourceUrlLabel => 'ソース URL';

  @override
  String get soundCreditPublicHashtagsLabel => '公開ハッシュタグ';

  @override
  String get videoMetadataTagsPickerCancelSemanticLabel => 'タグの選択をキャンセル';

  @override
  String get videoMetadataTagsPickerConfirmSemanticLabel => '選択したタグを適用';

  @override
  String get userPickerCancelSemanticLabel => 'ユーザー選択をキャンセル';

  @override
  String get userPickerConfirmSemanticLabel => '選択したユーザーを確定';

  @override
  String get userPickerClearSelectionSemanticLabel => 'ユーザー選択をクリア';

  @override
  String get videoMetadataContentWarningsPickerCancelSemanticLabel =>
      'コンテンツ警告の選択をキャンセル';

  @override
  String get videoMetadataContentWarningsPickerConfirmSemanticLabel =>
      '選択したコンテンツ警告を適用';

  @override
  String get videoEditorCloseEditorSemanticLabel => '動画エディターを閉じる';

  @override
  String get videoEditorContinueToPostDetailsSemanticLabel => '投稿の詳細に進む';

  @override
  String videoEditorDiscardToolChangesSemanticLabel(String tool) {
    return '$toolでの変更を破棄';
  }

  @override
  String videoEditorApplyToolChangesSemanticLabel(String tool) {
    return '$toolでの変更を適用';
  }

  @override
  String get videoEditorRemoveAudioSemanticLabel => '音声を削除';

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
  String get verifyTitle => '認証済みアカウント';

  @override
  String get verifySignedOutMessage => 'アカウントを連携するにはログインしてね。';

  @override
  String get verifyIntro => 'すでに持っているアカウントを連携すれば、本人だとひと目でわかるよ。';

  @override
  String get verifyLoadFailed => '連携を読み込めなかった。';

  @override
  String get verifyRetry => 'もう一度試す';

  @override
  String get verifyLinkedSectionTitle => '連携済み';

  @override
  String get verifyVerifierUnreachable => '認証サービスにつながらなかったから、すべて未確認と表示されてる。';

  @override
  String get verifyAddSectionTitle => 'アカウントを追加';

  @override
  String get verifyAllPlatformsLinked => '対応しているものは全部連携済みだよ。';

  @override
  String get verifyStatusVerified => '認証済み';

  @override
  String get verifyStatusUnverified => '未認証';

  @override
  String verifyUnlinkSemanticLabel(String platform, String identity) {
    return '$platform のアカウント $identity の連携を解除';
  }

  @override
  String verifyUnlinkConfirmTitle(String platform) {
    return '$platform の連携を解除する?';
  }

  @override
  String verifyUnlinkConfirmSubtitle(String identity) {
    return '$identity はプロフィールに表示されなくなるよ。あとでまた連携できるけど、もう一度ログインするか、新しい証明を投稿する必要があるよ。';
  }

  @override
  String get verifyUnlinkConfirmCta => '連携を解除';

  @override
  String verifyLinkSemanticLabel(String platform) {
    return '$platform のアカウントを連携';
  }

  @override
  String get verifyOneTapBadge => 'ワンタップ';

  @override
  String verifyConnectOauthExplainer(String platform) {
    return '$platform にログインすれば、あとはこっちでやるよ。投稿は一切されない。';
  }

  @override
  String verifyConnectOauthCta(String platform) {
    return '$platform で続ける';
  }

  @override
  String get verifyConnectProofTitle => 'または証明を投稿';

  @override
  String get verifyConnectProofExplainer =>
      '自分の npub をそのアカウントで投稿して、その投稿のリンクを貼ってね。';

  @override
  String get verifyNpubLabel => 'あなたの npub';

  @override
  String get verifyCopyNpubSemanticLabel => 'npub をコピー';

  @override
  String get verifyNpubCopied => 'npub をコピーしたよ';

  @override
  String get verifyIdentityLabel => 'アカウント名';

  @override
  String get verifyProofLabel => '投稿のリンク';

  @override
  String get verifyConnectProofCta => '確認して連携';

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
  String get verifyErrorVerifierUnreachable => '認証サービスにつながらなかった。少ししてからもう一度。';

  @override
  String get verifyErrorOauthFailed => 'うまくいかなかった。もう一度試してみて。';

  @override
  String get verifyErrorHandleRequired => '先にハンドルを入力してね。';

  @override
  String get verifyErrorPublishFailed => '認証はできたけど、どのリレーも更新を受け取らなかった。もう一度試して。';

  @override
  String get verifyErrorOauthUnavailable =>
      'ワンタップのログインはこれにはまだ用意されてない。下の証明投稿を使ってね。';

  @override
  String get verifyConnectProofExplainerGithub =>
      '最初のファイルに npub を入れた公開 gist を作って、その gist のリンクを貼ってね。';

  @override
  String get verifyConnectProofExplainerDiscord =>
      'うちのボットが読める Discord チャンネルに npub を投稿して、そのメッセージのリンクを貼ってね。サーバー招待では証明にならないよ。';

  @override
  String get verifyConnectProofExplainerTwitter =>
      'そのアカウントから npub をツイートして、そのツイートのリンクを貼ってね。';

  @override
  String get verifyConnectProofExplainerMastodon =>
      'そのアカウントから npub を投稿して、リンクを貼ってね。アカウント名にはインスタンスが必要だよ — alice ではなく mastodon.social/@alice。';

  @override
  String get verifyConnectProofExplainerTelegram =>
      '連携されるのはチャンネルで、Telegram アカウントじゃないよ。まず公開リンクが必要（Telegram は新規チャンネルを非公開で作る）。そこに npub を投稿して、メッセージのリンクを貼ってね。';

  @override
  String get verifyConnectProofExplainerBluesky =>
      '上でログインした？ならこれ以上は不要。していないなら npub を投稿して、その投稿のリンクを貼ってね。';

  @override
  String get verifyConnectProofExplainerTiktok =>
      '動画のキャプションに npub を入れて、その動画のリンクを貼ってね。';

  @override
  String get verifyConnectProofExplainerYoutube =>
      '動画の説明欄に npub を入れて、その動画のリンクを貼ってね。';

  @override
  String verifyLinkedConfirmation(String platform) {
    return '$platform を連携したよ。';
  }

  @override
  String get verifyErrorTelegramNotPublic =>
      'それは非公開チャンネルか招待リンクだよ。チャンネルに公開リンクを設定してから、メッセージのリンクを貼ってね。';

  @override
  String get verifyErrorRemoveFailed => '連携を解除できなかった。もう一度試してね。';

  @override
  String get verifyErrorLinksUnreadable =>
      'いまの連携を読み取れなかったから、何も変更していないよ。接続を確認してもう一度試してね。';

  @override
  String get verifyChannelLabel => 'チャンネル名';

  @override
  String get verifyHowItWorksTitle => 'これはどういう仕組み？';

  @override
  String get verifyHowItWorksIntro => 'ふたつのアカウントの握手だと思ってね：';

  @override
  String get verifyHowItWorksYourSide =>
      'きみの Divine プロフィールが「Twitter の @alice は私です」と言う。';

  @override
  String get verifyHowItWorksOtherSide =>
      'きみの Twitter アカウントが「はい、その Divine プロフィールは私のものです」と認める。';

  @override
  String get verifyHowItWorksBothSides =>
      '両方をこちらで照合するよ。一致すれば認証完了。偽装はできない — 名前や写真は真似できても、きみの本物のアカウントから投稿はできないからね。';

  @override
  String get verifyHowItWorksOwnership =>
      'リンクはきみ自身の Nostr アイデンティティ上にあるから、ここからいつでも外せるよ。';

  @override
  String get generalSettingsSectionIdentity => 'アイデンティティ';

  @override
  String get libraryFilterAll => 'すべて';

  @override
  String get libraryFilterArchive => 'アーカイブ';

  @override
  String get libraryFilterDeleted => '削除済み';

  @override
  String get libraryCategoryNewChipLabel => '新規';

  @override
  String get libraryCategoryCreateSemanticLabel => 'カテゴリを作成';

  @override
  String get libraryCategoryCreateTitle => '新しいカテゴリ';

  @override
  String get libraryCategoryCreateAction => '作成';

  @override
  String get libraryCategoryRenameTitle => 'カテゴリ名を変更';

  @override
  String get libraryCategoryRenameAction => '名前を変更';

  @override
  String get libraryCategoryDeleteAction => 'カテゴリを削除';

  @override
  String get libraryCategoryNameLabel => 'カテゴリ名';

  @override
  String libraryCategoryDeleteConfirmTitle(String name) {
    return '「$name」を削除しますか？';
  }

  @override
  String get libraryCategoryDeleteConfirmMessage =>
      'クリップはそのまま残ります。「すべて」に戻るだけです。';

  @override
  String get libraryCategoryManageSemanticLabel => 'このカテゴリの名前を変更または削除';

  @override
  String get libraryCategoryMoveTitle => '移動先';

  @override
  String get libraryCategoryMoveNone => 'カテゴリなし';

  @override
  String get libraryCategoryMoveNewCategory => '新しいカテゴリ';

  @override
  String get libraryArchiveAction => 'アーカイブ';

  @override
  String get libraryUnarchiveAction => 'アーカイブ解除';

  @override
  String libraryArchiveKeepCategoryTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'これらのカテゴリに残しますか？',
      one: 'このカテゴリに残しますか？',
    );
    return '$_temp0';
  }

  @override
  String libraryArchiveKeepCategoryAction(String name) {
    return '$nameに残す';
  }

  @override
  String get libraryArchiveKeepCategoryActionMixed => 'カテゴリに残す';

  @override
  String libraryArchiveRemoveCategoryAction(String name) {
    return '$nameから外す';
  }

  @override
  String get libraryArchiveRemoveCategoryActionMixed => 'カテゴリから外す';

  @override
  String get libraryMoveSelectedClipsTooltip => '選択したクリップを移動';

  @override
  String get libraryCategoryEmptyTitle => 'ここにはまだ何もありません';

  @override
  String get libraryCategoryEmptySubtitle => 'クリップをいくつか選んで、このカテゴリに移動しましょう。';

  @override
  String get libraryArchiveEmptyTitle => 'アーカイブはまだありません';

  @override
  String get libraryArchiveEmptySubtitle =>
      'アーカイブしたクリップは、メインのライブラリから離れてここで待機します。';

  @override
  String libraryClipsMovedToCategory(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件のクリップを$nameに移動しました',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsRemovedFromCategory(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件のクリップをカテゴリから外しました',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsArchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件のクリップをアーカイブしました',
    );
    return '$_temp0';
  }

  @override
  String libraryClipsUnarchived(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件のクリップをライブラリに戻しました',
    );
    return '$_temp0';
  }

  @override
  String get accountSettingsChangeEmail => 'メールアドレスを変更';

  @override
  String get accountSettingsChangeEmailSubtitle => 'アカウントを別のアドレスに移す';

  @override
  String get accountSettingsChangePassword => 'パスワードを変更';

  @override
  String get accountSettingsChangePasswordSubtitle => 'ログイン用の新しいパスワードを決める';

  @override
  String get accountCredentialsNeedsSignIn =>
      'セッションが切れました。もう一度ログインしてから変更してください。';

  @override
  String get accountCredentialsRateLimited => '試行が多すぎます。数分待ってからどうぞ。';

  @override
  String get accountCredentialsNetwork =>
      'Divine に接続できませんでした。通信環境を確認してもう一度お試しください。';

  @override
  String get accountCredentialsUnknown => 'うまくいきませんでした。もう一度お試しください。';

  @override
  String get changePasswordSubtitle => '現在のパスワードを入力して、新しいパスワードを決めてください。';

  @override
  String get changePasswordCurrentLabel => '現在のパスワード';

  @override
  String get changePasswordWrongCurrent => '現在のパスワードと違います。';

  @override
  String get changePasswordSuccess => 'パスワードを変更しました。';

  @override
  String get changeEmailSubtitle =>
      '新しいアドレスと、アカウントに登録中のアドレスの両方に確認リンクを送ります。両方で確認するとメールアドレスが変わります。';

  @override
  String changeEmailCurrentAddress(String email) {
    return 'アカウントのアドレス: $email';
  }

  @override
  String get changeEmailNewLabel => '新しいメールアドレス';

  @override
  String get changeEmailPasswordLabel => 'パスワード';

  @override
  String get changeEmailSameAsCurrent => 'すでにそのメールアドレスを使っています。';

  @override
  String get changeEmailWrongPassword => 'パスワードが違います。';

  @override
  String get changeEmailSubmit => '確認リンクを送る';

  @override
  String get changeEmailSentTitle => '確認リンクを2通送りました';

  @override
  String changeEmailSentMessage(String email) {
    return '$email と、アカウントに登録中のアドレスの両方で確認してください。両方が終わるとメールアドレスが切り替わります。';
  }

  @override
  String get changeEmailSentExpiry => 'リンクは24時間で使えなくなります。';

  @override
  String get changeEmailSentDone => 'わかりました';

  @override
  String searchUserVideoCount(int count, String formattedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$formattedCount本の動画',
    );
    return '$_temp0';
  }

  @override
  String get socialProofMutual => '相互フォロー';

  @override
  String get socialProofFollowsYou => 'フォローされています';

  @override
  String get socialProofYouFollow => 'フォロー中';

  @override
  String socialProofFollowerCount(int count, String formattedCount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'フォロワー$formattedCount人',
    );
    return '$_temp0';
  }

  @override
  String get feedOutageMessage => 'いま動画を読み込めません。\nこちらの不具合だよ。すぐ直すね。';

  @override
  String get feedOfflineMessage => 'オフラインだよ。\n接続を確認して、もう一度試してね。';

  @override
  String get dbFailureTitle => 'ローカルデータベースのロックを解除できませんでした';

  @override
  String get dbFailureAdviceResettable =>
      '再起動では解決しません。下のローカルデータベースをリセットすると Divine をきれいな状態から始められます。アカウントはそのまま残ります。';

  @override
  String get dbFailureAdviceRestart =>
      'デバイスのロックを解除してから Divine を再起動してください。これが続く場合は、アプリを更新するかサポートにご連絡ください。';

  @override
  String get dbFailureAdviceHotJournal =>
      'Divineを一度再起動してみてください。問題が続く場合は、アプリを更新するかサポートにお問い合わせください。ローカルデータはそのまま残っています。';

  @override
  String dbFailureDiagnostic(String code) {
    return '診断: $code';
  }

  @override
  String get dbFailureCloseApp => 'Divine を閉じる';

  @override
  String get dbFailureResetAction => 'ローカルデータベースをリセット';

  @override
  String get dbFailureConfirmTitle => 'ローカルデータベースをリセットしますか？';

  @override
  String get dbFailureConfirmBody =>
      'アカウントはそのまま残ります。この端末に保存された下書きとクリップは削除されます。メッセージとフィードはネットワークから復元されます。';

  @override
  String get dbFailureResetConfirm => '今すぐローカルデータベースをリセット';

  @override
  String get dbFailureCancel => 'キャンセル';

  @override
  String get dbFailureResetFailed => 'うまくいきませんでした。Divine を閉じてもう一度お試しください。';

  @override
  String get dbFailureResetDoneTitle => 'ローカルデータベースをリセットしました';

  @override
  String get dbFailureResetDoneBody =>
      'Divine を閉じてもう一度開いてください。次回の起動で新しいローカルデータベースが作成されます。';

  @override
  String get authSignInOptionsInfo => 'ログイン方法について';

  @override
  String get authShowPassword => 'パスワードを表示';

  @override
  String get authHidePassword => 'パスワードを非表示';

  @override
  String get followUserSemanticLabel => 'ユーザーをフォロー';

  @override
  String get unfollowUserSemanticLabel => 'ユーザーのフォローを解除';

  @override
  String get commentsLoadingSemanticLabel => 'コメントを読み込み中';

  @override
  String get analyticsWindowAll => 'すべて';

  @override
  String followUserIndexedSemanticLabel(String index) {
    return 'ユーザーをフォロー $index';
  }

  @override
  String unfollowUserIndexedSemanticLabel(String index) {
    return 'ユーザーのフォローを解除 $index';
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
  String get updateGentleBanner => '新しいアップデートが公開されました。チェックする →';

  @override
  String get updateModerateTitle => '前回の確認後にアップデートが公開されました';

  @override
  String get updateUrgentTitle => '重要な修正が適用されていません';

  @override
  String get updateNotNow => '後で';

  @override
  String get updateAction => 'アップデート';

  @override
  String updateNewIn(String version) {
    return '$version の新機能:';
  }

  @override
  String get settingsUpdateAvailable => 'アップデートがあります';
}

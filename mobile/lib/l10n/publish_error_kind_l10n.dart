// ABOUTME: Maps PublishErrorKind codes to localized strings.
// ABOUTME: State/persistence store the kind; the UI layer localizes for display.

import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/services/video_publish/publish_error_kind.dart';

/// Maps a [PublishErrorKind] to a localized, user-facing message.
///
/// Follows the project's l10n rule: state carries codes, never English copy.
/// Call this from widgets (where an [AppLocalizations] is available) to render
/// the correct translated message. [serverName] is interpolated for the
/// server-related kinds; when absent, a localized "Unknown server" is used.
extension PublishErrorKindL10n on AppLocalizations {
  String publishErrorMessage(PublishErrorKind kind, {String? serverName}) {
    final server = serverName ?? publishErrorUnknownServer;
    switch (kind) {
      case PublishErrorKind.notSignedIn:
        return publishErrorNotSignedIn;
      case PublishErrorKind.noRetry:
        return publishErrorNoRetry;
      case PublishErrorKind.noInternet:
        return publishErrorNoInternet;
      case PublishErrorKind.serverUnreachable:
        return publishErrorServerUnreachable;
      case PublishErrorKind.timeout:
        return publishErrorTimeout;
      case PublishErrorKind.uploadSessionExpired:
        return publishErrorUploadSessionExpired;
      case PublishErrorKind.tls:
        return publishErrorTls;
      case PublishErrorKind.serverNotFound:
        return publishErrorServerNotFound(server);
      case PublishErrorKind.fileTooLarge:
        return publishErrorFileTooLarge;
      case PublishErrorKind.serverInternalError:
        return publishErrorServerInternalError(server);
      case PublishErrorKind.serverDown:
        return publishErrorServerDown(server);
      case PublishErrorKind.rateLimited:
        return publishErrorRateLimited;
      case PublishErrorKind.forbidden:
        return publishErrorForbidden;
      case PublishErrorKind.permissionDenied:
        return publishErrorPermissionDenied;
      case PublishErrorKind.fileNotFound:
        return publishErrorFileNotFound;
      case PublishErrorKind.lowStorage:
        return publishErrorLowStorage;
      case PublishErrorKind.outOfMemory:
        return publishErrorOutOfMemory;
      case PublishErrorKind.thumbnailFailed:
        return publishErrorThumbnailFailed;
      case PublishErrorKind.nostrPublishFailed:
        return publishErrorNostrPublishFailed;
      case PublishErrorKind.accountRestricted:
        return publishErrorAccountRestricted;
      case PublishErrorKind.audioReuseNotPermitted:
        return publishErrorAudioReuseNotPermitted;
      case PublishErrorKind.interrupted:
        return publishErrorInterrupted;
      case PublishErrorKind.scheduleRejected:
        return publishErrorScheduleRejected;
      case PublishErrorKind.accountChanged:
        return publishErrorAccountChanged;
      case PublishErrorKind.generic:
        return publishErrorGeneric;
    }
  }
}

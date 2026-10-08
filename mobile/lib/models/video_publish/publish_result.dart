// ABOUTME: Outcomes of a video publish: success, scheduled, or a classified
// ABOUTME: error, plus the collaborator invite warnings a success can carry.

import 'package:equatable/equatable.dart';
import 'package:openvine/services/video_publish/publish_error_kind.dart';

/// Result of a publish operation.
sealed class PublishResult extends Equatable {
  const PublishResult();

  @override
  List<Object?> get props => [];
}

class PublishSuccess extends PublishResult {
  const PublishSuccess({
    this.stableId,
    this.eventId,
    this.inviteWarnings = const [],
    this.audioReuseDegraded = false,
  });

  /// The published video's `d` tag, which is also its [VideoEvent.stableId].
  ///
  /// Identifies the video without a relay round-trip, so the post-publish
  /// confirmation can link to `/video/<stableId>` and build a share URL
  /// while the event is still propagating. Null for an upload whose
  /// `videoId` is absent or empty — never the empty string, so a caller can
  /// treat non-null as routable.
  final String? stableId;

  /// The published Nostr event's id, for follow-ups that address the exact
  /// event rather than the video, such as crossposting it. Null when the
  /// upload record no longer carries it.
  final String? eventId;

  final List<CollaboratorInviteWarning> inviteWarnings;

  /// The creator asked for a reusable sound and the video published without
  /// one. The publish succeeded, so this is a warning rather than an error —
  /// but silently dropping an explicit sharing choice is worse than saying so.
  final bool audioReuseDegraded;

  bool get hasInviteWarnings => inviteWarnings.isNotEmpty;

  @override
  List<Object?> get props => [
    stableId,
    eventId,
    inviteWarnings,
    audioReuseDegraded,
  ];
}

/// The media is up and the signed event waits for its publish time (#3538).
///
/// [submitted] says whether the relay's hold queue has accepted the event;
/// when false the app keeps it and retries the hand-off in the background.
class PublishScheduled extends PublishResult {
  const PublishScheduled({
    required this.eventId,
    required this.publishAt,
    required this.submitted,
    this.audioReuseDegraded = false,
  });

  final String eventId;
  final DateTime publishAt;
  final bool submitted;

  /// As [PublishSuccess.audioReuseDegraded]. The signed event is final, so
  /// unlike a failed immediate publish no retry can restore the sound.
  final bool audioReuseDegraded;

  @override
  List<Object?> get props => [
    eventId,
    publishAt,
    submitted,
    audioReuseDegraded,
  ];
}

/// A failed publish, classified by [kind] so the UI can localize it.
///
/// [serverName] is the media-server host for the server-related kinds
/// ([PublishErrorKind.serverNotFound] / [PublishErrorKind.serverInternalError]
/// / [PublishErrorKind.serverDown]); null otherwise.
///
/// [rawFallback] carries an already-user-friendly upstream message (or a
/// legacy persisted string) that the UI should render verbatim instead of
/// mapping [kind] — used for the upload-manager passthrough and for drafts
/// persisted before this type existed.
class PublishError extends PublishResult {
  const PublishError(this.kind, {this.serverName, this.rawFallback});

  /// Decodes a value previously produced by [toPersistedString].
  ///
  /// Returns null only when [raw] is null/empty. A value written by an older
  /// build (a plain English sentence) decodes to a generic error carrying that
  /// sentence as [rawFallback], so historical drafts still render verbatim.
  static PublishError? fromPersistedString(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    const prefix = 'pek1:';
    if (raw.startsWith(prefix)) {
      final parts = raw.substring(prefix.length).split(':');
      final kind = _kindByName(parts.first);
      if (kind == null) {
        return PublishError(PublishErrorKind.generic, rawFallback: raw);
      }
      final serverName = parts.length > 1 ? parts.sublist(1).join(':') : null;
      return PublishError(kind, serverName: serverName);
    }
    // Legacy (pre-#4892) sentence string — show as-is.
    return PublishError(PublishErrorKind.generic, rawFallback: raw);
  }

  final PublishErrorKind kind;
  final String? serverName;
  final String? rawFallback;

  /// Encodes this error for persistence in the draft's `publishError` column.
  ///
  /// A [rawFallback] is persisted verbatim (it is already user-friendly text).
  /// Otherwise the stable [kind] (+ [serverName]) is encoded under a `pek1:`
  /// sentinel so it survives a locale change and re-localizes on resume.
  String? toPersistedString() {
    final fallback = rawFallback;
    if (fallback != null && fallback.isNotEmpty) return fallback;
    final base = 'pek1:${kind.name}';
    return serverName == null ? base : '$base:$serverName';
  }

  static PublishErrorKind? _kindByName(String name) {
    for (final kind in PublishErrorKind.values) {
      if (kind.name == name) return kind;
    }
    return null;
  }

  @override
  List<Object?> get props => [kind, serverName, rawFallback];
}

class CollaboratorInviteWarning extends Equatable {
  const CollaboratorInviteWarning({
    required this.collaboratorPubkey,
    required this.creatorPubkey,
    required this.videoAddress,
    this.title,
    this.thumbnailUrl,
    this.relayHint,
    this.error,
  });

  final String collaboratorPubkey;
  final String creatorPubkey;
  final String videoAddress;
  final String? title;
  final String? thumbnailUrl;
  final String? relayHint;
  final String? error;

  @override
  List<Object?> get props => [
    collaboratorPubkey,
    creatorPubkey,
    videoAddress,
    title,
    thumbnailUrl,
    relayHint,
    error,
  ];
}

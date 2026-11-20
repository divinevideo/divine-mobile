// ABOUTME: Sends encrypted collaborator invites via NIP-17 direct messages.
// ABOUTME: Builds readable fallback content plus structured collab tags.

import 'dart:ui' show Locale;

import 'package:dm_repository/dm_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:models/models.dart' show divineVideoShareUrl;
import 'package:openvine/l10n/l10n.dart';

class CollaboratorInviteResult extends Equatable {
  const CollaboratorInviteResult({
    required this.success,
    this.retryablePending = false,
    this.messageEventId,
    this.error,
  });

  final bool success;

  /// The invite has a durable queue row and will be retried in the background.
  /// This is neither confirmed delivery nor a user-actionable hard failure.
  final bool retryablePending;
  final String? messageEventId;
  final String? error;

  @override
  List<Object?> get props => [
    success,
    retryablePending,
    messageEventId,
    error,
  ];
}

class CollaboratorInviteBatchResult extends Equatable {
  const CollaboratorInviteBatchResult({required this.results});

  final Map<String, CollaboratorInviteResult> results;

  /// Whether any invite hard-failed. Retryable pending rows are still active.
  bool get hasFailures => results.values.any(
    (result) => !result.success && !result.retryablePending,
  );

  @override
  List<Object?> get props => [results];
}

class CollaboratorInviteService {
  CollaboratorInviteService({
    required DmRepository dmRepository,
    AppLocalizations? l10n,
    this.videoLinkBase = defaultVideoLinkBase,
    this.defaultRelayHint = 'wss://relay.divine.video',
  }) : _dmRepository = dmRepository,
       _l10n = l10n ?? lookupAppLocalizations(const Locale('en'));

  final DmRepository _dmRepository;
  final AppLocalizations _l10n;
  final String videoLinkBase;
  final String defaultRelayHint;

  /// Base URL for the invite's standard NIP-19 video reference.
  static const String defaultVideoLinkBase = 'https://divine.video/video';

  /// Suffix that uniquely identifies the plaintext fallback body of an
  /// **English-locale** collaborator invite DM, kept in sync with the
  /// English ARB value of `collaboratorInviteDmBody` /
  /// `collaboratorInviteDmBodyUntitled`. The conversation view uses this to
  /// suppress legacy NIP-04 invite duplicates that cannot be turned into
  /// actionable cards (#3559); newer locale-translated invites surface
  /// inside Divine via the structured-tag parser path
  /// (`CollaboratorInviteParser`) and don't depend on this suffix.
  static const String invitePlaintextSuffix =
      'Open Divine to review and accept.';

  /// Wire text this suffix used to have, still present in published events.
  ///
  /// Nostr events are immutable, so correcting the brand casing in the ARB
  /// did not rewrite the invites already sitting on relays. Matching only
  /// the current spelling would un-suppress every one of them, so
  /// [hasInvitePlaintextSuffix] checks the historical spellings too. Add to
  /// this list rather than editing [invitePlaintextSuffix] whenever that
  /// copy changes again.
  static const List<String> legacyInvitePlaintextSuffixes = [
    'Open diVine to review and accept.',
  ];

  /// Whether [content] is a plaintext invite fallback in any spelling we
  /// have ever published.
  static bool hasInvitePlaintextSuffix(String content) =>
      content.endsWith(invitePlaintextSuffix) ||
      legacyInvitePlaintextSuffixes.any(content.endsWith);

  Future<CollaboratorInviteResult> sendInvite({
    required String collaboratorPubkey,
    required String creatorPubkey,
    required String videoAddress,
    String? title,
    String? thumbnailUrl,
    String? relayHint,
  }) async {
    final content = _buildContent(title: title, videoAddress: videoAddress);
    final tags = _buildTags(
      creatorPubkey: creatorPubkey,
      videoAddress: videoAddress,
      title: title,
      thumbnailUrl: thumbnailUrl,
      relayHint: relayHint ?? defaultRelayHint,
    );

    final result = await _dmRepository.sendMessage(
      recipientPubkey: collaboratorPubkey,
      content: content,
      additionalTags: tags,
      // Structured invites cannot be represented in NIP-04; the legacy
      // fallback would publish a duplicate plaintext message that reads
      // "Open Divine to review and accept" inside Divine itself (#3559).
      skipNip04Fallback: true,
    );

    return CollaboratorInviteResult(
      success: result.success,
      retryablePending: result.retryablePending,
      messageEventId: result.messageEventId,
      error: result.retryablePending ? null : result.error,
    );
  }

  Future<CollaboratorInviteBatchResult> sendInvites({
    required Iterable<String> collaboratorPubkeys,
    required String creatorPubkey,
    required String videoAddress,
    String? title,
    String? thumbnailUrl,
    String? relayHint,
  }) async {
    final results = <String, CollaboratorInviteResult>{};
    for (final pubkey in collaboratorPubkeys) {
      results[pubkey] = await sendInvite(
        collaboratorPubkey: pubkey,
        creatorPubkey: creatorPubkey,
        videoAddress: videoAddress,
        title: title,
        thumbnailUrl: thumbnailUrl,
        relayHint: relayHint,
      );
    }
    return CollaboratorInviteBatchResult(results: results);
  }

  String _buildContent({required String videoAddress, String? title}) {
    final url = _videoUrlFor(videoAddress);
    final cleanTitle = title?.trim();
    if (cleanTitle == null || cleanTitle.isEmpty) {
      return _l10n.collaboratorInviteDmBodyUntitled(url);
    }
    return _l10n.collaboratorInviteDmBody(cleanTitle, url);
  }

  String _videoUrlFor(String videoAddress) {
    final parts = videoAddress.split(':');
    final url = divineVideoShareUrl(
      parts.length >= 3 ? parts.sublist(2).join(':') : '',
      authorPubkey: parts.length >= 3 ? parts[1] : null,
      kind: int.tryParse(parts.first),
    );
    return url.replaceFirst(defaultVideoLinkBase, videoLinkBase);
  }

  List<List<String>> _buildTags({
    required String creatorPubkey,
    required String videoAddress,
    required String relayHint,
    String? title,
    String? thumbnailUrl,
  }) {
    return [
      [CollaboratorInviteTags.markerName, CollaboratorInviteTags.markerValue],
      [CollaboratorInviteTags.address, videoAddress, relayHint, 'root'],
      [CollaboratorInviteTags.pubkey, creatorPubkey],
      [CollaboratorInviteTags.role, CollaboratorInviteTags.collaboratorRole],
      if (title != null && title.trim().isNotEmpty)
        [CollaboratorInviteTags.title, title.trim()],
      if (thumbnailUrl != null && thumbnailUrl.trim().isNotEmpty)
        [CollaboratorInviteTags.thumbnail, thumbnailUrl.trim()],
    ];
  }
}

// ABOUTME: Service for sharing videos with other users via Nostr DMs and social features
// ABOUTME: Handles sending videos to specific users and managing sharing options

import 'dart:async';

import 'package:dm_repository/dm_repository.dart';
import 'package:models/models.dart';
import 'package:openvine/models/shareable_user.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/services/share_recents_store.dart';
import 'package:openvine/services/short_link_client.dart';
import 'package:unified_logger/unified_logger.dart';

export 'package:openvine/models/shareable_user.dart';

/// Structured share metadata for the platform share sheet.
///
/// Contains all the information needed to build a rich [ShareParams].
typedef ShareData = ({String shareUrl, String? title, String? thumbnailUrl});

/// Local enqueue outcome. Recipient-route acceptance is observed separately.
enum ShareDelivery { queued, notSent }

class ShareResult {
  const ShareResult.queued(String this.rumorId, String this.conversationId)
    : delivery = ShareDelivery.queued,
      error = null;

  const ShareResult.failure(String this.error)
    : delivery = ShareDelivery.notSent,
      rumorId = null,
      conversationId = null;

  final ShareDelivery delivery;
  final String? error;
  final String? rumorId;
  final String? conversationId;
}

/// Service for sharing videos with other users
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class VideoSharingService {
  VideoSharingService({
    required AuthService authService,
    required ShareRecentsStore recentsStore,
    required DmRepository dmRepository,
    ShortLinkClient? shortLinkClient,
  }) : _authService = authService,
       _recentsStore = recentsStore,
       _dmRepository = dmRepository,
       _shortLinkClient = shortLinkClient;
  final AuthService _authService;
  final ShareRecentsStore _recentsStore;
  final DmRepository _dmRepository;
  final ShortLinkClient? _shortLinkClient;

  List<ShareableUser> get recentlySharedWith =>
      _recentsStore.snapshot(_authService.currentPublicKeyHex ?? '');

  Future<void> warmRecents(String owner) => _recentsStore.warm(owner);

  Future<ShareResult> shareVideoWithUser({
    required VideoEvent video,
    required String recipientPubkey,
    String? personalMessage,
  }) async {
    final outcomes = await shareVideoWithMultipleUsers(
      video: video,
      recipientPubkeys: [recipientPubkey],
      personalMessage: personalMessage,
    );
    return outcomes[recipientPubkey.trim().toLowerCase()]!;
  }

  /// Queue the entire eligible fan-out before exposing any successful result.
  Future<Map<String, ShareResult>> shareVideoWithMultipleUsers({
    required VideoEvent video,
    required List<String> recipientPubkeys,
    String? personalMessage,
  }) async {
    final recipients = recipientPubkeys
        .map((key) => key.trim().toLowerCase())
        .toSet();
    Map<String, ShareResult> refuseAll(String reason) => {
      for (final key in recipients) key: ShareResult.failure(reason),
    };
    if (!_authService.isAuthenticated) {
      return refuseAll('User not authenticated');
    }
    if (!_authService.canPublishNostrWritesNow) {
      return refuseAll('Signing is not available yet');
    }
    final owner = _dmRepository.userPubkey;
    if (_authService.currentPublicKeyHex != owner) {
      return refuseAll('Account changed');
    }
    final identity = divineVideoShareIdentity(video);
    final outcomes = await _dmRepository.enqueueSharedVideoBatch(
      recipientPubkeys: recipients.toList(),
      baseContent: _createShareMessage(video, personalMessage),
      videoKind: identity.kind,
      videoAuthorPubkey: video.pubkey,
      videoDTag: identity.dTag,
      videoEventId: video.id,
      relayHint: video.sourceRelay,
    );
    final results = <String, ShareResult>{};
    for (final key in recipients) {
      final outcome = outcomes[key];
      results[key] = switch (outcome) {
        ShareEnqueueQueued(:final rumorId, :final conversationId) =>
          ShareResult.queued(rumorId, conversationId),
        ShareEnqueueRefused(:final reason) => ShareResult.failure(reason),
        ShareEnqueueBlocked() => const ShareResult.failure('Recipient blocked'),
        ShareEnqueueTooLong() => const ShareResult.failure('Message too long'),
        null => const ShareResult.failure('Recipient unavailable'),
      };
    }
    final queued = results.keys.where(
      (key) => results[key]!.delivery == ShareDelivery.queued,
    );
    if (_authService.currentPublicKeyHex == owner && queued.isNotEmpty) {
      unawaited(
        _recentsStore.recordQueued(owner, queued).catchError(
          (Object error, StackTrace stack) {
            Log.warning(
              'Could not update local share recents',
              name: 'VideoSharingService',
              category: LogCategory.video,
            );
          },
        ),
      );
    }
    return results;
  }

  /// External share URL for a video known only by its real `d` tag.
  ///
  /// Callers that hold a hydrated event should use [generateShareUrl]: a
  /// [VideoEvent.stableId] can be the event-id fallback, which this would
  /// encode as a `d` tag. This exists for the post-publish confirmation, which
  /// knows the freshly published video only by its `d` tag — seconds after
  /// publish the event is often not yet resolvable from Funnelcake or any
  /// relay. Without a hex [authorPubkey] the link falls back to the legacy
  /// `/video/<d tag>` shape; see [divineVideoShareUrl].
  static String shareUrlForStableId(
    String stableId, {
    required int kind,
    String? authorPubkey,
  }) => divineVideoShareUrl(stableId, authorPubkey: authorPubkey, kind: kind);

  /// Generate external share URL for the video.
  ///
  /// Addressable videos use `naddr`; regular events and videos without a
  /// real `d` tag use `nevent`.
  String generateShareUrl(VideoEvent video) =>
      divineVideoShareUrlForEvent(video);

  /// Shortens [url] for a link that leaves the app; message bodies and
  /// protocol payloads stay canonical.
  Future<String> shortenExternalUrl(String url) =>
      _shortLinkClient?.shorten(url) ?? Future.value(url);

  /// Generate share text for external sharing (social media, etc.)
  ///
  /// Returns only the share URL so users can add their own context.
  String generateShareText(VideoEvent video) {
    return generateShareUrl(video);
  }

  /// Generate structured share metadata for the platform share sheet.
  ///
  /// Returns a [ShareData] record containing the share URL, video title,
  /// and thumbnail URL so callers can build rich [ShareParams] with an
  /// attached image file.
  ShareData generateShareData(VideoEvent video) {
    return (
      shareUrl: generateShareUrl(video),
      title: video.title,
      thumbnailUrl: video.effectiveThumbnailUrl,
    );
  }

  /// Create the message content for sharing a video.
  ///
  /// Uses the canonical share URL for the video.
  String _createShareMessage(VideoEvent video, String? personalMessage) {
    final buffer = StringBuffer();

    if (personalMessage != null && personalMessage.isNotEmpty) {
      buffer.writeln(personalMessage);
      buffer.writeln();
    }

    if (video.title != null && video.title!.isNotEmpty) {
      buffer.writeln('"${video.title}"');
      buffer.writeln();
    }

    buffer.writeln(generateShareUrl(video));

    return buffer.toString();
  }
}

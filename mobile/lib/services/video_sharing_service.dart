// ABOUTME: Service for sharing videos with other users via Nostr DMs and social features
// ABOUTME: Handles sending videos to specific users and managing sharing options

import 'dart:async';

import 'package:dm_repository/dm_repository.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
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

/// Why a video share was not queued for one recipient.
enum ShareRefusal {
  /// No account is signed in.
  notAuthenticated,

  /// The account cannot sign yet, for example while a remote signer connects.
  signerUnavailable,

  /// The signed-in account changed before the batch was queued.
  accountChanged,

  /// The recipient fails the current outbound block or mute policy.
  blocked,

  /// The share is longer than one gift wrap can carry.
  tooLong,

  /// The DM repository refused the recipient before queueing: an invalid key,
  /// the sender themselves, or another local rule. The log carries the detail.
  recipientRefused,

  /// The recipient was left out of the batch, or the batch returned no outcome
  /// for them.
  unavailable,
}

/// The local outcome of queueing a video share for one recipient.
///
/// It says only whether the share reached the durable outgoing queue; whether
/// the recipient's relays accepted it is observed later through the delivery
/// state of [rumorId].
class ShareResult {
  /// The share is committed to the outgoing queue.
  const ShareResult.queued(String this.rumorId, String this.conversationId)
    : delivery = ShareDelivery.queued,
      refusal = null;

  /// Nothing was queued for this recipient, because of [refusal].
  const ShareResult.failure(ShareRefusal this.refusal)
    : delivery = ShareDelivery.notSent,
      rumorId = null,
      conversationId = null;

  /// Whether the share reached the outgoing queue.
  final ShareDelivery delivery;

  /// Why nothing was queued; null when [delivery] is [ShareDelivery.queued].
  final ShareRefusal? refusal;

  /// Stable id of the queued message, whose delivery state the sender
  /// watches; null when nothing was queued.
  final String? rumorId;

  /// The one-to-one conversation holding the queued message, used for "View
  /// chat"; null when nothing was queued.
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

  /// Queues one share of [video] to [recipientPubkey] and returns its outcome.
  ///
  /// A single-recipient [shareVideoWithMultipleUsers], with the same throws.
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

  /// Queues one share of [video] per recipient as a single local batch, and
  /// returns every outcome only once the whole batch is committed.
  ///
  /// Results are keyed by the trimmed, lower-cased [recipientPubkeys], so
  /// duplicates collapse. Each recipient left unqueued is logged with its
  /// reason. Queued recipients join the owner's share recents without delaying
  /// the result.
  ///
  /// Throws whatever [DmRepository.enqueueSharedVideoBatch] throws, such as
  /// [ShareSessionEndedException] when the account changes before the commit;
  /// nothing is queued then.
  Future<Map<String, ShareResult>> shareVideoWithMultipleUsers({
    required VideoEvent video,
    required List<String> recipientPubkeys,
    String? personalMessage,
  }) async {
    final recipients = recipientPubkeys
        .map((key) => key.trim().toLowerCase())
        .toSet();
    Map<String, ShareResult> refuseAll(ShareRefusal refusal) => _logged({
      for (final key in recipients) key: ShareResult.failure(refusal),
    });
    if (!_authService.isAuthenticated) {
      return refuseAll(ShareRefusal.notAuthenticated);
    }
    if (!_authService.canPublishNostrWritesNow) {
      return refuseAll(ShareRefusal.signerUnavailable);
    }
    final owner = _dmRepository.userPubkey;
    if (_authService.currentPublicKeyHex != owner) {
      return refuseAll(ShareRefusal.accountChanged);
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
    final results = _logged(
      {
        for (final key in recipients)
          key: switch (outcomes[key]) {
            ShareEnqueueQueued(:final rumorId, :final conversationId) =>
              ShareResult.queued(rumorId, conversationId),
            ShareEnqueueBlocked() => const ShareResult.failure(
              ShareRefusal.blocked,
            ),
            ShareEnqueueTooLong() => const ShareResult.failure(
              ShareRefusal.tooLong,
            ),
            ShareEnqueueRefused() => const ShareResult.failure(
              ShareRefusal.recipientRefused,
            ),
            null => const ShareResult.failure(ShareRefusal.unavailable),
          },
      },
      details: {
        for (final MapEntry(:key, :value) in outcomes.entries)
          if (value case ShareEnqueueRefused(:final reason)) key: reason,
      },
    );
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
              error: error,
              stackTrace: stack,
            );
          },
        ),
      );
    }
    return results;
  }

  /// Logs each recipient [results] left unqueued, then the batch totals.
  ///
  /// [details] holds the repository's own reason for a local refusal.
  Map<String, ShareResult> _logged(
    Map<String, ShareResult> results, {
    Map<String, String> details = const {},
  }) {
    var refused = 0;
    for (final MapEntry(key: recipient, value: result) in results.entries) {
      final refusal = result.refusal;
      if (refusal == null) continue;
      refused++;
      final detail = details[recipient];
      Log.warning(
        'Video share not queued for ${pubkeyForLogs(recipient)}: '
        '${refusal.name}${detail == null ? '' : ' ($detail)'}',
        name: 'VideoSharingService',
        category: LogCategory.video,
      );
    }
    Log.info(
      'Video share batch: ${results.length - refused} queued, '
      '$refused refused',
      name: 'VideoSharingService',
      category: LogCategory.video,
    );
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

  /// A short URL already available for this canonical external link.
  String? cachedShortUrl(String url) => _shortLinkClient?.cachedShortUrl(url);

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

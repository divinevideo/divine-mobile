// ABOUTME: Service for sharing videos with other users via Nostr DMs and social features
// ABOUTME: Handles sending videos to specific users and managing sharing options

import 'dart:async';

import 'package:dm_repository/dm_repository.dart';
import 'package:meta/meta.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
// `auth_service` exports an unrelated `UserProfile`; hide it so the models
// one (used by [ShareableUser.fromProfile]) resolves unambiguously.
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:profile_repository/profile_repository.dart';
import 'package:unified_logger/unified_logger.dart';

/// Represents a user that can receive shared videos
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
@immutable
class ShareableUser {
  const ShareableUser({
    required this.pubkey,
    this.displayName,
    this.handle,
    this.picture,
  });

  /// Builds a shareable user from a (possibly missing) [profile].
  ///
  /// Uses `displayNip05` — the full `@username.divine.video` form the
  /// find-people design calls for (Figma node `13945:91140`) — rather than
  /// `UserProfile.handle`, which shortens divine identifiers to `@username`
  /// and prefixes external ones into a doubled `@alice@example.com`. Falls
  /// back to the kind-0 `name`, then to `null` when the profile carries
  /// neither, so the row can drop its handle line entirely.
  factory ShareableUser.fromProfile(String pubkey, UserProfile? profile) {
    return ShareableUser(
      pubkey: pubkey,
      displayName: profile?.bestDisplayName,
      handle:
          _handleFromDisplayNip05(profile?.displayNip05) ??
          _handleFromName(profile?.name),
      picture: profile?.picture,
    );
  }

  /// [displayNip05] as a handle when it is already handle-shaped.
  static String? _handleFromDisplayNip05(String? displayNip05) {
    final trimmed = displayNip05?.trim();
    if (trimmed == null ||
        trimmed.isEmpty ||
        RegExp(r'\s').hasMatch(trimmed) ||
        !trimmed.contains('@') ||
        trimmed == '@') {
      return null;
    }
    return trimmed;
  }

  /// [name] as a handle: `@`-prefixed unless it already reads as one.
  ///
  /// A kind-0 `name` is free-form and often email-shaped
  /// (`dana@nostrplebs.com`) or already prefixed (`@dana`). Prefixing those
  /// would produce the doubled `@dana@nostrplebs.com` that this factory
  /// avoids for external NIP-05.
  static String? _handleFromName(String? name) {
    if (name == null || name.isEmpty) return null;
    final sanitized = UserProfile.sanitizeDisplayName(name);
    return sanitized.contains('@') ? sanitized : '@$sanitized';
  }

  final String pubkey;

  /// Populate from `UserProfile.bestDisplayName`, never the raw kind-0
  /// fields: this renders directly in the share sheet and find-people list,
  /// where a lone UTF-16 surrogate crashes the paragraph builder.
  final String? displayName;

  /// Handle for the user (e.g. `@alice.divine.video` or `alice@example.com`).
  ///
  /// Populate via [ShareableUser.fromProfile]. `null` means the profile has
  /// no `nip05` and no `name`, and the find-people row then renders no
  /// secondary line at all rather than falling back to an npub.
  final String? handle;
  final String? picture;

  /// Whether the share row has enough user-visible data for a recipient tile.
  bool get hasVisibleIdentity =>
      displayName != null || handle != null || picture != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShareableUser &&
          runtimeType == other.runtimeType &&
          pubkey == other.pubkey &&
          displayName == other.displayName &&
          handle == other.handle &&
          picture == other.picture;

  @override
  int get hashCode => Object.hash(pubkey, displayName, handle, picture);
}

/// Structured share metadata for the platform share sheet.
///
/// Contains all the information needed to build a rich [ShareParams].
typedef ShareData = ({String shareUrl, String? title, String? thumbnailUrl});

/// Result of sharing operation
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class ShareResult {
  const ShareResult({
    required this.success,
    this.error,
    this.messageEventId,
    this.conversationId,
  });
  final bool success;
  final String? error;
  final String? messageEventId;

  /// The DM conversation ID (NIP-17), used for "View Chat" navigation.
  final String? conversationId;

  factory ShareResult.createSuccess(
    String messageEventId, {
    String? conversationId,
  }) => ShareResult(
    success: true,
    messageEventId: messageEventId,
    conversationId: conversationId,
  );

  factory ShareResult.failure(String error) =>
      ShareResult(success: false, error: error);
}

/// Service for sharing videos with other users
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class VideoSharingService {
  VideoSharingService({
    required NostrClient nostrService,
    required AuthService authService,
    required ProfileReader profileRepository,
    DmRepository? dmRepository,
  }) : _nostrService = nostrService,
       _authService = authService,
       _profileRepository = profileRepository,
       _dmRepository = dmRepository;
  final NostrClient _nostrService;
  final AuthService _authService;
  final ProfileReader _profileRepository;
  final DmRepository? _dmRepository;

  final List<ShareableUser> _recentlySharedWith = [];
  final Map<String, DateTime> _shareHistory = {};

  // Getters
  List<ShareableUser> get recentlySharedWith =>
      List.unmodifiable(_recentlySharedWith);

  /// Share a video with a specific user via Nostr DM.
  ///
  /// When a [DmRepository] is available (user is authenticated with NIP-17),
  /// uses gift-wrapped encrypted DMs (kind 14/13/1059). Otherwise falls back
  /// to legacy NIP-04 encrypted DMs (kind 4).
  Future<ShareResult> shareVideoWithUser({
    required VideoEvent video,
    required String recipientPubkey,
    String? personalMessage,
  }) async {
    try {
      Log.debug(
        'Sharing video with user: ${pubkeyForLogs(recipientPubkey)}',
        name: 'VideoSharingService',
        category: LogCategory.video,
      );

      if (!_authService.isAuthenticated) {
        return ShareResult.failure('User not authenticated');
      }

      // Explicit publish-readiness gate. This service used to inherit one by
      // accident: it was built from the relay-gated profile repository, so a
      // not-yet-ready session made the whole service — and therefore the
      // share sheet — null. That turned Share into a silent dead tap for the
      // entire cold-start window. The sheet now opens on the read-only
      // handle, so the send path has to state the requirement itself (#6423).
      if (!_authService.canPublishNostrWritesNow) {
        return ShareResult.failure('Signing is not available yet');
      }

      final dmContent = _createShareMessage(video, personalMessage);

      // Prefer NIP-17 when DmRepository is available. `await` (not a bare
      // `return`) so an async throw from the send is caught here and mapped
      // to a ShareResult.failure instead of escaping to the fan-out loop and
      // aborting the remaining recipients.
      if (_dmRepository != null) {
        return await _shareViaNip17(
          video: video,
          recipientPubkey: recipientPubkey,
          content: dmContent,
        );
      }

      // Fallback to NIP-04 (legacy)
      return await _shareViaNip04(
        video: video,
        recipientPubkey: recipientPubkey,
        content: dmContent,
      );
    } catch (e) {
      Log.error(
        'Error sharing video: $e',
        name: 'VideoSharingService',
        category: LogCategory.video,
      );
      return ShareResult.failure('Error sharing video: $e');
    }
  }

  Future<ShareResult> _shareViaNip17({
    required VideoEvent video,
    required String recipientPubkey,
    required String content,
  }) async {
    final dmRepo = _dmRepository!;
    final result = await dmRepo.sendSharedVideo(
      recipientPubkey: recipientPubkey,
      baseContent: content,
      videoKind: video.shareKind,
      videoAuthorPubkey: video.pubkey,
      videoDTag: video.vineId,
      videoEventId: video.id,
      relayHint: video.sourceRelay,
      // A shared video is a NIP-17-native action. Skip the plaintext kind-4
      // fallback so we don't publish the sender↔recipient link and real
      // timestamp in the clear on the (unauthenticated) relay — which would
      // defeat NIP-17's metadata protection for exactly this message — and so
      // NIP-17 and NIP-04 copies can't render as a duplicate on the recipient.
      skipNip04Fallback: true,
    );

    // Soft-unconfirmed sends stay in the durable queue and render like the
    // ordinary DM optimistic bubble. Use that queue handle as the share result
    // identity so the sheet reports success without minting a second rumor.
    final optimisticMessageId = result.success
        ? result.messageEventId
        : result.retryablePending
        ? result.queuedRumorId
        : null;
    if (optimisticMessageId != null) {
      _shareHistory[recipientPubkey] = DateTime.now();
      // Fire-and-forget: this only refreshes the in-memory recents list for
      // the next share-sheet open. Awaiting it kept the success toast waiting
      // on a 5s-timeout profile fetch for no user-visible benefit. It
      // self-catches its own errors. See #5391.
      unawaited(_updateRecentlySharedWith(recipientPubkey));

      final participants = [dmRepo.userPubkey, recipientPubkey]..sort();
      final conversationId = DmRepository.computeConversationId(participants);

      Log.info(
        'Video shared via NIP-17: ${result.messageEventId}',
        name: 'VideoSharingService',
        category: LogCategory.video,
      );

      return ShareResult.createSuccess(
        optimisticMessageId,
        conversationId: conversationId,
      );
    }

    return ShareResult.failure(result.error ?? 'Failed to send NIP-17 message');
  }

  Future<ShareResult> _shareViaNip04({
    required VideoEvent video,
    required String recipientPubkey,
    required String content,
  }) async {
    final tags = <List<String>>[
      ['p', recipientPubkey],
      ['e', video.id],
    ];

    final event = await _authService.createAndSignEvent(
      kind: 4,
      content: content,
      tags: tags,
    );

    if (event == null) {
      return ShareResult.failure('Failed to create share message');
    }

    final sentEvent = await _nostrService.publishEvent(event);

    final failureReason = sentEvent.failureReason;
    if (failureReason != null) {
      Log.error(
        'Failed to publish NIP-04 share message: $failureReason',
        name: 'VideoSharingService',
        category: LogCategory.video,
      );
      return ShareResult.failure('Failed to publish share message');
    }

    final success = sentEvent as PublishSuccess;
    _shareHistory[recipientPubkey] = DateTime.now();
    await _updateRecentlySharedWith(recipientPubkey);

    Log.info(
      'Video shared via NIP-04: ${event.id}',
      name: 'VideoSharingService',
      category: LogCategory.video,
    );

    return ShareResult.createSuccess(success.event.id);
  }

  /// Share video to multiple users at once
  Future<Map<String, ShareResult>> shareVideoWithMultipleUsers({
    required VideoEvent video,
    required List<String> recipientPubkeys,
    String? personalMessage,
  }) async {
    final results = <String, ShareResult>{};

    // Sequential (not parallel) so N recipients' gift-wrap publishes are spaced
    // out under the relay's per-connection burst limit. Each iteration is
    // guarded so one recipient's failure — or an unexpected throw — becomes a
    // failure entry for that recipient instead of aborting the remaining sends.
    for (final pubkey in recipientPubkeys) {
      try {
        results[pubkey] = await shareVideoWithUser(
          video: video,
          recipientPubkey: pubkey,
          personalMessage: personalMessage,
        );
      } catch (e) {
        Log.error(
          'Failed to share video with ${pubkeyForLogs(pubkey)}: $e',
          name: 'VideoSharingService',
          category: LogCategory.video,
        );
        results[pubkey] = ShareResult.failure('Error sharing video: $e');
      }
    }

    return results;
  }

  /// Generate external share URL from a [VideoEvent.stableId].
  ///
  /// Callers that hold a hydrated event should use [generateShareUrl]. This
  /// exists for the post-publish confirmation, which knows the freshly
  /// published video only by its `d` tag — seconds after publish the event
  /// is often not yet resolvable from Funnelcake or any relay.
  static String shareUrlForStableId(String stableId) =>
      'https://divine.video/video/$stableId';

  /// Generate external share URL for the video.
  ///
  /// Always emits an `https://divine.video/video/...` URL. The route accepts
  /// raw event IDs, d-tags, and NIP-19 references, and [VideoEvent.stableId]
  /// falls back to the event ID when a `d` tag is missing — so this never
  /// returns a non-routable URL.
  String generateShareUrl(VideoEvent video) =>
      shareUrlForStableId(video.stableId);

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

  /// Check if user has been shared with recently
  bool hasSharedWithRecently(String pubkey) {
    final lastShared = _shareHistory[pubkey];
    if (lastShared == null) return false;

    final daysSinceShared = DateTime.now().difference(lastShared).inDays;
    return daysSinceShared < 7; // Consider "recent" as within 7 days
  }

  /// Get sharing statistics
  Map<String, dynamic> getSharingStats() {
    final totalShares = _shareHistory.length;
    final recentShares = _shareHistory.values
        .where((date) => DateTime.now().difference(date).inDays <= 30)
        .length;

    return {
      'totalShares': totalShares,
      'recentShares': recentShares,
      'uniqueRecipients': _shareHistory.keys.length,
      'averageSharesPerMonth': recentShares, // Simplified calculation
    };
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

  /// Update recently shared with list
  Future<void> _updateRecentlySharedWith(String pubkey) async {
    try {
      // Remove if already in list
      _recentlySharedWith.removeWhere((user) => user.pubkey == pubkey);

      // Fetch user profile for display
      final profile = await _profileRepository.fetchFreshProfile(
        pubkey: pubkey,
      );

      // Add to front of list
      _recentlySharedWith.insert(0, ShareableUser.fromProfile(pubkey, profile));

      // Keep only recent 10 users
      if (_recentlySharedWith.length > 10) {
        _recentlySharedWith.removeRange(10, _recentlySharedWith.length);
      }
    } catch (e) {
      Log.error(
        'Failed to update recently shared with: $e',
        name: 'VideoSharingService',
        category: LogCategory.video,
      );
    }
  }

  /// Clear sharing history (for privacy)
  void clearSharingHistory() {
    _shareHistory.clear();
    _recentlySharedWith.clear();

    Log.debug(
      '🧹 Cleared sharing history',
      name: 'VideoSharingService',
      category: LogCategory.video,
    );
  }
}

// ABOUTME: Service for sharing videos with other users via Nostr DMs and social features
// ABOUTME: Handles sending videos to specific users and managing sharing options

import 'dart:async';

import 'package:dm_repository/dm_repository.dart';
import 'package:meta/meta.dart';
import 'package:models/models.dart';
// `auth_service` exports an unrelated `UserProfile`; hide it so the models
// one (used by [ShareableUser.fromProfile]) resolves unambiguously.
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/services/short_link_client.dart';
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
    required ProfileReader profileRepository,
    required DmRepository dmRepository,
    ShortLinkClient? shortLinkClient,
  }) : _authService = authService,
       _profileRepository = profileRepository,
       _dmRepository = dmRepository,
       _shortLinkClient = shortLinkClient;
  final AuthService _authService;
  final ProfileReader _profileRepository;
  final DmRepository _dmRepository;
  final ShortLinkClient? _shortLinkClient;

  final List<ShareableUser> _recentlySharedWith = [];
  final Map<String, DateTime> _shareHistory = {};

  // Getters
  List<ShareableUser> get recentlySharedWith =>
      List.unmodifiable(_recentlySharedWith);

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
      if (outcome is ShareEnqueueQueued &&
          _authService.currentPublicKeyHex == owner) {
        _shareHistory[key] = DateTime.now();
        unawaited(_updateRecentlySharedWith(owner, key));
      }
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
  Future<void> _updateRecentlySharedWith(String owner, String pubkey) async {
    try {
      // Remove if already in list
      _recentlySharedWith.removeWhere((user) => user.pubkey == pubkey);

      // Fetch user profile for display
      final profile = await _profileRepository.fetchFreshProfile(
        pubkey: pubkey,
      );

      if (_authService.currentPublicKeyHex != owner) return;
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

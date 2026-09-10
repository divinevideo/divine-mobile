// ABOUTME: Repository for managing NIP-22 text comments and video replies.
// ABOUTME: Provides loading, posting, and streaming of threaded comments.
// ABOUTME: Uses NostrClient for relay operations and organizes comments
// chronologically.

import 'dart:async';

import 'package:comments_repository/src/blocked_comment_filter.dart';
import 'package:comments_repository/src/exceptions.dart';
import 'package:comments_repository/src/models/models.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

/// Kind 1111 is the NIP-22 comment kind for replying to non-Kind-1 events.
const int _commentKind = EventKind.comment;

/// Kind 5 is the NIP-09 deletion request kind.
const int _deletionKind = EventKind.eventDeletion;

/// Default limit for comment queries.
const _defaultLimit = 100;

/// Relay hint used for diVine mention `p` tags.
const _divineRelayHint = 'wss://relay.divine.video';

final _hexPubkeyPattern = RegExp(r'^[0-9a-fA-F]{64}$');

List<int> _threadKinds({required bool includeVideoReplies}) => [
  _commentKind,
  if (includeVideoReplies) EventKind.videoVertical,
];

List<List<String>> _buildMentionTags({
  required Iterable<String> mentionedPubkeys,
  required Iterable<String> excludedPubkeys,
}) {
  final seenPubkeys = <String>{
    for (final pubkey in excludedPubkeys) pubkey.trim().toLowerCase(),
  };
  final tags = <List<String>>[];

  for (final pubkey in mentionedPubkeys) {
    final normalizedPubkey = pubkey.trim().toLowerCase();
    if (!_hexPubkeyPattern.hasMatch(normalizedPubkey)) continue;
    if (!seenPubkeys.add(normalizedPubkey)) continue;

    tags.add(['p', normalizedPubkey, _divineRelayHint, 'mention']);
  }

  return tags;
}

/// Repository for managing comments and video replies on Nostr events.
///
/// This repository provides a unified interface for:
/// - Loading comments with thread structure
/// - Watching real-time comment streams
/// - Posting new comments and replies
/// - Counting comments on events
///
/// Comments use NIP-22 threading with uppercase/lowercase tags:
/// - Uppercase tags (`E`, `K`, `P`): Point to the root scope (e.g., video)
/// - Lowercase tags (`e`, `k`, `p`): Point to the parent item (for replies)
class CommentsRepository {
  /// Creates a new comments repository.
  ///
  /// Parameters:
  /// - [nostrClient]: Client for Nostr relay communication (handles signing)
  /// - [clock]: Injectable time source for the recently-posted-comment
  ///   self-heal window (see [_recentlyPostedComments]). Defaults to
  ///   [DateTime.now]; override in tests for deterministic TTL behaviour.
  CommentsRepository({
    required NostrClient nostrClient,
    FunnelcakeApiClient? funnelcakeApiClient,
    BlockedCommentFilter? blockFilter,
    DateTime Function()? clock,
  }) : _nostrClient = nostrClient,
       _funnelcakeApiClient = funnelcakeApiClient,
       _blockFilter = blockFilter,
       _now = clock ?? DateTime.now;

  final NostrClient _nostrClient;
  final FunnelcakeApiClient? _funnelcakeApiClient;
  final BlockedCommentFilter? _blockFilter;
  final DateTime Function() _now;

  /// In-memory cache of comment counts keyed by root event ID.
  ///
  /// Prevents redundant relay queries when the same video is scrolled
  /// back into view. Adjusted on post/delete, and automatically updated
  /// when [loadComments] receives an authoritative total count from the
  /// server or relay (so callers never need to push counts back in).
  final Map<String, int> _commentCountCache = {};

  /// Companion cache keyed by NIP-71 addressable id (`kind:pubkey:d-tag`).
  ///
  /// For addressable video events (Kind 30000-39999), a metadata edit
  /// publishes a replacement event with a new `id` but the same address.
  /// Keying [_commentCountCache] purely by the volatile event id loses
  /// the carried count on every edit and forces a relay re-query whose
  /// NIP-45 COUNT on `#A` for kind 1111 can transiently return 0 (mirror
  /// of the kind-7 issue in #4432). This companion cache lets a fresh
  /// [getCommentsCount] for the new event id reuse the prior count via
  /// the stable address.
  ///
  /// All writes are dual-keyed via [_writeCachedCommentCount] when a
  /// `rootAddressableId` is in scope; reads check this map when the
  /// event-id cache misses ([_readCachedCommentCount]).
  final Map<String, int> _commentCountCacheByAddressableId = {};

  /// Comments this user has just posted, retained briefly so the user's own
  /// comment stays visible when the comment sheet is reopened before the
  /// Funnelcake REST index (the primary read source in [loadComments]) has
  /// ingested it. Keyed by root event id.
  ///
  /// Issue #5598 (recurrence of #211): a comment publishes to relays
  /// instantly, but [loadComments] reads REST-first and only falls back to
  /// relays when REST is unavailable. A stale-but-non-empty REST response
  /// short-circuits, so a fresh read after posting omits the user's own
  /// comment until the index catches up. Entries are merged into read results
  /// and pruned once the fetched thread contains them or after
  /// [_recentlyPostedRetention].
  final Map<String, List<_RecentlyPostedComment>> _recentlyPostedComments = {};

  /// How long a just-posted comment is retained for the self-heal merge before
  /// it is assumed stale. Long enough to cover worst-case REST index lag, short
  /// enough that a never-indexed comment (relay-rejected, or deleted from
  /// another client) cannot linger locally indefinitely.
  static const _recentlyPostedRetention = Duration(minutes: 10);

  /// Subscription ID for the active comment watch, if any.
  String? _watchSubscriptionId;

  /// Default page size for author comment queries.
  static const _authorCommentsLimit = 50;

  /// Loads comments for a root event and returns them in a flat list.
  ///
  /// This is a one-shot query that returns all comments organized
  /// chronologically (newest first) with reply relationships maintained
  /// through each Comment's replyToEventId field.
  ///
  /// Parameters:
  /// - [rootEventId]: The ID of the event to load comments for
  /// - [rootEventKind]: The kind of the root event (e.g., 34236 for videos)
  /// - [rootAddressableId]: Optional addressable identifier for the root event
  ///   (format: `kind:pubkey:d-tag`). When provided, queries by both E and A
  ///   tags to find comments that reference the event by either identifier.
  ///   This is important for Kind 34236 addressable events where some clients
  ///   may use E tags and others may use A tags.
  /// - [limit]: Maximum number of comments to fetch (default: 100)
  /// - [before]: Cursor for pagination - fetch comments created
  ///   before this time.
  ///   Note: Nostr `until` filter is inclusive, so subtract 1 second from the
  ///   oldest loaded comment's timestamp when paginating.
  ///
  /// Returns a [CommentThread] containing:
  /// - All comments in chronological order
  /// - Comment cache for quick lookup by ID
  /// - Total comment count
  ///
  /// Throws [LoadCommentsFailedException] if the query fails.
  Future<CommentThread> loadComments({
    required String rootEventId,
    required int rootEventKind,
    String? rootAddressableId,
    int limit = _defaultLimit,
    DateTime? before,
    int offset = 0,
    bool includeVideoReplies = false,
  }) async {
    try {
      if (before == null && (_funnelcakeApiClient?.isAvailable ?? false)) {
        try {
          final response = await _funnelcakeApiClient!.getVideoComments(
            videoId: rootEventId,
            limit: limit,
            offset: offset,
            // Skip the un-purged edge cache while the local user has a
            // just-posted comment/reply for this video, so a post-action
            // reload reflects it (and other fresh comments) instead of a
            // stale ~120s cached list. Self-clears once the pending set
            // prunes. Other viewers still need a backend surrogate purge.
            cacheBustToken: _commentsCacheBustToken(rootEventId),
          );
          if (response != null) {
            final restThread = _buildThreadFromRestComments(
              response,
              rootEventId,
              rootEventKind,
              rootAddressableId: rootAddressableId,
            );
            // Merge the user's own just-posted comment when the REST index has
            // not yet ingested it, so a sheet reopen doesn't drop it (#5598).
            final thread = _mergeRecentlyPostedComments(
              restThread,
              rootEventId,
            );
            if (thread.hasExactTotal) {
              // Auto-update the count cache with the authoritative REST total.
              // Zero is written too so a previously cached positive value
              // can't outlive the comments it counted — important with the
              // addressable-id companion cache, which would otherwise serve
              // that stale positive for the post-edit event id.
              _writeCachedCommentCount(
                rootEventId,
                thread.totalCount,
                rootAddressableId: rootAddressableId,
              );
            }
            return _filterThread(thread);
          }
        } on FunnelcakeException {
          // Fall back to relay query when REST bootstrap is unavailable.
        }
      }

      final untilTimestamp = before != null
          ? before.millisecondsSinceEpoch ~/ 1000
          : null;

      // NIP-22: Filter by Kind 1111 and uppercase E tag for root scope
      final filterByE = Filter(
        kinds: _threadKinds(includeVideoReplies: includeVideoReplies),
        uppercaseE: [rootEventId],
        limit: limit,
        until: untilTimestamp,
      );

      CommentThread thread;

      // If we have an addressable ID, also query by uppercase A tag
      // Some clients may reference addressable events using A instead of E
      if (rootAddressableId != null && rootAddressableId.isNotEmpty) {
        final filterByA = Filter(
          kinds: _threadKinds(includeVideoReplies: includeVideoReplies),
          uppercaseA: [rootAddressableId],
          limit: limit,
          until: untilTimestamp,
        );

        // Run both queries in parallel and merge results
        final results = await Future.wait([
          _nostrClient.queryEvents([filterByE]),
          _nostrClient.queryEvents([filterByA]),
        ]);

        // Merge and deduplicate by event ID
        final eventMap = <String, Event>{};
        for (final event in results[0]) {
          eventMap[event.id] = event;
        }
        for (final event in results[1]) {
          eventMap[event.id] = event;
        }

        thread = _buildThreadFromEvents(
          eventMap.values.toList(),
          rootEventId,
          rootEventKind,
          rootAddressableId: rootAddressableId,
        );
      } else {
        // No addressable ID - just query by E tag
        final events = await _nostrClient.queryEvents([filterByE]);
        thread = _buildThreadFromEvents(
          events,
          rootEventId,
          rootEventKind,
        );
      }

      // Merge the user's own just-posted comment on first-page loads when the
      // relay query has not yet returned it, mirroring the REST path (#5598).
      if (before == null) {
        thread = _mergeRecentlyPostedComments(thread, rootEventId);
      }

      // Auto-update the count cache with the authoritative total so that
      // callers (e.g. VideoInteractionsBloc) don't need to push counts back
      // into the repository manually. Pagination (`before != null`) returns
      // a slice rather than the full total, so the guard stays. Zero is
      // written on a first-page result: trusting it for the empty UI but
      // distrusting it for the cache would let the addressable-id companion
      // serve a stale positive across a metadata edit.
      if (before == null) {
        _writeCachedCommentCount(
          rootEventId,
          thread.totalCount,
          rootAddressableId: rootAddressableId,
        );
      }

      return _filterThread(thread);
    } on Exception catch (e) {
      throw LoadCommentsFailedException('Failed to load comments: $e');
    }
  }

  /// Posts a new comment using NIP-22 format.
  ///
  /// Creates a Kind 1111 event with proper NIP-22 threading tags
  /// and broadcasts it to relays.
  ///
  /// Parameters:
  /// - [content]: The comment text
  /// - [rootEventId]: The ID of the root event (e.g., video)
  /// - [rootEventKind]: The kind of the root event (e.g., 34236)
  /// - [rootEventAuthorPubkey]: Public key of the root event author
  /// - [rootAddressableId]: Optional addressable identifier for the root event
  ///   (format: `kind:pubkey:d-tag`). When provided, includes both E and A tags
  ///   to ensure the comment can be found by clients querying either way.
  /// - [replyToEventId]: ID of parent comment (for nested replies)
  /// - [replyToAuthorPubkey]: Public key of parent comment author
  /// - [mentionedPubkeys]: Optional full hex pubkeys to publish as generic
  ///   mention `p` tags.
  ///
  /// Returns the created [Comment] with its event ID.
  ///
  /// Throws [InvalidCommentContentException] if content is empty.
  /// Throws [PostCommentFailedException] if broadcasting fails.
  Future<Comment> postComment({
    required String content,
    required String rootEventId,
    required int rootEventKind,
    required String rootEventAuthorPubkey,
    String? rootAddressableId,
    String? replyToEventId,
    String? replyToAuthorPubkey,
    List<String> mentionedPubkeys = const [],
  }) async {
    final trimmedContent = content.trim();
    if (trimmedContent.isEmpty) {
      throw const InvalidCommentContentException('Comment cannot be empty');
    }

    // Build tags for NIP-22 threading
    // Uppercase tags point to root scope, lowercase to parent item
    final tags = <List<String>>[
      // Root scope tags (uppercase) - always point to the original event
      ['E', rootEventId, '', rootEventAuthorPubkey],
      // Include A tag for addressable events (Kind 30000-39999)
      // This ensures comments can be found by clients querying by either E or A
      // NIP-22: A tags use 3 elements [A, address, relay_hint]
      if (rootAddressableId != null && rootAddressableId.isNotEmpty)
        ['A', rootAddressableId, ''],
      ['K', rootEventKind.toString()],
      ['P', rootEventAuthorPubkey],
      // Parent item tags (lowercase)
      if (replyToEventId != null && replyToAuthorPubkey != null) ...[
        // Replying to another comment
        ['e', replyToEventId, '', replyToAuthorPubkey],
        ['k', _commentKind.toString()],
        ['p', replyToAuthorPubkey],
      ] else ...[
        // Top-level comment - parent is the same as root
        ['e', rootEventId, '', rootEventAuthorPubkey],
        // Include lowercase 'a' tag for addressable events too
        // NIP-22: a tags use 3 elements [a, address, relay_hint]
        if (rootAddressableId != null && rootAddressableId.isNotEmpty)
          ['a', rootAddressableId, ''],
        ['k', rootEventKind.toString()],
        ['p', rootEventAuthorPubkey],
      ],
      ..._buildMentionTags(
        mentionedPubkeys: mentionedPubkeys,
        excludedPubkeys: [
          rootEventAuthorPubkey,
          ?replyToAuthorPubkey,
        ],
      ),
    ];

    // Create the event
    final event = Event(
      _nostrClient.publicKey,
      _commentKind,
      tags,
      trimmedContent,
    );

    try {
      // Broadcast the event (NostrClient handles signing)
      final result = await _nostrClient.publishEvent(event);

      if (result is! PublishSuccess) {
        throw const PostCommentFailedException('Failed to publish comment');
      }
      final sentEvent = result.event;

      _adjustCachedCommentCount(
        rootEventId,
        1,
        rootAddressableId: rootAddressableId,
      );
      final videoMetadata = _parseVideoMetadataFromImetaTags(sentEvent.tags);

      final comment = Comment(
        id: sentEvent.id,
        content: trimmedContent,
        authorPubkey: sentEvent.pubkey,
        createdAt: sentEvent.createdAtDateTime,
        rootEventId: rootEventId,
        rootAuthorPubkey: rootEventAuthorPubkey,
        rootAddressableId: rootAddressableId,
        replyToEventId: replyToEventId,
        replyToAuthorPubkey: replyToAuthorPubkey,
        videoUrl: videoMetadata.videoUrl,
        thumbnailUrl: videoMetadata.thumbnailUrl,
        videoDimensions: videoMetadata.videoDimensions,
        videoDuration: videoMetadata.videoDuration,
        videoBlurhash: videoMetadata.videoBlurhash,
      );

      // Retain so a comment-sheet reopen shows the user's own comment even
      // while the REST read source has not yet indexed it (#5598).
      _recordRecentlyPostedComment(rootEventId, comment);

      return comment;
    } on CommentsRepositoryException {
      rethrow;
    } on Exception catch (e) {
      throw PostCommentFailedException('Failed to post comment: $e');
    }
  }

  /// Gets the comment count for an event from NIP-45 COUNT requests.
  ///
  /// Parameters:
  /// - [rootEventId]: The ID of the event to count comments for
  /// - [rootAddressableId]: Optional addressable identifier for the root event
  ///   (format: `kind:pubkey:d-tag`). When provided, counts comments from both
  ///   E and A tag queries to get an accurate total.
  /// - [includeVideoReplies]: Whether to include Kind 34236 video replies in
  ///   the count. Defaults to `false` so flag-off callers do not inflate the
  ///   comment badge with reply-only videos.
  ///
  /// Returns the number of comments on the event, or `null` when the count is
  /// unknown because a relay did not answer. When both the E and A counts are
  /// needed and only one answers, the result is `null` too: the answer is the
  /// larger of the two, and one side alone is only a floor. Nothing is cached
  /// for an unknown count, so the next call asks again.
  ///
  /// Throws [CountCommentsFailedException] if counting fails for any other
  /// reason.
  Future<int?> getCommentsCount(
    String rootEventId, {
    String? rootAddressableId,
    bool includeVideoReplies = false,
  }) async {
    final cached = _readCachedCommentCount(
      rootEventId,
      rootAddressableId: rootAddressableId,
    );
    if (cached != null) return cached;

    try {
      // NIP-22: Filter by Kind 1111 and uppercase E tag
      final filterByE = Filter(
        kinds: _threadKinds(includeVideoReplies: includeVideoReplies),
        uppercaseE: [rootEventId],
      );

      int count;

      // If we have an addressable ID, also query by uppercase A tag
      if (rootAddressableId != null && rootAddressableId.isNotEmpty) {
        final filterByA = Filter(
          kinds: _threadKinds(includeVideoReplies: includeVideoReplies),
          uppercaseA: [rootAddressableId],
        );

        // Run both COUNT queries in parallel
        // Note: This may over-count if a comment has both E and A tags,
        // but that's rare and the count is still useful for UI purposes.
        // For exact count, use loadComments which deduplicates.
        final results = await Future.wait([
          _nostrClient.countEvents([filterByE]),
          _nostrClient.countEvents([filterByA]),
        ]);

        // Return the maximum of the two counts
        // (since comments should have at least one of these tags)
        final countByE = results[0].count;
        final countByA = results[1].count;
        count = countByE > countByA ? countByE : countByA;
      } else {
        final result = await _nostrClient.countEvents([filterByE]);
        count = result.count;
      }

      _writeCachedCommentCount(
        rootEventId,
        count,
        rootAddressableId: rootAddressableId,
      );
      return count;
    } on CountUnavailableException {
      return null;
    } on Exception catch (e) {
      throw CountCommentsFailedException('Failed to count comments: $e');
    }
  }

  /// Updates the cached comment count for a root event.
  ///
  /// Called by the UI layer (e.g. after the comments sheet is dismissed)
  /// to keep the cache in sync with the authoritative count from the
  /// loaded comment thread. This avoids a stale NIP-45 COUNT when the
  /// user scrolls back to the same video.
  ///
  /// Pass [rootAddressableId] for addressable videos so the count
  /// survives a future metadata edit that changes the event id.
  void updateCachedCommentCount(
    String rootEventId,
    int count, {
    String? rootAddressableId,
  }) {
    _writeCachedCommentCount(
      rootEventId,
      count,
      rootAddressableId: rootAddressableId,
    );
  }

  /// Clears the in-memory comment count cache and the recently-posted-comment
  /// self-heal buffer.
  ///
  /// Should be called on logout so stale counts and a previous user's pending
  /// comments are not served after re-login.
  void clearCommentCountCache() {
    _commentCountCache.clear();
    _commentCountCacheByAddressableId.clear();
    _recentlyPostedComments.clear();
  }

  /// Reads the cached comment count, checking event-id first then the
  /// addressable-id companion cache. Returns `null` on a full miss.
  int? _readCachedCommentCount(
    String rootEventId, {
    String? rootAddressableId,
  }) {
    final byEventId = _commentCountCache[rootEventId];
    if (byEventId != null) return byEventId;
    if (rootAddressableId == null || rootAddressableId.isEmpty) return null;
    return _commentCountCacheByAddressableId[rootAddressableId];
  }

  /// Writes [count] into both caches when [rootAddressableId] is provided.
  /// Otherwise writes only the event-id cache.
  void _writeCachedCommentCount(
    String rootEventId,
    int count, {
    String? rootAddressableId,
  }) {
    _commentCountCache[rootEventId] = count;
    if (rootAddressableId != null && rootAddressableId.isNotEmpty) {
      _commentCountCacheByAddressableId[rootAddressableId] = count;
    }
  }

  /// Adjusts the cached comment count by [delta] (clamped at zero),
  /// dual-writing both caches. No-op if neither cache has a baseline
  /// value yet — an isolated delta without a known total would lie.
  void _adjustCachedCommentCount(
    String rootEventId,
    int delta, {
    String? rootAddressableId,
  }) {
    final current = _readCachedCommentCount(
      rootEventId,
      rootAddressableId: rootAddressableId,
    );
    if (current == null) return;
    final updated = current + delta;
    _writeCachedCommentCount(
      rootEventId,
      updated < 0 ? 0 : updated,
      rootAddressableId: rootAddressableId,
    );
  }

  /// Returns a cache-bust token for [rootEventId]'s comments REST read, or
  /// `null` when the local user has no recently-posted comment for the video.
  ///
  /// The token is the newest retained post time (microseconds), so it is stable
  /// across reads within a post window (the edge can still cache that variant)
  /// and changes when a newer comment is posted. Once [_recentlyPostedComments]
  /// prunes (merged in or older than [_recentlyPostedRetention]), it returns
  /// `null` and reads fall back to the normal cached URL (#5854).
  String? _commentsCacheBustToken(String rootEventId) {
    final pending = _recentlyPostedComments[rootEventId];
    if (pending == null || pending.isEmpty) return null;
    final latestMicros = pending
        .map((p) => p.postedAt.microsecondsSinceEpoch)
        .reduce((a, b) => a > b ? a : b);
    return latestMicros.toString();
  }

  /// Records a just-posted [comment] so [loadComments] can keep it visible on
  /// a comment-sheet reopen while the REST read source catches up (#5598).
  void _recordRecentlyPostedComment(String rootEventId, Comment comment) {
    _recentlyPostedComments.putIfAbsent(rootEventId, () => [])
      ..removeWhere((p) => p.comment.id == comment.id)
      ..add(_RecentlyPostedComment(comment, _now()));
  }

  /// Merges any retained just-posted comments for [rootEventId] into [thread]
  /// when the fetched thread does not already contain them (#5598).
  ///
  /// Self-pruning: entries already present in [thread] (the backend caught up)
  /// or older than [_recentlyPostedRetention] are dropped. Deduplication is by
  /// event id, so a later relay echo or REST refresh cannot create a duplicate
  /// row. [CommentThread.totalCount] is bumped by the number of injected
  /// comments so the count badge stays consistent with the rendered list.
  CommentThread _mergeRecentlyPostedComments(
    CommentThread thread,
    String rootEventId,
  ) {
    final pending = _recentlyPostedComments[rootEventId];
    if (pending == null || pending.isEmpty) return thread;

    final now = _now();
    pending
      ..removeWhere(
        (p) => now.difference(p.postedAt) > _recentlyPostedRetention,
      )
      ..removeWhere((p) => thread.commentCache.containsKey(p.comment.id));

    if (pending.isEmpty) {
      _recentlyPostedComments.remove(rootEventId);
      return thread;
    }

    final mergedCache = <String, Comment>{
      ...thread.commentCache,
      for (final p in pending) p.comment.id: p.comment,
    };
    final mergedComments = mergedCache.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return thread.copyWith(
      comments: mergedComments,
      commentCache: Map<String, Comment>.unmodifiable(mergedCache),
      totalCount: thread.totalCount + pending.length,
    );
  }

  /// Deletes a comment by publishing a NIP-09 deletion request.
  ///
  /// Creates a Kind 5 event with an `e` tag referencing the comment
  /// and a `k` tag specifying the comment kind (1111).
  ///
  /// Parameters:
  /// - [commentId]: The ID of the comment event to delete
  /// - [rootEventId]: Optional root event ID. When provided, the cached
  ///   comment count for that root event is decremented so subsequent
  ///   [getCommentsCount] calls return the correct value.
  /// - [rootAddressableId]: Optional addressable id of the root event.
  ///   Pass alongside [rootEventId] for addressable videos so the
  ///   decrement is mirrored into the companion cache and survives a
  ///   subsequent metadata edit.
  /// - [reason]: Optional reason for the deletion
  ///
  /// Throws [DeleteCommentFailedException] if broadcasting fails.
  Future<void> deleteComment({
    required String commentId,
    String? rootEventId,
    String? rootAddressableId,
    String? reason,
  }) async {
    try {
      // NIP-09: Build deletion request tags
      final tags = <List<String>>[
        ['e', commentId],
        ['k', _commentKind.toString()],
      ];

      final event = Event(
        _nostrClient.publicKey,
        _deletionKind,
        tags,
        reason ?? '',
      );

      final sentEvent = await _nostrClient.publishEvent(event);
      if (sentEvent is! PublishSuccess) {
        throw const DeleteCommentFailedException(
          'Failed to publish deletion request',
        );
      }

      if (rootEventId != null) {
        _adjustCachedCommentCount(
          rootEventId,
          -1,
          rootAddressableId: rootAddressableId,
        );
      }
    } on CommentsRepositoryException {
      rethrow;
    } on Exception catch (e) {
      throw DeleteCommentFailedException('Failed to delete comment: $e');
    }
  }

  /// Watches for new comments in real-time via a persistent Nostr subscription.
  ///
  /// Opens a subscription for Kind 1111 events matching the root event,
  /// returning a [Stream<Comment>] that emits each new comment as it arrives.
  ///
  /// Parameters:
  /// - [rootEventId]: The ID of the root event to watch comments for
  /// - [rootEventKind]: The kind of the root event (e.g., 34236 for videos)
  /// - [rootAddressableId]: Optional addressable identifier (format:
  ///   `kind:pubkey:d-tag`). When provided, subscribes to both E and A tags.
  /// - [since]: Only receive comments created after this time
  ///
  /// Returns a [Stream<Comment>] that emits new comments as they arrive.
  /// Call [stopWatchingComments] to close the subscription.
  ///
  /// Throws [WatchCommentsFailedException] if the subscription fails.
  Stream<Comment> watchComments({
    required String rootEventId,
    required int rootEventKind,
    DateTime? since,
    String? rootAddressableId,
    void Function()? onEose,
    bool includeVideoReplies = false,
  }) {
    try {
      final sinceTimestamp = since != null
          ? since.millisecondsSinceEpoch ~/ 1000
          : null;

      final filters = <Filter>[
        Filter(
          kinds: _threadKinds(includeVideoReplies: includeVideoReplies),
          uppercaseE: [rootEventId],
          since: sinceTimestamp,
        ),
        if (rootAddressableId != null && rootAddressableId.isNotEmpty)
          Filter(
            kinds: _threadKinds(includeVideoReplies: includeVideoReplies),
            uppercaseA: [rootAddressableId],
            since: sinceTimestamp,
          ),
      ];

      _watchSubscriptionId = 'comments_watch_$rootEventId';

      final eventStream = _nostrClient.subscribe(
        filters,
        subscriptionId: _watchSubscriptionId,
        onEose: onEose,
      );

      // When dual-filter subscriptions are active (E + A tags), the same
      // comment event can arrive from both filters. Deduplicate by event ID
      // to prevent consumers from processing duplicates.
      final seenIds = <String>{};

      final filter = _blockFilter;
      return eventStream
          .where((event) => seenIds.add(event.id))
          .map((event) => _eventToComment(event, rootEventId, rootEventKind))
          .where((comment) => comment != null)
          .cast<Comment>()
          .where((c) => !(filter?.call(c.authorPubkey) ?? false));
    } on Exception catch (e) {
      throw WatchCommentsFailedException('Failed to watch comments: $e');
    }
  }

  /// Stops watching for new comments.
  ///
  /// Closes the persistent Nostr subscription opened by [watchComments].
  Future<void> stopWatchingComments() async {
    final id = _watchSubscriptionId;
    if (id != null) {
      await _nostrClient.unsubscribe(id);
      _watchSubscriptionId = null;
    }
  }

  /// Loads comments authored by a specific user across all videos.
  ///
  /// Returns a list of comments sorted newest first.
  /// Supports cursor-based pagination via [before].
  ///
  /// By default this returns text comments only. Callers that render a
  /// dedicated video-replies surface should opt in with
  /// [includeVideoReplies].
  ///
  /// Throws:
  ///
  /// * [LoadCommentsByAuthorFailedException] if the query fails.
  Future<List<Comment>> loadCommentsByAuthor({
    required String authorPubkey,
    int limit = _authorCommentsLimit,
    DateTime? before,
    bool includeVideoReplies = false,
  }) async {
    try {
      final untilTimestamp = before != null
          ? before.millisecondsSinceEpoch ~/ 1000
          : null;

      final filter = Filter(
        kinds: _threadKinds(includeVideoReplies: includeVideoReplies),
        authors: [authorPubkey],
        limit: limit,
        until: untilTimestamp,
      );

      final events = await _nostrClient.queryEvents([filter]);

      final comments =
          events.map(_eventToCommentFromRawEvent).whereType<Comment>().toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return comments;
    } on Exception catch (e) {
      throw LoadCommentsByAuthorFailedException(e.toString());
    }
  }

  /// Removes comments authored by blocked/muted users from a thread.
  ///
  /// Replies to filtered comments are kept — consumers that build threaded
  /// views already treat orphaned replies (missing parent) as root-level items.
  /// The original [CommentThread.totalCount] (server-authoritative) is
  /// preserved so pagination logic remains correct.
  CommentThread _filterThread(CommentThread thread) {
    final filter = _blockFilter;
    if (filter == null) return thread;
    final filtered = thread.comments
        .where((c) => !filter(c.authorPubkey))
        .toList();
    if (filtered.length == thread.comments.length) return thread;
    return thread.copyWith(
      comments: filtered,
      commentCache: Map<String, Comment>.unmodifiable({
        for (final c in filtered) c.id: c,
      }),
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Converts a raw Nostr event to a Comment by extracting root info
  /// from the event's own NIP-22 tags.
  ///
  /// Unlike [_eventToComment] which requires root context from the caller,
  /// this method reads the uppercase `E` and `K` tags directly from the event.
  /// Returns `null` if the required root tags are missing.
  Comment? _eventToCommentFromRawEvent(Event event) {
    try {
      String? rootEventId;
      String? rootEventKind;

      for (final rawTag in event.tags) {
        final tag = rawTag as List<dynamic>;
        if (tag.length < 2) continue;
        final tagType = tag[0] as String;
        final tagValue = tag[1] as String;

        if (tagType == 'E') {
          rootEventId = tagValue;
        } else if (tagType == 'K') {
          rootEventKind = tagValue;
        }
      }

      if (rootEventId == null || rootEventKind == null) return null;

      final kind = int.tryParse(rootEventKind);
      if (kind == null) return null;

      return _eventToComment(event, rootEventId, kind);
    } on Exception {
      return null;
    }
  }

  /// Converts a Nostr event to a Comment model using NIP-22 format.
  Comment? _eventToComment(Event event, String rootEventId, int rootEventKind) {
    try {
      String? parsedRootEventId;
      String? parsedRootAddressableId;
      String? replyToEventId;
      String? rootAuthorPubkey;
      String? replyToAuthorPubkey;
      String? parentKind;

      // Parse NIP-22 tags to determine comment relationships
      // Uppercase tags (E, A, K, P) = root scope
      // Lowercase tags (e, a, k, p) = parent item
      for (final rawTag in event.tags) {
        final tag = rawTag as List<dynamic>;
        if (tag.length < 2) continue;

        final tagType = tag[0] as String;
        final tagValue = tag[1] as String;

        switch (tagType) {
          case 'E':
            // Root event ID (uppercase = root scope)
            parsedRootEventId = tagValue;
            if (tag.length >= 4) {
              rootAuthorPubkey = tag[3] as String;
            }
          case 'A':
            // Root addressable ID (uppercase = root scope)
            // Format: kind:pubkey:d-tag
            parsedRootAddressableId = tagValue;
          case 'P':
            // Root author pubkey (uppercase = root scope)
            rootAuthorPubkey ??= tagValue;
          case 'e':
            // Parent event ID (lowercase = parent item)
            replyToEventId = tagValue;
            if (tag.length >= 4) {
              replyToAuthorPubkey = tag[3] as String;
            }
          case 'k':
            // Parent kind (lowercase = parent item)
            parentKind = tagValue;
          case 'p':
            // Parent author pubkey (lowercase = parent item)
            replyToAuthorPubkey ??= tagValue;
        }
      }

      // Extract root author pubkey from addressable ID if not found in tags
      // A tag format: kind:pubkey:d-tag
      if (rootAuthorPubkey == null && parsedRootAddressableId != null) {
        final parts = parsedRootAddressableId.split(':');
        if (parts.length >= 2) {
          rootAuthorPubkey = parts[1];
        }
      }

      // Determine if this is a top-level comment or a reply
      // If parent kind equals root kind, it's a top-level comment
      final isTopLevel =
          parentKind == rootEventKind.toString() ||
          replyToEventId == parsedRootEventId;

      final videoMetadata = _parseVideoMetadataFromImetaTags(event.tags);

      return Comment(
        id: event.id,
        content: event.content,
        authorPubkey: event.pubkey,
        createdAt: event.createdAtDateTime,
        eventKind: event.kind,
        addressableId: _ownAddressableId(
          kind: event.kind,
          pubkey: event.pubkey,
          tags: event.tags,
        ),
        rootEventId: parsedRootEventId ?? rootEventId,
        // For top-level comments, replyToEventId should be null
        replyToEventId: isTopLevel ? null : replyToEventId,
        rootAuthorPubkey: rootAuthorPubkey ?? '',
        rootAddressableId: parsedRootAddressableId,
        replyToAuthorPubkey: isTopLevel ? null : replyToAuthorPubkey,
        videoUrl: videoMetadata.videoUrl,
        thumbnailUrl: videoMetadata.thumbnailUrl,
        videoDimensions: videoMetadata.videoDimensions,
        videoDuration: videoMetadata.videoDuration,
        videoBlurhash: videoMetadata.videoBlurhash,
      );
    } on Exception {
      return null;
    }
  }

  /// Builds an event's **own** addressable coordinate, or `null` when it has
  /// none.
  ///
  /// Only addressable kinds (30000-39999) have coordinates, and only when the
  /// event actually carries a `d` tag. A missing `d` must yield `null` rather
  /// than substituting the event id the way `VideoEvent` does — that would
  /// mint a well-formed coordinate addressing nothing, and a reaction tagged
  /// with it would be unresolvable (#6124).
  ///
  /// Takes raw tags rather than an [Event] so the funnelcake REST payload,
  /// which carries the same tag list on a different type, resolves identically.
  String? _ownAddressableId({
    required int kind,
    required String pubkey,
    required List<dynamic> tags,
  }) {
    if (kind < 30000 || kind > 39999) return null;
    for (final rawTag in tags) {
      final tag = rawTag as List<dynamic>;
      if (tag.length < 2 || tag[0] != 'd') continue;
      final dTag = tag[1] as String;
      return dTag.isEmpty
          ? null
          : AId(kind: kind, pubkey: pubkey, dTag: dTag).toAString();
    }
    return null;
  }

  /// Checks whether an event's uppercase `E` or `A` tag matches the queried
  /// root. This provides client-side filtering for relays that do not support
  /// NIP-22 uppercase tag filters and return all Kind 1111 events.
  bool _eventMatchesRoot(
    Event event,
    String rootEventId,
    String? rootAddressableId,
  ) {
    for (final rawTag in event.tags) {
      final tag = rawTag as List<dynamic>;
      if (tag.length < 2) continue;
      final tagType = tag[0] as String;
      final tagValue = tag[1] as String;
      if (tagType == 'E' && tagValue == rootEventId) return true;
      if (tagType == 'A' &&
          rootAddressableId != null &&
          tagValue == rootAddressableId) {
        return true;
      }
    }
    return false;
  }

  /// Builds a CommentThread from a list of Nostr events.
  ///
  /// Events that do not reference the queried root (via uppercase `E` or `A`
  /// tags) are filtered out to guard against relays that ignore uppercase tag
  /// filters.
  CommentThread _buildThreadFromEvents(
    List<Event> events,
    String rootEventId,
    int rootEventKind, {
    String? rootAddressableId,
  }) {
    final commentMap = <String, Comment>{};

    for (final event in events) {
      if (!_eventMatchesRoot(event, rootEventId, rootAddressableId)) continue;
      final comment = _eventToComment(event, rootEventId, rootEventKind);
      if (comment != null) {
        commentMap[comment.id] = comment;
      }
    }

    return _buildThreadFromComments(commentMap, rootEventId);
  }

  CommentThread _buildThreadFromRestComments(
    VideoCommentsResponse response,
    String rootEventId,
    int rootEventKind, {
    String? rootAddressableId,
  }) {
    final commentMap = <String, Comment>{};

    for (final restComment in response.comments) {
      final comment = _restCommentToComment(
        restComment,
        rootEventId,
        rootEventKind,
        rootAddressableId: rootAddressableId,
      );
      if (comment != null) {
        commentMap[comment.id] = comment;
      }
    }

    final thread = _buildThreadFromComments(commentMap, rootEventId);
    return thread.copyWith(
      totalCount: response.total,
      hasMore: response.hasMore,
      hasExactTotal: response.hasExactTotal,
    );
  }

  Comment? _restCommentToComment(
    VideoComment restComment,
    String rootEventId,
    int rootEventKind, {
    String? rootAddressableId,
  }) {
    try {
      String? parsedRootEventId;
      String? parsedRootAddressableId;
      String? rootAuthorPubkey;

      for (final tag in restComment.tags) {
        if (tag.length < 2) continue;
        switch (tag[0]) {
          case 'E':
            parsedRootEventId = tag[1];
            if (tag.length >= 4) {
              rootAuthorPubkey = tag[3];
            }
          case 'A':
            parsedRootAddressableId = tag[1];
          case 'P':
            rootAuthorPubkey ??= tag[1];
        }
      }

      if (rootAuthorPubkey == null && parsedRootAddressableId != null) {
        final parts = parsedRootAddressableId.split(':');
        if (parts.length >= 2) {
          rootAuthorPubkey = parts[1];
        }
      }
      if (rootAuthorPubkey == null && rootAddressableId != null) {
        final parts = rootAddressableId.split(':');
        if (parts.length >= 2) {
          rootAuthorPubkey = parts[1];
        }
      }

      final parsedReplyToEventId = restComment.replyToEventId;
      final isTopLevel =
          parsedReplyToEventId == null || parsedReplyToEventId == rootEventId;
      final videoMetadata = _parseVideoMetadataFromImetaTags(restComment.tags);

      return Comment(
        id: restComment.id,
        content: restComment.content,
        authorPubkey: restComment.pubkey,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          restComment.createdAt * 1000,
        ),
        // The REST payload carries Kind 34236 video replies too, so the same
        // coordinate/kind the relay path derives must be derived here — this
        // path is REST-first and serves the first page in production (#6124).
        // `kind` defaults to 0 when the payload omits it; map that back to
        // null so the vote handler still falls back to Kind 1111.
        eventKind: restComment.kind > 0 ? restComment.kind : null,
        addressableId: _ownAddressableId(
          kind: restComment.kind,
          pubkey: restComment.pubkey,
          tags: restComment.tags,
        ),
        rootEventId: parsedRootEventId ?? rootEventId,
        rootAuthorPubkey: rootAuthorPubkey ?? '',
        rootAddressableId: parsedRootAddressableId ?? rootAddressableId,
        replyToEventId: isTopLevel ? null : parsedReplyToEventId,
        replyToAuthorPubkey: isTopLevel ? null : restComment.replyToPubkey,
        videoUrl: videoMetadata.videoUrl,
        thumbnailUrl: videoMetadata.thumbnailUrl,
        videoDimensions: videoMetadata.videoDimensions,
        videoDuration: videoMetadata.videoDuration,
        videoBlurhash: videoMetadata.videoBlurhash,
      );
    } on Exception {
      return null;
    }
  }

  _CommentVideoMetadata _parseVideoMetadataFromImetaTags(
    List<List<String>> tags,
  ) {
    String? videoUrl;
    String? thumbnailUrl;
    String? videoDimensions;
    int? videoDuration;
    String? videoBlurhash;

    for (final tag in tags) {
      if (tag.isEmpty || tag.first != 'imeta') continue;

      String? imetaUrlCandidate;
      String? imetaMimeType;

      parseImetaTag(tag, (key, rawValue) {
        final value = rawValue.trim();
        switch (key) {
          case 'url':
            imetaUrlCandidate = value;
          case 'm':
            imetaMimeType = value.toLowerCase();
          case 'image':
          case 'thumb':
            thumbnailUrl = value;
          case 'dim':
            videoDimensions = value;
          case 'duration':
            videoDuration = int.tryParse(value);
          case 'blurhash':
            videoBlurhash = value;
        }
      });

      final candidate = imetaUrlCandidate;
      if (candidate != null &&
          ((imetaMimeType?.startsWith('video/') ?? false) ||
              _isVideoUrl(candidate))) {
        videoUrl = candidate;
      }
    }

    return _CommentVideoMetadata(
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      videoDimensions: videoDimensions,
      videoDuration: videoDuration,
      videoBlurhash: videoBlurhash,
    );
  }

  bool _isVideoUrl(String url) =>
      switch (Uri.tryParse(url)?.path.toLowerCase()) {
        final String path
            when path.endsWith('.mp4') ||
                path.endsWith('.mov') ||
                path.endsWith('.webm') =>
          true,
        _ => false,
      };

  /// Builds a CommentThread from a map of comments.
  ///
  /// Organizes comments into a flat list sorted chronologically (newest first).
  /// Reply relationships are maintained through each Comment's
  /// replyToEventId field.
  CommentThread _buildThreadFromComments(
    Map<String, Comment> commentMap,
    String rootEventId,
  ) {
    if (commentMap.isEmpty) {
      return CommentThread.empty(rootEventId);
    }

    // Simple chronological sort: newest first
    final sortedComments = commentMap.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return CommentThread(
      rootEventId: rootEventId,
      comments: sortedComments,
      totalCount: commentMap.length,
      commentCache: Map<String, Comment>.unmodifiable(commentMap),
    );
  }
}

class _CommentVideoMetadata {
  const _CommentVideoMetadata({
    this.videoUrl,
    this.thumbnailUrl,
    this.videoDimensions,
    this.videoDuration,
    this.videoBlurhash,
  });

  final String? videoUrl;
  final String? thumbnailUrl;
  final String? videoDimensions;
  final int? videoDuration;
  final String? videoBlurhash;
}

/// A comment the local user just posted, retained briefly in
/// [CommentsRepository] so it survives a comment-sheet reopen while the REST
/// read source catches up. See [CommentsRepository] field
/// `_recentlyPostedComments` and issue #5598.
class _RecentlyPostedComment {
  _RecentlyPostedComment(this.comment, this.postedAt);

  final Comment comment;
  final DateTime postedAt;
}

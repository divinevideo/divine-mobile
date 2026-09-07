// ABOUTME: Repository that fetches raw notifications from FunnelCake,
// ABOUTME: enriches them with profile + video metadata, groups video-anchored
// ABOUTME: notifications by (referencedEventId, kind), and maps actor-anchored
// ABOUTME: notifications.

import 'dart:async';
import 'dart:math' as math;

import 'package:db_client/db_client.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:meta/meta.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/nip19.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:notification_repository/src/blocked_notification_filter.dart';
import 'package:notification_repository/src/notification_page.dart';
import 'package:profile_repository/profile_repository.dart';
// Hide rxdart's `NotificationKind` (a stream-event enum) to avoid clashing
// with the domain `NotificationKind` from `models`.
import 'package:rxdart/rxdart.dart' hide NotificationKind;
import 'package:text_sanitizer/text_sanitizer.dart';
import 'package:unified_logger/unified_logger.dart';

/// Callback that returns NIP-98 auth headers for an outgoing request.
///
/// The repository invokes this with the **full** URL the request will use
/// (scheme + host + path + query) and the HTTP method. For requests with
/// a body, [body] is the exact byte-identical JSON the request will send
/// so the implementation can compute the matching `payload` tag — passing
/// an empty body for a POST/PUT/PATCH causes the server to 401 with
/// `payload hash mismatch`.
typedef AuthHeadersProvider =
    Future<Map<String, String>> Function(
      String url,
      String method, {
      String? body,
    });

/// Maximum length for comment preview text before truncation.
///
/// Sized just above the widest measured two-line capacity of
/// `NotificationCommentQuote` — 112 Latin code units at 440pt, 99 at 393pt,
/// 76 at 320pt — so the cap never truncates text the row could otherwise have
/// shown. The row clamps itself with `maxLines: 2` + ellipsis, so this bound
/// exists only to keep remote-controlled content finite, not for layout.
const _maxCommentLength = 120;

/// Longest raw reference that may be kept whole when it straddles the cap.
///
/// `NotificationCommentQuote` renders valid profile references as `@label`
/// and video/event references as the localized "View video" label, so the
/// source token can be longer than its visible text. This bound keeps
/// remote-controlled source content finite while still admitting normal
/// `nprofile`/`nevent`/`naddr` references with relay hints.
const _maxKeptResolvedReferenceLength = 512;

/// If an unbounded reference starts before this point, use the plain cap
/// instead of returning an empty quote body such as `...`.
const _minPreviewBeforeDroppingReference = 12;

/// Maximum number of actor avatars shown in a grouped notification.
const _maxGroupActors = 3;

final RegExp _hexIdentifierPattern = RegExp(r'^[0-9a-fA-F]{32,}$');
final RegExp _npubIdentifierPattern = RegExp(
  r'^npub1[023456789acdefghjklmnpqrstuvwxyz]+$',
  caseSensitive: false,
);

/// Mirror of `LinkifiedTextSpanBuilder._combinedRegex`
/// (`mobile/lib/widgets/linkified_text/linkified_text_span_builder.dart`),
/// alternative for alternative and in the same order.
///
/// The surrounding alternatives are mirrored too, not just the two reference
/// ones, because alternation resolves per start position: a URL or hashtag
/// that *contains* a bech32 or hex run starts earlier and wins there. In the
/// UI `https://host/<64-hex>` is a single URL token and the hex inside it is
/// never a reference. A pattern holding only the reference alternatives
/// cannot see that and pulls the preview cut back for a span the UI never
/// links — Blossom and CDN media URLs are exactly that shape.
///
/// Group 3 is a bech32 reference and group 4 a bare 64-char hex pubkey /
/// event id; those are the spans [NotificationRepository._referenceAwareCut]
/// protects. Groups 1 and 2 (URL/email, hashtag) are here only to consume
/// their own text so a run buried inside them is not mistaken for one.
///
/// The UI's trailing mention alternative,
/// `@([a-zA-Z](?:[a-zA-Z0-9_]|[.-](?=[a-zA-Z0-9_])){0,30})`, is the one
/// deliberate divergence, and it only fires when a letter follows the `@`.
/// It therefore always wins for `@npub1…` — every bech32 prefix starts with
/// `n` — and wins over hex only for a letter-initial `@<64-hex>`, capping
/// either at 31 characters. A digit-initial `@<64-hex>` starts with no
/// letter to consume, so it falls through to the hex alternative in both
/// patterns and does not diverge at all. Mirroring the alternative would
/// drop the protection #6346 added for `@npub1…`. Whether the UI should
/// tokenize these as mentions at all is a separate question from this cut.
final RegExp _uiTokenPattern = RegExp(
  r'((?:[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})|(?:https?:\/\/[^\s]+|www\.[^\s]+|(?<![@\w])(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(?:\/[^\s]*)?))|#(\w+)|(?<![A-Za-z0-9])(?:nostr:)?((?:npub|nprofile|note|nevent|naddr)1[a-z0-9]+)\b|(?<![A-Fa-f0-9])([A-Fa-f0-9]{64})(?![A-Fa-f0-9])',
  caseSensitive: false,
);

/// [_uiTokenPattern] group holding a bech32 Nostr reference.
const _bech32ReferenceGroup = 3;

/// [_uiTokenPattern] group holding a bare 64-char hex pubkey / event id.
const _hexReferenceGroup = 4;

/// Retry policy for the first-page notifications fetch.
///
/// Retries only transient server faults — HTTP `5xx` and request timeouts
/// — with full-jitter backoff. Auth (`401`) and client errors (`4xx` other
/// than 408/429) are caller bugs, not transient, and are surfaced
/// immediately so the failure UI can fire.
abstract class _NotificationRetryConfig {
  /// Number of attempts including the initial call.
  static const maxAttempts = 3;

  /// Base backoff applied to the i-th retry (0-indexed) as `base * 3^i`.
  static const baseBackoff = Duration(milliseconds: 200);

  /// Upper bound on a single retry's delay before jitter.
  static const maxBackoff = Duration(milliseconds: 1500);
}

class _VideoMetadataLookup {
  const _VideoMetadataLookup({
    required this.videosById,
    required this.notFoundIds,
  });

  const _VideoMetadataLookup.empty()
    : videosById = const <String, VideoStats>{},
      notFoundIds = const <String>{};

  final Map<String, VideoStats> videosById;
  final Set<String> notFoundIds;
}

class _VideoMetadataResult {
  const _VideoMetadataResult({
    required this.id,
    this.stats,
    this.notFound = false,
  });

  final String id;
  final VideoStats? stats;
  final bool notFound;
}

class _NotificationFeed {
  _NotificationFeed({required this.filter})
    : snapshot = BehaviorSubject<NotificationPage>.seeded(
        NotificationPage.empty,
      );

  final NotificationKind? filter;
  final BehaviorSubject<NotificationPage> snapshot;

  String? lastCursor;
  String? lastCursorId;
  int fetchGeneration = 0;
  int pagesLoaded = 0;
}

/// Number of notifications loaded per page.
///
/// Bounds both the cold-start cache hydration and the first-page REST
/// fetch. Kept deliberately small: each first-page notification can fan
/// out to a `getVideoStats` lookup (see `_fetchVideoMetadata`), so a large
/// page turns every inbox open into a burst of parallel requests that
/// keeps the stale-while-revalidate progress bar up — and the list
/// janking — for seconds. Older notifications load on demand via
/// `loadNextPage` as the user scrolls.
const _pageSize = 20;

/// Repository for fetching, enriching, grouping, and managing
/// notifications.
///
/// Responsibilities:
/// 1. Fetch raw notifications via [FunnelcakeApiClient.getNotifications]
/// 2. Batch-fetch profiles via [ProfileRepository.fetchBatchProfiles]
/// 3. Fetch per-video metadata via [FunnelcakeApiClient.getVideoStats]
/// 4. Group like/comment/repost by `(referencedEventId, kind)` into
///    [VideoNotification]s — threshold 1
/// 5. Map follow/mention/system into [ActorNotification]s
/// 6. Consolidate follow duplicates (keep most recent per source pubkey)
/// 7. Truncate long comment text
class NotificationRepository {
  /// Creates a [NotificationRepository].
  ///
  /// When [hydrateOnStart] is `true` (default), the repository kicks off a
  /// best-effort load from [notificationsDao] so the inbox can render
  /// cached items before the first REST call resolves. Tests pass `false`
  /// to keep the snapshot at [NotificationPage.empty] for deterministic
  /// assertions.
  NotificationRepository({
    required FunnelcakeApiClient funnelcakeApiClient,
    required ProfileRepository profileRepository,
    required NotificationsDao notificationsDao,
    required String userPubkey,
    BlockedNotificationFilter? blockFilter,
    AuthHeadersProvider? authHeadersProvider,
    bool hydrateOnStart = true,
  }) : _funnelcakeApiClient = funnelcakeApiClient,
       _profileRepository = profileRepository,
       _notificationsDao = notificationsDao,
       _userPubkey = userPubkey,
       _blockFilter = blockFilter,
       _authHeadersProvider = authHeadersProvider {
    if (hydrateOnStart) {
      unawaited(_hydrateFromCache());
    }
  }

  final FunnelcakeApiClient _funnelcakeApiClient;
  final ProfileRepository _profileRepository;
  final NotificationsDao _notificationsDao;
  final String _userPubkey;
  final BlockedNotificationFilter? _blockFilter;
  final AuthHeadersProvider? _authHeadersProvider;

  final Map<NotificationKind?, _NotificationFeed> _feeds = {};
  bool _closed = false;

  _NotificationFeed _feedFor(NotificationKind? filter) {
    if (_closed) {
      throw StateError('NotificationRepository is closed');
    }
    final existing = _feeds[filter];
    if (existing != null) return existing;
    final feed = _NotificationFeed(filter: filter);
    _feeds[filter] = feed;
    if (filter != null) _seedFilteredFeed(feed);
    return feed;
  }

  _NotificationFeed get _allFeed => _feedFor(null);

  Iterable<_NotificationFeed> get _liveFeeds => _feeds.values;

  /// Seeds a freshly minted filtered feed from the unfiltered feed's rows.
  ///
  /// Only the unfiltered feed reads and writes the DAO, so without this a
  /// category tab starts at [NotificationPage.empty] with no cache path at
  /// all: on a cold start with no network its first fetch fails against an
  /// empty list, and the bloc renders the full-screen failure body instead
  /// of cached rows plus the inline refresh-error banner. Before per-tab
  /// feeds every tab read the same hydrated snapshot and degraded to a
  /// cached subset.
  ///
  /// Placeholder-grade by construction: the feed's page count stays 0 and
  /// its own first-page fetch replaces these rows wholesale.
  void _seedFilteredFeed(_NotificationFeed feed) {
    if (feed.pagesLoaded > 0) return;
    final source = _feeds[null];
    if (source == null) return;
    final items = source.snapshot.value.items
        .where((item) => _belongsInFeed(item, feed.filter))
        .toList();
    if (items.isEmpty) return;
    feed.snapshot.add(
      // Seeded rows are a degraded view; assume more is available until the
      // feed's own refresh resolves. Mirrors [_hydrateFromCache].
      feed.snapshot.value.copyWith(items: items, hasMore: true),
    );
  }

  /// Re-seeds every live filtered feed that has not fetched yet.
  ///
  /// The repository is constructed when [ProfileRepository] becomes
  /// available, which on a cold start can land after the inbox has already
  /// mounted its tabs — so hydration finishes with the filtered feeds
  /// already minted and empty.
  void _seedFilteredFeedsFromAllFeed() {
    for (final feed in _liveFeeds.toList()) {
      if (feed.filter == null) continue;
      if (feed.snapshot.value.items.isNotEmpty) continue;
      _seedFilteredFeed(feed);
    }
  }

  /// Whether [item] belongs in the tab identified by [filter].
  ///
  /// Mirrors the server-side `types` mapping in [_serverTypesForFilter] for
  /// rows that were fetched without it (cache hydration, cross-feed seed).
  bool _belongsInFeed(NotificationItem item, NotificationKind? filter) =>
      switch (filter) {
        null => true,
        NotificationKind.comment => _belongsInCommentsFeed(item),
        // `reaction`/`zap` map to a video like or a comment like depending on
        // the target, and both belong in the Likes tab.
        NotificationKind.like =>
          item.type == NotificationKind.like ||
              item.type == NotificationKind.likeComment,
        _ => item.type == filter,
      };

  /// Reactive snapshot of the enriched, grouped notification feed.
  ///
  /// Single source of truth for the feed bloc (list rendering) and the
  /// badge cubit (badge count). Every mutation — [getNotifications],
  /// [refresh], [markAsRead], [markAllAsRead] — updates this subject so
  /// consumers can never diverge.
  BehaviorSubject<NotificationPage> get _snapshot => _allFeed.snapshot;

  /// Stream of the latest [NotificationPage] snapshot.
  ///
  /// Use this for screen-level rendering. For badge counts, prefer
  /// [watchUnreadCount] — it is `.distinct()`-filtered so the badge
  /// only rebuilds on actual count changes.
  Stream<NotificationPage> watchSnapshot({NotificationKind? filter}) =>
      _feedFor(filter).snapshot.stream;

  /// Stream of the unread badge count derived from the consolidated
  /// visible list.
  ///
  /// Counts items in [NotificationPage.items] where `isRead == false`
  /// rather than using the server's `unreadCount` directly. The server
  /// reports one row per Kind 3 republish per follower (tracked at
  /// funnelcake#234); this method matches the same post-consolidation
  /// derivation that `NotificationFeedState.unreadBadgeCount` documents.
  Stream<int> watchUnreadCount() => _snapshot.stream
      .map((page) => page.items.where((n) => !n.isRead).length)
      .distinct();

  /// Disposes the internal snapshot subject.
  ///
  /// Called when the repository is no longer needed (e.g. on auth flip
  /// when a new repository instance replaces this one).
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final feed in _liveFeeds.toList()) {
      await feed.snapshot.close();
    }
  }

  /// Whether [close] has been called on this repository.
  ///
  /// After an auth flip the provider closes the outgoing instance while a
  /// long-lived consumer (e.g. the refresh coordinator) may still hold it
  /// across an in-flight call. Such callers use this to classify the
  /// resulting [StateError] as expected account-switch noise.
  bool get isClosed => _closed;

  /// Whether every live feed is paginated beyond its first page.
  ///
  /// Resume-driven liveness triggers consult this to avoid collapsing a
  /// user-visible paginated feed back to page 1. [refreshApplied] already
  /// skips the individual feeds that would collapse, so this only reports
  /// `true` when no live feed is refreshable at all — otherwise one tab
  /// scrolled two pages deep would suppress resume refreshes for every
  /// other tab as well. An explicit [refresh] (pull-to-refresh, page mount)
  /// still replaces the snapshot and resets this to `false`.
  bool get hasPaginatedBeyondFirstPage =>
      _liveFeeds.isNotEmpty && _liveFeeds.every((feed) => feed.pagesLoaded > 1);

  /// Releases the current page-depth guard after the feed UI is gone, and
  /// collapses any deep-scrolled accumulation back to the first page.
  ///
  /// While the notifications screen is visible, app-resume refreshes skip
  /// over a paginated snapshot so they do not collapse the list under the
  /// user. Once the feed BLoC closes, no visible list can collapse; resetting
  /// the depth lets out-of-screen liveness refresh the badge again.
  ///
  /// The snapshot is long-lived (the repository outlives the feed BLoC), so a
  /// session that scrolled through several pages would otherwise leave every
  /// loaded item in the snapshot. The next open's stale-while-revalidate
  /// render would then paint and project that entire accumulation before the
  /// first-page refresh trims it — janking the open in proportion to how far
  /// the previous session scrolled. Trimming to [_pageSize] here keeps the
  /// newest page and lets [refresh] replace it with authoritative first-page
  /// data on reopen. The unread badge, derived from the snapshot, then
  /// reflects only the newest page's unread rows — the same bound the next
  /// `refresh()` would impose anyway, so this only brings that bound forward
  /// to feed-close instead of next-open.
  void resetPaginationDepth({NotificationKind? filter}) {
    if (_closed) {
      return;
    }

    final feed = _feedFor(filter);
    final current = feed.snapshot.value;
    if (current.items.length > _pageSize) {
      feed.snapshot.add(
        current.copyWith(items: current.items.take(_pageSize).toList()),
      );
    }
    feed.pagesLoaded = feed.snapshot.value.items.isEmpty ? 0 : 1;
  }

  /// Fetches the next page of notifications.
  ///
  /// Pass [cursor] to override the stored pagination cursor. On success,
  /// merges the new items into the snapshot — the first page replaces
  /// the snapshot's items, subsequent pages append. First-page successes
  /// also write the enriched items through to [NotificationsDao] so a
  /// later cold-start can hydrate the inbox before the network responds,
  /// and clear any pending `lastRefreshError` flag on the snapshot.
  ///
  /// Transient first-page failures (`5xx`, request timeout) are retried
  /// per [_NotificationRetryConfig]. On terminal failure the snapshot is
  /// stamped with `lastRefreshError: true` so the BLoC can keep cached
  /// items visible alongside an inline error affordance, and the typed
  /// [FunnelcakeException] is rethrown after structured logging so
  /// callers can also drive a hard-failure UI when the cache is empty.
  ///
  /// A [refresh] issued while this call is in flight supersedes it: the
  /// late completion neither updates the stored cursor nor touches the
  /// snapshot, and returns the current snapshot unchanged.
  Future<NotificationPage> getNotifications({
    String? cursor,
    String? cursorId,
    NotificationKind? filter,
  }) async => (await _getNotificationsResult(
    cursor: cursor,
    cursorId: cursorId,
    filter: filter,
  )).page;

  Future<({NotificationPage page, bool applied})> _getNotificationsResult({
    String? cursor,
    String? cursorId,
    NotificationKind? filter,
  }) async {
    final feed = _feedFor(filter);
    final generation = feed.fetchGeneration;
    final effectiveCursor = cursor ?? feed.lastCursor;
    final effectiveCursorId = cursor != null
        ? cursorId
        : cursorId ?? feed.lastCursorId;
    final isFirstPage = effectiveCursor == null;

    try {
      final response = isFirstPage
          ? await _fetchWithRetry(
              cursor: effectiveCursor,
              cursorId: effectiveCursorId,
              filter: filter,
            )
          : await _fetchOnce(
              cursor: effectiveCursor,
              cursorId: effectiveCursorId,
              filter: filter,
            );
      if (generation != feed.fetchGeneration) {
        return (page: feed.snapshot.value, applied: false);
      }

      feed
        ..lastCursor = response.nextCursor
        ..lastCursorId = response.nextCursorId;

      final items = await _enrichAndGroup(
        response.notifications,
        filter: filter,
      );
      if (generation != feed.fetchGeneration) {
        return (page: feed.snapshot.value, applied: false);
      }

      final page = NotificationPage(
        items: items,
        unreadCount: response.unreadCount,
        nextCursor: response.nextCursor,
        nextCursorId: response.nextCursorId,
        hasMore: response.hasMore,
      );
      feed.pagesLoaded = isFirstPage ? 1 : feed.pagesLoaded + 1;
      _emitSnapshotForPage(feed, page, isFirstPage: isFirstPage);

      if (isFirstPage && filter == null) {
        unawaited(_persistSnapshot(items));
      }
      return (page: page, applied: true);
    } on Exception catch (e, s) {
      Log.error(
        'Failed to fetch notifications: $e',
        name: 'NotificationRepository.getNotifications',
        category: LogCategory.api,
        error: e,
        stackTrace: s,
      );
      if (isFirstPage && generation == feed.fetchGeneration) {
        _markRefreshError(feed);
      }
      rethrow;
    }
  }

  /// Single-attempt fetch — used for paginate-load-more requests where
  /// retrying could shift `before` past the user-visible boundary.
  Future<NotificationResponse> _fetchOnce({
    required String? cursor,
    required String? cursorId,
    required NotificationKind? filter,
  }) async {
    final types = _serverTypesForFilter(filter);
    final requestUrl = _funnelcakeApiClient
        .notificationsUri(
          pubkey: _userPubkey,
          limit: _pageSize,
          cursor: cursor,
          cursorId: cursorId,
          types: types,
        )
        .toString();
    final authHeaders = _authHeadersProvider != null
        ? await _authHeadersProvider(requestUrl, 'GET')
        : <String, String>{};
    return _funnelcakeApiClient.getNotifications(
      pubkey: _userPubkey,
      limit: _pageSize,
      cursor: cursor,
      cursorId: cursorId,
      types: types,
      requestUri: Uri.parse(requestUrl),
      authHeaders: authHeaders,
    );
  }

  /// First-page fetch with bounded retry on transient server faults.
  Future<NotificationResponse> _fetchWithRetry({
    required String? cursor,
    required String? cursorId,
    required NotificationKind? filter,
  }) async {
    Object? lastError;
    StackTrace? lastStack;
    for (
      var attempt = 0;
      attempt < _NotificationRetryConfig.maxAttempts;
      attempt++
    ) {
      try {
        return await _fetchOnce(
          cursor: cursor,
          cursorId: cursorId,
          filter: filter,
        );
      } on Exception catch (e, s) {
        if (!_isTransient(e) ||
            attempt == _NotificationRetryConfig.maxAttempts - 1) {
          rethrow;
        }
        lastError = e;
        lastStack = s;
        Log.error(
          'Transient notifications fetch failure '
          '(attempt ${attempt + 1}/${_NotificationRetryConfig.maxAttempts}): '
          '$e',
          name: 'NotificationRepository._fetchWithRetry',
          category: LogCategory.api,
          error: e,
          stackTrace: s,
        );
        await Future<void>.delayed(_backoffFor(attempt));
      }
    }
    // Unreachable — the loop either returns on success or rethrows on the
    // final attempt — but the analyzer can't prove that.
    Error.throwWithStackTrace(
      lastError ?? StateError('retry exhausted'),
      lastStack ?? StackTrace.current,
    );
  }

  /// Whether [e] is a transient error worth retrying.
  ///
  /// Retries timeouts and HTTP `5xx` plus 408/429. Skips `401`/`403`
  /// (auth) and other `4xx` (caller bug) so failure UI fires immediately.
  static bool _isTransient(Exception e) {
    if (e is FunnelcakeTimeoutException) return true;
    if (e is FunnelcakeApiException) {
      final status = e.statusCode;
      if (status == 408 || status == 429) return true;
      return status >= 500 && status < 600;
    }
    return false;
  }

  /// Computes the delay for the i-th retry (0-indexed) using full jitter
  /// on top of an exponential schedule, capped at
  /// [_NotificationRetryConfig.maxBackoff].
  Duration _backoffFor(int attempt) {
    final scaled =
        _NotificationRetryConfig.baseBackoff.inMilliseconds *
        math.pow(3, attempt).toInt();
    final capped = math.min(
      scaled,
      _NotificationRetryConfig.maxBackoff.inMilliseconds,
    );
    final jittered = _jitter.nextInt(capped + 1);
    return Duration(milliseconds: jittered);
  }

  /// Stamps the snapshot with `lastRefreshError: true` so the UI can
  /// render an inline error affordance while keeping cached items.
  void _markRefreshError(_NotificationFeed feed) {
    final current = feed.snapshot.value;
    if (current.lastRefreshError) return;
    feed.snapshot.add(current.copyWith(lastRefreshError: true));
  }

  /// Best-effort load of cached rows into the snapshot on construction.
  ///
  /// Runs only when the snapshot is still empty (avoids racing the first
  /// REST response). Cached rows are surfaced as lightweight placeholders
  /// — video-anchored rows stay video-anchored when reconstructable, and
  /// the next REST arrival replaces them with fully enriched items.
  Future<void> _hydrateFromCache() async {
    try {
      if (_snapshot.value.items.isNotEmpty) return;
      final rows = await _notificationsDao.getAllNotifications(
        limit: _pageSize,
        ownerPubkey: _userPubkey,
      );
      if (rows.isEmpty) return;
      if (_snapshot.value.items.isNotEmpty) return;
      final items = rows
          .map(_rowToPlaceholder)
          .whereType<NotificationItem>()
          .toList();
      if (items.isEmpty) return;
      _snapshot.add(
        _snapshot.value.copyWith(
          items: items,
          // Hydrated rows are a degraded view; assume more is available
          // until the first REST refresh resolves.
          hasMore: true,
        ),
      );
      _seedFilteredFeedsFromAllFeed();
      unawaited(_enrichCachedPlaceholders(items));
    } on Exception catch (e, s) {
      Log.error(
        'Failed to hydrate notifications cache: $e',
        name: 'NotificationRepository._hydrateFromCache',
        category: LogCategory.storage,
        error: e,
        stackTrace: s,
      );
    }
  }

  Future<void> _enrichCachedPlaceholders(
    List<NotificationItem> placeholders,
  ) async {
    final generation = _allFeed.fetchGeneration;
    try {
      final pubkeys = placeholders
          .map(
            (item) => switch (item) {
              VideoNotification(:final actors) => actors.first.pubkey,
              ActorNotification(:final actor) => actor.pubkey,
            },
          )
          .where((pubkey) => pubkey.isNotEmpty)
          .toSet()
          .toList();
      final eventIds = placeholders
          .whereType<VideoNotification>()
          .map((item) => item.videoEventId)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      if (pubkeys.isEmpty && eventIds.isEmpty) return;

      final profilesFuture = pubkeys.isEmpty
          ? Future.value(<String, UserProfile>{})
          : _profileRepository.fetchBatchProfiles(pubkeys: pubkeys);
      final videosFuture = _fetchVideoMetadata(eventIds);
      final (profiles, videoMetadata) = await (
        profilesFuture,
        videosFuture,
      ).wait;

      if (generation != _allFeed.fetchGeneration) return;

      final current = _snapshot.value;
      if (!_sameNotificationIds(current.items, placeholders)) return;

      final enriched = current.items.map((item) {
        return switch (item) {
          VideoNotification(:final actors, :final videoEventId) => () {
            final actor = actors.first;
            final video = videoMetadata.videosById[videoEventId];
            return item.copyWith(
              actors: _isCachedVideoPlaceholder(item)
                  ? [_buildActor(actor.pubkey, profiles)]
                  : actors,
              videoThumbnailUrl:
                  item.videoThumbnailUrl ?? _nonEmpty(video?.thumbnail),
              videoTitle: item.videoTitle ?? _nonEmpty(video?.title),
              videoAddressableId:
                  item.videoAddressableId ??
                  (item.type == NotificationKind.mention
                      ? _sourceVideoAddressableId(video: video)
                      : _recipientScopedVideoAddressableId(
                          dTag: null,
                          video: video,
                        )),
            );
          }(),
          ActorNotification(:final actor) => item.copyWith(
            actor: _buildActor(actor.pubkey, profiles),
          ),
        };
      }).toList();

      _snapshot.add(current.copyWith(items: enriched));
    } on Exception catch (e, s) {
      Log.error(
        'Failed to enrich cached notifications: $e',
        name: 'NotificationRepository._enrichCachedPlaceholders',
        category: LogCategory.storage,
        error: e,
        stackTrace: s,
      );
    }
  }

  static bool _isCachedVideoPlaceholder(VideoNotification item) =>
      item.actors.length == 1 &&
      item.totalCount == 1 &&
      item.sourceEventIds.isEmpty;

  static bool _sameNotificationIds(
    List<NotificationItem> current,
    List<NotificationItem> expected,
  ) {
    if (current.length != expected.length) return false;
    for (var i = 0; i < current.length; i++) {
      if (current[i].id != expected[i].id) return false;
    }
    return true;
  }

  /// Maps a [NotificationRow] into a placeholder [NotificationItem].
  ///
  /// Returns null when the cached row cannot be reconstructed as a valid
  /// item (e.g. a `like`/`comment`/`repost` row whose `targetEventId` is
  /// missing — [VideoNotification] requires a non-null `videoEventId`).
  /// Skipping is preferable to degrading video-anchored rows into
  /// [NotificationKind.system], because system rows disappear from the
  /// Likes/Comments/Reposts tab filters and become inert on tap.
  ///
  /// Profile and video metadata aren't refetched here — placeholders are
  /// always replaced by the next first-page REST emission, so we keep
  /// the hydration path synchronous and dependency-free.
  static NotificationItem? _rowToPlaceholder(NotificationRow row) {
    final timestamp = DateTime.fromMillisecondsSinceEpoch(
      row.timestamp * 1000,
      isUtc: true,
    ).toLocal();
    final actor = ActorInfo(
      pubkey: row.fromPubkey,
      displayName: UserProfile.defaultDisplayNameFor(row.fromPubkey),
    );

    // Video-anchored kinds — reconstruct VideoNotification using the cached
    // targetEventId (which `_itemToCacheRow` writes as videoEventId).
    final videoKind = _videoKindFromCachedType(row.type);
    if (videoKind != null) {
      final videoEventId = row.targetEventId;
      if (videoEventId == null || videoEventId.isEmpty) return null;
      return VideoNotification(
        id: row.id,
        type: videoKind,
        videoEventId: videoEventId,
        videoAddressableId: _nonEmpty(row.videoAddressableId),
        actors: [actor],
        totalCount: 1,
        timestamp: timestamp,
        isRead: row.isRead,
        commentText: videoKind == NotificationKind.comment ? row.content : null,
        listTitle: videoKind == NotificationKind.listAdd ? row.content : null,
        listCoordinate: videoKind == NotificationKind.listAdd
            ? _nonEmpty(row.targetPubkey)
            : null,
        notificationIds: row.id.isNotEmpty ? [row.id] : const [],
        // sourceEventIds intentionally empty — the cache stores only the
        // persisted row id and the videoEventId (`targetEventId`), not the
        // underlying Nostr source event id set. First-page REST emission
        // replaces the placeholder, so the union-by-sourceEventId merge path
        // doesn't need a value here.
      );
    }

    // Actor-anchored kinds — `follow`, `actorLike`, `mention`, `likeComment`,
    // `reply`, `system` (and unknown future types fall through to `system`).
    return ActorNotification(
      id: row.id,
      type: _actorKindFromCachedType(row.type),
      actor: actor,
      timestamp: timestamp,
      isRead: row.isRead,
      commentText: row.content,
      targetEventId: row.targetEventId,
      notificationIds: row.id.isNotEmpty ? [row.id] : const [],
      videoAddressableId: _nonEmpty(row.videoAddressableId),
      hasCommentTarget: row.hasCommentTarget,
    );
  }

  /// Maps a cached `type` column to a video-anchored [NotificationKind].
  ///
  /// Returns null for non-video types — those are routed through
  /// [_actorKindFromCachedType] instead.
  static NotificationKind? _videoKindFromCachedType(String type) =>
      switch (type) {
        'like' => NotificationKind.like,
        'comment' => NotificationKind.comment,
        'videoMention' => NotificationKind.mention,
        'repost' => NotificationKind.repost,
        'newPost' => NotificationKind.newPost,
        'listAdd' => NotificationKind.listAdd,
        _ => null,
      };

  /// Maps a cached `type` column to an actor-anchored [NotificationKind].
  ///
  /// Unknown types fall back to [NotificationKind.system] so the row
  /// stays renderable until REST refreshes it.
  static NotificationKind _actorKindFromCachedType(String type) =>
      switch (type) {
        'follow' => NotificationKind.follow,
        'actorLike' => NotificationKind.like,
        'mention' => NotificationKind.mention,
        'likeComment' => NotificationKind.likeComment,
        'reply' => NotificationKind.reply,
        _ => NotificationKind.system,
      };

  /// Writes [items] through to [NotificationsDao] so a future cold start
  /// can hydrate the inbox before the network responds.
  ///
  /// Per-item failures are swallowed — the in-memory snapshot is the
  /// active source of truth; the cache is a fallback, not a critical
  /// path.
  Future<void> _persistSnapshot(List<NotificationItem> items) async {
    try {
      final rows = items.map(_itemToCacheRow).toList();
      await _notificationsDao.replaceAll(rows, ownerPubkey: _userPubkey);
    } on Exception catch (e, s) {
      Log.error(
        'Failed to persist notifications cache: $e',
        name: 'NotificationRepository._persistSnapshot',
        category: LogCategory.storage,
        error: e,
        stackTrace: s,
      );
    }
  }

  /// Projects an enriched [NotificationItem] into the persistence record
  /// shape accepted by [NotificationsDao.replaceAll].
  static NotificationCacheRow _itemToCacheRow(NotificationItem item) {
    final (
      fromPubkey,
      targetEventId,
      videoAddressableId,
      targetPubkey,
      content,
      hasCommentTarget,
    ) = switch (item) {
      VideoNotification(
        type: NotificationKind.listAdd,
        :final actors,
        :final videoEventId,
        :final videoAddressableId,
        :final listTitle,
        :final listCoordinate,
      ) =>
        (
          actors.isNotEmpty ? actors.first.pubkey : '',
          videoEventId,
          videoAddressableId,
          listCoordinate,
          listTitle,
          false,
        ),
      VideoNotification(
        :final actors,
        :final videoEventId,
        :final videoAddressableId,
        :final commentText,
      ) =>
        (
          actors.isNotEmpty ? actors.first.pubkey : '',
          videoEventId,
          videoAddressableId,
          null,
          commentText,
          false,
        ),
      ActorNotification(
        :final actor,
        :final targetEventId,
        :final videoAddressableId,
        :final commentText,
        :final hasCommentTarget,
      ) =>
        (
          actor.pubkey,
          targetEventId,
          videoAddressableId,
          actor.pubkey,
          commentText,
          hasCommentTarget,
        ),
    };
    return (
      id: item.id,
      type: _persistType(item),
      fromPubkey: fromPubkey,
      timestamp: item.timestamp.toUtc().millisecondsSinceEpoch ~/ 1000,
      targetEventId: targetEventId,
      videoAddressableId: videoAddressableId,
      hasCommentTarget: hasCommentTarget,
      targetPubkey: targetPubkey,
      content: content,
      isRead: item.isRead,
    );
  }

  /// String form persisted in the `type` column.
  ///
  /// Inverse of [_videoKindFromCachedType] plus [_actorKindFromCachedType].
  static String _persistType(NotificationItem item) => switch (item) {
    VideoNotification(type: NotificationKind.mention) => 'videoMention',
    ActorNotification(type: NotificationKind.like) => 'actorLike',
    NotificationItem(:final type) => _persistKind(type),
  };

  static String _persistKind(NotificationKind kind) => switch (kind) {
    NotificationKind.like => 'like',
    NotificationKind.comment => 'comment',
    NotificationKind.repost => 'repost',
    NotificationKind.follow => 'follow',
    NotificationKind.mention => 'mention',
    NotificationKind.likeComment => 'likeComment',
    NotificationKind.reply => 'reply',
    NotificationKind.system => 'system',
    NotificationKind.newPost => 'newPost',
    NotificationKind.listAdd => 'listAdd',
  };

  static List<String>? _serverTypesForFilter(NotificationKind? filter) =>
      switch (filter) {
        null => null,
        NotificationKind.like => const ['reaction', 'zap'],
        NotificationKind.comment => const ['comment', 'reply', 'mention'],
        NotificationKind.repost => const ['repost'],
        NotificationKind.follow => const ['follow'],
        NotificationKind.mention => const ['mention'],
        NotificationKind.likeComment => const ['reaction', 'zap'],
        NotificationKind.reply => const ['reply'],
        NotificationKind.system => const ['system'],
        NotificationKind.newPost => const ['newPost'],
        NotificationKind.listAdd => const ['list_add'],
      };

  static final math.Random _jitter = math.Random();

  /// Refreshes notifications from the beginning (no cursor).
  ///
  /// Starts a new pagination stream: bumps the fetch generation so any
  /// in-flight page fetch from the previous stream completes without
  /// touching the cursor or snapshot, then clears the stored cursor.
  Future<NotificationPage> refresh() {
    return _refreshResult().then((result) => result.page);
  }

  /// Refreshes notifications and reports whether this call applied a snapshot.
  ///
  /// App-resume refresh coordination uses this to avoid consuming its cooldown
  /// when the refresh was superseded by another first-page fetch before it
  /// could apply.
  Future<bool> refreshApplied() {
    return _refreshAppliedForLiveFeeds();
  }

  Future<({NotificationPage page, bool applied})> _refreshResult() {
    return _refreshResultFor(null);
  }

  /// Refreshes every live feed that a first-page replace would not collapse.
  ///
  /// Feeds the user scrolled past page 1 are skipped rather than rebuilt, so
  /// a deep-scrolled tab loses neither its position nor its accumulated
  /// items — and, unlike a single global guard, does not suppress the
  /// refresh for the tabs that are still on page 1.
  ///
  /// Each feed is refreshed independently: one feed's failure must not stop
  /// the others from refreshing. The first error is rethrown only when no
  /// feed applied a snapshot, so a partial success still advances the
  /// coordinator's cooldown instead of re-running the whole fan-out on
  /// every trigger.
  ///
  /// A filtered feed is only refreshed while something is subscribed to it.
  /// [_feeds] is append-only, so without that gate a user who swiped through
  /// the five tabs once would pay five REST requests — and five NIP-98
  /// signatures, which are not free on a remote signer — on every later
  /// resume, forever. The unfiltered feed is always refreshed: the badge
  /// reads it whether or not the inbox is on screen.
  Future<bool> _refreshAppliedForLiveFeeds() async {
    final live = _liveFeeds
        .where((feed) => feed.filter == null || feed.snapshot.hasListener)
        .toList(growable: false);
    if (live.isEmpty) {
      return _refreshResult().then((result) => result.applied);
    }

    final feeds = live
        .where((feed) => feed.pagesLoaded <= 1)
        .toList(growable: false);
    // Every live feed is deep-scrolled — refreshing any of them would
    // collapse it, and falling back to the unfiltered feed would collapse
    // that one too.
    if (feeds.isEmpty) return false;

    var applied = false;
    Object? firstError;
    StackTrace? firstStackTrace;
    for (final feed in feeds) {
      try {
        final result = await _refreshResultFor(feed.filter);
        applied = applied || result.applied;
      } on Object catch (e, s) {
        // Deliberately broad: one feed's failure — typed
        // FunnelcakeException or an Error — must not stop the others.
        // The original type and stack are preserved by the rethrow below.
        firstError ??= e;
        firstStackTrace ??= s;
      }
    }
    if (!applied && firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
    return applied;
  }

  Future<({NotificationPage page, bool applied})> _refreshResultFor(
    NotificationKind? filter,
  ) {
    final feed = _feedFor(filter);
    feed
      ..fetchGeneration = feed.fetchGeneration + 1
      ..lastCursor = null
      ..lastCursorId = null;
    return _getNotificationsResult(filter: filter);
  }

  /// Refreshes one filtered notification feed from the beginning.
  Future<NotificationPage> refreshFeed(NotificationKind? filter) {
    return _refreshResultFor(filter).then((result) => result.page);
  }

  /// Fetches the page after the last one applied to the snapshot.
  ///
  /// Returns `null` without issuing a request when no pagination cursor
  /// is stored — before the first page resolves, or immediately after
  /// [refresh] reset the stream — so a racing load-more can never turn
  /// into a duplicate first-page fetch.
  Future<NotificationPage?> loadNextPage() async {
    return loadNextPageFor(null);
  }

  /// Fetches the page after the last one applied to [filter]'s snapshot.
  Future<NotificationPage?> loadNextPageFor(NotificationKind? filter) async {
    final feed = _feedFor(filter);
    if (feed.lastCursor == null) return null;
    return getNotifications(filter: filter);
  }

  void _restoreSnapshots(Map<_NotificationFeed, NotificationPage> values) {
    for (final entry in values.entries) {
      entry.key.snapshot.add(entry.value);
    }
  }

  void _restorePagesLoaded(Map<_NotificationFeed, int> values) {
    for (final entry in values.entries) {
      entry.key.pagesLoaded = entry.value;
    }
  }

  /// Marks specific notifications as read on the server and locally.
  ///
  /// Optimistically flips matching items in the snapshot to `isRead:
  /// true`, then writes through to the API and the local DAO. On
  /// failure, restores the pre-write snapshot so subscribers see the
  /// authoritative state, and rethrows so callers can surface the
  /// error.
  ///
  /// Rollback is scoped to the feeds the flip actually changed. Capturing
  /// every live feed would revert a tab that landed a fresh page while the
  /// POST was in flight — the common case being a tab swipe during the
  /// `markAllAsRead` that runs on inbox open.
  Future<void> markAsRead(List<String> ids) async {
    if (ids.isEmpty) return;

    final idSet = ids.toSet();
    final itemsBefore = <NotificationItem>[];
    final snapshotsBefore = <_NotificationFeed, NotificationPage>{};
    final pagesLoadedBefore = <_NotificationFeed, int>{};
    for (final feed in _liveFeeds.toList()) {
      final page = feed.snapshot.value;
      itemsBefore.addAll(page.items);
      if (!page.items.any((n) => !n.isRead && _matchesMarkReadId(n, idSet))) {
        continue;
      }
      snapshotsBefore[feed] = page;
      pagesLoadedBefore[feed] = feed.pagesLoaded;
      feed.snapshot.add(page.copyWith(items: _flipIsRead(page.items, idSet)));
    }
    final notificationIds = _expandServerNotificationIds(itemsBefore, idSet);

    try {
      // Sign the exact URL + body the request will use, otherwise the
      // funnelcake server 401s with `URL mismatch` / `payload hash
      // mismatch` and the rollback bounces the badge back to N.
      final url = _funnelcakeApiClient
          .notificationsReadUri(pubkey: _userPubkey)
          .toString();
      final body = FunnelcakeApiClient.buildMarkNotificationsReadBody(
        notificationIds: notificationIds,
      );
      final authHeaders = _authHeadersProvider != null
          ? await _authHeadersProvider(url, 'POST', body: body)
          : <String, String>{};

      await _funnelcakeApiClient.markNotificationsRead(
        pubkey: _userPubkey,
        notificationIds: notificationIds,
        authHeaders: authHeaders,
      );

      for (final id in notificationIds) {
        await _notificationsDao.markAsRead(id, ownerPubkey: _userPubkey);
      }
    } catch (_) {
      _restorePagesLoaded(pagesLoadedBefore);
      _restoreSnapshots(snapshotsBefore);
      rethrow;
    }
  }

  /// Marks all notifications as read on the server and locally.
  ///
  /// Always sends the explicit server mark-all request, even when no live
  /// snapshot has local unread rows. The optimistic local flip still only
  /// touches feeds that contain unread rows. On failure, restores the
  /// pre-write snapshot for those feeds — preserving the rollback semantics
  /// introduced by PR #4034 at the repository layer so every consumer
  /// (badge cubit, feed bloc) recovers consistently.
  ///
  /// As in [markAsRead], only the feeds this call actually flipped are
  /// captured for rollback, so a tab that paginated while the POST was in
  /// flight keeps its fresher page.
  Future<void> markAllAsRead() async {
    final snapshotsBefore = <_NotificationFeed, NotificationPage>{};
    final pagesLoadedBefore = <_NotificationFeed, int>{};
    for (final feed in _liveFeeds.toList()) {
      final page = feed.snapshot.value;
      if (page.items.every((n) => n.isRead)) continue;
      snapshotsBefore[feed] = page;
      pagesLoadedBefore[feed] = feed.pagesLoaded;
      feed.snapshot.add(page.copyWith(items: _flipAllRead(page.items)));
    }

    try {
      final url = _funnelcakeApiClient
          .notificationsReadUri(pubkey: _userPubkey)
          .toString();
      final body = FunnelcakeApiClient.buildMarkNotificationsReadBody();
      final authHeaders = _authHeadersProvider != null
          ? await _authHeadersProvider(url, 'POST', body: body)
          : <String, String>{};

      await _funnelcakeApiClient.markNotificationsRead(
        pubkey: _userPubkey,
        authHeaders: authHeaders,
      );

      await _notificationsDao.markAllAsRead(ownerPubkey: _userPubkey);
    } catch (_) {
      _restorePagesLoaded(pagesLoadedBefore);
      _restoreSnapshots(snapshotsBefore);
      rethrow;
    }
  }

  /// Updates [_snapshot] with [page]'s contents.
  ///
  /// First-page emissions replace the items list (used by [refresh] and
  /// the initial [getNotifications] call) — the REST first page is the
  /// authoritative ground truth, so a full replace is correct.
  ///
  /// Subsequent pages merge incoming items into the existing snapshot
  /// using three gates:
  ///
  /// 1. **`(videoEventId, type)` overlap (VideoNotification only)** —
  ///    when an incoming group matches an existing snapshot group, the
  ///    existing row is replaced in place by
  ///    [_mergeAppendedVideoGroup] (richer page data folded into the
  ///    existing row, preserving its position).
  /// 2. **`sourceEventIds` overlap** — when an incoming item's
  ///    underlying Nostr event ids overlap the rendered snapshot's set,
  ///    the incoming item is skipped as a cross-page duplicate (the
  ///    server can deliver the same logical Nostr event as distinct
  ///    rows across pages).
  /// 3. **`id` equality fallback** — defensive against the rare case of
  ///    items with empty `sourceEventIds` (server returned a notification
  ///    without `source_event_id`).
  ///
  /// Together these keep a logical event that reappears on a later page
  /// from duplicating its existing row (#4264).
  void _emitSnapshotForPage(
    _NotificationFeed feed,
    NotificationPage page, {
    required bool isFirstPage,
  }) {
    if (isFirstPage) {
      feed.snapshot.add(page);
      return;
    }
    final current = feed.snapshot.value;
    final mergedItems = _mergeAppendedPage(current.items, page.items);
    feed.snapshot.add(page.copyWith(items: mergedItems));
  }

  /// Returns the merged item list for a non-first-page emission.
  ///
  /// See [_emitSnapshotForPage] for the dedupe/merge contract.
  static List<NotificationItem> _mergeAppendedPage(
    List<NotificationItem> current,
    List<NotificationItem> incoming,
  ) {
    final result = [...current];
    final allSourceEventIds = <String>{
      for (final n in result) ...n.sourceEventIds,
    };
    final allIds = <String>{for (final n in result) n.id};
    final videoGroupIndex = <(String, NotificationKind), int>{};
    final followIndex = <String, int>{};
    for (var i = 0; i < result.length; i++) {
      final item = result[i];
      if (item is VideoNotification) {
        videoGroupIndex[_snapshotVideoGroupKey(item)] = i;
      } else if (item is ActorNotification &&
          item.type == NotificationKind.follow) {
        followIndex[item.actor.pubkey] = i;
      }
    }

    // Appends land in `result` itself so the indices in `followIndex` stay
    // valid for the `result[idx] = …` merges below.
    for (final item in incoming) {
      if (item is VideoNotification) {
        final idx = videoGroupIndex[_snapshotVideoGroupKey(item)];
        if (idx != null) {
          result[idx] = _mergeAppendedVideoGroup(
            result[idx] as VideoNotification,
            item,
          );
          allSourceEventIds.addAll(item.sourceEventIds);
          allIds.add(item.id);
          continue;
        }
      }
      if (item is ActorNotification && item.type == NotificationKind.follow) {
        final idx = followIndex[item.actor.pubkey];
        if (idx != null) {
          result[idx] = _mergeAppendedFollow(
            result[idx] as ActorNotification,
            item,
          );
          allSourceEventIds.addAll(item.sourceEventIds);
          allIds.add(item.id);
          continue;
        }
      }
      final hasOverlap = item.sourceEventIds.any(allSourceEventIds.contains);
      if (hasOverlap) continue;
      // Fallback: catch same-id repeats when sourceEventIds is empty (server
      // omitted source_event_id). Preserves the original by-id dedupe
      // contract.
      if (allIds.contains(item.id)) continue;
      result.add(item);
      allSourceEventIds.addAll(item.sourceEventIds);
      allIds.add(item.id);
      if (item is VideoNotification) {
        videoGroupIndex[_snapshotVideoGroupKey(item)] = result.length - 1;
      }
      if (item is ActorNotification && item.type == NotificationKind.follow) {
        followIndex[item.actor.pubkey] = result.length - 1;
      }
    }
    return result;
  }

  static (String, NotificationKind) _snapshotVideoGroupKey(
    VideoNotification item,
  ) {
    final groupId = item.type == NotificationKind.listAdd
        ? _nonEmpty(item.listCoordinate) ?? item.videoEventId
        : item.videoEventId;
    return (groupId, item.type);
  }

  static ActorNotification _mergeAppendedFollow(
    ActorNotification existing,
    ActorNotification incoming,
  ) {
    final existingIsNewer = !existing.timestamp.isBefore(incoming.timestamp);
    final latest = existingIsNewer ? existing : incoming;
    return latest.copyWith(
      isRead: existing.isRead && incoming.isRead,
      sourceEventIds: <String>{
        ...existing.sourceEventIds,
        ...incoming.sourceEventIds,
      }.toList(),
      notificationIds: <String>{
        ...existing.notificationIds,
        ...incoming.notificationIds,
      }.toList(),
    );
  }

  /// Merges [incoming] (from a REST pagination page) into [existing] (a
  /// row already in the snapshot) without changing the row's position in
  /// the snapshot. Semantics:
  ///
  /// - `sourceEventIds` = set union of both sides (preserves uniqueness).
  /// - `totalCount` = for mention and list-add rows, distinct actor count;
  ///   otherwise size of the source-event union, floored at
  ///   `mergedActors.length` so the constructor's `totalCount >= actors.length`
  ///   invariant always holds even in the defensive edge case where both sides
  ///   had empty `sourceEventIds` (server response missing `source_event_id`).
  /// - `addedVideoCount` for list-add rows = size of the server-notification
  ///   id union.
  /// - `actors` = the union of existing + incoming actors, then
  ///   re-ordered to keep an explicitly named actor in front and capped
  ///   at [_maxGroupActors].
  /// - `isRead` = `existing.isRead && incoming.isRead` (either side
  ///   being unread keeps the row unread).
  /// - `timestamp` = `max(existing.timestamp, incoming.timestamp)`.
  /// - Thumbnail / title / addressable id = existing if non-empty, else
  ///   incoming (parallel to `_groupVideoAnchored`'s
  ///   `_nonEmpty(...) ?? _nonEmpty(...)` pattern).
  /// - `commentText` for comment-kind rows: pick from the side with the
  ///   larger `timestamp`, falling back to the other side only when the
  ///   newer side has no text. Mirrors the long-standing pagination
  ///   merge contract even after lead-actor reordering.
  static VideoNotification _mergeAppendedVideoGroup(
    VideoNotification existing,
    VideoNotification incoming,
  ) {
    final unionIds = <String>{
      ...existing.sourceEventIds,
      ...incoming.sourceEventIds,
    }.toList();
    final unionNotificationIds = <String>{
      ...existing.notificationIds,
      ...incoming.notificationIds,
    }.toList();
    final mergedActors = _orderVideoGroupActors([
      ...existing.actors,
      ...incoming.actors.where(
        (a) => !existing.actors.any((e) => e.pubkey == a.pubkey),
      ),
    ]).take(_maxGroupActors).toList();
    final existingIsNewer = !existing.timestamp.isBefore(incoming.timestamp);
    final mergedTimestamp = existingIsNewer
        ? existing.timestamp
        : incoming.timestamp;
    final mergedCommentText = existing.type == NotificationKind.comment
        ? (existingIsNewer
              ? (existing.commentText ?? incoming.commentText)
              : (incoming.commentText ?? existing.commentText))
        : null;
    final mergedTotalCount = existing.type == NotificationKind.mention
        ? mergedActors.length
        : existing.type == NotificationKind.listAdd
        ? mergedActors.length
        : (unionIds.length >= mergedActors.length
              ? unionIds.length
              : mergedActors.length);
    final mergedAddedVideoCount = existing.type == NotificationKind.listAdd
        ? (unionNotificationIds.length >= mergedActors.length
              ? unionNotificationIds.length
              : mergedActors.length)
        : null;
    return existing.copyWith(
      sourceEventIds: unionIds,
      notificationIds: unionNotificationIds,
      actors: mergedActors,
      totalCount: mergedTotalCount,
      addedVideoCount: mergedAddedVideoCount,
      isRead: existing.isRead && incoming.isRead,
      timestamp: mergedTimestamp,
      videoThumbnailUrl:
          _nonEmpty(existing.videoThumbnailUrl) ??
          _nonEmpty(incoming.videoThumbnailUrl),
      videoTitle:
          _nonEmpty(existing.videoTitle) ?? _nonEmpty(incoming.videoTitle),
      videoAddressableId:
          _nonEmpty(existing.videoAddressableId) ??
          _nonEmpty(incoming.videoAddressableId),
      listTitle: _nonEmpty(existing.listTitle) ?? _nonEmpty(incoming.listTitle),
      listCoordinate:
          _nonEmpty(existing.listCoordinate) ??
          _nonEmpty(incoming.listCoordinate),
      commentText: mergedCommentText,
    );
  }

  /// Returns [items] with the matching ids flipped to `isRead: true`.
  static List<NotificationItem> _flipIsRead(
    List<NotificationItem> items,
    Set<String> ids,
  ) {
    return items.map((n) {
      if (!_matchesMarkReadId(n, ids) || n.isRead) return n;
      return switch (n) {
        VideoNotification() => n.copyWith(isRead: true),
        ActorNotification() => n.copyWith(isRead: true),
      };
    }).toList();
  }

  /// Expands display-row ids to all raw server notification ids represented by
  /// those rows. Unknown ids pass through so callers can still mark a raw id
  /// that is not present in the current snapshot.
  static List<String> _expandServerNotificationIds(
    Iterable<NotificationItem> items,
    Set<String> ids,
  ) {
    final expanded = <String>{};
    final matchedInputIds = <String>{};

    for (final item in items) {
      if (!_matchesMarkReadId(item, ids)) continue;

      matchedInputIds
        ..add(item.id)
        ..addAll(item.notificationIds.where(ids.contains));

      final rawIds = item.notificationIds.isNotEmpty
          ? item.notificationIds
          : [item.id];
      expanded.addAll(rawIds.where((id) => id.isNotEmpty));
    }

    for (final id in ids) {
      if (id.isNotEmpty && !matchedInputIds.contains(id)) {
        expanded.add(id);
      }
    }

    return expanded.toList();
  }

  static bool _matchesMarkReadId(NotificationItem item, Set<String> ids) {
    return ids.contains(item.id) || item.notificationIds.any(ids.contains);
  }

  /// Returns [items] with every item flipped to `isRead: true`.
  static List<NotificationItem> _flipAllRead(List<NotificationItem> items) {
    return items.map((n) {
      if (n.isRead) return n;
      return switch (n) {
        VideoNotification() => n.copyWith(isRead: true),
        ActorNotification() => n.copyWith(isRead: true),
      };
    }).toList();
  }

  /// Enriches raw relay notifications with profile + video metadata, then
  /// groups them into [VideoNotification]s and [ActorNotification]s.
  Future<List<NotificationItem>> _enrichAndGroup(
    List<RelayNotification> raw, {
    NotificationKind? filter,
  }) async {
    if (raw.isEmpty) return [];

    final pubkeys = raw.map((n) => n.sourcePubkey).toSet().toList();
    final eventIds = _videoMetadataEventIds(raw);

    final profilesFuture = _profileRepository.fetchBatchProfiles(
      pubkeys: pubkeys,
    );
    final videosFuture = _fetchVideoMetadata(eventIds);
    final (profiles, videoMetadata) = await (profilesFuture, videosFuture).wait;

    final consolidated = _consolidateFollows(raw);
    final misattributed = <RelayNotification>[];
    final videos = _groupVideoAnchored(
      consolidated,
      profiles,
      videoMetadata.videosById,
      videoNotFoundIds: videoMetadata.notFoundIds,
      misattributed: misattributed,
    );
    final actors = _mapActorAnchored(consolidated, profiles);
    final reclassified = _reclassifyMisattributed(misattributed, profiles);

    final items = <NotificationItem>[...videos, ...actors, ...reclassified]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return _applyBlockFilter(_applyFeedFilter(items, filter));
  }

  List<NotificationItem> _applyFeedFilter(
    List<NotificationItem> items,
    NotificationKind? filter,
  ) {
    if (filter == null) return items;
    return items.where((item) => _belongsInFeed(item, filter)).toList();
  }

  bool _belongsInCommentsFeed(NotificationItem item) {
    if (item.type == NotificationKind.comment ||
        item.type == NotificationKind.reply) {
      return true;
    }
    return item is ActorNotification &&
        item.type == NotificationKind.mention &&
        item.hasCommentTarget;
  }

  /// Filters notifications from blocked/muted users.
  ///
  /// - [VideoNotification]: blocked actors stripped; if no actors remain,
  ///   the entire notification is dropped. The displayed totalCount is
  ///   recomputed from the remaining actors.
  /// - [ActorNotification]: dropped if the actor is blocked.
  List<NotificationItem> _applyBlockFilter(List<NotificationItem> items) {
    final filter = _blockFilter;
    if (filter == null) return items;
    return items
        .map(
          (n) => switch (n) {
            VideoNotification() => () {
              final filtered = n.actors
                  .where((a) => !filter(a.pubkey))
                  .toList();
              if (filtered.isEmpty) return null;
              if (filtered.length == n.actors.length) return n;
              return n.copyWith(actors: filtered, totalCount: filtered.length);
            }(),
            ActorNotification() => filter(n.actor.pubkey) ? null : n,
          },
        )
        .whereType<NotificationItem>()
        .toList();
  }

  /// Fetches [VideoStats] for each id in parallel.
  ///
  /// Per-id failures are tolerated for display metadata, but only a `null`
  /// return from [FunnelcakeApiClient.getVideoStats] is treated as a confirmed
  /// not-found. Thrown errors are transient/unknown misses and must not drive
  /// ownership reclassification.
  Future<_VideoMetadataLookup> _fetchVideoMetadata(
    List<String> eventIds,
  ) async {
    if (eventIds.isEmpty) return const _VideoMetadataLookup.empty();
    final futures = eventIds.map((id) async {
      try {
        final stats = await _funnelcakeApiClient.getVideoStats(id);
        return _VideoMetadataResult(
          id: id,
          stats: stats,
          notFound: stats == null,
        );
      } on Object {
        return _VideoMetadataResult(id: id);
      }
    });
    final results = await Future.wait(futures);
    final map = <String, VideoStats>{};
    final notFoundIds = <String>{};
    for (final result in results) {
      final stats = result.stats;
      if (stats != null) {
        map[result.id] = stats;
      } else if (result.notFound) {
        notFoundIds.add(result.id);
      }
    }
    return _VideoMetadataLookup(videosById: map, notFoundIds: notFoundIds);
  }

  List<String> _videoMetadataEventIds(List<RelayNotification> raw) {
    final eventIds = <String>{};
    for (final notification in raw) {
      final referencedEventId = notification.referencedEventId;
      if (referencedEventId != null &&
          referencedEventId.isNotEmpty &&
          _isEventId(referencedEventId)) {
        eventIds.add(referencedEventId);
      }

      final kind = _mapNotificationKind(notification);
      if (!_isVideoAnchoredNotification(kind, notification)) continue;
      final anchorEventId = _videoAnchorEventId(kind, notification);
      if (anchorEventId != null &&
          anchorEventId.isNotEmpty &&
          _isEventId(anchorEventId)) {
        eventIds.add(anchorEventId);
      }
    }
    return eventIds.toList();
  }

  /// Builds [VideoNotification]s by grouping like/comment/repost
  /// notifications by `(video anchor event id, kind)`.
  ///
  /// Threshold is 1 — every notification with a non-empty video anchor becomes
  /// a [VideoNotification], even if only one actor interacted. Comments can
  /// anchor on `rootEventId` when the payload omits `referencedEventId`.
  ///
  /// Notifications whose referenced video is confirmed to belong to a
  /// different user are collected in [misattributed] for reclassification
  /// as actor-anchored notifications (e.g. "liked your comment" instead of
  /// "liked your video"). This fixes #4813.
  List<VideoNotification> _groupVideoAnchored(
    List<RelayNotification> raw,
    Map<String, UserProfile> profiles,
    Map<String, VideoStats> videosById, {
    required Set<String> videoNotFoundIds,
    List<RelayNotification>? misattributed,
  }) {
    final groups = <_VideoGroupKey, List<RelayNotification>>{};
    for (final n in raw) {
      final kind = _mapNotificationKind(n);
      if (!_isVideoAnchoredNotification(kind, n)) continue;
      final eventId = _videoAnchorEventId(kind, n);
      if (eventId == null || eventId.isEmpty) continue;
      // Video-sourced mentions are anchored to the sender's source video, not
      // the recipient's, so the recipient-owner check does not apply. Their
      // root coordinate is validated separately by
      // _trustedSourceRootAddressableId: a kind 34236 published without a `d`
      // tag makes Funnelcake derive the root from the event's `a`/`A` tag
      // instead, which for an inspired-by or reply video is the *original*
      // creator's coordinate — often the recipient's own.
      if (kind != NotificationKind.mention &&
          _hasKnownReferencedVideoOwnerMismatch(
            kind: kind,
            referencedVideoEventId: eventId,
            videosById: videosById,
            videoNotFoundIds: videoNotFoundIds,
            rootEventPubkey: n.rootEventPubkey,
          )) {
        _logReclassifiedOwnerMismatch(
          notificationId: n.dedupeKey,
          sourcePubkey: n.sourcePubkey,
          referencedVideoEventId: eventId,
          referencedVideoOwnerPubkey: videosById[eventId]?.pubkey,
          rootEventPubkey: n.rootEventPubkey,
        );
        misattributed?.add(n);
        continue;
      }
      final video = videosById[eventId];
      final key = _VideoGroupKey(
        groupId: _videoGroupId(kind, n, eventId, video: video),
        eventId: eventId,
        kind: kind,
      );
      (groups[key] ??= []).add(n);
    }

    final result = <VideoNotification>[];
    for (final entry in groups.entries) {
      final group = entry.value
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final isVideoMention = entry.key.kind == NotificationKind.mention;
      final isListAdd = entry.key.kind == NotificationKind.listAdd;
      final actorNotifications = _orderVideoGroupActorNotifications(
        group,
        profiles,
      );
      final displayActorNotifications = isVideoMention || isListAdd
          ? _distinctActorNotificationsBySourcePubkey(actorNotifications)
          : actorNotifications;
      final actors = _orderVideoGroupActors(
        displayActorNotifications
            .take(_maxGroupActors)
            .map((n) => _buildActor(n.sourcePubkey, profiles))
            .toList(),
      );
      final rowEventId = isListAdd
          ? _videoAnchorEventId(entry.key.kind, group.first) ??
                entry.key.eventId
          : entry.key.eventId;
      final totalCount = isVideoMention || isListAdd
          ? group.map((n) => n.sourcePubkey).toSet().length
          : group.length;
      final addedVideoCount = isListAdd ? group.length : null;
      final video = videosById[rowEventId];
      // Funnelcake sets `referenced_d_tag` from `root_d_tag`, so both name the
      // same coordinate (funnelcake `client.rs:12145`).
      final dTag = isListAdd
          ? group.first.referencedDTag
          : group
                .map((n) => n.referencedDTag)
                .firstWhere((d) => d != null, orElse: () => null);
      final trustedRootAddressableId = isVideoMention
          ? _trustedRootAddressableIdForGroup(group, video: video)
          : null;
      // `root_d_tag` and the `referenced_video` block are both keyed on the
      // root coordinate, so rejecting that coordinate as untrusted invalidates
      // them too — splicing either one back in would describe another
      // creator's video under "mentioned you".
      final trustsRootPayload =
          !isVideoMention || trustedRootAddressableId != null;
      final groupRootEventPubkey = _groupRootEventPubkey(
        group,
        entry.key.eventId,
      );
      final addressableId = isVideoMention
          ? trustedRootAddressableId ?? _sourceVideoAddressableId(video: video)
          : isListAdd
          ? _listAddVideoAddressableId(
              group.first,
              dTag: dTag,
              video: video,
              rootEventPubkey: groupRootEventPubkey,
            )
          : _recipientScopedVideoAddressableId(
              dTag: dTag,
              video: video,
              rootEventPubkey: groupRootEventPubkey,
            );
      // Normal video rows prefer payload media because it is stable after
      // metadata updates. Video mentions prefer the resolved source video, and
      // only accept payload media when the root coordinate was trusted.
      final thumbnailFromNotif = group
          .map((n) => n.referencedVideoThumbnail)
          .firstWhere((t) => t != null && t.isNotEmpty, orElse: () => null);
      final titleFromNotif = group
          .map((n) => n.referencedVideoTitle)
          .firstWhere((t) => t != null && t.isNotEmpty, orElse: () => null);
      final thumbnailUrl = isVideoMention
          ? _nonEmpty(video?.thumbnail) ??
                (trustsRootPayload ? _nonEmpty(thumbnailFromNotif) : null)
          : _nonEmpty(thumbnailFromNotif) ?? _nonEmpty(video?.thumbnail);
      final videoTitle = isVideoMention
          ? _nonEmpty(video?.title) ??
                (trustsRootPayload ? _nonEmpty(titleFromNotif) : null)
          : _nonEmpty(titleFromNotif) ?? _nonEmpty(video?.title);
      // Carry the lead actor's comment text so the quoted body stays in
      // sync with the bold first-actor span after named-actor reordering.
      // Only meaningful for `comment` kind — likes and reposts have no
      // body text. Reuses the same length-cap as actor-anchored comments
      // / replies for layout safety.
      final commentTextForRow = entry.key.kind == NotificationKind.comment
          ? _truncateComment(actorNotifications.first.content, entry.key.kind)
          : null;
      result.add(
        VideoNotification(
          id: group.first.dedupeKey,
          type: entry.key.kind,
          videoEventId: rowEventId,
          videoAddressableId: addressableId,
          videoThumbnailUrl: thumbnailUrl,
          videoTitle: videoTitle,
          listTitle: entry.key.kind == NotificationKind.listAdd
              ? group
                    .map((n) => n.listTitle)
                    .firstWhere((t) => t != null, orElse: () => null)
              : null,
          listCoordinate: entry.key.kind == NotificationKind.listAdd
              ? group
                    .map((n) => n.listCoordinate)
                    .firstWhere((c) => c != null, orElse: () => null)
              : null,
          actors: actors,
          totalCount: totalCount,
          addedVideoCount: addedVideoCount,
          timestamp: group.first.createdAt,
          isRead: group.every((n) => n.read),
          commentText: commentTextForRow,
          sourceEventIds: group
              .map((n) => n.sourceEventId)
              .where((s) => s.isNotEmpty)
              .toList(),
          notificationIds: group
              .map((n) => n.dedupeKey)
              .where((s) => s.isNotEmpty)
              .toList(),
        ),
      );
    }
    return result;
  }

  static bool _isVideoAnchoredKind(NotificationKind kind) =>
      kind == NotificationKind.like ||
      kind == NotificationKind.comment ||
      kind == NotificationKind.repost ||
      kind == NotificationKind.newPost ||
      kind == NotificationKind.listAdd;

  static bool _isVideoAnchoredNotification(
    NotificationKind kind,
    RelayNotification notification,
  ) => _isVideoAnchoredKind(kind) || _isVideoSourcedMention(notification);

  /// Builds [ActorNotification]s for follow/mention/system kinds and
  /// reactions that have no concrete video event ID.
  ///
  /// `reply` and other unmapped kinds are also routed here as
  /// [ActorNotification] — they don't have a clean video anchor, so we
  /// surface them as actor-anchored rows.
  List<ActorNotification> _mapActorAnchored(
    List<RelayNotification> raw,
    Map<String, UserProfile> profiles,
  ) {
    final result = <ActorNotification>[];
    for (final n in raw) {
      final kind = _mapNotificationKind(n);
      final isAnchorlessLike =
          kind == NotificationKind.like &&
          _nonEmpty(_videoAnchorEventId(kind, n)) == null;
      // Skip kinds that became VideoNotifications. An a-tag-only reaction has
      // no event ID to group on, so keep it as an actor-backed like instead of
      // silently dropping it from both pipelines.
      if ((_isVideoAnchoredKind(kind) && !isAnchorlessLike) ||
          _isVideoSourcedMention(n)) {
        continue;
      }
      // ActorNotification supports follow/like/mention/system/likeComment/
      // reply; coerce any other kind to system.
      final mapped =
          (kind == NotificationKind.follow ||
              kind == NotificationKind.like ||
              kind == NotificationKind.mention ||
              kind == NotificationKind.system ||
              kind == NotificationKind.likeComment ||
              kind == NotificationKind.reply)
          ? kind
          : NotificationKind.system;
      result.add(
        _buildActorNotification(
          n,
          type: mapped,
          profiles: profiles,
          commentKind: kind,
        ),
      );
    }
    return result;
  }

  /// Reclassifies video-anchored notifications that were dropped because
  /// the referenced video is owned by a different user.
  ///
  /// Instead of silently dropping these, they are surfaced as
  /// [ActorNotification]s with the correct kind:
  /// - `like` (reaction on someone else's video) → `likeComment`
  ///   ("liked your comment")
  /// - `comment` (reply on someone else's video) → `reply`
  ///   ("replied to your comment")
  /// - `repost` remains dropped — a repost of someone else's video should
  ///   not notify the commenter.
  ///
  /// Fixes #4813: user sees "liked your video" / "commented on your video"
  /// for interactions that are actually on their comments on other users'
  /// videos.
  List<ActorNotification> _reclassifyMisattributed(
    List<RelayNotification> misattributed,
    Map<String, UserProfile> profiles,
  ) {
    final result = <ActorNotification>[];
    for (final n in misattributed) {
      final originalKind = _mapNotificationKind(n);
      final reclassifiedKind = _reclassifiedMisattributedKind(originalKind);
      if (reclassifiedKind == null) continue;
      result.add(
        _buildActorNotification(
          n,
          type: reclassifiedKind,
          profiles: profiles,
          targetEventId: _reclassifiedMisattributedTargetEventId(
            reclassifiedKind,
            n,
          ),
        ),
      );
    }
    return result;
  }

  ActorNotification _buildActorNotification(
    RelayNotification notification, {
    required NotificationKind type,
    required Map<String, UserProfile> profiles,
    NotificationKind? commentKind,
    String? targetEventId,
  }) {
    final quoteKind = commentKind ?? type;
    return ActorNotification(
      id: notification.dedupeKey,
      type: type,
      actor: _buildActor(notification.sourcePubkey, profiles),
      timestamp: notification.createdAt,
      isRead: notification.read,
      commentText: _truncateComment(
        _commentQuoteSource(notification, quoteKind),
        quoteKind,
      ),
      targetEventId: targetEventId ?? _actorTargetEventId(type, notification),
      sourceEventIds: notification.sourceEventId.isNotEmpty
          ? [notification.sourceEventId]
          : const [],
      notificationIds: notification.dedupeKey.isNotEmpty
          ? [notification.dedupeKey]
          : const [],
      videoAddressableId: _actorVideoAddressableId(type, notification),
      hasCommentTarget: _actorHasCommentTarget(type, notification),
    );
  }

  /// Raw text a row quotes beneath its message, before truncation.
  ///
  /// `comment` and `reply` quote the source event's own body. A
  /// `likeComment` row instead quotes the comment that was liked: its
  /// source event is a kind 7 reaction whose `content` is just the emoji,
  /// so without `comment_content` the row states that someone liked a
  /// comment while naming neither the comment nor its video.
  static String? _commentQuoteSource(
    RelayNotification notification,
    NotificationKind kind,
  ) => kind == NotificationKind.likeComment
      ? notification.commentContent
      : notification.content;

  static bool _actorHasCommentTarget(
    NotificationKind type,
    RelayNotification notification,
  ) =>
      type == NotificationKind.likeComment ||
      type == NotificationKind.reply ||
      (type == NotificationKind.mention &&
          _nonEmpty(notification.targetCommentId) != null);

  static NotificationKind? _reclassifiedMisattributedKind(
    NotificationKind originalKind,
  ) => switch (originalKind) {
    NotificationKind.like => NotificationKind.likeComment,
    NotificationKind.comment => NotificationKind.reply,
    // Reposts on foreign videos are not meaningful for the commenter.
    _ => null,
  };

  static String? _reclassifiedMisattributedTargetEventId(
    NotificationKind reclassifiedKind,
    RelayNotification notification,
  ) {
    final targetCommentId = _nonEmpty(notification.targetCommentId);
    if (targetCommentId != null) return targetCommentId;

    // Misattributed rows often carry the foreign video as referencedEventId
    // because FunnelCake included it for navigation context. Without the
    // comment id, keep the standard actor target fallback so taps can still
    // resolve or degrade through the existing navigation path.
    return _actorTargetEventId(reclassifiedKind, notification);
  }

  /// Returns null if [s] is null or empty, otherwise [s].
  static String? _nonEmpty(String? s) => (s == null || s.isEmpty) ? null : s;

  static ({int kind, String pubkey, String dTag})? _parseAddressableId(
    String addressableId,
  ) {
    final parts = addressableId.split(':');
    if (parts.length < 3) return null;
    final kind = int.tryParse(parts[0]);
    if (kind == null) return null;
    return (kind: kind, pubkey: parts[1], dTag: parts.sublist(2).join(':'));
  }

  /// Returns the `targetEventId` for an actor-anchored notification.
  ///
  /// - anchorless `like` → the reaction event ID (resolver follows its `a` tag
  ///   to the video when no recipient-owned root coordinate is available).
  /// - `likeComment`/`reply` → the referenced comment event ID (resolver
  ///   walks its E-tags to reach the root video).
  /// - `mention` → the source event ID (the kind-1 event that mentioned
  ///   the user; same resolver path).
  /// - Everything else → null.
  ///
  /// Used by the page-load path ([_mapActorAnchored]).
  static String? _actorTargetEventId(
    NotificationKind mapped,
    RelayNotification n,
  ) => switch (mapped) {
    NotificationKind.like =>
      n.sourceEventId.isNotEmpty ? n.sourceEventId : null,
    NotificationKind.likeComment || NotificationKind.reply =>
      // Prefer the explicit parent comment ID. Some Funnelcake reply payloads
      // carry the root video in referenced_event_id and the actual parent
      // comment in target_comment_id.
      n.targetCommentId?.isNotEmpty == true
          ? n.targetCommentId
          : n.referencedEventId?.isNotEmpty == true
          ? n.referencedEventId
          : (n.sourceEventId.isNotEmpty ? n.sourceEventId : null),
    NotificationKind.mention =>
      n.sourceEventId.isNotEmpty ? n.sourceEventId : null,
    _ => null,
  };

  /// Builds the stable NIP-33 addressable route for the video a video-anchored
  /// notification (like/comment/repost) points at, always scoped to
  /// [_userPubkey], or null when no usable d-tag is available.
  ///
  /// Video-anchored notifications are structurally about the recipient's own
  /// video; a confirmed *different* owner is reclassified to an actor row
  /// upstream ([_groupVideoAnchored] / #4920) before this is reached. So
  /// ownership here is either confirmed-recipient or unconfirmable (a metadata
  /// miss: stale/edited event id or fetch failure). In both cases we synthesize
  /// the route rather than
  /// dropping to the raw, often-stale `referencedEventId` — which is the #4730
  /// broken-link gap: once the recipient edits a video, its old event id no
  /// longer resolves, so the stable route is the only thing that reopens it.
  ///
  /// Safety bound (unchanged from #4730): the pubkey is pinned to
  /// [_userPubkey], so a wrong/stale d-tag can only ever surface the
  /// recipient's *own* (or a non-existent) video — never another creator's.
  /// The relaxation is purely *when* to synthesize (now also on a metadata
  /// miss), not *whose* video the route can address. Tradeoff: a misattributed
  /// notification whose ownership the metadata fetch happened to miss now
  /// resolves to the recipient's d-tag match (or not-found) instead of the
  /// other creator's event id. The route resolver preserves this bound by
  /// validating addressable candidates before cache or REST hits can satisfy
  /// the coordinate.
  ///
  /// Prefers the authoritative `VideoStats` d-tag over the payload [dTag] so a
  /// `referenced_video` block disagreeing with `referenced_event_id` cannot
  /// build a mismatched route.
  ///
  /// [rootEventPubkey] is the payload's root-video author. It is evidence
  /// about the anchored video only when the anchor IS the thread root — a
  /// comment with an empty `referenced_event_id`, or a like/repost/list-add
  /// of the root video itself. Callers pass null otherwise: for a comment on
  /// the user's own video *reply* inside someone else's thread, the root
  /// author is the other creator while the anchored reply still belongs to
  /// the user, and gating on the payload there would kill the legitimate
  /// stable route (#4730) that #6369 must not regress.
  String? _recipientScopedVideoAddressableId({
    required String? dTag,
    required VideoStats? video,
    String? rootEventPubkey,
  }) {
    // Defensive local invariant: metadata that resolves and names a different
    // owner never yields a recipient-scoped route. Unreachable via
    // _groupVideoAnchored (those are reclassified to actor rows, #4920).
    if (video != null && video.pubkey != _userPubkey) return null;

    // Payload fallback for #6369: the anchor is the thread root, metadata
    // could not resolve its owner (transient miss), and the payload's root
    // author is someone else — minting `<userPubkey>:<d-tag>` would route to
    // a video that does not exist. Resolved metadata wins over the payload
    // (#6805), so this only fires on a metadata miss.
    if (video == null &&
        rootEventPubkey != null &&
        rootEventPubkey.isNotEmpty &&
        rootEventPubkey != _userPubkey) {
      return null;
    }

    final resolvedDTag = _nonEmpty(video?.dTag) ?? _nonEmpty(dTag);
    if (resolvedDTag == null) return null;
    return '${NIP71VideoKinds.addressableShortVideo}'
        ':$_userPubkey:$resolvedDTag';
  }

  /// The payload's root-video author for [anchorEventId], derived across the
  /// whole group instead of sampled from one member: notifications sharing an
  /// anchor can disagree — a transient Funnelcake gap can leave the newest
  /// member's `root_event_pubkey` empty while an older member carries it — and
  /// a single sampled member would make the #6369 guard order-dependent.
  ///
  /// Only a member whose thread root IS the anchor describes the anchored
  /// video's root author: for a comment on the user's own video *reply*
  /// inside someone else's thread, the root author is the other creator while
  /// the anchored reply still belongs to the user, and gating on the payload
  /// there would kill the legitimate stable route (#4730) that #6369 must not
  /// regress. A foreign author from any root-anchored member wins over the
  /// user's own — minting `<userPubkey>:<d-tag>` on contradictory ownership
  /// evidence is the #6369 failure.
  String? _groupRootEventPubkey(
    List<RelayNotification> group,
    String anchorEventId,
  ) {
    String? ownAuthor;
    for (final n in group) {
      if (n.rootEventId != anchorEventId) continue;
      final author = _nonEmpty(n.rootEventPubkey);
      if (author == null) continue;
      if (author != _userPubkey) return author;
      ownAuthor ??= author;
    }
    return ownAuthor;
  }

  /// Returns the full source-video coordinate for video-sourced mention rows.
  ///
  /// Unlike likes/comments/reposts on the recipient's own video, a kind 34236
  /// mention is anchored to the sender's source video. The authoritative
  /// coordinate is the root coordinate from Funnelcake; this is the fallback
  /// used only once [_trustedSourceRootAddressableId] has rejected it, so both
  /// halves must come from the resolved [VideoStats]. Taking the d-tag from the
  /// payload instead would splice the rejected coordinate's d-tag onto the
  /// sender's pubkey and mint a route to a video that does not exist.
  String? _sourceVideoAddressableId({required VideoStats? video}) {
    final ownerPubkey = _nonEmpty(video?.pubkey);
    final resolvedDTag = _nonEmpty(video?.dTag);
    if (ownerPubkey == null || resolvedDTag == null) return null;
    return '${NIP71VideoKinds.addressableShortVideo}'
        ':$ownerPubkey:$resolvedDTag';
  }

  static String? _trustedRootAddressableIdForGroup(
    List<RelayNotification> group, {
    required VideoStats? video,
  }) => group
      .map((n) => _trustedSourceRootAddressableId(n, video: video))
      .firstWhere((id) => id != null && id.isNotEmpty, orElse: () => null);

  static String? _trustedSourceRootAddressableId(
    RelayNotification notification, {
    required VideoStats? video,
  }) {
    final addressableId = _nonEmpty(notification.rootAddressableId);
    if (addressableId == null) return null;
    final parsed = _parseAddressableId(addressableId);
    if (parsed == null) return null;
    final rootKind = notification.rootEventKind;
    if (rootKind != null && parsed.kind != rootKind) return null;
    if (!NIP71VideoKinds.isVideoKind(rootKind ?? parsed.kind)) return null;
    if (parsed.pubkey.isEmpty || parsed.dTag.isEmpty) return null;
    if (parsed.pubkey != notification.sourcePubkey) return null;

    final resolvedOwner = _nonEmpty(video?.pubkey);
    if (resolvedOwner != null && parsed.pubkey != resolvedOwner) return null;
    return addressableId;
  }

  /// Returns the stable NIP-33 addressable ID for an actor-anchored
  /// notification, when the server provided the root video's full coordinate.
  ///
  /// Populated for actor-anchored rows only when the coordinate is usable for
  /// that row's ownership claim. Anchorless `like` rows render "liked your
  /// video", so their direct route must name the notification recipient's own
  /// video. `likeComment` and `reply` rows may legitimately route to a foreign
  /// root video because the notification is about the recipient's comment on
  /// that video.
  ///
  /// Used by the page-load path ([_mapActorAnchored]).
  String? _actorVideoAddressableId(
    NotificationKind mapped,
    RelayNotification notification,
  ) {
    if (mapped != NotificationKind.like &&
        mapped != NotificationKind.likeComment &&
        mapped != NotificationKind.reply) {
      return null;
    }
    final addressableId = _nonEmpty(notification.rootAddressableId);
    if (addressableId == null) return null;
    final parsed = _parseAddressableId(addressableId);
    if (parsed == null) return null;
    if (!NIP71VideoKinds.isVideoKind(parsed.kind)) return null;
    if (parsed.pubkey.isEmpty || parsed.dTag.isEmpty) return null;
    if (mapped == NotificationKind.like && parsed.pubkey != _userPubkey) {
      return null;
    }
    return addressableId;
  }

  bool _hasKnownReferencedVideoOwnerMismatch({
    required NotificationKind kind,
    required String referencedVideoEventId,
    required Map<String, VideoStats> videosById,
    required Set<String> videoNotFoundIds,
    String? rootEventPubkey,
  }) {
    // Authoritative owner of the event the notification actually anchors on.
    // When metadata resolves it, it decides ownership outright: a like/repost
    // on the user's own video — including a video-reply whose thread root
    // belongs to another creator — is a genuine "…your video" and must NOT be
    // reclassified. Trusting the payload's root author here instead would
    // mislabel that like as "liked your comment" and silently drop the repost.
    final ownerPubkey = videosById[referencedVideoEventId]?.pubkey;
    if (ownerPubkey != null && ownerPubkey.isNotEmpty) {
      return ownerPubkey != _userPubkey;
    }
    // Only a confirmed not-found is precise enough for the weaker root-author
    // fallback. A thrown metadata fetch may be a timeout or API failure for a
    // real user-owned video, so it must leave the row video-anchored.
    if (!videoNotFoundIds.contains(referencedVideoEventId)) return false;

    // Repost reclassification is destructive: foreign-video reposts are
    // intentionally dropped later. Do not let root author alone delete a row.
    if (kind == NotificationKind.repost) return false;

    // The anchor may be a comment id rather than a video id. In that confirmed
    // not-found case, fall back to the payload's root video author: for a
    // reaction on the user's comment on someone else's video this is the other
    // creator, so a "liked your video" row should be actor-anchored instead.
    if (rootEventPubkey != null &&
        rootEventPubkey.isNotEmpty &&
        rootEventPubkey != _userPubkey) {
      return true;
    }
    return false;
  }

  void _logReclassifiedOwnerMismatch({
    required String notificationId,
    required String sourcePubkey,
    required String referencedVideoEventId,
    required String? referencedVideoOwnerPubkey,
    required String? rootEventPubkey,
  }) {
    Log.info(
      'Reclassifying misattributed video notification as actor-anchored: '
      'notificationId=$notificationId '
      'sourcePubkey=${pubkeyForLogs(sourcePubkey)} '
      'referencedVideoEventId=$referencedVideoEventId '
      'referencedVideoOwnerPubkey='
      '${pubkeyForLogs(referencedVideoOwnerPubkey, whenNull: 'unknown')} '
      'rootEventPubkey=${pubkeyForLogs(rootEventPubkey, whenNull: 'unknown')} '
      'currentUserPubkey=${pubkeyForLogs(_userPubkey)}',
      name: 'NotificationRepository',
      category: LogCategory.api,
    );
  }

  /// Consolidates follow notifications — keeps the most recent per pubkey.
  ///
  /// Kind 3 (contact list) is a replaceable event: a single follower can
  /// produce several follow notifications over time (re-publishes).
  /// Collapsing them to one row per `sourcePubkey` keeps the Follows tab
  /// from showing the same person repeatedly.
  ///
  /// The surviving row must carry the *latest* `createdAt`, not the
  /// earliest. The feed sorts newest-first and paginates, so stamping a
  /// recent follow with a stale timestamp sinks it below older
  /// notifications — potentially off the first page entirely, which
  /// surfaces as an empty "Follows" tab even though the follow exists.
  List<RelayNotification> _consolidateFollows(List<RelayNotification> raw) {
    final followsByPubkey = <String, RelayNotification>{};
    final result = <RelayNotification>[];

    for (final n in raw) {
      final kind = _mapNotificationKind(n);
      if (kind == NotificationKind.follow) {
        final existing = followsByPubkey[n.sourcePubkey];
        if (existing == null || n.createdAt.isAfter(existing.createdAt)) {
          followsByPubkey[n.sourcePubkey] = n;
        }
      } else {
        result.add(n);
      }
    }

    result.addAll(followsByPubkey.values);
    return result;
  }

  /// Builds an [ActorInfo] from a pubkey and the profile lookup map.
  ActorInfo _buildActor(String pubkey, Map<String, UserProfile> profiles) {
    final profile = profiles[pubkey];
    return ActorInfo(
      pubkey: pubkey,
      displayName: _displayNameForActor(pubkey, profile),
      pictureUrl: profile?.picture,
    );
  }

  /// Orders grouped video notifications with a named profile in the lead
  /// actor position.
  List<RelayNotification> _orderVideoGroupActorNotifications(
    List<RelayNotification> group,
    Map<String, UserProfile> profiles,
  ) {
    RelayNotification? lead;
    for (final n in group) {
      if (_hasExplicitActorName(n.sourcePubkey, profiles)) {
        lead = n;
        break;
      }
    }

    final ordered = lead == null
        ? group
        : <RelayNotification>[lead, ...group.where((n) => !identical(n, lead))];
    return ordered;
  }

  static List<RelayNotification> _distinctActorNotificationsBySourcePubkey(
    List<RelayNotification> notifications,
  ) {
    final seen = <String>{};
    return [
      for (final notification in notifications)
        if (seen.add(notification.sourcePubkey)) notification,
    ];
  }

  static bool _hasExplicitActorName(
    String pubkey,
    Map<String, UserProfile> profiles,
  ) => _explicitActorName(pubkey, profiles[pubkey]) != null;

  static String _displayNameForActor(String pubkey, UserProfile? profile) {
    final explicit = _explicitActorName(pubkey, profile);
    if (explicit != null) return explicit;

    final fallback = profile?.bestDisplayName;
    if (_isUsableActorName(fallback, pubkey)) return fallback!.trim();

    return UserProfile.defaultDisplayNameFor(pubkey);
  }

  static String? _explicitActorName(String pubkey, UserProfile? profile) {
    if (profile == null) return null;

    final displayName = profile.displayName;
    if (_isUsableActorName(displayName, pubkey)) {
      return sanitizeForDisplay(displayName!).trim();
    }

    final name = profile.name;
    if (_isUsableActorName(name, pubkey)) {
      return sanitizeForDisplay(name!).trim();
    }

    return null;
  }

  static List<ActorInfo> _orderVideoGroupActors(List<ActorInfo> actors) {
    ActorInfo? lead;
    for (final actor in actors) {
      if (_hasPreferredLeadActorName(actor.displayName, actor.pubkey)) {
        lead = actor;
        break;
      }
    }

    if (lead == null) return actors;
    return [lead, ...actors.where((actor) => actor.pubkey != lead!.pubkey)];
  }

  static bool _hasPreferredLeadActorName(String displayName, String pubkey) {
    if (!_isUsableActorName(displayName, pubkey)) {
      return false;
    }
    return displayName.trim() != UserProfile.defaultDisplayNameFor(pubkey);
  }

  static bool _isUsableActorName(String? value, String pubkey) {
    final name = value?.trim();
    if (name == null || name.isEmpty) return false;

    final lower = name.toLowerCase();
    if (lower == 'unknown' || lower == 'unknown user') return false;
    if (name == pubkey) return false;
    if (_hexIdentifierPattern.hasMatch(name)) return false;
    if (_npubIdentifierPattern.hasMatch(name)) return false;

    return true;
  }

  /// Maps a relay notification type string + source kind to
  /// [NotificationKind].
  ///
  /// Likes (and zaps) on a comment map to [NotificationKind.likeComment]
  /// so the UI can render "liked your comment" instead of "liked your
  /// video". A comment target is identified by a non-empty
  /// `targetCommentId`, which Funnelcake sets to the comment's event ID
  /// for reactions on a kind 1111 comment. That signal is the *only* one
  /// used for the split.
  ///
  /// `isReferencedVideo` deliberately plays no part. It reports whether
  /// Funnelcake managed to attach a `referenced_video` block, which it
  /// builds from the notification's *root* video — so it is set for a like
  /// on a comment (whose root is that video) exactly as it is for a like on
  /// the video itself, and it is unset whenever the root video simply
  /// failed to resolve. Treating its absence as evidence of a comment
  /// target relabelled ordinary video likes as "liked your comment"
  /// whenever the video was unindexed or deleted.
  ///
  /// A reaction on a comment that Funnelcake could not resolve leaves
  /// `targetCommentId` empty and so lands here as [NotificationKind.like].
  /// That residual case is caught downstream by
  /// [_hasKnownReferencedVideoOwnerMismatch], which reclassifies it to
  /// `likeComment` once a confirmed metadata 404 plus a foreign
  /// `root_event_pubkey` prove the anchor is not the user's own video.
  ///
  /// Replies (kind 1111) split by the immediate target, not by whether the
  /// payload also carries root video metadata. A reply directly on a video
  /// is indistinguishable from a comment for the user, so we map it to
  /// [NotificationKind.comment]. A reply on another comment maps to
  /// [NotificationKind.reply], even when Funnelcake also includes the root
  /// video's metadata for navigation.
  static NotificationKind _mapNotificationKind(RelayNotification n) {
    final isReaction = switch (n.notificationType) {
      'reaction' || 'zap' => true,
      _ => n.sourceKind == 7,
    };
    if (isReaction) {
      final targetCommentId = n.targetCommentId;
      final targetsComment =
          targetCommentId != null && targetCommentId.isNotEmpty;
      return targetsComment
          ? NotificationKind.likeComment
          : NotificationKind.like;
    }
    if (_isNestedCommentReply(n)) {
      return NotificationKind.reply;
    }
    if (n.notificationType != 'reply' &&
        n.sourceKind == 1111 &&
        n.rootEventId != null &&
        n.rootEventId!.isNotEmpty) {
      return NotificationKind.comment;
    }
    return switch (n.notificationType) {
      'reply' =>
        n.isReferencedVideo ? NotificationKind.comment : NotificationKind.reply,
      'comment' => NotificationKind.comment,
      'repost' => NotificationKind.repost,
      'mention' => NotificationKind.mention,
      'newPost' => NotificationKind.newPost,
      'list_add' => NotificationKind.listAdd,
      'follow' || 'contact' => NotificationKind.follow,
      _ when n.sourceKind == 6 => NotificationKind.repost,
      _ when n.sourceKind == 16 => NotificationKind.repost,
      _ when n.sourceKind == 3 => NotificationKind.follow,
      _ when n.sourceKind == 1 => NotificationKind.comment,
      _ => NotificationKind.system,
    };
  }

  static bool _isVideoSourcedMention(RelayNotification n) =>
      n.notificationType == 'mention' &&
      NIP71VideoKinds.isVideoKind(n.sourceKind);

  static String _videoGroupId(
    NotificationKind kind,
    RelayNotification n,
    String eventId, {
    required VideoStats? video,
  }) {
    if (kind == NotificationKind.mention && _isVideoSourcedMention(n)) {
      return _trustedSourceRootAddressableId(n, video: video) ?? eventId;
    }
    if (kind == NotificationKind.listAdd) {
      return _nonEmpty(n.listCoordinate) ?? eventId;
    }
    return eventId;
  }

  static bool _isNestedCommentReply(RelayNotification n) {
    if (n.notificationType != 'reply' && n.notificationType != 'comment') {
      return false;
    }
    if (n.sourceKind != 1111) return false;
    final rootEventId = n.rootEventId;
    if (rootEventId == null || rootEventId.isEmpty) return false;

    final referencedEventId = n.referencedEventId;
    if (referencedEventId != null &&
        referencedEventId.isNotEmpty &&
        referencedEventId != rootEventId &&
        !n.isReferencedVideo) {
      return true;
    }

    final targetCommentId = n.targetCommentId;
    if (n.isReferencedVideo && targetCommentId == referencedEventId) {
      return false;
    }
    return targetCommentId != null &&
        targetCommentId.isNotEmpty &&
        n.sourceEventId.isNotEmpty &&
        targetCommentId != n.sourceEventId &&
        targetCommentId != rootEventId;
  }

  /// Returns the video event ID a video-anchored notification should group by.
  ///
  /// New staging Funnelcake payloads for NIP-22 comments can omit
  /// `referenced_event_id` while including `root_event_id`. For comments, the
  /// root ID is the video we want to open and group on unless the referenced
  /// event is itself a video, which happens for comments on video replies.
  String? _videoAnchorEventId(
    NotificationKind kind,
    RelayNotification n,
  ) {
    if (kind == NotificationKind.mention && _isVideoSourcedMention(n)) {
      return _nonEmpty(n.sourceEventId);
    }
    if (kind == NotificationKind.comment) {
      if (n.isReferencedVideo &&
          n.referencedEventId != null &&
          n.referencedEventId!.isNotEmpty) {
        return n.referencedEventId;
      }
      if (n.rootEventId != null && n.rootEventId!.isNotEmpty) {
        return n.rootEventId;
      }
    }
    if (kind == NotificationKind.listAdd) {
      return _nonEmpty(n.referencedEventId) ??
          _nonEmpty(n.rootEventId) ??
          _trustedListAddRootAddressableId(n);
    }
    return n.referencedEventId;
  }

  /// [rootEventPubkey] is the group-derived root author from
  /// [_groupRootEventPubkey], which already restricts the evidence to members
  /// whose thread root IS the anchor. Deriving it across the group rather than
  /// sampling [notification] matters for the same reason it does for comments:
  /// a list-add group shares an anchor across several adders, and a transient
  /// Funnelcake gap can leave the newest member's `root_event_pubkey` empty
  /// while an older member carries the foreign one.
  String? _listAddVideoAddressableId(
    RelayNotification notification, {
    required String? dTag,
    required VideoStats? video,
    String? rootEventPubkey,
  }) {
    final addressableId = _trustedListAddRootAddressableId(notification);
    if (addressableId != null) {
      return addressableId;
    }
    return _recipientScopedVideoAddressableId(
      dTag: dTag,
      video: video,
      rootEventPubkey: rootEventPubkey,
    );
  }

  String? _trustedListAddRootAddressableId(RelayNotification notification) {
    final addressableId = _nonEmpty(notification.rootAddressableId);
    if (addressableId == null) return null;
    final parsed = _parseAddressableId(addressableId);
    if (parsed == null) return null;
    final rootKind = notification.rootEventKind;
    if (rootKind != null && parsed.kind != rootKind) return null;
    if (!NIP71VideoKinds.isVideoKind(parsed.kind)) return null;
    if (parsed.pubkey != _userPubkey || parsed.dTag.isEmpty) return null;
    return addressableId;
  }

  static bool _isEventId(String id) => _parseAddressableId(id) == null;

  /// Truncates comment text to [_maxCommentLength] characters, keeping any
  /// Nostr reference that straddles the cut intact.
  ///
  /// Only applies to the kinds that render a quote: comment, reply, and
  /// likeComment. Pair it with [_commentQuoteSource], which picks the text
  /// each kind should quote.
  ///
  /// The cut never splits a Nostr reference the UI can decode — bech32
  /// (`npub1...`, `nprofile1...`, `note1...`, `nevent1...`, `naddr1...`) or a
  /// bare 64-char hex pubkey / event id. A sliced token can no longer be
  /// decoded, so the row widget falls back to rendering the raw string
  /// verbatim instead of resolving it.
  static String? _truncateComment(String? content, NotificationKind kind) {
    if (content == null) return null;
    if (kind != NotificationKind.comment &&
        kind != NotificationKind.reply &&
        kind != NotificationKind.likeComment) {
      return null;
    }
    if (content.length <= _maxCommentLength) return content;

    final cut = _surrogateSafeCut(
      content,
      _referenceAwareCut(content, _maxCommentLength),
    );
    if (cut >= content.length) return content;
    return '${content.substring(0, cut).trimRight()}...';
  }

  /// Returns a bounded cut index that does not split a decodable Nostr
  /// reference — bech32 or bare 64-char hex.
  ///
  /// A reference that straddles [limit] is kept whole when the notification
  /// quote UI renders it as bounded display text: a decoded profile label, a
  /// video label, or a 64-char hex reference. Dropping those instead deleted
  /// mid-sentence mentions outright (#6763).
  ///
  /// A token-shaped run that would render raw is omitted rather than split
  /// (#6346), unless it starts too early to leave a useful preview; in that
  /// case the plain cap is clearer than a bare `...`.
  ///
  /// A token the UI resolves as a URL or hashtag is skipped even when a
  /// bech32 or hex run sits inside it — the UI does not link that run, so
  /// pulling the cut back to it only shortens the preview.
  static int _referenceAwareCut(String content, int limit) {
    for (final match in _uiTokenPattern.allMatches(content)) {
      if (match.start >= limit) break;
      final isReference =
          match.group(_bech32ReferenceGroup) != null ||
          match.group(_hexReferenceGroup) != null;
      if (!isReference) continue;
      // The `break` above already guarantees `match.start < limit`, so
      // ending after it is exactly the straddling case.
      if (match.end <= limit) continue;
      if (_referenceRendersAsBoundedLabel(match)) return match.end;
      return match.start < _minPreviewBeforeDroppingReference
          ? limit
          : match.start;
    }
    return limit;
  }

  static bool _referenceRendersAsBoundedLabel(RegExpMatch match) {
    final hexReference = match.group(_hexReferenceGroup);
    if (hexReference != null) return true;

    final bech32Reference = match.group(_bech32ReferenceGroup);
    if (bech32Reference == null ||
        bech32Reference.length > _maxKeptResolvedReferenceLength) {
      return false;
    }

    final lower = bech32Reference.toLowerCase();
    if (lower.startsWith('npub1')) {
      return Nip19.decode(bech32Reference).length == 64;
    }

    if (lower.startsWith('nprofile1')) {
      final pubkey = NIP19Tlv.decodeNprofile(bech32Reference)?.pubkey;
      return pubkey != null && pubkey.length == 64;
    }

    return lower.startsWith('note1') ||
        lower.startsWith('nevent1') ||
        lower.startsWith('naddr1');
  }

  /// Moves [cut] back one code unit when it would split a surrogate pair.
  ///
  /// [_maxCommentLength] counts UTF-16 code units, so a cut can land between
  /// the halves of an astral character (emoji). The lone high surrogate left
  /// behind renders as U+FFFD once the span builder sanitizes it.
  static int _surrogateSafeCut(String content, int cut) {
    if (cut <= 0 || cut >= content.length) return cut;
    final previous = content.codeUnitAt(cut - 1);
    final isHighSurrogate = previous >= 0xD800 && previous <= 0xDBFF;
    return isHighSurrogate ? cut - 1 : cut;
  }
}

@immutable
class _VideoGroupKey {
  const _VideoGroupKey({
    required this.groupId,
    required this.eventId,
    required this.kind,
  });
  final String groupId;
  final String eventId;
  final NotificationKind kind;

  @override
  bool operator ==(Object other) =>
      other is _VideoGroupKey && other.groupId == groupId && other.kind == kind;

  @override
  int get hashCode => Object.hash(groupId, kind);
}

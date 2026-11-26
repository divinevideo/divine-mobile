// ABOUTME: Riverpod providers for user lists (kind 30000) and curated video lists (kind 30005)
// ABOUTME: Manages list state and provides reactive updates for the Lists tab

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart' show Provider;
import 'package:models/models.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/services/openvine_media_cache.dart';
import 'package:openvine/services/video_event_service.dart'
    show VideoEventService;
import 'package:openvine/utils/curated_lists_snapshot.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart';

part 'list_providers.g.dart';

/// Checks whether a resolved video is eligible for automatic list playback.
/// Waits for the same broken-video tracker used by the fullscreen feed.
final curatedListPlaybackEligibilityProvider =
    Provider<bool Function(VideoEvent)>((ref) {
      final tracker = ref.watch(brokenVideoTrackerProvider);
      if (tracker.isLoading) return (_) => false;
      final cache = kIsWeb ? null : ref.watch(mediaCacheProvider);
      return (video) =>
          tracker.value?.isVideoBroken(video.id) != true &&
          (video.videoUrl?.trim().isNotEmpty == true ||
              cache?.getCachedFileSync(video.id) != null);
    });

/// Provider for videos in a specific curated list
@riverpod
Future<List<String>> curatedListVideos(Ref ref, String listId) async {
  final service = ref.read(curatedListsStateProvider.notifier).service;
  final list = service?.getListById(listId);

  if (list == null) {
    return [];
  }

  // Return video IDs in the order specified by the list's playOrder setting
  return service?.getOrderedVideoIds(listId) ?? [];
}

/// Provider reads that stop once the owning provider is torn down.
///
/// An `async*` provider body does not start until the returned stream is
/// listened to, and it keeps running for a moment after Riverpod tears the
/// provider down — so any `Ref` touched across one of its `await`s can land on
/// a dead `Ref` and throw "Cannot use the Ref … after it has been disposed"
/// (#6274, #7294). Bundling the reads here keeps the `async*` helpers below
/// free of `Ref` entirely.
///
/// The flag cannot be replaced by `ref.mounted`: `invalidateSelf` runs
/// `onDispose` immediately but only *schedules* the rebuild, so `ref.mounted`
/// still reports `true` while the old body is running against a `Ref` that is
/// already being torn down. Pull-to-refresh takes exactly that path, and the
/// two disposal tests in `list_providers_test.dart` fail against `ref.mounted`.
///
/// A `null` return means the body abandons its work rather than fetching on
/// behalf of something nobody is listening to any more.
class _LiveDeps {
  _LiveDeps(this._ref) {
    _ref.onDispose(() => _torndown = true);
  }

  final Ref _ref;
  bool _torndown = false;

  VideoEventService? get videoEventService =>
      _torndown ? null : _ref.read(videoEventServiceProvider);

  VideosRepository? get videosRepository =>
      _torndown ? null : _ref.read(videosRepositoryProvider);
}

/// Riverpod's default retries a failed provider ten times with backoff, and
/// every attempt here is a relay query with its own timeout — the viewer
/// would sit on a spinner for minutes. While it retries the state is loading
/// that carries the error, so a screen never reaches its retry view. A failed
/// read surfaces at once instead, with a retry the viewer drives.
Duration? _noAutomaticRetry(int retryCount, Object error) => null;

/// Provider for the videos published by the members of a user list.
///
/// The members' newest videos come from
/// [VideosRepository.getVideosByAuthors]: Funnelcake first, the relays when
/// it fails or holds none of their videos. Whatever the feed pool already
/// holds from those members shows first, so a list of followed people paints
/// before the round trip returns; the fetched set is then merged in. A fetch
/// that fails after that first paint keeps the pooled videos; one that fails
/// with nothing to show surfaces the error at once, with no automatic retry,
/// so a network failure never reads as "no videos yet" or as endless loading.
/// Only an [Exception] is absorbed that way: an [Error] is a bug and
/// surfaces whatever is pooled.
///
/// It re-runs when the blocklist changes, as the other list providers here
/// do (#5104), and when the repository is rebuilt for a filter change or an
/// account switch. The pool is read, not watched: every pool emission would
/// otherwise cost a relay round trip.
///
/// Equal member sets reuse the same feed across cache decoding and metadata
/// changes without mutating the caller's roster.
UserListMemberVideosByRosterProvider userListMemberVideosProvider(
  List<String> pubkeys,
) {
  final members = pubkeys.toSet().toList()..sort();
  return userListMemberVideosByRosterProvider(jsonEncode(members));
}

/// Reads dependencies synchronously during build before the stream starts.
@Riverpod(retry: _noAutomaticRetry)
Stream<List<VideoEvent>> userListMemberVideosByRoster(
  Ref ref,
  String rosterKey,
) {
  final pubkeys = (jsonDecode(rosterKey) as List<dynamic>).cast<String>();
  ref.watch(blocklistVersionProvider);
  final repository = ref.watch(videosRepositoryProvider);
  final pooled = ref.read(videoEventsProvider).value ?? const <VideoEvent>[];
  return _userListMemberVideos(repository, pooled, pubkeys);
}

Stream<List<VideoEvent>> _userListMemberVideos(
  VideosRepository repository,
  List<VideoEvent> pooled,
  List<String> pubkeys,
) async* {
  final members = pubkeys.toSet();
  // A re-run can read the pool before it drops what the change hid, and the
  // merge below keeps every pooled video, so filter it again here.
  final seeded = _newestFirst(
    repository.applyContentPreferences([
      for (final video in pooled)
        if (members.contains(video.pubkey)) video,
    ]),
  );
  if (seeded.isNotEmpty) yield seeded;

  final List<VideoEvent> fetched;
  try {
    fetched = await repository.getVideosByAuthors(authorPubkeys: pubkeys);
  } on Exception catch (error, stackTrace) {
    if (seeded.isEmpty) rethrow;
    Log.warning(
      'Member videos fetch failed; keeping ${seeded.length} pooled videos',
      name: 'ListProviders',
      category: LogCategory.relay,
      error: error,
      stackTrace: stackTrace,
    );
    return;
  }

  // Keyed like the repository's own merge: an edit keeps the d-tag and mints
  // a new event id, so the pool can hold the revision the fetch replaced.
  final seenKeys = fetched.map((video) => video.feedDedupKey).toSet();
  yield _newestFirst([
    ...fetched,
    for (final video in seeded)
      if (seenKeys.add(video.feedDedupKey)) video,
  ]);
}

List<VideoEvent> _newestFirst(List<VideoEvent> videos) =>
    videos..sort((a, b) => b.createdAt.compareTo(a.createdAt));

/// Provider that fetches a public curated list (kind 30005) by author +
/// d-tag for the `/list/:pubkey/:listId` universal-link route.
///
/// Unlike [curatedListVideos], this does not require the list to be in
/// local storage — it resolves from cache + relays, so deep links to lists
/// the user has never seen still work. Returns `null` when no matching
/// list event exists.
@riverpod
Future<CuratedList?> publicCuratedList(
  Ref ref, {
  required String authorPubkey,
  required String listId,
}) async {
  // Depend on the notifier (stable across state emissions), not the state:
  // CuratedListsState re-emits on every CuratedListService.notifyListeners
  // (background relay sync, list add/remove), and watching the state future
  // would re-run this fetch — resetting the deep-link screen to loading —
  // on every one of those emissions.
  final notifier = ref.watch(curatedListsStateProvider.notifier);
  // One-shot await so the service exists on cold-start deep links;
  // deliberately read, not watch (see above).
  await ref.read(curatedListsStateProvider.future);
  final service = notifier.service;
  return service?.fetchPublicList(authorPubkey: authorPubkey, listId: listId);
}

/// The viewer's own video lists with card-fan thumbnails resolved.
///
/// The profile's My Lists gallery renders instantly from the service's
/// lists (placeholder fans) and swaps to these enriched copies when the
/// resolver returns.
@riverpod
Future<List<CuratedList>> myListsWithThumbnails(Ref ref) async {
  var disposed = false;
  ref.onDispose(() => disposed = true);
  final notifier = ref.watch(curatedListsStateProvider.notifier);
  final repository = ref.watch(curatedListRepositoryProvider);
  // The repository keeps its subscription stream stable across policy changes;
  // this consumer still retires loaded and in-flight preview snapshots.
  final policy = ref.watch(curatedListThumbnailFilterProvider);
  final policyInitialized = ref.watch(
    curatedListThumbnailPolicyInitializedProvider.future,
  );
  final authService = ref.watch(authServiceProvider);
  final owner = authService.currentPublicKeyHex;
  // Service rebuilds retain the notifier, so its construction dependencies
  // must also invalidate a pending thumbnail pass.
  ref.watch(currentAuthStateProvider);
  ref.watch(nostrServiceProvider);
  ref.watch(sharedPreferencesProvider);
  final selectedFuture = ref.watch(
    curatedListsStateProvider.selectAsync((_) {
      final service = notifier.service;
      return (
        service: service,
        snapshot: CuratedListsSnapshot(
          service?.myLists ?? const <CuratedList>[],
        ),
      );
    }),
  );
  final (selected, _) = await (selectedFuture, policyInitialized).wait;
  bool isCurrent() =>
      !disposed &&
      ref.mounted &&
      identical(notifier.service, selected.service) &&
      authService.currentPublicKeyHex == owner &&
      identical(ref.read(curatedListThumbnailFilterProvider), policy);
  if (!isCurrent()) return const <CuratedList>[];
  final lists = selected.snapshot.lists;
  if (lists.isEmpty) return lists;
  final resolved = await repository.resolveListThumbnails(lists);
  return isCurrent() ? resolved : const <CuratedList>[];
}

/// Resolves a discovered public people list by author + d-tag from relays.
///
/// The owner-scoped [PeopleListsBloc] only holds the viewer's own lists, so
/// discovery cards and deep links to someone else's list resolve through
/// this instead.
@Riverpod(retry: _noAutomaticRetry)
Future<UserList?> publicPeopleList(
  Ref ref, {
  required String ownerPubkey,
  required String listId,
}) {
  final repository = ref.watch(peopleListsRepositoryProvider);
  return repository.fetchPublicList(ownerPubkey: ownerPubkey, listId: listId);
}

/// The videos of a curated list held in local storage (the viewer's own lists
/// and the ones they follow), as [_listVideos] reads them, from the relays
/// alone: a private list's decrypted contents must not reach Funnelcake as
/// one request.
///
/// `Ref` is either read synchronously in `build` or guarded by [_LiveDeps] —
/// this provider is the one that matters most, because
/// `curated_list_feed_screen` calls
/// `ref.invalidate(curatedListVideoEventsProvider(listId))` on pull-to-refresh,
/// which disposes the previous build while it is still awaiting its reads.
@riverpod
Stream<List<VideoEvent>> curatedListVideoEvents(Ref ref, String listId) {
  // Re-run (and therefore re-filter) when the blocklist changes. Broad changes
  // (account switch / identity adoption, relay-synced blocked-by-others,
  // mute-list recovery) bump this version but emit no granular removed-id
  // signal, so version-reactivity is the only way the grid drops a newly
  // blocked author without a manual refresh (#5104).
  ref.watch(blocklistVersionProvider);

  return _curatedListVideoEvents(
    listId: listId,
    // Watched (not awaited) here so the dependency is registered during build;
    // the future itself is awaited inside the helper below.
    videoIdsFuture: ref.watch(curatedListVideosProvider(listId).future),
    live: _LiveDeps(ref),
  );
}

Stream<List<VideoEvent>> _curatedListVideoEvents({
  required String listId,
  required Future<List<String>> videoIdsFuture,
  required _LiveDeps live,
}) async* {
  Log.info(
    '📋 Fetching videos for curated list: $listId',
    name: 'CuratedListVideoEvents',
    category: LogCategory.video,
  );
  yield* _listVideos(
    videoRefs: await videoIdsFuture,
    live: live,
    logName: 'CuratedListVideoEvents',
    relayOnly: true,
  );
}

/// The videos a list names, for a discovered list that is not in local
/// storage, as [_listVideos] reads them.
///
/// The body is a plain function, and the reads it needs after an `await` go
/// through [_LiveDeps] — see there for why an `async*` body cannot touch `Ref`.
@riverpod
Stream<List<VideoEvent>> videoEventsByIds(Ref ref, List<String> videoIds) {
  // Re-run (and therefore re-filter) when the blocklist changes — broad changes
  // bump this version but emit no granular removed-id signal (#5104).
  ref.watch(blocklistVersionProvider);

  return _listVideos(
    videoRefs: videoIds,
    live: _LiveDeps(ref),
    logName: 'VideoEventsByIds',
  );
}

/// The videos [videoRefs] names (64-hex event ids and `kind:pubkey:d-tag`
/// coordinates), those the feed pool already holds first.
///
/// Pooled videos show at once. The rest come from
/// [VideosRepository.watchVideosForList]: Funnelcake first, the relays for
/// what it does not hold, or the relays alone when [relayOnly] is set. They
/// are appended as they arrive, so a tile already on screen keeps its place,
/// and are added to the pool. The viewer's
/// feed-shape preference does not apply, because the list's author chose
/// these videos; videos [VideoEventService.shouldHideVideo] hides are left
/// out. A reference of any other shape is skipped.
///
/// A read that fails with an [Exception] after pooled videos showed keeps
/// them; one that fails with nothing to show surfaces the error. An [Error]
/// is a bug and always surfaces.
Stream<List<VideoEvent>> _listVideos({
  required List<String> videoRefs,
  required _LiveDeps live,
  required String logName,
  bool relayOnly = false,
}) async* {
  if (videoRefs.isEmpty) {
    yield const [];
    return;
  }

  // Null means the provider was disposed while this body was suspended —
  // abandon the fetch instead of reading a dead Ref (#7294).
  final videoEventService = live.videoEventService;
  if (videoEventService == null) return;

  final foundVideos = <VideoEvent>[];
  final slotByVideoKey = <String, int>{};
  final missingRefs = <String>[];

  // A list can name an old event id and the current coordinate of the same
  // video, so revisions share a tile: the newest keeps the first one's slot.
  // Returns whether the tiles changed.
  bool keepNewest(VideoEvent video) {
    final slot = slotByVideoKey[video.feedDedupKey];
    if (slot == null) {
      slotByVideoKey[video.feedDedupKey] = foundVideos.length;
      foundVideos.add(video);
      return true;
    }
    if (video.createdAt <= foundVideos[slot].createdAt) return false;
    foundVideos[slot] = video;
    return true;
  }

  // Every subscription's pool, for the coordinates (kind:pubkey:d-tag).
  final pooledVideos = <VideoEvent>{
    ...videoEventService.discoveryVideos,
    ...videoEventService.homeFeedVideos,
    ...videoEventService.profileVideos,
  };

  // Hidden videos are skipped on a pool hit too, or a blocked author would
  // pass through unfiltered (#5104).
  for (final ref in videoRefs) {
    final VideoEvent? pooled;
    if (ref.contains(':')) {
      final parts = ref.split(':');
      if (parts.length < 3) continue;
      final pubkey = parts[1];
      final dTag = parts[2];
      pooled = pooledVideos
          .where(
            (video) =>
                video.pubkey == pubkey &&
                (video.rawTags['d'] ?? video.vineId ?? video.id) == dTag,
          )
          .firstOrNull;
    } else if (_hexEventId.hasMatch(ref)) {
      pooled = videoEventService.getVideoById(ref);
    } else {
      continue;
    }
    if (pooled == null) {
      missingRefs.add(ref);
    } else if (!videoEventService.shouldHideVideo(pooled)) {
      keepNewest(pooled);
    }
  }

  List<VideoEvent> orderedVideos() => order.sort([
    ...foundVideos,
    for (final video in legacyCacheHits.values)
      if (!seenIds.contains(video.id.toLowerCase())) video,
  ], legacyMatches: legacyCacheHits);

  Log.info(
    '📋 Found ${foundVideos.length} of ${videoRefs.length} videos in the '
    'pool; reading ${missingRefs.length}',
    name: logName,
    category: LogCategory.video,
  );

  // An empty yield would show "No videos" instead of the loading state.
  if (foundVideos.isNotEmpty) yield List.of(foundVideos);

  if (missingRefs.isNotEmpty) {
    // Null once the provider is disposed — see the pool lookup above.
    final repository = live.videosRepository;
    if (repository == null) return;

    try {
      await for (final videos in repository.watchVideosForList(
        missingRefs,
        includeFeedShape: false,
        relayOnly: relayOnly,
      )) {
        var changed = false;
        for (final video in videos) {
          if (videoEventService.shouldHideVideo(video) || !keepNewest(video)) {
            continue;
          }
          changed = true;
          videoEventService.addVideoEvent(video);
        }
        if (changed) yield List.of(foundVideos);
      }
    } on Exception catch (error, stackTrace) {
      if (foundVideos.isEmpty) rethrow;
      Log.warning(
        "📋 Reading the list's other videos failed; keeping the pooled ones",
        name: logName,
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  yield foundVideos;
}

final _hexEventId = RegExp(r'^[a-fA-F0-9]{64}$');

// ABOUTME: Riverpod providers for user lists (kind 30000) and curated video lists (kind 30005)
// ABOUTME: Manages list state and provides reactive updates for the Lists tab

import 'dart:async';

import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart'
    show NostrClient, RelaySubscriptionRefusedException;
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/services/video_event_service.dart'
    show VideoEventService;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:unified_logger/unified_logger.dart';

part 'list_providers.g.dart';

/// Provider for all curated video lists (kind 30005)
@riverpod
Future<List<CuratedList>> curatedLists(Ref ref) async {
  final service = await ref.watch(curatedListsStateProvider.future);
  return service;
}

/// State class for discovered public lists

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

  NostrClient? get nostrClient =>
      _torndown ? null : _ref.read(nostrServiceProvider);
}

/// Provider for videos from all members of a user list
///
/// The body is a plain function so every `Ref` read happens synchronously
/// during `build` — see [_LiveDeps] for why an `async*` body cannot
/// touch `Ref`.
@riverpod
Stream<List<VideoEvent>> userListMemberVideos(Ref ref, List<String> pubkeys) {
  // Watch discovery videos and filter to only those from list members
  final allVideosAsync = ref.watch(videoEventsProvider);

  return _userListMemberVideos(allVideosAsync, pubkeys);
}

Stream<List<VideoEvent>> _userListMemberVideos(
  AsyncValue<List<VideoEvent>> allVideosAsync,
  List<String> pubkeys,
) async* {
  await for (final _ in Stream.value(null)) {
    if (allVideosAsync.hasValue) {
      final allVideos = allVideosAsync.value!;

      // Filter videos to only those authored by list members
      final listMemberVideos = allVideos
          .where((video) => pubkeys.contains(video.pubkey))
          .toList();

      // Sort by creation time (newest first)
      listMemberVideos.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      yield listMemberVideos;
    }
  }
}

/// Provider that streams public lists containing a specific video
/// Accumulates results as they arrive from Nostr relays, yielding updated list
/// on each new result. This enables progressive UI updates via Riverpod.
@riverpod
Stream<List<CuratedList>> publicListsContainingVideo(
  Ref ref,
  String videoId,
) async* {
  /// wait to initialize the curated list service
  await ref.read(curatedListsStateProvider.future);
  final curatedListStream = ref
      .read(curatedListsStateProvider.notifier)
      .service
      ?.streamPublicListsContainingVideo(videoId);
  final accumulated = <CuratedList>[];
  final seenIds = <String>{};

  // Yield an initial value to avoid hanging if the stream is empty
  yield const <CuratedList>[];

  // Stream events from Nostr relays, accumulating as they arrive. A refusal
  // from every relay ends the read; keep what already arrived.
  await for (final CuratedList list
      in curatedListStream?.handleError(
            (Object error) => Log.warning(
              '📋 Relay refused public list stream: $error',
              name: 'PublicListsContainingVideo',
              category: LogCategory.video,
            ),
            test: (error) => error is RelaySubscriptionRefusedException,
          ) ??
          const Stream.empty()) {
    if (!seenIds.contains(list.id)) {
      seenIds.add(list.id);
      accumulated.add(list);
      // Yield a copy of accumulated list on each new result
      yield List<CuratedList>.from(accumulated);
    }
  }

  // After stream completes (EOSE from relay), yield final accumulated result
  // This ensures the provider has data even if stream completes immediately
  yield accumulated;
}

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
  await ref.watch(curatedListsStateProvider.future);
  final service = ref.watch(curatedListsStateProvider.notifier).service;
  final lists = service?.myLists ?? const <CuratedList>[];
  if (lists.isEmpty) return lists;
  final repository = ref.watch(curatedListRepositoryProvider);
  return repository.resolveListThumbnails(lists);
}

/// Riverpod's default retries a failed provider ten times with backoff, and
/// every attempt here is a relay query with its own timeout — the viewer
/// would sit on a spinner for minutes. A failed read surfaces at once
/// instead, with a retry the viewer drives.
Duration? _noAutomaticRetry(int retryCount, Object error) => null;

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

/// Provider that fetches actual VideoEvent objects for a curated list
/// Streams videos as they are fetched from cache or relays
///
/// `Ref` is either read synchronously in `build` or guarded by [_LiveDeps] —
/// this provider is the one that matters most, because
/// `curated_list_feed_screen` calls
/// `ref.invalidate(curatedListVideoEventsProvider(listId))` on pull-to-refresh,
/// which disposes the previous build while it is still awaiting relays.
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

  // Get the video IDs from the curated list
  final videoIds = await videoIdsFuture;

  if (videoIds.isEmpty) {
    Log.info(
      '📋 List $listId has no videos',
      name: 'CuratedListVideoEvents',
      category: LogCategory.video,
    );
    yield [];
    return;
  }

  Log.info(
    '📋 List has ${videoIds.length} video IDs to fetch',
    name: 'CuratedListVideoEvents',
    category: LogCategory.video,
  );

  // Separate video event IDs from addressable coordinates
  final eventIds = <String>[];
  final addressableCoords = <String>[]; // Format: 34236:pubkey:d-tag

  // Simple hex validation for 64-character Nostr event IDs
  final hexRegex = RegExp(r'^[a-fA-F0-9]{64}$');

  for (final id in videoIds) {
    if (id.contains(':')) {
      addressableCoords.add(id);
    } else if (hexRegex.hasMatch(id)) {
      eventIds.add(id);
    }
  }

  Log.info(
    '📋 IDs breakdown: ${eventIds.length} event IDs, '
    '${addressableCoords.length} addressable coords',
    name: 'CuratedListVideoEvents',
    category: LogCategory.video,
  );

  // First check cache via video event service. Null means the provider was
  // disposed while awaiting the list — abandon the fetch instead of reading a
  // dead Ref (#7294).
  final videoEventService = live.videoEventService;
  if (videoEventService == null) return;

  final foundVideos = <VideoEvent>[];
  final missingIds = <String>[];
  final missingCoords = <String>[];

  // Check cache for regular event IDs. Skip blocked authors here too — the
  // addressable-coord and relay branches already guard, but a plain-event-ID
  // cache hit would otherwise pass an unfiltered blocked author through (#5104).
  for (final eventId in eventIds) {
    final cached = videoEventService.getVideoById(eventId);
    if (cached == null) {
      missingIds.add(eventId);
    } else if (!videoEventService.shouldHideVideo(cached)) {
      foundVideos.add(cached);
    }
  }

  // Check cache for addressable coordinates (kind:pubkey:d-tag)
  // Combine videos from all subscription types for cache lookup
  final allCachedVideos = <VideoEvent>{
    ...videoEventService.discoveryVideos,
    ...videoEventService.homeFeedVideos,
    ...videoEventService.profileVideos,
  }.toList();
  Log.debug(
    '📋 Searching ${allCachedVideos.length} cached videos for ${addressableCoords.length} coords',
    name: 'CuratedListVideoEvents',
    category: LogCategory.video,
  );

  for (final coord in addressableCoords) {
    final parts = coord.split(':');
    if (parts.length >= 3) {
      final pubkey = parts[1];
      final dTag = parts[2];

      final cached = allCachedVideos.where((v) {
        if (v.pubkey != pubkey) return false;
        // Check d-tag in rawTags, vineId, or video id
        final videoDTag = v.rawTags['d'] ?? v.vineId ?? v.id;
        return videoDTag == dTag;
      }).firstOrNull;

      if (cached != null) {
        if (!videoEventService.shouldHideVideo(cached)) {
          foundVideos.add(cached);
          Log.debug(
            '📋 Found addressable video in cache: ${cached.title ?? cached.id}',
            name: 'CuratedListVideoEvents',
            category: LogCategory.video,
          );
        }
      } else {
        Log.debug(
          '📋 Cache miss for coord: $coord (pubkey=${pubkeyForLogs(pubkey)}, dTag=$dTag)',
          name: 'CuratedListVideoEvents',
          category: LogCategory.video,
        );
        missingCoords.add(coord);
      }
    }
  }

  Log.info(
    '📋 Found ${foundVideos.length} videos in cache '
    '(${missingIds.length} missing IDs, ${missingCoords.length} missing coords)',
    name: 'CuratedListVideoEvents',
    category: LogCategory.video,
  );

  // Yield cached videos immediately (but not empty - keep loading state)
  if (foundVideos.isNotEmpty) {
    yield List.from(foundVideos);
  }

  // Fetch missing videos from relays
  if (missingIds.isNotEmpty || missingCoords.isNotEmpty) {
    Log.info(
      '📋 Fetching ${missingIds.length} missing IDs + '
      '${missingCoords.length} missing coords from relays',
      name: 'CuratedListVideoEvents',
      category: LogCategory.video,
    );

    // Build filters for missing videos
    final filters = <Filter>[];

    // Filter for regular event IDs
    if (missingIds.isNotEmpty) {
      filters.add(Filter(ids: missingIds));
    }

    // Filter for addressable events (kind 34236)
    for (final coord in missingCoords) {
      final parts = coord.split(':');
      if (parts.length >= 3) {
        final kind = int.tryParse(parts[0]);
        final pubkey = parts[1];
        final dTag = parts[2];
        if (kind != null) {
          filters.add(Filter(kinds: [kind], authors: [pubkey], d: [dTag]));
        }
      }
    }

    // Null once the provider is disposed — see the cache lookup above.
    final nostrClient = live.nostrClient;
    if (nostrClient == null) return;

    if (filters.isNotEmpty) {
      // A refusal from every relay closes the read early. Log it and keep the
      // videos already resolved rather than failing the whole provider.
      final eventStream = nostrClient
          .subscribe(filters, closeOnEose: true)
          .handleError(
            (Object error) => Log.warning(
              '📋 Relay refused video fetch: $error',
              name: 'CuratedListVideoEvents',
              category: LogCategory.video,
            ),
            test: (error) => error is RelaySubscriptionRefusedException,
          );
      final seenIds = foundVideos.map((v) => v.id.toLowerCase()).toSet();

      await for (final event in eventStream) {
        if (seenIds.contains(event.id.toLowerCase())) continue;

        try {
          // Use permissive mode to accept all NIP-71 video kinds from curated lists
          final video = VideoEvent.fromNostrEvent(event, permissive: true);
          if (videoEventService.shouldHideVideo(video)) {
            continue;
          }
          foundVideos.add(video);
          seenIds.add(event.id.toLowerCase());

          // Also add to the video event service cache
          videoEventService.addVideoEvent(video);

          Log.info(
            '📋 Fetched video (kind ${event.kind}): ${video.title ?? video.id}',
            name: 'CuratedListVideoEvents',
            category: LogCategory.video,
          );

          // Yield updated list with new video
          yield List.from(foundVideos);
        } catch (e) {
          // Log the actual event kind to help diagnose issues
          Log.warning(
            '📋 Failed to parse event ${event.id} (kind ${event.kind}): $e',
            name: 'CuratedListVideoEvents',
            category: LogCategory.video,
          );
        }
      }
    }
  }

  Log.info(
    '📋 Finished fetching. Total videos: ${foundVideos.length}',
    name: 'CuratedListVideoEvents',
    category: LogCategory.video,
  );

  // Yield final result
  yield foundVideos;
}

/// Provider that fetches VideoEvent objects directly from a list of video IDs
/// Use this for discovered lists that aren't in local storage
///
/// The body is a plain function, and the reads it needs after an `await` go
/// through [_LiveDeps] — see there for why an `async*` body cannot touch `Ref`.
@riverpod
Stream<List<VideoEvent>> videoEventsByIds(Ref ref, List<String> videoIds) {
  // Re-run (and therefore re-filter) when the blocklist changes — broad changes
  // bump this version but emit no granular removed-id signal (#5104).
  ref.watch(blocklistVersionProvider);

  return _videoEventsByIds(videoIds: videoIds, live: _LiveDeps(ref));
}

Stream<List<VideoEvent>> _videoEventsByIds({
  required List<String> videoIds,
  required _LiveDeps live,
}) async* {
  Log.info(
    '📋 Fetching ${videoIds.length} videos by IDs',
    name: 'VideoEventsByIds',
    category: LogCategory.video,
  );

  if (videoIds.isEmpty) {
    yield [];
    return;
  }

  // Separate video event IDs from addressable coordinates
  final eventIds = <String>[];
  final addressableCoords = <String>[]; // Format: 34236:pubkey:d-tag

  // Simple hex validation for 64-character Nostr event IDs
  final hexRegex = RegExp(r'^[a-fA-F0-9]{64}$');

  for (final id in videoIds) {
    if (id.contains(':')) {
      addressableCoords.add(id);
    } else if (hexRegex.hasMatch(id)) {
      eventIds.add(id);
    }
  }

  Log.info(
    '📋 IDs breakdown: ${eventIds.length} event IDs, '
    '${addressableCoords.length} addressable coords',
    name: 'VideoEventsByIds',
    category: LogCategory.video,
  );

  // First check cache via video event service. Null means the provider was
  // disposed while this body was suspended — abandon the fetch instead of
  // reading a dead Ref (#7294).
  final videoEventService = live.videoEventService;
  if (videoEventService == null) return;

  final foundVideos = <VideoEvent>[];
  final missingIds = <String>[];
  final missingCoords = <String>[];

  // Check cache for regular event IDs. Skip blocked authors here too — a
  // plain-event-ID cache hit would otherwise pass an unfiltered blocked author
  // through, unlike the addressable-coord and relay branches below (#5104).
  for (final eventId in eventIds) {
    final cached = videoEventService.getVideoById(eventId);
    if (cached == null) {
      missingIds.add(eventId);
    } else if (!videoEventService.shouldHideVideo(cached)) {
      foundVideos.add(cached);
    }
  }

  // Check cache for addressable coordinates (kind:pubkey:d-tag)
  // Combine videos from all subscription types for cache lookup
  final allCachedVideos = <VideoEvent>{
    ...videoEventService.discoveryVideos,
    ...videoEventService.homeFeedVideos,
    ...videoEventService.profileVideos,
  }.toList();
  Log.debug(
    '📋 Searching ${allCachedVideos.length} cached videos for ${addressableCoords.length} coords',
    name: 'VideoEventsByIds',
    category: LogCategory.video,
  );

  for (final coord in addressableCoords) {
    final parts = coord.split(':');
    if (parts.length >= 3) {
      final pubkey = parts[1];
      final dTag = parts[2];

      // Find video in cache that matches pubkey and d-tag
      final cached = allCachedVideos.where((v) {
        if (v.pubkey != pubkey) return false;
        // Check d-tag in rawTags, vineId, or even the video id itself
        final videoDTag = v.rawTags['d'] ?? v.vineId ?? v.id;
        return videoDTag == dTag;
      }).firstOrNull;

      if (cached != null) {
        if (!videoEventService.shouldHideVideo(cached)) {
          foundVideos.add(cached);
          Log.debug(
            '📋 Found addressable video in cache: ${cached.title ?? cached.id}',
            name: 'VideoEventsByIds',
            category: LogCategory.video,
          );
        }
      } else {
        // Log what we're looking for vs what's in cache for debugging
        final matchingPubkey = allCachedVideos
            .where((v) => v.pubkey == pubkey)
            .toList();
        Log.debug(
          '📋 Cache miss for coord: $coord\n'
          '   Looking for: pubkey=${pubkeyForLogs(pubkey)}, dTag=$dTag\n'
          '   Videos by same author: ${matchingPubkey.length}\n'
          '   Their d-tags: ${matchingPubkey.take(3).map((v) => v.rawTags['d'] ?? v.vineId ?? 'none').toList()}',
          name: 'VideoEventsByIds',
          category: LogCategory.video,
        );
        missingCoords.add(coord);
      }
    }
  }

  Log.info(
    '📋 Found ${foundVideos.length} videos in cache '
    '(${missingIds.length} missing IDs, ${missingCoords.length} missing coords)',
    name: 'VideoEventsByIds',
    category: LogCategory.video,
  );

  // Only yield cached videos if we have some - don't yield empty yet
  // (empty yield would show "No videos" instead of loading state)
  if (foundVideos.isNotEmpty) {
    yield List.from(foundVideos);
  }

  // Fetch missing videos from relays
  if (missingIds.isNotEmpty || missingCoords.isNotEmpty) {
    Log.info(
      '📋 Fetching ${missingIds.length} missing event IDs + '
      '${missingCoords.length} missing addressable coords from relays',
      name: 'VideoEventsByIds',
      category: LogCategory.video,
    );

    // Build filters for missing videos
    final filters = <Filter>[];

    // Filter for regular event IDs
    if (missingIds.isNotEmpty) {
      filters.add(Filter(ids: missingIds));
    }

    // Filter for addressable events (NIP-71 video kinds)
    for (final coord in missingCoords) {
      final parts = coord.split(':');
      if (parts.length >= 3) {
        final kind = int.tryParse(parts[0]);
        final pubkey = parts[1];
        final dTag = parts[2];
        if (kind != null) {
          filters.add(Filter(kinds: [kind], authors: [pubkey], d: [dTag]));
        }
      }
    }

    // Null once the provider is disposed — see the cache lookup above.
    final nostrClient = live.nostrClient;
    if (nostrClient == null) return;

    if (filters.isNotEmpty) {
      // A refusal from every relay closes the read early. Log it and keep the
      // videos already resolved rather than failing the whole provider.
      final eventStream = nostrClient
          .subscribe(filters, closeOnEose: true)
          .handleError(
            (Object error) => Log.warning(
              '📋 Relay refused video fetch: $error',
              name: 'VideoEventsByIds',
              category: LogCategory.video,
            ),
            test: (error) => error is RelaySubscriptionRefusedException,
          );
      final seenIds = foundVideos.map((v) => v.id.toLowerCase()).toSet();

      await for (final event in eventStream) {
        if (seenIds.contains(event.id.toLowerCase())) continue;

        try {
          // Use permissive mode to accept all NIP-71 video kinds from external sources
          final video = VideoEvent.fromNostrEvent(event, permissive: true);
          if (videoEventService.shouldHideVideo(video)) {
            continue;
          }
          foundVideos.add(video);
          seenIds.add(event.id.toLowerCase());

          // Also add to the video event service cache
          videoEventService.addVideoEvent(video);

          Log.info(
            '📋 Fetched video (kind ${event.kind}): ${video.title ?? video.id}',
            name: 'VideoEventsByIds',
            category: LogCategory.video,
          );

          // Yield updated list with new video
          yield List.from(foundVideos);
        } catch (e) {
          // Log the actual event kind to help diagnose issues
          Log.warning(
            '📋 Failed to parse event ${event.id} (kind ${event.kind}): $e',
            name: 'VideoEventsByIds',
            category: LogCategory.video,
          );
        }
      }
    }
  }

  Log.info(
    '📋 Finished fetching. Total videos: ${foundVideos.length}',
    name: 'VideoEventsByIds',
    category: LogCategory.video,
  );

  // Yield final result
  yield foundVideos;
}

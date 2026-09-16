// ABOUTME: Tests for ProfileFeedCubit — cold load, pagination (REST + Nostr),
// ABOUTME: realtime/optimistic add, filtering-on-every-emit, the spinner
// ABOUTME: machine, error channels, and the C5 Nostr-loadMore count-preserve fix.

import 'dart:async';

import 'package:cache_sync/cache_sync.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_feed/profile_feed_cubit.dart';
import 'package:openvine/blocs/profile_shared/profile_video_offset_snapshot.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/repositories/profile_pins_repository.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockProfilePinsRepository extends Mock
    implements ProfilePinsRepository {}

/// In-memory [CacheDao] so the cubit's [CacheSync] reads/writes are isolated
/// per test without touching disk.
class _InMemoryCacheDao implements CacheDao {
  final Map<String, String> _store = {};

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write({
    required String key,
    required String payload,
    Duration? ttl,
  }) async {
    _store[key] = payload;
  }

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  Future<void> deletePrefix(String prefix) async =>
      _store.removeWhere((key, _) => key.startsWith(prefix));

  @override
  Future<int> totalPayloadBytes() async =>
      _store.values.fold<int>(0, (sum, v) => sum + v.length);

  @override
  Future<void> evictOldest(int bytesToFree) async {}
}

const _author =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

VideoEvent _video(
  String id, {
  String pubkey = _author,
  int createdAt = 1000,
  int? originalLikes,
  String? vineId,
  String? dTag,
}) {
  return VideoEvent(
    id: id,
    pubkey: pubkey,
    createdAt: createdAt,
    content: '',
    timestamp: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
    videoUrl: 'https://example.com/$id.mp4',
    originalLikes: originalLikes,
    vineId: vineId,
    addressableDTag: dTag,
  );
}

/// The kind-34236 coordinate a pin list stores for a video with [dTag].
String _coordinate(String dTag, {String pubkey = _author}) =>
    '34236:$pubkey:$dTag';

AuthorFeedResult _result(
  List<VideoEvent> videos, {
  int? totalCount,
  int? nextOffset,
  bool? hasMore,
  bool isFromCache = false,
}) {
  return AuthorFeedResult(
    authorPubkey: _author,
    videos: videos,
    totalCount: totalCount,
    nextOffset: nextOffset,
    hasMore: hasMore,
    isFromCache: isFromCache,
  );
}

/// Holds the mocks + captured VES listener callbacks so realtime paths can be
/// driven from tests.
class _Harness {
  _Harness() {
    when(() => ves.authorVideos(any())).thenReturn(const <VideoEvent>[]);
    when(
      () => ves.filterVideoList(any()),
    ).thenAnswer((i) => i.positionalArguments[0] as List<VideoEvent>);
    when(() => ves.isVideoEventKnownDeleted(any())).thenReturn(false);
    when(() => ves.subscribeToUserVideos(any())).thenAnswer((_) async {});
    when(() => ves.unsubscribeFromUserVideos(any())).thenAnswer((_) async {});
    when(
      () => ves.queryHistoricalUserVideos(any(), until: any(named: 'until')),
    ).thenAnswer((_) async {});
    when(() => ves.addListener(any())).thenAnswer((i) {
      onChanged = i.positionalArguments[0] as void Function();
    });
    when(() => ves.removeListener(any())).thenReturn(null);
    when(() => ves.addVideoUpdateListener(any())).thenAnswer((i) {
      onUpdate = i.positionalArguments[0] as void Function(VideoEvent);
      return () {};
    });
    when(() => blocklist.shouldFilterFromFeeds(any())).thenReturn(false);
    when(() => pins.readCached(any())).thenAnswer((_) async => null);
    when(() => pins.fetch(any())).thenAnswer((_) async => const []);
    when(
      () => repo.getVideosByAddressableIds(
        any(),
        cacheResults: any(named: 'cacheResults'),
      ),
    ).thenAnswer((_) async => const []);
  }

  final repo = _MockVideosRepository();
  final ves = _MockVideoEventService();
  final blocklist = _MockContentBlocklistRepository();
  final pins = _MockProfilePinsRepository();

  void Function()? onChanged;
  void Function(VideoEvent)? onUpdate;

  List<VideoEvent> enrichInput = const [];
  Future<List<VideoEvent>> Function(List<VideoEvent>)? enrichOverride;

  Future<List<VideoEvent>> _noopEnrich(List<VideoEvent> videos) async {
    enrichInput = videos;
    return videos; // identical -> no enrichment re-emit
  }

  void stubAuthorFeed(AuthorFeedResult result) {
    when(
      () => repo.getAuthorFeed(
        authorPubkey: any(named: 'authorPubkey'),
        offset: any(named: 'offset'),
        relaySeed: any(named: 'relaySeed'),
        skipCache: any(named: 'skipCache'),
      ),
    ).thenAnswer((_) async => result);
  }

  void stubAuthorFeedSequence(List<AuthorFeedResult> results) {
    var index = 0;
    when(
      () => repo.getAuthorFeed(
        authorPubkey: any(named: 'authorPubkey'),
        offset: any(named: 'offset'),
        relaySeed: any(named: 'relaySeed'),
        skipCache: any(named: 'skipCache'),
      ),
    ).thenAnswer((_) async => results[index++]);
  }

  void stubAuthorFeedThrows(Object error) {
    when(
      () => repo.getAuthorFeed(
        authorPubkey: any(named: 'authorPubkey'),
        offset: any(named: 'offset'),
        relaySeed: any(named: 'relaySeed'),
        skipCache: any(named: 'skipCache'),
      ),
    ).thenThrow(error);
  }

  ProfileFeedCubit build() => ProfileFeedCubit(
    authorPubkey: _author,
    videosRepository: repo,
    videoEventService: ves,
    blocklistRepository: blocklist,
    profilePinsRepository: pins,
    enrichVideos: enrichOverride ?? _noopEnrich,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_video('fallback'));
    registerFallbackValue(<VideoEvent>[]);
    registerFallbackValue(() {});
    registerFallbackValue((VideoEvent _) {});
    registerFallbackValue(<String>[]);
  });

  group('ProfileFeedCubit', () {
    late _Harness h;
    late _InMemoryCacheDao cacheDao;
    late Duration originalSnapshotPersistDebounce;

    setUp(() async {
      originalSnapshotPersistDebounce =
          ProfileFeedCubit.snapshotPersistDebounce;
      ProfileFeedCubit.snapshotPersistDebounce = Duration.zero;
      h = _Harness();
      cacheDao = _InMemoryCacheDao();
      await CacheSync.init(dao: cacheDao);
    });

    tearDown(() {
      ProfileFeedCubit.snapshotPersistDebounce =
          originalSnapshotPersistDebounce;
    });

    Future<ProfileFeedCubit> buildReady(AuthorFeedResult result) async {
      h.stubAuthorFeed(result);
      final cubit = h.build();
      await pumpEventQueue();
      return cubit;
    }

    const cacheKey = '$_author:profile_videos';

    Future<void> seedSnapshot(ProfileVideoOffsetSnapshot snapshot) =>
        CacheSync.write<ProfileVideoOffsetSnapshot>(
          key: cacheKey,
          value: snapshot,
          toJson: (s) => s.toJson(),
        );

    Future<ProfileVideoOffsetSnapshot?> readSnapshot() =>
        CacheSync.read<ProfileVideoOffsetSnapshot>(
          key: cacheKey,
          fromJson: ProfileVideoOffsetSnapshot.fromJson,
        );

    test('close unsubscribes the active profile feed subscription', () async {
      h.stubAuthorFeed(_result(const []));
      final cubit = h.build();
      await pumpEventQueue();

      await cubit.close();

      verify(() => h.ves.unsubscribeFromUserVideos(_author)).called(1);
    });

    group('CacheSync fills on bad networks', () {
      test('persists the relay seed when the REST load fails', () async {
        // A cache that only fills after a successful round-trip is empty for
        // exactly the users who need it: every cold start on a bad connection
        // re-fails and still persists nothing.
        when(
          () => h.ves.authorVideos(any()),
        ).thenReturn([_video('v1', createdAt: 5000)]);
        h.stubAuthorFeedThrows(const FunnelcakeException('offline'));

        final cubit = h.build();
        addTearDown(cubit.close);
        await pumpEventQueue();

        final persisted = await readSnapshot();
        expect(persisted, isNotNull);
        expect(persisted!.videos.map((v) => v.id), ['v1']);
      });

      test('does not persist a cold open that has nothing to show', () async {
        when(() => h.ves.authorVideos(any())).thenReturn(const <VideoEvent>[]);
        h.stubAuthorFeedThrows(const FunnelcakeException('offline'));

        final cubit = h.build();
        addTearDown(cubit.close);
        await pumpEventQueue();

        // Persisting an empty window would make the next cold start restore
        // nothing and skip straight past the stale-while-revalidate path it
        // exists for.
        expect(await readSnapshot(), isNull);
      });
    });

    group('CacheSync stale-while-revalidate', () {
      test('reopen restores the persisted window + cursor instantly, then '
          'revalidates the head without clobbering the cursor', () async {
        await seedSnapshot(
          ProfileVideoOffsetSnapshot(
            videos: [
              _video('v1', createdAt: 5000),
              _video('v2', createdAt: 4000),
              _video('v3', createdAt: 3000),
            ],
            nextOffset: 150,
            totalVideoCount: 300,
            hasMoreContent: true,
          ),
        );
        // Head revalidation returns the freshest first page (no new clips).
        h.stubAuthorFeed(
          _result(
            [_video('v1', createdAt: 5000)],
            totalCount: 300,
            nextOffset: 50,
            hasMore: true,
          ),
        );

        final cubit = h.build();
        addTearDown(cubit.close);
        await pumpEventQueue();

        expect(cubit.state.status, ProfileFeedStatus.ready);
        expect(cubit.state.videos.map((v) => v.id), ['v1', 'v2', 'v3']);
        // Cursor comes from the snapshot, NOT the head refresh's offset (50).
        expect(cubit.state.nextOffset, 150);
        expect(cubit.state.hasMoreContent, isTrue);
        expect(cubit.state.totalVideoCount, 300);
        expect(cubit.state.isInitialLoad, isFalse);
        expect(cubit.state.isRefreshing, isFalse);
        verify(
          () => h.repo.getAuthorFeed(
            authorPubkey: _author,
            relaySeed: any(named: 'relaySeed'),
            skipCache: true,
          ),
        ).called(1);
      });

      test('cold load persists the resolved window', () async {
        h.stubAuthorFeed(
          _result(
            [_video('a', createdAt: 5000), _video('b', createdAt: 4000)],
            totalCount: 2,
            hasMore: false,
          ),
        );

        final cubit = h.build();
        addTearDown(cubit.close);
        await pumpEventQueue(times: 3);

        final persisted = await readSnapshot();
        expect(persisted, isNotNull);
        expect(persisted!.videos.map((v) => v.id), ['a', 'b']);
        expect(persisted.totalVideoCount, 2);
        expect(persisted.hasMoreContent, isFalse);
      });

      test('REST load-more grows the persisted window', () async {
        h.stubAuthorFeedSequence([
          _result(
            [_video('a', createdAt: 5000)],
            totalCount: 1,
            nextOffset: 1,
            hasMore: true,
          ),
          _result(
            [_video('b', createdAt: 4000)],
            totalCount: 2,
            nextOffset: 2,
            hasMore: false,
          ),
        ]);

        final cubit = h.build();
        addTearDown(cubit.close);
        await pumpEventQueue(times: 3);

        cubit.add(const ProfileFeedLoadMoreRequested());
        await pumpEventQueue(times: 3);

        expect(cubit.state.videos.map((v) => v.id), ['a', 'b']);
        expect(cubit.state.nextOffset, 2);

        final persisted = await readSnapshot();
        expect(persisted!.videos.map((v) => v.id), ['a', 'b']);
        expect(persisted.nextOffset, 2);
        expect(persisted.hasMoreContent, isFalse);
      });

      test(
        'revalidation failure keeps the restored window (offline reopen)',
        () async {
          await seedSnapshot(
            ProfileVideoOffsetSnapshot(
              videos: [
                _video('v1', createdAt: 5000),
                _video('v2', createdAt: 4000),
              ],
              nextOffset: 120,
              totalVideoCount: 200,
              hasMoreContent: true,
            ),
          );
          // Head revalidation fails (e.g. offline); the restored window must
          // survive and the cursor must not be reset.
          h.stubAuthorFeedThrows(Exception('offline'));

          final cubit = h.build();
          addTearDown(cubit.close);
          await pumpEventQueue();

          expect(cubit.state.status, ProfileFeedStatus.ready);
          expect(cubit.state.videos.map((v) => v.id), ['v1', 'v2']);
          expect(cubit.state.nextOffset, 120);
          expect(cubit.state.hasMoreContent, isTrue);
          expect(cubit.state.isRefreshing, isFalse);
        },
      );

      test('Nostr-fallback loadMore persists the grown window', () async {
        // No snapshot seeded -> cold load into Nostr-fallback mode (a null
        // REST offset), then a relay-backed load-more.
        h.stubAuthorFeed(
          _result(
            [_video('a', createdAt: 3000)],
            totalCount: 50,
            hasMore: true,
          ),
        );
        final cubit = h.build();
        addTearDown(cubit.close);
        await pumpEventQueue(times: 3);
        expect(cubit.state.nextOffset, isNull);

        when(() => h.ves.authorVideos(_author)).thenReturn([
          _video('a', createdAt: 3000),
          _video('b', createdAt: 2000),
        ]);
        cubit.add(const ProfileFeedLoadMoreRequested());
        await pumpEventQueue(times: 3);

        expect(cubit.state.videos.map((v) => v.id), containsAll(['a', 'b']));

        final persisted = await readSnapshot();
        expect(persisted, isNotNull);
        expect(persisted!.videos.map((v) => v.id), containsAll(['a', 'b']));
        expect(persisted.nextOffset, isNull);
      });
    });

    test('cold load: REST success -> ready with envelope', () async {
      final cubit = await buildReady(
        _result([_video('a')], totalCount: 42, nextOffset: 50, hasMore: true),
      );
      addTearDown(cubit.close);

      expect(cubit.state.status, ProfileFeedStatus.ready);
      expect(cubit.state.videos.single.id, 'a');
      expect(cubit.state.totalVideoCount, 42);
      expect(cubit.state.nextOffset, 50);
      expect(cubit.state.hasMoreContent, isTrue);
      expect(cubit.state.isFetchingTotalCount, isFalse);
      expect(cubit.state.isInitialLoad, isFalse);
      verify(() => h.ves.subscribeToUserVideos(_author)).called(1);
    });

    test(
      'cold load: cached reseed is followed by skip-cache refresh',
      () async {
        h.stubAuthorFeedSequence([
          _result([_video('cached')], hasMore: true, isFromCache: true),
          _result(const [], hasMore: false),
        ]);

        final cubit = h.build();
        addTearDown(cubit.close);
        await pumpEventQueue();
        await pumpEventQueue();

        expect(cubit.state.status, ProfileFeedStatus.ready);
        expect(cubit.state.videos, isEmpty);
        expect(cubit.state.hasMoreContent, isFalse);
        verifyInOrder([
          () => h.repo.getAuthorFeed(
            authorPubkey: _author,
            relaySeed: any(named: 'relaySeed'),
          ),
          () => h.repo.getAuthorFeed(
            authorPubkey: _author,
            relaySeed: any(named: 'relaySeed'),
            skipCache: true,
          ),
        ]);
      },
    );

    test(
      'cold load: partial first page backfills to a complete initial page',
      () async {
        h.stubAuthorFeedSequence([
          _result(
            [_video('a', createdAt: 4000), _video('b', createdAt: 3000)],
            totalCount: 4,
            nextOffset: 2,
            hasMore: true,
          ),
          _result(
            [_video('c', createdAt: 2000), _video('d')],
            totalCount: 4,
            hasMore: false,
          ),
        ]);

        final cubit = h.build();
        addTearDown(cubit.close);
        await pumpEventQueue(times: 5);

        expect(cubit.state.status, ProfileFeedStatus.ready);
        expect(cubit.state.videos.map((video) => video.id), [
          'a',
          'b',
          'c',
          'd',
        ]);
        expect(cubit.state.hasMoreContent, isFalse);
        expect(cubit.state.nextOffset, isNull);
        verify(
          () => h.repo.getAuthorFeed(authorPubkey: _author, offset: 2),
        ).called(1);
      },
    );

    test('cold load: backfill skips empty advancing REST pages', () async {
      h.stubAuthorFeedSequence([
        _result(
          [_video('a', createdAt: 5000), _video('b', createdAt: 4000)],
          totalCount: 4,
          nextOffset: 2,
          hasMore: true,
        ),
        _result(const [], totalCount: 4, nextOffset: 3, hasMore: true),
        _result(
          [_video('c', createdAt: 3000), _video('d', createdAt: 2000)],
          totalCount: 4,
          hasMore: false,
        ),
      ]);

      final cubit = h.build();
      addTearDown(cubit.close);
      await pumpEventQueue(times: 8);

      expect(cubit.state.videos.map((video) => video.id), ['a', 'b', 'c', 'd']);
      expect(cubit.state.hasMoreContent, isFalse);
      expect(cubit.state.nextOffset, isNull);
      verify(
        () => h.repo.getAuthorFeed(authorPubkey: _author, offset: 2),
      ).called(1);
      verify(
        () => h.repo.getAuthorFeed(authorPubkey: _author, offset: 3),
      ).called(1);
    });

    test('cold load: REST failure, no relay -> failure + addError', () async {
      h.stubAuthorFeedThrows(Exception('boom'));
      final cubit = h.build();
      addTearDown(cubit.close);
      await pumpEventQueue();

      expect(cubit.state.status, ProfileFeedStatus.failure);
      expect(cubit.state.videos, isEmpty);
      expect(cubit.state.isFetchingTotalCount, isFalse);
    });

    test(
      'cold load: REST failure but relay has videos -> stays ready',
      () async {
        h.stubAuthorFeedThrows(Exception('boom'));
        when(() => h.ves.authorVideos(_author)).thenReturn([_video('relay')]);
        final cubit = h.build();
        addTearDown(cubit.close);
        await pumpEventQueue();

        expect(cubit.state.status, ProfileFeedStatus.ready);
        expect(cubit.state.videos.single.id, 'relay');
      },
    );

    test(
      'loadMore REST: appends the next page and advances the offset',
      () async {
        final cubit = await buildReady(
          _result(
            [_video('a', createdAt: 3000)],
            nextOffset: 50,
            hasMore: true,
          ),
        );
        addTearDown(cubit.close);

        h.stubAuthorFeed(
          _result(
            [_video('b', createdAt: 2000)],
            nextOffset: 100,
            hasMore: false,
          ),
        );
        cubit.add(const ProfileFeedLoadMoreRequested());
        await pumpEventQueue();

        expect(cubit.state.videos.map((v) => v.id), ['a', 'b']);
        expect(cubit.state.nextOffset, 100);
        expect(cubit.state.hasMoreContent, isFalse);
        expect(cubit.state.isLoadingMore, isFalse);
      },
    );

    test(
      'loadMore REST: empty advancing page keeps REST pagination active',
      () async {
        final initialVideos = [
          for (var i = 0; i < AppConstants.paginationBatchSize; i++)
            _video('initial-$i', createdAt: 5000 - i),
        ];
        final cubit = await buildReady(
          _result(initialVideos, nextOffset: 50, hasMore: true),
        );
        addTearDown(cubit.close);
        clearInteractions(h.repo);

        h.stubAuthorFeed(_result(const [], nextOffset: 100, hasMore: true));
        cubit.add(const ProfileFeedLoadMoreRequested());
        await pumpEventQueue();

        expect(cubit.state.videos.map((video) => video.id), [
          for (var i = 0; i < AppConstants.paginationBatchSize; i++)
            'initial-$i',
        ]);
        expect(cubit.state.nextOffset, 100);
        expect(cubit.state.hasMoreContent, isTrue);
        expect(cubit.state.isLoadingMore, isFalse);
      },
    );

    test('loadMore failure: hasLoadMoreError set, videos retained, no error '
        'string in state', () async {
      final cubit = await buildReady(
        _result([_video('a')], nextOffset: 50, hasMore: true),
      );
      addTearDown(cubit.close);

      h.stubAuthorFeedThrows(Exception('page boom'));
      cubit.add(const ProfileFeedLoadMoreRequested());
      await pumpEventQueue();

      expect(cubit.state.status, ProfileFeedStatus.ready);
      expect(cubit.state.hasLoadMoreError, isTrue);
      expect(cubit.state.isLoadingMore, isFalse);
      expect(cubit.state.videos.single.id, 'a'); // retained
    });

    test(
      'loadMore recovers after a transient failure: the banner clears and the '
      'next page appends',
      () async {
        final cubit = await buildReady(
          _result(
            [_video('a', createdAt: 3000)],
            nextOffset: 50,
            hasMore: true,
          ),
        );
        addTearDown(cubit.close);

        // First page throws: degraded banner, videos + offset retained.
        h.stubAuthorFeedThrows(Exception('transient'));
        cubit.add(const ProfileFeedLoadMoreRequested());
        await pumpEventQueue();

        expect(cubit.state.hasLoadMoreError, isTrue);
        expect(cubit.state.videos.map((v) => v.id), ['a']);
        expect(cubit.state.nextOffset, 50);

        // Retry from the same offset succeeds: banner clears, page appends.
        h.stubAuthorFeed(
          _result(
            [_video('b', createdAt: 2000)],
            nextOffset: 100,
            hasMore: false,
          ),
        );
        cubit.add(const ProfileFeedLoadMoreRequested());
        await pumpEventQueue();

        expect(cubit.state.hasLoadMoreError, isFalse);
        expect(cubit.state.videos.map((v) => v.id), ['a', 'b']);
        expect(cubit.state.nextOffset, 100);
        expect(cubit.state.hasMoreContent, isFalse);
        expect(cubit.state.isLoadingMore, isFalse);
      },
    );

    test(
      'cold load -> loadMore -> realtime add compose in newest-first order',
      () async {
        final originalAudit = ProfileFeedCubit.relaySnapshotAudit;
        ProfileFeedCubit.relaySnapshotAudit = const Duration(milliseconds: 20);
        addTearDown(() => ProfileFeedCubit.relaySnapshotAudit = originalAudit);

        // Cold load: first page, more available.
        final cubit = await buildReady(
          _result(
            [_video('a', createdAt: 3000)],
            nextOffset: 50,
            hasMore: true,
          ),
        );
        addTearDown(cubit.close);
        expect(cubit.state.videos.map((v) => v.id), ['a']);

        // loadMore appends an older page beneath the cold-load page.
        h.stubAuthorFeed(
          _result(
            [_video('b', createdAt: 2000)],
            nextOffset: 100,
            hasMore: false,
          ),
        );
        cubit.add(const ProfileFeedLoadMoreRequested());
        await pumpEventQueue();
        expect(cubit.state.videos.map((v) => v.id), ['a', 'b']);

        // A new relay video for this author slots ahead of the paginated list
        // without disturbing the pagination cursor. It flows through the
        // audited snapshot reconciliation (the sole realtime add path).
        when(
          () => h.ves.authorVideos(_author),
        ).thenReturn([_video('c', createdAt: 5000)]);
        h.onChanged!();
        await Future<void>.delayed(const Duration(milliseconds: 60));
        await pumpEventQueue();

        expect(cubit.state.videos.map((v) => v.id), ['c', 'a', 'b']);
        expect(cubit.state.nextOffset, 100);
        expect(cubit.state.hasMoreContent, isFalse);
      },
    );

    test('C5: Nostr-fallback loadMore preserves totalVideoCount / isInitialLoad '
        '/ isFetchingTotalCount', () async {
      // REST unavailable -> getAuthorFeed returns seed-only (nextOffset null).
      final cubit = await buildReady(
        _result([_video('a', createdAt: 3000)], totalCount: 200, hasMore: true),
      );
      addTearDown(cubit.close);
      expect(cubit.state.nextOffset, isNull); // Nostr-fallback mode
      expect(cubit.state.totalVideoCount, 200);

      // Nostr loadMore: VES yields one more video.
      when(() => h.ves.authorVideos(_author)).thenReturn([
        _video('a', createdAt: 3000),
        _video('b', createdAt: 2000),
      ]);
      cubit.add(const ProfileFeedLoadMoreRequested());
      await pumpEventQueue();

      expect(cubit.state.videos.map((v) => v.id), containsAll(['a', 'b']));
      // The legacy bug dropped these; the fix preserves them.
      expect(cubit.state.totalVideoCount, 200);
      expect(cubit.state.isInitialLoad, isFalse);
      expect(cubit.state.isFetchingTotalCount, isFalse);
    });

    test('Nostr-fallback loadMore excludes tombstoned videos', () async {
      final cubit = await buildReady(
        _result([_video('a', createdAt: 3000)], hasMore: true),
      );
      addTearDown(cubit.close);
      expect(cubit.state.nextOffset, isNull);

      when(() => h.ves.authorVideos(_author)).thenReturn([
        _video('a', createdAt: 3000),
        _video('b', createdAt: 2000),
      ]);
      when(
        () => h.ves.isVideoEventKnownDeleted(
          any(that: isA<VideoEvent>().having((v) => v.id, 'id', 'b')),
        ),
      ).thenReturn(true);

      cubit.add(const ProfileFeedLoadMoreRequested());
      await pumpEventQueue();

      expect(cubit.state.videos.map((v) => v.id), ['a']);
    });

    test(
      'loadMore is droppable: two rapid requests cause one repo call',
      () async {
        final cubit = await buildReady(
          _result([_video('a')], nextOffset: 50, hasMore: true),
        );
        addTearDown(cubit.close);
        clearInteractions(h.repo);

        h.stubAuthorFeed(
          _result([_video('b')], nextOffset: 100, hasMore: false),
        );
        cubit
          ..add(const ProfileFeedLoadMoreRequested())
          ..add(const ProfileFeedLoadMoreRequested());
        await pumpEventQueue();

        verify(
          () => h.repo.getAuthorFeed(
            authorPubkey: any(named: 'authorPubkey'),
            offset: any(named: 'offset'),
            relaySeed: any(named: 'relaySeed'),
            skipCache: any(named: 'skipCache'),
          ),
        ).called(1);
      },
    );

    test('FiltersChanged re-filters in place without a re-fetch', () async {
      final cubit = await buildReady(
        _result([_video('a'), _video('b', pubkey: 'blocked')]),
      );
      addTearDown(cubit.close);
      expect(cubit.state.videos.length, 2);
      clearInteractions(h.repo);

      when(() => h.blocklist.shouldFilterFromFeeds('blocked')).thenReturn(true);
      cubit.add(const ProfileFeedFiltersChanged());
      await pumpEventQueue();

      expect(cubit.state.videos.map((v) => v.id), ['a']);
      verifyNever(
        () => h.repo.getAuthorFeed(
          authorPubkey: any(named: 'authorPubkey'),
          offset: any(named: 'offset'),
          relaySeed: any(named: 'relaySeed'),
          skipCache: any(named: 'skipCache'),
        ),
      );
    });

    test(
      'snapshot add: new video prepended; duplicate snapshot no-ops',
      () async {
        final originalAudit = ProfileFeedCubit.relaySnapshotAudit;
        ProfileFeedCubit.relaySnapshotAudit = const Duration(milliseconds: 20);
        addTearDown(() => ProfileFeedCubit.relaySnapshotAudit = originalAudit);

        final cubit = await buildReady(_result([_video('a')]));
        addTearDown(cubit.close);

        // A new relay video flows through the audited snapshot path; allow the
        // window to elapse before asserting the merged result.
        when(
          () => h.ves.authorVideos(_author),
        ).thenReturn([_video('b', createdAt: 5000), _video('a')]);
        h.onChanged!();
        await Future<void>.delayed(const Duration(milliseconds: 60));
        await pumpEventQueue();
        expect(cubit.state.videos.map((v) => v.id), ['b', 'a']);

        // A repeat snapshot with the same set produces no further change.
        final before = cubit.state.videos.length;
        h.onChanged!();
        await Future<void>.delayed(const Duration(milliseconds: 60));
        await pumpEventQueue();
        expect(cubit.state.videos.length, before);
      },
    );

    test(
      'relay-snapshot bursts coalesce into a single reconciliation (audit)',
      () async {
        final originalAudit = ProfileFeedCubit.relaySnapshotAudit;
        ProfileFeedCubit.relaySnapshotAudit = const Duration(milliseconds: 20);
        addTearDown(() => ProfileFeedCubit.relaySnapshotAudit = originalAudit);

        final cubit = await buildReady(_result(const []));
        addTearDown(cubit.close);

        // Cold-load interactions are irrelevant — only count the snapshot
        // reconciliation triggered by the burst below.
        clearInteractions(h.ves);
        when(
          () => h.ves.authorVideos(_author),
        ).thenReturn([_video('relay', createdAt: 9000)]);

        final emitted = <List<String>>[];
        final sub = cubit.stream.listen(
          (s) => emitted.add(s.videos.map((v) => v.id).toList()),
        );
        addTearDown(sub.cancel);

        // A burst of app-wide VideoEventService notifications (e.g. other feeds
        // streaming, or this author's backlog arriving as live events) all land
        // inside one audit window.
        for (var i = 0; i < 5; i++) {
          h.onChanged!();
        }
        await Future<void>.delayed(const Duration(milliseconds: 60));
        await pumpEventQueue();

        // The O(videos) snapshot reconciliation runs once, not once per
        // notification, and lands the new relay video in a single emit.
        verify(() => h.ves.authorVideos(_author)).called(1);
        expect(emitted, hasLength(1));
        expect(cubit.state.videos.map((v) => v.id), contains('relay'));
      },
    );

    test('VideoUpdated for this author triggers a refresh', () async {
      final cubit = await buildReady(_result([_video('a')], nextOffset: 1));
      addTearDown(cubit.close);
      clearInteractions(h.repo);
      h.stubAuthorFeed(_result([_video('a'), _video('c')], nextOffset: 2));

      h.onUpdate!(_video('a'));
      await pumpEventQueue();

      verify(
        () => h.repo.getAuthorFeed(
          authorPubkey: any(named: 'authorPubkey'),
          offset: any(named: 'offset'),
          relaySeed: any(named: 'relaySeed'),
          skipCache: true,
        ),
      ).called(1);
    });

    test('tombstoned videos are excluded from emitted state', () async {
      when(
        () => h.ves.isVideoEventKnownDeleted(
          any(that: isA<VideoEvent>().having((v) => v.id, 'id', 'a')),
        ),
      ).thenReturn(true);
      final cubit = await buildReady(_result([_video('a'), _video('b')]));
      addTearDown(cubit.close);

      expect(cubit.state.videos.map((v) => v.id), ['b']);
    });

    test('service tombstone removes an already-loaded REST video', () async {
      final originalAudit = ProfileFeedCubit.relaySnapshotAudit;
      ProfileFeedCubit.relaySnapshotAudit = const Duration(milliseconds: 20);
      addTearDown(() => ProfileFeedCubit.relaySnapshotAudit = originalAudit);

      final cubit = await buildReady(_result([_video('a'), _video('b')]));
      addTearDown(cubit.close);
      expect(cubit.state.videos.map((v) => v.id), ['a', 'b']);

      when(
        () => h.ves.isVideoEventKnownDeleted(
          any(that: isA<VideoEvent>().having((v) => v.id, 'id', 'a')),
        ),
      ).thenReturn(true);
      when(() => h.ves.authorVideos(_author)).thenReturn(const <VideoEvent>[]);

      h.onChanged!();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await pumpEventQueue();

      expect(cubit.state.videos.map((v) => v.id), ['b']);
      expect((await readSnapshot())?.videos.map((v) => v.id), ['b']);
    });

    test(
      'cold load excludes tombstoned replacement videos from REST',
      () async {
        final replacement = _video(
          'new-event-id-from-rest',
          vineId: 'deleted-addressable-d-tag',
          createdAt: 5000,
        );
        when(
          () => h.ves.isVideoEventKnownDeleted(
            any(
              that: isA<VideoEvent>()
                  .having((v) => v.id, 'id', 'new-event-id-from-rest')
                  .having(
                    (v) => v.stableId,
                    'stableId',
                    'deleted-addressable-d-tag',
                  ),
            ),
          ),
        ).thenReturn(true);

        final cubit = await buildReady(
          _result([replacement, _video('visible-event-id')]),
        );
        addTearDown(cubit.close);

        expect(cubit.state.videos.map((v) => v.id), ['visible-event-id']);
      },
    );

    test('blocklist is applied on the cold-load emit (#4782)', () async {
      when(() => h.blocklist.shouldFilterFromFeeds('blocked')).thenReturn(true);
      final cubit = await buildReady(
        _result([_video('a'), _video('b', pubkey: 'blocked')]),
      );
      addTearDown(cubit.close);

      expect(cubit.state.videos.map((v) => v.id), ['a']);
    });

    test('close() cancels the realtime listeners and the timer', () async {
      h.stubAuthorFeed(_result(const []));
      final cubit = h.build();
      await pumpEventQueue();
      await cubit.close();

      verify(() => h.ves.removeListener(any())).called(1);
    });

    test('spinner: isInitialLoad clears on the hard timeout when nothing '
        'settles', () {
      fakeAsync((async) {
        // REST is in flight; relay empty -> isInitialLoad stays true until the
        // hard timeout fires.
        final completer = Completer<AuthorFeedResult>();
        when(
          () => h.repo.getAuthorFeed(
            authorPubkey: any(named: 'authorPubkey'),
            offset: any(named: 'offset'),
            relaySeed: any(named: 'relaySeed'),
            skipCache: any(named: 'skipCache'),
          ),
        ).thenAnswer((_) => completer.future);
        final cubit = h.build();
        async.flushMicrotasks();

        expect(cubit.state.isInitialLoad, isTrue);

        async.elapse(ProfileFeedCubit.initialLoadHardTimeout);
        async.flushMicrotasks();

        expect(cubit.state.isInitialLoad, isFalse);

        // Settle the in-flight load and close inside the zone so no handler is
        // left awaiting across teardown.
        completer.complete(_result(const []));
        async.flushMicrotasks();
        cubit.close();
        async.flushMicrotasks();
      });
    });

    test('background enrichment re-emits with the enriched copies', () async {
      h.enrichOverride = (videos) async => [
        for (final v in videos) v.copyWith(title: 'enriched'),
      ];
      final cubit = await buildReady(_result([_video('a')]));
      addTearDown(cubit.close);

      expect(cubit.state.videos.single.title, 'enriched');
    });

    test(
      'stale background enrichment cannot reintroduce refreshed videos',
      () async {
        final enrichment = Completer<List<VideoEvent>>();
        var enrichCallCount = 0;
        h.enrichOverride = (videos) {
          enrichCallCount += 1;
          if (enrichCallCount == 1) return enrichment.future;
          return Future.value(videos);
        };
        h.stubAuthorFeedSequence([
          _result([_video('old-rest', vineId: 'old-vine')]),
          _result([_video('new-rest', vineId: 'new-vine')]),
        ]);

        final cubit = h.build();
        addTearDown(cubit.close);
        await pumpEventQueue();
        expect(cubit.state.videos.map((video) => video.id), ['old-rest']);

        cubit.add(const ProfileFeedRefreshRequested());
        await pumpEventQueue();
        expect(cubit.state.videos.map((video) => video.id), ['new-rest']);

        enrichment.complete([
          _video('old-nostr', vineId: 'old-vine', originalLikes: 10),
        ]);
        await pumpEventQueue();
        await pumpEventQueue();

        expect(cubit.state.videos.map((video) => video.id), ['new-rest']);
        expect(cubit.state.videos.single.originalLikes, isNull);
      },
    );

    group('pinned videos', () {
      test('cached pins lead the first emit; the relay list then replaces '
          'them', () async {
        when(
          () => h.pins.readCached(_author),
        ).thenAnswer((_) async => [_coordinate('c')]);
        final relayFetch = Completer<List<String>?>();
        when(() => h.pins.fetch(_author)).thenAnswer((_) => relayFetch.future);
        h.stubAuthorFeed(
          _result([
            _video('a', createdAt: 3000, dTag: 'a'),
            _video('b', createdAt: 2000, dTag: 'b'),
            _video('c', dTag: 'c'),
          ], hasMore: false),
        );

        final cubit = h.build();
        addTearDown(cubit.close);
        await pumpEventQueue();

        expect(cubit.state.videos.map((v) => v.id), ['c', 'a', 'b']);
        expect(cubit.state.pinnedCoordinates, [_coordinate('c')]);
        expect(cubit.state.isPinned(_video('c', dTag: 'c')), isTrue);
        expect(cubit.state.isPinned(_video('a', dTag: 'a')), isFalse);

        relayFetch.complete([_coordinate('b'), _coordinate('c')]);
        await pumpEventQueue();

        expect(cubit.state.videos.map((v) => v.id), ['b', 'c', 'a']);
        expect(cubit.state.pinnedCoordinates, [
          _coordinate('b'),
          _coordinate('c'),
        ]);
      });

      test('no emit orders the grid by a pin it does not also report as '
          'pinned', () async {
        await seedSnapshot(
          ProfileVideoOffsetSnapshot(
            videos: [
              _video('a', createdAt: 3000, dTag: 'a'),
              _video('b', createdAt: 2000, dTag: 'b'),
              _video('c', dTag: 'c'),
            ],
            nextOffset: 3,
            totalVideoCount: 3,
            hasMoreContent: false,
          ),
        );
        when(
          () => h.pins.readCached(_author),
        ).thenAnswer((_) async => [_coordinate('c')]);
        final relayFetch = Completer<List<String>?>();
        when(() => h.pins.fetch(_author)).thenAnswer((_) => relayFetch.future);
        h.stubAuthorFeed(
          _result(
            [
              _video('a', createdAt: 3000, dTag: 'a'),
            ],
            totalCount: 3,
            hasMore: false,
          ),
        );

        final cubit = h.build();
        addTearDown(cubit.close);
        final emitted = <ProfileFeedState>[];
        final sub = cubit.stream.listen(emitted.add);
        addTearDown(sub.cancel);
        await pumpEventQueue();

        final ordered = emitted
            .where((s) => s.videos.isNotEmpty && s.videos.first.id == 'c')
            .toList();
        expect(ordered, isNotEmpty);
        for (final state in ordered) {
          expect(state.pinnedCoordinates, [_coordinate('c')]);
          expect(state.isPinned(_video('c', dTag: 'c')), isTrue);
        }
      });

      test('a cold open seeded from the relay reports the cached pin on the '
          'same emit that orders by it', () async {
        when(() => h.ves.authorVideos(_author)).thenReturn([
          _video('a', createdAt: 3000, dTag: 'a'),
          _video('c', dTag: 'c'),
        ]);
        when(
          () => h.pins.readCached(_author),
        ).thenAnswer((_) async => [_coordinate('c')]);
        final relayFetch = Completer<List<String>?>();
        when(() => h.pins.fetch(_author)).thenAnswer((_) => relayFetch.future);
        h.stubAuthorFeed(
          _result([
            _video('a', createdAt: 3000, dTag: 'a'),
            _video('c', dTag: 'c'),
          ], hasMore: false),
        );

        final cubit = h.build();
        addTearDown(cubit.close);
        final emitted = <ProfileFeedState>[];
        final sub = cubit.stream.listen(emitted.add);
        addTearDown(sub.cancel);
        await pumpEventQueue();

        final ordered = emitted
            .where((s) => s.videos.isNotEmpty && s.videos.first.id == 'c')
            .toList();
        expect(ordered, isNotEmpty);
        for (final state in ordered) {
          expect(state.pinnedCoordinates, [_coordinate('c')]);
        }
      });

      test('an inconclusive relay read keeps the cached pins', () async {
        when(
          () => h.pins.readCached(_author),
        ).thenAnswer((_) async => [_coordinate('b')]);
        when(() => h.pins.fetch(_author)).thenAnswer((_) async => null);
        h.stubAuthorFeed(
          _result([
            _video('a', createdAt: 3000, dTag: 'a'),
            _video('b', createdAt: 2000, dTag: 'b'),
          ], hasMore: false),
        );

        final cubit = h.build();
        addTearDown(cubit.close);
        await pumpEventQueue();

        expect(cubit.state.videos.map((v) => v.id), ['b', 'a']);
      });

      test('a pinned video outside the loaded window is fetched by '
          'coordinate and placed first', () async {
        final old = _video('old', createdAt: 10, dTag: 'old');
        when(
          () => h.pins.fetch(_author),
        ).thenAnswer((_) async => [_coordinate('old')]);
        when(
          () => h.repo.getVideosByAddressableIds([
            _coordinate('old'),
          ], cacheResults: true),
        ).thenAnswer((_) async => [old]);
        h.stubAuthorFeed(
          _result([
            _video('a', createdAt: 3000, dTag: 'a'),
            _video('b', createdAt: 2000, dTag: 'b'),
          ], hasMore: false),
        );

        final cubit = h.build();
        addTearDown(cubit.close);
        await pumpEventQueue();

        expect(cubit.state.videos.map((v) => v.id), ['old', 'a', 'b']);
        // The resolved copy is not part of the source window the snapshot
        // persists: it is re-resolved by coordinate on the next open.
        final snapshot = await readSnapshot();
        expect(snapshot?.videos.map((v) => v.id), ['a', 'b']);
      });

      test('a pinned coordinate that resolves nowhere is skipped', () async {
        when(
          () => h.pins.fetch(_author),
        ).thenAnswer((_) async => [_coordinate('gone'), _coordinate('b')]);
        h.stubAuthorFeed(
          _result([
            _video('a', createdAt: 3000, dTag: 'a'),
            _video('b', createdAt: 2000, dTag: 'b'),
          ], hasMore: false),
        );

        final cubit = h.build();
        addTearDown(cubit.close);
        await pumpEventQueue();

        expect(cubit.state.videos.map((v) => v.id), ['b', 'a']);
        verify(
          () => h.repo.getVideosByAddressableIds([
            _coordinate('gone'),
          ], cacheResults: true),
        ).called(1);
      });

      test('pins survive every re-derivation: filter change, relay '
          'snapshot and refresh', () async {
        final originalAudit = ProfileFeedCubit.relaySnapshotAudit;
        ProfileFeedCubit.relaySnapshotAudit = const Duration(milliseconds: 20);
        addTearDown(() => ProfileFeedCubit.relaySnapshotAudit = originalAudit);
        when(
          () => h.pins.fetch(_author),
        ).thenAnswer((_) async => [_coordinate('b')]);
        final cubit = await buildReady(
          _result([
            _video('a', createdAt: 3000, dTag: 'a'),
            _video('b', createdAt: 2000, dTag: 'b'),
          ], hasMore: false),
        );
        addTearDown(cubit.close);
        expect(cubit.state.videos.map((v) => v.id), ['b', 'a']);

        cubit.add(const ProfileFeedFiltersChanged());
        await pumpEventQueue();
        expect(cubit.state.videos.map((v) => v.id), ['b', 'a']);

        when(() => h.ves.authorVideos(_author)).thenReturn([
          _video('c', createdAt: 4000, dTag: 'c'),
          _video('a', createdAt: 3000, dTag: 'a'),
          _video('b', createdAt: 2000, dTag: 'b'),
        ]);
        h.onChanged!();
        await cubit.stream.firstWhere((s) => s.videos.length == 3);
        expect(cubit.state.videos.map((v) => v.id), ['b', 'c', 'a']);

        // The mocked REST head has no 'c'; the refreshed window is [a, b]
        // again and the pin still leads it.
        cubit.add(const ProfileFeedRefreshRequested());
        await pumpEventQueue();
        expect(cubit.state.videos.map((v) => v.id), ['b', 'a']);
      });

      test('Nostr-fallback loadMore pages from the source window, not the '
          'pinned display order', () async {
        final old = _video('old', createdAt: 10, dTag: 'old');
        when(
          () => h.pins.fetch(_author),
        ).thenAnswer((_) async => [_coordinate('old')]);
        when(
          () => h.repo.getVideosByAddressableIds(any(), cacheResults: true),
        ).thenAnswer((_) async => [old]);
        final cubit = await buildReady(
          _result([_video('a', createdAt: 3000, dTag: 'a')], hasMore: true),
        );
        addTearDown(cubit.close);
        expect(cubit.state.nextOffset, isNull);
        expect(cubit.state.videos.map((v) => v.id), ['old', 'a']);

        cubit.add(const ProfileFeedLoadMoreRequested());
        await pumpEventQueue();

        verify(
          () => h.ves.queryHistoricalUserVideos(_author, until: 3000),
        ).called(1);
      });

      test(
        'pin: publishes, adopts the accepted list, reports pinned',
        () async {
          final b = _video('b', createdAt: 2000, dTag: 'b');
          when(
            () => h.pins.pin(_coordinate('b')),
          ).thenAnswer(
            (_) async => ProfilePinMutation.succeeded([_coordinate('b')]),
          );
          final cubit = await buildReady(
            _result([
              _video('a', createdAt: 3000, dTag: 'a'),
              b,
            ], hasMore: false),
          );
          addTearDown(cubit.close);
          final feedback = <ProfileFeedPinFeedback>[];
          final sub = cubit.stream.listen((s) => feedback.add(s.pinFeedback));
          addTearDown(sub.cancel);

          cubit.add(ProfileFeedPinRequested(b));
          await pumpEventQueue();

          expect(cubit.state.videos.map((v) => v.id), ['b', 'a']);
          expect(cubit.state.pinnedCoordinates, [_coordinate('b')]);
          expect(cubit.state.isPinMutationInFlight, isFalse);
          expect(feedback, contains(ProfileFeedPinFeedback.pinned));
        },
      );

      test('unpinning drops the resolved copy, so a later pin list resolves '
          'the video again instead of serving the stale one', () async {
        final oldV1 = _video('old-v1', createdAt: 10, dTag: 'old');
        final oldV2 = _video('old-v2', createdAt: 10, dTag: 'old');
        var resolveCount = 0;
        when(
          () => h.pins.fetch(_author),
        ).thenAnswer((_) async => [_coordinate('old')]);
        when(
          () => h.repo.getVideosByAddressableIds([
            _coordinate('old'),
          ], cacheResults: true),
        ).thenAnswer((_) async => [if (resolveCount++ == 0) oldV1 else oldV2]);
        when(
          () => h.pins.unpin(_coordinate('old')),
        ).thenAnswer((_) async => const ProfilePinMutation.succeeded([]));

        final cubit = await buildReady(
          _result([_video('a', createdAt: 3000, dTag: 'a')], hasMore: false),
        );
        addTearDown(cubit.close);
        expect(cubit.state.videos.map((v) => v.id), ['old-v1', 'a']);

        cubit.add(ProfileFeedUnpinRequested(oldV1));
        await pumpEventQueue();
        expect(cubit.state.pinnedCoordinates, isEmpty);

        // The relay reports it pinned again — from Divine Web, or a re-pin
        // after the video was edited.
        cubit.add(ProfileFeedPinsChanged([_coordinate('old')]));
        await pumpEventQueue();

        expect(cubit.state.videos.map((v) => v.id), ['old-v2', 'a']);
      });

      test('unpin: adopts the accepted list, reports unpinned', () async {
        final b = _video('b', createdAt: 2000, dTag: 'b');
        when(
          () => h.pins.fetch(_author),
        ).thenAnswer((_) async => [_coordinate('b')]);
        when(
          () => h.pins.unpin(_coordinate('b')),
        ).thenAnswer((_) async => const ProfilePinMutation.succeeded([]));
        final cubit = await buildReady(
          _result([_video('a', createdAt: 3000, dTag: 'a'), b], hasMore: false),
        );
        addTearDown(cubit.close);
        expect(cubit.state.videos.map((v) => v.id), ['b', 'a']);

        cubit.add(ProfileFeedUnpinRequested(b));
        await pumpEventQueue();

        expect(cubit.state.videos.map((v) => v.id), ['a', 'b']);
        expect(cubit.state.pinnedCoordinates, isEmpty);
        expect(cubit.state.pinFeedback, ProfileFeedPinFeedback.unpinned);
      });

      test('a quiet unpin adopts the accepted list and leaves the last '
          'feedback in place', () async {
        final b = _video('b', createdAt: 2000, dTag: 'b');
        when(
          () => h.pins.pin(_coordinate('b')),
        ).thenAnswer(
          (_) async => ProfilePinMutation.succeeded([_coordinate('b')]),
        );
        when(
          () => h.pins.unpin(_coordinate('b')),
        ).thenAnswer((_) async => const ProfilePinMutation.succeeded([]));
        final cubit = await buildReady(
          _result([_video('a', createdAt: 3000, dTag: 'a'), b], hasMore: false),
        );
        addTearDown(cubit.close);
        cubit.add(ProfileFeedPinRequested(b));
        await pumpEventQueue();
        expect(cubit.state.pinFeedback, ProfileFeedPinFeedback.pinned);
        final feedback = <ProfileFeedPinFeedback>[];
        final sub = cubit.stream.listen((s) => feedback.add(s.pinFeedback));
        addTearDown(sub.cancel);

        cubit.add(ProfileFeedUnpinRequested(b, quiet: true));
        await pumpEventQueue();

        expect(cubit.state.videos.map((v) => v.id), ['a', 'b']);
        expect(cubit.state.pinnedCoordinates, isEmpty);
        expect(cubit.state.isPinMutationInFlight, isFalse);
        // Neither the reset a loud request starts with nor an outcome.
        expect(feedback, isNotEmpty);
        expect(feedback, everyElement(ProfileFeedPinFeedback.pinned));
      });

      test('a quiet unpin that fails reports nothing either', () async {
        final b = _video('b', createdAt: 2000, dTag: 'b');
        when(
          () => h.pins.pin(_coordinate('b')),
        ).thenAnswer(
          (_) async => ProfilePinMutation.succeeded([_coordinate('b')]),
        );
        when(() => h.pins.unpin(_coordinate('b'))).thenAnswer(
          (_) async => const ProfilePinMutation.failed(
            ProfilePinFailure.couldNotReachRelays,
          ),
        );
        final cubit = await buildReady(
          _result([_video('a', createdAt: 3000, dTag: 'a'), b], hasMore: false),
        );
        addTearDown(cubit.close);
        cubit.add(ProfileFeedPinRequested(b));
        await pumpEventQueue();
        expect(cubit.state.pinFeedback, ProfileFeedPinFeedback.pinned);
        final feedback = <ProfileFeedPinFeedback>[];
        final sub = cubit.stream.listen((s) => feedback.add(s.pinFeedback));
        addTearDown(sub.cancel);

        cubit.add(ProfileFeedUnpinRequested(b, quiet: true));
        await pumpEventQueue();

        expect(cubit.state.pinnedCoordinates, [_coordinate('b')]);
        expect(cubit.state.videos.map((v) => v.id), ['b', 'a']);
        expect(cubit.state.isPinMutationInFlight, isFalse);
        expect(feedback, isNotEmpty);
        expect(feedback, everyElement(ProfileFeedPinFeedback.pinned));
      });

      test(
        'pin failure leaves the order alone and reports the cause',
        () async {
          final b = _video('b', createdAt: 2000, dTag: 'b');
          when(
            () => h.pins.pin(_coordinate('b')),
          ).thenAnswer(
            (_) async =>
                const ProfilePinMutation.failed(ProfilePinFailure.limitReached),
          );
          final cubit = await buildReady(
            _result([
              _video('a', createdAt: 3000, dTag: 'a'),
              b,
            ], hasMore: false),
          );
          addTearDown(cubit.close);

          cubit.add(ProfileFeedPinRequested(b));
          await pumpEventQueue();

          expect(cubit.state.videos.map((v) => v.id), ['a', 'b']);
          expect(cubit.state.pinnedCoordinates, isEmpty);
          expect(
            cubit.state.pinFeedback,
            ProfileFeedPinFeedback.pinLimitReached,
          );
          expect(cubit.state.isPinMutationInFlight, isFalse);
        },
      );

      test(
        'pin at the cap reports the limit without a relay round trip',
        () async {
          final videos = [
            for (var i = 0; i <= ProfilePinsRepository.maxPins; i++)
              _video('v$i', createdAt: 3000 - i, dTag: 'v$i'),
          ];
          when(() => h.pins.fetch(_author)).thenAnswer(
            (_) async => [for (final v in videos.skip(1)) v.addressableId!],
          );
          final cubit = await buildReady(_result(videos, hasMore: false));
          addTearDown(cubit.close);
          expect(cubit.state.canPinMore, isFalse);

          cubit.add(ProfileFeedPinRequested(videos[0]));
          await pumpEventQueue();

          expect(
            cubit.state.pinFeedback,
            ProfileFeedPinFeedback.pinLimitReached,
          );
          expect(cubit.state.isPinMutationInFlight, isFalse);
          verifyNever(() => h.pins.pin(any()));

          // Unpin is still allowed at the cap.
          when(() => h.pins.unpin(videos[1].addressableId!)).thenAnswer(
            (_) async => ProfilePinMutation.succeeded([
              for (final v in videos.skip(2)) v.addressableId!,
            ]),
          );
          cubit.add(ProfileFeedUnpinRequested(videos[1]));
          await pumpEventQueue();
          expect(cubit.state.pinFeedback, ProfileFeedPinFeedback.unpinned);
          expect(cubit.state.canPinMore, isTrue);
        },
      );

      test(
        'a legacy video without a d tag is never sent to the repository',
        () async {
          final legacy = _video('legacy', createdAt: 2000);
          final cubit = await buildReady(
            _result([legacy], hasMore: false),
          );
          addTearDown(cubit.close);

          cubit.add(ProfileFeedPinRequested(legacy));
          await pumpEventQueue();

          verifyNever(() => h.pins.pin(any()));
          expect(cubit.state.pinFeedback, ProfileFeedPinFeedback.none);
        },
      );

      test('a second mutation while one is in flight is dropped', () async {
        final a = _video('a', createdAt: 3000, dTag: 'a');
        final b = _video('b', createdAt: 2000, dTag: 'b');
        final inFlight = Completer<ProfilePinMutation>();
        when(() => h.pins.pin(any())).thenAnswer((_) => inFlight.future);
        final cubit = await buildReady(_result([a, b], hasMore: false));
        addTearDown(cubit.close);

        cubit
          ..add(ProfileFeedPinRequested(a))
          ..add(ProfileFeedPinRequested(b));
        await pumpEventQueue();
        expect(cubit.state.isPinMutationInFlight, isTrue);

        inFlight.complete(ProfilePinMutation.succeeded([_coordinate('a')]));
        await pumpEventQueue();

        verify(() => h.pins.pin(_coordinate('a'))).called(1);
        verifyNever(() => h.pins.pin(_coordinate('b')));
        expect(cubit.state.videos.map((v) => v.id), ['a', 'b']);
      });
    });

    group('ProfileFeedRefreshRequested completer', () {
      test('fires once the refresh has settled', () async {
        final cubit = await buildReady(_result([_video('a')]));
        addTearDown(cubit.close);

        final refresh = Completer<void>();
        cubit.add(ProfileFeedRefreshRequested(completer: refresh));

        await refresh.future.timeout(
          const Duration(seconds: 1),
          onTimeout: () => fail(
            'the refresh completer never fired — pull-to-refresh '
            'would spin forever',
          ),
        );
      });

      test('a superseded refresh still fires its own completer', () async {
        Completer<AuthorFeedResult>? gate;
        when(
          () => h.repo.getAuthorFeed(
            authorPubkey: any(named: 'authorPubkey'),
            offset: any(named: 'offset'),
            relaySeed: any(named: 'relaySeed'),
            skipCache: any(named: 'skipCache'),
          ),
        ).thenAnswer((_) {
          final parked = gate;
          gate = null;
          return parked?.future ?? Future.value(_result([_video('a')]));
        });

        final cubit = h.build();
        addTearDown(cubit.close);
        await pumpEventQueue();

        // Park the first refresh mid-load, then supersede it. `restartable()`
        // cancels the loser's emitter but still runs its handler, so its
        // `finally` — and therefore its waiter — must survive the swap.
        final firstLoad = Completer<AuthorFeedResult>();
        gate = firstLoad;
        final first = Completer<void>();
        cubit.add(ProfileFeedRefreshRequested(completer: first));
        await pumpEventQueue();
        expect(first.isCompleted, isFalse);

        final second = Completer<void>();
        cubit.add(ProfileFeedRefreshRequested(completer: second));
        firstLoad.complete(_result([_video('b')]));

        await Future.wait([first.future, second.future]).timeout(
          const Duration(seconds: 1),
          onTimeout: () => fail(
            'a superseded refresh stranded its completer — '
            'pull-to-refresh would spin forever',
          ),
        );
      });
    });
  });
}

// ABOUTME: Tests for ProfileSavedVideosBloc — loading bookmarked videos from
// ABOUTME: BookmarksRepository and paginating through VideosRepository.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:bookmarks_repository/bookmarks_repository.dart';
import 'package:cache_sync/cache_sync.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart' show NostrClient;
import 'package:nostr_sdk/nostr_sdk.dart'
    show
        Event,
        Filter,
        LocalNostrSigner,
        NostrSigner,
        generatePrivateKey,
        getPublicKey;
import 'package:openvine/blocs/profile_saved_videos/profile_saved_videos_bloc.dart';
import 'package:openvine/blocs/profile_shared/profile_tab_page_size.dart';
import 'package:openvine/blocs/profile_shared/profile_video_list_snapshot.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockBookmarksRepository extends Mock implements BookmarksRepository {}

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockBookmarkSigner extends Mock implements BookmarkSigner {}

class _MockNostrSigner extends Mock implements NostrSigner {}

/// The public references of a list with no private section: whatever the
/// mocked list names is public. The bloc only asks it [contains].
class _EveryReferenceIsPublic extends SetBase<String> {
  @override
  bool contains(Object? element) => element is String;

  @override
  Iterator<String> get iterator =>
      throw UnsupportedError('the set of every reference cannot be listed');

  @override
  int get length =>
      throw UnsupportedError('the set of every reference has no length');

  @override
  bool add(String value) => throw UnsupportedError('read-only');

  @override
  String? lookup(Object? element) => element is String ? element : null;

  @override
  bool remove(Object? value) => throw UnsupportedError('read-only');

  @override
  Set<String> toSet() => this;
}

/// In-memory [CacheDao] so the bloc's [CacheSync] reads/writes are isolated
/// per test without touching disk.
class _InMemoryCacheDao implements CacheDao {
  final Map<String, String> _store = {};

  /// Keys whose entries read as expired, as a past-TTL row would.
  final Set<String> staleKeys = {};

  /// When set, [write] parks until it completes, holding a sync handler in the
  /// post-emit snapshot write the way a real disk write does.
  Completer<void>? writeGate;

  @override
  Future<CacheEntry?> readEntry(String key) async {
    final payload = _store[key];
    return payload == null
        ? null
        : CacheEntry(payload: payload, isStale: staleKeys.contains(key));
  }

  @override
  Future<void> write({
    required String key,
    required String payload,
    Duration? ttl,
  }) async {
    await writeGate?.future;
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

void main() {
  group('ProfileSavedVideosBloc', () {
    late _MockBookmarksRepository mockBookmarksRepository;
    late _MockVideosRepository mockVideosRepository;
    late _InMemoryCacheDao cacheDao;

    const currentUserPubkey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

    /// Where the bloc persists its snapshot.
    const snapshotCacheKey = '$currentUserPubkey:profile_saved_videos_v4';

    /// Author of every fixture video.
    final videoAuthor = '0' * 64;

    /// The address of the Kind 34236 fixture video carrying [dTag].
    String coordinateFor(String dTag) => '34236:$videoAuthor:$dTag';

    /// One addressable video before and after an edit: the edit republishes it
    /// at the same address under a new event id (#7135).
    final originalRevisionId = '1' * 64;
    final editedRevisionId = '2' * 64;

    setUp(() async {
      mockBookmarksRepository = _MockBookmarksRepository();
      mockVideosRepository = _MockVideosRepository();
      cacheDao = _InMemoryCacheDao();
      await CacheSync.init(dao: cacheDao);

      // The bloc reconciles with the relay before reading the list; tests that
      // care about the relay-sourced path override this.
      when(
        () => mockBookmarksRepository.syncGlobalBookmarks(),
      ).thenAnswer((_) async => true);
      // The bloc subscribes at construction; tests that drive a change swap in
      // a controller of their own.
      when(
        () => mockBookmarksRepository.watchBookmarkedVideoReferences(),
      ).thenAnswer((_) => const Stream<List<String>>.empty());
      when(
        () => mockBookmarksRepository.hasUnreadablePrivateItems,
      ).thenReturn(false);
      // These lists have no private section; the private case runs against a
      // real repository ('with private bookmarks on the list').
      when(
        () => mockBookmarksRepository.publicBookmarkedVideoReferences,
      ).thenReturn(_EveryReferenceIsPublic());
    });

    ProfileSavedVideosBloc createBloc({
      Stream<String>? removedVideoIds,
      bool Function(VideoEvent video)? deletedVideoFilter,
    }) => ProfileSavedVideosBloc(
      bookmarksRepository: mockBookmarksRepository,
      videosRepository: mockVideosRepository,
      currentUserPubkey: currentUserPubkey,
      removedVideoIds: removedVideoIds ?? const Stream<String>.empty(),
      deletedVideoFilter: deletedVideoFilter ?? (_) => false,
    );

    /// The video references the repository holds for a grid showing [ids]
    /// top to bottom: the repository lists the oldest bookmark first, and the
    /// bloc reverses it for presentation.
    List<String> referencesShownAs(List<String> ids) => ids.reversed.toList();

    VideoEvent createTestVideo(
      String id, {
      String videoUrl = 'https://example.com/video.mp4',
      String? addressableDTag,
    }) {
      final now = DateTime.now();
      return VideoEvent(
        id: id,
        pubkey: videoAuthor,
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        content: '',
        timestamp: now,
        title: 'Test Video $id',
        videoUrl: videoUrl,
        thumbnailUrl: 'https://example.com/thumb.jpg',
        addressableDTag: addressableDTag,
      );
    }

    /// Answers [VideosRepository.getVideosByAddressableIds] with the edited
    /// revision of the `clip` video, the latest one at its address.
    void stubLatestRevisionAtClipAddress() {
      when(
        () => mockVideosRepository.getVideosByAddressableIds(
          any(),
          cacheResults: any(named: 'cacheResults'),
        ),
      ).thenAnswer(
        (invocation) async => [
          for (final coordinate
              in invocation.positionalArguments.first as List<String>)
            if (coordinate == coordinateFor('clip'))
              createTestVideo(editedRevisionId, addressableDTag: 'clip'),
        ],
      );
    }

    /// Answers [VideosRepository.getVideosByIds] with a video per id, the
    /// original revision of the `clip` video included.
    void stubVideosByEventId() {
      when(
        () => mockVideosRepository.getVideosByIds(
          any(),
          cacheResults: any(named: 'cacheResults'),
        ),
      ).thenAnswer(
        (invocation) async => [
          for (final id in invocation.positionalArguments.first as List<String>)
            createTestVideo(
              id,
              addressableDTag: id == originalRevisionId ? 'clip' : null,
            ),
        ],
      );
    }

    for (final warmRefresh in [false, true]) {
      test(
        'retains a save made during ${warmRefresh ? 'warm' : 'cold'} sync',
        () async {
          final firstId = 'a' * 64;
          final secondId = 'b' * 64;
          final newestId = 'c' * 64;
          final changes = StreamController<List<String>>.broadcast();
          var items = referencesShownAs([firstId]);
          when(() => mockBookmarksRepository.bookmarkedVideoReferences)
              .thenAnswer((_) => items);
          when(() => mockBookmarksRepository.watchBookmarkedVideoReferences())
              .thenAnswer((_) => changes.stream);
          when(() => mockBookmarksRepository.syncGlobalBookmarks())
              .thenAnswer((_) async {
                changes.add(items);
                return true;
              });
          final fetchedIds = <String>[];
          final fetchStarted = Completer<void>();
          final fetchGate = Completer<void>();
          when(
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          ).thenAnswer((invocation) async {
            final ids = invocation.positionalArguments.first as List<String>;
            fetchedIds.addAll(ids);
            if (ids.contains(secondId) && !fetchStarted.isCompleted) {
              fetchStarted.complete();
              await fetchGate.future;
            }
            return ids.map(createTestVideo).toList();
          });
          final bloc = createBloc();
          addTearDown(() async {
            if (!fetchGate.isCompleted) fetchGate.complete();
            await bloc.close();
            await changes.close();
          });
          if (warmRefresh) {
            final initial = Completer<void>();
            bloc.add(ProfileSavedVideosSyncRequested(completer: initial));
            await initial.future;
            await pumpEventQueue();
          }
          items = referencesShownAs([secondId, firstId]);
          final sync = Completer<void>();
          bloc.add(ProfileSavedVideosSyncRequested(completer: sync));
          await fetchStarted.future;
          await pumpEventQueue();
          items = referencesShownAs([newestId, secondId, firstId]);
          changes.add(items);
          await pumpEventQueue();
          fetchGate.complete();
          await sync.future;
          await pumpEventQueue();
          expect(bloc.state.savedEventIds, [newestId, secondId, firstId]);
          expect(fetchedIds.where((id) => id == secondId), hasLength(1));
          expect(fetchedIds.where((id) => id == newestId), hasLength(1));
          final persisted = await cacheDao.readEntry(snapshotCacheKey);
          expect(
            ProfileVideoListSnapshot.fromJson(persisted!.payload).itemIds,
            [
              newestId,
              secondId,
              firstId,
            ],
          );
        },
      );
    }

    test('coalesces load-more requests queued during a refresh', () async {
      final ids = List.generate(
        ProfileTabPagination.pageSize * 4,
        (i) => i.toRadixString(16).padLeft(64, '0'),
      );
      when(() => mockBookmarksRepository.bookmarkedVideoReferences)
          .thenReturn(referencesShownAs(ids));
      when(
        () => mockVideosRepository.getVideosByIds(
          any(),
          cacheResults: any(named: 'cacheResults'),
        ),
      ).thenAnswer(
        (invocation) async =>
            (invocation.positionalArguments.first as List<String>)
                .map(createTestVideo)
                .toList(),
      );
      final bloc = createBloc();
      final refreshGate = Completer<void>();
      addTearDown(() async {
        if (!refreshGate.isCompleted) refreshGate.complete();
        await bloc.close();
      });
      final initial = Completer<void>();
      bloc.add(ProfileSavedVideosSyncRequested(completer: initial));
      await initial.future;
      final refreshStarted = Completer<void>();
      when(() => mockBookmarksRepository.syncGlobalBookmarks())
          .thenAnswer((_) async {
            if (!refreshStarted.isCompleted) refreshStarted.complete();
            await refreshGate.future;
            return true;
          });
      final refresh = Completer<void>();
      bloc.add(ProfileSavedVideosSyncRequested(completer: refresh));
      await refreshStarted.future;
      for (var i = 0; i < 4; i++) {
        bloc.add(const ProfileSavedVideosLoadMoreRequested());
        await pumpEventQueue();
      }
      refreshGate.complete();
      await refresh.future;
      await pumpEventQueue();
      expect(bloc.state.nextPageOffset, ProfileTabPagination.pageSize * 2);
      final persisted = await cacheDao.readEntry(snapshotCacheKey);
      expect(
        ProfileVideoListSnapshot.fromJson(persisted!.payload).nextPageOffset,
        ProfileTabPagination.pageSize * 2,
      );
      // A new gesture after completion still loads the next page.
      bloc.add(const ProfileSavedVideosLoadMoreRequested());
      await pumpEventQueue();
      expect(bloc.state.nextPageOffset, ProfileTabPagination.pageSize * 3);
    });

    test('initial state is initial with empty collections', () {
      final bloc = createBloc();
      addTearDown(bloc.close);
      expect(bloc.state.status, ProfileSavedVideosStatus.initial);
      expect(bloc.state.videos, isEmpty);
      expect(bloc.state.savedEventIds, isEmpty);
      expect(bloc.state.error, isNull);
    });

    group('ProfileSavedVideosState', () {
      test('isLoaded returns true when status is success', () {
        const initialState = ProfileSavedVideosState();
        const successState = ProfileSavedVideosState(
          status: ProfileSavedVideosStatus.success,
        );

        expect(initialState.isLoaded, isFalse);
        expect(successState.isLoaded, isTrue);
      });

      test('isLoading returns true when status is loading or syncing', () {
        const loadingState = ProfileSavedVideosState(
          status: ProfileSavedVideosStatus.loading,
        );
        const syncingState = ProfileSavedVideosState(
          status: ProfileSavedVideosStatus.syncing,
        );
        const successState = ProfileSavedVideosState(
          status: ProfileSavedVideosStatus.success,
        );

        expect(loadingState.isLoading, isTrue);
        expect(syncingState.isLoading, isTrue);
        expect(successState.isLoading, isFalse);
      });
    });

    group('ProfileSavedVideosSyncRequested', () {
      group('with a private list it could not unlock', () {
        blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
          'flags it rather than settling as nothing saved',
          setUp: () {
            when(
              () => mockBookmarksRepository.bookmarkedVideoReferences,
            ).thenReturn(const []);
            when(
              () => mockBookmarksRepository.hasUnreadablePrivateItems,
            ).thenReturn(true);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const ProfileSavedVideosSyncRequested()),
          wait: const Duration(milliseconds: 50),
          expect: () => [
            const ProfileSavedVideosState(
              status: ProfileSavedVideosStatus.success,
              hasMoreContent: false,
              privateBookmarksLocked: true,
            ),
          ],
        );

        test('clears the flag once a later sync unlocks the list', () async {
          var locked = true;
          when(
            () => mockBookmarksRepository.bookmarkedVideoReferences,
          ).thenReturn(const []);
          when(
            () => mockBookmarksRepository.hasUnreadablePrivateItems,
          ).thenAnswer((_) => locked);
          final bloc = createBloc();
          addTearDown(bloc.close);

          final first = Completer<void>();
          bloc.add(ProfileSavedVideosSyncRequested(completer: first));
          await first.future.timeout(const Duration(seconds: 5));
          expect(bloc.state.privateBookmarksLocked, isTrue);

          locked = false;
          final second = Completer<void>();
          bloc.add(ProfileSavedVideosSyncRequested(completer: second));
          await second.future.timeout(const Duration(seconds: 5));

          expect(bloc.state.privateBookmarksLocked, isFalse);
        });

        blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
          'flags it on a re-sync of videos already showing',
          setUp: () {
            when(
              () => mockBookmarksRepository.bookmarkedVideoReferences,
            ).thenReturn(referencesShownAs(['video-1']));
            when(
              () => mockBookmarksRepository.hasUnreadablePrivateItems,
            ).thenReturn(true);
          },
          build: createBloc,
          seed: () => ProfileSavedVideosState(
            status: ProfileSavedVideosStatus.success,
            videos: [createTestVideo('video-1')],
            savedEventIds: const ['video-1'],
            nextPageOffset: 1,
            hasMoreContent: false,
          ),
          act: (bloc) => bloc.add(const ProfileSavedVideosSyncRequested()),
          wait: const Duration(milliseconds: 50),
          verify: (bloc) {
            expect(bloc.state.isRefreshing, isFalse);
            expect(bloc.state.privateBookmarksLocked, isTrue);
          },
        );

        blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
          'flags it on a first load that shows the public saves',
          setUp: () {
            when(
              () => mockBookmarksRepository.bookmarkedVideoReferences,
            ).thenReturn(referencesShownAs(['video-1']));
            when(
              () => mockBookmarksRepository.hasUnreadablePrivateItems,
            ).thenReturn(true);
            when(
              () => mockVideosRepository.getVideosByIds(
                any(),
                cacheResults: any(named: 'cacheResults'),
              ),
            ).thenAnswer((_) async => [createTestVideo('video-1')]);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const ProfileSavedVideosSyncRequested()),
          wait: const Duration(milliseconds: 50),
          verify: (bloc) {
            expect(bloc.state.videos.map((video) => video.id), ['video-1']);
            expect(bloc.state.privateBookmarksLocked, isTrue);
          },
        );

        blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
          'flags it on a re-sync that moves the saves already showing',
          setUp: () {
            when(
              () => mockBookmarksRepository.bookmarkedVideoReferences,
            ).thenReturn(referencesShownAs(['video-2', 'video-1']));
            when(
              () => mockBookmarksRepository.hasUnreadablePrivateItems,
            ).thenReturn(true);
            when(
              () => mockVideosRepository.getVideosByIds(
                any(),
                cacheResults: any(named: 'cacheResults'),
              ),
            ).thenAnswer((_) async => [createTestVideo('video-2')]);
          },
          build: createBloc,
          seed: () => ProfileSavedVideosState(
            status: ProfileSavedVideosStatus.success,
            videos: [createTestVideo('video-1')],
            savedEventIds: const ['video-1'],
            nextPageOffset: 1,
            hasMoreContent: false,
          ),
          act: (bloc) => bloc.add(const ProfileSavedVideosSyncRequested()),
          wait: const Duration(milliseconds: 50),
          verify: (bloc) {
            expect(bloc.state.savedEventIds, ['video-2', 'video-1']);
            expect(bloc.state.privateBookmarksLocked, isTrue);
          },
        );
      });

      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'emits success with empty list when there are no bookmarks',
        setUp: () {
          when(
            () => mockBookmarksRepository.bookmarkedVideoReferences,
          ).thenReturn(const []);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ProfileSavedVideosSyncRequested()),
        wait: const Duration(milliseconds: 50),
        expect: () => [
          const ProfileSavedVideosState(
            status: ProfileSavedVideosStatus.success,
            hasMoreContent: false,
          ),
        ],
      );

      test(
        're-sync of a settled empty tab still settles (pull-to-refresh)',
        () async {
          when(
            () => mockBookmarksRepository.bookmarkedVideoReferences,
          ).thenReturn(const []);
          final bloc = createBloc();
          addTearDown(bloc.close);

          bloc.add(const ProfileSavedVideosSyncRequested());
          await bloc.stream.firstWhere(
            (state) => state.status == ProfileSavedVideosStatus.success,
          );

          // Mirrors how ProfileGridView's RefreshIndicator awaits this tab:
          // it holds the spinner until the bloc reports a settled state.
          final emitted = <ProfileSavedVideosState>[];
          final subscription = bloc.stream.listen(emitted.add);
          addTearDown(subscription.cancel);

          bloc.add(const ProfileSavedVideosSyncRequested());
          final settled = await bloc.stream
              .firstWhere(
                (state) =>
                    !state.isRefreshing &&
                    state.status != ProfileSavedVideosStatus.syncing &&
                    state.status != ProfileSavedVideosStatus.loading,
              )
              .timeout(const Duration(seconds: 1));

          expect(settled.status, ProfileSavedVideosStatus.success);
          expect(settled.videos, isEmpty);
          // The start/end edges are what let the refresh settle — without them
          // the terminal state equals the current one and bloc suppresses it.
          expect(
            emitted.map((state) => (state.status, state.isRefreshing)),
            const [
              (ProfileSavedVideosStatus.success, true),
              (ProfileSavedVideosStatus.success, false),
            ],
          );
        },
      );

      test('shows bookmarks that only exist on the relay', () async {
        // #6627: on a fresh install the SharedPreferences cache is empty, so
        // without the reconcile the tab renders nothing even though the user's
        // kind-10003 list is on the relay.
        when(
          () => mockBookmarksRepository.bookmarkedVideoReferences,
        ).thenReturn(const []);
        when(() => mockBookmarksRepository.syncGlobalBookmarks()).thenAnswer((
          _,
        ) async {
          when(() => mockBookmarksRepository.bookmarkedVideoReferences)
              .thenReturn(const [
                'video-1',
              ]);
          return true;
        });
        when(
          () => mockVideosRepository.getVideosByIds(
            any(),
            cacheResults: any(named: 'cacheResults'),
          ),
        ).thenAnswer((_) async => [createTestVideo('video-1')]);

        final bloc = createBloc();
        addTearDown(bloc.close);
        bloc.add(const ProfileSavedVideosSyncRequested());

        final settled = await bloc.stream
            .firstWhere(
              (state) => state.status == ProfileSavedVideosStatus.success,
            )
            .timeout(const Duration(seconds: 1));

        expect(settled.savedEventIds, equals(['video-1']));
        expect(settled.videos.map((video) => video.id), equals(['video-1']));
      });

      // #7634: syncGlobalBookmarks() returns false when the kind-10003 list
      // could not be reconciled with the relay. An empty list the repository
      // still holds then proves nothing.
      group('when the bookmark list could not be read from the relay', () {
        setUp(() {
          when(
            () => mockBookmarksRepository.syncGlobalBookmarks(),
          ).thenAnswer((_) async => false);
        });

        Future<void> syncAndSettle(ProfileSavedVideosBloc bloc) async {
          final sync = Completer<void>();
          bloc.add(ProfileSavedVideosSyncRequested(completer: sync));
          await sync.future.timeout(const Duration(seconds: 5));
        }

        test('reports a load failure, not an empty list', () async {
          when(
            () => mockBookmarksRepository.bookmarkedVideoReferences,
          ).thenReturn(const []);
          final bloc = createBloc();
          addTearDown(bloc.close);

          await syncAndSettle(bloc);

          expect(bloc.state.status, ProfileSavedVideosStatus.failure);
          expect(bloc.state.error, ProfileSavedVideosError.loadFailed);
          expect(
            await cacheDao.readEntry(snapshotCacheKey),
            isNull,
            reason: 'an unanswered read is not the viewer list to cache',
          );
        });

        test(
          'keeps a settled empty list on a refresh it cannot read',
          () async {
            var synced = true;
            when(
              () => mockBookmarksRepository.syncGlobalBookmarks(),
            ).thenAnswer((_) async => synced);
            when(
              () => mockBookmarksRepository.bookmarkedVideoReferences,
            ).thenReturn(const []);
            final bloc = createBloc();
            addTearDown(bloc.close);
            await syncAndSettle(bloc);
            expect(bloc.state.status, ProfileSavedVideosStatus.success);

            synced = false;
            await syncAndSettle(bloc);

            expect(bloc.state.status, ProfileSavedVideosStatus.success);
            expect(bloc.state.error, isNull);
            expect(bloc.state.isRefreshing, isFalse);
          },
        );

        test('stops refreshing when a failed load fails again', () async {
          when(
            () => mockBookmarksRepository.bookmarkedVideoReferences,
          ).thenReturn(const []);
          final bloc = createBloc();
          addTearDown(bloc.close);
          await syncAndSettle(bloc);
          final emitted = <ProfileSavedVideosState>[];
          final subscription = bloc.stream.listen(emitted.add);
          addTearDown(subscription.cancel);

          await syncAndSettle(bloc);
          await pumpEventQueue();

          expect(emitted.map((state) => state.isRefreshing), [true, false]);
          expect(bloc.state.status, ProfileSavedVideosStatus.failure);
        });

        test(
          'recovers when a later reconciled read finds no bookmarks',
          () async {
            final changes = StreamController<List<String>>.broadcast();
            addTearDown(changes.close);
            when(
              () => mockBookmarksRepository.watchBookmarkedVideoReferences(),
            ).thenAnswer((_) => changes.stream);
            when(
              () => mockBookmarksRepository.bookmarkedVideoReferences,
            ).thenReturn(const []);
            final bloc = createBloc();
            addTearDown(bloc.close);
            await syncAndSettle(bloc);
            expect(bloc.state.status, ProfileSavedVideosStatus.failure);

            // The share sheet's own sync reconciled and found no list.
            changes.add(const []);
            await pumpEventQueue();

            expect(bloc.state.status, ProfileSavedVideosStatus.success);
            expect(bloc.state.error, isNull);
            expect(bloc.state.savedEventIds, isEmpty);
          },
        );

        test('keeps the saved videos already on screen', () async {
          await cacheDao.write(
            key: snapshotCacheKey,
            payload: ProfileVideoListSnapshot(
              videos: [createTestVideo('video-1')],
              itemIds: const ['video-1'],
              nextPageOffset: 1,
              hasMoreContent: false,
            ).toJson(),
          );
          when(
            () => mockBookmarksRepository.bookmarkedVideoReferences,
          ).thenReturn(const []);
          final bloc = createBloc();
          addTearDown(bloc.close);

          await syncAndSettle(bloc);

          expect(bloc.state.status, ProfileSavedVideosStatus.success);
          expect(bloc.state.videos.map((video) => video.id), ['video-1']);
          expect(bloc.state.savedEventIds, ['video-1']);
          expect(bloc.state.isRefreshing, isFalse);
          final persisted = await cacheDao.readEntry(snapshotCacheKey);
          expect(
            ProfileVideoListSnapshot.fromJson(persisted!.payload).itemIds,
            ['video-1'],
          );
        });

        test('shows the bookmarks this device already holds', () async {
          // The documented #6966 fallback: a failed read still shows the
          // list this device kept rather than nothing.
          when(
            () => mockBookmarksRepository.bookmarkedVideoReferences,
          ).thenReturn(const ['video-1']);
          when(
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          ).thenAnswer((_) async => [createTestVideo('video-1')]);
          final bloc = createBloc();
          addTearDown(bloc.close);

          await syncAndSettle(bloc);

          expect(bloc.state.status, ProfileSavedVideosStatus.success);
          expect(bloc.state.savedEventIds, ['video-1']);
          expect(bloc.state.videos.map((video) => video.id), ['video-1']);
        });
      });

      // The same #7634 path through the real repository, so the test fails if
      // the repository's own "inconclusive is false" contract drifts.
      group('over a real $BookmarksRepository', () {
        late _MockNostrClient nostrClient;
        late BookmarksRepository repository;
        final savedVideoId = 'b' * 64;

        setUpAll(() => registerFallbackValue(<Filter>[]));

        setUp(() async {
          SharedPreferences.setMockInitialValues(<String, Object>{});
          nostrClient = _MockNostrClient();
          final signer = _MockBookmarkSigner();
          when(() => signer.isAuthenticated).thenReturn(true);
          when(() => signer.currentPublicKeyHex).thenReturn(currentUserPubkey);
          repository = BookmarksRepository(
            nostrClient: nostrClient,
            signer: signer,
            prefs: await SharedPreferences.getInstance(),
          );
          addTearDown(repository.dispose);
          when(
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          ).thenAnswer((_) async => [createTestVideo(savedVideoId)]);
        });

        /// The relay holds a kind-10003 saving [savedVideoId]; [timedOut]
        /// says whether the read of it ran out of time.
        void stubRelayHoldingTheList({required bool timedOut}) {
          final list = Event(
            currentUserPubkey,
            BookmarksRepository.globalBookmarksKind,
            [
              ['e', savedVideoId],
            ],
            '',
          );
          when(
            () => nostrClient.queryEventsDetailed(
              any(),
              useCache: any(named: 'useCache'),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).thenAnswer(
            (_) async => (events: [list], timedOut: timedOut, noRelays: false),
          );
        }

        ProfileSavedVideosBloc createRealRepositoryBloc() =>
            ProfileSavedVideosBloc(
              bookmarksRepository: repository,
              videosRepository: mockVideosRepository,
              currentUserPubkey: currentUserPubkey,
              removedVideoIds: const Stream<String>.empty(),
              deletedVideoFilter: (_) => false,
            );

        test('shows the list when the relay finishes the read', () async {
          stubRelayHoldingTheList(timedOut: false);
          final bloc = createRealRepositoryBloc();
          addTearDown(bloc.close);

          final sync = Completer<void>();
          bloc.add(ProfileSavedVideosSyncRequested(completer: sync));
          await sync.future.timeout(const Duration(seconds: 5));

          expect(bloc.state.status, ProfileSavedVideosStatus.success);
          expect(bloc.state.savedEventIds, [savedVideoId]);
          expect(bloc.state.videos.map((video) => video.id), [savedVideoId]);
        });

        test(
          'reports a load failure when the read of that list times out',
          () async {
            stubRelayHoldingTheList(timedOut: true);
            final bloc = createRealRepositoryBloc();
            addTearDown(bloc.close);

            final sync = Completer<void>();
            bloc.add(ProfileSavedVideosSyncRequested(completer: sync));
            await sync.future.timeout(const Duration(seconds: 5));

            expect(bloc.state.status, ProfileSavedVideosStatus.failure);
            expect(bloc.state.savedEventIds, isEmpty);
          },
        );
      });

      // #11181 and #11180: a list with NIP-51 private items, read through the
      // real repository and real NIP-44 crypto across two app launches.
      group('over a real $BookmarksRepository with private bookmarks', () {
        late String viewer;
        late LocalNostrSigner identity;
        late _MockBookmarkSigner signer;
        late _MockNostrClient nostrClient;
        late SharedPreferences prefs;
        final publicVideoId = 'c' * 64;
        final privateVideoId = 'd' * 64;

        /// One event per list shape, so every read of a test sees the same
        /// revision rather than a re-encrypted one that ties on `created_at`.
        final lists = <bool, Event>{};

        setUpAll(() => registerFallbackValue(<Filter>[]));

        setUp(() async {
          final privateKey = generatePrivateKey();
          viewer = getPublicKey(privateKey);
          identity = LocalNostrSigner(privateKey);
          lists.clear();
          signer = _MockBookmarkSigner();
          when(() => signer.isAuthenticated).thenReturn(true);
          when(() => signer.currentPublicKeyHex).thenReturn(viewer);
          when(() => signer.currentIdentity).thenReturn(identity);
          nostrClient = _MockNostrClient();
          SharedPreferences.setMockInitialValues(<String, Object>{});
          prefs = await SharedPreferences.getInstance();
          when(
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          ).thenAnswer(
            (invocation) async => [
              for (final id
                  in invocation.positionalArguments.first as List<String>)
                createTestVideo(id),
            ],
          );
        });

        /// The relay's answer to the kind-10003 read: [onlyPrivate] drops the
        /// public item, and [timedOut] says the read ran out of time.
        Future<void> stubRelay({
          bool timedOut = false,
          bool onlyPrivate = false,
        }) async {
          final list = lists[onlyPrivate] ??= Event(
            viewer,
            BookmarksRepository.globalBookmarksKind,
            [
              if (!onlyPrivate) ['e', publicVideoId],
            ],
            (await identity.nip44Encrypt(
              viewer,
              jsonEncode([
                ['e', privateVideoId],
              ]),
            ))!,
          );
          when(
            () => nostrClient.queryEventsDetailed(
              any(),
              useCache: any(named: 'useCache'),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).thenAnswer(
            (_) async => (events: [list], timedOut: timedOut, noRelays: false),
          );
        }

        Future<void> sync(ProfileSavedVideosBloc bloc) async {
          final done = Completer<void>();
          bloc.add(ProfileSavedVideosSyncRequested(completer: done));
          await done.future.timeout(const Duration(seconds: 5));
        }

        /// One app launch: a new repository over the device's preferences
        /// and a new bloc over it, synced once.
        Future<(BookmarksRepository, ProfileSavedVideosBloc)> launch() async {
          final repository = BookmarksRepository(
            nostrClient: nostrClient,
            signer: signer,
            prefs: prefs,
          );
          addTearDown(repository.dispose);
          final bloc = ProfileSavedVideosBloc(
            bookmarksRepository: repository,
            videosRepository: mockVideosRepository,
            currentUserPubkey: viewer,
            removedVideoIds: const Stream<String>.empty(),
            deletedVideoFilter: (_) => false,
          );
          addTearDown(bloc.close);
          await sync(bloc);
          return (repository, bloc);
        }

        /// The first launch reads the list, then the app is closed.
        Future<void> readListOnFirstLaunch({bool onlyPrivate = false}) async {
          await stubRelay(onlyPrivate: onlyPrivate);
          final (repository, bloc) = await launch();
          expect(
            bloc.state.videos.map((video) => video.id),
            contains(privateVideoId),
          );
          await bloc.close();
          repository.dispose();
        }

        Iterable<String> shownIds(ProfileSavedVideosBloc bloc) =>
            bloc.state.videos.map((video) => video.id);

        test(
          'keeps a private save on screen when a later launch cannot read '
          'the list',
          () async {
            await readListOnFirstLaunch();
            await stubRelay(timedOut: true);

            final (_, bloc) = await launch();

            expect(shownIds(bloc), [privateVideoId, publicVideoId]);
            expect(bloc.state.privateBookmarksLocked, isFalse);
          },
        );

        test(
          'says some saves may be missing when the kept private items cannot '
          'be decrypted',
          () async {
            await readListOnFirstLaunch();
            await stubRelay(timedOut: true);
            final broken = _MockNostrSigner();
            when(
              () => broken.nip44Decrypt(any(), any()),
            ).thenAnswer((_) async => null);
            when(() => signer.currentIdentity).thenReturn(broken);

            final (_, bloc) = await launch();

            expect(bloc.state.privateBookmarksLocked, isTrue);
            expect(shownIds(bloc), [publicVideoId]);
          },
        );

        test(
          'says some saves may be missing when the later launch reads a list '
          'it cannot decrypt',
          () async {
            await readListOnFirstLaunch();
            final broken = _MockNostrSigner();
            when(
              () => broken.nip44Decrypt(any(), any()),
            ).thenAnswer((_) async => null);
            when(() => signer.currentIdentity).thenReturn(broken);

            final (_, bloc) = await launch();

            expect(bloc.state.privateBookmarksLocked, isTrue);
          },
        );

        test(
          'shows the private save when the later launch reads the list',
          () async {
            await readListOnFirstLaunch();

            final (_, bloc) = await launch();

            expect(shownIds(bloc), [privateVideoId, publicVideoId]);
          },
        );

        test(
          'brings a private save back on the next read that finishes',
          () async {
            await readListOnFirstLaunch();
            await stubRelay(timedOut: true);
            final (_, bloc) = await launch();

            await stubRelay();
            await sync(bloc);

            expect(shownIds(bloc), [privateVideoId, publicVideoId]);
          },
        );

        test(
          'keeps a private-only list on screen when a later launch cannot '
          'read it',
          () async {
            await readListOnFirstLaunch(onlyPrivate: true);
            await stubRelay(timedOut: true, onlyPrivate: true);

            final (_, bloc) = await launch();

            expect(shownIds(bloc), [privateVideoId]);
          },
        );
      });

      test('a sync arriving during the snapshot write still runs', () async {
        when(
          () => mockBookmarksRepository.bookmarkedVideoReferences,
        ).thenReturn(const []);
        final bloc = createBloc();
        addTearDown(bloc.close);

        // Park the first sync in its post-emit snapshot write — the window in
        // which the tab already looks settled but the handler is still busy.
        final writeGate = Completer<void>();
        cacheDao.writeGate = writeGate;
        final firstSync = Completer<void>();
        bloc.add(ProfileSavedVideosSyncRequested(completer: firstSync));
        await bloc.stream.firstWhere(
          (state) => state.status == ProfileSavedVideosStatus.success,
        );
        expect(firstSync.isCompleted, isFalse);

        // A pull landing in that window used to be discarded outright, leaving
        // the RefreshIndicator with nothing left to wait for.
        final secondSync = Completer<void>();
        bloc.add(ProfileSavedVideosSyncRequested(completer: secondSync));
        writeGate.complete();

        await Future.wait([firstSync.future, secondSync.future]).timeout(
          const Duration(seconds: 1),
          onTimeout: () => fail(
            'a sync dispatched during the snapshot write never completed — '
            'pull-to-refresh would spin forever',
          ),
        );
      });

      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'shows a stale snapshot while revalidating',
        setUp: () async {
          await cacheDao.write(
            key: snapshotCacheKey,
            payload: ProfileVideoListSnapshot(
              videos: [createTestVideo('video-1'), createTestVideo('video-2')],
              itemIds: const ['video-1', 'video-2'],
              nextPageOffset: 2,
              hasMoreContent: false,
            ).toJson(),
          );
          cacheDao.staleKeys.add(snapshotCacheKey);
          when(
            () => mockBookmarksRepository.bookmarkedVideoReferences,
          ).thenReturn(referencesShownAs(['video-1', 'video-2']));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ProfileSavedVideosSyncRequested()),
        wait: const Duration(milliseconds: 50),
        expect: () => [
          isA<ProfileSavedVideosState>()
              .having((s) => s.isRefreshing, 'isRefreshing', true)
              .having(
                (s) => s.videos.map((v) => v.id).toList(),
                'stale videos',
                ['video-1', 'video-2'],
              ),
          isA<ProfileSavedVideosState>().having(
            (s) => s.isRefreshing,
            'isRefreshing',
            false,
          ),
        ],
        verify: (_) {
          verify(() => mockBookmarksRepository.bookmarkedVideoReferences)
              .called(
                greaterThan(0),
              );
        },
      );

      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'reopen restores the cached list, then flips the bar off when '
        'bookmarks are unchanged',
        setUp: () async {
          await cacheDao.write(
            key: snapshotCacheKey,
            payload: ProfileVideoListSnapshot(
              videos: [createTestVideo('video-1'), createTestVideo('video-2')],
              itemIds: const ['video-1', 'video-2'],
              nextPageOffset: 2,
              hasMoreContent: false,
            ).toJson(),
          );
          when(
            () => mockBookmarksRepository.bookmarkedVideoReferences,
          ).thenReturn(referencesShownAs(['video-1', 'video-2']));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ProfileSavedVideosSyncRequested()),
        wait: const Duration(milliseconds: 50),
        expect: () => [
          isA<ProfileSavedVideosState>()
              .having((s) => s.isRefreshing, 'isRefreshing', true)
              .having((s) => s.videos.length, 'cached videos', 2),
          isA<ProfileSavedVideosState>()
              .having((s) => s.isRefreshing, 'isRefreshing', false)
              .having((s) => s.videos.length, 'unchanged videos', 2),
        ],
        verify: (_) {
          verifyNever(
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          );
        },
      );

      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'filters tombstoned videos from cached snapshot restore',
        setUp: () async {
          await cacheDao.write(
            key: snapshotCacheKey,
            payload: ProfileVideoListSnapshot(
              videos: [
                createTestVideo('video-1'),
                createTestVideo('deleted-video'),
              ],
              itemIds: const ['video-1', 'deleted-video'],
              nextPageOffset: 2,
              hasMoreContent: false,
            ).toJson(),
          );
          when(
            () => mockBookmarksRepository.bookmarkedVideoReferences,
          ).thenReturn(const ['video-1']);
        },
        build: () => createBloc(
          deletedVideoFilter: (video) => video.id == 'deleted-video',
        ),
        act: (bloc) => bloc.add(const ProfileSavedVideosSyncRequested()),
        wait: const Duration(milliseconds: 50),
        expect: () => [
          isA<ProfileSavedVideosState>()
              .having((s) => s.isRefreshing, 'isRefreshing', true)
              .having(
                (s) => s.videos.map((v) => v.id).toList(),
                'cached videos',
                ['video-1'],
              )
              .having((s) => s.savedEventIds, 'savedEventIds', ['video-1']),
          isA<ProfileSavedVideosState>()
              .having((s) => s.isRefreshing, 'isRefreshing', false)
              .having(
                (s) => s.videos.map((v) => v.id).toList(),
                'unchanged videos',
                ['video-1'],
              ),
        ],
      );

      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'reconcile that resolves nothing reports the bookmarks as unresolved',
        // #7587 on the warm path: the previously-shown videos have all been
        // unbookmarked, so none of them is in the reconcile window. They are
        // no evidence that the window resolved, and counting them as such
        // would send the tab back to "Nothing saved yet".
        setUp: () async {
          await cacheDao.write(
            key: snapshotCacheKey,
            payload: ProfileVideoListSnapshot(
              videos: [createTestVideo('video-1')],
              itemIds: const ['video-1'],
              nextPageOffset: 1,
              hasMoreContent: false,
            ).toJson(),
          );
          when(() => mockBookmarksRepository.bookmarkedVideoReferences)
              .thenReturn(const [
                'video-2',
              ]);
          when(
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          ).thenAnswer((_) async => []);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ProfileSavedVideosSyncRequested()),
        wait: const Duration(milliseconds: 50),
        skip: 1,
        expect: () => [
          isA<ProfileSavedVideosState>()
              .having((s) => s.videos, 'videos', isEmpty)
              .having((s) => s.savedEventIds, 'savedEventIds', ['video-2'])
              .having((s) => s.hasUnresolvedSaves, 'hasUnresolvedSaves', true),
        ],
      );

      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'removal event drops video and persists snapshot without it',
        build: () => createBloc(
          deletedVideoFilter: (video) => video.id == 'deleted-video',
        ),
        seed: () => ProfileSavedVideosState(
          status: ProfileSavedVideosStatus.success,
          videos: [
            createTestVideo('video-1'),
            createTestVideo('deleted-video'),
          ],
          savedEventIds: const ['video-1', 'deleted-video'],
          nextPageOffset: 2,
          hasMoreContent: false,
        ),
        act: (bloc) =>
            bloc.add(const ProfileSavedVideosVideoRemoved('deleted-video')),
        wait: const Duration(milliseconds: 50),
        expect: () => [
          isA<ProfileSavedVideosState>()
              .having((s) => s.videos.map((v) => v.id).toList(), 'videos', [
                'video-1',
              ])
              .having((s) => s.savedEventIds, 'savedEventIds', ['video-1'])
              .having((s) => s.nextPageOffset, 'nextPageOffset', 1),
        ],
        verify: (_) async {
          final cached = await CacheSync.read<ProfileVideoListSnapshot>(
            key: snapshotCacheKey,
            fromJson: ProfileVideoListSnapshot.fromJson,
          );
          expect(cached, isNotNull);
          expect(cached!.videos.map((v) => v.id), ['video-1']);
          expect(cached.itemIds, ['video-1']);
        },
      );

      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'removal shifts nextPageOffset left when deleting before the cursor',
        build: () => createBloc(
          deletedVideoFilter: (video) => video.id == 'deleted-video',
        ),
        seed: () => ProfileSavedVideosState(
          status: ProfileSavedVideosStatus.success,
          videos: [
            createTestVideo('video-1'),
            createTestVideo('deleted-video'),
          ],
          savedEventIds: const ['video-1', 'deleted-video', 'video-2'],
          nextPageOffset: 2,
        ),
        act: (bloc) =>
            bloc.add(const ProfileSavedVideosVideoRemoved('deleted-video')),
        wait: const Duration(milliseconds: 50),
        expect: () => [
          isA<ProfileSavedVideosState>()
              .having((s) => s.videos.map((v) => v.id).toList(), 'videos', [
                'video-1',
              ])
              .having((s) => s.savedEventIds, 'savedEventIds', [
                'video-1',
                'video-2',
              ])
              .having((s) => s.nextPageOffset, 'nextPageOffset', 1),
        ],
      );

      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'removal drops IDs for videos removed only by the deletion filter',
        build: () => createBloc(
          deletedVideoFilter: (video) => video.id == 'edited-video',
        ),
        seed: () => ProfileSavedVideosState(
          status: ProfileSavedVideosStatus.success,
          videos: [createTestVideo('video-1'), createTestVideo('edited-video')],
          savedEventIds: const ['video-1', 'edited-video', 'video-2'],
          nextPageOffset: 2,
        ),
        act: (bloc) =>
            bloc.add(const ProfileSavedVideosVideoRemoved('original-video')),
        wait: const Duration(milliseconds: 50),
        expect: () => [
          isA<ProfileSavedVideosState>()
              .having((s) => s.videos.map((v) => v.id).toList(), 'videos', [
                'video-1',
              ])
              .having((s) => s.savedEventIds, 'savedEventIds', [
                'video-1',
                'video-2',
              ])
              .having((s) => s.nextPageOffset, 'nextPageOffset', 1),
        ],
      );

      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'removal prunes unloaded IDs from the backing list',
        build: createBloc,
        seed: () => ProfileSavedVideosState(
          status: ProfileSavedVideosStatus.success,
          videos: [createTestVideo('video-1')],
          savedEventIds: const ['video-1', 'deleted-unloaded', 'video-2'],
          nextPageOffset: 2,
        ),
        act: (bloc) =>
            bloc.add(const ProfileSavedVideosVideoRemoved('deleted-unloaded')),
        wait: const Duration(milliseconds: 50),
        expect: () => [
          isA<ProfileSavedVideosState>()
              .having((s) => s.videos.map((v) => v.id).toList(), 'videos', [
                'video-1',
              ])
              .having((s) => s.savedEventIds, 'savedEventIds', [
                'video-1',
                'video-2',
              ])
              .having((s) => s.nextPageOffset, 'nextPageOffset', 1),
        ],
      );

      // The repository never stores private items because local storage is
      // unencrypted, and the snapshot lives in the unencrypted cache_sync.db
      // (#11180). A real repository decrypts a genuine NIP-44 private section.
      group('with private bookmarks on the list', () {
        late _MockNostrClient nostrClient;
        late BookmarksRepository repository;
        late String ownerPubkey;
        late LocalNostrSigner identity;
        final privateVideoId = 'c' * 64;
        final publicVideoId = 'd' * 64;

        setUpAll(() => registerFallbackValue(<Filter>[]));

        setUp(() async {
          SharedPreferences.setMockInitialValues(<String, Object>{});
          final privateKeyHex = generatePrivateKey();
          ownerPubkey = getPublicKey(privateKeyHex);
          identity = LocalNostrSigner(privateKeyHex);
          nostrClient = _MockNostrClient();
          final signer = _MockBookmarkSigner();
          when(() => signer.isAuthenticated).thenReturn(true);
          when(() => signer.currentPublicKeyHex).thenReturn(ownerPubkey);
          when(() => signer.currentIdentity).thenReturn(identity);
          repository = BookmarksRepository(
            nostrClient: nostrClient,
            signer: signer,
            prefs: await SharedPreferences.getInstance(),
          );
          addTearDown(repository.dispose);
          when(
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          ).thenAnswer((invocation) async {
            final ids = invocation.positionalArguments.first as List<String>;
            return ids.map(createTestVideo).toList();
          });
        });

        /// The relay holds a kind-10003 with [publicIds] in `tags` and
        /// [privateIds] NIP-44 encrypted to the owner in `content`.
        Future<void> stubRelayHoldingTheList({
          required List<String> privateIds,
          List<String> publicIds = const [],
        }) async {
          final content = await identity.nip44Encrypt(
            ownerPubkey,
            jsonEncode([
              for (final id in privateIds) ['e', id],
            ]),
          );
          final list = Event(
            ownerPubkey,
            BookmarksRepository.globalBookmarksKind,
            [
              for (final id in publicIds) ['e', id],
            ],
            content!,
          );
          when(
            () => nostrClient.queryEventsDetailed(
              any(),
              useCache: any(named: 'useCache'),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).thenAnswer(
            (_) async => (events: [list], timedOut: false, noRelays: false),
          );
        }

        Future<ProfileSavedVideosBloc> syncedBloc() async {
          final bloc = ProfileSavedVideosBloc(
            bookmarksRepository: repository,
            videosRepository: mockVideosRepository,
            currentUserPubkey: currentUserPubkey,
            removedVideoIds: const Stream<String>.empty(),
            deletedVideoFilter: (_) => false,
          );
          addTearDown(bloc.close);
          final sync = Completer<void>();
          bloc.add(ProfileSavedVideosSyncRequested(completer: sync));
          await sync.future.timeout(const Duration(seconds: 5));
          return bloc;
        }

        test('keeps a private-only list out of the snapshot', () async {
          await stubRelayHoldingTheList(privateIds: [privateVideoId]);

          final bloc = await syncedBloc();

          // The private save is read and shown: the snapshot check below is
          // about storage, not about a list that never decrypted.
          expect(bloc.state.savedEventIds, [privateVideoId]);
          expect(bloc.state.videos.map((v) => v.id), [privateVideoId]);
          final persisted = await cacheDao.readEntry(snapshotCacheKey);
          expect(persisted, isNotNull);
          expect(persisted!.payload, isNot(contains(privateVideoId)));
        });

        test(
          'keeps the public saves of a mixed list in the snapshot',
          () async {
            await stubRelayHoldingTheList(
              publicIds: [publicVideoId],
              privateIds: [privateVideoId],
            );

            final bloc = await syncedBloc();

            expect(
              bloc.state.videos.map((v) => v.id),
              unorderedEquals([privateVideoId, publicVideoId]),
            );
            final persisted = await cacheDao.readEntry(snapshotCacheKey);
            expect(persisted!.payload, contains(publicVideoId));
            expect(persisted.payload, isNot(contains(privateVideoId)));
          },
        );

        // Every earlier key could hold private bookmarks, and a new key only
        // stopped reading the old row; nothing deleted it.
        test('deletes the snapshots earlier versions wrote', () async {
          await stubRelayHoldingTheList(privateIds: [privateVideoId]);
          final legacyKeys = [
            '$currentUserPubkey:profile_saved_videos',
            '$currentUserPubkey:profile_saved_videos_v2',
            '$currentUserPubkey:profile_saved_videos_v3',
          ];
          final otherAccountsKey = '${'f' * 64}:profile_saved_videos_v3';
          for (final key in [...legacyKeys, otherAccountsKey]) {
            await cacheDao.write(key: key, payload: '"$privateVideoId"');
          }
          for (final key in legacyKeys) {
            expect(await cacheDao.readEntry(key), isNotNull);
          }

          await syncedBloc();

          for (final key in legacyKeys) {
            expect(await cacheDao.readEntry(key), isNull, reason: key);
          }
          expect(await cacheDao.readEntry(otherAccountsKey), isNotNull);
        });
      });

      group('when a video saved by its address is removed', () {
        late StreamController<String> removals;

        setUp(() {
          removals = StreamController<String>.broadcast();
          addTearDown(removals.close);
        });

        blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
          'prunes the address from the saved references',
          build: () => createBloc(removedVideoIds: removals.stream),
          seed: () => ProfileSavedVideosState(
            status: ProfileSavedVideosStatus.success,
            videos: [
              createTestVideo(editedRevisionId, addressableDTag: 'clip'),
              createTestVideo('a' * 64),
            ],
            savedEventIds: [coordinateFor('clip'), 'a' * 64],
            nextPageOffset: 2,
            hasMoreContent: false,
          ),
          // The deletion bus reports the event id of the revision on screen.
          act: (_) => removals.add(editedRevisionId),
          wait: const Duration(milliseconds: 50),
          expect: () => [
            isA<ProfileSavedVideosState>()
                .having((s) => s.videos.map((v) => v.id), 'videos', ['a' * 64])
                .having((s) => s.savedEventIds, 'savedEventIds', ['a' * 64])
                .having((s) => s.nextPageOffset, 'nextPageOffset', 1),
          ],
        );
      });

      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'grows a persisted window shorter than a page even when the bookmark '
        'list is unchanged',
        setUp: () async {
          final ids = List.generate(
            ProfileTabPagination.pageSize + 14,
            (i) => 'video-$i',
          );
          await cacheDao.write(
            key: snapshotCacheKey,
            payload: ProfileVideoListSnapshot(
              videos: ids.take(6).map(createTestVideo).toList(),
              itemIds: ids,
              nextPageOffset: 6,
              hasMoreContent: true,
            ).toJson(),
          );
          when(
            () => mockBookmarksRepository.bookmarkedVideoReferences,
          ).thenReturn(referencesShownAs(ids));
          when(
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          ).thenAnswer(
            (invocation) async =>
                (invocation.positionalArguments[0] as List<String>)
                    .map(createTestVideo)
                    .toList(),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ProfileSavedVideosSyncRequested()),
        wait: const Duration(milliseconds: 50),
        expect: () => [
          isA<ProfileSavedVideosState>().having(
            (s) => s.videos.length,
            'short cached window served first',
            6,
          ),
          isA<ProfileSavedVideosState>()
              .having(
                (s) => s.videos.length,
                'grown to a full page',
                ProfileTabPagination.pageSize,
              )
              .having(
                (s) => s.nextPageOffset,
                'nextPageOffset',
                ProfileTabPagination.pageSize,
              )
              .having((s) => s.hasMoreContent, 'hasMoreContent', true),
        ],
      );

      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'stays on the fast path for a sub-page window whose IDs are all '
        'consumed',
        setUp: () async {
          // 6 bookmark IDs consumed, only 5 resolved to a video. The window
          // is under a page with nothing left to top it up with, so
          // revalidation must not re-enter reconcile. See
          // ProfileLikedVideosBloc's sibling test for the loop this pins.
          final ids = List.generate(6, (i) => 'video-$i');
          await cacheDao.write(
            key: snapshotCacheKey,
            payload: ProfileVideoListSnapshot(
              videos: ids
                  .where((id) => id != 'video-3')
                  .map(createTestVideo)
                  .toList(),
              itemIds: ids,
              nextPageOffset: 6,
              hasMoreContent: false,
            ).toJson(),
          );
          when(
            () => mockBookmarksRepository.bookmarkedVideoReferences,
          ).thenReturn(referencesShownAs(ids));
          when(
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          ).thenAnswer(
            (invocation) async =>
                (invocation.positionalArguments[0] as List<String>)
                    .where((id) => id != 'video-3')
                    .map(createTestVideo)
                    .toList(),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ProfileSavedVideosSyncRequested()),
        wait: const Duration(milliseconds: 50),
        expect: () => [
          isA<ProfileSavedVideosState>()
              .having((s) => s.videos.length, 'cached videos', 5)
              .having((s) => s.isRefreshing, 'isRefreshing', true),
          isA<ProfileSavedVideosState>()
              .having((s) => s.videos.length, 'unchanged videos', 5)
              .having((s) => s.nextPageOffset, 'nextPageOffset', 6)
              .having((s) => s.isRefreshing, 'isRefreshing', false),
        ],
        verify: (_) {
          verifyNever(
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          );
        },
      );

      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'lists the most recent bookmark first',
        setUp: () {
          // The repository lists bookmarks oldest first.
          when(
            () => mockBookmarksRepository.bookmarkedVideoReferences,
          ).thenReturn(const ['video-1', 'video-2']);
          when(
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          ).thenAnswer(
            (invocation) async =>
                (invocation.positionalArguments.first as List<String>)
                    .map(createTestVideo)
                    .toList(),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ProfileSavedVideosSyncRequested()),
        verify: (bloc) {
          expect(bloc.state.status, ProfileSavedVideosStatus.success);
          expect(bloc.state.videos.map((v) => v.id), ['video-2', 'video-1']);
          expect(bloc.state.savedEventIds, equals(['video-2', 'video-1']));
          expect(bloc.state.hasMoreContent, isFalse);
          verify(
            () => mockVideosRepository.getVideosByIds([
              'video-2',
              'video-1',
            ], cacheResults: true),
          ).called(1);
        },
      );

      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'emits failure when fetching videos throws',
        setUp: () {
          when(
            () => mockBookmarksRepository.bookmarkedVideoReferences,
          ).thenReturn(const ['video-1']);
          when(
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          ).thenThrow(Exception('relay error'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ProfileSavedVideosSyncRequested()),
        verify: (bloc) {
          expect(bloc.state.status, ProfileSavedVideosStatus.failure);
          expect(bloc.state.error, ProfileSavedVideosError.loadFailed);
        },
        errors: () => [isA<Exception>()],
      );

      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'shows the latest revision of a video saved by its address',
        setUp: () {
          when(
            () => mockBookmarksRepository.bookmarkedVideoReferences,
          ).thenReturn([coordinateFor('clip')]);
          stubLatestRevisionAtClipAddress();
          stubVideosByEventId();
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ProfileSavedVideosSyncRequested()),
        verify: (bloc) {
          expect(bloc.state.videos.map((v) => v.id), [editedRevisionId]);
          expect(bloc.state.savedEventIds, [coordinateFor('clip')]);
          verify(
            () => mockVideosRepository.getVideosByAddressableIds([
              coordinateFor('clip'),
            ], cacheResults: true),
          ).called(1);
          verifyNever(
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          );
        },
      );

      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'keeps newest-first order across address and event-id bookmarks',
        setUp: () {
          when(() => mockBookmarksRepository.bookmarkedVideoReferences)
              .thenReturn([
                'a' * 64,
                coordinateFor('clip'),
                'b' * 64,
              ]);
          stubLatestRevisionAtClipAddress();
          stubVideosByEventId();
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ProfileSavedVideosSyncRequested()),
        verify: (bloc) {
          expect(bloc.state.videos.map((v) => v.id), [
            'b' * 64,
            editedRevisionId,
            'a' * 64,
          ]);
          expect(bloc.state.savedEventIds, [
            'b' * 64,
            coordinateFor('clip'),
            'a' * 64,
          ]);
        },
      );

      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'shows one tile for a video saved by both its event id and its '
        'address',
        // An `e` bookmark the repository could not match to its address sits
        // beside an `a` bookmark of the same video. Both resolve.
        setUp: () {
          when(
            () => mockBookmarksRepository.bookmarkedVideoReferences,
          ).thenReturn([originalRevisionId, coordinateFor('clip')]);
          stubLatestRevisionAtClipAddress();
          stubVideosByEventId();
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ProfileSavedVideosSyncRequested()),
        verify: (bloc) {
          expect(bloc.state.videos.map((v) => v.id), [editedRevisionId]);
          expect(bloc.state.savedEventIds, [
            coordinateFor('clip'),
            originalRevisionId,
          ]);
        },
      );

      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'does not restore a snapshot saved under the event-id-only key',
        // A v2 snapshot keys its videos by event id, so restoring it would
        // show the pre-edit revision until the reconcile replaced it.
        setUp: () async {
          await cacheDao.write(
            key: '$currentUserPubkey:profile_saved_videos_v2',
            payload: ProfileVideoListSnapshot(
              videos: [
                createTestVideo(originalRevisionId, addressableDTag: 'clip'),
              ],
              itemIds: [originalRevisionId],
              nextPageOffset: 1,
              hasMoreContent: false,
            ).toJson(),
          );
          when(
            () => mockBookmarksRepository.bookmarkedVideoReferences,
          ).thenReturn([coordinateFor('clip')]);
          stubLatestRevisionAtClipAddress();
          stubVideosByEventId();
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ProfileSavedVideosSyncRequested()),
        wait: const Duration(milliseconds: 50),
        expect: () => [
          isA<ProfileSavedVideosState>()
              .having((s) => s.videos.map((v) => v.id), 'videos', [
                editedRevisionId,
              ])
              .having((s) => s.isRefreshing, 'isRefreshing', false),
        ],
      );

      group('revalidating an unchanged bookmark list', () {
        /// Persists a snapshot showing the original revision of the `clip`
        /// video, saved by its address.
        Future<void> persistOriginalRevisionAtClipAddress() => cacheDao.write(
          key: snapshotCacheKey,
          payload: ProfileVideoListSnapshot(
            videos: [
              createTestVideo(originalRevisionId, addressableDTag: 'clip'),
            ],
            itemIds: [coordinateFor('clip')],
            nextPageOffset: 1,
            hasMoreContent: false,
          ).toJson(),
        );

        Future<ProfileSavedVideosBloc> syncedBloc() async {
          final bloc = createBloc();
          addTearDown(bloc.close);
          final sync = Completer<void>();
          bloc.add(ProfileSavedVideosSyncRequested(completer: sync));
          await sync.future;
          return bloc;
        }

        test('shows an address edited since the snapshot at its latest '
            'revision', () async {
          await persistOriginalRevisionAtClipAddress();
          when(
            () => mockBookmarksRepository.bookmarkedVideoReferences,
          ).thenReturn([coordinateFor('clip')]);
          stubLatestRevisionAtClipAddress();

          final bloc = await syncedBloc();

          expect(bloc.state.videos.map((v) => v.id), [editedRevisionId]);
          expect(bloc.state.isRefreshing, isFalse);
          final persisted = ProfileVideoListSnapshot.fromJson(
            (await cacheDao.readEntry(snapshotCacheKey))!.payload,
          );
          expect(persisted.videos.map((v) => v.id), [editedRevisionId]);
          expect(persisted.itemIds, [coordinateFor('clip')]);
        });

        test('keeps the tile when its address comes back empty', () async {
          await persistOriginalRevisionAtClipAddress();
          when(
            () => mockBookmarksRepository.bookmarkedVideoReferences,
          ).thenReturn([coordinateFor('clip')]);
          when(
            () => mockVideosRepository.getVideosByAddressableIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          ).thenAnswer((_) async => []);

          final bloc = await syncedBloc();

          verify(
            () => mockVideosRepository.getVideosByAddressableIds([
              coordinateFor('clip'),
            ], cacheResults: true),
          ).called(1);
          expect(bloc.state.videos.map((v) => v.id), [originalRevisionId]);
          expect(bloc.state.isRefreshing, isFalse);
        });

        test('makes no request for a full window of event ids', () async {
          // One id never resolved, so anything but the fast path would ask
          // for it again. An event id cannot be edited.
          final ids = List.generate(
            ProfileTabPagination.pageSize,
            (i) => i.toRadixString(16).padLeft(64, 'e'),
          );
          final unresolvedId = ids[3];
          await cacheDao.write(
            key: snapshotCacheKey,
            payload: ProfileVideoListSnapshot(
              videos: [
                for (final id in ids)
                  if (id != unresolvedId) createTestVideo(id),
              ],
              itemIds: ids,
              nextPageOffset: ids.length,
              hasMoreContent: false,
            ).toJson(),
          );
          when(
            () => mockBookmarksRepository.bookmarkedVideoReferences,
          ).thenReturn(referencesShownAs(ids));

          final bloc = await syncedBloc();

          expect(bloc.state.videos, hasLength(ids.length - 1));
          expect(bloc.state.isRefreshing, isFalse);
          verifyNever(
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          );
          verifyNever(
            () => mockVideosRepository.getVideosByAddressableIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          );
        });

        // Another client can move a save into the private section without
        // moving it in the list, so no video id changes (#11180).
        test('drops a save that turned private from the snapshot', () async {
          const ids = ['video-1', 'video-2'];
          // Written while both saves were public.
          await cacheDao.write(
            key: snapshotCacheKey,
            payload: ProfileVideoListSnapshot(
              videos: ids.map(createTestVideo).toList(),
              itemIds: ids,
              nextPageOffset: ids.length,
              hasMoreContent: false,
            ).toJson(),
          );
          when(
            () => mockBookmarksRepository.bookmarkedVideoReferences,
          ).thenReturn(referencesShownAs(ids));
          when(
            () => mockBookmarksRepository.publicBookmarkedVideoReferences,
          ).thenReturn({'video-2'});

          final bloc = await syncedBloc();

          expect(bloc.state.videos.map((v) => v.id), ids);
          final persisted = ProfileVideoListSnapshot.fromJson(
            (await cacheDao.readEntry(snapshotCacheKey))!.payload,
          );
          expect(persisted.itemIds, ['video-2']);
          expect(persisted.videos.map((v) => v.id), ['video-2']);
        });
      });

      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'prunes the address of a tombstoned video from a restored snapshot',
        setUp: () async {
          await cacheDao.write(
            key: snapshotCacheKey,
            payload: ProfileVideoListSnapshot(
              videos: [
                createTestVideo(editedRevisionId, addressableDTag: 'clip'),
                createTestVideo('a' * 64),
              ],
              itemIds: [coordinateFor('clip'), 'a' * 64],
              nextPageOffset: 2,
              hasMoreContent: false,
            ).toJson(),
          );
          when(
            () => mockBookmarksRepository.bookmarkedVideoReferences,
          ).thenReturn(['a' * 64]);
        },
        build: () => createBloc(
          deletedVideoFilter: (video) => video.id == editedRevisionId,
        ),
        act: (bloc) => bloc.add(const ProfileSavedVideosSyncRequested()),
        wait: const Duration(milliseconds: 50),
        expect: () => [
          isA<ProfileSavedVideosState>()
              .having((s) => s.isRefreshing, 'isRefreshing', true)
              .having((s) => s.videos.map((v) => v.id), 'cached videos', [
                'a' * 64,
              ])
              .having((s) => s.savedEventIds, 'savedEventIds', ['a' * 64]),
          isA<ProfileSavedVideosState>().having(
            (s) => s.isRefreshing,
            'isRefreshing',
            false,
          ),
        ],
      );
    });

    group('ProfileSavedVideosLoadMoreRequested', () {
      // Build a list that exceeds one page so hasMoreContent starts true and
      // a second fetch is required.
      const bookmarkCount = ProfileTabPagination.pageSize + 7;
      late List<String> manyBookmarks;

      setUp(() {
        manyBookmarks = referencesShownAs(
          List.generate(bookmarkCount, (i) => 'video-$i'),
        );
      });

      // A first page that resolves nothing sets the failure evidence. A later
      // page that resolves videos the platform filter then drops must replace
      // it, or the tab keeps claiming a failure that a fetch already answered.
      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'a later page that resolved-then-filtered clears the failure evidence',
        setUp: () {
          // The platform filter only drops WebM on iOS/macOS, and the test
          // binding reports android, so the filter is inert without this.
          debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
          when(
            () => mockBookmarksRepository.bookmarkedVideoReferences,
          ).thenReturn(manyBookmarks);
          when(
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          ).thenAnswer((invocation) async {
            final ids = invocation.positionalArguments.first as List<String>;
            // Page 1 resolves nothing at all; page 2 resolves videos that are
            // unplayable here, so both pages render empty for different
            // reasons.
            if (ids.contains('video-0')) return <VideoEvent>[];
            return ids
                .map(
                  (id) =>
                      createTestVideo(id, videoUrl: 'https://e.dev/$id.webm'),
                )
                .toList();
          });
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const ProfileSavedVideosSyncRequested());
          await bloc.stream.firstWhere(
            (state) => state.status == ProfileSavedVideosStatus.success,
          );
          expect(bloc.state.hasUnresolvedSaves, isTrue);
          bloc.add(const ProfileSavedVideosLoadMoreRequested());
        },
        tearDown: () => debugDefaultTargetPlatformOverride = null,
        verify: (bloc) {
          expect(bloc.state.videos, isEmpty);
          expect(bloc.state.savedEventIds, isNotEmpty);
          expect(bloc.state.hasUnresolvedSaves, isFalse);
        },
      );

      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'fetches the next page and advances offset',
        setUp: () {
          when(
            () => mockBookmarksRepository.bookmarkedVideoReferences,
          ).thenReturn(manyBookmarks);
          when(
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          ).thenAnswer((invocation) async {
            final ids = invocation.positionalArguments.first as List<String>;
            return ids.map(createTestVideo).toList();
          });
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const ProfileSavedVideosSyncRequested());
          // Wait for sync to complete before requesting more.
          await bloc.stream.firstWhere(
            (state) => state.status == ProfileSavedVideosStatus.success,
          );
          bloc.add(const ProfileSavedVideosLoadMoreRequested());
        },
        verify: (bloc) {
          expect(bloc.state.status, ProfileSavedVideosStatus.success);
          expect(bloc.state.videos, hasLength(bookmarkCount));
          expect(bloc.state.nextPageOffset, bookmarkCount);
          expect(bloc.state.hasMoreContent, isFalse);
          expect(bloc.state.isLoadingMore, isFalse);
        },
      );

      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'skips a video the first page already shows under its address',
        setUp: () {
          // Newest first, the address opens page one and the event-id bookmark
          // of the same video's original revision is alone on page two.
          final fillers = List.generate(
            ProfileTabPagination.pageSize - 1,
            (i) => i.toRadixString(16).padLeft(64, 'f'),
          );
          when(() => mockBookmarksRepository.bookmarkedVideoReferences)
              .thenReturn([
                originalRevisionId,
                ...fillers.reversed,
                coordinateFor('clip'),
              ]);
          stubLatestRevisionAtClipAddress();
          stubVideosByEventId();
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const ProfileSavedVideosSyncRequested());
          await bloc.stream.firstWhere(
            (state) => state.status == ProfileSavedVideosStatus.success,
          );
          bloc.add(const ProfileSavedVideosLoadMoreRequested());
        },
        verify: (bloc) {
          expect(bloc.state.nextPageOffset, ProfileTabPagination.pageSize + 1);
          expect(bloc.state.videos, hasLength(ProfileTabPagination.pageSize));
          expect(bloc.state.videos.first.id, editedRevisionId);
          expect(
            bloc.state.videos.map((v) => v.id),
            isNot(contains(originalRevisionId)),
          );
        },
      );

      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'is a no-op when hasMoreContent is false',
        build: createBloc,
        seed: () => const ProfileSavedVideosState(
          status: ProfileSavedVideosStatus.success,
          hasMoreContent: false,
        ),
        act: (bloc) => bloc.add(const ProfileSavedVideosLoadMoreRequested()),
        expect: () => const <ProfileSavedVideosState>[],
      );

      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'is a no-op when already loading more',
        build: createBloc,
        seed: () => const ProfileSavedVideosState(
          status: ProfileSavedVideosStatus.success,
          isLoadingMore: true,
        ),
        act: (bloc) => bloc.add(const ProfileSavedVideosLoadMoreRequested()),
        expect: () => const <ProfileSavedVideosState>[],
      );
    });

    group('a bookmark change while the grid is showing', () {
      late StreamController<List<String>> bookmarkChanges;

      setUp(() {
        bookmarkChanges = StreamController<List<String>>.broadcast();
        addTearDown(bookmarkChanges.close);
        when(
          () => mockBookmarksRepository.watchBookmarkedVideoReferences(),
        ).thenAnswer((_) => bookmarkChanges.stream);
        when(
          () => mockVideosRepository.getVideosByIds(
            any(),
            cacheResults: any(named: 'cacheResults'),
          ),
        ).thenAnswer(
          (invocation) async =>
              (invocation.positionalArguments.first as List<String>)
                  .map(createTestVideo)
                  .toList(),
        );
      });

      ProfileSavedVideosState showing(List<String> ids) =>
          ProfileSavedVideosState(
            status: ProfileSavedVideosStatus.success,
            videos: ids.map(createTestVideo).toList(),
            savedEventIds: ids,
            nextPageOffset: ids.length,
            hasMoreContent: false,
          );

      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'a change that locks the private list is flagged when no video moved',
        setUp: () {
          when(
            () => mockBookmarksRepository.hasUnreadablePrivateItems,
          ).thenReturn(true);
        },
        build: createBloc,
        seed: () => showing(['video-1']),
        act: (_) => bookmarkChanges.add(referencesShownAs(['video-1'])),
        wait: const Duration(milliseconds: 50),
        expect: () => [
          showing(['video-1']).copyWith(privateBookmarksLocked: true),
        ],
      );

      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'a save that turned private leaves the snapshot when no video moved',
        setUp: () async {
          // Written while both saves were public.
          await CacheSync.write<ProfileVideoListSnapshot>(
            key: snapshotCacheKey,
            value: ProfileVideoListSnapshot(
              videos: ['video-1', 'video-2'].map(createTestVideo).toList(),
              itemIds: const ['video-1', 'video-2'],
              nextPageOffset: 2,
              hasMoreContent: false,
            ),
            toJson: (snapshot) => snapshot.toJson(),
          );
          when(
            () => mockBookmarksRepository.publicBookmarkedVideoReferences,
          ).thenReturn({'video-2'});
        },
        build: createBloc,
        seed: () => showing(['video-1', 'video-2']),
        act: (_) => bookmarkChanges.add(
          referencesShownAs(['video-1', 'video-2']),
        ),
        wait: const Duration(milliseconds: 50),
        verify: (bloc) async {
          expect(bloc.state.savedEventIds, ['video-1', 'video-2']);
          final cached = await CacheSync.read<ProfileVideoListSnapshot>(
            key: snapshotCacheKey,
            fromJson: ProfileVideoListSnapshot.fromJson,
          );
          expect(cached?.itemIds, ['video-2']);
        },
      );

      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'a save landing while the private list is locked keeps the flag',
        setUp: () {
          when(
            () => mockBookmarksRepository.hasUnreadablePrivateItems,
          ).thenReturn(true);
        },
        build: createBloc,
        seed: () => showing(['video-1']),
        act: (_) => bookmarkChanges.add(
          referencesShownAs(['video-2', 'video-1']),
        ),
        wait: const Duration(milliseconds: 50),
        verify: (bloc) {
          expect(bloc.state.savedEventIds, equals(['video-2', 'video-1']));
          expect(bloc.state.privateBookmarksLocked, isTrue);
        },
      );

      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'a save made from the share sheet lands at the top',
        build: createBloc,
        seed: () => showing(['video-1']),
        act: (_) => bookmarkChanges.add(
          referencesShownAs(['video-2', 'video-1']),
        ),
        wait: const Duration(milliseconds: 50),
        expect: () => [
          isA<ProfileSavedVideosState>()
              .having((s) => s.videos.map((v) => v.id), 'videos', [
                'video-2',
                'video-1',
              ])
              .having((s) => s.savedEventIds, 'savedEventIds', [
                'video-2',
                'video-1',
              ]),
        ],
        verify: (_) async {
          // Only the new save is fetched; the video already showing is kept.
          verify(
            () => mockVideosRepository.getVideosByIds([
              'video-2',
            ], cacheResults: true),
          ).called(1);
          final cached = await CacheSync.read<ProfileVideoListSnapshot>(
            key: snapshotCacheKey,
            fromJson: ProfileVideoListSnapshot.fromJson,
          );
          expect(cached?.itemIds, equals(['video-2', 'video-1']));
        },
      );

      group('when a bookmark saved by event id resolves to its address', () {
        // The first sync timed out, so the grid fetched the revision the
        // event id names; a later sync matched that id to the address.
        ProfileSavedVideosState showingOriginalRevisionByEventId() =>
            ProfileSavedVideosState(
              status: ProfileSavedVideosStatus.success,
              videos: [
                createTestVideo(originalRevisionId, addressableDTag: 'clip'),
              ],
              savedEventIds: [originalRevisionId],
              nextPageOffset: 1,
              hasMoreContent: false,
            );

        blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
          'shows the latest revision at that address',
          setUp: stubLatestRevisionAtClipAddress,
          build: createBloc,
          seed: showingOriginalRevisionByEventId,
          act: (_) => bookmarkChanges.add([coordinateFor('clip')]),
          wait: const Duration(milliseconds: 50),
          expect: () => [
            isA<ProfileSavedVideosState>()
                .having((s) => s.videos.map((v) => v.id), 'videos', [
                  editedRevisionId,
                ])
                .having((s) => s.savedEventIds, 'savedEventIds', [
                  coordinateFor('clip'),
                ]),
          ],
          verify: (_) {
            verify(
              () => mockVideosRepository.getVideosByAddressableIds([
                coordinateFor('clip'),
              ], cacheResults: true),
            ).called(1);
          },
        );

        blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
          'keeps the tile when the address comes back empty',
          setUp: () {
            when(
              () => mockVideosRepository.getVideosByAddressableIds(
                any(),
                cacheResults: any(named: 'cacheResults'),
              ),
            ).thenAnswer((_) async => []);
          },
          build: createBloc,
          seed: showingOriginalRevisionByEventId,
          act: (_) => bookmarkChanges.add([coordinateFor('clip')]),
          wait: const Duration(milliseconds: 50),
          expect: () => [
            isA<ProfileSavedVideosState>()
                .having((s) => s.videos.map((v) => v.id), 'videos', [
                  originalRevisionId,
                ])
                .having((s) => s.savedEventIds, 'savedEventIds', [
                  coordinateFor('clip'),
                ]),
          ],
          verify: (_) {
            verify(
              () => mockVideosRepository.getVideosByAddressableIds([
                coordinateFor('clip'),
              ], cacheResults: true),
            ).called(1);
          },
        );
      });

      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'a save does not refetch a video already showing under its address',
        setUp: stubLatestRevisionAtClipAddress,
        build: createBloc,
        seed: () => ProfileSavedVideosState(
          status: ProfileSavedVideosStatus.success,
          videos: [createTestVideo(editedRevisionId, addressableDTag: 'clip')],
          savedEventIds: [coordinateFor('clip')],
          nextPageOffset: 1,
          hasMoreContent: false,
        ),
        act: (_) => bookmarkChanges.add(
          referencesShownAs(['a' * 64, coordinateFor('clip')]),
        ),
        wait: const Duration(milliseconds: 50),
        expect: () => [
          isA<ProfileSavedVideosState>()
              .having((s) => s.videos.map((v) => v.id), 'videos', [
                'a' * 64,
                editedRevisionId,
              ])
              .having((s) => s.savedEventIds, 'savedEventIds', [
                'a' * 64,
                coordinateFor('clip'),
              ]),
        ],
        verify: (_) {
          verify(
            () => mockVideosRepository.getVideosByIds([
              'a' * 64,
            ], cacheResults: true),
          ).called(1);
          verifyNever(
            () => mockVideosRepository.getVideosByAddressableIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          );
        },
      );

      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'shows one tile for a video the change names by its address and by '
        'an earlier event id',
        // The repository could not match the older `e` bookmark to the
        // address, so both references reach the grid and both resolve.
        setUp: () {
          stubLatestRevisionAtClipAddress();
          stubVideosByEventId();
        },
        build: createBloc,
        seed: () => showing(['video-1']),
        act: (_) => bookmarkChanges.add(
          referencesShownAs([
            coordinateFor('clip'),
            originalRevisionId,
            'video-1',
          ]),
        ),
        wait: const Duration(milliseconds: 50),
        verify: (bloc) {
          expect(bloc.state.videos.map((v) => v.id), [
            editedRevisionId,
            'video-1',
          ]);
        },
      );

      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'an unsave drops the video without fetching anything',
        build: createBloc,
        seed: () => showing(['video-2', 'video-1']),
        act: (_) => bookmarkChanges.add(referencesShownAs(['video-1'])),
        wait: const Duration(milliseconds: 50),
        expect: () => [
          isA<ProfileSavedVideosState>()
              .having((s) => s.videos.map((v) => v.id), 'videos', ['video-1'])
              .having((s) => s.savedEventIds, 'savedEventIds', ['video-1']),
        ],
        verify: (_) {
          verifyNever(
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          );
        },
      );

      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'is ignored before the first sync has settled',
        build: createBloc,
        act: (_) => bookmarkChanges.add(referencesShownAs(['video-1'])),
        wait: const Duration(milliseconds: 50),
        expect: () => const <ProfileSavedVideosState>[],
        verify: (_) {
          // That sync reads the same repository, so fetching here as well
          // would load the first page twice.
          verifyNever(
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          );
        },
      );

      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'is ignored when it matches what is already showing',
        build: createBloc,
        seed: () => showing(['video-2', 'video-1']),
        // The repository announces every sync, changed or not.
        act: (_) => bookmarkChanges.add(
          referencesShownAs(['video-2', 'video-1']),
        ),
        wait: const Duration(milliseconds: 50),
        expect: () => const <ProfileSavedVideosState>[],
      );

      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'keeps the grid as it was when the new save cannot be fetched',
        setUp: () {
          when(
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          ).thenThrow(Exception('relay unavailable'));
        },
        build: createBloc,
        seed: () => showing(['video-1']),
        act: (_) => bookmarkChanges.add(
          referencesShownAs(['video-2', 'video-1']),
        ),
        wait: const Duration(milliseconds: 50),
        expect: () => const <ProfileSavedVideosState>[],
        errors: () => [isA<Exception>()],
      );

      test('stops listening to the repository on close', () async {
        final bloc = createBloc();
        expect(bookmarkChanges.hasListener, isTrue);

        await bloc.close();

        expect(bookmarkChanges.hasListener, isFalse);
      });
    });
  });
}

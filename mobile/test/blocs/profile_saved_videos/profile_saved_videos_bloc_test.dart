// ABOUTME: Tests for ProfileSavedVideosBloc — loading bookmarked videos from
// ABOUTME: BookmarksRepository and paginating through VideosRepository.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:bookmarks_repository/bookmarks_repository.dart';
import 'package:cache_sync/cache_sync.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_saved_videos/profile_saved_videos_bloc.dart';
import 'package:openvine/blocs/profile_shared/profile_tab_page_size.dart';
import 'package:openvine/blocs/profile_shared/profile_video_list_snapshot.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockBookmarksRepository extends Mock implements BookmarksRepository {}

class _MockVideosRepository extends Mock implements VideosRepository {}

/// In-memory [CacheDao] so the bloc's [CacheSync] reads/writes are isolated
/// per test without touching disk.
class _InMemoryCacheDao implements CacheDao {
  final Map<String, String> _store = {};

  /// When set, [write] parks until it completes, holding a sync handler in the
  /// post-emit snapshot write the way a real disk write does.
  Completer<void>? writeGate;

  @override
  Future<String?> read(String key) async => _store[key];

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

    VideoEvent createTestVideo(
      String id, {
      String videoUrl = 'https://example.com/video.mp4',
    }) {
      final now = DateTime.now();
      return VideoEvent(
        id: id,
        pubkey: '0' * 64,
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        content: '',
        timestamp: now,
        title: 'Test Video $id',
        videoUrl: videoUrl,
        thumbnailUrl: 'https://example.com/thumb.jpg',
      );
    }

    test('initial state is initial with empty collections', () {
      final bloc = createBloc();
      expect(bloc.state.status, ProfileSavedVideosStatus.initial);
      expect(bloc.state.videos, isEmpty);
      expect(bloc.state.savedEventIds, isEmpty);
      expect(bloc.state.error, isNull);
      bloc.close();
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
      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'emits success with empty list when there are no bookmarks',
        setUp: () {
          when(
            () => mockBookmarksRepository.globalBookmarks,
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
            () => mockBookmarksRepository.globalBookmarks,
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
          () => mockBookmarksRepository.globalBookmarks,
        ).thenReturn(const []);
        when(() => mockBookmarksRepository.syncGlobalBookmarks()).thenAnswer((
          _,
        ) async {
          when(() => mockBookmarksRepository.globalBookmarks).thenReturn(const [
            BookmarkItem(type: 'e', id: 'video-1'),
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

      test('a sync arriving during the snapshot write still runs', () async {
        when(
          () => mockBookmarksRepository.globalBookmarks,
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
        'reopen restores the cached list, then flips the bar off when '
        'bookmarks are unchanged',
        setUp: () async {
          await cacheDao.write(
            key: '$currentUserPubkey:profile_saved_videos',
            payload: ProfileVideoListSnapshot(
              videos: [createTestVideo('video-1'), createTestVideo('video-2')],
              itemIds: const ['video-1', 'video-2'],
              nextPageOffset: 2,
              hasMoreContent: false,
            ).toJson(),
          );
          when(() => mockBookmarksRepository.globalBookmarks).thenReturn(const [
            BookmarkItem(type: 'e', id: 'video-1'),
            BookmarkItem(type: 'e', id: 'video-2'),
          ]);
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
            key: '$currentUserPubkey:profile_saved_videos',
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
            () => mockBookmarksRepository.globalBookmarks,
          ).thenReturn(const [BookmarkItem(type: 'e', id: 'video-1')]);
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
            key: '$currentUserPubkey:profile_saved_videos',
            payload: ProfileVideoListSnapshot(
              videos: [createTestVideo('video-1')],
              itemIds: const ['video-1'],
              nextPageOffset: 1,
              hasMoreContent: false,
            ).toJson(),
          );
          when(() => mockBookmarksRepository.globalBookmarks).thenReturn(const [
            BookmarkItem(type: 'e', id: 'video-2'),
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
            key: '$currentUserPubkey:profile_saved_videos',
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

      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'grows a persisted window shorter than a page even when the bookmark '
        'list is unchanged',
        setUp: () async {
          final ids = List.generate(
            ProfileTabPagination.pageSize + 14,
            (i) => 'video-$i',
          );
          await cacheDao.write(
            key: '$currentUserPubkey:profile_saved_videos',
            payload: ProfileVideoListSnapshot(
              videos: ids.take(6).map(createTestVideo).toList(),
              itemIds: ids,
              nextPageOffset: 6,
              hasMoreContent: true,
            ).toJson(),
          );
          when(
            () => mockBookmarksRepository.globalBookmarks,
          ).thenReturn([for (final id in ids) BookmarkItem(type: 'e', id: id)]);
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
            key: '$currentUserPubkey:profile_saved_videos',
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
            () => mockBookmarksRepository.globalBookmarks,
          ).thenReturn([for (final id in ids) BookmarkItem(type: 'e', id: id)]);
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
        'filters non-event bookmarks (hashtags, urls) and loads videos for '
        'event bookmarks',
        setUp: () {
          when(() => mockBookmarksRepository.globalBookmarks).thenReturn(const [
            BookmarkItem(type: 'e', id: 'video-1'),
            BookmarkItem(type: 't', id: 'flutter'),
            BookmarkItem(type: 'e', id: 'video-2'),
            BookmarkItem(type: 'r', id: 'https://example.com'),
          ]);
          when(
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          ).thenAnswer(
            (_) async => [
              createTestVideo('video-1'),
              createTestVideo('video-2'),
            ],
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ProfileSavedVideosSyncRequested()),
        verify: (bloc) {
          expect(bloc.state.status, ProfileSavedVideosStatus.success);
          expect(bloc.state.videos, hasLength(2));
          expect(bloc.state.savedEventIds, equals(['video-1', 'video-2']));
          expect(bloc.state.hasMoreContent, isFalse);
          verify(
            () => mockVideosRepository.getVideosByIds([
              'video-1',
              'video-2',
            ], cacheResults: true),
          ).called(1);
        },
      );

      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'emits failure when fetching videos throws',
        setUp: () {
          when(
            () => mockBookmarksRepository.globalBookmarks,
          ).thenReturn(const [BookmarkItem(type: 'e', id: 'video-1')]);
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
    });

    group('ProfileSavedVideosLoadMoreRequested', () {
      // Build a list that exceeds one page so hasMoreContent starts true and
      // a second fetch is required.
      const bookmarkCount = ProfileTabPagination.pageSize + 7;
      final manyBookmarks = List.generate(
        bookmarkCount,
        (i) => BookmarkItem(type: 'e', id: 'video-$i'),
      );

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
            () => mockBookmarksRepository.globalBookmarks,
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
            () => mockBookmarksRepository.globalBookmarks,
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
  });
}

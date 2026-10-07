// ABOUTME: Verifies live Home policy changes filter the existing feed in place.
// ABOUTME: Real block and relay-mute policy must preserve source and pagination.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:videos_repository/videos_repository.dart';

class _Videos extends Mock implements VideosRepository {}

class _Follows extends Mock implements FollowRepository {}

class _CuratedLists extends Mock implements CuratedListRepository {}

class _Nostr extends Mock implements NostrClient {}

/// Runs the production policy and records that a general change reached it.
/// A no-op event handler must not pass the unchanged-state regression.
class _ObservedBlocklist extends ContentBlocklistRepository {
  _ObservedBlocklist({required super.onChanged});

  final filteredAuthorSets = <List<String>>[];

  @override
  List<T> filterContent<T>(List<T> content, String Function(T) getPubkey) {
    filteredAuthorSets.add(content.map(getPubkey).toList());
    return super.filterContent(content, getPubkey);
  }
}

class _HomePreferences extends InMemorySharedPreferencesStore {
  _HomePreferences()
    : super.withData({'flutter.$_selectionKey': _storedSource});

  final writes = <String>[];

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    writes.add(key);
    return super.setValue(valueType, key, value);
  }

  @override
  Future<bool> remove(String key) {
    writes.add(key);
    return super.remove(key);
  }
}

const _viewer =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _visibleAuthor =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _deniedAuthor =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _unrelatedAuthor =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
const _selectionKey = 'selected_feed_mode_$_viewer';
const _source = VideoFeedSource.subscribedList(
  listId: '$_visibleAuthor:crew',
  listName: 'Crew',
);
const _storedSource = 'curated:$_visibleAuthor:crew';

VideoEvent _video(String id, String author) => VideoEvent(
  id: id,
  pubkey: author,
  createdAt: 1755300000,
  content: 'Home policy regression',
  timestamp: DateTime.utc(2026, 8, 16),
  videoUrl: 'https://example.com/$id.mp4',
);

void main() {
  setUpAll(() => registerFallbackValue(<Filter>[]));

  setUp(() {
    final originalPreferencesPlatform = SharedPreferencesStorePlatform.instance;
    addTearDown(() {
      SharedPreferences.setMockInitialValues({});
      SharedPreferencesStorePlatform.instance = originalPreferencesPlatform;
    });
  });

  group(VideoFeedBloc, () {
    group('VideoFeedBlocklistChanged', () {
      late _Videos videos;
      late _Follows follows;
      late _CuratedLists curatedLists;
      late _Nostr nostr;
      late _ObservedBlocklist blocklist;
      late _HomePreferences platformPreferences;
      late SharedPreferences preferences;
      late StreamController<Event> relayEvents;
      late Completer<void> policyChanged;
      late VideoFeedBlocState activeFeed;

      setUp(() async {
        videos = _Videos();
        follows = _Follows();
        curatedLists = _CuratedLists();
        nostr = _Nostr();
        relayEvents = StreamController<Event>.broadcast();
        policyChanged = Completer<void>();
        blocklist = _ObservedBlocklist(
          onChanged: () {
            if (!policyChanged.isCompleted) policyChanged.complete();
          },
        );
        when(() => nostr.subscribe(any()))
            .thenAnswer((_) => relayEvents.stream);

        SharedPreferences.setMockInitialValues({});
        platformPreferences = _HomePreferences();
        SharedPreferencesStorePlatform.instance = platformPreferences;
        preferences = await SharedPreferences.getInstance();

        activeFeed = VideoFeedBlocState(
          status: VideoFeedStatus.success,
          source: _source,
          videos: [
            _video(_visibleAuthor, _visibleAuthor),
            _video(_viewer, _visibleAuthor),
            _video(_deniedAuthor, _deniedAuthor),
          ],
          paginationCursor: 'next-home-page',
          currentIndex: 1,
        );
      });

      tearDown(() async {
        await relayEvents.close();
        blocklist.dispose();
      });

      VideoFeedBloc buildBloc() => VideoFeedBloc(
        videosRepository: videos,
        followRepository: follows,
        curatedListRepository: curatedLists,
        contentBlocklistRepository: blocklist,
        userPubkey: _viewer,
        sharedPreferences: preferences,
        serveCachedHomeFeed: false,
      );

      Future<void> receiveMute(String author) async {
        await blocklist.syncMuteListsInBackground(nostr, _viewer);
        relayEvents.add(
          Event(
              _viewer,
              10000,
              [
                ['p', author],
              ],
              '',
              createdAt: 1755300001,
            )
            ..id = _unrelatedAuthor
            ..sig = ''.padLeft(128, 'e'),
        );
        await policyChanged.future;
      }

      void expectNoRestartOrSelectionWrite(VideoFeedBloc bloc) {
        expect(bloc.state.status, VideoFeedStatus.success);
        expect(bloc.state.source, _source);
        expect(bloc.state.paginationCursor, 'next-home-page');
        expect(bloc.state.hasMore, isTrue);
        expect(bloc.state.isLoadingMore, isFalse);
        expect(bloc.state.currentIndex, 1);
        expect(preferences.getString(_selectionKey), _storedSource);
        expect(platformPreferences.writes, isEmpty);
        verifyZeroInteractions(videos);
        verifyZeroInteractions(follows);
        verifyZeroInteractions(curatedLists);
      }

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'new local block removes its author without restarting the selected feed',
        build: buildBloc,
        seed: () => activeFeed,
        act: (bloc) async {
          expect(blocklist.shouldFilterFromFeeds(_deniedAuthor), isFalse);
          await blocklist.blockUser(_deniedAuthor, ourPubkey: _viewer);
          bloc.add(const VideoFeedBlocklistChanged());
        },
        expect: () => [
          activeFeed.copyWith(videos: activeFeed.videos.take(2).toList()),
        ],
        verify: (bloc) {
          expect(blocklist.isBlocked(_deniedAuthor), isTrue);
          expect(blocklist.isMutedByUs(_deniedAuthor), isFalse);
          expectNoRestartOrSelectionWrite(bloc);
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'new relay mute removes its author through the full current policy',
        build: buildBloc,
        seed: () => activeFeed,
        act: (bloc) async {
          expect(blocklist.shouldFilterFromFeeds(_deniedAuthor), isFalse);
          await receiveMute(_deniedAuthor);
          bloc.add(const VideoFeedBlocklistChanged());
        },
        expect: () => [
          activeFeed.copyWith(videos: activeFeed.videos.take(2).toList()),
        ],
        verify: (bloc) {
          expect(blocklist.isMutedByUs(_deniedAuthor), isTrue);
          expect(blocklist.isBlocked(_deniedAuthor), isFalse);
          expectNoRestartOrSelectionWrite(bloc);
        },
      );

      blocTest<VideoFeedBloc, VideoFeedBlocState>(
        'unrelated background mute retains loaded videos and their pagination',
        build: buildBloc,
        seed: () => activeFeed,
        act: (bloc) async {
          await receiveMute(_unrelatedAuthor);
          bloc.add(const VideoFeedBlocklistChanged());
        },
        expect: () => <VideoFeedBlocState>[],
        verify: (bloc) {
          expect(blocklist.isMutedByUs(_unrelatedAuthor), isTrue);
          expect(blocklist.filteredAuthorSets, [
            [_visibleAuthor, _visibleAuthor, _deniedAuthor],
          ]);
          expect(bloc.state, activeFeed);
          expect(bloc.state.videos, hasLength(3));
          expectNoRestartOrSelectionWrite(bloc);
        },
      );
    });
  });
}

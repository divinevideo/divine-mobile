// ABOUTME: Verifies author-qualified Home selections and conservative migration
// ABOUTME: across partial subscription hydration, account boundaries and unfollows.

import 'dart:async';

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:videos_repository/videos_repository.dart';

class _Nostr extends Mock implements NostrClient {}

class _Api extends Mock implements FunnelcakeApiClient {}

class _Follows extends Mock implements FollowRepository {}

class _Videos extends Mock implements VideosRepository {}

/// Uses the real SharedPreferences cache and a controllable platform write.
/// Storage can finish after a newer snapshot or an explicit Home choice.
class _GatedPreferences extends InMemorySharedPreferencesStore {
  _GatedPreferences({
    required String savedValue,
    required this.blockedValue,
    this.blockedRepairValue,
  }) : super.withData({'flutter.$_key': savedValue});

  final String blockedValue;
  final String? blockedRepairValue;
  final started = Completer<void>();
  final release = Completer<void>();
  final repairStarted = Completer<void>();
  final releaseRepair = Completer<void>();
  final writes = StreamController<String>.broadcast(sync: true);
  bool _blocked = false;
  int _repairWrites = 0;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.$_key' && value == blockedValue && !_blocked) {
      _blocked = true;
      started.complete();
      await release.future;
    }
    if (key == 'flutter.$_key' && value == blockedRepairValue) {
      if (++_repairWrites == 2) {
        repairStarted.complete();
        await releaseRepair.future;
      }
    }
    final result = await super.setValue(valueType, key, value);
    if (key == 'flutter.$_key' && value is String && !writes.isClosed) {
      writes.add(value);
    }
    return result;
  }

  Future<void> committed(String value) => writes.stream
      .firstWhere((written) => written == value)
      .timeout(const Duration(seconds: 5));
}

const _authorA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _authorB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _viewer =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _otherViewer =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
const _sharedDTag = 'my_vine_list';
const _key = 'selected_feed_mode_$_viewer';

CuratedList _list(
  String author, {
  String id = _sharedDTag,
  String name = 'Alice',
}) => CuratedList(
  id: id,
  pubkey: author,
  name: name,
  videoEventIds: [author],
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

VideoFeedSource _source(CuratedList list) => VideoFeedSource.subscribedList(
  listId: list.authorScopedId,
  listName: list.name,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CuratedListRepository lists;
  late _Follows follows;
  late _Videos videos;
  late SharedPreferences preferences;

  setUp(() async {
    lists = CuratedListRepository(
      nostrClient: _Nostr(),
      funnelcakeApiClient: _Api(),
    );
    follows = _Follows();
    videos = _Videos();
    when(() => follows.followingPubkeys).thenReturn(const []);
    when(() => follows.followingStream).thenAnswer((_) => const Stream.empty());
    when(() => videos.getVideosForList(any())).thenAnswer((_) async => []);
    when(
      () => videos.getRecommendedVideos(
        userPubkey: any(named: 'userPubkey'),
        limit: any(named: 'limit'),
        until: any(named: 'until'),
        skipCache: any(named: 'skipCache'),
        revalidate: any(named: 'revalidate'),
      ),
    ).thenAnswer((_) async => const HomeFeedResult(videos: []));
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });
  tearDown(() => lists.dispose());

  FeedModePreferenceStore store({String viewer = _viewer}) =>
      FeedModePreferenceStore(
        sharedPreferences: preferences,
        userPubkey: viewer,
        followRepository: follows,
        curatedListRepository: lists,
      );

  VideoFeedBloc bloc() => VideoFeedBloc(
    videosRepository: videos,
    followRepository: follows,
    curatedListRepository: lists,
    userPubkey: _viewer,
    sharedPreferences: preferences,
    serveCachedHomeFeed: false,
  );

  Future<VideoFeedBlocState> waitFor(
    VideoFeedBloc feed,
    bool Function(VideoFeedBlocState) matches,
    void Function() action,
  ) {
    final result = feed.stream
        .firstWhere(matches)
        .timeout(const Duration(seconds: 5));
    action();
    return result;
  }

  Future<_GatedPreferences> gatePreferences({
    required String savedValue,
    required String blockedValue,
    String? blockedRepairValue,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final backend = _GatedPreferences(
      savedValue: savedValue,
      blockedValue: blockedValue,
      blockedRepairValue: blockedRepairValue,
    );
    SharedPreferencesStorePlatform.instance = backend;
    preferences = await SharedPreferences.getInstance();
    addTearDown(() async {
      if (!backend.release.isCompleted) backend.release.complete();
      if (!backend.releaseRepair.isCompleted) backend.releaseRepair.complete();
      await backend.writes.close();
      SharedPreferences.setMockInitialValues({});
    });
    return backend;
  }

  group('curated Home preferences', () {
    test(
      'same display name and d-tag retain distinct persisted identities',
      () async {
        final a = _list(_authorA);
        final b = _list(_authorB);
        lists.setSubscribedLists([a, b]);
        await store().persist(_source(a));
        expect(store().restoreSource(FeedMode.forYou), _source(a));
        await store().persist(_source(b));
        expect(store().restoreSource(FeedMode.forYou), _source(b));
        expect(_source(a).persistenceValue, isNot(_source(b).persistenceValue));
      },
    );

    test(
      'a complete unique scoped legacy value resolves to canonical identity',
      () async {
        final a = _list(_authorA);
        lists.setSubscribedLists([a]);
        await preferences.setString(_key, 'list:$_sharedDTag');
        final restored = store().restoreSource(FeedMode.forYou);
        expect(restored, _source(a));
        await store().persist(restored);
        expect(preferences.getString(_key), 'list:$_authorA:$_sharedDTag');
      },
    );

    test('legacy uniqueness is not inferred from a partial snapshot', () async {
      lists.setSubscribedLists([_list(_authorA)], isComplete: false);
      await preferences.setString(_key, 'list:$_sharedDTag');
      expect(store().sourceFromValue('list:$_sharedDTag'), isNull);
      expect(
        store().restoreSource(FeedMode.following),
        const VideoFeedSource.forYou(),
      );
      expect(preferences.getString(_key), 'list:$_sharedDTag');
    });

    test(
      'exact canonical identity can restore from partial copies safely',
      () async {
        final a = _list(_authorA);
        lists.setSubscribedLists([a], isComplete: false);
        await preferences.setString(_key, _source(a).persistenceValue);
        expect(store().restoreSource(FeedMode.forYou), _source(a));
      },
    );

    test('missing qualified identity never aliases another author', () async {
      lists.setSubscribedLists([_list(_authorB)]);
      await preferences.setString(_key, 'list:$_authorA:$_sharedDTag');
      expect(
        store().restoreSource(FeedMode.forYou),
        const VideoFeedSource.forYou(),
      );
    });

    test('ambiguous legacy identity never depends on snapshot order', () async {
      final a = _list(_authorA);
      final b = _list(_authorB);
      await preferences.setString(_key, 'list:$_sharedDTag');
      for (final snapshot in [
        [a, b],
        [b, a],
      ]) {
        lists.setSubscribedLists(snapshot);
        expect(
          store().restoreSource(FeedMode.forYou),
          const VideoFeedSource.forYou(),
        );
      }
    });

    test(
      'complete d-tags with multiple colons survive persistence and restore',
      () async {
        final a = _list(_authorA, id: 'series:season:episode');
        lists.setSubscribedLists([a]);
        await store().persist(_source(a));
        expect(
          store().restoreSource(FeedMode.forYou).listId,
          '$_authorA:series:season:episode',
        );
        await preferences.setString(_key, 'list:series:season:episode');
        expect(store().restoreSource(FeedMode.forYou), _source(a));
      },
    );

    test(
      'leading-colon raw d-tag upgrades only its unique full identity',
      () async {
        final a = _list(_authorA, id: ':series:episode');
        lists.setSubscribedLists([a]);
        await preferences.setString(_key, 'list::series:episode');
        final restored = store().restoreSource(FeedMode.forYou);
        expect(restored, _source(a));
        await store().persist(restored);
        expect(preferences.getString(_key), 'list:$_authorA::series:episode');
      },
    );

    test('another account does not inherit a scoped list selection', () async {
      final a = _list(_authorA);
      lists.setSubscribedLists([a]);
      await store().persist(_source(a));
      expect(
        store(viewer: _otherViewer).restoreSource(FeedMode.forYou),
        const VideoFeedSource.forYou(),
      );
      expect(preferences.getString('selected_feed_mode_$_otherViewer'), isNull);
      expect(preferences.getString(_key), _source(a).persistenceValue);
    });

    test(
      'global legacy list remains untrusted even with one matching list',
      () async {
        lists.setSubscribedLists([_list(_authorA)]);
        await preferences.setString('selected_feed_mode', 'list:$_sharedDTag');
        expect(
          store().restoreSource(FeedMode.forYou),
          const VideoFeedSource.forYou(),
        );
        expect(preferences.getString(_key), isNull);
      },
    );
  });

  group('curated Home feed integration', () {
    test('selecting two identical labels fetches each author independently; restart restores B', () async {
      final a = _list(_authorA);
      final b = _list(_authorB);
      lists.setSubscribedLists([a, b]);
      final feed = bloc();
      await waitFor(
        feed,
        (s) => s.status == VideoFeedStatus.success,
        () => feed.add(const VideoFeedStarted()),
      );
      expect(feed.state.subscribedLists, [a, b]);
      for (final selected in [a, b]) {
        await waitFor(
          feed,
          (s) =>
              s.status == VideoFeedStatus.success &&
              s.source == _source(selected),
          () => feed.add(VideoFeedSourceChanged(_source(selected))),
        );
        verify(() => videos.getVideosForList([selected.pubkey!])).called(1);
      }
      await feed.close();
      final restarted = bloc();
      await waitFor(
        restarted,
        (s) => s.status == VideoFeedStatus.success && s.source == _source(b),
        () => restarted.add(const VideoFeedStarted()),
      );
      expect(preferences.getString(_key), _source(b).persistenceValue);
      await restarted.close();
    });

    test('renaming A does not change selected B; unfollowing selected B never switches to A', () async {
      final a = _list(_authorA);
      final b = _list(_authorB);
      lists.setSubscribedLists([a, b]);
      await preferences.setString(_key, _source(b).persistenceValue);
      final feed = bloc();
      await waitFor(
        feed,
        (s) => s.status == VideoFeedStatus.success,
        () => feed.add(const VideoFeedStarted()),
      );
      final renamedA = _list(_authorA, name: 'Alice renamed');
      await waitFor(
        feed,
        (s) =>
            s.status == VideoFeedStatus.success &&
            s.subscribedLists.first.name == 'Alice renamed',
        () => lists.setSubscribedLists([renamedA, b]),
      );
      expect(feed.state.source, _source(b));
      await waitFor(
        feed,
        (s) =>
            s.status == VideoFeedStatus.success &&
            s.source == const VideoFeedSource.forYou(),
        () => lists.setSubscribedLists([renamedA]),
      );
      expect(preferences.getString(_key), 'forYou');
      await feed.close();
    });

    test(
      'unfollowing A leaves B selected and refreshes B after its rename',
      () async {
        final a = _list(_authorA);
        final b = _list(_authorB);
        lists.setSubscribedLists([a, b]);
        await preferences.setString(_key, _source(b).persistenceValue);
        final feed = bloc();
        await waitFor(
          feed,
          (s) => s.status == VideoFeedStatus.success,
          () => feed.add(const VideoFeedStarted()),
        );
        final renamedB = _list(_authorB, name: 'New B name');
        await waitFor(
          feed,
          (s) =>
              s.status == VideoFeedStatus.success &&
              s.source.listName == 'New B name',
          () => lists.setSubscribedLists([renamedB]),
        );
        expect(feed.state.source.listId, b.authorScopedId);
        expect(preferences.getString(_key), _source(b).persistenceValue);
        await feed.close();
      },
    );

    test('complete startup ambiguity deliberately resets to For You', () async {
      lists.setSubscribedLists([_list(_authorA), _list(_authorB)]);
      await preferences.setString(_key, 'list:$_sharedDTag');
      final feed = bloc();
      await waitFor(
        feed,
        (s) => s.status == VideoFeedStatus.success,
        () => feed.add(const VideoFeedStarted()),
      );
      expect(feed.state.source, const VideoFeedSource.forYou());
      expect(preferences.getString(_key), 'forYou');
      verifyNever(() => videos.getVideosForList(any()));
      await feed.close();
    });

    test('missing qualified selection falls back after complete startup without loading namesake', () async {
      lists.setSubscribedLists([_list(_authorB)]);
      await preferences.setString(_key, 'list:$_authorA:$_sharedDTag');
      final feed = bloc();
      await waitFor(
        feed,
        (s) => s.status == VideoFeedStatus.success,
        () => feed.add(const VideoFeedStarted()),
      );
      expect(feed.state.source, const VideoFeedSource.forYou());
      expect(preferences.getString(_key), 'forYou');
      verifyNever(() => videos.getVideosForList(any()));
      await feed.close();
    });

    test(
      'startup preserves legacy value until a complete snapshot proves unique',
      () async {
        lists.setSubscribedLists([_list(_authorA)], isComplete: false);
        await preferences.setString(_key, 'list:$_sharedDTag');
        final feed = bloc();
        await waitFor(
          feed,
          (s) => s.status == VideoFeedStatus.success,
          () => feed.add(const VideoFeedStarted()),
        );
        expect(feed.state.source, const VideoFeedSource.forYou());
        expect(preferences.getString(_key), 'list:$_sharedDTag');
        final a = _list(_authorA);
        await waitFor(
          feed,
          (s) => s.status == VideoFeedStatus.success && s.source == _source(a),
          () => lists.setSubscribedLists([a]),
        );
        expect(preferences.getString(_key), _source(a).persistenceValue);
        await feed.close();
      },
    );

    test(
      'late authoritative ambiguity deliberately replaces stored legacy value',
      () async {
        lists.setSubscribedLists([_list(_authorA)], isComplete: false);
        await preferences.setString(_key, 'list:$_sharedDTag');
        final feed = bloc();
        await waitFor(
          feed,
          (s) => s.status == VideoFeedStatus.success,
          () => feed.add(const VideoFeedStarted()),
        );
        final a = _list(_authorA);
        final b = _list(_authorB);
        await waitFor(
          feed,
          (s) =>
              s.status == VideoFeedStatus.success &&
              s.subscribedLists.length == 2,
          () => lists.setSubscribedLists([a, b]),
        );
        expect(feed.state.source, const VideoFeedSource.forYou());
        expect(preferences.getString(_key), 'forYou');
        await feed.close();
      },
    );

    test('hydration finishing during initial fetch is restored by first stream replay', () async {
      final fetch = Completer<HomeFeedResult>();
      final requested = Completer<void>();
      when(
        () => videos.getRecommendedVideos(
          userPubkey: any(named: 'userPubkey'),
          limit: any(named: 'limit'),
          until: any(named: 'until'),
          skipCache: any(named: 'skipCache'),
          revalidate: any(named: 'revalidate'),
        ),
      ).thenAnswer((_) {
        requested.complete();
        return fetch.future;
      });
      await preferences.setString(_key, 'list:$_sharedDTag');
      final feed = bloc();
      feed.add(const VideoFeedStarted());
      await requested.future;
      final a = _list(_authorA);
      lists.setSubscribedLists([a]);
      await waitFor(
        feed,
        (s) => s.status == VideoFeedStatus.success && s.source == _source(a),
        () => fetch.complete(const HomeFeedResult(videos: [])),
      );
      expect(preferences.getString(_key), _source(a).persistenceValue);
      await feed.close();
    });

    test(
      'a temporarily missing qualified copy does not discard selection',
      () async {
        final a = _list(_authorA);
        lists.setSubscribedLists([_list(_authorB)], isComplete: false);
        await preferences.setString(_key, _source(a).persistenceValue);
        final feed = bloc();
        await waitFor(
          feed,
          (s) => s.status == VideoFeedStatus.success,
          () => feed.add(const VideoFeedStarted()),
        );
        expect(preferences.getString(_key), _source(a).persistenceValue);
        await waitFor(
          feed,
          (s) => s.status == VideoFeedStatus.success && s.source == _source(a),
          () => lists.setSubscribedLists([a, _list(_authorB)]),
        );
        await feed.close();
      },
    );

    test('queued partial snapshot cannot invalidate a source present in latest complete snapshot', () async {
      final a = _list(_authorA);
      final b = _list(_authorB);
      lists.setSubscribedLists([a]);
      await preferences.setString(_key, _source(a).persistenceValue);
      final feed = bloc();
      await waitFor(
        feed,
        (s) => s.status == VideoFeedStatus.success,
        () => feed.add(const VideoFeedStarted()),
      );
      final seen = <VideoFeedSource>[];
      final subscription = feed.stream.listen((s) => seen.add(s.source));
      await waitFor(
        feed,
        (s) =>
            s.status == VideoFeedStatus.success &&
            s.subscribedLists.length == 2,
        () {
          lists.setSubscribedLists([b], isComplete: false);
          lists.setSubscribedLists([a, b]);
        },
      );
      expect(seen, everyElement(_source(a)));
      expect(preferences.getString(_key), _source(a).persistenceValue);
      await subscription.cancel();
      await feed.close();
    });

    test('queued old complete snapshot cannot discard a source from a newer incomplete snapshot', () async {
      final a = _list(_authorA);
      final b = _list(_authorB);
      lists.setSubscribedLists([a]);
      await preferences.setString(_key, _source(a).persistenceValue);
      final feed = bloc();
      await waitFor(
        feed,
        (s) => s.status == VideoFeedStatus.success,
        () => feed.add(const VideoFeedStarted()),
      );
      final seen = <VideoFeedSource>[];
      final subscription = feed.stream.listen((s) => seen.add(s.source));
      await waitFor(
        feed,
        (s) =>
            s.status == VideoFeedStatus.success &&
            s.subscribedLists.length == 2,
        () {
          lists.setSubscribedLists([b]);
          lists.setSubscribedLists([a, b], isComplete: false);
        },
      );
      expect(seen, everyElement(_source(a)));
      expect(preferences.getString(_key), _source(a).persistenceValue);
      await subscription.cancel();
      await feed.close();
    });

    test('snapshot superseding a blocked fallback repairs canonical platform preference', () async {
      final a = _list(_authorA);
      final b = _list(_authorB);
      final backend = await gatePreferences(
        savedValue: _source(a).persistenceValue,
        blockedValue: 'forYou',
      );
      lists.setSubscribedLists([a]);
      final feed = bloc();
      addTearDown(feed.close);
      await waitFor(
        feed,
        (s) => s.status == VideoFeedStatus.success,
        () => feed.add(const VideoFeedStarted()),
      );
      final seen = <VideoFeedSource>[];
      final subscription = feed.stream.listen((s) => seen.add(s.source));
      addTearDown(subscription.cancel);
      lists.setSubscribedLists([b]);
      await backend.started.future.timeout(const Duration(seconds: 5));
      // The first handler is inside the real preferences platform write.
      lists.setSubscribedLists([a, b]);
      final repaired = backend.committed(_source(a).persistenceValue);
      await waitFor(
        feed,
        (s) =>
            s.status == VideoFeedStatus.success &&
            s.subscribedLists.length == 2,
        backend.release.complete,
      );
      await repaired;
      await preferences.reload();
      expect(feed.state.source, _source(a));
      expect(seen, everyElement(_source(a)));
      expect(preferences.getString(_key), _source(a).persistenceValue);
    });

    test('startup fallback superseded during platform write restores the latest exact author', () async {
      final a = _list(_authorA);
      final b = _list(_authorB);
      final backend = await gatePreferences(
        savedValue: _source(a).persistenceValue,
        blockedValue: 'forYou',
      );
      lists.setSubscribedLists([b]);
      final feed = bloc();
      addTearDown(feed.close);
      feed.add(const VideoFeedStarted());
      await backend.started.future.timeout(const Duration(seconds: 5));
      lists.setSubscribedLists([a, b]);
      final repaired = backend.committed(_source(a).persistenceValue);
      await waitFor(
        feed,
        (s) => s.status == VideoFeedStatus.success && s.source == _source(a),
        backend.release.complete,
      );
      await repaired;
      await preferences.reload();
      expect(preferences.getString(_key), _source(a).persistenceValue);
      verifyNever(() => videos.getVideosForList([_authorB]));
      verifyNever(
        () => videos.getRecommendedVideos(
          userPubkey: any(named: 'userPubkey'),
          limit: any(named: 'limit'),
          until: any(named: 'until'),
          skipCache: any(named: 'skipCache'),
          revalidate: any(named: 'revalidate'),
        ),
      );
    });

    test('startup migration superseded by ambiguity does not load an arbitrary author', () async {
      final a = _list(_authorA);
      final b = _list(_authorB);
      final backend = await gatePreferences(
        savedValue: 'list:$_sharedDTag',
        blockedValue: _source(a).persistenceValue,
      );
      lists.setSubscribedLists([a]);
      final feed = bloc();
      addTearDown(feed.close);
      feed.add(const VideoFeedStarted());
      await backend.started.future.timeout(const Duration(seconds: 5));
      lists.setSubscribedLists([a, b]);
      final repaired = backend.committed('list:$_sharedDTag');
      await waitFor(
        feed,
        (s) => s.status == VideoFeedStatus.success,
        backend.release.complete,
      );
      await repaired;
      await preferences.reload();
      expect(feed.state.source, const VideoFeedSource.forYou());
      expect(preferences.getString(_key), 'forYou');
      verifyNever(() => videos.getVideosForList(any()));
    });

    test(
      'explicit choice during startup migration remains selected and persisted',
      () async {
        final a = _list(_authorA);
        final b = _list(_authorB);
        final backend = await gatePreferences(
          savedValue: 'list:$_sharedDTag',
          blockedValue: _source(a).persistenceValue,
        );
        lists.setSubscribedLists([a]);
        final feed = bloc();
        addTearDown(feed.close);
        feed.add(const VideoFeedStarted());
        await backend.started.future.timeout(const Duration(seconds: 5));
        lists.setSubscribedLists([a, b]);
        await waitFor(
          feed,
          (s) => s.status == VideoFeedStatus.success && s.source == _source(b),
          () => feed.add(VideoFeedSourceChanged(_source(b))),
        );
        final repaired = backend.committed(_source(b).persistenceValue);
        backend.release.complete();
        await repaired;
        await preferences.reload();
        expect(feed.state.source, _source(b));
        expect(preferences.getString(_key), _source(b).persistenceValue);
        verifyNever(() => videos.getVideosForList([_authorA]));
      },
    );

    test('ambiguity arriving during blocked legacy migration never selects the earlier author', () async {
      final a = _list(_authorA);
      final b = _list(_authorB);
      final backend = await gatePreferences(
        savedValue: 'list:$_sharedDTag',
        blockedValue: _source(a).persistenceValue,
      );
      lists.setSubscribedLists([a], isComplete: false);
      final feed = bloc();
      addTearDown(feed.close);
      await waitFor(
        feed,
        (s) => s.status == VideoFeedStatus.success,
        () => feed.add(const VideoFeedStarted()),
      );
      final seen = <VideoFeedSource>[];
      final subscription = feed.stream.listen((s) => seen.add(s.source));
      addTearDown(subscription.cancel);
      lists.setSubscribedLists([a]);
      await backend.started.future.timeout(const Duration(seconds: 5));
      lists.setSubscribedLists([a, b]);
      final repaired = backend.committed('list:$_sharedDTag');
      await waitFor(
        feed,
        (s) =>
            s.status == VideoFeedStatus.success &&
            s.subscribedLists.length == 2,
        backend.release.complete,
      );
      await repaired;
      await preferences.reload();
      expect(feed.state.source, const VideoFeedSource.forYou());
      expect(seen, everyElement(const VideoFeedSource.forYou()));
      expect(preferences.getString(_key), 'forYou');
      verifyNever(() => videos.getVideosForList(any()));
    });

    test(
      'explicit source choice wins over a stale blocked automatic migration',
      () async {
        final a = _list(_authorA);
        final b = _list(_authorB);
        final backend = await gatePreferences(
          savedValue: 'list:$_sharedDTag',
          blockedValue: _source(a).persistenceValue,
        );
        lists.setSubscribedLists([a], isComplete: false);
        final feed = bloc();
        addTearDown(feed.close);
        await waitFor(
          feed,
          (s) => s.status == VideoFeedStatus.success,
          () => feed.add(const VideoFeedStarted()),
        );
        lists.setSubscribedLists([a]);
        await backend.started.future.timeout(const Duration(seconds: 5));
        lists.setSubscribedLists([a, b]);
        await waitFor(
          feed,
          (s) => s.status == VideoFeedStatus.success && s.source == _source(b),
          () => feed.add(VideoFeedSourceChanged(_source(b))),
        );
        final repaired = backend.committed(_source(b).persistenceValue);
        await waitFor(
          feed,
          (s) =>
              s.status == VideoFeedStatus.success &&
              s.source == _source(b) &&
              s.subscribedLists.length == 2,
          backend.release.complete,
        );
        await repaired;
        await preferences.reload();
        expect(preferences.getString(_key), _source(b).persistenceValue);
        verifyNever(() => videos.getVideosForList([_authorA]));
      },
    );

    test('newer explicit choice repairs an older explicit write that finishes last', () async {
      final a = _list(_authorA);
      final b = _list(_authorB);
      final backend = await gatePreferences(
        savedValue: 'forYou',
        blockedValue: _source(a).persistenceValue,
      );
      lists.setSubscribedLists([a, b]);
      final feed = bloc();
      addTearDown(feed.close);
      await waitFor(
        feed,
        (s) => s.status == VideoFeedStatus.success,
        () => feed.add(const VideoFeedStarted()),
      );
      feed.add(VideoFeedSourceChanged(_source(a)));
      await backend.started.future.timeout(const Duration(seconds: 5));
      await waitFor(
        feed,
        (s) => s.status == VideoFeedStatus.success && s.source == _source(b),
        () => feed.add(VideoFeedSourceChanged(_source(b))),
      );
      final repaired = backend.committed(_source(b).persistenceValue);
      backend.release.complete();
      await repaired;
      await preferences.reload();
      expect(feed.state.source, _source(b));
      expect(preferences.getString(_key), _source(b).persistenceValue);
      verifyNever(() => videos.getVideosForList([_authorA]));
    });

    test('third explicit choice arriving during repair wins in state and native storage', () async {
      final a = _list(_authorA);
      final b = _list(_authorB);
      final backend = await gatePreferences(
        savedValue: 'forYou',
        blockedValue: _source(a).persistenceValue,
        blockedRepairValue: _source(b).persistenceValue,
      );
      lists.setSubscribedLists([a, b]);
      final feed = bloc();
      addTearDown(feed.close);
      await waitFor(
        feed,
        (s) => s.status == VideoFeedStatus.success,
        () => feed.add(const VideoFeedStarted()),
      );
      feed.add(VideoFeedSourceChanged(_source(a)));
      await backend.started.future.timeout(const Duration(seconds: 5));
      await waitFor(
        feed,
        (s) => s.status == VideoFeedStatus.success && s.source == _source(b),
        () => feed.add(VideoFeedSourceChanged(_source(b))),
      );
      backend.release.complete();
      await backend.repairStarted.future.timeout(const Duration(seconds: 5));
      await waitFor(
        feed,
        (s) =>
            s.status == VideoFeedStatus.success &&
            s.source == const VideoFeedSource.forYou(),
        () => feed.add(const VideoFeedSourceChanged(VideoFeedSource.forYou())),
      );
      final repaired = backend.committed('forYou');
      backend.releaseRepair.complete();
      await repaired;
      await preferences.reload();
      expect(feed.state.source, const VideoFeedSource.forYou());
      expect(preferences.getString(_key), 'forYou');
      verifyNever(() => videos.getVideosForList([_authorA]));
    });

    test('burst hydration cannot migrate legacy preference from an obsolete unique partial copy', () async {
      await preferences.setString(_key, 'list:$_sharedDTag');
      final feed = bloc();
      await waitFor(
        feed,
        (s) => s.status == VideoFeedStatus.success,
        () => feed.add(const VideoFeedStarted()),
      );
      final seen = <VideoFeedSource>[];
      final subscription = feed.stream.listen((s) => seen.add(s.source));
      await waitFor(
        feed,
        (s) =>
            s.status == VideoFeedStatus.success &&
            s.subscribedLists.length == 2,
        () {
          lists.setSubscribedLists([_list(_authorA)], isComplete: false);
          lists.setSubscribedLists([_list(_authorA), _list(_authorB)]);
        },
      );
      expect(seen, everyElement(const VideoFeedSource.forYou()));
      expect(preferences.getString(_key), 'forYou');
      await subscription.cancel();
      await feed.close();
    });

    test('explicit For You choice cancels deferred restoration', () async {
      lists.setSubscribedLists([], isComplete: false);
      await preferences.setString(_key, 'list:$_sharedDTag');
      final feed = bloc();
      await waitFor(
        feed,
        (s) => s.status == VideoFeedStatus.success,
        () => feed.add(const VideoFeedStarted()),
      );
      feed.add(const VideoFeedSourceChanged(VideoFeedSource.forYou()));
      await Future<void>.delayed(Duration.zero);
      expect(preferences.getString(_key), 'forYou');
      await waitFor(
        feed,
        (s) => s.subscribedLists.length == 1,
        () => lists.setSubscribedLists([_list(_authorA)]),
      );
      expect(feed.state.source, const VideoFeedSource.forYou());
      await feed.close();
    });
  });
}

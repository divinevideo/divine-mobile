// ABOUTME: Verifies author-qualified Home selections and conservative migration
// ABOUTME: across partial subscription hydration, account boundaries and unfollows.

import 'dart:async';

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:db_client/db_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:openvine/providers/container_swap_host.dart';
import 'package:openvine/providers/device_scope.dart';
import 'package:openvine/providers/feed_mode_persistence_provider.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/startup_performance_service.dart';
import 'package:openvine/utils/log_message_batcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:videos_repository/videos_repository.dart';

class _Nostr extends Mock implements NostrClient {}

class _Api extends Mock implements FunnelcakeApiClient {}

class _Follows extends Mock implements FollowRepository {}

class _Videos extends Mock implements VideosRepository {}

class _Database extends Mock implements AppDatabase {}

enum _RemovalResult { succeeds, throwsError, returnsFalse }

class _GatedLegacyRemoval extends InMemorySharedPreferencesStore {
  _GatedLegacyRemoval(String scopedValue, this.result)
    : super.withData({
        'flutter.$_key': scopedValue,
        'flutter.selected_feed_mode': 'classic',
      });

  final _RemovalResult result;
  final started = Completer<void>();
  final release = Completer<void>();
  bool _blocked = false;

  @override
  Future<bool> remove(String key) async {
    if (key == 'flutter.selected_feed_mode' && !_blocked) {
      _blocked = true;
      started.complete();
      await release.future;
      if (result == _RemovalResult.throwsError) {
        throw StateError('The native legacy clear failed.');
      }
      if (result == _RemovalResult.returnsFalse) return false;
    }
    return super.remove(key);
  }
}

/// Uses the real SharedPreferences cache and a controllable platform write.
/// Storage can finish after a newer snapshot or an explicit Home choice.
class _GatedPreferences extends InMemorySharedPreferencesStore {
  _GatedPreferences({
    required String savedValue,
    required this.blockedValue,
    this.blockedRepairValue,
    this.throwBlockedWrite = false,
    this.rejectBlockedWrite = false,
  }) : super.withData({'flutter.$_key': savedValue});

  final String blockedValue;
  final String? blockedRepairValue;
  final bool throwBlockedWrite;
  final bool rejectBlockedWrite;
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
      if (throwBlockedWrite) throw StateError('The platform write failed.');
      if (rejectBlockedWrite) return false;
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

String _stored(VideoFeedSource source) =>
    FeedModePreferenceStore.storageValueFor(source);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CuratedListRepository lists;
  late _Follows follows;
  late _Videos videos;
  late SharedPreferences preferences;

  setUp(() {
    final originalPreferencesPlatform = SharedPreferencesStorePlatform.instance;
    addTearDown(() {
      SharedPreferences.setMockInitialValues({});
      SharedPreferencesStorePlatform.instance = originalPreferencesPlatform;
    });
  });

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

  VideoFeedBloc bloc({
    FeedModePersistenceCoordinator? coordinator,
    CuratedListRepository? repository,
    String viewer = _viewer,
  }) => VideoFeedBloc(
    videosRepository: videos,
    followRepository: follows,
    curatedListRepository: repository ?? lists,
    userPubkey: viewer,
    sharedPreferences: preferences,
    persistenceCoordinator: coordinator,
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
    bool throwBlockedWrite = false,
    bool rejectBlockedWrite = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final backend = _GatedPreferences(
      savedValue: savedValue,
      blockedValue: blockedValue,
      blockedRepairValue: blockedRepairValue,
      throwBlockedWrite: throwBlockedWrite,
      rejectBlockedWrite: rejectBlockedWrite,
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
    test('an injected coordinator cannot cross account boundaries', () {
      final coordinator = FeedModePersistenceCoordinator(
        sharedPreferences: preferences,
        userPubkey: _viewer,
      );
      expect(
        () => bloc(coordinator: coordinator, viewer: _otherViewer),
        throwsArgumentError,
      );
    });

    test(
      'an injected coordinator cannot silently change preferences instances',
      () async {
        final coordinator = FeedModePersistenceCoordinator(
          sharedPreferences: preferences,
          userPubkey: _viewer,
        );
        SharedPreferences.setMockInitialValues({});
        preferences = await SharedPreferences.getInstance();
        expect(() => bloc(coordinator: coordinator), throwsArgumentError);
      },
    );

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
        expect(_stored(_source(a)), isNot(_stored(_source(b))));
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
        expect(preferences.getString(_key), 'curated:$_authorA:$_sharedDTag');
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
      'a pubkey-shaped complete raw d-tag migrates only its original author',
      () async {
        final a = _list(_authorA, id: '$_authorB:cats');
        final b = _list(_authorB, id: 'cats');
        lists.setSubscribedLists([b, a]);
        await preferences.setString(_key, 'list:$_authorB:cats');
        final feed = bloc();
        addTearDown(feed.close);
        await waitFor(
          feed,
          (s) => s.status == VideoFeedStatus.success,
          () => feed.add(const VideoFeedStarted()),
        );
        expect(feed.state.source, _source(a));
        expect(preferences.getString(_key), 'curated:$_authorA:$_authorB:cats');
        verify(() => videos.getVideosForList([_authorA])).called(1);
        verifyNever(() => videos.getVideosForList([_authorB]));
      },
    );

    test(
      'a pubkey-shaped raw d-tag restores when only its raw author remains',
      () async {
        final a = _list(_authorA, id: '$_authorB:cats');
        lists.setSubscribedLists([a]);
        await preferences.setString(_key, 'list:$_authorB:cats');
        expect(store().restoreSource(FeedMode.forYou), _source(a));
        await store().persist(_source(a));
        expect(preferences.getString(_key), _stored(_source(a)));
      },
    );

    test(
      'missing raw legacy author never guesses a matching canonical coordinate',
      () async {
        lists.setSubscribedLists([_list(_authorB, id: 'cats')]);
        await preferences.setString(_key, 'list:$_authorB:cats');
        final feed = bloc();
        addTearDown(feed.close);
        await waitFor(
          feed,
          (s) => s.status == VideoFeedStatus.success,
          () => feed.add(const VideoFeedStarted()),
        );
        expect(feed.state.source, const VideoFeedSource.forYou());
        expect(preferences.getString(_key), 'forYou');
        verifyNever(() => videos.getVideosForList(any()));
      },
    );

    test(
      'canonical B survives cold restore despite A raw d-tag collision',
      () async {
        final a = _list(_authorA, id: '$_authorB:cats');
        final b = _list(_authorB, id: 'cats');
        lists.setSubscribedLists([a, b], isComplete: false);
        await preferences.setString(_key, _stored(_source(b)));
        final feed = bloc();
        addTearDown(feed.close);
        await waitFor(
          feed,
          (s) => s.status == VideoFeedStatus.success,
          () => feed.add(const VideoFeedStarted()),
        );
        expect(feed.state.source, _source(b));
        expect(preferences.getString(_key), 'curated:$_authorB:cats');
        verify(() => videos.getVideosForList([_authorB])).called(1);
        verifyNever(() => videos.getVideosForList([_authorA]));
      },
    );

    test('pubkey-shaped raw legacy waits for authoritative hydration before selecting A', () async {
      final a = _list(_authorA, id: '$_authorB:cats');
      final b = _list(_authorB, id: 'cats');
      lists.setSubscribedLists([b], isComplete: false);
      await preferences.setString(_key, 'list:$_authorB:cats');
      final feed = bloc();
      addTearDown(feed.close);
      await waitFor(
        feed,
        (s) => s.status == VideoFeedStatus.success,
        () => feed.add(const VideoFeedStarted()),
      );
      expect(feed.state.source, const VideoFeedSource.forYou());
      expect(preferences.getString(_key), 'list:$_authorB:cats');
      await waitFor(
        feed,
        (s) => s.status == VideoFeedStatus.success && s.source == _source(a),
        () => lists.setSubscribedLists([a, b]),
      );
      expect(preferences.getString(_key), _stored(_source(a)));
      verifyNever(() => videos.getVideosForList([_authorB]));
    });

    test(
      'two complete raw d-tag matches resolve to For You after authority',
      () async {
        final a = _list(_authorA, id: '$_authorB:cats');
        final other = _list(_otherViewer, id: '$_authorB:cats');
        lists.setSubscribedLists([a], isComplete: false);
        await preferences.setString(_key, 'list:$_authorB:cats');
        final feed = bloc();
        addTearDown(feed.close);
        await waitFor(
          feed,
          (s) => s.status == VideoFeedStatus.success,
          () => feed.add(const VideoFeedStarted()),
        );
        expect(preferences.getString(_key), 'list:$_authorB:cats');
        final persisted = waitFor(
          feed,
          (s) =>
              s.status == VideoFeedStatus.success &&
              s.subscribedLists.length == 2,
          () => lists.setSubscribedLists([a, other]),
        );
        await persisted;
        expect(feed.state.source, const VideoFeedSource.forYou());
        expect(preferences.getString(_key), 'forYou');
        verifyNever(() => videos.getVideosForList(any()));
      },
    );

    test('pubkey-shaped legacy migration superseded by raw ambiguity repairs original preference', () async {
      final a = _list(_authorA, id: '$_authorB:cats');
      final other = _list(_otherViewer, id: '$_authorB:cats');
      final backend = await gatePreferences(
        savedValue: 'list:$_authorB:cats',
        blockedValue: _stored(_source(a)),
      );
      lists.setSubscribedLists([a]);
      final feed = bloc();
      addTearDown(feed.close);
      feed.add(const VideoFeedStarted());
      await backend.started.future.timeout(const Duration(seconds: 5));
      lists.setSubscribedLists([a, other]);
      final repaired = backend.committed('list:$_authorB:cats');
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
      'exact canonical identity can restore from partial copies safely',
      () async {
        final a = _list(_authorA);
        lists.setSubscribedLists([a], isComplete: false);
        await preferences.setString(_key, _stored(_source(a)));
        expect(store().restoreSource(FeedMode.forYou), _source(a));
      },
    );

    test('missing qualified identity never aliases another author', () async {
      lists.setSubscribedLists([_list(_authorB)]);
      await preferences.setString(_key, 'curated:$_authorA:$_sharedDTag');
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
        expect(
          preferences.getString(_key),
          'curated:$_authorA::series:episode',
        );
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
      expect(preferences.getString(_key), _stored(_source(a)));
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
      expect(preferences.getString(_key), _stored(_source(b)));
      await restarted.close();
    });

    test('renaming A does not change selected B; unfollowing selected B never switches to A', () async {
      final a = _list(_authorA);
      final b = _list(_authorB);
      lists.setSubscribedLists([a, b]);
      await preferences.setString(_key, _stored(_source(b)));
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
        await preferences.setString(_key, _stored(_source(b)));
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
        expect(preferences.getString(_key), _stored(_source(b)));
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
      await preferences.setString(_key, 'curated:$_authorA:$_sharedDTag');
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
        expect(preferences.getString(_key), _stored(_source(a)));
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
      expect(preferences.getString(_key), _stored(_source(a)));
      await feed.close();
    });

    test(
      'a temporarily missing qualified copy does not discard selection',
      () async {
        final a = _list(_authorA);
        lists.setSubscribedLists([_list(_authorB)], isComplete: false);
        await preferences.setString(_key, _stored(_source(a)));
        final feed = bloc();
        await waitFor(
          feed,
          (s) => s.status == VideoFeedStatus.success,
          () => feed.add(const VideoFeedStarted()),
        );
        expect(preferences.getString(_key), _stored(_source(a)));
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
      await preferences.setString(_key, _stored(_source(a)));
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
      expect(preferences.getString(_key), _stored(_source(a)));
      await subscription.cancel();
      await feed.close();
    });

    test('queued old complete snapshot cannot discard a source from a newer incomplete snapshot', () async {
      final a = _list(_authorA);
      final b = _list(_authorB);
      lists.setSubscribedLists([a]);
      await preferences.setString(_key, _stored(_source(a)));
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
      expect(preferences.getString(_key), _stored(_source(a)));
      await subscription.cancel();
      await feed.close();
    });

    test('snapshot superseding a blocked fallback repairs canonical platform preference', () async {
      final a = _list(_authorA);
      final b = _list(_authorB);
      final backend = await gatePreferences(
        savedValue: _stored(_source(a)),
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
      final repaired = backend.committed(_stored(_source(a)));
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
      expect(preferences.getString(_key), _stored(_source(a)));
    });

    test('startup fallback superseded during platform write restores the latest exact author', () async {
      final a = _list(_authorA);
      final b = _list(_authorB);
      final backend = await gatePreferences(
        savedValue: _stored(_source(a)),
        blockedValue: 'forYou',
      );
      lists.setSubscribedLists([b]);
      final feed = bloc();
      addTearDown(feed.close);
      feed.add(const VideoFeedStarted());
      await backend.started.future.timeout(const Duration(seconds: 5));
      lists.setSubscribedLists([a, b]);
      final repaired = backend.committed(_stored(_source(a)));
      await waitFor(
        feed,
        (s) => s.status == VideoFeedStatus.success && s.source == _source(a),
        backend.release.complete,
      );
      await repaired;
      await preferences.reload();
      expect(preferences.getString(_key), _stored(_source(a)));
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
        blockedValue: _stored(_source(a)),
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
          blockedValue: _stored(_source(a)),
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
        final repaired = backend.committed(_stored(_source(b)));
        backend.release.complete();
        await repaired;
        await preferences.reload();
        expect(feed.state.source, _source(b));
        expect(preferences.getString(_key), _stored(_source(b)));
        verifyNever(() => videos.getVideosForList([_authorA]));
      },
    );

    test('ambiguity arriving during blocked legacy migration never selects the earlier author', () async {
      final a = _list(_authorA);
      final b = _list(_authorB);
      final backend = await gatePreferences(
        savedValue: 'list:$_sharedDTag',
        blockedValue: _stored(_source(a)),
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
          blockedValue: _stored(_source(a)),
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
        final repaired = backend.committed(_stored(_source(b)));
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
        expect(preferences.getString(_key), _stored(_source(b)));
        verifyNever(() => videos.getVideosForList([_authorA]));
      },
    );

    test('newer explicit choice repairs an older explicit write that finishes last', () async {
      final a = _list(_authorA);
      final b = _list(_authorB);
      final backend = await gatePreferences(
        savedValue: 'forYou',
        blockedValue: _stored(_source(a)),
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
      final repaired = backend.committed(_stored(_source(b)));
      backend.release.complete();
      await repaired;
      await preferences.reload();
      expect(feed.state.source, _source(b));
      expect(preferences.getString(_key), _stored(_source(b)));
      verifyNever(() => videos.getVideosForList([_authorA]));
    });

    test('third explicit choice arriving during repair wins in state and native storage', () async {
      final a = _list(_authorA);
      final b = _list(_authorB);
      final backend = await gatePreferences(
        savedValue: 'forYou',
        blockedValue: _stored(_source(a)),
        blockedRepairValue: _stored(_source(b)),
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

    test('old-source removal cannot overwrite an explicit choice still awaiting native storage', () async {
      final a = _list(_authorA);
      final b = _list(_authorB);
      final backend = await gatePreferences(
        savedValue: _stored(_source(a)),
        blockedValue: _stored(_source(b)),
      );
      lists.setSubscribedLists([a, b]);
      final feed = bloc();
      addTearDown(() async {
        if (!backend.release.isCompleted) backend.release.complete();
        await feed.close();
      });
      await waitFor(
        feed,
        (s) => s.status == VideoFeedStatus.success,
        () => feed.add(const VideoFeedStarted()),
      );
      feed.add(VideoFeedSourceChanged(_source(b)));
      await backend.started.future.timeout(const Duration(seconds: 5));
      await waitFor(
        feed,
        (s) => s.subscribedLists.length == 1,
        () => lists.setSubscribedLists([b]),
      );
      await waitFor(
        feed,
        (s) => s.status == VideoFeedStatus.success && s.source == _source(b),
        backend.release.complete,
      );
      await preferences.reload();
      expect(preferences.getString(_key), _stored(_source(b)));
      expect(feed.state.source, _source(b));
    });

    group('shared persistence ownership across replacement blocs', () {
      Future<
        ({
          VideoFeedBloc old,
          Future<void> closing,
          FeedModePersistenceCoordinator coordinator,
          FeedModePersistenceRegistry? registry,
          _GatedPreferences backend,
          CuratedListRepository replacement,
        })
      >
      blockedReplacement({
        String? blockedRepairValue,
        bool deviceOwned = false,
      }) async {
        final a = _list(_authorA);
        final backend = await gatePreferences(
          savedValue: _stored(_source(a)),
          blockedValue: 'forYou',
          blockedRepairValue: blockedRepairValue,
        );
        final registry = deviceOwned
            ? FeedModePersistenceRegistry(sharedPreferences: preferences)
            : null;
        final coordinator =
            registry?.forAccount(_viewer) ??
            FeedModePersistenceCoordinator(
              sharedPreferences: preferences,
              userPubkey: _viewer,
            );
        lists.setSubscribedLists([a]);
        final old = bloc(coordinator: coordinator);
        await waitFor(
          old,
          (s) => s.status == VideoFeedStatus.success,
          () => old.add(const VideoFeedStarted()),
        );
        lists.setSubscribedLists([_list(_authorB)]);
        await backend.started.future.timeout(const Duration(seconds: 5));
        final closing = old.close();
        final replacement = CuratedListRepository(
          nostrClient: _Nostr(),
          funnelcakeApiClient: _Api(),
        );
        replacement.setSubscribedLists([a, _list(_authorB)]);
        addTearDown(replacement.dispose);
        addTearDown(() async {
          if (!backend.release.isCompleted) backend.release.complete();
          if (!backend.releaseRepair.isCompleted) {
            backend.releaseRepair.complete();
          }
          await closing;
        });
        return (
          old: old,
          closing: closing,
          coordinator: coordinator,
          registry: registry,
          backend: backend,
          replacement: replacement,
        );
      }

      test(
        'replacement reads accepted A while old fallback is provisional',
        () async {
          final setup = await blockedReplacement();
          final current = bloc(
            coordinator: setup.coordinator,
            repository: setup.replacement,
          );
          addTearDown(current.close);
          await waitFor(
            current,
            (s) => s.status == VideoFeedStatus.success,
            () => current.add(const VideoFeedStarted()),
          );
          expect(current.state.source, _source(_list(_authorA)));
          setup.backend.release.complete();
          await setup.closing;
          await preferences.reload();
          expect(current.state.source, _source(_list(_authorA)));
          expect(
            preferences.getString(_key),
            _stored(_source(_list(_authorA))),
          );
        },
      );

      test(
        'closed old completion repairs the replacement explicit B choice',
        () async {
          final setup = await blockedReplacement();
          final current = bloc(
            coordinator: setup.coordinator,
            repository: setup.replacement,
          );
          addTearDown(current.close);
          await waitFor(
            current,
            (s) => s.status == VideoFeedStatus.success,
            () => current.add(const VideoFeedStarted()),
          );
          final b = _source(_list(_authorB));
          await waitFor(
            current,
            (s) => s.status == VideoFeedStatus.success && s.source == b,
            () => current.add(VideoFeedSourceChanged(b)),
          );
          setup.backend.release.complete();
          await setup.closing;
          await preferences.reload();
          expect(current.state.source, b);
          expect(preferences.getString(_key), _stored(b));
        },
      );

      test(
        'another account key is isolated from old-owner compensation',
        () async {
          final setup = await blockedReplacement();
          final b = _source(_list(_authorB));
          const otherKey = 'selected_feed_mode_$_otherViewer';
          await preferences.setString(otherKey, _stored(b));
          final otherCoordinator = FeedModePersistenceCoordinator(
            sharedPreferences: preferences,
            userPubkey: _otherViewer,
          );
          final current = bloc(
            coordinator: otherCoordinator,
            repository: setup.replacement,
            viewer: _otherViewer,
          );
          addTearDown(current.close);
          await waitFor(
            current,
            (s) => s.status == VideoFeedStatus.success,
            () => current.add(const VideoFeedStarted()),
          );
          setup.backend.release.complete();
          await setup.closing;
          await preferences.reload();
          expect(current.state.source, b);
          expect(preferences.getString(otherKey), _stored(b));
          expect(
            preferences.getString(_key),
            _stored(_source(_list(_authorA))),
          );
        },
      );

      test(
        'retired account completion preserves the guest global choice',
        () async {
          final setup = await blockedReplacement();
          setup.coordinator.dispose();
          final guest = FeedModePreferenceStore(
            sharedPreferences: preferences,
            userPubkey: null,
            followRepository: follows,
            curatedListRepository: setup.replacement,
          );
          await guest.persist(const VideoFeedSource.newVideos());
          setup.backend.release.complete();
          await setup.closing;
          await preferences.reload();
          expect(preferences.getString('selected_feed_mode'), 'latest');
          expect(
            preferences.getString(_key),
            _stored(_source(_list(_authorA))),
          );
        },
      );

      test(
        'DeviceScope returning account latest B survives old same-key repair',
        () async {
          final setup = await blockedReplacement(deviceOwned: true);
          final device = DeviceScope(
            database: _Database(),
            sharedPreferences: preferences,
            feedModePersistence: setup.registry!,
            switchController: AccountSwitchController(),
            appVersion: 'test',
            documentsPath: '',
            crashReporting: CrashReportingService(),
            startupPerformance: StartupPerformanceService(
              crashReporting: CrashReportingService(),
            ),
            logMessageBatcher: LogMessageBatcher(),
          );
          final leavingContainer = buildAccountContainer(device);
          expect(
            leavingContainer
                .read(feedModePersistenceRegistryProvider)
                .forAccount(_viewer),
            same(setup.coordinator),
          );
          leavingContainer.dispose();
          final otherContainer = buildAccountContainer(device);
          final other = bloc(
            coordinator: otherContainer
                .read(feedModePersistenceRegistryProvider)
                .forAccount(_otherViewer),
            repository: setup.replacement,
            viewer: _otherViewer,
          );
          await waitFor(
            other,
            (s) => s.status == VideoFeedStatus.success,
            () => other.add(const VideoFeedStarted()),
          );
          await other.close();
          otherContainer.dispose();
          final returnedContainer = buildAccountContainer(device);
          addTearDown(returnedContainer.dispose);
          final returned = bloc(
            coordinator: returnedContainer
                .read(feedModePersistenceRegistryProvider)
                .forAccount(_viewer),
            repository: setup.replacement,
          );
          addTearDown(returned.close);
          await waitFor(
            returned,
            (s) => s.status == VideoFeedStatus.success,
            () => returned.add(const VideoFeedStarted()),
          );
          final b = _source(_list(_authorB));
          await waitFor(
            returned,
            (s) => s.status == VideoFeedStatus.success && s.source == b,
            () => returned.add(VideoFeedSourceChanged(b)),
          );
          setup.backend.release.complete();
          await setup.closing;
          await preferences.reload();
          expect(returned.state.source, b);
          expect(preferences.getString(_key), _stored(b));
        },
      );

      test(
        'device-owned old account repair cannot clear the guest choice',
        () async {
          final setup = await blockedReplacement(deviceOwned: true);
          final guest = FeedModePreferenceStore(
            sharedPreferences: preferences,
            userPubkey: null,
            followRepository: follows,
            curatedListRepository: setup.replacement,
            persistenceCoordinator: setup.registry!.forAccount(null),
          );
          await guest.persist(const VideoFeedSource.newVideos());
          setup.backend.release.complete();
          await setup.closing;
          await preferences.reload();
          expect(preferences.getString('selected_feed_mode'), 'latest');
          expect(
            preferences.getString(_key),
            _stored(_source(_list(_authorA))),
          );
        },
      );

      for (final result in _RemovalResult.values) {
        test(
          'late native legacy removal $result preserves guest choice',
          () async {
            final a = _list(_authorA);
            SharedPreferences.setMockInitialValues({});
            final backend = _GatedLegacyRemoval(
              _stored(_source(a)),
              result,
            );
            SharedPreferencesStorePlatform.instance = backend;
            preferences = await SharedPreferences.getInstance();
            addTearDown(() {
              if (!backend.release.isCompleted) backend.release.complete();
              SharedPreferences.setMockInitialValues({});
            });
            final registry = FeedModePersistenceRegistry(
              sharedPreferences: preferences,
            );
            lists.setSubscribedLists([a]);
            final error = Completer<Object>();
            late VideoFeedBloc old;
            runZonedGuarded(
              () => old = bloc(coordinator: registry.forAccount(_viewer)),
              (failure, _) => error.complete(failure),
            );
            await waitFor(
              old,
              (s) => s.status == VideoFeedStatus.success,
              () => old.add(const VideoFeedStarted()),
            );
            lists.setSubscribedLists([]);
            await backend.started.future.timeout(const Duration(seconds: 5));
            final closing = old.close();
            addTearDown(() async {
              if (!backend.release.isCompleted) backend.release.complete();
              await closing;
            });
            final guest = FeedModePreferenceStore(
              sharedPreferences: preferences,
              userPubkey: null,
              followRepository: follows,
              curatedListRepository: lists,
              persistenceCoordinator: registry.forAccount(null),
            );
            expect(guest.savedValue(), 'classic');
            await guest.persist(const VideoFeedSource.newVideos());
            backend.release.complete();
            if (result != _RemovalResult.succeeds) {
              final failure = await error.future.timeout(
                const Duration(seconds: 5),
              );
              expect(failure, isA<StateError>());
              expect(
                failure.toString(),
                contains(
                  result == _RemovalResult.throwsError
                      ? 'The native legacy clear failed.'
                      : 'The Home selection could not be persisted.',
                ),
              );
            }
            await closing;
            await preferences.reload();
            expect(guest.savedValue(), 'latest');
            expect(preferences.getString('selected_feed_mode'), 'latest');
            expect(preferences.getString(_key), _stored(_source(a)));
            expect(error.isCompleted, result != _RemovalResult.succeeds);
          },
        );
      }

      for (final throwsWrite in [true, false]) {
        test(
          '${throwsWrite ? 'throwing' : 'rejected'} provisional write preserves accepted selection for replacement',
          () async {
            final a = _list(_authorA);
            final backend = await gatePreferences(
              savedValue: _stored(_source(a)),
              blockedValue: 'forYou',
              throwBlockedWrite: throwsWrite,
              rejectBlockedWrite: !throwsWrite,
            );
            final coordinator = FeedModePersistenceCoordinator(
              sharedPreferences: preferences,
              userPubkey: _viewer,
            );
            lists.setSubscribedLists([a]);
            late VideoFeedBloc old;
            final failure = Completer<Object>();
            runZonedGuarded(
              () => old = bloc(coordinator: coordinator),
              (error, _) => failure.complete(error),
            );
            addTearDown(old.close);
            await waitFor(
              old,
              (s) => s.status == VideoFeedStatus.success,
              () => old.add(const VideoFeedStarted()),
            );
            lists.setSubscribedLists([]);
            await backend.started.future.timeout(const Duration(seconds: 5));
            backend.release.complete();
            final error = await failure.future.timeout(
              const Duration(seconds: 5),
            );
            expect(error, isA<StateError>());
            expect(
              error.toString(),
              contains(
                throwsWrite
                    ? 'The platform write failed.'
                    : 'The Home selection could not be persisted.',
              ),
            );
            await old.close();
            lists.setSubscribedLists([a]);
            final current = bloc(coordinator: coordinator);
            addTearDown(current.close);
            await waitFor(
              current,
              (s) => s.status == VideoFeedStatus.success,
              () => current.add(const VideoFeedStarted()),
            );
            await preferences.reload();
            expect(current.state.source, _source(a));
            expect(preferences.getString(_key), _stored(_source(a)));
          },
        );
      }

      test(
        'third replacement choice wins while closed-owner repair is blocked',
        () async {
          final b = _source(_list(_authorB));
          final setup = await blockedReplacement(
            blockedRepairValue: _stored(b),
          );
          final current = bloc(
            coordinator: setup.coordinator,
            repository: setup.replacement,
          );
          addTearDown(current.close);
          await waitFor(
            current,
            (s) => s.status == VideoFeedStatus.success,
            () => current.add(const VideoFeedStarted()),
          );
          await waitFor(
            current,
            (s) => s.status == VideoFeedStatus.success && s.source == b,
            () => current.add(VideoFeedSourceChanged(b)),
          );
          setup.backend.release.complete();
          await setup.backend.repairStarted.future.timeout(
            const Duration(seconds: 5),
          );
          await waitFor(
            current,
            (s) =>
                s.status == VideoFeedStatus.success &&
                s.source == const VideoFeedSource.forYou(),
            () => current.add(
              const VideoFeedSourceChanged(VideoFeedSource.forYou()),
            ),
          );
          setup.backend.releaseRepair.complete();
          await setup.closing;
          await preferences.reload();
          expect(current.state.source, const VideoFeedSource.forYou());
          expect(preferences.getString(_key), 'forYou');
        },
      );
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
      await pumpEventQueue();
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

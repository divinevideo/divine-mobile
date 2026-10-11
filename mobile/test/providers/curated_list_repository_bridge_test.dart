// ABOUTME: Regression tests for the curated-list repository provider bridge.
// ABOUTME: Keeps Home feed list selection scoped to subscribed lists and feeds
// ABOUTME: the list search the viewer's own lists.

import 'dart:async';
import 'dart:convert';

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videos_repository/videos_repository.dart';

import '../helpers/committed_list_account.dart';

class _MockCuratedListService extends Mock implements CuratedListService {}

class _MockAuthService extends Mock implements AuthService {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

const _otherAuthor =
    '2222222222222222222222222222222222222222222222222222222222222222';

const _viewer =
    '1111111111111111111111111111111111111111111111111111111111111111';

void main() {
  group('curated list repository bridge', () {
    void completeService(
      _MockCuratedListService service, {
      List<CuratedList> subscribed = const [],
      List<CuratedList>? cached,
      Set<String>? knownIds,
    }) {
      when(() => service.isCurrentSession).thenReturn(true);
      when(() => service.isInitialized).thenReturn(true);
      when(() => service.initializationError).thenReturn(null);
      when(() => service.hasLoadedSubscriptionIds).thenReturn(true);
      when(() => service.subscribedLists).thenReturn(subscribed);
      when(() => service.lists).thenReturn(cached ?? subscribed);
      when(() => service.subscribedListIds).thenReturn(
        knownIds ?? subscribed.map((list) => list.authorScopedId).toSet(),
      );
    }

    test('complete empty metadata is authoritative', () {
      final service = _MockCuratedListService();
      when(() => service.isCurrentSession).thenReturn(true);
      completeService(service);

      expect(hasCompleteSubscriptionSnapshotForHomeBridge(service), isTrue);
    });

    test(
      'retired, uninitialized, failed and unreadable states are incomplete',
      () {
        final service = _MockCuratedListService();
        when(() => service.isCurrentSession).thenReturn(true);
        completeService(service);
        when(() => service.isCurrentSession).thenReturn(false);
        expect(hasCompleteSubscriptionSnapshotForHomeBridge(service), isFalse);
        completeService(service);
        when(() => service.isInitialized).thenReturn(false);
        expect(hasCompleteSubscriptionSnapshotForHomeBridge(service), isFalse);
        completeService(service);
        when(() => service.initializationError)
            .thenReturn(Exception('recovery'));
        expect(hasCompleteSubscriptionSnapshotForHomeBridge(service), isFalse);
        completeService(service);
        when(() => service.hasLoadedSubscriptionIds).thenReturn(false);
        expect(hasCompleteSubscriptionSnapshotForHomeBridge(service), isFalse);
      },
    );

    test('two qualified follows remain complete despite identical raw IDs', () {
      final service = _MockCuratedListService();
      when(() => service.isCurrentSession).thenReturn(true);
      final alice = _curatedList(id: 'same', pubkey: _viewer);
      final bob = _curatedList(id: 'same', pubkey: _otherAuthor);
      completeService(service, subscribed: [alice, bob]);

      expect(subscribedListsForHomeBridge(service), [alice, bob]);
      expect(hasCompleteSubscriptionSnapshotForHomeBridge(service), isTrue);
    });

    test(
      'known follow missing its copy is incomplete even with another author',
      () {
        final service = _MockCuratedListService();
        when(() => service.isCurrentSession).thenReturn(true);
        final bob = _curatedList(id: 'same', pubkey: _otherAuthor);
        completeService(
          service,
          subscribed: [bob],
          knownIds: {bob.authorScopedId, '$_viewer:same'},
        );

        expect(hasCompleteSubscriptionSnapshotForHomeBridge(service), isFalse);
      },
    );

    test(
      'a single known bare follow resolves only its unique cached identity',
      () {
        final service = _MockCuratedListService();
        when(() => service.isCurrentSession).thenReturn(true);
        final alice = _curatedList(id: 'series:cats', pubkey: _viewer);
        completeService(
          service,
          subscribed: [alice],
          knownIds: {'series:cats'},
        );

        expect(hasCompleteSubscriptionSnapshotForHomeBridge(service), isTrue);
      },
    );

    test('owned-first legacy selection cannot prove snapshot uniqueness', () {
      final service = _MockCuratedListService();
      when(() => service.isCurrentSession).thenReturn(true);
      final alice = _curatedList(id: 'same', pubkey: _viewer);
      final bob = _curatedList(id: 'same', pubkey: _otherAuthor);
      completeService(
        service,
        subscribed: [alice],
        cached: [alice, bob],
        knownIds: {'same'},
      );

      expect(hasCompleteSubscriptionSnapshotForHomeBridge(service), isFalse);
    });

    test(
      'absent bare follow and cached but unfollowed copy stay incomplete',
      () {
        final service = _MockCuratedListService();
        when(() => service.isCurrentSession).thenReturn(true);
        completeService(service, knownIds: {'missing'});
        expect(hasCompleteSubscriptionSnapshotForHomeBridge(service), isFalse);

        completeService(
          service,
          cached: [_curatedList(id: 'missing', pubkey: _viewer)],
          knownIds: {'missing'},
        );
        expect(hasCompleteSubscriptionSnapshotForHomeBridge(service), isFalse);
      },
    );

    test(
      'authorless followed cache remains incomplete without guessing an owner',
      () {
        final service = _MockCuratedListService();
        when(() => service.isCurrentSession).thenReturn(true);
        final authorless = _curatedList(id: 'legacy');
        completeService(
          service,
          subscribed: [authorless],
          knownIds: {'legacy'},
        );

        expect(hasCompleteSubscriptionSnapshotForHomeBridge(service), isFalse);
        expect(subscribedListsForHomeBridge(service), isEmpty);
        expect(service.subscribedLists, [authorless]);
        expect(authorless.pubkey, isNull);
      },
    );

    for (final author in <String?>[null, '', 'incomplete-key']) {
      test(
        'unknown author $author is withheld while valid subscribed copies remain visible',
        () {
          final service = _MockCuratedListService();
          final unknown = _curatedList(id: 'unknown', pubkey: author);
          final valid = _curatedList(id: 'valid', pubkey: _otherAuthor);
          completeService(service, subscribed: [unknown, valid]);

          expect(subscribedListsForHomeBridge(service), [valid]);
          expect(
            hasCompleteSubscriptionSnapshotForHomeBridge(service),
            isFalse,
          );
          expect(service.subscribedLists, [unknown, valid]);
          expect(service.subscribedListIds, {
            unknown.authorScopedId,
            valid.authorScopedId,
          });
        },
      );
    }

    CuratedListRepository createRepository() {
      final repository = CuratedListRepository(
        nostrClient: _MockNostrClient(),
        funnelcakeApiClient: _MockFunnelcakeApiClient(),
      );
      addTearDown(repository.dispose);
      return repository;
    }

    test('retired subscription and own rows are excluded by both helpers', () {
      final service = _MockCuratedListService();
      when(() => service.isCurrentSession).thenReturn(false);
      when(() => service.subscribedLists).thenReturn([
        _curatedList(id: 'private', pubkey: _viewer),
      ]);
      when(() => service.myLists).thenReturn([
        _curatedList(id: 'draft').copyWith(videoEventIds: ['video']),
      ]);

      expect(subscribedListsForHomeBridge(service), isEmpty);
      expect(
        ownListsForSearchBridge(service, viewerPubkey: _otherAuthor),
        isEmpty,
      );
      verifyNever(() => service.subscribedLists);
      verifyNever(() => service.myLists);
    });

    test(
      'initial replay never seeds a new repository from the previous account',
      () {
        final service = _MockCuratedListService();
        completeService(service);
        when(() => service.isCurrentSession).thenReturn(false);
        final repository = createRepository();
        syncCuratedListRepositoryBridge(
          repository,
          service,
          viewerPubkey: _otherAuthor,
          isDataReady: true,
        );

        expect(repository.getSubscribedLists(), isEmpty);
        expect(repository.searchLists('draft'), isEmpty);
        expect(repository.hasCompleteSubscriptionSnapshot, isFalse);
        verifyNever(() => service.myLists);
      },
    );

    test(
      'loading transition clears retired rows instead of retaining them',
      () {
        final service = _MockCuratedListService();
        final private = _curatedList(id: 'private', pubkey: _viewer);
        completeService(service, subscribed: [private]);
        when(() => service.myLists).thenReturn([
          _curatedList(id: 'draft').copyWith(videoEventIds: ['video']),
        ]);
        final repository = createRepository();
        syncCuratedListRepositoryBridge(
          repository,
          service,
          viewerPubkey: _viewer,
          isDataReady: true,
        );
        expect(repository.getSubscribedLists(), [private]);
        when(() => service.isCurrentSession).thenReturn(false);
        syncCuratedListRepositoryBridge(
          repository,
          service,
          viewerPubkey: _otherAuthor,
          isDataReady: false,
        );

        expect(repository.getSubscribedLists(), isEmpty);
        expect(repository.getListById(private.authorScopedId), isNull);
        expect(repository.searchLists('draft'), isEmpty);
        expect(repository.hasCompleteSubscriptionSnapshot, isFalse);
      },
    );

    test('current loading/error snapshots retain only current cached rows', () {
      final service = _MockCuratedListService();
      final cached = _curatedList(id: 'current', pubkey: _viewer);
      completeService(service, subscribed: [cached]);
      when(() => service.myLists).thenReturn([
        _curatedList(id: 'draft').copyWith(videoEventIds: ['video']),
      ]);
      final repository = createRepository();
      syncCuratedListRepositoryBridge(
        repository,
        service,
        viewerPubkey: _viewer,
        isDataReady: true,
      );
      expect(repository.hasCompleteSubscriptionSnapshot, isTrue);
      syncCuratedListRepositoryBridge(
        repository,
        service,
        viewerPubkey: _viewer,
        isDataReady: false,
      );

      expect(repository.getSubscribedLists(), [cached]);
      expect(repository.getListById(cached.authorScopedId), cached);
      expect(repository.hasCompleteSubscriptionSnapshot, isFalse);
    });

    test('missing current service drops previous cached snapshots', () {
      final repository = createRepository();
      repository
        ..setSubscribedLists([_curatedList(id: 'previous')])
        ..setOwnLists([_curatedList(id: 'previous draft')]);
      syncCuratedListRepositoryBridge(
        repository,
        null,
        viewerPubkey: _otherAuthor,
        isDataReady: false,
      );
      expect(repository.getSubscribedLists(), isEmpty);
      expect(repository.searchLists('previous'), isEmpty);
      expect(repository.hasCompleteSubscriptionSnapshot, isFalse);
    });

    test('selects subscribed lists instead of all service lists', () {
      final service = _MockCuratedListService();
      when(() => service.isCurrentSession).thenReturn(true);
      final subscribedList = _curatedList(
        id: 'subscribed-list',
        pubkey: _otherAuthor,
      );
      final discoveredList = _curatedList(id: 'discovered-list');

      when(() => service.lists).thenReturn([subscribedList, discoveredList]);
      when(() => service.subscribedLists).thenReturn([subscribedList]);

      expect(
        subscribedListsForHomeBridge(service),
        [subscribedList],
      );
    });

    test("hands the list search the viewer's own lists", () {
      final service = _MockCuratedListService();
      when(() => service.isCurrentSession).thenReturn(true);
      final ownList = _curatedList(id: 'own-list', pubkey: _viewer);
      final subscribedList = _curatedList(id: 'subscribed-list');

      when(() => service.myLists).thenReturn([ownList]);
      when(() => service.subscribedLists).thenReturn([subscribedList]);

      expect(
        ownListsForSearchBridge(service, viewerPubkey: _viewer),
        [ownList],
      );
    });

    test('files an own list without an author under the viewer', () {
      // The repository keys lists by author, so a draft without one would sit
      // beside its own relay copy instead of replacing it.
      final service = _MockCuratedListService();
      when(() => service.isCurrentSession).thenReturn(true);
      final draft = _curatedList(id: 'draft');

      when(() => service.myLists).thenReturn([draft]);

      final [stamped] = ownListsForSearchBridge(
        service,
        viewerPubkey: _viewer,
      );

      expect(stamped.pubkey, _viewer);
      expect(stamped.authorScopedId, '$_viewer:draft');
    });

    test('leaves an authorless own list alone while signed out', () {
      final service = _MockCuratedListService();
      when(() => service.isCurrentSession).thenReturn(true);
      final draft = _curatedList(id: 'draft');

      when(() => service.myLists).thenReturn([draft]);

      expect(ownListsForSearchBridge(service, viewerPubkey: null), [draft]);
    });

    test('real unknown-author follow preserves raw preference until a decoded author arrives', () async {
      registerFallbackValue(<Filter>[]);
      const rawId = 'legacy:cats';
      const eventId =
          '3333333333333333333333333333333333333333333333333333333333333333';
      const key = 'selected_feed_mode_$_viewer';
      final unknown = _curatedList(id: rawId).copyWith(nostrEventId: eventId);
      final draft = _curatedList(id: 'owned-draft')
          .copyWith(videoEventIds: [eventId]);
      final storedRows = jsonEncode([unknown.toJson(), draft.toJson()]);
      final storedFollows = jsonEncode([rawId]);
      SharedPreferences.setMockInitialValues({
        CuratedListService.listsStorageKey: storedRows,
        CuratedListService.subscribedListsStorageKey: storedFollows,
        CuratedListService.defaultListDeletedStorageKey: true,
        key: 'list:$rawId',
      });
      final prefs = await SharedPreferences.getInstance();
      final services = <CuratedListService>[];
      final streams = <StreamController<Event>>[];
      addTearDown(() async {
        for (final service in services) {
          service.dispose();
        }
        for (final stream in streams) {
          await stream.close();
        }
        await pumpEventQueue();
      });
      // Hydrating an unresolved row reopens the list cache in the same account;
      // it does not replace that account's activation with a second identity.
      final auth = _MockAuthService();
      when(() => auth.isAuthenticated).thenReturn(true);
      when(() => auth.currentPublicKeyHex).thenReturn(_viewer);
      await stubCommittedListAccount(auth: auth, preferences: prefs);
      Future<CuratedListService> open() async {
        final nostr = _MockNostrClient();
        final stream = StreamController<Event>.broadcast();
        streams.add(stream);
        when(
          () => nostr.subscribe(
            any(),
            closeOnEose: true,
            onEose: any(named: 'onEose'),
          ),
        ).thenAnswer((_) => stream.stream);
        when(() => nostr.subscribe(any(), closeOnEose: true))
            .thenAnswer((_) => stream.stream);
        when(() => nostr.subscribe(any())).thenAnswer((_) => stream.stream);
        final service = CuratedListService(
          nostrService: nostr,
          authService: auth,
          prefs: prefs,
        );
        services.add(service);
        await service.initialize();
        expect(service.isInitialized, isTrue);
        expect(service.initializationError, isNull);
        expect(stream.hasListener, isTrue);
        return service;
      }

      final unresolved = await open();
      final repository = CuratedListRepository(
        nostrClient: _MockNostrClient(),
        funnelcakeApiClient: _MockFunnelcakeApiClient(),
      );
      addTearDown(repository.dispose);
      syncCuratedListRepositoryBridge(
        repository,
        unresolved,
        viewerPubkey: _viewer,
        isDataReady: true,
      );
      expect(unresolved.subscribedLists.single.pubkey, isNull);
      expect(repository.getSubscribedLists(), isEmpty);
      expect(repository.hasCompleteSubscriptionSnapshot, isFalse);
      expect(repository.searchLists('owned-draft').single.pubkey, _viewer);
      expect(prefs.getString(CuratedListService.listsStorageKey), storedRows);
      expect(
        prefs.getString(CuratedListService.subscribedListsStorageKey),
        storedFollows,
      );
      final follows = _MockFollowRepository();
      when(() => follows.followingPubkeys).thenReturn(const []);
      when(() => follows.followingStream)
          .thenAnswer((_) => const Stream.empty());
      final videos = _MockVideosRepository();
      when(
        () => videos.getRecommendedVideos(
          userPubkey: any(named: 'userPubkey'),
          limit: any(named: 'limit'),
          until: any(named: 'until'),
          skipCache: any(named: 'skipCache'),
          revalidate: any(named: 'revalidate'),
        ),
      ).thenAnswer((_) async => const HomeFeedResult(videos: []));
      when(() => videos.getVideosForList(any())).thenAnswer((_) async => []);
      final home = VideoFeedBloc(
        videosRepository: videos,
        followRepository: follows,
        curatedListRepository: repository,
        userPubkey: _viewer,
        sharedPreferences: prefs,
        serveCachedHomeFeed: false,
      );
      addTearDown(home.close);
      final started = home.stream.firstWhere(
        (state) => state.status == VideoFeedStatus.success,
      );
      home.add(const VideoFeedStarted());
      await started.timeout(const Duration(seconds: 5));
      expect(home.state.source, const VideoFeedSource.forYou());
      expect(prefs.getString(key), 'list:$rawId');

      // A decoded relay row supplies its full author. The guard does not repair,
      // delete, or attribute the old cache; this represents verified hydration.
      final relay = Event(
        _otherAuthor,
        30005,
        [
          ['d', rawId],
          ['title', rawId],
          ['e', eventId],
        ],
        '',
        createdAt: DateTime(2026, 5, 19).millisecondsSinceEpoch ~/ 1000,
      );
      final verified = CuratedListConverter.fromEvent(relay)!;
      await prefs.setString(
        CuratedListService.listsStorageKey,
        jsonEncode([verified.toJson(), draft.toJson()]),
      );
      final hydrated = await open();
      final restored = home.stream.firstWhere(
        (state) =>
            state.status == VideoFeedStatus.success &&
            state.source.listId == verified.authorScopedId,
      );
      syncCuratedListRepositoryBridge(
        repository,
        hydrated,
        viewerPubkey: _viewer,
        isDataReady: true,
      );
      await restored.timeout(const Duration(seconds: 5));
      expect(repository.hasCompleteSubscriptionSnapshot, isTrue);
      expect(repository.getSubscribedLists(), [verified]);
      expect(home.state.source.listId, '$_otherAuthor:$rawId');
      expect(prefs.getString(key), 'curated:$_otherAuthor:$rawId');
      expect(
        prefs.getString(CuratedListService.subscribedListsStorageKey),
        storedFollows,
      );
      expect(
        unresolved.lists.firstWhere((list) => list.id == rawId).pubkey,
        isNull,
      );
      expect(repository.searchLists('owned-draft').single.pubkey, _viewer);
    });
  });
}

CuratedList _curatedList({required String id, String? pubkey}) {
  final now = DateTime(2026, 5, 19);
  return CuratedList(
    id: id,
    name: id,
    pubkey: pubkey,
    videoEventIds: const [],
    createdAt: now,
    updatedAt: now,
  );
}

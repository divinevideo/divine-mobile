// ABOUTME: Regression tests for the curated-list repository provider bridge.
// ABOUTME: Keeps Home feed list selection scoped to subscribed lists and feeds
// ABOUTME: the list search the viewer's own lists.

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/curated_list_service.dart';

class _MockCuratedListService extends Mock implements CuratedListService {}

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

    test('complete authorless follow does not infer an owner', () {
      final service = _MockCuratedListService();
      when(() => service.isCurrentSession).thenReturn(true);
      final authorless = _curatedList(id: 'legacy');
      completeService(service, subscribed: [authorless], knownIds: {'legacy'});

      expect(hasCompleteSubscriptionSnapshotForHomeBridge(service), isTrue);
      expect(subscribedListsForHomeBridge(service).single.pubkey, isNull);
    });

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
      final subscribedList = _curatedList(id: 'subscribed-list');
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

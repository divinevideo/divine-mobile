import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:test/test.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

const _authorA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _authorB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _viewer =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

CuratedList _list({
  String id = defaultListId,
  String? author = _authorA,
  String name = 'My List',
  List<String> videos = const ['video-a'],
  List<String> tags = const ['cats'],
  PlayOrder order = PlayOrder.chronological,
}) => CuratedList(
  id: id,
  pubkey: author,
  name: name,
  videoEventIds: videos,
  tags: tags,
  playOrder: order,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  group('author-qualified subscription identity', () {
    late CuratedListRepository repository;
    late _MockNostrClient client;
    late CuratedList alice;
    late CuratedList bob;

    setUp(() {
      client = _MockNostrClient();
      repository = CuratedListRepository(
        nostrClient: client,
        funnelcakeApiClient: _MockFunnelcakeApiClient(),
      );
      alice = _list();
      bob = _list(
        author: _authorB,
        videos: const ['video-b', 'video-c'],
        tags: const ['skating'],
        order: PlayOrder.reverse,
      );
    });

    tearDown(() async => repository.dispose());

    test(
      'seeded empty snapshot does not authorize preference migration',
      () async {
        expect(repository.hasCompleteSubscriptionSnapshot, isFalse);
        await expectLater(repository.subscribedListsStream, emits(isEmpty));
      },
    );

    test(
      'partial and complete snapshots publish their readiness before emission',
      () async {
        final readiness = <bool>[];
        final subscription = repository.subscribedListsStream.listen((_) {
          readiness.add(repository.hasCompleteSubscriptionSnapshot);
        });
        await Future<void>.delayed(Duration.zero);
        repository.setSubscribedLists([alice], isComplete: false);
        await Future<void>.delayed(Duration.zero);
        repository.setSubscribedLists([alice, bob]);
        await Future<void>.delayed(Duration.zero);
        repository.setSubscribedLists([alice], isComplete: false);
        await Future<void>.delayed(Duration.zero);

        expect(readiness, [false, false, true, false]);
        expect(repository.getListById(alice.authorScopedId), alice);
        await subscription.cancel();
      },
    );

    test(
      'explicitly complete empty snapshot and disposal reset readiness',
      () async {
        repository.setSubscribedLists([]);
        expect(repository.hasCompleteSubscriptionSnapshot, isTrue);
        await repository.dispose();
        expect(repository.hasCompleteSubscriptionSnapshot, isFalse);
      },
    );

    test(
      'queued partial and complete snapshots retain their own metadata',
      () async {
        final snapshots = <CuratedListSubscriptionSnapshot>[];
        final subscription = repository.subscriptionSnapshots.listen(
          snapshots.add,
        );
        await Future<void>.delayed(Duration.zero);
        repository
          ..setSubscribedLists([alice], isComplete: false)
          ..setSubscribedLists([alice, bob])
          ..setSubscribedLists([bob], isComplete: false);
        final latest = repository.subscriptionSnapshot;
        await Future<void>.delayed(Duration.zero);

        expect(snapshots.map((snapshot) => snapshot.isComplete), [
          false,
          false,
          true,
          false,
        ]);
        expect(snapshots.map((snapshot) => snapshot.lists), [
          <CuratedList>[],
          [alice],
          [alice, bob],
          [bob],
        ]);
        expect(identical(snapshots.last, latest), isTrue);
        expect(identical(snapshots[2], latest), isFalse);
        expect(() => latest.lists.add(alice), throwsUnsupportedError);
        await subscription.cancel();
      },
    );

    test('retains both authors even with identical names and d-tags', () {
      repository.setSubscribedLists([alice, bob]);

      expect(repository.getSubscribedLists(), [alice, bob]);
      expect(repository.getListById(alice.authorScopedId), alice);
      expect(repository.getListById(bob.authorScopedId), bob);
      expect(
        () => repository.getSubscribedLists().add(alice),
        throwsUnsupportedError,
      );
    });

    test(
      'replays both complete identities to late stream subscribers',
      () async {
        repository.setSubscribedLists([alice, bob]);

        await expectLater(
          repository.subscribedListsStream,
          emits([alice, bob]),
        );
      },
    );

    test('snapshot replacement removes only the absent identity', () {
      repository
        ..setSubscribedLists([alice, bob])
        ..setSubscribedLists([bob]);

      expect(repository.getSubscribedLists(), [bob]);
      expect(repository.getListById(alice.authorScopedId), isNull);
      expect(repository.getListById(bob.authorScopedId), bob);
      expect(repository.getListById(defaultListId), bob);
    });

    test('last snapshot entry wins only within the same identity', () {
      final newerAlice = alice.copyWith(name: 'Renamed Alice');
      repository.setSubscribedLists([alice, bob, newerAlice]);

      expect(repository.getSubscribedLists(), [newerAlice, bob]);
      expect(repository.getListById(alice.authorScopedId), newerAlice);
    });

    test('ambiguous raw ID never chooses either author or snapshot order', () {
      for (final snapshot in [
        [alice, bob],
        [bob, alice],
      ]) {
        repository.setSubscribedLists(snapshot);

        expect(repository.getListById(defaultListId), isNull);
        expect(repository.isSubscribedToList(defaultListId), isFalse);
        expect(repository.isVideoInList(defaultListId, 'video-a'), isFalse);
        expect(repository.getOrderedVideoIds(defaultListId), isEmpty);
      }
    });

    test('unique raw ID retains legacy query compatibility', () {
      repository.setSubscribedLists([alice]);

      expect(repository.getListById(defaultListId), alice);
      expect(repository.isSubscribedToList(defaultListId), isTrue);
      expect(repository.isVideoInList(defaultListId, 'video-a'), isTrue);
      expect(repository.getOrderedVideoIds(defaultListId), ['video-a']);
    });

    test('scalar queries target their exact author', () {
      repository.setSubscribedLists([alice, bob]);

      expect(repository.isSubscribedToList(alice.authorScopedId), isTrue);
      expect(repository.isSubscribedToList(bob.authorScopedId), isTrue);
      expect(repository.isVideoInList(alice.authorScopedId, 'video-a'), isTrue);
      expect(
        repository.isVideoInList(alice.authorScopedId, 'video-b'),
        isFalse,
      );
      expect(repository.isVideoInList(bob.authorScopedId, 'video-b'), isTrue);
      expect(repository.getOrderedVideoIds(alice.authorScopedId), ['video-a']);
      expect(repository.getOrderedVideoIds(bob.authorScopedId), [
        'video-c',
        'video-b',
      ]);
    });

    test('missing qualified ID never aliases another author or raw ID', () {
      const missingId = '$_viewer:$defaultListId';
      final rawLookalike = _list(id: missingId);
      repository.setSubscribedLists([bob, rawLookalike]);

      expect(repository.getListById(missingId), isNull);
      expect(repository.isSubscribedToList(missingId), isFalse);
      expect(repository.isVideoInList(missingId, 'video-a'), isFalse);
      expect(repository.getOrderedVideoIds(missingId), isEmpty);
      expect(repository.getListById(rawLookalike.authorScopedId), rawLookalike);
    });

    test('exact coordinate wins over a raw d-tag that looks qualified', () {
      final lookalike = _list(id: alice.authorScopedId, author: _authorB);
      repository.setSubscribedLists([lookalike, alice]);

      expect(repository.getListById(alice.authorScopedId), alice);
      expect(repository.getListById(lookalike.authorScopedId), lookalike);
    });

    for (final rawId in ['', 'series:cats:2026', ':playlist', '::playlist']) {
      test('preserves complete d-tag "$rawId" in exact and legacy queries', () {
        final list = _list(id: rawId);
        repository.setSubscribedLists([list]);

        expect(repository.getListById(list.authorScopedId), list);
        expect(repository.getListById(rawId), list);
        expect(repository.getOrderedVideoIds(list.authorScopedId), ['video-a']);
      });
    }

    test(
      'authorless rows stay separate without inferring a foreign author',
      () {
        final authorless = _list(author: null);
        repository.setSubscribedLists([alice, authorless]);

        expect(repository.getSubscribedLists(), [alice, authorless]);
        expect(repository.getListById(':$defaultListId'), authorless);
        expect(repository.getListById(alice.authorScopedId), alice);
        expect(repository.getListById(defaultListId), isNull);
        expect(repository.getListById(bob.authorScopedId), isNull);
      },
    );

    test('unique authorless raw row retains legacy compatibility', () {
      final authorless = _list(author: null);
      repository.setSubscribedLists([authorless]);

      expect(repository.getListById(defaultListId), authorless);
      expect(repository.getListById(':$defaultListId'), authorless);
    });

    test(
      'unique leading-colon raw d-tag does not infer authorless ownership',
      () {
        final lookalike = _list(id: ':$defaultListId');
        repository.setSubscribedLists([lookalike]);

        expect(repository.getListById(':$defaultListId'), lookalike);
        expect(repository.getListById(lookalike.authorScopedId), lookalike);
        expect(lookalike.pubkey, _authorA);
      },
    );

    test(
      'collection queries retain both authors and their independent data',
      () {
        bob = bob.copyWith(videoEventIds: ['video-a', 'video-b']);
        repository.setSubscribedLists([alice, bob]);

        expect(repository.getListsByTag('cats'), [alice]);
        expect(repository.getListsByTag('skating'), [bob]);
        expect(repository.getAllTags(), ['cats', 'skating']);
        expect(repository.getListsContainingVideo('video-a'), [alice, bob]);
        expect(repository.getListsContainingVideo('video-b'), [bob]);
        expect(
          repository.getVideoListSummary('video-a'),
          'In "My List", "My List"',
        );
        expect(repository.searchLists('my list'), [alice, bob]);
      },
    );

    test(
      'own search snapshot preserves authors and same-identity last entry',
      () {
        final newerAlice = alice.copyWith(name: 'My List renamed');
        repository.setOwnLists([alice, bob, newerAlice]);

        expect(repository.searchLists('my list'), [newerAlice, bob]);
        expect(repository.getSubscribedLists(), isEmpty);
        expect(repository.getListById(alice.authorScopedId), isNull);
        repository.setOwnLists([bob]);
        expect(repository.searchLists('my list'), [bob]);
      },
    );

    test('local search deduplicates only an identical owned subscription', () {
      repository
        ..setOwnLists([alice])
        ..setSubscribedLists([alice, bob]);

      expect(repository.searchLists('my list'), [alice, bob]);
    });

    test(
      'every progressive search emission retains both local authors',
      () async {
        registerFallbackValue(Duration.zero);
        when(
          () => client.queryEvents(any(), timeout: any(named: 'timeout')),
        ).thenAnswer((_) async => []);
        repository.setSubscribedLists([alice, bob]);

        final emissions = await repository
            .searchAllLists('my list', maxThumbnails: 0)
            .toList();

        expect(emissions, hasLength(4));
        for (final emission in emissions) {
          expect(emission.map((list) => list.authorScopedId), [
            alice.authorScopedId,
            bob.authorScopedId,
          ]);
        }
      },
    );

    test('default queries require the exact subscribed owner', () {
      repository.setSubscribedLists([alice, bob]);

      expect(repository.getDefaultList(ownerPubkey: _authorA), alice);
      expect(repository.getDefaultList(ownerPubkey: _authorB), bob);
      expect(repository.getDefaultList(ownerPubkey: _viewer), isNull);
      expect(repository.hasDefaultList(ownerPubkey: _authorA), isTrue);
      expect(repository.hasDefaultList(ownerPubkey: _viewer), isFalse);
    });

    test(
      'default query does not infer authorless ownership or own membership',
      () {
        repository
          ..setOwnLists([alice])
          ..setSubscribedLists([_list(author: null), bob]);

        expect(repository.getDefaultList(ownerPubkey: _authorA), isNull);
        expect(repository.getDefaultList(ownerPubkey: ''), isNull);
        expect(repository.hasDefaultList(ownerPubkey: ''), isFalse);
        expect(repository.getDefaultList(ownerPubkey: _authorB), bob);
      },
    );
  });
}

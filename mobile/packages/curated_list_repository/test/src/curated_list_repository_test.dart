import 'dart:async';

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:fake_async/fake_async.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show Event;
import 'package:nostr_sdk/relay/query_result.dart';
import 'package:test/test.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

/// 64-char hex pubkey for test events.
const _testPubkey =
    'aabbccddaabbccddaabbccddaabbccdd'
    'aabbccddaabbccddaabbccddaabbccdd';

/// A second 64-char hex ID used as a video event reference.
const _videoEventId =
    '1111111111111111111111111111111111111111111111111111111111111111';

/// Additional hex IDs for multi-ref thumbnail tests.
const _videoEventId2 =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _videoEventId3 =
    '3333333333333333333333333333333333333333333333333333333333333333';
const _lowerTieEventId =
    '4444444444444444444444444444444444444444444444444444444444444441';
const _higherTieEventId =
    '4444444444444444444444444444444444444444444444444444444444444442';
const _blockedPubkey =
    'ffffffffffffffffffffffffffffffff'
    'ffffffffffffffffffffffffffffffff';

/// Another author, for lists that share a d-tag across accounts.
const _otherPubkey =
    '99999999999999999999999999999999'
    '99999999999999999999999999999999';

/// Creates a kind 30005 Nostr event with the given [tags] and [content].
Event _makeEvent({
  List<List<String>> tags = const [],
  String content = '',
  int? createdAt,
  String pubkey = _testPubkey,
}) {
  return Event(
    pubkey,
    30005,
    tags.map(List<String>.from).toList(),
    content,
    createdAt: createdAt ?? 1718400000,
  );
}

/// Creates a kind 34236 (addressable short video) Nostr event with a
/// thumbnail tag.
Event _makeVideoEvent({String? thumbnail, String dTag = 'test-video'}) {
  return Event(
    _testPubkey,
    34236,
    [
      ['d', dTag],
      ['title', 'Test Video'],
      ['url', 'https://example.com/video.mp4'],
      if (thumbnail != null) ['thumb', thumbnail],
    ],
    '',
    createdAt: 1718400000,
  );
}

/// Creates a kind 34236 video event with a specific [id] for relay
/// batching tests where the returned event must match the queried hex ID.
Event _makeVideoEventWithId(
  String id, {
  String? thumbnail,
  String dTag = 'test-video',
  String pubkey = _testPubkey,
  int kind = 34236,
  int createdAt = 1718400000,
  List<List<String>> extraTags = const [],
}) {
  return Event.fromJson({
    'id': id,
    'pubkey': pubkey,
    'created_at': createdAt,
    'kind': kind,
    'tags': [
      ['d', dTag],
      ['title', 'Test Video'],
      ['url', 'https://example.com/video.mp4'],
      if (thumbnail != null) ['thumb', thumbnail],
      ...extraTags,
    ],
    'content': '',
    'sig': '',
  });
}

VideoStats _previewStats({
  String pubkey = _testPubkey,
  List<String> labels = const [],
  String thumbnail = 'https://example.com/preview.jpg',
}) => VideoStats(
  id: _videoEventId,
  pubkey: pubkey,
  createdAt: DateTime(2025),
  kind: 34236,
  dTag: 'video',
  title: 'Preview',
  thumbnail: thumbnail,
  videoUrl: 'https://example.com/video.mp4',
  reactions: 0,
  comments: 0,
  reposts: 0,
  engagementScore: 0,
  contentWarningLabels: labels,
);

/// The lists of every emission of a search.
Future<List<List<CuratedList>>> _lists(
  Stream<List<CuratedListSearchResult>> search,
) async => [
  for (final results in await search.toList())
    [for (final result in results) result.list],
];

void main() {
  group(CuratedListRepository, () {
    late _MockNostrClient nostrClient;
    late _MockFunnelcakeApiClient funnelcakeApiClient;
    late CuratedListRepository repository;

    final now = DateTime(2025, 6, 15);

    CuratedList createList({
      required String id,
      String name = 'Test List',
      List<String> videoEventIds = const ['fixture-video'],
      String? description,
      String? pubkey,
      bool isPublic = true,
      List<String> tags = const [],
      PlayOrder playOrder = PlayOrder.chronological,
    }) {
      return CuratedList(
        id: id,
        name: name,
        videoEventIds: videoEventIds,
        createdAt: now,
        updatedAt: now,
        pubkey: pubkey,
        description: description,
        isPublic: isPublic,
        tags: tags,
        playOrder: playOrder,
      );
    }

    setUp(() {
      registerFallbackValue(Duration.zero);
      registerFallbackValue(<Filter>[]);
      nostrClient = _MockNostrClient();
      funnelcakeApiClient = _MockFunnelcakeApiClient();
      repository = CuratedListRepository(
        nostrClient: nostrClient,
        funnelcakeApiClient: funnelcakeApiClient,
      );
    });

    tearDown(() async {
      await repository.dispose();
    });

    Future<({List<Event> events, bool timedOut, bool noRelays})>
    thumbnailRead() => nostrClient.queryEventsDetailed(
      any(),
      timeout: any(named: 'timeout'),
      requireAllRelaysSettled: true,
    );

    void answerThumbnailRead(
      List<Event> events, {
      bool timedOut = false,
      bool noRelays = false,
    }) {
      when(thumbnailRead).thenAnswer(
        (_) async => (events: events, timedOut: timedOut, noRelays: noRelays),
      );
    }

    test('can be instantiated', () {
      expect(
        CuratedListRepository(
          nostrClient: _MockNostrClient(),
          funnelcakeApiClient: _MockFunnelcakeApiClient(),
        ),
        isNotNull,
      );
    });

    group('subscribedListsStream', () {
      test('emits initial empty list', () async {
        await expectLater(repository.subscribedListsStream, emits(isEmpty));
      });

      test('emits after setSubscribedLists', () async {
        final list = createList(id: 'list-a', name: 'List A');

        repository.setSubscribedLists([list]);

        await expectLater(
          repository.subscribedListsStream,
          emits(equals([list])),
        );
      });

      test('replays last value to new subscribers', () async {
        final list = createList(id: 'list-a');

        repository.setSubscribedLists([list]);

        // Subscribe after emission — BehaviorSubject replays.
        await expectLater(
          repository.subscribedListsStream,
          emits(equals([list])),
        );
      });

      test('emits unmodifiable list', () async {
        repository.setSubscribedLists([createList(id: 'list-a')]);

        final emitted = await repository.subscribedListsStream.first;

        expect(
          () => emitted.add(createList(id: 'hack')),
          throwsA(isA<UnsupportedError>()),
        );
      });
    });

    group('dispose', () {
      test('closes stream', () async {
        await repository.dispose();

        await expectLater(
          repository.subscribedListsStream,
          emitsInOrder(<dynamic>[isEmpty, emitsDone]),
        );
      });

      test('is idempotent', () async {
        await repository.dispose();
        await repository.dispose();

        // No exception thrown.
      });

      test('setSubscribedLists after dispose does not throw', () async {
        await repository.dispose();

        // Should not throw even though stream is closed.
        expect(
          () => repository.setSubscribedLists([createList(id: 'x')]),
          returnsNormally,
        );
      });
    });

    group('getListById', () {
      test('returns null when no lists are set', () {
        expect(repository.getListById('nonexistent'), isNull);
      });

      test('returns null for unknown ID', () {
        repository.setSubscribedLists([createList(id: 'list-a')]);

        expect(repository.getListById('unknown'), isNull);
      });

      test('returns correct list by ID', () {
        final listA = createList(id: 'list-a', name: 'List A');
        final listB = createList(id: 'list-b', name: 'List B');
        repository.setSubscribedLists([listA, listB]);

        expect(repository.getListById('list-a'), equals(listA));
        expect(repository.getListById('list-b'), equals(listB));
      });
    });

    group('setSubscribedLists', () {
      test('replaces previous data', () {
        repository
          ..setSubscribedLists([
            createList(id: 'old-list', videoEventIds: ['old-video']),
          ])
          ..setSubscribedLists([
            createList(id: 'new-list', videoEventIds: ['new-video']),
          ]);

        expect(repository.getListById('old-list'), isNull);
        expect(repository.getListById('new-list'), isNotNull);

        final lists = repository.getSubscribedLists();
        expect(lists, hasLength(1));
        expect(lists.first.id, equals('new-list'));
      });

      test('clears all data when set with empty list', () {
        repository
          ..setSubscribedLists([
            createList(id: 'list-a', videoEventIds: ['video']),
          ])
          ..setSubscribedLists([]);

        expect(repository.getSubscribedLists(), isEmpty);
        expect(repository.getListById('list-a'), isNull);
      });

      test('handles duplicate IDs by keeping the last one', () {
        repository.setSubscribedLists([
          createList(id: 'same-id', name: 'First'),
          createList(id: 'same-id', name: 'Second'),
        ]);

        expect(repository.getListById('same-id')?.name, equals('Second'));
      });
    });

    group('getSubscribedLists', () {
      test('returns empty list initially', () {
        expect(repository.getSubscribedLists(), isEmpty);
      });

      test('returns all subscribed lists', () {
        final listA = createList(id: 'a');
        final listB = createList(id: 'b');
        repository.setSubscribedLists([listA, listB]);

        expect(repository.getSubscribedLists(), hasLength(2));
        expect(repository.getSubscribedLists(), contains(listA));
        expect(repository.getSubscribedLists(), contains(listB));
      });

      test('returns unmodifiable list', () {
        repository.setSubscribedLists([createList(id: 'a')]);

        expect(
          () => repository.getSubscribedLists().add(createList(id: 'hack')),
          throwsA(isA<UnsupportedError>()),
        );
      });
    });

    group('isSubscribedToList', () {
      test('returns false for unknown list', () {
        expect(repository.isSubscribedToList('unknown'), isFalse);
      });

      test('returns true for subscribed list', () {
        repository.setSubscribedLists([createList(id: 'list-a')]);

        expect(repository.isSubscribedToList('list-a'), isTrue);
      });
    });

    group('isVideoInList', () {
      test('returns false for unknown list', () {
        expect(repository.isVideoInList('unknown', 'video-1'), isFalse);
      });

      test('returns false when video is not in list', () {
        repository.setSubscribedLists([
          createList(id: 'list-a', videoEventIds: ['video-1']),
        ]);

        expect(repository.isVideoInList('list-a', 'video-2'), isFalse);
      });

      test('returns true when video is in list', () {
        repository.setSubscribedLists([
          createList(id: 'list-a', videoEventIds: ['video-1', 'video-2']),
        ]);

        expect(repository.isVideoInList('list-a', 'video-2'), isTrue);
      });
    });

    group('hasDefaultList', () {
      test('returns false when no default list exists', () {
        repository.setSubscribedLists([createList(id: 'other')]);

        expect(repository.hasDefaultList(ownerPubkey: _testPubkey), isFalse);
      });

      test('returns true when default list exists', () {
        repository.setSubscribedLists([
          createList(id: defaultListId, pubkey: _testPubkey),
        ]);

        expect(repository.hasDefaultList(ownerPubkey: _testPubkey), isTrue);
      });
    });

    group('getDefaultList', () {
      test('returns null when no default list exists', () {
        expect(repository.getDefaultList(ownerPubkey: _testPubkey), isNull);
      });

      test('returns the default list', () {
        final myList = createList(
          id: defaultListId,
          name: 'My List',
          pubkey: _testPubkey,
        );
        repository.setSubscribedLists([myList]);

        expect(
          repository.getDefaultList(ownerPubkey: _testPubkey),
          equals(myList),
        );
      });
    });

    group('searchLists', () {
      test("matches the viewer's own public lists", () {
        repository
          ..setOwnLists([
            createList(id: 'mine', name: 'Top Dance', pubkey: _testPubkey),
          ])
          ..setSubscribedLists([createList(id: 'other', name: 'Cooking')]);

        final results = repository.searchLists('dance');

        expect(results.map((l) => l.id), equals(['mine']));
      });

      test("excludes the viewer's own private lists", () {
        repository.setOwnLists([
          createList(id: 'mine', name: 'Secret Dance', isPublic: false),
        ]);

        expect(repository.searchLists('dance'), isEmpty);
      });

      test('reports a list that is both owned and subscribed once', () {
        final list = createList(id: 'a', name: 'Dance', pubkey: _testPubkey);
        repository
          ..setOwnLists([list])
          ..setSubscribedLists([list]);

        expect(repository.searchLists('dance'), hasLength(1));
      });

      test('returns empty for blank query', () {
        repository.setSubscribedLists([createList(id: 'a', name: 'Test')]);

        expect(repository.searchLists(''), isEmpty);
        expect(repository.searchLists('   '), isEmpty);
      });

      test('matches by name case-insensitively', () {
        repository.setSubscribedLists([
          createList(id: 'a', name: 'Dance Moves'),
          createList(id: 'b', name: 'Cooking Tips'),
        ]);

        final results = repository.searchLists('dance');

        expect(results, hasLength(1));
        expect(results.first.id, equals('a'));
      });

      test('matches by description', () {
        repository.setSubscribedLists([
          createList(
            id: 'a',
            name: 'Collection',
            description: 'Amazing guitar solos',
          ),
        ]);

        final results = repository.searchLists('guitar');

        expect(results, hasLength(1));
      });

      test('matches by tags', () {
        repository.setSubscribedLists([
          createList(id: 'a', name: 'Playlist', tags: ['music', 'jazz']),
        ]);

        final results = repository.searchLists('jazz');

        expect(results, hasLength(1));
      });

      test('excludes private lists', () {
        repository.setSubscribedLists([
          createList(id: 'a', name: 'Secret Dance', isPublic: false),
          createList(id: 'b', name: 'Public Dance'),
        ]);

        final results = repository.searchLists('dance');

        expect(results, hasLength(1));
        expect(results.first.id, equals('b'));
      });

      test('excludes lists with no videos, own or subscribed', () {
        repository
          ..setOwnLists([
            createList(
              id: 'mine',
              name: 'Dance Drafts',
              pubkey: _testPubkey,
              videoEventIds: const [],
            ),
          ])
          ..setSubscribedLists([
            createList(id: 'bare', name: 'Dance Bare', videoEventIds: const []),
            createList(id: 'full', name: 'Dance Full'),
          ]);

        final results = repository.searchLists('dance');

        expect(results.map((l) => l.id), equals(['full']));
      });
    });

    group('getListsByTag', () {
      test('returns matching public lists', () {
        repository.setSubscribedLists([
          createList(id: 'a', tags: ['music', 'dance']),
          createList(id: 'b', tags: ['cooking']),
          createList(id: 'c', tags: ['music'], isPublic: false),
        ]);

        final results = repository.getListsByTag('music');

        expect(results, hasLength(1));
        expect(results.first.id, equals('a'));
      });

      test('returns empty when no match', () {
        repository.setSubscribedLists([
          createList(id: 'a', tags: ['cooking']),
        ]);

        expect(repository.getListsByTag('music'), isEmpty);
      });
    });

    group('getAllTags', () {
      test('returns empty when no lists', () {
        expect(repository.getAllTags(), isEmpty);
      });

      test('returns unique sorted tags from public lists', () {
        repository.setSubscribedLists([
          createList(id: 'a', tags: ['music', 'dance']),
          createList(id: 'b', tags: ['dance', 'cooking']),
          createList(id: 'c', tags: ['secret'], isPublic: false),
        ]);

        expect(repository.getAllTags(), equals(['cooking', 'dance', 'music']));
      });
    });

    group('getListsContainingVideo', () {
      test('returns empty when video is in no lists', () {
        repository.setSubscribedLists([
          createList(id: 'a', videoEventIds: ['other-video']),
        ]);

        expect(repository.getListsContainingVideo('my-video'), isEmpty);
      });

      test('returns all lists containing the video', () {
        repository.setSubscribedLists([
          createList(id: 'a', videoEventIds: ['v1', 'v2']),
          createList(id: 'b', videoEventIds: ['v2', 'v3']),
          createList(id: 'c', videoEventIds: ['v3']),
        ]);

        final results = repository.getListsContainingVideo('v2');

        expect(results, hasLength(2));
        expect(results.map((l) => l.id), containsAll(['a', 'b']));
      });
    });

    group('getOrderedVideoIds', () {
      test('returns empty for unknown list', () {
        expect(repository.getOrderedVideoIds('unknown'), isEmpty);
      });

      test('returns chronological order', () {
        repository.setSubscribedLists([
          createList(id: 'list', videoEventIds: ['v1', 'v2', 'v3']),
        ]);

        expect(
          repository.getOrderedVideoIds('list'),
          equals(['v1', 'v2', 'v3']),
        );
      });

      test('returns reverse order', () {
        repository.setSubscribedLists([
          createList(
            id: 'list',
            videoEventIds: ['v1', 'v2', 'v3'],
            playOrder: PlayOrder.reverse,
          ),
        ]);

        expect(
          repository.getOrderedVideoIds('list'),
          equals(['v3', 'v2', 'v1']),
        );
      });

      test('returns manual order as-is', () {
        repository.setSubscribedLists([
          createList(
            id: 'list',
            videoEventIds: ['v3', 'v1', 'v2'],
            playOrder: PlayOrder.manual,
          ),
        ]);

        expect(
          repository.getOrderedVideoIds('list'),
          equals(['v3', 'v1', 'v2']),
        );
      });

      test('returns shuffled order with same elements', () {
        repository.setSubscribedLists([
          createList(
            id: 'list',
            videoEventIds: ['v1', 'v2', 'v3'],
            playOrder: PlayOrder.shuffle,
          ),
        ]);

        final ordered = repository.getOrderedVideoIds('list');

        // Contains the same elements (order may vary).
        expect(ordered, unorderedEquals(['v1', 'v2', 'v3']));
      });

      test('does not mutate original list', () {
        repository
          ..setSubscribedLists([
            createList(
              id: 'list',
              videoEventIds: ['v1', 'v2', 'v3'],
              playOrder: PlayOrder.reverse,
            ),
          ])
          ..getOrderedVideoIds('list');

        // Original list is unchanged.
        final list = repository.getListById('list')!;
        expect(list.videoEventIds, equals(['v1', 'v2', 'v3']));
      });
    });

    group('resolveListThumbnails', () {
      test('filters REST metadata before exposing a thumbnail', () async {
        repository = CuratedListRepository(
          nostrClient: nostrClient,
          funnelcakeApiClient: funnelcakeApiClient,
          videoFilter: (video) => video.contentWarningLabels.contains('nudity'),
        );
        when(
          () => funnelcakeApiClient.getVideoStats(_videoEventId),
        ).thenAnswer((_) async => _previewStats(labels: ['nudity']));

        final [hidden] = await repository.resolveListThumbnails([
          createList(id: 'list', videoEventIds: [_videoEventId]),
        ]);
        expect(hidden.thumbnailUrls, isEmpty);
        verifyNever(thumbnailRead);

        when(
          () => funnelcakeApiClient.getVideoStats(_videoEventId),
        ).thenAnswer((_) async => _previewStats());
        final [allowed] = await repository.resolveListThumbnails([hidden]);
        expect(allowed.thumbnailUrls, ['https://example.com/preview.jpg']);
      });

      test(
        'does not discard denied REST metadata before relay fallback',
        () async {
          var hideLabeled = true;
          repository = CuratedListRepository(
            nostrClient: nostrClient,
            funnelcakeApiClient: funnelcakeApiClient,
            videoFilter: (video) =>
                hideLabeled && video.contentWarningLabels.contains('nudity'),
          );
          when(
            () => funnelcakeApiClient.getVideoStats(_videoEventId),
          ).thenAnswer(
            (_) async => _previewStats(labels: ['nudity'], thumbnail: ''),
          );
          answerThumbnailRead([
            _makeVideoEventWithId(
              _videoEventId,
              thumbnail: 'https://example.com/permitted-relay.jpg',
            ),
          ]);
          final [denied] = await repository.resolveListThumbnails([
            createList(id: 'list', videoEventIds: [_videoEventId]),
          ]);
          expect(denied.thumbnailUrls, isEmpty);
          verifyNever(thumbnailRead);

          hideLabeled = false;
          final [retried] = await repository.resolveListThumbnails([denied]);
          expect(retried.thumbnailUrls, [
            'https://example.com/permitted-relay.jpg',
          ]);
          verify(thumbnailRead).called(1);
        },
      );

      test('applies the author block filter to REST video authors', () async {
        repository = CuratedListRepository(
          nostrClient: nostrClient,
          funnelcakeApiClient: funnelcakeApiClient,
          blockFilter: (pubkey) => pubkey == _blockedPubkey,
        );
        when(
          () => funnelcakeApiClient.getVideoStats(_videoEventId),
        ).thenAnswer((_) async => _previewStats(pubkey: _blockedPubkey));
        final [result] = await repository.resolveListThumbnails([
          createList(id: 'list', videoEventIds: [_videoEventId]),
        ]);
        expect(result.thumbnailUrls, isEmpty);
      });

      test('rechecks live policy after an outstanding REST read', () async {
        var hidden = false;
        final response = Completer<VideoStats?>();
        repository = CuratedListRepository(
          nostrClient: nostrClient,
          funnelcakeApiClient: funnelcakeApiClient,
          videoFilter: (_) => hidden,
        );
        when(
          () => funnelcakeApiClient.getVideoStats(_videoEventId),
        ).thenAnswer((_) => response.future);
        final resolving = repository.resolveListThumbnails([
          createList(id: 'list', videoEventIds: [_videoEventId]),
        ]);
        hidden = true;
        response.complete(_previewStats());
        expect((await resolving).single.thumbnailUrls, isEmpty);
      });

      test(
        'matches relay coordinates before filtering sibling videos',
        () async {
          repository = CuratedListRepository(
            nostrClient: nostrClient,
            funnelcakeApiClient: funnelcakeApiClient,
            videoFilter: (video) => video.addressableDTag == 'hidden',
          );
          Event video(String dTag) => Event(
            _testPubkey,
            34236,
            [
              ['d', dTag],
              ['url', 'https://example.com/video.mp4'],
              ['thumb', 'https://example.com/$dTag.jpg'],
            ],
            '',
          );
          answerThumbnailRead([video('allowed'), video('hidden')]);
          final [result] = await repository.resolveListThumbnails([
            createList(
              id: 'list',
              videoEventIds: [
                '34236:$_testPubkey:hidden',
                '34236:$_testPubkey:allowed',
              ],
            ),
          ]);
          expect(result.thumbnailUrls, ['https://example.com/allowed.jpg']);
        },
      );

      for (final policy in [
        (decision: 'Hide', label: 'nudity'),
        (decision: 'Warn', label: 'flashing-lights'),
      ]) {
        for (final newestFirst in [true, false]) {
          test(
            'uses the newest ${policy.decision} coordinate revision '
            'when newest arrives ${newestFirst ? 'first' : 'last'}',
            () async {
              repository = CuratedListRepository(
                nostrClient: nostrClient,
                funnelcakeApiClient: funnelcakeApiClient,
                // Both decisions suppress a list-card image; the app owns
                // the distinction between Hide and Warn preferences.
                videoFilter: (video) =>
                    video.contentWarningLabels.contains(policy.label),
              );
              final older = _makeVideoEventWithId(
                _videoEventId,
                thumbnail: 'https://example.com/older.jpg',
              );
              final newest = _makeVideoEventWithId(
                _videoEventId2,
                createdAt: 1718400100,
                thumbnail: 'https://example.com/newest.jpg',
                extraTags: [
                  ['content-warning', policy.label],
                ],
              );
              final allowed = _makeVideoEventWithId(
                _videoEventId3,
                pubkey: _otherPubkey,
                createdAt: 1718400200,
                thumbnail: 'https://example.com/allowed.jpg',
              );
              answerThumbnailRead([
                if (newestFirst) newest,
                older,
                if (!newestFirst) newest,
                allowed,
              ]);

              final [result] = await repository.resolveListThumbnails([
                createList(
                  id: 'list',
                  videoEventIds: [
                    '34236:$_testPubkey:test-video',
                    '34236:$_otherPubkey:test-video',
                  ],
                ),
              ]);

              expect(result.thumbnailUrls, ['https://example.com/allowed.jpg']);
            },
          );
        }
      }

      for (final newestFirst in [true, false]) {
        test(
          'does not revive an older image for a thumbnail-less revision '
          'when newest arrives ${newestFirst ? 'first' : 'last'}',
          () async {
            final older = _makeVideoEventWithId(
              _videoEventId,
              thumbnail: 'https://example.com/older.jpg',
            );
            final newest = _makeVideoEventWithId(
              _videoEventId2,
              createdAt: 1718400100,
            );
            final allowed = _makeVideoEventWithId(
              _videoEventId3,
              dTag: 'allowed',
              thumbnail: 'https://example.com/allowed.jpg',
            );
            answerThumbnailRead([
              if (newestFirst) newest,
              older,
              if (!newestFirst) newest,
              allowed,
            ]);

            final [result] = await repository.resolveListThumbnails([
              createList(
                id: 'list',
                videoEventIds: [
                  '34236:$_testPubkey:test-video',
                  '34236:$_testPubkey:allowed',
                ],
              ),
            ]);

            expect(result.thumbnailUrls, ['https://example.com/allowed.jpg']);
          },
        );

        test(
          'does not revive an older image for an unparseable revision '
          'when newest arrives ${newestFirst ? 'first' : 'last'}',
          () async {
            final older = _makeVideoEventWithId(
              _videoEventId,
              thumbnail: 'https://example.com/older.jpg',
            );
            final newest = _makeVideoEventWithId(
              _videoEventId2,
              createdAt: 1718400100,
              thumbnail: 'https://example.com/newest.jpg',
              // Out-of-range published metadata cannot be parsed as a date.
              extraTags: const [
                ['published_at', '8640000000001'],
              ],
            );
            answerThumbnailRead([
              if (newestFirst) newest,
              older,
              if (!newestFirst) newest,
            ]);

            final [result] = await repository.resolveListThumbnails([
              createList(
                id: 'list',
                videoEventIds: ['34236:$_testPubkey:test-video'],
              ),
            ]);

            expect(result.thumbnailUrls, isEmpty);
          },
        );

        test(
          'uses the lowest full event ID for equal-time revisions '
          'when the lowest ID arrives ${newestFirst ? 'first' : 'last'}',
          () async {
            final lowest = _makeVideoEventWithId(
              _lowerTieEventId,
              thumbnail: 'https://example.com/lowest.jpg',
            );
            final higher = _makeVideoEventWithId(
              _higherTieEventId,
              thumbnail: 'https://example.com/higher.jpg',
            );
            answerThumbnailRead([
              if (newestFirst) lowest,
              higher,
              if (!newestFirst) lowest,
            ]);

            final [result] = await repository.resolveListThumbnails([
              createList(
                id: 'list',
                videoEventIds: ['34236:$_testPubkey:test-video'],
              ),
            ]);

            expect(result.thumbnailUrls, ['https://example.com/lowest.jpg']);
          },
        );

        test(
          'keeps an exact hex event separate from a newer hidden revision '
          'when newest arrives ${newestFirst ? 'first' : 'last'}',
          () async {
            repository = CuratedListRepository(
              nostrClient: nostrClient,
              funnelcakeApiClient: funnelcakeApiClient,
              videoFilter: (video) => video.hasContentWarning,
            );
            when(
              () => funnelcakeApiClient.getVideoStats(_videoEventId),
            ).thenAnswer((_) async => null);
            final requested = _makeVideoEventWithId(
              _videoEventId,
              thumbnail: 'https://example.com/requested.jpg',
            );
            final newest = _makeVideoEventWithId(
              _videoEventId2,
              createdAt: 1718400100,
              thumbnail: 'https://example.com/newest.jpg',
              extraTags: const [
                ['content-warning', 'nudity'],
              ],
            );
            answerThumbnailRead([
              if (newestFirst) newest,
              requested,
              if (!newestFirst) newest,
            ]);

            final [result] = await repository.resolveListThumbnails([
              createList(
                id: 'list',
                videoEventIds: [
                  _videoEventId,
                  '34236:$_testPubkey:test-video',
                ],
              ),
            ]);

            expect(result.thumbnailUrls, ['https://example.com/requested.jpg']);
          },
        );
      }

      test(
        'does not substitute a coordinate sibling for an absent hex ID',
        () async {
          when(
            () => funnelcakeApiClient.getVideoStats(_videoEventId),
          ).thenAnswer((_) async => null);
          answerThumbnailRead([
            _makeVideoEventWithId(
              _videoEventId2,
              thumbnail: 'https://example.com/sibling.jpg',
            ),
          ]);

          final [result] = await repository.resolveListThumbnails([
            createList(id: 'list', videoEventIds: [_videoEventId]),
          ]);

          expect(result.thumbnailUrls, isEmpty);
        },
      );

      test(
        'matches the full coordinate including kind and colon-bearing d-tag',
        () async {
          answerThumbnailRead([
            _makeVideoEventWithId(
              _videoEventId,
              dTag: 'video:part:one',
              thumbnail: 'https://example.com/short.jpg',
            ),
            _makeVideoEventWithId(
              _videoEventId2,
              kind: 34235,
              dTag: 'video:part:one',
              createdAt: 1718400100,
              thumbnail: 'https://example.com/normal.jpg',
            ),
            _makeVideoEventWithId(
              _videoEventId3,
              pubkey: _otherPubkey,
              dTag: 'video:part:one',
              createdAt: 1718400200,
              thumbnail: 'https://example.com/unrequested.jpg',
            ),
          ]);

          final [result] = await repository.resolveListThumbnails([
            createList(
              id: 'list',
              videoEventIds: [
                '34236:$_testPubkey:video:part:one',
                '34235:$_testPubkey:video:part:one',
              ],
            ),
          ]);

          expect(result.thumbnailUrls, [
            'https://example.com/short.jpg',
            'https://example.com/normal.jpg',
          ]);
        },
      );

      for (final newestFirst in [true, false]) {
        test(
          'contradictory parsed coordinate metadata stays neutral '
          'when newest arrives ${newestFirst ? 'first' : 'last'}',
          () async {
            final older = _makeVideoEventWithId(
              _videoEventId,
              dTag: 'first',
              thumbnail: 'https://example.com/older.jpg',
            );
            final newest = _makeVideoEventWithId(
              _videoEventId2,
              dTag: 'first',
              createdAt: 1718400100,
              thumbnail: 'https://example.com/contradictory.jpg',
              extraTags: const [
                ['d', 'later'],
              ],
            );
            final allowed = _makeVideoEventWithId(
              _videoEventId3,
              dTag: 'allowed',
              thumbnail: 'https://example.com/allowed.jpg',
            );
            when(
              () => funnelcakeApiClient.getVideoStats(_videoEventId2),
            ).thenAnswer((_) async => null);
            answerThumbnailRead([
              if (newestFirst) newest,
              older,
              if (!newestFirst) newest,
              allowed,
            ]);

            final [first, later, exact] = await repository
                .resolveListThumbnails([
                  createList(
                    id: 'first-list',
                    videoEventIds: [
                      '34236:$_testPubkey:first',
                      '34236:$_testPubkey:allowed',
                    ],
                  ),
                  createList(
                    id: 'later-list',
                    videoEventIds: ['34236:$_testPubkey:later'],
                  ),
                  createList(
                    id: 'immutable-list',
                    videoEventIds: [_videoEventId2],
                  ),
                ]);

            expect(first.thumbnailUrls, ['https://example.com/allowed.jpg']);
            expect(later.thumbnailUrls, isEmpty);
            // An exact ID does not choose a coordinate revision.
            expect(exact.thumbnailUrls, [
              'https://example.com/contradictory.jpg',
            ]);
          },
        );
      }

      test(
        'clears stale previews without fetching for an empty video list',
        () async {
          final list = createList(
            id: 'empty',
            videoEventIds: const [],
          ).copyWith(thumbnailUrls: ['https://example.com/stale.jpg']);
          expect(
            (await repository.resolveListThumbnails([
              list,
            ])).single.thumbnailUrls,
            isEmpty,
          );
          verifyZeroInteractions(funnelcakeApiClient);
          verifyZeroInteractions(nostrClient);
        },
      );
      test('enriches lists with resolved thumbnail URLs', () async {
        when(() => funnelcakeApiClient.getVideoStats(_videoEventId)).thenAnswer(
          (_) async => VideoStats(
            id: _videoEventId,
            pubkey: _testPubkey,
            createdAt: DateTime(2025),
            kind: 34236,
            dTag: 'd',
            title: 'Test',
            thumbnail: 'https://example.com/thumb.jpg',
            videoUrl: 'https://example.com/video.mp4',
            reactions: 0,
            comments: 0,
            reposts: 0,
            engagementScore: 0,
          ),
        );

        final enriched = await repository.resolveListThumbnails([
          createList(id: 'list-1', videoEventIds: [_videoEventId]),
        ]);

        expect(enriched, hasLength(1));
        expect(
          enriched.single.thumbnailUrls,
          equals(['https://example.com/thumb.jpg']),
        );
      });

      test('leaves a list without videos untouched', () async {
        final list = createList(id: 'list-1', videoEventIds: const []);

        final enriched = await repository.resolveListThumbnails([list]);

        expect(enriched.single.thumbnailUrls, isEmpty);
        verifyNever(() => funnelcakeApiClient.getVideoStats(any()));
      });
    });

    group('resolveListThumbnails across lists', () {
      String coordinate(String dTag) => '34236:$_testPubkey:$dTag';
      String thumb(String dTag) => 'https://example.com/$dTag.jpg';
      Event video(String dTag) =>
          _makeVideoEvent(dTag: dTag, thumbnail: thumb(dTag));
      List<String> coordinates(Iterable<String> dTags) => [
        for (final dTag in dTags) coordinate(dTag),
      ];

      Future<({List<Event> events, bool timedOut, bool noRelays})>
      freshRead() => nostrClient.queryEventsOnFreshConnections(
        any(),
        timeout: any(named: 'timeout'),
      );

      void answerFreshRead(
        List<Event> events, {
        bool timedOut = false,
        bool noRelays = false,
      }) {
        when(freshRead).thenAnswer(
          (_) async => (events: events, timedOut: timedOut, noRelays: noRelays),
        );
      }

      /// The d-tags each shared-connection read asked for, in call order.
      List<Set<String>> askedDTags() => [
        for (final filters in verify(
          () => nostrClient.queryEventsDetailed(
            captureAny(),
            timeout: kListThumbnailRelayReadTimeout,
            requireAllRelaysSettled: true,
          ),
        ).captured)
          {for (final filter in filters as List<Filter>) ...?filter.d},
      ];

      test(
        "reads every list's coordinates in one request of at most ten "
        'filters',
        () async {
          final lists = [
            for (var l = 0; l < 120; l++)
              createList(
                id: 'list-$l',
                videoEventIds: coordinates([
                  for (var v = 0; v < 5; v++) 'l$l-v$v',
                ]),
              ),
          ];
          answerThumbnailRead([
            for (var l = 0; l < 120; l++)
              for (var v = 0; v < 5; v++) video('l$l-v$v'),
          ]);

          final resolved = await repository.resolveListThumbnails(lists);

          expect(resolved.first.thumbnailUrls, [
            for (var v = 0; v < 5; v++) thumb('l0-v$v'),
          ]);
          expect(resolved.last.thumbnailUrls, [
            for (var v = 0; v < 5; v++) thumb('l119-v$v'),
          ]);
          final filters =
              verify(
                    () => nostrClient.queryEventsDetailed(
                      captureAny(),
                      timeout: kListThumbnailRelayReadTimeout,
                      requireAllRelaysSettled: true,
                    ),
                  ).captured.single
                  as List<Filter>;
          expect(filters.length, lessThanOrEqualTo(kMaxFiltersPerRelayRequest));
          expect({for (final filter in filters) ...?filter.d}, hasLength(600));
          expect(filters.every((filter) => filter.limit == null), isTrue);
        },
      );

      test(
        'asks the relays for coordinates while FunnelCake still answers',
        () async {
          final rest = Completer<VideoStats?>();
          when(
            () => funnelcakeApiClient.getVideoStats(_videoEventId),
          ).thenAnswer((_) => rest.future);
          answerThumbnailRead([video('a')]);

          final resolving = repository.resolveListThumbnails([
            createList(
              id: 'list',
              videoEventIds: [_videoEventId, coordinate('a')],
            ),
          ]);
          await pumpEventQueue();
          expect(askedDTags(), [
            {'a'},
          ]);

          rest.complete(_previewStats());
          expect((await resolving).single.thumbnailUrls, [
            'https://example.com/preview.jpg',
            thumb('a'),
          ]);
        },
      );

      test('asks FunnelCake once for a video in several lists', () async {
        when(
          () => funnelcakeApiClient.getVideoStats(_videoEventId),
        ).thenAnswer((_) async => _previewStats());

        final resolved = await repository.resolveListThumbnails([
          createList(id: 'first', videoEventIds: [_videoEventId]),
          createList(id: 'second', videoEventIds: [_videoEventId]),
        ]);

        expect(resolved.map((list) => list.thumbnailUrls), [
          ['https://example.com/preview.jpg'],
          ['https://example.com/preview.jpg'],
        ]);
        verify(
          () => funnelcakeApiClient.getVideoStats(_videoEventId),
        ).called(1);
      });

      test(
        'asks again on new connections for the videos the shared '
        'connections did not answer',
        () async {
          answerThumbnailRead([video('a')], timedOut: true);
          answerFreshRead([video('b')]);

          final [result] = await repository.resolveListThumbnails([
            createList(id: 'list', videoEventIds: coordinates(['a', 'b'])),
          ]);

          expect(result.thumbnailUrls, [thumb('a'), thumb('b')]);
          final filters =
              verify(
                    () => nostrClient.queryEventsOnFreshConnections(
                      captureAny(),
                      timeout: kListThumbnailFreshRelayReadTimeout,
                    ),
                  ).captured.single
                  as List<Filter>;
          expect(filters.single.d, ['b']);
        },
      );

      test(
        'keeps the slot of a video no relay answered for instead of '
        'filling it from further down the list',
        () async {
          answerThumbnailRead([
            for (final dTag in ['a', 'c', 'd', 'e', 'f']) video(dTag),
          ], timedOut: true);
          answerFreshRead([], timedOut: true);

          final [result] = await repository.resolveListThumbnails([
            createList(
              id: 'list',
              videoEventIds: coordinates(['a', 'b', 'c', 'd', 'e', 'f']),
            ),
          ]);

          expect(result.thumbnailUrls, [
            thumb('a'),
            thumb('c'),
            thumb('d'),
            thumb('e'),
          ]);
          expect(askedDTags(), [
            {'a', 'b', 'c', 'd', 'e'},
          ]);
        },
      );

      test(
        'does not ask new connections when no relay could be asked',
        () async {
          answerThumbnailRead([], noRelays: true);

          final [result] = await repository.resolveListThumbnails([
            createList(
              id: 'list',
              videoEventIds: coordinates(['a', 'b', 'c', 'd', 'e', 'f']),
            ),
          ]);

          expect(result.thumbnailUrls, isEmpty);
          verifyNever(freshRead);
          expect(askedDTags(), hasLength(1));
        },
      );

      test(
        'keeps the slots when new connections find no relay either',
        () async {
          answerThumbnailRead([], timedOut: true);
          answerFreshRead([], noRelays: true);

          final [result] = await repository.resolveListThumbnails([
            createList(
              id: 'list',
              videoEventIds: coordinates(['a', 'b', 'c', 'd', 'e', 'f']),
            ),
          ]);

          expect(result.thumbnailUrls, isEmpty);
          expect(askedDTags(), hasLength(1));
        },
      );

      test(
        'gives the slot of a gone video to the next one in the list',
        () async {
          answerThumbnailRead([
            for (final dTag in ['a', 'c', 'd', 'e', 'f', 'g', 'x2'])
              video(dTag),
          ]);

          final [short, full] = await repository.resolveListThumbnails([
            createList(
              id: 'short',
              videoEventIds: coordinates(['a', 'b', 'c', 'd', 'e', 'f', 'g']),
            ),
            createList(
              id: 'full',
              videoEventIds: coordinates(['a', 'c', 'd', 'e', 'x2', 'x1']),
            ),
          ]);

          expect(short.thumbnailUrls, [
            for (final dTag in ['a', 'c', 'd', 'e', 'f']) thumb(dTag),
          ]);
          expect(full.thumbnailUrls, [
            for (final dTag in ['a', 'c', 'd', 'e', 'x2']) thumb(dTag),
          ]);
          // Only the short list reads on, as far as its window goes; the
          // full list's sixth video is never asked for.
          expect(askedDTags(), [
            {'a', 'b', 'c', 'd', 'e', 'x2'},
            {'f', 'g'},
          ]);
        },
      );

      test(
        'gives the slot of a hidden video to the next one in the list',
        () async {
          repository = CuratedListRepository(
            nostrClient: nostrClient,
            funnelcakeApiClient: funnelcakeApiClient,
            videoFilter: (video) => video.addressableDTag == 'hidden',
          );
          final dTags = ['a', 'hidden', 'b', 'c', 'd', 'e'];
          answerThumbnailRead([for (final dTag in dTags) video(dTag)]);

          final [result] = await repository.resolveListThumbnails([
            createList(id: 'list', videoEventIds: coordinates(dTags)),
          ]);

          expect(result.thumbnailUrls, [
            for (final dTag in ['a', 'b', 'c', 'd', 'e']) thumb(dTag),
          ]);
        },
      );

      test(
        'looks at no more than twice as many videos as the fan has slots',
        () async {
          final dTags = [for (var v = 0; v < 12; v++) 'v$v'];
          answerThumbnailRead([
            for (final dTag in dTags.skip(9)) video(dTag),
          ]);

          final [result] = await repository.resolveListThumbnails([
            createList(id: 'list', videoEventIds: coordinates(dTags)),
          ]);

          expect(result.thumbnailUrls, [thumb('v9')]);
          expect(askedDTags(), [
            dTags.take(5).toSet(),
            dTags.skip(5).take(5).toSet(),
          ]);
        },
      );
    });

    group('searchAllLists without the list index', () {
      test('never emits cached or resolved hidden preview URLs', () async {
        repository =
            CuratedListRepository(
              nostrClient: nostrClient,
              funnelcakeApiClient: funnelcakeApiClient,
              videoFilter: (_) => true,
            )..setOwnLists([
              createList(
                id: 'dance',
                name: 'Dance',
                videoEventIds: [_videoEventId],
              ).copyWith(thumbnailUrls: ['https://example.com/stale.jpg']),
            ]);
        when(
          () => funnelcakeApiClient.getVideoStats(_videoEventId),
        ).thenAnswer((_) async => _previewStats());
        when(
          () => nostrClient.queryEvents(
            any(),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => []);

        final emissions = await _lists(repository.searchAllLists('dance'));
        expect(emissions, hasLength(4));
        for (final lists in emissions) {
          expect(lists.single.id, 'dance');
          expect(lists.single.thumbnailUrls, isEmpty);
        }
      });
      setUp(() {
        registerFallbackValue(<Filter>[]);
        when(() => funnelcakeApiClient.isAvailable).thenReturn(false);
      });

      test(
        'reads the shared relay window with the shared read budget',
        () async {
          // Every account publishes an empty default list, so the newest 50
          // list events are placeholders; the search reads the same window as
          // discovery, and waits as long as discovery does rather than the
          // client's default budget, which startup work can exhaust.
          when(
            () =>
                nostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
          ).thenAnswer((_) async => []);

          await _lists(repository.searchAllLists('dance'));

          final captured = verify(
            () => nostrClient.queryEvents(
              captureAny(),
              timeout: captureAny(named: 'timeout'),
            ),
          ).captured;
          final filters = captured[0] as List<Filter>;
          expect(filters.single.kinds, equals([30005]));
          expect(filters.single.limit, equals(kPublicListsRelayWindow));
          expect(kPublicListsRelayWindow, equals(500));
          expect(captured[1], equals(kPublicCuratedListsRelayReadTimeout));
          expect(
            kPublicCuratedListsRelayReadTimeout,
            greaterThan(const Duration(seconds: 5)),
          );
        },
      );

      test('keeps same-named lists from different authors apart', () async {
        // Every account owns a `my_vine_list`: the viewer's must not hide
        // other authors' lists with that d-tag, and only the viewer's own
        // relay copy is the duplicate to drop.
        repository.setOwnLists([
          createList(
            id: 'my_vine_list',
            name: 'Dance Mine',
            pubkey: _testPubkey,
          ),
        ]);
        when(
          () => nostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
        ).thenAnswer(
          (_) async => [
            _makeEvent(
              pubkey: _otherPubkey,
              tags: [
                ['d', 'my_vine_list'],
                ['title', 'Dance Theirs'],
                ['e', 'video-1'],
              ],
            ),
            _makeEvent(
              tags: [
                ['d', 'my_vine_list'],
                ['title', 'Dance Mine Stale'],
                ['e', 'video-1'],
              ],
            ),
          ],
        );

        final emissions = await _lists(repository.searchAllLists('dance'));

        expect(
          emissions[2].map((l) => l.name),
          unorderedEquals(['Dance Mine', 'Dance Theirs']),
        );
      });

      test(
        'a list its author later emptied is not found through an older '
        'revision',
        () async {
          when(
            () =>
                nostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
          ).thenAnswer(
            (_) async => [
              _makeEvent(
                createdAt: 1718400000,
                tags: [
                  ['d', 'dance-list'],
                  ['title', 'Dance'],
                  ['e', 'video-1'],
                ],
              ),
              _makeEvent(
                createdAt: 1718400100,
                tags: [
                  ['d', 'dance-list'],
                  ['title', 'Dance'],
                ],
              ),
            ],
          );

          final emissions = await _lists(repository.searchAllLists('dance'));

          expect(emissions.last, isEmpty);
        },
      );

      test('emits nothing for blank query', () async {
        await expectLater(repository.searchAllLists(''), emitsDone);
      });

      test('emits nothing for whitespace-only query', () async {
        await expectLater(repository.searchAllLists('   '), emitsDone);
      });

      test('emits 4 progressive yields with thumbnails', () async {
        // Set up local subscribed lists
        repository.setSubscribedLists([
          createList(id: 'local-1', name: 'Dance Local'),
        ]);

        when(
          () => nostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
        ).thenAnswer(
          (_) async => [
            _makeEvent(
              tags: [
                ['d', 'relay-1'],
                ['title', 'Dance Relay'],
                ['e', 'video-1'],
              ],
            ),
          ],
        );

        final emissions = await _lists(repository.searchAllLists('dance'));

        expect(emissions, hasLength(4));

        // Yield 1: local results immediately (no thumbnails)
        expect(emissions[0], hasLength(1));
        expect(emissions[0].first.id, equals('local-1'));

        // Yield 2: local results with thumbnails resolved
        expect(emissions[1], hasLength(1));
        expect(emissions[1].first.id, equals('local-1'));

        // Yield 3: local + relay merged (relay without thumbnails)
        expect(emissions[2], hasLength(2));
        expect(
          emissions[2].map((l) => l.id),
          containsAll(['local-1', 'relay-1']),
        );

        // Yield 4: fully enriched
        expect(emissions[3], hasLength(2));
        expect(
          emissions[3].map((l) => l.id),
          containsAll(['local-1', 'relay-1']),
        );
      });

      test('excludes local IDs from relay search', () async {
        repository.setSubscribedLists([
          createList(id: 'shared-id', name: 'Dance Local'),
        ]);

        when(
          () => nostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
        ).thenAnswer((_) async => []);

        await _lists(repository.searchAllLists('dance'));

        // Verify queryEvents was called (relay search happened)
        verify(
          () => nostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
        ).called(1);
      });

      test('deduplicates relay results with local results', () async {
        repository.setSubscribedLists([
          createList(id: 'shared-id', name: 'Dance Local'),
        ]);

        // Relay returns a list with the same ID — but excludeIds
        // should prevent it. Return a different one instead.
        when(
          () => nostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
        ).thenAnswer(
          (_) async => [
            _makeEvent(
              tags: [
                ['d', 'new-relay'],
                ['title', 'Dance Relay'],
                ['e', 'video-1'],
              ],
            ),
          ],
        );

        final emissions = await _lists(repository.searchAllLists('dance'));

        expect(emissions, hasLength(4));
        // Yield 3: local + relay (no duplicates)
        expect(emissions[2], hasLength(2));
      });

      test('filters blocked owners from local and relay list search', () async {
        final blockedRepository = CuratedListRepository(
          nostrClient: nostrClient,
          funnelcakeApiClient: funnelcakeApiClient,
          blockFilter: (pubkey) => pubkey == _blockedPubkey,
        );
        addTearDown(blockedRepository.dispose);

        blockedRepository.setSubscribedLists([
          createList(
            id: 'allowed-local',
            name: 'Dance Local',
            pubkey: _testPubkey,
          ),
          createList(
            id: 'blocked-local',
            name: 'Dance Hidden',
            pubkey: _blockedPubkey,
          ),
        ]);

        when(
          () => nostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
        ).thenAnswer(
          (_) async => [
            Event(
              _blockedPubkey,
              30005,
              [
                ['d', 'blocked-relay'],
                ['title', 'Dance Hidden Relay'],
                ['e', 'video-1'],
              ],
              '',
              createdAt: 1718400000,
            ),
            _makeEvent(
              tags: [
                ['d', 'allowed-relay'],
                ['title', 'Dance Relay'],
                ['e', 'video-1'],
              ],
            ),
          ],
        );

        final emissions = await _lists(
          blockedRepository.searchAllLists('dance'),
        );

        expect(
          emissions.last.map((list) => list.id),
          containsAll(['allowed-local', 'allowed-relay']),
        );
        expect(
          emissions.last.map((list) => list.id),
          isNot(contains('blocked-local')),
        );
        expect(
          emissions.last.map((list) => list.id),
          isNot(contains('blocked-relay')),
        );
      });

      test('resolves thumbnails from FunnelCake API', () async {
        repository.setSubscribedLists([
          createList(
            id: 'local-1',
            name: 'Dance Local',
            videoEventIds: [_videoEventId],
          ),
        ]);

        when(() => funnelcakeApiClient.getVideoStats(_videoEventId)).thenAnswer(
          (_) async => VideoStats(
            id: _videoEventId,
            pubkey: _testPubkey,
            createdAt: DateTime(2025),
            kind: 34236,
            dTag: 'd',
            title: 'Test',
            thumbnail: 'https://example.com/thumb.jpg',
            videoUrl: 'https://example.com/video.mp4',
            reactions: 0,
            comments: 0,
            reposts: 0,
            engagementScore: 0,
          ),
        );

        when(
          () => nostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
        ).thenAnswer((_) async => []);

        final emissions = await _lists(repository.searchAllLists('dance'));

        // Yield 2 should have thumbnail resolved via FunnelCake
        expect(emissions[1].first.thumbnailUrls, isNotEmpty);
        expect(
          emissions[1].first.thumbnailUrls.first,
          equals('https://example.com/thumb.jpg'),
        );
      });

      test('falls back to relay when FunnelCake fails', () async {
        repository.setSubscribedLists([
          createList(
            id: 'local-1',
            name: 'Dance Local',
            videoEventIds: [_videoEventId],
          ),
        ]);

        when(
          () => funnelcakeApiClient.getVideoStats(_videoEventId),
        ).thenThrow(Exception('API down'));

        // The relay search finds no lists; the thumbnail read finds the
        // video FunnelCake could not answer for.
        when(
          () => nostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
        ).thenAnswer((_) async => []);
        answerThumbnailRead([
          _makeVideoEventWithId(
            _videoEventId,
            thumbnail: 'https://relay.com/thumb.jpg',
          ),
        ]);

        final emissions = await _lists(repository.searchAllLists('dance'));

        expect(emissions[1].first.thumbnailUrls, isNotEmpty);
        expect(
          emissions[1].first.thumbnailUrls.first,
          equals('https://relay.com/thumb.jpg'),
        );
      });

      test('resolves addressable coordinate thumbnails', () async {
        const addressableCoord = '34236:$_testPubkey:my-video';
        repository.setSubscribedLists([
          createList(
            id: 'local-1',
            name: 'Dance Local',
            videoEventIds: [addressableCoord],
          ),
        ]);

        when(
          () => nostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
        ).thenAnswer((_) async => []);
        answerThumbnailRead([
          _makeVideoEvent(
            dTag: 'my-video',
            thumbnail: 'https://relay.com/addr-thumb.jpg',
          ),
        ]);

        final emissions = await _lists(repository.searchAllLists('dance'));

        expect(emissions[1].first.thumbnailUrls, isNotEmpty);
        expect(
          emissions[1].first.thumbnailUrls.first,
          equals('https://relay.com/addr-thumb.jpg'),
        );
      });

      test('skips invalid addressable coordinates', () async {
        repository.setSubscribedLists([
          createList(
            id: 'local-1',
            name: 'Dance Local',
            videoEventIds: ['invalid-coord'],
          ),
        ]);

        when(
          () => nostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
        ).thenAnswer((_) async => []);

        final emissions = await _lists(repository.searchAllLists('dance'));

        // Thumbnail resolution returns null for bad coord, list stays empty
        expect(emissions[1].first.thumbnailUrls, isEmpty);
      });

      test('filters null thumbnails from results', () async {
        repository.setSubscribedLists([
          createList(
            id: 'local-1',
            name: 'Dance Local',
            videoEventIds: [_videoEventId],
          ),
        ]);

        // FunnelCake returns null (not found)
        when(
          () => funnelcakeApiClient.getVideoStats(_videoEventId),
        ).thenAnswer((_) async => null);

        // Relay also returns empty
        when(
          () => nostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
        ).thenAnswer((_) async => []);
        answerThumbnailRead([]);

        final emissions = await _lists(repository.searchAllLists('dance'));

        expect(emissions[1].first.thumbnailUrls, isEmpty);
      });

      test('matches relay lists by description', () async {
        when(
          () => nostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
        ).thenAnswer(
          (_) async => [
            _makeEvent(
              tags: [
                ['d', 'relay-1'],
                ['title', 'My List'],
                ['description', 'Great dance videos'],
                ['e', 'video-1'],
              ],
            ),
          ],
        );

        final emissions = await _lists(repository.searchAllLists('dance'));

        // Yield 3 should include the relay list matched by description
        expect(emissions[2].any((l) => l.id == 'relay-1'), isTrue);
      });

      test('matches relay lists by tag', () async {
        when(
          () => nostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
        ).thenAnswer(
          (_) async => [
            _makeEvent(
              tags: [
                ['d', 'relay-1'],
                ['title', 'My List'],
                ['t', 'dance'],
                ['e', 'video-1'],
              ],
            ),
          ],
        );

        final emissions = await _lists(repository.searchAllLists('dance'));

        expect(emissions[2].any((l) => l.id == 'relay-1'), isTrue);
      });

      test('keeps newer relay duplicate over older', () async {
        when(
          () => nostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
        ).thenAnswer(
          (_) async => [
            _makeEvent(
              tags: [
                ['d', 'dup-id'],
                ['title', 'Dance Old'],
                ['e', 'video-1'],
              ],
              createdAt: 1718400000,
            ),
            _makeEvent(
              tags: [
                ['d', 'dup-id'],
                ['title', 'Dance New'],
                ['e', 'video-1'],
              ],
              createdAt: 1718500000,
            ),
          ],
        );

        final emissions = await _lists(repository.searchAllLists('dance'));

        final relayList = emissions[2].where((l) => l.id == 'dup-id').toList();
        expect(relayList, hasLength(1));
        expect(relayList.first.name, equals('Dance New'));
      });

      test('returns empty thumbnails when relay batch throws', () async {
        repository.setSubscribedLists([
          createList(
            id: 'local-1',
            name: 'Dance Local',
            videoEventIds: [_videoEventId],
          ),
        ]);

        when(
          () => funnelcakeApiClient.getVideoStats(_videoEventId),
        ).thenAnswer((_) async => null);

        // Both thumbnail reads throw, relay search returns empty.
        when(
          () => nostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
        ).thenAnswer((_) async => []);
        when(thumbnailRead).thenThrow(Exception('relay timeout'));
        when(
          () => nostrClient.queryEventsOnFreshConnections(
            any(),
            timeout: any(named: 'timeout'),
          ),
        ).thenThrow(Exception('relay timeout'));

        final emissions = await _lists(repository.searchAllLists('dance'));

        // Yield 2: relay batch failed, thumbnails empty
        expect(emissions[1].first.thumbnailUrls, isEmpty);
      });

      test(
        'skips unparseable relay events during thumbnail resolution',
        () async {
          repository.setSubscribedLists([
            createList(
              id: 'local-1',
              name: 'Dance Local',
              videoEventIds: [_videoEventId],
            ),
          ]);

          when(
            () => funnelcakeApiClient.getVideoStats(_videoEventId),
          ).thenAnswer((_) async => null);

          // The thumbnail read returns an event with kind 1 (text note),
          // which VideoEvent.fromNostrEvent refuses to parse.
          when(
            () =>
                nostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
          ).thenAnswer((_) async => []);
          answerThumbnailRead([
            Event.fromJson({
              'id': _videoEventId,
              'pubkey': _testPubkey,
              'created_at': 1718400000,
              'kind': 1, // text note — not a video kind
              'tags': <List<String>>[],
              'content': 'hello',
              'sig': '',
            }),
          ]);

          final emissions = await _lists(repository.searchAllLists('dance'));

          // Thumbnail resolution skipped the unparseable event
          expect(emissions[1].first.thumbnailUrls, isEmpty);
        },
      );

      test('filters out private lists from all emissions', () async {
        repository.setSubscribedLists([
          createList(id: 'private-1', name: 'Dance Secret', isPublic: false),
          createList(id: 'public-1', name: 'Dance Public'),
        ]);

        when(
          () => nostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
        ).thenAnswer((_) async => []);

        final emissions = await _lists(repository.searchAllLists('dance'));

        for (final emission in emissions) {
          expect(emission.every((l) => l.id != 'private-1'), isTrue);
        }
      });

      test('excludes relay lists with empty videoEventIds', () async {
        when(
          () => nostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
        ).thenAnswer(
          (_) async => [
            _makeEvent(
              tags: [
                ['d', 'empty-list'],
                ['title', 'Dance Empty'],
                // No 'e' or 'a' tags → videoEventIds is empty
              ],
            ),
            _makeEvent(
              tags: [
                ['d', 'good-list'],
                ['title', 'Dance Good'],
                ['e', 'video-1'],
              ],
            ),
          ],
        );

        final emissions = await _lists(repository.searchAllLists('dance'));

        final relayIds = emissions[2].map((l) => l.id).toList();
        expect(relayIds, isNot(contains('empty-list')));
        expect(relayIds, contains('good-list'));
      });

      test('skips malformed relay events without d-tag', () async {
        when(
          () => nostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
        ).thenAnswer(
          (_) async => [
            // Valid event
            _makeEvent(
              tags: [
                ['d', 'good-list'],
                ['title', 'Dance Good'],
                ['e', 'video-1'],
              ],
            ),
            // Malformed — no d-tag → fromEvent returns null
            _makeEvent(
              tags: [
                ['title', 'Dance Bad'],
                ['e', 'video-2'],
              ],
            ),
          ],
        );

        final emissions = await _lists(repository.searchAllLists('dance'));

        // Yield 3 (merged) should contain only the valid relay list
        final relayIds = emissions[2].map((l) => l.id).toList();
        expect(relayIds, contains('good-list'));
        expect(relayIds, isNot(contains(null)));
        expect(emissions[2], hasLength(1));
      });

      test('emissions are unmodifiable', () async {
        repository.setSubscribedLists([
          createList(id: 'local-1', name: 'Dance Local'),
        ]);

        when(
          () => nostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
        ).thenAnswer((_) async => []);

        final emissions = await repository.searchAllLists('dance').toList();

        for (final emission in emissions) {
          expect(
            () => emission.add(CuratedListSearchResult(createList(id: 'hack'))),
            throwsA(isA<UnsupportedError>()),
          );
        }
      });

      test('partial thumbnail resolution across sources', () async {
        repository.setSubscribedLists([
          createList(
            id: 'local-1',
            name: 'Dance Local',
            videoEventIds: [_videoEventId, _videoEventId2, _videoEventId3],
          ),
        ]);

        // FunnelCake: ref1 → thumbnail, ref2 → null, ref3 → throws
        when(() => funnelcakeApiClient.getVideoStats(_videoEventId)).thenAnswer(
          (_) async => VideoStats(
            id: _videoEventId,
            pubkey: _testPubkey,
            createdAt: DateTime(2025),
            kind: 34236,
            dTag: 'd',
            title: 'Test',
            thumbnail: 'https://fc.com/thumb1.jpg',
            videoUrl: 'https://example.com/video.mp4',
            reactions: 0,
            comments: 0,
            reposts: 0,
            engagementScore: 0,
          ),
        );

        when(
          () => funnelcakeApiClient.getVideoStats(_videoEventId2),
        ).thenAnswer((_) async => null);

        when(
          () => funnelcakeApiClient.getVideoStats(_videoEventId3),
        ).thenThrow(Exception('API error'));

        // Batched relay fallback: ref2 and ref3 go in one query.
        // Only ref3 returns a video with a thumbnail (ref2 has no match).
        // Relay search call returns empty.
        when(
          () => nostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
        ).thenAnswer((_) async => []);
        answerThumbnailRead([
          _makeVideoEventWithId(
            _videoEventId3,
            thumbnail: 'https://relay.com/thumb3.jpg',
          ),
        ]);

        final emissions = await _lists(repository.searchAllLists('dance'));

        // Yield 2: thumbnails resolved — ref1 from FC, ref3 from relay
        final thumbs = emissions[1].first.thumbnailUrls;
        expect(thumbs, hasLength(2));
        expect(thumbs, contains('https://fc.com/thumb1.jpg'));
        expect(thumbs, contains('https://relay.com/thumb3.jpg'));
      });

      test('emits 4 yields even when relay returns empty', () async {
        repository.setSubscribedLists([
          createList(id: 'local-1', name: 'Dance Local'),
        ]);

        when(
          () => nostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
        ).thenAnswer((_) async => []);

        final emissions = await _lists(repository.searchAllLists('dance'));

        expect(emissions, hasLength(4));
        // All yields contain only the local result
        for (final emission in emissions) {
          expect(emission, hasLength(1));
          expect(emission.first.id, equals('local-1'));
        }
      });
    });

    group('searchAllLists with the list index', () {
      PublicListCard card(
        String dTag, {
        String title = 'Dance',
        String description = '',
        String pubkey = _testPubkey,
        int itemCount = 2,
        int kind = 30005,
        int updatedAt = 1718400000,
      }) => PublicListCard(
        kind: kind,
        pubkey: pubkey,
        dTag: dTag,
        title: title,
        description: description,
        itemCount: itemCount,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          updatedAt * 1000,
          isUtc: true,
        ),
      );

      void answerIndex(List<PublicListCard> cards) {
        when(
          () => funnelcakeApiClient.searchLists(
            query: any(named: 'query'),
            kind: any(named: 'kind'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => ListSearchResponse(cards: cards));
      }

      void answerRelays(List<Event> events) {
        when(
          () => nostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
        ).thenAnswer((_) async => events);
      }

      setUp(() {
        registerFallbackValue(<Filter>[]);
        when(() => funnelcakeApiClient.isAvailable).thenReturn(true);
        when(
          () => funnelcakeApiClient.getVideoStats(any()),
        ).thenAnswer((_) async => null);
        answerThumbnailRead([]);
      });

      test(
        'publishes the summaries first, in the server order, before any '
        'relay answers',
        () async {
          answerIndex([
            card('dance-b', title: 'Dance Battles', itemCount: 7),
            card(
              'dance-a',
              description: 'Moves',
              pubkey: _otherPubkey,
            ),
          ]);
          final relays = Completer<List<Event>>();
          when(
            () =>
                nostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
          ).thenAnswer((_) => relays.future);

          final first = await repository.searchAllLists('  dance ').first;

          expect(first.map((result) => result.list.id), [
            'dance-b',
            'dance-a',
          ]);
          expect(first.map((result) => result.isComplete), [false, false]);
          expect(first.map((result) => result.itemCount), [7, 2]);
          expect(first.first.list.pubkey, _testPubkey);
          expect(first.first.list.name, 'Dance Battles');
          expect(first.first.list.description, isNull);
          expect(first.last.list.description, 'Moves');
          expect(first.first.list.videoEventIds, isEmpty);
          verify(
            () => funnelcakeApiClient.searchLists(
              query: 'dance',
              kind: PublicListKind.videos,
              limit: kCuratedListSearchIndexLimit,
            ),
          ).called(1);
        },
      );

      test(
        'completes the lists from their own events and resolves their '
        'thumbnails without searching the relay window',
        () async {
          answerIndex([card('dance-list', itemCount: 1)]);
          answerRelays([
            _makeEvent(
              tags: [
                ['d', 'dance-list'],
                ['title', 'Dance'],
                ['e', _videoEventId],
              ],
            ),
          ]);
          when(
            () => funnelcakeApiClient.getVideoStats(_videoEventId),
          ).thenAnswer((_) async => _previewStats());

          final emissions = await repository.searchAllLists('dance').toList();

          expect(emissions, hasLength(3));
          expect(emissions[1].single.isComplete, isTrue);
          expect(emissions[1].single.list.videoEventIds, [_videoEventId]);
          expect(emissions[1].single.list.thumbnailUrls, isEmpty);
          expect(emissions[2].single.list.thumbnailUrls, [
            'https://example.com/preview.jpg',
          ]);
          final filter =
              (verify(
                        () => nostrClient.queryEvents(
                          captureAny(),
                          timeout: any(named: 'timeout'),
                        ),
                      ).captured.single
                      as List<Filter>)
                  .single;
          expect(filter.kinds, [30005]);
          expect(filter.authors, [_testPubkey]);
          expect(filter.d, ['dance-list']);
          expect(filter.limit, isNull);
        },
      );

      test(
        'drops a list whose newest revision is private or empty and keeps '
        'one the relays cannot complete',
        () async {
          answerIndex([
            card('emptied'),
            card('missing'),
            card('stale', updatedAt: 1718400100),
            card('kept'),
          ]);
          answerRelays([
            _makeEvent(
              tags: [
                ['d', 'emptied'],
                ['title', 'Dance'],
              ],
            ),
            _makeEvent(
              tags: [
                ['d', 'stale'],
                ['title', 'Dance'],
                ['e', _videoEventId],
              ],
            ),
            _makeEvent(
              tags: [
                ['d', 'kept'],
                ['title', 'Dance Renamed'],
                ['e', _videoEventId],
              ],
            ),
          ]);

          final emissions = await repository.searchAllLists('dance').toList();

          final completed = emissions[1];
          expect(completed.map((result) => result.list.id), [
            'missing',
            'stale',
            'kept',
          ]);
          expect(completed.map((result) => result.isComplete), [
            false,
            false,
            true,
          ]);
          expect(completed.last.list.name, 'Dance Renamed');
          expect(emissions.last, completed);
        },
      );

      test(
        'leaves out empty lists, other kinds, blocked authors and repeated '
        'coordinates',
        () async {
          final blockedRepository = CuratedListRepository(
            nostrClient: nostrClient,
            funnelcakeApiClient: funnelcakeApiClient,
            blockFilter: (pubkey) => pubkey == _blockedPubkey,
          );
          addTearDown(blockedRepository.dispose);
          answerIndex([
            card('empty', itemCount: 0),
            card('people', kind: 30000),
            card('blocked', pubkey: _blockedPubkey),
            card('untitled', title: ''),
            card('untitled', title: 'Repeated'),
          ]);
          answerRelays([]);

          final first = await blockedRepository.searchAllLists('dance').first;

          expect(first.single.list.id, 'untitled');
          expect(
            first.single.list.name,
            CuratedListConverter.untitledListName,
          );
        },
      );

      test('keeps the summaries when the relay read fails', () async {
        answerIndex([card('dance-list')]);
        when(
          () => nostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
        ).thenThrow(Exception('relays down'));

        final emissions = await repository.searchAllLists('dance').toList();

        expect(emissions, hasLength(2));
        expect(emissions.last.single.isComplete, isFalse);
        verifyNever(() => funnelcakeApiClient.getVideoStats(any()));
      });

      test(
        'publishes no lists and reads no relay when the index finds none',
        () async {
          answerIndex([]);

          final emissions = await repository.searchAllLists('dance').toList();

          expect(emissions, [isEmpty]);
          verifyNever(
            () => nostrClient.queryEvents(
              any(),
              timeout: any(named: 'timeout'),
            ),
          );
        },
      );

      test('searches the relay window when the index fails', () async {
        when(
          () => funnelcakeApiClient.searchLists(
            query: any(named: 'query'),
            kind: any(named: 'kind'),
            limit: any(named: 'limit'),
          ),
        ).thenThrow(
          const FunnelcakeApiException(message: 'down', statusCode: 503),
        );
        answerRelays([
          _makeEvent(
            tags: [
              ['d', 'relay-list'],
              ['title', 'Dance'],
              ['e', _videoEventId],
            ],
          ),
        ]);

        final emissions = await repository.searchAllLists('dance').toList();

        expect(emissions, hasLength(4));
        expect(emissions[2].single.list.id, 'relay-list');
        expect(emissions[2].single.isComplete, isTrue);
        final filter =
            (verify(
                      () => nostrClient.queryEvents(
                        captureAny(),
                        timeout: any(named: 'timeout'),
                      ),
                    ).captured.first
                    as List<Filter>)
                .single;
        expect(filter.limit, kPublicListsRelayWindow);
      });

      test(
        'searches the relay window once the index outlasts its budget',
        () {
          fakeAsync((async) {
            when(
              () => funnelcakeApiClient.searchLists(
                query: any(named: 'query'),
                kind: any(named: 'kind'),
                limit: any(named: 'limit'),
              ),
            ).thenAnswer((_) => Completer<ListSearchResponse>().future);
            answerRelays([]);
            final emissions = <List<CuratedListSearchResult>>[];
            repository.searchAllLists('dance').listen(emissions.add);

            async.elapse(
              kCuratedListSearchIndexTimeout - const Duration(seconds: 1),
            );
            expect(emissions, isEmpty);

            async.elapse(const Duration(seconds: 1));

            expect(emissions, hasLength(4));
            verify(
              () => nostrClient.queryEvents(
                any(),
                timeout: kPublicCuratedListsRelayReadTimeout,
              ),
            ).called(1);
          });
        },
      );
    });

    group('discoverLists', () {
      PublicListCard card(
        String dTag, {
        String pubkey = _testPubkey,
        int itemCount = 2,
      }) => PublicListCard(
        kind: 30005,
        pubkey: pubkey,
        dTag: dTag,
        title: 'Dance',
        itemCount: itemCount,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          1718400000 * 1000,
          isUtc: true,
        ),
      );

      void answerIndex(List<PublicListCard> cards) {
        when(
          () => funnelcakeApiClient.discoverLists(
            kind: any(named: 'kind'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => ListSearchResponse(cards: cards));
      }

      void answerRelayWindow(
        List<Event> events, {
        QueryEnd endedBy = QueryEnd.complete,
        int answeredRelays = 1,
      }) {
        when(
          () => nostrClient.readEvents(
            any(),
            useCache: false,
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (_) async => QueryResult(
            events: events,
            endedBy: endedBy,
            answeredNetworkRelayCount: answeredRelays,
          ),
        );
      }

      Event listEvent(String dTag, {int? createdAt, String? pubkey}) =>
          _makeEvent(
            tags: [
              ['d', dTag],
              ['title', 'Dance'],
              ['e', _videoEventId],
            ],
            createdAt: createdAt,
            pubkey: pubkey ?? _testPubkey,
          );

      setUp(() {
        registerFallbackValue(<Filter>[]);
        registerFallbackValue(PublicListKind.videos);
        when(() => funnelcakeApiClient.isAvailable).thenReturn(true);
        when(
          () => funnelcakeApiClient.getVideoStats(any()),
        ).thenAnswer((_) async => _previewStats());
      });

      test(
        "shows the index's newest lists first, without the viewer's own",
        () async {
          answerIndex([card('newest'), card('own', pubkey: _otherPubkey)]);
          when(
            () =>
                nostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
          ).thenAnswer((_) => Completer<List<Event>>().future);

          final first = await repository
              .discoverLists(limit: 50, excludeAuthor: _otherPubkey)
              .first;

          expect(first.single.list.id, 'newest');
          expect(first.single.isComplete, isFalse);
          verify(
            () => funnelcakeApiClient.discoverLists(
              kind: PublicListKind.videos,
              limit: 50,
            ),
          ).called(1);
        },
      );

      test(
        'completes the lists from their events, then resolves thumbnails',
        () async {
          answerIndex([card('dance-list')]);
          when(
            () =>
                nostrClient.queryEvents(any(), timeout: any(named: 'timeout')),
          ).thenAnswer((_) async => [listEvent('dance-list')]);

          final emissions = await repository.discoverLists(limit: 50).toList();

          expect(emissions, hasLength(3));
          expect(emissions[1].single.isComplete, isTrue);
          expect(emissions[2].single.list.thumbnailUrls, [
            'https://example.com/preview.jpg',
          ]);
          verifyNever(
            () => nostrClient.readEvents(
              any(),
              useCache: false,
              timeout: any(named: 'timeout'),
            ),
          );
        },
      );

      test('asks the index for no more than one page holds', () async {
        answerIndex([]);

        await repository.discoverLists(limit: 500).toList();

        verify(
          () => funnelcakeApiClient.discoverLists(
            kind: PublicListKind.videos,
            limit: FunnelcakeApiClient.maxListSearchLimit,
          ),
        ).called(1);
      });

      test(
        'reads the newest lists on relays when the index fails',
        () async {
          when(
            () => funnelcakeApiClient.discoverLists(
              kind: any(named: 'kind'),
              limit: any(named: 'limit'),
            ),
          ).thenThrow(
            const FunnelcakeApiException(message: 'down', statusCode: 503),
          );
          answerRelayWindow([
            listEvent('third', createdAt: 1718400000),
            listEvent('own', createdAt: 1718400300, pubkey: _otherPubkey),
            listEvent('first', createdAt: 1718400200),
            listEvent('second', createdAt: 1718400100),
          ]);

          final emissions = await repository
              .discoverLists(limit: 2, excludeAuthor: _otherPubkey)
              .toList();

          expect(emissions, hasLength(2));
          expect(emissions.first.map((result) => result.list.id), [
            'first',
            'second',
          ]);
          expect(emissions.first.every((result) => result.isComplete), isTrue);
          expect(emissions.last.first.list.thumbnailUrls, [
            'https://example.com/preview.jpg',
          ]);
          final filter =
              (verify(
                        () => nostrClient.readEvents(
                          captureAny(),
                          useCache: false,
                          timeout: kPublicCuratedListsRelayReadTimeout,
                        ),
                      ).captured.single
                      as List<Filter>)
                  .single;
          expect(filter.kinds, [30005]);
          expect(filter.limit, kPublicListsRelayWindow);
        },
      );

      test('publishes no lists when the relays hold none', () async {
        when(() => funnelcakeApiClient.isAvailable).thenReturn(false);
        answerRelayWindow([]);

        final emissions = await repository.discoverLists(limit: 50).toList();

        expect(emissions, [isEmpty]);
        verifyNever(() => funnelcakeApiClient.getVideoStats(any()));
      });

      for (final end in [
        QueryEnd.noRelay,
        QueryEnd.deadline,
        QueryEnd.relayClosed,
        QueryEnd.socketDropped,
      ]) {
        test(
          'fails with no lists or relay answers after ${end.name}',
          () async {
            when(() => funnelcakeApiClient.isAvailable).thenReturn(false);
            answerRelayWindow([], endedBy: end, answeredRelays: 0);

            await expectLater(
              repository.discoverLists(limit: 50),
              emitsError(isA<PublicCuratedListReadUnavailableException>()),
            );
          },
        );
      }

      test(
        'keeps a successful empty answer when another relay closes',
        () async {
          when(() => funnelcakeApiClient.isAvailable).thenReturn(false);
          answerRelayWindow([], endedBy: QueryEnd.relayClosed);

          expect(await repository.discoverLists(limit: 50).toList(), [isEmpty]);
        },
      );

      test('leaves out lists by blocked authors from the relays', () async {
        final blockedRepository = CuratedListRepository(
          nostrClient: nostrClient,
          funnelcakeApiClient: funnelcakeApiClient,
          blockFilter: (pubkey) => pubkey == _blockedPubkey,
        );
        addTearDown(blockedRepository.dispose);
        when(() => funnelcakeApiClient.isAvailable).thenReturn(false);
        answerRelayWindow([
          listEvent('kept'),
          listEvent('blocked', pubkey: _blockedPubkey),
        ]);

        final first = await blockedRepository.discoverLists(limit: 50).first;

        expect(first.single.list.id, 'kept');
      });
    });

    group('getVideoListSummary', () {
      test('returns "Not in any lists" when video is nowhere', () {
        expect(
          repository.getVideoListSummary('v1'),
          equals('Not in any lists'),
        );
      });

      test('returns single list name', () {
        repository.setSubscribedLists([
          createList(id: 'a', name: 'My Favorites', videoEventIds: ['v1']),
        ]);

        expect(
          repository.getVideoListSummary('v1'),
          equals('In "My Favorites"'),
        );
      });

      test('returns comma-separated names for 2-3 lists', () {
        repository.setSubscribedLists([
          createList(id: 'a', name: 'Favs', videoEventIds: ['v1']),
          createList(id: 'b', name: 'Dance', videoEventIds: ['v1']),
        ]);

        expect(
          repository.getVideoListSummary('v1'),
          equals('In "Favs", "Dance"'),
        );
      });

      test('returns count for 4+ lists', () {
        repository.setSubscribedLists([
          createList(id: 'a', name: 'A', videoEventIds: ['v1']),
          createList(id: 'b', name: 'B', videoEventIds: ['v1']),
          createList(id: 'c', name: 'C', videoEventIds: ['v1']),
          createList(id: 'd', name: 'D', videoEventIds: ['v1']),
        ]);

        expect(repository.getVideoListSummary('v1'), equals('In 4 lists'));
      });
    });
  });
}

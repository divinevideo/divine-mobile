// ABOUTME: Regression tests for #10922: the vote totals and the viewer's own
// ABOUTME: vote include a like or unlike the offline queue still holds, read
// ABOUTME: through an in-memory relay behind a mocked NostrClient.

import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

class _MockNostrClient extends Mock implements NostrClient {}

String _hex(String suffix) => suffix.codeUnits
    .map((c) => c.toRadixString(16).padLeft(2, '0'))
    .join()
    .padLeft(64, '0');

final String _me = _hex('me');
final String _other = _hex('other');
final String _author = _hex('author');
final String _comment = _hex('comment');
final String _otherComment = _hex('comment2');

/// A relay held in memory, reached through a mocked [NostrClient].
class _Relay {
  _Relay(this.client) {
    when(() => client.publicKey).thenReturn(_me);
    when(() => client.hasKeys).thenReturn(true);
    when(client.resolvePublicKey).thenAnswer((_) async => _me);
    when(
      () => client.subscribe(
        any(),
        subscriptionId: any(named: 'subscriptionId'),
      ),
    ).thenAnswer((_) => const Stream.empty());
    when(() => client.unsubscribe(any())).thenAnswer((_) async {});
    when(() => client.queryEvents(any())).thenAnswer(
      (invocation) async =>
          _matching(invocation.positionalArguments.first as List),
    );
    when(
      () => client.readEvents(
        any(),
        requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        timeout: any(named: 'timeout'),
      ),
    ).thenAnswer(
      (invocation) async => QueryResult(
        events: _matching(invocation.positionalArguments.first as List),
        endedBy: QueryEnd.complete,
      ),
    );
    when(
      () => client.sendLike(
        any(),
        content: any(named: 'content'),
        addressableId: any(named: 'addressableId'),
        targetAuthorPubkey: any(named: 'targetAuthorPubkey'),
        targetKind: any(named: 'targetKind'),
      ),
    ).thenAnswer(
      (invocation) async =>
          vote(_me, invocation.positionalArguments.first as String),
    );
  }

  List<Event> _matching(List<dynamic> filters) => [
    for (final event in events)
      if (filters.cast<Filter>().any((f) => _matches(f, event))) event,
  ];

  final _MockNostrClient client;
  final List<Event> events = <Event>[];
  var _createdAt = 1700000000;

  Event vote(String pubkey, String target, {String content = '+'}) {
    final reaction = Event(
      pubkey,
      EventKind.reaction,
      [
        ['e', target],
        ['p', _author],
        ['k', '${EventKind.comment}'],
      ],
      content,
      createdAt: _createdAt++,
    );
    events.add(reaction);
    return reaction;
  }

  static bool _matches(Filter filter, Event event) {
    final kinds = filter.kinds;
    if (kinds != null && !kinds.contains(event.kind)) return false;
    final authors = filter.authors;
    if (authors != null && !authors.contains(event.pubkey)) return false;
    final e = filter.e;
    if (e != null) {
      final tagged = event.tags
          .where((t) => t.length > 1 && t[0] == 'e')
          .map((t) => t[1]);
      if (!tagged.any(e.contains)) return false;
    }
    return true;
  }
}

void main() {
  group('LikesRepository with queued votes (#10922)', () {
    late _Relay relay;
    late List<QueuedLikeAction> queue;
    late LikesRepository repository;

    setUpAll(() {
      registerFallbackValue(<Filter>[]);
      registerFallbackValue(Duration.zero);
    });

    setUp(() {
      relay = _Relay(_MockNostrClient());
      queue = [];
      repository = LikesRepository(
        nostrClient: relay.client,
        queuedLikeActions: () async => queue,
      );
    });

    tearDown(() => repository.dispose());

    group('getVoteCounts', () {
      test('counts a like the queue holds and the relay has not', () async {
        relay.vote(_other, _comment);
        queue.add((eventId: _comment, isLike: true));

        final counts = await repository.getVoteCounts([_comment]);

        expect(counts.upvotes[_comment], equals(2));
      });

      test('control: counts only the relay with nothing queued', () async {
        relay.vote(_other, _comment);

        final counts = await repository.getVoteCounts([_comment]);

        expect(counts.upvotes[_comment], equals(1));
      });

      test('counts a queued like once when the relay already has it', () async {
        // The publish landed without its OK reaching the client, so the
        // queue still holds the like the relay already counts.
        relay
          ..vote(_other, _comment)
          ..vote(_me, _comment);
        queue.add((eventId: _comment, isLike: true));

        final counts = await repository.getVoteCounts([_comment]);

        expect(counts.upvotes[_comment], equals(2));
      });

      test('leaves out a published like whose unlike is queued', () async {
        relay
          ..vote(_other, _comment)
          ..vote(_me, _comment);
        queue.add((eventId: _comment, isLike: false));

        final counts = await repository.getVoteCounts([_comment]);

        expect(counts.upvotes[_comment], equals(1));
      });

      test('a queued unlike leaves a downvote counted', () async {
        relay.vote(_me, _comment, content: '-');
        queue.add((eventId: _comment, isLike: false));

        final counts = await repository.getVoteCounts([_comment]);

        expect(counts.downvotes[_comment], equals(1));
        expect(counts.upvotes[_comment], equals(0));
      });

      test("a queued like replaces the viewer's downvote", () async {
        relay.vote(_me, _comment, content: '-');
        queue.add((eventId: _comment, isLike: true));

        final counts = await repository.getVoteCounts([_comment]);

        expect(counts.upvotes[_comment], equals(1));
        expect(counts.downvotes[_comment], equals(0));
      });

      test('the newest queued action for a target decides it', () async {
        // A like still replaying when an unlike was queued: the queue only
        // cancels a like that is still waiting, so both rows exist.
        relay.vote(_other, _comment);
        queue.addAll([
          (eventId: _comment, isLike: true),
          (eventId: _comment, isLike: false),
        ]);

        final counts = await repository.getVoteCounts([_comment]);

        expect(counts.upvotes[_comment], equals(1));
      });

      test('ignores queued votes on targets it was not asked about', () async {
        queue.add((eventId: _otherComment, isLike: true));

        final counts = await repository.getVoteCounts([_comment]);

        expect(counts.upvotes, equals({_comment: 0}));
      });

      test('counts the relay alone when the queue cannot be read', () async {
        relay.vote(_other, _comment);
        repository.dispose();
        repository = LikesRepository(
          nostrClient: relay.client,
          queuedLikeActions: () async => throw Exception('database closed'),
        );

        final counts = await repository.getVoteCounts([_comment]);

        expect(counts.upvotes[_comment], equals(1));
      });
    });

    group('getUserVoteStatuses', () {
      test("reports a queued like as the viewer's upvote", () async {
        queue.add((eventId: _comment, isLike: true));

        final statuses = await repository.getUserVoteStatuses([_comment]);

        expect(statuses.upvotedIds, equals({_comment}));
      });

      test('control: no upvote with nothing queued or published', () async {
        final statuses = await repository.getUserVoteStatuses([_comment]);

        expect(statuses.upvotedIds, isEmpty);
      });

      test('drops a published like whose unlike is queued', () async {
        relay.vote(_me, _comment);
        queue.add((eventId: _comment, isLike: false));

        final statuses = await repository.getUserVoteStatuses([_comment]);

        expect(statuses.upvotedIds, isEmpty);
      });

      test("a queued like replaces the viewer's downvote", () async {
        relay.vote(_me, _comment, content: '-');
        queue.add((eventId: _comment, isLike: true));

        final statuses = await repository.getUserVoteStatuses([_comment]);

        expect(statuses.upvotedIds, equals({_comment}));
        expect(statuses.downvotedIds, isEmpty);
      });
    });

    group('when the queue gives up', () {
      late bool online;

      setUp(() {
        online = true;
        repository.dispose();
        repository = LikesRepository(
          nostrClient: relay.client,
          isOnline: () => online,
          queueOfflineAction:
              ({
                required isLike,
                required eventId,
                required authorPubkey,
                addressableId,
                targetKind,
              }) async {},
        );
      });

      Future<void> like() =>
          repository.likeEvent(eventId: _comment, authorPubkey: _author);

      group('abandonLikeAction', () {
        test('takes back a like that never reached the relays', () async {
          online = false;
          await like();
          expect(await repository.isLiked(_comment), isTrue);

          await repository.abandonLikeAction(_comment);

          expect(await repository.isLiked(_comment), isFalse);
          expect(await repository.getLikedEventIds(), isEmpty);
        });

        test('control: keeps a like that was published', () async {
          await like();

          await repository.abandonLikeAction(_comment);

          expect(await repository.isLiked(_comment), isTrue);
        });
      });

      group('abandonUnlikeAction', () {
        test('restores a like whose unlike never reached the relays', () async {
          await like();
          online = false;
          await repository.unlikeEvent(_comment);
          expect(await repository.isLiked(_comment), isFalse);

          await repository.abandonUnlikeAction(_comment);

          expect(await repository.isLiked(_comment), isTrue);
        });

        test(
          'control: leaves it unliked when the relays hold no like',
          () async {
            online = false;
            await like();
            await repository.unlikeEvent(_comment);

            await repository.abandonUnlikeAction(_comment);

            expect(await repository.isLiked(_comment), isFalse);
          },
        );
      });
    });
  });
}

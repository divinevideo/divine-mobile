// ABOUTME: Regression tests for #10992 and #10809: a downvote checks the
// ABOUTME: relays for this account's existing one whatever the target, and
// ABOUTME: acts only on a check that proved its answer.

import 'dart:async';

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
final String _reply = '34236:$_author:reply-d-tag';

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
          _answer(invocation.positionalArguments.first as List).events,
    );
    when(
      () => client.readEvents(
        any(),
        requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        timeout: any(named: 'timeout'),
      ),
    ).thenAnswer((invocation) async {
      settledReads++;
      await _held?.future;
      final answer = _answer(invocation.positionalArguments.first as List);
      return QueryResult(
        events: answer.events,
        endedBy: answer.complete ? QueryEnd.complete : QueryEnd.deadline,
      );
    });
    when(() => client.deleteEvent(any())).thenAnswer(
      (invocation) async =>
          delete(invocation.positionalArguments.first as String),
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
      (invocation) async => vote(
        _me,
        invocation.positionalArguments.first as String,
        content: invocation.namedArguments[#content] as String? ?? '+',
        coordinate: invocation.namedArguments[#addressableId] as String?,
      ),
    );
  }

  final _MockNostrClient client;
  final List<Event> events = <Event>[];

  /// False: no relay answers. A plain query comes back empty and a read that
  /// must prove its answer ends at its deadline with nothing.
  bool answers = true;

  /// False: reads of kind 5 deletions come back empty, as from a relay that
  /// holds them and did not answer.
  bool deletionsAnswer = true;

  /// When set, a filter scoped by neither `#e` nor `#a` returns only its
  /// newest matches, as a relay clamps an unbounded `REQ`.
  int? unscopedResultLimit;

  /// Reads that had to prove their answer, counted as they were asked.
  int settledReads = 0;

  Completer<void>? _held;
  var _createdAt = 1700000000;

  /// Holds every read that must prove its answer until [releaseReads].
  void holdReads() => _held = Completer<void>();

  void releaseReads() => _held?.complete();

  int downvotesBy(String pubkey, String target) => events
      .where(
        (e) =>
            e.kind == EventKind.reaction &&
            e.pubkey == pubkey &&
            e.content == '-' &&
            e.tags.any((t) => t.length > 1 && t[0] == 'e' && t[1] == target),
      )
      .length;

  int get deletionCount =>
      events.where((e) => e.kind == EventKind.eventDeletion).length;

  Event vote(
    String pubkey,
    String target, {
    String content = '+',
    String? coordinate,
  }) {
    final reaction = Event(
      pubkey,
      EventKind.reaction,
      [
        ['e', target],
        if (coordinate != null) ['a', coordinate],
        ['p', _author],
        ['k', '${EventKind.comment}'],
      ],
      content,
      createdAt: _createdAt++,
    );
    events.add(reaction);
    return reaction;
  }

  Event delete(String eventId) {
    final deletion = Event(
      _me,
      EventKind.eventDeletion,
      [
        ['e', eventId],
      ],
      '',
      createdAt: _createdAt++,
    );
    events.add(deletion);
    return deletion;
  }

  ({List<Event> events, bool complete}) _answer(List<dynamic> filters) {
    if (!answers) return (events: const <Event>[], complete: false);
    var complete = true;
    final answered = <String, Event>{};
    for (final filter in filters.cast<Filter>()) {
      final asksForDeletions =
          filter.kinds?.contains(EventKind.eventDeletion) ?? false;
      if (asksForDeletions && !deletionsAnswer) {
        complete = false;
        continue;
      }
      var matches = [
        for (final event in events)
          if (_matches(filter, event)) event,
      ];
      final limit = unscopedResultLimit;
      if (limit != null && filter.e == null && filter.a == null) {
        matches.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        matches = matches.take(limit).toList();
      }
      for (final event in matches) {
        answered[event.id] = event;
      }
    }
    return (events: answered.values.toList(), complete: complete);
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
    final a = filter.a;
    if (a != null) {
      final tagged = event.tags
          .where((t) => t.length > 1 && t[0] == 'a')
          .map((t) => t[1]);
      if (!tagged.any(a.contains)) return false;
    }
    return true;
  }
}

void main() {
  group('LikesRepository downvote relay check', () {
    late _Relay relay;
    late LikesRepository repository;

    setUpAll(() {
      registerFallbackValue(<Filter>[]);
      registerFallbackValue(Duration.zero);
    });

    setUp(() {
      relay = _Relay(_MockNostrClient());
      repository = LikesRepository(nostrClient: relay.client);
    });

    tearDown(() => repository.dispose());

    group('downvoteEvent', () {
      test('adopts the relay downvote on a plain comment this device does '
          'not remember (#10992)', () async {
        relay
          ..vote(_other, _comment, content: '-')
          ..vote(_me, _comment, content: '-');

        await expectLater(
          repository.downvoteEvent(
            eventId: _comment,
            authorPubkey: _author,
            targetKind: EventKind.comment,
          ),
          throwsA(isA<AlreadyDownvotedException>()),
        );

        expect(relay.downvotesBy(_me, _comment), equals(1));
        expect(await repository.isDownvoted(_comment), isTrue);
        final counts = await repository.getVoteCounts([_comment]);
        expect(counts.downvotes[_comment], equals(2));
      });

      test(
        'control: adopts the relay downvote on an addressable reply',
        () async {
          relay.vote(_me, _comment, content: '-', coordinate: _reply);

          await expectLater(
            repository.downvoteEvent(
              eventId: _comment,
              authorPubkey: _author,
              targetKind: 34236,
              addressableId: _reply,
            ),
            throwsA(isA<AlreadyDownvotedException>()),
          );

          expect(relay.downvotesBy(_me, _comment), equals(1));
        },
      );

      test('a finished startup sync already remembers a plain-comment '
          'downvote', () async {
        relay.vote(_me, _comment, content: '-');
        await repository.initialize();
        expect(await repository.isDownvoted(_comment), isTrue);

        await expectLater(
          repository.downvoteEvent(
            eventId: _comment,
            authorPubkey: _author,
            targetKind: EventKind.comment,
          ),
          throwsA(isA<AlreadyDownvotedException>()),
        );

        expect(relay.downvotesBy(_me, _comment), equals(1));
      });

      test(
        'a complete startup snapshot publishes without a target read',
        () async {
          relay.vote(_other, _comment, content: '-');
          await repository.initialize();
          final readsAfterStartup = relay.settledReads;
          expect(readsAfterStartup, greaterThan(0));

          await repository.downvoteEvent(
            eventId: _comment,
            authorPubkey: _author,
            targetKind: EventKind.comment,
          );

          expect(relay.settledReads, equals(readsAfterStartup));
          expect(relay.downvotesBy(_me, _comment), equals(1));
        },
      );

      test('a tap during the startup sync waits for it (#10992)', () async {
        relay
          ..vote(_me, _comment, content: '-')
          ..holdReads();
        final startup = repository.initialize();

        final tap = expectLater(
          repository.downvoteEvent(
            eventId: _comment,
            authorPubkey: _author,
            targetKind: EventKind.comment,
          ),
          throwsA(isA<AlreadyDownvotedException>()),
        );
        await pumpEventQueue();
        expect(relay.downvotesBy(_me, _comment), equals(1));

        relay.releaseReads();
        await startup;
        await tap.timeout(const Duration(seconds: 5));
        expect(relay.downvotesBy(_me, _comment), equals(1));
      });

      test('does not adopt a downvote whose deletion it could not read '
          '(#10809)', () async {
        final retracted = relay.vote(
          _me,
          _comment,
          content: '-',
          coordinate: _reply,
        );
        relay
          ..delete(retracted.id)
          ..deletionsAnswer = false;

        final id = await repository.downvoteEvent(
          eventId: _comment,
          authorPubkey: _author,
          targetKind: 34236,
          addressableId: _reply,
        );

        expect(id, isNot(equals(retracted.id)));
        expect(relay.downvotesBy(_me, _comment), equals(2));
      });
    });
  });
}

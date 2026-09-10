// ABOUTME: Tests Nostr.readAllEvents, the until pager: boundary ties kept,
// ABOUTME: repeats dropped, and when a walk ends complete or incomplete.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';
import 'package:nostr_sdk/relay/relay_info.dart';

/// Relay that answers every `REQ` out of [stored] the way a relay does: newest
/// first, at most `limit` or its NIP-11 `max_limit` when that is lower, at or
/// before `until` unless [ignoresUntil].
class _StoreRelay extends Relay {
  _StoreRelay(String url, this.stored) : super(url, RelayStatus(url));

  final List<Event> stored;

  /// When true, every `REQ` gets the newest events whatever its `until`.
  bool ignoresUntil = false;

  /// When true, every `EOSE` carries the NIP-67 `finish` hint.
  bool sendsFinish = false;

  /// When set, this relay serves events the way a local cache relay does,
  /// each one naming these relays as the ones it first came from.
  List<String>? cachedFrom;

  /// The 1-based numbers of the `REQ`s this relay sends events for but never
  /// an `EOSE`.
  final Set<int> withholdsEoseFor = {};

  /// The filter of every `REQ` this relay was sent, in order.
  final List<Map<String, dynamic>> requests = [];

  /// When set, this relay answers each `REQ` only after [answersAfter] has
  /// answered its own, so an event both hold reaches the pool from that
  /// relay first.
  _StoreRelay? answersAfter;

  /// This relay's answer to its latest `REQ`.
  Future<void> _latestAnswer = Future<void>.value();

  @override
  Future<bool> doConnect() async {
    relayStatus.connected = ClientConnected.connected;
    return true;
  }

  @override
  Future<void> disconnect() async {
    relayStatus.connected = ClientConnected.disconnect;
  }

  @override
  Future<bool> send(
    List<dynamic> message, {
    bool queueIfFailed = true,
    bool skipReconnect = false,
    DateTime? deadline,
  }) async {
    if (message.firstOrNull == 'REQ') {
      final filter = Map<String, dynamic>.from(message[2] as Map);
      requests.add(filter);
      final withEose = !withholdsEoseFor.contains(requests.length);
      final after = answersAfter?._latestAnswer;
      final answered = Completer<void>();
      _latestAnswer = answered.future;
      // Answered once the pool has saved the query, which it does only after
      // this write returns.
      Timer.run(
        () => unawaited(
          _answer(
            message[1] as String,
            filter,
            withEose,
            after,
          ).whenComplete(answered.complete),
        ),
      );
    }
    return true;
  }

  Future<void> _answer(
    String subId,
    Map<String, dynamic> filter,
    bool withEose,
    Future<void>? after,
  ) async {
    if (after != null) await after;
    final until = filter['until'] as int?;
    final answer = [
      for (final event in stored)
        if (ignoresUntil || until == null || event.createdAt <= until) event,
    ]..sort(_newestFirst);
    final requested = filter['limit'] as int? ?? answer.length;
    final maxLimit = info?.maxLimit;
    final limit = maxLimit != null && maxLimit < requested
        ? maxLimit
        : requested;
    for (final event in answer.take(limit)) {
      await _deliver([
        'EVENT',
        subId,
        {...event.toJson(), if (cachedFrom != null) 'sources': cachedFrom},
      ]);
    }
    if (withEose) {
      await _deliver([
        'EOSE',
        subId,
        if (sendsFinish) ['finish'],
      ]);
    }
  }

  Future<void> _deliver(List<dynamic> json) async {
    final dynamic result = onMessage!(this, json);
    if (result is Future) await result;
  }
}

/// Newest first, ties in id order, so a relay's answer is repeatable.
int _newestFirst(Event a, Event b) {
  final byAge = b.createdAt.compareTo(a.createdAt);
  return byAge != 0 ? byAge : a.id.compareTo(b.id);
}

const _privateKey =
    '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';

/// How long a page that never settles holds the walk. Nothing races it: the
/// page is never going to be answered in full.
const _unsettledPageTimeout = Duration(milliseconds: 300);

/// Bounds a wait that only a regression could stretch.
const _guard = Duration(seconds: 3);

Map<String, dynamic> _textNotes() => {
  'kinds': [EventKind.textNote],
};

Iterable<String> _idsOf(Iterable<Event> events) =>
    events.map((event) => event.id);

List<int?> _untilsOf(_StoreRelay relay) => [
  for (final filter in relay.requests) filter['until'] as int?,
];

void main() {
  group('Nostr.readAllEvents', () {
    late Nostr nostr;
    var eventNumber = 0;

    setUp(() {
      nostr = Nostr(
        LocalNostrSigner(_privateKey),
        const [],
        (url) => RelayBase(url, RelayStatus(url)),
      );
    });

    Future<_StoreRelay> addStore(
      String url,
      List<Event> stored, {
      int relayType = RelayType.normal,
      int? maxLimit,
    }) async {
      final relay = _StoreRelay(url, stored)..relayStatus.relayType = relayType;
      if (maxLimit != null) {
        relay.info = RelayInfo(
          '',
          '',
          '',
          '',
          const [],
          '',
          '',
          maxLimit: maxLimit,
        );
      }
      expect(await nostr.relayPool.add(relay, relayType: relayType), isTrue);
      return relay;
    }

    /// Signed text notes, one per entry of [createdAts], in that order.
    Future<List<Event>> eventsAt(List<int> createdAts) async {
      final pubkey = await nostr.ensurePublicKey();
      return [
        for (final createdAt in createdAts)
          (await nostr.nostrSigner.signEvent(
            Event(
              pubkey,
              EventKind.textNote,
              [],
              'paged-${eventNumber++}',
              createdAt: createdAt,
            ),
          ))!,
      ];
    }

    group('with a NIP-11 max_limit', () {
      test('counts a relay that stops at its max_limit as filling the '
          'page', () async {
        final clamped = await eventsAt([110, 109, 108, 107, 106]);
        final sparse = await eventsAt([100]);
        await addStore('wss://clamped.example', clamped, maxLimit: 2);
        await addStore('wss://sparse.example', sparse);

        final result = await nostr.readAllEvents(_textNotes(), pageSize: 5);

        expect(
          _idsOf(result.events),
          unorderedEquals(_idsOf([...clamped, ...sparse])),
          reason:
              'two events fill a page for a relay whose NIP-11 max_limit is '
              '2, so the cursor has to follow it rather than jump past the '
              'events it has not sent yet',
        );
        expect(result.isComplete, isTrue);
      });
    });

    group('with a cache relay', () {
      test('does not let cached copies move the cursor', () async {
        final live = await eventsAt([110, 109, 108, 107]);
        final stale = await eventsAt([90, 80]);
        final relay = await addStore('wss://relay.example', live);
        (await addStore(
          'wss://cache.example',
          stale,
          relayType: RelayType.cache,
        )).cachedFrom = [
          relay.url,
        ];

        final result = await nostr.readAllEvents(_textNotes(), pageSize: 2);

        expect(
          _idsOf(result.events),
          unorderedEquals(_idsOf([...live, ...stale])),
          reason:
              'the cached copies name the relay they came from, so counting '
              "them as that relay's answer would move the cursor to 80 and "
              'skip 108 and 107',
        );
        expect(result.isComplete, isTrue);
      });
    });

    group('across page breaks', () {
      test('returns events that share the boundary created_at exactly '
          'once', () async {
        final stored = await eventsAt([110, 109, 108, 108, 107]);
        final relay = await addStore('wss://relay.example', stored);

        final result = await nostr.readAllEvents(_textNotes(), pageSize: 3);

        expect(
          _idsOf(result.events),
          unorderedEquals(_idsOf(stored)),
          reason:
              'the two events at 108 straddle the first page break, and the '
              'second page returns the one already collected again',
        );
        expect(
          _untilsOf(relay),
          [null, 108, 107, 106],
          reason:
              'each page asks again for the second the last one ended on, '
              'and steps past it once nothing new comes back',
        );
        expect(result.isComplete, isTrue);
        expect(result.pages, 4);
      });

      test('steps past a second that fills a whole page, and ends the walk '
          'incomplete', () async {
        final stored = await eventsAt([105, 104, 104, 104, 103]);
        final relay = await addStore('wss://relay.example', stored);

        final result = await nostr.readAllEvents(_textNotes(), pageSize: 2);

        expect(
          _untilsOf(relay),
          [null, 104, 103, 102],
          reason:
              'a page that sits wholly inside the cursor second cannot be '
              'paged within it, so the walk moves on to older history',
        );
        expect(
          _idsOf(result.events),
          containsAll(_idsOf([stored.first, stored.last])),
          reason: 'the walk still reads the history on either side of it',
        );
        expect(
          result.events,
          hasLength(stored.length - 1),
          reason: 'no page could reach the third event at 104',
        );
        expect(result.isComplete, isFalse);
        expect(
          result.stoppedBy,
          isNull,
          reason: 'no single page stopped the walk; a skipped second did',
        );
      });
    });

    group('across relays', () {
      test('keeps one copy of an event two relays both return', () async {
        final [newest, shared, oldest] = await eventsAt([103, 102, 101]);
        await addStore('wss://first.example', [newest, shared]);
        await addStore('wss://second.example', [shared, oldest]);

        final result = await nostr.readAllEvents(_textNotes(), pageSize: 5);

        expect(
          _idsOf(result.events),
          unorderedEquals(_idsOf([newest, shared, oldest])),
        );
        expect(result.isComplete, isTrue);
      });

      test('reads every event of a relay that fills its pages while another '
          'relay reaches further back', () async {
        final dense = await eventsAt([110, 109, 108, 107, 106, 105]);
        final sparse = await eventsAt([100]);
        final denseRelay = await addStore('wss://dense.example', dense);
        await addStore('wss://sparse.example', sparse);

        final result = await nostr.readAllEvents(_textNotes(), pageSize: 3);

        expect(
          _idsOf(result.events),
          unorderedEquals(_idsOf([...dense, ...sparse])),
          reason:
              "the sparse relay's older event must not pull the cursor past "
              'events the dense relay has not sent yet',
        );
        expect(
          _untilsOf(denseRelay),
          [null, 108, 106, 99],
          reason:
              'the cursor follows the relay that filled the page, then one '
              'more page asks past everything returned',
        );
        expect(result.isComplete, isTrue);
      });

      test('counts an event two relays both return toward each of '
          'them', () async {
        final [newest, shared, second108, second107, first105, first104] =
            await eventsAt([110, 109, 108, 107, 105, 104]);
        final first = await addStore('wss://first.example', [
          shared,
          first105,
          first104,
        ]);
        (await addStore('wss://second.example', [
          newest,
          shared,
          second108,
          second107,
        ])).answersAfter = first;

        final result = await nostr.readAllEvents(_textNotes(), pageSize: 2);

        expect(
          _idsOf(result.events),
          unorderedEquals(
            _idsOf([newest, shared, second108, second107, first105, first104]),
          ),
          reason:
              'the second relay filled its first page only by counting the '
              'event the first relay sent too; crediting that event to the '
              'first relay alone would move the cursor past 108 and 107',
        );
        expect(result.isComplete, isTrue);
      });

      test('pages a single relay exactly as before', () async {
        final stored = await eventsAt([106, 105, 104, 103, 102, 101]);
        final relay = await addStore('wss://relay.example', stored);

        final result = await nostr.readAllEvents(_textNotes(), pageSize: 2);

        expect(_idsOf(result.events), unorderedEquals(_idsOf(stored)));
        expect(_untilsOf(relay), [
          null,
          105,
          104,
          103,
          102,
          101,
          100,
        ], reason: "a lone relay's cursor is still each page's oldest second");
        expect(result.isComplete, isTrue);
      });

      test(
        "does not stall on a relay whose history ends below the others'",
        () async {
          final busy = await eventsAt([110, 109, 108, 107]);
          final [early] = await eventsAt([50]);
          await addStore('wss://busy.example', busy);
          await addStore('wss://early.example', [early]);

          final result = await nostr.readAllEvents(_textNotes(), pageSize: 2);

          expect(
            _idsOf(result.events),
            unorderedEquals(_idsOf([...busy, early])),
          );
          expect(
            result.pages,
            5,
            reason:
                'once no relay fills a page, one page past everything returned '
                'ends the walk, not a page per second down to 50',
          );
          expect(result.isComplete, isTrue);
        },
      );
    });

    group('when the walk is done', () {
      test('stops on an empty settled page, after asking for it', () async {
        final stored = await eventsAt([103, 102, 101]);
        final relay = await addStore('wss://relay.example', stored);

        final result = await nostr.readAllEvents(_textNotes(), pageSize: 5);

        expect(_idsOf(result.events), unorderedEquals(_idsOf(stored)));
        expect(
          _untilsOf(relay),
          [null, 100],
          reason:
              'a short page is not taken as the end: the walk asks once more, '
              'past everything returned, and only that empty page ends it',
        );
        expect(result.isComplete, isTrue);
        expect(result.stoppedBy, isNull);
        expect(result.pages, 2);
      });

      test('stops early on a settled page confirmed exhaustive', () async {
        final stored = await eventsAt([103, 102]);
        final relay = await addStore('wss://relay.example', stored)
          ..sendsFinish = true;

        final result = await nostr.readAllEvents(_textNotes(), pageSize: 5);

        expect(_idsOf(result.events), unorderedEquals(_idsOf(stored)));
        expect(
          relay.requests,
          hasLength(1),
          reason: 'NIP-67 finish says the relay sent everything that matched',
        );
        expect(result.isComplete, isTrue);
        expect(result.pages, 1);
      });
    });

    group('when a page does not settle', () {
      test('stops with isComplete false and the partial events when a page '
          'times out', () async {
        final stored = await eventsAt([105, 104, 103, 102, 101]);
        (await addStore('wss://relay.example', stored)).withholdsEoseFor.add(2);

        final result = await nostr
            .readAllEvents(
              _textNotes(),
              pageSize: 3,
              pageTimeout: _unsettledPageTimeout,
            )
            .timeout(
              _guard,
              onTimeout: () => fail('the page outlived its pageTimeout'),
            );

        expect(result.isComplete, isFalse);
        expect(result.stoppedBy, QueryEnd.deadline);
        expect(result.pages, 2);
        expect(
          _idsOf(result.events),
          unorderedEquals(_idsOf(stored)),
          reason:
              'the second page never settled, but the events it sent before '
              'its deadline are kept',
        );
      });

      test('stops incomplete on a page one relay confirmed exhaustive while '
          'another never settled', () async {
        final [event] = await eventsAt([101]);
        (await addStore('wss://finishes.example', [event])).sendsFinish = true;
        (await addStore(
          'wss://never-settles.example',
          [],
        )).withholdsEoseFor.addAll([1, 2]);

        // The shape of page the walk must not take as done: every relay that
        // answered sent `finish`, yet the page never settled.
        final page = await nostr.readEvents(
          [
            {..._textNotes(), 'limit': 5},
          ],
          deadline: DateTime.now().add(_unsettledPageTimeout),
          requireAllRelaysSettled: true,
        );
        expect(page.confirmedExhaustive, isTrue);
        expect(page.isComplete, isFalse);

        final result = await nostr.readAllEvents(
          _textNotes(),
          pageSize: 5,
          pageTimeout: _unsettledPageTimeout,
        );

        expect(result.isComplete, isFalse);
        expect(result.stoppedBy, QueryEnd.deadline);
        expect(_idsOf(result.events), [event.id]);
      });

      test('stops incomplete on a page no relay took', () async {
        final result = await nostr.readAllEvents(_textNotes());

        expect(result.isComplete, isFalse);
        expect(result.stoppedBy, QueryEnd.noRelay);
        expect(result.pages, 1);
        expect(result.events, isEmpty);
      });
    });

    group('when a relay ignores until', () {
      test('steps past the boundary instead of asking for the same page '
          'again', () async {
        final stored = await eventsAt([103, 102, 101]);
        final relay = await addStore('wss://ignores-until.example', stored)
          ..ignoresUntil = true;

        final result = await nostr.readAllEvents(_textNotes(), pageSize: 2);

        // Every page gets the same two newest events back. The pool's filter
        // gate drops the ones above `until`, so all that reaches the walk is
        // the event at the cursor, which it has already collected; stepping
        // past it is what ends the walk rather than spinning to `maxPages`.
        expect(_untilsOf(relay), [null, 102, 101]);
        expect(result.pages, 3);
        expect(_idsOf(result.events), unorderedEquals(_idsOf(stored.take(2))));
      });
    });

    group('bounds', () {
      test('stops incomplete after maxPages', () async {
        final stored = await eventsAt([105, 104, 103, 102, 101]);
        final relay = await addStore('wss://relay.example', stored);

        final result = await nostr.readAllEvents(
          _textNotes(),
          pageSize: 2,
          maxPages: 2,
        );

        expect(relay.requests, hasLength(2));
        expect(result.pages, 2);
        expect(result.isComplete, isFalse);
        expect(
          result.stoppedBy,
          isNull,
          reason: "the page cap is the walk's own limit, not how a page ended",
        );
        expect(_idsOf(result.events), unorderedEquals(_idsOf(stored.take(3))));
      });

      test('stops without asking once its deadline has passed', () async {
        final relay = await addStore(
          'wss://relay.example',
          await eventsAt([101]),
        );

        final result = await nostr.readAllEvents(
          _textNotes(),
          deadline: DateTime.now().subtract(const Duration(seconds: 1)),
        );

        expect(relay.requests, isEmpty);
        expect(result.pages, 0);
        expect(result.isComplete, isFalse);
        expect(result.stoppedBy, isNull);
      });

      test('cuts a page short at its deadline', () async {
        final stored = await eventsAt([102, 101]);
        (await addStore('wss://relay.example', stored)).withholdsEoseFor.add(1);

        final result = await nostr
            .readAllEvents(
              _textNotes(),
              pageTimeout: const Duration(minutes: 1),
              deadline: DateTime.now().add(_unsettledPageTimeout),
            )
            .timeout(
              _guard,
              onTimeout: () => fail("the page outlived the walk's deadline"),
            );

        expect(result.isComplete, isFalse);
        expect(result.stoppedBy, QueryEnd.deadline);
        expect(_idsOf(result.events), unorderedEquals(_idsOf(stored)));
      });

      test('rejects a pageSize below 1', () async {
        await expectLater(
          nostr.readAllEvents(_textNotes(), pageSize: 0),
          throwsArgumentError,
        );
      });

      test('rejects a maxPages below 1', () async {
        await expectLater(
          nostr.readAllEvents(_textNotes(), maxPages: 0),
          throwsArgumentError,
        );
      });
    });

    group('requests', () {
      test('ask for 500 events a page by default', () async {
        final relay = await addStore('wss://relay.example', []);

        await nostr.readAllEvents(_textNotes());

        expect(relay.requests.single['limit'], 500);
      });

      test('ask for pageSize events a page, keeping the rest of the '
          'filter', () async {
        final stored = await eventsAt([103, 102]);
        final relay = await addStore('wss://relay.example', stored);

        await nostr.readAllEvents({
          ..._textNotes(),
          'limit': 1,
          'since': 100,
          'until': 150,
        }, pageSize: 7);

        expect(
          relay.requests.map((filter) => filter['limit']),
          everyElement(7),
          reason: "the caller's own limit gives way to the page size",
        );
        expect(
          relay.requests.map((filter) => filter['since']),
          everyElement(100),
        );
        expect(relay.requests.first['kinds'], [EventKind.textNote]);
        expect(
          relay.requests.first['until'],
          150,
          reason: "the caller's own until starts the walk",
        );
      });
    });
  });
}

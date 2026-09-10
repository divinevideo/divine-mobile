// ABOUTME: Tests Nostr.readAllEvents, the until pager: boundary ties kept,
// ABOUTME: repeats dropped, and when a walk ends complete or incomplete.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';
import 'package:nostr_sdk/relay/relay_info.dart';

/// Relay that answers every `REQ` out of [stored] the way a relay does: newest
/// first, at most `limit`, its NIP-11 `max_limit` or its [silentCap],
/// whichever is lowest, at or before `until` unless [ignoresUntil].
class _StoreRelay extends Relay {
  _StoreRelay(String url, this.stored) : super(url, RelayStatus(url));

  final List<Event> stored;

  /// When true, every `REQ` gets the newest events whatever its `until`.
  bool ignoresUntil = false;

  /// When set, every `REQ` gets at most this many events, and the relay says
  /// so nowhere: no NIP-11 `max_limit`, no NIP-67 `more`.
  int? silentCap;

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
    var limit = filter['limit'] as int? ?? answer.length;
    for (final cap in [info?.maxLimit, silentCap].nonNulls) {
      if (cap < limit) limit = cap;
    }
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

/// Block list that hides the events whose ids it holds, the way a mute list
/// hides an author's.
class _BlockedIds implements EventFilter {
  final Set<String> ids = {};

  @override
  bool check(Event e) => ids.contains(e.id);
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
    late List<RelayDiagnostic> diagnostics;
    late _BlockedIds blockList;
    late Nostr nostr;
    var eventNumber = 0;

    setUp(() {
      diagnostics = [];
      blockList = _BlockedIds();
      nostr = Nostr(
        LocalNostrSigner(_privateKey),
        [blockList],
        (url) => RelayBase(url, RelayStatus(url)),
        diagnosticsSink: diagnostics.add,
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

    group('with a relay that stops short of the page size without saying '
        'so', () {
      test('reads every event, asking again for the second its page '
          'split', () async {
        final stored = await eventsAt([105, 104, 104]);
        final relay = await addStore('wss://relay.example', stored)
          ..silentCap = 2;

        final result = await nostr.readAllEvents(_textNotes(), pageSize: 5);

        expect(
          _idsOf(result.events),
          unorderedEquals(_idsOf(stored)),
          reason:
              'the relay stopped after 105 and one of the events at 104, so '
              'the next page has to ask for 104 again rather than start '
              'below it',
        );
        expect(_untilsOf(relay), [null, 104, 104, 103]);
        expect(result.isComplete, isTrue);
      });

      test('reads every event while another relay reaches further '
          'back', () async {
        final capped = await eventsAt([
          110,
          109,
          108,
          107,
          106,
          105,
          104,
          103,
          102,
          101,
        ]);
        final sparse = await eventsAt([50]);
        (await addStore('wss://capped.example', capped)).silentCap = 3;
        await addStore('wss://sparse.example', sparse);

        final result = await nostr.readAllEvents(_textNotes(), pageSize: 5);

        expect(
          _idsOf(result.events),
          unorderedEquals(_idsOf([...capped, ...sparse])),
          reason:
              "the sparse relay's event at 50 must not pull the cursor past "
              'the events the capped relay has not sent yet',
        );
        expect(result.isComplete, isTrue);
      });

      test('can lose the rest of a second that holds more events than it '
          'sends, the limit readAllEvents documents', () async {
        final stored = await eventsAt([105, 104, 104, 104, 103]);
        // The relay sends ties in id order, so no page reaches the last one.
        final unreached =
            (stored.where((event) => event.createdAt == 104).toList()
                  ..sort(_newestFirst))
                .last;
        (await addStore('wss://relay.example', stored)).silentCap = 2;

        final result = await nostr.readAllEvents(_textNotes(), pageSize: 5);

        expect(
          _idsOf(result.events),
          unorderedEquals(
            _idsOf(stored.where((event) => event.id != unreached.id)),
          ),
          reason:
              'nothing marks a page of two capped when five were asked for, '
              'so the cursor steps past 104 with one of its three events '
              'unread',
        );
        expect(result.isComplete, isTrue);
      });
    });

    group('with a NIP-11 max_limit', () {
      test('stops incomplete, rather than skip part of a second, when the '
          'relay stops at its max_limit inside it', () async {
        final stored = await eventsAt([105, 104, 104, 104, 103]);
        final relay = await addStore(
          'wss://clamped.example',
          stored,
          maxLimit: 2,
        );

        final result = await nostr.readAllEvents(_textNotes(), pageSize: 5);

        expect(
          _untilsOf(relay),
          [null, 104, 104],
          reason:
              'the third page brought nothing new at the cursor second, from '
              'a relay that sent as many events as its max_limit allows',
        );
        expect(
          result.events,
          hasLength(3),
          reason: 'no page can reach the third event at 104',
        );
        expect(
          result.isComplete,
          isFalse,
          reason: 'stepping past 104 could skip events the relay holds there',
        );
        expect(
          result.stoppedBy,
          QueryEnd.complete,
          reason:
              'the page that stopped the walk settled; it stopped it by '
              'bringing nothing new from a relay that may be capped',
        );
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

      test('stops incomplete when the newest second holds more than a '
          'page', () async {
        final stored = await eventsAt([104, 104, 104, 103]);
        final relay = await addStore('wss://relay.example', stored);

        final result = await nostr.readAllEvents(_textNotes(), pageSize: 2);

        expect(
          _untilsOf(relay),
          [null, 104],
          reason:
              'the second page brought nothing new at the cursor second, '
              'from a relay that filled it',
        );
        expect(
          result.events,
          hasLength(2),
          reason: 'no until can page within one second',
        );
        expect(
          result.isComplete,
          isFalse,
          reason: 'the third event at 104 is still unread',
        );
        expect(result.stoppedBy, QueryEnd.complete);
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
          [null, 108, 106, 105, 104, 100, 99],
          reason:
              'the cursor follows the dense relay, the one reaching least '
              'far back, down to its last event; then it drops to the sparse '
              "relay's, and steps past that",
        );
        expect(result.isComplete, isTrue);
      });

      test('counts an event two relays both return toward each of '
          'them', () async {
        final [shared, older, early] = await eventsAt([110, 108, 105]);
        final first = await addStore('wss://first.example', [shared, early]);
        (await addStore('wss://second.example', [shared, older]))
          ..silentCap = 1
          ..answersAfter = first;

        final result = await nostr.readAllEvents(_textNotes(), pageSize: 3);

        expect(
          _idsOf(result.events),
          unorderedEquals(_idsOf([shared, older, early])),
          reason:
              'the second relay sent only the event both relays hold, and the '
              "first relay's copy of it arrived first. Counted for the first "
              'relay alone, the second relay would seem to have sent nothing, '
              'and the cursor would jump to 105, past its event at 108',
        );
        expect(result.isComplete, isTrue);
      });

      test('pages a single relay the way the labeler history pager (#8817) '
          'does, then confirms the end', () async {
        final stored = await eventsAt([106, 105, 104, 103, 102, 101]);
        final relay = await addStore('wss://relay.example', stored);

        final result = await nostr.readAllEvents(_textNotes(), pageSize: 2);

        expect(_idsOf(result.events), unorderedEquals(_idsOf(stored)));
        expect(
          _untilsOf(relay),
          [null, 105, 104, 103, 102, 101, 100],
          reason:
              'up to 101 these are the untils #8817 sends, each page starting '
              "at the last one's oldest second. #8817 takes the short answer "
              'at 101 as the end; this walk asks once more below it, since a '
              'relay may stop short of the page size without saying so',
        );
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
            7,
            reason:
                'once the busy relay runs out, the cursor drops straight to '
                "the early relay's event, not a page per second down to 50",
          );
          expect(result.isComplete, isTrue);
        },
      );
    });

    group('with block-listed events', () {
      test('keeps following a relay whose page the block list '
          'thinned', () async {
        final thinned = await eventsAt([110, 109, 108, 107, 106, 105]);
        final [early] = await eventsAt([100]);
        final hidden = thinned[1];
        blockList.ids.add(hidden.id);
        await addStore('wss://thinned.example', thinned);
        await addStore('wss://early.example', [early]);

        final result = await nostr.readAllEvents(_textNotes(), pageSize: 3);

        expect(
          _idsOf(result.events),
          unorderedEquals(
            _idsOf([...thinned.where((event) => event != hidden), early]),
          ),
          reason:
              'the relay filled its first page with 110, 109 and 108, and '
              'the block list hid 109: the cursor has to follow the relay to '
              '108 rather than jump past 107, 106 and 105',
        );
        expect(result.isComplete, isTrue);
      });
    });

    group('when the walk is done', () {
      test('stops on an empty settled page, after asking for it', () async {
        final stored = await eventsAt([103, 102, 101]);
        final relay = await addStore('wss://relay.example', stored);

        final result = await nostr.readAllEvents(_textNotes(), pageSize: 5);

        expect(_idsOf(result.events), unorderedEquals(_idsOf(stored)));
        expect(
          _untilsOf(relay),
          [null, 101, 100],
          reason:
              'a short page is not taken as the end: the walk asks for the '
              'second it ended on again, steps past it once nothing new '
              'comes back, and only that empty page ends it',
        );
        expect(result.isComplete, isTrue);
        expect(result.stoppedBy, isNull);
        expect(result.pages, 3);
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
      test('stops incomplete, and the completion line counts the events '
          'outside the filter', () async {
        final stored = await eventsAt([103, 102, 101]);
        final relay = await addStore('wss://ignores-until.example', stored)
          ..ignoresUntil = true;

        final result = await nostr.readAllEvents(_textNotes(), pageSize: 2);

        // Every page gets the same two newest events back, and the pool's
        // filter gate drops the one above `until`. What is left brings
        // nothing new, from a relay that did not honour the filter.
        expect(_untilsOf(relay), [null, 102]);
        expect(result.isComplete, isFalse);
        expect(
          result.stoppedBy,
          QueryEnd.complete,
          reason:
              'the page settled; it stopped the walk by bringing nothing new '
              'from a relay that may be capped',
        );
        expect(_idsOf(result.events), unorderedEquals(_idsOf(stored.take(2))));
        expect([
          for (final entry in diagnostics)
            if (entry.site == RelayDiagnosticSite.queryCompletion)
              entry.message,
        ], contains(contains('1 event outside the filter')));
      });

      test('stops incomplete on a page whose events all fell outside the '
          'filter', () async {
        final relay =
            await addStore(
                'wss://ignores-until.example',
                await eventsAt([103, 102]),
              )
              ..ignoresUntil = true;

        final result = await nostr.readAllEvents({
          ..._textNotes(),
          'until': 100,
        }, pageSize: 5);

        expect(relay.requests, hasLength(1));
        expect(
          result.events,
          isEmpty,
          reason: 'the pool drops both events, newer than the until asked for',
        );
        expect(
          result.isComplete,
          isFalse,
          reason:
              'an empty page ends the walk complete only when no relay may be '
              'holding events back, and one that ignored the filter may be',
        );
        expect(result.stoppedBy, QueryEnd.complete);
      });

      test('ends the same walk complete for a relay that honours '
          'until', () async {
        final stored = await eventsAt([103, 102, 101]);
        await addStore('wss://relay.example', stored);

        final result = await nostr.readAllEvents(_textNotes(), pageSize: 2);

        expect(_idsOf(result.events), unorderedEquals(_idsOf(stored)));
        expect(result.isComplete, isTrue);
        expect([
          for (final entry in diagnostics) entry.message,
        ], everyElement(isNot(contains('outside the filter'))));
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

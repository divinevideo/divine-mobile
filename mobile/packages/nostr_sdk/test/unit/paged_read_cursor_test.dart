// ABOUTME: Tests the until cursor of Nostr.readAllEvents: each rule on one
// ABOUTME: page, then whole walks over model relays, review repros included.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/relay/query_outcome.dart';
import 'package:nostr_sdk/src/relay/paged_read_cursor.dart';

const _first = 'wss://first.example';
const _second = 'wss://second.example';

QueryRelaySummary _relay(
  String url, {
  required int oldest,
  bool capped = false,
}) => QueryRelaySummary(url: url, oldestCreatedAt: oldest, capped: capped);

/// The step after a settled page that no relay confirmed exhaustive. Unless
/// [sentTo] says otherwise, every relay in [previousRelays] and [relays] took
/// the page's REQ, and unless [firstSentTo] says otherwise, every relay that
/// took this page's REQ took the first page's too. Unless
/// [cappedWithoutEvents] says otherwise, no relay may have been capped on a
/// page it sent no matching event to.
PagedReadStep _afterSettledPage(
  int? cursor,
  List<QueryRelaySummary> relays, {
  int? since,
  bool possiblyCapped = false,
  List<QueryRelaySummary> previousRelays = const [],
  List<String>? sentTo,
  List<String>? firstSentTo,
  List<String> cappedWithoutEvents = const [],
}) {
  final took =
      sentTo ??
      [
        for (final relay in [...previousRelays, ...relays]) relay.url,
      ];
  return nextPagedReadStep(
    cursor: cursor,
    since: since,
    relays: relays,
    previousRelays: previousRelays,
    sentTo: took,
    firstSentTo: firstSentTo ?? took,
    settled: true,
    confirmedExhaustive: false,
    possiblyCapped: possiblyCapped,
    cappedWithoutEvents: cappedWithoutEvents,
  );
}

Matcher _readsAt(int until) =>
    isA<ReadPageAt>().having((step) => step.until, 'until', until);

Matcher _ends({required bool complete}) => isA<EndPagedRead>().having(
  (step) => step.isComplete,
  'isComplete',
  complete,
);

/// An event a model relay holds. Relays holding the same [id] hold the same
/// event.
typedef _Held = ({String id, int createdAt});

/// Events `<prefix>-0`, `<prefix>-1`, …, one per entry of [createdAts].
List<_Held> _held(String prefix, List<int> createdAts) => [
  for (var i = 0; i < createdAts.length; i++)
    (id: '$prefix-$i', createdAt: createdAts[i]),
];

Set<String> _idsOf(Iterable<_Held> events) => {
  for (final event in events) event.id,
};

/// A relay as the cursor rule meets it: it answers a page with its newest
/// events at or before the page's `until` and at or after its `since`, ties
/// in id order, at most the page size, its NIP-11 [maxLimit] or its
/// [silentCap], whichever is lowest.
class _ModelRelay {
  _ModelRelay(
    this.url,
    this.held, {
    this.maxLimit,
    this.silentCap,
    this.ignoresUntil = false,
    this.missesPages = const {},
  });

  final String url;
  final List<_Held> held;

  /// The limit the relay publishes, so a page it fills to it counts as
  /// capped.
  final int? maxLimit;

  /// A limit the relay keeps to itself.
  final int? silentCap;

  /// When true, every page gets the relay's newest events whatever `until`
  /// asked for.
  final bool ignoresUntil;

  /// The 1-based numbers of the pages whose REQ the relay does not take, the
  /// way a relay whose socket write fails does not.
  final Set<int> missesPages;

  List<_Held> answer(int? until, int limit, {int? since}) {
    final eligible = [
      for (final event in held)
        if ((ignoresUntil || until == null || event.createdAt <= until) &&
            (since == null || event.createdAt >= since))
          event,
    ]..sort(_newestFirst);
    var take = limit;
    for (final cap in [maxLimit, silentCap].nonNulls) {
      take = math.min(take, cap);
    }
    return eligible.take(take).toList();
  }
}

int _newestFirst(_Held a, _Held b) {
  final byAge = b.createdAt.compareTo(a.createdAt);
  return byAge != 0 ? byAge : a.id.compareTo(b.id);
}

/// A whole paged read over [relays], every page settling, with only
/// [nextPagedReadStep] choosing where each page starts. Each page is judged
/// the way the relay pool judges it: events after `until` fall outside the
/// filter and are not counted, [hidden] events are counted but never
/// delivered, a relay may be capped when it answered outside the filter or
/// filled the page or its published limit, and a relay that misses a page
/// neither takes its REQ nor answers it.
({Set<String> collected, bool isComplete, List<int?> untils}) _walk(
  List<_ModelRelay> relays, {
  required int pageSize,
  int? until,
  int? since,
  Set<String> hidden = const {},
}) {
  final collected = <String>{};
  final untils = <int?>[];
  var cursor = until;
  var previousSummaries = const <QueryRelaySummary>[];
  var firstSentTo = const <String>[];
  while (untils.length < 50) {
    untils.add(cursor);
    final page = untils.length;
    final summaries = <QueryRelaySummary>[];
    final sentTo = <String>[];
    final cappedWithoutEvents = <String>[];
    var possiblyCapped = false;
    for (final relay in relays) {
      if (relay.missesPages.contains(page)) continue;
      sentTo.add(relay.url);
      final sent = relay.answer(cursor, pageSize, since: since);
      final counted = [
        for (final event in sent)
          if ((cursor == null || event.createdAt <= cursor) &&
              (since == null || event.createdAt >= since))
            event,
      ];
      final capped =
          counted.length < sent.length ||
          counted.length >= math.min(pageSize, relay.maxLimit ?? pageSize);
      possiblyCapped = possiblyCapped || capped;
      if (counted.isEmpty) {
        if (capped) cappedWithoutEvents.add(relay.url);
        continue;
      }
      summaries.add(
        QueryRelaySummary(
          url: relay.url,
          oldestCreatedAt: counted.last.createdAt,
          capped: capped,
        ),
      );
      collected.addAll([
        for (final event in counted)
          if (!hidden.contains(event.id)) event.id,
      ]);
    }
    if (page == 1) firstSentTo = sentTo;
    switch (nextPagedReadStep(
      cursor: cursor,
      since: since,
      relays: summaries,
      previousRelays: previousSummaries,
      sentTo: sentTo,
      firstSentTo: firstSentTo,
      settled: true,
      confirmedExhaustive: false,
      possiblyCapped: possiblyCapped,
      cappedWithoutEvents: cappedWithoutEvents,
    )) {
      case ReadPageAt(until: final next):
        cursor = next;
        previousSummaries = summaries;
      case EndPagedRead(:final isComplete):
        return (collected: collected, isComplete: isComplete, untils: untils);
    }
  }
  return (collected: collected, isComplete: false, untils: untils);
}

void main() {
  group('nextPagedReadStep', () {
    group('on a page that did not settle', () {
      test('ends the walk incomplete', () {
        expect(
          nextPagedReadStep(
            cursor: 110,
            since: null,
            relays: [_relay(_first, oldest: 100)],
            previousRelays: const [],
            sentTo: const [_first],
            firstSentTo: const [_first],
            settled: false,
            confirmedExhaustive: false,
            possiblyCapped: false,
            cappedWithoutEvents: const [],
          ),
          _ends(complete: false),
        );
      });

      test('ends the walk incomplete even when every relay that answered '
          'confirmed it exhaustive', () {
        expect(
          nextPagedReadStep(
            cursor: 110,
            since: null,
            relays: [_relay(_first, oldest: 100)],
            previousRelays: const [],
            sentTo: const [_first],
            firstSentTo: const [_first],
            settled: false,
            confirmedExhaustive: true,
            possiblyCapped: false,
            cappedWithoutEvents: const [],
          ),
          _ends(complete: false),
        );
      });
    });

    group('on a settled page', () {
      test('ends the walk complete when every relay confirmed it '
          'exhaustive', () {
        expect(
          nextPagedReadStep(
            cursor: 110,
            since: null,
            relays: [_relay(_first, oldest: 100)],
            previousRelays: const [],
            sentTo: const [_first],
            firstSentTo: const [_first],
            settled: true,
            confirmedExhaustive: true,
            possiblyCapped: false,
            cappedWithoutEvents: const [],
          ),
          _ends(complete: true),
        );
      });

      test('ends the walk complete when no relay sent an event', () {
        expect(_afterSettledPage(100, const []), _ends(complete: true));
      });

      test('ends the walk incomplete when no relay sent an event and one may '
          'be capped', () {
        // A relay whose every event fell outside the filter sent nothing the
        // walk can page by, yet may be holding events back.
        expect(
          _afterSettledPage(100, const [], possiblyCapped: true),
          _ends(complete: false),
        );
      });

      test("after the first page, starts at the latest of the relays' oldest "
          'created_at', () {
        expect(
          _afterSettledPage(null, [
            _relay(_first, oldest: 108),
            _relay(_second, oldest: 50),
          ]),
          _readsAt(108),
        );
      });

      test('moves to the latest oldest created_at below the cursor', () {
        expect(
          _afterSettledPage(108, [
            _relay(_first, oldest: 106),
            _relay(_second, oldest: 50),
          ]),
          _readsAt(106),
        );
      });

      test('stops at a capped relay whose page sits in the cursor second, '
          'even while another reaches further back', () {
        // It may hold more events in that second than any until can reach.
        expect(
          _afterSettledPage(104, [
            _relay(_first, oldest: 104, capped: true),
            _relay(_second, oldest: 90),
          ], possiblyCapped: true),
          _ends(complete: false),
        );
      });

      test('steps one second back from an uncapped relay whose page sits in '
          'the cursor second, even while another reaches further back', () {
        // Uncapped may still mean capped without saying so: whatever the
        // relay holds below this second is only safe from a page at 109.
        expect(
          _afterSettledPage(110, [
            _relay(_first, oldest: 105),
            _relay(_second, oldest: 110),
          ]),
          _readsAt(109),
        );
      });
    });

    group('when a relay may have been capped on a page it sent no matching '
        'event to', () {
      test('ends the walk incomplete', () {
        // It named no created_at for the cursor to follow, so the page below
        // is not known to be below what it withheld.
        expect(
          _afterSettledPage(
            null,
            [_relay(_second, oldest: 1000, capped: true)],
            sentTo: [_first, _second],
            possiblyCapped: true,
            cappedWithoutEvents: [_first],
          ),
          _ends(complete: false),
        );
      });

      test('ends the walk incomplete even when every relay that answered '
          'confirmed it exhaustive', () {
        expect(
          nextPagedReadStep(
            cursor: null,
            since: null,
            relays: [_relay(_second, oldest: 1000, capped: true)],
            previousRelays: const [],
            sentTo: const [_first, _second],
            firstSentTo: const [_first, _second],
            settled: true,
            confirmedExhaustive: true,
            possiblyCapped: true,
            cappedWithoutEvents: const [_first],
          ),
          _ends(complete: false),
        );
      });

      test('keeps walking when no relay was judged capped without an '
          'event', () {
        // A relay that sent the page nothing and said nothing is not capped,
        // so its silence must not stop the walk.
        expect(
          _afterSettledPage(
            null,
            [_relay(_second, oldest: 1000, capped: true)],
            sentTo: [_first, _second],
            possiblyCapped: true,
          ),
          _readsAt(1000),
        );
      });
    });

    group("at the filter's since", () {
      test('ends the walk complete rather than ask for a page below it', () {
        expect(
          _afterSettledPage(100, [_relay(_first, oldest: 100)], since: 100),
          _ends(complete: true),
        );
      });

      test('ends it incomplete there when a relay may be capped', () {
        // As on a page no relay sent an event: one whose every event fell
        // outside the filter gave nothing to page by.
        expect(
          _afterSettledPage(
            100,
            [_relay(_first, oldest: 100)],
            since: 100,
            possiblyCapped: true,
          ),
          _ends(complete: false),
        );
      });

      test('still asks for the second at since itself', () {
        expect(
          _afterSettledPage(101, [_relay(_first, oldest: 101)], since: 100),
          _readsAt(100),
        );
      });
    });

    group('when a relay that sent the last page events misses this one', () {
      test('ends the walk incomplete', () {
        // Nothing was asked of it below the cursor, where it may hold more.
        expect(
          _afterSettledPage(
            109,
            [_relay(_second, oldest: 50)],
            previousRelays: [
              _relay(_first, oldest: 109, capped: true),
              _relay(_second, oldest: 50),
            ],
            sentTo: [_second],
          ),
          _ends(complete: false),
        );
      });

      test('ends the walk incomplete even when every relay that answered '
          'confirmed it exhaustive', () {
        expect(
          nextPagedReadStep(
            cursor: 109,
            since: null,
            relays: [_relay(_second, oldest: 50)],
            previousRelays: [
              _relay(_first, oldest: 109, capped: true),
              _relay(_second, oldest: 50),
            ],
            sentTo: const [_second],
            firstSentTo: const [_first, _second],
            settled: true,
            confirmedExhaustive: true,
            possiblyCapped: false,
            cappedWithoutEvents: const [],
          ),
          _ends(complete: false),
        );
      });

      test('keeps walking when that relay took the REQ and sent nothing', () {
        expect(
          _afterSettledPage(
            108,
            [_relay(_second, oldest: 50)],
            previousRelays: [
              _relay(_first, oldest: 108, capped: true),
              _relay(_second, oldest: 50),
            ],
            sentTo: [_first, _second],
          ),
          _readsAt(50),
        );
      });
    });

    group("when a relay takes a page's REQ that missed the first page's", () {
      test('ends the walk incomplete', () {
        // Every page it did take asked only at or below that page's cursor,
        // so whatever it holds above 108 was never read.
        expect(
          _afterSettledPage(
            108,
            [
              _relay(_first, oldest: 106, capped: true),
              _relay(_second, oldest: 107),
            ],
            previousRelays: [_relay(_first, oldest: 108, capped: true)],
            firstSentTo: [_first],
          ),
          _ends(complete: false),
        );
      });

      test('ends the walk incomplete even when every relay that answered '
          'confirmed it exhaustive', () {
        expect(
          nextPagedReadStep(
            cursor: 108,
            since: null,
            relays: [_relay(_second, oldest: 107)],
            previousRelays: [_relay(_first, oldest: 108, capped: true)],
            sentTo: const [_first, _second],
            firstSentTo: const [_first],
            settled: true,
            confirmedExhaustive: true,
            possiblyCapped: false,
            cappedWithoutEvents: const [],
          ),
          _ends(complete: false),
        );
      });

      test('keeps walking when every relay that took this page took the '
          'first page too', () {
        expect(
          _afterSettledPage(
            108,
            [_relay(_second, oldest: 107)],
            previousRelays: [_relay(_second, oldest: 108)],
            sentTo: [_second],
            firstSentTo: [_first, _second],
          ),
          _readsAt(107),
        );
      });
    });

    group('over a whole walk', () {
      test('reads every event of a relay that stops short of the page size '
          'without saying so', () {
        final relay = _ModelRelay(
          _first,
          _held('a', [105, 104, 104]),
          silentCap: 2,
        );

        final walk = _walk([relay], pageSize: 5);

        expect(walk.collected, _idsOf(relay.held));
        expect(walk.untils, [null, 104, 103]);
        expect(walk.isComplete, isTrue);
      });

      test('reads every event of such a relay while another reaches further '
          'back', () {
        final capped = _ModelRelay(
          _first,
          _held('x', [110, 109, 108, 107, 106, 105, 104, 103, 102, 101]),
          silentCap: 3,
        );
        final sparse = _ModelRelay(_second, _held('y', [50]));

        final walk = _walk([capped, sparse], pageSize: 5);

        expect(walk.collected, {
          ..._idsOf(capped.held),
          ..._idsOf(sparse.held),
        });
        expect(walk.isComplete, isTrue);
      });

      test('stops incomplete when the newest second holds more than a '
          'page', () {
        final relay = _ModelRelay(_first, _held('a', [104, 104, 104, 103]));

        final walk = _walk([relay], pageSize: 2);

        expect(walk.untils, [null, 104]);
        expect(walk.collected, hasLength(2));
        expect(walk.isComplete, isFalse);
      });

      test('keeps following a relay whose page the block list thinned', () {
        final thinned = _ModelRelay(
          _first,
          _held('a', [110, 109, 108, 107, 106, 105]),
        );
        final early = _ModelRelay(_second, _held('b', [100]));
        final hidden = {thinned.held[1].id};

        final walk = _walk([thinned, early], pageSize: 3, hidden: hidden);

        expect(
          walk.collected,
          {..._idsOf(thinned.held), ..._idsOf(early.held)}.difference(hidden),
        );
        expect(walk.isComplete, isTrue);
      });

      test('follows a capped relay whose whole page the block list hid', () {
        final hiddenFirst = _ModelRelay(
          _first,
          _held('a', [110, 109, 108, 107, 106, 105]),
        );
        final early = _ModelRelay(_second, _held('b', [100]));
        final hidden = _idsOf(hiddenFirst.held.take(3));

        final walk = _walk([hiddenFirst, early], pageSize: 3, hidden: hidden);

        expect(
          walk.collected,
          {
            ..._idsOf(hiddenFirst.held),
            ..._idsOf(early.held),
          }.difference(hidden),
          reason:
              'the relay sent 110, 109 and 108 and the block list hid all '
              'three; its reach is still 108, so the cursor cannot jump to '
              'the other relay at 100 past 107, 106 and 105',
        );
        expect(walk.isComplete, isTrue);
      });

      test("reads every event of a dense relay around a sparse relay's event "
          'inside its history', () {
        final dense = _ModelRelay(
          _first,
          _held('d', [110, 109, 108, 107, 106, 105, 104, 103, 102, 101]),
        );
        final sparse = _ModelRelay(_second, _held('s', [105]));

        final walk = _walk([dense, sparse], pageSize: 3);

        expect(walk.collected, {..._idsOf(dense.held), ..._idsOf(sparse.held)});
        expect(
          walk.isComplete,
          isTrue,
          reason:
              "the sparse relay at the cursor second is not capped, and the "
              'dense relay, capped below it, is not in that second',
        );
      });

      test('pages a single relay the way the labeler history pager (#8817) '
          'does, then confirms the end', () {
        final relay = _ModelRelay(
          _first,
          _held('a', [106, 105, 104, 103, 102, 101]),
        );

        final walk = _walk([relay], pageSize: 2);

        expect(walk.collected, _idsOf(relay.held));
        expect(walk.untils, [null, 105, 104, 103, 102, 101, 100]);
        expect(walk.isComplete, isTrue);
      });

      test('reads a dense relay and a sparse relay that reaches further '
          'back', () {
        final dense = _ModelRelay(
          _first,
          _held('d', [110, 109, 108, 107, 106, 105]),
        );
        final sparse = _ModelRelay(_second, _held('s', [100]));

        final walk = _walk([dense, sparse], pageSize: 3);

        expect(walk.collected, {..._idsOf(dense.held), ..._idsOf(sparse.held)});
        expect(walk.untils, [null, 108, 106, 105, 104, 100, 99]);
        expect(walk.isComplete, isTrue);
      });

      test('counts an event two relays both send for each of them', () {
        const shared = (id: 'shared', createdAt: 110);
        final first = _ModelRelay(_first, [
          shared,
          (id: 'first', createdAt: 105),
        ]);
        final second = _ModelRelay(_second, [
          shared,
          (id: 'second', createdAt: 108),
        ], silentCap: 1);

        final walk = _walk([first, second], pageSize: 3);

        expect(walk.collected, {'shared', 'first', 'second'});
        expect(walk.isComplete, isTrue);
      });

      test('steps one second back, not past, from a relay that may hold more '
          'below the cursor second', () {
        final first = _ModelRelay(_first, _held('a', [110, 105]));
        final second = _ModelRelay(
          _second,
          _held('b', [110, 108]),
          silentCap: 1,
        );

        final walk = _walk([first, second], pageSize: 3);

        expect(
          walk.collected,
          {..._idsOf(first.held), ..._idsOf(second.held)},
          reason:
              'at 110 the second relay sent only its event there, uncapped '
              'as far as anyone can tell; moving the cursor to the first '
              "relay's 105 would skip its event at 108",
        );
        expect(walk.isComplete, isTrue);
      });

      test('loses only the rest of a second a relay silently caps within, '
          'the limit readAllEvents documents', () {
        final relay = _ModelRelay(
          _first,
          _held('a', [105, 104, 104, 104, 103]),
          silentCap: 2,
        );

        final walk = _walk([relay], pageSize: 5);

        expect(
          walk.collected,
          _idsOf(relay.held).difference({'a-3'}),
          reason:
              'nothing marks a page of two capped when five were asked for, '
              'so the cursor steps past 104 with its third event unread',
        );
        expect(walk.isComplete, isTrue);
      });

      test('stops incomplete, rather than skip part of a second, at a relay '
          'that publishes the limit it stopped at', () {
        final relay = _ModelRelay(
          _first,
          _held('a', [105, 104, 104, 104, 103]),
          maxLimit: 2,
        );

        final walk = _walk([relay], pageSize: 5);

        expect(walk.untils, [null, 104]);
        expect(walk.collected, hasLength(3));
        expect(walk.isComplete, isFalse);
      });

      test('stops incomplete at a relay that answers outside the filter', () {
        final relay = _ModelRelay(
          _first,
          _held('a', [103, 102, 101]),
          ignoresUntil: true,
        );

        final walk = _walk([relay], pageSize: 2);

        expect(walk.untils, [null, 102]);
        expect(walk.isComplete, isFalse);
      });

      test('stops incomplete on a page whose events all fell outside the '
          'filter', () {
        final relay = _ModelRelay(
          _first,
          _held('a', [103, 102]),
          ignoresUntil: true,
        );

        final walk = _walk([relay], pageSize: 5, until: 100);

        expect(walk.untils, [100]);
        expect(walk.collected, isEmpty);
        expect(walk.isComplete, isFalse);
      });

      test('stops incomplete at a relay that misses the page after one it '
          'sent events on', () {
        final capped = _ModelRelay(
          _first,
          _held('x', [110, 109, 108, 107, 106, 105, 104, 103, 102, 101]),
          missesPages: {2},
        );
        final sparse = _ModelRelay(_second, _held('y', [50]));

        final walk = _walk([capped, sparse], pageSize: 2);

        expect(walk.untils, [null, 109]);
        expect(walk.collected, {'x-0', 'x-1', 'y-0'});
        expect(
          walk.isComplete,
          isFalse,
          reason:
              'the capped relay sent the first page 110 and 109, then missed '
              "the page at 109; following the sparse relay's 50 from there "
              'would skip its 108 down to 101',
        );
      });

      test('stops incomplete at a relay that first takes part on a later '
          'page', () {
        final joiner = _ModelRelay(
          _first,
          _held('x', [110, 109, 108]),
          missesPages: {1},
        );
        final early = _ModelRelay(_second, _held('y', [50]));

        final walk = _walk([joiner, early], pageSize: 2);

        expect(walk.untils, [null, 50]);
        expect(walk.collected, {'y-0'});
        expect(
          walk.isComplete,
          isFalse,
          reason:
              'the first page never reached the relay holding 110 down to '
              '108, and the page that did reach it asked only at or below the '
              "other relay's 50",
        );
      });

      test("asks for no page below the filter's since", () {
        final relay = _ModelRelay(_first, _held('a', [105, 100, 95]));

        final walk = _walk([relay], pageSize: 2, since: 100);

        expect(walk.untils, [null, 100]);
        expect(walk.collected, {'a-0', 'a-1'});
        expect(walk.isComplete, isTrue);
      });

      test("reaches a relay's early event in a bounded number of pages", () {
        final busy = _ModelRelay(_first, _held('a', [110, 109, 108, 107]));
        final early = _ModelRelay(_second, _held('b', [50]));

        final walk = _walk([busy, early], pageSize: 2);

        expect(walk.collected, {..._idsOf(busy.held), ..._idsOf(early.held)});
        expect(
          walk.untils,
          hasLength(7),
          reason:
              "once the busy relay runs out the cursor drops to the early "
              "relay's event, not a page per second down to 50",
        );
        expect(walk.isComplete, isTrue);
      });
    });
  });
}

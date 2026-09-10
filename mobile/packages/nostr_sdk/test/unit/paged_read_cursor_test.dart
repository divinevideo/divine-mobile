// ABOUTME: Tests the until cursor of Nostr.readAllEvents one page at a time,
// ABOUTME: including the pages it once walked past unread events on.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/src/relay/paged_read_cursor.dart';

final _pubkey = getPublicKey(
  '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
);

const _first = 'wss://first.example';
const _second = 'wss://second.example';

var _contentNumber = 0;

/// A text note at [createdAt] as a page delivers it: naming the relays in
/// [from] that sent it or, when [cached], the ones a cache relay's copy first
/// came from.
Event _at(
  int createdAt, {
  List<String> from = const [_first],
  bool cached = false,
}) => Event(_pubkey, 1, [], 'page-${_contentNumber++}', createdAt: createdAt)
  ..sources = [...from]
  ..cacheEvent = cached;

Matcher _readsAt(int until) =>
    isA<ReadPageAt>().having((step) => step.until, 'until', until);

Matcher _ends({required bool complete}) => isA<EndPagedRead>().having(
  (step) => step.isComplete,
  'isComplete',
  complete,
);

void main() {
  group('nextPagedReadStep', () {
    group('on a page no relay sent an event to', () {
      test('ends the walk complete', () {
        expect(
          nextPagedReadStep(
            cursor: 100,
            events: const [],
            broughtNew: false,
            possiblyCapped: false,
          ),
          _ends(complete: true),
        );
      });

      test('ends the walk incomplete when a relay may be capped', () {
        // A relay whose every event fell outside the filter sent nothing the
        // walk can see, yet may be holding events back.
        expect(
          nextPagedReadStep(
            cursor: 100,
            events: const [],
            broughtNew: false,
            possiblyCapped: true,
          ),
          _ends(complete: false),
        );
      });

      test('counts a page of cached copies alone as empty', () {
        expect(
          nextPagedReadStep(
            cursor: 100,
            events: [_at(90, cached: true)],
            broughtNew: true,
            possiblyCapped: false,
          ),
          _ends(complete: true),
        );
      });
    });

    group('when the page brought new events', () {
      test('starts the next page inside the second the page split', () {
        // A relay that stops at two events without saying so, holding 105
        // and two events at 104, sent 105 and one of them.
        expect(
          nextPagedReadStep(
            cursor: null,
            events: [_at(105), _at(104)],
            broughtNew: true,
            possiblyCapped: false,
          ),
          _readsAt(104),
        );
      });

      test('stays on the cursor second while it brings something new', () {
        // The same relay, asked at 104, sent both events there.
        expect(
          nextPagedReadStep(
            cursor: 104,
            events: [_at(104), _at(104)],
            broughtNew: true,
            possiblyCapped: false,
          ),
          _readsAt(104),
        );
      });

      test("takes the latest of the relays' oldest created_at, not the "
          'earliest', () {
        // A relay that stops at three events without saying so, beside one
        // whose only event is far older: the older one must not pull the
        // cursor past the events the first has not sent yet.
        expect(
          nextPagedReadStep(
            cursor: null,
            events: [
              _at(110),
              _at(109),
              _at(108),
              _at(50, from: const [_second]),
            ],
            broughtNew: true,
            possiblyCapped: false,
          ),
          _readsAt(108),
        );
      });

      test('follows a relay whose page the block list thinned', () {
        // The relay sent 110, 109 and 108, and the block list hid 109. How
        // many events a relay delivered says nothing about where it stopped.
        expect(
          nextPagedReadStep(
            cursor: null,
            events: [
              _at(110),
              _at(108),
              _at(100, from: const [_second]),
            ],
            broughtNew: true,
            possiblyCapped: true,
          ),
          _readsAt(108),
        );
      });

      test('counts an event for every relay that sent it', () {
        // The second relay sent only the event both relays hold. Counted for
        // the first relay alone, the second would seem to have sent nothing.
        expect(
          nextPagedReadStep(
            cursor: null,
            events: [
              _at(110, from: const [_first, _second]),
              _at(105),
            ],
            broughtNew: true,
            possiblyCapped: false,
          ),
          _readsAt(110),
        );
      });

      test('leaves cached copies out of the frontier', () {
        expect(
          nextPagedReadStep(
            cursor: null,
            events: [_at(110), _at(109), _at(80, cached: true)],
            broughtNew: true,
            possiblyCapped: false,
          ),
          _readsAt(109),
        );
      });
    });

    group('when the page brought nothing new', () {
      test('drops the cursor to a frontier below it', () {
        // The capped relay has run out; only the older relay's 50 came back.
        expect(
          nextPagedReadStep(
            cursor: 100,
            events: [
              _at(50, from: const [_second]),
            ],
            broughtNew: false,
            possiblyCapped: false,
          ),
          _readsAt(50),
        );
      });

      test('steps one second back from a frontier at the cursor', () {
        // The relay that stops at two events without saying so sent the same
        // two events at 104 again.
        expect(
          nextPagedReadStep(
            cursor: 104,
            events: [_at(104), _at(104)],
            broughtNew: false,
            possiblyCapped: false,
          ),
          _readsAt(103),
        );
      });

      test('ends the walk incomplete at the cursor second when a relay may be '
          'capped', () {
        // Asked for two events, the relay sent the same two at 104 again: a
        // third may be there, and no until can page within one second.
        expect(
          nextPagedReadStep(
            cursor: 104,
            events: [_at(104), _at(104)],
            broughtNew: false,
            possiblyCapped: true,
          ),
          _ends(complete: false),
        );
      });
    });
  });
}

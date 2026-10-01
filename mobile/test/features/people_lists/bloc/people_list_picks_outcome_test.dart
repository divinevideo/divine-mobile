// ABOUTME: Tests for awaitRefusedPicks: which outcome on the bloc's state
// ABOUTME: answers for the picks a sheet sent, and when the wait ends.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/people_lists/bloc/people_list_picks_outcome.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';

// Full-length Nostr pubkeys — never truncate.
const String _ownerPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const String _pubkey =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const String _otherPubkey =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

PeopleListsPicksOutcome _outcome(
  int sequence, {
  Object requestId = 'batch',
  String pubkey = _pubkey,
  int refused = 0,
}) => PeopleListsPicksOutcome(
  requestId: requestId,
  sequence: sequence,
  pubkey: pubkey,
  refused: refused,
);

PeopleListsState _state({PeopleListsPicksOutcome? outcome}) => PeopleListsState(
  status: PeopleListsStatus.ready,
  ownerPubkey: _ownerPubkey,
  lastPicksOutcome: outcome,
);

void main() {
  group('awaitRefusedPicks', () {
    late StreamController<PeopleListsState> states;

    setUp(() {
      states = StreamController<PeopleListsState>();
    });

    tearDown(() {
      // A single-subscription stream nobody listened to never reports done.
      final listened = states.hasListener;
      final closed = states.close();
      return listened ? closed : null;
    });

    Future<int> wait({PeopleListsPicksOutcome? before}) => awaitRefusedPicks(
      states: states.stream,
      requestId: 'batch',
      ownerPubkey: _ownerPubkey,
      before: before,
      pubkey: _pubkey,
    );

    test('answers with the first outcome for the person', () async {
      final future = wait();
      states
        ..add(_state())
        ..add(_state(outcome: _outcome(1, refused: 2)));

      expect(await future, 2);
    });

    test('skips the outcome it saw when the picks were sent', () async {
      final stale = _outcome(3, refused: 1);
      final future = wait(before: stale);
      states
        ..add(_state(outcome: stale))
        ..add(_state(outcome: _outcome(4)));

      expect(await future, 0);
    });

    test("skips another person's outcome", () async {
      final future = wait();
      states
        ..add(_state(outcome: _outcome(1, pubkey: _otherPubkey, refused: 1)))
        ..add(_state(outcome: _outcome(2)));

      expect(await future, 0);
    });

    test('ignores another batch for the same person', () async {
      final future = wait();
      states
        ..add(
          _state(outcome: _outcome(1, requestId: 'other-batch', refused: 3)),
        )
        ..add(_state(outcome: _outcome(2, refused: 1)));

      expect(await future, 1);
    });

    test('settles quietly when the active owner changes', () async {
      final future = wait();
      states.add(const PeopleListsState(ownerPubkey: _otherPubkey));

      expect(await future, 0);
    });

    test('settles quietly when the feature is disabled', () async {
      final future = wait();
      states.add(
        const PeopleListsState(ownerPubkey: _ownerPubkey, enabled: false),
      );

      expect(await future, 0);
    });

    test('answers 0 when the stream closes first', () async {
      final future = wait();
      await states.close();

      expect(await future, 0);
    });
  });
}

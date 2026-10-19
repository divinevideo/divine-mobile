// ABOUTME: Verifies explicit EOSE fixtures preserve transport failure semantics.
// ABOUTME: Missing callback wiring, errors and cancellation cannot imply success.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event.dart';

import 'completed_owned_list_snapshot.dart';

void main() {
  group('completed owned-list snapshot fixture', () {
    Event event(int at) => Event('a' * 64, 30005, const [], '', createdAt: at);

    Invocation invocation(void Function() onEose) => Invocation.method(
      #subscribe,
      const [],
      {#closeOnEose: true, #onEose: onEose},
    );

    test('reports EOSE only after every event reaches the reader', () async {
      final first = event(1);
      final second = event(2);
      final observed = <Event>[];
      var completions = 0;
      final stream = completedOwnedListSnapshot(
        invocation(() {
          expect(observed, [first, second]);
          completions++;
        }),
        [first, second],
      );
      await stream.forEach(observed.add);
      expect(completions, 1);
    });

    test(
      'consumer cancellation before the snapshot ends does not report EOSE',
      () async {
        var completions = 0;
        final iterator = StreamIterator<Event>(
          completedOwnedListSnapshot(
            invocation(() => completions++),
            [event(1), event(2)],
          ),
        );
        expect(await iterator.moveNext(), isTrue);
        await iterator.cancel();
        expect(completions, 0);
      },
    );

    test('source failure after a partial event does not report EOSE', () async {
      var completions = 0;
      Iterable<Event> partial() sync* {
        yield event(1);
        throw StateError('Controlled source failure');
      }

      await expectLater(
        completedOwnedListSnapshot(
          invocation(() => completions++),
          partial(),
        ).toList(),
        throwsA(isA<StateError>()),
      );
      expect(completions, 0);
    });

    test(
      'missing protocol callback wiring fails instead of fabricating completion',
      () async {
        await expectLater(
          completedOwnedListSnapshot(
            Invocation.method(#subscribe, const [], {#closeOnEose: true}),
            const [],
          ).toList(),
          throwsA(isA<StateError>()),
        );
      },
    );
  });
}

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/account_state_write_barrier.dart';

void main() {
  group('account state write barrier', () {
    test(
      'retains disposed writers and drains all writers only for the owner',
      () async {
        final barrier = AccountStateWriteBarrier();
        final first = Completer<void>();
        final second = Completer<void>();
        var firstCalls = 0;
        var otherCalls = 0;
        final dispose = barrier.register('owner', () {
          firstCalls++;
          return first.future;
        });
        barrier.register('owner', () => second.future);
        barrier.register('other', () async {
          otherCalls++;
        });
        final disposed = dispose();
        var stopped = false;
        final stopping = barrier.stop('owner').then((_) {
          stopped = true;
        });
        await pumpEventQueue();
        expect(firstCalls, 1);
        expect(otherCalls, 0);
        expect(stopped, isFalse);
        first.complete();
        await disposed;
        expect(stopped, isFalse);
        second.complete();
        await stopping;
        await barrier.stop('owner');
        expect(firstCalls, 1);
        expect(otherCalls, 0);
        await barrier.stop('other');
        expect(otherCalls, 1);
      },
    );

    test(
      'retains failed drains so subsequent erasure still fails closed',
      () async {
        final barrier = AccountStateWriteBarrier();
        final failure = StateError('local write failed');
        final dispose = barrier.register('owner', () async {
          throw failure;
        });
        await expectLater(dispose(), throwsA(same(failure)));
        await expectLater(barrier.stop('owner'), throwsA(same(failure)));
        await expectLater(barrier.stop('owner'), throwsA(same(failure)));
      },
    );
  });
}

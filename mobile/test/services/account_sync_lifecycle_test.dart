import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/account_sync_lifecycle.dart';

void main() {
  group('account sync lifecycle', () {
    test(
      'startup flushes independent protocols together and retains a trailing reconnect retry',
      () async {
        final connectivity = StreamController<bool>.broadcast(sync: true);
        final blocked = Completer<void>();
        var writes = 0;
        var reads = 0;
        final lifecycle = AccountSyncLifecycle(
          flushers: [
            () async {
              ++writes;
              if (writes == 1) {
                await blocked.future;
                throw StateError('offline');
              }
            },
            () async {
              ++reads;
            },
          ],
          connectivity: connectivity.stream,
        );
        expect(writes, 1);
        expect(
          reads,
          1,
          reason: 'a stalled settings relay must not block read retries',
        );
        connectivity.add(true);
        final foreground = lifecycle.flush();
        expect(writes, 1);
        blocked.complete();
        await foreground;
        expect(writes, 2);
        expect(reads, 2);
        await lifecycle.flush();
        expect(writes, 3);
        connectivity.add(false);
        connectivity.add(true);
        await pumpEventQueue();
        expect(writes, 4);
        lifecycle.close();
        connectivity.add(false);
        connectivity.add(true);
        await lifecycle.flush();
        expect(writes, 4);
        await connectivity.close();
      },
    );

    test('disposal suppresses queued retry and future triggers', () async {
      final connectivity = StreamController<bool>.broadcast();
      final blocked = Completer<void>();
      var calls = 0;
      final lifecycle = AccountSyncLifecycle(
        flushers: [
          () async {
            ++calls;
            await blocked.future;
          },
        ],
        connectivity: connectivity.stream,
      );
      final operation = lifecycle.flush();
      lifecycle.close();
      blocked.complete();
      await operation;
      await lifecycle.flush();
      expect(calls, 1);
      await connectivity.close();
    });
  });
}

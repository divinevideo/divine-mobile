// ABOUTME: Verifies cache cleanup waits for startup and yields to users.
import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/foreground_idle_warmup_provider.dart';

class _RetiredCache extends Fake implements RetiredEventCache {
  _RetiredCache(this.runBatch);
  final Future<bool> Function() runBatch;
  @override
  Future<bool> pruneBatch() => runBatch();
}

// Broadcast subscription cancellation can complete through a future from the
// outer zone. Let that completion settle before advancing another fake tick.
Future<void> _elapse(FakeAsync time, Duration duration) async {
  time.elapse(duration);
  await pumpEventQueue();
  time.flushMicrotasks();
}

void main() {
  group('start', () {
    test('stops for this session when a cleanup batch fails', () async {
      final time = FakeAsync();
      late ProviderContainer container;
      var attemptedBatches = 0;
      time.run((_) {
        container = ProviderContainer(
          overrides: [
            retiredEventCacheProvider.overrideWithValue(
              _RetiredCache(() async {
                attemptedBatches++;
                throw StateError('retired cache unavailable');
              }),
            ),
          ],
        );
        container.read(retiredEventCacheCleanupSchedulerProvider).start();
      });
      await _elapse(time, const Duration(seconds: 10));
      expect(attemptedBatches, 1);
      await _elapse(time, const Duration(minutes: 1));
      expect(attemptedBatches, 1);
      container.dispose();
      await _elapse(time, Duration.zero);
    });

    test(
      'waits for startup and pauses between batches when backgrounded',
      () async {
        final time = FakeAsync();
        late ProviderContainer container;
        var deletedBatches = 0;
        time.run((_) {
          container = ProviderContainer(
            overrides: [
              retiredEventCacheProvider.overrideWithValue(
                _RetiredCache(() async {
                  deletedBatches++;
                  container
                      .read(appForegroundProvider.notifier)
                      .setForeground(false);
                  return true;
                }),
              ),
            ],
          );
          container.read(retiredEventCacheCleanupSchedulerProvider).start();
        });
        await _elapse(time, const Duration(seconds: 9));
        expect(deletedBatches, 0);
        await _elapse(time, const Duration(seconds: 1));
        expect(deletedBatches, 1);
        await _elapse(time, const Duration(seconds: 10));
        expect(deletedBatches, 1);
        container.read(appForegroundProvider.notifier).setForeground(true);
        await _elapse(time, const Duration(seconds: 1));
        expect(deletedBatches, 2);
        container.dispose();
        await _elapse(time, Duration.zero);
      },
    );

    test(
      'yields to feed activity then stops scheduling when cleanup is done',
      () async {
        final time = FakeAsync();
        late ProviderContainer container;
        var deletedBatches = 0;
        time.run((_) {
          container = ProviderContainer(
            overrides: [
              retiredEventCacheProvider.overrideWithValue(
                _RetiredCache(() async {
                  deletedBatches++;
                  if (deletedBatches == 1) {
                    container
                        .read(foregroundFeedActivityGateProvider)
                        .markActive();
                    return true;
                  }
                  return false;
                }),
              ),
            ],
          );
          container.read(retiredEventCacheCleanupSchedulerProvider).start();
        });
        await _elapse(time, const Duration(seconds: 10));
        expect(deletedBatches, 1);
        await _elapse(time, const Duration(seconds: 9));
        expect(deletedBatches, 1);
        await _elapse(time, const Duration(seconds: 2));
        expect(deletedBatches, 2);
        await _elapse(time, const Duration(minutes: 1));
        expect(deletedBatches, 2);
        container.dispose();
        await _elapse(time, Duration.zero);
      },
    );

    test(
      'does not overlap batches or read disposed providers after an await',
      () async {
        final time = FakeAsync();
        late Completer<bool> batch;
        late ProviderContainer container;
        var deletedBatches = 0;
        time.run((_) {
          batch = Completer<bool>();
          container = ProviderContainer(
            overrides: [
              retiredEventCacheProvider.overrideWithValue(
                _RetiredCache(() {
                  deletedBatches++;
                  return batch.future;
                }),
              ),
            ],
          );
          container.read(retiredEventCacheCleanupSchedulerProvider).start();
        });
        await _elapse(time, const Duration(seconds: 15));
        expect(deletedBatches, 1);
        container.dispose();
        batch.complete(true);
        await _elapse(time, const Duration(minutes: 1));
        expect(deletedBatches, 1);
      },
    );
  });
}

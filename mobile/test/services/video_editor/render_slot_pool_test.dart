// ABOUTME: Tests for RenderSlotPool — the shared cap on concurrent native
// ABOUTME: preview renders and the priority seams take over speed bodies.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_editor/render_slot_pool.dart';

void main() {
  group(RenderSlotPool, () {
    group('acquire', () {
      test('grants slots up to the cap and queues the rest', () async {
        final pool = RenderSlotPool();
        final granted = <int>[];

        for (var i = 0; i < 3; i++) {
          unawaited(pool.acquire().then((_) => granted.add(i)));
        }
        await pumpEventQueue();

        expect(granted, [0, 1]);
        expect(pool.activeCount, 2);
      });

      test('a priority waiter goes ahead of earlier plain waiters', () async {
        final pool = RenderSlotPool(maxConcurrent: 1);
        final granted = <String>[];
        await pool.acquire();

        unawaited(pool.acquire().then((_) => granted.add('speed')));
        unawaited(
          pool.acquire(priority: true).then((_) => granted.add('seam')),
        );
        await pumpEventQueue();
        expect(granted, isEmpty);

        pool.release();
        await pumpEventQueue();
        expect(granted, ['seam']);

        pool.release();
        await pumpEventQueue();
        expect(granted, ['seam', 'speed']);
      });
    });

    group('release', () {
      test('hands the slot to the next waiter instead of freeing it', () async {
        final pool = RenderSlotPool(maxConcurrent: 1);
        await pool.acquire();
        var secondGranted = false;
        unawaited(pool.acquire().then((_) => secondGranted = true));

        pool.release();
        await pumpEventQueue();

        expect(secondGranted, isTrue);
        expect(pool.activeCount, 1);
      });

      test('frees the slot when nobody waits', () async {
        final pool = RenderSlotPool(maxConcurrent: 1);
        await pool.acquire();

        pool.release();

        expect(pool.activeCount, 0);
      });
    });
  });
}

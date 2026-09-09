// ABOUTME: Tests that a pooled value survives the remount the editor performs
// ABOUTME: while a layer is dragged, and is still reclaimed once nobody holds it

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/grace_period_registry.dart';

/// Stands in for a detached clip's player: something built once and torn down
/// once, which is all the registry contracts on.
class _Resource {
  _Resource(this.name);

  final String name;
  bool disposed = false;
}

void main() {
  late GracePeriodRegistry<_Resource> registry;
  late List<String> disposed;
  late int builds;

  const grace = Duration(seconds: 3);

  setUp(() {
    disposed = [];
    builds = 0;
    registry = GracePeriodRegistry<_Resource>(
      graceWindow: grace,
      dispose: (value) async {
        value.disposed = true;
        disposed.add(value.name);
      },
    );
  });

  tearDown(() => registry.resetForTesting());

  Future<_Resource?> build([String name = 'a']) async {
    builds++;
    return _Resource(name);
  }

  group(GracePeriodRegistry, () {
    group('acquire', () {
      test('builds one value per key', () async {
        final first = await registry.acquire('a', build);
        final second = await registry.acquire('a', build);

        expect(builds, 1);
        expect(second, same(first));
        expect(registry.entryCount, 1);
      });

      test('builds a separate value for a different key', () async {
        final first = await registry.acquire('a', build);
        final second = await registry.acquire('b', () => build('b'));

        expect(builds, 2);
        expect(second, isNot(same(first)));
        expect(registry.entryCount, 2);
      });

      test('shares one build between racing callers', () async {
        // Both arrive before either build resolves — the second must join the
        // first rather than start a second decoder on the same clip.
        final results = await Future.wait([
          registry.acquire('a', build),
          registry.acquire('a', build),
        ]);

        expect(builds, 1);
        expect(results.first, same(results.last));
      });
    });

    group('acquireIfReady', () {
      test('hands over a built value without an await', () async {
        final built = await registry.acquire('a', build);

        final resumed = registry.acquireIfReady('a');

        // The whole point: a remount renders in its first frame instead of
        // drawing nothing until a future completes.
        expect(resumed, isNotNull);
        expect(resumed, same(built));
        expect(builds, 1);
      });

      test('takes a reference, so the earlier holder can let go', () {
        fakeAsync((async) {
          unawaited(registry.acquire('a', build));
          async.flushMicrotasks();

          expect(registry.acquireIfReady('a'), isNotNull);
          registry.release('a');
          async.elapse(grace * 2);

          // Two holders, one released: the value stays.
          expect(disposed, isEmpty);
          expect(registry.entryCount, 1);
        });
      });

      test('reports not-ready while the build is still in flight', () {
        final gate = Completer<_Resource?>();
        unawaited(registry.acquire('a', () => gate.future));

        expect(registry.acquireIfReady('a'), isNull);

        gate.complete(_Resource('a'));
      });

      test('reports not-ready for a key nothing opened', () {
        expect(registry.acquireIfReady('nothing'), isNull);
      });
    });

    group('release', () {
      test('keeps the value through a remount inside the grace window', () {
        fakeAsync((async) {
          unawaited(registry.acquire('a', build));
          async.flushMicrotasks();

          // What a drag does: the new state mounts moments after the old one
          // let go. Rebuilding here is what blanked the layer and restarted
          // the clip.
          registry.release('a');
          async.elapse(const Duration(milliseconds: 20));
          final resumed = registry.acquireIfReady('a');
          async.elapse(grace * 2);

          expect(resumed, isNotNull);
          expect(builds, 1);
          expect(disposed, isEmpty);
          expect(registry.entryCount, 1);
        });
      });

      test('tears the value down once the grace window passes', () {
        fakeAsync((async) {
          unawaited(registry.acquire('a', build));
          async.flushMicrotasks();

          registry.release('a');
          expect(
            disposed,
            isEmpty,
            reason: 'held until the window passes',
          );

          async.elapse(grace * 2);
          expect(disposed, ['a']);
          expect(registry.entryCount, 0);
        });
      });

      test('keeps the value while a second holder remains', () {
        fakeAsync((async) {
          unawaited(registry.acquire('a', build));
          unawaited(registry.acquire('a', build));
          async.flushMicrotasks();

          registry.release('a');
          async.elapse(grace * 2);

          // Two layers can show the same clip; the last one out turns the
          // lights off, not the first.
          expect(disposed, isEmpty);
          expect(registry.entryCount, 1);
        });
      });

      test('ignores a key it never lent out', () {
        expect(() => registry.release('never-acquired'), returnsNormally);
      });
    });
  });
}

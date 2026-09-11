// ABOUTME: Tests for ConnectivityTransitionMonitor — the single owner that
// ABOUTME: turns connectivity reports into relay repairs and DM sweep triggers.

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/connectivity_transition_monitor.dart';

const List<ConnectivityResult> _wifi = [ConnectivityResult.wifi];
const List<ConnectivityResult> _mobile = [ConnectivityResult.mobile];
const List<ConnectivityResult> _offline = [ConnectivityResult.none];

/// Drives a monitor inside a fake clock. Construct it inside `fakeAsync` so
/// the monitor's timers run on that clock.
class _Harness {
  _Harness({
    Future<List<ConnectivityResult>> Function()? check,
    Future<void> Function()? repair,
  }) {
    monitor = ConnectivityTransitionMonitor(
      changes: changes.stream,
      checkConnectivity: check ?? () async => _wifi,
      repair: () {
        repairs++;
        return (repair ?? () async {})();
      },
      canRepair: () => canRepair,
    );
    monitor.transitions.listen(transitions.add);
    monitor.start();
  }

  final StreamController<List<ConnectivityResult>> changes =
      StreamController<List<ConnectivityResult>>();
  final List<ConnectivityTransition> transitions = [];
  late final ConnectivityTransitionMonitor monitor;
  int repairs = 0;
  bool canRepair = true;

  void report(List<ConnectivityResult> results) => changes.add(results);
}

void main() {
  group(ConnectivityTransitionMonitor, () {
    group('baseline', () {
      test('ignores the report a fresh subscription replays', () {
        // Repairing on it tore down healthy sockets ~2 s after every launch
        // and sign-in (#8990).
        fakeAsync((async) {
          final harness = _Harness();
          async.flushMicrotasks();

          harness.report(_wifi);
          async.elapse(const Duration(seconds: 5));

          expect(harness.repairs, isZero);
          expect(harness.transitions, isEmpty);
        });
      });

      test('uses the first report as the baseline when the seed fails', () {
        fakeAsync((async) {
          final harness = _Harness(
            check: () async => throw StateError('plugin unavailable'),
          );
          async.flushMicrotasks();

          harness.report(_wifi);
          async.elapse(const Duration(seconds: 5));
          expect(harness.repairs, isZero);

          harness.report(_mobile);
          async.elapse(const Duration(seconds: 2));
          expect(harness.repairs, equals(1));
        });
      });

      test('counts a first report that differs from the seed', () {
        // A new container gets no replay, so its first report is a change.
        fakeAsync((async) {
          final harness = _Harness(check: () async => _offline);
          async.flushMicrotasks();

          harness.report(_wifi);
          async.elapse(const Duration(seconds: 2));

          expect(harness.repairs, equals(1));
        });
      });

      test('keeps a report that beats the seed as the baseline', () {
        // A slow seed must not overwrite it, or the next duplicate report
        // would read as a change and reconnect every relay (#8990).
        fakeAsync((async) {
          final seed = Completer<List<ConnectivityResult>>();
          final harness = _Harness(check: () => seed.future);
          harness.report(_mobile);
          async.flushMicrotasks();
          seed.complete(_wifi);
          async.flushMicrotasks();

          harness.report(_mobile);
          async.elapse(const Duration(seconds: 5));

          expect(harness.repairs, isZero);
        });
      });
    });

    group('repair', () {
      test('repairs once, after the debounce, when the network returns', () {
        fakeAsync((async) {
          final harness = _Harness(check: () async => _offline);
          async.flushMicrotasks();

          harness.report(_wifi);
          async.elapse(const Duration(milliseconds: 1999));
          expect(harness.repairs, isZero);

          async.elapse(const Duration(milliseconds: 1));
          expect(harness.repairs, equals(1));
          expect(harness.transitions, [ConnectivityTransition.online]);
        });
      });

      test('repairs once when the transport changes while online', () {
        fakeAsync((async) {
          final harness = _Harness();
          async.flushMicrotasks();

          harness.report(_mobile);
          async.elapse(const Duration(seconds: 2));

          expect(harness.repairs, equals(1));
          expect(harness.transitions, [ConnectivityTransition.online]);
        });
      });

      test('ignores a duplicate report of the same transports', () {
        fakeAsync((async) {
          final harness = _Harness();
          async.flushMicrotasks();

          harness.report(_mobile);
          async.elapse(const Duration(seconds: 2));
          harness.report(_mobile);
          async.elapse(const Duration(seconds: 5));

          expect(harness.repairs, equals(1));
        });
      });

      test('collapses a burst of reports into one repair', () {
        fakeAsync((async) {
          final harness = _Harness();
          async.flushMicrotasks();

          harness.report(_mobile);
          async.elapse(const Duration(seconds: 1));
          harness.report(const [
            ConnectivityResult.wifi,
            ConnectivityResult.mobile,
          ]);
          async.elapse(const Duration(seconds: 1));
          harness.report(_mobile);
          async.elapse(const Duration(seconds: 5));

          expect(harness.repairs, equals(1));
        });
      });

      test('waits while the client cannot repair yet', () {
        fakeAsync((async) {
          final harness = _Harness()..canRepair = false;
          async.flushMicrotasks();

          harness.report(_mobile);
          async.elapse(const Duration(seconds: 10));
          expect(harness.repairs, isZero);

          harness.canRepair = true;
          async.elapse(const Duration(seconds: 2));
          expect(harness.repairs, equals(1));
        });
      });

      test('reports online even when the repair fails', () {
        fakeAsync((async) {
          final harness = _Harness(
            repair: () async => throw StateError('pool gone'),
          );
          async.flushMicrotasks();

          harness.report(_mobile);
          async.elapse(const Duration(seconds: 2));

          expect(harness.transitions, [ConnectivityTransition.online]);
        });
      });

      test('reports online once the repair reaches its cap', () {
        fakeAsync((async) {
          final hung = Completer<void>();
          final harness = _Harness(repair: () => hung.future);
          async.flushMicrotasks();

          harness.report(_mobile);
          async.elapse(const Duration(seconds: 2));
          expect(harness.transitions, isEmpty);

          async.elapse(const Duration(seconds: 15));
          expect(harness.transitions, [ConnectivityTransition.online]);
        });
      });

      test(
        're-runs once when the network changes mid-repair and reports '
        'online after the final repair',
        () {
          fakeAsync((async) {
            final gates = <Completer<void>>[];
            final harness = _Harness(
              repair: () {
                final gate = Completer<void>();
                gates.add(gate);
                return gate.future;
              },
            );
            async.flushMicrotasks();

            harness.report(_mobile);
            async.elapse(const Duration(seconds: 2));
            expect(gates, hasLength(1));

            harness
              ..report(_wifi)
              ..report(_mobile);
            async.flushMicrotasks();
            gates.single.complete();
            async.flushMicrotasks();
            expect(harness.transitions, isEmpty);

            async.elapse(const Duration(seconds: 2));
            expect(gates, hasLength(2));
            gates.last.complete();
            async.flushMicrotasks();
            expect(harness.transitions, [ConnectivityTransition.online]);
          });
        },
      );
    });

    group('offline', () {
      test('is reported at once', () {
        fakeAsync((async) {
          final harness = _Harness();
          async.flushMicrotasks();

          harness.report(_offline);
          async.flushMicrotasks();

          expect(harness.transitions, [ConnectivityTransition.offline]);
          expect(harness.repairs, isZero);
        });
      });

      test('cancels a pending repair', () {
        fakeAsync((async) {
          final harness = _Harness();
          async.flushMicrotasks();

          harness.report(_mobile);
          async.elapse(const Duration(seconds: 1));
          harness.report(_offline);
          async.elapse(const Duration(seconds: 5));

          expect(harness.repairs, isZero);
          expect(harness.transitions, [ConnectivityTransition.offline]);
        });
      });

      test('during a repair suppresses its online report', () {
        fakeAsync((async) {
          final gate = Completer<void>();
          final harness = _Harness(repair: () => gate.future);
          async.flushMicrotasks();

          harness.report(_mobile);
          async.elapse(const Duration(seconds: 2));
          harness.report(_offline);
          async.flushMicrotasks();
          gate.complete();
          async.elapse(const Duration(seconds: 5));

          expect(harness.transitions, [ConnectivityTransition.offline]);
        });
      });
    });

    group('dispose', () {
      test('cancels a pending repair', () {
        fakeAsync((async) {
          final harness = _Harness();
          async.flushMicrotasks();

          harness.report(_mobile);
          unawaited(harness.monitor.dispose());
          async.elapse(const Duration(seconds: 5));

          expect(harness.repairs, isZero);
        });
      });

      test('during a repair stops it reporting or repairing again', () {
        fakeAsync((async) {
          final gate = Completer<void>();
          final harness = _Harness(repair: () => gate.future);
          async.flushMicrotasks();

          harness.report(_mobile);
          async.elapse(const Duration(seconds: 2));
          harness.report(_wifi);
          async.flushMicrotasks();
          unawaited(harness.monitor.dispose());
          async.flushMicrotasks();
          gate.complete();
          async.elapse(const Duration(seconds: 5));

          expect(harness.repairs, equals(1));
          expect(harness.transitions, isEmpty);
        });
      });
    });
  });
}

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:upload_repository/upload_repository.dart';

class _MixinHarness with CircuitBreakerMixin {}

/// Build an OPEN breaker by recording [threshold] failures on distinct urls
/// (distinct so no single url hits the permanent-failure cap of threshold*2).
VideoCircuitBreaker _openedBreaker({
  int threshold = 3,
  Duration openTimeout = const Duration(seconds: 10),
  Duration halfOpenTimeout = const Duration(seconds: 5),
}) {
  final breaker = VideoCircuitBreaker(
    failureThreshold: threshold,
    openTimeout: openTimeout,
    halfOpenTimeout: halfOpenTimeout,
  );
  for (var i = 0; i < threshold; i++) {
    breaker.recordFailure('https://cdn/v$i.mp4', 'boom');
  }
  return breaker;
}

void main() {
  group(VideoCircuitBreaker, () {
    late VideoCircuitBreaker breaker;

    setUp(() {
      breaker = VideoCircuitBreaker(
        failureThreshold: 3,
        openTimeout: const Duration(seconds: 10),
        halfOpenTimeout: const Duration(seconds: 5),
      );
    });

    tearDown(() => breaker.dispose());

    group('initial state', () {
      test('starts closed and allows requests', () {
        expect(breaker.state, CircuitBreakerState.closed);
        expect(breaker.allowRequests, isTrue);
        expect(breaker.shouldAllowUrl('https://cdn/v.mp4'), isTrue);
        expect(breaker.failureRate, 0);
      });

      test('reports an initial stats snapshot', () {
        final stats = breaker.getStats();
        expect(stats['state'], 'closed');
        expect(stats['totalFailures'], 0);
        expect(stats['recentFailures'], 0);
        expect(stats['failedUrls'], 0);
        expect(stats['permanentlyFailedUrls'], 0);
        expect(stats['allowRequests'], isTrue);
        expect(stats['failureThreshold'], 3);
      });
    });

    group('recordFailure', () {
      test('tracks failure count and history', () {
        breaker.recordFailure('https://cdn/a.mp4', 'timeout');
        final stats = breaker.getStats();
        expect(stats['totalFailures'], 1);
        expect(stats['recentFailures'], 1);
        expect(stats['failedUrls'], 1);
      });

      test('opens the circuit after threshold recent failures', () {
        breaker.recordFailure('https://cdn/a.mp4', 'e');
        breaker.recordFailure('https://cdn/b.mp4', 'e');
        expect(breaker.state, CircuitBreakerState.closed);

        breaker.recordFailure('https://cdn/c.mp4', 'e');
        expect(breaker.state, CircuitBreakerState.open);
        expect(breaker.allowRequests, isFalse);
        expect(breaker.shouldAllowUrl('https://cdn/unrelated.mp4'), isFalse);
      });

      test('permanently blocks a url after threshold*2 failures', () {
        for (var i = 0; i < 6; i++) {
          breaker.recordFailure('https://cdn/bad.mp4', 'e');
        }
        expect(breaker.getStats()['permanentlyFailedUrls'], 1);
        expect(breaker.shouldAllowUrl('https://cdn/bad.mp4'), isFalse);
      });

      test('caps the failure history at maxFailureHistory', () {
        final bounded = VideoCircuitBreaker(maxFailureHistory: 5);
        for (var i = 0; i < 12; i++) {
          bounded.recordFailure('https://cdn/u$i.mp4', 'e');
        }
        expect(bounded.getStats()['totalFailures'], 5);
        bounded.dispose();
      });
    });

    group('shouldAllowUrl', () {
      test('allows an unknown url', () {
        expect(breaker.shouldAllowUrl('https://cdn/fresh.mp4'), isTrue);
      });

      test('keeps blocking a permanently failed url after reset', () {
        for (var i = 0; i < 6; i++) {
          breaker.recordFailure('https://cdn/bad.mp4', 'e');
        }
        breaker.reset();
        // reset clears state/counters but not the permanent set.
        expect(breaker.shouldAllowUrl('https://cdn/bad.mp4'), isFalse);
      });
    });

    group('recordSuccess', () {
      test('clears the failure counters for that url', () {
        breaker.recordFailure('https://cdn/u.mp4', 'e');
        breaker.recordFailure('https://cdn/u.mp4', 'e');
        expect(breaker.getStats()['failedUrls'], 1);

        breaker.recordSuccess('https://cdn/u.mp4');
        expect(breaker.getStats()['failedUrls'], 0);
      });
    });

    group('failureRate', () {
      test('is zero with no recent failures', () {
        expect(breaker.failureRate, 0);
      });

      test('scales with recent failures', () {
        breaker.recordFailure('https://cdn/a.mp4', 'e');
        expect(breaker.failureRate, 5); // 1 / 20 * 100
      });

      test('clamps at 100', () {
        for (var i = 0; i < 30; i++) {
          breaker.recordFailure('https://cdn/u$i.mp4', 'e');
        }
        expect(breaker.failureRate, 100);
      });
    });

    group('getDetailedStats', () {
      test('exposes per-url counts and most-failed urls', () {
        breaker.recordFailure('https://cdn/a.mp4', 'e');
        breaker.recordFailure('https://cdn/a.mp4', 'e');
        breaker.recordFailure('https://cdn/b.mp4', 'e');

        final detailed = breaker.getDetailedStats();
        expect(detailed['state'], isNotNull); // inherits base stats
        final counts = detailed['urlFailureCounts'] as Map;
        expect(counts['https://cdn/a.mp4'], 2);
        expect(counts['https://cdn/b.mp4'], 1);
        final mostFailed =
            detailed['mostFailedUrls'] as List<MapEntry<String, int>>;
        expect(mostFailed.first.key, 'https://cdn/a.mp4');
        expect(mostFailed.first.value, 2);
      });
    });

    group('reset', () {
      test('clears history, counters, and returns to closed', () {
        for (var i = 0; i < 4; i++) {
          breaker.recordFailure('https://cdn/u$i.mp4', 'e');
        }
        breaker.reset();

        final stats = breaker.getStats();
        expect(breaker.state, CircuitBreakerState.closed);
        expect(stats['totalFailures'], 0);
        expect(stats['failedUrls'], 0);
        expect(breaker.allowRequests, isTrue);
      });
    });

    group('clearPermanentFailures', () {
      test('re-allows a previously permanent url', () {
        for (var i = 0; i < 6; i++) {
          breaker.recordFailure('https://cdn/bad.mp4', 'e');
        }
        breaker.reset();
        expect(breaker.shouldAllowUrl('https://cdn/bad.mp4'), isFalse);

        breaker.clearPermanentFailures();
        expect(breaker.shouldAllowUrl('https://cdn/bad.mp4'), isTrue);
      });
    });

    group('state transitions', () {
      test('open -> halfOpen after the open timeout', () {
        fakeAsync((async) {
          final b = _openedBreaker();
          expect(b.state, CircuitBreakerState.open);

          async.elapse(const Duration(seconds: 10));
          expect(b.state, CircuitBreakerState.halfOpen);
          b.dispose();
        });
      });

      test('halfOpen -> open after the half-open timeout with no success', () {
        fakeAsync((async) {
          final b = _openedBreaker();
          async.elapse(const Duration(seconds: 10)); // -> halfOpen
          expect(b.state, CircuitBreakerState.halfOpen);

          async.elapse(const Duration(seconds: 5)); // no success -> open
          expect(b.state, CircuitBreakerState.open);
          b.dispose();
        });
      });

      test('halfOpen -> closed after the required successes', () {
        fakeAsync((async) {
          final b = _openedBreaker();
          async.elapse(const Duration(seconds: 10)); // -> halfOpen
          expect(b.state, CircuitBreakerState.halfOpen);

          b.recordSuccess('https://cdn/v0.mp4');
          b.recordSuccess('https://cdn/v1.mp4');
          expect(b.state, CircuitBreakerState.halfOpen); // not enough yet
          b.recordSuccess('https://cdn/v2.mp4'); // 3rd -> closed
          expect(b.state, CircuitBreakerState.closed);
          b.dispose();
        });
      });

      test('blocks a url within its backoff window while half-open', () {
        fakeAsync((async) {
          final b = VideoCircuitBreaker(
            failureThreshold: 3,
            openTimeout: const Duration(seconds: 10),
            // halfOpenTimeout defaults to 30s, so half-open won't time out
            // during this test (we only elapse the 10s open timeout).
          );
          // 3 failures on the same url: opens the circuit AND pushes that url's
          // count to the threshold (but below the permanent cap of 6).
          for (var i = 0; i < 3; i++) {
            b.recordFailure('https://cdn/bad.mp4', 'e');
          }
          async.elapse(const Duration(seconds: 10)); // -> halfOpen
          expect(b.state, CircuitBreakerState.halfOpen);

          expect(b.shouldAllowUrl('https://cdn/bad.mp4'), isFalse); // backoff
          expect(b.shouldAllowUrl('https://cdn/clean.mp4'), isTrue);
          b.dispose();
        });
      });

      test('dispose cancels the recovery timer', () {
        fakeAsync((async) {
          final b = _openedBreaker();
          expect(b.state, CircuitBreakerState.open);

          b.dispose();
          async.elapse(const Duration(minutes: 5));
          expect(b.state, CircuitBreakerState.open); // never recovered
        });
      });

      test('reset cancels the recovery timer', () {
        fakeAsync((async) {
          final b = _openedBreaker();
          b.reset();
          expect(b.state, CircuitBreakerState.closed);

          async.elapse(const Duration(minutes: 5));
          expect(b.state, CircuitBreakerState.closed); // timer did not refire
          b.dispose();
        });
      });
    });
  });

  group(CircuitBreakerMixin, () {
    test('allows urls and returns null stats before initialization', () {
      final harness = _MixinHarness();
      expect(harness.shouldAllowVideoUrl('https://cdn/v.mp4'), isTrue);
      expect(harness.getCircuitBreakerStats(), isNull);
    });

    test('delegates to the breaker once initialized', () {
      final harness = _MixinHarness()
        ..initializeCircuitBreaker(failureThreshold: 2);

      harness.recordVideoFailure('https://cdn/a.mp4', 'e');
      harness.recordVideoFailure('https://cdn/b.mp4', 'e'); // 2 -> open

      expect(harness.shouldAllowVideoUrl('https://cdn/any.mp4'), isFalse);
      expect(harness.getCircuitBreakerStats(), isNotNull);
      harness.disposeCircuitBreaker();
    });

    test('recordVideoSuccess clears the failure counters for a url', () {
      final harness = _MixinHarness()..initializeCircuitBreaker();
      harness.recordVideoFailure('https://cdn/a.mp4', 'e');
      expect(harness.getCircuitBreakerStats()!['failedUrls'], 1);

      harness.recordVideoSuccess('https://cdn/a.mp4');
      expect(harness.getCircuitBreakerStats()!['failedUrls'], 0);
      harness.disposeCircuitBreaker();
    });

    test('disposeCircuitBreaker tears the breaker down', () {
      final harness = _MixinHarness()..initializeCircuitBreaker();
      harness.disposeCircuitBreaker();

      expect(harness.getCircuitBreakerStats(), isNull);
      expect(harness.shouldAllowVideoUrl('https://cdn/v.mp4'), isTrue);
    });
  });
}

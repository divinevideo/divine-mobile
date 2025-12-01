// ABOUTME: Unit tests for VideoState model covering lifecycle and state transitions
// ABOUTME: Comprehensive test suite for TDD-driven video state management

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/models/video_state.dart';

void main() {
  group('VideoState', () {
    late VideoEvent testEvent;

    setUp(() {
      testEvent = VideoEvent(
        id: 'test-id',
        pubkey: 'test-pubkey',
        createdAt: 1234567890,
        content: 'Test video content',
        timestamp: DateTime.now(),
        videoUrl: 'https://example.com/video.mp4',
      );
    });

    group('Creation and Initial State', () {
      test('creates with default notLoaded state', () {
        final state = VideoState(event: testEvent);

        expect(state.event, equals(testEvent));
        expect(state.loadingState, equals(VideoLoadingState.notLoaded));
        expect(state.errorMessage, isNull);
        expect(state.retryCount, equals(0));
        expect(state.lastUpdated, isA<DateTime>());
        expect(state.isLoading, isFalse);
        expect(state.isReady, isFalse);
        expect(state.hasFailed, isFalse);
        expect(state.canRetry, isFalse);
        expect(state.isDisposed, isFalse);
      });

      test('creates with custom initial state', () {
        final state = VideoState(
          event: testEvent,
          loadingState: VideoLoadingState.loading,
          errorMessage: 'Custom error',
          retryCount: 2,
        );

        expect(state.loadingState, equals(VideoLoadingState.loading));
        expect(state.errorMessage, equals('Custom error'));
        expect(state.retryCount, equals(2));
      });

      test('validates retry count cannot be negative', () {
        expect(
          () => VideoState(event: testEvent, retryCount: -1),
          throwsA(isA<AssertionError>()),
        );
      });
    });

    group('State Transitions - toLoading()', () {
      test('transitions from notLoaded to loading', () {
        final state = VideoState(event: testEvent);
        final loadingState = state.toLoading();

        expect(loadingState.loadingState, equals(VideoLoadingState.loading));
        expect(loadingState.errorMessage, isNull);
        expect(loadingState.retryCount, equals(0));
        expect(loadingState.isLoading, isTrue);
        expect(loadingState.lastUpdated.isAfter(state.lastUpdated), isTrue);
      });

      test('transitions from failed to loading', () {
        final failedState = VideoState(event: testEvent).toFailed('Test error');
        final loadingState = failedState.toLoading();

        expect(loadingState.loadingState, equals(VideoLoadingState.loading));
        expect(loadingState.errorMessage, isNull);
        expect(loadingState.retryCount, equals(1)); // Retry count preserved
      });

      test('transitions from ready to loading', () {
        final readyState = VideoState(event: testEvent).toLoading().toReady();
        final reloadingState = readyState.toLoading();

        expect(reloadingState.loadingState, equals(VideoLoadingState.loading));
        expect(reloadingState.errorMessage, isNull);
      });

      test('throws error when transitioning from disposed', () {
        final disposedState = VideoState(event: testEvent).toDisposed();

        expect(disposedState.toLoading, throwsA(isA<StateError>()));
      });

      test('throws error when transitioning from permanently failed', () {
        final permFailedState = VideoState(
          event: testEvent,
        ).toPermanentlyFailed('Permanent error');

        expect(permFailedState.toLoading, throwsA(isA<StateError>()));
      });
    });

    group('State Transitions - toReady()', () {
      test('transitions from loading to ready', () {
        final loadingState = VideoState(event: testEvent).toLoading();
        final readyState = loadingState.toReady();

        expect(readyState.loadingState, equals(VideoLoadingState.ready));
        expect(readyState.errorMessage, isNull);
        expect(readyState.retryCount, equals(0));
        expect(readyState.isReady, isTrue);
        expect(
          readyState.lastUpdated.isAfter(loadingState.lastUpdated),
          isTrue,
        );
      });

      test('throws error when transitioning from non-loading states', () {
        final notLoadedState = VideoState(event: testEvent);
        final failedState = VideoState(event: testEvent).toFailed('Error');
        final readyState = VideoState(event: testEvent).toLoading().toReady();

        expect(notLoadedState.toReady, throwsA(isA<StateError>()));
        expect(failedState.toReady, throwsA(isA<StateError>()));
        expect(readyState.toReady, throwsA(isA<StateError>()));
      });
    });

    group('State Transitions - toFailed()', () {
      test('transitions to failed and increments retry count', () {
        final state = VideoState(event: testEvent);
        final failedState = state.toFailed('Network error');

        expect(failedState.loadingState, equals(VideoLoadingState.failed));
        expect(failedState.errorMessage, equals('Network error'));
        expect(failedState.retryCount, equals(1));
        expect(failedState.hasFailed, isTrue);
        expect(failedState.canRetry, isTrue);
      });

      test('transitions to permanently failed after max retries', () {
        var state = VideoState(event: testEvent);

        // Fail 3 times (max retries)
        state = state.toFailed('Error 1');
        state = state.toFailed('Error 2');
        state = state.toFailed('Error 3');

        expect(state.loadingState, equals(VideoLoadingState.failed));
        expect(state.retryCount, equals(3));
        expect(state.canRetry, isFalse);

        // Fourth failure should go to permanently failed
        final permFailedState = state.toFailed('Error 4');
        expect(
          permFailedState.loadingState,
          equals(VideoLoadingState.permanentlyFailed),
        );
        expect(permFailedState.errorMessage, equals('Error 4'));
        expect(permFailedState.retryCount, equals(3));
        expect(permFailedState.canRetry, isFalse);
      });

      test('throws error when transitioning from disposed', () {
        final disposedState = VideoState(event: testEvent).toDisposed();

        expect(
          () => disposedState.toFailed('Error'),
          throwsA(isA<StateError>()),
        );
      });

      test('throws error when transitioning from permanently failed', () {
        final permFailedState = VideoState(
          event: testEvent,
        ).toPermanentlyFailed('Permanent error');

        expect(
          () => permFailedState.toFailed('Another error'),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('State Transitions - toPermanentlyFailed()', () {
      test('transitions directly to permanently failed', () {
        final state = VideoState(event: testEvent);
        final permFailedState = state.toPermanentlyFailed('Critical error');

        expect(
          permFailedState.loadingState,
          equals(VideoLoadingState.permanentlyFailed),
        );
        expect(permFailedState.errorMessage, equals('Critical error'));
        expect(permFailedState.retryCount, equals(0));
        expect(permFailedState.hasFailed, isTrue);
        expect(permFailedState.canRetry, isFalse);
      });

      test('throws error when transitioning from disposed', () {
        final disposedState = VideoState(event: testEvent).toDisposed();

        expect(
          () => disposedState.toPermanentlyFailed('Error'),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('State Transitions - toDisposed()', () {
      test('transitions from any state to disposed', () {
        final states = [
          VideoState(event: testEvent), // notLoaded
          VideoState(event: testEvent).toLoading(), // loading
          VideoState(event: testEvent).toLoading().toReady(), // ready
          VideoState(event: testEvent).toFailed('Error'), // failed
          VideoState(
            event: testEvent,
          ).toPermanentlyFailed('Error'), // permanentlyFailed
        ];

        for (final state in states) {
          final disposedState = state.toDisposed();
          expect(
            disposedState.loadingState,
            equals(VideoLoadingState.disposed),
          );
          expect(disposedState.isDisposed, isTrue);
          expect(disposedState.lastUpdated.isAfter(state.lastUpdated), isTrue);
        }
      });

      test('throws error when already disposed', () {
        final disposedState = VideoState(event: testEvent).toDisposed();

        expect(disposedState.toDisposed, throwsA(isA<StateError>()));
      });
    });

    group('State Validation', () {
      test('convenience getters work correctly', () {
        final notLoadedState = VideoState(event: testEvent);
        final loadingState = notLoadedState.toLoading();
        final readyState = loadingState.toReady();
        final failedState = VideoState(event: testEvent).toFailed('Error');
        final permFailedState = VideoState(
          event: testEvent,
        ).toPermanentlyFailed('Error');
        final disposedState = VideoState(event: testEvent).toDisposed();

        expect(notLoadedState.isLoading, isFalse);
        expect(loadingState.isLoading, isTrue);
        expect(readyState.isReady, isTrue);
        expect(failedState.hasFailed, isTrue);
        expect(failedState.canRetry, isTrue);
        expect(permFailedState.hasFailed, isTrue);
        expect(permFailedState.canRetry, isFalse);
        expect(disposedState.isDisposed, isTrue);
      });

      test('canRetry logic respects max retry count', () {
        var state = VideoState(event: testEvent);

        // Should be able to retry for first 3 failures (but not after max)
        for (var i = 1; i < VideoState.maxRetryCount; i++) {
          state = state.toFailed('Error $i');
          expect(state.canRetry, isTrue);
          expect(state.retryCount, equals(i));
        }

        // At max retries, should still be able to retry
        state = state.toFailed('Error ${VideoState.maxRetryCount}');
        expect(state.canRetry, isFalse); // At max retries, cannot retry anymore
        expect(state.retryCount, equals(VideoState.maxRetryCount));

        // After max retries, should transition to permanently failed
        final finalState = state.toFailed('Final error');
        expect(finalState.canRetry, isFalse);
        expect(
          finalState.loadingState,
          equals(VideoLoadingState.permanentlyFailed),
        );
      });
    });

    group('Equality and Hashing', () {
      test('equality works correctly', () {
        final state1 = VideoState(event: testEvent);
        final state2 = VideoState(event: testEvent);
        final state3 = VideoState(
          event: testEvent,
          loadingState: VideoLoadingState.loading,
        );

        expect(state1, equals(state2));
        expect(state1, isNot(equals(state3)));
      });

      test('hashCode works correctly', () {
        final state1 = VideoState(event: testEvent);
        final state2 = VideoState(event: testEvent);

        expect(state1.hashCode, equals(state2.hashCode));
      });
    });

    group('String Representation', () {
      test('toString includes key information', () {
        final state = VideoState(
          event: testEvent,
          loadingState: VideoLoadingState.loading,
          errorMessage: 'Test error',
          retryCount: 2,
        );

        final str = state.toString();
        expect(str, contains('test-id'));
        expect(str, contains('loading'));
        expect(str, contains('Test error'));
        expect(str, contains('retries: 2'));
      });
    });

    group('Memory Management Tests', () {
      test('state objects are immutable', () {
        final originalState = VideoState(event: testEvent);
        final newState = originalState.toLoading();

        // Original state should be unchanged
        expect(originalState.loadingState, equals(VideoLoadingState.notLoaded));
        expect(newState.loadingState, equals(VideoLoadingState.loading));
        expect(originalState, isNot(same(newState)));
      });

      test('disposed state cannot transition to any other state', () {
        final disposedState = VideoState(event: testEvent).toDisposed();

        expect(disposedState.toLoading, throwsA(isA<StateError>()));
        expect(disposedState.toReady, throwsA(isA<StateError>()));
        expect(
          () => disposedState.toFailed('Error'),
          throwsA(isA<StateError>()),
        );
        expect(
          () => disposedState.toPermanentlyFailed('Error'),
          throwsA(isA<StateError>()),
        );
        expect(disposedState.toDisposed, throwsA(isA<StateError>()));
      });

      test('permanently failed state cannot transition to other states', () {
        final permFailedState = VideoState(
          event: testEvent,
        ).toPermanentlyFailed('Permanent error');

        expect(permFailedState.toLoading, throwsA(isA<StateError>()));
        expect(permFailedState.toReady, throwsA(isA<StateError>()));
        expect(
          () => permFailedState.toFailed('Error'),
          throwsA(isA<StateError>()),
        );

        // Can still dispose permanently failed state
        expect(permFailedState.toDisposed, returnsNormally);
      });
    });

    group('Error Handling and Recovery', () {
      test('error messages are preserved and updated correctly', () {
        var state = VideoState(event: testEvent);

        // First failure
        state = state.toFailed('Network timeout');
        expect(state.errorMessage, equals('Network timeout'));

        // Retry and fail again
        state = state.toLoading().toFailed('DNS resolution failed');
        expect(state.errorMessage, equals('DNS resolution failed'));
        expect(state.retryCount, equals(2));
      });

      test('error state transitions maintain retry count', () {
        var state = VideoState(event: testEvent);

        // Fail twice
        state = state.toFailed('Error 1');
        state = state.toFailed('Error 2');
        expect(state.retryCount, equals(2));

        // Transition to loading should preserve retry count
        final loadingState = state.toLoading();
        expect(loadingState.retryCount, equals(2));

        // Successful load should preserve retry count
        final readyState = loadingState.toReady();
        expect(readyState.retryCount, equals(2));
      });

      test('full lifecycle: notLoaded -> loading -> ready -> disposed', () {
        var state = VideoState(event: testEvent);
        expect(state.loadingState, equals(VideoLoadingState.notLoaded));

        state = state.toLoading();
        expect(state.loadingState, equals(VideoLoadingState.loading));

        state = state.toReady();
        expect(state.loadingState, equals(VideoLoadingState.ready));

        state = state.toDisposed();
        expect(state.loadingState, equals(VideoLoadingState.disposed));
      });

      test(
        'full lifecycle with failure: notLoaded -> loading -> failed -> loading -> ready',
        () {
          var state = VideoState(event: testEvent);

          // First attempt fails
          state = state.toLoading().toFailed('Network error');
          expect(state.loadingState, equals(VideoLoadingState.failed));
          expect(state.retryCount, equals(1));

          // Retry succeeds
          state = state.toLoading().toReady();
          expect(state.loadingState, equals(VideoLoadingState.ready));
          expect(state.retryCount, equals(1)); // Count preserved
        },
      );
    });
  });
}

// ABOUTME: Tests for FeedPerformanceTracker stale session handling.
// ABOUTME: Verifies sessions older than 60s are discarded and resetAllSessions
// ABOUTME: clears all active sessions on app resume.

import 'package:analytics/analytics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(FeedPerformanceTracker, () {
    late FeedPerformanceTracker tracker;

    setUp(() {
      tracker = FeedPerformanceTracker(sink: const NoOpAnalyticsEventSink());
    });

    group('resetAllSessions', () {
      test('clears all active sessions', () {
        tracker
          ..startFeedLoad('home')
          ..startFeedLoad('explore')
          ..startFeedLoad('profile');

        expect(tracker.activeSessionCount, 3);

        tracker.resetAllSessions();

        expect(tracker.activeSessionCount, 0);
      });

      test('does nothing when no sessions are active', () {
        expect(tracker.activeSessionCount, 0);

        // Should not throw
        tracker.resetAllSessions();

        expect(tracker.activeSessionCount, 0);
      });
    });

    group('stale session detection', () {
      test('discards a session older than the maximum age', () {
        var now = DateTime(2026, 9, 10, 12);
        tracker = FeedPerformanceTracker(
          sink: const NoOpAnalyticsEventSink(),
          now: () => now,
        );
        final handle = tracker.startFeedLoad('home');
        now = now.add(const Duration(seconds: 61));

        tracker.markFirstVideosReceived(handle, 5);

        expect(tracker.activeSessionCount, 0);
      });

      test('markFirstVideosReceived processes fresh session normally', () {
        final handle = tracker.startFeedLoad('home');
        expect(tracker.activeSessionCount, 1);

        tracker.markFirstVideosReceived(handle, 5);

        // Session should still be active (not yet displayed)
        expect(tracker.activeSessionCount, 1);
      });

      test('markFeedDisplayed removes session on completion', () {
        final handle = tracker.startFeedLoad('home');
        expect(tracker.activeSessionCount, 1);

        tracker.markFeedDisplayed(handle, 5);

        expect(tracker.activeSessionCount, 0);
      });

      test('milestones are no-ops after reset', () {
        final handle = tracker.startFeedLoad('home');
        tracker.resetAllSessions();
        tracker
          ..markFirstVideosReceived(handle, 5)
          ..markFeedDisplayed(handle, 5);
        expect(tracker.activeSessionCount, 0);
      });
    });

    group('session lifecycle', () {
      test('sessions do not leak between instances', () {
        final handle = tracker.startFeedLoad('home');

        final other = FeedPerformanceTracker(
          sink: const NoOpAnalyticsEventSink(),
        );
        final otherHandle = other.startFeedLoad('home');

        // Guards the reason the app resolves one shared instance through
        // `feedPerformanceTrackerProvider`: a second instance cannot complete
        // a session the first one started.
        expect(other.activeSessionCount, 1);
        other.markFeedDisplayed(handle, 3);
        expect(tracker.activeSessionCount, 1);
        expect(other.activeSessionCount, 1);
        other.abandonFeedLoad(otherHandle);
      });

      test('tracks multiple independent sessions', () {
        final home = tracker.startFeedLoad('home');
        final explore = tracker.startFeedLoad('explore');

        expect(tracker.activeSessionCount, 2);

        tracker.markFeedDisplayed(home, 5);
        expect(tracker.activeSessionCount, 1);

        tracker.markFeedDisplayed(explore, 10);
        expect(tracker.activeSessionCount, 0);
      });
    });

    group('video swipe tracking', () {
      test('startVideoSwipeTracking creates a session', () {
        const videoId =
            'abc123def456abc123def456abc123def456abc123def456abc123def456abcd';
        tracker.startVideoSwipeTracking(videoId);

        expect(tracker.activeSessionCount, 1);
      });

      test('markVideoSwipeComplete removes the session', () {
        const videoId =
            'abc123def456abc123def456abc123def456abc123def456abc123def456abcd';
        tracker
          ..startVideoSwipeTracking(videoId)
          ..markVideoSwipeComplete(videoId);

        expect(tracker.activeSessionCount, 0);
      });
    });
  });
}

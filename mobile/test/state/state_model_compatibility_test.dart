// ABOUTME: Pins the Freezed-era copyWith and collection contracts of app state.
// ABOUTME: Prevents handwritten Equatable models from weakening immutability.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/state/curation_state.dart';
import 'package:openvine/state/seen_videos_state.dart';
import 'package:openvine/state/user_profile_state.dart';
import 'package:openvine/state/video_feed_state.dart';

void main() {
  group('nullable copyWith arguments', () {
    test('preserve existing values when omitted', () {
      final timestamp = DateTime(2026, 9, 8);
      final state = VideoFeedState(
        videos: const [],
        hasMoreContent: false,
        error: 'stale error',
        lastUpdated: timestamp,
        totalVideoCount: 4,
      );

      final copied = state.copyWith(isRefreshing: true);

      expect(copied.error, 'stale error');
      expect(copied.lastUpdated, timestamp);
      expect(copied.totalVideoCount, 4);
    });

    test('clear existing values when explicitly null', () {
      final state = VideoFeedState(
        videos: const [],
        hasMoreContent: false,
        error: 'stale error',
        lastUpdated: DateTime(2026, 9, 8),
        totalVideoCount: 4,
      );

      final copied = state.copyWith(
        error: null,
        lastUpdated: null,
        totalVideoCount: null,
      );

      expect(copied.error, isNull);
      expect(copied.lastUpdated, isNull);
      expect(copied.totalVideoCount, isNull);
    });

    test('reject values of the wrong nullable-field type', () {
      const state = VideoFeedState(
        videos: [],
        hasMoreContent: false,
        error: 'stale error',
      );

      expect(() => state.copyWith(error: 42), throwsA(isA<TypeError>()));
    });
  });

  group('state collections', () {
    test('remain deeply comparable across distinct collection instances', () {
      expect(
        const SeenVideosState(seenVideoIds: {'one'}),
        const SeenVideosState(seenVideoIds: {'one'}),
      );
    });

    test('curation lists remain unmodifiable', () {
      const state = CurationState(
        editorsPicks: [],
        isLoading: false,
      );

      expect(state.editorsPicks.clear, throwsUnsupportedError);
      expect(state.trending.clear, throwsUnsupportedError);
      expect(state.curationSets.clear, throwsUnsupportedError);
    });

    test('seen-video sets remain unmodifiable', () {
      const state = SeenVideosState(seenVideoIds: {'one'});

      expect(state.seenVideoIds.clear, throwsUnsupportedError);
    });

    test('profile cache collections remain unmodifiable', () {
      final state = UserProfileState(
        pendingRequests: const {'one'},
        knownMissingProfiles: const {'two'},
        missingProfileRetryAfter: {'two': DateTime(2026, 9, 8)},
        pendingBatchPubkeys: const {'three'},
      );

      expect(state.pendingRequests.clear, throwsUnsupportedError);
      expect(state.knownMissingProfiles.clear, throwsUnsupportedError);
      expect(state.missingProfileRetryAfter.clear, throwsUnsupportedError);
      expect(state.pendingBatchPubkeys.clear, throwsUnsupportedError);
    });

    test('video-feed collections remain unmodifiable', () {
      const state = VideoFeedState(
        videos: [],
        hasMoreContent: false,
        videoListSources: {
          'video': {'list'},
        },
        listOnlyVideoIds: {'video'},
      );

      expect(state.videos.clear, throwsUnsupportedError);
      expect(state.videoListSources.clear, throwsUnsupportedError);
      expect(state.listOnlyVideoIds.clear, throwsUnsupportedError);
    });
  });
}

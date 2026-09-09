// ABOUTME: Pins the Freezed-era copyWith and collection contracts of app state.
// ABOUTME: Prevents handwritten Equatable models from weakening immutability.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
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
    // Every collection here is built through a mutable local rather than a
    // `const` literal on purpose: a const collection already throws on
    // `clear()`, so a const fixture would keep these tests green even if the
    // getters stopped wrapping at all.
    test('remain deeply comparable across distinct collection instances', () {
      expect(
        SeenVideosState(seenVideoIds: mutableSet(['one'])),
        SeenVideosState(seenVideoIds: mutableSet(['one'])),
      );
    });

    test('curation lists remain unmodifiable', () {
      final state = CurationState(
        editorsPicks: mutableList<VideoEvent>([]),
        isLoading: false,
        trending: mutableList<VideoEvent>([]),
        curationSets: mutableList<CurationSet>([]),
      );

      expect(state.editorsPicks.clear, throwsUnsupportedError);
      expect(state.trending.clear, throwsUnsupportedError);
      expect(state.curationSets.clear, throwsUnsupportedError);
    });

    test('seen-video sets remain unmodifiable', () {
      final state = SeenVideosState(seenVideoIds: mutableSet(['one']));

      expect(state.seenVideoIds.clear, throwsUnsupportedError);
    });

    test('profile cache collections remain unmodifiable', () {
      final state = UserProfileState(
        pendingRequests: mutableSet(['one']),
        knownMissingProfiles: mutableSet(['two']),
        missingProfileRetryAfter: mutableMap({'two': DateTime(2026, 9, 8)}),
        pendingBatchPubkeys: mutableSet(['three']),
      );

      expect(state.pendingRequests.clear, throwsUnsupportedError);
      expect(state.knownMissingProfiles.clear, throwsUnsupportedError);
      expect(state.missingProfileRetryAfter.clear, throwsUnsupportedError);
      expect(state.pendingBatchPubkeys.clear, throwsUnsupportedError);
    });

    test('video-feed collections remain unmodifiable', () {
      final state = VideoFeedState(
        videos: mutableList<VideoEvent>([]),
        hasMoreContent: false,
        videoListSources: mutableMap({
          'video': mutableSet(['list']),
        }),
        listOnlyVideoIds: mutableSet(['video']),
      );

      expect(state.videos.clear, throwsUnsupportedError);
      expect(state.videoListSources.clear, throwsUnsupportedError);
      expect(state.listOnlyVideoIds.clear, throwsUnsupportedError);
    });
  });

  group('collection getter equality', () {
    // Freezed handed out views that compare equal when they wrap the same
    // source, which is what lets `fooProvider.select((s) => s.items)` skip a
    // rebuild. A plain `dart:collection` view has identity `==`, so a getter
    // allocating one per read never compares equal to itself and every
    // selector over it fires on every unrelated state change.
    test('holds across two reads of the same field', () {
      final state = VideoFeedState(
        videos: mutableList<VideoEvent>([]),
        hasMoreContent: false,
        videoListSources: mutableMap({
          'video': mutableSet(['list']),
        }),
        listOnlyVideoIds: mutableSet(['video']),
      );

      expect(state.videos == state.videos, isTrue);
      expect(state.videoListSources == state.videoListSources, isTrue);
      expect(state.listOnlyVideoIds == state.listOnlyVideoIds, isTrue);
    });

    test('survives a copyWith that does not touch the collection', () {
      final state = CurationState(
        editorsPicks: mutableList<VideoEvent>([]),
        isLoading: false,
        trending: mutableList<VideoEvent>([]),
      );

      final copied = state.copyWith(isLoading: true);

      expect(copied.editorsPicks == state.editorsPicks, isTrue);
      expect(copied.trending == state.trending, isTrue);
    });

    test('stays flat instead of nesting one view per copyWith', () {
      var state = SeenVideosState(seenVideoIds: mutableSet(['one']));
      final first = state.seenVideoIds;

      for (var i = 0; i < 5; i++) {
        state = state.copyWith(isInitialized: true);
      }

      expect(state.seenVideoIds == first, isTrue);
    });

    test('breaks when the collection is replaced', () {
      final state = SeenVideosState(seenVideoIds: mutableSet(['one']));

      final copied = state.copyWith(seenVideoIds: mutableSet(['one', 'two']));

      expect(copied.seenVideoIds == state.seenVideoIds, isFalse);
    });
  });
}

/// A growable list the analyzer cannot fold into a `const` literal.
List<T> mutableList<T>(Iterable<T> items) => List<T>.of(items);

/// A mutable set the analyzer cannot fold into a `const` literal.
Set<T> mutableSet<T>(Iterable<T> items) => Set<T>.of(items);

/// A mutable map the analyzer cannot fold into a `const` literal.
Map<K, V> mutableMap<K, V>(Map<K, V> items) => Map<K, V>.of(items);

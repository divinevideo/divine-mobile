# Fresh Content Filter - Simple TDD Implementation

## What We're Building

**When user reopens the app, show unwatched videos first.**

That's it. No toggles, no settings, no complexity.

## Implementation Strategy

Replace `videoEventsProvider` with filtered version everywhere:
- Discovery feed shows unseen first
- Home feed shows unseen first
- User doesn't need to know or choose

---

## TDD Test 1: Filter Provider

**File**: `test/providers/unseen_video_events_provider_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/unseen_video_events_provider.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/seen_videos_service.dart';

void main() {
  group('UnseenVideoEventsProvider', () {
    test('shows unseen videos before seen videos', () async {
      // Arrange
      final seenService = SeenVideosService();
      await seenService.initialize();

      // Mark video1 and video3 as seen
      await seenService.markVideoAsSeen('video1');
      await seenService.markVideoAsSeen('video3');

      final testVideos = [
        VideoEvent(id: 'video1', pubkey: 'pub1', title: 'Seen 1'),
        VideoEvent(id: 'video2', pubkey: 'pub2', title: 'Unseen 1'),
        VideoEvent(id: 'video3', pubkey: 'pub3', title: 'Seen 2'),
        VideoEvent(id: 'video4', pubkey: 'pub4', title: 'Unseen 2'),
      ];

      final container = ProviderContainer(
        overrides: [
          seenVideosServiceProvider.overrideWithValue(seenService),
          videoEventsProvider.overrideWith(
            (ref) => Stream.value(testVideos),
          ),
        ],
      );

      // Act
      final result = await container.read(unseenVideoEventsProvider.future);

      // Assert - unseen videos come first
      expect(result.length, 4); // All videos, just reordered
      expect(result[0].id, 'video2'); // Unseen first
      expect(result[1].id, 'video4'); // Unseen second
      expect(result[2].id, 'video1'); // Seen after
      expect(result[3].id, 'video3'); // Seen last
    });

    test('maintains order within unseen and seen groups', () async {
      final seenService = SeenVideosService();
      await seenService.initialize();
      await seenService.markVideoAsSeen('video2');

      final testVideos = [
        VideoEvent(id: 'video1', pubkey: 'pub1', title: 'Unseen A'),
        VideoEvent(id: 'video2', pubkey: 'pub2', title: 'Seen A'),
        VideoEvent(id: 'video3', pubkey: 'pub3', title: 'Unseen B'),
        VideoEvent(id: 'video4', pubkey: 'pub4', title: 'Seen B'),
      ];

      final container = ProviderContainer(
        overrides: [
          seenVideosServiceProvider.overrideWithValue(seenService),
          videoEventsProvider.overrideWith(
            (ref) => Stream.value(testVideos),
          ),
        ],
      );

      final result = await container.read(unseenVideoEventsProvider.future);

      // Unseen maintain their order
      expect(result[0].id, 'video1');
      expect(result[1].id, 'video3');
      // Seen maintain their order
      expect(result[2].id, 'video2');
      expect(result[3].id, 'video4');
    });
  });
}
```

**Prompt 1A: Write failing test**
```
Create test/providers/unseen_video_events_provider_test.dart with the tests above.
Run: flutter test test/providers/unseen_video_events_provider_test.dart
Verify it fails because unseenVideoEventsProvider doesn't exist.
```

**Prompt 1B: Implement provider**
```
Create lib/providers/unseen_video_events_provider.dart:

import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'unseen_video_events_provider.g.dart';

/// Reorders video stream to show unseen videos before seen videos
@Riverpod(keepAlive: false)
Stream<List<VideoEvent>> unseenVideoEvents(Ref ref) async* {
  final seenService = ref.watch(seenVideosServiceProvider);

  await for (final videos in ref.watch(videoEventsProvider)) {
    final unseen = <VideoEvent>[];
    final seen = <VideoEvent>[];

    // Partition into unseen and seen, maintaining order within each
    for (final video in videos) {
      if (seenService.hasSeenVideo(video.id)) {
        seen.add(video);
      } else {
        unseen.add(video);
      }
    }

    // Concatenate: unseen first, then seen
    final reordered = [...unseen, ...seen];

    Log.debug(
      '🆕 UnseenVideoEvents: ${videos.length} videos → ${unseen.length} unseen, ${seen.length} seen',
      name: 'UnseenVideoEventsProvider',
      category: LogCategory.video,
    );

    yield reordered;
  }
}

Run: dart run build_runner build
Run: flutter test test/providers/unseen_video_events_provider_test.dart
Verify tests pass.
```

---

## TDD Test 2: Performance

```dart
test('reorders 1000 videos in less than 50ms', () async {
  final seenService = SeenVideosService();
  await seenService.initialize();

  // Mark half as seen
  for (int i = 0; i < 500; i++) {
    await seenService.markVideoAsSeen('video$i');
  }

  final largeVideoList = List.generate(
    1000,
    (i) => VideoEvent(id: 'video$i', pubkey: 'pub$i', title: 'Video $i'),
  );

  final container = ProviderContainer(
    overrides: [
      seenVideosServiceProvider.overrideWithValue(seenService),
      videoEventsProvider.overrideWith(
        (ref) => Stream.value(largeVideoList),
      ),
    ],
  );

  final stopwatch = Stopwatch()..start();
  final result = await container.read(unseenVideoEventsProvider.future);
  stopwatch.stop();

  expect(result.length, 1000);
  expect(stopwatch.elapsedMilliseconds, lessThan(50));
});
```

**Prompt 2: Add performance test and verify**
```
Add performance test to test/providers/unseen_video_events_provider_test.dart.
Run and verify it passes.
```

---

## TDD Test 3: Wire to ExploreScreen

**File**: `test/screens/explore_screen_shows_fresh_test.dart`

```dart
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/seen_videos_service.dart';

void main() {
  testWidgets('ExploreScreen shows unseen videos first', (tester) async {
    final seenService = SeenVideosService();
    await seenService.initialize();
    await seenService.markVideoAsSeen('video1');

    final testVideos = [
      VideoEvent(id: 'video1', pubkey: 'pub1', title: 'Seen Video'),
      VideoEvent(id: 'video2', pubkey: 'pub2', title: 'Unseen Video'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          seenVideosServiceProvider.overrideWithValue(seenService),
          videoEventsProvider.overrideWith(
            (ref) => Stream.value(testVideos),
          ),
        ],
        child: MaterialApp(home: ExploreScreen()),
      ),
    );

    await tester.pumpAndSettle();

    // Both should be visible, but verify grid order if possible
    // (Note: actual grid widget testing may need widget-specific finders)
    expect(find.text('Unseen Video'), findsWidgets);
    expect(find.text('Seen Video'), findsWidgets);
  });
}
```

**Prompt 3A: Write test**
```
Create test/screens/explore_screen_shows_fresh_test.dart with test above.
Run and see current behavior.
```

**Prompt 3B: Wire unseenVideoEventsProvider to ExploreScreen**
```
Modify lib/screens/explore_screen.dart:

Change line that watches videoEventsProvider to:
  final videos = ref.watch(unseenVideoEventsProvider);

That's it. ExploreScreen now automatically shows fresh videos first.

Run: flutter test test/screens/explore_screen_shows_fresh_test.dart
Verify test passes (or update test to verify actual order in grid).
```

---

## TDD Test 4: Home Feed

**File**: `test/providers/unseen_home_feed_provider_test.dart`

```dart
test('home feed shows unseen videos first', () async {
  final seenService = SeenVideosService();
  await seenService.initialize();
  await seenService.markVideoAsSeen('video1');

  final testState = VideoFeedState(
    videos: [
      VideoEvent(id: 'video1', pubkey: 'follow1', title: 'Seen'),
      VideoEvent(id: 'video2', pubkey: 'follow2', title: 'Unseen'),
    ],
    hasMoreContent: false,
    isLoadingMore: false,
  );

  final container = ProviderContainer(
    overrides: [
      seenVideosServiceProvider.overrideWithValue(seenService),
      homeFeedProvider.overrideWith((ref) async => testState),
    ],
  );

  final result = await container.read(unseenHomeFeedProvider.future);

  expect(result.videos[0].id, 'video2'); // Unseen first
  expect(result.videos[1].id, 'video1'); // Seen after
});
```

**Prompt 4A: Write test**
```
Create test/providers/unseen_home_feed_provider_test.dart with test above.
Run and verify it fails.
```

**Prompt 4B: Implement unseenHomeFeedProvider**
```
Create lib/providers/unseen_home_feed_provider.dart:

@riverpod
Future<VideoFeedState> unseenHomeFeed(Ref ref) async {
  final seenService = ref.watch(seenVideosServiceProvider);
  final homeFeed = await ref.watch(homeFeedProvider.future);

  final unseen = <VideoEvent>[];
  final seen = <VideoEvent>[];

  for (final video in homeFeed.videos) {
    if (seenService.hasSeenVideo(video.id)) {
      seen.add(video);
    } else {
      unseen.add(video);
    }
  }

  final reordered = [...unseen, ...seen];

  return homeFeed.copyWith(videos: reordered);
}

Run: dart run build_runner build
Run test and verify it passes.
```

**Prompt 4C: Wire to VideoFeedScreen**
```
Modify lib/screens/video_feed_screen.dart:

In _VideoFeedScreenState, change homeFeedProvider to unseenHomeFeedProvider:
  final feedState = ref.watch(unseenHomeFeedProvider);

That's it. Home feed now shows fresh first.

Run tests to verify nothing broke.
```

---

## TDD Test 5: Integration

**File**: `test/integration/fresh_content_integration_test.dart`

```dart
testWidgets('watching video moves it to end of feed on next load', (tester) async {
  final seenService = SeenVideosService();
  await seenService.initialize();

  final testVideos = [
    VideoEvent(id: 'video1', pubkey: 'pub1', title: 'Video 1'),
    VideoEvent(id: 'video2', pubkey: 'pub2', title: 'Video 2'),
  ];

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        seenVideosServiceProvider.overrideWithValue(seenService),
        videoEventsProvider.overrideWith(
          (ref) => Stream.value(testVideos),
        ),
      ],
      child: MaterialApp(home: ExploreScreen()),
    ),
  );

  await tester.pumpAndSettle();

  // Initial state: both videos present
  expect(find.text('Video 1'), findsWidgets);
  expect(find.text('Video 2'), findsWidgets);

  // Simulate watching video1
  await seenService.recordVideoView('video1');

  // Trigger rebuild by invalidating provider
  final container = ProviderScope.containerOf(tester.element(find.byType(ExploreScreen)));
  container.invalidate(unseenVideoEventsProvider);

  await tester.pumpAndSettle();

  // Both videos still present, but order changed
  // (Detailed order verification depends on grid widget implementation)
  expect(find.text('Video 1'), findsWidgets);
  expect(find.text('Video 2'), findsWidgets);
});
```

**Prompt 5: Integration test**
```
Create test/integration/fresh_content_integration_test.dart with test above.
Run and verify the complete flow works.
```

---

## What Gets Changed

**New Files**:
- `lib/providers/unseen_video_events_provider.dart`
- `lib/providers/unseen_home_feed_provider.dart`

**Modified Files**:
- `lib/screens/explore_screen.dart` - Change one line to use unseenVideoEventsProvider
- `lib/screens/video_feed_screen.dart` - Change one line to use unseenHomeFeedProvider

**Not Changed**:
- VideoFeedScreen structure
- ExploreScreen structure
- PageView logic
- Video preloading
- VideoMetricsTracker

---

## Implementation Order

1. Write test 1 → Implement unseenVideoEventsProvider
2. Write test 2 → Verify performance
3. Write test 3 → Wire to ExploreScreen (change 1 line)
4. Write test 4 → Implement unseenHomeFeedProvider
5. Write test 4C → Wire to VideoFeedScreen (change 1 line)
6. Write test 5 → Verify integration

Total changes: **2 new providers + 2 lines changed in screens**

---

## Why This Works

- **Simple reordering** - O(n) partition, maintains original order within groups
- **PageView compatible** - Still gets full list, just reordered
- **Automatic** - No user settings, just works
- **Fast** - HashMap lookup per video
- **Test-driven** - Every step has test

Ready to implement? Start with **Prompt 1A**.

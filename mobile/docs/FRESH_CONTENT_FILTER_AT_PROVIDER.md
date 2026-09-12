# Fresh Content Filter - Provider-Level Implementation (TDD)

## Core Principle

**Filter at the provider level** - VideoFeedScreen receives pre-filtered list, no UI changes needed.

```dart
// homeFeedProvider returns filtered videos
// VideoFeedScreen consumes them unchanged
// PageView indices work because list is filtered BEFORE it reaches UI
```

## Architecture Pattern

Looking at `home_feed_provider.dart`, it already filters by following list:
1. Gets all videos from VideoEventService
2. Filters to only followed authors
3. Returns filtered VideoFeedState
4. VideoFeedScreen displays it unchanged

**We use the same pattern for seen/unseen filtering.**

---

## Where to Apply Filter

### Discovery Feed (Explore)
- **Always show fresh first** - users exploring want new content
- Filter: `videoEventsProvider` → `unseenVideoEventsProvider`

### Home Feed (Following)
- **User preference** - toggle "show fresh from following"
- Filter: `homeFeedProvider` → wrapped with unseen filter when enabled

### User Profile / Hashtag Feeds
- **No filtering** - when viewing specific content, show everything

---

## TDD Implementation Plan

### Test 1: Unseen Filter for Discovery Feed

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
    test('filters out seen videos from discovery feed', () async {
      // Arrange
      final seenService = SeenVideosService();
      await seenService.initialize();
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
      final unseenAsync = await container.read(unseenVideoEventsProvider.future);

      // Assert
      expect(unseenAsync.length, 2);
      expect(unseenAsync[0].id, 'video2');
      expect(unseenAsync[1].id, 'video4');
      expect(unseenAsync[0].title, 'Unseen 1');
    });

    test('returns empty list when all videos are seen', () async {
      final seenService = SeenVideosService();
      await seenService.initialize();
      await seenService.markVideoAsSeen('video1');
      await seenService.markVideoAsSeen('video2');

      final testVideos = [
        VideoEvent(id: 'video1', pubkey: 'pub1', title: 'Seen 1'),
        VideoEvent(id: 'video2', pubkey: 'pub2', title: 'Seen 2'),
      ];

      final container = ProviderContainer(
        overrides: [
          seenVideosServiceProvider.overrideWithValue(seenService),
          videoEventsProvider.overrideWith(
            (ref) => Stream.value(testVideos),
          ),
        ],
      );

      final unseenAsync = await container.read(unseenVideoEventsProvider.future);

      expect(unseenAsync.length, 0);
    });

    test('returns all videos when none are seen', () async {
      final seenService = SeenVideosService();
      await seenService.initialize();

      final testVideos = [
        VideoEvent(id: 'video1', pubkey: 'pub1', title: 'Unseen 1'),
        VideoEvent(id: 'video2', pubkey: 'pub2', title: 'Unseen 2'),
      ];

      final container = ProviderContainer(
        overrides: [
          seenVideosServiceProvider.overrideWithValue(seenService),
          videoEventsProvider.overrideWith(
            (ref) => Stream.value(testVideos),
          ),
        ],
      );

      final unseenAsync = await container.read(unseenVideoEventsProvider.future);

      expect(unseenAsync.length, 2);
    });
  });
}
```

**Prompt 1A: Write the failing test**
```
Create test/providers/unseen_video_events_provider_test.dart with the tests above.
Run: flutter test test/providers/unseen_video_events_provider_test.dart
Verify it fails because unseenVideoEventsProvider doesn't exist.
```

**Prompt 1B: Implement the provider**
```
Create lib/providers/unseen_video_events_provider.dart:

import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'unseen_video_events_provider.g.dart';

/// Stream provider that filters videoEventsProvider to show only unseen videos
@Riverpod(keepAlive: false)
Stream<List<VideoEvent>> unseenVideoEvents(Ref ref) async* {
  final seenService = ref.watch(seenVideosServiceProvider);

  await for (final videos in ref.watch(videoEventsProvider)) {
    final unseen = videos.where((v) => !seenService.hasSeenVideo(v.id)).toList();

    Log.debug(
      '🆕 UnseenVideoEvents: Filtered ${videos.length} videos → ${unseen.length} unseen',
      name: 'UnseenVideoEventsProvider',
      category: LogCategory.video,
    );

    yield unseen;
  }
}

Then run: dart run build_runner build
Then run: flutter test test/providers/unseen_video_events_provider_test.dart
Verify all tests pass.
```

---

### Test 2: Performance - Filter 1000 Videos Quickly

```dart
test('filters 1000 videos in less than 50ms', () async {
  // Arrange
  final seenService = SeenVideosService();
  await seenService.initialize();

  // Mark half as seen
  for (int i = 0; i < 500; i++) {
    await seenService.markVideoAsSeen('video$i');
  }

  final largeVideoList = List.generate(
    1000,
    (i) => VideoEvent(
      id: 'video$i',
      pubkey: 'pub$i',
      title: 'Video $i',
    ),
  );

  final container = ProviderContainer(
    overrides: [
      seenVideosServiceProvider.overrideWithValue(seenService),
      videoEventsProvider.overrideWith(
        (ref) => Stream.value(largeVideoList),
      ),
    ],
  );

  // Act
  final stopwatch = Stopwatch()..start();
  final unseen = await container.read(unseenVideoEventsProvider.future);
  stopwatch.stop();

  // Assert
  expect(unseen.length, 500);
  expect(stopwatch.elapsedMilliseconds, lessThan(50),
      reason: 'Filtering should be fast (was ${stopwatch.elapsedMilliseconds}ms)');
});
```

**Prompt 2: Add performance test**
```
Add the performance test above to test/providers/unseen_video_events_provider_test.dart.
Run the test and verify it passes.
If it fails due to performance, profile and optimize:
  - Ensure hasSeenVideo() is O(1) HashMap lookup
  - Consider caching if needed
```

---

### Test 3: Wire to ExploreScreen

**File**: `test/screens/explore_screen_fresh_filter_test.dart`

```dart
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/providers/unseen_video_events_provider.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/seen_videos_service.dart';

void main() {
  testWidgets('ExploreScreen shows only unseen videos when fresh filter enabled',
      (tester) async {
    // Arrange
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
          // ExploreScreen should use unseenVideoEventsProvider when fresh filter is on
          videoEventsProvider.overrideWith(
            (ref) => ref.watch(unseenVideoEventsProvider),
          ),
        ],
        child: MaterialApp(home: ExploreScreen()),
      ),
    );

    await tester.pumpAndSettle();

    // Assert - Only unseen video should be visible
    expect(find.text('Unseen Video'), findsWidgets);
    expect(find.text('Seen Video'), findsNothing);
  });
}
```

**Prompt 3A: Write the test**
```
Create test/screens/explore_screen_fresh_filter_test.dart with the test above.
Run it and verify current behavior (probably shows both videos).
```

**Prompt 3B: Add fresh filter toggle to ExploreScreen**
```
Modify lib/screens/explore_screen.dart:

1. Add state: bool _showFreshOnly = true; // Default to fresh filter
2. Add toggle button in AppBar:
   IconButton(
     icon: Icon(_showFreshOnly ? Icons.auto_awesome : Icons.all_inclusive),
     onPressed: () => setState(() => _showFreshOnly = !_showFreshOnly),
   )
3. Change video source based on toggle:
   final videos = _showFreshOnly
       ? ref.watch(unseenVideoEventsProvider)
       : ref.watch(videoEventsProvider);
4. Use videos in grid/feed display

Run test again and verify it passes.
```

---

### Test 4: Home Feed Optional Filter

**File**: `test/providers/unseen_home_feed_provider_test.dart`

```dart
test('unseenHomeFeedProvider filters home feed by seen status', () async {
  // Arrange
  final seenService = SeenVideosService();
  await seenService.initialize();
  await seenService.markVideoAsSeen('video1');

  final testVideos = [
    VideoEvent(id: 'video1', pubkey: 'following1', title: 'Seen'),
    VideoEvent(id: 'video2', pubkey: 'following2', title: 'Unseen'),
  ];

  final container = ProviderContainer(
    overrides: [
      seenVideosServiceProvider.overrideWithValue(seenService),
      homeFeedProvider.overrideWith((ref) async {
        return VideoFeedState(
          videos: testVideos,
          hasMoreContent: false,
          isLoadingMore: false,
        );
      }),
    ],
  );

  // Act
  final unseenFeed = await container.read(unseenHomeFeedProvider.future);

  // Assert
  expect(unseenFeed.videos.length, 1);
  expect(unseenFeed.videos[0].id, 'video2');
});
```

**Prompt 4A: Write the test**
```
Create test/providers/unseen_home_feed_provider_test.dart with the test above.
Run and verify it fails.
```

**Prompt 4B: Implement unseenHomeFeedProvider**
```
Create lib/providers/unseen_home_feed_provider.dart:

@riverpod
Future<VideoFeedState> unseenHomeFeed(Ref ref) async {
  final seenService = ref.watch(seenVideosServiceProvider);
  final homeFeed = await ref.watch(homeFeedProvider.future);

  final unseenVideos = homeFeed.videos
      .where((v) => !seenService.hasSeenVideo(v.id))
      .toList();

  return homeFeed.copyWith(videos: unseenVideos);
}

Run: dart run build_runner build
Run test and verify it passes.
```

---

### Test 5: Settings Persistence

**File**: `test/services/feed_preferences_service_test.dart`

```dart
test('feed preferences persist across app restarts', () async {
  // Arrange
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();

  final service = FeedPreferencesService(prefs);
  await service.initialize();

  // Act
  await service.setShowFreshInExplore(true);
  await service.setShowFreshInHome(false);

  // Create new instance to simulate app restart
  final service2 = FeedPreferencesService(prefs);
  await service2.initialize();

  // Assert
  expect(service2.showFreshInExplore, true);
  expect(service2.showFreshInHome, false);
});
```

**Prompt 5A: Write preferences test**
```
Create test/services/feed_preferences_service_test.dart with the test above.
Run and verify it fails.
```

**Prompt 5B: Implement FeedPreferencesService**
```
Create lib/services/feed_preferences_service.dart:

class FeedPreferencesService {
  static const _keyShowFreshExplore = 'show_fresh_in_explore';
  static const _keyShowFreshHome = 'show_fresh_in_home';

  final SharedPreferences _prefs;

  bool _showFreshInExplore = true; // Default: filter explore
  bool _showFreshInHome = false; // Default: don't filter home

  bool get showFreshInExplore => _showFreshInExplore;
  bool get showFreshInHome => _showFreshInHome;

  FeedPreferencesService(this._prefs);

  Future<void> initialize() async {
    _showFreshInExplore = _prefs.getBool(_keyShowFreshExplore) ?? true;
    _showFreshInHome = _prefs.getBool(_keyShowFreshHome) ?? false;
  }

  Future<void> setShowFreshInExplore(bool value) async {
    _showFreshInExplore = value;
    await _prefs.setBool(_keyShowFreshExplore, value);
  }

  Future<void> setShowFreshInHome(bool value) async {
    _showFreshInHome = value;
    await _prefs.setBool(_keyShowFreshHome, value);
  }
}

Add provider in lib/providers/app_providers.dart:

@riverpod
FeedPreferencesService feedPreferencesService(Ref ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return FeedPreferencesService(prefs);
}

Run test and verify it passes.
```

---

### Test 6: Integration - Full Flow

**File**: `test/integration/fresh_content_flow_test.dart`

```dart
testWidgets('watching video removes it from fresh feed', (tester) async {
  // Arrange
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

  // Both videos visible initially
  expect(find.text('Video 1'), findsOneWidget);
  expect(find.text('Video 2'), findsOneWidget);

  // Act - Tap to watch video1
  await tester.tap(find.text('Video 1'));
  await tester.pumpAndSettle();

  // Simulate VideoMetricsTracker marking as seen
  await seenService.recordVideoView('video1');

  // Navigate back
  await tester.pageBack();
  await tester.pumpAndSettle();

  // Assert - Video 1 should be gone, Video 2 still there
  expect(find.text('Video 1'), findsNothing);
  expect(find.text('Video 2'), findsOneWidget);
});
```

**Prompt 6: Integration test**
```
Create test/integration/fresh_content_flow_test.dart with the test above.
This verifies the full flow:
  1. Videos load in explore
  2. User watches a video
  3. VideoMetricsTracker marks it as seen
  4. It disappears from feed

Run and verify the complete integration works.
```

---

## Implementation Summary

### What Gets Changed

**New Files**:
- `lib/providers/unseen_video_events_provider.dart` - Filter discovery feed
- `lib/providers/unseen_home_feed_provider.dart` - Filter home feed
- `lib/services/feed_preferences_service.dart` - Store user preferences

**Modified Files**:
- `lib/screens/explore_screen.dart` - Add toggle button, use unseen provider when enabled
- `lib/screens/video_feed_screen.dart` - Use unseen home feed when preference enabled
- `lib/providers/app_providers.dart` - Add feedPreferencesService provider

**NO Changes to**:
- VideoFeedScreen core logic
- PageView implementation
- Video preloading
- VideoMetricsTracker

---

## Why This Works

1. **Reuses all existing UI** - VideoFeedScreen, ExploreScreen unchanged at core
2. **Filter before UI sees data** - PageView gets pre-filtered list, indices work fine
3. **Simple O(n) performance** - HashMap lookup per video
4. **User control** - Toggle on/off per feed type
5. **Test-driven** - Every feature has failing test → passing implementation

---

## TDD Execution Order

1. Test unseenVideoEventsProvider → Implement
2. Test performance → Optimize if needed
3. Test ExploreScreen integration → Wire toggle
4. Test unseenHomeFeedProvider → Implement
5. Test preferences service → Implement
6. Integration test → Verify full flow

Each step: **Write test → Run (should fail) → Implement → Run (should pass)**

---

## Default Behavior

**Explore (Discovery)**: Fresh filter ON by default - exploring means finding new content
**Home (Following)**: Fresh filter OFF by default - see all from people you follow
**Profile/Hashtag**: No filter - viewing specific content

Users can toggle in settings or via AppBar icon.

// ABOUTME: Integration test proving profile route renders videos with overlays
// ABOUTME: Tests the full router → provider → service → UI pipeline

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/app_lifecycle_provider.dart';
import 'package:openvine/providers/active_video_provider.dart';
import 'package:openvine/ui/overlay_policy.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/utils/npub_hex.dart';
import 'package:openvine/services/video_prewarmer.dart';
import 'package:openvine/services/visibility_tracker.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart'
    as ff;
import 'package:shared_preferences/shared_preferences.dart';

/// Helper to wait for a condition to become true
Future<void> waitFor<T>(
  WidgetTester tester,
  T Function() read, {
  required T want,
  Duration timeout = const Duration(seconds: 2),
}) async {
  final start = DateTime.now();
  while (read() != want) {
    if (DateTime.now().difference(start) > timeout) {
      throw TestFailure('waitFor timed out. wanted: $want, got: ${read()}');
    }
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('profile route renders videos & overlays', (tester) async {
    // Test fixture
    final testNpub =
        'npub1l5sga6xg72phsz5422ykujprejwud075ggrr3z2hwyrfgr7eylqstegx9z';
    final testHex = npubToHexOrNull(testNpub)!;

    final testVideo = VideoEvent(
      id: 'test-video-1',
      pubkey: testHex,
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      content: 'Test Title',
      title: 'Test Title',
      videoUrl: 'https://example.com/test.mp4',
      timestamp: DateTime.now(),
    );

    // Create fake service that returns test videos
    final fakeService = _FakeVideoEventService(
      authorVideos: {
        testHex: [testVideo],
      },
    );

    // Setup fake SharedPreferences
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        videoEventServiceProvider.overrideWithValue(fakeService),
        appForegroundProvider.overrideWithValue(
          const AsyncValue.data(true),
        ), // Ensure app is in foreground
        overlayPolicyProvider.overrideWithValue(
          OverlayPolicy.alwaysOn,
        ), // Force overlays visible in tests
        videoPrewarmerProvider.overrideWithValue(
          NoopPrewarmer(),
        ), // Prevent timer leaks from video prewarming
        visibilityTrackerProvider.overrideWithValue(
          NoopVisibilityTracker(),
        ), // Prevent timer leaks from visibility tracking
        analyticsServiceProvider.overrideWithValue(
          NoopAnalyticsService(),
        ), // Prevent timer leaks from analytics retry delays
        ff.sharedPreferencesProvider.overrideWithValue(
          prefs,
        ), // Override feature flag shared prefs provider
      ],
    );
    // NOTE: container.dispose() is called explicitly before test ends, not in tearDown

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: container.read(goRouterProvider),
        ),
      ),
    );

    // Navigate to profile route
    container.read(goRouterProvider).go('/profile/$testNpub/0');
    await tester.pump(); // Build router
    await tester.pump(const Duration(milliseconds: 1)); // Post-frames
    await tester.pump(); // Settle

    // Wait for the first video to become active
    await waitFor(
      tester,
      () => container.read(isVideoActiveProvider(testVideo.id)),
      want: true,
    );

    // Assertions: video card visible + overlay text visible
    expect(
      find.text('Test Title'),
      findsOneWidget,
      reason: 'Video title should be visible in overlay',
    );

    // Verify ProfileScreenRouter uses VideoPageView (not legacy placeholder)
    expect(
      find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == 'VideoPageView',
      ),
      findsOneWidget,
      reason: 'ProfileScreenRouter should use VideoPageView',
    );
    expect(
      find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == 'VideoFeedItem',
      ),
      findsOneWidget,
      reason: 'VideoPageView should render VideoFeedItem',
    );
    expect(
      find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == 'VideoOverlayActions',
      ),
      findsOneWidget,
      reason: 'VideoFeedItem should render VideoOverlayActions',
    );

    // CRITICAL: Dispose services BEFORE test ends to cancel pending timers
    fakeService
        .dispose(); // Dispose fake service to cancel ConnectionStatusService timer
    container.dispose(); // Dispose provider container

    // NOTE: Timer leaks previously fixed:
    // - VideoPrewarmer: NoOp override prevents timer leaks
    // - VisibilityTracker: NoOp override prevents timer leaks
    // - UserProfileService: dispose() wired into provider lifecycle
    // - AnalyticsService: dispose() already wired into provider lifecycle
  });
}

/// Fake VideoEventService for testing
class _FakeVideoEventService extends VideoEventService {
  _FakeVideoEventService({required Map<String, List<VideoEvent>> authorVideos})
    : _authorVideos = authorVideos,
      super(
        _FakeNostrService(),
        subscriptionManager: _FakeSubscriptionManager(),
      );

  final Map<String, List<VideoEvent>> _authorVideos;

  @override
  List<VideoEvent> authorVideos(String pubkeyHex) {
    return _authorVideos[pubkeyHex] ?? const [];
  }

  @override
  Future<void> subscribeToUserVideos(String pubkey, {int limit = 50}) async {
    // No-op for test - videos already populated
    return Future.value();
  }
}

class _FakeNostrService implements INostrService {
  @override
  bool get isInitialized => true;

  @override
  int get connectedRelayCount => 1;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSubscriptionManager extends SubscriptionManager {
  _FakeSubscriptionManager() : super(_FakeNostrService());
}

/// NoOp AnalyticsService that prevents network calls and timer leaks
class NoopAnalyticsService extends AnalyticsService {
  @override
  Future<void> trackVideoView(video, {String source = 'mobile'}) async {
    // No-op - prevent network calls in tests
  }

  @override
  Future<void> trackVideoViewWithUser(
    video, {
    required userId,
    String source = 'mobile',
  }) async {
    // No-op - prevent network calls in tests
  }

  @override
  Future<void> trackDetailedVideoView(
    video, {
    required String source,
    required String eventType,
    watchDuration,
    totalDuration,
    loopCount,
    completedVideo,
  }) async {
    // No-op - prevent network calls in tests
  }

  @override
  Future<void> trackDetailedVideoViewWithUser(
    video, {
    required userId,
    required String source,
    required String eventType,
    watchDuration,
    totalDuration,
    loopCount,
    completedVideo,
  }) async {
    // No-op - prevent network calls in tests
  }
}

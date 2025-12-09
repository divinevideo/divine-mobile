// ABOUTME: Integration test for /profile/me/ redirect with full app context
// ABOUTME: Tests redirect logic + profile screen rendering in realistic scenario

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/app_lifecycle_provider.dart';
import 'package:openvine/ui/overlay_policy.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_prewarmer.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart'
    as ff;
import 'package:openvine/services/analytics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Profile /me/ Redirect Integration', () {
    testWidgets(
      'should redirect /profile/me/0 to actual user npub and render profile',
      (tester) async {
        // ARRANGE: Create authenticated user with known public key
        const testUserHex =
            '78a5c21b5166dc1474b64ddf7454bf79e6b5d6b4a77148593bf1e866b73c2738';
        final testUserNpub = NostrKeyUtils.encodePubKey(testUserHex);

        final testVideo = VideoEvent(
          id: 'test-video-1',
          pubkey: testUserHex,
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          content: 'Test Video',
          title: 'Test Video',
          videoUrl: 'https://example.com/test.mp4',
          timestamp: DateTime.now(),
        );

        // Create mock services
        final mockAuthService = _MockAuthService(testUserHex);
        final fakeVideoService = _FakeVideoEventService(
          authorVideos: {
            testUserHex: [testVideo],
          },
        );

        // Setup fake SharedPreferences
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final container = ProviderContainer(
          overrides: [
            authServiceProvider.overrideWithValue(mockAuthService),
            videoEventServiceProvider.overrideWithValue(fakeVideoService),
            appForegroundProvider.overrideWithValue(
              const AsyncValue.data(true),
            ),
            overlayPolicyProvider.overrideWithValue(OverlayPolicy.alwaysOn),
            videoPrewarmerProvider.overrideWithValue(NoopPrewarmer()),
            analyticsServiceProvider.overrideWithValue(NoopAnalyticsService()),
            ff.sharedPreferencesProvider.overrideWithValue(prefs),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              routerConfig: container.read(goRouterProvider),
            ),
          ),
        );

        // Wait for initial route to settle
        await tester.pumpAndSettle();

        // ACT: Navigate to /profile/me/0 (mimics post-publish navigation)
        final router = container.read(goRouterProvider);
        router.go('/profile/me/0');
        await tester.pump(); // Trigger redirect
        await tester.pump(); // Build new route
        await tester.pump(const Duration(milliseconds: 1)); // Post-frames

        // ASSERT: Route should have been redirected to actual npub
        final location = router.routeInformationProvider.value.uri.toString();
        expect(
          location,
          '/profile/$testUserNpub/0',
          reason:
              'Should redirect /profile/me/0 to actual user npub: $testUserNpub',
        );

        // ASSERT: Profile screen should render
        await tester.pumpAndSettle();

        // Verify VideoPageView is used (not legacy placeholder)
        expect(
          find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == 'VideoPageView',
          ),
          findsOneWidget,
          reason: 'ProfileScreenRouter should use VideoPageView after redirect',
        );

        // Clean up
        fakeVideoService.dispose();
        container.dispose();
      },
    );

    testWidgets('should redirect /profile/me/1 to grid view with actual npub', (
      tester,
    ) async {
      // ARRANGE
      const testUserHex =
          '78a5c21b5166dc1474b64ddf7454bf79e6b5d6b4a77148593bf1e866b73c2738';
      final testUserNpub = NostrKeyUtils.encodePubKey(testUserHex);

      final mockAuthService = _MockAuthService(testUserHex);
      final fakeVideoService = _FakeVideoEventService(authorVideos: {});

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(mockAuthService),
          videoEventServiceProvider.overrideWithValue(fakeVideoService),
          appForegroundProvider.overrideWithValue(const AsyncValue.data(true)),
          videoPrewarmerProvider.overrideWithValue(NoopPrewarmer()),
          analyticsServiceProvider.overrideWithValue(NoopAnalyticsService()),
          ff.sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // ACT: Navigate to grid view (index=1)
      final router = container.read(goRouterProvider);
      router.go('/profile/me/1');
      await tester.pump();
      await tester.pump();

      // ASSERT: Should redirect to grid view with actual npub
      final location = router.routeInformationProvider.value.uri.toString();
      expect(
        location,
        '/profile/$testUserNpub/1',
        reason: 'Should redirect /profile/me/1 to actual user npub grid view',
      );

      // Clean up
      fakeVideoService.dispose();
      container.dispose();
    });

    testWidgets('should redirect to /home/0 when not authenticated', (
      tester,
    ) async {
      // ARRANGE: Not authenticated
      final mockAuthService = _MockAuthService(null);
      final fakeVideoService = _FakeVideoEventService(authorVideos: {});

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(mockAuthService),
          videoEventServiceProvider.overrideWithValue(fakeVideoService),
          appForegroundProvider.overrideWithValue(const AsyncValue.data(true)),
          videoPrewarmerProvider.overrideWithValue(NoopPrewarmer()),
          analyticsServiceProvider.overrideWithValue(NoopAnalyticsService()),
          ff.sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // ACT: Try to navigate to /profile/me/0 when not logged in
      final router = container.read(goRouterProvider);
      router.go('/profile/me/0');
      await tester.pump();
      await tester.pump();

      // ASSERT: Should redirect to home
      final location = router.routeInformationProvider.value.uri.toString();
      expect(
        location.contains('/home'),
        isTrue,
        reason: 'Should redirect to home when not authenticated',
      );

      // Clean up
      fakeVideoService.dispose();
      container.dispose();
    });
  });
}

/// Mock auth service for testing
class _MockAuthService implements AuthService {
  final String? _currentUserHex;

  _MockAuthService(this._currentUserHex);

  @override
  String? get currentPublicKeyHex => _currentUserHex;

  @override
  bool get isAuthenticated => _currentUserHex != null;

  @override
  AuthState get authState =>
      isAuthenticated ? AuthState.authenticated : AuthState.unauthenticated;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

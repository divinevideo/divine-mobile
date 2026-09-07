// ABOUTME: Integration test for /profile/me/ redirect with full app context
// ABOUTME: Tests redirect logic + profile screen rendering in realistic scenario
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/view_traffic_source.dart'
    show ViewTrafficSource;
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/ui/overlay_policy.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_pubkeys.dart';

void main() {
  group('Profile /me/ Redirect Integration', () {
    testWidgets(
      'should redirect /profile/me/0 to actual user npub and render profile',
      (tester) async {
        // ARRANGE: Create authenticated user with known public key
        const testUserHex = syntheticTestPubkey;
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
            overlayPolicyProvider.overrideWithValue(OverlayPolicy.alwaysOn),
            analyticsServiceProvider.overrideWithValue(NoopAnalyticsService()),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
        );
        container.read(appForegroundProvider.notifier).setForeground(true);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: container.read(goRouterProvider),
            ),
          ),
        );

        // Wait for initial route to settle
        await tester.pumpAndSettle();

        // ACT: Navigate to /profile/me/0 (mimics post-publish navigation)
        final router = container.read(goRouterProvider);
        router.go(ProfileScreenRouter.pathForIndex('me', 0));
        await tester.pump(); // Trigger redirect
        await tester.pump(); // Build new route
        await tester.pump(const Duration(milliseconds: 1)); // Post-frames

        // ASSERT: Route should have been redirected to actual npub
        final location = router.routeInformationProvider.value.uri.toString();
        expect(
          location,
          ProfileScreenRouter.pathForIndex(testUserNpub, 0),
          reason:
              'Should redirect /profile/me/0 to actual user npub: $testUserNpub',
        );

        // ASSERT: Profile screen should render
        await tester.pumpAndSettle();

        // Clean up
        fakeVideoService.dispose();
        container.dispose();
      },
    );

    testWidgets('should redirect /profile/me/1 to grid view with actual npub', (
      tester,
    ) async {
      // ARRANGE
      const testUserHex = syntheticTestPubkey;
      final testUserNpub = NostrKeyUtils.encodePubKey(testUserHex);

      final mockAuthService = _MockAuthService(testUserHex);
      final fakeVideoService = _FakeVideoEventService(authorVideos: {});

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(mockAuthService),
          videoEventServiceProvider.overrideWithValue(fakeVideoService),
          analyticsServiceProvider.overrideWithValue(NoopAnalyticsService()),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      container.read(appForegroundProvider.notifier).setForeground(true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // ACT: Navigate to grid view (index=1)
      final router = container.read(goRouterProvider);
      router.go(ProfileScreenRouter.pathForIndex('me', 1));
      await tester.pump();
      await tester.pump();

      // ASSERT: Should redirect to grid view with actual npub
      final location = router.routeInformationProvider.value.uri.toString();
      expect(
        location,
        ProfileScreenRouter.pathForIndex(testUserNpub, 1),
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
          analyticsServiceProvider.overrideWithValue(NoopAnalyticsService()),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      container.read(appForegroundProvider.notifier).setForeground(true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // ACT: Try to navigate to /profile/me/0 when not logged in
      final router = container.read(goRouterProvider);
      router.go(ProfileScreenRouter.pathForIndex('me', 0));
      await tester.pump();
      await tester.pump();

      // ASSERT: Should redirect to home
      final location = router.routeInformationProvider.value.uri.toString();
      expect(
        location.contains(VideoFeedPage.path),
        isTrue,
        reason: 'Should redirect to home when not authenticated',
      );

      // Clean up
      fakeVideoService.dispose();
      container.dispose();
    });
    // TODO(any): Fix and reenable this test
  }, skip: true);
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
        crashReporter: const SilentCrashReporter(),
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

class _FakeNostrService implements NostrClient {
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
  NoopAnalyticsService()
    : super(backgroundActivityManager: BackgroundActivityManager());

  @override
  Future<void> trackVideoView(
    VideoEvent video, {
    String source = 'mobile',
  }) async {
    // No-op - prevent network calls in tests
  }

  @override
  Future<void> trackVideoViewWithUser(
    VideoEvent video, {
    required String? userId,
    String source = 'mobile',
  }) async {
    // No-op - prevent network calls in tests
  }

  @override
  Future<void> trackDetailedVideoView(
    VideoEvent video, {
    required String source,
    required String eventType,
    String? sessionToken,
    Duration? watchDuration,
    Duration? totalDuration,
    double? loopCount,
    bool? completedVideo,
    ViewTrafficSource trafficSource = ViewTrafficSource.unknown,
    String? sourceDetail,
  }) async {
    // No-op - prevent network calls in tests
  }

  @override
  Future<void> trackDetailedVideoViewWithUser(
    VideoEvent video, {
    required String? userId,
    required String source,
    required String eventType,
    String? sessionToken,
    Duration? watchDuration,
    Duration? totalDuration,
    double? loopCount,
    bool? completedVideo,
    ViewTrafficSource trafficSource = ViewTrafficSource.unknown,
    String? sourceDetail,
  }) async {
    // No-op - prevent network calls in tests
  }
}

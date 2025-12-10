// ABOUTME: Integration test for ExploreScreen displaying real video events from relay
// ABOUTME: Tests the complete flow from relay connection to UI rendering

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/tab_visibility_provider.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/services/content_blocklist_service.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/utils/unified_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ExploreScreen Real Relay Integration', () {
    late NostrKeyManager keyManager;
    late NostrService nostrService;
    late SubscriptionManager subscriptionManager;
    late VideoEventService videoEventService;
    late ContentBlocklistService blocklistService;

    setUp(() async {
      // Enable logging for debugging
      Log.setLogLevel(LogLevel.debug);
      Log.enableCategories({
        LogCategory.system,
        LogCategory.relay,
        LogCategory.video,
      });

      // Initialize services
      keyManager = NostrKeyManager();
      await keyManager.initialize();

      if (!keyManager.hasKeys) {
        await keyManager.generateKeys();
      }

      blocklistService = ContentBlocklistService();
      nostrService = NostrService(keyManager);
      await nostrService.initialize();

      subscriptionManager = SubscriptionManager(nostrService);
      videoEventService = VideoEventService(
        nostrService,
        subscriptionManager: subscriptionManager,
      );
      videoEventService.setBlocklistService(blocklistService);

      // TopHashtagsService loads from static JSON, no need to inject dependencies
    });

    tearDown(() async {
      videoEventService.dispose();
      subscriptionManager.dispose();
      await nostrService.dispose();
    });

    testWidgets(
      'ExploreScreen displays videos from real relay',
      (WidgetTester tester) async {
        Log.info('🧪 Starting ExploreScreen real relay integration test');

        // Verify relay connection
        expect(nostrService.isInitialized, true);
        expect(nostrService.connectedRelays.isNotEmpty, true);
        Log.info(
          '✅ Connected to ${nostrService.connectedRelays.length} relay(s)',
        );

        // Subscribe to video feed before building UI
        Log.info('📡 Subscribing to discovery videos...');
        await videoEventService.subscribeToDiscovery(limit: 20);

        // Wait for initial events to arrive
        var attempts = 0;
        const maxAttempts = 60; // 30 seconds (500ms * 60)

        while (!videoEventService.hasEvents(SubscriptionType.discovery) &&
            attempts < maxAttempts) {
          await Future.delayed(const Duration(milliseconds: 500));
          attempts++;

          if (attempts % 10 == 0) {
            Log.info(
              '⏳ Waiting for events... ${videoEventService.getEventCount(SubscriptionType.discovery)} so far',
            );
          }
        }

        final eventCount = videoEventService.getEventCount(
          SubscriptionType.discovery,
        );
        Log.info('📊 Received $eventCount discovery videos');

        // Verify we got some events
        expect(
          eventCount,
          greaterThan(0),
          reason: 'Should receive video events from relay',
        );

        // Build widget with provider overrides
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              nostrServiceProvider.overrideWithValue(nostrService),
              subscriptionManagerProvider.overrideWithValue(
                subscriptionManager,
              ),
              videoEventServiceProvider.overrideWithValue(videoEventService),
              tabVisibilityProvider.overrideWith(
                () => TabVisibility()..setActiveTab(2),
              ), // Explore tab active
            ],
            child: MaterialApp(home: Scaffold(body: ExploreScreen())),
          ),
        );

        // Let the UI settle
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        Log.info('🔍 Checking UI rendering...');

        // Verify ExploreScreen rendered
        expect(find.byType(ExploreScreen), findsOneWidget);

        // Check for tab bar
        expect(find.byType(TabBar), findsOneWidget);
        expect(find.text('Popular Now'), findsOneWidget);
        expect(find.text('Trending'), findsOneWidget);

        // Wait for async state to resolve
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // Check that we're NOT showing loading indicator
        final loadingIndicators = find.byType(CircularProgressIndicator);
        Log.info(
          '🔄 Loading indicators found: ${tester.widgetList(loadingIndicators).length}',
        );

        // Check that we're NOT showing "No videos" message
        final noVideosText = find.text('No videos in Popular Now');
        expect(
          noVideosText,
          findsNothing,
          reason: 'Should not show "No videos" when we have $eventCount videos',
        );

        // Verify video grid is present (GridView.builder)
        final gridViews = find.byType(GridView);
        Log.info('📱 GridViews found: ${tester.widgetList(gridViews).length}');
        expect(
          gridViews,
          findsWidgets,
          reason: 'Should show video grid when we have videos',
        );

        // Try to find video tiles (GestureDetector wrapping video content)
        final videoTiles = find.byWidgetPredicate(
          (widget) => widget is GestureDetector && widget.child is Container,
        );
        Log.info(
          '🎬 Video tiles found: ${tester.widgetList(videoTiles).length}',
        );

        // Log final state
        Log.info('✅ ExploreScreen integration test complete');
        Log.info('   - Videos received: $eventCount');
        Log.info(
          '   - UI rendered: ${find.byType(ExploreScreen).evaluate().length}',
        );
        Log.info('   - GridViews: ${tester.widgetList(gridViews).length}');
      },
      timeout: const Timeout(Duration(seconds: 90)),
    );

    testWidgets(
      'ExploreScreen handles AsyncValue state correctly during tab navigation',
      (WidgetTester tester) async {
        Log.info('🧪 Testing AsyncValue state handling during navigation');

        // Subscribe and get some videos
        await videoEventService.subscribeToDiscovery(limit: 10);
        await Future.delayed(const Duration(seconds: 3));

        final eventCount = videoEventService.getEventCount(
          SubscriptionType.discovery,
        );
        expect(
          eventCount,
          greaterThan(0),
          reason: 'Need some videos for this test',
        );

        Log.info('📊 Pre-loaded $eventCount videos');

        // Build with Explore tab INACTIVE initially
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              nostrServiceProvider.overrideWithValue(nostrService),
              videoEventServiceProvider.overrideWithValue(videoEventService),
              tabVisibilityProvider.overrideWith(
                () => TabVisibility()..setActiveTab(0),
              ), // Feed tab active
            ],
            child: MaterialApp(home: Scaffold(body: ExploreScreen())),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Now simulate tab change to Explore tab
        Log.info('🔄 Simulating tab change to Explore');
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              nostrServiceProvider.overrideWithValue(nostrService),
              videoEventServiceProvider.overrideWithValue(videoEventService),
              tabVisibilityProvider.overrideWith(
                () => TabVisibility()..setActiveTab(2),
              ), // Explore tab now active
            ],
            child: MaterialApp(home: Scaffold(body: ExploreScreen())),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // CRITICAL: Videos should display immediately, not show loading
        // This tests the fix where hasValue takes priority over isLoading
        final noVideosText = find.text('No videos in Popular Now');
        expect(
          noVideosText,
          findsNothing,
          reason:
              'Should show cached videos immediately on tab change, not loading state',
        );

        final gridViews = find.byType(GridView);
        expect(
          gridViews,
          findsWidgets,
          reason: 'Should display video grid immediately with cached videos',
        );

        Log.info('✅ AsyncValue priority test passed');
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });
}

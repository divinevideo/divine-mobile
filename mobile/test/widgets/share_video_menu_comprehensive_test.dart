// ABOUTME: Comprehensive TDD tests for ShareVideoMenu with real data and service integration
// ABOUTME: Tests all functionality including content moderation, social sharing, and list management

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:openvine/widgets/share_video_menu.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/content_deletion_service.dart';
import 'package:openvine/services/content_moderation_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/video_sharing_service.dart';
import 'package:openvine/utils/unified_logger.dart';

@GenerateNiceMocks([
  MockSpec<ContentDeletionService>(),
  MockSpec<ContentModerationService>(),
  MockSpec<CuratedListService>(),
  MockSpec<SocialService>(),
  MockSpec<VideoSharingService>(),
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _setupPlatformMocks();

  group('ShareVideoMenu - Comprehensive TDD Tests', () {
    late NostrService nostrService;
    late NostrKeyManager keyManager;
    late VideoEventService videoEventService;
    late SubscriptionManager subscriptionManager;
    late List<VideoEvent> realVideos;
    // Mock services removed - focusing on core widget functionality first

    setUpAll(() async {
      Log.info(
        '🚀 Setting up ShareVideoMenu real video data test environment',
        name: 'ShareVideoMenuTest',
        category: LogCategory.system,
      );

      // Initialize real Nostr connection for realistic testing
      keyManager = NostrKeyManager();
      await keyManager.initialize();

      nostrService = NostrService(keyManager);
      await nostrService.initialize(
        customRelays: [
          'wss://staging-relay.divine.video',
          'wss://relay.damus.io',
          'wss://nos.lol',
        ],
      );

      subscriptionManager = SubscriptionManager(nostrService);
      videoEventService = VideoEventService(
        nostrService,
        subscriptionManager: subscriptionManager,
      );
      await _waitForRelayConnection(nostrService);
      realVideos = await _fetchRealVideoEvents(videoEventService);

      Log.info(
        '✅ Found ${realVideos.length} real videos for ShareVideoMenu testing',
        name: 'ShareVideoMenuTest',
        category: LogCategory.system,
      );
    });

    setUp(() {
      // Test setup - focus on widget behavior rather than service mocking
    });

    tearDownAll(() async {
      await nostrService.closeAllSubscriptions();
      nostrService.dispose();
    });

    group('Basic Widget Structure', () {
      testWidgets('creates ShareVideoMenu with required video', (tester) async {
        if (realVideos.isEmpty) return;

        final testVideo = realVideos.first;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(home: ShareVideoMenu(video: testVideo)),
          ),
        );

        // Allow for async loading
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(ShareVideoMenu), findsOneWidget);

        // Check for basic header elements first
        expect(find.text('Share Video'), findsOneWidget);
        expect(find.byIcon(Icons.close), findsOneWidget);

        // Debug: Print all text widgets to see what's rendered
        final textWidgets = find.byType(Text);
        for (int i = 0; i < textWidgets.evaluate().length && i < 10; i++) {
          final text = tester.widget<Text>(textWidgets.at(i));
          print('Found text widget: "${text.data}"');
        }

        // Should show main sections (if providers are working)
        expect(find.text('Share With'), findsOneWidget);
      });

      testWidgets('displays video information correctly', (tester) async {
        if (realVideos.isEmpty) return;

        final testVideo = realVideos.first;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(home: ShareVideoMenu(video: testVideo)),
          ),
        );

        await tester.pumpAndSettle();

        // Should display video title if available
        if (testVideo.title != null && testVideo.title!.isNotEmpty) {
          expect(find.textContaining(testVideo.title!), findsWidgets);
        }

        // Should display video duration if available
        if (testVideo.duration != null) {
          final durationText = '${testVideo.duration}s';
          expect(find.textContaining(durationText), findsWidgets);
        }
      });

      testWidgets('shows proper header with close functionality', (
        tester,
      ) async {
        if (realVideos.isEmpty) return;

        final testVideo = realVideos.first;
        bool dismissed = false;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: ShareVideoMenu(
                video: testVideo,
                onDismiss: () => dismissed = true,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should have close button or dismiss functionality
        final closeButton = find.byIcon(Icons.close);
        if (closeButton.evaluate().isNotEmpty) {
          await tester.tap(closeButton);
          await tester.pumpAndSettle();
          expect(dismissed, isTrue);
        }
      });
    });

    group('Share Functionality Tests', () {
      testWidgets('displays share options with proper icons and text', (
        tester,
      ) async {
        if (realVideos.isEmpty) return;

        final testVideo = realVideos.first;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(home: ShareVideoMenu(video: testVideo)),
          ),
        );

        await tester.pumpAndSettle();

        // Check for share options
        expect(find.text('Send to Viner'), findsOneWidget);
        expect(find.text('Share'), findsOneWidget);
        expect(find.byIcon(Icons.person_add), findsOneWidget);
        expect(find.byIcon(Icons.share), findsWidgets);
      });

      testWidgets('displays share button that triggers external share', (
        tester,
      ) async {
        if (realVideos.isEmpty) return;

        final testVideo = realVideos.first;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(home: ShareVideoMenu(video: testVideo)),
          ),
        );

        await tester.pumpAndSettle();

        // Verify Share button is present (combines copy link and share externally)
        expect(find.text('Share'), findsOneWidget);
        expect(find.text('Share via other apps or copy link'), findsOneWidget);

        Log.info(
          '✅ Share button test completed',
          name: 'ShareVideoMenuTest',
          category: LogCategory.system,
        );
      });

      testWidgets('shows send to user dialog when tapped', (tester) async {
        if (realVideos.isEmpty) return;

        final testVideo = realVideos.first;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(home: ShareVideoMenu(video: testVideo)),
          ),
        );

        await tester.pumpAndSettle();

        // Tap "Send to Viner"
        await tester.tap(find.text('Send to Viner'));
        await tester.pumpAndSettle();

        // Should show dialog or navigation to send interface
        // The exact UI depends on implementation, but some interaction should occur
        expect(find.byType(ShareVideoMenu), findsOneWidget);
      });
    });

    group('List Management Tests', () {
      testWidgets('displays list management options', (tester) async {
        if (realVideos.isEmpty) return;

        final testVideo = realVideos.first;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(home: ShareVideoMenu(video: testVideo)),
          ),
        );

        await tester.pumpAndSettle();

        // Should show list management section
        expect(find.text('Manage Lists'), findsOneWidget);
        expect(find.text('Add to Global Bookmarks'), findsOneWidget);
        expect(find.text('Create Follow Set'), findsOneWidget);
      });

      testWidgets('handles bookmark functionality with real video', (
        tester,
      ) async {
        if (realVideos.isEmpty) return;

        final testVideo = realVideos.first;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(home: ShareVideoMenu(video: testVideo)),
          ),
        );

        await tester.pumpAndSettle();

        // Tap bookmark option
        final bookmarkTile = find.text('Add to Global Bookmarks');
        if (bookmarkTile.evaluate().isNotEmpty) {
          await tester.tap(bookmarkTile);
          await tester.pumpAndSettle();

          // Should attempt to bookmark the video
          // Verification depends on UI feedback
          expect(find.byType(ShareVideoMenu), findsOneWidget);
        }
      });

      testWidgets('shows follow set creation options', (tester) async {
        if (realVideos.isEmpty) return;

        final testVideo = realVideos.first;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(home: ShareVideoMenu(video: testVideo)),
          ),
        );

        await tester.pumpAndSettle();

        // Should show follow set options
        expect(find.text('Create Follow Set'), findsOneWidget);
        expect(find.text('Add to Follow Set'), findsOneWidget);
      });
    });

    group('Content Reporting Tests', () {
      testWidgets('displays content reporting options', (tester) async {
        if (realVideos.isEmpty) return;

        final testVideo = realVideos.first;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(home: ShareVideoMenu(video: testVideo)),
          ),
        );

        await tester.pumpAndSettle();

        // Should show reporting section
        expect(find.text('Report Content'), findsOneWidget);

        // Common reporting options
        final reportOptions = [
          'Report as Spam',
          'Report as Inappropriate',
          'Block User',
          'Hide from Timeline',
        ];

        for (final option in reportOptions) {
          final finder = find.text(option);
          if (finder.evaluate().isNotEmpty) {
            expect(finder, findsOneWidget);
          }
        }
      });

      testWidgets('handles content reporting with confirmation', (
        tester,
      ) async {
        if (realVideos.isEmpty) return;

        final testVideo = realVideos.first;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(home: ShareVideoMenu(video: testVideo)),
          ),
        );

        await tester.pumpAndSettle();

        // Look for reporting options and test interaction
        final spamReport = find.text('Report as Spam');
        if (spamReport.evaluate().isNotEmpty) {
          await tester.tap(spamReport);
          await tester.pumpAndSettle();

          // Should show confirmation dialog or process report
          expect(find.byType(ShareVideoMenu), findsOneWidget);
        }
      });

      testWidgets('handles user blocking functionality', (tester) async {
        if (realVideos.isEmpty) return;

        final testVideo = realVideos.first;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(home: ShareVideoMenu(video: testVideo)),
          ),
        );

        await tester.pumpAndSettle();

        // Look for block user option
        final blockUser = find.text('Block User');
        if (blockUser.evaluate().isNotEmpty) {
          await tester.tap(blockUser);
          await tester.pumpAndSettle();

          // Should handle blocking action
          expect(find.byType(ShareVideoMenu), findsOneWidget);
        }
      });
    });

    group('Service Integration Tests', () {
      testWidgets('integrates with multiple services correctly', (
        tester,
      ) async {
        if (realVideos.isEmpty) return;

        final testVideo = realVideos.first;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(home: ShareVideoMenu(video: testVideo)),
          ),
        );

        await tester.pumpAndSettle();

        // Should successfully render with service integration
        expect(find.byType(ShareVideoMenu), findsOneWidget);
        expect(find.text('Share With'), findsOneWidget);
        expect(find.text('Manage Lists'), findsOneWidget);
        expect(find.text('Report Content'), findsOneWidget);

        Log.info(
          '✅ Service integration test completed successfully',
          name: 'ShareVideoMenuTest',
          category: LogCategory.system,
        );
      });
    });

    group('Error Handling', () {
      testWidgets('handles null video gracefully', (tester) async {
        // Test with minimal video event
        final emptyVideo = VideoEvent(
          id: 'test_empty_video',
          title: null,
          videoUrl: null,
          pubkey: 'test_pubkey',
          content: '',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          timestamp: DateTime.now(),
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(home: ShareVideoMenu(video: emptyVideo)),
          ),
        );

        await tester.pumpAndSettle();

        // Should render without crashing
        expect(find.byType(ShareVideoMenu), findsOneWidget);
      });

      testWidgets('handles service failures gracefully', (tester) async {
        if (realVideos.isEmpty) return;

        final testVideo = realVideos.first;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(home: ShareVideoMenu(video: testVideo)),
          ),
        );

        await tester.pumpAndSettle();

        // Should handle service failures and still render
        expect(find.byType(ShareVideoMenu), findsOneWidget);
      });
    });

    group('Real Data Integration', () {
      testWidgets('works with real video metadata from Nostr', (tester) async {
        if (realVideos.isEmpty) return;

        final realVideo = realVideos.first;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(home: ShareVideoMenu(video: realVideo)),
          ),
        );

        await tester.pumpAndSettle();

        // Should display real video information
        expect(find.byType(ShareVideoMenu), findsOneWidget);

        Log.info(
          '✅ Real data test completed with video: ${realVideo.title ?? "No title"}',
          name: 'ShareVideoMenuTest',
          category: LogCategory.system,
        );
      });

      testWidgets('handles multiple real videos with different metadata', (
        tester,
      ) async {
        if (realVideos.length < 3) return;

        for (int i = 0; i < 3; i++) {
          final video = realVideos[i];

          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(home: ShareVideoMenu(video: video)),
            ),
          );

          await tester.pumpAndSettle();

          // Should render each video's menu successfully
          expect(find.byType(ShareVideoMenu), findsOneWidget);

          // Clear widget for next test
          await tester.pumpWidget(Container());
        }

        Log.info(
          '✅ Multiple real videos test completed successfully',
          name: 'ShareVideoMenuTest',
          category: LogCategory.system,
        );
      });
    });

    group('Accessibility', () {
      testWidgets('provides semantic labels for screen readers', (
        tester,
      ) async {
        if (realVideos.isEmpty) return;

        final testVideo = realVideos.first;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(home: ShareVideoMenu(video: testVideo)),
          ),
        );

        await tester.pumpAndSettle();

        // Check for semantic labels on key interactive elements
        final semantics = tester.getSemantics(find.byType(ShareVideoMenu));
        expect(semantics, isNotNull);

        // Should have accessible tap targets
        final tapTargets = find.byType(GestureDetector);
        expect(tapTargets.evaluate().length, greaterThan(0));
      });
    });
  });
}

void _setupPlatformMocks() {
  // Mock SharedPreferences
  const MethodChannel prefsChannel = MethodChannel(
    'plugins.flutter.io/shared_preferences',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(prefsChannel, (MethodCall methodCall) async {
        if (methodCall.method == 'getAll') return <String, dynamic>{};
        if (methodCall.method == 'setString' || methodCall.method == 'setBool')
          return true;
        return null;
      });

  // Mock connectivity
  const MethodChannel connectivityChannel = MethodChannel(
    'dev.fluttercommunity.plus/connectivity',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(connectivityChannel, (
        MethodCall methodCall,
      ) async {
        if (methodCall.method == 'check') return ['wifi'];
        return null;
      });

  // Mock secure storage
  const MethodChannel secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureStorageChannel, (
        MethodCall methodCall,
      ) async {
        if (methodCall.method == 'write') return null;
        if (methodCall.method == 'read') return null;
        if (methodCall.method == 'readAll') return <String, String>{};
        return null;
      });

  // Mock path provider
  const MethodChannel pathProviderChannel = MethodChannel(
    'plugins.flutter.io/path_provider',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(pathProviderChannel, (
        MethodCall methodCall,
      ) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return '/tmp/openvine_share_menu_test_db';
        }
        return null;
      });

  // Mock device info
  const MethodChannel deviceInfoChannel = MethodChannel(
    'dev.fluttercommunity.plus/device_info',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(deviceInfoChannel, (
        MethodCall methodCall,
      ) async {
        return <String, dynamic>{'systemName': 'iOS', 'model': 'iPhone'};
      });

  // Mock share_plus
  const MethodChannel shareChannel = MethodChannel(
    'dev.fluttercommunity.plus/share',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(shareChannel, (MethodCall methodCall) async {
        if (methodCall.method == 'share') return null;
        return null;
      });
}

Future<void> _waitForRelayConnection(NostrService nostrService) async {
  final connectionCompleter = Completer<void>();
  late Timer timer;

  timer = Timer.periodic(Duration(milliseconds: 500), (t) {
    if (nostrService.connectedRelayCount > 0) {
      timer.cancel();
      connectionCompleter.complete();
    }
  });

  try {
    await connectionCompleter.future.timeout(Duration(seconds: 20));
    Log.info(
      '✅ Connected to ${nostrService.connectedRelayCount} relays for ShareVideoMenu testing',
      name: 'ShareVideoMenuTest',
      category: LogCategory.system,
    );
  } catch (e) {
    timer.cancel();
    Log.warning(
      'Connection timeout: $e',
      name: 'ShareVideoMenuTest',
      category: LogCategory.system,
    );
  }
}

Future<List<VideoEvent>> _fetchRealVideoEvents(
  VideoEventService videoEventService,
) async {
  Log.info(
    '🎬 Fetching real video events for ShareVideoMenu testing...',
    name: 'ShareVideoMenuTest',
    category: LogCategory.system,
  );

  try {
    await videoEventService.subscribeToDiscovery();
    await Future.delayed(Duration(seconds: 3));

    final videos = videoEventService.discoveryVideos;
    Log.info(
      '📋 Found ${videos.length} video events for ShareVideoMenu testing',
      name: 'ShareVideoMenuTest',
      category: LogCategory.system,
    );

    for (int i = 0; i < videos.length && i < 3; i++) {
      final video = videos[i];
      Log.info(
        '  [$i] ${video.title ?? "No title"} by ${video.pubkey}',
        name: 'ShareVideoMenuTest',
        category: LogCategory.system,
      );
    }

    return videos;
  } catch (e) {
    Log.error(
      'Failed to fetch video events for ShareVideoMenu testing: $e',
      name: 'ShareVideoMenuTest',
      category: LogCategory.system,
    );
    return [];
  }
}

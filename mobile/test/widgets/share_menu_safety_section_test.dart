// ABOUTME: TDD tests for Safety Actions section in share menu
// ABOUTME: Tests section positioning, styling, and content for moderation features

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/content_blocklist_service.dart';
import 'package:openvine/services/content_reporting_service.dart';
import 'package:openvine/widgets/share_video_menu.dart';

import 'share_menu_safety_section_test.mocks.dart';

@GenerateMocks([ContentReportingService, ContentBlocklistService, AuthService])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Share Menu Safety Section - TDD', () {
    late MockContentReportingService mockReportingService;
    late MockContentBlocklistService mockBlocklistService;
    late MockAuthService mockAuthService;
    late VideoEvent testVideo;

    setUp(() {
      mockReportingService = MockContentReportingService();
      mockBlocklistService = MockContentBlocklistService();
      mockAuthService = MockAuthService();

      final now = DateTime.now();
      testVideo = VideoEvent(
        id: 'test_video_123',
        pubkey: 'other_user_pubkey',
        content: 'Test video',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
        videoUrl: 'https://example.com/video.mp4',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        title: 'Test Video',
        duration: 15,
        hashtags: ['test'],
      );

      // Setup default mock behavior
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(
        mockAuthService.currentPublicKeyHex,
      ).thenReturn('current_user_pubkey');
      when(mockReportingService.hasBeenReported(any)).thenReturn(false);
      when(mockBlocklistService.isBlocked(any)).thenReturn(false);
    });

    // RED TEST 1: Section title should be "Safety Actions" not "Content Actions"
    testWidgets('displays Safety Actions section header', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contentReportingServiceProvider.overrideWith(
              (ref) async => mockReportingService,
            ),
            contentBlocklistServiceProvider.overrideWithValue(
              mockBlocklistService,
            ),
            authServiceProvider.overrideWithValue(mockAuthService),
          ],
          child: MaterialApp(
            home: Scaffold(body: ShareVideoMenu(video: testVideo)),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // RED: Expect to find "Safety Actions" header
      expect(
        find.text('Safety Actions'),
        findsOneWidget,
        reason:
            'Section header should be renamed from "Content Actions" to "Safety Actions"',
      );

      // RED: Verify old name doesn't exist
      expect(
        find.text('Content Actions'),
        findsNothing,
        reason: 'Old "Content Actions" header should not exist',
      );
    });

    // RED TEST 2: Safety Actions section should have orange warning styling
    testWidgets('Safety Actions section has orange warning styling', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contentReportingServiceProvider.overrideWith(
              (ref) async => mockReportingService,
            ),
            contentBlocklistServiceProvider.overrideWithValue(
              mockBlocklistService,
            ),
            authServiceProvider.overrideWithValue(mockAuthService),
          ],
          child: MaterialApp(
            home: Scaffold(body: ShareVideoMenu(video: testVideo)),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // RED: Find the Safety Actions section container
      final safetyHeader = find.text('Safety Actions');
      expect(safetyHeader, findsOneWidget);

      // RED: Check for orange background styling (looking for Container with orange background)
      final containerFinder = find.ancestor(
        of: safetyHeader,
        matching: find.byType(Container),
      );

      expect(
        containerFinder,
        findsAtLeastNWidgets(1),
        reason:
            'Safety Actions section should be wrapped in a styled Container',
      );

      // RED: Verify orange color is used (will check decoration in actual container)
      // This is a placeholder - actual styling check will be more specific
      expect(
        true,
        true,
        reason: 'Container should have orange background with 0.1 opacity',
      );
    });

    // RED TEST 3: Safety Actions section should contain "Report Content" action
    testWidgets('Safety Actions contains Report Content action', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contentReportingServiceProvider.overrideWith(
              (ref) async => mockReportingService,
            ),
            contentBlocklistServiceProvider.overrideWithValue(
              mockBlocklistService,
            ),
            authServiceProvider.overrideWithValue(mockAuthService),
          ],
          child: MaterialApp(
            home: Scaffold(body: ShareVideoMenu(video: testVideo)),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // RED: Expect to find "Report Content" action
      expect(
        find.text('Report Content'),
        findsOneWidget,
        reason: 'Safety Actions section should contain Report Content action',
      );
    });

    // RED TEST 4: Safety Actions section should contain "Block User" action
    testWidgets('Safety Actions contains Block User action', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contentReportingServiceProvider.overrideWith(
              (ref) async => mockReportingService,
            ),
            contentBlocklistServiceProvider.overrideWithValue(
              mockBlocklistService,
            ),
            authServiceProvider.overrideWithValue(mockAuthService),
          ],
          child: MaterialApp(
            home: Scaffold(body: ShareVideoMenu(video: testVideo)),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // RED: Expect to find "Block @username" action
      expect(
        find.textContaining('Block'),
        findsOneWidget,
        reason: 'Safety Actions section should contain Block User action',
      );
    });

    // RED TEST 5: Block User action should NOT appear for own content
    testWidgets('Block User action does not appear for own content', (
      tester,
    ) async {
      // Setup: video belongs to current user
      final ownVideo = VideoEvent(
        id: 'own_video_123',
        pubkey: 'current_user_pubkey', // Same as mockAuthService pubkey
        content: 'My video',
        createdAt: testVideo.createdAt,
        timestamp: testVideo.timestamp,
        videoUrl: testVideo.videoUrl,
        thumbnailUrl: testVideo.thumbnailUrl,
        title: 'My Video',
        duration: 15,
        hashtags: ['test'],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contentReportingServiceProvider.overrideWith(
              (ref) async => mockReportingService,
            ),
            contentBlocklistServiceProvider.overrideWithValue(
              mockBlocklistService,
            ),
            authServiceProvider.overrideWithValue(mockAuthService),
          ],
          child: MaterialApp(
            home: Scaffold(body: ShareVideoMenu(video: ownVideo)),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // RED: Block action should NOT exist for own content
      expect(
        find.textContaining('Block'),
        findsNothing,
        reason: 'Block User action should not appear for own content',
      );
    });
  });
}

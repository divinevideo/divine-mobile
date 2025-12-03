// ABOUTME: Integration test for content reporting flow from share menu
// ABOUTME: Tests complete user journey from video to report dialog to service storage

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nostr_sdk/event.dart' as nostr;
import 'package:models/models.dart';
import 'package:openvine/widgets/share_video_menu.dart';
import 'package:openvine/services/content_moderation_service.dart';
import 'package:openvine/providers/app_providers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Content Reporting Flow Integration Tests', () {
    testWidgets('Complete reporting flow from share menu works end-to-end', (
      tester,
    ) async {
      // Create test Nostr event (kind 34236 - addressable short video)
      final testNostrEvent = nostr.Event(
        'test_author_pubkey_67890',
        34236, // Kind 34236 - addressable short looping video
        [
          ['d', 'test_vine_id_123'],
          ['title', 'Test Reporting Video'],
          ['imeta', 'url https://example.com/test.mp4', 'm video/mp4'],
        ],
        'This is a test video for reporting',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      // Sign the event (set id and sig)
      testNostrEvent.id = 'test_video_event_12345';
      testNostrEvent.sig = 'test_signature';

      // Create VideoEvent from Nostr event
      final testVideo = VideoEvent.fromNostrEvent(testNostrEvent);

      // Setup app with ProviderScope
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ShareVideoMenu(
                video: testVideo,
                key: const Key('share_video_menu_test'),
              ),
            ),
          ),
        ),
      );

      // Wait for share menu to build
      await tester.pumpAndSettle();

      // Verify share menu is displayed
      expect(find.text('Share Video'), findsOneWidget);

      // Scroll down to find the Safety Actions section and Report Content button
      await tester.dragUntilVisible(
        find.text('Safety Actions'),
        find.byType(ShareVideoMenu),
        const Offset(0, -100),
      );
      await tester.pumpAndSettle();

      // Verify Safety Actions section is visible
      expect(find.text('Safety Actions'), findsOneWidget);

      // Find and tap the "Report Content" action
      final reportContentFinder = find.text('Report Content');
      expect(reportContentFinder, findsOneWidget);

      await tester.tap(reportContentFinder);
      await tester.pumpAndSettle();

      // Verify report dialog appears
      expect(find.text('Report Content'), findsWidgets); // Title in dialog
      expect(find.text('Why are you reporting this content?'), findsOneWidget);

      // Select a report reason (Spam)
      final spamReasonFinder = find.text('Spam or Unwanted Content');
      expect(spamReasonFinder, findsOneWidget);
      await tester.tap(spamReasonFinder);
      await tester.pumpAndSettle();

      // Add optional details text
      final detailsFieldFinder = find.widgetWithText(
        TextField,
        'Additional details (optional)',
      );
      expect(detailsFieldFinder, findsOneWidget);
      await tester.enterText(
        detailsFieldFinder,
        'This video is clearly spam content',
      );
      await tester.pumpAndSettle();

      // Submit the report
      final reportButtonFinder = find.widgetWithText(TextButton, 'Report').last;
      expect(reportButtonFinder, findsOneWidget);
      await tester.tap(reportButtonFinder);
      await tester.pumpAndSettle();

      // Verify report was submitted (dialog closes, success message appears)
      expect(find.text('Report Content'), findsNothing); // Dialog closed
      expect(find.text('Content reported successfully'), findsOneWidget);

      // Get the container to access services
      final context = tester.element(
        find.byKey(const Key('share_video_menu_test')),
      );
      final container = ProviderScope.containerOf(context);

      // Verify report is stored in ContentReportingService
      final reportServiceAsync = await container.read(
        contentReportingServiceProvider.future,
      );
      expect(reportServiceAsync.hasBeenReported(testVideo.id), isTrue);

      // Verify report details are correct
      final reports = reportServiceAsync.getReportsForEvent(testVideo.id);
      expect(reports.length, equals(1));
      expect(reports.first.reason, equals(ContentFilterReason.spam));
      expect(reports.first.details, contains('This video is clearly spam'));
      expect(reports.first.eventId, equals(testVideo.id));
      expect(reports.first.authorPubkey, equals(testVideo.pubkey));

      // Reopen share menu and verify "Already Reported" status
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ShareVideoMenu(
                video: testVideo,
                key: const Key('share_video_menu_reopen'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to Safety Actions
      await tester.dragUntilVisible(
        find.text('Safety Actions'),
        find.byKey(const Key('share_video_menu_reopen')),
        const Offset(0, -100),
      );
      await tester.pumpAndSettle();

      // Verify "Already Reported" status is shown
      expect(find.text('Already Reported'), findsOneWidget);
      expect(find.text('You have reported this content'), findsOneWidget);

      // Verify report button is disabled (onTap is null)
      final alreadyReportedTile = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('Already Reported'),
          matching: find.byType(ListTile),
        ),
      );
      expect(alreadyReportedTile.onTap, isNull);
    });

    testWidgets('Quick AI report flow works end-to-end', (tester) async {
      // Create test Nostr event for AI-generated video (no original content marker)
      final testAiNostrEvent = nostr.Event(
        'different_author_pubkey_11111',
        34236, // Kind 34236 - addressable short looping video
        [
          ['d', 'test_ai_vine_id_456'],
          ['title', 'AI Test Video'],
          ['imeta', 'url https://example.com/ai-test.mp4', 'm video/mp4'],
          // No original content marker - appears AI-generated
        ],
        'Potentially AI-generated video',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      // Sign the event
      testAiNostrEvent.id = 'test_ai_video_98765';
      testAiNostrEvent.sig = 'test_signature_ai';

      // Create VideoEvent from Nostr event
      final testVideo = VideoEvent.fromNostrEvent(testAiNostrEvent);

      // Setup app with ProviderScope
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ShareVideoMenu(
                video: testVideo,
                key: const Key('share_video_menu_ai_test'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Scroll to find the "Report AI Content" quick button
      await tester.dragUntilVisible(
        find.text('Report AI Content'),
        find.byType(ShareVideoMenu),
        const Offset(0, -100),
      );
      await tester.pumpAndSettle();

      // Verify quick AI report button is visible
      expect(find.text('Report AI Content'), findsOneWidget);
      expect(
        find.text('Quick report suspected AI-generated content'),
        findsOneWidget,
      );

      // Tap quick report button
      await tester.tap(find.text('Report AI Content'));
      await tester.pumpAndSettle();

      // Wait for loading snackbar to appear and disappear
      await tester.pump(const Duration(milliseconds: 100));

      // Wait for success message
      await tester.pumpAndSettle();

      // Verify success message appears
      expect(find.text('AI content reported successfully'), findsOneWidget);

      // Get the container to access services
      final context = tester.element(
        find.byKey(const Key('share_video_menu_ai_test')),
      );
      final container = ProviderScope.containerOf(context);

      // Verify report is stored with AI-generated reason
      final reportServiceAsync = await container.read(
        contentReportingServiceProvider.future,
      );
      expect(reportServiceAsync.hasBeenReported(testVideo.id), isTrue);

      final reports = reportServiceAsync.getReportsForEvent(testVideo.id);
      expect(reports.length, equals(1));
      expect(reports.first.reason, equals(ContentFilterReason.aiGenerated));
      expect(reports.first.details, equals('Suspected AI-generated content'));
    });
  });
}

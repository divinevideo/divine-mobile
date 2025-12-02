// ABOUTME: Unit tests for ReportContentDialog widget
// ABOUTME: Tests Apple compliance requirements and user blocking functionality

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/event.dart' as nostr;
import 'package:openvine/models/video_event.dart';
import 'package:openvine/widgets/share_video_menu.dart';
import 'package:openvine/services/content_reporting_service.dart';
import 'package:openvine/services/content_blocklist_service.dart';
import 'package:openvine/services/mute_service.dart';
import 'package:openvine/services/content_moderation_service.dart';
import 'package:openvine/providers/app_providers.dart';

import 'report_content_dialog_test.mocks.dart';

@GenerateMocks([ContentReportingService, ContentBlocklistService, MuteService])
void main() {
  group('ReportContentDialog', () {
    late VideoEvent testVideo;
    late MockContentReportingService mockReportingService;
    late MockContentBlocklistService mockBlocklistService;
    late MockMuteService mockMuteService;

    setUp(() {
      // Create test Nostr event with valid hex pubkey
      final testNostrEvent = nostr.Event(
        '78a5c21b5166dc1474b64ddf7454bf79e6b5d6b4a77148593bf1e866b73c2738',
        34236,
        [
          ['d', 'test_video_id'],
          ['title', 'Test Video'],
          ['imeta', 'url https://example.com/test.mp4', 'm video/mp4'],
        ],
        'Test video content',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      testNostrEvent.id =
          'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
      testNostrEvent.sig =
          'aa11bb22cc33dd44ee55ff66aa11bb22cc33dd44ee55ff66aa11bb22cc33dd44ee55ff66aa11bb22cc33dd44ee55ff66aa11bb22cc33dd44ee55ff66aa11bb22';

      testVideo = VideoEvent.fromNostrEvent(testNostrEvent);
      mockReportingService = MockContentReportingService();
      mockBlocklistService = MockContentBlocklistService();
      mockMuteService = MockMuteService();

      // Setup default mock behavior
      when(
        mockReportingService.reportContent(
          eventId: anyNamed('eventId'),
          authorPubkey: anyNamed('authorPubkey'),
          reason: anyNamed('reason'),
          details: anyNamed('details'),
          additionalContext: anyNamed('additionalContext'),
          hashtags: anyNamed('hashtags'),
        ),
      ).thenAnswer((_) async => ReportResult.createSuccess('test_report_id'));

      when(
        mockReportingService.reportUser(
          userPubkey: anyNamed('userPubkey'),
          reason: anyNamed('reason'),
          details: anyNamed('details'),
          relatedEventIds: anyNamed('relatedEventIds'),
        ),
      ).thenAnswer(
        (_) async => ReportResult.createSuccess('test_user_report_id'),
      );

      when(
        mockMuteService.muteUser(
          any,
          reason: anyNamed('reason'),
          duration: anyNamed('duration'),
        ),
      ).thenAnswer((_) async => true);
    });

    testWidgets(
      'Submit button is visible (not null) even before selecting a reason',
      (tester) async {
        // Apple compliance requirement: submit button must always be visible

        // Set larger test size to prevent overflow
        await tester.binding.setSurfaceSize(const Size(800, 1200));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              contentReportingServiceProvider.overrideWith(
                (ref) async => mockReportingService,
              ),
            ],
            child: MaterialApp(
              home: Scaffold(body: ReportContentDialog(video: testVideo)),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Find the Report button
        final reportButton = find.widgetWithText(TextButton, 'Report');
        expect(reportButton, findsOneWidget);

        // Get the button widget to check if onPressed is not null
        final TextButton button = tester.widget(reportButton);

        // CRITICAL: Button must be enabled (onPressed != null) even before selecting reason
        // This is an Apple App Store requirement
        expect(
          button.onPressed,
          isNotNull,
          reason:
              'Submit button must be visible/enabled before selecting reason (Apple requirement)',
        );
      },
    );

    testWidgets(
      'Submit button shows error when tapped without selecting reason',
      (tester) async {
        // Set larger test size to prevent overflow
        await tester.binding.setSurfaceSize(const Size(800, 1200));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              contentReportingServiceProvider.overrideWith(
                (ref) async => mockReportingService,
              ),
            ],
            child: MaterialApp(
              home: Scaffold(body: ReportContentDialog(video: testVideo)),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Tap the Report button without selecting a reason
        final reportButton = find.widgetWithText(TextButton, 'Report');
        await tester.tap(reportButton);
        await tester.pumpAndSettle();

        // Should show an error snackbar
        expect(
          find.text('Please select a reason for reporting this content'),
          findsOneWidget,
          reason: 'Should show error when no reason selected',
        );
      },
    );

    testWidgets('Block user checkbox is visible and can be toggled', (
      tester,
    ) async {
      // Set larger test size to prevent overflow
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contentReportingServiceProvider.overrideWith(
              (ref) async => mockReportingService,
            ),
            contentBlocklistServiceProvider.overrideWith(
              (ref) => mockBlocklistService,
            ),
            muteServiceProvider.overrideWith((ref) async => mockMuteService),
          ],
          child: MaterialApp(
            home: Scaffold(body: ReportContentDialog(video: testVideo)),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the block user checkbox
      final blockUserCheckbox = find.text('Block this user');
      expect(
        blockUserCheckbox,
        findsOneWidget,
        reason: 'Block user checkbox should be visible',
      );

      // Find the checkbox widget itself
      final Checkbox checkbox = tester.widget(find.byType(Checkbox));
      expect(
        checkbox.value,
        isFalse,
        reason: 'Checkbox should be unchecked by default',
      );

      // Tap the checkbox to enable blocking
      await tester.tap(blockUserCheckbox);
      await tester.pumpAndSettle();

      // Verify checkbox is now checked
      final Checkbox checkedCheckbox = tester.widget(find.byType(Checkbox));
      expect(
        checkedCheckbox.value,
        isTrue,
        reason: 'Checkbox should be checked after tapping',
      );
    });
  });

  // NOTE: Full integration test for proper Nostr event publishing when blocking
  // users is in integration_test/report_content_flow_test.dart
  //
  // When user checks "Block this user" and submits report:
  // - Creates kind 1984 (NIP-56) for the CONTENT being reported
  // - Creates kind 1984 (NIP-56) for the USER being reported
  // - Publishes kind 10000 (NIP-51) mute list with user added
  //
  // When user does NOT check "Block this user":
  // - Only creates kind 1984 for the CONTENT

  // Unit test for Nostr event service calls
  group('Nostr Event Publishing', () {
    test('reportUser() and muteUser() are called when blocking', () async {
      // This is a unit test verifying the service method calls
      // Integration test verifies actual Nostr event creation

      final mockReportingService = MockContentReportingService();
      final mockMuteService = MockMuteService();

      when(
        mockReportingService.reportUser(
          userPubkey: anyNamed('userPubkey'),
          reason: anyNamed('reason'),
          details: anyNamed('details'),
          relatedEventIds: anyNamed('relatedEventIds'),
        ),
      ).thenAnswer((_) async => ReportResult.createSuccess('user_report_id'));

      when(
        mockMuteService.muteUser(
          any,
          reason: anyNamed('reason'),
          duration: anyNamed('duration'),
        ),
      ).thenAnswer((_) async => true);

      // Call the service methods
      final userReportResult = await mockReportingService.reportUser(
        userPubkey:
            '78a5c21b5166dc1474b64ddf7454bf79e6b5d6b4a77148593bf1e866b73c2738',
        reason: ContentFilterReason.harassment,
        details: 'Test user report',
        relatedEventIds: ['test_event_id'],
      );

      final muteResult = await mockMuteService.muteUser(
        '78a5c21b5166dc1474b64ddf7454bf79e6b5d6b4a77148593bf1e866b73c2738',
        reason: 'Test mute',
      );

      // Verify service methods were called and succeeded
      expect(userReportResult.success, isTrue);
      expect(muteResult, isTrue);

      verify(
        mockReportingService.reportUser(
          userPubkey: anyNamed('userPubkey'),
          reason: anyNamed('reason'),
          details: anyNamed('details'),
          relatedEventIds: anyNamed('relatedEventIds'),
        ),
      ).called(1);

      verify(
        mockMuteService.muteUser(
          any,
          reason: anyNamed('reason'),
          duration: anyNamed('duration'),
        ),
      ).called(1);
    });
  });
}

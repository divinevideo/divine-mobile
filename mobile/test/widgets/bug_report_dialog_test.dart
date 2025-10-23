// ABOUTME: Widget tests for BugReportDialog user interface
// ABOUTME: Tests UI rendering, user interaction, and submission flow

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/models/bug_report_data.dart';
import 'package:openvine/models/bug_report_result.dart';
import 'package:openvine/services/bug_report_service.dart';
import 'package:openvine/widgets/bug_report_dialog.dart';

import 'bug_report_dialog_test.mocks.dart';
import '../helpers/test_provider_overrides.dart';

@GenerateMocks([BugReportService])
void main() {
  group('BugReportDialog', () {
    late MockBugReportService mockBugReportService;

    setUp(() {
      mockBugReportService = MockBugReportService();
    });

    testWidgets('should display title and description field', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BugReportDialog(bugReportService: mockBugReportService),
          ),
        ),
      );

      // Verify title
      expect(find.text('Report a Bug'), findsOneWidget);

      // Verify description field
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Describe the issue (optional)...'), findsOneWidget);
    });

    testWidgets('should have Send and Cancel buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BugReportDialog(bugReportService: mockBugReportService),
          ),
        ),
      );

      expect(find.text('Send Report'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('should allow Send button even when description is empty',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BugReportDialog(bugReportService: mockBugReportService),
          ),
        ),
      );

      final sendButton = find.text('Send Report');
      expect(sendButton, findsOneWidget);

      // Button should be enabled even when empty (diagnostic info is more important)
      final button = tester.widget<ElevatedButton>(
        find.ancestor(
          of: sendButton,
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('should enable Send button when description is not empty',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BugReportDialog(bugReportService: mockBugReportService),
          ),
        ),
      );

      // Enter text in description field
      await tester.enterText(find.byType(TextField), 'App crashed on startup');
      await tester.pump();

      final sendButton = find.text('Send Report');
      final button = tester.widget<ElevatedButton>(
        find.ancestor(
          of: sendButton,
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('should call collectDiagnostics and sendBugReport on submit',
        (tester) async {
      // Setup mocks
      final testReportData = BugReportData(
        reportId: 'test-123',
        timestamp: DateTime.now(),
        userDescription: 'App crashed on startup',
        deviceInfo: {},
        appVersion: '1.0.0',
        recentLogs: [],
        errorCounts: {},
      );

      when(mockBugReportService.collectDiagnostics(
        userDescription: anyNamed('userDescription'),
        currentScreen: anyNamed('currentScreen'),
        userPubkey: anyNamed('userPubkey'),
        additionalContext: anyNamed('additionalContext'),
      )).thenAnswer((_) async => testReportData);

      when(mockBugReportService.sendBugReportViaEmail(any)).thenAnswer(
        (_) async => BugReportResult(
          success: true,
          reportId: 'test-123',
          timestamp: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BugReportDialog(bugReportService: mockBugReportService),
          ),
        ),
      );

      // Enter bug description
      await tester.enterText(find.byType(TextField), 'App crashed on startup');
      await tester.pump();

      // Tap Send button
      await tester.tap(find.text('Send Report'));
      await tester.pump();

      // Verify service methods were called
      verify(mockBugReportService.collectDiagnostics(
        userDescription: 'App crashed on startup',
        currentScreen: anyNamed('currentScreen'),
        userPubkey: anyNamed('userPubkey'),
        additionalContext: anyNamed('additionalContext'),
      )).called(1);

      verify(mockBugReportService.sendBugReportViaEmail(any)).called(1);
    });

    testWidgets('should show loading indicator while submitting',
        (tester) async {
      // Setup mock with delay
      when(mockBugReportService.collectDiagnostics(
        userDescription: anyNamed('userDescription'),
        currentScreen: anyNamed('currentScreen'),
        userPubkey: anyNamed('userPubkey'),
        additionalContext: anyNamed('additionalContext'),
      )).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return BugReportData(
          reportId: 'test-123',
          timestamp: DateTime.now(),
          userDescription: 'Test',
          deviceInfo: {},
          appVersion: '1.0.0',
          recentLogs: [],
          errorCounts: {},
        );
      });

      when(mockBugReportService.sendBugReportViaEmail(any)).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return BugReportResult.createSuccess(
          reportId: 'test-123',
          messageEventId: 'test-event-id',
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BugReportDialog(bugReportService: mockBugReportService),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Test bug');
      await tester.pump();
      await tester.tap(find.text('Send Report'));
      await tester.pump();

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Wait for async operations to complete and timer to fire
      await tester.pumpAndSettle();
    });

    testWidgets('should show success message on successful submission',
        (tester) async {
      when(mockBugReportService.collectDiagnostics(
        userDescription: anyNamed('userDescription'),
        currentScreen: anyNamed('currentScreen'),
        userPubkey: anyNamed('userPubkey'),
        additionalContext: anyNamed('additionalContext'),
      )).thenAnswer((_) async => BugReportData(
            reportId: 'test-123',
            timestamp: DateTime.now(),
            userDescription: 'Test',
            deviceInfo: {},
            appVersion: '1.0.0',
            recentLogs: [],
            errorCounts: {},
          ));

      when(mockBugReportService.sendBugReportViaEmail(any)).thenAnswer(
        (_) async => BugReportResult(
          success: true,
          reportId: 'test-123',
          timestamp: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BugReportDialog(bugReportService: mockBugReportService),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Test bug');
      await tester.pump();
      await tester.tap(find.text('Send Report'));
      await tester.pumpAndSettle();

      // Should show success message with email instructions
      expect(find.textContaining('Opening email to contact@divine.video'), findsOneWidget);
    });

    testWidgets('should show error message on failed submission',
        (tester) async {
      when(mockBugReportService.collectDiagnostics(
        userDescription: anyNamed('userDescription'),
        currentScreen: anyNamed('currentScreen'),
        userPubkey: anyNamed('userPubkey'),
        additionalContext: anyNamed('additionalContext'),
      )).thenAnswer((_) async => BugReportData(
            reportId: 'test-123',
            timestamp: DateTime.now(),
            userDescription: 'Test',
            deviceInfo: {},
            appVersion: '1.0.0',
            recentLogs: [],
            errorCounts: {},
          ));

      when(mockBugReportService.sendBugReportViaEmail(any)).thenAnswer(
        (_) async => BugReportResult.failure(
          'Could not create file',
          reportId: 'test-123',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BugReportDialog(bugReportService: mockBugReportService),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Test bug');
      await tester.pump();
      await tester.tap(find.text('Send Report'));
      await tester.pumpAndSettle();

      // Should show error message
      expect(find.textContaining('Failed to create bug report'), findsOneWidget);
    });

    testWidgets('should close dialog on Cancel', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => BugReportDialog(
                      bugReportService: mockBugReportService,
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Report a Bug'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog should be closed
      expect(find.text('Report a Bug'), findsNothing);
    });
  });
}

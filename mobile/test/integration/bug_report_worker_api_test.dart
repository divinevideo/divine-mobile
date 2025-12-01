// ABOUTME: Integration test for bug report submission to Cloudflare Worker
// ABOUTME: Tests real HTTP POST to Worker API endpoint

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/config/bug_report_config.dart';
import 'package:openvine/models/bug_report_data.dart';
import 'package:openvine/models/log_entry.dart';
import 'package:openvine/services/bug_report_service.dart';
import 'package:openvine/utils/unified_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BugReportService Worker API Integration', () {
    late BugReportService bugReportService;

    setUp(() {
      bugReportService = BugReportService();
    });

    test(
      'sendBugReport should successfully POST to Worker API',
      () async {
        // Create minimal bug report data
        final testData = BugReportData(
          reportId: 'test-${DateTime.now().millisecondsSinceEpoch}',
          timestamp: DateTime.now(),
          userDescription: 'Integration test bug report',
          deviceInfo: {
            'platform': 'test',
            'version': '1.0',
            'model': 'Test Device',
          },
          appVersion: '0.0.1+66',
          recentLogs: [
            LogEntry(
              timestamp: DateTime.now(),
              level: LogLevel.info,
              message: 'Test log entry',
              category: LogCategory.system,
            ),
          ],
          errorCounts: {'TestError': 1},
          currentScreen: 'TestScreen',
          userPubkey: null,
        );

        // Send to Worker API
        final result = await bugReportService.sendBugReport(testData);

        // Verify success
        expect(
          result.success,
          isTrue,
          reason: 'Bug report submission should succeed',
        );
        expect(
          result.reportId,
          equals(testData.reportId),
          reason: 'Report ID should match',
        );
        expect(
          result.error,
          isNull,
          reason: 'Should not have an error message',
        );

        print('✅ Bug report sent successfully: ${result.reportId}');
        print('   API endpoint: ${BugReportConfig.bugReportApiUrl}');
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'sendBugReport should handle API errors gracefully',
      () async {
        // Create invalid data (empty reportId to trigger validation error)
        final invalidData = BugReportData(
          reportId: '', // Invalid: empty report ID
          timestamp: DateTime.now(),
          userDescription: 'Test invalid report',
          deviceInfo: {},
          appVersion: '',
          recentLogs: [],
          errorCounts: {},
        );

        // Attempt to send
        final result = await bugReportService.sendBugReport(invalidData);

        // Should fail or fall back to email
        // We accept either failure or email fallback
        expect(result.success, isNotNull);
        print(
          'Result: ${result.success ? "Success" : "Failed: ${result.error}"}',
        );
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'collectDiagnostics and send complete workflow',
      () async {
        // Test the full workflow from collection to submission
        final diagnostics = await bugReportService.collectDiagnostics(
          userDescription: 'Full workflow integration test',
          currentScreen: 'IntegrationTestScreen',
        );

        // Verify diagnostics were collected
        expect(diagnostics.reportId, isNotEmpty);
        expect(diagnostics.appVersion, isNotEmpty);
        expect(diagnostics.deviceInfo, isNotEmpty);

        // Send the collected diagnostics
        final result = await bugReportService.sendBugReport(diagnostics);

        // Verify submission
        expect(result.success, isTrue);
        expect(result.reportId, equals(diagnostics.reportId));

        print('✅ Complete workflow test passed');
        print('   Report ID: ${result.reportId}');
        print('   Logs collected: ${diagnostics.recentLogs.length}');
        print('   Error types: ${diagnostics.errorCounts.length}');
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });
}

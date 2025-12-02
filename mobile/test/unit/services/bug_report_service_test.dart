// ABOUTME: Unit tests for BugReportService diagnostic collection and sanitization
// ABOUTME: Tests data gathering, sensitive data removal, and report packaging

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/bug_report_service.dart';
import 'package:openvine/models/bug_report_data.dart';
import 'package:openvine/config/bug_report_config.dart';

void main() {
  group('BugReportService', () {
    late BugReportService service;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();

      // Mock package_info_plus
      const MethodChannel(
        'dev.fluttercommunity.plus/package_info',
      ).setMockMethodCallHandler((MethodCall methodCall) async {
        if (methodCall.method == 'getAll') {
          return <String, dynamic>{
            'appName': 'OpenVine',
            'packageName': 'com.openvine.mobile',
            'version': '0.0.1',
            'buildNumber': '35',
          };
        }
        return null;
      });

      // Mock Firebase Core
      const MethodChannel(
        'plugins.flutter.io/firebase_core',
      ).setMockMethodCallHandler((MethodCall methodCall) async {
        if (methodCall.method == 'Firebase#initializeCore') {
          return [
            {
              'name': '[DEFAULT]',
              'options': {
                'apiKey': 'test',
                'appId': 'test',
                'messagingSenderId': 'test',
                'projectId': 'test',
              },
              'pluginConstants': {},
            },
          ];
        }
        return null;
      });

      // Mock Firebase Analytics
      const MethodChannel(
        'plugins.flutter.io/firebase_analytics',
      ).setMockMethodCallHandler((MethodCall methodCall) async {
        return null; // Just return null for all analytics calls
      });

      service = BugReportService();
    });

    test('should collect diagnostics with all fields', () async {
      final data = await service.collectDiagnostics(
        userDescription: 'App crashed when loading feed',
      );

      expect(data.reportId, isNotEmpty);
      expect(data.userDescription, equals('App crashed when loading feed'));
      expect(data.deviceInfo, isNotEmpty);
      expect(data.appVersion, isNotEmpty);
      expect(data.recentLogs, isNotEmpty);
      expect(data.errorCounts, isA<Map<String, int>>());
      expect(data.timestamp, isA<DateTime>());
    });

    test('should sanitize nsec keys from description', () {
      final input = BugReportData(
        reportId: 'test-123',
        timestamp: DateTime.now(),
        userDescription:
            'My nsec is nsec1qqqsyrhq4p4d8hf40q7tlujzw87hqhz9axhfnm35s2a3u3rrnwsq9sp5p6',
        deviceInfo: {},
        appVersion: '1.0.0',
        recentLogs: [],
        errorCounts: {},
      );

      final sanitized = service.sanitizeSensitiveData(input);

      expect(sanitized.userDescription, isNot(contains('nsec1')));
      expect(sanitized.userDescription, contains('[REDACTED]'));
    });

    test('should preserve hex strings (event IDs and pubkeys) from logs', () {
      // Hex strings could be public event IDs or pubkeys, so they should NOT be redacted
      // Private keys should be in nsec format (which IS redacted)
      final input = BugReportData(
        reportId: 'test-123',
        timestamp: DateTime.now(),
        userDescription: 'Normal description',
        deviceInfo: {},
        appVersion: '1.0.0',
        recentLogs: [],
        errorCounts: {},
        additionalContext: {
          'eventId':
              '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          'pubkeyHex':
              'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210',
        },
      );

      final sanitized = service.sanitizeSensitiveData(input);

      // Hex event IDs and pubkeys should be preserved for debugging
      expect(
        sanitized.additionalContext.toString(),
        contains('0123456789abcdef'),
      );
      expect(
        sanitized.additionalContext.toString(),
        contains('fedcba9876543210'),
      );
    });

    test('should sanitize password patterns', () {
      final input = BugReportData(
        reportId: 'test-123',
        timestamp: DateTime.now(),
        userDescription: 'Error with password=mySecretPass123',
        deviceInfo: {},
        appVersion: '1.0.0',
        recentLogs: [],
        errorCounts: {},
      );

      final sanitized = service.sanitizeSensitiveData(input);

      expect(sanitized.userDescription, isNot(contains('mySecretPass123')));
      expect(sanitized.userDescription, contains('[REDACTED]'));
    });

    test('should sanitize token patterns', () {
      final input = BugReportData(
        reportId: 'test-123',
        timestamp: DateTime.now(),
        userDescription: 'Auth failed with token=abc123xyz',
        deviceInfo: {},
        appVersion: '1.0.0',
        recentLogs: [],
        errorCounts: {},
      );

      final sanitized = service.sanitizeSensitiveData(input);

      expect(sanitized.userDescription, isNot(contains('abc123xyz')));
      expect(sanitized.userDescription, contains('[REDACTED]'));
    });

    test('should sanitize Authorization header patterns', () {
      final input = BugReportData(
        reportId: 'test-123',
        timestamp: DateTime.now(),
        userDescription:
            'Request failed with Authorization: Bearer secret_token_here',
        deviceInfo: {},
        appVersion: '1.0.0',
        recentLogs: [],
        errorCounts: {},
      );

      final sanitized = service.sanitizeSensitiveData(input);

      expect(sanitized.userDescription, isNot(contains('secret_token_here')));
      expect(sanitized.userDescription, contains('[REDACTED]'));
    });

    test('should preserve pubkeys in sanitized data', () {
      const testPubkey =
          'npub1wmr34t36fy03m8hvgl96zl3znndyzyaqhwmwdtshwmtkg03fetaqhjg240';
      final input = BugReportData(
        reportId: 'test-123',
        timestamp: DateTime.now(),
        userDescription: 'User pubkey: $testPubkey',
        deviceInfo: {},
        appVersion: '1.0.0',
        recentLogs: [],
        errorCounts: {},
        userPubkey: testPubkey,
      );

      final sanitized = service.sanitizeSensitiveData(input);

      // Pubkeys should NOT be redacted
      expect(sanitized.userDescription, contains(testPubkey));
      expect(sanitized.userPubkey, equals(testPubkey));
    });

    test('should handle empty diagnostics gracefully', () async {
      final data = await service.collectDiagnostics(userDescription: '');

      expect(data.reportId, isNotEmpty);
      expect(
        data.deviceInfo,
        isNotEmpty,
      ); // Device info should still be collected
    });

    test('should validate report size', () {
      // Create a huge report
      final input = BugReportData(
        reportId: 'test-123',
        timestamp: DateTime.now(),
        userDescription: 'x' * 1000000, // 1MB description
        deviceInfo: {},
        appVersion: '1.0.0',
        recentLogs: [],
        errorCounts: {},
      );

      final sizeInBytes = service.estimateReportSize(input);

      expect(sizeInBytes, greaterThan(0));
    });

    test('should truncate logs if report exceeds size limit', () {
      // This will be implemented when we add size validation
      expect(BugReportConfig.maxReportSizeBytes, equals(1024 * 1024)); // 1MB
    });
  });
}

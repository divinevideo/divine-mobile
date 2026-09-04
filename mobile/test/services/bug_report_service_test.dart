// ABOUTME: Unit tests for BugReportService diagnostic collection and sanitization
// ABOUTME: Tests data gathering, sensitive data removal, and report packaging

import 'dart:io' show Platform;
import 'dart:ui' show Locale;

import 'package:analytics/analytics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show BugReportData, LogEntry, LogLevel;
import 'package:openvine/services/bug_report_service.dart';
import 'package:unified_logger/unified_logger.dart';

const _rawNsec =
    'nsec1qqqsyrhq4p4d8hf40q7tlujzw87hqhz9axhfnm35s2a3u3rrnwsq9sp5p6';
const _rawNcryptsec = 'ncryptsec1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq';

void main() {
  group('BugReportService', () {
    late BugReportService service;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();

      final binding = TestDefaultBinaryMessengerBinding.instance;

      // Mock package_info_plus
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/package_info'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'getAll') {
            return <String, dynamic>{
              'appName': 'OpenVine',
              'packageName': 'com.openvine.mobile',
              'version': '0.0.1',
              'buildNumber': '35',
            };
          }
          return null;
        },
      );

      // Mock Firebase Core
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/firebase_core'),
        (MethodCall methodCall) async {
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
        },
      );

      // Mock Firebase Analytics
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/firebase_analytics'),
        (MethodCall methodCall) async {
          return null; // Just return null for all analytics calls
        },
      );

      service = BugReportService();
    });

    test('should collect diagnostics with all fields', () async {
      final data = await service.collectDiagnostics(
        userDescription: 'App crashed when loading feed',
      );

      expect(data.reportId, isNotEmpty);
      expect(data.userDescription, equals('App crashed when loading feed'));
      expect(data.deviceInfo, isA<Map<String, dynamic>>());
      expect(data.appVersion, isNotEmpty);
      expect(data.recentLogs, isA<List>());
      expect(data.errorCounts, isA<Map<String, int>>());
      expect(data.timestamp, isA<DateTime>());
    });

    test('should collect error counts from injected tracker', () async {
      final errorTracker =
          ErrorAnalyticsTracker(sink: const NoOpAnalyticsEventSink())
            ..trackError(
              errorType: 'feed_load_failed',
              errorMessage: 'Feed failed to load',
              location: 'NewVideosTab',
            );
      final service = BugReportService(errorTracker: errorTracker);

      final data = await service.collectDiagnostics(
        userDescription: 'Feed failed',
      );

      expect(data.errorCounts, {'NewVideosTab:feed_load_failed': 1});
    });

    test('includes durable local support diagnostics in the report', () async {
      final service = BugReportService(
        supportDiagnosticsLoader: () async => {
          'databaseRecovery': {
            'outcome': 'recreatedKeyLoss',
            'occurredAt': '2026-08-29T17:34:56.000Z',
          },
          'contentInventory': {'visibleDraftRows': 0, 'foreignDraftRows': 4},
        },
      );

      final data = await service.collectDiagnostics(
        userDescription: 'My drafts are missing',
      );

      expect(data.deviceInfo['localStorage'], {
        'databaseRecovery': {
          'outcome': 'recreatedKeyLoss',
          'occurredAt': '2026-08-29T17:34:56.000Z',
        },
        'contentInventory': {'visibleDraftRows': 0, 'foreignDraftRows': 4},
      });
    });

    test('diagnostic collection failure does not block a report', () async {
      final service = BugReportService(
        supportDiagnosticsLoader: () async => throw StateError('db busy'),
      );

      final data = await service.collectDiagnostics(
        userDescription: 'My drafts are missing',
      );

      expect(data.userDescription, 'My drafts are missing');
      expect(data.additionalContext, isNull);
    });

    test('collectDiagnostics returns sanitized description', () async {
      final data = await service.collectDiagnostics(
        userDescription: 'My key is $_rawNsec and email liz@example.com',
      );

      expect(data.userDescription, isNot(contains(_rawNsec)));
      expect(data.userDescription, isNot(contains('liz@example.com')));
      expect(data.userDescription, contains('[REDACTED]'));
    });

    test(
      'should populate deviceInfo on mobile platforms',
      () async {
        final data = await service.collectDiagnostics(
          userDescription: 'Test on mobile',
        );

        expect(data.deviceInfo, isNotEmpty);
        expect(data.deviceInfo.containsKey('model'), isTrue);
      },
      skip: !(Platform.isIOS || Platform.isAndroid)
          ? 'Only runs on iOS/Android'
          : null,
    );

    test('should sanitize nsec keys from description', () {
      final input = BugReportData(
        reportId: 'test-123',
        timestamp: DateTime.now(),
        userDescription: 'My nsec is $_rawNsec',
        deviceInfo: {},
        appVersion: '1.0.0',
        recentLogs: [],
        errorCounts: {},
      );

      final sanitized = service.sanitizeSensitiveData(input);

      expect(sanitized.userDescription, isNot(contains('nsec1')));
      expect(sanitized.userDescription, contains('[REDACTED]'));
    });

    test('sanitizes a device value by its key, not on its own', () {
      // The rules match a credential key next to its value, so a map value
      // sanitized in isolation arrives with no key attached and survives. This
      // map is rendered into the shareable export, so the miss ships.
      final input = BugReportData(
        reportId: 'test-123',
        timestamp: DateTime.now(),
        userDescription: 'it crashed',
        deviceInfo: {
          'platform': 'ios',
          'sessionKey': 'hunter2',
          // A credential is just as exposed inside a list or a nested map, and
          // recursing into those hands the rules a bare value with no key.
          'apiKeys': ['LISTSECRET1', 'LISTSECRET2'],
          'tokenBag': {'inner': 'NESTEDSECRET'},
          'passcode': 1234,
          'version': '18.2',
        },
        appVersion: '1.0.0',
        recentLogs: [],
        errorCounts: {'auth:sessionKey=hunter2': 3, 'login:token=abc': 5},
      );

      final sanitized = service.sanitizeSensitiveData(input);
      final rendered = sanitized.deviceInfo.toString();

      expect(sanitized.deviceInfo['sessionKey'], isNot(contains('hunter2')));
      expect(rendered, isNot(contains('LISTSECRET1')));
      expect(rendered, isNot(contains('LISTSECRET2')));
      expect(rendered, isNot(contains('NESTEDSECRET')));
      expect(rendered, isNot(contains('1234')));
      // Error-count keys are `'$location:$errorType'` strings, so they can
      // carry a credential-shaped name too.
      expect(sanitized.errorCounts.keys.join(), isNot(contains('hunter2')));
      // Both credential-shaped keys collapse to the same placeholder, so the
      // counts are summed rather than one silently replacing the other.
      expect(sanitized.errorCounts['[REDACTED]'], 8);
      // Ordinary device fields are untouched - the rule is key-driven, not a
      // blanket redaction of everything in the map.
      expect(sanitized.deviceInfo['platform'], 'ios');
      expect(sanitized.deviceInfo['version'], '18.2');
    });

    test('should sanitize ncryptsec keys from description', () {
      final input = BugReportData(
        reportId: 'test-123',
        timestamp: DateTime.now(),
        userDescription: 'My encrypted key is $_rawNcryptsec',
        deviceInfo: {},
        appVersion: '1.0.0',
        recentLogs: [],
        errorCounts: {},
      );

      final sanitized = service.sanitizeSensitiveData(input);

      expect(sanitized.userDescription, isNot(contains('ncryptsec1')));
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

    test('should sanitize email addresses from descriptions and logs', () {
      final input = BugReportData(
        reportId: 'test-123',
        timestamp: DateTime.now(),
        userDescription: 'Follow up at liz@example.com',
        deviceInfo: {},
        appVersion: '1.0.0',
        recentLogs: [
          LogEntry(
            timestamp: DateTime.now(),
            level: LogLevel.warning,
            message: 'User email liz@example.com',
            error: 'Contact liz@example.com failed',
            stackTrace: 'Frame included liz@example.com',
          ),
        ],
        errorCounts: {},
      );

      final sanitized = service.sanitizeSensitiveData(input);
      final log = sanitized.recentLogs.single;

      expect(sanitized.userDescription, isNot(contains('liz@example.com')));
      expect(log.message, isNot(contains('liz@example.com')));
      expect(log.error, isNot(contains('liz@example.com')));
      expect(log.stackTrace, isNot(contains('liz@example.com')));
      expect(sanitized.userDescription, contains('[REDACTED]'));
      expect(log.message, contains('[REDACTED]'));
    });

    test('should sanitize nsec keys from log entries', () {
      final input = BugReportData(
        reportId: 'test-123',
        timestamp: DateTime.now(),
        userDescription: 'Normal description',
        deviceInfo: {},
        appVersion: '1.0.0',
        recentLogs: [
          LogEntry(
            timestamp: DateTime.now(),
            level: LogLevel.error,
            message: 'Message included $_rawNsec',
            error: 'Error included $_rawNsec',
            stackTrace: 'Stack included $_rawNsec',
          ),
        ],
        errorCounts: {},
      );

      final sanitized = service.sanitizeSensitiveData(input);
      final log = sanitized.recentLogs.single;

      expect(log.message, isNot(contains(_rawNsec)));
      expect(log.error, isNot(contains(_rawNsec)));
      expect(log.stackTrace, isNot(contains(_rawNsec)));
      expect(log.message, contains('[REDACTED]'));
      expect(log.error, contains('[REDACTED]'));
      expect(log.stackTrace, contains('[REDACTED]'));
    });

    test('should redact device names from diagnostic device info', () {
      final input = BugReportData(
        reportId: 'test-123',
        timestamp: DateTime.now(),
        userDescription: 'Normal description',
        deviceInfo: const {
          'platform': 'ios',
          'model': 'iPhone',
          'name': "Liz's iPhone",
          'hostName': 'liz-macbook',
          'computerName': 'LIZ-PC',
        },
        appVersion: '1.0.0',
        recentLogs: [],
        errorCounts: {},
      );

      final sanitized = service.sanitizeSensitiveData(input);

      expect(sanitized.deviceInfo['platform'], 'ios');
      expect(sanitized.deviceInfo['model'], 'iPhone');
      expect(sanitized.deviceInfo['name'], '[REDACTED]');
      expect(sanitized.deviceInfo['hostName'], '[REDACTED]');
      expect(sanitized.deviceInfo['computerName'], '[REDACTED]');
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
      expect(data.deviceInfo, isA<Map<String, dynamic>>());
    });

    test(
      'should collect deviceInfo even with empty description on mobile',
      () async {
        final data = await service.collectDiagnostics(userDescription: '');

        expect(data.deviceInfo, isNotEmpty);
      },
      skip: !(Platform.isIOS || Platform.isAndroid)
          ? 'Only runs on iOS/Android'
          : null,
    );

    group('locale diagnostics', () {
      // For most of the 21+ supported locales there is no native reviewer, so
      // a copy report is the only signal - and it can only be routed if it says
      // which language the app was rendering. The resolved UI locale is that
      // language; the device locale is recorded only when it differs, because
      // a device set to Amharic that is showing the English fallback is a
      // different bug from a bad Amharic string (#7939).
      test('records the resolved UI locale in deviceInfo', () async {
        final service = BugReportService(
          resolvedUiLocaleLoader: () => const Locale('am'),
          deviceLocaleLoader: () => const Locale('am'),
        );

        final data = await service.collectDiagnostics(
          userDescription: 'This screen is showing bad copy',
        );

        expect(data.deviceInfo['locale'], 'am');
        // Same language shown as requested, so no device-locale line to add.
        expect(data.deviceInfo.containsKey('deviceLocale'), isFalse);
      });

      test(
        'records the device locale when it differs from the resolved locale',
        () async {
          final service = BugReportService(
            resolvedUiLocaleLoader: () => const Locale('en'),
            deviceLocaleLoader: () => const Locale('am', 'ET'),
          );

          final data = await service.collectDiagnostics(
            userDescription: 'App is in English but my phone is Amharic',
          );

          expect(data.deviceInfo['locale'], 'en');
          expect(data.deviceInfo['deviceLocale'], 'am-ET');
        },
      );
    });

    group('clearCapturedLogs', () {
      test('empties the in-memory capture buffer', () async {
        final capture = LogCaptureService();
        await capture.clearAllLogs();
        capture.captureLog(
          LogEntry(
            timestamp: DateTime.now(),
            level: LogLevel.info,
            message: 'before clear',
          ),
        );
        expect(capture.isEmpty, isFalse);

        await service.clearCapturedLogs();

        expect(capture.isEmpty, isTrue);
      });
    });
  });
}

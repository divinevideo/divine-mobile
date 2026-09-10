// ABOUTME: Tests BugReportService export sizing, headers, and result values.
// ABOUTME: Covers deterministic UTF-8 bounds without platform file or share IO.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/bug_report_service.dart';
import 'package:openvine/services/storage_management_service.dart';
import 'package:openvine/utils/app_uptime.dart';
import 'package:openvine/utils/device_memory_util.dart';

class _MockStorageManagementService extends Mock
    implements StorageManagementService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(LogExportResult, () {
    test('saved carries the path the user picked', () {
      const path = '/Users/rabble/Downloads/openvine_full_logs.txt';
      const result = LogExportResult.saved(path);

      expect(result.status, equals(LogExportStatus.saved));
      expect(result.filePath, equals(path));
    });

    test('shared has no file path', () {
      const result = LogExportResult.shared();

      expect(result.filePath, isNull);
    });

    // The regression in #8113: an Android share whose outcome the platform
    // declines to report is not a failure, and reporting it as one told the
    // user log export was broken when it had just worked.
    test('unconfirmed stays distinct from failure', () {
      const result = LogExportResult.unconfirmed();

      expect(result.status, equals(LogExportStatus.unconfirmed));
    });

    test('cancelled has its own status and no path', () {
      const result = LogExportResult.cancelled();

      expect(result.status, equals(LogExportStatus.cancelled));
      expect(result.filePath, isNull);
    });

    // #8114: an empty capture buffer is the user's to fix by reproducing
    // without restarting, so it must stay distinguishable from a real error.
    test('noLogs is distinct from failed', () {
      const noLogs = LogExportResult.noLogs();
      const failed = LogExportResult.failed();

      expect(noLogs.status, equals(LogExportStatus.noLogs));
      expect(failed.status, equals(LogExportStatus.failed));
      expect(noLogs.status, isNot(equals(failed.status)));
    });
  });

  group('buildLogExportShareParams', () {
    test('carries the file without a text extra', () {
      final params = BugReportService.buildLogExportShareParams(
        '/tmp/logs.txt',
      );

      expect(params.files!.single.path, '/tmp/logs.txt');
      expect(params.subject, 'Divine Full Logs');
      expect(params.text, isNull);
    });
  });

  group('log export timestamp', () {
    test('formats the export time as UTC', () {
      final localTime = DateTime.parse('2026-09-02T13:00:00.000+05:00');

      expect(
        BugReportService.formatLogExportTimestamp(localTime),
        '2026-09-02T08:00:00.000Z',
      );
    });

    test('uses the same UTC timestamp in the export filename', () {
      final localTime = DateTime.parse('2026-09-02T13:00:00.000+05:00');

      expect(
        BugReportService.buildLogExportFileName(localTime),
        'openvine_full_logs_2026-09-02T08-00-00.000Z.txt',
      );
    });
  });

  group('buildBoundedLogBody', () {
    const passthrough = _passthrough;

    test('retains every record under the limit', () {
      final result = BugReportService.buildBoundedLogBody(
        const ['oldest', 'newest'],
        sanitize: passthrough,
        maxBytes: 100,
      );

      expect(result.lines, ['oldest', 'newest']);
      expect(result.exportedCount, 2);
      expect(result.omittedCount, 0);
      expect(result.body, 'oldest\nnewest\n');
    });

    test('retains every record exactly at the limit', () {
      final result = BugReportService.buildBoundedLogBody(
        const ['abc', 'de'],
        sanitize: passthrough,
        maxBytes: utf8.encode('abc\nde\n').length,
      );

      expect(result.lines, ['abc', 'de']);
      expect(utf8.encode(result.body).length, 7);
      expect(result.omittedCount, 0);
    });

    test('drops the oldest record when one byte over the limit', () {
      final result = BugReportService.buildBoundedLogBody(
        const ['a', 'new'],
        sanitize: passthrough,
        maxBytes: utf8.encode('a\nnew\n').length - 1,
      );

      expect(result.lines, ['new']);
      expect(result.exportedCount, 1);
      expect(result.omittedCount, 1);
    });

    test('retains a newest contiguous suffix in original order', () {
      final result = BugReportService.buildBoundedLogBody(
        const ['first', 'second', 'third'],
        sanitize: passthrough,
        maxBytes: utf8.encode('second\nthird\n').length,
      );

      expect(result.lines, ['second', 'third']);
      expect(result.omittedCount, 1);
    });

    test('counts multibyte records as UTF-8 without splitting them', () {
      final result = BugReportService.buildBoundedLogBody(
        const ['🪩', '🌿'],
        sanitize: passthrough,
        maxBytes: utf8.encode('🌿\n').length + 1,
      );

      expect(result.lines, ['🌿']);
      expect(utf8.decode(utf8.encode(result.body)), '🌿\n');
      expect(result.body, isNot(contains('�')));
    });

    test('measures records after sanitization', () {
      final result = BugReportService.buildBoundedLogBody(
        const ['secret', 'safe'],
        sanitize: (line) => line == 'secret' ? '[REDACTED]' : line,
        maxBytes: utf8.encode('[REDACTED]\nsafe\n').length - 1,
      );

      expect(result.lines, ['safe']);
      expect(result.omittedCount, 1);
    });

    test('exports retained records in their sanitized form', () {
      final result = BugReportService.buildBoundedLogBody(
        const ['keep nsec1secret'],
        sanitize: (line) => line.replaceAll('nsec1secret', '[REDACTED]'),
        maxBytes: 100,
      );

      expect(result.lines, ['keep [REDACTED]']);
      expect(result.body, contains('[REDACTED]'));
      expect(result.body, isNot(contains('nsec1secret')));
    });

    test('sanitizes retained records plus at most one rejected probe', () {
      var calls = 0;
      final result = BugReportService.buildBoundedLogBody(
        const ['first', 'second', 'third'],
        sanitize: (line) {
          calls++;
          return line;
        },
        maxBytes: utf8.encode('third\n').length,
      );

      expect(result.lines, ['third']);
      expect(calls, result.exportedCount + 1);
    });
  });

  group('buildBoundedLogContent', () {
    String header({required int exportedCount, required int omittedCount}) =>
        'Records Exported: $exportedCount of 3\n'
        'Omitted Records: $omittedCount\n\n';

    test('includes header bytes in the export ceiling', () {
      final maxBytes =
          utf8.encode(header(exportedCount: 3, omittedCount: 3)).length +
          utf8.encode('three\n').length;
      final result = BugReportService.buildBoundedLogContent(
        const ['one', 'two', 'three'],
        buildHeader: header,
        sanitize: _passthrough,
        maxBytes: maxBytes,
      );

      expect(utf8.encode(result.content).length, lessThanOrEqualTo(maxBytes));
      expect(result.content, contains('Records Exported: 1 of 3'));
      expect(result.content, contains('Omitted Records: 2'));
      expect(result.content, endsWith('three\n'));
    });

    test('rejects a header that alone exceeds the ceiling', () {
      expect(
        () => BugReportService.buildBoundedLogContent(
          const ['line'],
          buildHeader: ({required exportedCount, required omittedCount}) =>
              'Current Screen: ${'x' * 100}',
          sanitize: _passthrough,
          maxBytes: 20,
        ),
        throwsArgumentError,
      );
    });
  });

  group('buildLogExportRecordSummary', () {
    test('reports full retention', () {
      expect(
        BugReportService.buildLogExportRecordSummary(
          totalCount: 3,
          exportedCount: 3,
          omittedCount: 0,
        ),
        'Records Exported: 3 of 3\n'
        'Omitted Records: 0 '
        '(oldest first, export size limit 2.0 MB)\n',
      );
    });

    test('reports oldest records omitted by the ceiling', () {
      expect(
        BugReportService.buildLogExportRecordSummary(
          totalCount: 50000,
          exportedCount: 17342,
          omittedCount: 32658,
        ),
        contains('Omitted Records: 32658 (oldest first'),
      );
    });
  });

  group('buildLogRouteDiagnostics', () {
    test('includes the retained current screen and bounded trail', () {
      expect(
        BugReportService.buildLogRouteDiagnostics(
          currentScreen: 'settings',
          recentScreens: const ['home', 'profile', 'settings'],
        ),
        'Current Screen: settings\n'
        'Recent Screens: home → profile → settings\n',
      );
    });
  });

  group('buildDeviceDescription', () {
    const channel = MethodChannel('dev.fluttercommunity.plus/device_info');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    Map<String, dynamic>? deviceInfoResponse;

    setUp(() {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getDeviceInfo') {
          final response = deviceInfoResponse;
          if (response == null) {
            throw PlatformException(code: 'unavailable');
          }
          return response;
        }
        return null;
      });
    });

    tearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
      deviceInfoResponse = null;
    });

    test('returns the utsname machine identifier on iOS', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      deviceInfoResponse = {
        'name': 'iPhone',
        'systemName': 'iOS',
        'systemVersion': '26.5.1',
        'model': 'iPhone',
        'localizedModel': 'iPhone',
        'identifierForVendor': null,
        'isPhysicalDevice': true,
        'utsname': {
          'sysname': 'Darwin',
          'nodename': 'iPhone',
          'release': '25.5.0',
          'version': 'Darwin Kernel',
          'machine': 'iPhone17,2',
        },
      };

      final description = await BugReportService.buildDeviceDescription();

      expect(description, equals('iPhone17,2'));
    });

    test('returns null when the device info probe fails', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      deviceInfoResponse = null;

      final description = await BugReportService.buildDeviceDescription();

      expect(description, isNull);
    });

    test('marks iOS simulators', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      deviceInfoResponse = {
        'name': 'iPhone',
        'systemName': 'iOS',
        'systemVersion': '26.5.1',
        'model': 'iPhone',
        'localizedModel': 'iPhone',
        'identifierForVendor': null,
        'isPhysicalDevice': false,
        'utsname': {
          'sysname': 'Darwin',
          'nodename': 'iPhone',
          'release': '25.5.0',
          'version': 'Darwin Kernel',
          'machine': 'arm64',
        },
      };

      final description = await BugReportService.buildDeviceDescription();

      expect(description, equals('arm64 (Simulator)'));
    });

    test('returns null on Windows so no computer name leaks', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      final description = await BugReportService.buildDeviceDescription();

      expect(description, isNull);
    });
  });

  group('buildEnvironmentDiagnostics', () {
    const connectivityChannel = MethodChannel(
      'dev.fluttercommunity.plus/connectivity',
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    setUp(() {
      messenger.setMockMethodCallHandler(connectivityChannel, (call) async {
        if (call.method == 'check') return <String>['wifi'];
        return null;
      });
    });

    tearDown(() {
      messenger.setMockMethodCallHandler(connectivityChannel, null);
      AppUptime.reset();
      DeviceMemoryUtil.resetCache();
    });

    test('reports network, text scale and memory tier', () async {
      final diagnostics = await BugReportService()
          .buildEnvironmentDiagnostics();

      expect(diagnostics, contains('Network: wifi'));
      expect(diagnostics, contains('Text Scale: '));
      expect(diagnostics, contains('Memory Tier: '));
    });

    test('reports app uptime once marked and omits it before', () async {
      final before = await BugReportService().buildEnvironmentDiagnostics();
      expect(before, isNot(contains('App Uptime: ')));

      AppUptime.markStarted();
      final after = await BugReportService().buildEnvironmentDiagnostics();
      expect(after, contains('App Uptime: '));
    });

    test('omits the cache line without a storage service', () async {
      final diagnostics = await BugReportService()
          .buildEnvironmentDiagnostics();

      expect(diagnostics, isNot(contains('Cache: ')));
    });

    test('reports cache usage against matching category budgets', () async {
      final storage = _MockStorageManagementService();
      when(storage.cacheUsage).thenAnswer(
        (_) async => const CacheUsage(
          video: CacheUsageCategory(
            usedBytes: 1536 * 1024 * 1024,
            limitBytes: 2 * 1024 * 1024 * 1024,
          ),
          images: CacheUsageCategory(
            usedBytes: 128 * 1024 * 1024,
            limitBytes: 256 * 1024 * 1024,
          ),
          transitionSeams: CacheUsageCategory(
            usedBytes: 64 * 1024 * 1024,
            limitBytes: 200 * 1024 * 1024,
          ),
          tempRenders: CacheUsageCategory(usedBytes: 32 * 1024 * 1024),
        ),
      );

      final diagnostics = await BugReportService(
        storageManagementService: storage,
      ).buildEnvironmentDiagnostics();

      expect(
        diagnostics,
        contains(
          'Cache: video 1.5 GB/2.0 GB '
          '(75.0%, within limit, 1610612736/2147483648 bytes) · '
          'images 128.0 MB/256.0 MB '
          '(50.0%, within limit, 134217728/268435456 bytes) · '
          'seams 64.0 MB/200.0 MB '
          '(32.0%, within limit, 67108864/209715200 bytes) · '
          'temp 32.0 MB',
        ),
      );
      expect(diagnostics, isNot(contains('used /')));
      expect(diagnostics, contains('within limit'));
    });

    test('reports exact cache limit status at and over budget', () async {
      final storage = _MockStorageManagementService();
      when(storage.cacheUsage).thenAnswer(
        (_) async => const CacheUsage(
          video: CacheUsageCategory(
            usedBytes: 2 * 1024 * 1024 * 1024,
            limitBytes: 2 * 1024 * 1024 * 1024,
          ),
          images: CacheUsageCategory(
            usedBytes: 300 * 1024 * 1024,
            limitBytes: 256 * 1024 * 1024,
          ),
          transitionSeams: CacheUsageCategory(
            usedBytes: 0,
            limitBytes: 200 * 1024 * 1024,
          ),
          tempRenders: CacheUsageCategory(usedBytes: 0),
        ),
      );

      final diagnostics = await BugReportService(
        storageManagementService: storage,
      ).buildEnvironmentDiagnostics();

      expect(
        diagnostics,
        contains(
          'video 2.0 GB/2.0 GB '
          '(100.0%, at limit, 2147483648/2147483648 bytes)',
        ),
      );
      expect(
        diagnostics,
        contains(
          'images 300.0 MB/256.0 MB '
          '(117.2%, over limit by 44.0 MB, 314572800/268435456 bytes)',
        ),
      );
    });
  });

  group('buildRuntimeDiagnostics', () {
    test('reports platform, CPU count and build mode', () {
      final diagnostics = BugReportService.buildRuntimeDiagnostics();

      expect(diagnostics, contains('Platform: '));
      expect(diagnostics, contains('CPU Cores: '));
      expect(diagnostics, contains('Build Mode: '));
    });

    test('reports process memory when ProcessInfo is supported', () {
      final diagnostics = BugReportService.buildRuntimeDiagnostics();

      // The production code omits this line if the ProcessInfo probe throws
      // on an unsupported platform, so only assert its format when present.
      if (diagnostics.contains('Process Memory: ')) {
        expect(diagnostics, contains('Process Memory: RSS '));
      }
    });

    test('reports a positive CPU core count', () {
      final diagnostics = BugReportService.buildRuntimeDiagnostics();
      final cpuLine = diagnostics
          .split('\n')
          .firstWhere((line) => line.startsWith('CPU Cores: '));
      final cores = int.parse(cpuLine.substring('CPU Cores: '.length).trim());

      expect(cores, greaterThan(0));
    });
  });
}

String _passthrough(String value) => value;

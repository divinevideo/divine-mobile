import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/pro_video_editor_log_forwarder.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

class _MockProVideoEditor extends Mock implements ProVideoEditor {}

class _RecordingCrashReporter extends Fake implements CrashReporter {
  final breadcrumbs = <String>[];

  @override
  void log(String message) => breadcrumbs.add(message);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  LogEntry? latestWithMessage(String message) {
    final matches = LogCaptureService().getRecentLogs().where(
      (entry) => entry.message == message,
    );
    return matches.isEmpty ? null : matches.last;
  }

  NativeLogEntry entry(
    NativeLogLevel level,
    String message, {
    String? tag,
    String? stackTrace,
  }) => NativeLogEntry(
    level: level,
    message: message,
    tag: tag,
    stackTrace: stackTrace,
    timestamp: DateTime.now(),
  );

  tearDown(() async {
    await ProVideoEditorLogForwarder.stop();
  });

  group('ProVideoEditorLogForwarder.forwardEntry', () {
    test('preserves native failure and cause chain in crash breadcrumbs', () {
      final reporter = _RecordingCrashReporter();
      const stack =
          'androidx.media3.transformer.ExportException: '
          'Video frame processing error\n'
          'Caused by: androidx.media3.common.VideoFrameProcessingException: '
          'GL_OUT_OF_MEMORY';

      ProVideoEditorLogForwarder.forwardEntry(
        entry(
          NativeLogLevel.error,
          'Error rendering video: Video frame processing error',
          tag: 'RenderVideo',
          stackTrace: stack,
        ),
        crashReporter: reporter,
      );

      expect(reporter.breadcrumbs, hasLength(1));
      expect(reporter.breadcrumbs.single, contains('RenderVideo'));
      expect(reporter.breadcrumbs.single, contains(stack));
    });

    test('sanitizes the message, tag and cause before crash reporting', () {
      final reporter = _RecordingCrashReporter();
      // Synthetic identifiers exercise the shared crash-report sanitizer.
      final publicKey = 'npub1${List.filled(58, 'q').join()}';
      final secretKey = 'nsec1${List.filled(58, 'q').join()}';
      ProVideoEditorLogForwarder.forwardEntry(
        entry(
          NativeLogLevel.error,
          'Error for $publicKey',
          tag: secretKey,
          stackTrace: 'Caused by: failed for creator@example.com',
        ),
        crashReporter: reporter,
      );

      expect(reporter.breadcrumbs, hasLength(1));
      final breadcrumb = reporter.breadcrumbs.single;
      expect(breadcrumb, isNot(contains(publicKey)));
      expect(breadcrumb, isNot(contains(secretKey)));
      expect(breadcrumb, isNot(contains('creator@example.com')));
      expect(breadcrumb, contains('npub1<redacted>'));
      expect(breadcrumb, contains('nsec1<redacted>'));
      expect(breadcrumb, contains('Caused by:'));
    });

    test(
      'keeps warnings but excludes routine native logs and empty messages',
      () {
        final reporter = _RecordingCrashReporter();
        for (final level in NativeLogLevel.values) {
          ProVideoEditorLogForwarder.forwardEntry(
            entry(level, 'native-${level.name}'),
            crashReporter: reporter,
          );
        }
        ProVideoEditorLogForwarder.forwardEntry(
          entry(NativeLogLevel.error, ''),
          crashReporter: reporter,
        );

        expect(reporter.breadcrumbs, hasLength(2));
        expect(reporter.breadcrumbs.join(), contains('native-warning'));
        expect(reporter.breadcrumbs.join(), contains('native-error'));
      },
    );

    test('forwards an error with stack trace under the video category', () {
      const message = 'pve-fwd-error-unique';
      ProVideoEditorLogForwarder.forwardEntry(
        entry(
          NativeLogLevel.error,
          message,
          tag: 'ProVideoEditor-Renderer',
          stackTrace: 'at foo\nat bar',
        ),
      );

      final logged = latestWithMessage(message);
      expect(logged, isNotNull);
      expect(logged!.level, LogLevel.error);
      expect(logged.name, 'ProVideoEditor-Renderer');
      expect(logged.category, LogCategory.video);
      expect(logged.stackTrace, isNotNull);
    });

    test('maps the warning level', () {
      const message = 'pve-fwd-warning-unique';
      ProVideoEditorLogForwarder.forwardEntry(
        entry(NativeLogLevel.warning, message),
      );
      expect(latestWithMessage(message)?.level, LogLevel.warning);
    });

    test('maps the info level', () {
      const message = 'pve-fwd-info-unique';
      ProVideoEditorLogForwarder.forwardEntry(
        entry(NativeLogLevel.info, message),
      );
      expect(latestWithMessage(message)?.level, LogLevel.info);
    });

    test('maps the debug level', () {
      const message = 'pve-fwd-debug-unique';
      ProVideoEditorLogForwarder.forwardEntry(
        entry(NativeLogLevel.debug, message),
      );
      expect(latestWithMessage(message)?.level, LogLevel.debug);
    });

    test('maps the verbose level', () {
      const message = 'pve-fwd-verbose-unique';
      ProVideoEditorLogForwarder.forwardEntry(
        entry(NativeLogLevel.verbose, message),
      );
      expect(latestWithMessage(message)?.level, LogLevel.verbose);
    });

    test('maps the none level to info', () {
      const message = 'pve-fwd-none-unique';
      ProVideoEditorLogForwarder.forwardEntry(
        entry(NativeLogLevel.none, message),
      );
      expect(latestWithMessage(message)?.level, LogLevel.info);
    });

    test('falls back to a default name when tag is missing', () {
      const message = 'pve-fwd-default-name-unique';
      ProVideoEditorLogForwarder.forwardEntry(
        entry(NativeLogLevel.info, message),
      );
      expect(latestWithMessage(message)?.name, 'ProVideoEditorNative');
    });

    test('ignores an entry with an empty message', () {
      const tag = 'pve-fwd-empty-message-unique';
      // Positive control first: a dead forwarder would also leave the buffer
      // untouched, and the buffer is a ring that stops growing once full, so
      // the guard is asserted on content rather than on bufferSize (#8617).
      const control = 'pve-fwd-empty-message-control-unique';
      ProVideoEditorLogForwarder.forwardEntry(
        entry(NativeLogLevel.error, control, tag: tag),
      );
      expect(latestWithMessage(control)?.name, tag);

      ProVideoEditorLogForwarder.forwardEntry(
        entry(NativeLogLevel.error, '', tag: tag),
      );

      expect(
        LogCaptureService().getRecentLogs().where(
          (logged) => logged.name == tag && logged.message.isEmpty,
        ),
        isEmpty,
      );
    });
  });

  group('ProVideoEditorLogForwarder start/stop', () {
    test('forwards stream entries while subscribed, stops on cancel', () async {
      final mock = _MockProVideoEditor();
      final controller = StreamController<NativeLogEntry>.broadcast();
      when(() => mock.logStream).thenAnswer((_) => controller.stream);

      final reporter = _RecordingCrashReporter();
      ProVideoEditorLogForwarder.start(
        proVideoEditor: mock,
        crashReporter: reporter,
      );

      const live = 'pve-stream-live-unique';
      controller.add(entry(NativeLogLevel.warning, live));
      await Future<void>.delayed(Duration.zero);
      expect(latestWithMessage(live), isNotNull);
      expect(reporter.breadcrumbs.single, contains(live));

      await ProVideoEditorLogForwarder.stop();

      const afterStop = 'pve-stream-afterstop-unique';
      controller.add(entry(NativeLogLevel.warning, afterStop));
      await Future<void>.delayed(Duration.zero);
      expect(latestWithMessage(afterStop), isNull);
      expect(reporter.breadcrumbs, hasLength(1));

      await controller.close();
    });

    test(
      'start is idempotent — a second call does not double-subscribe',
      () async {
        final mock = _MockProVideoEditor();
        final controller = StreamController<NativeLogEntry>.broadcast();
        var listenCount = 0;
        when(() => mock.logStream).thenAnswer((_) {
          listenCount++;
          return controller.stream;
        });

        ProVideoEditorLogForwarder.start(proVideoEditor: mock);
        ProVideoEditorLogForwarder.start(proVideoEditor: mock);

        expect(listenCount, 1);
        await ProVideoEditorLogForwarder.stop();
        await controller.close();
      },
    );
  });
}

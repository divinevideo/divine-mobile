// ABOUTME: Tests relay diagnostic capture and deterministic volume bounding.
// ABOUTME: Verifies the nostr_sdk port reaches the shared support-log buffer.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_client/src/relay_diagnostics_adapter.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:unified_logger/unified_logger.dart';

void main() {
  group('RelayDiagnosticsAdapter', () {
    late DateTime now;
    late LogCaptureService capture;

    setUp(() async {
      now = DateTime.utc(2026, 9, 8, 12);
      capture = LogCaptureService();
      await capture.clearAllLogs();
    });

    tearDown(() => capture.clearAllLogs());

    RelayDiagnostic diagnostic({
      String relayUrl = 'wss://relay.example',
      RelayDiagnosticSite site = RelayDiagnosticSite.connectionLifecycle,
      String message = 'Relay connection succeeded',
      RelayDiagnosticLevel level = RelayDiagnosticLevel.info,
      Object? error,
      StackTrace? stackTrace,
    }) => RelayDiagnostic(
      site: site,
      level: level,
      relayUrl: relayUrl,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );

    test('writes relay diagnostics to the support-log buffer', () {
      final adapter = RelayDiagnosticsAdapter(clock: () => now);

      adapter(diagnostic());

      final entry = capture.getRecentLogs().single;
      expect(entry.message, contains('wss://relay.example'));
      expect(entry.message, contains('Relay connection succeeded'));
      expect(entry.name, 'RelayDiagnostics');
      expect(entry.category, LogCategory.relay);
      expect(entry.level, LogLevel.info);
    });

    test('bounds repeated relay and site diagnostics', () {
      final adapter = RelayDiagnosticsAdapter(
        maxEventsPerWindow: 2,
        clock: () => now,
      );

      adapter(diagnostic(message: 'first'));
      adapter(diagnostic(message: 'second'));
      adapter(diagnostic(message: 'third'));

      expect(capture.getRecentLogs(), hasLength(3));
      expect(
        capture.getRecentLogs().last.message,
        contains('Further connectionLifecycle info diagnostics suppressed'),
      );

      now = now.add(const Duration(minutes: 1));
      adapter(diagnostic(message: 'after rollover'));

      final messages = capture.getRecentLogs().map((entry) => entry.message);
      expect(messages, hasLength(5));
      expect(messages.elementAt(3), contains('Suppressed 1 repeated'));
      expect(messages.last, contains('after rollover'));
    });

    test('the suppression summary reports the span it actually covers', () {
      final adapter = RelayDiagnosticsAdapter(
        maxEventsPerWindow: 1,
        clock: () => now,
      );
      final windowStart = now;

      adapter(diagnostic(message: 'emitted'));
      adapter(diagnostic(message: 'suppressed'));

      final marker = capture.getRecentLogs().elementAt(1).message;
      expect(marker, contains('Further connectionLifecycle info diagnostics'));
      expect(
        marker,
        contains(
          windowStart.add(const Duration(minutes: 1)).toUtc().toIso8601String(),
        ),
      );

      // The next diagnostic arrives much later, but the summary still names
      // the fixed limiter window rather than implying a ten-minute storm.
      now = now.add(const Duration(minutes: 10));
      adapter(diagnostic(message: 'much later'));

      final summary = capture.getRecentLogs().elementAt(2).message;
      expect(summary, contains('Suppressed 1 repeated'));
      expect(summary, contains('during the 60-second window'));
      expect(summary, contains(windowStart.toUtc().toIso8601String()));
    });

    test('bounds limiter keys and treats separate sites independently', () {
      final adapter = RelayDiagnosticsAdapter(
        maxEventsPerWindow: 1,
        maxTrackedKeys: 1,
        clock: () => now,
      );

      adapter(diagnostic(message: 'first relay'));
      adapter(diagnostic(message: 'suppressed'));
      adapter(
        diagnostic(
          relayUrl: 'wss://other.example',
          site: RelayDiagnosticSite.queryDispatch,
          message: 'other key',
        ),
      );
      adapter(diagnostic(message: 'first key after eviction'));

      final messages = capture.getRecentLogs().map((entry) => entry.message);
      expect(messages, hasLength(5));
      expect(messages.elementAt(2), contains('Suppressed 1 repeated'));
      expect(messages.last, contains('first key after eviction'));
    });

    test('severity has an independent budget for a relay and site', () {
      final adapter = RelayDiagnosticsAdapter(
        maxEventsPerWindow: 1,
        clock: () => now,
      );

      adapter(diagnostic(message: 'info emitted'));
      adapter(diagnostic(message: 'info suppressed'));
      adapter(
        diagnostic(
          level: RelayDiagnosticLevel.warning,
          message: 'terminal warning',
        ),
      );
      adapter(
        diagnostic(
          level: RelayDiagnosticLevel.error,
          message: 'terminal error',
        ),
      );

      final messages = capture.getRecentLogs().map((entry) => entry.message);
      expect(messages, hasLength(4));
      expect(messages, contains(contains('terminal warning')));
      expect(messages, contains(contains('terminal error')));
    });

    test('bounds a reconnect storm to one marker per severity budget', () {
      final adapter = RelayDiagnosticsAdapter(
        maxEventsPerWindow: 1,
        clock: () => now,
      );

      for (final level in RelayDiagnosticLevel.values) {
        for (var i = 0; i < 20; i++) {
          adapter(diagnostic(level: level, message: '${level.name} $i'));
        }
      }

      // One original plus one suppression marker for each of four levels.
      expect(capture.getRecentLogs(), hasLength(8));
    });

    test(
      'maps warning and error diagnostics without copying error objects',
      () {
        final adapter = RelayDiagnosticsAdapter(clock: () => now);

        adapter(
          diagnostic(
            level: RelayDiagnosticLevel.warning,
            message: 'warning',
          ),
        );
        adapter(
          diagnostic(
            site: RelayDiagnosticSite.authentication,
            level: RelayDiagnosticLevel.error,
            message: 'authentication failed',
            error: StateError('private failure detail'),
            stackTrace: StackTrace.fromString('private stack frame'),
          ),
        );

        final entries = capture.getRecentLogs();
        expect(entries.map((entry) => entry.level), [
          LogLevel.warning,
          LogLevel.error,
        ]);
        expect(entries.every((entry) => entry.error == null), isTrue);
        expect(entries.every((entry) => entry.stackTrace == null), isTrue);
        expect(entries.last.message, contains('error type: StateError'));
        expect(entries.last.message, isNot(contains('private failure detail')));
        expect(entries.last.message, isNot(contains('private stack frame')));
      },
    );
  });
}

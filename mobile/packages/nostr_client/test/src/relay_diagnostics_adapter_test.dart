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
    }) => RelayDiagnostic(
      site: site,
      level: level,
      relayUrl: relayUrl,
      message: message,
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

      expect(capture.getRecentLogs(), hasLength(2));

      now = now.add(const Duration(minutes: 1));
      adapter(diagnostic(message: 'after rollover'));

      final messages = capture.getRecentLogs().map((entry) => entry.message);
      expect(messages, hasLength(4));
      expect(messages.elementAt(2), contains('Suppressed 1 repeated'));
      expect(messages.last, contains('after rollover'));
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
      expect(messages, hasLength(3));
      expect(messages.last, contains('first key after eviction'));
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
          ),
        );

        final entries = capture.getRecentLogs();
        expect(entries.map((entry) => entry.level), [
          LogLevel.warning,
          LogLevel.error,
        ]);
        expect(entries.every((entry) => entry.error == null), isTrue);
      },
    );
  });
}

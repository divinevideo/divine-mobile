// ABOUTME: Test timestamp backdating functionality
import 'package:openvine/utils/unified_logger.dart';
// ABOUTME: Verifies NostrTimestamp generates acceptable timestamps for relays

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/nostr_timestamp.dart';

void main() {
  group('NostrTimestamp', () {
    test('should generate current timestamp without drift tolerance', () {
      final timestamp = NostrTimestamp.now(driftTolerance: 0);
      final currentTime = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

      // Should be within 1 second of current time
      expect(timestamp, closeTo(currentTime, 1));
    });

    test('should apply drift tolerance correctly', () {
      const driftTolerance = 300; // 5 minutes
      final timestamp = NostrTimestamp.now(driftTolerance: driftTolerance);
      final currentTime = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

      // Should be exactly driftTolerance seconds behind current time
      expect(timestamp, equals(currentTime - driftTolerance));
    });

    test('should get correct drift tolerance for Kind 0 (profile)', () {
      final tolerance = NostrTimestamp.getDriftToleranceForKind(0);
      expect(tolerance, equals(5 * 60)); // 5 minutes
    });

    test('should get correct drift tolerance for Kind 22 (video)', () {
      final tolerance = NostrTimestamp.getDriftToleranceForKind(22);
      expect(tolerance, equals(30)); // 30 seconds
    });

    test('Kind 0 timestamp should be 5 minutes behind current time', () {
      final tolerance = NostrTimestamp.getDriftToleranceForKind(0);
      final timestamp = NostrTimestamp.now(driftTolerance: tolerance);
      final currentTime = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

      Log.info(
        'Current time: $currentTime (${NostrTimestamp.format(currentTime)})',
      );
      Log.info(
        'Kind 0 timestamp: $timestamp (${NostrTimestamp.format(timestamp)})',
      );
      Log.info('Difference: ${currentTime - timestamp} seconds');

      // Should be exactly 5 minutes (300 seconds) behind
      expect(timestamp, equals(currentTime - 300));
      expect(currentTime - timestamp, equals(300));
    });

    test('timestamp should be valid according to validation', () {
      final timestamp = NostrTimestamp.now(driftTolerance: 300);
      expect(NostrTimestamp.isValid(timestamp), isTrue);
    });

    test('debug info should show timezone details', () {
      final debugInfo = NostrTimestamp.debugInfo();

      Log.info('Debug info:');
      debugInfo.forEach((key, value) {
        Log.info('  $key: $value');
      });

      expect(debugInfo, contains('local_time'));
      expect(debugInfo, contains('utc_time'));
      expect(debugInfo, contains('unix_timestamp'));
      expect(debugInfo, contains('adjusted_timestamp'));
      expect(debugInfo, contains('drift_applied'));
    });
  });
}

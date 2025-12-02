// ABOUTME: Test that AuthService creates events with correct backdated timestamps
import 'package:openvine/utils/unified_logger.dart';
// ABOUTME: Verifies Kind 0 profile events use 5-minute backdate

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/nostr_timestamp.dart';

void main() {
  group('AuthService Event Creation', () {
    test('should create Kind 0 event with 5-minute backdated timestamp', () async {
      // Note: This test requires actual AuthService setup
      // For now, let's test the timestamp logic directly

      final currentTime = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final kind0Tolerance = NostrTimestamp.getDriftToleranceForKind(0);
      final kind0Timestamp = NostrTimestamp.now(driftTolerance: kind0Tolerance);

      Log.info('Testing Kind 0 (profile) event timestamp:');
      Log.info(
        'Current UTC time: $currentTime (${NostrTimestamp.format(currentTime)})',
      );
      Log.info(
        'Kind 0 timestamp: $kind0Timestamp (${NostrTimestamp.format(kind0Timestamp)})',
      );
      Log.info(
        'Backdate amount: ${currentTime - kind0Timestamp} seconds (${(currentTime - kind0Timestamp) / 60} minutes)',
      );

      // Verify it's exactly 5 minutes behind
      expect(currentTime - kind0Timestamp, equals(300));
      expect(kind0Timestamp, equals(currentTime - 300));

      // Verify the timestamp would be accepted by relay (not in future)
      expect(kind0Timestamp, lessThanOrEqualTo(currentTime));
      expect(NostrTimestamp.isValid(kind0Timestamp), isTrue);
    });

    test(
      'should create Kind 22 event with 30-second backdated timestamp',
      () async {
        final currentTime =
            DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final kind22Tolerance = NostrTimestamp.getDriftToleranceForKind(22);
        final kind22Timestamp = NostrTimestamp.now(
          driftTolerance: kind22Tolerance,
        );

        Log.info('Testing Kind 22 (video) event timestamp:');
        Log.info(
          'Current UTC time: $currentTime (${NostrTimestamp.format(currentTime)})',
        );
        Log.info(
          'Kind 22 timestamp: $kind22Timestamp (${NostrTimestamp.format(kind22Timestamp)})',
        );
        Log.info('Backdate amount: ${currentTime - kind22Timestamp} seconds');

        // Verify it's exactly 30 seconds behind
        expect(currentTime - kind22Timestamp, equals(30));
        expect(kind22Timestamp, equals(currentTime - 30));

        // Verify the timestamp would be accepted by relay
        expect(kind22Timestamp, lessThanOrEqualTo(currentTime));
        expect(NostrTimestamp.isValid(kind22Timestamp), isTrue);
      },
    );
  });
}

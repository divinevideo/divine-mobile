// ABOUTME: Regression tests for avoiding high-volume profile event log spam.
// ABOUTME: Keeps hot profile loads from formatting/capturing per-event debug data.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart' as sdk;
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:unified_logger/unified_logger.dart';

class _MockNostrClient extends Mock implements NostrClient {}

void main() {
  group('VideoEventService profile logging', () {
    const pubkey =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

    late VideoEventService service;

    setUp(() async {
      await LogCaptureService().clearAllLogs();

      service = VideoEventService(
        _MockNostrClient(),
        crashReporter: const SilentCrashReporter(),
      );
    });

    tearDown(() {
      service.dispose();
    });

    sdk.Event makeProfileVideoEvent() => sdk.Event(
      pubkey,
      NIP71VideoKinds.addressableShortVideo,
      const [
        ['d', 'profile-log-regression'],
        ['url', 'https://example.com/video.mp4'],
        ['title', 'Profile log regression'],
        ['summary', 'A video with enough tags to make eager formatting costly'],
      ],
      '',
      createdAt: 1000,
    )..id = 'profile-log-regression-event';

    test(
      'does not capture per-event profile checkpoints or full tag dumps',
      () {
        service.handleEventForTesting(
          makeProfileVideoEvent(),
          SubscriptionType.profile,
        );

        final messages = LogCaptureService()
            .getRecentLogs()
            .map((entry) => entry.message)
            .toList();

        expect(
          messages.where((message) => message.startsWith('SVC event:')),
          isEmpty,
        );
        expect(
          messages.where((message) => message.startsWith('Direct event tags:')),
          isEmpty,
        );
      },
    );

    test('does not eagerly log per-field dumps for parsed video events', () {
      service.handleEventForTesting(
        makeProfileVideoEvent(),
        SubscriptionType.profile,
      );

      final messages = LogCaptureService()
          .getRecentLogs()
          .map((entry) => entry.message)
          .toList();

      const eagerPrefixes = [
        'Parsed direct video:',
        'Thumbnail URL:',
        'Has thumbnail:',
        'Video author pubkey:',
        'Video title:',
        'Video hashtags:',
      ];
      for (final prefix in eagerPrefixes) {
        expect(
          messages.where((message) => message.startsWith(prefix)),
          isEmpty,
          reason: 'per-event verbose dump "$prefix" must not be logged',
        );
      }
    });
  });
}

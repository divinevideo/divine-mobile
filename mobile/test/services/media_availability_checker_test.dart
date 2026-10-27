// ABOUTME: Tests for MediaAvailabilityChecker — HEAD-based 404 confirmation
// ABOUTME: used before permanently removing a video from all feeds.

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvine/services/media_availability_checker.dart';

void main() {
  group(MediaAvailabilityChecker, () {
    for (final code in [200, 204, 302, 401, 403, 404, 500]) {
      test('positive availability requires a successful HEAD: $code', () async {
        final checker = MediaAvailabilityChecker(
          client: MockClient((request) async {
            expect(request.method, 'HEAD');
            expect(request.followRedirects, isFalse);
            return http.Response('', code);
          }),
        );
        expect(
          await checker.isConfirmedAvailable(
            'https://media.example.test/video',
          ),
          code >= 200 && code < 300,
        );
      });
    }
    test('unknown media cannot grant positive availability', () async {
      final checker = MediaAvailabilityChecker(
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      expect(
        await checker.isConfirmedAvailable('https://media.example.test/video'),
        isFalse,
      );
      expect(await checker.isConfirmedAvailable(''), isFalse);
    });
    group('isConfirmedMissing', () {
      test('returns true when HEAD returns 404', () async {
        final client = MockClient((request) async {
          expect(request.method, equals('HEAD'));
          return http.Response('', 404);
        });
        final checker = MediaAvailabilityChecker(client: client);

        final result = await checker.isConfirmedMissing(
          'https://example.com/missing.mp4',
        );

        expect(result, isTrue);
      });

      test('returns false when HEAD returns 200', () async {
        final client = MockClient((_) async => http.Response('', 200));
        final checker = MediaAvailabilityChecker(client: client);

        final result = await checker.isConfirmedMissing(
          'https://example.com/ok.mp4',
        );

        expect(result, isFalse);
      });

      test('returns false when HEAD returns 500', () async {
        final client = MockClient((_) async => http.Response('', 500));
        final checker = MediaAvailabilityChecker(client: client);

        final result = await checker.isConfirmedMissing(
          'https://example.com/flaky.mp4',
        );

        expect(result, isFalse);
      });

      test('returns false on network exception', () async {
        final client = MockClient(
          (_) async => throw http.ClientException('timeout'),
        );
        final checker = MediaAvailabilityChecker(client: client);

        final result = await checker.isConfirmedMissing(
          'https://example.com/slow.mp4',
        );

        expect(result, isFalse);
      });

      // Blossom answers 401 for an age-gated fetch and serves the blob to any
      // authenticated request, so an anonymous probe cannot conclude the media
      // is gone. DeadMediaFeedGuard persists this answer once moderation
      // confirms a terminal verdict, so widening the predicate to 401 would
      // hide viewable content for the tracker's full TTL. See #5953 / #6251.
      test('returns false for the 401 age gate', () async {
        final client = MockClient((_) async => http.Response('', 401));
        final checker = MediaAvailabilityChecker(client: client);

        final result = await checker.isConfirmedMissing(
          'https://media.divine.video/agegated',
        );

        expect(result, isFalse);
      });

      test('returns false for a 403', () async {
        final client = MockClient((_) async => http.Response('', 403));
        final checker = MediaAvailabilityChecker(client: client);

        final result = await checker.isConfirmedMissing(
          'https://media.divine.video/forbidden',
        );

        expect(result, isFalse);
      });

      test('returns false for empty URL without hitting the client', () async {
        var calls = 0;
        final client = MockClient((_) async {
          calls++;
          return http.Response('', 404);
        });
        final checker = MediaAvailabilityChecker(client: client);

        final result = await checker.isConfirmedMissing('');

        expect(result, isFalse);
        expect(calls, equals(0));
      });
    });
  });
}

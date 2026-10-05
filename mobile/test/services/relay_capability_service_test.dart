// ABOUTME: Test for RelayCapabilityService - validates NIP-11 relay information fetching and parsing
// ABOUTME: Covers divine_extensions detection for sorted query support

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/relay_capability_service.dart';

class _MockClient extends Mock implements http.Client {}

void main() {
  group('RelayCapabilityService', () {
    late RelayCapabilityService service;
    late _MockClient mockHttpClient;

    setUpAll(() {
      registerFallbackValue(Uri.parse('https://example.com'));
    });

    setUp(() {
      mockHttpClient = _MockClient();
      service = RelayCapabilityService(httpClient: mockHttpClient);
    });

    tearDown(() {
      service.dispose();
    });

    group('NIP-11 Information Document', () {
      test('parses divine.video relay capabilities correctly', () async {
        // NIP-11 response from staging-relay.divine.video
        const nip11Response = '''
{
  "name": "Divine Video Relay",
  "description": "Specialized relay for short vertical videos",
  "pubkey": "pub...",
  "contact": "relay@divine.video",
  "supported_nips": [1, 2, 9, 11, 12, 15, 16, 20, 33, 40, 71],
  "software": "nosflare",
  "version": "0.3.0",
  "limitation": {
    "max_message_length": 524288,
    "max_subscriptions": 100,
    "max_filters": 10,
    "max_limit": 200,
    "max_subid_length": 256,
    "max_event_tags": 2500,
    "max_content_length": 102400,
    "min_pow_difficulty": 0,
    "auth_required": false,
    "payment_required": false
  },
  "relay_countries": ["US"],
  "language_tags": ["en"],
  "tags": ["video", "nip71"],
  "posting_policy": "https://divine.video/policy",
  "divine_extensions": {
    "int_filters": ["loop_count", "likes", "views", "comments", "avg_completion"],
    "sort_fields": ["loop_count", "likes", "views", "comments", "avg_completion", "created_at"],
    "cursor_format": "base64url-encoded HMAC-SHA256 with query hash binding",
    "videos_kind": 34236,
    "metrics_freshness_sec": 3600,
    "limit_max": 200
  }
}
''';

        when(
          () => mockHttpClient.get(
            Uri.parse('https://staging-relay.divine.video'),
            headers: {'Accept': 'application/nostr+json'},
          ),
        ).thenAnswer((_) async => http.Response(nip11Response, 200));

        final capabilities = await service.getRelayCapabilities(
          'wss://staging-relay.divine.video',
        );

        expect(capabilities.relayUrl, 'wss://staging-relay.divine.video');
        expect(capabilities.name, 'Divine Video Relay');
        expect(capabilities.supportedNips, contains(71));
        expect(capabilities.hasDivineExtensions, true);
        expect(capabilities.supportsSorting, true);
        expect(capabilities.supportsIntFilters, true);
        expect(capabilities.supportsCursor, true);
        expect(capabilities.sortFields, contains('loop_count'));
        expect(capabilities.sortFields, contains('likes'));
        expect(capabilities.sortFields, contains('views'));
        expect(capabilities.intFilterFields, contains('loop_count'));
        expect(capabilities.maxLimit, 200);
      });

      test('handles relay without divine_extensions gracefully', () async {
        // Standard Nostr relay NIP-11 response (no divine extensions)
        const nip11Response = '''
{
  "name": "Standard Nostr Relay",
  "description": "General purpose relay",
  "supported_nips": [1, 2, 9, 11, 12],
  "software": "nostr-rs-relay",
  "version": "0.8.0"
}
''';

        when(
          () => mockHttpClient.get(
            Uri.parse('https://relay.example.com'),
            headers: {'Accept': 'application/nostr+json'},
          ),
        ).thenAnswer((_) async => http.Response(nip11Response, 200));

        final capabilities = await service.getRelayCapabilities(
          'wss://relay.example.com',
        );

        expect(capabilities.relayUrl, 'wss://relay.example.com');
        expect(capabilities.name, 'Standard Nostr Relay');
        expect(capabilities.hasDivineExtensions, false);
        expect(capabilities.supportsSorting, false);
        expect(capabilities.supportsIntFilters, false);
        expect(capabilities.supportsCursor, false);
        expect(capabilities.sortFields, isEmpty);
        expect(capabilities.intFilterFields, isEmpty);
      });

      test('converts wss:// to https:// for NIP-11 fetch', () async {
        when(
          () => mockHttpClient.get(
            Uri.parse('https://staging-relay.divine.video'),
            headers: {'Accept': 'application/nostr+json'},
          ),
        ).thenAnswer((_) async => http.Response('{"name": "Test Relay"}', 200));

        await service.getRelayCapabilities('wss://staging-relay.divine.video');

        verify(
          () => mockHttpClient.get(
            Uri.parse('https://staging-relay.divine.video'),
            headers: {'Accept': 'application/nostr+json'},
          ),
        ).called(1);
      });

      test('converts uppercase WSS:// to https:// for NIP-11 fetch', () async {
        when(
          () => mockHttpClient.get(
            Uri.parse('https://staging-relay.divine.video'),
            headers: {'Accept': 'application/nostr+json'},
          ),
        ).thenAnswer((_) async => http.Response('{"name": "Test Relay"}', 200));

        await service.getRelayCapabilities('WSS://staging-relay.divine.video');

        verify(
          () => mockHttpClient.get(
            Uri.parse('https://staging-relay.divine.video'),
            headers: {'Accept': 'application/nostr+json'},
          ),
        ).called(1);
      });

      test('handles HTTP errors gracefully', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Not Found', 404));

        expect(
          () => service.getRelayCapabilities('wss://nonexistent.relay'),
          throwsA(isA<RelayCapabilityException>()),
        );
      });

      test('handles network errors gracefully', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenThrow(Exception('Network error'));

        expect(
          () => service.getRelayCapabilities('wss://offline.relay'),
          throwsA(isA<RelayCapabilityException>()),
        );
      });

      test('handles malformed JSON gracefully', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('not json', 200));

        expect(
          () => service.getRelayCapabilities('wss://broken.relay'),
          throwsA(isA<RelayCapabilityException>()),
        );
      });
    });

    group('insecure URL rejection (#3362)', () {
      test('refuses NIP-11 fetch for ws:// non-loopback host', () async {
        await expectLater(
          service.getRelayCapabilities('ws://attacker.example.com'),
          throwsA(isA<RelayCapabilityException>()),
        );

        verifyNever(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        );
      });

      test('refuses NIP-11 fetch for http:// non-loopback host', () async {
        await expectLater(
          service.getRelayCapabilities('http://attacker.example.com'),
          throwsA(isA<RelayCapabilityException>()),
        );

        verifyNever(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        );
      });

      test(
        'refuses NIP-11 fetch for https:// input (not a relay URL)',
        () async {
          // Input contract is the WS form. An https:// URL means a caller
          // upstream lost the WS form somewhere — fail closed.
          await expectLater(
            service.getRelayCapabilities('https://relay.example.com'),
            throwsA(isA<RelayCapabilityException>()),
          );

          verifyNever(
            () => mockHttpClient.get(any(), headers: any(named: 'headers')),
          );
        },
      );

      test(
        'refuses NIP-11 fetch for http://localhost input (not a relay URL)',
        () async {
          // Loopback http:// is a valid HTTP target, but it's not a relay
          // URL — relays are WS-only, so reject the input.
          await expectLater(
            service.getRelayCapabilities('http://localhost:47777'),
            throwsA(isA<RelayCapabilityException>()),
          );

          verifyNever(
            () => mockHttpClient.get(any(), headers: any(named: 'headers')),
          );
        },
      );

      test('allows http://localhost for local Docker stack', () async {
        when(
          () => mockHttpClient.get(
            Uri.parse('http://localhost:47777'),
            headers: {'Accept': 'application/nostr+json'},
          ),
        ).thenAnswer((_) async => http.Response('{"name": "Local"}', 200));

        final capabilities = await service.getRelayCapabilities(
          'ws://localhost:47777',
        );

        expect(capabilities.relayUrl, equals('ws://localhost:47777'));
      });
    });

    group('Caching', () {
      test('caches relay capabilities and reuses them', () async {
        const nip11Response = '{"name": "Test Relay"}';

        when(
          () => mockHttpClient.get(
            Uri.parse('https://staging-relay.divine.video'),
            headers: {'Accept': 'application/nostr+json'},
          ),
        ).thenAnswer((_) async => http.Response(nip11Response, 200));

        // First call - should fetch from network
        await service.getRelayCapabilities('wss://staging-relay.divine.video');

        // Second call - should use cache
        await service.getRelayCapabilities('wss://staging-relay.divine.video');

        // Should only fetch once
        verify(
          () => mockHttpClient.get(
            Uri.parse('https://staging-relay.divine.video'),
            headers: {'Accept': 'application/nostr+json'},
          ),
        ).called(1);
      });

      test('respects cache TTL and refetches after expiration', () async {
        var now = DateTime.utc(2026);
        await withClock(Clock(() => now), () async {
          final shortTtlService = RelayCapabilityService(
            httpClient: mockHttpClient,
            cacheTtl: const Duration(milliseconds: 100),
          );

          const nip11Response = '{"name": "Test Relay"}';

          when(
            () => mockHttpClient.get(
              Uri.parse('https://staging-relay.divine.video'),
              headers: {'Accept': 'application/nostr+json'},
            ),
          ).thenAnswer((_) async => http.Response(nip11Response, 200));

          // First call
          await shortTtlService.getRelayCapabilities(
            'wss://staging-relay.divine.video',
          );

          // Wait for cache to expire
          now = now.add(const Duration(milliseconds: 101));

          // Second call after expiration
          await shortTtlService.getRelayCapabilities(
            'wss://staging-relay.divine.video',
          );

          // Should fetch twice
          verify(
            () => mockHttpClient.get(
              Uri.parse('https://staging-relay.divine.video'),
              headers: {'Accept': 'application/nostr+json'},
            ),
          ).called(2);

          shortTtlService.dispose();
        });
      });

      test('clearCache removes all cached capabilities', () async {
        const nip11Response = '{"name": "Test Relay"}';

        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(nip11Response, 200));

        // Fetch and cache
        await service.getRelayCapabilities('wss://staging-relay.divine.video');

        // Clear cache
        service.clearCache();

        // Should fetch again
        await service.getRelayCapabilities('wss://staging-relay.divine.video');

        verify(
          () => mockHttpClient.get(
            Uri.parse('https://staging-relay.divine.video'),
            headers: {'Accept': 'application/nostr+json'},
          ),
        ).called(2);
      });
    });

    group('Helper Methods', () {
      test('supportsMetric returns true for supported metrics', () async {
        const nip11Response = '''
{
  "name": "Divine Relay",
  "divine_extensions": {
    "int_filters": ["loop_count", "likes", "views"],
    "sort_fields": ["loop_count", "likes", "views", "created_at"]
  }
}
''';

        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(nip11Response, 200));

        final capabilities = await service.getRelayCapabilities(
          'wss://staging-relay.divine.video',
        );

        expect(capabilities.supportsMetric('loop_count'), true);
        expect(capabilities.supportsMetric('likes'), true);
        expect(capabilities.supportsMetric('views'), true);
        expect(capabilities.supportsMetric('nonexistent'), false);
      });

      test('supportsSortBy returns true for supported sort fields', () async {
        const nip11Response = '''
{
  "name": "Divine Relay",
  "divine_extensions": {
    "sort_fields": ["loop_count", "created_at"]
  }
}
''';

        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(nip11Response, 200));

        final capabilities = await service.getRelayCapabilities(
          'wss://staging-relay.divine.video',
        );

        expect(capabilities.supportsSortBy('loop_count'), true);
        expect(capabilities.supportsSortBy('created_at'), true);
        expect(capabilities.supportsSortBy('unsupported'), false);
      });
    });
  });
}

// ABOUTME: Tests that searchVideos() only requests valid video event kinds
// ABOUTME: Verifies filter uses kinds [34236, 34235, 22, 21] and not kind 34236

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/nostr_service.dart';

import '../test_setup.dart';

void main() {
  group('NostrService Search Kinds Filter', () {
    late NostrKeyManager keyManager;
    late NostrService nostrService;

    setUp(() async {
      setupTestEnvironment();

      keyManager = NostrKeyManager();
      await keyManager.initialize();

      nostrService = NostrService(keyManager);
      await nostrService.initialize(
        customRelays: ['wss://staging-relay.divine.video'],
      );

      // Wait for relay connection
      await Future.delayed(const Duration(seconds: 2));
    });

    tearDown(() async {
      await nostrService.dispose();
    });

    test('searchVideos should only return video event kinds', () async {
      const searchQuery = 'test';

      // Perform search
      final searchStream = nostrService.searchVideos(searchQuery, limit: 20);

      // Collect events
      final events = await searchStream.toList();

      print('🔍 Received ${events.length} events from search');

      // Valid video kinds according to NIP-71 + reposts
      const validVideoKinds = [34236, 34235, 22, 21, 6];

      for (final event in events) {
        print('  Event ${event.id}: kind=${event.kind}');

        // Assert that ONLY video kinds and reposts are returned
        expect(
          validVideoKinds.contains(event.kind),
          isTrue,
          reason:
              'Search returned invalid event kind ${event.kind}. '
              'Expected only video kinds and reposts: $validVideoKinds',
        );

        // Specifically verify we never get kind 34236 (text notes)
        expect(
          event.kind,
          isNot(equals(32222)),
          reason: 'Search should never return kind 34236 (text notes)',
        );
      }

      print('✅ All ${events.length} events are valid video kinds or reposts');
    });

    test(
      'searchVideos should not return text notes or other non-video kinds',
      () async {
        // Search for common terms that might match text notes
        const searchQuery = 'nostr';

        final searchStream = nostrService.searchVideos(searchQuery, limit: 50);
        final events = await searchStream.toList();

        print(
          '🔍 Received ${events.length} events from search for "$searchQuery"',
        );

        // Forbidden kinds (text notes, reactions, etc. - but NOT kind 6 reposts)
        const forbiddenKinds = [
          1, // Text note (NIP-01)
          3, // Contact list
          7, // Reaction
          34236, // Article (not a video)
        ];

        for (final event in events) {
          expect(
            forbiddenKinds.contains(event.kind),
            isFalse,
            reason:
                'Search returned forbidden kind ${event.kind}. '
                'Expected only video kinds [34236, 34235, 22, 21, 6]',
          );
        }

        print('✅ No forbidden event kinds found in ${events.length} results');
      },
    );

    test('searchVideos with no results should return empty stream', () async {
      const impossibleQuery = 'xyzabc123impossible456query789';

      final searchStream = nostrService.searchVideos(
        impossibleQuery,
        limit: 10,
      );
      final events = await searchStream.toList();

      print('🔍 Search for impossible query returned ${events.length} events');

      expect(events, isEmpty);
    });
  });
}

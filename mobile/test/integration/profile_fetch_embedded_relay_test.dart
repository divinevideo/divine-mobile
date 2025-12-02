// ABOUTME: Integration test for profile fetching with embedded relay
// ABOUTME: Tests that Kind 0 events are fetched when video authors are discovered

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_embedded_nostr_relay/flutter_embedded_nostr_relay.dart'
    as embedded;
import 'package:openvine/utils/unified_logger.dart';

void main() {
  // Initialize Flutter binding for tests
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Profile Fetching with Embedded Relay', () {
    late embedded.EmbeddedNostrRelay embeddedRelay;

    setUp(() async {
      embeddedRelay = embedded.EmbeddedNostrRelay();
      await embeddedRelay.initialize();
    });

    tearDown(() async {
      // EmbeddedNostrRelay doesn't have dispose method
      // It will be cleaned up automatically
    });

    test(
      'should fetch profiles for video authors from OpenVine relay',
      () async {
        Log.info('🚀 Starting profile fetch test...', name: 'Test');

        // Connect to OpenVine relay
        Log.info(
          '🔗 Connecting to wss://staging-relay.divine.video...',
          name: 'Test',
        );
        await embeddedRelay.addExternalRelay(
          'wss://staging-relay.divine.video',
        );

        // Wait for connection
        await Future.delayed(const Duration(seconds: 2));

        final connected = embeddedRelay.connectedRelays;
        expect(connected, isNotEmpty, reason: 'Should connect to relay');
        Log.info('✅ Connected to ${connected.length} relay(s)', name: 'Test');

        // First, get some video events
        Log.info('📹 Getting video events...', name: 'Test');

        final videoFilter = embedded.Filter(
          kinds: [34236], // NIP-71 kind 34236 addressable video events
          limit: 5,
        );

        final videoEvents = <embedded.NostrEvent>[];
        final videoCompleter = Completer<void>();

        final videoSubscription = embeddedRelay.subscribe(
          filters: [videoFilter],
          onEvent: (event) {
            videoEvents.add(event);
            Log.info('  Video from ${event.pubkey}', name: 'Test');

            if (videoEvents.length >= 3 && !videoCompleter.isCompleted) {
              videoCompleter.complete();
            }
          },
        );

        // Wait for video events
        await videoCompleter.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            Log.info(
              'Timeout (got ${videoEvents.length} videos)',
              name: 'Test',
            );
          },
        );

        await videoSubscription.close();

        if (videoEvents.isEmpty) {
          Log.warning(
            'No videos received, skipping profile test',
            name: 'Test',
          );
          return;
        }

        // Extract unique pubkeys from videos
        final videoPubkeys = videoEvents.map((e) => e.pubkey).toSet().toList();
        Log.info(
          '📝 Found ${videoPubkeys.length} unique video authors',
          name: 'Test',
        );

        // Now fetch profiles for these authors
        Log.info('👤 Fetching profiles for video authors...', name: 'Test');

        final profileFilter = embedded.Filter(
          kinds: [0], // Kind 0 = user metadata/profile
          authors: videoPubkeys,
          limit: videoPubkeys.length,
        );

        final profileEvents = <embedded.NostrEvent>[];
        final profileCompleter = Completer<void>();
        Timer? timeoutTimer;

        final profileSubscription = embeddedRelay.subscribe(
          filters: [profileFilter],
          onEvent: (event) {
            profileEvents.add(event);
            Log.info('  ✓ Got profile for ${event.pubkey}', name: 'Test');

            // Parse profile content
            try {
              // Profile content is JSON string
              final content = event.content;
              if (content.contains('name') ||
                  content.contains('display_name')) {
                Log.info('    Profile has name/display_name', name: 'Test');
              }
            } catch (e) {
              Log.warning('    Failed to parse profile: $e', name: 'Test');
            }

            // Complete if we have at least one profile
            if (profileEvents.isNotEmpty && !profileCompleter.isCompleted) {
              timeoutTimer?.cancel();
              profileCompleter.complete();
            }
          },
        );

        // Set a timeout
        timeoutTimer = Timer(const Duration(seconds: 10), () {
          if (!profileCompleter.isCompleted) {
            Log.info(
              'Profile fetch timeout (got ${profileEvents.length} profiles)',
              name: 'Test',
            );
            profileCompleter.complete();
          }
        });

        // Wait for profiles
        await profileCompleter.future;
        timeoutTimer.cancel();
        await profileSubscription.close();

        // Results
        Log.info('📊 Profile fetch results:', name: 'Test');
        Log.info('  Videos: ${videoEvents.length}', name: 'Test');
        Log.info('  Unique authors: ${videoPubkeys.length}', name: 'Test');
        Log.info('  Profiles fetched: ${profileEvents.length}', name: 'Test');

        // Verify we got at least some profiles
        if (videoPubkeys.isNotEmpty) {
          expect(
            profileEvents,
            isNotEmpty,
            reason: 'Should fetch at least one profile for video authors',
          );

          // Calculate success rate
          final successRate = (profileEvents.length / videoPubkeys.length * 100)
              .toStringAsFixed(1);
          Log.info('  Success rate: $successRate%', name: 'Test');
        }
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'should fetch known profile from Damus relay',
      () async {
        Log.info('🚀 Testing known profile fetch...', name: 'Test');

        // Connect to Damus relay
        await embeddedRelay.addExternalRelay('wss://relay.damus.io');
        await Future.delayed(const Duration(seconds: 2));

        // Jack Dorsey's pubkey (known to have a profile)
        const jackPubkey =
            '82341f882b6eabcd2ba7f1ef90aad961cf074af15b9ef44a09f9d2a8fbfbe6a2';

        Log.info('👤 Fetching Jack Dorsey profile...', name: 'Test');

        final filter = embedded.Filter(
          kinds: [0],
          authors: [jackPubkey],
          limit: 1,
        );

        embedded.NostrEvent? profileEvent;
        final completer = Completer<void>();

        final subscription = embeddedRelay.subscribe(
          filters: [filter],
          onEvent: (event) {
            profileEvent = event;
            Log.info('✓ Got profile event', name: 'Test');

            // Parse and log profile details
            try {
              final content = event.content;
              Log.info(
                '  Content preview: ${content.length > 100 ? "${content.substring(0, 100)}..." : content}',
                name: 'Test',
              );
            } catch (e) {
              Log.warning('  Could not parse content: $e', name: 'Test');
            }

            if (!completer.isCompleted) {
              completer.complete();
            }
          },
        );

        // Wait for profile with timeout
        await completer.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            Log.warning('Timeout waiting for profile', name: 'Test');
          },
        );

        await subscription.close();

        // Verify we got the profile
        expect(
          profileEvent,
          isNotNull,
          reason: 'Should fetch Jack Dorsey profile',
        );

        if (profileEvent != null) {
          expect(
            profileEvent!.kind,
            equals(0),
            reason: 'Should be a Kind 0 event',
          );
          expect(
            profileEvent!.pubkey,
            equals(jackPubkey),
            reason: 'Should be from correct pubkey',
          );
          expect(
            profileEvent!.content,
            isNotEmpty,
            reason: 'Profile should have content',
          );
        }
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );
  });
}

// ABOUTME: Integration test for profile update event broadcast and retrieval from relay
import 'package:openvine/utils/unified_logger.dart';
// ABOUTME: Tests the complete flow to identify why profile events aren't being retrieved after broadcast

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/user_profile_service.dart';

void main() {
  setUpAll(() async {
    // Initialize Flutter bindings for testing
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('Profile Update Relay Integration', () {
    late NostrService nostrService;
    late AuthService authService;
    late UserProfileService userProfileService;
    late SubscriptionManager subscriptionManager;
    late NostrKeyManager keyManager;

    setUp(() async {
      keyManager = NostrKeyManager();
      nostrService = NostrService(keyManager);
      authService = AuthService();
      subscriptionManager = SubscriptionManager(nostrService);
      userProfileService = UserProfileService(
        nostrService,
        subscriptionManager: subscriptionManager,
      );

      // Initialize services
      await authService.initialize();
      await nostrService.initialize();
      await userProfileService.initialize();

      // Ensure we have an authenticated user
      if (!authService.isAuthenticated) {
        await authService.createNewIdentity();
      }
    });

    tearDown(() async {
      userProfileService.dispose();
      subscriptionManager.dispose();
      nostrService.dispose();
      authService.dispose();
    });

    test('profile event broadcast and retrieval flow', () async {
      final pubkey = authService.currentPublicKeyHex!;

      // Step 1: Create and broadcast a profile event
      final profileData = {
        'name': 'Test Profile Update ${DateTime.now().millisecondsSinceEpoch}',
        'about': 'Testing profile update relay storage',
      };

      Log.info(
        '📝 Creating kind 0 event with data: ${jsonEncode(profileData)}',
      );

      final event = await authService.createAndSignEvent(
        kind: 0,
        content: jsonEncode(profileData),
      );

      expect(event, isNotNull, reason: 'Event creation should succeed');
      expect(event!.kind, equals(0));
      expect(event.pubkey, equals(pubkey));
      expect(event.isSigned, isTrue, reason: 'Event should be properly signed');

      Log.info('✅ Created event ID: ${event.id}');

      // Step 2: Broadcast the event
      Log.info('📤 Broadcasting event to relay...');
      final broadcastResult = await nostrService.broadcastEvent(event);

      expect(
        broadcastResult.isSuccessful,
        isTrue,
        reason: 'Event broadcast should succeed',
      );

      Log.info(
        '✅ Broadcast successful to ${broadcastResult.successCount} relays',
      );

      // Step 3: Wait for relay to process
      Log.info('⏳ Waiting for relay to process event...');
      await Future.delayed(const Duration(seconds: 2));

      // Step 4: Query the event back using direct subscription
      Log.info('🔍 Querying event back with direct subscription...');

      final filter = Filter(kinds: [0], authors: [pubkey], limit: 1);

      Event? foundEvent;
      var queryCompleted = false;

      final subscription = nostrService.subscribeToEvents(filters: [filter]);
      final subscriptionListener = subscription.listen(
        (receivedEvent) {
          Log.info(
            '📨 Received event: ${receivedEvent.id}, kind: ${receivedEvent.kind}',
          );
          if (receivedEvent.kind == 0 && receivedEvent.pubkey == pubkey) {
            foundEvent = receivedEvent;
            Log.info('🎯 Found profile event for our pubkey');
          }
        },
        onDone: () {
          queryCompleted = true;
          Log.info('✅ Subscription completed');
        },
        onError: (error) {
          Log.info('❌ Subscription error: $error');
          queryCompleted = true;
        },
      );

      // Wait up to 10 seconds for the event
      var waitTime = 0;
      while (foundEvent == null && !queryCompleted && waitTime < 10000) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitTime += 100;
      }

      await subscriptionListener.cancel();

      // Step 5: Verify results
      if (foundEvent != null) {
        Log.info('✅ SUCCESS: Found event ${foundEvent!.id}');
        expect(
          foundEvent!.id,
          equals(event.id),
          reason: 'Should find the exact event we broadcast',
        );
        expect(foundEvent!.kind, equals(0));
        expect(foundEvent!.pubkey, equals(pubkey));

        final content = jsonDecode(foundEvent!.content);
        expect(content['name'], equals(profileData['name']));
        expect(content['about'], equals(profileData['about']));
      } else {
        Log.info('❌ ISSUE: Event not found via direct query');

        // Additional debugging - try with UserProfileService
        Log.info('🔍 Trying with UserProfileService.fetchProfile...');
        final profile = await userProfileService.fetchProfile(
          pubkey,
          forceRefresh: true,
        );

        if (profile != null) {
          Log.info('📋 UserProfileService found profile:');
          Log.info('  - Event ID: ${profile.eventId}');
          Log.info('  - Name: ${profile.name}');
          Log.info('  - Created at: ${profile.createdAt}');

          if (profile.eventId == event.id) {
            Log.info('✅ UserProfileService found our event!');
          } else {
            Log.info('⚠️ UserProfileService found different event');
            Log.info('  - Expected: ${event.id}');
            Log.info('  - Found: ${profile.eventId}');
          }
        } else {
          Log.info('❌ UserProfileService also found no profile');
        }

        fail(
          'Event was broadcast successfully but not retrievable from relay. '
          'This indicates a relay storage or query issue.',
        );
      }
    });

    test('profile update with UserProfileService integration', () async {
      final pubkey = authService.currentPublicKeyHex!;

      // Clear any existing profile
      userProfileService.removeProfile(pubkey);

      // Create profile event
      final profileData = {
        'name': 'Integration Test ${DateTime.now().millisecondsSinceEpoch}',
        'about': 'Testing full profile update flow',
      };

      final event = await authService.createAndSignEvent(
        kind: 0,
        content: jsonEncode(profileData),
      );

      expect(event, isNotNull);

      // Broadcast
      final result = await nostrService.broadcastEvent(event!);
      expect(result.isSuccessful, isTrue);

      // Wait and fetch through UserProfileService
      await Future.delayed(const Duration(seconds: 2));

      final profile = await userProfileService.fetchProfile(
        pubkey,
        forceRefresh: true,
      );

      expect(
        profile,
        isNotNull,
        reason: 'UserProfileService should retrieve the updated profile',
      );

      if (profile != null) {
        expect(profile.name, equals(profileData['name']));
        expect(profile.about, equals(profileData['about']));
        expect(
          profile.eventId,
          equals(event.id),
          reason: 'Should retrieve the exact event we broadcast',
        );
      }
    });
  });
}

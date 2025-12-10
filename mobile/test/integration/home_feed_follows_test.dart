// ABOUTME: Integration test verifying home feed displays videos from followed users
// ABOUTME: Tests that events matching both discovery and home feed filters appear in both feeds

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/content_blocklist_service.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/utils/unified_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Home Feed Follows Integration', () {
    late NostrKeyManager keyManager;
    late NostrService nostrService;
    late SubscriptionManager subscriptionManager;
    late VideoEventService videoEventService;
    late ContentBlocklistService blocklistService;
    late UserProfileService userProfileService;

    setUp(() async {
      // Enable logging for debugging
      Log.setLogLevel(LogLevel.debug);
      Log.enableCategories({
        LogCategory.system,
        LogCategory.relay,
        LogCategory.video,
      });

      // Initialize services
      keyManager = NostrKeyManager();
      await keyManager.initialize();

      if (!keyManager.hasKeys) {
        await keyManager.generateKeys();
      }

      blocklistService = ContentBlocklistService();
      nostrService = NostrService(keyManager);
      await nostrService.initialize();

      subscriptionManager = SubscriptionManager(nostrService);
      userProfileService = UserProfileService(
        nostrService,
        subscriptionManager: subscriptionManager,
      );
      videoEventService = VideoEventService(
        nostrService,
        subscriptionManager: subscriptionManager,
        userProfileService: userProfileService,
      );
      videoEventService.setBlocklistService(blocklistService);
    });

    tearDown(() async {
      videoEventService.dispose();
      subscriptionManager.dispose();
      await nostrService.dispose();
    });

    test(
      'Home feed shows videos from followed users even when discovery feed also receives them',
      () async {
        Log.info('🧪 Starting home feed follows integration test');

        // Verify relay connection
        expect(nostrService.isInitialized, true);
        expect(nostrService.connectedRelays.isNotEmpty, true);
        Log.info(
          '✅ Connected to ${nostrService.connectedRelays.length} relay(s)',
        );

        // Subscribe to discovery feed first (all videos)
        Log.info('📡 Subscribing to discovery videos...');
        await videoEventService.subscribeToDiscovery(limit: 50);

        // Wait for discovery events
        var attempts = 0;
        const maxAttempts = 40; // 20 seconds

        while (!videoEventService.hasEvents(SubscriptionType.discovery) &&
            attempts < maxAttempts) {
          await Future.delayed(const Duration(milliseconds: 500));
          attempts++;
        }

        final discoveryCount = videoEventService.getEventCount(
          SubscriptionType.discovery,
        );
        Log.info('📊 Discovery feed received $discoveryCount videos');
        expect(
          discoveryCount,
          greaterThan(0),
          reason: 'Discovery feed should receive videos',
        );

        // Get some author pubkeys from discovery feed to "follow"
        final discoveryVideos = videoEventService.discoveryVideos;
        final authorPubkeys = discoveryVideos
            .map((v) => v.pubkey)
            .toSet()
            .take(5) // Follow first 5 unique authors
            .toList();

        Log.info(
          '👥 Following ${authorPubkeys.length} authors from discovery feed',
        );
        for (final pubkey in authorPubkeys) {
          Log.info('   - ${pubkey}...');
        }

        // Subscribe to home feed with these authors
        Log.info('📡 Subscribing to home feed for followed users...');
        await videoEventService.subscribeToHomeFeed(authorPubkeys, limit: 50);

        // Wait for home feed events
        attempts = 0;
        while (!videoEventService.hasEvents(SubscriptionType.homeFeed) &&
            attempts < maxAttempts) {
          await Future.delayed(const Duration(milliseconds: 500));
          attempts++;

          if (attempts % 10 == 0) {
            final homeFeedCount = videoEventService.getEventCount(
              SubscriptionType.homeFeed,
            );
            Log.info('⏳ Waiting for home feed... $homeFeedCount so far');
          }
        }

        final homeFeedCount = videoEventService.getEventCount(
          SubscriptionType.homeFeed,
        );
        Log.info('📊 Home feed received $homeFeedCount videos');

        // CRITICAL ASSERTION: Home feed should have videos from followed users
        // These are the SAME events that are in discovery feed
        expect(
          homeFeedCount,
          greaterThan(0),
          reason:
              'Home feed should receive videos from followed users, '
              'even though these events were already delivered to discovery feed. '
              'The same event should appear in BOTH feeds.',
        );

        // Verify the videos in home feed are actually from followed authors
        final homeFeedVideos = videoEventService.homeFeedVideos;
        for (final video in homeFeedVideos) {
          expect(
            authorPubkeys.contains(video.pubkey),
            true,
            reason:
                'Home feed video ${video.id} '
                'should be from a followed author',
          );
        }

        Log.info('✅ Home feed integration test complete');
        Log.info('   - Discovery videos: $discoveryCount');
        Log.info('   - Home feed videos: $homeFeedCount');
        Log.info('   - Followed authors: ${authorPubkeys.length}');
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      'Same video event appears in both discovery and home feed when author is followed',
      () async {
        Log.info('🧪 Testing same event in multiple feeds');

        // Subscribe to discovery
        await videoEventService.subscribeToDiscovery(limit: 30);

        // Wait for events
        var attempts = 0;
        while (!videoEventService.hasEvents(SubscriptionType.discovery) &&
            attempts < 40) {
          await Future.delayed(const Duration(milliseconds: 500));
          attempts++;
        }

        final discoveryVideos = videoEventService.discoveryVideos;
        expect(discoveryVideos.isNotEmpty, true);

        // Pick the first video and follow its author
        final targetVideo = discoveryVideos.first;
        final targetAuthor = targetVideo.pubkey;
        Log.info('🎯 Target video: ${targetVideo.id} from $targetAuthor');

        // Subscribe to home feed for just this author
        await videoEventService.subscribeToHomeFeed([targetAuthor], limit: 30);

        // Wait for home feed
        attempts = 0;
        while (!videoEventService.hasEvents(SubscriptionType.homeFeed) &&
            attempts < 40) {
          await Future.delayed(const Duration(milliseconds: 500));
          attempts++;
        }

        final homeFeedVideos = videoEventService.homeFeedVideos;
        Log.info(
          '📊 Home feed has ${homeFeedVideos.length} videos from followed author',
        );

        // CRITICAL: The target video should be in home feed
        final targetInHomeFeed = homeFeedVideos.any(
          (v) => v.id == targetVideo.id,
        );
        expect(
          targetInHomeFeed,
          true,
          reason:
              'Video ${targetVideo.id} should appear in home feed '
              'because its author is followed, even though it was already in discovery feed. '
              'One event, multiple feeds.',
        );

        Log.info('✅ Same event appears in both feeds as expected');
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });
}

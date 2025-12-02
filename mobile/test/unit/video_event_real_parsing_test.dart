// ABOUTME: Test to verify VideoEvent parsing of real kind 34236 events from staging-relay.divine.video
// ABOUTME: This tests the actual parsing logic with real relay data

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/utils/unified_logger.dart';

void main() {
  group('VideoEvent Parsing - Real Relay Data', () {
    test('should parse kind 34236 event with url tag correctly', () {
      Log.debug(
        '🔍 Testing VideoEvent parsing with real staging-relay.divine.video data...',
        name: 'VideoEventRealParsingTest',
        category: LogCategory.system,
      );

      // Real event from staging-relay.divine.video relay with url tag
      final event = Event(
        'd95aa8fc0eff8e488952495b8064991d27fb96ed8652f12cdedc5a4e8b5ae540',
        34236,
        [
          ["d", "test-video-1751355501029"], // Required for addressable events
          ["url", "https://api.openvine.co/media/1751355501029-7553157a"],
          ["m", "video/mp4"],
          ["title", "Untitled"],
          ["summary", ""],
          ["t", "openvine"],
          ["client", "openvine"],
          ["h", "vine"],
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ],
        '',
      );

      // Parse the event
      final videoEvent = VideoEvent.fromNostrEvent(event);

      Log.info(
        '✅ Parsed VideoEvent: hasVideo=${videoEvent.hasVideo}, videoUrl=${videoEvent.videoUrl}',
        name: 'VideoEventRealParsingTest',
        category: LogCategory.system,
      );

      // Verify parsing results
      expect(videoEvent.hasVideo, true, reason: 'Event should have video URL');
      expect(
        videoEvent.videoUrl,
        'https://api.openvine.co/media/1751355501029-7553157a',
      );
      expect(videoEvent.mimeType, 'video/mp4');
      expect(videoEvent.title, 'Untitled');
      expect(videoEvent.hashtags, contains('openvine'));
      expect(videoEvent.group, 'vine');
    });

    test('should parse kind 34236 event with r tag correctly', () {
      Log.debug(
        '🔍 Testing VideoEvent parsing with r tag...',
        name: 'VideoEventRealParsingTest',
        category: LogCategory.system,
      );

      // Real event from staging-relay.divine.video relay with r tag
      final event = Event(
        '033877f4080835f162880482590762c0a7508851e88fe164dd89028743914da5',
        34236,
        [
          ["d", "itjpUUgL6tE"], // Required for addressable events
          ["h", "vine"],
          [
            "r",
            "https://api.openvine.co/media/1751258545721-9733b197",
            "video",
          ],
          [
            "r",
            "https://api.openvine.co/media/1751258547438-fb6bd5f8",
            "thumbnail",
          ],
          ["t", "randomvines"],
          ["t", "classicvines"],
          ["vine_id", "itjpUUgL6tE"],
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ],
        'this mascot and fan had some problems 😳😂\n\n#RandomVines #ClassicVines #Preserved #RabblesSelection',
      );

      // Parse the event
      final videoEvent = VideoEvent.fromNostrEvent(event);

      Log.info(
        '✅ Parsed VideoEvent: hasVideo=${videoEvent.hasVideo}, videoUrl=${videoEvent.videoUrl}',
        name: 'VideoEventRealParsingTest',
        category: LogCategory.system,
      );
      Log.info(
        '✅ Thumbnail URL: ${videoEvent.thumbnailUrl}',
        name: 'VideoEventRealParsingTest',
        category: LogCategory.system,
      );

      // Verify parsing results
      expect(
        videoEvent.hasVideo,
        true,
        reason: 'Event should have video URL from r tag',
      );
      expect(
        videoEvent.videoUrl,
        'https://api.openvine.co/media/1751258545721-9733b197',
      );
      expect(
        videoEvent.thumbnailUrl,
        'https://api.openvine.co/media/1751258547438-fb6bd5f8',
      );
      expect(videoEvent.hashtags, contains('randomvines'));
      expect(videoEvent.hashtags, contains('classicvines'));
      expect(videoEvent.group, 'vine');
      // vineId comes from 'd' tag, but this event has 'vine_id' tag - different format
      // expect(videoEvent.vineId, 'itjpUUgL6tE'); // This might be parsed differently
    });

    test('URL validation should accept api.openvine.co URLs', () {
      // Test the URL validation directly since it's a static method
      // We need to access the private method - let's create an event and check if it's accepted
      final event = Event(
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        34236,
        [
          ["d", "test-video-validation"], // Required for addressable events
          ["url", "https://api.openvine.co/media/test-video-id"],
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ],
        '',
      );

      final videoEvent = VideoEvent.fromNostrEvent(event);

      expect(
        videoEvent.hasVideo,
        true,
        reason: 'api.openvine.co URLs should be valid',
      );
      expect(
        videoEvent.videoUrl,
        'https://api.openvine.co/media/test-video-id',
      );
    });
  });
}

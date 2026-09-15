// ABOUTME: Tests VideoEventService filtering for the feed video-shape preference.
// ABOUTME: Verifies square-only filtering at the shared list-surface chokepoint.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/feed_aspect_ratio_preference_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

VideoEvent _video({required String id, String? dimensions}) {
  return VideoEvent(
    id: id,
    pubkey: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    createdAt: 1704067200,
    content: '',
    timestamp: DateTime.fromMillisecondsSinceEpoch(1704067200 * 1000),
    title: 'Test Video',
    videoUrl: 'https://example.com/$id.mp4',
    dimensions: dimensions,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoEventService aspect-ratio filtering', () {
    late VideoEventService service;
    late FeedAspectRatioPreferenceService aspectRatioPreference;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      aspectRatioPreference = FeedAspectRatioPreferenceService(prefs);
      service = VideoEventService(
        _MockNostrClient(),
        crashReporter: const SilentCrashReporter(),
      );
      service.setFeedAspectRatioPreferenceService(aspectRatioPreference);
    });

    tearDown(() {
      aspectRatioPreference.dispose();
      service.dispose();
    });

    test(
      'shouldHideVideo keeps portrait videos when square-only is enabled',
      () async {
        await aspectRatioPreference.setPreference(
          FeedAspectRatioPreference.squareOnly,
        );

        expect(
          service.shouldHideVideo(
            _video(id: 'portrait', dimensions: '720x1280'),
          ),
          isFalse,
          reason:
              'The shape preference is a feed-list preference, not a '
              'detail/by-id/search/reception hard-hide rule.',
        );
      },
    );

    test(
      'filterVideoList hides portrait videos when square-only is enabled',
      () async {
        await aspectRatioPreference.setPreference(
          FeedAspectRatioPreference.squareOnly,
        );

        final filtered = service.filterVideoList([
          _video(id: 'square', dimensions: '640x640'),
          _video(id: 'portrait', dimensions: '720x1280'),
        ]);

        expect(filtered.map((video) => video.id), equals(['square']));
      },
    );

    test('filterVideoList re-filters an already-loaded list when the '
        'preference flips', () async {
      final videos = [
        _video(id: 'square', dimensions: '640x640'),
        _video(id: 'portrait', dimensions: '720x1280'),
      ];

      expect(
        service.filterVideoList(videos).map((video) => video.id),
        equals(['square', 'portrait']),
      );

      await aspectRatioPreference.setPreference(
        FeedAspectRatioPreference.squareOnly,
      );

      expect(
        service.filterVideoList(videos).map((video) => video.id),
        equals(['square']),
        reason:
            'The reported bug (#6511) is a live toggle: the service must '
            'read the preference at filter time, not snapshot it at attach.',
      );
    });
  });
}

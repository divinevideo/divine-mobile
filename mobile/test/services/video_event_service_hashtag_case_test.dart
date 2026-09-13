// ABOUTME: Regression tests for case-insensitive hashtag filtering in VideoEventService
// ABOUTME: Pins realtime/pagination parity so load-more stops dropping capitalised hashtags
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockNostrClient extends Mock implements NostrClient {}

Event _videoEvent({required String id, required String hashtag}) {
  final event = Event(
    'a' * 64,
    NIP71VideoKinds.addressableShortVideo,
    [
      ['d', 'vine_$id'],
      ['url', 'https://media.divine.video/$id.mp4'],
      ['m', 'video/mp4'],
      ['t', hashtag],
    ],
    '',
    createdAt: 1787236269,
  );
  event.id = id;
  return event;
}

void main() {
  group(VideoEventService, () {
    late _MockNostrClient nostrClient;
    late VideoEventService service;

    setUp(() {
      nostrClient = _MockNostrClient();
      when(() => nostrClient.isInitialized).thenReturn(true);
      when(() => nostrClient.isDisposed).thenReturn(false);
      when(() => nostrClient.connectedRelayCount).thenReturn(1);
      service = VideoEventService(
        nostrClient,
        crashReporter: const SilentCrashReporter(),
      );
    });

    tearDown(() => service.dispose());

    group('hashtag filter casing', () {
      // `subscribeToVideoFeed` lowercases the tag for the relay REQ (NIP-24)
      // but stores the caller's original casing in `_activeHashtagFilters`, so
      // every event the relay returns carries the lowercase form. A
      // case-sensitive compare on the pagination path therefore rejected 100%
      // of them whenever the hashtag had any uppercase character.
      test(
        'pagination keeps a lowercase-tagged video under a capitalised filter',
        () {
          service.setActiveHashtagFilterForTesting(
            SubscriptionType.hashtag,
            ['DivineUniversity'],
          );

          service.handleHistoricalEventForTesting(
            _videoEvent(id: 'b' * 64, hashtag: 'divineuniversity'),
            SubscriptionType.hashtag,
          );

          expect(
            service.getVideos(SubscriptionType.hashtag).map((v) => v.id),
            ['b' * 64],
          );
        },
      );

      test('realtime and pagination agree for the same event and filter', () {
        service.setActiveHashtagFilterForTesting(
          SubscriptionType.hashtag,
          ['DivineUniversity'],
        );

        service.handleEventForTesting(
          _videoEvent(id: 'c' * 64, hashtag: 'divineuniversity'),
          SubscriptionType.hashtag,
        );
        service.handleHistoricalEventForTesting(
          _videoEvent(id: 'd' * 64, hashtag: 'divineuniversity'),
          SubscriptionType.hashtag,
        );

        expect(
          service.getVideos(SubscriptionType.hashtag).map((v) => v.id),
          containsAll(['c' * 64, 'd' * 64]),
        );
      });

      test('a genuinely unrelated hashtag is still rejected on both paths', () {
        service.setActiveHashtagFilterForTesting(
          SubscriptionType.hashtag,
          ['DivineUniversity'],
        );

        service.handleEventForTesting(
          _videoEvent(id: 'e' * 64, hashtag: 'cats'),
          SubscriptionType.hashtag,
        );
        service.handleHistoricalEventForTesting(
          _videoEvent(id: 'f' * 64, hashtag: 'cats'),
          SubscriptionType.hashtag,
        );

        expect(service.getVideos(SubscriptionType.hashtag), isEmpty);
      });
    });
  });
}

// ABOUTME: Tests the deletion side-channel — removeVideoCompletely fires on
// the removedVideoIds broadcast stream so subscribers (FullscreenFeedBloc,
// profileFeedProvider) can drop the id without waiting for a route change.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockNostrClient extends Mock implements NostrClient {}

VideoEvent _videoEvent({
  required String id,
  required String pubkey,
  required String dTag,
}) {
  final event =
      Event(
          pubkey,
          34236,
          [
            ['d', dTag],
            ['url', 'https://example.com/$id.mp4'],
          ],
          'test video',
          createdAt: 1000,
        )
        ..id = id
        ..sig = 'sig-$id';
  return VideoEvent.fromNostrEvent(event);
}

Event _deletionEvent({
  required String id,
  required String pubkey,
  required List<List<String>> tags,
}) {
  return Event(pubkey, 5, tags, 'delete', createdAt: 1001)
    ..id = id
    ..sig = 'sig-$id';
}

void main() {
  setUpAll(() {
    registerFallbackValue(<Filter>[]);
  });

  group('VideoEventService.removedVideoIds', () {
    late VideoEventService service;
    late _MockNostrClient nostrClient;

    setUp(() {
      nostrClient = _MockNostrClient();
      when(() => nostrClient.isInitialized).thenReturn(true);
      when(() => nostrClient.connectedRelayCount).thenReturn(1);
      when(() => nostrClient.publicKey).thenReturn(
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      );
      when(
        () => nostrClient.subscribe(any()),
      ).thenAnswer((_) => const Stream<Event>.empty());

      service = VideoEventService(
        nostrClient,
        crashReporter: const SilentCrashReporter(),
      );
    });

    tearDown(() {
      service.dispose();
    });

    test('removeVideoCompletely emits the id on the bus', () async {
      final emitted = <String>[];
      final sub = service.removedVideoIds.listen(emitted.add);

      service.removeVideoCompletely('vid-1');
      await Future<void>.delayed(Duration.zero);

      expect(emitted, equals(['vid-1']));
      await sub.cancel();
    });

    test('emits even when the video was not in any active feed', () async {
      // Mirrors the log line "Video ... marked as deleted (was not in any
      // active feeds)" — the side-channel must still fire so a fullscreen
      // bloc holding the id in its own list drops it.
      final emitted = <String>[];
      final sub = service.removedVideoIds.listen(emitted.add);

      service.removeVideoCompletely('phantom');
      await Future<void>.delayed(Duration.zero);

      expect(emitted, equals(['phantom']));
      await sub.cancel();
    });

    test('notifies listeners when the video was not in any active feed', () {
      var notifyCount = 0;
      service.addListener(() => notifyCount++);

      service.removeVideoCompletely('phantom');

      expect(notifyCount, 1);
    });

    test('emits one event per call, in dispatch order', () async {
      final emitted = <String>[];
      final sub = service.removedVideoIds.listen(emitted.add);

      service
        ..removeVideoCompletely('a')
        ..removeVideoCompletely('b')
        ..removeVideoCompletely('c');
      await Future<void>.delayed(Duration.zero);

      expect(emitted, equals(['a', 'b', 'c']));
      await sub.cancel();
    });

    test('broadcast: a late subscriber misses past emits but receives '
        'future emits', () async {
      final earlyEmits = <String>[];
      final lateEmits = <String>[];

      final earlySub = service.removedVideoIds.listen(earlyEmits.add);
      service.removeVideoCompletely('past');
      await Future<void>.delayed(Duration.zero);

      final lateSub = service.removedVideoIds.listen(lateEmits.add);
      service.removeVideoCompletely('future');
      await Future<void>.delayed(Duration.zero);

      expect(earlyEmits, equals(['past', 'future']));
      expect(lateEmits, equals(['future']));

      await earlySub.cancel();
      await lateSub.cancel();
    });

    test(
      'addressable removal emits requested id when only a sibling is cached',
      () async {
        const pubkey =
            'c3dd74d68e414f0305db9f7dc96ec32e616502e6ccf5bbf5739de19a96b67f3e';
        final emitted = <String>[];
        final sub = service.removedVideoIds.listen(emitted.add);

        final deletedVideo = _videoEvent(
          id: 'held-fullscreen-id',
          pubkey: pubkey,
          dTag: 'shared-vine-id',
        );
        final cachedSibling = _videoEvent(
          id: 'cached-replacement-id',
          pubkey: pubkey,
          dTag: 'shared-vine-id',
        );

        service.addVideoEventForTesting(
          cachedSibling,
          SubscriptionType.discovery,
          isHistorical: false,
        );

        service.removeVideoEventCompletely(deletedVideo);
        await Future<void>.delayed(Duration.zero);

        expect(emitted, contains('held-fullscreen-id'));
        expect(emitted, contains('cached-replacement-id'));
        await sub.cancel();
      },
    );

    test('isVideoLocallyDeleted reflects the tombstone after emit', () {
      service.removeVideoCompletely('vid-1');
      expect(service.isVideoLocallyDeleted('vid-1'), isTrue);
      expect(service.isVideoLocallyDeleted('vid-2'), isFalse);
    });

    test(
      'observed author deletion removes a matching cached profile video',
      () async {
        const author =
            'c3dd74d68e414f0305db9f7dc96ec32e616502e6ccf5bbf5739de19a96b67f3e';
        const videoId =
            '1111111111111111111111111111111111111111111111111111111111111111';
        const deletionId =
            '2222222222222222222222222222222222222222222222222222222222222222';
        final emitted = <String>[];
        final sub = service.removedVideoIds.listen(emitted.add);

        final video = _videoEvent(
          id: videoId,
          pubkey: author,
          dTag: 'deleted-vine-id',
        );
        service.addVideoEventForTesting(
          video,
          SubscriptionType.profile,
          isHistorical: false,
        );

        service.handleEventForTesting(
          _deletionEvent(
            id: deletionId,
            pubkey: author,
            tags: [
              ['e', videoId],
              ['k', '34236'],
            ],
          ),
          SubscriptionType.profile,
        );
        await Future<void>.delayed(Duration.zero);

        expect(service.authorVideos(author), isEmpty);
        expect(service.isVideoKnownDeleted(videoId), isTrue);
        expect(emitted, contains(videoId));
        await sub.cancel();
      },
    );

    test('observed deletion from a different pubkey is ignored', () async {
      const author =
          'c3dd74d68e414f0305db9f7dc96ec32e616502e6ccf5bbf5739de19a96b67f3e';
      const attacker =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const videoId =
          '3333333333333333333333333333333333333333333333333333333333333333';
      const deletionId =
          '4444444444444444444444444444444444444444444444444444444444444444';
      final emitted = <String>[];
      final sub = service.removedVideoIds.listen(emitted.add);

      final video = _videoEvent(
        id: videoId,
        pubkey: author,
        dTag: 'protected-vine-id',
      );
      service.addVideoEventForTesting(
        video,
        SubscriptionType.profile,
        isHistorical: false,
      );

      service.handleEventForTesting(
        _deletionEvent(
          id: deletionId,
          pubkey: attacker,
          tags: [
            ['e', videoId],
            ['a', '34236:$author:protected-vine-id'],
            ['k', '34236'],
          ],
        ),
        SubscriptionType.profile,
      );
      await Future<void>.delayed(Duration.zero);

      expect(service.authorVideos(author).map((v) => v.id), contains(videoId));
      expect(service.isVideoKnownDeleted(videoId), isFalse);
      expect(emitted, isEmpty);
      await sub.cancel();
    });

    test(
      'observed addressable deletion tombstones replacement event ids',
      () async {
        const author =
            'c3dd74d68e414f0305db9f7dc96ec32e616502e6ccf5bbf5739de19a96b67f3e';
        const olderId =
            '5555555555555555555555555555555555555555555555555555555555555555';
        const replacementId =
            '6666666666666666666666666666666666666666666666666666666666666666';
        const deletionId =
            '7777777777777777777777777777777777777777777777777777777777777777';
        final emitted = <String>[];
        final sub = service.removedVideoIds.listen(emitted.add);

        final older = _videoEvent(
          id: olderId,
          pubkey: author,
          dTag: 'same-addressable-video',
        );
        final replacement = _videoEvent(
          id: replacementId,
          pubkey: author,
          dTag: 'same-addressable-video',
        );
        service
          ..addVideoEventForTesting(
            older,
            SubscriptionType.profile,
            isHistorical: false,
          )
          ..addVideoEventForTesting(
            replacement,
            SubscriptionType.discovery,
            isHistorical: false,
          );

        service.handleEventForTesting(
          _deletionEvent(
            id: deletionId,
            pubkey: author,
            tags: [
              ['a', '34236:$author:same-addressable-video'],
              ['k', '34236'],
            ],
          ),
          SubscriptionType.profile,
        );
        await Future<void>.delayed(Duration.zero);

        expect(service.authorVideos(author), isEmpty);
        expect(service.isVideoEventKnownDeleted(older), isTrue);
        expect(service.isVideoEventKnownDeleted(replacement), isTrue);
        expect(emitted, containsAll(<String>[olderId, replacementId]));
        await sub.cancel();
      },
    );

    test('dispose closes the stream', () async {
      final sub = service.removedVideoIds.listen((_) {});
      service.dispose();
      // Re-create for tearDown safety — overrides the field.
      service = VideoEventService(
        nostrClient,
        crashReporter: const SilentCrashReporter(),
      );
      // The original subscription should complete cleanly.
      await sub.cancel();
    });
  });
}

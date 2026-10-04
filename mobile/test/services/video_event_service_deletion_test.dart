// ABOUTME: Tests the deletion side-channel — removeVideoCompletely fires on
// the removedVideoIds broadcast stream so subscribers (FullscreenFeedBloc,
// profileFeedProvider) can drop the id without waiting for a route change.

import 'package:async/async.dart';
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
      final removal = expectLater(service.removedVideoIds, emits('vid-1'));

      service.removeVideoCompletely('vid-1');

      await removal;
    });

    test('emits even when the video was not in any active feed', () async {
      // Mirrors the log line "Video ... marked as deleted (was not in any
      // active feeds)" — the side-channel must still fire so a fullscreen
      // bloc holding the id in its own list drops it.
      final removal = expectLater(service.removedVideoIds, emits('phantom'));

      service.removeVideoCompletely('phantom');

      await removal;
    });

    test('notifies listeners when the video was not in any active feed', () {
      var notifyCount = 0;
      service.addListener(() => notifyCount++);

      service.removeVideoCompletely('phantom');

      expect(notifyCount, 1);
    });

    test('emits one event per call, in dispatch order', () async {
      final removals = expectLater(
        service.removedVideoIds,
        emitsInOrder(['a', 'b', 'c']),
      );

      service
        ..removeVideoCompletely('a')
        ..removeVideoCompletely('b')
        ..removeVideoCompletely('c');

      await removals;
    });

    test('broadcast: a late subscriber misses past emits but receives '
        'future emits', () async {
      final early = StreamQueue(service.removedVideoIds);
      addTearDown(early.cancel);
      final past = early.next;
      service.removeVideoCompletely('past');
      expect(await past, 'past');

      final late = StreamQueue(service.removedVideoIds);
      addTearDown(late.cancel);
      final earlyFuture = early.next;
      final lateFuture = late.next;
      service.removeVideoCompletely('future');

      expect(await earlyFuture, 'future');
      expect(await lateFuture, 'future');
    });

    test(
      'addressable removal emits requested id when only a sibling is cached',
      () async {
        const pubkey =
            'c3dd74d68e414f0305db9f7dc96ec32e616502e6ccf5bbf5739de19a96b67f3e';
        final removal = expectLater(
          service.removedVideoIds,
          emitsInAnyOrder(['held-fullscreen-id', 'cached-replacement-id']),
        );

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
        await removal;
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
        final removal = expectLater(service.removedVideoIds, emits(videoId));

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
        await removal;

        expect(service.authorVideos(author), isEmpty);
        expect(service.isVideoKnownDeleted(videoId), isTrue);
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
      addTearDown(sub.cancel);

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
      await pumpEventQueue();

      expect(service.authorVideos(author).map((v) => v.id), contains(videoId));
      expect(service.isVideoKnownDeleted(videoId), isFalse);
      expect(emitted, isEmpty);
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
        final removal = expectLater(
          service.removedVideoIds,
          emitsInAnyOrder([olderId, replacementId]),
        );

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
        await removal;

        expect(service.authorVideos(author), isEmpty);
        expect(service.isVideoEventKnownDeleted(older), isTrue);
        expect(service.isVideoEventKnownDeleted(replacement), isTrue);
      },
    );

    test('dispose closes the stream', () async {
      final closed = expectLater(service.removedVideoIds, emitsDone);
      service.dispose();
      // Re-create for tearDown safety — overrides the field.
      service = VideoEventService(
        nostrClient,
        crashReporter: const SilentCrashReporter(),
      );
      await closed;
    });
  });
}

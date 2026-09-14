// ABOUTME: Unit tests for VideoEventService.removeVideoCompletely() method
// ABOUTME: Tests comprehensive video removal from all data structures (issue #270)

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/video_event_service.dart';

// Mock classes
class _MockNostrService extends Mock implements NostrClient {}

class _FakeFilter extends Fake implements Filter {}

VideoEvent _videoEvent({
  required String id,
  required String pubkey,
  required String dTag,
  int createdAt = 1000,
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
          createdAt: createdAt,
        )
        ..id = id
        ..sig = 'sig-$id';
  return VideoEvent.fromNostrEvent(event);
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeFilter());
    registerFallbackValue(<Filter>[]);
  });

  group('VideoEventService.removeVideoCompletely()', () {
    late VideoEventService videoEventService;
    late _MockNostrService mockNostrService;
    late StreamController<Event> eventStreamController;

    setUp(() {
      mockNostrService = _MockNostrService();
      eventStreamController = StreamController<Event>.broadcast();

      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockNostrService.connectedRelayCount).thenReturn(1);
      when(
        () => mockNostrService.subscribe(any()),
      ).thenAnswer((_) => eventStreamController.stream);

      videoEventService = VideoEventService(
        mockNostrService,
        crashReporter: const SilentCrashReporter(),
      );
    });

    tearDown(() async {
      await eventStreamController.close();
      reset(mockNostrService);
    });

    test('marks video as locally deleted in VideoEventService', () {
      const videoId = 'test-video-id-local-delete';

      // Remove a video
      videoEventService.removeVideoCompletely(videoId);

      // Verify video is marked as locally deleted
      expect(videoEventService.isVideoLocallyDeleted(videoId), isTrue);
    });

    test('handles non-existent video gracefully without throwing', () {
      const videoId = 'non-existent-video-id';

      // Should not throw
      expect(
        () => videoEventService.removeVideoCompletely(videoId),
        returnsNormally,
      );

      // Video should still be marked as locally deleted
      expect(videoEventService.isVideoLocallyDeleted(videoId), isTrue);
    });

    test(
      'deprecated removeVideoFromAuthorList delegates to removeVideoCompletely',
      () {
        const videoId = 'test-video-deprecated';
        const pubkey =
            'c3dd74d68e414f0305db9f7dc96ec32e616502e6ccf5bbf5739de19a96b67f3e';

        // Call deprecated method
        // ignore: deprecated_member_use_from_same_package
        videoEventService.removeVideoFromAuthorList(pubkey, videoId);

        // Verify video is marked as deleted (proves delegation happened)
        expect(videoEventService.isVideoLocallyDeleted(videoId), isTrue);
      },
    );

    test(
      'prevents resurrection of deleted videos via isVideoLocallyDeleted',
      () {
        const videoId = 'test-video-resurrection';

        // Initially not deleted
        expect(videoEventService.isVideoLocallyDeleted(videoId), isFalse);

        // Delete the video
        videoEventService.removeVideoCompletely(videoId);

        // Now marked as deleted
        expect(videoEventService.isVideoLocallyDeleted(videoId), isTrue);

        // This check is used during pagination to filter out deleted videos
        // ensuring they don't "resurrect" when new data loads
      },
    );

    test('tombstones replacement event ids for the same addressable video', () {
      const pubkey =
          'c3dd74d68e414f0305db9f7dc96ec32e616502e6ccf5bbf5739de19a96b67f3e';
      final deletedVideo = _videoEvent(
        id: 'event-id-before-delete',
        pubkey: pubkey,
        dTag: 'shared-vine-id',
      );
      final replacementVersion = _videoEvent(
        id: 'event-id-after-delete',
        pubkey: pubkey,
        dTag: 'shared-vine-id',
        createdAt: 1001,
      );
      final unrelatedVideo = _videoEvent(
        id: 'unrelated-event-id',
        pubkey: pubkey,
        dTag: 'different-vine-id',
      );

      videoEventService.removeVideoEventCompletely(deletedVideo);

      expect(videoEventService.isVideoLocallyDeleted(deletedVideo.id), isTrue);
      expect(
        videoEventService.isVideoEventLocallyDeleted(replacementVersion),
        isTrue,
      );
      expect(
        videoEventService.isVideoEventLocallyDeleted(unrelatedVideo),
        isFalse,
      );
    });

    test('seedLocalDeletionTombstones hydrates event id tombstones', () {
      videoEventService.seedLocalDeletionTombstones(
        eventIds: const ['deleted-event-id'],
      );

      expect(videoEventService.isVideoLocallyDeleted('deleted-event-id'), true);
      expect(videoEventService.isVideoLocallyDeleted('other-event-id'), false);
    });

    test('seedLocalDeletionTombstones converts persisted addressable ids to '
        'local coordinate keys', () {
      const pubkey =
          'C3DD74D68E414F0305DB9F7DC96EC32E616502E6CCF5BBF5739DE19A96B67F3E';
      const dTag = 'shared:vine:id';
      final replacementVersion = _videoEvent(
        id: 'event-id-after-restart',
        pubkey: pubkey.toLowerCase(),
        dTag: dTag,
        createdAt: 1001,
      );
      final unrelatedVideo = _videoEvent(
        id: 'unrelated-event-id',
        pubkey: pubkey.toLowerCase(),
        dTag: 'different-vine-id',
      );

      videoEventService.seedLocalDeletionTombstones(
        addressableDeletedAt: const {'34236:$pubkey:$dTag': 2000},
      );

      expect(
        videoEventService.isVideoEventLocallyDeleted(replacementVersion),
        isTrue,
      );
      expect(
        videoEventService.isVideoEventLocallyDeleted(unrelatedVideo),
        isFalse,
      );
    });

    test(
      'seedLocalDeletionTombstones ignores unsupported addressable kinds',
      () {
        const pubkey =
            'c3dd74d68e414f0305db9f7dc96ec32e616502e6ccf5bbf5739de19a96b67f3e';
        final video = _videoEvent(
          id: 'not-deleted',
          pubkey: pubkey,
          dTag: 'shared-vine-id',
        );

        videoEventService.seedLocalDeletionTombstones(
          addressableDeletedAt: const {'30023:$pubkey:shared-vine-id': 2000},
        );

        expect(videoEventService.isVideoEventLocallyDeleted(video), isFalse);
      },
    );

    test('a coordinate tombstone only covers versions up to its timestamp', () {
      const pubkey =
          'c3dd74d68e414f0305db9f7dc96ec32e616502e6ccf5bbf5739de19a96b67f3e';
      const dTag = 'shared-vine-id';
      // Default created_at (1000) predates the deletion seeded below (2000).
      final deletedVersion = _videoEvent(
        id: 'version-before-deletion',
        pubkey: pubkey,
        dTag: dTag,
      );
      final republishedVersion = _videoEvent(
        id: 'version-after-deletion',
        pubkey: pubkey,
        dTag: dTag,
        createdAt: 5000,
      );

      videoEventService.seedLocalDeletionTombstones(
        addressableDeletedAt: const {'34236:$pubkey:$dTag': 2000},
      );

      expect(
        videoEventService.isVideoEventKnownDeleted(deletedVersion),
        isTrue,
      );
      expect(
        videoEventService.isVideoEventKnownDeleted(republishedVersion),
        isFalse,
        reason: 'NIP-09 scopes an `a` deletion to its own created_at',
      );
    });

    test('a second, older deletion does not lower the coordinate bound', () {
      const pubkey =
          'c3dd74d68e414f0305db9f7dc96ec32e616502e6ccf5bbf5739de19a96b67f3e';
      const dTag = 'shared-vine-id';
      final coveredVersion = _videoEvent(
        id: 'version-between-deletions',
        pubkey: pubkey,
        dTag: dTag,
        createdAt: 5000,
      );

      // Relays serve deletion requests indefinitely, so a cold-start flood can
      // deliver an old Kind 5 after a newer one for the same coordinate. The
      // newest bound has to win, or the version between them reappears.
      videoEventService.seedLocalDeletionTombstones(
        addressableDeletedAt: const {'34236:$pubkey:$dTag': 6000},
      );
      videoEventService.seedLocalDeletionTombstones(
        addressableDeletedAt: const {'34236:$pubkey:$dTag': 2000},
      );

      expect(
        videoEventService.isVideoEventKnownDeleted(coveredVersion),
        isTrue,
        reason: 'the older redelivery must not un-cover the 6000 deletion',
      );
    });
  });
}

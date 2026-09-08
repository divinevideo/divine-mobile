// ABOUTME: Tests that VideoEventService passes addressable IDs through to
// ABOUTME: getLikeCounts so reactions on replaced videos are counted correctly.

import 'package:flutter_test/flutter_test.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' hide NIP71VideoKinds;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart' as sdk;
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockSubscriptionManager extends Mock implements SubscriptionManager {}

class _MockLikesRepository extends Mock implements LikesRepository {}

void main() {
  group('VideoEventService - like count addressable ID wiring', () {
    const pubkey =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    const videoUrl = 'https://example.com/video.mp4';

    late _MockNostrClient mockNostrClient;
    late _MockSubscriptionManager mockSubscriptionManager;
    late _MockLikesRepository mockLikesRepository;
    late VideoEventService service;

    setUp(() {
      mockNostrClient = _MockNostrClient();
      mockSubscriptionManager = _MockSubscriptionManager();
      mockLikesRepository = _MockLikesRepository();

      when(() => mockNostrClient.isInitialized).thenReturn(true);
      when(() => mockNostrClient.publicKey).thenReturn('');
      when(
        () => mockLikesRepository.getLikeCounts(
          any(),
          addressableIds: any(named: 'addressableIds'),
        ),
      ).thenAnswer((_) async => {});

      service = VideoEventService(
        mockNostrClient,
        subscriptionManager: mockSubscriptionManager,
        crashReporter: const SilentCrashReporter(),
      );
      service.setLikesRepository(mockLikesRepository);
    });

    tearDown(() {
      service.dispose();
    });

    sdk.Event makeEvent(
      String dTag, {
      int createdAt = 1000,
      int kind = NIP71VideoKinds.addressableShortVideo,
      bool includeDTag = true,
    }) => sdk.Event(
      pubkey,
      kind,
      [
        if (includeDTag) ['d', dTag],
        ['url', videoUrl],
        ['title', 'Test'],
      ],
      '',
      createdAt: createdAt,
    )..id = '$kind-$dTag-$createdAt';

    test(
      '_fetchAndUpdateLikeCount populates addressable IDs and passes them to getLikeCounts',
      () async {
        final targetEvent = makeEvent('target-vine');
        service.handleEventForTesting(targetEvent, SubscriptionType.discovery);

        await service.flushPendingLikeCountBatchForTesting();

        final captured = verify(
          () => mockLikesRepository.getLikeCounts(
            any(),
            addressableIds: captureAny(named: 'addressableIds'),
          ),
        ).captured;

        // The captured value is the addressableIds map passed to getLikeCounts.
        // The map is keyed by current event ID even when the lookup also fans
        // out across prior edited versions via addressable IDs.
        final addressableIds = captured.first as Map<String, String>?;
        expect(
          addressableIds,
          isNotNull,
          reason: 'addressableIds should be non-null for a batch containing a kind 34236 video',
        );

        final targetVideo = VideoEvent.fromNostrEvent(targetEvent);
        expect(
          addressableIds!.containsKey(targetVideo.id),
          isTrue,
          reason:
              'The target video event ID should be present in addressableIds',
        );
        expect(
          addressableIds[targetVideo.id],
          equals(targetVideo.addressableId),
          reason: 'The addressable ID should be the kind:pubkey:d-tag string from the video',
        );
      },
    );

    test(
      'addressable ID value has the correct kind:pubkey:d-tag format',
      () async {
        const dTag = 'my-special-vine';

        final targetEvent = makeEvent(dTag);
        service.handleEventForTesting(targetEvent, SubscriptionType.discovery);

        await service.flushPendingLikeCountBatchForTesting();

        final captured = verify(
          () => mockLikesRepository.getLikeCounts(
            any(),
            addressableIds: captureAny(named: 'addressableIds'),
          ),
        ).captured;

        final addressableIds = captured.first as Map<String, String>?;
        expect(addressableIds, isNotNull);

        final targetVideo = VideoEvent.fromNostrEvent(targetEvent);
        final aId = addressableIds![targetVideo.id];
        expect(
          aId,
          equals('${NIP71VideoKinds.addressableShortVideo}:$pubkey:$dTag'),
          reason: 'Addressable ID should be kind:pubkey:d-tag',
        );
      },
    );

    test(
      '_applyLikeCountToVideo direct-replaces the cached count, including '
      'lowering it (#6102 review)',
      () async {
        final event = makeEvent('merge-vine');
        service.handleEventForTesting(event, SubscriptionType.discovery);
        final video = VideoEvent.fromNostrEvent(event);

        int? cachedLikeCount() => service.discoveryVideos
            .firstWhere((v) => v.id == video.id)
            .nostrLikeCount;

        // First resolve applies null -> 10.
        expect(
          service.applyLikeCountForTesting(
            video.id,
            10,
            SubscriptionType.discovery,
          ),
          isTrue,
        );
        expect(cachedLikeCount(), 10);

        // A later, lower resolve DOES lower the cached count — nostrLikeCount
        // is a live relay-derived count that legitimately decreases (e.g.
        // after the user's own unlike decrements LikesRepository's count
        // cache, or a reaction is deleted), so a max-merge floor here would
        // wrongly freeze it at the session high. #6022's addressable floor
        // is applied once, in VideoInteractionsBloc._onFetchRequested,
        // independent of this cache.
        service.applyLikeCountForTesting(
          video.id,
          4,
          SubscriptionType.discovery,
        );
        expect(cachedLikeCount(), 4);

        // A higher resolve still raises it.
        service.applyLikeCountForTesting(
          video.id,
          15,
          SubscriptionType.discovery,
        );
        expect(cachedLikeCount(), 15);
      },
    );

    test(
      'non-addressable videos are omitted from the addressableIds batch map',
      () async {
        final addressableEvent = makeEvent('addressable-vine');
        final nonAddressableEvent = makeEvent(
          'legacy-vine',
          kind: NIP71VideoKinds.shortVideo,
          includeDTag: false,
        );

        service.handleEventForTesting(
          addressableEvent,
          SubscriptionType.discovery,
        );
        service.handleEventForTesting(
          nonAddressableEvent,
          SubscriptionType.discovery,
        );

        await service.flushPendingLikeCountBatchForTesting();

        final captured = verify(
          () => mockLikesRepository.getLikeCounts(
            any(),
            addressableIds: captureAny(named: 'addressableIds'),
          ),
        ).captured;

        final addressableIds = captured.first as Map<String, String>?;
        final addressableVideo = VideoEvent.fromNostrEvent(addressableEvent);

        expect(addressableIds, isNotNull);
        expect(addressableIds!.containsKey(addressableVideo.id), isTrue);
        expect(addressableIds.containsKey(nonAddressableEvent.id), isFalse);
      },
    );
  });
}

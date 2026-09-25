// ABOUTME: Covers VideoEventPublisher's scheduled-post path (#3538): the
// ABOUTME: event is signed for the publish time, handed back, and never
// ABOUTME: broadcast, cached or reused.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show VideoEvent;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/exceptions/video_exceptions.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_event_publisher.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockUploadManager extends Mock implements UploadManager {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockPersonalEventCacheService extends Mock
    implements PersonalEventCacheService {}

class _FakeEvent extends Fake implements Event {}

class _FakeVideoEvent extends Fake implements VideoEvent {}

void main() {
  group('VideoEventPublisher scheduled posts', () {
    late _MockUploadManager uploadManager;
    late _MockNostrClient nostrClient;
    late _MockAuthService authService;
    late _MockVideoEventService videoEventService;
    late _MockPersonalEventCacheService personalEventCache;
    late VideoEventPublisher publisher;

    const testPubkey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    final scheduledAt = DateTime.utc(2026, 10, 1, 9);
    final scheduledSecs = scheduledAt.millisecondsSinceEpoch ~/ 1000;

    setUpAll(() {
      registerFallbackValue(_FakeEvent());
      registerFallbackValue(_FakeVideoEvent());
      registerFallbackValue(UploadStatus.pending);
      registerFallbackValue(File(''));
      registerFallbackValue(Duration.zero);
    });

    // Construction only. The stubs live in a named helper each leaf group
    // installs for itself, so no decision is inherited across groups (#8399).
    setUp(() {
      uploadManager = _MockUploadManager();
      nostrClient = _MockNostrClient();
      authService = _MockAuthService();
      videoEventService = _MockVideoEventService();
      personalEventCache = _MockPersonalEventCacheService();

      publisher = VideoEventPublisher(
        uploadManager: uploadManager,
        nostrService: nostrClient,
        authService: authService,
        videoEventService: videoEventService,
        personalEventCache: personalEventCache,
      );
    });

    /// A signed-in account with a connected relay and a quiet local cache —
    /// the ordinary state every test here starts from.
    void stubSignedInWithRelay() {
      when(() => nostrClient.isInitialized).thenReturn(true);
      when(() => nostrClient.configuredRelayCount).thenReturn(1);
      when(() => nostrClient.connectedRelayCount).thenReturn(1);
      when(
        () => nostrClient.configuredRelays,
      ).thenReturn(const ['wss://relay.divine.video']);
      when(
        () => nostrClient.connectedRelays,
      ).thenReturn(const ['wss://relay.divine.video']);
      when(() => nostrClient.publicKey).thenReturn(testPubkey);
      when(() => authService.isAuthenticated).thenReturn(true);
      when(() => authService.currentPublicKeyHex).thenReturn(testPubkey);
      when(
        () => uploadManager.updateUploadStatus(
          any(),
          any(),
          nostrEventId: any(named: 'nostrEventId'),
        ),
      ).thenAnswer((_) async {});
      when(() => personalEventCache.cacheUserEvent(any())).thenReturn(null);
      when(() => personalEventCache.getEventById(any())).thenReturn(null);
      when(() => videoEventService.addVideoEvent(any())).thenReturn(null);
    }

    PendingUpload createUpload({String? nostrEventId}) => PendingUpload(
      id: 'upload-id',
      localVideoPath: '',
      nostrPubkey: testPubkey,
      status: UploadStatus.readyToPublish,
      createdAt: DateTime.now(),
      videoId: 'video-id',
      title: 'Plants',
      cdnUrl: 'https://cdn.example.com/video.mp4',
      fallbackUrl: 'https://cdn.example.com/video.mp4',
      nostrEventId: nostrEventId,
    );

    /// Signs like a well-behaved signer: honours the requested `created_at`.
    List<Event> stubSigning({int? forcedCreatedAt}) {
      final signed = <Event>[];
      when(
        () => authService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
          createdAt: any(named: 'createdAt'),
        ),
      ).thenAnswer((invocation) async {
        final tags = invocation.namedArguments[#tags] as List<List<String>>;
        final createdAt = invocation.namedArguments[#createdAt] as int?;
        final event = Event(
          testPubkey,
          NIP71VideoKinds.getPreferredAddressableKind(),
          tags,
          invocation.namedArguments[#content] as String,
          createdAt: forcedCreatedAt ?? createdAt,
        );
        signed.add(event);
        return event;
      });
      return signed;
    }

    String? tagValue(Event event, String name) {
      for (final tag in event.tags) {
        if (tag.isNotEmpty && tag[0] == name) return tag[1];
      }
      return null;
    }

    group('publishVideoEvent', () {
      setUp(stubSignedInWithRelay);

      test(
        'signs for the publish time, hands the event back and stops there',
        () async {
          final signed = stubSigning();
          Event? handedOff;
          var signedSteps = 0;

          final result = await publisher.publishVideoEvent(
            upload: createUpload(),
            scheduledAt: scheduledAt,
            expirationTimestamp: scheduledSecs + 86400,
            onEventSigned: () => signedSteps++,
            onScheduledEventSigned: (event) => handedOff = event,
          );

          expect(result, isTrue);
          expect(signedSteps, 1);
          expect(handedOff, isNotNull);
          expect(handedOff, same(signed.single));
          expect(handedOff!.createdAt, scheduledSecs);
          expect(tagValue(handedOff!, 'published_at'), '$scheduledSecs');
          expect(
            tagValue(handedOff!, 'expiration'),
            '${scheduledSecs + 86400}',
          );
          expect(tagValue(handedOff!, 'd'), 'video-id');

          // Not broadcast, not cached for retry, not recorded as published.
          verifyNever(
            () => nostrClient.publishEventAwaitOk(
              any(),
              timeout: any(named: 'timeout'),
            ),
          );
          verifyNever(() => personalEventCache.cacheUserEvent(any()));
          verifyNever(
            () => uploadManager.updateUploadStatus(
              any(),
              any(),
              nostrEventId: any(named: 'nostrEventId'),
            ),
          );
          verifyNever(() => videoEventService.addVideoEvent(any()));
        },
      );

      test('never reuses a cached retry event for a scheduled post', () async {
        final cached = Event(
          testPubkey,
          NIP71VideoKinds.getPreferredAddressableKind(),
          const [
            ['d', 'video-id'],
          ],
          'old',
          createdAt: 1700000000,
        );
        when(
          () => personalEventCache.getEventById(cached.id),
        ).thenReturn(cached);
        stubSigning();
        Event? handedOff;

        final result = await publisher.publishVideoEvent(
          upload: createUpload(nostrEventId: cached.id),
          scheduledAt: scheduledAt,
          onScheduledEventSigned: (event) => handedOff = event,
        );

        expect(result, isTrue);
        expect(handedOff!.id, isNot(cached.id));
        expect(handedOff!.createdAt, scheduledSecs);
        verifyNever(() => personalEventCache.getEventById(any()));
      });

      test('refuses an event whose signer moved created_at', () async {
        stubSigning(forcedCreatedAt: 1700000000);
        var handedOff = false;

        await expectLater(
          publisher.publishVideoEvent(
            upload: createUpload(),
            scheduledAt: scheduledAt,
            onScheduledEventSigned: (_) => handedOff = true,
          ),
          throwsA(
            isA<ScheduledSignatureTimestampException>()
                .having(
                  (e) => e.requestedCreatedAt,
                  'requestedCreatedAt',
                  scheduledSecs,
                )
                .having(
                  (e) => e.signedCreatedAt,
                  'signedCreatedAt',
                  1700000000,
                ),
          ),
        );

        expect(handedOff, isFalse);
        verifyNever(
          () => nostrClient.publishEventAwaitOk(
            any(),
            timeout: any(named: 'timeout'),
          ),
        );
      });

      test('an immediate publish still signs with the current time', () async {
        final signed = stubSigning();
        when(
          () => nostrClient.publishEventAwaitOk(
            any(),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (invocation) async => PublishOutcome(
            eventId: (invocation.positionalArguments.first as Event).id,
            acceptedBy: const ['wss://relay.divine.video'],
            rejectedBy: const {},
            noResponseFrom: const [],
          ),
        );
        var handedOff = false;

        final result = await publisher.publishVideoEvent(
          upload: createUpload(),
          onScheduledEventSigned: (_) => handedOff = true,
        );

        expect(result, isTrue);
        expect(handedOff, isFalse);
        final nowSecs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        expect(signed.single.createdAt, closeTo(nowSecs, 120));
        verify(() => personalEventCache.cacheUserEvent(any())).called(1);
      });
    });

    group('recordScheduledPublish', () {
      setUp(stubSignedInWithRelay);

      Event heldEvent() => Event(
        testPubkey,
        NIP71VideoKinds.getPreferredAddressableKind(),
        const [
          ['d', 'video-id'],
          ['title', 'Plants'],
          ['imeta', 'url https://cdn.example.com/video.mp4'],
        ],
        'Plants',
        createdAt: scheduledSecs,
      );

      test('runs the confirmed-publish side effects with the upload', () async {
        final upload = createUpload();
        when(() => uploadManager.getUpload('upload-id')).thenReturn(upload);
        final event = heldEvent();

        await publisher.recordScheduledPublish(event, uploadId: 'upload-id');

        verify(
          () => uploadManager.updateUploadStatus(
            'upload-id',
            UploadStatus.published,
            nostrEventId: event.id,
          ),
        ).called(1);
        verify(() => videoEventService.addVideoEvent(any())).called(1);
        expect(publisher.publishingStats['total_published'], 1);
      });

      test('tolerates an upload that is already gone', () async {
        when(() => uploadManager.getUpload(any())).thenReturn(null);

        await publisher.recordScheduledPublish(
          heldEvent(),
          uploadId: 'vanished',
        );

        verifyNever(
          () => uploadManager.updateUploadStatus(
            any(),
            any(),
            nostrEventId: any(named: 'nostrEventId'),
          ),
        );
        verify(() => videoEventService.addVideoEvent(any())).called(1);
      });
    });
  });
}

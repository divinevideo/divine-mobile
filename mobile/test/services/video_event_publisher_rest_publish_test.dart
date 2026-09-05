// ABOUTME: Tests for VideoEventPublisher REST-first publish with WebSocket fallback
// ABOUTME: Covers REST accept, transient fallback, recovery, retry reuse, no-duplicate

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show VideoEvent;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/exceptions/video_exceptions.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/event_api_client.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_event_publisher.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockUploadManager extends Mock implements UploadManager {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _MockPersonalEventCacheService extends Mock
    implements PersonalEventCacheService {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockEventApiClient extends Mock implements EventApiClient {}

class _FakeEvent extends Fake implements Event {}

class _FakeVideoEvent extends Fake implements VideoEvent {}

void main() {
  const testPubkey =
      '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd';

  late _MockUploadManager mockUploadManager;
  late _MockNostrClient mockNostrClient;
  late _MockAuthService mockAuthService;
  late _MockPersonalEventCacheService mockPersonalEventCache;
  late _MockVideoEventService mockVideoEventService;
  late _MockEventApiClient mockEventApiClient;
  late VideoEventPublisher publisher;

  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(_FakeVideoEvent());
    registerFallbackValue(UploadStatus.pending);
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    mockUploadManager = _MockUploadManager();
    mockNostrClient = _MockNostrClient();
    mockAuthService = _MockAuthService();
    mockPersonalEventCache = _MockPersonalEventCacheService();
    mockVideoEventService = _MockVideoEventService();
    mockEventApiClient = _MockEventApiClient();

    publisher = VideoEventPublisher(
      uploadManager: mockUploadManager,
      nostrService: mockNostrClient,
      authService: mockAuthService,
      personalEventCache: mockPersonalEventCache,
      videoEventService: mockVideoEventService,
      eventApiClient: mockEventApiClient,
      trustedRelayUrl: 'wss://trusted.example',
    );

    when(() => mockAuthService.isAuthenticated).thenReturn(true);
    when(() => mockAuthService.currentPublicKeyHex).thenReturn(testPubkey);

    when(() => mockNostrClient.isInitialized).thenReturn(true);
    when(() => mockNostrClient.configuredRelayCount).thenReturn(1);
    when(() => mockNostrClient.connectedRelayCount).thenReturn(1);
    when(
      () => mockNostrClient.configuredRelays,
    ).thenReturn(const ['wss://relay.divine.video']);
    when(
      () => mockNostrClient.connectedRelays,
    ).thenReturn(const ['wss://relay.divine.video']);
    when(() => mockNostrClient.publicKey).thenReturn(testPubkey);

    // Recovery queries return nothing unless a test overrides this.
    when(
      () =>
          mockNostrClient.queryEvents(any(), useCache: any(named: 'useCache')),
    ).thenAnswer((_) async => <Event>[]);

    when(
      () => mockUploadManager.updateUploadStatus(
        any(),
        any(),
        nostrEventId: any(named: 'nostrEventId'),
      ),
    ).thenAnswer((_) async {});

    when(() => mockPersonalEventCache.cacheUserEvent(any())).thenReturn(null);
    when(() => mockPersonalEventCache.getEventById(any())).thenReturn(null);
    when(() => mockVideoEventService.addVideoEvent(any())).thenReturn(null);
  });

  PendingUpload createUpload() {
    return PendingUpload(
      id: 'test-upload-id',
      localVideoPath: '/tmp/test.mp4',
      nostrPubkey: testPubkey,
      status: UploadStatus.readyToPublish,
      createdAt: DateTime.now(),
      videoId: 'test-video-id',
      title: 'Plants',
      cdnUrl: 'https://cdn.example.com/video.mp4',
      fallbackUrl: 'https://cdn.example.com/video.mp4',
    );
  }

  Event createSignedEvent() {
    return Event(
      testPubkey,
      NIP71VideoKinds.getPreferredAddressableKind(),
      const [
        ['d', 'test-video-id'],
        ['title', 'Plants'],
        ['imeta', 'url https://cdn.example.com/video.mp4', 'm video/mp4'],
      ],
      'A plant video',
      createdAt: 1700000000,
    );
  }

  void stubSigning(Event event) {
    when(
      () => mockAuthService.createAndSignEvent(
        kind: any(named: 'kind'),
        content: any(named: 'content'),
        tags: any(named: 'tags'),
      ),
    ).thenAnswer((_) async => event);
  }

  void stubRest(EventApiPublishResult result) {
    when(
      () => mockEventApiClient.publishEvent(any()),
    ).thenAnswer((_) async => result);
  }

  void stubWebSocket(PublishOutcome outcome) {
    when(
      () => mockNostrClient.publishEventAwaitOk(
        any(),
        timeout: any(named: 'timeout'),
      ),
    ).thenAnswer((_) async => outcome);
  }

  group('VideoEventPublisher REST-first publish', () {
    test('REST 200 acceptance marks the upload published', () async {
      final signedEvent = createSignedEvent();
      stubSigning(signedEvent);
      stubRest(const EventApiAccepted('server-event-id'));

      final result = await publisher.publishDirectUpload(createUpload());

      expect(result, isTrue);
      verify(() => mockEventApiClient.publishEvent(any())).called(1);
      verify(
        () => mockUploadManager.updateUploadStatus(
          'test-upload-id',
          UploadStatus.published,
          nostrEventId: signedEvent.id,
        ),
      ).called(1);
      // REST succeeded — no WebSocket fallback.
      verifyNever(
        () => mockNostrClient.publishEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
        ),
      );
    });

    test(
      'REST transient failure falls back to WebSocket send success',
      () async {
        final signedEvent = createSignedEvent();
        stubSigning(signedEvent);
        stubRest(const EventApiTransientFailure('http_503'));
        stubWebSocket(
          PublishOutcome(
            eventId: signedEvent.id,
            acceptedBy: const ['wss://trusted.example'],
            rejectedBy: const {},
            noResponseFrom: const [],
          ),
        );

        final result = await publisher.publishDirectUpload(createUpload());

        expect(result, isTrue);
        verify(() => mockEventApiClient.publishEvent(any())).called(1);
        verify(
          () => mockNostrClient.publishEventAwaitOk(
            signedEvent,
            timeout: any(named: 'timeout'),
          ),
        ).called(1);
        verify(
          () => mockUploadManager.updateUploadStatus(
            'test-upload-id',
            UploadStatus.published,
            nostrEventId: signedEvent.id,
          ),
        ).called(1);
      },
    );

    test('REST rejection falls back to WebSocket acceptance', () async {
      final signedEvent = createSignedEvent();
      stubSigning(signedEvent);
      stubRest(const EventApiRejected(statusCode: 422, reason: 'bad event'));
      stubWebSocket(
        PublishOutcome(
          eventId: signedEvent.id,
          acceptedBy: const ['wss://trusted.example'],
          rejectedBy: const {},
          noResponseFrom: const [],
        ),
      );

      final result = await publisher.publishDirectUpload(createUpload());

      expect(result, isTrue);
      verify(
        () => mockNostrClient.publishEventAwaitOk(
          signedEvent,
          timeout: any(named: 'timeout'),
        ),
      ).called(1);
      verify(() => mockEventApiClient.publishEvent(signedEvent)).called(1);
    });

    test('account restriction stops without WebSocket fallback', () async {
      final signedEvent = createSignedEvent();
      stubSigning(signedEvent);
      stubRest(
        const EventApiRejected(
          statusCode: 403,
          reason: 'blocked: pubkey is suspended',
        ),
      );

      await expectLater(
        publisher.publishDirectUpload(createUpload()),
        throwsA(isA<AccountRestrictedPublishException>()),
      );
      verifyNever(
        () => mockNostrClient.publishEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
        ),
      );
    });

    test('trusted WebSocket restriction stops retrying', () async {
      final signedEvent = createSignedEvent();
      stubSigning(signedEvent);
      stubRest(const EventApiTransientFailure('http_503'));
      stubWebSocket(
        PublishOutcome(
          eventId: signedEvent.id,
          acceptedBy: const [],
          rejectedBy: const {
            'wss://trusted.example/': 'blocked: pubkey is suspended',
          },
          noResponseFrom: const [],
        ),
      );

      await expectLater(
        publisher.publishDirectUpload(createUpload()),
        throwsA(isA<AccountRestrictedPublishException>()),
      );

      verify(
        () => mockNostrClient.publishEventAwaitOk(
          signedEvent,
          timeout: any(named: 'timeout'),
        ),
      ).called(1);
      verify(() => mockEventApiClient.publishEvent(signedEvent)).called(1);
    });

    test('an acceptance defeats a trusted WebSocket restriction', () async {
      final signedEvent = createSignedEvent();
      stubSigning(signedEvent);
      stubRest(const EventApiTransientFailure('http_503'));
      stubWebSocket(
        PublishOutcome(
          eventId: signedEvent.id,
          acceptedBy: const ['wss://another.example'],
          rejectedBy: const {
            'wss://trusted.example': 'blocked: pubkey is banned',
          },
          noResponseFrom: const [],
        ),
      );

      expect(await publisher.publishDirectUpload(createUpload()), isTrue);
    });

    test('an untrusted WebSocket restriction is not authoritative', () async {
      final signedEvent = createSignedEvent();
      stubSigning(signedEvent);
      stubRest(const EventApiTransientFailure('http_503'));
      stubWebSocket(
        PublishOutcome(
          eventId: signedEvent.id,
          acceptedBy: const [],
          rejectedBy: const {
            'wss://untrusted.example': 'blocked: pubkey is suspended',
          },
          noResponseFrom: const [],
        ),
      );
      when(
        () => mockNostrClient.queryEvents(
          any(),
          useCache: any(named: 'useCache'),
        ),
      ).thenAnswer((_) async => [signedEvent]);

      expect(await publisher.publishDirectUpload(createUpload()), isTrue);
      verify(
        () => mockNostrClient.publishEventAwaitOk(
          signedEvent,
          timeout: any(named: 'timeout'),
        ),
      ).called(1);
    });

    test('retry reuses the original signed event id (no re-sign)', () async {
      final signedEvent = createSignedEvent();
      final retryUpload = createUpload().copyWith(nostrEventId: signedEvent.id);
      when(
        () => mockPersonalEventCache.getEventById(signedEvent.id),
      ).thenReturn(signedEvent);
      stubRest(const EventApiAccepted('server-event-id'));

      final result = await publisher.publishDirectUpload(retryUpload);

      expect(result, isTrue);
      // No new event signed — the cached event is reused.
      verifyNever(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      );
      final captured = verify(
        () => mockEventApiClient.publishEvent(captureAny()),
      ).captured;
      expect((captured.single as Event).id, equals(signedEvent.id));
    });

    test(
      'recovery: existing relay event marks published without re-publishing',
      () async {
        final signedEvent = createSignedEvent();
        final retryUpload = createUpload().copyWith(
          nostrEventId: signedEvent.id,
        );
        when(
          () => mockPersonalEventCache.getEventById(signedEvent.id),
        ).thenReturn(signedEvent);
        // The event is already on a configured relay.
        when(
          () => mockNostrClient.queryEvents(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async => [signedEvent]);

        final result = await publisher.publishDirectUpload(retryUpload);

        expect(result, isTrue);
        verifyNever(() => mockEventApiClient.publishEvent(any()));
        verifyNever(
          () => mockNostrClient.publishEventAwaitOk(
            any(),
            timeout: any(named: 'timeout'),
          ),
        );
        verify(
          () => mockUploadManager.updateUploadStatus(
            'test-upload-id',
            UploadStatus.published,
            nostrEventId: signedEvent.id,
          ),
        ).called(1);
      },
    );

    test(
      'WebSocket false-negative does not create a duplicate event',
      () async {
        final signedEvent = createSignedEvent();
        stubSigning(signedEvent);
        // REST keeps failing transiently across attempts.
        stubRest(const EventApiTransientFailure('http_503'));
        // WebSocket reports failure even though the relay actually stored it
        // during the first send — so the pre-retry recovery query finds it.
        stubWebSocket(
          PublishOutcome(
            eventId: signedEvent.id,
            acceptedBy: const [],
            rejectedBy: const {},
            noResponseFrom: const ['wss://trusted.example'],
          ),
        );
        when(
          () => mockNostrClient.queryEvents(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async => [signedEvent]);

        final result = await publisher.publishDirectUpload(createUpload());

        expect(result, isTrue);
        // The event is signed exactly once and reused across attempts — a
        // retry never re-signs, so relays cannot receive a second distinct id.
        verify(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).called(1);
        // Exactly one WebSocket send — the second attempt short-circuits on
        // recovery rather than re-broadcasting and creating a duplicate.
        verify(
          () => mockNostrClient.publishEventAwaitOk(
            signedEvent,
            timeout: any(named: 'timeout'),
          ),
        ).called(1);
        verify(
          () => mockUploadManager.updateUploadStatus(
            'test-upload-id',
            UploadStatus.published,
            nostrEventId: signedEvent.id,
          ),
        ).called(1);
      },
    );

    test(
      'final WebSocket false-negative is recovered by relay presence',
      () async {
        final signedEvent = createSignedEvent();
        stubSigning(signedEvent);
        stubRest(const EventApiTransientFailure('http_503'));
        stubWebSocket(
          PublishOutcome(
            eventId: signedEvent.id,
            acceptedBy: const [],
            rejectedBy: const {},
            noResponseFrom: const ['wss://trusted.example'],
          ),
        );
        var presenceChecks = 0;
        when(
          () => mockNostrClient.queryEvents(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async {
          presenceChecks++;
          return presenceChecks == 3 ? [signedEvent] : <Event>[];
        });

        expect(await publisher.publishDirectUpload(createUpload()), isTrue);
        verify(() => mockEventApiClient.publishEvent(signedEvent)).called(3);
        verify(
          () => mockNostrClient.publishEventAwaitOk(
            signedEvent,
            timeout: any(named: 'timeout'),
          ),
        ).called(3);
        expect(presenceChecks, 3);
      },
    );
  });
}

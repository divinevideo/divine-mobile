import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:creator_sync/creator_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show AudioEvent, VideoEvent, audioEventKind;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/services/audio_extraction_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/services/published_event_local_echo.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_event_publisher.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockUploadManager extends Mock implements UploadManager {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

class _MockAudioExtractionService extends Mock
    implements AudioExtractionService {}

class _MockPersonalEventCacheService extends Mock
    implements PersonalEventCacheService {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockSoundSyncRepository extends Mock implements SoundSyncRepository {}

class _FakeEvent extends Fake implements Event {}

class _FakeVideoEvent extends Fake implements VideoEvent {}

void main() {
  late _MockUploadManager mockUploadManager;
  late _MockNostrClient mockNostrClient;
  late _MockAuthService mockAuthService;
  late _MockPersonalEventCacheService mockPersonalEventCache;
  late _MockVideoEventService mockVideoEventService;
  late VideoEventPublisher publisher;

  const testPubkey =
      '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd';

  late List<Event> persistedEvents;
  Object? persistFailure;

  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(_FakeVideoEvent());
    registerFallbackValue(UploadStatus.pending);
    registerFallbackValue(File(''));
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    mockUploadManager = _MockUploadManager();
    mockNostrClient = _MockNostrClient();
    mockAuthService = _MockAuthService();
    mockPersonalEventCache = _MockPersonalEventCacheService();
    mockVideoEventService = _MockVideoEventService();

    persistedEvents = [];
    persistFailure = null;
    publisher = VideoEventPublisher(
      uploadManager: mockUploadManager,
      nostrService: mockNostrClient,
      authService: mockAuthService,
      personalEventCache: mockPersonalEventCache,
      videoEventService: mockVideoEventService,
      publishedEventLocalEcho: PublishedEventLocalEcho((event) async {
        final failure = persistFailure;
        if (failure != null) throw failure;
        persistedEvents.add(event);
      }),
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

  void stubPublish(Event event) {
    when(
      () => mockNostrClient.publishEventAwaitOk(
        any(),
        timeout: any(named: 'timeout'),
      ),
    ).thenAnswer(
      (_) async => PublishOutcome(
        eventId: event.id,
        acceptedBy: const ['wss://relay.divine.video'],
        rejectedBy: const {},
        noResponseFrom: const [],
      ),
    );
  }

  bool containsTag(List<List<String>> tags, List<String> expected) {
    return tags.any((tag) {
      if (tag.length != expected.length) return false;
      for (var i = 0; i < expected.length; i++) {
        if (tag[i] != expected[i]) return false;
      }
      return true;
    });
  }

  group('VideoEventPublisher direct publish', () {
    test('succeeds when relay accepts the event', () async {
      final signedEvent = createSignedEvent();
      stubSigning(signedEvent);
      stubPublish(signedEvent);

      final result = await publisher.publishDirectUpload(createUpload());

      expect(result, isTrue);
      verify(
        () => mockUploadManager.updateUploadStatus(
          'test-upload-id',
          UploadStatus.published,
          nostrEventId: signedEvent.id,
        ),
      ).called(1);
      verify(() => mockVideoEventService.addVideoEvent(any())).called(1);
    });

    test(
      'caches the published event locally so it is readable at once',
      () async {
        // The relay commits to ClickHouse on a minutes-long batch timer and
        // funnelcake reads that same table, so nothing can serve this event
        // back yet. Without the local write, the post-publish confirmation's
        // View button opens /video/<d-tag> onto "Video not found".
        final signedEvent = createSignedEvent();
        stubSigning(signedEvent);
        stubPublish(signedEvent);

        await publisher.publishDirectUpload(createUpload());

        expect(persistedEvents.map((e) => e.id), equals([signedEvent.id]));
      },
    );

    test('a failed local cache write does not fail the publish', () async {
      // The video is already live on the relay by this point; losing the
      // read-back optimisation must not report the publish as failed.
      final signedEvent = createSignedEvent();
      stubSigning(signedEvent);
      stubPublish(signedEvent);
      persistFailure = Exception('disk full');

      final result = await publisher.publishDirectUpload(createUpload());

      expect(result, isTrue);
    });

    test('does not mark published when relays reject with OK false despite '
        'successful send', () async {
      final signedEvent = createSignedEvent();
      stubSigning(signedEvent);
      // WebSocket frame accepted by the pool...
      when(
        () => mockNostrClient.publishEvent(any()),
      ).thenAnswer((_) async => PublishSuccess(event: signedEvent));
      // ...but every relay rejects the event at the protocol level
      // (NIP-20 `OK false`, e.g. divine relay policy rejection).
      when(
        () => mockNostrClient.publishEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer(
        (_) async => PublishOutcome(
          eventId: signedEvent.id,
          acceptedBy: const [],
          rejectedBy: const {
            'wss://relay.divine.video': 'blocked: event rejected by policy',
          },
          noResponseFrom: const [],
        ),
      );

      final result = await publisher.publishDirectUpload(createUpload());

      expect(result, isFalse);
      verifyNever(
        () => mockUploadManager.updateUploadStatus(
          any(),
          UploadStatus.published,
          nostrEventId: any(named: 'nostrEventId'),
        ),
      );
      verifyNever(() => mockVideoEventService.addVideoEvent(any()));
    });

    test(
      'returns false when relay rejects the event on all attempts',
      () async {
        final signedEvent = createSignedEvent();
        stubSigning(signedEvent);
        // Relay rejects the event (no relay accepts the publish).
        when(
          () => mockNostrClient.publishEventAwaitOk(
            any(),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (_) async => PublishOutcome(
            eventId: signedEvent.id,
            acceptedBy: const [],
            rejectedBy: const {'wss://relay.divine.video': 'rejected'},
            noResponseFrom: const [],
          ),
        );

        final result = await publisher.publishDirectUpload(createUpload());

        expect(result, isFalse);
        verifyNever(
          () => mockUploadManager.updateUploadStatus(
            any(),
            UploadStatus.published,
            nostrEventId: any(named: 'nostrEventId'),
          ),
        );
        verifyNever(() => mockVideoEventService.addVideoEvent(any()));
      },
    );

    test('reuses a cached signed event when retrying publish', () async {
      final signedEvent = createSignedEvent();
      final retryUpload = createUpload().copyWith(nostrEventId: signedEvent.id);

      when(
        () => mockPersonalEventCache.getEventById(signedEvent.id),
      ).thenReturn(signedEvent);
      stubPublish(signedEvent);

      final result = await publisher.publishDirectUpload(retryUpload);

      expect(result, isTrue);
      verifyNever(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      );
      verify(
        () => mockNostrClient.publishEventAwaitOk(
          signedEvent,
          timeout: any(named: 'timeout'),
        ),
      ).called(1);
    });

    test('adds selected audio tag only for valid Nostr event ids', () async {
      final validAudioId = 'b' * 64;
      late List<List<String>> videoTags;

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((invocation) async {
        videoTags = invocation.namedArguments[#tags] as List<List<String>>;
        return Event(
          testPubkey,
          NIP71VideoKinds.getPreferredAddressableKind(),
          videoTags,
          'video content',
        );
      });
      when(
        () => mockNostrClient.publishEventAwaitOk(
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

      final result = await publisher.publishDirectUpload(
        createUpload(),
        selectedAudioEventId: validAudioId,
        selectedAudioRelay: 'wss://relay.divine.video',
      );

      expect(result, isTrue);
      expect(
        containsTag(videoTags, [
          'e',
          validAudioId,
          'wss://relay.divine.video',
          'audio',
        ]),
        isTrue,
      );
    });

    test('skips selected audio tag for non-event ids', () async {
      late List<List<String>> videoTags;

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((invocation) async {
        videoTags = invocation.namedArguments[#tags] as List<List<String>>;
        return Event(
          testPubkey,
          NIP71VideoKinds.getPreferredAddressableKind(),
          videoTags,
          'video content',
        );
      });
      when(
        () => mockNostrClient.publishEventAwaitOk(
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

      final result = await publisher.publishDirectUpload(
        createUpload(),
        selectedAudioEventId: 'video_not_a_64_hex_id',
        selectedAudioRelay: 'wss://relay.divine.video',
      );

      expect(result, isTrue);
      expect(
        videoTags.any(
          (tag) =>
              tag.length >= 4 &&
              tag.first == 'e' &&
              tag[1] == 'video_not_a_64_hex_id' &&
              tag[3] == 'audio',
        ),
        isFalse,
      );
    });

    test('publishes reusable audio event and saves it to My Sounds', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final savedSoundsService = SavedSoundsService(prefs);
      final blossomUploadService = _MockBlossomUploadService();
      final audioExtractionService = _MockAudioExtractionService();
      final syncRepository = _MockSoundSyncRepository();
      when(
        () => syncRepository.publishLocalChange(any()),
      ).thenAnswer((_) async {});
      final audioPublisher = VideoEventPublisher(
        uploadManager: mockUploadManager,
        nostrService: mockNostrClient,
        authService: mockAuthService,
        blossomUploadService: blossomUploadService,
        audioExtractionService: audioExtractionService,
        savedSoundsService: savedSoundsService,
        soundSyncRepositoryGetter: () => syncRepository,
      );

      const audioPath = '/tmp/openvine_test_audio.m4a';
      when(
        () => audioExtractionService.extractAudio(videoPath: '/tmp/test.mp4'),
      ).thenAnswer(
        (_) async => const AudioExtractionResult(
          audioFilePath: audioPath,
          duration: 6,
          fileSize: 12345,
          sha256Hash: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          mimeType: 'audio/m4a',
        ),
      );
      when(
        () => audioExtractionService.cleanupAudioFile(audioPath),
      ).thenAnswer((_) async {});
      when(
        () => blossomUploadService.uploadAudio(
          audioFile: any(named: 'audioFile'),
          mimeType: 'audio/m4a',
        ),
      ).thenAnswer(
        (_) async => const BlossomUploadResult(
          success: true,
          url: 'https://cdn.example.com/audio.m4a',
          fallbackUrl: 'https://cdn.example.com/audio.m4a',
          videoId: 'audio-file-hash',
        ),
      );

      late Event signedAudioEvent;
      late List<List<String>> audioTags;
      late List<List<String>> videoTags;

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((invocation) async {
        final kind = invocation.namedArguments[#kind] as int;
        final tags = invocation.namedArguments[#tags] as List<List<String>>;
        if (kind == audioEventKind) {
          audioTags = tags;
          return signedAudioEvent = Event(testPubkey, audioEventKind, tags, '');
        }

        videoTags = tags;
        return Event(testPubkey, kind, tags, 'video content');
      });
      when(
        () => mockNostrClient.publishEventAwaitOk(
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

      final result = await audioPublisher.publishDirectUpload(
        createUpload(),
        allowAudioReuse: true,
      );

      expect(result, isTrue);
      expect(
        containsTag(audioTags, ['url', 'https://cdn.example.com/audio.m4a']),
        isTrue,
      );
      expect(containsTag(audioTags, ['m', 'audio/m4a']), isTrue);
      expect(containsTag(audioTags, ['x', 'a' * 64]), isTrue);
      expect(containsTag(audioTags, ['size', '12345']), isTrue);
      expect(containsTag(audioTags, ['duration', '6.0']), isTrue);
      expect(containsTag(audioTags, ['title', 'Plants']), isTrue);
      expect(containsTag(videoTags, ['allow_audio_reuse', 'true']), isTrue);
      expect(
        containsTag(videoTags, [
          'e',
          signedAudioEvent.id,
          'wss://relay.divine.video',
          'audio',
        ]),
        isTrue,
      );

      final savedSounds = savedSoundsService.loadSounds();
      expect(savedSounds, hasLength(1));
      final savedSound = savedSounds.single;
      expect(savedSound, isA<AudioEvent>());
      expect(savedSound.id, signedAudioEvent.id);
      expect(savedSound.pubkey, testPubkey);
      expect(savedSound.url, 'https://cdn.example.com/audio.m4a');
      expect(savedSound.mimeType, 'audio/m4a');
      expect(
        savedSound.sourceVideoReference,
        '34236:$testPubkey:test-video-id',
      );
      verify(
        () => syncRepository.publishLocalChange(signedAudioEvent.id),
      ).called(1);
    });
  });

  group('VideoEventPublisher.currentOuterPublishTimeout wiring', () {
    // Pins the production wiring between [outerPublishTimeoutFor] and
    // the actual `Future.timeout` inside _publishEventToNostr. The math
    // is covered exhaustively in video_event_publisher_test.dart; this
    // group only verifies the call site reads from the helper rather
    // than re-introducing a hard-coded literal.

    test(
      'reflects outerPublishTimeoutFor for the current configuredRelayCount',
      () {
        when(() => mockNostrClient.configuredRelayCount).thenReturn(6);
        expect(
          publisher.currentOuterPublishTimeout,
          equals(outerPublishTimeoutFor(6)),
        );
      },
    );

    test('updates live as configuredRelayCount changes', () {
      when(() => mockNostrClient.configuredRelayCount).thenReturn(0);
      expect(
        publisher.currentOuterPublishTimeout,
        equals(outerPublishTimeoutFor(0)),
      );

      when(() => mockNostrClient.configuredRelayCount).thenReturn(50);
      expect(
        publisher.currentOuterPublishTimeout,
        equals(outerPublishTimeoutFor(50)),
      );
    });

    test(
      'never collapses to a single hard-coded literal across relay counts',
      () {
        // Regression guard against reverting the call site to e.g.
        // `Duration(seconds: 30)`. With three different stubbed counts
        // straddling the floor / mid-range / ceiling, the getter must
        // produce three distinct values.
        when(() => mockNostrClient.configuredRelayCount).thenReturn(0);
        final atFloor = publisher.currentOuterPublishTimeout;

        when(() => mockNostrClient.configuredRelayCount).thenReturn(6);
        final atDefault = publisher.currentOuterPublishTimeout;

        when(() => mockNostrClient.configuredRelayCount).thenReturn(50);
        final atCeiling = publisher.currentOuterPublishTimeout;

        expect(
          {atFloor, atDefault, atCeiling},
          hasLength(3),
          reason:
              'getter must vary with configuredRelayCount; '
              'a single literal would collapse all three to one value',
        );
      },
    );
  });
}

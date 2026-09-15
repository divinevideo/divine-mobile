// ABOUTME: Regression tests for #6018 - concurrent publishDirectUpload calls
// ABOUTME: must coalesce into one signed/broadcast addressable video event

import 'dart:async';
import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:openvine/services/audio_extraction_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_event_publisher.dart';

class _MockUploadManager extends Mock implements UploadManager {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

class _MockAudioExtractionService extends Mock
    implements AudioExtractionService {}

class _MockPersonalEventCacheService extends Mock
    implements PersonalEventCacheService {}

class _FakeEvent extends Fake implements Event {}

void main() {
  group('VideoEventPublisher concurrent publishDirectUpload (#6018)', () {
    late _MockUploadManager mockUploadManager;
    late _MockNostrClient mockNostrClient;
    late _MockAuthService mockAuthService;
    late _MockBlossomUploadService mockBlossomUploadService;
    late _MockAudioExtractionService mockAudioExtractionService;
    late _MockPersonalEventCacheService mockPersonalEventCache;
    late VideoEventPublisher publisher;

    const testPubkey =
        '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd';

    setUpAll(() {
      registerFallbackValue(_FakeEvent());
      registerFallbackValue(UploadStatus.pending);
      registerFallbackValue(File(''));
      registerFallbackValue(Duration.zero);
    });

    setUp(() {
      mockUploadManager = _MockUploadManager();
      mockNostrClient = _MockNostrClient();
      mockAuthService = _MockAuthService();
      mockBlossomUploadService = _MockBlossomUploadService();
      mockAudioExtractionService = _MockAudioExtractionService();
      mockPersonalEventCache = _MockPersonalEventCacheService();

      publisher = VideoEventPublisher(
        uploadManager: mockUploadManager,
        nostrService: mockNostrClient,
        authService: mockAuthService,
        personalEventCache: mockPersonalEventCache,
        blossomUploadService: mockBlossomUploadService,
        audioExtractionService: mockAudioExtractionService,
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
    });

    // Only the audio-reuse test needs a non-empty localVideoPath (it gates the
    // audio-extraction step). The other tests pass '' so publishDirectUpload
    // skips the thumbnail/blurhash branch and its real pro_video_editor plugin
    // channel + retry timers.
    PendingUpload createUpload({String localVideoPath = ''}) {
      return PendingUpload(
        id: 'test-upload-id',
        localVideoPath: localVideoPath,
        nostrPubkey: testPubkey,
        status: UploadStatus.readyToPublish,
        createdAt: DateTime.now(),
        videoId: 'test-video-id',
        title: 'Plants',
        cdnUrl: 'https://cdn.example.com/video.mp4',
        fallbackUrl: 'https://cdn.example.com/video.mp4',
      );
    }

    test(
      'second call during a slow failing audio-reuse step reuses the '
      'in-flight publish instead of signing a duplicate event',
      () async {
        // Gate the audio extraction so the first publish is stuck in the
        // audio-reuse step - the window where production duplicates were
        // minted. The extraction then fails, which degrades to a video-only
        // publish rather than discarding the already-uploaded video.
        final audioGate = Completer<void>();
        var extractionCount = 0;
        when(
          () => mockAudioExtractionService.extractAudio(
            videoPath: any(named: 'videoPath'),
          ),
        ).thenAnswer((_) async {
          extractionCount++;
          await audioGate.future;
          throw const AudioExtractionException('extraction failed');
        });

        var videoSignCount = 0;
        final broadcastVideoEvents = <Event>[];
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((invocation) async {
          videoSignCount++;
          return Event(
            testPubkey,
            invocation.namedArguments[#kind] as int,
            invocation.namedArguments[#tags] as List<List<String>>,
            'video content',
            createdAt: 1700000000 + videoSignCount,
          );
        });
        when(
          () => mockNostrClient.publishEventAwaitOk(
            any(),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((invocation) async {
          final event = invocation.positionalArguments.first as Event;
          broadcastVideoEvents.add(event);
          return PublishOutcome(
            eventId: event.id,
            acceptedBy: const ['wss://relay.divine.video'],
            rejectedBy: const {},
            noResponseFrom: const [],
          );
        });

        final upload = createUpload(localVideoPath: '/tmp/test.mp4');
        final firstPublish = publisher.publishDirectUpload(
          upload,
          allowAudioReuse: true,
        );
        // Let the first call run into the gated audio extraction.
        await pumpEventQueue();

        final secondPublish = publisher.publishDirectUpload(
          upload,
          allowAudioReuse: true,
        );
        await pumpEventQueue();

        audioGate.complete();
        final results = await Future.wait([firstPublish, secondPublish]);

        // The video still publishes; a failed extraction must not discard an
        // already-uploaded video.
        expect(results, everyElement(isTrue));
        expect(
          extractionCount,
          equals(1),
          reason: 'the concurrent second publish must await the in-flight one',
        );
        expect(
          videoSignCount,
          equals(1),
          reason: 'two concurrent calls must yield exactly one signed event',
        );
        expect(
          broadcastVideoEvents,
          hasLength(1),
          reason: 'the de-duplicated publish reaches the relays once',
        );
        expect(
          broadcastVideoEvents.single.tags.where(
            (tag) => tag.first == 'allow_audio_reuse',
          ),
          isEmpty,
          reason: 'the event must not claim audio reuse that never published',
        );
      },
    );

    test('publishes again for the same upload once the first publish '
        'has completed', () async {
      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer(
        (invocation) async => Event(
          testPubkey,
          invocation.namedArguments[#kind] as int,
          invocation.namedArguments[#tags] as List<List<String>>,
          'video content',
        ),
      );
      var broadcastCount = 0;
      when(
        () => mockNostrClient.publishEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer((invocation) async {
        broadcastCount++;
        return PublishOutcome(
          eventId: (invocation.positionalArguments.first as Event).id,
          acceptedBy: const ['wss://relay.divine.video'],
          rejectedBy: const {},
          noResponseFrom: const [],
        );
      });

      final upload = createUpload();
      expect(await publisher.publishDirectUpload(upload), isTrue);
      expect(
        await publisher.publishDirectUpload(upload),
        isTrue,
        reason: 'sequential re-publish (e.g. an edit) must not be blocked',
      );
      expect(broadcastCount, equals(2));
    });

    test(
      'concurrent publishes for different uploads are not coalesced',
      () async {
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (invocation) async => Event(
            testPubkey,
            invocation.namedArguments[#kind] as int,
            invocation.namedArguments[#tags] as List<List<String>>,
            'video content',
          ),
        );
        final broadcastDTags = <String>[];
        when(
          () => mockNostrClient.publishEventAwaitOk(
            any(),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((invocation) async {
          final event = invocation.positionalArguments.first as Event;
          broadcastDTags.add(
            event.tags.firstWhere((tag) => tag.first == 'd')[1],
          );
          return PublishOutcome(
            eventId: event.id,
            acceptedBy: const ['wss://relay.divine.video'],
            rejectedBy: const {},
            noResponseFrom: const [],
          );
        });

        final results = await Future.wait([
          publisher.publishDirectUpload(createUpload()),
          publisher.publishDirectUpload(
            createUpload().copyWith(videoId: 'other-video-id'),
          ),
        ]);

        expect(results, everyElement(isTrue));
        expect(
          broadcastDTags,
          unorderedEquals(['test-video-id', 'other-video-id']),
        );
      },
    );
  });
}

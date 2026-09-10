// ABOUTME: Covers the reusable-audio degrade path at the sign/cache boundary
// ABOUTME: A degraded event must never enter the retry cache, so retries heal

import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:openvine/exceptions/video_exceptions.dart';
import 'package:openvine/models/pending_upload.dart';
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
  group('VideoEventPublisher reusable-audio degrade', () {
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

      // The real degrade path: extraction is attempted and fails, rather than
      // the publisher short-circuiting because no audio services were wired.
      when(
        () => mockAudioExtractionService.extractAudio(
          videoPath: any(named: 'videoPath'),
        ),
      ).thenThrow(const AudioExtractionException('extraction failed'));
    });

    PendingUpload createUpload() => PendingUpload(
      id: 'test-upload-id',
      localVideoPath: '/tmp/video-with-audio.mp4',
      nostrPubkey: testPubkey,
      status: UploadStatus.readyToPublish,
      createdAt: DateTime.now(),
      videoId: 'test-video-id',
      title: 'Plants',
      cdnUrl: 'https://cdn.example.com/video.mp4',
      fallbackUrl: 'https://cdn.example.com/video.mp4',
    );

    List<Event> stubSigning() {
      final signed = <Event>[];
      var signCount = 0;
      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((invocation) async {
        signCount++;
        final event = Event(
          testPubkey,
          invocation.namedArguments[#kind] as int,
          invocation.namedArguments[#tags] as List<List<String>>,
          'video content',
          createdAt: 1700000000 + signCount,
        );
        signed.add(event);
        return event;
      });
      return signed;
    }

    /// [accepts] applies to the video event only; the Kind 1063 sound is
    /// always accepted so a rejected video does not double as a failed audio
    /// publish (which would degrade and mask what the test is pinning).
    void stubRelay({required bool accepts}) {
      when(
        () => mockNostrClient.publishEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer((invocation) async {
        final event = invocation.positionalArguments.first as Event;
        final accepted = accepts || event.kind != 34236;
        return PublishOutcome(
          eventId: event.id,
          acceptedBy: accepted ? const ['wss://relay.divine.video'] : const [],
          rejectedBy: accepted
              ? const {}
              : const {'wss://relay.divine.video': 'rejected'},
          noResponseFrom: const [],
        );
      });
    }

    test(
      'a degraded event is kept out of the retry cache so "Try Again" can '
      'rebuild the audio tags',
      () async {
        stubSigning();
        stubRelay(accepts: false);

        final result = await publisher.publishDirectUpload(
          createUpload(),
          allowAudioReuse: true,
        );

        expect(result, isFalse, reason: 'the relay rejected the event');

        // Caching it would make the retry reuse this marker-less event
        // verbatim, permanently stranding the video without its sound.
        verifyNever(() => mockPersonalEventCache.cacheUserEvent(any()));
        verifyNever(
          () => mockUploadManager.updateUploadStatus(
            any(),
            any(),
            nostrEventId: any(named: 'nostrEventId', that: isNotNull),
          ),
        );
      },
    );

    test('a degraded publish still succeeds and reports the loss', () async {
      final signed = stubSigning();
      stubRelay(accepts: true);

      var degraded = false;
      final result = await publisher.publishDirectUpload(
        createUpload(),
        allowAudioReuse: true,
        onAudioReuseDegraded: () => degraded = true,
      );

      expect(result, isTrue, reason: 'an uploaded video is not discarded');
      expect(
        degraded,
        isTrue,
        reason: 'the caller must be able to tell the creator the sound is gone',
      );
      expect(
        signed.single.tags.where((tag) => tag.first == 'allow_audio_reuse'),
        isEmpty,
      );
      expect(
        signed.single.tags.where(
          (tag) => tag.first == 'e' && tag.last == 'audio',
        ),
        isEmpty,
      );
    });

    test(
      'a successful reusable-audio publish is still cached for retry',
      () async {
        // The guard must key off the degrade, not off allowAudioReuse being
        // set: when extraction succeeds the event carries its audio markers,
        // so caching it is correct and a retry should reuse it.
        const audioPath = '/tmp/divine-audio.m4a';
        when(
          () => mockAudioExtractionService.extractAudio(
            videoPath: any(named: 'videoPath'),
          ),
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
          () => mockAudioExtractionService.cleanupAudioFile(audioPath),
        ).thenAnswer((_) async {});
        when(
          () => mockBlossomUploadService.uploadAudio(
            audioFile: any(named: 'audioFile'),
            mimeType: 'audio/m4a',
          ),
        ).thenAnswer(
          (_) async => const BlossomUploadResult(
            success: true,
            url: 'https://cdn.example.com/audio.m4a',
            fallbackUrl: 'https://cdn.example.com/audio.m4a',
            videoId: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          ),
        );

        final signed = stubSigning();
        stubRelay(accepts: false);

        var degraded = false;
        await publisher.publishDirectUpload(
          createUpload(),
          allowAudioReuse: true,
          onAudioReuseDegraded: () => degraded = true,
        );

        expect(degraded, isFalse);

        final videoEvent = signed.last;
        expect(
          videoEvent.tags.where((tag) => tag.first == 'allow_audio_reuse'),
          isNotEmpty,
          reason: 'the markers the retry would rebuild are already present',
        );
        verify(
          () => mockUploadManager.updateUploadStatus(
            any(),
            any(),
            nostrEventId: videoEvent.id,
          ),
        ).called(1);
      },
    );

    test(
      'an authoritative reusable-audio restriction is not degraded',
      () async {
        const audioPath = '/tmp/divine-audio.m4a';
        when(
          () => mockAudioExtractionService.extractAudio(
            videoPath: any(named: 'videoPath'),
          ),
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
          () => mockAudioExtractionService.cleanupAudioFile(audioPath),
        ).thenAnswer((_) async {});
        when(
          () => mockBlossomUploadService.uploadAudio(
            audioFile: any(named: 'audioFile'),
            mimeType: 'audio/m4a',
          ),
        ).thenAnswer(
          (_) async => const BlossomUploadResult(
            success: true,
            url: 'https://cdn.example.com/audio.m4a',
            fallbackUrl: 'https://cdn.example.com/audio.m4a',
            videoId: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          ),
        );
        stubSigning();
        when(
          () => mockNostrClient.publishEventAwaitOk(
            any(),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((invocation) async {
          final event = invocation.positionalArguments.first as Event;
          return PublishOutcome(
            eventId: event.id,
            acceptedBy: const [],
            rejectedBy: const {
              'wss://relay.divine.video': 'blocked: pubkey is suspended',
            },
            noResponseFrom: const [],
          );
        });

        await expectLater(
          publisher.publishDirectUpload(createUpload(), allowAudioReuse: true),
          throwsA(
            isA<AccountRestrictedPublishException>().having(
              (error) => error.source,
              'source',
              AccountRestrictionSource.webSocket,
            ),
          ),
        );
      },
    );
  });
}

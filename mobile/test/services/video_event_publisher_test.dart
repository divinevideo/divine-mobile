// ABOUTME: Tests for VideoEventPublisher service ensuring complete imeta tag generation
// ABOUTME: Verifies file metadata (size, SHA256), thumbnails, and NIP-71 kind 34236 compliance

import 'dart:async';
import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:collection/collection.dart';
import 'package:creator_sync/creator_sync.dart';
import 'package:crypto/crypto.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart'
    show
        AudioEvent,
        AudioExternalSource,
        AudioLicenseMetadata,
        UserProfile,
        VideoEvent,
        VideoUrlResolver,
        audioEventKind;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:nostr_sdk/relay/relay_pool.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/exceptions/video_exceptions.dart';
import 'package:openvine/models/audio_share_attribution.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/services/audio_extraction_service.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_event_publisher.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockUploadManager extends Mock implements UploadManager {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

class _MockAudioExtractionService extends Mock
    implements AudioExtractionService {}

class _MockSavedSoundsService extends Mock implements SavedSoundsService {}

class _MockSoundSyncRepository extends Mock implements SoundSyncRepository {}

class _FakeEvent extends Fake implements Event {}

class _FakeFilter extends Fake implements Filter {}

const _deepEquals = DeepCollectionEquality();

bool _containsTag(List<List<String>> tags, List<String> expected) {
  return tags.any((tag) => _deepEquals.equals(tag, expected));
}

/// Helper class to test imeta tag generation logic
class ImetaTagGenerator {
  /// Generate imeta components for a video upload (extracted from VideoEventPublisher)
  static Future<List<String>> generateImetaComponents(
    PendingUpload upload,
  ) async {
    final imetaComponents = <String>[];

    // Add URL(s), excluding delivery hosts known to be dead.
    if (upload.cdnUrl != null) {
      final cdnUrl = upload.cdnUrl!;
      if (!VideoUrlResolver.isKnownDeadMediaUrl(cdnUrl)) {
        imetaComponents.add('url $cdnUrl');
      }
    }
    imetaComponents.add('m video/mp4');

    // Add thumbnail to imeta if available
    if (upload.thumbnailPath != null && upload.thumbnailPath!.isNotEmpty) {
      imetaComponents.add('image ${upload.thumbnailPath!}');
    }

    // Add dimensions to imeta if available
    if (upload.videoWidth != null && upload.videoHeight != null) {
      imetaComponents.add('dim ${upload.videoWidth}x${upload.videoHeight}');
    }

    // Add file size and SHA256 if available from local video file
    if (upload.localVideoPath.isNotEmpty) {
      try {
        final videoFile = File(upload.localVideoPath);
        if (videoFile.existsSync()) {
          // Add file size
          final fileSize = videoFile.lengthSync();
          imetaComponents.add('size $fileSize');

          // Calculate SHA256 hash
          final bytes = await videoFile.readAsBytes();
          final hash = sha256.convert(bytes);
          imetaComponents.add('x $hash');
        }
      } catch (e) {
        // File metadata calculation failed - this is handled gracefully
      }
    }

    return imetaComponents;
  }
}

void main() {
  group('VideoEventPublisher imeta tag generation', () {
    late File testVideoFile;
    late Directory tempDir;

    setUpAll(() async {
      // Create temporary directory and test video file
      tempDir = await Directory.systemTemp.createTemp('video_publisher_test');
      testVideoFile = File('${tempDir.path}/test_video.mp4');

      // Create a test video file with known content
      const testContent = 'This is test video content for hash calculation';
      await testVideoFile.writeAsString(testContent);
    });

    tearDownAll(() async {
      // Clean up test files
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('should generate complete imeta tag with file metadata', () async {
      // Arrange
      final upload =
          PendingUpload.create(
            localVideoPath: testVideoFile.path,
            nostrPubkey: 'test_pubkey',
            thumbnailPath: 'https://example.com/thumbnail.jpg',
            title: 'Test Video',
            description: 'Test description',
            hashtags: const ['test', 'video'],
            videoWidth: 1920,
            videoHeight: 1080,
          ).copyWith(
            cdnUrl: 'https://api.openvine.co/media/test_video.mp4',
            status: UploadStatus.readyToPublish,
          );

      // Calculate expected values
      final fileSize = testVideoFile.lengthSync();
      final bytes = await testVideoFile.readAsBytes();
      final expectedHash = sha256.convert(bytes).toString();

      // Act
      final imetaComponents = await ImetaTagGenerator.generateImetaComponents(
        upload,
      );

      // Assert
      expect(
        imetaComponents.isNotEmpty,
        true,
        reason: 'Should have imeta components',
      );

      // Verify all expected components are present
      expect(
        imetaComponents.any((c) => c.startsWith('url ')),
        true,
        reason: 'Should include URL component',
      );
      expect(
        imetaComponents.any((c) => c == 'm video/mp4'),
        true,
        reason: 'Should include MIME type',
      );
      expect(
        imetaComponents.any((c) => c.startsWith('image ')),
        true,
        reason: 'Should include thumbnail image',
      );
      expect(
        imetaComponents.any((c) => c.startsWith('dim ')),
        true,
        reason: 'Should include dimensions',
      );
      expect(
        imetaComponents.any((c) => c.startsWith('size ')),
        true,
        reason: 'Should include file size',
      );
      expect(
        imetaComponents.any((c) => c.startsWith('x ')),
        true,
        reason: 'Should include SHA256 hash',
      );

      // Verify specific values
      expect(
        imetaComponents.contains('url ${upload.cdnUrl}'),
        true,
        reason: 'URL should match upload CDN URL',
      );
      expect(
        imetaComponents.contains('image ${upload.thumbnailPath}'),
        true,
        reason: 'Image should match thumbnail path',
      );
      expect(
        imetaComponents.contains(
          'dim ${upload.videoWidth}x${upload.videoHeight}',
        ),
        true,
        reason: 'Dimensions should be correct',
      );
      expect(
        imetaComponents.contains('size $fileSize'),
        true,
        reason: 'File size should be correct',
      );
      expect(
        imetaComponents.contains('x $expectedHash'),
        true,
        reason: 'SHA256 hash should be correct',
      );
    });

    test(
      'should generate imeta tag without optional metadata when unavailable',
      () async {
        // Arrange - Upload without thumbnail, dimensions
        final upload =
            PendingUpload.create(
              localVideoPath: testVideoFile.path,
              nostrPubkey: 'test_pubkey',
              title: 'Test Video',
            ).copyWith(
              cdnUrl: 'https://api.openvine.co/media/test_video.mp4',
              status: UploadStatus.readyToPublish,
            );

        // Act
        final imetaComponents = await ImetaTagGenerator.generateImetaComponents(
          upload,
        );

        // Assert
        expect(
          imetaComponents.isNotEmpty,
          true,
          reason: 'Should have imeta components',
        );

        // Should have required components
        expect(
          imetaComponents.any((c) => c.startsWith('url ')),
          true,
          reason: 'Should include URL component',
        );
        expect(
          imetaComponents.any((c) => c == 'm video/mp4'),
          true,
          reason: 'Should include MIME type',
        );
        expect(
          imetaComponents.any((c) => c.startsWith('size ')),
          true,
          reason: 'Should include file size',
        );
        expect(
          imetaComponents.any((c) => c.startsWith('x ')),
          true,
          reason: 'Should include SHA256 hash',
        );

        // Should NOT have optional components
        expect(
          imetaComponents.any((c) => c.startsWith('image ')),
          false,
          reason: 'Should NOT include thumbnail when unavailable',
        );
        expect(
          imetaComponents.any((c) => c.startsWith('dim ')),
          false,
          reason: 'Should NOT include dimensions when unavailable',
        );
      },
    );

    test('should handle missing local video file gracefully', () async {
      // Arrange - Upload with non-existent local file
      final nonExistentFile = '${tempDir.path}/nonexistent.mp4';
      final upload =
          PendingUpload.create(
            localVideoPath: nonExistentFile,
            nostrPubkey: 'test_pubkey',
            title: 'Test Video',
          ).copyWith(
            cdnUrl: 'https://api.openvine.co/media/test_video.mp4',
            status: UploadStatus.readyToPublish,
          );

      // Act
      final imetaComponents = await ImetaTagGenerator.generateImetaComponents(
        upload,
      );

      // Assert
      expect(
        imetaComponents.isNotEmpty,
        true,
        reason: 'Should have basic imeta components',
      );

      // Should have basic components
      expect(
        imetaComponents.any((c) => c.startsWith('url ')),
        true,
        reason: 'Should include URL component',
      );
      expect(
        imetaComponents.any((c) => c == 'm video/mp4'),
        true,
        reason: 'Should include MIME type',
      );

      // Should NOT have file-dependent components
      expect(
        imetaComponents.any((c) => c.startsWith('size ')),
        false,
        reason: 'Should NOT include size when file missing',
      );
      expect(
        imetaComponents.any((c) => c.startsWith('x ')),
        false,
        reason: 'Should NOT include hash when file missing',
      );
    });

    test('should include thumbnail in imeta when available', () async {
      // Arrange
      final upload =
          PendingUpload.create(
            localVideoPath: testVideoFile.path,
            nostrPubkey: 'test_pubkey',
            thumbnailPath: 'https://example.com/custom_thumbnail.jpg',
            title: 'Test Video',
          ).copyWith(
            cdnUrl: 'https://api.openvine.co/media/test_video.mp4',
            status: UploadStatus.readyToPublish,
          );

      // Act
      final imetaComponents = await ImetaTagGenerator.generateImetaComponents(
        upload,
      );

      // Assert
      expect(
        imetaComponents.any((c) => c.startsWith('image ')),
        true,
        reason: 'Should include thumbnail when available',
      );
      expect(
        imetaComponents.contains('image ${upload.thumbnailPath}'),
        true,
        reason: 'Thumbnail URL should match',
      );
    });

    test('should include dimensions in imeta when available', () async {
      // Arrange
      final upload =
          PendingUpload.create(
            localVideoPath: testVideoFile.path,
            nostrPubkey: 'test_pubkey',
            videoWidth: 1280,
            videoHeight: 720,
          ).copyWith(
            cdnUrl: 'https://api.openvine.co/media/test_video.mp4',
            status: UploadStatus.readyToPublish,
          );

      // Act
      final imetaComponents = await ImetaTagGenerator.generateImetaComponents(
        upload,
      );

      // Assert
      expect(
        imetaComponents.any((c) => c.startsWith('dim ')),
        true,
        reason: 'Should include dimensions when available',
      );
      expect(
        imetaComponents.contains('dim 1280x720'),
        true,
        reason: 'Dimensions should be formatted correctly',
      );
    });

    test('should omit Bunny Stream HLS URLs from imeta', () async {
      const hlsUrl =
          'https://stream.divine.video/fa4a90a3-6a30-4dc6-9b9d-3f78551c9053/playlist.m3u8';
      final upload = PendingUpload.create(
        localVideoPath: testVideoFile.path,
        nostrPubkey: 'test_pubkey',
        title: 'Test Video',
      ).copyWith(cdnUrl: hlsUrl, status: UploadStatus.readyToPublish);

      // Act
      final imetaComponents = await ImetaTagGenerator.generateImetaComponents(
        upload,
      );

      expect(
        imetaComponents.contains('url $hlsUrl'),
        false,
        reason: 'Bunny Stream URLs are known dead and should not be minted',
      );
    });

    test('should only add single URL for non-Bunny Stream CDN URLs', () async {
      // Arrange - Regular CDN URL (not Bunny Stream)
      const regularUrl = 'https://cdn.divine.video/abc123.mp4';
      final upload = PendingUpload.create(
        localVideoPath: testVideoFile.path,
        nostrPubkey: 'test_pubkey',
        title: 'Test Video',
      ).copyWith(cdnUrl: regularUrl, status: UploadStatus.readyToPublish);

      // Act
      final imetaComponents = await ImetaTagGenerator.generateImetaComponents(
        upload,
      );

      // Assert - Should only have ONE URL
      final urlComponents = imetaComponents
          .where((c) => c.startsWith('url '))
          .toList();
      expect(
        urlComponents.length,
        equals(1),
        reason: 'Should only have one URL for non-Bunny Stream CDNs',
      );
      expect(
        urlComponents.first,
        equals('url $regularUrl'),
        reason: 'Should use original CDN URL',
      );
    });
  });

  group('VideoEventPublisher mention tags', () {
    late _MockUploadManager uploadManager;
    late _MockNostrClient nostrClient;
    late _MockAuthService authService;
    late _MockVideoEventService videoEventService;
    late VideoEventPublisher publisher;
    late List<List<String>> capturedTags;

    const testPubkey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const mentionPubkey =
        'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';

    setUpAll(() {
      registerFallbackValue(_FakeEvent());
      registerFallbackValue(_FakeFilter());
      registerFallbackValue(<Filter>[]);
      registerFallbackValue(UploadStatus.pending);
      registerFallbackValue(File('fallback.mp3'));
      registerFallbackValue(
        AudioEvent(id: 'fallback', pubkey: 'fallback', createdAt: 0),
      );
      registerFallbackValue(Duration.zero);
    });

    setUp(() {
      uploadManager = _MockUploadManager();
      nostrClient = _MockNostrClient();
      authService = _MockAuthService();
      videoEventService = _MockVideoEventService();
      capturedTags = [];

      publisher = VideoEventPublisher(
        uploadManager: uploadManager,
        nostrService: nostrClient,
        authService: authService,
        videoEventService: videoEventService,
      );

      when(() => nostrClient.isInitialized).thenReturn(true);
      when(() => nostrClient.configuredRelayCount).thenReturn(1);
      when(() => nostrClient.connectedRelayCount).thenReturn(1);
      when(
        () => nostrClient.configuredRelays,
      ).thenReturn(['wss://relay.divine.video']);
      when(
        () => nostrClient.connectedRelays,
      ).thenReturn(['wss://relay.divine.video']);
      when(() => nostrClient.publicKey).thenReturn('');

      when(() => authService.isAuthenticated).thenReturn(true);
      when(() => authService.currentPublicKeyHex).thenReturn(testPubkey);

      when(
        () => uploadManager.updateUploadStatus(
          any(),
          any(),
          nostrEventId: any(named: 'nostrEventId'),
        ),
      ).thenAnswer((_) async {});
    });

    PendingUpload createUpload({String localVideoPath = ''}) {
      return PendingUpload(
        id: 'upload-id',
        localVideoPath: localVideoPath,
        nostrPubkey: testPubkey,
        status: UploadStatus.readyToPublish,
        createdAt: DateTime.now(),
        videoId: 'video-id',
        cdnUrl: 'https://cdn.example.com/video.mp4',
        fallbackUrl: 'https://cdn.example.com/video.mp4',
      );
    }

    void stubSignAndPublish() {
      late Event publishedEvent;

      when(
        () => authService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((invocation) async {
        capturedTags = invocation.namedArguments[#tags] as List<List<String>>;
        return publishedEvent = Event(
          testPubkey,
          NIP71VideoKinds.getPreferredAddressableKind(),
          capturedTags,
          'test content',
        );
      });

      when(
        () => nostrClient.publishEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer(
        (_) async => PublishOutcome(
          eventId: publishedEvent.id,
          acceptedBy: const ['wss://relay.divine.video'],
          rejectedBy: const {},
          noResponseFrom: const [],
        ),
      );
    }

    test('publishVideoEvent passes generic mention p-tags through', () async {
      stubSignAndPublish();

      final result = await publisher.publishVideoEvent(
        upload: createUpload(),
        mentionedPubkeys: const [mentionPubkey],
      );

      expect(result, isTrue);
      expect(
        _containsTag(capturedTags, const [
          'p',
          mentionPubkey,
          'wss://relay.divine.video',
          'mention',
        ]),
        isTrue,
      );
    });

    test('publishVideoEvent omits known dead media URLs from imeta', () async {
      stubSignAndPublish();

      final result = await publisher.publishVideoEvent(
        upload: createUpload().copyWith(
          streamingMp4Url:
              'https://stream.divine.video/fa4a90a3-6a30-4dc6-9b9d-3f78551c9053/play_360p.mp4',
          streamingHlsUrl:
              'https://stream.divine.video/fa4a90a3-6a30-4dc6-9b9d-3f78551c9053/playlist.m3u8',
          fallbackUrl: 'https://media.divine.video/fa4a90a3.mp4',
          cdnUrl: 'https://stream.divine.video/legacy/playlist.m3u8',
        ),
      );

      expect(result, isTrue);
      final imeta = capturedTags.singleWhere((tag) => tag.first == 'imeta');
      final imetaText = imeta.join(' ');
      expect(imetaText, contains('https://media.divine.video/fa4a90a3.mp4'));
      expect(imetaText, isNot(contains('stream.divine.video')));
    });

    test('publishVideoEvent writes an explicit false reuse marker', () async {
      stubSignAndPublish();

      expect(
        await publisher.publishVideoEvent(upload: createUpload()),
        isTrue,
      );
      expect(
        _containsTag(capturedTags, const ['allow_audio_reuse', 'false']),
        isTrue,
      );
    });

    test(
      'publishVideoEvent attaches text-track tags to the initial event',
      () async {
        stubSignAndPublish();

        final result = await publisher.publishVideoEvent(
          upload: createUpload(),
          textTrackRefs: const [
            'https://media.divine.video/captions.vtt',
            '39307:$testPubkey:subtitles:video-id',
          ],
          textTrackLang: 'de',
        );

        expect(result, isTrue);
        expect(
          _containsTag(capturedTags, const [
            'text-track',
            'https://media.divine.video/captions.vtt',
            'wss://relay.divine.video',
            'captions',
            'de',
          ]),
          isTrue,
        );
        expect(
          _containsTag(capturedTags, const [
            'text-track',
            '39307:$testPubkey:subtitles:video-id',
            'wss://relay.divine.video',
            'captions',
            'de',
          ]),
          isTrue,
        );
      },
    );

    group('reused audio attribution', () {
      // A reused original sound carries the source video's event id behind a
      // `video_` prefix; the reference must survive so the audio is credited
      // to the original creator instead of the reusing user (#6057).
      final sourceVideoId = 'b' * 64;
      final sourceCreator = 'c' * 64;

      test(
        'references the source video when reusing an original sound',
        () async {
          stubSignAndPublish();

          final reusedSound = AudioEvent(
            id: 'video_$sourceVideoId',
            pubkey: sourceCreator,
            createdAt: 1700000000,
            sourceVideoReference: '34236:$sourceCreator:vine-xyz',
          );

          final result = await publisher.publishVideoEvent(
            upload: createUpload(),
            selectedAudio: reusedSound,
            selectedAudioEventId: reusedSound.id,
            selectedAudioRelay: reusedSound.sourceVideoRelay,
          );

          expect(result, isTrue);
          expect(
            _containsTag(capturedTags, [
              'e',
              sourceVideoId,
              'wss://relay.divine.video',
              'audio',
            ]),
            isTrue,
          );
        },
      );

      /// A publisher whose consent checker answers with [consent], or throws
      /// [failure] when the check itself cannot be carried out.
      VideoEventPublisher publisherWithConsent({
        bool consent = false,
        Object? failure,
      }) {
        return VideoEventPublisher(
          uploadManager: uploadManager,
          nostrService: nostrClient,
          authService: authService,
          videoEventService: videoEventService,
          audioReuseConsentChecker: (_) async {
            if (failure != null) throw failure;
            return consent;
          },
        );
      }

      final withheldSound = AudioEvent(
        id: 'd' * 64,
        pubkey: sourceCreator,
        createdAt: 1700000000,
        allowsReuse: false,
        hasExplicitReuseConsent: true,
      );

      test('publishes with an enabled verified archive sound', () async {
        stubSignAndPublish();
        final classicVideo = VideoEvent(
          id: sourceVideoId,
          pubkey: sourceCreator,
          createdAt: 1700000000,
          content: '',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
          videoUrl: 'https://example.com/classic.mp4',
          addressableDTag: 'classic-vine',
          isVerifiedArchive: true,
          archiveAudioReuseEnabled: true,
        );
        final classicSound = AudioEvent.fromVideoOriginalSound(classicVideo);

        final result = await publisherWithConsent(consent: true)
            .publishVideoEvent(
              upload: createUpload(),
              selectedAudio: classicSound,
              selectedAudioEventId: classicSound.id,
            );

        expect(result, isTrue);
        expect(classicSound.allowsReuse, isTrue);
        expect(classicSound.hasExplicitReuseConsent, isFalse);
        expect(classicSound.requiresCurrentReuseVerification, isTrue);
      });

      test(
        'revalidates an archive grant after the saved-sound handoff',
        () async {
          stubSignAndPublish();
          final persistedSound = AudioEvent.fromJson(
            AudioEvent.fromVideoOriginalSound(
              VideoEvent(
                id: sourceVideoId,
                pubkey: sourceCreator,
                createdAt: 1700000000,
                content: '',
                timestamp: DateTime.fromMillisecondsSinceEpoch(
                  1700000000 * 1000,
                ),
                videoUrl: 'https://example.com/classic.mp4',
                isVerifiedArchive: true,
                archiveAudioReuseEnabled: true,
              ),
            ).toJson(),
          );

          expect(persistedSound.requiresCurrentReuseVerification, isTrue);
          expect(
            await publisherWithConsent(consent: true).publishVideoEvent(
              upload: createUpload(),
              selectedAudio: persistedSound,
              selectedAudioEventId: persistedSound.id,
            ),
            isTrue,
          );
        },
      );

      test(
        'blocks selected audio when the source explicitly forbids reuse',
        () async {
          stubSignAndPublish();

          await expectLater(
            publisherWithConsent().publishVideoEvent(
              upload: createUpload(),
              selectedAudio: withheldSound,
              selectedAudioEventId: withheldSound.id,
            ),
            throwsA(
              isA<AudioReuseNotPermittedException>().having(
                (error) => error.audioEventId,
                'audioEventId',
                withheldSound.id,
              ),
            ),
          );
          expect(
            _containsTag(capturedTags, [
              'e',
              withheldSound.id,
              'wss://relay.divine.video',
              'audio',
            ]),
            isFalse,
          );
        },
      );

      test('an explicit decline still permits the sound owner', () async {
        stubSignAndPublish();
        final ownDeclinedSound = withheldSound.copyWith(pubkey: testPubkey);

        final result = await publisher.publishVideoEvent(
          upload: createUpload(),
          selectedAudio: ownDeclinedSound,
          selectedAudioEventId: ownDeclinedSound.id,
        );

        expect(result, isTrue);
      });

      test('an unmarked legacy sound still permits the sound owner', () async {
        stubSignAndPublish();
        final ownLegacySound = AudioEvent(
          id: 'e' * 64,
          pubkey: testPubkey,
          createdAt: 1700000000,
          allowsReuse: false,
        );

        final result = await publisher.publishVideoEvent(
          upload: createUpload(),
          selectedAudio: ownLegacySound,
          selectedAudioEventId: ownLegacySound.id,
        );

        expect(result, isTrue);
      });

      test('a malformed reuse marker still permits the sound owner', () async {
        stubSignAndPublish();
        final ownedSound = AudioEvent.fromVideoOriginalSound(
          VideoEvent(
            id: sourceVideoId,
            pubkey: testPubkey,
            createdAt: 1700000000,
            content: '',
            timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
            videoUrl: 'https://example.com/owned.mp4',
            rawTags: const {'allow_audio_reuse': 'TRUE'},
          ),
        );

        expect(
          await publisher.publishVideoEvent(
            upload: createUpload(),
            selectedAudio: ownedSound,
            selectedAudioEventId: ownedSound.id,
          ),
          isTrue,
        );
      });

      // The legacy resolver's `false` cannot tell a refusal from an
      // unreachable relay, a source video outside the query window, or one the
      // viewer's own filters dropped. Raising the refusal on it would tell
      // those users to swap a sound that may well be cleared, and to stop
      // retrying the one thing that would have worked.
      test('reports an unverified legacy sound as a plain failure', () async {
        stubSignAndPublish();

        final legacySound = AudioEvent(
          id: 'e' * 64,
          pubkey: sourceCreator,
          createdAt: 1700000000,
          allowsReuse: false,
          sourceVideoReference: '34236:$sourceCreator:vine-xyz',
        );

        final result = await publisherWithConsent().publishVideoEvent(
          upload: createUpload(),
          selectedAudio: legacySound,
          selectedAudioEventId: legacySound.id,
        );

        expect(result, isFalse);
        expect(capturedTags, isEmpty);
      });

      // With no resolver wired there is nothing to ask, so a legacy sound
      // belonging to someone else must not be remixed on the strength of a
      // missing check. `publisher` here is the bare one from setUp.
      test('blocks reuse when no consent checker is wired', () async {
        stubSignAndPublish();

        final legacySound = AudioEvent(
          id: 'f' * 64,
          pubkey: sourceCreator,
          createdAt: 1700000000,
          allowsReuse: false,
          sourceVideoReference: '34236:$sourceCreator:vine-xyz',
        );

        final result = await publisher.publishVideoEvent(
          upload: createUpload(),
          selectedAudio: legacySound,
          selectedAudioEventId: legacySound.id,
        );

        expect(result, isFalse);
        expect(capturedTags, isEmpty);
      });

      test('recovers the reference from an editor timeline track id', () async {
        stubSignAndPublish();

        // The editor appends a `-<timestamp>` uniqueness suffix to timeline
        // track ids; the reference must still resolve to the source video.
        final reusedTrack = AudioEvent(
          id: 'video_$sourceVideoId-1700000000000',
          pubkey: sourceCreator,
          createdAt: 1700000000,
          sourceVideoReference: '34236:$sourceCreator:vine-xyz',
        );

        final result = await publisher.publishVideoEvent(
          upload: createUpload(),
          selectedAudio: reusedTrack,
          selectedAudioEventId: reusedTrack.id,
        );

        expect(result, isTrue);
        expect(
          _containsTag(capturedTags, [
            'e',
            sourceVideoId,
            'wss://relay.divine.video',
            'audio',
          ]),
          isTrue,
        );
      });

      test(
        'does not re-publish the video audio when a source is referenced',
        () async {
          stubSignAndPublish();

          final reusedSound = AudioEvent(
            id: 'video_$sourceVideoId',
            pubkey: sourceCreator,
            createdAt: 1700000000,
          );

          final result = await publisher.publishVideoEvent(
            upload: createUpload(localVideoPath: '/tmp/divine-video-6185.mp4'),
            allowAudioReuse: true,
            selectedAudio: reusedSound,
            selectedAudioEventId: reusedSound.id,
          );

          expect(result, isTrue);
          expect(
            _containsTag(capturedTags, const ['allow_audio_reuse', 'true']),
            isFalse,
          );
        },
      );

      test('honors audio reuse for bundled sounds', () async {
        final blossomUploadService = _MockBlossomUploadService();
        final audioExtractionService = _MockAudioExtractionService();
        final signedEvents = <Event>[];
        publisher = VideoEventPublisher(
          uploadManager: uploadManager,
          nostrService: nostrClient,
          authService: authService,
          videoEventService: videoEventService,
          blossomUploadService: blossomUploadService,
          audioExtractionService: audioExtractionService,
        );

        // A bundled sound has no Nostr event to reference, so the video's own
        // audio is the user's to offer and "Publish this sound" must still
        // take effect instead of being silently dropped (#6185).
        final bundledSound = AudioEvent(
          id: '${AudioEvent.bundledMarker}_oh_no_no_no_crowd',
          pubkey: AudioEvent.bundledMarker,
          createdAt: 0,
          url: 'asset://assets/sounds/oh-no-no-no-crowd.mp3',
        );

        const audioPath = '/tmp/divine-video-6185.m4a';
        when(
          () => audioExtractionService.extractAudio(
            videoPath: '/tmp/divine-video-6185.mp4',
          ),
        ).thenAnswer(
          (_) async => const AudioExtractionResult(
            audioFilePath: audioPath,
            duration: 6,
            fileSize: 12345,
            sha256Hash:
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
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
            videoId:
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          ),
        );
        when(
          () => authService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((invocation) async {
          final kind = invocation.namedArguments[#kind] as int;
          final content = invocation.namedArguments[#content] as String;
          final tags = invocation.namedArguments[#tags] as List<List<String>>;
          final event = Event(testPubkey, kind, tags, content);
          signedEvents.add(event);
          capturedTags = tags;
          return event;
        });
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

        final result = await publisher.publishVideoEvent(
          upload: createUpload(localVideoPath: '/tmp/divine-video-6185.mp4'),
          allowAudioReuse: true,
          selectedAudio: bundledSound,
          selectedAudioEventId: bundledSound.id,
        );

        expect(result, isTrue);
        expect(
          _containsTag(capturedTags, const ['allow_audio_reuse', 'true']),
          isTrue,
        );
        final audioEvent = signedEvents.singleWhere(
          (event) => event.kind == audioEventKind,
        );
        final fallbackName = UserProfile.defaultDisplayNameFor(testPubkey);
        expect(
          _containsTag(audioEvent.tags, [
            'title',
            'Original sound - @$fallbackName',
          ]),
          isTrue,
        );
        expect(
          _containsTag(audioEvent.tags, ['creator', fallbackName]),
          isTrue,
        );
        final publicCreditTags = audioEvent.tags
            .where(
              (tag) =>
                  tag.firstOrNull == 'title' || tag.firstOrNull == 'creator',
            )
            .expand((tag) => tag);
        expect(publicCreditTags.join(' '), isNot(contains(testPubkey)));
        final videoEvent = signedEvents.singleWhere(
          (event) => event.kind != audioEventKind,
        );
        expect(
          _containsTag(audioEvent.tags, const [
            'url',
            'https://cdn.example.com/audio.m4a',
          ]),
          isTrue,
        );
        expect(
          _containsTag(videoEvent.tags, [
            'e',
            audioEvent.id,
            'wss://relay.divine.video',
            'audio',
          ]),
          isTrue,
        );
      });

      // This group's publisher is built with no blossomUploadService and no
      // audioExtractionService, so the audio step returns at its first guard —
      // nothing is extracted or uploaded here. The real extraction-failure
      // path is covered in video_event_publisher_audio_degrade_test.dart.
      test('an unavailable audio pipeline still publishes the video, without '
          'claiming reuse', () async {
        stubSignAndPublish();

        final result = await publisher.publishVideoEvent(
          upload: createUpload(localVideoPath: '/tmp/video-with-audio.mp4'),
          allowAudioReuse: true,
        );

        // A video-only publish beats discarding an already-uploaded video.
        expect(result, isTrue);

        final tags =
            verify(
                  () => authService.createAndSignEvent(
                    kind: NIP71VideoKinds.getPreferredAddressableKind(),
                    content: any(named: 'content'),
                    tags: captureAny(named: 'tags'),
                  ),
                ).captured.single
                as List<List<String>>;

        // The event must never advertise reusable audio that was never
        // published — no allow_audio_reuse, and no audio `e` reference.
        expect(tags.where((tag) => tag.first == 'allow_audio_reuse'), isEmpty);
        expect(
          tags.where((tag) => tag.first == 'e' && tag.last == 'audio'),
          isEmpty,
        );
      });

      test(
        'publishes durable provider credit without claiming ownership',
        () async {
          stubSignAndPublish();

          final externalProviderSound = AudioEvent(
            id: 'freesound:12345',
            pubkey: AudioEvent.externalProviderMarker,
            createdAt: 0,
            url: 'https://cdn.example.com/freesound-preview.mp3',
            title: 'Morning birds',
            externalSource: AudioExternalSource(
              provider: 'freesound',
              providerSoundId: '12345',
              providerName: 'Freesound',
              creatorName: 'Catalog Artist',
              creatorUrl: 'https://freesound.org/people/catalog-artist/',
              sourceUrl:
                  'https://freesound.org/people/catalog-artist/sounds/12345/',
              catalogTags: const ['birds', 'field-recording'],
              license: AudioLicenseMetadata(
                type: 'cc-by',
                name: 'Creative Commons Attribution',
                url: 'https://creativecommons.org/licenses/by/4.0/',
                allowsCommercialUse: true,
                allowsDerivatives: true,
                requiresAttribution: true,
              ),
            ),
          );

          final result = await publisher.publishVideoEvent(
            upload: createUpload(localVideoPath: '/tmp/divine-video-6185.mp4'),
            allowAudioReuse: true,
            selectedAudio: externalProviderSound,
            selectedAudioEventId: externalProviderSound.id,
          );

          expect(result, isTrue);
          final captured = verify(
            () => authService.createAndSignEvent(
              kind: audioEventKind,
              content: captureAny(named: 'content'),
              tags: captureAny(named: 'tags'),
            ),
          ).captured;
          final audioContent = captured[0] as String;
          final audioTags = captured[1] as List<List<String>>;
          expect(audioContent, contains('Catalog Artist'));
          expect(
            _containsTag(audioTags, const ['proxy', '12345', 'freesound']),
            isTrue,
          );
          expect(
            _containsTag(audioTags, const [
              'source',
              'https://freesound.org/people/catalog-artist/sounds/12345/',
            ]),
            isTrue,
          );
          expect(
            _containsTag(audioTags, const ['creator', 'Catalog Artist']),
            isTrue,
          );
          expect(
            _containsTag(audioTags, const [
              'license',
              'Creative Commons Attribution',
            ]),
            isTrue,
          );
          expect(
            _containsTag(audioTags, const ['allow_audio_reuse', 'true']),
            isTrue,
          );
          expect(
            audioTags.where((tag) => tag.first == 't').toList(),
            equals([
              ['t', 'birds'],
              ['t', 'field-recording'],
            ]),
          );
        },
      );

      test(
        'provider bridge keeps reuse off when the video toggle is off',
        () async {
          stubSignAndPublish();
          final externalProviderSound = AudioEvent(
            id: 'freesound:12345',
            pubkey: AudioEvent.externalProviderMarker,
            createdAt: 0,
            url: 'https://cdn.example.com/freesound-preview.mp3',
            externalSource: AudioExternalSource(
              provider: 'freesound',
              providerSoundId: '12345',
              providerName: 'Freesound',
              creatorName: 'Catalog Artist',
              sourceUrl: 'https://freesound.org/s/12345/',
              license: AudioLicenseMetadata(
                type: 'cc-by',
                name: 'Creative Commons Attribution',
                url: 'https://creativecommons.org/licenses/by/4.0/',
                allowsCommercialUse: true,
                allowsDerivatives: true,
                requiresAttribution: true,
              ),
            ),
          );

          expect(
            await publisher.publishVideoEvent(
              upload: createUpload(),
              selectedAudio: externalProviderSound,
              selectedAudioEventId: externalProviderSound.id,
            ),
            isTrue,
          );

          final captured =
              verify(
                    () => authService.createAndSignEvent(
                      kind: audioEventKind,
                      content: any(named: 'content'),
                      tags: captureAny(named: 'tags'),
                    ),
                  ).captured.single
                  as List<List<String>>;
          expect(
            _containsTag(captured, const ['allow_audio_reuse', 'false']),
            isTrue,
          );
        },
      );
    });

    test('provider license can forbid further reuse', () async {
      stubSignAndPublish();
      final sound = AudioEvent(
        id: 'freesound:locked',
        pubkey: AudioEvent.externalProviderMarker,
        createdAt: 0,
        url: 'https://cdn.example.com/locked.mp3',
        externalSource: AudioExternalSource(
          provider: 'freesound',
          providerSoundId: 'locked',
          providerName: 'Freesound',
          creatorName: 'Catalog Artist',
          sourceUrl: 'https://freesound.org/s/locked/',
          license: AudioLicenseMetadata(
            type: 'no-derivatives',
            name: 'No derivatives',
            url: 'https://license.example/no-derivatives',
            allowsCommercialUse: true,
            allowsDerivatives: false,
            requiresAttribution: true,
          ),
        ),
      );

      expect(
        await publisher.publishVideoEvent(
          upload: createUpload(),
          selectedAudio: sound,
          selectedAudioEventId: sound.id,
          allowAudioReuse: true,
        ),
        isTrue,
      );

      final tags =
          verify(
                () => authService.createAndSignEvent(
                  kind: audioEventKind,
                  content: any(named: 'content'),
                  tags: captureAny(named: 'tags'),
                ),
              ).captured.single
              as List<List<String>>;
      expect(_containsTag(tags, const ['allow_audio_reuse', 'false']), isTrue);
    });

    test(
      'blocks provider audio without durable credit only when reuse is asked '
      'for',
      () async {
        stubSignAndPublish();

        expect(
          await publisher.publishVideoEvent(
            upload: createUpload(localVideoPath: '/tmp/divine-video-6185.mp4'),
            allowAudioReuse: true,
            selectedAudio: _uncreditedProviderSound,
            selectedAudioEventId: _uncreditedProviderSound.id,
          ),
          isFalse,
        );
        verifyNever(
          () => authService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        );
      },
    );

    test(
      'publishes without the provider reference when reuse was never asked for',
      () async {
        stubSignAndPublish();

        expect(
          await publisher.publishVideoEvent(
            upload: createUpload(),
            selectedAudio: _uncreditedProviderSound,
            selectedAudioEventId: _uncreditedProviderSound.id,
          ),
          isTrue,
        );
        verifyNever(
          () => authService.createAndSignEvent(
            kind: audioEventKind,
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        );
      },
    );

    test('credits the provider when the catalog row has no creator', () async {
      stubSignAndPublish();
      final thinCatalogRow = AudioEvent(
        id: 'freesound:thin',
        pubkey: AudioEvent.externalProviderMarker,
        createdAt: 0,
        url: 'https://cdn.example.com/thin.mp3',
        externalSource: AudioExternalSource(
          provider: 'freesound',
          providerSoundId: 'thin',
          providerName: 'Freesound',
          sourceUrl: 'https://freesound.org/s/thin/',
          license: AudioLicenseMetadata(
            type: 'cc0',
            name: 'CC0',
            url: 'https://creativecommons.org/publicdomain/zero/1.0/',
            allowsCommercialUse: true,
            allowsDerivatives: true,
            requiresAttribution: false,
          ),
        ),
      );

      expect(
        await publisher.publishVideoEvent(
          upload: createUpload(localVideoPath: '/tmp/divine-video-6185.mp4'),
          allowAudioReuse: true,
          selectedAudio: thinCatalogRow,
          selectedAudioEventId: thinCatalogRow.id,
        ),
        isTrue,
      );
      final audioContent =
          verify(
                () => authService.createAndSignEvent(
                  kind: audioEventKind,
                  content: captureAny(named: 'content'),
                  tags: any(named: 'tags'),
                ),
              ).captured.single
              as String;
      expect(audioContent, contains('Freesound'));
    });

    group('local imported audio', () {
      late _MockBlossomUploadService blossomUploadService;
      late _MockSavedSoundsService savedSoundsService;
      late _MockSoundSyncRepository syncRepository;
      late List<Event> signedEvents;

      setUp(() {
        blossomUploadService = _MockBlossomUploadService();
        savedSoundsService = _MockSavedSoundsService();
        syncRepository = _MockSoundSyncRepository();
        signedEvents = [];

        publisher = VideoEventPublisher(
          uploadManager: uploadManager,
          nostrService: nostrClient,
          authService: authService,
          videoEventService: videoEventService,
          blossomUploadService: blossomUploadService,
          savedSoundsService: savedSoundsService,
          soundSyncRepositoryGetter: () => syncRepository,
        );

        when(
          () => savedSoundsService.saveSound(any()),
        ).thenAnswer((_) async => SavedSoundSaveResult.saved);

        when(
          () => syncRepository.publishLocalChange(any()),
        ).thenAnswer((_) async {});

        when(
          () => authService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((invocation) async {
          final kind = invocation.namedArguments[#kind] as int;
          final content = invocation.namedArguments[#content] as String;
          final tags = invocation.namedArguments[#tags] as List<List<String>>;
          final event = Event(testPubkey, kind, tags, content);
          signedEvents.add(event);
          return event;
        });

        when(
          () => nostrClient.publishEventAwaitOk(
            any(),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((invocation) async {
          final event = invocation.positionalArguments.first as Event;
          return PublishOutcome(
            eventId: event.id,
            acceptedBy: const ['wss://relay.divine.video'],
            rejectedBy: const {},
            noResponseFrom: const [],
          );
        });
      });

      test(
        'publishes local imported audio before video and tags video event',
        () async {
          final audioFile = File(
            '${Directory.systemTemp.path}/imported_audio.mp3',
          );
          await audioFile.writeAsBytes([1, 2, 3]);
          addTearDown(() {
            if (audioFile.existsSync()) audioFile.deleteSync();
          });

          final localAudio = AudioEvent.fromLocalImport(
            id: 'local_import_1700000000000',
            filePath: audioFile.path,
            createdAt: 1700000000,
            title: 'imported_audio',
            mimeType: 'audio/mpeg',
            duration: 3,
          );

          when(
            () => blossomUploadService.uploadAudio(
              audioFile: any(named: 'audioFile'),
              mimeType: 'audio/mpeg',
              onProgress: any(named: 'onProgress'),
            ),
          ).thenAnswer(
            (_) async => const BlossomUploadResult(
              success: true,
              url: 'https://cdn.example/audiohash',
              fallbackUrl: 'https://cdn.example/audiohash',
              videoId:
                  'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            ),
          );

          final result = await publisher.publishVideoEvent(
            upload: createUpload(),
            allowAudioReuse: true,
            selectedAudio: localAudio,
            audioShareAttribution: const AudioShareAttribution(
              title: 'Rain on a roof',
              creatorName: 'Field Recordist',
              creatorUrl: 'https://creator.example/profile',
              sourceUrl: 'https://creator.example/rain',
              licenseName: 'CC BY 4.0',
              licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
              publicTags: ['rain', 'field-recording'],
              confirmedOwnWork: false,
            ),
          );

          expect(result, isTrue);

          final audioEvent = signedEvents.singleWhere(
            (event) => event.kind == audioEventKind,
          );
          expect(
            _containsTag(audioEvent.tags, const [
              'url',
              'https://cdn.example/audiohash',
            ]),
            isTrue,
          );
          expect(
            _containsTag(audioEvent.tags, const ['m', 'audio/mpeg']),
            isTrue,
          );
          expect(
            _containsTag(audioEvent.tags, const [
              'x',
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            ]),
            isTrue,
          );
          expect(_containsTag(audioEvent.tags, const ['size', '3']), isTrue);
          expect(
            _containsTag(audioEvent.tags, const ['title', 'Rain on a roof']),
            isTrue,
          );
          expect(
            _containsTag(audioEvent.tags, const ['creator', 'Field Recordist']),
            isTrue,
          );
          expect(
            _containsTag(audioEvent.tags, const ['allow_audio_reuse', 'true']),
            isTrue,
          );
          final publishedAudio = [
            audioEvent.content,
            ...audioEvent.tags.expand((tag) => tag),
          ].join(' ');
          expect(publishedAudio, isNot(contains('imported_audio')));
          expect(publishedAudio, isNot(contains('personalLabel')));
          expect(publishedAudio, isNot(contains('personalHashtags')));

          final videoEvent = signedEvents.singleWhere(
            (event) => event.kind != audioEventKind,
          );
          expect(
            _containsTag(videoEvent.tags, [
              'e',
              audioEvent.id,
              'wss://relay.divine.video',
              'audio',
            ]),
            isTrue,
          );
          verify(() => savedSoundsService.saveSound(any())).called(1);
          verify(
            () => syncRepository.publishLocalChange(audioEvent.id),
          ).called(1);
        },
      );

      test('a sync failure does not fail the video publish', () async {
        when(
          () => syncRepository.publishLocalChange(any()),
        ).thenThrow(SyncIndexException('relay down'));

        final audioFile = File(
          '${Directory.systemTemp.path}/imported_audio_sync_failure.mp3',
        );
        await audioFile.writeAsBytes([1, 2, 3]);
        addTearDown(() {
          if (audioFile.existsSync()) audioFile.deleteSync();
        });

        when(
          () => blossomUploadService.uploadAudio(
            audioFile: any(named: 'audioFile'),
            mimeType: 'audio/mpeg',
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer(
          (_) async => const BlossomUploadResult(
            success: true,
            url: 'https://cdn.example/audiohash',
            fallbackUrl: 'https://cdn.example/audiohash',
            videoId:
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          ),
        );

        final result = await publisher.publishVideoEvent(
          upload: createUpload(),
          allowAudioReuse: true,
          selectedAudio: AudioEvent.fromLocalImport(
            id: 'local_import_1700000000001',
            filePath: audioFile.path,
            createdAt: 1700000000,
            title: 'imported_audio_sync_failure',
            mimeType: 'audio/mpeg',
            duration: 3,
          ),
          audioShareAttribution: const AudioShareAttribution(
            title: 'Rain on a roof',
            creatorName: 'Field Recordist',
            creatorUrl: 'https://creator.example/profile',
            sourceUrl: 'https://creator.example/rain',
            licenseName: 'CC BY 4.0',
            licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
            publicTags: ['rain', 'field-recording'],
            confirmedOwnWork: false,
          ),
        );

        expect(result, isTrue);
        verify(() => savedSoundsService.saveSound(any())).called(1);
        // The mirror sits inside an enclosing catch-and-log, so without
        // this the test would pass unchanged even if _mirrorSavedSound's
        // own try/catch — or the mirror call entirely — were deleted.
        verify(() => syncRepository.publishLocalChange(any())).called(1);
      });

      test(
        'publishes video privately without uploading a local import',
        () async {
          final localAudio = AudioEvent.fromLocalImport(
            id: 'local_import_1700000000000',
            filePath: '${Directory.systemTemp.path}/private_import.mp3',
            createdAt: 1700000000,
            title: 'private',
            mimeType: 'audio/mpeg',
          );

          final result = await publisher.publishVideoEvent(
            upload: createUpload(),
            selectedAudio: localAudio,
          );

          expect(result, isTrue);
          expect(
            signedEvents.where((event) => event.kind == audioEventKind),
            isEmpty,
          );
          verifyNever(
            () => blossomUploadService.uploadAudio(
              audioFile: any(named: 'audioFile'),
              mimeType: any(named: 'mimeType'),
              onProgress: any(named: 'onProgress'),
            ),
          );
        },
      );

      test(
        'rejects reusable local import without public attribution before upload',
        () async {
          final localAudio = AudioEvent.fromLocalImport(
            id: 'local_import_1700000000000',
            filePath: '${Directory.systemTemp.path}/private_import.mp3',
            createdAt: 1700000000,
            title: 'private',
            mimeType: 'audio/mpeg',
          );

          final result = await publisher.publishVideoEvent(
            upload: createUpload(),
            selectedAudio: localAudio,
            allowAudioReuse: true,
          );

          expect(result, isFalse);
          expect(signedEvents, isEmpty);
          verifyNever(
            () => blossomUploadService.uploadAudio(
              audioFile: any(named: 'audioFile'),
              mimeType: any(named: 'mimeType'),
              onProgress: any(named: 'onProgress'),
            ),
          );
        },
      );

      test(
        'blocks reusable local import when attributed audio cannot be published',
        () async {
          final localAudio = AudioEvent.fromLocalImport(
            id: 'local_import_1700000000000',
            filePath: '${Directory.systemTemp.path}/missing_imported_audio.mp3',
            createdAt: 1700000000,
            title: 'missing',
            mimeType: 'audio/mpeg',
          );

          final result = await publisher.publishVideoEvent(
            upload: createUpload(),
            selectedAudio: localAudio,
            allowAudioReuse: true,
            audioShareAttribution: const AudioShareAttribution(
              title: 'Missing sound',
              creatorName: 'Me',
              publicTags: [],
              confirmedOwnWork: true,
            ),
          );

          expect(result, isFalse);
          expect(
            signedEvents.where((event) => event.kind != audioEventKind),
            isEmpty,
          );
        },
      );
    });
  });

  group('publishEvent timeout guard', () {
    // Locks the contract introduced in video_event_publisher.dart's
    // `_publishEventToNostr`: a derived `Future.timeout` wrapped in
    // try/catch (TimeoutException) so a stalled relay-pool send cannot
    // freeze the publish flow. We use the try/catch shape (not
    // `onTimeout: () => null`) because mocktail-stubbed Futures lose
    // their declared `?` nullability at runtime, which would make the
    // onTimeout closure-cast throw — see
    // `test/diag/mocktail_timeout_diag_test.dart` for the full diagnosis.
    //
    // The duration used here is incidental to the pattern under test;
    // production sizes the timeout via `outerPublishTimeoutFor`, covered
    // by the dedicated group below.
    const patternTimeout = Duration(seconds: 30);

    test('a never-completing publishEvent future surfaces TimeoutException '
        'and is mapped to null', () {
      fakeAsync((async) {
        final never = Completer<String?>();
        var completed = false;
        String? result;

        // Mirrors the exact wrapping inside _publishEventToNostr.
        Future<void> wrapped() async {
          try {
            result = await never.future.timeout(patternTimeout);
          } on TimeoutException {
            result = null;
          }
          completed = true;
        }

        unawaited(wrapped());

        // Just before the timeout — must still be pending.
        async.elapse(const Duration(seconds: 29));
        expect(completed, isFalse);

        // Cross the timeout boundary.
        async.elapse(const Duration(seconds: 2));
        expect(completed, isTrue);
        expect(result, isNull);
      });
    });

    test('a publishEvent future that completes before the timeout returns its '
        'value', () {
      fakeAsync((async) {
        final completer = Completer<String?>();
        var resolvedValue = 'unset';

        Future<void> wrapped() async {
          try {
            final value = await completer.future.timeout(patternTimeout);
            resolvedValue = value ?? 'null';
          } on TimeoutException {
            resolvedValue = 'timeout';
          }
        }

        unawaited(wrapped());

        async.elapse(const Duration(seconds: 5));
        completer.complete('signed_event_id');
        async.flushMicrotasks();

        expect(resolvedValue, equals('signed_event_id'));
      });
    });
  });

  group('outerPublishTimeoutFor', () {
    // Pins the derivation introduced as the follow-up to PR #3683 / issue
    // #3688: the outer publish timeout is `RelayPool.perRelaySendTimeout *
    // relayCount + buffer`, clamped to `[floor, ceiling]`. Encoding the
    // relationship in code keeps the outer guard from silently firing
    // before the inner sequential fan-out can complete on degraded
    // networks, regardless of how many relays the user configures.

    test('clamps to the floor when the relay count is zero', () {
      // 0 * 5s + 5s = 5s, which is below the 10s floor.
      expect(outerPublishTimeoutFor(0), equals(const Duration(seconds: 10)));
    });

    test('still clamps to the floor for a single relay', () {
      // 1 * 5s + 5s = 10s, exactly at the floor — never below it.
      expect(outerPublishTimeoutFor(1), equals(const Duration(seconds: 10)));
    });

    test('scales linearly between the floor and ceiling', () {
      // 2 * 5s + 5s = 15s
      expect(outerPublishTimeoutFor(2), equals(const Duration(seconds: 15)));
      // 6 * 5s + 5s = 35s — the current default-config worst case.
      expect(outerPublishTimeoutFor(6), equals(const Duration(seconds: 35)));
      // 11 * 5s + 5s = 60s, exactly at the ceiling.
      expect(outerPublishTimeoutFor(11), equals(const Duration(seconds: 60)));
    });

    test('clamps to the ceiling for misconfigured huge relay lists', () {
      // 12 * 5s + 5s = 65s → clamped to 60s ceiling. Bounds worst-case
      // publish latency so the user never stares at a spinner for
      // several minutes.
      expect(outerPublishTimeoutFor(12), equals(const Duration(seconds: 60)));
      expect(outerPublishTimeoutFor(50), equals(const Duration(seconds: 60)));
    });

    test('strictly exceeds the inner worst-case fan-out up to the ceiling '
        'boundary', () {
      // The whole point of the derivation: the outer guard must never
      // fire before the inner sequential fan-out inside
      // `RelayPool._sendCollect` can complete. Asserts the invariant
      // strictly (with the buffer present) for the full range up to
      // the ceiling boundary.
      for (final relayCount in [0, 1, 2, 6, 7, 11]) {
        final innerWorstCase = RelayPool.perRelaySendTimeout * relayCount;
        final outer = outerPublishTimeoutFor(relayCount);
        expect(
          outer > innerWorstCase,
          isTrue,
          reason:
              'outer ($outer) must strictly exceed inner worst case '
              '($innerWorstCase) for relayCount=$relayCount '
              '(buffer must be present)',
        );
      }
    });

    test('invariant degrades at the ceiling boundary (relayCount >= 12)', () {
      // Pinned trade-off: clamping to the 60s ceiling means the
      // strict `outer > inner_worst_case` invariant evaporates at the
      // boundary and inverts beyond it. This test locks the documented
      // edge so any change to the ceiling, the per-relay timeout, or
      // the buffer surfaces here loudly. See the
      // `_outerPublishTimeoutCeiling` doc comment for the rationale.

      // At relayCount == 12: derived = 12 * 5s + 5s = 65s, clamped to
      // 60s. Inner worst case = 12 * 5s = 60s. Outer == inner; buffer
      // is gone but the invariant is not yet violated.
      final innerAt12 = RelayPool.perRelaySendTimeout * 12;
      final outerAt12 = outerPublishTimeoutFor(12);
      expect(outerAt12, equals(const Duration(seconds: 60)));
      expect(outerAt12, equals(innerAt12));
      expect(
        outerAt12 > innerAt12,
        isFalse,
        reason: 'buffer is exhausted at relayCount == 12',
      );

      // At relayCount == 13: derived = 70s, clamped to 60s. Inner
      // worst case = 65s. Outer < inner — the original false-negative
      // failure mode is back for this edge. The retry loop in
      // VideoEventPublisher.publishDirectUpload absorbs it.
      final innerAt13 = RelayPool.perRelaySendTimeout * 13;
      final outerAt13 = outerPublishTimeoutFor(13);
      expect(outerAt13, equals(const Duration(seconds: 60)));
      expect(
        outerAt13 < innerAt13,
        isTrue,
        reason:
            'invariant breaks at relayCount == 13: '
            'outer ($outerAt13) < inner ($innerAt13)',
      );
    });
  });
}

/// A catalog row with neither a creator nor a source URL — no durable public
/// credit can be built from it.
final _uncreditedProviderSound = AudioEvent(
  id: 'freesound:uncredited',
  pubkey: AudioEvent.externalProviderMarker,
  createdAt: 0,
  url: 'https://cdn.example.com/uncredited.mp3',
  externalSource: AudioExternalSource(
    provider: 'freesound',
    providerSoundId: 'uncredited',
    providerName: 'Freesound',
    license: AudioLicenseMetadata(
      type: 'cc0',
      name: 'CC0',
      url: 'https://creativecommons.org/publicdomain/zero/1.0/',
      allowsCommercialUse: true,
      allowsDerivatives: true,
      requiresAttribution: false,
    ),
  ),
);

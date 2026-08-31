// ABOUTME: Tests for AudioEvent model - Kind 1063 audio file metadata events
// ABOUTME: Validates parsing from Nostr events, tag generation, and edge cases

import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';
import 'package:test/test.dart';

// Valid 64-character hex pubkey for testing
const testPubkey =
    'abc123def456789012345678901234'
    '567890123456789012345678901234abcd';

// Valid 64-character hex SHA-256 hash for testing
const testSha256 =
    'e3b0c44298fc1c149afbf4c8996fb924'
    '27ae41e4649b934ca495991b7852b855';

// Valid 64-character hex ID for testing
const testHexId =
    'abc123def456789012345678901234'
    '567890123456789012345678901234abcd';

void main() {
  group('AudioEvent', () {
    group('fromNostrEvent', () {
      test('parses complete audio event with all fields', () {
        // Arrange
        final nostrEvent = Event(
          testPubkey,
          1063,
          [
            ['url', 'https://blossom.example/abc123.aac'],
            ['m', 'audio/aac'],
            ['x', testSha256],
            ['size', '98765'],
            ['duration', '6.2'],
            ['title', 'Original sound - @username'],
            ['a', '34236:pubkey123:vine-id-456', 'wss://relay.example'],
          ],
          '',
          createdAt: 1700000000,
        );

        // Act
        final audioEvent = AudioEvent.fromNostrEvent(nostrEvent);

        // Assert
        expect(audioEvent.id, equals(nostrEvent.id));
        expect(audioEvent.pubkey, equals(testPubkey));
        expect(audioEvent.url, equals('https://blossom.example/abc123.aac'));
        expect(audioEvent.mimeType, equals('audio/aac'));
        expect(audioEvent.sha256, equals(testSha256));
        expect(audioEvent.fileSize, equals(98765));
        expect(audioEvent.duration, closeTo(6.2, 0.001));
        expect(audioEvent.title, equals('Original sound - @username'));
        expect(
          audioEvent.sourceVideoReference,
          equals('34236:pubkey123:vine-id-456'),
        );
        expect(audioEvent.sourceVideoRelay, equals('wss://relay.example'));
        expect(audioEvent.createdAt, equals(1700000000));
      });

      test('parses audio event with minimal required fields', () {
        // Arrange - only url and m are truly required per NIP-94
        final nostrEvent = Event(
          testPubkey,
          1063,
          [
            ['url', 'https://cdn.example/audio.aac'],
            ['m', 'audio/mp4'],
          ],
          '',
          createdAt: 1700000000,
        );

        // Act
        final audioEvent = AudioEvent.fromNostrEvent(nostrEvent);

        // Assert
        expect(audioEvent.url, equals('https://cdn.example/audio.aac'));
        expect(audioEvent.mimeType, equals('audio/mp4'));
        expect(audioEvent.sha256, isNull);
        expect(audioEvent.fileSize, isNull);
        expect(audioEvent.duration, isNull);
        expect(audioEvent.title, isNull);
        expect(audioEvent.sourceVideoReference, isNull);
        expect(audioEvent.hasExplicitReuseConsent, isFalse);
        expect(audioEvent.allowsReuse, isFalse);
      });

      test('only explicit true allows reuse for a published sound', () {
        AudioEvent parseWith(String value) => AudioEvent.fromNostrEvent(
          Event(
            testPubkey,
            1063,
            [
              ['allow_audio_reuse', value],
            ],
            '',
            createdAt: 1700000000,
          ),
        );

        expect(parseWith('true').allowsReuse, isTrue);
        expect(parseWith('false').allowsReuse, isFalse);
        expect(parseWith('TRUE').allowsReuse, isFalse);
        expect(parseWith('true').hasExplicitReuseConsent, isTrue);
        expect(parseWith('false').hasExplicitReuseConsent, isTrue);
      });

      test('parses public credit, tags, and proxy provenance', () {
        final nostrEvent = Event(
          testPubkey,
          1063,
          [
            ['allow_audio_reuse', 'true'],
            ['creator', 'Field Recordist'],
            ['creator_url', 'https://creator.example/profile'],
            ['license', 'CC BY 4.0'],
            ['license_url', 'https://creativecommons.org/licenses/by/4.0/'],
            ['p', testHexId],
            ['t', 'field-recording'],
            ['t', 'birds'],
            ['proxy', '12345', 'freesound'],
          ],
          '',
          createdAt: 1700000000,
        );

        final audioEvent = AudioEvent.fromNostrEvent(nostrEvent);

        expect(audioEvent.creatorName, equals('Field Recordist'));
        expect(audioEvent.creatorPubkey, equals(testHexId));
        expect(
          audioEvent.creatorUrl,
          equals('https://creator.example/profile'),
        );
        expect(audioEvent.licenseName, equals('CC BY 4.0'));
        expect(
          audioEvent.licenseUrl,
          equals('https://creativecommons.org/licenses/by/4.0/'),
        );
        expect(audioEvent.publicTags, equals(['field-recording', 'birds']));
        expect(audioEvent.proxyId, equals('12345'));
        expect(audioEvent.proxyProtocol, equals('freesound'));
      });

      test('throws for non-1063 event kind', () {
        // Arrange
        final nostrEvent = Event(
          testPubkey,
          34236, // Wrong kind - this is video
          [
            ['url', 'https://example.com/video.mp4'],
          ],
          '',
          createdAt: 1700000000,
        );

        // Act & Assert
        expect(
          () => AudioEvent.fromNostrEvent(nostrEvent),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('parses duration as integer seconds', () {
        // Arrange - some clients might send integer duration
        final nostrEvent = Event(
          testPubkey,
          1063,
          [
            ['url', 'https://example.com/audio.aac'],
            ['m', 'audio/aac'],
            ['duration', '6'],
          ],
          '',
          createdAt: 1700000000,
        );

        // Act
        final audioEvent = AudioEvent.fromNostrEvent(nostrEvent);

        // Assert
        expect(audioEvent.duration, equals(6.0));
      });

      test("handles malformed duration gracefully (Postel's law)", () {
        // Arrange
        final nostrEvent = Event(
          testPubkey,
          1063,
          [
            ['url', 'https://example.com/audio.aac'],
            ['m', 'audio/aac'],
            ['duration', 'not-a-number'],
          ],
          '',
          createdAt: 1700000000,
        );

        // Act
        final audioEvent = AudioEvent.fromNostrEvent(nostrEvent);

        // Assert - should not crash, just return null
        expect(audioEvent.duration, isNull);
      });

      test("handles malformed size gracefully (Postel's law)", () {
        // Arrange
        final nostrEvent = Event(
          testPubkey,
          1063,
          [
            ['url', 'https://example.com/audio.aac'],
            ['m', 'audio/aac'],
            ['size', 'invalid'],
          ],
          '',
          createdAt: 1700000000,
        );

        // Act
        final audioEvent = AudioEvent.fromNostrEvent(nostrEvent);

        // Assert
        expect(audioEvent.fileSize, isNull);
      });

      test('parses a tag without relay hint', () {
        // Arrange
        final nostrEvent = Event(
          testPubkey,
          1063,
          [
            ['url', 'https://example.com/audio.aac'],
            ['m', 'audio/aac'],
            ['a', '34236:somepubkey:some-vine-id'],
          ],
          '',
          createdAt: 1700000000,
        );

        // Act
        final audioEvent = AudioEvent.fromNostrEvent(nostrEvent);

        // Assert
        expect(
          audioEvent.sourceVideoReference,
          equals('34236:somepubkey:some-vine-id'),
        );
        expect(audioEvent.sourceVideoRelay, isNull);
      });

      test('handles empty tags array', () {
        // Arrange
        final nostrEvent = Event(
          testPubkey,
          1063,
          [],
          '',
          createdAt: 1700000000,
        );

        // Act
        final audioEvent = AudioEvent.fromNostrEvent(nostrEvent);

        // Assert
        expect(audioEvent.url, isNull);
        expect(audioEvent.mimeType, isNull);
      });
    });

    test('restored events without consent fail closed', () {
      final restored = AudioEvent.fromJson(const {
        'id': testHexId,
        'pubkey': testPubkey,
        'createdAt': 1700000000,
        'url': 'https://cdn.example/audio.aac',
        'mimeType': 'audio/aac',
      });

      expect(restored.allowsReuse, isFalse);
      expect(restored.hasExplicitReuseConsent, isFalse);
    });

    group('fromBundledSound', () {
      test('creates AudioEvent from VineSound with correct fields', () {
        // Arrange
        final vineSound = VineSound(
          id: 'bruh',
          title: 'Bruh Sound Effect',
          assetPath: 'assets/sounds/bruh-sound-effect.mp3',
          duration: const Duration(milliseconds: 1000),
          tags: ['meme', 'reaction', 'classic'],
        );

        // Act
        final audioEvent = AudioEvent.fromBundledSound(vineSound);

        // Assert
        expect(audioEvent.id, equals('${AudioEvent.bundledMarker}_bruh'));
        expect(audioEvent.pubkey, equals(AudioEvent.bundledMarker));
        expect(audioEvent.createdAt, equals(0));
        expect(
          audioEvent.url,
          equals('asset://assets/sounds/bruh-sound-effect.mp3'),
        );
        expect(audioEvent.mimeType, equals('audio/mpeg'));
        expect(audioEvent.duration, equals(1.0));
        expect(audioEvent.title, equals('Bruh Sound Effect'));
      });

      test('isBundled returns true for bundled sounds', () {
        final vineSound = VineSound(
          id: 'test',
          title: 'Test Sound',
          assetPath: 'assets/sounds/test.mp3',
          duration: const Duration(seconds: 2),
        );

        final audioEvent = AudioEvent.fromBundledSound(vineSound);

        expect(audioEvent.isBundled, isTrue);
      });

      test('isBundled returns false for Nostr sounds', () {
        final audioEvent = AudioEvent(
          id: testHexId,
          pubkey: testPubkey,
          createdAt: 1700000000,
          url: 'https://blossom.example/audio.aac',
        );

        expect(audioEvent.isBundled, isFalse);
      });

      test('assetPath returns path for bundled sounds', () {
        final vineSound = VineSound(
          id: 'vine_boom',
          title: 'Vine Boom',
          assetPath: 'assets/sounds/vine-boom.mp3',
          duration: const Duration(seconds: 7),
        );

        final audioEvent = AudioEvent.fromBundledSound(vineSound);

        expect(audioEvent.assetPath, equals('assets/sounds/vine-boom.mp3'));
      });

      test('assetPath returns null for Nostr sounds', () {
        final audioEvent = AudioEvent(
          id: testHexId,
          pubkey: testPubkey,
          createdAt: 1700000000,
          url: 'https://blossom.example/audio.aac',
        );

        expect(audioEvent.assetPath, isNull);
      });

      test('converts duration correctly from milliseconds', () {
        final vineSound = VineSound(
          id: 'test',
          title: 'Test',
          assetPath: 'assets/sounds/test.mp3',
          duration: const Duration(milliseconds: 4500),
        );

        final audioEvent = AudioEvent.fromBundledSound(vineSound);

        expect(audioEvent.duration, equals(4.5));
      });

      test('passes source attribution from VineSound with artist', () {
        final vineSound = VineSound(
          id: 'freesound_crowd',
          title: 'Oh No No No Crowd',
          assetPath: 'assets/sounds/oh-no-no-no-crowd.mp3',
          duration: const Duration(milliseconds: 5943),
          artist: 'ThePauny',
          license: 'CC0',
          sourceUrl: 'https://freesound.org/people/ThePauny/sounds/502915/',
        );

        final audioEvent = AudioEvent.fromBundledSound(vineSound);

        expect(audioEvent.source, equals('ThePauny via Freesound'));
      });

      test('omits source when VineSound has no artist or sourceUrl', () {
        final vineSound = VineSound(
          id: 'meme_bruh',
          title: 'Bruh Sound Effect',
          assetPath: 'assets/sounds/bruh.mp3',
          duration: const Duration(seconds: 1),
        );

        final audioEvent = AudioEvent.fromBundledSound(vineSound);

        expect(audioEvent.source, isNull);
      });

      test('uses artist without via Freesound when no sourceUrl', () {
        final vineSound = VineSound(
          id: 'custom_sound',
          title: 'Custom Sound',
          assetPath: 'assets/sounds/custom.mp3',
          duration: const Duration(seconds: 3),
          artist: 'SomeArtist',
        );

        final audioEvent = AudioEvent.fromBundledSound(vineSound);

        expect(audioEvent.source, equals('SomeArtist'));
      });
    });

    group('fromVideoOriginalSound', () {
      test('copies video duration for library display', () {
        final now = DateTime(2026);
        final video = VideoEvent(
          id: testHexId,
          pubkey: testPubkey,
          createdAt: 1700000000,
          content: 'classic vine',
          timestamp: now,
          videoUrl: 'https://example.com/video.mp4',
          duration: 6,
          vineId: 'vine-123',
          addressableDTag: 'vine-123',
        );

        final audioEvent = AudioEvent.fromVideoOriginalSound(
          video,
          creatorName: 'Kenya',
        );

        expect(audioEvent.duration, equals(6.0));
        expect(audioEvent.title, equals('Original sound - Kenya'));
        expect(
          audioEvent.sourceVideoReference,
          equals('34236:$testPubkey:vine-123'),
        );
      });

      test('leaves title null when creatorName is omitted', () {
        final video = VideoEvent(
          id: testHexId,
          pubkey: testPubkey,
          createdAt: 1700000000,
          content: 'classic vine',
          timestamp: DateTime(2026),
          videoUrl: 'https://example.com/video.mp4',
          duration: 6,
          vineId: 'vine-123',
          addressableDTag: 'vine-123',
        );

        final audioEvent = AudioEvent.fromVideoOriginalSound(video);

        expect(audioEvent.title, isNull);
        expect(audioEvent.pubkey, equals(testPubkey));
      });

      test(
        'omits sourceVideoReference when source video has no real d tag',
        () {
          final video = VideoEvent(
            id: testHexId,
            pubkey: testPubkey,
            createdAt: 1700000000,
            content: 'classic vine',
            timestamp: DateTime(2026),
            videoUrl: 'https://example.com/video.mp4',
            duration: 6,
            vineId: 'legacy-vine-id',
          );

          final audioEvent = AudioEvent.fromVideoOriginalSound(video);

          expect(audioEvent.sourceVideoReference, isNull);
        },
      );

      test('carries definitive reuse terms from the source video', () {
        VideoEvent video({String? marker, bool isClassicVine = false}) {
          final rawTags = <String, String>{
            if (isClassicVine) 'platform': 'vine',
          };
          if (marker case final value?) {
            rawTags['allow_audio_reuse'] = value;
          }
          return VideoEvent(
            id: testHexId,
            pubkey: testPubkey,
            createdAt: 1700000000,
            content: 'classic vine',
            timestamp: DateTime(2026),
            videoUrl: 'https://example.com/video.mp4',
            duration: 6,
            vineId: 'vine-123',
            addressableDTag: 'vine-123',
            rawTags: rawTags,
          );
        }

        final granted = AudioEvent.fromVideoOriginalSound(
          video(marker: 'true'),
        );
        final declined = AudioEvent.fromVideoOriginalSound(
          video(marker: 'false', isClassicVine: true),
        );
        final classicCompatibility = AudioEvent.fromVideoOriginalSound(
          video(isClassicVine: true),
        );
        final unspecified = AudioEvent.fromVideoOriginalSound(video());

        expect(granted.allowsReuse, isTrue);
        expect(granted.hasExplicitReuseConsent, isTrue);
        expect(declined.allowsReuse, isFalse);
        expect(declined.hasExplicitReuseConsent, isTrue);
        expect(classicCompatibility.allowsReuse, isTrue);
        expect(classicCompatibility.hasExplicitReuseConsent, isTrue);
        expect(unspecified.allowsReuse, isFalse);
        expect(unspecified.hasExplicitReuseConsent, isFalse);
      });

      test('defaults allowsReuse to true for a plain AudioEvent', () {
        final audioEvent = AudioEvent(
          id: testHexId,
          pubkey: testPubkey,
          createdAt: 1700000000,
        );

        expect(audioEvent.allowsReuse, isTrue);
      });
    });

    group('attributionEventId', () {
      AudioEvent soundWithId(String id) =>
          AudioEvent(id: id, pubkey: testPubkey, createdAt: 1700000000);

      test('returns the event id for a plain Kind 1063 sound', () {
        expect(soundWithId(testHexId).attributionEventId, equals(testHexId));
      });

      test('strips the video_ prefix for a reused original sound', () {
        expect(
          soundWithId('video_$testHexId').attributionEventId,
          equals(testHexId),
        );
      });

      test('strips a trailing editor timeline uniqueness suffix', () {
        expect(
          soundWithId('$testHexId-1700000000000').attributionEventId,
          equals(testHexId),
        );
      });

      test('strips both the video_ prefix and the timeline suffix', () {
        expect(
          soundWithId('video_$testHexId-1700000000000').attributionEventId,
          equals(testHexId),
        );
      });

      test('strips a duplicate/split _copy_ suffix', () {
        expect(
          soundWithId(
            'video_${testHexId}_copy_1700000000000',
          ).attributionEventId,
          equals(testHexId),
        );
      });

      test('strips a chained timeline + _copy_ suffix', () {
        expect(
          soundWithId(
            'video_$testHexId-1700000000000_copy_1700000000001',
          ).attributionEventId,
          equals(testHexId),
        );
      });

      test('returns null for a bundled sound', () {
        expect(soundWithId('bundled_classic_snare').attributionEventId, isNull);
      });

      test('returns null for an unpublished imported sound', () {
        expect(
          soundWithId('local_import_1700000000000').attributionEventId,
          isNull,
        );
      });
    });

    group('extracted clip audio', () {
      AudioEvent extracted({String id = 'local_extracted_1', String? url}) =>
          AudioEvent(
            id: id,
            pubkey: '',
            createdAt: 1700000000,
            url: url ?? '/docs/extracted_clip_audio/extracted_audio_1.wav',
          );

      test('is draft-local audio with a usable file path', () {
        final event = extracted();

        expect(event.isLocalExtracted, isTrue);
        expect(event.isDraftLocalAudio, isTrue);
        expect(
          event.localFilePath,
          equals('/docs/extracted_clip_audio/extracted_audio_1.wav'),
        );
      });

      test('is not a local import, so reuse and attribution skip it', () {
        // An extracted track is the video's own sound. Treating it as
        // imported material would push it into the reuse-consent and
        // attribution paths, which key on isLocalImport.
        expect(extracted().isLocalImport, isFalse);
      });

      test('has no file path without a url', () {
        expect(extracted(url: '').localFilePath, isNull);
      });
    });

    group('fromLocalImport', () {
      test('creates draft-local audio event', () {
        final event = AudioEvent.fromLocalImport(
          id: 'local_import_1700000000000',
          filePath: '/tmp/divine-audio/snare.mp3',
          createdAt: 1700000000,
          title: 'snare',
          mimeType: 'audio/mpeg',
          duration: 2.5,
        );

        expect(event.id, equals('local_import_1700000000000'));
        expect(event.pubkey, equals(AudioEvent.localImportMarker));
        expect(event.url, equals('/tmp/divine-audio/snare.mp3'));
        expect(event.localFilePath, equals('/tmp/divine-audio/snare.mp3'));
        expect(event.isLocalImport, isTrue);
        expect(event.mimeType, equals('audio/mpeg'));
        expect(event.title, equals('snare'));
        expect(event.source, equals('Imported audio'));
      });

      test('survives json round trip', () {
        final original = AudioEvent.fromLocalImport(
          id: 'local_import_1700000000000',
          filePath: '/tmp/divine-audio/kick.wav',
          createdAt: 1700000000,
          title: 'kick',
          mimeType: 'audio/wav',
          duration: 1.25,
        );

        final restored = AudioEvent.fromJson(original.toJson());

        expect(restored.isLocalImport, isTrue);
        expect(restored.localFilePath, equals('/tmp/divine-audio/kick.wav'));
        expect(restored.title, equals('kick'));
        expect(restored.duration, equals(1.25));
      });
    });

    group('resolvedSource', () {
      test('classifies imported audio as a file source', () {
        final event = AudioEvent.fromLocalImport(
          id: 'local_import_1700000000000',
          filePath: '/var/mobile/draft_audio/import.mp3',
          createdAt: 1700000000,
          title: 'import',
          mimeType: 'audio/mpeg',
        );

        expect(
          event.resolvedSource,
          equals((
            kind: AudioSourceKind.file,
            path: '/var/mobile/draft_audio/import.mp3',
          )),
        );
      });

      test('classifies bundled sounds as an asset source', () {
        final event = AudioEvent.fromBundledSound(
          VineSound(
            id: 'bruh',
            title: 'Bruh',
            assetPath: 'assets/sounds/bruh.mp3',
            duration: const Duration(seconds: 1),
          ),
        );

        expect(
          event.resolvedSource,
          equals((kind: AudioSourceKind.asset, path: 'assets/sounds/bruh.mp3')),
        );
      });

      test('classifies remote sounds as a network source', () {
        final event = AudioEvent(
          id: 'remote',
          pubkey: 'abc',
          createdAt: 0,
          url: 'https://example.com/audio.mp3',
        );

        expect(
          event.resolvedSource,
          equals((
            kind: AudioSourceKind.network,
            path: 'https://example.com/audio.mp3',
          )),
        );
      });

      test('classifies a bare absolute path as a file source', () {
        // Clip-extracted J-cut audio: not a `local_import_` id, `url` is a
        // raw on-disk path (clip_editor_bloc writes `result.audioFilePath`).
        final event = AudioEvent(
          id: 'local_extracted_1700000000000',
          pubkey: '',
          createdAt: 0,
          url: '/var/mobile/clip_audio/extracted.m4a',
        );

        expect(
          event.resolvedSource,
          equals((
            kind: AudioSourceKind.file,
            path: '/var/mobile/clip_audio/extracted.m4a',
          )),
        );
      });

      test('classifies a file:// URI as a file source', () {
        final event = AudioEvent(
          id: 'local_extracted_1700000000000',
          pubkey: '',
          createdAt: 0,
          url: 'file:///var/mobile/clip_audio/extracted.m4a',
        );

        expect(
          event.resolvedSource,
          equals((
            kind: AudioSourceKind.file,
            path: '/var/mobile/clip_audio/extracted.m4a',
          )),
        );
      });

      test('returns null when no source url is present', () {
        final event = AudioEvent(id: 'empty', pubkey: 'abc', createdAt: 0);

        expect(event.resolvedSource, isNull);
      });
    });

    group('external provider metadata', () {
      test('round trips external source and license metadata through JSON', () {
        final audioEvent = AudioEvent(
          id: 'freesound_502915',
          pubkey: AudioEvent.externalProviderMarker,
          createdAt: 1779120000,
          url: 'https://cdn.freesound.org/previews/502/502915.mp3',
          mimeType: 'audio/mpeg',
          duration: 5.943,
          title: 'Oh No No No Crowd',
          source: 'ThePauny via Freesound',
          externalSource: AudioExternalSource(
            provider: 'freesound',
            providerSoundId: '502915',
            providerName: 'Freesound',
            creatorName: 'ThePauny',
            creatorUrl: 'https://freesound.org/people/ThePauny/',
            sourceUrl: 'https://freesound.org/people/ThePauny/sounds/502915/',
            previewUrl: 'https://cdn.freesound.org/previews/502/502915.mp3',
            catalogTags: const ['crowd', 'field recording'],
            license: AudioLicenseMetadata(
              type: 'cc0',
              name: 'Creative Commons 0',
              url: 'https://creativecommons.org/publicdomain/zero/1.0/',
              allowsCommercialUse: true,
              allowsDerivatives: true,
              requiresAttribution: false,
            ),
          ),
        );

        final decoded = AudioEvent.fromJson(audioEvent.toJson());

        expect(decoded.isExternalProviderSound, isTrue);
        expect(decoded.externalSource?.provider, equals('freesound'));
        expect(decoded.externalSource?.providerSoundId, equals('502915'));
        expect(decoded.externalSource?.creatorName, equals('ThePauny'));
        expect(decoded.externalSource?.license.type, equals('cc0'));
        expect(decoded.externalSource?.license.allowsCommercialUse, isTrue);
        expect(decoded.externalSource?.license.allowsDerivatives, isTrue);
        expect(decoded.externalSource?.license.requiresAttribution, isFalse);
        expect(decoded.externalSource?.catalogTags, [
          'crowd',
          'field recording',
        ]);
        expect(decoded.externalSource, equals(audioEvent.externalSource));
      });

      test('external source and license metadata use value equality', () {
        final license = AudioLicenseMetadata(
          type: 'cc0',
          name: 'Creative Commons 0',
          url: 'https://creativecommons.org/publicdomain/zero/1.0/',
          allowsCommercialUse: true,
          allowsDerivatives: true,
          requiresAttribution: false,
        );
        final sameLicense = AudioLicenseMetadata(
          type: 'cc0',
          name: 'Creative Commons 0',
          url: 'https://creativecommons.org/publicdomain/zero/1.0/',
          allowsCommercialUse: true,
          allowsDerivatives: true,
          requiresAttribution: false,
        );
        final source = AudioExternalSource(
          provider: 'freesound',
          providerSoundId: '502915',
          providerName: 'Freesound',
          creatorName: 'ThePauny',
          creatorUrl: 'https://freesound.org/people/ThePauny/',
          sourceUrl: 'https://freesound.org/people/ThePauny/sounds/502915/',
          previewUrl: 'https://cdn.freesound.org/previews/502/502915.mp3',
          license: license,
        );
        final sameSource = AudioExternalSource(
          provider: 'freesound',
          providerSoundId: '502915',
          providerName: 'Freesound',
          creatorName: 'ThePauny',
          creatorUrl: 'https://freesound.org/people/ThePauny/',
          sourceUrl: 'https://freesound.org/people/ThePauny/sounds/502915/',
          previewUrl: 'https://cdn.freesound.org/previews/502/502915.mp3',
          license: sameLicense,
        );

        expect(license, equals(sameLicense));
        expect(license.hashCode, equals(sameLicense.hashCode));
        expect(source, equals(sameSource));
        expect(source.hashCode, equals(sameSource.hashCode));
      });

      test('omits external source metadata when it is absent', () {
        final audioEvent = AudioEvent(
          id: testHexId,
          pubkey: testPubkey,
          createdAt: 1700000000,
        );

        expect(audioEvent.toJson(), isNot(contains('externalSource')));
        expect(audioEvent.isExternalProviderSound, isFalse);
      });
    });

    group('toTags', () {
      test('generates complete tags list', () {
        // Arrange
        final audioEvent = AudioEvent(
          id: 'test-id-123456789012345678901234567890123456789012345678901234',
          pubkey: 'test-pubkey',
          createdAt: 1700000000,
          url: 'https://blossom.example/audio.aac',
          mimeType: 'audio/aac',
          sha256: 'hash123',
          fileSize: 12345,
          duration: 5.5,
          title: 'Test Sound',
          sourceVideoReference: '34236:pubkey:vine-id',
          sourceVideoRelay: 'wss://relay.example',
        );

        // Act
        final tags = audioEvent.toTags();

        // Assert - check that specific tags exist
        expect(
          _findTag(tags, 'url'),
          equals(['url', 'https://blossom.example/audio.aac']),
        );
        expect(_findTag(tags, 'm'), equals(['m', 'audio/aac']));
        expect(_findTag(tags, 'x'), equals(['x', 'hash123']));
        expect(_findTag(tags, 'size'), equals(['size', '12345']));
        expect(_findTag(tags, 'duration'), equals(['duration', '5.5']));
        expect(_findTag(tags, 'title'), equals(['title', 'Test Sound']));
        expect(
          _findTag(tags, 'a'),
          equals(['a', '34236:pubkey:vine-id', 'wss://relay.example']),
        );
        expect(
          _findTag(tags, 'allow_audio_reuse'),
          equals(['allow_audio_reuse', 'true']),
        );
      });

      test('generates minimal tags for sparse event', () {
        // Arrange
        final audioEvent = AudioEvent(
          id: 'minimal-id-123456789012345678901234567890123456789012345678',
          pubkey: 'test-pubkey',
          createdAt: 1700000000,
          url: 'https://example.com/audio.aac',
          mimeType: 'audio/aac',
        );

        // Act
        final tags = audioEvent.toTags();

        // Assert
        expect(
          _findTag(tags, 'url'),
          equals(['url', 'https://example.com/audio.aac']),
        );
        expect(_findTag(tags, 'm'), equals(['m', 'audio/aac']));
        // Should not contain null fields
        expect(_findTag(tags, 'x'), isNull);
        expect(_findTag(tags, 'size'), isNull);
        expect(_findTag(tags, 'duration'), isNull);
        expect(_findTag(tags, 'title'), isNull);
        expect(_findTag(tags, 'a'), isNull);
        expect(
          _findTag(tags, 'allow_audio_reuse'),
          equals(['allow_audio_reuse', 'true']),
        );
      });

      test('generates a tag without relay when relay is null', () {
        // Arrange
        final audioEvent = AudioEvent(
          id: 'no-relay-id-12345678901234567890123456789012345678901234567',
          pubkey: 'test-pubkey',
          createdAt: 1700000000,
          url: 'https://example.com/audio.aac',
          mimeType: 'audio/aac',
          sourceVideoReference: '34236:pubkey:vine-id',
        );

        // Act
        final tags = audioEvent.toTags();

        // Assert
        expect(_findTag(tags, 'a'), equals(['a', '34236:pubkey:vine-id']));
      });

      test('publishes explicit consent and durable public credit', () {
        final audioEvent = AudioEvent(
          id: testHexId,
          pubkey: testPubkey,
          createdAt: 1700000000,
          allowsReuse: false,
          creatorName: 'Field Recordist',
          creatorPubkey: testHexId,
          creatorUrl: 'https://creator.example/profile',
          licenseName: 'CC BY 4.0',
          licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
          publicTags: const ['birds', ' field-recording ', 'birds', ''],
          proxyId: '12345',
          proxyProtocol: 'freesound',
        );

        final tags = audioEvent.toTags();

        expect(
          _findTag(tags, 'allow_audio_reuse'),
          equals(['allow_audio_reuse', 'false']),
        );
        expect(
          _findTag(tags, 'creator'),
          equals(['creator', 'Field Recordist']),
        );
        expect(_findTag(tags, 'p'), equals(['p', testHexId]));
        expect(
          _findTag(tags, 'creator_url'),
          equals(['creator_url', 'https://creator.example/profile']),
        );
        expect(_findTag(tags, 'license'), equals(['license', 'CC BY 4.0']));
        expect(
          _findTag(tags, 'license_url'),
          equals([
            'license_url',
            'https://creativecommons.org/licenses/by/4.0/',
          ]),
        );
        expect(
          tags.where((tag) => tag.first == 't').toList(),
          equals([
            ['t', 'birds'],
            ['t', 'field-recording'],
          ]),
        );
        expect(
          _findTag(tags, 'proxy'),
          equals(['proxy', '12345', 'freesound']),
        );
      });

      test('cannot leak private saved-library metadata into public tags', () {
        final audioEvent = AudioEvent(
          id: testHexId,
          pubkey: testPubkey,
          createdAt: 1700000000,
          title: 'Public title',
          publicTags: const ['public-tag'],
        );

        final published = audioEvent.toTags().expand((tag) => tag).join(' ');

        expect(published, isNot(contains('personalLabel')));
        expect(published, isNot(contains('personalHashtags')));
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        // Arrange
        final original = AudioEvent(
          id: 'original-id-1234567890123456789012345678901234567890123456',
          pubkey: 'original-pubkey',
          createdAt: 1700000000,
          url: 'https://original.com/audio.aac',
          mimeType: 'audio/aac',
          title: 'Original Title',
        );

        // Act
        final copy = original.copyWith(title: 'New Title', duration: 6);

        // Assert
        expect(copy.id, equals(original.id));
        expect(copy.pubkey, equals(original.pubkey));
        expect(copy.url, equals(original.url));
        expect(copy.title, equals('New Title'));
        expect(copy.duration, equals(6.0));
        expect(original.title, equals('Original Title')); // Original unchanged
        expect(original.duration, isNull);
      });
    });

    group('equality', () {
      test('events with same id are equal', () {
        // Arrange
        final event1 = AudioEvent(
          id: 'same-id-123456789012345678901234567890123456789012345678901',
          pubkey: 'pubkey1',
          createdAt: 1700000000,
          url: 'https://example1.com/audio.aac',
          mimeType: 'audio/aac',
        );

        final event2 = AudioEvent(
          id: 'same-id-123456789012345678901234567890123456789012345678901',
          pubkey: 'pubkey2', // Different pubkey
          createdAt: 1700000001, // Different timestamp
          url: 'https://example2.com/audio.aac', // Different url
          mimeType: 'audio/mp4', // Different mime
        );

        // Assert
        expect(event1, equals(event2));
        expect(event1.hashCode, equals(event2.hashCode));
      });

      test('events with different ids are not equal', () {
        // Arrange
        final event1 = AudioEvent(
          id: 'id-one-123456789012345678901234567890123456789012345678901',
          pubkey: 'pubkey',
          createdAt: 1700000000,
          url: 'https://example.com/audio.aac',
          mimeType: 'audio/aac',
        );

        final event2 = AudioEvent(
          id: 'id-two-123456789012345678901234567890123456789012345678901',
          pubkey: 'pubkey',
          createdAt: 1700000000,
          url: 'https://example.com/audio.aac',
          mimeType: 'audio/aac',
        );

        // Assert
        expect(event1, isNot(equals(event2)));
      });

      test('events with same id but different startOffset are not equal', () {
        // Arrange
        final event1 = AudioEvent(
          id: 'same-id-123456789012345678901234567890123456789012345678901',
          pubkey: 'pubkey',
          createdAt: 1700000000,
          url: 'https://example.com/audio.aac',
          mimeType: 'audio/aac',
          // Using default startOffset (Duration.zero)
        );

        final event2 = AudioEvent(
          id: 'same-id-123456789012345678901234567890123456789012345678901',
          pubkey: 'pubkey',
          createdAt: 1700000000,
          url: 'https://example.com/audio.aac',
          mimeType: 'audio/aac',
          startOffset: const Duration(seconds: 5),
        );

        // Assert - same audio with different start positions are distinct
        expect(event1, isNot(equals(event2)));
        expect(event1.hashCode, isNot(equals(event2.hashCode)));
      });

      test('events with same id but different anchorClipId are not equal', () {
        final event1 = AudioEvent(
          id: 'same-id-123456789012345678901234567890123456789012345678901',
          pubkey: 'pubkey',
          createdAt: 1700000000,
          url: 'https://example.com/audio.aac',
          mimeType: 'audio/aac',
          anchorClipId: 'clip-a',
        );

        final event2 = AudioEvent(
          id: 'same-id-123456789012345678901234567890123456789012345678901',
          pubkey: 'pubkey',
          createdAt: 1700000000,
          url: 'https://example.com/audio.aac',
          mimeType: 'audio/aac',
        );

        expect(event1, isNot(equals(event2)));
        expect(event1.hashCode, isNot(equals(event2.hashCode)));
      });
    });

    group('toString', () {
      test('returns readable debug string', () {
        // Arrange
        final audioEvent = AudioEvent(
          id: 'test-id-123456789012345678901234567890123456789012345678901234',
          pubkey: 'test-pubkey',
          createdAt: 1700000000,
          url: 'https://example.com/audio.aac',
          mimeType: 'audio/aac',
          title: 'Test Sound',
          duration: 6.2,
        );

        // Act
        final str = audioEvent.toString();

        // Assert
        expect(str, contains('AudioEvent'));
        expect(
          str,
          contains(
            'test-id-123456789012345678901234567890123456789012345678901234',
          ),
        );
        expect(str, contains('Test Sound'));
        expect(str, contains('6.2'));
      });
    });

    group('sourceVideoKind getter', () {
      test('extracts kind from sourceVideoReference', () {
        // Arrange
        final audioEvent = AudioEvent(
          id: 'test-id-123456789012345678901234567890123456789012345678901234',
          pubkey: 'test-pubkey',
          createdAt: 1700000000,
          url: 'https://example.com/audio.aac',
          mimeType: 'audio/aac',
          sourceVideoReference: '34236:pubkey:vine-id',
        );

        // Assert
        expect(audioEvent.sourceVideoKind, equals(34236));
      });

      test('returns null when sourceVideoReference is null', () {
        // Arrange
        final audioEvent = AudioEvent(
          id: 'test-id-123456789012345678901234567890123456789012345678901234',
          pubkey: 'test-pubkey',
          createdAt: 1700000000,
          url: 'https://example.com/audio.aac',
          mimeType: 'audio/aac',
        );

        // Assert
        expect(audioEvent.sourceVideoKind, isNull);
      });
    });

    group('sourceVideoPubkey getter', () {
      test('extracts pubkey from sourceVideoReference', () {
        // Arrange
        final audioEvent = AudioEvent(
          id: 'test-id-123456789012345678901234567890123456789012345678901234',
          pubkey: 'test-pubkey',
          createdAt: 1700000000,
          url: 'https://example.com/audio.aac',
          mimeType: 'audio/aac',
          sourceVideoReference: '34236:creator-pubkey-abc:vine-id',
        );

        // Assert
        expect(audioEvent.sourceVideoPubkey, equals('creator-pubkey-abc'));
      });
    });

    group('sourceVideoIdentifier getter', () {
      test('extracts d-tag identifier from sourceVideoReference', () {
        // Arrange
        final audioEvent = AudioEvent(
          id: 'test-id-123456789012345678901234567890123456789012345678901234',
          pubkey: 'test-pubkey',
          createdAt: 1700000000,
          url: 'https://example.com/audio.aac',
          mimeType: 'audio/aac',
          sourceVideoReference: '34236:creator-pubkey:my-vine-id-123',
        );

        // Assert
        expect(audioEvent.sourceVideoIdentifier, equals('my-vine-id-123'));
      });
    });

    group('formattedDuration getter', () {
      test('formats duration as mm:ss', () {
        // Arrange - 65.4 rounds to 65 seconds = 1:05
        final audioEvent = AudioEvent(
          id: 'test-id-123456789012345678901234567890123456789012345678901234',
          pubkey: 'test-pubkey',
          createdAt: 1700000000,
          url: 'https://example.com/audio.aac',
          mimeType: 'audio/aac',
          duration: 65.4,
        );

        // Assert
        expect(audioEvent.formattedDuration, equals('1:05'));
      });

      test('handles sub-minute duration', () {
        // Arrange
        final audioEvent = AudioEvent(
          id: 'test-id-123456789012345678901234567890123456789012345678901234',
          pubkey: 'test-pubkey',
          createdAt: 1700000000,
          url: 'https://example.com/audio.aac',
          mimeType: 'audio/aac',
          duration: 6.2,
        );

        // Assert
        expect(audioEvent.formattedDuration, equals('0:06'));
      });

      test('returns empty string when duration is null', () {
        // Arrange
        final audioEvent = AudioEvent(
          id: 'test-id-123456789012345678901234567890123456789012345678901234',
          pubkey: 'test-pubkey',
          createdAt: 1700000000,
          url: 'https://example.com/audio.aac',
          mimeType: 'audio/aac',
        );

        // Assert
        expect(audioEvent.formattedDuration, equals(''));
      });
    });

    group('fileSizeKB getter', () {
      test('returns file size in KB', () {
        // Arrange
        final audioEvent = AudioEvent(
          id: 'test-id-123456789012345678901234567890123456789012345678901234',
          pubkey: 'test-pubkey',
          createdAt: 1700000000,
          url: 'https://example.com/audio.aac',
          mimeType: 'audio/aac',
          fileSize: 102400, // 100 KB
        );

        // Assert
        expect(audioEvent.fileSizeKB, closeTo(100.0, 0.001));
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        final audioEvent = AudioEvent(
          id: 'test-id-123456789012345678901234567890123456789012345678901234',
          pubkey: testPubkey,
          createdAt: 1700000000,
          url: 'https://blossom.example/audio.aac',
          mimeType: 'audio/aac',
          sha256: 'hash123',
          fileSize: 98765,
          duration: 6.2,
          title: 'Test Sound',
          source: 'Original Sound',
          sourceVideoReference: '34236:pubkey:vine-id',
          sourceVideoRelay: 'wss://relay.example',
          startOffset: const Duration(milliseconds: 1500),
          volume: 0.4,
        );

        final json = audioEvent.toJson();

        expect(
          json['id'],
          equals(
            'test-id-123456789012345678901234567890123456789012345678901234',
          ),
        );
        expect(json['pubkey'], equals(testPubkey));
        expect(json['createdAt'], equals(1700000000));
        expect(json['url'], equals('https://blossom.example/audio.aac'));
        expect(json['mimeType'], equals('audio/aac'));
        expect(json['sha256'], equals('hash123'));
        expect(json['fileSize'], equals(98765));
        expect(json['duration'], equals(6.2));
        expect(json['title'], equals('Test Sound'));
        expect(json['source'], equals('Original Sound'));
        expect(json['sourceVideoReference'], equals('34236:pubkey:vine-id'));
        expect(json['sourceVideoRelay'], equals('wss://relay.example'));
        expect(json['startOffsetMs'], equals(1500));
        expect(json['volume'], equals(0.4));
      });

      test('omits null optional fields', () {
        final audioEvent = AudioEvent(
          id: 'minimal-id-123456789012345678901234567890123456789012345678',
          pubkey: testPubkey,
          createdAt: 1700000000,
        );

        final json = audioEvent.toJson();

        expect(json.containsKey('url'), isFalse);
        expect(json.containsKey('mimeType'), isFalse);
        expect(json.containsKey('sha256'), isFalse);
        expect(json.containsKey('fileSize'), isFalse);
        expect(json.containsKey('duration'), isFalse);
        expect(json.containsKey('title'), isFalse);
        expect(json.containsKey('source'), isFalse);
        expect(json.containsKey('sourceVideoReference'), isFalse);
        expect(json.containsKey('sourceVideoRelay'), isFalse);
      });

      test('omits startOffsetMs when offset is zero', () {
        final audioEvent = AudioEvent(
          id: 'zero-offset-123456789012345678901234567890123456789012345678',
          pubkey: testPubkey,
          createdAt: 1700000000,
        );

        final json = audioEvent.toJson();

        expect(json.containsKey('startOffsetMs'), isFalse);
      });

      test('always serializes volume for backward-compatible snapshots', () {
        final audioEvent = AudioEvent(
          id: 'default-volume-123456789012345678901234567890123456789012345',
          pubkey: testPubkey,
          createdAt: 1700000000,
        );

        final json = audioEvent.toJson();

        expect(json['volume'], equals(1.0));
      });
    });

    group('fromJson', () {
      test('deserializes all fields', () {
        final json = <String, dynamic>{
          'id':
              'test-id-123456789012345678901234567890123456789012345678901234',
          'pubkey': testPubkey,
          'createdAt': 1700000000,
          'url': 'https://blossom.example/audio.aac',
          'mimeType': 'audio/aac',
          'sha256': 'hash123',
          'fileSize': 98765,
          'duration': 6.2,
          'title': 'Test Sound',
          'source': 'Original Sound',
          'sourceVideoReference': '34236:pubkey:vine-id',
          'sourceVideoRelay': 'wss://relay.example',
          'startOffsetMs': 1500,
        };

        final audioEvent = AudioEvent.fromJson(json);

        expect(
          audioEvent.id,
          equals(
            'test-id-123456789012345678901234567890123456789012345678901234',
          ),
        );
        expect(audioEvent.pubkey, equals(testPubkey));
        expect(audioEvent.createdAt, equals(1700000000));
        expect(audioEvent.url, equals('https://blossom.example/audio.aac'));
        expect(audioEvent.mimeType, equals('audio/aac'));
        expect(audioEvent.sha256, equals('hash123'));
        expect(audioEvent.fileSize, equals(98765));
        expect(audioEvent.duration, equals(6.2));
        expect(audioEvent.title, equals('Test Sound'));
        expect(audioEvent.source, equals('Original Sound'));
        expect(audioEvent.sourceVideoReference, equals('34236:pubkey:vine-id'));
        expect(audioEvent.sourceVideoRelay, equals('wss://relay.example'));
        expect(
          audioEvent.startOffset,
          equals(const Duration(milliseconds: 1500)),
        );
      });

      test('handles missing optional fields', () {
        final json = <String, dynamic>{
          'id': 'minimal-id-123456789012345678901234567890123456789012345678',
          'pubkey': testPubkey,
          'createdAt': 1700000000,
        };

        final audioEvent = AudioEvent.fromJson(json);

        expect(audioEvent.url, isNull);
        expect(audioEvent.mimeType, isNull);
        expect(audioEvent.sha256, isNull);
        expect(audioEvent.fileSize, isNull);
        expect(audioEvent.duration, isNull);
        expect(audioEvent.title, isNull);
        expect(audioEvent.source, isNull);
        expect(audioEvent.sourceVideoReference, isNull);
        expect(audioEvent.sourceVideoRelay, isNull);
        expect(audioEvent.startOffset, equals(Duration.zero));
      });

      test('defaults startOffset to Duration.zero when missing', () {
        final json = <String, dynamic>{
          'id': 'no-offset-123456789012345678901234567890123456789012345678',
          'pubkey': testPubkey,
          'createdAt': 1700000000,
        };

        final audioEvent = AudioEvent.fromJson(json);

        expect(audioEvent.startOffset, equals(Duration.zero));
      });

      test('defaults volume to 1.0 when reading older JSON snapshots', () {
        final json = <String, dynamic>{
          'id': 'no-volume-123456789012345678901234567890123456789012345678',
          'pubkey': testPubkey,
          'createdAt': 1700000000,
        };

        final audioEvent = AudioEvent.fromJson(json);

        expect(audioEvent.volume, equals(1.0));
      });
    });

    group('toJson/fromJson roundtrip', () {
      test('roundtrips complete AudioEvent preserving all data', () {
        final original = AudioEvent(
          id: 'roundtrip-1234567890123456789012345678901234567890123456789',
          pubkey: testPubkey,
          createdAt: 1700000000,
          url: 'https://blossom.example/audio.aac',
          mimeType: 'audio/aac',
          sha256: 'hash123abc',
          fileSize: 54321,
          duration: 12.5,
          title: 'Roundtrip Sound',
          source: 'SoundCloud',
          sourceVideoReference: '34236:creator:vine-abc',
          sourceVideoRelay: 'wss://relay.example',
          startOffset: const Duration(milliseconds: 3200),
        );

        final restored = AudioEvent.fromJson(original.toJson());

        expect(restored.id, equals(original.id));
        expect(restored.pubkey, equals(original.pubkey));
        expect(restored.createdAt, equals(original.createdAt));
        expect(restored.url, equals(original.url));
        expect(restored.mimeType, equals(original.mimeType));
        expect(restored.sha256, equals(original.sha256));
        expect(restored.fileSize, equals(original.fileSize));
        expect(restored.duration, equals(original.duration));
        expect(restored.title, equals(original.title));
        expect(restored.source, equals(original.source));
        expect(
          restored.sourceVideoReference,
          equals(original.sourceVideoReference),
        );
        expect(restored.sourceVideoRelay, equals(original.sourceVideoRelay));
        expect(restored.startOffset, equals(original.startOffset));
      });

      test('roundtrips minimal AudioEvent', () {
        final original = AudioEvent(
          id: 'minimal-rt-12345678901234567890123456789012345678901234567',
          pubkey: testPubkey,
          createdAt: 1700000000,
        );

        final restored = AudioEvent.fromJson(original.toJson());

        expect(restored.id, equals(original.id));
        expect(restored.pubkey, equals(original.pubkey));
        expect(restored.createdAt, equals(original.createdAt));
        expect(restored.url, isNull);
        expect(restored.startOffset, equals(Duration.zero));
      });
    });

    group('copyWith startOffset', () {
      test('updates startOffset', () {
        final original = AudioEvent(
          id: 'offset-id-12345678901234567890123456789012345678901234567890',
          pubkey: testPubkey,
          createdAt: 1700000000,
          url: 'https://example.com/audio.aac',
        );

        final updated = original.copyWith(
          startOffset: const Duration(milliseconds: 2500),
        );

        expect(updated.startOffset, equals(const Duration(milliseconds: 2500)));
        expect(original.startOffset, equals(Duration.zero));
      });

      test('preserves startOffset when not specified in copyWith', () {
        final original = AudioEvent(
          id: 'preserve-id-1234567890123456789012345678901234567890123456789',
          pubkey: testPubkey,
          createdAt: 1700000000,
          startOffset: const Duration(seconds: 5),
        );

        final updated = original.copyWith(title: 'New Title');

        expect(updated.startOffset, equals(const Duration(seconds: 5)));
        expect(updated.title, equals('New Title'));
      });
    });

    group('anchorClipId', () {
      final anchored = AudioEvent(
        id: 'anchor-id-123456789012345678901234567890123456789012345678901',
        pubkey: testPubkey,
        createdAt: 1700000000,
        url: 'https://example.com/audio.aac',
        anchorClipId: 'clip-7',
      );

      test('isAnchored reflects anchorClipId presence', () {
        expect(anchored.isAnchored, isTrue);
        expect(anchored.copyWith(clearAnchorClipId: true).isAnchored, isFalse);
      });

      test('copyWith clears the anchor with clearAnchorClipId', () {
        final unanchored = anchored.copyWith(clearAnchorClipId: true);
        expect(unanchored.anchorClipId, isNull);
        // Other fields are preserved.
        expect(unanchored.id, equals(anchored.id));
        expect(unanchored.url, equals(anchored.url));
      });

      test('copyWith preserves the anchor when not specified', () {
        final updated = anchored.copyWith(title: 'New Title');
        expect(updated.anchorClipId, equals('clip-7'));
      });

      test('survives a toJson/fromJson roundtrip', () {
        final restored = AudioEvent.fromJson(anchored.toJson());
        expect(restored.anchorClipId, equals('clip-7'));
      });

      test('is omitted from JSON when null', () {
        final original = AudioEvent(
          id: 'plain-id-1234567890123456789012345678901234567890123456789012',
          pubkey: testPubkey,
          createdAt: 1700000000,
        );
        expect(original.toJson(), isNot(contains('anchorClipId')));
        expect(AudioEvent.fromJson(original.toJson()).anchorClipId, isNull);
      });
    });

    group('isClipAnchoredOriginalSound', () {
      test('is true for an original sound anchored to a clip', () {
        final event = AudioEvent(
          id: 'video_source-abc_copy_1',
          pubkey: testPubkey,
          createdAt: 1700000000,
          anchorClipId: 'clip-7',
        );
        expect(event.isOriginalSound, isTrue);
        expect(event.isAnchored, isTrue);
        expect(event.isClipAnchoredOriginalSound, isTrue);
      });

      test('is false for an original sound added from another video '
          '(not anchored)', () {
        // A network "Original Sound" the user added from the sound browser:
        // its id is video_-prefixed but it is free-standing, so it keeps its
        // own volume arc.
        final event = AudioEvent(
          id: 'video_source-abc_copy_1',
          pubkey: testPubkey,
          createdAt: 1700000000,
        );
        expect(event.isOriginalSound, isTrue);
        expect(event.isAnchored, isFalse);
        expect(event.isClipAnchoredOriginalSound, isFalse);
      });

      test('is false for a non-original (custom/imported) track', () {
        final event = AudioEvent(
          id: 'local_import_1234567890',
          pubkey: testPubkey,
          createdAt: 1700000000,
          anchorClipId: 'clip-7',
        );
        expect(event.isOriginalSound, isFalse);
        expect(event.isClipAnchoredOriginalSound, isFalse);
      });
    });

    group('UTF-16 well-formedness', () {
      // The headless flutter_tester does not throw on a lone surrogate — only
      // the real engine does — so the assertion has to be on the model value
      // rather than on a rendered widget.
      String poisoned(String text) => '$text${String.fromCharCode(0xD83D)}!';

      test('replaces lone surrogates in the display text tags', () {
        final event = AudioEvent(
          id: testHexId,
          pubkey: testPubkey,
          createdAt: 1700000000,
          title: poisoned('Beat'),
          source: poisoned('Freesound'),
          creatorName: poisoned('ThePauny'),
          licenseName: poisoned('CC0'),
          publicTags: ['crowd', poisoned('field')],
        );

        expect(event.title, equals('Beat�!'));
        expect(event.source, equals('Freesound�!'));
        expect(event.creatorName, equals('ThePauny�!'));
        expect(event.licenseName, equals('CC0�!'));
        expect(event.publicTags, equals(['crowd', 'field�!']));
      });

      test('republishes the sanitized values rather than the raw ones', () {
        final tags = AudioEvent(
          id: testHexId,
          pubkey: testPubkey,
          createdAt: 1700000000,
          title: poisoned('Beat'),
          creatorName: poisoned('ThePauny'),
          licenseName: poisoned('CC0'),
        ).toTags();

        expect(_findTag(tags, 'title'), equals(['title', 'Beat�!']));
        expect(_findTag(tags, 'creator'), equals(['creator', 'ThePauny�!']));
        expect(_findTag(tags, 'license'), equals(['license', 'CC0�!']));
      });

      test('leaves the playback source and identifiers untouched', () {
        final url =
            'https://cdn.example.com/${String.fromCharCode(0xD83D)}.mp3';
        final event = AudioEvent(
          id: testHexId,
          pubkey: testPubkey,
          createdAt: 1700000000,
          url: url,
          sha256: testSha256,
        );

        expect(event.url, same(url));
        expect(event.sha256, equals(testSha256));
      });

      test('preserves valid emoji and keeps clean text identical', () {
        const title = 'Beat \u{1F600}';
        final event = AudioEvent(
          id: testHexId,
          pubkey: testPubkey,
          createdAt: 1700000000,
          title: title,
        );

        expect(event.title, same(title));
      });

      test('sanitizes external source and license display text', () {
        final source = AudioExternalSource(
          provider: 'freesound',
          providerSoundId: '502915',
          providerName: poisoned('Freesound'),
          creatorName: poisoned('ThePauny'),
          catalogTags: [poisoned('crowd')],
          license: AudioLicenseMetadata(
            type: 'cc0',
            name: poisoned('CC0 1.0'),
            url: 'https://creativecommons.org/publicdomain/zero/1.0/',
            allowsCommercialUse: true,
            allowsDerivatives: true,
            requiresAttribution: false,
          ),
        );

        expect(source.providerName, equals('Freesound�!'));
        expect(source.creatorName, equals('ThePauny�!'));
        expect(source.catalogTags, equals(['crowd�!']));
        expect(source.license.name, equals('CC0 1.0�!'));
      });
    });
  });
}

/// Helper to find a tag by its first element (tag name)
List<String>? _findTag(List<List<String>> tags, String tagName) {
  for (final tag in tags) {
    if (tag.isNotEmpty && tag[0] == tagName) {
      return tag;
    }
  }
  return null;
}

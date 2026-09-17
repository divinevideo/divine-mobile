// ABOUTME: Tests for VideoAudioPublisher: reuse-consent gating and which sound
// ABOUTME: reference a video publish ends up carrying

import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart'
    show AudioEvent, AudioExternalSource, AudioLicenseMetadata;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/exceptions/video_exceptions.dart';
import 'package:openvine/models/audio_share_attribution.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_publish/signed_event_relay_publisher.dart';
import 'package:openvine/services/video_publish/video_audio_publisher.dart';
import 'package:unified_logger/unified_logger.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _MockRelayPublisher extends Mock implements SignedEventRelayPublisher {}

class _FakeEvent extends Fake implements Event {}

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

Event _signedAudioEvent() => Event.fromJson({
  'id': _soundEventId,
  'pubkey': _self,
  'created_at': 0,
  'kind': 1063,
  'tags': <List<String>>[],
  'content': '',
  'sig': 'sig',
});

const _self =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _other =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _soundEventId =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

AudioEvent _publishedSound({
  required String pubkey,
  bool allowsReuse = true,
  bool hasExplicitReuseConsent = false,
}) => AudioEvent(
  id: _soundEventId,
  pubkey: pubkey,
  createdAt: 0,
  url: 'https://cdn.example/sound.mp3',
  allowsReuse: allowsReuse,
  hasExplicitReuseConsent: hasExplicitReuseConsent,
);

AudioEvent _providerSound() => AudioEvent(
  id: 'freesound-1',
  pubkey: _other,
  createdAt: 0,
  url: 'https://cdn.example/provider.mp3',
  externalSource: AudioExternalSource(
    provider: 'freesound',
    providerSoundId: '1',
    providerName: 'Freesound',
    sourceUrl: 'https://freesound.example/sounds/1',
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

void main() {
  late _MockNostrClient nostrClient;
  late _MockAuthService authService;
  late _MockRelayPublisher relayPublisher;

  final upload = PendingUpload.create(
    localVideoPath: '',
    nostrPubkey: _self,
    title: 'Plants',
  );

  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(File('unused'));
  });

  setUp(() {
    nostrClient = _MockNostrClient();
    authService = _MockAuthService();
    relayPublisher = _MockRelayPublisher();
    when(() => nostrClient.connectedRelays).thenReturn(const []);
    when(() => authService.currentPublicKeyHex).thenReturn(_self);
  });

  VideoAudioPublisher publisher({AudioReuseConsentChecker? consentChecker}) =>
      VideoAudioPublisher(
        nostrClient: nostrClient,
        relayPublisher: relayPublisher,
        authService: authService,
        audioReuseConsentChecker: consentChecker,
      );

  group(VideoAudioPublisher, () {
    group('canReuseSelectedAudio', () {
      test(
        'allows a creator to reuse their own sound without asking',
        () async {
          var asked = false;
          final result =
              await publisher(
                consentChecker: (_) async => asked = true,
              ).canReuseSelectedAudio(
                _publishedSound(pubkey: _self, allowsReuse: false),
              );

          expect(result, isTrue);
          expect(asked, isFalse);
        },
      );

      test('fails closed when nobody can answer for another creator', () async {
        final result = await publisher().canReuseSelectedAudio(
          _publishedSound(pubkey: _other, allowsReuse: false),
        );

        expect(result, isFalse);
      });

      test('fails closed when the consent lookup throws', () async {
        final result =
            await publisher(
              consentChecker: (_) async => throw StateError('relay down'),
            ).canReuseSelectedAudio(
              _publishedSound(pubkey: _other, allowsReuse: false),
            );

        expect(result, isFalse);
      });
    });

    group('resolveForPublish', () {
      test('publishes without audio tags when no sound was selected', () async {
        final resolution = await publisher().resolveForPublish(
          upload: upload,
          videoDTag: 'vine-1',
          allowAudioReuse: false,
        );

        expect(
          resolution,
          isA<VideoAudioResolved>()
              .having((r) => r.tags, 'tags', isEmpty)
              .having((r) => r.reuseDegraded, 'reuseDegraded', isFalse),
        );
      });

      test('references a reusable sound by its event id', () async {
        final resolution = await publisher().resolveForPublish(
          upload: upload,
          videoDTag: 'vine-1',
          allowAudioReuse: false,
          selectedAudio: _publishedSound(pubkey: _other),
          selectedAudioEventId: _soundEventId,
          selectedAudioRelay: 'wss://relay.example',
        );

        expect(
          resolution,
          isA<VideoAudioResolved>().having((r) => r.tags, 'tags', [
            ['e', _soundEventId, 'wss://relay.example', 'audio'],
          ]),
        );
      });

      test('recovers the event id behind a reused original-sound id', () async {
        final resolution = await publisher().resolveForPublish(
          upload: upload,
          videoDTag: 'vine-1',
          allowAudioReuse: false,
          selectedAudio: AudioEvent(
            id: 'video_$_soundEventId-1700000000',
            pubkey: _other,
            createdAt: 0,
            url: 'https://cdn.example/sound.mp3',
          ),
          selectedAudioEventId: 'video_$_soundEventId-1700000000',
        );

        expect(
          resolution,
          isA<VideoAudioResolved>().having((r) => r.tags, 'tags', [
            ['e', _soundEventId, 'wss://relay.divine.video', 'audio'],
          ]),
        );
      });

      test('throws when the sound explicitly forbids reuse', () async {
        await expectLater(
          publisher().resolveForPublish(
            upload: upload,
            videoDTag: 'vine-1',
            allowAudioReuse: false,
            selectedAudio: _publishedSound(
              pubkey: _other,
              allowsReuse: false,
              hasExplicitReuseConsent: true,
            ),
          ),
          throwsA(
            isA<AudioReuseNotPermittedException>().having(
              (e) => e.audioEventId,
              'audioEventId',
              _soundEventId,
            ),
          ),
        );
      });

      test('blocks the publish when consent cannot be verified', () async {
        final resolution = await publisher().resolveForPublish(
          upload: upload,
          videoDTag: 'vine-1',
          allowAudioReuse: false,
          selectedAudio: _publishedSound(pubkey: _other, allowsReuse: false),
        );

        expect(resolution, isA<VideoAudioBlocked>());
      });

      test(
        'degrades a reuse request that has no account to sign with',
        () async {
          when(() => authService.currentPublicKeyHex).thenReturn(null);

          final resolution = await publisher().resolveForPublish(
            upload: upload.copyWith(localVideoPath: '/tmp/video.mp4'),
            videoDTag: 'vine-1',
            allowAudioReuse: true,
          );

          expect(
            resolution,
            isA<VideoAudioResolved>()
                .having((r) => r.tags, 'tags', isEmpty)
                .having((r) => r.reuseDegraded, 'reuseDegraded', isTrue),
          );
        },
      );

      test(
        'logs why it blocks a provider sound with no account to sign with',
        () async {
          await LogCaptureService().clearAllLogs();
          when(() => authService.currentPublicKeyHex).thenReturn(null);

          final resolution = await publisher().resolveForPublish(
            upload: upload,
            videoDTag: 'vine-1',
            allowAudioReuse: false,
            selectedAudio: _providerSound(),
          );

          expect(resolution, isA<VideoAudioBlocked>());
          expect(
            LogCaptureService()
                .getRecentLogs(minLevel: LogLevel.error)
                .where(
                  (entry) => entry.name == 'VideoAudioPublisher',
                ),
            isNotEmpty,
            reason: 'VideoAudioBlocked promises its reason was logged',
          );
          verifyNever(() => relayPublisher.publishViaWebSocket(any()));
        },
      );

      test('blocks a reusable imported sound without attribution', () async {
        final resolution = await publisher().resolveForPublish(
          upload: upload,
          videoDTag: 'vine-1',
          allowAudioReuse: true,
          selectedAudio: AudioEvent(
            id: '${AudioEvent.localImportMarker}_take-1',
            pubkey: AudioEvent.localImportMarker,
            createdAt: 0,
            url: '/tmp/take-1.m4a',
          ),
        );

        expect(resolution, isA<VideoAudioBlocked>());
        verifyNever(() => relayPublisher.publishViaWebSocket(any()));
      });

      // These two share a fixture where the import would otherwise publish, so
      // the only difference between them is whether the attribution is valid.
      // Without that, both outcomes collapse to VideoAudioBlocked for unrelated
      // reasons (no Blossom service, no file) and the gate goes untested.
      group('imported-sound attribution gate', () {
        late Directory tempDir;
        late File audioFile;
        late _MockBlossomUploadService blossom;

        AudioEvent importedSound() => AudioEvent(
          id: '${AudioEvent.localImportMarker}_take-1',
          pubkey: AudioEvent.localImportMarker,
          createdAt: 0,
          url: audioFile.path,
        );

        setUp(() {
          tempDir = Directory.systemTemp.createTempSync('audio-attr-test');
          audioFile = File('${tempDir.path}/take-1.m4a')
            ..writeAsBytesSync(const [1, 2, 3]);
          blossom = _MockBlossomUploadService();
          when(
            () => blossom.uploadAudio(
              audioFile: any(named: 'audioFile'),
              mimeType: any(named: 'mimeType'),
            ),
          ).thenAnswer(
            (_) async => const BlossomUploadResult(
              success: true,
              videoId: _soundEventId,
              fallbackUrl: 'https://cdn.example/uploaded.m4a',
            ),
          );
          when(
            () => relayPublisher.publishViaWebSocket(any()),
          ).thenAnswer((_) async => EventPublishOutcome.published);
          when(() => authService.isAuthenticated).thenReturn(true);
          when(
            () => authService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async => _signedAudioEvent());
        });

        tearDown(() => tempDir.deleteSync(recursive: true));

        VideoAudioPublisher importPublisher() => VideoAudioPublisher(
          nostrClient: nostrClient,
          relayPublisher: relayPublisher,
          authService: authService,
          blossomUploadService: blossom,
        );

        test('publishes the import when the attribution is complete', () async {
          final resolution = await importPublisher().resolveForPublish(
            upload: upload,
            videoDTag: 'vine-1',
            allowAudioReuse: true,
            selectedAudio: importedSound(),
            audioShareAttribution: const AudioShareAttribution(
              title: 'Take 1',
              creatorName: 'Someone',
              publicTags: [],
              confirmedOwnWork: true,
            ),
          );

          expect(resolution, isA<VideoAudioResolved>());
        });

        test(
          'surfaces an account restriction instead of blocking the import',
          () async {
            when(() => relayPublisher.publishViaWebSocket(any())).thenThrow(
              const AccountRestrictedPublishException(
                reason: 'blocked: pubkey is suspended',
                source: AccountRestrictionSource.webSocket,
              ),
            );

            await expectLater(
              importPublisher().resolveForPublish(
                upload: upload,
                videoDTag: 'vine-1',
                allowAudioReuse: true,
                selectedAudio: importedSound(),
                audioShareAttribution: const AudioShareAttribution(
                  title: 'Take 1',
                  creatorName: 'Someone',
                  publicTags: [],
                  confirmedOwnWork: true,
                ),
              ),
              throwsA(isA<AccountRestrictedPublishException>()),
            );
          },
        );

        test('blocks the import when the attribution is incomplete', () async {
          final resolution = await importPublisher().resolveForPublish(
            upload: upload,
            videoDTag: 'vine-1',
            allowAudioReuse: true,
            selectedAudio: importedSound(),
            audioShareAttribution: const AudioShareAttribution(
              title: '   ',
              creatorName: 'Someone',
              publicTags: [],
              confirmedOwnWork: true,
            ),
          );

          expect(resolution, isA<VideoAudioBlocked>());
          verifyNever(
            () => blossom.uploadAudio(
              audioFile: any(named: 'audioFile'),
              mimeType: any(named: 'mimeType'),
            ),
          );
        });
      });
    });
  });
}

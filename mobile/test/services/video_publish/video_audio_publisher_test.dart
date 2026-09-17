// ABOUTME: Tests for VideoAudioPublisher: reuse-consent gating and which sound
// ABOUTME: reference a video publish ends up carrying

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/exceptions/video_exceptions.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_publish/signed_event_relay_publisher.dart';
import 'package:openvine/services/video_publish/video_audio_publisher.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _MockRelayPublisher extends Mock implements SignedEventRelayPublisher {}

class _FakeEvent extends Fake implements Event {}

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

void main() {
  late _MockNostrClient nostrClient;
  late _MockAuthService authService;
  late _MockRelayPublisher relayPublisher;

  final upload = PendingUpload.create(
    localVideoPath: '',
    nostrPubkey: _self,
    title: 'Plants',
  );

  setUpAll(() => registerFallbackValue(_FakeEvent()));

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
    });
  });
}

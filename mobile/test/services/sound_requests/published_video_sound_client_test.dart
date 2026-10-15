import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/services/sound_requests/published_video_sound_client.dart';

const owner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const soundId =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const address = '34236:$owner:clip';
VideoEvent video() => VideoEvent(
  id: 'c' * 64,
  pubkey: owner,
  createdAt: 1,
  content: 'description',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
  eventKind: 34236,
  addressableDTag: 'clip',
  nostrEventTags: const [
    ['d', 'clip'],
  ],
  videoUrl: 'https://example.com/video.mp4',
);
void main() {
  for (final original in [true, false]) {
    group('interactions', () {
      test(
        'retained audio can be requested and republished only when original: $original',
        () async {
          var extracted = false;
          var replaced = false;
          final client = PublishedVideoSoundClient(
            ownerPubkey: owner,
            currentOwner: () => owner,
            readSource: (_) async => SoundRequestSource(
              video: video().copyWith(audioEventId: soundId),
              allowReuse: false,
              requestable: true,
              audioEventId: soundId,
            ),
            acquireMedia: (_) async {
              extracted = true;
              return '/cached/video.mp4';
            },
            publishOriginal: (_, _) async => soundId,
            replaceMetadata: (_, _) async {
              replaced = true;
              return true;
            },
            fetchSound: (_) async => AudioEvent(
              id: soundId,
              pubkey: original ? owner : 'd' * 64,
              createdAt: 1,
              sourceVideoReference: address,
              hasExplicitReuseConsent: true,
            ),
          );
          final source = await client.resolve(address);
          expect(source.requestable, original);
          if (original) {
            expect(await client.publishAudio(source), soundId);
            await client.enableReuse(source, soundId);
            expect(replaced, isTrue);
            expect(extracted, isFalse);
          } else {
            await expectLater(client.publishAudio(source), throwsStateError);
          }
        },
      );
    });
  }

  group('interactions', () {
    test(
      'downloads published media and refuses stale-account replacement',
      () async {
        var active = owner;
        var mediaAcquired = false;
        var replaced = false;
        final client = PublishedVideoSoundClient(
          ownerPubkey: owner,
          currentOwner: () => active,
          readSource: (_) async => SoundRequestSource(
            video: video(),
            allowReuse: false,
            requestable: true,
          ),
          acquireMedia: (source) async {
            mediaAcquired = source.videoUrl != null;
            return '/cached/video.mp4';
          },
          publishOriginal: (source, path) async {
            expect(path, '/cached/video.mp4');
            return soundId;
          },
          replaceMetadata: (source, id) async {
            replaced = true;
            return true;
          },
          fetchSound: (_) async => null,
        );
        final source = await client.resolve(address);
        expect(await client.publishAudio(source), soundId);
        expect(mediaAcquired, isTrue);
        active = 'd' * 64;
        await expectLater(
          client.enableReuse(source, soundId),
          throwsStateError,
        );
        expect(replaced, isFalse);
      },
    );
  });
  group('interactions', () {
    test(
      'ready resolution requires current source linkage and public permission',
      () async {
        var allowed = false;
        var declined = false;
        final client = PublishedVideoSoundClient(
          ownerPubkey: owner,
          currentOwner: () => owner,
          readSource: (_) async => SoundRequestSource(
            video: video().copyWith(
              rawTags: {if (declined) 'allow_audio_reuse': 'false'},
            ),
            allowReuse: allowed,
            requestable: true,
            audioEventId: soundId,
          ),
          acquireMedia: (_) async => '',
          publishOriginal: (_, _) async => soundId,
          replaceMetadata: (_, _) async => true,
          fetchSound: (_) async => AudioEvent(
            id: soundId,
            pubkey: owner,
            createdAt: 1,
            url: 'https://example.com/sound.wav',
            sourceVideoReference: address,
            hasExplicitReuseConsent: true,
          ),
        );
        expect(await client.resolveReady(address, soundId), isNull);
        allowed = true;
        expect((await client.resolveReady(address, soundId))?.id, soundId);
        declined = true;
        expect(await client.resolveReady(address, soundId), isNull);
      },
    );
  });
}

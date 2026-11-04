import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/models/saved_sound.dart';
import 'package:openvine/models/sound_cover.dart';

VideoEvent _video({
  String? thumbnailUrl = 'https://example.com/thumb.jpg',
  String? blurhash = 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
  List<String> warnLabels = const [],
}) {
  return VideoEvent(
    id: 'video-id',
    pubkey: 'author-pubkey',
    createdAt: 1704067200,
    content: '',
    timestamp: DateTime.utc(2024),
    thumbnailUrl: thumbnailUrl,
    blurhash: blurhash,
    warnLabels: warnLabels,
  );
}

void main() {
  group(SoundCover, () {
    group('fromSourceVideo', () {
      test('takes the thumbnail and blurhash of the video', () {
        expect(
          SoundCover.fromSourceVideo(_video()),
          equals(
            const SoundCover(
              imageUrl: 'https://example.com/thumb.jpg',
              blurhash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
            ),
          ),
        );
      });

      test('keeps only the blurhash of a video behind a content warning', () {
        expect(
          SoundCover.fromSourceVideo(_video(warnLabels: const ['nudity'])),
          equals(const SoundCover(blurhash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj')),
        );
      });

      test('has no image for a video without a thumbnail', () {
        expect(
          SoundCover.fromSourceVideo(_video(thumbnailUrl: '')).imageUrl,
          isNull,
        );
      });
    });

    group('publishedWith', () {
      AudioEvent sound({String? imageUrl}) => AudioEvent(
        id: 'sound-id',
        pubkey: 'author-pubkey',
        createdAt: 1704067200,
        imageUrl: imageUrl,
        blurhash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
      );

      test("takes a cover stored on Divine's media server", () {
        final url = 'https://media.divine.video/${'a' * 64}';

        expect(
          SoundCover.publishedWith(sound(imageUrl: url)),
          equals(
            SoundCover(
              imageUrl: url,
              blurhash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
            ),
          ),
        );
      });

      test('ignores a cover stored anywhere else', () {
        expect(
          SoundCover.publishedWith(
            sound(imageUrl: 'https://example.com/cover.jpg'),
          ),
          isNull,
        );
      });

      test('is null for a sound published without a cover', () {
        expect(SoundCover.publishedWith(sound()), isNull);
      });
    });

    group('isScreenedHost', () {
      test("accepts Divine's media hosts over https", () {
        for (final host in [
          'media.divine.video',
          'cdn.divine.video',
          'blossom.divine.video',
        ]) {
          expect(SoundCover.isScreenedHost('https://$host/x'), isTrue);
        }
      });

      test('rejects other hosts, plain http and other schemes', () {
        for (final url in [
          'https://divine.video.example.com/x',
          'https://stream.divine.video/x',
          'http://media.divine.video/x',
          'data:image/png;base64,AAAA',
          'http://[::1',
        ]) {
          expect(SoundCover.isScreenedHost(url), isFalse, reason: url);
        }
      });

      test("accepts the local stack's server in a debug build", () {
        expect(SoundCover.isScreenedHost('http://localhost:43003/x'), isTrue);
      });
    });

    group('forSavedSound', () {
      const video = '34236:creator:clip';
      const storedFrame = 'https://example.com/saved-frame.jpg';

      SavedSound savedSound({String? imageUrl}) => SavedSound(
        audio: AudioEvent(
          id: 'sound',
          pubkey: 'creator',
          createdAt: 1,
          imageUrl: imageUrl,
          sourceVideoReference: video,
        ),
        personalHashtags: const [],
        catalogTags: const [],
        waveformSamples: const [],
        sourceContext: const SavedSoundSourceContext(thumbnailUrl: storedFrame),
      );

      test('keeps the frame stored with the sound until a lookup answers', () {
        expect(
          SoundCover.forSavedSound(savedSound()),
          const SoundCover(imageUrl: storedFrame),
        );
      });

      test('takes what the lookup found for its source video', () {
        const found = SoundCover(blurhash: 'LKO2?U%2Tw=w');

        expect(
          SoundCover.forSavedSound(
            savedSound(),
            sourceCovers: const {video: found},
          ),
          found,
        );
      });

      test('shows no frame of a source video found gone', () {
        expect(
          SoundCover.forSavedSound(
            savedSound(),
            sourceCovers: const {video: null},
          ),
          isNull,
        );
      });

      test('prefers the cover the sound was published with', () {
        const published = 'https://media.divine.video/cover.jpg';

        expect(
          SoundCover.forSavedSound(
            savedSound(imageUrl: published),
            sourceCovers: const {video: null},
          ),
          const SoundCover(imageUrl: published),
        );
      });
    });

    group('cannotBeReused', () {
      const video = '34236:creator:clip';
      final sound = AudioEvent(
        id: 'sound',
        pubkey: 'creator',
        createdAt: 1,
        sourceVideoReference: video,
      );

      test('is true for a video the lookup found gone', () {
        expect(
          SoundCover.cannotBeReused(sound, const {video: null}, viewer: 'me'),
          isTrue,
        );
      });

      test('is false for a video found, or not looked up yet', () {
        expect(
          SoundCover.cannotBeReused(
            sound,
            const {video: SoundCover()},
            viewer: 'me',
          ),
          isFalse,
        );
        expect(
          SoundCover.cannotBeReused(sound, const {}, viewer: 'me'),
          isFalse,
        );
        expect(SoundCover.cannotBeReused(sound, null, viewer: 'me'), isFalse);
      });

      test('is false for a sound taken from no video', () {
        final imported = AudioEvent(id: 'file', pubkey: 'me', createdAt: 1);

        expect(
          SoundCover.cannotBeReused(
            imported,
            const {video: null},
            viewer: 'someone',
          ),
          isFalse,
        );
      });

      test('is false for a sound the viewer published', () {
        expect(
          SoundCover.cannotBeReused(
            sound,
            const {video: null},
            viewer: 'creator',
          ),
          isFalse,
        );
      });
    });
  });
}

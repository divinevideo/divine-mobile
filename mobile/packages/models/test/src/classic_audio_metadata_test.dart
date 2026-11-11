import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';
import 'package:test/test.dart';

void main() {
  final pubkey = '1' * 64;

  group('Classic audio metadata', () {
    test('published caption and aliases survive persistence and editing', () {
      const description =
          'Original caption: The tiny puppet show\n'
          'Also known as: still got snacks';
      final event = Event(
        pubkey,
        1063,
        [
          ['title', 'Tiny puppet'],
          ['m', 'audio/mp4'],
        ],
        description,
        createdAt: 100,
      );
      final sound = AudioEvent.fromNostrEvent(event);
      final restored = AudioEvent.fromJson(
        sound.toJson(),
      ).copyWith(volume: 0.5);

      expect(restored.toJson()['description'], description);
      expect(restored.matchesSearch('still snacks'), isTrue);
      expect(restored.matchesSearch('tiny show'), isTrue);
      expect(restored.publicTags, isEmpty);
    });

    test(
      'classic originals keep the recognizable caption as the sound name',
      () {
        final video = VideoEvent(
          id: '2' * 64,
          pubkey: pubkey,
          createdAt: 100,
          timestamp: DateTime.fromMillisecondsSinceEpoch(100000),
          content: 'The tiny puppet show',
          title: 'The tiny puppet show',
          videoUrl: 'https://example.com/classic.mp4',
          rawTags: const {'platform': 'vine', 'd': 'classic-puppet'},
          isVerifiedArchive: true,
          archiveAudioReuseEnabled: true,
        );
        final sound = AudioEvent.fromVideoOriginalSound(
          video,
          creatorName: 'Alex',
        );

        expect(sound.title, 'The tiny puppet show');
        expect(sound.creatorName, 'Alex');
        expect(sound.sourceVideoReference, video.addressableId);
        expect(sound.requiresCurrentReuseVerification, isTrue);
      },
    );
    test('imported statistics alone are not a sound name', () {
      final video = VideoEvent(
        id: '2' * 64,
        pubkey: pubkey,
        createdAt: 100,
        timestamp: DateTime.fromMillisecondsSinceEpoch(100000),
        content: 'Original stats: 3 loops - 2 likes',
        title: 'Vine video',
        videoUrl: 'https://example.com/classic.mp4',
        rawTags: const {'platform': 'vine', 'd': 'classic-puppet'},
      );
      final sound = AudioEvent.fromVideoOriginalSound(
        video,
        creatorName: 'Alex',
      );

      expect(sound.title, 'Original sound - Alex');
      expect(sound.description, video.displayContent);
    });
  });
}

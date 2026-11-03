import 'package:models/models.dart';
import 'package:sounds_repository/sounds_repository.dart';
import 'package:test/test.dart';

void main() {
  group('linkDivineSounds', () {
    AudioEvent shipped(String manifestId) => AudioEvent.fromBundledSound(
      VineSound(
        id: manifestId,
        title: manifestId,
        assetPath: 'assets/sounds/$manifestId.mp3',
        duration: const Duration(seconds: 6),
      ),
    );

    AudioEvent published(String id, {String? shippedId, int createdAt = 1}) =>
        AudioEvent(
          id: id,
          pubkey: 'divine',
          createdAt: createdAt,
          divineSoundId: shippedId,
        );

    final eventA = 'a' * 64;
    final eventB = 'b' * 64;
    final eventC = 'c' * 64;

    test('ties a shipped sound to the event Divine published for it', () {
      final linked = linkDivineSounds(
        shipped: [shipped('wednesday'), shipped('boom')],
        published: [published(eventA, shippedId: 'wednesday')],
      );

      expect(linked.map((sound) => sound.id), [
        '${AudioEvent.bundledMarker}_wednesday',
        '${AudioEvent.bundledMarker}_boom',
      ]);
      expect(linked.first.linkedEventId, eventA);
      expect(linked.first.assetPath, 'assets/sounds/wednesday.mp3');
      expect(linked.last.linkedEventId, isNull);
    });

    test('adds the published sounds the app does not ship', () {
      final linked = linkDivineSounds(
        shipped: [shipped('wednesday')],
        published: [
          published(eventA),
          published(eventB, shippedId: 'dropped-from-the-app'),
        ],
      );

      expect(linked.map((sound) => sound.id), [
        '${AudioEvent.bundledMarker}_wednesday',
        eventA,
        eventB,
      ]);
    });

    test('ties to the newest of two events for one sound, keeping neither '
        'as a sound of its own', () {
      final linked = linkDivineSounds(
        shipped: [shipped('wednesday')],
        published: [
          published(eventB, shippedId: 'wednesday', createdAt: 2),
          published(eventC, shippedId: 'wednesday'),
        ],
      );

      expect(linked, hasLength(1));
      expect(linked.single.linkedEventId, eventB);
    });
  });
}

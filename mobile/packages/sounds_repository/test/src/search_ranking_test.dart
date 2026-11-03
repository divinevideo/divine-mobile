import 'package:sounds_repository/sounds_repository.dart';
import 'package:test/test.dart';

typedef _Sound = ({String? title, bool divine});

void main() {
  group('rankSearchMatches', () {
    List<String?> rank(List<_Sound> sounds, String query) => [
      for (final sound in rankSearchMatches(
        sounds,
        query,
        titleOf: (sound) => sound.title,
        isDivine: (sound) => sound.divine,
      ))
        sound.title,
    ];

    test('orders by how well the title fits', () {
      final ranked = rank(
        const [
          (title: 'Found by its tag', divine: false),
          (title: 'Old boom box', divine: false),
          (title: 'Kaboom', divine: false),
          (title: 'Boom shakalaka', divine: false),
          (title: 'Boom', divine: false),
        ],
        'boom',
      );

      expect(ranked, [
        'Boom',
        'Boom shakalaka',
        'Old boom box',
        'Kaboom',
        'Found by its tag',
      ]);
    });

    test('puts Divine first within a fit, not above a better one', () {
      final ranked = rank(
        const [
          (title: 'Laugh track', divine: false),
          (title: 'Laugh', divine: false),
          (title: 'Laugh riot', divine: true),
        ],
        'laugh',
      );

      expect(ranked, ['Laugh', 'Laugh riot', 'Laugh track']);
    });

    test('needs every word of the query for a word match', () {
      final ranked = rank(
        const [
          (title: 'Sad trombone', divine: false),
          (title: 'Sad violin', divine: false),
        ],
        '#violin sad',
      );

      expect(ranked, ['Sad violin', 'Sad trombone']);
    });

    test('fits a repeated word only where the title repeats it', () {
      final ranked = rank(
        const [
          (title: 'Boom', divine: false),
          (title: 'Boom Boom', divine: false),
        ],
        'boom boom',
      );

      expect(ranked, ['Boom Boom', 'Boom']);
    });

    test('reads a title spaced out of shape as the words it holds', () {
      final ranked = rank(
        const [
          (title: 'Rock anthem remix', divine: false),
          (title: ' Rock  anthem ', divine: false),
        ],
        'rock anthem',
      );

      expect(ranked, [' Rock  anthem ', 'Rock anthem remix']);
    });

    test('keeps the given order for equal matches and untitled ones', () {
      final ranked = rank(
        const [
          (title: null, divine: false),
          (title: 'Beat one', divine: false),
          (title: 'Beat two', divine: false),
        ],
        'beat',
      );

      expect(ranked, ['Beat one', 'Beat two', null]);
    });

    test('leaves the order alone without a query', () {
      const sounds = [
        (title: 'B', divine: false),
        (title: 'A', divine: true),
      ];

      expect(rank(sounds, '  '), ['B', 'A']);
    });
  });
}

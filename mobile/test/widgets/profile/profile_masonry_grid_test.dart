import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show VideoEvent;
import 'package:openvine/widgets/profile/profile_masonry_grid.dart';

VideoEvent _video({String? dimensions, Map<String, String>? rawTags}) {
  final now = DateTime(2026, 10, 28);
  return VideoEvent(
    id: 'video-id',
    pubkey: 'a' * 64,
    createdAt: now.millisecondsSinceEpoch ~/ 1000,
    content: '',
    timestamp: now,
    dimensions: dimensions,
    rawTags: rawTags ?? const {},
  );
}

void main() {
  group('profileTileAspectRatio', () {
    test('returns a 2:3 tile for a vertical video', () {
      expect(
        profileTileAspectRatio('1080x1920'),
        equals(profileVerticalTileAspectRatio),
      );
    });

    test('returns a square tile for a square video', () {
      expect(
        profileTileAspectRatio('480x480'),
        equals(profileSquareTileAspectRatio),
      );
    });

    test('returns a square tile for a landscape video', () {
      expect(
        profileTileAspectRatio('1920x1080'),
        equals(profileSquareTileAspectRatio),
      );
    });

    test('returns the fallback for missing or malformed dimensions', () {
      expect(profileTileAspectRatio(null, fallback: 1), equals(1));
      expect(profileTileAspectRatio('wide', fallback: 1), equals(1));
      expect(profileTileAspectRatio('0x100', fallback: 1), equals(1));
    });
  });

  group('profileTileAspectRatioForVideo', () {
    test('uses the video dimensions when present', () {
      expect(
        profileTileAspectRatioForVideo(_video(dimensions: '720x720')),
        equals(profileSquareTileAspectRatio),
      );
    });

    test('falls back to vertical for a video without dimensions', () {
      expect(
        profileTileAspectRatioForVideo(_video()),
        equals(profileVerticalTileAspectRatio),
      );
    });

    test('falls back to square for an original Vine without dimensions', () {
      expect(
        profileTileAspectRatioForVideo(
          _video(rawTags: const {'platform': 'vine'}),
        ),
        equals(profileSquareTileAspectRatio),
      );
    });
  });

  group(ProfileMasonryGrid, () {
    testWidgets('sizes each tile by its aspect ratio across three columns', (
      tester,
    ) async {
      const ratios = [
        profileVerticalTileAspectRatio,
        profileSquareTileAspectRatio,
        profileVerticalTileAspectRatio,
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 308,
              height: 600,
              child: CustomScrollView(
                slivers: [
                  ProfileMasonryGrid(
                    childCount: ratios.length,
                    aspectRatioOf: (index) => ratios[index],
                    itemBuilder: (context, index) =>
                        ColoredBox(key: ValueKey(index), color: Colors.black),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // (308 - 2 gaps of 4) / 3 columns = 100 wide.
      expect(
        tester.getSize(find.byKey(const ValueKey(0))),
        const Size(100, 150),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey(1))),
        const Size(100, 100),
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey(2))).dx,
        equals(208),
      );
    });
  });
}

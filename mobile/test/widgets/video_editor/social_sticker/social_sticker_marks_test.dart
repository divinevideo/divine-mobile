// ABOUTME: Tests the link and note marks social stickers draw in place of an
// ABOUTME: emoji: read from the icons' path data into their 32 by 32 box.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_editor/social_sticker/social_sticker_marks.dart';

void main() {
  group(SocialStickerMark, () {
    group('path', () {
      test('draws each mark inside its box, as its icon places it', () {
        const box = SocialStickerMark.box;
        final link = SocialStickerMark.link.path.getBounds();
        final note = SocialStickerMark.note.path.getBounds();

        // linkSimple.svg: 27 wide and high from (2.5, 2.5).
        expect(link.left, closeTo(2.5, 0.01));
        expect(link.top, closeTo(2.5, 0.01));
        expect(link.width, closeTo(27, 0.01));
        expect(link.height, closeTo(27, 0.01));
        // music_note.svg: its note head bulges a little left of the origin
        // the icon places it at, (5.94, 4.62), and its stem a hair above.
        expect(note.left, closeTo(5.81, 0.01));
        expect(note.top, closeTo(4.61, 0.01));
        expect(note.width, closeTo(20.25, 0.05));
        expect(note.height, closeTo(22.9, 0.05));
        for (final bounds in [link, note]) {
          expect(bounds.right, lessThanOrEqualTo(box));
          expect(bounds.bottom, lessThanOrEqualTo(box));
        }
      });
    });
  });
}

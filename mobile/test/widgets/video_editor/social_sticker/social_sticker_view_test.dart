// ABOUTME: Tests the social sticker as it shows on the video: the same size
// ABOUTME: whatever font size the system asks for.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/widgets/video_editor/social_sticker/social_sticker_view.dart';

const _mention = SocialStickerData(
  kind: SocialStickerKind.mention,
  pubkey: 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
  name: 'alice',
);

const _link = SocialStickerData(
  kind: SocialStickerKind.link,
  url: 'https://divine.video/about',
);

void main() {
  group(SocialStickerView, () {
    Future<Size> sizeAt(
      WidgetTester tester,
      SocialStickerData data,
      double textScale,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Center(child: SocialStickerView(data: data)),
          ),
        ),
      );
      return tester.getSize(find.byType(SocialStickerView));
    }

    group('renders', () {
      testWidgets('a pill the same size at any system font size', (
        tester,
      ) async {
        for (final data in [_mention, _link]) {
          final regular = await sizeAt(tester, data, 1);
          final large = await sizeAt(tester, data, 2);

          expect(large, equals(regular), reason: data.kind.name);
        }
      });
    });
  });
}

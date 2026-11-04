// ABOUTME: Tests the social sticker as it shows on the video: the same size
// ABOUTME: whatever font size the system asks for.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/utils/sound_credit_paint.dart';
import 'package:openvine/widgets/video_editor/info_sticker/sticker_pill_palette.dart';
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

  group(SocialStickerCopy, () {
    group('renders', () {
      testWidgets('a solid sound credit in a pill rounded like its own', (
        tester,
      ) async {
        const credit = SocialStickerData(
          kind: SocialStickerKind.soundCredit,
          soundTitle: 'Song',
          soundArtist: 'Artist',
        );
        // Twice the size it lays out at, as the frames carry it scaled.
        final box = soundCreditSize(credit) * 2;
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: SizedBox.fromSize(
                size: box,
                child: const SocialStickerCopy(data: credit),
              ),
            ),
          ),
        );

        // Its own corners are 48 round where it lays out, 96 at twice that.
        expect(
          find.byType(SocialStickerCopy),
          paints..something((method, arguments) {
            if (method != #drawRRect) return false;
            final [RRect pill, Paint paint] = arguments;
            return pill.outerRect == Offset.zero & box &&
                (pill.tlRadiusX - 96).abs() < 1e-9 &&
                paint.color ==
                    StickerPillPalette.of(InfoStickerStyle.light).background;
          }),
        );
      });
    });
  });
}

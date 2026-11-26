// ABOUTME: Widget tests for VideoEditorSticker: bundled raster stickers, the
// ABOUTME: legacy SVGs older drafts still name, and network stickers.

import 'package:flutter/rendering.dart' show RenderImage;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart'
    show LocalizedText, StickerData, StickerPackData;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/sticker_editor/video_editor_sticker.dart';

void main() {
  group(VideoEditorSticker, () {
    const assetSticker = StickerData.asset(
      'assets/divine_stickers/heart.webp',
      description: LocalizedText({'en': 'Heart'}),
      tags: ['heart'],
      packData: StickerPackData.fallback,
    );

    const legacySvgSticker = StickerData.asset(
      'assets/stickers/heart.svg',
      description: LocalizedText({'en': 'Heart'}),
      tags: ['heart'],
      packData: StickerPackData.fallback,
    );

    const networkSticker = StickerData.network(
      'https://example.com/sticker.png',
      description: LocalizedText({'en': 'Network sticker'}),
      tags: ['network'],
      packData: StickerPackData.fallback,
    );

    Widget buildTestWidget({
      StickerData sticker = assetSticker,
      bool? enableLimitCacheSize,
      double size = 100,
    }) {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: size,
            height: size,
            child: VideoEditorSticker(
              sticker: sticker,
              enableLimitCacheSize: enableLimitCacheSize ?? true,
            ),
          ),
        ),
      );
    }

    group('asset stickers', () {
      testWidgets('draws a raster sticker as an image', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        expect(find.byType(Image), findsOneWidget);
        expect(find.byType(SvgPicture), findsNothing);
      });

      testWidgets('draws a legacy SVG sticker a draft still names', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget(sticker: legacySvgSticker));

        expect(find.byType(SvgPicture), findsOneWidget);
        expect(find.byType(Image), findsNothing);
      });

      testWidgets('decodes a raster sticker at the picker cell size', (
        tester,
      ) async {
        // A smaller box than the largest picker cell still decodes at that
        // cell's size, so a precache made before layout shares the entry.
        await tester.pumpWidget(buildTestWidget(size: 80));

        final image = tester.widget<Image>(find.byType(Image)).image;
        final pixels = (stickerPickerCellExtent * tester.view.devicePixelRatio)
            .ceil();
        expect(
          image,
          isA<ResizeImage>()
              .having((resize) => resize.width, 'width', pixels)
              .having((resize) => resize.height, 'height', pixels)
              .having(
                (resize) => resize.policy,
                'policy',
                ResizeImagePolicy.fit,
              )
              .having(
                (resize) => resize.imageProvider,
                'imageProvider',
                const AssetImage('assets/divine_stickers/heart.webp'),
              ),
        );
      });

      testWidgets('draws a precached raster sticker in its first frame', (
        tester,
      ) async {
        // Decodes started by earlier tests finish in real time between tests
        // and would otherwise already be cached here.
        final imageCache = PaintingBinding.instance.imageCache
          ..clear()
          ..clearLiveImages();
        addTearDown(imageCache.clear);
        late BuildContext context;
        await tester.pumpWidget(
          Builder(
            builder: (builderContext) {
              context = builderContext;
              return const SizedBox();
            },
          ),
        );
        await tester.runAsync(
          () => precacheStickerPickerImage(context, assetSticker.assetPath!),
        );

        await tester.pumpWidget(buildTestWidget());

        // Without the precache the decode is still running here, and the
        // picker shows an empty cell that fills in later.
        expect(
          tester.renderObject<RenderImage>(find.byType(RawImage)).image,
          isNotNull,
        );
      });

      testWidgets(
        'decodes a raster sticker at full size without cache sizing',
        (tester) async {
          await tester.pumpWidget(buildTestWidget(enableLimitCacheSize: false));

          expect(
            tester.widget<Image>(find.byType(Image)).image,
            equals(const AssetImage('assets/divine_stickers/heart.webp')),
          );
        },
      );
    });

    testWidgets('uses LayoutBuilder for network stickers with cache sizing', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(sticker: networkSticker, enableLimitCacheSize: true),
      );

      expect(find.byType(LayoutBuilder), findsOneWidget);
    });

    testWidgets(
      'does not use LayoutBuilder for network stickers without cache sizing',
      (tester) async {
        await tester.pumpWidget(
          buildTestWidget(sticker: networkSticker, enableLimitCacheSize: false),
        );

        expect(find.byType(LayoutBuilder), findsNothing);
      },
    );
  });
}

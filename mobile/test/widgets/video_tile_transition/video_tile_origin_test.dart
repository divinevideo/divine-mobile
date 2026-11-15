import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_tile_transition/video_tile_origin.dart';

import 'sequenced_image_provider.dart';

const _tileRect = Rect.fromLTWH(20, 100, 120, 180);

class _Tile extends StatelessWidget {
  const _Tile({
    required this.rect,
    this.image,
    this.imageProvider,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.withBoundary = true,
    this.onContext,
  });

  final Rect rect;
  final ui.Image? image;

  /// Shows the thumbnail through an [Image] instead of [image].
  final ImageProvider<Object>? imageProvider;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final bool withBoundary;
  final ValueChanged<BuildContext>? onContext;

  @override
  Widget build(BuildContext context) {
    final image = this.image;
    final imageProvider = this.imageProvider;
    final thumbnail = imageProvider != null
        ? Image(image: imageProvider, fit: fit, alignment: alignment)
        : image == null
        ? const ColoredBox(color: Color(0xFF00FF00))
        : RawImage(image: image, fit: fit, alignment: alignment);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          Positioned.fromRect(
            rect: rect,
            child: Builder(
              builder: (tileContext) {
                onContext?.call(tileContext);
                return withBoundary
                    ? VideoTileThumbnailBoundary(child: thumbnail)
                    : thumbnail;
              },
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  group(VideoTileOrigin, () {
    Future<ui.Image> squareImage(WidgetTester tester) async {
      final image = await tester.runAsync(
        () => createTestImage(width: 300, height: 300),
      );
      addTearDown(image!.dispose);
      return image;
    }

    group('capture', () {
      testWidgets('reads the tile bounds and the video it shows', (
        tester,
      ) async {
        late BuildContext tileContext;
        await tester.pumpWidget(
          _Tile(rect: _tileRect, onContext: (c) => tileContext = c),
        );

        final origin = VideoTileOrigin.capture(tileContext, videoId: 'video1');

        expect(origin, isNotNull);
        expect(origin!.rect, equals(_tileRect));
        expect(origin.videoId, equals('video1'));
        expect(origin.borderRadius, equals(4));
      });

      testWidgets('returns null for a tile without a thumbnail boundary', (
        tester,
      ) async {
        late BuildContext tileContext;
        await tester.pumpWidget(
          _Tile(
            rect: _tileRect,
            withBoundary: false,
            onContext: (c) => tileContext = c,
          ),
        );

        expect(VideoTileOrigin.capture(tileContext, videoId: 'v'), isNull);
      });
    });

    group('rect', () {
      testWidgets('follows the tile when it moves', (tester) async {
        late BuildContext tileContext;
        await tester.pumpWidget(
          _Tile(rect: _tileRect, onContext: (c) => tileContext = c),
        );
        final origin = VideoTileOrigin.capture(tileContext, videoId: 'v')!;
        expect(origin.rect, equals(_tileRect));

        const moved = Rect.fromLTWH(20, 40, 120, 180);
        await tester.pumpWidget(const _Tile(rect: moved));

        expect(origin.rect, equals(moved));
      });

      testWidgets('is only the painted part of a letterboxed thumbnail', (
        tester,
      ) async {
        final image = await squareImage(tester);
        late BuildContext tileContext;
        await tester.pumpWidget(
          _Tile(
            rect: _tileRect,
            image: image,
            fit: BoxFit.contain,
            onContext: (c) => tileContext = c,
          ),
        );

        final origin = VideoTileOrigin.capture(tileContext, videoId: 'v')!;

        expect(
          origin.rect,
          equals(
            Rect.fromCenter(center: _tileRect.center, width: 120, height: 120),
          ),
        );
      });

      testWidgets('is null once the tile is gone', (tester) async {
        late BuildContext tileContext;
        await tester.pumpWidget(
          _Tile(rect: _tileRect, onContext: (c) => tileContext = c),
        );
        final origin = VideoTileOrigin.capture(tileContext, videoId: 'v')!;
        expect(origin.rect, isNotNull);

        await tester.pumpWidget(const SizedBox.shrink());

        expect(origin.rect, isNull);
      });
    });

    group('alignment', () {
      testWidgets('is where the tile crops its thumbnail', (tester) async {
        final image = await squareImage(tester);
        late BuildContext tileContext;
        await tester.pumpWidget(
          _Tile(
            rect: _tileRect,
            image: image,
            alignment: AlignmentDirectional.topStart,
            onContext: (c) => tileContext = c,
          ),
        );

        final origin = VideoTileOrigin.capture(tileContext, videoId: 'v')!;

        expect(origin.alignment, equals(Alignment.topLeft));
      });

      testWidgets('is the middle for a snapshot of a tile with no image', (
        tester,
      ) async {
        late BuildContext tileContext;
        await tester.pumpWidget(
          _Tile(rect: _tileRect, onContext: (c) => tileContext = c),
        );

        final origin = VideoTileOrigin.capture(tileContext, videoId: 'v')!;

        expect(origin.alignment, equals(Alignment.center));
      });
    });

    group('takeImage', () {
      testWidgets('hands over the whole decoded thumbnail, not the crop', (
        tester,
      ) async {
        final square = await squareImage(tester);
        late BuildContext tileContext;
        await tester.pumpWidget(
          _Tile(
            rect: _tileRect,
            image: square,
            onContext: (c) => tileContext = c,
          ),
        );
        final origin = VideoTileOrigin.capture(tileContext, videoId: 'v')!;

        final image = origin.takeImage();
        addTearDown(() => image?.dispose());

        expect(image, isNotNull);
        expect(image!.isCloneOf(square), isTrue);
        expect(origin.takeImage(), isNull);
      });

      testWidgets('falls back to a snapshot of a tile with no image', (
        tester,
      ) async {
        late BuildContext tileContext;
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(devicePixelRatio: 2),
            child: _Tile(rect: _tileRect, onContext: (c) => tileContext = c),
          ),
        );
        final origin = VideoTileOrigin.capture(tileContext, videoId: 'v')!;

        final image = origin.takeImage();
        addTearDown(() => image?.dispose());

        expect(image, isNotNull);
        expect(image!.width, equals(240));
        expect(image.height, equals(360));
      });
    });

    group('playerSizeImage', () {
      Future<ui.Image> image(WidgetTester tester, int size) async {
        final image = await tester.runAsync(
          () => createTestImage(width: size, height: size),
        );
        addTearDown(image!.dispose);
        return image;
      }

      Future<VideoTileOrigin> captureTileShowing(
        WidgetTester tester,
        ImageProvider<Object> provider,
      ) async {
        addTearDown(() {
          imageCache
            ..clear()
            ..clearLiveImages();
        });
        late BuildContext tileContext;
        await tester.pumpWidget(
          _Tile(
            rect: _tileRect,
            imageProvider: provider,
            onContext: (c) => tileContext = c,
          ),
        );
        await tester.pump();
        final origin = VideoTileOrigin.capture(tileContext, videoId: 'v')!;
        final taken = origin.takeImage();
        addTearDown(() => taken?.dispose());
        return origin;
      }

      testWidgets(
        'decodes the thumbnail again when the tile shows it resized',
        (
          tester,
        ) async {
          final tileDecode = await image(tester, 30);
          final playerDecode = await image(tester, 300);
          final provider = SequencedImageProvider([
            () => SynchronousFuture(tileDecode),
            () => SynchronousFuture(playerDecode),
          ]);
          final origin = await captureTileShowing(
            tester,
            ResizeImage(provider, width: 30),
          );

          ImageInfo? loaded;
          final listener = ImageStreamListener((info, _) => loaded = info);
          origin.playerSizeImage!.addListener(listener);
          addTearDown(() {
            origin.playerSizeImage!.removeListener(listener);
            loaded?.dispose();
          });

          expect(loaded?.image.isCloneOf(playerDecode), isTrue);
        },
      );

      testWidgets('is null when the tile shows the thumbnail unresized', (
        tester,
      ) async {
        final decode = await image(tester, 30);
        final origin = await captureTileShowing(
          tester,
          SequencedImageProvider([() => SynchronousFuture(decode)]),
        );

        expect(origin.playerSizeImage, isNull);
      });

      testWidgets("is null when the tile's decode already fills the screen", (
        tester,
      ) async {
        tester.view.physicalSize = const Size(300, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final decode = await image(tester, 300);
        final origin = await captureTileShowing(
          tester,
          ResizeImage(
            SequencedImageProvider([() => SynchronousFuture(decode)]),
            width: 300,
          ),
        );

        expect(origin.playerSizeImage, isNull);
      });
    });

    group('readImage', () {
      testWidgets('copies what the tile shows now', (tester) async {
        final square = await squareImage(tester);
        late BuildContext tileContext;
        await tester.pumpWidget(
          _Tile(
            rect: _tileRect,
            image: square,
            onContext: (c) => tileContext = c,
          ),
        );
        final origin = VideoTileOrigin.capture(tileContext, videoId: 'v')!;
        origin.takeImage()?.dispose();

        final image = origin.readImage();
        addTearDown(() => image?.dispose());

        expect(image?.isCloneOf(square), isTrue);
      });

      testWidgets('is null once the tile is gone', (tester) async {
        final square = await squareImage(tester);
        late BuildContext tileContext;
        await tester.pumpWidget(
          _Tile(
            rect: _tileRect,
            image: square,
            onContext: (c) => tileContext = c,
          ),
        );
        final origin = VideoTileOrigin.capture(tileContext, videoId: 'v')!;
        origin.takeImage()?.dispose();
        expect(origin.rect, isNotNull);

        await tester.pumpWidget(const SizedBox.shrink());

        expect(origin.readImage(), isNull);
      });
    });
  });
}

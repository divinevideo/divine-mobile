import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/blurhash_display.dart';
import 'package:openvine/widgets/video_clip/clip_thumbnail_image.dart';
import 'package:openvine/widgets/video_feed_item/blurred_video_backdrop.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

void main() {
  group(BlurredVideoBackdrop, () {
    const testUrl = 'https://example.com/poster.jpg';
    const testBlurhash = 'L6Pj0^jE.AyE_3t7t7R**0o#DgR4';

    Widget buildWidget({
      String url = testUrl,
      String? blurhash,
      double? videoAspectRatio,
    }) {
      return WidgetsApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        color: const Color(0xFF000000),
        builder: (_, _) => SizedBox(
          width: 400,
          height: 800,
          child: BlurredVideoBackdrop(
            url: url,
            blurhash: blurhash,
            videoAspectRatio: videoAspectRatio,
          ),
        ),
      );
    }

    testWidgets('renders $ClipRect wrapping $ImageFiltered', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.byType(ClipRect), findsOneWidget);
      expect(find.byType(ImageFiltered), findsOneWidget);
    });

    testWidgets(
      'renders $BlurhashDisplay without any blur pass when a blurhash '
      'is available',
      (tester) async {
        await tester.pumpWidget(buildWidget(blurhash: testBlurhash));

        final display = tester.widget<BlurhashDisplay>(
          find.byType(BlurhashDisplay),
        );
        expect(display.blurhash, equals(testBlurhash));
        expect(display.opacity, equals(0.5));
        // The runtime-blur fallback (and its saveLayers) must not mount.
        expect(find.byType(ImageFiltered), findsNothing);
        expect(find.byType(Opacity), findsNothing);
        expect(find.byType(VineCachedImage), findsNothing);
      },
    );

    testWidgets(
      'falls back to the runtime blur when blurhash is empty',
      (tester) async {
        await tester.pumpWidget(buildWidget(blurhash: ''));

        expect(find.byType(BlurhashDisplay), findsNothing);
        expect(find.byType(ImageFiltered), findsOneWidget);
      },
    );

    testWidgets(
      'renders the blurhash path without any poster url',
      (tester) async {
        await tester.pumpWidget(
          WidgetsApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            color: const Color(0xFF000000),
            builder: (_, _) => const SizedBox(
              width: 400,
              height: 800,
              child: BlurredVideoBackdrop(blurhash: testBlurhash),
            ),
          ),
        );

        expect(find.byType(BlurhashDisplay), findsOneWidget);
        expect(find.byType(VineCachedImage), findsNothing);
      },
    );

    testWidgets(
      'renders empty when neither blurhash nor url is available',
      (tester) async {
        await tester.pumpWidget(
          WidgetsApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            color: const Color(0xFF000000),
            builder: (_, _) => const SizedBox(
              width: 400,
              height: 800,
              child: BlurredVideoBackdrop(url: ''),
            ),
          ),
        );

        expect(find.byType(BlurhashDisplay), findsNothing);
        expect(find.byType(ImageFiltered), findsNothing);
        expect(find.byType(VineCachedImage), findsNothing);
      },
    );

    testWidgets(
      'blurs the local poster file when no url is available',
      (tester) async {
        // The pre-publish preview has a local thumbnail, never a poster URL.
        await tester.pumpWidget(
          WidgetsApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            color: const Color(0xFF000000),
            builder: (_, _) => const SizedBox(
              width: 400,
              height: 800,
              child: BlurredVideoBackdrop(filePath: '/tmp/poster.jpg'),
            ),
          ),
        );

        final image = tester.widget<ClipThumbnailImage>(
          find.byType(ClipThumbnailImage),
        );
        expect(image.path, equals('/tmp/poster.jpg'));
        expect(image.fit, equals(BoxFit.cover));
        expect(find.byType(ImageFiltered), findsOneWidget);
        expect(find.byType(VineCachedImage), findsNothing);
      },
    );

    testWidgets('bounds the network poster decode to physical layout size', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(800, 1600)
        ..devicePixelRatio = 2;
      addTearDown(() {
        tester.view
          ..resetPhysicalSize()
          ..resetDevicePixelRatio();
      });
      await tester.pumpWidget(buildWidget());

      final image = tester.widget<VineCachedImage>(
        find.byType(VineCachedImage),
      );
      expect(image.imageUrl, equals(testUrl));
      expect(image.memCacheWidth, 800);
      expect(image.memCacheHeight, 1600);
      expect(image.resizePolicy, ResizeImagePolicy.fit);
    });

    testWidgets('uses $BoxFit cover with half opacity', (tester) async {
      await tester.pumpWidget(buildWidget());

      final image = tester.widget<VineCachedImage>(
        find.byType(VineCachedImage),
      );
      expect(image.fit, equals(BoxFit.cover));
      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, equals(0.5));
    });

    testWidgets('errorWidget renders $SizedBox shrink when image fails', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());

      final image = tester.widget<VineCachedImage>(
        find.byType(VineCachedImage),
      );
      final fallback = image.errorWidget!(
        tester.element(find.byType(VineCachedImage)),
        'https://example.com/fallback.jpg',
        Exception('load error'),
      );

      expect(fallback, isA<SizedBox>());
      final box = fallback as SizedBox;
      expect(box.width, equals(0));
      expect(box.height, equals(0));
    });

    group('letterbox bands', () {
      testWidgets(
        'renders a RepaintBoundary-isolated blur fill in each letterbox bar '
        'when the aspect ratio is known',
        (tester) async {
          // 1:1 video in the 400×800 box → top and bottom bars → two fills.
          await tester.pumpWidget(
            buildWidget(blurhash: testBlurhash, videoAspectRatio: 1),
          );

          expect(find.byType(BlurhashDisplay), findsNWidgets(2));
          // Each bar wraps its fill in its own RepaintBoundary. Assert that
          // structure directly instead of counting RepaintBoundary widgets:
          // BlurhashDisplay adds its own internal RepaintBoundary once its
          // async image decode resolves, so a global count would be
          // timing-dependent.
          final bars = tester.widgetList<Positioned>(
            find.descendant(
              of: find.byType(BlurredVideoBackdrop),
              matching: find.byType(Positioned),
            ),
          );
          expect(bars, hasLength(2));
          for (final bar in bars) {
            expect(bar.child, isA<RepaintBoundary>());
          }
        },
      );

      testWidgets(
        'paints a single fullscreen fill when the aspect ratio is unknown',
        (tester) async {
          await tester.pumpWidget(buildWidget(blurhash: testBlurhash));

          expect(find.byType(BlurhashDisplay), findsOneWidget);
          // No letterbox bars: the fullscreen fill has no Positioned wrapper.
          expect(
            find.descendant(
              of: find.byType(BlurredVideoBackdrop),
              matching: find.byType(Positioned),
            ),
            findsNothing,
          );
        },
      );
    });

    group('letterboxVideoRect', () {
      test('centers a 1:1 video with symmetric top/bottom bars', () {
        // 1:1 into 400×800 → 400×400 centered → 200 px bars top and bottom.
        expect(
          letterboxVideoRect(1, const Size(400, 800)),
          equals(const Rect.fromLTWH(0, 200, 400, 400)),
        );
      });

      test('pillarboxes a video wider than a landscape box', () {
        // 1:1 into 800×400 → 400×400 centered → 200 px bars left and right.
        expect(
          letterboxVideoRect(1, const Size(800, 400)),
          equals(const Rect.fromLTWH(200, 0, 400, 400)),
        );
      });

      test('letterboxes a 16:9 video in a portrait box', () {
        // 16:9 (≈1.778) into 400×800 → full width, height 225, centered.
        final rect = letterboxVideoRect(16 / 9, const Size(400, 800));
        expect(rect.width, equals(400));
        expect(rect.height, closeTo(225, 0.001));
        expect(rect.top, closeTo((800 - 225) / 2, 0.001));
      });
    });

    group('letterboxBands', () {
      // Assert the exact band rects (not just the count): a regression that
      // keeps two bands but shifts or shrinks one — a 1px seam — must fail.
      test(
        'tiles full-width top and bottom bars around a letterboxed video',
        () {
          const box = Size(400, 800);
          // 1:1 in a portrait box → 400×400 video centered → 200px top/bottom.
          final bands = letterboxBands(letterboxVideoRect(1, box), box);
          expect(bands, hasLength(2));
          expect(bands, contains(const Rect.fromLTWH(0, 0, 400, 200)));
          expect(bands, contains(const Rect.fromLTWH(0, 600, 400, 200)));
        },
      );

      test('tiles left and right bars around a pillarboxed video', () {
        const box = Size(800, 400);
        // 1:1 in a landscape box → 400×400 video centered → 200px left/right.
        final bands = letterboxBands(letterboxVideoRect(1, box), box);
        expect(bands, hasLength(2));
        expect(bands, contains(const Rect.fromLTWH(0, 0, 200, 400)));
        expect(bands, contains(const Rect.fromLTWH(600, 0, 200, 400)));
      });
    });

    group('backdropAspectRatio', () {
      test('returns width / height when both dimensions are known', () {
        expect(backdropAspectRatio(1920, 1080), closeTo(16 / 9, 0.0001));
      });

      test('returns null when either dimension is missing', () {
        expect(backdropAspectRatio(null, 1080), isNull);
        expect(backdropAspectRatio(1920, null), isNull);
      });

      test('returns null when height is zero (avoids divide-by-zero)', () {
        expect(backdropAspectRatio(1920, 0), isNull);
      });
    });

    group('videoCoversFeedViewport', () {
      // Mirrors the cover branch of VideoItemWidget._resolveBoxFit: the video
      // is cover-fit (and so occludes the backdrop) only when portrait-expand
      // is on and it is not square. These pin the local mirror; the real
      // _resolveBoxFit is private and driven by the decoded ratio, so nothing
      // binds the two — keep them in sync by hand.
      test('landscape with portrait-expand covers the viewport', () {
        expect(
          videoCoversFeedViewport(
            aspectRatio: 16 / 9,
            shouldPortraitExpand: true,
          ),
          isTrue,
        );
      });

      test('square stays contain-fit even with portrait-expand', () {
        expect(
          videoCoversFeedViewport(aspectRatio: 1, shouldPortraitExpand: true),
          isFalse,
        );
      });

      test('portrait-expand off never covers the viewport', () {
        expect(
          videoCoversFeedViewport(
            aspectRatio: 16 / 9,
            shouldPortraitExpand: false,
          ),
          isFalse,
        );
      });

      test(
        'unknown aspect ratio never covers (backdrop paints fullscreen)',
        () {
          expect(
            videoCoversFeedViewport(
              aspectRatio: null,
              shouldPortraitExpand: true,
            ),
            isFalse,
          );
        },
      );
    });
  });
}

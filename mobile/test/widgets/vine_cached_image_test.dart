import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_cache/media_cache.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

class _FakeImageCache extends Mock implements MediaCacheManager {}

Widget _deadErrorBuilder(BuildContext context, String url, Object error) {
  return const Text('dead-render', textDirection: TextDirection.ltr);
}

void main() {
  group('openVineImageCache', () {
    test('is a $MediaCacheManager', () {
      expect(openVineImageCache, isA<MediaCacheManager>());
    });

    test('uses image config with correct cache key', () {
      expect(
        openVineImageCache.mediaConfig.cacheKey,
        equals('openvine_image_cache'),
      );
    });

    test('uses 7-day stale period from image preset', () {
      expect(
        openVineImageCache.mediaConfig.stalePeriod,
        equals(const Duration(days: 7)),
      );
    });

    test('limits to 200 cache objects', () {
      expect(openVineImageCache.mediaConfig.maxNrOfCacheObjects, equals(200));
    });
  });

  group(VineCachedImage, () {
    const testUrl = 'https://example.com/image.jpg';

    testWidgets(
      'renders the error widget without resolving a known-dead host',
      (tester) async {
        const deadUrl = 'http://v.cdn.vine.co/v/avatars/dead.jpg';
        final cache = _FakeImageCache();
        debugImageCacheOverride = cache;
        addTearDown(() => debugImageCacheOverride = null);

        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: VineCachedImage(
              imageUrl: deadUrl,
              errorWidget: _deadErrorBuilder,
            ),
          ),
        );

        expect(find.text('dead-render'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (w) => w is Image && w.image is MediaCacheImageProvider,
          ),
          findsNothing,
        );
        verifyNever(() => cache.getFileFromCache(any()));
        verifyNever(
          () => cache.cacheFileCancellable(
            any(),
            key: any(named: 'key'),
            aliasKey: any(named: 'aliasKey'),
            authHeaders: any(named: 'authHeaders'),
          ),
        );
      },
    );

    testWidgets('renders Image with a MediaCacheImageProvider', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: VineCachedImage(imageUrl: testUrl),
        ),
      );

      expect(find.byType(Image), findsOneWidget);

      final image = tester.widget<Image>(find.byType(Image));
      final provider = image.image as MediaCacheImageProvider;
      expect(provider.url, equals(testUrl));
      expect(provider.cacheManager, same(openVineImageCache));
    });

    testWidgets('uses ResizeImage when memCache sizing is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: VineCachedImage(
            imageUrl: testUrl,
            memCacheWidth: 256,
            memCacheHeight: 512,
          ),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      final resized = image.image as ResizeImage;
      expect(resized.width, 256);
      expect(resized.height, 512);
      expect(resized.policy, ResizeImagePolicy.exact);
      expect(resized.imageProvider, isA<MediaCacheImageProvider>());
    });

    testWidgets('passes the requested resize policy to ResizeImage', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: VineCachedImage(
            imageUrl: testUrl,
            memCacheWidth: 256,
            memCacheHeight: 512,
            resizePolicy: ResizeImagePolicy.fit,
          ),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      final resized = image.image as ResizeImage;
      expect(resized.policy, ResizeImagePolicy.fit);
    });

    testWidgets('defaults fit to BoxFit.cover', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: VineCachedImage(imageUrl: testUrl),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, equals(BoxFit.cover));
    });

    testWidgets('defaults alignment to Alignment.center', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: VineCachedImage(imageUrl: testUrl),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.alignment, equals(Alignment.center));
    });

    testWidgets('passes width and height through', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: VineCachedImage(imageUrl: testUrl, width: 100, height: 200),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.width, equals(100));
      expect(image.height, equals(200));
    });

    testWidgets('passes fit and alignment through', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: VineCachedImage(
            imageUrl: testUrl,
            fit: BoxFit.contain,
            alignment: Alignment.topCenter,
          ),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, equals(BoxFit.contain));
      expect(image.alignment, equals(Alignment.topCenter));
    });

    testWidgets('defaults fadeInDuration to 500ms', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: VineCachedImage(imageUrl: testUrl),
        ),
      );

      final image = tester.widget<VineCachedImage>(
        find.byType(VineCachedImage),
      );
      expect(image.fadeInDuration, equals(const Duration(milliseconds: 500)));
    });

    testWidgets('defaults fadeOutDuration to 1000ms', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: VineCachedImage(imageUrl: testUrl),
        ),
      );

      final image = tester.widget<VineCachedImage>(
        find.byType(VineCachedImage),
      );
      expect(image.fadeOutDuration, equals(const Duration(milliseconds: 1000)));
    });

    testWidgets('passes fadeInDuration and fadeOutDuration through', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: VineCachedImage(
            imageUrl: testUrl,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration(milliseconds: 200),
          ),
        ),
      );

      final image = tester.widget<VineCachedImage>(
        find.byType(VineCachedImage),
      );
      expect(image.fadeInDuration, equals(Duration.zero));
      expect(image.fadeOutDuration, equals(const Duration(milliseconds: 200)));
    });
  });

  group('debugImageCacheOverride', () {
    tearDown(() => debugImageCacheOverride = null);

    testWidgets('resolves through openVineImageCache when override is null', (
      tester,
    ) async {
      debugImageCacheOverride = null;
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: VineCachedImage(imageUrl: 'https://example.com/a.jpg'),
        ),
      );

      final provider =
          tester.widget<Image>(find.byType(Image)).image
              as MediaCacheImageProvider;
      expect(provider.cacheManager, same(openVineImageCache));
    });

    testWidgets('resolves through the override when set', (tester) async {
      final override = _FakeImageCache();
      debugImageCacheOverride = override;
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: VineCachedImage(imageUrl: 'https://example.com/a.jpg'),
        ),
      );

      final provider =
          tester.widget<Image>(find.byType(Image)).image
              as MediaCacheImageProvider;
      expect(provider.cacheManager, same(override));
    });

    testWidgets(
      'skips AnimatedOpacity fade-in when image resolves synchronously from '
      'memory cache',
      (tester) async {
        const cachedUrl = 'https://example.com/sync-cached.jpg';
        final override = _FakeImageCache();
        debugImageCacheOverride = override;
        addTearDown(() => debugImageCacheOverride = null);

        final recorder = ui.PictureRecorder();
        ui.Canvas(recorder);
        final uiImage = recorder.endRecording().toImageSync(4, 4);
        final provider = MediaCacheImageProvider(
          cachedUrl,
          cacheManager: override,
        );
        PaintingBinding.instance.imageCache.putIfAbsent(
          provider,
          () => OneFrameImageStreamCompleter(
            SynchronousFuture<ImageInfo>(ImageInfo(image: uiImage.clone())),
          ),
        );
        addTearDown(() {
          PaintingBinding.instance.imageCache.evict(provider);
          uiImage.dispose();
        });

        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: VineCachedImage(imageUrl: cachedUrl),
          ),
        );

        expect(find.byType(Image), findsOneWidget);
        expect(find.byType(AnimatedOpacity), findsNothing);
      },
    );
  });
}

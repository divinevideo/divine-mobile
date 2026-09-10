// ABOUTME: Regression coverage for concurrent thumbnail loading through VineCachedImage
// ABOUTME: Ensures placeholders and transport settings stay stable under load
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_cache/media_cache.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

void main() {
  group('VineCachedImage concurrency regression', () {
    testWidgets(
      'multiple concurrent image widgets should build without hanging',
      (tester) async {
        const testImageUrls = [
          'https://api.openvine.co/avatar1.jpg',
          'https://api.openvine.co/avatar2.jpg',
          'https://api.openvine.co/avatar3.jpg',
          'https://api.openvine.co/thumbnail1.jpg',
          'https://api.openvine.co/thumbnail2.jpg',
          'https://api.openvine.co/thumbnail3.jpg',
        ];

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Column(
                children: testImageUrls
                    .map(
                      (url) => SizedBox(
                        width: 100,
                        height: 100,
                        child: VineCachedImage(
                          imageUrl: url,
                          placeholder: (context, url) =>
                              Container(color: Colors.grey),
                          errorWidget: (context, url, error) =>
                              Container(color: Colors.red),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        );

        await tester.pump();

        final stopwatch = Stopwatch()..start();
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        stopwatch.stop();

        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(5000),
          reason:
              'Concurrent image loading took too long, possible stall detected',
        );
        expect(find.byType(Container), findsAtLeast(testImageUrls.length));
      },
    );

    testWidgets('single image shows placeholder before load resolves', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 100,
              height: 100,
              child: VineCachedImage(
                imageUrl: 'https://api.openvine.co/nonexistent-image.jpg',
                placeholder: (context, url) => const ColoredBox(
                  color: Colors.grey,
                  child: Text('Loading'),
                ),
                errorWidget: (context, url, error) =>
                    const ColoredBox(color: Colors.red, child: Text('Error')),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Loading'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ColoredBox), findsAtLeast(1));
    });

    test('openVineImageCache keeps the image preset transport limits', () {
      expect(openVineImageCache.mediaConfig, isA<MediaCacheConfig>());
      expect(
        openVineImageCache.mediaConfig.connectionTimeout,
        const Duration(seconds: 10),
      );
      expect(
        openVineImageCache.mediaConfig.idleTimeout,
        const Duration(seconds: 30),
      );
      expect(openVineImageCache.mediaConfig.maxConnectionsPerHost, 20);
    });
  });
}

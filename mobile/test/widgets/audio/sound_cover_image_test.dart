import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/sound_cover.dart';
import 'package:openvine/widgets/audio/sound_cover_image.dart';
import 'package:openvine/widgets/blurhash_display.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

const _blurhash = 'LEHV6nWB2yk8pyo0adR*.7kCMdnj';

Widget _app(SoundCover? cover, {String colorSeed = ''}) => MaterialApp(
  localizationsDelegates: appLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: VineTheme.theme,
  home: Scaffold(
    body: Center(
      child: SoundCoverImage(cover: cover, size: 48, colorSeed: colorSeed),
    ),
  ),
);

Color _tileColor(WidgetTester tester) => tester
    .widget<ColoredBox>(find.byKey(const Key('sound_cover_fallback')))
    .color;

void main() {
  group(SoundCoverImage, () {
    group('renders', () {
      testWidgets('a colour tile for a sound without a cover', (tester) async {
        await tester.pumpWidget(_app(null));

        expect(find.byKey(const Key('sound_cover_fallback')), findsOneWidget);
        expect(find.byType(VineCachedImage), findsNothing);
      });

      testWidgets('the same colour for the same sound, and not one for all', (
        tester,
      ) async {
        final colors = <Color>{};
        for (final seed in ['a', 'b', 'c', 'd', 'e', 'f', 'a']) {
          await tester.pumpWidget(_app(null, colorSeed: seed));
          colors.add(_tileColor(tester));
        }
        await tester.pumpWidget(_app(null, colorSeed: 'a'));
        final first = _tileColor(tester);
        await tester.pumpWidget(_app(null, colorSeed: 'a'));

        expect(_tileColor(tester), first);
        expect(colors.length, greaterThan(1));
      });

      testWidgets('a plain tile while the cover is looked up', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            home: const Scaffold(
              body: Center(child: SoundCoverImage(isPending: true, size: 48)),
            ),
          ),
        );

        expect(find.byKey(const Key('sound_cover_pending')), findsOneWidget);
        expect(find.byKey(const Key('sound_cover_fallback')), findsNothing);
      });

      testWidgets('the blurhash when the cover has no image', (tester) async {
        await tester.pumpWidget(_app(const SoundCover(blurhash: _blurhash)));

        expect(find.byType(BlurhashDisplay), findsOneWidget);
        expect(find.byType(VineCachedImage), findsNothing);
        expect(find.byKey(const Key('sound_cover_fallback')), findsNothing);
      });

      testWidgets('the image when the cover has one', (tester) async {
        await tester.pumpWidget(
          _app(
            const SoundCover(
              imageUrl: 'https://example.com/thumb.jpg',
              blurhash: _blurhash,
            ),
          ),
        );

        final image = tester.widget<VineCachedImage>(
          find.byType(VineCachedImage),
        );
        expect(image.imageUrl, 'https://example.com/thumb.jpg');
      });

      // Decoding to both a width and a height squashed portrait video frames
      // into the square instead of cropping them.
      testWidgets('decodes the image by width alone, at the screen density', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          _app(const SoundCover(imageUrl: 'https://example.com/thumb.jpg')),
        );

        final image = tester.widget<VineCachedImage>(
          find.byType(VineCachedImage),
        );
        expect(image.memCacheWidth, 144);
        expect(image.memCacheHeight, isNull);
      });
    });
  });
}

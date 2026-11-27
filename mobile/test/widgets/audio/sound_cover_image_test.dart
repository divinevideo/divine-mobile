import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_cache/media_cache.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show SoundKind;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/sound_cover.dart';
import 'package:openvine/widgets/audio/sound_cover_image.dart';
import 'package:openvine/widgets/blurhash_display.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

const _blurhash = 'LEHV6nWB2yk8pyo0adR*.7kCMdnj';

class _MockMediaCacheManager extends Mock implements MediaCacheManager {}

Widget _app(
  SoundCover? cover, {
  String colorSeed = '',
  SoundKind? kind,
}) => MaterialApp(
  localizationsDelegates: appLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: VineTheme.theme,
  home: Scaffold(
    body: Center(
      child: SoundCoverImage(
        cover: cover,
        size: 48,
        colorSeed: colorSeed,
        kind: kind,
      ),
    ),
  ),
);

Color _tileColor(WidgetTester tester) => tester
    .widget<ColoredBox>(find.byKey(const Key('sound_cover_fallback')))
    .color;

DivineIconName _tileIcon(WidgetTester tester) => tester
    .widget<DivineIcon>(
      find.descendant(
        of: find.byKey(const Key('sound_cover_fallback')),
        matching: find.byType(DivineIcon),
      ),
    )
    .icon;

void main() {
  group(SoundCoverImage, () {
    group('renders', () {
      testWidgets('a colour tile for a sound without a cover', (tester) async {
        await tester.pumpWidget(_app(null));

        expect(find.byKey(const Key('sound_cover_fallback')), findsOneWidget);
        expect(find.byType(VineCachedImage), findsNothing);
      });

      testWidgets('notes on the colour tile of music', (tester) async {
        await tester.pumpWidget(_app(null, kind: SoundKind.music));

        expect(_tileIcon(tester), DivineIconName.musicNotes);
      });

      testWidgets('a flash on the colour tile of an effect', (tester) async {
        await tester.pumpWidget(_app(null, kind: SoundKind.effect));

        expect(_tileIcon(tester), DivineIconName.lightning);
      });

      testWidgets('a waveform on the colour tile of a sound of unknown kind', (
        tester,
      ) async {
        await tester.pumpWidget(_app(null));

        expect(_tileIcon(tester), DivineIconName.waveform);
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

      // A slow cover without a blurhash showed a blank grey tile until it
      // loaded or failed; on Android a stalled download has no timeout.
      testWidgets(
        'the colour tile while an image without a blurhash loads',
        (tester) async {
          final cache = _MockMediaCacheManager();
          final neverLoads = Completer<FileInfo?>();
          when(
            () => cache.getFileFromCache(any()),
          ).thenAnswer((_) => neverLoads.future);
          debugImageCacheOverride = cache;
          addTearDown(() => debugImageCacheOverride = null);
          addTearDown(imageCache.clear);

          await tester.pumpWidget(
            _app(const SoundCover(imageUrl: 'https://example.com/slow.jpg')),
          );
          await tester.pump(const Duration(seconds: 1));

          expect(find.byType(VineCachedImage), findsOneWidget);
          expect(
            find.byKey(const Key('sound_cover_fallback')),
            findsOneWidget,
          );
        },
      );

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

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/blurhash_display.dart';
import 'package:openvine/widgets/profile/profile_tab_thumbnail.dart';
import 'package:openvine/widgets/profile/profile_tab_thumbnail_placeholder.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';

void main() {
  group(ProfileTabThumbnail, () {
    Widget buildSubject({
      String? thumbnailUrl,
      String? blurhash,
      bool isPrecached = false,
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: Scaffold(
          body: SizedBox(
            width: 100,
            height: 100,
            child: ProfileTabThumbnail(
              thumbnailUrl: thumbnailUrl,
              blurhash: blurhash,
              isPrecached: isPrecached,
            ),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('$ProfileTabThumbnailPlaceholder when thumbnailUrl is null', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());

        expect(find.byType(ProfileTabThumbnailPlaceholder), findsOneWidget);
        expect(find.byType(PassiveAuthThumbnailImage), findsNothing);
      });

      testWidgets(
        '$ProfileTabThumbnailPlaceholder when thumbnailUrl is empty',
        (tester) async {
          await tester.pumpWidget(buildSubject(thumbnailUrl: ''));

          expect(find.byType(ProfileTabThumbnailPlaceholder), findsOneWidget);
          expect(find.byType(PassiveAuthThumbnailImage), findsNothing);
        },
      );

      testWidgets('$PassiveAuthThumbnailImage when thumbnailUrl is non-empty', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(thumbnailUrl: 'https://example.com/thumb.jpg'),
        );

        expect(find.byType(PassiveAuthThumbnailImage), findsOneWidget);
      });

      testWidgets(
        '$PassiveAuthThumbnailImage with default fade durations when not precached',
        (tester) async {
          await tester.pumpWidget(
            buildSubject(thumbnailUrl: 'https://example.com/thumb.jpg'),
          );

          final image = tester.widget<PassiveAuthThumbnailImage>(
            find.byType(PassiveAuthThumbnailImage),
          );
          expect(
            image.fadeInDuration,
            equals(const Duration(milliseconds: 500)),
          );
          expect(
            image.fadeOutDuration,
            equals(const Duration(milliseconds: 1000)),
          );
          expect(image.alignment, equals(Alignment.center));
        },
      );

      testWidgets(
        '$PassiveAuthThumbnailImage with zero fade durations when precached',
        (tester) async {
          await tester.pumpWidget(
            buildSubject(
              thumbnailUrl: 'https://example.com/thumb.jpg',
              isPrecached: true,
            ),
          );

          final image = tester.widget<PassiveAuthThumbnailImage>(
            find.byType(PassiveAuthThumbnailImage),
          );
          expect(image.fadeInDuration, equals(Duration.zero));
          expect(image.fadeOutDuration, equals(Duration.zero));
        },
      );

      // memCacheWidth = tile_width × DPR caps decoded size while leaving height
      // unconstrained so portrait thumbnails decode proportionally and BoxFit.cover
      // crops without upscaling. See PR #4220 (#4190).
      testWidgets(
        '$PassiveAuthThumbnailImage memCacheWidth matches tile width × devicePixelRatio',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            buildSubject(thumbnailUrl: 'https://example.com/thumb.jpg'),
          );

          final image = tester.widget<PassiveAuthThumbnailImage>(
            find.byType(PassiveAuthThumbnailImage),
          );
          // SizedBox is 100×100 and DPR is pinned to 1, so width = 100.
          expect(image.memCacheWidth, equals(100));
        },
      );
    });

    group('blurhash fallback', () {
      const validBlurhash = 'LEHV6nWB2yk8pyo0adR*.7kCMdnj';

      testWidgets(
        'uses the blurhash when passive thumbnail auth is unavailable',
        (
          tester,
        ) async {
          const url = 'https://media.divine.video/not-a-hash.jpg';
          await tester.pumpWidget(
            buildSubject(thumbnailUrl: url, blurhash: validBlurhash),
          );
          final image = tester.widget<PassiveAuthThumbnailImage>(
            find.byType(PassiveAuthThumbnailImage),
          );

          final fallback = image.errorWidget!(
            tester.element(find.byType(PassiveAuthThumbnailImage)),
            url,
            const PassiveAuthUnavailableThumbnailException(),
          );
          await tester.pumpWidget(MaterialApp(home: fallback));

          expect(find.byType(BlurhashDisplay), findsOneWidget);
        },
      );

      testWidgets(
        '$BlurhashDisplay when thumbnailUrl is null and blurhash is provided',
        (tester) async {
          await tester.pumpWidget(buildSubject(blurhash: validBlurhash));

          expect(find.byType(BlurhashDisplay), findsOneWidget);
          expect(find.byType(ProfileTabThumbnailPlaceholder), findsNothing);
        },
      );

      testWidgets(
        '$ProfileTabThumbnailPlaceholder when thumbnailUrl and blurhash are '
        'both null',
        (tester) async {
          await tester.pumpWidget(buildSubject());

          expect(find.byType(ProfileTabThumbnailPlaceholder), findsOneWidget);
          expect(find.byType(BlurhashDisplay), findsNothing);
        },
      );

      testWidgets(
        '$ProfileTabThumbnailPlaceholder when blurhash is empty string',
        (tester) async {
          await tester.pumpWidget(buildSubject(blurhash: ''));

          expect(find.byType(ProfileTabThumbnailPlaceholder), findsOneWidget);
          expect(find.byType(BlurhashDisplay), findsNothing);
        },
      );
    });
  });
}

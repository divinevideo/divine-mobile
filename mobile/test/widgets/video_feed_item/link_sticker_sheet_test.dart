// ABOUTME: Tests the sheet a link sticker opens: the whole domain and the
// ABOUTME: address shown before the link opens, and the sheet closing after.

import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_feed_item/link_sticker_sheet.dart';

const _url = 'https://www.example.com/a/very/long/path?with=query';

void main() {
  group('showLinkStickerSheet', () {
    late List<String> launched;

    setUp(() => launched = []);

    Future<void> openSheet(
      WidgetTester tester, {
      String url = _url,
      LinkStickerLauncher? launch,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => showLinkStickerSheet(
                    context,
                    url,
                    launch: launch ?? ((_, url) async => launched.add(url)),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    group('renders', () {
      testWidgets('the domain and the address before opening', (
        tester,
      ) async {
        await openSheet(tester);
        final l10n = lookupAppLocalizations(const Locale('en'));

        expect(find.text(l10n.messageExternalLinkDialogTitle), findsOneWidget);
        expect(find.text(l10n.videoStickerLinkSheetBody), findsOneWidget);
        expect(find.text('example.com'), findsOneWidget);
        expect(find.text(_url), findsOneWidget);
        expect(launched, isEmpty);
      });

      testWidgets('the whole domain, however long', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        // Cut at its end, this host would read as divine.video.
        const host =
            'divine.video.account-security-check.verify-login-session.example.com';
        await openSheet(tester, url: 'https://$host/login');

        final domain = tester.renderObject<RenderParagraph>(find.text(host));
        final lineHeight = domain.getFullHeightForCaret(
          const TextPosition(offset: 0),
        );

        expect(domain.size.height, greaterThan(lineHeight * 1.5));
        expect(domain.didExceedMaxLines, isFalse);
      });
    });

    group('interactions', () {
      testWidgets('handles a rejected launch and keeps the sheet open', (
        tester,
      ) async {
        await openSheet(
          tester,
          launch: (_, _) async => throw Exception('launch failed'),
        );

        await tester.tap(find.byType(LinkStickerSheetTile));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(LinkStickerSheetTile), findsOneWidget);
      });

      testWidgets('opens the link and closes on a tap', (tester) async {
        await openSheet(tester);

        await tester.tap(find.byType(LinkStickerSheetTile));
        await tester.pumpAndSettle();

        expect(launched, equals([_url]));
        expect(find.byType(LinkStickerSheetTile), findsNothing);
      });
    });
  });
}

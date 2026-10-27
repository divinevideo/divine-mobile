// ABOUTME: Tests the sheet a link sticker opens: the address shown in full
// ABOUTME: before the link opens, and the sheet closing once it has.

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

    Future<void> openSheet(WidgetTester tester) async {
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
                    _url,
                    launch: (_, url) async => launched.add(url),
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
      testWidgets('the domain and the full address before opening', (
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
    });

    group('interactions', () {
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

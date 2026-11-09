// ABOUTME: Widget tests for the shared TV-static message takeover
// ABOUTME: Covers optional description, optional action, close, and footer

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/tv_static_message_screen.dart';

void main() {
  group(TvStaticMessageScreen, () {
    testWidgets('renders the sticker, title, and description', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TvStaticMessageScreen(
            sticker: DivineStickerName.vintageTvTestPattern,
            title: 'Video not found',
            description: 'It was either deleted, or it is hiding.',
            onClose: () {},
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is DivineSticker &&
              w.sticker == DivineStickerName.vintageTvTestPattern,
        ),
        findsOneWidget,
      );
      expect(find.text('Video not found'), findsOneWidget);
      expect(
        find.text('It was either deleted, or it is hiding.'),
        findsOneWidget,
      );
    });

    testWidgets('omits the action button when no action is supplied', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TvStaticMessageScreen(
            sticker: DivineStickerName.alert,
            title: 'Video not found',
            onClose: () {},
          ),
        ),
      );

      expect(find.byType(DivineButton), findsNothing);
    });

    testWidgets('invokes the action when the button is tapped', (tester) async {
      var actionCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TvStaticMessageScreen(
            sticker: DivineStickerName.alert,
            title: 'Failed to load video',
            actionLabel: 'Retry',
            onAction: () => actionCount++,
            onClose: () {},
          ),
        ),
      );

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(actionCount, equals(1));
    });

    testWidgets('invokes onClose from the labelled close button', (
      tester,
    ) async {
      var closeCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TvStaticMessageScreen(
            sticker: DivineStickerName.alert,
            title: 'Failed to load video',
            onClose: () => closeCount++,
            closeSemanticLabel: 'Close video player',
          ),
        ),
      );

      await tester.tap(find.bySemanticsLabel('Close video player'));
      await tester.pump();

      expect(closeCount, equals(1));
    });

    testWidgets('renders the footer chrome when supplied', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TvStaticMessageScreen(
            sticker: DivineStickerName.alert,
            title: 'Allow camera access',
            onClose: () {},
            footer: const SizedBox(key: Key('footer'), height: 48),
          ),
        ),
      );

      expect(find.byKey(const Key('footer')), findsOneWidget);
    });

    testWidgets('lets the footer paint to the bottom screen edge', (
      tester,
    ) async {
      // A footer carries its own SafeArea. If this screen also consumed the
      // bottom inset, the footer's background would stop short of the edge
      // and the animated static behind it would show through the gap.
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(padding: EdgeInsets.only(bottom: 48)),
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TvStaticMessageScreen(
              sticker: DivineStickerName.alert,
              title: 'Allow camera access',
              onClose: _noop,
              footer: SizedBox(key: Key('footer'), height: 60),
            ),
          ),
        ),
      );

      final footer = tester.getRect(find.byKey(const Key('footer')));
      final screen = tester.getRect(find.byType(Scaffold));

      expect(footer.bottom, equals(screen.bottom));
    });

    testWidgets('keeps the bottom inset when there is no footer', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(padding: EdgeInsets.only(bottom: 48)),
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TvStaticMessageScreen(
              sticker: DivineStickerName.alert,
              title: 'Video not found',
              onClose: _noop,
            ),
          ),
        ),
      );

      final column = tester.getRect(
        find
            .descendant(
              of: find.byType(SafeArea),
              matching: find.byType(Column),
            )
            .first,
      );
      final screen = tester.getRect(find.byType(Scaffold));

      expect(column.bottom, equals(screen.bottom - 48));
    });

    group('at the largest text size on a small phone', () {
      // The German camera permission error: the language with the longest
      // words, on an iPhone SE at the largest iOS text size.
      const title = 'Berechtigungsfehler';
      const description =
          'Beim Prüfen der Berechtigungen ist etwas schiefgelaufen.';

      Future<void> pumpScreen(WidgetTester tester) {
        tester.view
          ..physicalSize = const Size(375, 667)
          ..devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 3.12;
        addTearDown(() {
          tester.view
            ..resetPhysicalSize()
            ..resetDevicePixelRatio();
          tester.platformDispatcher.clearAllTestValues();
        });
        return tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TvStaticMessageScreen(
              sticker: DivineStickerName.alert,
              title: title,
              description: description,
              onClose: _noop,
            ),
          ),
        );
      }

      testWidgets('keeps every word on one line', (tester) async {
        await pumpScreen(tester);

        _expectWordsWhole(tester, title);
        _expectWordsWhole(tester, description);
      });
    });
  });
}

/// Expects each space-separated word of the rendered [text] on a single line.
void _expectWordsWhole(WidgetTester tester, String text) {
  final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
  var start = 0;
  for (final word in text.split(' ')) {
    final lineTops = paragraph
        .getBoxesForSelection(
          TextSelection(baseOffset: start, extentOffset: start + word.length),
        )
        .map((box) => box.top)
        .toSet();
    expect(lineTops, hasLength(1), reason: '"$word" was split across lines');
    start += word.length + 1;
  }
}

void _noop() {}

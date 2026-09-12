// ABOUTME: Widget tests for the shared TV-static message takeover
// ABOUTME: Covers optional description, optional action, close, and footer

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/tv_static_message_screen.dart';

void main() {
  group(TvStaticMessageScreen, () {
    testWidgets('renders the sticker, title, and description', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
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
  });
}

void _noop() {}

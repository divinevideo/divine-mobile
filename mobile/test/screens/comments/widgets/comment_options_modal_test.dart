// ABOUTME: Pins the comment options sheet's destructive row to a colour that
// ABOUTME: survives the light sheet surface once light mode is on, and its
// ABOUTME: dismissal once the opener has unmounted.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/comments/widgets/comment_options_modal.dart';

void main() {
  group(CommentOptionsModal, () {
    Future<void> openOwnCommentSheet(
      WidgetTester tester,
      ThemeData theme,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => CommentOptionsModal.showForOwnComment(
                  context,
                  commentId: 'c1',
                  commentContent: 'hi',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    /// The Delete row's resolved colour. The row paints its glyph and its
    /// label from one `color`, so the label pins both.
    Color? deleteLabelColor(WidgetTester tester) {
      final l10n = lookupAppLocalizations(const Locale('en'));
      return tester.widget<Text>(find.text(l10n.commonDelete)).style?.color;
    }

    testWidgets('destructive row leaves fixed likeRed behind on light', (
      tester,
    ) async {
      await openOwnCommentSheet(tester, VineTheme.lightTheme);

      // The sheet body is `ColoredBox(color: colors.surface)` = #FFFFFF on
      // light, where fixed `likeRed` holds only 4.13:1. The palette token is
      // #8C1D18 there — 9.11:1.
      final color = deleteLabelColor(tester);
      expect(color, VineTheme.lightColors.onErrorContainer);
      expect(color, isNot(VineTheme.likeRed));
    });

    testWidgets('destructive row tracks the dark error token', (tester) async {
      await openOwnCommentSheet(tester, VineTheme.theme);

      // This pinned `likeRed` byte-for-byte while the constant-to-token
      // migration needed dark to stay pixel-neutral. #7147 retired that
      // invariant by moving `onErrorContainer` onto Figma's `error/error`,
      // so what is worth holding now is that the row follows the token
      // rather than a constant of its own.
      final color = deleteLabelColor(tester);
      expect(color, VineTheme.darkColors.onErrorContainer);
      expect(color, isNot(VineTheme.likeRed));
    });

    // A recycled comment row can unmount while its own options sheet is up.
    // Dismissing through the opener's context at tap time then throws, since
    // a deactivated element can no longer find the router.
    testWidgets('returns the tapped option after its opener unmounts', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      CommentOptionResult? result;
      final openerVisible = ValueNotifier<bool>(true);
      addTearDown(openerVisible.dispose);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: ValueListenableBuilder<bool>(
                valueListenable: openerVisible,
                builder: (_, visible, _) => visible
                    ? _OwnCommentOpener(onResult: (value) => result = value)
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: VineTheme.theme,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      openerVisible.value = false;
      await tester.pumpAndSettle();
      expect(find.text('open'), findsNothing);

      await tester.tap(find.text(l10n.commonDelete));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(result, isA<CommentDeleteResult>());
      expect(find.text(l10n.commonDelete), findsNothing);
    });
  });
}

/// Opens the own-comment sheet from its own [State.context], so unmounting it
/// leaves the sheet open above a defunct opener.
class _OwnCommentOpener extends StatefulWidget {
  const _OwnCommentOpener({required this.onResult});

  final ValueChanged<CommentOptionResult?> onResult;

  @override
  State<_OwnCommentOpener> createState() => _OwnCommentOpenerState();
}

class _OwnCommentOpenerState extends State<_OwnCommentOpener> {
  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () async {
        widget.onResult(
          await CommentOptionsModal.showForOwnComment(
            context,
            commentId: 'c1',
            commentContent: 'hi',
          ),
        );
      },
      child: const Text('open'),
    );
  }
}

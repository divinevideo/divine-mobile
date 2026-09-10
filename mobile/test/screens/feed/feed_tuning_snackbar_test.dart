import 'package:feed_tuning_repository/feed_tuning_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/feed/feed_tuning_snackbar.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  Widget harness({
    required FeedTuningDirection direction,
    VoidCallback? onUndo,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showFeedTuningSnackbar(
                context,
                direction: direction,
                onUndo: onUndo,
              ),
              child: const Text('trigger'),
            ),
          ),
        ),
      ),
    );
  }

  group('showFeedTuningSnackbar', () {
    testWidgets(
      'auto-dismisses the receipt after its timeout even with an Undo action',
      (tester) async {
        await tester.pumpWidget(
          harness(direction: FeedTuningDirection.less, onUndo: () {}),
        );

        await tester.tap(find.text('trigger'));
        await tester.pump();
        // Let the reveal animation finish so the auto-dismiss timer starts.
        await tester.pump(const Duration(seconds: 1));

        // The Undo action is the case that used to pin the receipt on screen
        // forever: a Material SnackBarAction defaults SnackBar.persist to true,
        // which suppresses the timer. The design-system container keeps persist
        // false, so the timer still fires with the action present.
        expect(find.text(l10n.feedTuningLessLabel), findsOneWidget);
        expect(find.text(l10n.feedTuningUndo), findsOneWidget);

        await tester.pump(const Duration(seconds: 4)); // auto-dismiss window
        await tester.pump(const Duration(seconds: 1)); // exit animation

        expect(find.text(l10n.feedTuningLessLabel), findsNothing);
        expect(find.text(l10n.feedTuningUndo), findsNothing);
      },
    );

    testWidgets('dismisses the receipt and fires the callback on Undo tap', (
      tester,
    ) async {
      var undoCount = 0;
      await tester.pumpWidget(
        harness(direction: FeedTuningDirection.less, onUndo: () => undoCount++),
      );

      await tester.tap(find.text('trigger'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text(l10n.feedTuningUndo));
      await tester.pump();

      // The receipt is removed immediately, so Undo cannot fire twice and the
      // snackbar does not linger for the rest of its 4s window.
      expect(undoCount, equals(1));
      expect(find.text(l10n.feedTuningLessLabel), findsNothing);
      expect(find.text(l10n.feedTuningUndo), findsNothing);
    });

    testWidgets('omits the Undo action when no callback is given', (
      tester,
    ) async {
      await tester.pumpWidget(harness(direction: FeedTuningDirection.more));

      await tester.tap(find.text('trigger'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text(l10n.feedTuningMoreLabel), findsOneWidget);
      expect(find.text(l10n.feedTuningUndo), findsNothing);
    });
  });
}

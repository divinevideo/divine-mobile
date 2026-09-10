// ABOUTME: Tests the blocking progress overlay's modality and lifetime contract
// ABOUTME: dismiss() must be safe twice and after the host tree is gone

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/modal_progress_overlay.dart';

const _behindLabel = 'behind the spinner';

void main() {
  group(ModalProgressOverlay, () {
    late BuildContext hostContext;
    var taps = 0;

    setUp(() => taps = 0);

    Future<void> pumpHost(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              hostContext = context;
              return TextButton(
                onPressed: () => taps++,
                child: const Text(_behindLabel),
              );
            },
          ),
        ),
      );
    }

    testWidgets('shows a spinner and removes it on dismiss', (tester) async {
      await pumpHost(tester);

      final overlay = ModalProgressOverlay.show(hostContext);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      overlay.dismiss();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    // The opaque scrim stops pointers, but a screen reader activates a
    // control by node id without hit-testing — so the screen underneath has
    // to leave the semantics tree too, or the spinner is not actually modal
    // and a second activation starts a second deletion flow.
    testWidgets('takes the screen underneath out of the semantics tree', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();

      await pumpHost(tester);
      tester.semantics.tap(find.semantics.byLabel(_behindLabel));
      await tester.pump();
      expect(taps, 1);

      final overlay = ModalProgressOverlay.show(hostContext);
      await tester.pump();

      expect(find.semantics.byLabel(_behindLabel), findsNothing);
      final en = lookupAppLocalizations(const Locale('en'));
      expect(find.semantics.byLabel(en.commonLoading), findsOneWidget);

      overlay.dismiss();
      await tester.pump();
      tester.semantics.tap(find.semantics.byLabel(_behindLabel));
      await tester.pump();
      expect(taps, 2);

      semantics.dispose();
    });

    // The overlay outlives the screen that opened it — a back press during
    // the await pops that screen — so the `finally { dismiss() }` on every
    // call site lands after the host is gone.
    testWidgets('dismiss after the host tree is torn down does not throw', (
      tester,
    ) async {
      await pumpHost(tester);

      final overlay = ModalProgressOverlay.show(hostContext);
      await tester.pump();

      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      overlay.dismiss();
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    // The delete flow dismisses in a `finally` and again on the success path.
    testWidgets('dismiss is idempotent', (tester) async {
      await pumpHost(tester);

      final overlay = ModalProgressOverlay.show(hostContext);
      await tester.pump();

      overlay
        ..dismiss()
        ..dismiss();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

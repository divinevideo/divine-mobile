// ABOUTME: Widget tests for VideoEditorToolbar.
// ABOUTME: Verifies close/done actions and center content rendering.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_editor/video_editor_toolbar.dart';

import '../../helpers/accessibility_guidelines.dart';

void main() {
  group(VideoEditorToolbar, () {
    Widget buildWidget({
      required VoidCallback onClose,
      VoidCallback? onDone,
      Widget? center,
      ThemeData? theme,
    }) {
      return MaterialApp(
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: VideoEditorToolbar(
            onClose: onClose,
            onDone: onDone,
            closeSemanticLabel: 'Close test editor',
            doneSemanticLabel: 'Apply test changes',
            center: center,
          ),
        ),
      );
    }

    testWidgets('renders close and done semantics', (tester) async {
      await tester.pumpWidget(buildWidget(onClose: () {}, onDone: () {}));

      expect(find.bySemanticsLabel('Close test editor'), findsOneWidget);
      expect(find.bySemanticsLabel('Apply test changes'), findsOneWidget);
    });

    testWidgets('calls onClose when close button is tapped', (tester) async {
      var closeTapped = false;

      await tester.pumpWidget(
        buildWidget(onClose: () => closeTapped = true, onDone: () {}),
      );

      await tester.tap(find.bySemanticsLabel('Close test editor'));
      await tester.pump();

      expect(closeTapped, isTrue);
    });

    testWidgets('calls onDone when done button is tapped', (tester) async {
      var doneTapped = false;

      await tester.pumpWidget(
        buildWidget(onClose: () {}, onDone: () => doneTapped = true),
      );

      await tester.tap(find.bySemanticsLabel('Apply test changes'));
      await tester.pump();

      expect(doneTapped, isTrue);
    });

    testWidgets('renders center widget when provided', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          onClose: () {},
          onDone: () {},
          center: const Text('Center Content'),
        ),
      );

      expect(find.text('Center Content'), findsOneWidget);
    });

    group('accessibility', () {
      testWidgets('meets the guidelines in both appearances', (tester) async {
        await expectMeetsAccessibilityGuidelinesInBothAppearances(
          tester,
          (theme) => buildWidget(
            onClose: () {},
            onDone: () {},
            center: const Text('Trim'),
            theme: theme,
          ),
        );
      });
    });
  });
}

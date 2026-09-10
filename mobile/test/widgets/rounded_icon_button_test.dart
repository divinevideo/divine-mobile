// ABOUTME: Tests for RoundedIconButton widget
// ABOUTME: Verifies icon rendering, tap callback, null onPressed, and semantics

import 'dart:ui' show Tristate;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/rounded_icon_button.dart';

void main() {
  group(RoundedIconButton, () {
    Widget createTestWidget({
      VoidCallback? onPressed,
      Widget icon = const Icon(Icons.chevron_left),
      String semanticLabel = 'Back',
      String? semanticIdentifier,
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: Scaffold(
          body: RoundedIconButton(
            onPressed: onPressed,
            icon: icon,
            semanticLabel: semanticLabel,
            semanticIdentifier: semanticIdentifier,
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('displays the icon', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            onPressed: () {},
            icon: const Icon(Icons.info_outline),
          ),
        );

        expect(find.byIcon(Icons.info_outline), findsOneWidget);
      });

      testWidgets('renders $GestureDetector', (tester) async {
        await tester.pumpWidget(createTestWidget(onPressed: () {}));

        expect(find.byType(GestureDetector), findsOneWidget);
      });

      testWidgets('renders a 48x48 container', (tester) async {
        await tester.pumpWidget(createTestWidget(onPressed: () {}));

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.constraints?.maxWidth, equals(48));
        expect(container.constraints?.maxHeight, equals(48));
      });
    });

    group('interactions', () {
      testWidgets('calls onPressed when tapped', (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          createTestWidget(onPressed: () => tapped = true),
        );

        await tester.tap(find.byType(GestureDetector));
        expect(tapped, isTrue);
      });

      testWidgets('does not throw when onPressed is null', (tester) async {
        await tester.pumpWidget(createTestWidget());

        // Should not throw when tapped with null onPressed
        await tester.tap(find.byType(GestureDetector));
        await tester.pump();
      });
    });

    group('accessibility', () {
      // The button was a bare GestureDetector for its whole life, so every
      // auth-screen control it powers announced nothing at all. Observed on
      // device before the fix: the back control appeared in the semantics
      // tree as `actions: tap, flags: isImage` with no label.
      testWidgets('announces its label as a button', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          createTestWidget(onPressed: () {}, semanticLabel: 'Atrás'),
        );

        final node = tester.getSemantics(find.byType(RoundedIconButton));
        expect(node.label, equals('Atrás'));
        expect(node.flagsCollection.isButton, isTrue);
        expect(node.flagsCollection.isEnabled, Tristate.isTrue);
        handle.dispose();
      });

      testWidgets('exposes the identifier as a test anchor', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          createTestWidget(
            onPressed: () {},
            semanticIdentifier: 'back_button',
          ),
        );

        expect(find.bySemanticsIdentifier('back_button'), findsOneWidget);
        handle.dispose();
      });

      testWidgets('offers no tap action when onPressed is null', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(createTestWidget());

        final node = tester.getSemantics(find.byType(RoundedIconButton));
        expect(
          node.getSemanticsData().hasAction(SemanticsAction.tap),
          isFalse,
        );
        expect(node.flagsCollection.isEnabled, Tristate.isFalse);
        handle.dispose();
      });
    });
  });
}

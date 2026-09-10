import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/accessibility_guidelines.dart';

void main() {
  group(DivineSwitch, () {
    Widget buildTestWidget({
      required bool value,
      ValueChanged<bool>? onChanged,
      String? semanticLabel,
    }) {
      return MaterialApp(
        theme: VineTheme.theme,
        home: Scaffold(
          body: Center(
            child: DivineSwitch(
              value: value,
              onChanged: onChanged,
              semanticLabel: semanticLabel,
            ),
          ),
        ),
      );
    }

    testWidgets('reports the new value when toggled on', (tester) async {
      bool? received;
      await tester.pumpWidget(
        buildTestWidget(value: false, onChanged: (v) => received = v),
      );

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(received, isTrue);
    });

    testWidgets('reports the new value when toggled off', (tester) async {
      bool? received;
      await tester.pumpWidget(
        buildTestWidget(value: true, onChanged: (v) => received = v),
      );

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(received, isFalse);
    });

    testWidgets('is not interactive when onChanged is null', (tester) async {
      await tester.pumpWidget(buildTestWidget(value: false));

      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    });

    testWidgets('paints the brand palette when on', (tester) async {
      await tester.pumpWidget(buildTestWidget(value: true, onChanged: (_) {}));

      final toggle = tester.widget<Switch>(find.byType(Switch));
      expect(toggle.activeTrackColor, equals(VineTheme.primary));
      expect(toggle.activeThumbColor, equals(VineTheme.onPrimary));
    });

    testWidgets('exposes the semantic label when given one', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          value: false,
          onChanged: (_) {},
          semanticLabel: 'Autoplay',
        ),
      );

      expect(
        tester.getSemantics(find.byType(Switch)).label,
        contains('Autoplay'),
      );
    });

    testWidgets('adds no semantics node without a label', (tester) async {
      await tester.pumpWidget(buildTestWidget(value: false));

      expect(tester.getSemantics(find.byType(Switch)).label, isEmpty);
    });
  });

  group(DivineSwitchTile, () {
    Widget buildTestWidget({
      required bool value,
      ValueChanged<bool>? onChanged,
      String? subtitle,
      DivineIconName? leadingIcon,
      Widget? leading,
      ThemeData? theme,
    }) {
      return MaterialApp(
        theme: theme ?? VineTheme.theme,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: DivineSwitchTile(
                title: 'Autoplay',
                subtitle: subtitle,
                leadingIcon: leadingIcon,
                leading: leading,
                value: value,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      );
    }

    setUp(() => VineThemeColors.debugFallbackCount = 0);
    tearDown(() => VineThemeColors.debugFallbackCount = 0);

    testWidgets('renders the title', (tester) async {
      await tester.pumpWidget(buildTestWidget(value: false, onChanged: (_) {}));

      expect(find.text('Autoplay'), findsOneWidget);
    });

    testWidgets('renders the subtitle when given one', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          value: false,
          onChanged: (_) {},
          subtitle: 'Plays the next video automatically',
        ),
      );

      expect(find.text('Plays the next video automatically'), findsOneWidget);
    });

    testWidgets('omits the subtitle when absent', (tester) async {
      await tester.pumpWidget(buildTestWidget(value: false, onChanged: (_) {}));

      expect(tester.widget<ListTile>(find.byType(ListTile)).subtitle, isNull);
    });

    testWidgets('renders the leading icon when given one', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          value: false,
          onChanged: (_) {},
          leadingIcon: DivineIconName.gear,
        ),
      );

      expect(find.byType(DivineIcon), findsOneWidget);
    });

    testWidgets('uses light accentPositive for the leading icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          value: false,
          onChanged: (_) {},
          leadingIcon: DivineIconName.gear,
          theme: VineTheme.lightTheme,
        ),
      );

      final icon = tester.widget<DivineIcon>(find.byType(DivineIcon));
      expect(icon.color, VineTheme.lightColors.accentPositive);
      expect(
        icon.color,
        isNot(VineTheme.primary),
        reason: 'light mode must not fall back to the dark brand green',
      );
      expect(VineThemeColors.debugFallbackCount, 0);
    });

    testWidgets('uses dark accentPositive for the leading icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          value: false,
          onChanged: (_) {},
          leadingIcon: DivineIconName.gear,
          theme: VineTheme.theme,
        ),
      );

      final icon = tester.widget<DivineIcon>(find.byType(DivineIcon));
      expect(icon.color, VineTheme.darkColors.accentPositive);
      expect(VineThemeColors.debugFallbackCount, 0);
    });

    testWidgets('omits the leading icon when absent', (tester) async {
      await tester.pumpWidget(buildTestWidget(value: false, onChanged: (_) {}));

      expect(find.byType(DivineIcon), findsNothing);
    });

    testWidgets('renders a custom leading widget when given one', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          value: false,
          onChanged: (_) {},
          leading: const CircleAvatar(child: Text('AF')),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(ListTile),
          matching: find.byType(CircleAvatar),
        ),
        findsOneWidget,
      );
    });

    test('rejects a leading icon and a leading widget together', () {
      expect(
        () => DivineSwitchTile(
          title: 'Autoplay',
          leadingIcon: DivineIconName.gear,
          leading: const SizedBox.shrink(),
          value: false,
          onChanged: (_) {},
        ),
        throwsAssertionError,
      );
    });

    testWidgets('toggles when the row is tapped', (tester) async {
      bool? received;
      await tester.pumpWidget(
        buildTestWidget(value: false, onChanged: (v) => received = v),
      );

      await tester.tap(find.text('Autoplay'));
      await tester.pumpAndSettle();

      expect(received, isTrue);
    });

    testWidgets('toggles back off when already on', (tester) async {
      bool? received;
      await tester.pumpWidget(
        buildTestWidget(value: true, onChanged: (v) => received = v),
      );

      await tester.tap(find.text('Autoplay'));
      await tester.pumpAndSettle();

      expect(received, isFalse);
    });

    testWidgets('is disabled when onChanged is null', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          value: false,
          subtitle: 'Locked',
          leadingIcon: DivineIconName.gear,
        ),
      );

      final tile = tester.widget<ListTile>(find.byType(ListTile));
      expect(tile.enabled, isFalse);
      expect(tile.onTap, isNull);
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    });

    testWidgets('dims the whole row when disabled', (tester) async {
      await tester.pumpWidget(buildTestWidget(value: false, subtitle: 'Off'));

      expect(
        tester.widget<Opacity>(find.byType(Opacity).first).opacity,
        DivineSwitchTile.disabledOpacity,
      );
    });

    testWidgets('keeps full opacity when enabled', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(value: false, subtitle: 'On', onChanged: (_) {}),
      );

      expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, 1.0);
    });

    // A row gated on an async provider is built disabled on its first frame
    // and flips to enabled once the provider resolves. Recolouring the text
    // across that flip used to hand _RenderListTile a fresh TextPainter for a
    // subtitle that had already been laid out, tripping `debugSize == size`.
    // Assert the styles themselves are unchanged: the assertion only fires
    // when the rebuilt paragraph measures differently, which the test font
    // never does, so `takeException()` cannot catch a regression here.
    testWidgets('keeps its text styles across a disabled → enabled flip', (
      tester,
    ) async {
      const longSubtitle =
          'Include a Divine client tag on events you publish so other Nostr '
          'apps can attribute them correctly.';

      TextStyle styleOf(String data) =>
          tester.widget<Text>(find.text(data)).style!;

      await tester.pumpWidget(
        buildTestWidget(value: true, subtitle: longSubtitle),
      );
      await tester.pump();
      final disabledTitle = styleOf('Autoplay');
      final disabledSubtitle = styleOf(longSubtitle);

      await tester.pumpWidget(
        buildTestWidget(value: true, subtitle: longSubtitle, onChanged: (_) {}),
      );
      await tester.pumpAndSettle();

      expect(styleOf('Autoplay'), equals(disabledTitle));
      expect(styleOf(longSubtitle), equals(disabledSubtitle));
      expect(tester.takeException(), isNull);
    });

    group('accessibility', () {
      testWidgets('meets the accessibility guidelines', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            value: true,
            subtitle: 'Play the next video automatically',
            onChanged: (_) {},
          ),
        );

        await expectMeetsAccessibilityGuidelines(tester);
      });
    });
  });
}

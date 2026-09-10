import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/accessibility_guidelines.dart';

void main() {
  group(DivineListTile, () {
    Widget buildSubject({
      String? subtitle,
      DivineIconName? icon,
      Widget? leading,
      Color? iconColor,
      Color? titleColor,
      DivineIconName trailingIcon = DivineIconName.caretRight,
      double trailingIconSize = 24,
      VoidCallback? onTap,
      String? semanticIdentifier,
    }) {
      return MaterialApp(
        theme: VineTheme.theme,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: DivineListTile(
                title: 'Notifications',
                subtitle: subtitle,
                icon: icon,
                leading: leading,
                iconColor: iconColor,
                titleColor: titleColor,
                trailingIcon: trailingIcon,
                trailingIconSize: trailingIconSize,
                semanticIdentifier: semanticIdentifier,
                onTap: onTap ?? () {},
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('exposes semanticIdentifier without hiding the row copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          subtitle: 'Pings and mentions',
          semanticIdentifier: 'notifications_tile',
        ),
      );

      expect(find.bySemanticsIdentifier('notifications_tile'), findsOneWidget);
      // The wrapper must not swallow the ListTile's own semantics.
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Pings and mentions'), findsOneWidget);
    });

    testWidgets('adds no semantics wrapper when no identifier is given', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      expect(find.bySemanticsIdentifier('notifications_tile'), findsNothing);
    });

    testWidgets('renders the title', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('Notifications'), findsOneWidget);
    });

    testWidgets('renders the subtitle when given one', (tester) async {
      await tester.pumpWidget(buildSubject(subtitle: 'Pings and mentions'));

      expect(find.text('Pings and mentions'), findsOneWidget);
    });

    testWidgets('omits the subtitle when absent', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(tester.widget<ListTile>(find.byType(ListTile)).subtitle, isNull);
    });

    testWidgets('renders a design-system leading icon', (tester) async {
      await tester.pumpWidget(buildSubject(icon: DivineIconName.bellSimple));

      final leading =
          tester.widget<ListTile>(find.byType(ListTile)).leading! as DivineIcon;
      expect(leading.icon, DivineIconName.bellSimple);
    });

    testWidgets('applies the icon colour override', (tester) async {
      await tester.pumpWidget(
        buildSubject(icon: DivineIconName.trash, iconColor: VineTheme.error),
      );

      final leading =
          tester.widget<ListTile>(find.byType(ListTile)).leading! as DivineIcon;
      expect(leading.color, VineTheme.error);
    });

    testWidgets('renders an arbitrary leading widget', (tester) async {
      await tester.pumpWidget(buildSubject(leading: const Icon(Icons.gavel)));

      expect(find.byIcon(Icons.gavel), findsOneWidget);
    });

    testWidgets('has no leading slot without icon or leading', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(tester.widget<ListTile>(find.byType(ListTile)).leading, isNull);
    });

    testWidgets('applies the title colour override', (tester) async {
      await tester.pumpWidget(buildSubject(titleColor: VineTheme.error));

      expect(
        tester.widget<Text>(find.text('Notifications')).style?.color,
        VineTheme.error,
      );
    });

    testWidgets('defaults to a forward caret', (tester) async {
      await tester.pumpWidget(buildSubject());

      final trailing =
          tester.widget<ListTile>(find.byType(ListTile)).trailing!
              as DivineIcon;
      expect(trailing.icon, DivineIconName.caretRight);
      expect(trailing.size, 24);
    });

    testWidgets('takes a custom trailing affordance', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          trailingIcon: DivineIconName.arrowUpRight,
          trailingIconSize: 20,
        ),
      );

      final trailing =
          tester.widget<ListTile>(find.byType(ListTile)).trailing!
              as DivineIcon;
      expect(trailing.icon, DivineIconName.arrowUpRight);
      expect(trailing.size, 20);
    });

    testWidgets('drops the trailing affordance when asked to', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: DivineListTile(
                  title: 'Take photo',
                  trailingIcon: null,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.widget<ListTile>(find.byType(ListTile)).trailing, isNull);
    });

    testWidgets('reports taps', (tester) async {
      var tapped = false;
      await tester.pumpWidget(buildSubject(onTap: () => tapped = true));

      await tester.tap(find.byType(DivineListTile));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('keeps a tap-target-sized row', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(
        tester.getSize(find.byType(ListTile)).height,
        greaterThanOrEqualTo(DivineListTile.minHeight),
      );
    });

    group('accessibility', () {
      testWidgets('meets the accessibility guidelines', (tester) async {
        await tester.pumpWidget(buildSubject(subtitle: 'Push and email'));

        await expectMeetsAccessibilityGuidelines(tester);
      });
    });
  });

  group(DivineSectionHeader, () {
    testWidgets('shouts a sentence-case label', (tester) async {
      // Built from a runtime value on purpose: a const-evaluated widget never
      // executes its constructor, which leaves it uncovered.
      final label = 'Danger Zone'.substring(0);
      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          home: Scaffold(body: DivineSectionHeader(label)),
        ),
      );

      expect(find.text('DANGER ZONE'), findsOneWidget);
      expect(find.text('Danger Zone'), findsNothing);
    });

    testWidgets('leaves an already-uppercased label alone', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          home: const Scaffold(body: DivineSectionHeader('NETWORK')),
        ),
      );

      expect(find.text('NETWORK'), findsOneWidget);
    });

    testWidgets('uses the brand accent and tracked-out label style', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          home: const Scaffold(body: DivineSectionHeader('NETWORK')),
        ),
      );

      final style = tester.widget<Text>(find.text('NETWORK')).style!;
      expect(style.color, VineTheme.vineGreen);
      expect(style.letterSpacing, 1.2);
    });

    testWidgets('drops the brand accent in light mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.lightTheme,
          home: const Scaffold(body: DivineSectionHeader('NETWORK')),
        ),
      );

      // vineGreen is ~2.1:1 on the light background — far too low for a 12sp
      // label, so light mode uses the neutral instead.
      final style = tester.widget<Text>(find.text('NETWORK')).style!;
      expect(style.color, isNot(VineTheme.vineGreen));
      expect(style.color, VineTheme.lightColors.onSurface);
    });

    testWidgets('defaults to the canonical spacing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          home: const Scaffold(body: DivineSectionHeader('NETWORK')),
        ),
      );

      expect(
        tester.widget<Padding>(find.byType(Padding).first).padding,
        DivineSectionHeader.defaultPadding,
      );
    });

    testWidgets('takes a padding override', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          home: const Scaffold(
            body: DivineSectionHeader(
              'NETWORK',
              padding: EdgeInsets.only(bottom: 8),
            ),
          ),
        ),
      );

      expect(
        tester.widget<Padding>(find.byType(Padding).first).padding,
        const EdgeInsets.only(bottom: 8),
      );
    });
  });
}

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group(DivineInfoCard, () {
    Widget buildSubject({
      String? title,
      DivineIconName icon = DivineIconName.info,
      DivineInfoCardTone tone = DivineInfoCardTone.info,
      bool compact = false,
      Widget? footer,
      ThemeData? theme,
    }) {
      return MaterialApp(
        theme: theme ?? VineTheme.theme,
        home: Scaffold(
          body: DivineInfoCard(
            message: 'Your keys are your account.',
            title: title,
            icon: icon,
            tone: tone,
            compact: compact,
            footer: footer,
          ),
        ),
      );
    }

    BoxDecoration decorationOf(WidgetTester tester) =>
        tester
                .widget<DecoratedBox>(
                  find.descendant(
                    of: find.byType(DivineInfoCard),
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .decoration
            as BoxDecoration;

    DivineIcon iconOf(WidgetTester tester) => tester.widget<DivineIcon>(
      find.descendant(
        of: find.byType(DivineInfoCard),
        matching: find.byType(DivineIcon),
      ),
    );

    TextStyle styleOf(WidgetTester tester, String text) =>
        tester.widget<Text>(find.text(text)).style!;

    testWidgets('renders the message', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('Your keys are your account.'), findsOneWidget);
    });

    testWidgets('renders the title when given one', (tester) async {
      await tester.pumpWidget(buildSubject(title: 'What are Nostr keys?'));

      expect(find.text('What are Nostr keys?'), findsOneWidget);
    });

    testWidgets('omits the title when absent', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('renders the info glyph by default', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(iconOf(tester).icon, DivineIconName.info);
    });

    testWidgets('renders the given glyph', (tester) async {
      await tester.pumpWidget(buildSubject(icon: DivineIconName.shieldCheck));

      expect(iconOf(tester).icon, DivineIconName.shieldCheck);
    });

    testWidgets('renders the footer when given one', (tester) async {
      await tester.pumpWidget(
        buildSubject(footer: const Text('Copy my private key')),
      );

      expect(find.text('Copy my private key'), findsOneWidget);
    });

    group('without a glyph', () {
      testWidgets('renders title and message alone', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: DivineInfoCard(
                icon: null,
                title: 'Support links',
                message: 'Add the places people can support you from.',
              ),
            ),
          ),
        );

        expect(find.byType(DivineIcon), findsNothing);
        expect(find.text('Support links'), findsOneWidget);
        expect(
          find.text('Add the places people can support you from.'),
          findsOneWidget,
        );
      });

      testWidgets('renders a message-only card', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: DivineInfoCard(icon: null, message: 'Nothing set up yet.'),
            ),
          ),
        );

        expect(find.byType(DivineIcon), findsNothing);
        expect(find.text('Nothing set up yet.'), findsOneWidget);
      });
    });

    group('glyph alignment', () {
      const wrapping =
          'Your keys are your account, and nobody at Divine can reset them '
          'for you if you lose them.';

      Widget buildNarrow({required String message, String? title}) =>
          MaterialApp(
            theme: VineTheme.theme,
            home: Scaffold(
              body: SizedBox(
                width: 200,
                child: DivineInfoCard(title: title, message: message),
              ),
            ),
          );

      testWidgets('centres the glyph on a single-line message', (tester) async {
        await tester.pumpWidget(buildSubject());

        expect(
          tester.getCenter(find.byType(DivineIcon)).dy,
          moreOrLessEquals(
            tester.getCenter(find.text('Your keys are your account.')).dy,
            epsilon: 0.01,
          ),
        );
      });

      testWidgets('keeps the glyph on the first line when the message wraps', (
        tester,
      ) async {
        await tester.pumpWidget(buildNarrow(message: wrapping));

        final text = find.text(wrapping);
        expect(tester.getSize(text).height, greaterThan(20));
        expect(
          tester.getCenter(find.byType(DivineIcon)).dy,
          moreOrLessEquals(
            // bodyMedium is 14/20, so the first line's centre is 10 down.
            tester.getTopLeft(text).dy + 10,
            epsilon: 0.01,
          ),
        );
      });

      testWidgets('keeps the glyph on the first line when the title wraps', (
        tester,
      ) async {
        const title = 'What are Nostr keys and why do they matter to you?';
        await tester.pumpWidget(buildNarrow(title: title, message: 'Short.'));

        final heading = find.text(title);
        expect(tester.getSize(heading).height, greaterThan(20));
        expect(
          tester.getCenter(find.byType(DivineIcon)).dy,
          moreOrLessEquals(
            // titleSmall is 14/20, same first-line centre as the body.
            tester.getTopLeft(heading).dy + 10,
            epsilon: 0.01,
          ),
        );
      });
    });

    group('tone', () {
      testWidgets('info follows accentPositive in both appearances', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject(title: 'Heading'));
        await tester.pumpAndSettle();

        final decoration = decorationOf(tester);
        final darkAccent = VineTheme.darkColors.accentPositive;
        expect(
          decoration.color,
          darkAccent.withValues(alpha: DivineInfoCard.surfaceOpacity),
        );
        expect(
          (decoration.border! as Border).top.color,
          darkAccent.withValues(alpha: DivineInfoCard.borderOpacity),
        );
        expect(iconOf(tester).color, darkAccent);
        expect(styleOf(tester, 'Heading').color, darkAccent);

        await tester.pumpWidget(
          buildSubject(title: 'Heading', theme: VineTheme.lightTheme),
        );
        await tester.pumpAndSettle();

        final lightDecoration = decorationOf(tester);
        final lightAccent = VineTheme.lightColors.accentPositive;
        expect(
          lightDecoration.color,
          lightAccent.withValues(alpha: DivineInfoCard.surfaceOpacity),
        );
        expect(
          (lightDecoration.border! as Border).top.color,
          lightAccent.withValues(alpha: DivineInfoCard.borderOpacity),
        );
        expect(iconOf(tester).color, lightAccent);
        expect(styleOf(tester, 'Heading').color, lightAccent);
        expect(
          lightAccent,
          isNot(VineTheme.vineGreen),
          reason: 'light mode must use accentPositive, not raw brand green',
        );
      });

      testWidgets('warning tints with the warning colour', (tester) async {
        await tester.pumpWidget(buildSubject(tone: DivineInfoCardTone.warning));

        expect(
          decorationOf(tester).color,
          VineTheme.warning.withValues(alpha: DivineInfoCard.surfaceOpacity),
        );
        expect(iconOf(tester).color, VineTheme.warning);
      });

      testWidgets('error tints with the error colour', (tester) async {
        await tester.pumpWidget(buildSubject(tone: DivineInfoCardTone.error));

        expect(
          decorationOf(tester).color,
          VineTheme.error.withValues(alpha: DivineInfoCard.surfaceOpacity),
        );
        expect(iconOf(tester).color, VineTheme.error);
      });

      testWidgets('neutral sits on the card surface with a muted outline', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(title: 'Heading', tone: DivineInfoCardTone.neutral),
        );
        await tester.pumpAndSettle();

        final decoration = decorationOf(tester);
        expect(decoration.color, VineTheme.darkColors.card);
        expect(
          (decoration.border! as Border).top.color,
          VineTheme.darkColors.outlineMuted,
        );
        expect(iconOf(tester).color, VineTheme.darkColors.secondaryText);
        expect(
          styleOf(tester, 'Heading').color,
          VineTheme.darkColors.primaryText,
        );

        await tester.pumpWidget(
          buildSubject(
            title: 'Heading',
            tone: DivineInfoCardTone.neutral,
            theme: VineTheme.lightTheme,
          ),
        );
        await tester.pumpAndSettle();

        final lightDecoration = decorationOf(tester);
        expect(lightDecoration.color, VineTheme.lightColors.card);
        expect(
          (lightDecoration.border! as Border).top.color,
          VineTheme.lightColors.outlineMuted,
        );
        expect(iconOf(tester).color, VineTheme.lightColors.secondaryText);
        expect(
          styleOf(tester, 'Heading').color,
          VineTheme.lightColors.primaryText,
        );
      });
    });

    group('compact', () {
      testWidgets('uses the section-level metrics by default', (tester) async {
        await tester.pumpWidget(buildSubject(title: 'Heading'));

        expect(decorationOf(tester).borderRadius, BorderRadius.circular(12));
        expect(iconOf(tester).size, 24);
        expect(
          tester
              .widget<Padding>(
                find
                    .descendant(
                      of: find.byType(DivineInfoCard),
                      matching: find.byType(Padding),
                    )
                    .first,
              )
              .padding,
          const EdgeInsets.all(16),
        );
        expect(
          styleOf(tester, 'Heading').fontSize,
          VineTheme.titleSmallFont().fontSize,
        );
        expect(
          styleOf(tester, 'Your keys are your account.').fontSize,
          VineTheme.bodyMediumFont().fontSize,
        );
      });

      testWidgets('tightens every metric by one step', (tester) async {
        await tester.pumpWidget(buildSubject(title: 'Heading', compact: true));

        expect(decorationOf(tester).borderRadius, BorderRadius.circular(8));
        expect(iconOf(tester).size, 20);
        expect(
          tester
              .widget<Padding>(
                find
                    .descendant(
                      of: find.byType(DivineInfoCard),
                      matching: find.byType(Padding),
                    )
                    .first,
              )
              .padding,
          const EdgeInsets.all(12),
        );
        expect(
          styleOf(tester, 'Heading').fontSize,
          VineTheme.labelLargeFont().fontSize,
        );
        expect(
          styleOf(tester, 'Your keys are your account.').fontSize,
          VineTheme.bodySmallFont().fontSize,
        );
      });
    });
  });
}

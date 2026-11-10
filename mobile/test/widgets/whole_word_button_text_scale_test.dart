// ABOUTME: Tests that a stretched button's text stops growing before the
// ABOUTME: widest word of its label would be split across lines.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/whole_word_button_text_scale.dart';

import '../helpers/text_lines.dart';

void main() {
  group(WholeWordButtonTextScale, () {
    const label = 'Zurücksetzen';

    Future<void> pump(
      WidgetTester tester, {
      required double textScale,
      required Widget child,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: Scaffold(body: Center(child: child)),
          ),
        ),
      );
    }

    Widget button() => DivineButton(
      label: label,
      size: .small,
      expanded: true,
      maxLines: 3,
      onPressed: () {},
    );

    double labelTextScale(WidgetTester tester) =>
        MediaQuery.textScalerOf(tester.element(find.text(label))).scale(16) /
        16;

    testWidgets('follows the system text size while the widest word fits', (
      tester,
    ) async {
      await pump(
        tester,
        textScale: 1.2,
        child: SizedBox(
          width: 200,
          child: WholeWordButtonTextScale(label: label, child: button()),
        ),
      );

      expect(labelTextScale(tester), 1.2);
    });

    testWidgets('stops growing before the widest word would split, measured '
        'across the width the button is given', (tester) async {
      await pump(
        tester,
        textScale: 3.12,
        child: SizedBox(
          width: 200,
          child: WholeWordButtonTextScale(label: label, child: button()),
        ),
      );

      expect(labelTextScale(tester), lessThan(3.12));
      expect(labelTextScale(tester), greaterThan(1));
      expect(wordsSplitAcrossLines(tester, find.text(label)), isEmpty);
    });

    testWidgets('measures across an explicit width where its parent sizes '
        'by intrinsics', (tester) async {
      // A layout builder cannot answer intrinsic sizes, so the width is
      // handed in instead.
      await pump(
        tester,
        textScale: 3.12,
        child: IntrinsicWidth(
          child: SizedBox(
            width: 200,
            child: WholeWordButtonTextScale(
              label: label,
              width: 200,
              child: button(),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(labelTextScale(tester), lessThan(3.12));
      expect(wordsSplitAcrossLines(tester, find.text(label)), isEmpty);
    });

    testWidgets('leaves room for a leading icon', (tester) async {
      await pump(
        tester,
        textScale: 3.12,
        child: SizedBox(
          width: 200,
          child: WholeWordButtonTextScale(
            label: label,
            hasLeadingIcon: true,
            child: DivineButton(
              label: label,
              leadingIcon: .arrowsCounterClockwise,
              size: .small,
              expanded: true,
              maxLines: 3,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(wordsSplitAcrossLines(tester, find.text(label)), isEmpty);
    });

    testWidgets('never shrinks the text below the normal size', (
      tester,
    ) async {
      await pump(
        tester,
        textScale: 2,
        child: SizedBox(
          width: 60,
          child: WholeWordButtonTextScale(label: label, child: button()),
        ),
      );

      expect(labelTextScale(tester), 1);
    });
  });
}

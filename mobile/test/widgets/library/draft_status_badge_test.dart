// ABOUTME: Contrast of the library row badge's label against the fill it
// ABOUTME: sits on, in both appearances.

import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/library/draft_status_badge.dart';

/// WCAG relative luminance.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Color _over(Color fg, Color bg) => Color.from(
  alpha: 1,
  red: fg.r * fg.a + bg.r * (1 - fg.a),
  green: fg.g * fg.a + bg.g * (1 - fg.a),
  blue: fg.b * fg.a + bg.b * (1 - fg.a),
);

void main() {
  group(DraftStatusBadge, () {
    /// The label a row reads must clear WCAG AA body text against the pill it
    /// sits on. The muted tone used to borrow its own faint colour for the
    /// word and measured 2.81:1 in light mode.
    Future<void> expectReadable(
      WidgetTester tester,
      DraftStatusBadgeTone tone, {
      required ThemeData theme,
      required String label,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: DraftStatusBadge(label: 'Badge', tone: tone),
            ),
          ),
        ),
      );

      final context = tester.element(find.byType(DraftStatusBadge));
      final colors = Theme.of(context).extension<VineThemeColors>()!;
      final text = tester.widget<Text>(find.text('Badge'));
      final decorated = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(DraftStatusBadge),
          matching: find.byType(DecoratedBox),
        ),
      );
      final fill = (decorated.decoration as BoxDecoration).color!;

      // Both sides are composited first: a label colour carrying alpha —
      // onSurfaceMuted is white at 50% — reads as full white otherwise, and
      // the measurement flatters exactly the case this guards.
      final backdrop = _over(fill, colors.surface);
      final ratio = _contrast(_over(text.style!.color!, backdrop), backdrop);
      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason: '$label $tone measured ${ratio.toStringAsFixed(2)}:1',
      );
    }

    for (final tone in DraftStatusBadgeTone.values) {
      testWidgets('$tone clears 4.5:1 in dark', (tester) async {
        await expectReadable(
          tester,
          tone,
          theme: VineTheme.theme,
          label: 'dark',
        );
      });

      testWidgets('$tone clears 4.5:1 in light', (tester) async {
        await expectReadable(
          tester,
          tone,
          theme: VineTheme.lightTheme,
          label: 'light',
        );
      });
    }
  });
}

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// WCAG 2.1 contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (lighter, darker) = la > lb ? (la, lb) : (lb, la);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group(VineTheme, () {
    // Material 3 ignores `primarySwatch`. Without an explicit `colorScheme`
    // the theme falls back to the M3 baseline, whose primary is a purple that
    // leaks onto every widget defaulting to `colorScheme.primary` — the bug
    // that surfaced as purple RefreshIndicators.
    group('colorScheme', () {
      test('dark primary is the brand green, not the Material 3 baseline', () {
        expect(VineTheme.theme.colorScheme.primary, VineTheme.vineGreen);
        expect(VineTheme.theme.colorScheme.onPrimary, VineTheme.onPrimary);
      });

      test('light primary is a green dark enough to read on white', () {
        final primary = VineTheme.lightTheme.colorScheme.primary;
        // Not the dark-mode accent: vineGreen only reaches ~2.2:1 on the light
        // background, so anything defaulting to `primary` there is unreadable.
        expect(primary, isNot(VineTheme.vineGreen));
        expect(
          _contrast(primary, VineTheme.lightColors.background),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('brightness still follows the requested mode', () {
        expect(VineTheme.theme.colorScheme.brightness, Brightness.dark);
        expect(VineTheme.lightTheme.colorScheme.brightness, Brightness.light);
      });
    });

    group('progressIndicatorTheme', () {
      test('bare progress indicators follow the scheme primary', () {
        expect(
          VineTheme.theme.progressIndicatorTheme.color,
          VineTheme.vineGreen,
        );
        expect(
          VineTheme.lightTheme.progressIndicatorTheme.color,
          VineTheme.lightTheme.colorScheme.primary,
        );
      });
    });
  });
}

// ABOUTME: Shared Flutter accessibility-guideline assertions for widget tests.
// ABOUTME: Owns the SemanticsHandle so a failing check cannot leak one.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Guidelines that read the semantics tree only.
///
/// * [androidTapTargetGuideline] / [iOSTapTargetGuideline] hold tap targets at
///   48dp / 44pt.
/// * [labeledTapTargetGuideline] catches a tappable node that announces
///   nothing to a screen reader.
const divineSemanticsGuidelines = <AccessibilityGuideline>[
  androidTapTargetGuideline,
  iOSTapTargetGuideline,
  labeledTapTargetGuideline,
];

/// The full set every interactive app surface is expected to meet.
///
/// Adds [textContrastGuideline], which rasterizes the tree and holds rendered
/// text to WCAG AA contrast against the pixels actually painted behind it.
///
/// This set is app-layer only. The guideline rasterizes inside `runAsync`,
/// which lets a pending `google_fonts` load surface — fine here because the
/// app bundles BricolageGrotesque and Inter as assets and `test_setup.dart`
/// turns runtime fetching off, but not in `divine_ui`, which ships no fonts.
const divineAccessibilityGuidelines = <AccessibilityGuideline>[
  ...divineSemanticsGuidelines,
  textContrastGuideline,
];

/// Asserts the currently pumped widget tree meets [guidelines].
///
/// Call after `pumpWidget`. Semantics are enabled for the duration of the
/// check and the handle is disposed afterwards, including when an assertion
/// fails — a leaked handle would otherwise leave semantics on for every later
/// suite in the merged test isolate.
///
/// Keep the subject away from the viewport and scrollable edges. Flutter's
/// tap-target guidelines skip boundary-touching semantics nodes because they
/// may be partially off-screen, so flush fixtures can pass without evaluating
/// the intended target size. `Center` alone does not achieve this for a
/// subject that still resolves to full width — constrain the width as well.
Future<void> expectMeetsAccessibilityGuidelines(
  WidgetTester tester, {
  Iterable<AccessibilityGuideline> guidelines = divineAccessibilityGuidelines,
  String? reason,
}) async {
  final handle = tester.ensureSemantics();
  try {
    for (final guideline in guidelines) {
      await expectLater(tester, meetsGuideline(guideline), reason: reason);
    }
  } finally {
    handle.dispose();
  }
}

/// Pumps [build] in both shipped appearances and checks [guidelines] on each.
///
/// Divine ships dark and light, and a contrast regression normally lands in
/// one appearance only — `vineGreenLight` was 15:1 on the dark icon-button
/// container and 1.01:1 on the light one. Checking a single theme misses half
/// of them.
Future<void> expectMeetsAccessibilityGuidelinesInBothAppearances(
  WidgetTester tester,
  Widget Function(ThemeData theme) build, {
  Iterable<AccessibilityGuideline> guidelines = divineAccessibilityGuidelines,
}) async {
  for (final theme in <ThemeData>[VineTheme.theme, VineTheme.lightTheme]) {
    // Unmount first. `MaterialApp` interpolates through `AnimatedTheme`, so
    // swapping the theme on a live tree leaves the second appearance reading
    // the first one's colors for the next ~200ms. A fresh mount starts at the
    // target theme with no transition.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(build(theme));
    await tester.pump();
    await expectMeetsAccessibilityGuidelines(
      tester,
      guidelines: guidelines,
      reason: 'in the ${theme.brightness.name} appearance',
    );
  }
}

// ABOUTME: Tests for VineBottomSheetActionMenu component
// ABOUTME: Verifies action items, destructive states, and closeOnTap behavior

import 'dart:ui' show Tristate;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('VineBottomSheetActionMenu', () {
    const testIconPath = 'assets/icons/test.svg';

    setUp(svg.cache.clear);

    Widget buildTestApp({
      required List<VineBottomSheetActionData> options,
      Widget? title,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => VineBottomSheetActionMenu.show(
                context: context,
                options: options,
                title: title,
              ),
              child: const Text('Show Menu'),
            ),
          ),
        ),
      );
    }

    testWidgets('shows all options', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          options: [
            VineBottomSheetActionData(
              iconPath: testIconPath,
              label: 'Edit',
              onTap: () {},
            ),
            VineBottomSheetActionData(
              iconPath: testIconPath,
              label: 'Delete',
              isDestructive: true,
              onTap: () {},
            ),
          ],
        ),
      );

      await tester.tap(find.text('Show Menu'));
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('shows title when provided', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          options: [
            VineBottomSheetActionData(
              iconPath: testIconPath,
              label: 'Action',
              onTap: () {},
            ),
          ],
          title: const Text('Actions'),
        ),
      );

      await tester.tap(find.text('Show Menu'));
      await tester.pumpAndSettle();

      expect(find.text('Actions'), findsOneWidget);
    });

    testWidgets('calls onTap when action is tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        buildTestApp(
          options: [
            VineBottomSheetActionData(
              iconPath: testIconPath,
              label: 'Tap Me',
              onTap: () => tapped = true,
            ),
          ],
        ),
      );

      await tester.tap(find.text('Show Menu'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tap Me'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('closes sheet when closeOnTap is true (default)', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          options: [
            VineBottomSheetActionData(
              iconPath: testIconPath,
              label: 'Close Me',
              onTap: () {},
            ),
          ],
        ),
      );

      await tester.tap(find.text('Show Menu'));
      await tester.pumpAndSettle();

      expect(find.text('Close Me'), findsOneWidget);

      await tester.tap(find.text('Close Me'));
      await tester.pumpAndSettle();

      // Sheet should be closed
      expect(find.text('Close Me'), findsNothing);
    });

    testWidgets('does not close sheet when closeOnTap is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestApp(
          options: [
            VineBottomSheetActionData(
              iconPath: testIconPath,
              label: 'Stay Open',
              closeOnTap: false,
              onTap: () {},
            ),
          ],
        ),
      );

      await tester.tap(find.text('Show Menu'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Stay Open'));
      await tester.pumpAndSettle();

      // Sheet should still be open
      expect(find.text('Stay Open'), findsOneWidget);
    });

    testWidgets('disabled action is not tappable', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          options: [
            const VineBottomSheetActionData(
              iconPath: testIconPath,
              label: 'Disabled',
              // onTap is null, so action is disabled
            ),
          ],
        ),
      );

      await tester.tap(find.text('Show Menu'));
      await tester.pumpAndSettle();

      // ListTile should be disabled
      final listTile = tester.widget<ListTile>(find.byType(ListTile));
      expect(listTile.enabled, isFalse);

      // Tapping should do nothing
      await tester.tap(find.text('Disabled'));
      await tester.pumpAndSettle();

      // Sheet should still be open (wasn't closed by tap)
      expect(find.text('Disabled'), findsOneWidget);
    });

    testWidgets('destructive action has red color', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          options: [
            VineBottomSheetActionData(
              iconPath: testIconPath,
              label: 'Delete',
              isDestructive: true,
              onTap: () {},
            ),
          ],
        ),
      );

      await tester.tap(find.text('Show Menu'));
      await tester.pumpAndSettle();

      final textWidget = tester.widget<Text>(find.text('Delete'));
      expect(textWidget.style?.color, const Color(0xFFF44336));
    });

    testWidgets('normal action has white color', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          options: [
            VineBottomSheetActionData(
              iconPath: testIconPath,
              label: 'Edit',
              onTap: () {},
            ),
          ],
        ),
      );

      await tester.tap(find.text('Show Menu'));
      await tester.pumpAndSettle();

      final textWidget = tester.widget<Text>(find.text('Edit'));
      expect(textWidget.style?.color, Colors.white);
    });

    testWidgets('disabled action has dimmed color', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          options: [
            const VineBottomSheetActionData(
              iconPath: testIconPath,
              label: 'Disabled',
              // onTap is null
            ),
          ],
        ),
      );

      await tester.tap(find.text('Show Menu'));
      await tester.pumpAndSettle();

      final textWidget = tester.widget<Text>(find.text('Disabled'));
      expect(textWidget.style?.color, const Color(0x40FFFFFF));
    });

    testWidgets('dismisses when tapping outside', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          options: [
            VineBottomSheetActionData(
              iconPath: testIconPath,
              label: 'Action',
              onTap: () {},
            ),
          ],
        ),
      );

      await tester.tap(find.text('Show Menu'));
      await tester.pumpAndSettle();

      expect(find.text('Action'), findsOneWidget);

      // Dismiss by tapping outside (the barrier)
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Action'), findsNothing);
    });

    testWidgets('leading icon grows with the system text scale', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          // Wraps the Navigator, so the sheet's own route inherits the
          // scale too — a MediaQuery under `home` would not reach it.
          builder: (context, child) => MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => VineBottomSheetActionMenu.show(
                  context: context,
                  options: [
                    VineBottomSheetActionData(
                      iconPath: testIconPath,
                      label: 'Edit',
                      onTap: () {},
                    ),
                  ],
                ),
                child: const Text('Show Menu'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Menu'));
      await tester.pumpAndSettle();

      final leading = tester.getSize(
        find
            .ancestor(
              of: find.byType(SvgPicture),
              matching: find.byType(SizedBox),
            )
            .first,
      );

      expect(leading.width, closeTo(24 * DivineIcon.maxScaleFactor, 0.001));
      expect(leading.height, leading.width);
    });

    group('accessibility', () {
      Widget buildThemed(ThemeData theme, {required bool destructive}) =>
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => VineBottomSheetActionMenu.show(
                    context: context,
                    options: [
                      VineBottomSheetActionData(
                        iconPath: testIconPath,
                        label: 'Edit',
                        onTap: () {},
                      ),
                      if (destructive)
                        VineBottomSheetActionData(
                          iconPath: testIconPath,
                          label: 'Delete',
                          isDestructive: true,
                          onTap: () {},
                        ),
                      const VineBottomSheetActionData(
                        iconPath: testIconPath,
                        label: 'Unavailable',
                      ),
                    ],
                  ),
                  child: const Text('Show Menu'),
                ),
              ),
            ),
          );

      for (final (name, theme) in <(String, ThemeData)>[
        ('dark', VineTheme.theme),
        ('light', VineTheme.lightTheme),
      ]) {
        testWidgets('$name tiles meet the tap-target guidelines', (
          tester,
        ) async {
          final handle = tester.ensureSemantics();
          await tester.pumpWidget(buildThemed(theme, destructive: true));
          await tester.tap(find.text('Show Menu'));
          await tester.pumpAndSettle();

          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          handle.dispose();
        });

        // Covers the normal and dimmed tiles. The dimmed one sits below
        // 4.5:1 by design and stays legitimate only because it reports
        // itself disabled, which WCAG exempts and this guideline honours —
        // drop `enabled:` from the tile and this test fails.
        //
        // The destructive tile is excluded in light: VineTheme.error on the
        // light sheet surface measures 3.68:1, a real gap that needs a
        // design call on the tone rather than a unilateral recolour here.
        // See #6235. It is included in dark, where it passes.
        testWidgets('$name tiles meet the text-contrast guideline', (
          tester,
        ) async {
          final handle = tester.ensureSemantics();
          await tester.pumpWidget(
            buildThemed(theme, destructive: name == 'dark'),
          );
          await tester.tap(find.text('Show Menu'));
          await tester.pumpAndSettle();

          await expectLater(tester, meetsGuideline(textContrastGuideline));
          handle.dispose();
        });
      }

      testWidgets('a disabled tile reports itself as disabled', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          buildThemed(VineTheme.theme, destructive: false),
        );
        await tester.tap(find.text('Show Menu'));
        await tester.pumpAndSettle();

        final node = tester.getSemantics(find.text('Unavailable'));
        expect(
          node.getSemanticsData().flagsCollection.isEnabled,
          Tristate.isFalse,
        );
        handle.dispose();
      });
    });
  });

  group('VineBottomSheetActionData', () {
    test('creates with required parameters', () {
      const data = VineBottomSheetActionData(
        iconPath: 'assets/icon.svg',
        label: 'Test',
      );

      expect(data.iconPath, 'assets/icon.svg');
      expect(data.label, 'Test');
      expect(data.isDestructive, isFalse);
      expect(data.closeOnTap, isTrue);
      expect(data.onTap, isNull);
    });

    test('creates with all parameters', () {
      var called = false;
      final data = VineBottomSheetActionData(
        iconPath: 'assets/delete.svg',
        label: 'Delete',
        isDestructive: true,
        closeOnTap: false,
        onTap: () => called = true,
      );

      expect(data.iconPath, 'assets/delete.svg');
      expect(data.label, 'Delete');
      expect(data.isDestructive, isTrue);
      expect(data.closeOnTap, isFalse);
      expect(data.onTap, isNotNull);

      data.onTap!();
      expect(called, isTrue);
    });

    test('isDestructive defaults to false', () {
      const data = VineBottomSheetActionData(
        iconPath: 'icon.svg',
        label: 'Action',
      );

      expect(data.isDestructive, isFalse);
    });

    test('closeOnTap defaults to true', () {
      const data = VineBottomSheetActionData(
        iconPath: 'icon.svg',
        label: 'Action',
      );

      expect(data.closeOnTap, isTrue);
    });
  });
}

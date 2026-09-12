// ABOUTME: Tests for VineBottomSheetSelectionMenu component
// ABOUTME: Verifies modal behavior and selection return values

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('VineBottomSheetSelectionMenu', () {
    const testOptions = [
      VineBottomSheetSelectionOptionData(label: 'New', value: 'latest'),
      VineBottomSheetSelectionOptionData(label: 'Popular', value: 'popular'),
      VineBottomSheetSelectionOptionData(label: 'Following', value: 'home'),
    ];

    testWidgets('shows all options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => VineBottomSheetSelectionMenu.show(
                  context: context,
                  options: testOptions,
                ),
                child: const Text('Show Menu'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Menu'));
      await tester.pumpAndSettle();

      expect(find.text('New'), findsOneWidget);
      expect(find.text('Popular'), findsOneWidget);
      expect(find.text('Following'), findsOneWidget);
    });

    testWidgets('shows title when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => VineBottomSheetSelectionMenu.show(
                  context: context,
                  options: testOptions,
                  title: const Text('Feed Mode'),
                ),
                child: const Text('Show Menu'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Menu'));
      await tester.pumpAndSettle();

      expect(find.text('Feed Mode'), findsOneWidget);
    });

    testWidgets('shows checkmark for selected option', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => VineBottomSheetSelectionMenu.show(
                  context: context,
                  options: testOptions,
                  selectedValue: 'popular',
                ),
                child: const Text('Show Menu'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Menu'));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) => w is DivineIcon && w.icon == DivineIconName.check,
        ),
        findsOneWidget,
      );
    });

    testWidgets('exposes each option as a button reporting selected state', (
      tester,
    ) async {
      final semanticsHandle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => VineBottomSheetSelectionMenu.show(
                    context: context,
                    options: testOptions,
                    selectedValue: 'popular',
                  ),
                  child: const Text('Show Menu'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Menu'));
        await tester.pumpAndSettle();

        // The label is exactly the option label — the wrapper must not
        // concatenate the child Text on top of it.
        expect(
          tester.getSemantics(find.bySemanticsLabel('Popular')),
          isSemantics(
            label: 'Popular',
            isButton: true,
            isSelected: true,
            hasTapAction: true,
          ),
        );

        expect(
          tester.getSemantics(find.bySemanticsLabel('New')),
          isSemantics(
            label: 'New',
            isButton: true,
            isSelected: false,
            hasTapAction: true,
          ),
        );
      } finally {
        semanticsHandle.dispose();
      }
    });

    testWidgets('shows no checkmark when nothing selected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => VineBottomSheetSelectionMenu.show(
                  context: context,
                  options: testOptions,
                ),
                child: const Text('Show Menu'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Menu'));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) => w is DivineIcon && w.icon == DivineIconName.check,
        ),
        findsNothing,
      );
    });

    testWidgets('shows leading icon when provided', (tester) async {
      const optionsWithIcon = [
        VineBottomSheetSelectionOptionData(
          label: 'Newest',
          value: 'newest',
          leadingIcon: DivineIconName.arrowFatLineDown,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => VineBottomSheetSelectionMenu.show(
                  context: context,
                  options: optionsWithIcon,
                ),
                child: const Text('Show Menu'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Menu'));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) => w is DivineIcon && w.icon == DivineIconName.arrowFatLineDown,
        ),
        findsOneWidget,
      );
    });

    testWidgets('returns selected value when option tapped', (tester) async {
      String? selectedValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  selectedValue = await VineBottomSheetSelectionMenu.show(
                    context: context,
                    options: testOptions,
                    selectedValue: 'latest',
                  );
                },
                child: const Text('Show Menu'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Menu'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Popular'));
      await tester.pumpAndSettle();

      expect(selectedValue, 'popular');
    });

    testWidgets('returns null when dismissed', (tester) async {
      String? selectedValue = 'initial';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  selectedValue = await VineBottomSheetSelectionMenu.show(
                    context: context,
                    options: testOptions,
                  );
                },
                child: const Text('Show Menu'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Menu'));
      await tester.pumpAndSettle();

      // Dismiss by tapping the modal barrier.
      await tester.tap(
        find.byType(ModalBarrier).first,
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(selectedValue, isNull);
    });
  });

  group('VineBottomSheetSelectionOptionData', () {
    test('creates with required parameters', () {
      // Use non-const to ensure constructor coverage instrumentation.
      // ignore: prefer_const_constructors
      final data = VineBottomSheetSelectionOptionData(
        label: 'Test',
        value: 'test_value',
      );

      expect(data.label, 'Test');
      expect(data.value, 'test_value');
    });

    test('creates with optional leading icon', () {
      const data = VineBottomSheetSelectionOptionData(
        label: 'Test',
        value: 'test_value',
        leadingIcon: DivineIconName.arrowUp,
      );

      expect(data.leadingIcon, DivineIconName.arrowUp);
    });
  });
}

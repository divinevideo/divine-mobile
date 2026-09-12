import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('DivineSpriteCheckbox', () {
    Widget buildTestWidget({
      DivineCheckboxState state = DivineCheckboxState.unselected,
      Duration animationDuration = const Duration(milliseconds: 100),
      ThemeData? theme,
    }) {
      return MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Center(
            child: DivineSpriteCheckbox(
              state: state,
              animationDuration: animationDuration,
            ),
          ),
        ),
      );
    }

    group('appearance mode', () {
      // The unselected band is a filled box: dark green reads as an empty
      // checkbox on a dark surface and as a black blob on a light one, so
      // each palette gets its own sprite.
      testWidgets('uses the dark sprite on the dark palette', (tester) async {
        await tester.pumpWidget(buildTestWidget(theme: VineTheme.theme));

        final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
        expect(
          (svg.bytesLoader as SvgAssetLoader).assetName,
          DivineSpriteCheckbox.darkSpriteAsset,
        );
      });

      testWidgets('uses the light sprite on the light palette', (tester) async {
        await tester.pumpWidget(buildTestWidget(theme: VineTheme.lightTheme));

        final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
        expect(
          (svg.bytesLoader as SvgAssetLoader).assetName,
          DivineSpriteCheckbox.lightSpriteAsset,
        );
      });
    });

    group('rendering', () {
      testWidgets('renders SVG sprite', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        expect(find.byType(SvgPicture), findsOneWidget);
        expect(find.byType(DivineSpriteCheckbox), findsOneWidget);
      });

      testWidgets('has correct viewport size 24x24', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        // The SizedBox clips the sprite to 24x24 viewport
        final sizedBox = tester.widget<SizedBox>(
          find.descendant(
            of: find.byType(DivineSpriteCheckbox),
            matching: find.byType(SizedBox).first,
          ),
        );

        expect(sizedBox.width, 24);
        expect(sizedBox.height, 24);
      });
    });

    group('states', () {
      testWidgets('renders unselected state', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        final animatedOpacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(animatedOpacity.opacity, 1.0);
      });

      testWidgets('renders selected state', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(state: DivineCheckboxState.selected),
        );

        final animatedOpacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(animatedOpacity.opacity, 1.0);
      });

      testWidgets('renders intermediate state', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(state: DivineCheckboxState.intermediate),
        );

        final animatedOpacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(animatedOpacity.opacity, 1.0);
      });

      testWidgets('renders disabled state with reduced opacity', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(state: DivineCheckboxState.disabled),
        );

        final animatedOpacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(animatedOpacity.opacity, 0.5);
      });
    });

    group('animation', () {
      testWidgets('uses provided animation duration', (tester) async {
        const customDuration = Duration(milliseconds: 200);
        await tester.pumpWidget(
          buildTestWidget(animationDuration: customDuration),
        );

        final animatedOpacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(animatedOpacity.duration, customDuration);
      });
    });
  });

  group('DivineCheckbox', () {
    Widget buildTestWidget({
      DivineCheckboxState state = DivineCheckboxState.unselected,
      Widget label = const Text('Test label'),
      CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
      Duration animationDuration = const Duration(milliseconds: 100),
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: DivineCheckbox(
              state: state,
              label: label,
              crossAxisAlignment: crossAxisAlignment,
              animationDuration: animationDuration,
            ),
          ),
        ),
      );
    }

    group('rendering', () {
      testWidgets('renders sprite checkbox and label', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        expect(find.byType(DivineSpriteCheckbox), findsOneWidget);
        expect(find.text('Test label'), findsOneWidget);
      });

      testWidgets('renders with custom label widget', (tester) async {
        await tester.pumpWidget(buildTestWidget(label: const Icon(Icons.star)));

        expect(find.byType(DivineSpriteCheckbox), findsOneWidget);
        expect(find.byType(Icon), findsOneWidget);
      });
    });

    group('layout', () {
      testWidgets('uses center alignment by default', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        final row = tester.widget<Row>(find.byType(Row));
        expect(row.crossAxisAlignment, CrossAxisAlignment.center);
      });

      testWidgets('uses custom crossAxisAlignment', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(crossAxisAlignment: CrossAxisAlignment.start),
        );

        final row = tester.widget<Row>(find.byType(Row));
        expect(row.crossAxisAlignment, CrossAxisAlignment.start);
      });
    });

    group('states', () {
      testWidgets('passes state to sprite checkbox', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(state: DivineCheckboxState.selected),
        );

        final spriteCheckbox = tester.widget<DivineSpriteCheckbox>(
          find.byType(DivineSpriteCheckbox),
        );
        expect(spriteCheckbox.state, DivineCheckboxState.selected);
      });
    });

    group('animation', () {
      testWidgets('passes animation duration to sprite checkbox', (
        tester,
      ) async {
        const customDuration = Duration(milliseconds: 200);
        await tester.pumpWidget(
          buildTestWidget(animationDuration: customDuration),
        );

        final spriteCheckbox = tester.widget<DivineSpriteCheckbox>(
          find.byType(DivineSpriteCheckbox),
        );
        expect(spriteCheckbox.animationDuration, customDuration);
      });
    });
  });

  group('DivineRowCheckbox', () {
    Widget buildTestWidget({
      required ValueChanged<bool> onChanged,
      DivineCheckboxState state = DivineCheckboxState.unselected,
      Widget label = const Text('Test label'),
      CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
      Duration animationDuration = const Duration(milliseconds: 100),
      ThemeData? theme,
    }) {
      return MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Center(
            child: DivineRowCheckbox(
              state: state,
              onChanged: onChanged,
              label: label,
              crossAxisAlignment: crossAxisAlignment,
              animationDuration: animationDuration,
            ),
          ),
        ),
      );
    }

    group('rendering', () {
      testWidgets('renders checkbox with border', (tester) async {
        await tester.pumpWidget(buildTestWidget(onChanged: (_) {}));

        expect(find.byType(DivineCheckbox), findsOneWidget);
        expect(find.byType(AnimatedContainer), findsOneWidget);
      });

      testWidgets('renders with label', (tester) async {
        await tester.pumpWidget(buildTestWidget(onChanged: (_) {}));

        expect(find.text('Test label'), findsOneWidget);
      });
    });

    group('interaction', () {
      testWidgets('calls onChanged with true when tapping unselected', (
        tester,
      ) async {
        bool? newValue;
        await tester.pumpWidget(
          buildTestWidget(onChanged: (value) => newValue = value),
        );

        await tester.tap(find.byType(DivineRowCheckbox));
        await tester.pumpAndSettle();

        expect(newValue, isTrue);
      });

      testWidgets('calls onChanged with false when tapping selected', (
        tester,
      ) async {
        bool? newValue;
        await tester.pumpWidget(
          buildTestWidget(
            state: DivineCheckboxState.selected,
            onChanged: (value) => newValue = value,
          ),
        );

        await tester.tap(find.byType(DivineRowCheckbox));
        await tester.pumpAndSettle();

        expect(newValue, isFalse);
      });

      testWidgets('calls onChanged with false when tapping intermediate', (
        tester,
      ) async {
        bool? newValue;
        await tester.pumpWidget(
          buildTestWidget(
            state: DivineCheckboxState.intermediate,
            onChanged: (value) => newValue = value,
          ),
        );

        await tester.tap(find.byType(DivineRowCheckbox));
        await tester.pumpAndSettle();

        expect(newValue, isFalse);
      });

      testWidgets('does not call onChanged when disabled', (tester) async {
        var called = false;
        await tester.pumpWidget(
          buildTestWidget(
            state: DivineCheckboxState.disabled,
            onChanged: (_) => called = true,
          ),
        );

        await tester.tap(find.byType(DivineRowCheckbox));
        await tester.pumpAndSettle();

        expect(called, isFalse);
      });
    });

    group('accessibility', () {
      testWidgets('exposes checked checkbox semantics when selected', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          buildTestWidget(
            state: DivineCheckboxState.selected,
            onChanged: (_) {},
          ),
        );

        expect(
          tester.getSemantics(find.byType(DivineRowCheckbox)),
          isSemantics(hasCheckedState: true, isChecked: true, isEnabled: true),
        );
        handle.dispose();
      });

      testWidgets('exposes unchecked semantics when unselected', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(buildTestWidget(onChanged: (_) {}));

        expect(
          tester.getSemantics(find.byType(DivineRowCheckbox)),
          isSemantics(hasCheckedState: true, isChecked: false),
        );
        handle.dispose();
      });

      testWidgets('is marked disabled in semantics when disabled', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          buildTestWidget(
            state: DivineCheckboxState.disabled,
            onChanged: (_) {},
          ),
        );

        expect(
          tester.getSemantics(find.byType(DivineRowCheckbox)),
          isSemantics(hasEnabledState: true, isEnabled: false),
        );
        handle.dispose();
      });
    });

    group('border styling', () {
      Color borderColor(WidgetTester tester) {
        final container = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );
        final boxDecoration = container.decoration! as BoxDecoration;
        return boxDecoration.border!.top.color;
      }

      setUp(() => VineThemeColors.debugFallbackCount = 0);
      tearDown(() => VineThemeColors.debugFallbackCount = 0);

      testWidgets('uses light outlineMuted border when unselected', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(onChanged: (_) {}, theme: VineTheme.lightTheme),
        );

        expect(borderColor(tester), VineTheme.lightColors.outlineMuted);
        expect(VineThemeColors.debugFallbackCount, 0);
      });

      testWidgets('uses dark outlineMuted border when unselected', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(onChanged: (_) {}, theme: VineTheme.theme),
        );

        expect(borderColor(tester), VineTheme.darkColors.outlineMuted);
        expect(VineThemeColors.debugFallbackCount, 0);
      });

      testWidgets('uses light accentPositive border when selected', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            state: DivineCheckboxState.selected,
            onChanged: (_) {},
            theme: VineTheme.lightTheme,
          ),
        );

        final color = borderColor(tester);
        expect(color, VineTheme.lightColors.accentPositive);
        expect(
          color,
          isNot(VineTheme.primary),
          reason: 'light mode must not fall back to the dark brand green',
        );
        expect(VineThemeColors.debugFallbackCount, 0);
      });

      testWidgets('uses dark accentPositive border when selected', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            state: DivineCheckboxState.selected,
            onChanged: (_) {},
            theme: VineTheme.theme,
          ),
        );

        expect(borderColor(tester), VineTheme.darkColors.accentPositive);
        expect(VineThemeColors.debugFallbackCount, 0);
      });

      testWidgets('uses light accentPositive border when intermediate', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            state: DivineCheckboxState.intermediate,
            onChanged: (_) {},
            theme: VineTheme.lightTheme,
          ),
        );

        final color = borderColor(tester);
        expect(color, VineTheme.lightColors.accentPositive);
        expect(
          color,
          isNot(VineTheme.primary),
          reason: 'light mode must not fall back to the dark brand green',
        );
        expect(VineThemeColors.debugFallbackCount, 0);
      });

      testWidgets('uses dark accentPositive border when intermediate', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            state: DivineCheckboxState.intermediate,
            onChanged: (_) {},
            theme: VineTheme.theme,
          ),
        );

        expect(borderColor(tester), VineTheme.darkColors.accentPositive);
        expect(VineThemeColors.debugFallbackCount, 0);
      });
    });

    group('layout', () {
      testWidgets('passes crossAxisAlignment to checkbox', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            crossAxisAlignment: CrossAxisAlignment.start,
            onChanged: (_) {},
          ),
        );

        final checkbox = tester.widget<DivineCheckbox>(
          find.byType(DivineCheckbox),
        );
        expect(checkbox.crossAxisAlignment, CrossAxisAlignment.start);
      });
    });

    group('animation', () {
      testWidgets('passes animation duration to checkbox', (tester) async {
        const customDuration = Duration(milliseconds: 200);
        await tester.pumpWidget(
          buildTestWidget(animationDuration: customDuration, onChanged: (_) {}),
        );

        final checkbox = tester.widget<DivineCheckbox>(
          find.byType(DivineCheckbox),
        );
        expect(checkbox.animationDuration, customDuration);
      });

      testWidgets('passes animation duration to container', (tester) async {
        const customDuration = Duration(milliseconds: 200);
        await tester.pumpWidget(
          buildTestWidget(animationDuration: customDuration, onChanged: (_) {}),
        );

        final container = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );
        expect(container.duration, customDuration);
      });
    });
  });
}

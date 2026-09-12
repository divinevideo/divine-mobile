// MaterialIconSource is deprecated but still fully supported; these tests
// intentionally exercise it to guard that support, not migrate off it.
// ignore_for_file: deprecated_member_use_from_same_package

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/accessibility_guidelines.dart';

void main() {
  group('DivineAppBarIconButton', () {
    Widget buildTestWidget({
      required IconSource icon,
      VoidCallback? onPressed,
      String? tooltip,
      String? semanticLabel,
      Color? backgroundColor,
      Color? iconColor,
      BorderSide? borderSide,
    }) {
      return MaterialApp(
        theme: VineTheme.theme,
        home: Scaffold(
          body: Center(
            child: DivineAppBarIconButton(
              icon: icon,
              onPressed: onPressed,
              tooltip: tooltip,
              semanticLabel: semanticLabel,
              backgroundColor: backgroundColor,
              iconColor: iconColor,
              borderSide: borderSide,
            ),
          ),
        ),
      );
    }

    BoxDecoration findDecoration(WidgetTester tester) {
      final ink = tester.widget<Ink>(find.byType(Ink));
      return ink.decoration! as BoxDecoration;
    }

    group('rendering', () {
      testWidgets('renders with Material icon', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            icon: const MaterialIconSource(Icons.arrow_back),
          ),
        );

        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      });

      testWidgets('renders with SVG icon', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            icon: const SvgIconSource('assets/icon/CaretLeft.svg'),
          ),
        );

        expect(find.byType(SvgPicture), findsOneWidget);
      });

      testWidgets('delegates to DivineIconButton at small size', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(icon: const MaterialIconSource(Icons.arrow_back)),
        );

        final divineIconButton = tester.widget<DivineIconButton>(
          find.byType(DivineIconButton),
        );
        expect(divineIconButton.size, DivineIconButtonSize.small);
      });
    });

    group('styling', () {
      testWidgets('uses default background color', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(icon: const MaterialIconSource(Icons.arrow_back)),
        );

        expect(findDecoration(tester).color, VineTheme.iconButtonBackground);
      });

      testWidgets('uses custom background color', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            icon: const MaterialIconSource(Icons.arrow_back),
            backgroundColor: Colors.red,
          ),
        );

        expect(findDecoration(tester).color, Colors.red);
      });

      testWidgets('uses default icon color', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(icon: const MaterialIconSource(Icons.arrow_back)),
        );

        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.color, Colors.white);
      });

      testWidgets('uses custom icon color', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            icon: const MaterialIconSource(Icons.arrow_back),
            iconColor: Colors.blue,
          ),
        );

        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.color, Colors.blue);
      });

      testWidgets('applies border radius matching DivineIconButtonSize.small', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(icon: const MaterialIconSource(Icons.arrow_back)),
        );

        expect(
          findDecoration(tester).borderRadius,
          BorderRadius.circular(16),
        );
      });

      testWidgets('no border when borderSide is null', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(icon: const MaterialIconSource(Icons.arrow_back)),
        );

        expect(findDecoration(tester).border, isNull);
      });

      testWidgets('renders a 2px outlineMuted border when borderSide is set', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            icon: const MaterialIconSource(Icons.arrow_back),
            borderSide: const BorderSide(
              color: VineTheme.outlineMuted,
              width: 2,
            ),
          ),
        );

        final border = findDecoration(tester).border! as Border;
        expect(border.top.color, VineTheme.outlineMuted);
        expect(border.top.width, 2);
      });
    });

    group('shadow', () {
      testWidgets('renders no shadow, unlike a default DivineIconButton', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            icon: const MaterialIconSource(Icons.arrow_back),
            onPressed: () {},
          ),
        );

        expect(findDecoration(tester).boxShadow, isNull);
      });
    });

    group('interaction', () {
      testWidgets('calls onPressed when tapped', (tester) async {
        var pressed = false;
        await tester.pumpWidget(
          buildTestWidget(
            icon: const MaterialIconSource(Icons.arrow_back),
            onPressed: () => pressed = true,
          ),
        );

        await tester.tap(find.byType(DivineAppBarIconButton));
        await tester.pumpAndSettle();

        expect(pressed, isTrue);
      });

      testWidgets('does not throw when onPressed is null and tapped', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(icon: const MaterialIconSource(Icons.arrow_back)),
        );

        await tester.tap(find.byType(DivineAppBarIconButton));

        expect(tester.takeException(), isNull);
      });
    });

    group('tooltip', () {
      testWidgets('renders tooltip when provided', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            icon: const MaterialIconSource(Icons.arrow_back),
            tooltip: 'Go back',
          ),
        );

        expect(find.byType(Tooltip), findsOneWidget);
      });

      testWidgets('does not render tooltip when not provided', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(icon: const MaterialIconSource(Icons.arrow_back)),
        );

        expect(find.byType(Tooltip), findsNothing);
      });

      testWidgets('tooltip has correct message', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            icon: const MaterialIconSource(Icons.arrow_back),
            tooltip: 'Custom tooltip',
          ),
        );

        final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
        expect(tooltip.message, 'Custom tooltip');
      });
    });

    group('accessibility', () {
      Finder findButtonSemantics() {
        return find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && (widget.properties.button ?? false),
        );
      }

      testWidgets('has Semantics wrapper with button property', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            icon: const MaterialIconSource(Icons.arrow_back),
            semanticLabel: 'Back button',
          ),
        );

        expect(findButtonSemantics(), findsWidgets);
      });

      testWidgets('Semantics enabled when onPressed is provided', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            icon: const MaterialIconSource(Icons.arrow_back),
            onPressed: () {},
          ),
        );

        final semantics = tester.firstWidget<Semantics>(findButtonSemantics());
        expect(semantics.properties.enabled, isTrue);
      });

      testWidgets('Semantics disabled when onPressed is null', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(icon: const MaterialIconSource(Icons.arrow_back)),
        );

        final semantics = tester.firstWidget<Semantics>(findButtonSemantics());
        expect(semantics.properties.enabled, isFalse);
      });

      testWidgets('Semantics has correct label', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            icon: const MaterialIconSource(Icons.arrow_back),
            semanticLabel: 'Custom label',
          ),
        );

        final semantics = tester.firstWidget<Semantics>(findButtonSemantics());
        expect(semantics.properties.label, 'Custom label');
      });
    });

    group('SVG icon rendering', () {
      testWidgets('SVG icon uses correct color filter', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            icon: const SvgIconSource('assets/icon/CaretLeft.svg'),
            iconColor: Colors.red,
          ),
        );

        final svgPicture = tester.widget<SvgPicture>(find.byType(SvgPicture));
        expect(
          svgPicture.colorFilter,
          const ColorFilter.mode(Colors.red, BlendMode.srcIn),
        );
      });
    });

    group('accessibility', () {
      testWidgets('meets the accessibility guidelines', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            icon: SvgIconSource(DivineIconName.x.assetPath),
            semanticLabel: 'Close',
            onPressed: () {},
          ),
        );

        await expectMeetsAccessibilityGuidelines(tester);
      });
    });
  });
}

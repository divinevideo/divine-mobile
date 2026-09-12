import 'dart:ui' show SemanticsAction;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/accessibility_guidelines.dart';

void _noop() {}

void main() {
  group('DivineButton', () {
    Widget buildTestWidget({
      String label = 'Test',
      VoidCallback? onPressed,
      DivineButtonType type = DivineButtonType.primary,
      DivineButtonSize size = DivineButtonSize.base,
      DivineIconName? leadingIcon,
      DivineIconName? trailingIcon,
      bool expanded = false,
      bool isLoading = false,
      String? semanticLabel,
      String? semanticIdentifier,
      ThemeData? theme,
    }) {
      return MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Center(
            child: DivineButton(
              label: label,
              onPressed: onPressed,
              type: type,
              size: size,
              leadingIcon: leadingIcon,
              trailingIcon: trailingIcon,
              expanded: expanded,
              isLoading: isLoading,
              semanticLabel: semanticLabel,
              semanticIdentifier: semanticIdentifier,
            ),
          ),
        ),
      );
    }

    group('rendering', () {
      testWidgets('renders with label', (tester) async {
        await tester.pumpWidget(buildTestWidget(label: 'Click Me'));

        expect(find.text('Click Me'), findsOneWidget);
        expect(find.byType(DivineButton), findsOneWidget);
      });

      testWidgets('renders leading icon when provided', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            leadingIcon: DivineIconName.envelope,
            onPressed: () {},
          ),
        );

        expect(find.byType(DivineIcon), findsOneWidget);
        expect(find.byType(SvgPicture), findsOneWidget);
      });

      testWidgets('renders trailing icon when provided', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            trailingIcon: DivineIconName.arrowRight,
            onPressed: () {},
          ),
        );

        expect(find.byType(DivineIcon), findsOneWidget);
      });

      testWidgets('renders both icons when provided', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            leadingIcon: DivineIconName.envelope,
            trailingIcon: DivineIconName.arrowRight,
            onPressed: () {},
          ),
        );

        expect(find.byType(DivineIcon), findsNWidgets(2));
      });
    });

    group('semantics', () {
      testWidgets('semanticLabel replaces the visible label', (tester) async {
        final semanticsHandle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            buildTestWidget(
              label: 'Select',
              semanticLabel: 'Select clips',
              onPressed: _noop,
            ),
          );

          final node = tester.getSemantics(
            find.bySemanticsLabel('Select clips'),
          );
          expect(node.label, 'Select clips');
          expect(
            node.getSemanticsData().hasAction(SemanticsAction.tap),
            isTrue,
          );
          expect(find.bySemanticsLabel('Select'), findsNothing);
        } finally {
          semanticsHandle.dispose();
        }
      });

      testWidgets('semanticIdentifier alone keeps the visible label', (
        tester,
      ) async {
        final semanticsHandle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            buildTestWidget(
              label: 'Sign in',
              semanticIdentifier: 'sign_in_button',
              onPressed: _noop,
            ),
          );

          // The anchor and the accessible name have to land on the same
          // node. Declaring button/onTap on the wrapper splits them in two
          // and assistive tech reads an unnamed button ahead of the real
          // one, so assert the identified node itself carries the label
          // rather than that both exist somewhere in the tree.
          expect(find.bySemanticsLabel('Sign in'), findsOneWidget);
          final node = tester.getSemantics(
            find.bySemanticsIdentifier('sign_in_button'),
          );
          expect(node.label, equals('Sign in'));
          expect(
            node.getSemanticsData().hasAction(SemanticsAction.tap),
            isTrue,
          );
        } finally {
          semanticsHandle.dispose();
        }
      });

      testWidgets('semanticIdentifier and semanticLabel coexist', (
        tester,
      ) async {
        final semanticsHandle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            buildTestWidget(
              label: 'Select',
              semanticLabel: 'Select clips',
              semanticIdentifier: 'select_clips_button',
              onPressed: _noop,
            ),
          );

          final node = tester.getSemantics(
            find.bySemanticsLabel('Select clips'),
          );
          expect(node.label, 'Select clips');
          expect(node.identifier, equals('select_clips_button'));
          expect(find.bySemanticsLabel('Select'), findsNothing);
        } finally {
          semanticsHandle.dispose();
        }
      });

      testWidgets('no identifier when neither semantic param is set', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(label: 'Plain', onPressed: _noop),
        );

        expect(
          tester.getSemantics(find.byType(DivineButton)).identifier,
          isEmpty,
        );
      });
    });

    group('icon colors', () {
      testWidgets('primary type icon uses onPrimary color', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            leadingIcon: DivineIconName.envelope,
            onPressed: () {},
          ),
        );

        final divineIcon = tester.widget<DivineIcon>(find.byType(DivineIcon));
        expect(divineIcon.color, VineTheme.onPrimary);
      });

      testWidgets('secondary type icon uses primary color', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            type: DivineButtonType.secondary,
            leadingIcon: DivineIconName.key,
            onPressed: () {},
          ),
        );

        final divineIcon = tester.widget<DivineIcon>(find.byType(DivineIcon));
        expect(divineIcon.color, VineTheme.primary);
      });

      testWidgets('secondary type icon uses onSurface in light mode', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            theme: VineTheme.lightTheme,
            type: DivineButtonType.secondary,
            leadingIcon: DivineIconName.key,
            onPressed: () {},
          ),
        );

        final divineIcon = tester.widget<DivineIcon>(find.byType(DivineIcon));
        expect(divineIcon.color, VineTheme.lightColors.onSurface);
      });

      testWidgets('tertiary type icon uses inverseOnSurface color', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            type: DivineButtonType.tertiary,
            leadingIcon: DivineIconName.gear,
            onPressed: () {},
          ),
        );

        final divineIcon = tester.widget<DivineIcon>(find.byType(DivineIcon));
        expect(divineIcon.color, VineTheme.inverseOnSurface);
      });

      testWidgets('ghost type icon uses onSurface color', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            type: DivineButtonType.ghost,
            leadingIcon: DivineIconName.x,
            onPressed: () {},
          ),
        );

        final divineIcon = tester.widget<DivineIcon>(find.byType(DivineIcon));
        expect(divineIcon.color, VineTheme.onSurface);
      });

      testWidgets('ghostSecondary type icon uses onSurface in light mode', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            theme: VineTheme.lightTheme,
            type: DivineButtonType.ghostSecondary,
            leadingIcon: DivineIconName.x,
            onPressed: () {},
          ),
        );

        final divineIcon = tester.widget<DivineIcon>(find.byType(DivineIcon));
        expect(divineIcon.color, VineTheme.lightColors.onSurface);
      });

      testWidgets('error type icon uses onErrorContainer color', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            type: DivineButtonType.error,
            leadingIcon: DivineIconName.trash,
            onPressed: () {},
          ),
        );

        final divineIcon = tester.widget<DivineIcon>(find.byType(DivineIcon));
        expect(divineIcon.color, VineTheme.onErrorContainer);
      });
    });

    group('icon sizing', () {
      testWidgets('base size renders 24px icon', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            leadingIcon: DivineIconName.envelope,
            onPressed: () {},
          ),
        );

        final divineIcon = tester.widget<DivineIcon>(find.byType(DivineIcon));
        expect(divineIcon.size, 24);
      });

      testWidgets('small size renders 24px icon', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            size: DivineButtonSize.small,
            leadingIcon: DivineIconName.envelope,
            onPressed: () {},
          ),
        );

        final divineIcon = tester.widget<DivineIcon>(find.byType(DivineIcon));
        expect(divineIcon.size, 24);
      });

      testWidgets('tiny size renders 20px icon', (tester) async {
        // The 32px visible chip can't fit a 24px icon plus the 6px
        // padding above and below — tiny scales the icon down to 20px so
        // 6 + 20 + 6 = 32 exactly.
        await tester.pumpWidget(
          buildTestWidget(
            size: DivineButtonSize.tiny,
            leadingIcon: DivineIconName.envelope,
            onPressed: () {},
          ),
        );

        final divineIcon = tester.widget<DivineIcon>(find.byType(DivineIcon));
        expect(divineIcon.size, 20);
      });
    });

    group('interaction', () {
      testWidgets('calls onPressed when tapped', (tester) async {
        var pressed = false;
        await tester.pumpWidget(
          buildTestWidget(onPressed: () => pressed = true),
        );

        await tester.tap(find.byType(DivineButton));
        await tester.pumpAndSettle();

        expect(pressed, isTrue);
      });

      testWidgets('does not call onPressed when disabled', (tester) async {
        const pressed = false;
        await tester.pumpWidget(buildTestWidget());

        await tester.tap(find.byType(DivineButton));
        await tester.pump();

        expect(pressed, isFalse);
      });

      testWidgets('does not call onPressed while loading', (tester) async {
        var pressed = false;
        await tester.pumpWidget(
          buildTestWidget(onPressed: () => pressed = true, isLoading: true),
        );

        await tester.tap(find.byType(DivineButton));
        await tester.pump();

        expect(pressed, isFalse);
      });
    });

    group('button types', () {
      testWidgets('renders primary type', (tester) async {
        await tester.pumpWidget(buildTestWidget(onPressed: () {}));

        expect(find.byType(DivineButton), findsOneWidget);
      });

      testWidgets('renders secondary type', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(type: DivineButtonType.secondary, onPressed: () {}),
        );

        expect(find.byType(DivineButton), findsOneWidget);
      });

      testWidgets('renders tertiary type', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(type: DivineButtonType.tertiary, onPressed: () {}),
        );

        expect(find.byType(DivineButton), findsOneWidget);
      });

      testWidgets('renders ghost type', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(type: DivineButtonType.ghost, onPressed: () {}),
        );

        expect(find.byType(DivineButton), findsOneWidget);
      });

      testWidgets('renders ghostSecondary type', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            type: DivineButtonType.ghostSecondary,
            onPressed: () {},
          ),
        );

        expect(find.byType(DivineButton), findsOneWidget);
      });

      testWidgets('renders link type', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(type: DivineButtonType.link, onPressed: () {}),
        );

        expect(find.byType(DivineButton), findsOneWidget);
      });

      testWidgets('renders error type', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(type: DivineButtonType.error, onPressed: () {}),
        );

        expect(find.byType(DivineButton), findsOneWidget);
      });
    });

    group('button sizes', () {
      testWidgets('renders tiny size', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(size: DivineButtonSize.tiny, onPressed: () {}),
        );

        expect(find.byType(DivineButton), findsOneWidget);
      });

      testWidgets('renders small size', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(size: DivineButtonSize.small, onPressed: () {}),
        );

        expect(find.byType(DivineButton), findsOneWidget);
      });

      testWidgets('renders base size', (tester) async {
        await tester.pumpWidget(buildTestWidget(onPressed: () {}));

        expect(find.byType(DivineButton), findsOneWidget);
      });

      testWidgets(
        'bordered type keeps the same outer size as an unbordered one',
        (tester) async {
          // The secondary type draws a 2px border via the Ink decoration,
          // which the framework adds around its child. The inner padding
          // compensates so a bordered button does not render larger than an
          // unbordered one of the same size (regression: secondary was 4px
          // wider and taller than primary).
          await tester.pumpWidget(buildTestWidget(onPressed: () {}));
          final unbordered = tester.getSize(find.byType(DivineButton));

          await tester.pumpWidget(
            buildTestWidget(type: DivineButtonType.secondary, onPressed: () {}),
          );
          final bordered = tester.getSize(find.byType(DivineButton));

          expect(bordered, equals(unbordered));
          expect(bordered.height, equals(48));
        },
      );

      testWidgets('tiny footprint and tap target both stay 32px tall', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(size: DivineButtonSize.tiny, onPressed: () {}),
        );

        // Tiny keeps a 32px painted/layout height AND a 32px tap target so
        // it sits flush with the 32px module of the avatar / type icon it
        // usually sits next to, with no invisible hit area bleeding into
        // that neighbor. A row that swaps the button in and out (e.g. a
        // Follow back affordance) keeps the same intrinsic height.
        final outerSize = tester.getSize(find.byType(DivineButton));
        final chipSize = tester.getSize(find.byType(Ink));
        final tapTarget = tester.getSize(find.byType(InkWell));
        expect(outerSize.height, equals(32));
        expect(chipSize.height, equals(32));
        expect(tapTarget.height, equals(32));
      });

      testWidgets('tiny uses 12.8 corner radius (matches 32px UserAvatar)', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(size: DivineButtonSize.tiny, onPressed: () {}),
        );

        // The Ink widget owns the decorated background; its border
        // radius is the source of truth for the chip's corner.
        final ink = tester.widget<Ink>(find.byType(Ink));
        final decoration = ink.decoration! as BoxDecoration;
        final radius = decoration.borderRadius! as BorderRadius;
        expect(radius.topLeft, equals(const Radius.circular(12.8)));
      });

      testWidgets('tiny uses titleSmallFont (Bricolage Grotesque 800 14/20)', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(size: DivineButtonSize.tiny, onPressed: () {}),
        );

        final text = tester.widget<Text>(find.text('Test'));
        // titleSmallFont = Bricolage 800 14/20/0.1.  Bigger weight
        // than labelLargeFont (Inter 600) so the small chip still
        // reads as a primary action.
        expect(text.style?.fontWeight, equals(FontWeight.w800));
        expect(text.style?.fontSize, equals(14));
      });

      testWidgets(
        'small uses titleMediumFont (Bricolage Grotesque 800 16/24)',
        (tester) async {
          // Locks the contract that small / base keep the heavier-feel
          // titleMediumFont — the tiny→titleSmallFont fork above must
          // not leak into the other variants.
          await tester.pumpWidget(
            buildTestWidget(size: DivineButtonSize.small, onPressed: () {}),
          );

          final text = tester.widget<Text>(find.text('Test'));
          expect(text.style?.fontWeight, equals(FontWeight.w800));
          expect(text.style?.fontSize, equals(16));
        },
      );

      testWidgets('small visible chip is 40px tall with a 48dp tap target', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(size: DivineButtonSize.small, onPressed: () {}),
        );

        // The visible chip stays 40px; the InkWell tap target is padded out
        // to the 48dp minimum inside, so the footprint is 48 with no dead
        // (non-tappable) outer margin.
        final tapTarget = tester.getSize(find.byType(DivineButton));
        final chipSize = tester.getSize(find.byType(Ink));
        final inkWellSize = tester.getSize(find.byType(InkWell));
        expect(tapTarget.height, equals(48));
        expect(chipSize.height, equals(40));
        expect(inkWellSize.height, equals(40));
      });

      testWidgets(
        'small outer halo is tappable without expanding pressed ink',
        (tester) async {
          var taps = 0;
          await tester.pumpWidget(
            buildTestWidget(
              size: DivineButtonSize.small,
              onPressed: () => taps += 1,
            ),
          );

          final buttonTopLeft = tester.getTopLeft(find.byType(DivineButton));
          await tester.tapAt(buttonTopLeft + const Offset(2, 24));
          await tester.pump();

          expect(taps, equals(1));
          expect(tester.getSize(find.byType(DivineButton)).height, equals(48));
          expect(tester.getSize(find.byType(InkWell)).height, equals(40));
        },
      );

      testWidgets('small button stretches to fill a tight/Expanded slot', (
        tester,
      ) async {
        // The 48dp tap-target wrapper must not shrink-wrap a small button to
        // its label: inside an Expanded (tight width) the button fills the
        // slot, and the visible chip keeps its original 4px-each-side halo
        // (rowWidth - 8) rather than touching the slot's edges.
        const rowWidth = 300.0;
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: rowWidth,
                child: Row(
                  children: [
                    Expanded(
                      child: DivineButton(
                        label: 'Save',
                        size: DivineButtonSize.small,
                        onPressed: _noop,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(
          tester.getSize(find.byType(DivineButton)).width,
          equals(rowWidth),
        );
        expect(tester.getSize(find.byType(Ink)).width, equals(rowWidth - 8));
      });
    });

    group('accessibility', () {
      testWidgets('small meets the accessibility guidelines', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(size: DivineButtonSize.small, onPressed: () {}),
        );

        await expectMeetsAccessibilityGuidelines(tester);
      });

      testWidgets('base meets the accessibility guidelines', (tester) async {
        await tester.pumpWidget(buildTestWidget(onPressed: () {}));

        await expectMeetsAccessibilityGuidelines(tester);
      });

      testWidgets(
        'icon-only with semanticLabel meets the accessibility guidelines',
        (tester) async {
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: Center(
                  child: DivineButton(
                    label: '',
                    leadingIcon: DivineIconName.heart,
                    semanticLabel: 'Like',
                    onPressed: _noop,
                  ),
                ),
              ),
            ),
          );

          await expectMeetsAccessibilityGuidelines(tester);
        },
      );

      testWidgets(
        'icon-only disabled button with semanticLabel is not actionable',
        (tester) async {
          // A disabled labelled button must announce hasEnabledState +
          // isEnabled:false, so assistive tech doesn't present it as tappable
          // (matches DivineIconButton).
          final handle = tester.ensureSemantics();
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: Center(
                  child: DivineButton(
                    label: '',
                    leadingIcon: DivineIconName.heart,
                    semanticLabel: 'Like',
                    onPressed: null,
                  ),
                ),
              ),
            ),
          );

          expect(
            tester.getSemantics(find.byType(DivineButton)),
            isSemantics(
              label: 'Like',
              isButton: true,
              hasEnabledState: true,
              isEnabled: false,
            ),
          );
          handle.dispose();
        },
      );

      testWidgets('icon-only enabled button with semanticLabel is actionable', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: DivineButton(
                  label: '',
                  leadingIcon: DivineIconName.heart,
                  semanticLabel: 'Like',
                  onPressed: _noop,
                ),
              ),
            ),
          ),
        );

        expect(
          tester.getSemantics(find.byType(DivineButton)),
          isSemantics(
            label: 'Like',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
          ),
        );
        handle.dispose();
      });
    });

    group('label inner padding', () {
      // The inner padding is a render object (_AdaptiveButtonPadding), not a
      // Padding widget, so measure the resolved inset geometrically: the
      // content Row's offset within that box is the applied padding.
      final adaptiveFinder = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_AdaptiveButtonPadding',
      );

      EdgeInsets resolvedInnerPadding(WidgetTester tester) {
        final box = tester.getRect(adaptiveFinder);
        final content = tester.getRect(
          find.descendant(of: adaptiveFinder, matching: find.byType(Row)),
        );
        return EdgeInsets.fromLTRB(
          content.left - box.left,
          content.top - box.top,
          box.right - content.right,
          box.bottom - content.bottom,
        );
      }

      testWidgets(
        'base label uses 24px horizontal / 12px vertical inner padding',
        (tester) async {
          // A non-expanded labeled button hugs its content, so it keeps the
          // wider horizontal padding for visual balance.
          await tester.pumpWidget(
            buildTestWidget(label: 'Save', onPressed: () {}),
          );

          expect(
            resolvedInnerPadding(tester),
            const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          );
        },
      );

      testWidgets(
        'small label uses 16px horizontal / 8px vertical inner padding',
        (tester) async {
          await tester.pumpWidget(
            buildTestWidget(
              label: 'Save',
              size: DivineButtonSize.small,
              onPressed: () {},
            ),
          );

          expect(
            resolvedInnerPadding(tester),
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          );
        },
      );

      testWidgets(
        'tiny label uses 12px horizontal / 6px vertical inner padding',
        (tester) async {
          await tester.pumpWidget(
            buildTestWidget(
              label: 'Save',
              size: DivineButtonSize.tiny,
              onPressed: () {},
            ),
          );

          expect(
            resolvedInnerPadding(tester),
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          );
        },
      );

      testWidgets(
        'expanded label collapses to symmetric inner padding per size',
        (tester) async {
          // Expanded buttons are width-constrained by their parent, so the
          // extra horizontal padding is dropped to give the label the most
          // room before it ellipsizes.
          await tester.pumpWidget(
            buildTestWidget(label: 'Save', expanded: true, onPressed: () {}),
          );
          expect(resolvedInnerPadding(tester), const EdgeInsets.all(12));

          await tester.pumpWidget(
            buildTestWidget(
              label: 'Save',
              size: DivineButtonSize.small,
              expanded: true,
              onPressed: () {},
            ),
          );
          expect(resolvedInnerPadding(tester), const EdgeInsets.all(8));

          await tester.pumpWidget(
            buildTestWidget(
              label: 'Save',
              size: DivineButtonSize.tiny,
              expanded: true,
              onPressed: () {},
            ),
          );
          expect(resolvedInnerPadding(tester), const EdgeInsets.all(6));
        },
      );

      testWidgets(
        'non-expanded label keeps wider horizontal padding than icon-only',
        (tester) async {
          await tester.pumpWidget(
            buildTestWidget(label: 'Save', onPressed: () {}),
          );
          final labeledPadding = resolvedInnerPadding(tester);

          await tester.pumpWidget(
            buildTestWidget(
              label: '',
              leadingIcon: DivineIconName.heart,
              onPressed: () {},
            ),
          );
          final iconOnlyPadding = resolvedInnerPadding(tester);

          expect(labeledPadding.left, greaterThan(iconOnlyPadding.left));
          expect(labeledPadding.top, equals(iconOnlyPadding.top));
        },
      );

      testWidgets('expanded label matches icon-only inner padding', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(label: 'Save', expanded: true, onPressed: () {}),
        );
        final labeledPadding = resolvedInnerPadding(tester);

        await tester.pumpWidget(
          buildTestWidget(
            label: '',
            leadingIcon: DivineIconName.heart,
            onPressed: () {},
          ),
        );
        final iconOnlyPadding = resolvedInnerPadding(tester);

        expect(labeledPadding, equals(iconOnlyPadding));
      });

      testWidgets(
        'parent-forced tight width collapses to symmetric padding without '
        'the expanded flag',
        (tester) async {
          // Expanded inside a Row hands the button a tight width — it is
          // stretched even though expanded is false, so it should drop the
          // wider horizontal padding just like an expanded button.
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Row(
                  children: [
                    Expanded(
                      child: DivineButton(label: 'Save', onPressed: () {}),
                    ),
                  ],
                ),
              ),
            ),
          );

          expect(resolvedInnerPadding(tester), const EdgeInsets.all(12));
        },
      );

      testWidgets(
        'small parent-forced tight width still collapses to symmetric padding',
        (tester) async {
          // The small 48dp tap-target wrapper must keep passing the tight
          // width through to _AdaptiveButtonPadding: an Expanded small button
          // drops the wider horizontal inset just like base does.
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Row(
                  children: [
                    Expanded(
                      child: DivineButton(
                        label: 'Save',
                        size: DivineButtonSize.small,
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          expect(resolvedInnerPadding(tester), const EdgeInsets.all(8));
        },
      );

      testWidgets('long label ellipsizes instead of overflowing', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 120,
                  child: DivineButton(
                    label: 'A very long label that will not fit the width',
                    expanded: true,
                    onPressed: () {},
                  ),
                ),
              ),
            ),
          ),
        );

        final text = tester.widget<Text>(
          find.text('A very long label that will not fit the width'),
        );
        expect(text.maxLines, equals(1));
        expect(text.overflow, equals(TextOverflow.ellipsis));
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'renders inside IntrinsicHeight + stretched Row without errors',
        (tester) async {
          // Reproduces the context that throws "LayoutBuilder does not
          // support returning intrinsic dimensions": an ancestor probes the
          // button's intrinsic height. The render-object padding answers
          // intrinsics, so this must not throw.
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: DivineButton(label: 'Save', onPressed: () {}),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );

          expect(tester.takeException(), isNull);
          // Stretched by Expanded → tight width → symmetric inset.
          expect(resolvedInnerPadding(tester), const EdgeInsets.all(12));
        },
      );

      testWidgets('updates inner padding when size and expanded change', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(label: 'Save', onPressed: () {}),
        );
        expect(
          resolvedInnerPadding(tester),
          const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        );

        // base → tiny keeps the same tree position (neither size adds the
        // small-variant outer padding wrapper), so the render object is
        // updated in place: every inset field changes and its setters fire.
        await tester.pumpWidget(
          buildTestWidget(
            label: 'Save',
            size: DivineButtonSize.tiny,
            expanded: true,
            onPressed: () {},
          ),
        );
        expect(resolvedInnerPadding(tester), const EdgeInsets.all(6));
      });

      testWidgets('answers intrinsic and dry-layout queries for both states', (
        tester,
      ) async {
        for (final expanded in [false, true]) {
          await tester.pumpWidget(
            buildTestWidget(
              label: 'Save',
              expanded: expanded,
              onPressed: () {},
            ),
          );
          final box = tester.renderObject<RenderBox>(adaptiveFinder);

          expect(box.getMinIntrinsicWidth(double.infinity), greaterThan(0));
          expect(box.getMaxIntrinsicWidth(double.infinity), greaterThan(0));
          expect(box.getMinIntrinsicHeight(double.infinity), greaterThan(0));
          expect(box.getMaxIntrinsicHeight(double.infinity), greaterThan(0));
          expect(
            box.getDryLayout(const BoxConstraints(maxWidth: 200)).width,
            lessThanOrEqualTo(200),
          );
        }
      });

      testWidgets('dry baseline includes the top inset', (tester) async {
        // RenderShiftedBox's inherited computeDryBaseline omits padding.top,
        // so a missing override would report the parent baseline equal to the
        // child's instead of one inset lower. Assert the inset is added.
        await tester.pumpWidget(
          buildTestWidget(label: 'Save', onPressed: () {}),
        );
        final box = tester.renderObject<RenderBox>(adaptiveFinder);
        final child = tester.renderObject<RenderBox>(
          find.descendant(of: adaptiveFinder, matching: find.byType(Row)),
        );

        const constraints = BoxConstraints(maxWidth: 400);
        // Loose width on the base size resolves to the 24/12 inset.
        const padding = EdgeInsets.symmetric(horizontal: 24, vertical: 12);
        final parentBaseline = box.getDryBaseline(
          constraints,
          TextBaseline.alphabetic,
        );
        final childBaseline = child.getDryBaseline(
          constraints.deflate(padding),
          TextBaseline.alphabetic,
        );

        expect(parentBaseline, isNotNull);
        expect(childBaseline, isNotNull);
        expect(
          parentBaseline,
          moreOrLessEquals(childBaseline! + padding.top, epsilon: 0.5),
        );
      });
    });

    group('disabled state', () {
      testWidgets('shows reduced opacity when disabled', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        final animatedOpacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(animatedOpacity.opacity, 0.32);
      });

      testWidgets('error type has 0.5 opacity when disabled', (tester) async {
        await tester.pumpWidget(buildTestWidget(type: DivineButtonType.error));

        final animatedOpacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(animatedOpacity.opacity, 0.5);
      });

      testWidgets('shows full opacity when enabled', (tester) async {
        await tester.pumpWidget(buildTestWidget(onPressed: () {}));

        final animatedOpacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(animatedOpacity.opacity, 1.0);
      });
    });

    group('expanded mode', () {
      testWidgets('expands to fill available width when expanded is true', (
        tester,
      ) async {
        const containerWidth = 300.0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: containerWidth,
                  child: DivineButton(
                    label: 'Test',
                    expanded: true,
                    onPressed: () {},
                  ),
                ),
              ),
            ),
          ),
        );

        final buttonSize = tester.getSize(find.byType(DivineButton));
        expect(buttonSize.width, containerWidth);
      });

      testWidgets('works inside a Row with Expanded wrappers', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  Expanded(
                    child: DivineButton(
                      label: 'Cancel',
                      expanded: true,
                      type: DivineButtonType.secondary,
                      onPressed: () {},
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DivineButton(
                      label: 'Confirm',
                      expanded: true,
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        // Both buttons should render without overflow
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Confirm'), findsOneWidget);
      });
    });

    group('all types render in both sizes', () {
      for (final type in DivineButtonType.values) {
        for (final size in DivineButtonSize.values) {
          testWidgets('${type.name} renders in ${size.name} size', (
            tester,
          ) async {
            await tester.pumpWidget(
              buildTestWidget(type: type, size: size, onPressed: () {}),
            );

            expect(find.byType(DivineButton), findsOneWidget);
          });
        }
      }
    });

    group('loading state', () {
      testWidgets('renders CircularProgressIndicator when isLoading', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(isLoading: true, onPressed: () {}),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('does not render leading icon when isLoading', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            isLoading: true,
            leadingIcon: DivineIconName.envelope,
            onPressed: () {},
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(DivineIcon), findsNothing);
      });

      testWidgets('shows reduced opacity when isLoading', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(isLoading: true, onPressed: () {}),
        );

        final animatedOpacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(animatedOpacity.opacity, 0.32);
      });
    });

    group('all types render disabled', () {
      for (final type in DivineButtonType.values) {
        testWidgets('${type.name} renders disabled', (tester) async {
          await tester.pumpWidget(buildTestWidget(type: type));

          expect(find.byType(DivineButton), findsOneWidget);

          final animatedOpacity = tester.widget<AnimatedOpacity>(
            find.byType(AnimatedOpacity),
          );
          expect(animatedOpacity.opacity, lessThan(1.0));
        });
      }
    });

    group('icon-only mode (empty label)', () {
      testWidgets('tiny size uses DivineIconButton padding', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            label: '',
            leadingIcon: DivineIconName.heart,
            size: DivineButtonSize.tiny,
            onPressed: () {},
          ),
        );

        expect(find.byType(DivineButton), findsOneWidget);
        expect(find.byType(DivineIcon), findsOneWidget);
        expect(find.text(''), findsNothing);

        // Tiny icon-only chip is 6 + 20 + 6 = 32 visible; tiny keeps a 32px
        // tap target (no padding) so it stays flush with neighboring 32px
        // elements.
        final chipSize = tester.getSize(find.byType(Ink));
        final tapTarget = tester.getSize(find.byType(InkWell));
        expect(chipSize.height, equals(32));
        expect(tapTarget.height, equals(32));
      });

      testWidgets('small size uses DivineIconButton padding', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            label: '',
            leadingIcon: DivineIconName.heart,
            size: DivineButtonSize.small,
            onPressed: () {},
          ),
        );

        expect(find.byType(DivineButton), findsOneWidget);
        expect(find.byType(DivineIcon), findsOneWidget);
        expect(find.text(''), findsNothing);

        // Geometry parity with `DivineIconButton.small`: a 40x40 visible
        // chip inside a 48x48 tap target (DivineIconButton achieves the
        // same numbers via a fixed `SizedBox(48, 48)` wrapper — see
        // divine_icon_button.dart).
        final chipSize = tester.getSize(find.byType(Ink));
        final tapTarget = tester.getSize(find.byType(DivineButton));
        final inkWellSize = tester.getSize(find.byType(InkWell));
        expect(chipSize, equals(const Size(40, 40)));
        expect(tapTarget, equals(const Size(48, 48)));
        expect(inkWellSize, equals(const Size(40, 40)));
      });

      testWidgets('base size uses DivineIconButton padding', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            label: '',
            leadingIcon: DivineIconName.heart,
            onPressed: () {},
          ),
        );

        expect(find.byType(DivineButton), findsOneWidget);
        expect(find.byType(DivineIcon), findsOneWidget);
      });

      testWidgets('hides icon-to-label spacer', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            label: '',
            leadingIcon: DivineIconName.heart,
            onPressed: () {},
          ),
        );

        // Should have no SizedBox(width: 8) spacers between icon and label
        final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
        final spacers = sizedBoxes.where(
          (sb) => sb.width == 8 && sb.height == null,
        );
        expect(spacers, isEmpty);
      });
    });

    group('text scaling', () {
      Widget buildAtScale({required bool isLoading}) {
        return MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: Center(
                child: DivineButton(
                  label: 'Save',
                  onPressed: _noop,
                  leadingIcon: DivineIconName.check,
                  isLoading: isLoading,
                ),
              ),
            ),
          ),
        );
      }

      testWidgets('loading spinner occupies the same box as the icon it '
          'replaces', (tester) async {
        await tester.pumpWidget(buildAtScale(isLoading: false));
        final iconSize = tester.getSize(find.byType(SvgPicture));

        await tester.pumpWidget(buildAtScale(isLoading: true));
        final spinnerSize = tester.getSize(
          find.byType(CircularProgressIndicator),
        );

        expect(iconSize.width, closeTo(24 * DivineIcon.maxScaleFactor, 0.001));
        expect(spinnerSize, iconSize);
      });
    });
  });

  group('DivineTextLink', () {
    Widget buildTestWidget({String text = 'Link', VoidCallback? onTap}) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: DivineTextLink(text: text, onTap: onTap),
          ),
        ),
      );
    }

    testWidgets('renders with text', (tester) async {
      await tester.pumpWidget(buildTestWidget(text: 'Click here'));

      expect(find.text('Click here'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(buildTestWidget(onTap: () => tapped = true));

      await tester.tap(find.byType(DivineTextLink));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('does not call onTap when disabled', (tester) async {
      const tapped = false;
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.byType(DivineTextLink));
      await tester.pumpAndSettle();

      expect(tapped, isFalse);
    });

    group('span', () {
      testWidgets('creates TextSpan with correct text', (tester) async {
        final span = DivineTextLink.span(
          text: 'Link',
          onTap: () {},
          colors: VineTheme.darkColors,
        );

        expect(span.text, 'Link');
        expect(span.recognizer, isA<TapGestureRecognizer>());
      });

      testWidgets('span has no recognizer when onTap is null', (tester) async {
        final span = DivineTextLink.span(
          text: 'Disabled Link',
          onTap: null,
          colors: VineTheme.darkColors,
        );

        expect(span.text, 'Disabled Link');
        expect(span.recognizer, isNull);
      });

      testWidgets('span recognizer calls onTap', (tester) async {
        var tapped = false;
        final span = DivineTextLink.span(
          text: 'Link',
          onTap: () => tapped = true,
          colors: VineTheme.darkColors,
        );

        (span.recognizer! as TapGestureRecognizer).onTap!();

        expect(tapped, isTrue);
      });
    });
  });
}

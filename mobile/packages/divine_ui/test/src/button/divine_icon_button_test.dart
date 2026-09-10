// MaterialIconSource is deprecated but still fully supported; the
// fromSource group intentionally exercises it to guard that support, not
// migrate off it.
// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:ui' show Tristate;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/accessibility_guidelines.dart';

void main() {
  group('DivineIconButton', () {
    Widget buildTestWidget({
      DivineIconName icon = DivineIconName.x,
      VoidCallback? onPressed,
      VoidCallback? onLongPress,
      DivineIconButtonType type = DivineIconButtonType.primary,
      DivineIconButtonSize size = DivineIconButtonSize.base,
      Color? backgroundColor,
      Color? foregroundColor,
      bool showShadow = true,
      String? tooltip,
      String? semanticLabel,
      bool? semanticToggled,
      String? semanticIdentifier,
      String? semanticLongPressHint,
      ThemeData? theme,
    }) {
      return MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Center(
            child: DivineIconButton(
              icon: icon,
              onPressed: onPressed,
              onLongPress: onLongPress,
              type: type,
              size: size,
              backgroundColor: backgroundColor,
              foregroundColor: foregroundColor,
              showShadow: showShadow,
              tooltip: tooltip,
              semanticLabel: semanticLabel,
              semanticToggled: semanticToggled,
              semanticIdentifier: semanticIdentifier,
              semanticLongPressHint: semanticLongPressHint,
            ),
          ),
        ),
      );
    }

    group('rendering', () {
      testWidgets('renders with DivineIconName', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(onPressed: () {}),
        );

        expect(find.byType(DivineIcon), findsOneWidget);
        expect(find.byType(SvgPicture), findsOneWidget);
        expect(find.byType(DivineIconButton), findsOneWidget);
      });

      testWidgets('applies semantic label', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            semanticLabel: 'Close button',
            onPressed: () {},
          ),
        );

        expect(
          find.bySemanticsLabel('Close button'),
          findsOneWidget,
        );
      });

      testWidgets('applies semantic toggled state when set', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(semanticToggled: true, onPressed: () {}),
        );

        final semantics = tester.getSemantics(find.byType(DivineIconButton));
        expect(semantics.flagsCollection.isToggled, Tristate.isTrue);
      });

      testWidgets('has no toggled state when semanticToggled is null', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget(onPressed: () {}));

        final semantics = tester.getSemantics(find.byType(DivineIconButton));
        expect(semantics.flagsCollection.isToggled, Tristate.none);
      });

      testWidgets('applies semantic identifier', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            semanticIdentifier: 'settings_button',
            onPressed: () {},
          ),
        );

        final semantics = tester.getSemantics(find.byType(DivineIconButton));

        expect(semantics.identifier, equals('settings_button'));
      });

      testWidgets('leaves the identifier empty when not set', (tester) async {
        await tester.pumpWidget(buildTestWidget(onPressed: () {}));

        final semantics = tester.getSemantics(find.byType(DivineIconButton));

        expect(semantics.identifier, isEmpty);
      });

      testWidgets('identifier is independent of the label', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            semanticLabel: 'Settings',
            semanticIdentifier: 'settings_button',
            onPressed: () {},
          ),
        );

        final semantics = tester.getSemantics(find.byType(DivineIconButton));

        expect(semantics.identifier, equals('settings_button'));
        expect(semantics.label, equals('Settings'));
      });

      testWidgets('applies semantic long-press hint when set', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            semanticLongPressHint: 'Mute all tracks',
            onLongPress: () {},
          ),
        );

        final semantics = tester.getSemantics(find.byType(DivineIconButton));
        expect(semantics.hintOverrides?.onLongPressHint, 'Mute all tracks');
        expect(
          semantics.getSemanticsData().hasAction(SemanticsAction.longPress),
          isTrue,
        );
      });

      testWidgets(
        'has no long-press hint when semanticLongPressHint is null',
        (tester) async {
          await tester.pumpWidget(buildTestWidget(onPressed: () {}));

          final semantics = tester.getSemantics(
            find.byType(DivineIconButton),
          );
          expect(semantics.hintOverrides?.onLongPressHint, isNull);
        },
      );
    });

    group('interaction', () {
      testWidgets('calls onPressed when tapped', (tester) async {
        var pressed = false;
        await tester.pumpWidget(
          buildTestWidget(onPressed: () => pressed = true),
        );

        await tester.tap(find.byType(DivineIconButton));
        await tester.pumpAndSettle();

        expect(pressed, isTrue);
      });

      testWidgets('does not call onPressed when disabled', (tester) async {
        const pressed = false;
        await tester.pumpWidget(buildTestWidget());

        await tester.tap(find.byType(DivineIconButton));
        await tester.pumpAndSettle();

        expect(pressed, isFalse);
      });

      testWidgets('calls onLongPress when long-pressed', (tester) async {
        var longPressed = false;
        await tester.pumpWidget(
          buildTestWidget(
            onPressed: () {},
            onLongPress: () => longPressed = true,
          ),
        );

        await tester.longPress(find.byType(DivineIconButton));
        await tester.pumpAndSettle();

        expect(longPressed, isTrue);
      });

      testWidgets(
        'is enabled and fires onLongPress when only onLongPress is set',
        (tester) async {
          var longPressed = false;
          await tester.pumpWidget(
            buildTestWidget(onLongPress: () => longPressed = true),
          );

          await tester.longPress(find.byType(DivineIconButton));
          await tester.pumpAndSettle();

          expect(longPressed, isTrue);
        },
      );
    });

    group('icon sizing', () {
      testWidgets('small size renders 24px icon', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            size: DivineIconButtonSize.small,
            onPressed: () {},
          ),
        );

        final divineIcon = tester.widget<DivineIcon>(
          find.byType(DivineIcon),
        );
        expect(divineIcon.size, 24);
      });

      testWidgets('base size renders 24px icon', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            onPressed: () {},
          ),
        );

        final divineIcon = tester.widget<DivineIcon>(
          find.byType(DivineIcon),
        );
        expect(divineIcon.size, 24);
      });
    });

    group('tap target', () {
      testWidgets(
        'small size: InkWell tap target is 48x48 despite the 40px pill',
        (tester) async {
          await tester.pumpWidget(
            buildTestWidget(
              size: DivineIconButtonSize.small,
              onPressed: () {},
            ),
          );

          final inkWell = tester.widget<InkWell>(find.byType(InkWell));
          final sizedBox = inkWell.child! as SizedBox;
          expect(sizedBox.width, 48);
          expect(sizedBox.height, 48);
        },
      );

      testWidgets(
        'small size: tap outside the 40px pill but inside the 48px '
        'target still fires onPressed',
        (tester) async {
          var pressed = false;
          await tester.pumpWidget(
            buildTestWidget(
              size: DivineIconButtonSize.small,
              onPressed: () => pressed = true,
            ),
          );

          // 22px from center: outside the 40px visible pill (half-width
          // 20) but inside the 48px InkWell tap target (half-width 24).
          final center = tester.getCenter(find.byType(DivineIconButton));
          await tester.tapAt(center + const Offset(22, 0));
          await tester.pumpAndSettle();

          expect(pressed, isTrue);
        },
      );

      testWidgets(
        'small size occupies 48px regardless of whether the type has a border',
        (tester) async {
          // The border compensation belongs to `base`, where a border grows
          // the outer box. `small` already pins its outer size with an
          // explicit 48px tap-target box, so applying it there too made every
          // borderless type 52px and shifted any row mixing the two.
          final sizes = <DivineIconButtonType, Size>{};
          for (final type in [
            DivineIconButtonType.secondary,
            DivineIconButtonType.error,
            DivineIconButtonType.primary,
            DivineIconButtonType.ghost,
          ]) {
            await tester.pumpWidget(
              buildTestWidget(
                size: DivineIconButtonSize.small,
                type: type,
                onPressed: () {},
              ),
            );
            sizes[type] = tester.getSize(find.byType(DivineIconButton));
          }

          expect(
            sizes.values,
            everyElement(const Size(48, 48)),
            reason: 'got $sizes',
          );
        },
      );

      testWidgets(
        'base size: InkWell tap target matches the 48px pill exactly',
        (tester) async {
          await tester.pumpWidget(buildTestWidget(onPressed: () {}));

          final inkWell = tester.widget<InkWell>(find.byType(InkWell));
          expect(inkWell.child, isA<Ink>());
          expect(tester.getSize(find.byType(InkWell)), const Size(48, 48));
        },
      );
    });

    group('accessibility', () {
      testWidgets('with semanticLabel meets the accessibility guidelines', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(semanticLabel: 'Search', onPressed: () {}),
        );

        await expectMeetsAccessibilityGuidelines(tester);
      });

      testWidgets('small meets the accessibility guidelines', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            size: DivineIconButtonSize.small,
            semanticLabel: 'Search',
            onPressed: () {},
          ),
        );

        await expectMeetsAccessibilityGuidelines(tester);
      });
    });

    group('icon colors', () {
      testWidgets('foregroundColor override takes precedence', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            onPressed: () {},
            foregroundColor: Colors.purple,
          ),
        );

        final divineIcon = tester.widget<DivineIcon>(
          find.byType(DivineIcon),
        );
        expect(divineIcon.color, Colors.purple);
      });

      testWidgets('primary type uses onPrimary color', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            onPressed: () {},
          ),
        );

        final divineIcon = tester.widget<DivineIcon>(
          find.byType(DivineIcon),
        );
        expect(divineIcon.color, VineTheme.onPrimary);
      });

      testWidgets('secondary type uses primary color', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            type: DivineIconButtonType.secondary,
            onPressed: () {},
          ),
        );

        final divineIcon = tester.widget<DivineIcon>(
          find.byType(DivineIcon),
        );
        expect(divineIcon.color, VineTheme.primary);
      });

      testWidgets('secondary type uses onSurface in light mode', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            theme: VineTheme.lightTheme,
            type: DivineIconButtonType.secondary,
            onPressed: () {},
          ),
        );

        final divineIcon = tester.widget<DivineIcon>(
          find.byType(DivineIcon),
        );
        expect(divineIcon.color, VineTheme.lightColors.onSurface);
      });

      testWidgets('tertiary type uses inverseOnSurface color', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            type: DivineIconButtonType.tertiary,
            onPressed: () {},
          ),
        );

        final divineIcon = tester.widget<DivineIcon>(
          find.byType(DivineIcon),
        );
        expect(divineIcon.color, VineTheme.inverseOnSurface);
      });

      testWidgets('ghost type uses onSurface color', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            type: DivineIconButtonType.ghost,
            onPressed: () {},
          ),
        );

        final divineIcon = tester.widget<DivineIcon>(
          find.byType(DivineIcon),
        );
        expect(divineIcon.color, VineTheme.onSurface);
      });

      testWidgets('ghostSecondary type uses onSurface color', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            type: DivineIconButtonType.ghostSecondary,
            onPressed: () {},
          ),
        );

        final divineIcon = tester.widget<DivineIcon>(
          find.byType(DivineIcon),
        );
        expect(divineIcon.color, VineTheme.onSurface);
      });

      testWidgets('ghostSecondary type uses onSurface in light mode', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            theme: VineTheme.lightTheme,
            type: DivineIconButtonType.ghostSecondary,
            onPressed: () {},
          ),
        );

        final divineIcon = tester.widget<DivineIcon>(
          find.byType(DivineIcon),
        );
        expect(divineIcon.color, VineTheme.lightColors.onSurface);
      });

      testWidgets('ghostOverMedia type keeps the fixed light icon in light '
          'mode', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            theme: VineTheme.lightTheme,
            type: DivineIconButtonType.ghostOverMedia,
            onPressed: () {},
          ),
        );

        final divineIcon = tester.widget<DivineIcon>(
          find.byType(DivineIcon),
        );
        // A 15 % scrim over a video frame stays dark whatever the palette
        // says, so this variant must not follow it into the light palette.
        expect(divineIcon.color, VineTheme.onSurface);
        expect(divineIcon.color, isNot(VineTheme.lightColors.onSurface));
      });

      testWidgets('error type uses onErrorContainer color', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            type: DivineIconButtonType.error,
            onPressed: () {},
          ),
        );

        final divineIcon = tester.widget<DivineIcon>(
          find.byType(DivineIcon),
        );
        expect(divineIcon.color, VineTheme.onErrorContainer);
      });
    });

    group('background colors', () {
      testWidgets('backgroundColor override takes precedence', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            onPressed: () {},
            backgroundColor: Colors.orange,
          ),
        );

        final ink = tester.widget<Ink>(find.byType(Ink));
        final decoration = ink.decoration! as BoxDecoration;
        expect(decoration.color, Colors.orange);
      });
    });

    group('showShadow', () {
      testWidgets('shows a shadow by default when enabled', (tester) async {
        await tester.pumpWidget(buildTestWidget(onPressed: () {}));

        final ink = tester.widget<Ink>(find.byType(Ink));
        final decoration = ink.decoration! as BoxDecoration;
        expect(decoration.boxShadow, isNotNull);
        expect(decoration.boxShadow, isNotEmpty);
      });

      testWidgets('shows no shadow when showShadow is false', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(onPressed: () {}, showShadow: false),
        );

        final ink = tester.widget<Ink>(find.byType(Ink));
        final decoration = ink.decoration! as BoxDecoration;
        expect(decoration.boxShadow, isNull);
      });
    });

    group('button types', () {
      testWidgets('renders primary type', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            onPressed: () {},
          ),
        );

        expect(find.byType(DivineIconButton), findsOneWidget);
      });

      testWidgets('renders secondary type', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            type: DivineIconButtonType.secondary,
            onPressed: () {},
          ),
        );

        expect(find.byType(DivineIconButton), findsOneWidget);
      });

      testWidgets('renders tertiary type', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            type: DivineIconButtonType.tertiary,
            onPressed: () {},
          ),
        );

        expect(find.byType(DivineIconButton), findsOneWidget);
      });

      testWidgets('renders ghost type', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            type: DivineIconButtonType.ghost,
            onPressed: () {},
          ),
        );

        expect(find.byType(DivineIconButton), findsOneWidget);
      });

      testWidgets('renders ghostSecondary type', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            type: DivineIconButtonType.ghostSecondary,
            onPressed: () {},
          ),
        );

        expect(find.byType(DivineIconButton), findsOneWidget);
      });

      testWidgets('renders error type', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            type: DivineIconButtonType.error,
            onPressed: () {},
          ),
        );

        expect(find.byType(DivineIconButton), findsOneWidget);
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
        await tester.pumpWidget(
          buildTestWidget(type: DivineIconButtonType.error),
        );

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

    group('border-compensating outer padding', () {
      // No-border variants wrap their content in a 2px Padding to match the
      // visual footprint of the secondary type's 2px border.  Removing or
      // changing that compensation would silently reintroduce the size
      // mismatch this fix addressed.

      testWidgets(
        'no-border type (primary) applies 2px outer padding to compensate for '
        'missing border',
        (tester) async {
          await tester.pumpWidget(
            buildTestWidget(
              onPressed: () {},
            ),
          );

          // Walk up from AnimatedOpacity: the nearest Padding ancestor is the
          // border-compensation wrapper, not the inner icon padding.
          final compensatingPadding = tester.widget<Padding>(
            find
                .ancestor(
                  of: find.byType(AnimatedOpacity),
                  matching: find.byType(Padding),
                )
                .first,
          );
          expect(
            compensatingPadding.padding,
            equals(const EdgeInsets.all(2)),
          );
        },
      );

      testWidgets(
        'bordered type (secondary) applies no outer compensating padding',
        (tester) async {
          await tester.pumpWidget(
            buildTestWidget(
              type: DivineIconButtonType.secondary,
              onPressed: () {},
            ),
          );

          final compensatingPadding = tester.widget<Padding>(
            find
                .ancestor(
                  of: find.byType(AnimatedOpacity),
                  matching: find.byType(Padding),
                )
                .first,
          );
          expect(compensatingPadding.padding, equals(EdgeInsets.zero));
        },
      );
    });

    group('all types render in both sizes', () {
      for (final type in DivineIconButtonType.values) {
        for (final size in DivineIconButtonSize.values) {
          testWidgets(
            '${type.name} renders in ${size.name} size',
            (tester) async {
              await tester.pumpWidget(
                buildTestWidget(
                  type: type,
                  size: size,
                  onPressed: () {},
                ),
              );

              expect(find.byType(DivineIconButton), findsOneWidget);
            },
          );
        }
      }
    });

    group('all types render disabled', () {
      for (final type in DivineIconButtonType.values) {
        testWidgets('${type.name} renders disabled', (tester) async {
          await tester.pumpWidget(buildTestWidget(type: type));

          expect(find.byType(DivineIconButton), findsOneWidget);

          final animatedOpacity = tester.widget<AnimatedOpacity>(
            find.byType(AnimatedOpacity),
          );
          expect(animatedOpacity.opacity, lessThan(1.0));
        });
      }
    });

    group('tooltip', () {
      testWidgets('renders tooltip when provided', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(onPressed: () {}, tooltip: 'Close'),
        );

        expect(find.byType(Tooltip), findsOneWidget);
      });

      testWidgets('does not render tooltip when not provided', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget(onPressed: () {}));

        expect(find.byType(Tooltip), findsNothing);
      });

      testWidgets('tooltip has correct message', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(onPressed: () {}, tooltip: 'Custom tooltip'),
        );

        final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
        expect(tooltip.message, 'Custom tooltip');
      });

      testWidgets(
        'is not announced when it repeats the semantic label',
        (tester) async {
          await tester.pumpWidget(
            buildTestWidget(
              onPressed: () {},
              tooltip: 'Copy public key',
              semanticLabel: 'Copy public key',
            ),
          );

          final semantics = tester.getSemantics(find.byType(DivineIconButton));
          expect(semantics.label, 'Copy public key');
          expect(semantics.tooltip, isEmpty);
        },
      );

      testWidgets(
        'is announced when it adds to the semantic label',
        (tester) async {
          await tester.pumpWidget(
            buildTestWidget(
              onPressed: () {},
              tooltip: 'Copies the key to your clipboard',
              semanticLabel: 'Copy public key',
            ),
          );

          final semantics = tester.getSemantics(find.byType(DivineIconButton));
          expect(semantics.label, 'Copy public key');
          expect(semantics.tooltip, 'Copies the key to your clipboard');
        },
      );
    });

    group('fromSource', () {
      Widget buildFromSourceWidget({
        required IconSource icon,
        VoidCallback? onPressed,
        Color? foregroundColor,
        String? tooltip,
      }) {
        return MaterialApp(
          home: Scaffold(
            body: Center(
              child: DivineIconButton.fromSource(
                icon: icon,
                onPressed: onPressed,
                foregroundColor: foregroundColor,
                tooltip: tooltip,
              ),
            ),
          ),
        );
      }

      testWidgets('renders an SvgIconSource icon', (tester) async {
        await tester.pumpWidget(
          buildFromSourceWidget(
            icon: const SvgIconSource('assets/icon/CaretLeft.svg'),
            onPressed: () {},
          ),
        );

        expect(find.byType(SvgPicture), findsOneWidget);
        expect(find.byType(DivineIcon), findsNothing);
      });

      testWidgets('renders a MaterialIconSource icon', (tester) async {
        await tester.pumpWidget(
          buildFromSourceWidget(
            icon: const MaterialIconSource(Icons.arrow_back),
            onPressed: () {},
          ),
        );

        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      });

      testWidgets('applies foregroundColor to a MaterialIconSource icon', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildFromSourceWidget(
            icon: const MaterialIconSource(Icons.arrow_back),
            onPressed: () {},
            foregroundColor: Colors.purple,
          ),
        );

        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.color, Colors.purple);
      });

      testWidgets('applies color filter to an SvgIconSource icon', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildFromSourceWidget(
            icon: const SvgIconSource('assets/icon/CaretLeft.svg'),
            onPressed: () {},
            foregroundColor: Colors.red,
          ),
        );

        final svgPicture = tester.widget<SvgPicture>(find.byType(SvgPicture));
        expect(
          svgPicture.colorFilter,
          const ColorFilter.mode(Colors.red, BlendMode.srcIn),
        );
      });

      testWidgets('renders tooltip when provided', (tester) async {
        await tester.pumpWidget(
          buildFromSourceWidget(
            icon: const MaterialIconSource(Icons.arrow_back),
            onPressed: () {},
            tooltip: 'Go back',
          ),
        );

        expect(find.byType(Tooltip), findsOneWidget);
      });

      testWidgets('calls onPressed when tapped', (tester) async {
        var pressed = false;
        await tester.pumpWidget(
          buildFromSourceWidget(
            icon: const MaterialIconSource(Icons.arrow_back),
            onPressed: () => pressed = true,
          ),
        );

        await tester.tap(find.byType(DivineIconButton));
        await tester.pumpAndSettle();

        expect(pressed, isTrue);
      });
    });

    group('text scaling', () {
      Widget buildAtScale(Widget button) {
        return MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(body: Center(child: button)),
          ),
        );
      }

      testWidgets('renders the same icon size whichever source it is built '
          'from', (tester) async {
        await tester.pumpWidget(
          buildAtScale(
            DivineIconButton(icon: DivineIconName.x, onPressed: () {}),
          ),
        );
        final fromName = tester
            .widget<SvgPicture>(find.byType(SvgPicture))
            .width;

        await tester.pumpWidget(
          buildAtScale(
            DivineIconButton.fromSource(
              icon: SvgIconSource(DivineIconName.x.assetPath),
              onPressed: () {},
            ),
          ),
        );
        final fromSvgSource = tester
            .widget<SvgPicture>(find.byType(SvgPicture))
            .width;

        await tester.pumpWidget(
          buildAtScale(
            DivineIconButton.fromSource(
              icon: const MaterialIconSource(Icons.close),
              onPressed: () {},
            ),
          ),
        );
        final fromMaterialSource = tester.widget<Icon>(find.byType(Icon)).size;

        expect(fromName, closeTo(24 * DivineIcon.maxScaleFactor, 0.001));
        expect(fromSvgSource, fromName);
        expect(fromMaterialSource, fromName);
      });

      testWidgets('caps the small variant tap target with the icon', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildAtScale(
            DivineIconButton(
              icon: DivineIconName.x,
              size: DivineIconButtonSize.small,
              onPressed: () {},
            ),
          ),
        );

        final tapTarget = tester.getSize(
          find
              .descendant(
                of: find.byType(DivineIconButton),
                matching: find.byType(SizedBox),
              )
              .first,
        );

        expect(tapTarget.width, closeTo(48 * DivineIcon.maxScaleFactor, 0.001));
        expect(tapTarget.height, tapTarget.width);
      });
    });
  });
}

// ABOUTME: Widget tests for TimelineTrimHandles.
// ABOUTME: Validates handle rendering, drag callbacks, and configurability.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/timeline_trim_handles.dart';

void main() {
  group(TimelineTrimHandles, () {
    Widget buildWidget({
      TrimDragCallback? onLeftDragUpdate,
      TrimDragCallback? onRightDragUpdate,
      VoidCallback? onDragStart,
      VoidCallback? onDragEnd,
      Color? handleColor,
      double width = 300,
      double? trimWidth,
      double height = TimelineConstants.thumbnailStripHeight,
      double handleWidth = TimelineConstants.trimHandleWidth,
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: TimelineTrimHandles(
                height: height,
                width: trimWidth,
                onLeftDragUpdate: onLeftDragUpdate,
                onRightDragUpdate: onRightDragUpdate,
                onDragStart: onDragStart,
                onDragEnd: onDragEnd,
                handleColor: handleColor ?? VineTheme.accentYellow,
                handleWidth: handleWidth,
                child: const ColoredBox(
                  color: Colors.blue,
                  child: SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('renders $TimelineTrimHandles', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.byType(TimelineTrimHandles), findsOneWidget);
      });

      testWidgets('renders child between handles', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.byType(ColoredBox), findsWidgets);
      });

      testWidgets('renders two GestureDetectors for handles', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.byType(GestureDetector), findsNWidgets(2));
      });

      testWidgets('renders border with handle color', (tester) async {
        const color = Colors.red;
        await tester.pumpWidget(buildWidget(handleColor: color));

        final decorated = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(TimelineTrimHandles),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final decoration = decorated.decoration as BoxDecoration;
        expect(decoration.border, isNotNull);
        expect((decoration.border! as Border).top.color, equals(color));
      });

      testWidgets('uses configured height', (tester) async {
        const height = 80.0;
        await tester.pumpWidget(buildWidget(height: height));

        final box = tester.renderObject<RenderBox>(
          find.byType(TimelineTrimHandles),
        );
        expect(box.size.height, equals(height));
      });
    });

    /// Returns the global top-left of the [TimelineTrimHandles] widget.
    /// Handle hit areas overlap the content by [borderWidth] at each
    /// edge, so dragging from x ≈ 1 hits the left handle and from
    /// x ≈ width - 1 hits the right handle.
    Offset handleOrigin(WidgetTester tester) {
      final box = tester.renderObject<RenderBox>(
        find.byType(TimelineTrimHandles),
      );
      return box.localToGlobal(Offset.zero);
    }

    bool hitTestsAt(WidgetTester tester, Offset localPosition) {
      final box = tester.renderObject<RenderBox>(
        find.byType(TimelineTrimHandles),
      );
      return box.hitTest(BoxHitTestResult(), position: localPosition);
    }

    double baseOutwardHit({
      double handleWidth = TimelineConstants.trimHandleWidth,
    }) {
      return handleWidth -
          TimelineConstants.trimBorderWidth +
          TimelineConstants.trimHitAreaExtra / 2;
    }

    double narrowOutwardHit(
      double trimWidth, {
      double handleWidth = TimelineConstants.trimHandleWidth,
    }) {
      const defaultInward =
          TimelineConstants.trimHitAreaExtra / 2 +
          TimelineConstants.trimBorderWidth;
      final clampedInward = defaultInward.clamp(0.0, trimWidth / 2);
      return baseOutwardHit(handleWidth: handleWidth) +
          (defaultInward - clampedInward);
    }

    group('left handle drag', () {
      testWidgets('calls onDragStart on drag begin', (tester) async {
        var started = false;
        await tester.pumpWidget(buildWidget(onDragStart: () => started = true));

        final origin = handleOrigin(tester);
        final box = tester.renderObject<RenderBox>(
          find.byType(TimelineTrimHandles),
        );
        final from = origin + Offset(1, box.size.height / 2);

        await tester.dragFrom(from, const Offset(10, 0));
        await tester.pumpAndSettle();

        expect(started, isTrue);
      });

      testWidgets('calls onLeftDragUpdate with dx', (tester) async {
        final deltas = <double>[];
        await tester.pumpWidget(buildWidget(onLeftDragUpdate: deltas.add));

        final origin = handleOrigin(tester);
        final box = tester.renderObject<RenderBox>(
          find.byType(TimelineTrimHandles),
        );
        final from = origin + Offset(1, box.size.height / 2);

        await tester.dragFrom(from, const Offset(20, 0));
        await tester.pumpAndSettle();

        expect(deltas, isNotEmpty);
      });

      testWidgets('calls onDragEnd on drag end', (tester) async {
        var ended = false;
        await tester.pumpWidget(buildWidget(onDragEnd: () => ended = true));

        final origin = handleOrigin(tester);
        final box = tester.renderObject<RenderBox>(
          find.byType(TimelineTrimHandles),
        );
        final from = origin + Offset(1, box.size.height / 2);

        await tester.dragFrom(from, const Offset(10, 0));
        await tester.pumpAndSettle();

        expect(ended, isTrue);
      });
    });

    group('right handle drag', () {
      testWidgets('calls onRightDragUpdate with dx', (tester) async {
        final deltas = <double>[];
        await tester.pumpWidget(buildWidget(onRightDragUpdate: deltas.add));

        final origin = handleOrigin(tester);
        final box = tester.renderObject<RenderBox>(
          find.byType(TimelineTrimHandles),
        );
        final from = origin + Offset(box.size.width - 1, box.size.height / 2);

        await tester.dragFrom(from, const Offset(-20, 0));
        await tester.pumpAndSettle();

        expect(deltas, isNotEmpty);
      });

      testWidgets('calls onDragStart on right handle drag', (tester) async {
        var started = false;
        await tester.pumpWidget(buildWidget(onDragStart: () => started = true));

        final origin = handleOrigin(tester);
        final box = tester.renderObject<RenderBox>(
          find.byType(TimelineTrimHandles),
        );
        final from = origin + Offset(box.size.width - 1, box.size.height / 2);

        await tester.dragFrom(from, const Offset(-10, 0));
        await tester.pumpAndSettle();

        expect(started, isTrue);
      });

      testWidgets('accepts a drag from inside the right clip edge', (
        tester,
      ) async {
        final deltas = <double>[];
        await tester.pumpWidget(buildWidget(onRightDragUpdate: deltas.add));

        final origin = handleOrigin(tester);
        final box = tester.renderObject<RenderBox>(
          find.byType(TimelineTrimHandles),
        );
        final from =
            origin +
            Offset(
              box.size.width - (TimelineConstants.trimHitAreaExtra / 2),
              box.size.height / 2,
            );

        await tester.dragFrom(from, const Offset(-20, 0));
        await tester.pumpAndSettle();

        expect(deltas, isNotEmpty);
      });
    });

    group('narrow widths', () {
      testWidgets(
        'extends left hit testing beyond the original outward range',
        (tester) async {
          const trimWidth = 20.0;
          await tester.pumpWidget(
            buildWidget(width: trimWidth, trimWidth: trimWidth),
          );

          final box = tester.renderObject<RenderBox>(
            find.byType(TimelineTrimHandles),
          );
          final outwardHit = narrowOutwardHit(trimWidth);
          final originalOutwardHit = baseOutwardHit();
          final probeX =
              -(originalOutwardHit + (outwardHit - originalOutwardHit) / 2);

          expect(
            hitTestsAt(tester, Offset(probeX, box.size.height / 2)),
            isTrue,
          );
        },
      );

      testWidgets(
        'extends right hit testing beyond the original outward range',
        (tester) async {
          const trimWidth = 20.0;
          await tester.pumpWidget(
            buildWidget(width: trimWidth, trimWidth: trimWidth),
          );

          final box = tester.renderObject<RenderBox>(
            find.byType(TimelineTrimHandles),
          );
          final outwardHit = narrowOutwardHit(trimWidth);
          final originalOutwardHit = baseOutwardHit();
          final probeX =
              box.size.width +
              originalOutwardHit +
              (outwardHit - originalOutwardHit) / 2;

          expect(
            hitTestsAt(tester, Offset(probeX, box.size.height / 2)),
            isTrue,
          );
        },
      );

      testWidgets('keeps left and right hit areas separated at the midpoint', (
        tester,
      ) async {
        final leftDeltas = <double>[];
        final rightDeltas = <double>[];
        const trimWidth = 20.0;
        await tester.pumpWidget(
          buildWidget(
            width: trimWidth,
            trimWidth: trimWidth,
            onLeftDragUpdate: leftDeltas.add,
            onRightDragUpdate: rightDeltas.add,
          ),
        );

        final origin = handleOrigin(tester);
        final box = tester.renderObject<RenderBox>(
          find.byType(TimelineTrimHandles),
        );
        final leftFrom =
            origin + Offset(trimWidth / 2 - 1, box.size.height / 2);
        final rightFrom =
            origin + Offset(trimWidth / 2 + 1, box.size.height / 2);

        await tester.dragFrom(leftFrom, const Offset(8, 0));
        await tester.pumpAndSettle();

        expect(leftDeltas, isNotEmpty);
        expect(rightDeltas, isEmpty);

        leftDeltas.clear();
        rightDeltas.clear();

        await tester.dragFrom(rightFrom, const Offset(-8, 0));
        await tester.pumpAndSettle();

        expect(leftDeltas, isEmpty);
        expect(rightDeltas, isNotEmpty);
      });
    });

    group('defaults', () {
      testWidgets('uses $VineTheme accentYellow as default handle color', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());

        final decorated = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(TimelineTrimHandles),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final decoration = decorated.decoration as BoxDecoration;
        expect(
          (decoration.border! as Border).top.color,
          equals(VineTheme.accentYellow),
        );
      });
    });
  });
}

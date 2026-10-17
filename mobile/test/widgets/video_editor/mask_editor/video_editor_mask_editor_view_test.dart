// ABOUTME: Tests the shape mask editor: picking a shape, inverting it, moving
// ABOUTME: and stretching it by touch, and what it closes with.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/editor_mask.dart';
import 'package:openvine/widgets/video_editor/mask_editor/video_editor_mask_editor_view.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show LayerMask, LayerMaskShape;

import '../../../helpers/test_provider_overrides.dart';

void main() {
  // The item: a 200 x 400 box whose top-left sits at (100, 100) on screen.
  const boxSize = Size(200, 400);
  final geometry = (
    size: boxSize,
    transform: Matrix4.translationValues(100, 100, 0),
  );

  group(VideoEditorMaskEditorView, () {
    late List<LayerMask?> changes;

    setUp(() => changes = []);

    Widget buildEditor({LayerMask? initialMask}) => testMaterialApp(
      home: VideoEditorMaskEditorView(
        initialMask: initialMask,
        resolveGeometry: () => geometry,
        canvasChanges: ValueNotifier<int>(0),
        onChanged: changes.add,
      ),
    );

    AppLocalizations l10nOf(WidgetTester tester) => AppLocalizations.of(
      tester.element(find.byType(VideoEditorMaskEditorView)),
    );

    group('interactions', () {
      testWidgets('picks a shape, and None removes it', (tester) async {
        await tester.pumpWidget(buildEditor());
        await tester.pump();
        final l10n = l10nOf(tester);

        await tester.tap(find.bySemanticsLabel(l10n.videoEditorShapeMaskHeart));
        await tester.pump();
        await tester.tap(find.bySemanticsLabel(l10n.videoEditorShapeMaskNone));
        await tester.pump();

        expect(changes, [
          editorMaskForShape(LayerMaskShape.heart, boxSize: boxSize),
          null,
        ]);
      });

      testWidgets('inverts the mask', (tester) async {
        const circle = LayerMask(shape: LayerMaskShape.ellipse);
        await tester.pumpWidget(buildEditor(initialMask: circle));
        await tester.pump();

        await tester.tap(
          find.bySemanticsLabel(l10nOf(tester).videoEditorShapeMaskInvert),
        );
        await tester.pump();

        expect(changes, [circle.copyWith(invert: true)]);
      });

      testWidgets('moves the shape with one finger', (tester) async {
        const circle = LayerMask(shape: LayerMaskShape.ellipse);
        await tester.pumpWidget(buildEditor(initialMask: circle));
        await tester.pump();

        // From the shape's centre, 20 px right and 40 px down on a 200 x 400
        // box: a tenth of the way along each side.
        await tester.dragFrom(
          const Offset(200, 300),
          const Offset(20, 40),
          touchSlopX: 0,
          touchSlopY: 0,
        );
        await tester.pump();

        expect(changes.last!.center.dx, closeTo(0.6, 0.001));
        expect(changes.last!.center.dy, closeTo(0.6, 0.001));
        expect(changes.last!.size, circle.size);
      });

      testWidgets('stops the shape at the edge of the item', (tester) async {
        // 100 x 100 px on the box.
        const circle = LayerMask(
          shape: LayerMaskShape.ellipse,
          size: Size(0.5, 0.25),
        );
        await tester.pumpWidget(buildEditor(initialMask: circle));
        await tester.pump();

        await tester.dragFrom(
          const Offset(200, 300),
          const Offset(300, 0),
          touchSlopX: 0,
          touchSlopY: 0,
        );
        await tester.pump();

        // Its right edge rests on the item's.
        expect(changes.last!.center.dx, closeTo(0.75, 0.001));
      });

      testWidgets('keeps a shape pinched bigger on the item', (tester) async {
        const circle = LayerMask(
          shape: LayerMaskShape.ellipse,
          center: Offset(0.3, 0.5),
          size: Size(0.3, 0.15),
        );
        await tester.pumpWidget(buildEditor(initialMask: circle));
        await tester.pump();

        // Two fingers on the shape, spread far past both sides of the item.
        // A second finger always makes the gesture a pinch, even when the
        // first one landed on a resize handle, so where they land on the
        // shape does not matter. Neither passes `pointer:`: a fixed id can
        // equal the automatic one the other finger takes from flutter_test's
        // shared counter (#10245).
        final first = await tester.startGesture(const Offset(150, 300));
        final second = await tester.startGesture(const Offset(170, 300));
        await tester.pump();
        for (var step = 1; step <= 10; step++) {
          await first.moveTo(Offset(150 - step * 30, 300));
          await second.moveTo(Offset(170 + step * 30, 300));
          await tester.pump();
        }
        await first.up();
        await second.up();
        await tester.pump();

        expect(changes, isNotEmpty);
        final mask = changes.last!;
        final halfWidth = mask.size.width / 2;
        expect(mask.size.width, greaterThan(circle.size.width));
        expect(mask.center.dx - halfWidth, greaterThanOrEqualTo(-0.0001));
        expect(mask.center.dx + halfWidth, lessThanOrEqualTo(1.0001));
      });

      testWidgets('stops a side handle where the shape touches the edge', (
        tester,
      ) async {
        const circle = LayerMask(
          shape: LayerMaskShape.ellipse,
          center: Offset(0.7, 0.5),
          size: Size(0.2, 0.1),
        );
        await tester.pumpWidget(buildEditor(initialMask: circle));
        await tester.pump();

        // The width handle sits 20 px right of the centre, at (260, 300).
        await tester.dragFrom(
          const Offset(260, 300),
          const Offset(200, 0),
          touchSlopX: 0,
          touchSlopY: 0,
        );
        await tester.pump();

        // 0.3 from the right edge: 0.6 of the item wide around its centre.
        expect(changes.last!.size.width, closeTo(0.6, 0.001));
        expect(changes.last!.center, circle.center);
      });

      testWidgets('stretches the shape by its side handle', (tester) async {
        const circle = LayerMask(
          shape: LayerMaskShape.ellipse,
          size: Size(0.5, 0.25),
        );
        await tester.pumpWidget(buildEditor(initialMask: circle));
        await tester.pump();

        // The width handle sits half the shape's width right of its centre.
        await tester.dragFrom(
          const Offset(250, 300),
          const Offset(30, 0),
          touchSlopX: 0,
          touchSlopY: 0,
        );
        await tester.pump();

        expect(changes.last!.size.width, closeTo(0.8, 0.001));
        expect(changes.last!.size.height, 0.25);
        expect(changes.last!.center, circle.center);
      });

      testWidgets('closes with the mask on done and with nothing on cancel', (
        tester,
      ) async {
        final results = <MaskEditorResult?>[];
        await tester.pumpWidget(
          testMaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  results.add(
                    await Navigator.of(context).push<MaskEditorResult>(
                      MaterialPageRoute(
                        builder: (_) => VideoEditorMaskEditorView(
                          initialMask: null,
                          resolveGeometry: () => geometry,
                          canvasChanges: ValueNotifier<int>(0),
                          onChanged: changes.add,
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        final l10n = l10nOf(tester);
        await tester.tap(
          find.bySemanticsLabel(l10n.videoEditorShapeMaskCircle),
        );
        await tester.pump();
        await tester.tap(find.bySemanticsLabel(l10n.videoEditorDoneLabel));
        await tester.pumpAndSettle();

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel(l10n.commonCancel));
        await tester.pumpAndSettle();

        expect(results, [
          (mask: editorMaskForShape(LayerMaskShape.ellipse, boxSize: boxSize)),
          null,
        ]);
      });
    });

    group('renders', () {
      testWidgets('offers the corners only for a rectangle', (tester) async {
        await tester.pumpWidget(
          buildEditor(
            initialMask: const LayerMask(shape: LayerMaskShape.rectangle),
          ),
        );
        await tester.pump();
        final l10n = l10nOf(tester);

        expect(find.text(l10n.videoEditorShapeMaskSoftnessLabel), findsOne);
        expect(find.text(l10n.videoEditorShapeMaskCornersLabel), findsOne);

        await tester.tap(find.bySemanticsLabel(l10n.videoEditorShapeMaskHeart));
        await tester.pump();

        expect(find.text(l10n.videoEditorShapeMaskCornersLabel), findsNothing);
      });

      testWidgets('offers no sliders without a mask', (tester) async {
        await tester.pumpWidget(buildEditor());
        await tester.pump();

        expect(
          find.text(l10nOf(tester).videoEditorShapeMaskSoftnessLabel),
          findsNothing,
        );
      });
    });
  });

  group('maskResizedTowards', () {
    test('stretches the side along the turned shape, keeping its centre', () {
      // Turned a quarter: its width now runs down the box.
      const mask = LayerMask(
        shape: LayerMaskShape.rectangle,
        size: Size(0.2, 0.1),
        rotation: math.pi / 2,
      );

      final stretched = maskResizedTowards(
        mask,
        boxSize,
        const Offset(100, 320),
        horizontal: true,
      );

      // 120 px below the centre is a half width of 120 px.
      expect(stretched.size.width, closeTo(1.2, 0.001));
      expect(stretched.size.height, 0.1);
      expect(stretched.center, mask.center);
    });
  });

  group('maskHandles', () {
    test('sit on the middle of the right and bottom sides', () {
      const mask = LayerMask(
        shape: LayerMaskShape.ellipse,
        size: Size(0.5, 0.25),
      );

      final handles = maskHandles(mask, boxSize);

      expect(handles.width, const Offset(150, 200));
      expect(handles.height, const Offset(100, 250));
    });
  });
}

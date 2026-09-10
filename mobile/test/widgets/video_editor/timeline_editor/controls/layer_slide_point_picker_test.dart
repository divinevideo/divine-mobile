// ABOUTME: Tests the full-screen slide-point picker: the canvas projection it
// ABOUTME: maps touches through, and the placing / cancelling it hands back.

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/layer_slide_point_picker.dart';
import 'package:pro_image_editor/core/models/layers/layer.dart' show Layer;
import 'package:pro_video_editor/pro_video_editor.dart' show AnimationPhase;

import '../../../../helpers/test_provider_overrides.dart';

/// A scale+translate editor matrix, the shape the editor's
/// `onEditorZoomMatrix4Change` reports for a pinch (no rotation or skew).
Matrix4 _editorZoom({double scale = 1, double tx = 0, double ty = 0}) =>
    Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(0, 3, tx)
      ..setEntry(1, 3, ty);

void main() {
  // A 9:16 canvas cover-fitted into a wider body: the render surface overhangs
  // the visible area, which is the case a naive body-relative mapping gets
  // wrong.
  const bodyRect = Rect.fromLTWH(0, 100, 400, 600);
  const canvasSize = Size(360, 640);

  LayerCanvasProjection projectionWith({
    double coverScale = 0.9375,
    Matrix4? zoom,
    Rect rect = bodyRect,
    Size canvas = canvasSize,
  }) => LayerCanvasProjection(
    bodyRect: rect,
    canvasSize: canvas,
    coverScale: coverScale,
    zoom: zoom ?? Matrix4.identity(),
  );

  group(LayerCanvasProjection, () {
    group('isUsable', () {
      test('is true for a canvas that can be mapped', () {
        expect(projectionWith().isUsable, isTrue);
      });

      test('is false for a zero-sized canvas', () {
        expect(projectionWith(canvas: Size.zero).isUsable, isFalse);
        expect(projectionWith(canvas: const Size(0, 640)).isUsable, isFalse);
      });

      test('is false for a non-positive cover scale', () {
        expect(projectionWith(coverScale: 0).isUsable, isFalse);
        expect(projectionWith(coverScale: -1).isUsable, isFalse);
      });
    });

    group('toScreen', () {
      test('puts the canvas centre in the middle of the body', () {
        expect(projectionWith().toScreen(Offset.zero), equals(bodyRect.center));
      });

      test('scales a layer offset by the cover fit', () {
        final screen = projectionWith().toScreen(const Offset(80, -40));

        expect(
          screen,
          equals(bodyRect.center + const Offset(80, -40) * 0.9375),
        );
      });

      test('follows the editor zoom', () {
        final zoom = _editorZoom(scale: 2, tx: 30, ty: -20);

        // A zoom scales and translates in canvas pixels, before the canvas is
        // cover-fitted into the body — the same order the letterbox scrim uses.
        final absolute = Offset(canvasSize.width / 2, canvasSize.height / 2);
        final expected =
            bodyRect.topLeft +
            Offset(
              (bodyRect.width - 0.9375 * canvasSize.width) / 2,
              (bodyRect.height - 0.9375 * canvasSize.height) / 2,
            ) +
            (absolute * 2 + const Offset(30, -20)) * 0.9375;

        expect(
          projectionWith(zoom: zoom).toScreen(Offset.zero),
          equals(expected),
        );
      });
    });

    group('toFraction', () {
      test('is the inverse of toScreen', () {
        const layerPoint = Offset(-120, 210);
        final projection = projectionWith();

        final fraction = projection.toFraction(
          projection.toScreen(layerPoint),
        )!;

        expect(
          projection.screenOfFraction(fraction),
          within(distance: 0.001, from: projection.toScreen(layerPoint)),
        );
      });

      test('is the inverse of toScreen while zoomed', () {
        const layerPoint = Offset(-120, 210);
        final projection = projectionWith(
          zoom: _editorZoom(scale: 1.75, tx: -42, ty: 18),
        );

        final fraction = projection.toFraction(
          projection.toScreen(layerPoint),
        )!;

        expect(
          projection.screenOfFraction(fraction),
          within(distance: 0.001, from: projection.toScreen(layerPoint)),
        );
      });

      test('reads the body centre as the canvas centre', () {
        expect(
          projectionWith().toFraction(bodyRect.center),
          equals(Offset.zero),
        );
      });

      // A touch in the letterbox band still names a place, just one outside the
      // frame — which is exactly what a slide starting off-screen needs.
      test('maps a touch outside the frame to a fraction beyond it', () {
        final fraction = projectionWith().toFraction(
          bodyRect.topLeft - const Offset(20, 20),
        )!;

        expect(fraction.dx, lessThan(-0.5));
        expect(fraction.dy, lessThan(-0.5));
      });
    });
  });

  group(LayerSlidePointPickerView, () {
    late Layer layer;

    setUp(() {
      layer = Layer(offset: const Offset(40, -60));
    });

    Widget buildPicker({
      AnimationPhase phase = AnimationPhase.animateIn,
      Offset? initialFraction,
      LayerCanvasProjection? projection,
      Listenable? canvasChanges,
    }) => testMaterialApp(
      home: LayerSlidePointPickerView(
        resolveProjection: () => projection ?? projectionWith(),
        canvasChanges: canvasChanges ?? ValueNotifier<int>(0),
        layer: layer,
        phase: phase,
        initialFraction: initialFraction,
      ),
    );

    /// Whether the picker's confirm button is enabled — it stays disabled
    /// until a point has been placed.
    Tristate confirmEnabled(WidgetTester tester) {
      final l10n = AppLocalizations.of(
        tester.element(find.byType(LayerSlidePointPickerView)),
      );
      return tester
          .getSemantics(find.bySemanticsLabel(l10n.videoEditorDoneLabel))
          .flagsCollection
          .isEnabled;
    }

    String hintFor(WidgetTester tester, AnimationPhase phase) {
      final l10n = AppLocalizations.of(
        tester.element(find.byType(LayerSlidePointPickerView)),
      );
      return phase == AnimationPhase.animateOut
          ? l10n.videoEditorLayerAnimationPointLeaveHint
          : l10n.videoEditorLayerAnimationPointEnterHint;
    }

    group('renders', () {
      testWidgets('shows the enter hint for an enter phase', (tester) async {
        await tester.pumpWidget(buildPicker());
        await tester.pump();

        expect(
          find.text(hintFor(tester, AnimationPhase.animateIn)),
          findsOneWidget,
        );
        expect(
          find.text(hintFor(tester, AnimationPhase.animateOut)),
          findsNothing,
        );
      });

      testWidgets('shows the leave hint for a leave phase', (tester) async {
        await tester.pumpWidget(
          buildPicker(phase: AnimationPhase.animateOut),
        );
        await tester.pump();

        expect(
          find.text(hintFor(tester, AnimationPhase.animateOut)),
          findsOneWidget,
        );
      });

      // The hint is the tap target's semantic label, so leaving the visible
      // pill in the tree as well would read it out twice.
      testWidgets('announces the hint once', (tester) async {
        await tester.pumpWidget(buildPicker());
        await tester.pump();

        final hint = hintFor(tester, AnimationPhase.animateIn);
        expect(find.bySemanticsLabel(hint), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('confirm is disabled until a point is placed', (
        tester,
      ) async {
        await tester.pumpWidget(buildPicker());
        await tester.pump();

        expect(confirmEnabled(tester), Tristate.isFalse);

        await tester.tapAt(bodyRect.center);
        await tester.pump();

        expect(confirmEnabled(tester), Tristate.isTrue);
      });

      testWidgets('confirm returns the tapped point as a fraction', (
        tester,
      ) async {
        Offset? result;
        await tester.pumpWidget(
          testMaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<Offset>(
                    MaterialPageRoute<Offset>(
                      builder: (_) => LayerSlidePointPickerView(
                        resolveProjection: projectionWith,
                        canvasChanges: ValueNotifier<int>(0),
                        layer: layer,
                        phase: AnimationPhase.animateIn,
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

        // Quarter of the way across the body, on the vertical centre line.
        await tester.tapAt(
          Offset(bodyRect.center.dx - bodyRect.width / 4, bodyRect.center.dy),
        );
        await tester.pump();

        final l10n = AppLocalizations.of(
          tester.element(find.byType(LayerSlidePointPickerView)),
        );
        await tester.tap(find.bySemanticsLabel(l10n.videoEditorDoneLabel));
        await tester.pumpAndSettle();

        expect(result, isNotNull);
        expect(result!.dx, lessThan(0));
        expect(result!.dy, moreOrLessEquals(0, epsilon: 0.001));
      });

      testWidgets('cancel returns nothing even after placing a point', (
        tester,
      ) async {
        var popped = true;
        Offset? result;
        await tester.pumpWidget(
          testMaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<Offset>(
                    MaterialPageRoute<Offset>(
                      builder: (_) => LayerSlidePointPickerView(
                        resolveProjection: projectionWith,
                        canvasChanges: ValueNotifier<int>(0),
                        layer: layer,
                        phase: AnimationPhase.animateIn,
                      ),
                    ),
                  );
                  popped = false;
                },
                child: const Text('open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await tester.tapAt(bodyRect.center);
        await tester.pump();

        final l10n = AppLocalizations.of(
          tester.element(find.byType(LayerSlidePointPickerView)),
        );
        await tester.tap(find.bySemanticsLabel(l10n.commonCancel));
        await tester.pumpAndSettle();

        expect(popped, isFalse);
        expect(result, isNull);
      });

      testWidgets('a drag moves the point instead of placing a second', (
        tester,
      ) async {
        await tester.pumpWidget(buildPicker());
        await tester.pump();

        await tester.dragFrom(bodyRect.center, const Offset(0, 120));
        await tester.pump();

        // A drag repaints the same painter rather than adding a widget, so the
        // observable is that the picker now has a point to confirm.
        expect(confirmEnabled(tester), Tristate.isTrue);
      });

      // Without a canvas there is nothing to map a touch onto, so the picker
      // stays inert rather than handing back a point measured against nothing.
      testWidgets('does nothing while the canvas is not measurable', (
        tester,
      ) async {
        await tester.pumpWidget(
          testMaterialApp(
            home: LayerSlidePointPickerView(
              resolveProjection: () => null,
              canvasChanges: ValueNotifier<int>(0),
              layer: layer,
              phase: AnimationPhase.animateIn,
            ),
          ),
        );
        await tester.pump();

        await tester.tapAt(bodyRect.center);
        await tester.pump();

        expect(confirmEnabled(tester), Tristate.isFalse);
      });
    });

    group('canvas changes', () {
      // The canvas is mid-resize when the picker opens — the timeline is still
      // collapsing — so the first measurable frame comes after the first build
      // and the picker has to pick it up rather than staying inert.
      testWidgets('places a point once the canvas becomes measurable', (
        tester,
      ) async {
        final changes = ValueNotifier<int>(0);
        addTearDown(changes.dispose);
        LayerCanvasProjection? projection;

        await tester.pumpWidget(
          testMaterialApp(
            home: LayerSlidePointPickerView(
              resolveProjection: () => projection,
              canvasChanges: changes,
              layer: layer,
              phase: AnimationPhase.animateIn,
            ),
          ),
        );
        await tester.pump();
        await tester.tapAt(bodyRect.center);
        await tester.pump();
        expect(confirmEnabled(tester), Tristate.isFalse);

        projection = projectionWith();
        changes.value++;
        // The refresh lands in a post-frame callback, and a post-frame
        // callback does not schedule a frame of its own. In the app the canvas
        // is mid-layout when these notifiers fire, so a frame is always
        // already on its way; a test has to ask for one.
        tester.binding.scheduleFrame();
        await tester.pump();
        await tester.pump();

        await tester.tapAt(bodyRect.center);
        await tester.pump();

        expect(confirmEnabled(tester), Tristate.isTrue);
      });

      testWidgets('stops listening once disposed', (tester) async {
        final changes = ValueNotifier<int>(0);
        addTearDown(changes.dispose);

        await tester.pumpWidget(buildPicker(canvasChanges: changes));
        await tester.pump();
        await tester.pumpWidget(testMaterialApp(home: const SizedBox()));

        changes.value++;
        await tester.pump();

        expect(tester.takeException(), isNull);
      });
    });
  });
}

import 'dart:ui' show Tristate;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/track_frame_mapping.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/layer_slide_point_picker.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/tracking/layer_track_region_picker.dart';

import '../../../../helpers/test_provider_overrides.dart';

void main() {
  const bodyRect = Rect.fromLTWH(0, 100, 400, 600);
  const canvasSize = Size(360, 640);
  const coverScale = 0.9375;
  final projection = LayerCanvasProjection(
    bodyRect: bodyRect,
    canvasSize: canvasSize,
    coverScale: coverScale,
    canvasOrigin: Offset(
      (bodyRect.width - coverScale * canvasSize.width) / 2,
      (bodyRect.height - coverScale * canvasSize.height) / 2,
    ),
    zoom: Matrix4.identity(),
  );

  TrackFrameMapping mappingFor({double targetAspectRatio = 9 / 16}) =>
      TrackFrameMapping(
        canvasSize: canvasSize,
        videoAspectRatio: 9 / 16,
        targetAspectRatio: targetAspectRatio,
      );

  /// Opens the picker with the layer at [layerCenter] and returns what it
  /// pops with once [interact] ran and [confirm] closed it.
  Future<Rect?> pick(
    WidgetTester tester, {
    Offset layerCenter = Offset.zero,
    double targetAspectRatio = 9 / 16,
    Future<void> Function(WidgetTester tester)? interact,
    bool confirm = true,
  }) async {
    Rect? result;
    await tester.pumpWidget(
      testMaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await Navigator.of(context).push<Rect>(
                MaterialPageRoute<Rect>(
                  builder: (_) => LayerTrackRegionPickerView(
                    resolveProjection: () => projection,
                    resolveMapping: () =>
                        mappingFor(targetAspectRatio: targetAspectRatio),
                    canvasChanges: ValueNotifier<int>(0),
                    layerCenter: () => layerCenter,
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
    await interact?.call(tester);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(LayerTrackRegionPickerView)),
    );
    await tester.tap(
      find.bySemanticsLabel(
        confirm ? l10n.videoEditorTrackStartSemanticLabel : l10n.commonCancel,
      ),
    );
    await tester.pumpAndSettle();
    return result;
  }

  /// Where the frame point [fraction] shows on screen.
  Offset screenOf(Offset fraction) =>
      projection.toScreen(mappingFor().layerOffsetOf(fraction));

  group(LayerTrackRegionPickerView, () {
    group('renders', () {
      testWidgets('a box on the layer, sized for a typical object', (
        tester,
      ) async {
        final region = await pick(tester);
        expect(region, isNotNull);
        expect(region!.center.dx, closeTo(0.5, 1e-9));
        expect(region.center.dy, closeTo(0.5, 1e-9));
        // 28 % of the shorter side of the visible frame, square on screen.
        expect(region.width * 360, closeTo(0.28 * 360, 1e-6));
        expect(region.height * 640, closeTo(0.28 * 360, 1e-6));
      });

      testWidgets('the box where the layer shows', (tester) async {
        final region = await pick(tester, layerCenter: const Offset(90, -160));
        expect(region!.center.dx, closeTo(0.75, 1e-9));
        expect(region.center.dy, closeTo(0.25, 1e-9));
      });

      testWidgets('no confirm until the canvas can be measured', (
        tester,
      ) async {
        await tester.pumpWidget(
          testMaterialApp(
            home: LayerTrackRegionPickerView(
              resolveProjection: () => null,
              resolveMapping: mappingFor,
              canvasChanges: ValueNotifier<int>(0),
              layerCenter: () => Offset.zero,
            ),
          ),
        );
        await tester.pump();
        final l10n = AppLocalizations.of(
          tester.element(find.byType(LayerTrackRegionPickerView)),
        );
        expect(
          tester
              .getSemantics(
                find.bySemanticsLabel(l10n.videoEditorTrackStartSemanticLabel),
              )
              .flagsCollection
              .isEnabled,
          Tristate.isFalse,
        );
      });
    });

    group('interactions', () {
      testWidgets('a drag moves the box', (tester) async {
        final region = await pick(
          tester,
          interact: (tester) async {
            await tester.dragFrom(
              screenOf(const Offset(0.5, 0.5)),
              const Offset(120, 0),
            );
            await tester.pump();
          },
        );
        expect(region!.center.dx, greaterThan(0.6));
        expect(region.center.dy, closeTo(0.5, 1e-9));
        expect(region.width * 360, closeTo(0.28 * 360, 1e-6));
      });

      testWidgets('a corner grows the box and keeps the opposite corner', (
        tester,
      ) async {
        final start = Rect.fromCenter(
          center: const Offset(0.5, 0.5),
          width: 0.28,
          height: 0.28 * 360 / 640,
        );
        final region = await pick(
          tester,
          interact: (tester) async {
            await tester.dragFrom(
              screenOf(start.bottomRight),
              const Offset(80, 60),
            );
            await tester.pump();
          },
        );
        expect(region!.left, closeTo(start.left, 1e-9));
        expect(region.top, closeTo(start.top, 1e-9));
        expect(region.right, greaterThan(start.right));
        expect(region.bottom, greaterThan(start.bottom));
      });

      testWidgets('a corner never shrinks the box below its smallest size', (
        tester,
      ) async {
        final start = Rect.fromCenter(
          center: const Offset(0.5, 0.5),
          width: 0.28,
          height: 0.28 * 360 / 640,
        );
        final region = await pick(
          tester,
          interact: (tester) async {
            await tester.dragFrom(
              screenOf(start.bottomRight),
              const Offset(-300, -300),
            );
            await tester.pump();
          },
        );
        expect(region!.width * 360, closeTo(0.08 * 360, 1e-6));
        expect(region.height * 640, closeTo(0.08 * 360, 1e-6));
        expect(region.left, closeTo(start.left, 1e-9));
      });

      testWidgets('the box stays on the part of the frame the video keeps', (
        tester,
      ) async {
        final region = await pick(
          tester,
          targetAspectRatio: 1,
          interact: (tester) async {
            await tester.dragFrom(
              screenOf(const Offset(0.5, 0.5)),
              const Offset(-500, -500),
            );
            await tester.pump();
          },
        );
        expect(region!.left, closeTo(0, 1e-9));
        // A vertical frame cut square keeps from 7/32 to 25/32 of its height.
        expect(region.top, closeTo(7 / 32, 1e-9));
      });

      testWidgets('cancel returns nothing', (tester) async {
        final region = await pick(tester, confirm: false);
        expect(region, isNull);
      });
    });
  });
}

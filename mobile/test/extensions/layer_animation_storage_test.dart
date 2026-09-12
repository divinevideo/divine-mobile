// ABOUTME: Tests the layer-animation bridge between pro_image_editor's typed
// ABOUTME: Layer.animations and the pro_video_editor models used at export.

import 'dart:ui';

import 'package:flutter/widgets.dart' show BuildContext, Builder, SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/extensions/layer_animation_storage.dart';
import 'package:openvine/models/video_editor/layer_slide_point.dart';
import 'package:pro_image_editor/core/models/layers/layer.dart' show Layer;
// The two packages each declare a `SlideDirection`, so the one an in-editor
// animation carries has to be named apart from the one an exported animation
// does.
import 'package:pro_image_editor/core/models/layers/layer_animation.dart'
    as in_editor;
import 'package:pro_image_editor/features/main_editor/services/sizes_manager.dart'
    show SizesManager;
import 'package:pro_image_editor/pro_image_editor.dart'
    show EditorStateHistory, ProImageEditorConfigs;
import 'package:pro_image_editor/shared/widgets/screen_resize_detector.dart'
    show ResizeEvent;
import 'package:pro_video_editor/pro_video_editor.dart' as editor;

void main() {
  const enter = editor.LayerAnimation(
    type: editor.LayerAnimationType.slide,
    phase: editor.AnimationPhase.animateIn,
    duration: Duration(milliseconds: 400),
    slideDirection: editor.SlideDirection.left,
  );
  const leave = editor.LayerAnimation(
    type: editor.LayerAnimationType.fade,
    phase: editor.AnimationPhase.animateOut,
    duration: Duration(milliseconds: 300),
  );

  group('LayerAnimationStorage', () {
    test('round-trips animations through Layer.animations', () {
      final layer = Layer(animations: [enter, leave].toLayerAnimations());

      expect(layer.divineAnimations, equals([enter, leave]));
    });

    test('returns [] when the layer has no animations', () {
      expect(Layer().divineAnimations, isEmpty);
    });

    test('exposes the enter and leave animations by phase', () {
      final layer = Layer(animations: [leave, enter].toLayerAnimations());

      expect(layer.divineEnterAnimations, equals([enter]));
      expect(layer.divineLeaveAnimations, equals([leave]));
    });

    test('exposes every animation of a phase when several are combined', () {
      const slideIn = editor.LayerAnimation(
        type: editor.LayerAnimationType.slide,
        phase: editor.AnimationPhase.animateIn,
        duration: Duration(milliseconds: 400),
        slideDirection: editor.SlideDirection.left,
      );
      const fadeIn = editor.LayerAnimation(
        type: editor.LayerAnimationType.fade,
        phase: editor.AnimationPhase.animateIn,
        duration: Duration(milliseconds: 400),
      );
      final layer = Layer(animations: [fadeIn, slideIn].toLayerAnimations());

      expect(layer.divineEnterAnimations, equals([fadeIn, slideIn]));
      expect(layer.divineLeaveAnimations, isEmpty);
    });

    test('preserves scale-from across the conversion', () {
      const scaleIn = editor.LayerAnimation(
        type: editor.LayerAnimationType.scale,
        phase: editor.AnimationPhase.animateIn,
        duration: Duration(milliseconds: 500),
        scaleFrom: 0.5,
      );
      final layer = Layer(animations: [scaleIn].toLayerAnimations());

      expect(layer.divineAnimations.single.scaleFrom, equals(0.5));
    });

    test('empty input clears to no animations', () {
      final layer = Layer(
        animations: const <editor.LayerAnimation>[].toLayerAnimations(),
      );

      expect(layer.divineAnimations, isEmpty);
    });

    // pro_video_editor's fromMap is strict (`values.byName` throws on an
    // unknown name), so a future dependency bump that renamed any unexercised
    // enum value would throw at export time. Iterating every value turns the
    // schema-parity guarantee into something these tests enforce.
    test('round-trips every animation curve', () {
      for (final curve in editor.AnimationCurve.values) {
        final animation = editor.LayerAnimation(
          type: editor.LayerAnimationType.fade,
          phase: editor.AnimationPhase.animateIn,
          duration: const Duration(milliseconds: 400),
          curve: curve,
        );
        final layer = Layer(animations: [animation].toLayerAnimations());

        expect(
          layer.divineAnimations.single,
          equals(animation),
          reason: '$curve',
        );
      }
    });

    test('round-trips every slide direction', () {
      for (final direction in editor.SlideDirection.values) {
        final animation = editor.LayerAnimation(
          type: editor.LayerAnimationType.slide,
          phase: editor.AnimationPhase.animateIn,
          duration: const Duration(milliseconds: 400),
          slideDirection: direction,
        );
        final layer = Layer(animations: [animation].toLayerAnimations());

        expect(
          layer.divineAnimations.single,
          equals(animation),
          reason: '$direction',
        );
      }
    });

    test('round-trips every type and phase', () {
      for (final type in editor.LayerAnimationType.values) {
        for (final phase in editor.AnimationPhase.values) {
          final animation = editor.LayerAnimation(
            type: type,
            phase: phase,
            duration: const Duration(milliseconds: 250),
            slideDirection: type == editor.LayerAnimationType.slide
                ? editor.SlideDirection.top
                : null,
            scaleFrom: type == editor.LayerAnimationType.scale ? 0.25 : null,
          );
          final layer = Layer(animations: [animation].toLayerAnimations());

          expect(
            layer.divineAnimations.single,
            equals(animation),
            reason: '$type / $phase',
          );
        }
      }
    });

    // The two packages measure `slideFrom` in different spaces —
    // pro_image_editor in canvas pixels from the canvas centre,
    // pro_video_editor in video pixels from the frame's top-left — so it is
    // the one field that must never cross the bridge as-is, in either
    // direction.
    group('slideFrom', () {
      const slideIn = editor.LayerAnimation(
        type: editor.LayerAnimationType.slide,
        phase: editor.AnimationPhase.animateIn,
        duration: Duration(milliseconds: 400),
        slideDirection: editor.SlideDirection.left,
        slideFrom: Offset(-500, 120),
      );

      test('is dropped on the way out to pro_video_editor', () {
        final layer = Layer(
          animations: [slideIn].toLayerAnimations(),
        );

        expect(layer.divineAnimations.single.slideFrom, isNull);
      });

      test('is dropped on the way in when the phase has no point', () {
        final animations = [slideIn].toLayerAnimations(
          canvasSize: const Size(400, 800),
        );

        expect(animations.single.slideFrom, isNull);
        expect(
          animations.single.slideDirection,
          equals(in_editor.SlideDirection.left),
        );
      });

      test('is rebuilt from the phase point in canvas pixels', () {
        final animations = [slideIn].toLayerAnimations(
          points: const LayerSlidePoints(enter: Offset(-0.25, 0.5)),
          canvasSize: const Size(400, 800),
        );

        expect(animations.single.slideFrom, equals(const Offset(-100, 400)));
      });

      test('only the phase that carries a point gets one', () {
        const slideOut = editor.LayerAnimation(
          type: editor.LayerAnimationType.slide,
          phase: editor.AnimationPhase.animateOut,
          duration: Duration(milliseconds: 400),
          slideDirection: editor.SlideDirection.right,
        );

        final animations = [slideIn, slideOut].toLayerAnimations(
          points: const LayerSlidePoints(enter: Offset(0.25, 0.25)),
          canvasSize: const Size(400, 800),
        );

        expect(animations.first.slideFrom, equals(const Offset(100, 200)));
        expect(animations.last.slideFrom, isNull);
      });

      test('a non-slide animation never gets one', () {
        const fadeIn = editor.LayerAnimation(
          type: editor.LayerAnimationType.fade,
          phase: editor.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 400),
        );

        final animations = [fadeIn].toLayerAnimations(
          points: const LayerSlidePoints(enter: Offset(0.25, 0.25)),
          canvasSize: const Size(400, 800),
        );

        expect(animations.single.slideFrom, isNull);
      });

      test('a degenerate canvas leaves the slide on its edge', () {
        final animations = [slideIn].toLayerAnimations(
          points: const LayerSlidePoints(enter: Offset(0.25, 0.25)),
        );

        expect(animations.single.slideFrom, isNull);
        expect(
          animations.single.slideDirection,
          equals(in_editor.SlideDirection.left),
        );
      });

      // The preview reads the pixel copy, the export reads the fraction. They
      // only describe the same journey if pro_image_editor rescales the copy
      // together with the layer's offset when the canvas changes size (the
      // timeline collapsing, a sub-editor opening) — which 14.1.1 does. This
      // drives its real resize path so a dependency bump that loses that
      // behaviour fails here rather than on a device.
      testWidgets(
        'keeps matching the stored fraction after the canvas is resized',
        (tester) async {
          const canvas = Size(400, 800);
          const resized = Size(200, 400);
          const points = LayerSlidePoints(enter: Offset(-0.25, 0.5));
          final layer = Layer(
            offset: const Offset(40, 80),
            meta: points.applyTo(null),
            animations: [slideIn].toLayerAnimations(
              points: points,
              canvasSize: canvas,
            ),
          );
          expect(layer.animations.single.slideFrom, const Offset(-100, 400));

          late BuildContext context;
          await tester.pumpWidget(
            Builder(
              builder: (builderContext) {
                context = builderContext;
                return const SizedBox.shrink();
              },
            ),
          );
          SizesManager(context: context, configs: const ProImageEditorConfigs())
            ..decodedImageSize = canvas
            ..recalculateLayerPosition(
              history: [
                EditorStateHistory(layers: [layer]),
              ],
              resizeEvent: const ResizeEvent(
                oldContentSize: canvas,
                newContentSize: resized,
              ),
            );

          expect(layer.offset, const Offset(20, 40));
          expect(
            layer.animations.single.slideFrom,
            equals(points.resolve(editor.AnimationPhase.animateIn, resized)),
          );
        },
      );
    });
  });

  group('exportedLayerTopLeft', () {
    test('maps a centred layer onto the middle of the video', () {
      expect(
        exportedLayerTopLeft(
          anchor: Offset.zero,
          bodySize: const Size(400, 800),
          logicalSize: const Size(100, 50),
          scale: 2,
        ),
        equals(const Offset(300, 750)),
      );
    });

    test('is the layer top-left, so the layer size shifts it', () {
      const bodySize = Size(400, 800);
      final small = exportedLayerTopLeft(
        anchor: Offset.zero,
        bodySize: bodySize,
        logicalSize: const Size(100, 100),
        scale: 1,
      );
      final large = exportedLayerTopLeft(
        anchor: Offset.zero,
        bodySize: bodySize,
        logicalSize: const Size(200, 200),
        scale: 1,
      );

      expect(large, equals(small - const Offset(50, 50)));
    });

    test('scales the body offset into video pixels', () {
      expect(
        exportedLayerTopLeft(
          anchor: const Offset(50, -100),
          bodySize: const Size(400, 800),
          logicalSize: Size.zero,
          scale: 3,
        ),
        equals(const Offset(750, 900)),
      );
    });
  });

  group('LayerExportAnimations', () {
    const bodySize = Size(400, 800);
    const logicalSize = Size(100, 50);
    const scale = 2.0;

    const slideIn = editor.LayerAnimation(
      type: editor.LayerAnimationType.slide,
      phase: editor.AnimationPhase.animateIn,
      duration: Duration(milliseconds: 400),
      slideDirection: editor.SlideDirection.left,
    );

    List<editor.LayerAnimation> exportOf(Layer layer) =>
        layer.divineAnimationsForExport(
          bodySize: bodySize,
          logicalSize: logicalSize,
          scale: scale,
        );

    test('leaves a layer without points on its edge slide', () {
      final layer = Layer(animations: [slideIn].toLayerAnimations());

      expect(exportOf(layer).single.slideFrom, isNull);
      expect(
        exportOf(layer).single.slideDirection,
        equals(editor.SlideDirection.left),
      );
    });

    // The layer must land exactly on its resting offset, which only holds
    // while the travel start and the resting place go through the same
    // transform.
    test('resolves the point through the same transform as the offset', () {
      const points = LayerSlidePoints(enter: Offset(-0.25, 0.25));
      final layer = Layer(
        offset: const Offset(20, -40),
        meta: points.applyTo(null),
        animations: [slideIn].toLayerAnimations(),
      );

      expect(
        exportOf(layer).single.slideFrom,
        equals(
          exportedLayerTopLeft(
            anchor: points.resolve(editor.AnimationPhase.animateIn, bodySize)!,
            bodySize: bodySize,
            logicalSize: logicalSize,
            scale: scale,
          ),
        ),
      );
    });

    // A direction is kept alongside the point so the animation stays valid for
    // pro_image_editor, which requires one on every slide.
    test('keeps the slide direction the point overrides', () {
      final layer = Layer(
        meta: const LayerSlidePoints(enter: Offset(-0.25, 0.25)).applyTo(null),
        animations: [slideIn].toLayerAnimations(),
      );

      expect(
        exportOf(layer).single.slideDirection,
        equals(editor.SlideDirection.left),
      );
    });

    test('carries every other field of the animation over', () {
      const decorated = editor.LayerAnimation(
        type: editor.LayerAnimationType.slide,
        phase: editor.AnimationPhase.animateIn,
        duration: Duration(milliseconds: 720),
        curve: editor.AnimationCurve.elasticOut,
        slideDirection: editor.SlideDirection.bottom,
      );
      final layer = Layer(
        meta: const LayerSlidePoints(enter: Offset(0.1, 0.1)).applyTo(null),
        animations: [decorated].toLayerAnimations(),
      );

      final exported = exportOf(layer).single;

      expect(exported.type, equals(decorated.type));
      expect(exported.phase, equals(decorated.phase));
      expect(exported.duration, equals(decorated.duration));
      expect(exported.curve, equals(decorated.curve));
      expect(exported.slideDirection, equals(decorated.slideDirection));
      expect(exported.slideFrom, isNotNull);
    });

    test('leaves the phase that carries no point alone', () {
      const fadeOut = editor.LayerAnimation(
        type: editor.LayerAnimationType.fade,
        phase: editor.AnimationPhase.animateOut,
        duration: Duration(milliseconds: 300),
      );
      final layer = Layer(
        meta: const LayerSlidePoints(enter: Offset(0.1, 0.1)).applyTo(null),
        animations: [slideIn, fadeOut].toLayerAnimations(),
      );

      final exported = exportOf(layer);

      expect(exported.first.slideFrom, isNotNull);
      expect(exported.last, equals(fadeOut));
    });

    test('a point on a phase whose animation is a fade changes nothing', () {
      const fadeIn = editor.LayerAnimation(
        type: editor.LayerAnimationType.fade,
        phase: editor.AnimationPhase.animateIn,
        duration: Duration(milliseconds: 300),
      );
      final layer = Layer(
        meta: const LayerSlidePoints(enter: Offset(0.1, 0.1)).applyTo(null),
        animations: [fadeIn].toLayerAnimations(),
      );

      expect(exportOf(layer).single, equals(fadeIn));
    });

    test('a degenerate body leaves the slide on its edge', () {
      final layer = Layer(
        meta: const LayerSlidePoints(enter: Offset(0.1, 0.1)).applyTo(null),
        animations: [slideIn].toLayerAnimations(),
      );

      final exported = layer.divineAnimationsForExport(
        bodySize: Size.zero,
        logicalSize: logicalSize,
        scale: scale,
      );

      expect(exported.single.slideFrom, isNull);
      expect(
        exported.single.slideDirection,
        equals(editor.SlideDirection.left),
      );
    });
  });
}

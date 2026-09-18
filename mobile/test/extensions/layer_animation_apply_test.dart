// ABOUTME: Tests for the shared layer-animation write: the end time a leave
// ABOUTME: animation resolves to, and what withDivineAnimations stores.

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/extensions/layer_animation_apply.dart';
import 'package:openvine/extensions/layer_animation_storage.dart';
import 'package:openvine/models/video_editor/layer_slide_point.dart';
import 'package:pro_image_editor/pro_image_editor.dart' show Layer, TextLayer;
import 'package:pro_video_editor/pro_video_editor.dart' as editor;

void main() {
  group('resolveLayerEndTime', () {
    const total = Duration(seconds: 5);

    test('anchors an untrimmed layer to the window end for a leave '
        'animation', () {
      expect(
        resolveLayerEndTime(
          currentEndTime: null,
          startTime: Duration.zero,
          totalDuration: total,
          hasLeaveAnimation: true,
        ),
        total,
      );
    });

    test('keeps an explicit trim end for a leave animation', () {
      const trimEnd = Duration(seconds: 2);
      expect(
        resolveLayerEndTime(
          currentEndTime: trimEnd,
          startTime: Duration.zero,
          totalDuration: total,
          hasLeaveAnimation: true,
        ),
        trimEnd,
      );
    });

    test('leaves an untrimmed layer untrimmed without a leave animation', () {
      expect(
        resolveLayerEndTime(
          currentEndTime: null,
          startTime: Duration.zero,
          totalDuration: total,
          hasLeaveAnimation: false,
        ),
        isNull,
      );
    });

    test('preserves an explicit trim end without a leave animation', () {
      const trimEnd = Duration(seconds: 3);
      expect(
        resolveLayerEndTime(
          currentEndTime: trimEnd,
          startTime: Duration.zero,
          totalDuration: total,
          hasLeaveAnimation: false,
        ),
        trimEnd,
      );
    });

    test('drops a full-length end when the leave animation is removed', () {
      // The end was previously anchored to the window for a leave animation;
      // removing the leave must not leave the layer pinned (untrimmed again).
      expect(
        resolveLayerEndTime(
          currentEndTime: total,
          startTime: Duration.zero,
          totalDuration: total,
          hasLeaveAnimation: false,
        ),
        isNull,
      );
    });

    test('drops a stale end past the window without a leave animation', () {
      // e.g. the video was shortened after the end was anchored.
      expect(
        resolveLayerEndTime(
          currentEndTime: const Duration(seconds: 8),
          startTime: Duration.zero,
          totalDuration: total,
          hasLeaveAnimation: false,
        ),
        isNull,
      );
    });

    test('clamps a stale end past the window to the window for a leave', () {
      expect(
        resolveLayerEndTime(
          currentEndTime: const Duration(seconds: 8),
          startTime: Duration.zero,
          totalDuration: total,
          hasLeaveAnimation: true,
        ),
        total,
      );
    });

    test('does not collapse the layer when totalDuration is a transient '
        'zero', () {
      // A leave set before the player has reported its length: a zero total
      // must not anchor endTime at zero (== startTime), which would collapse
      // the layer to a zero-length window and drop it from the timeline.
      // Un-anchored (null) keeps it spanning the whole video instead.
      expect(
        resolveLayerEndTime(
          currentEndTime: null,
          startTime: Duration.zero,
          totalDuration: Duration.zero,
          hasLeaveAnimation: true,
        ),
        isNull,
      );
    });

    test('never anchors a late layer at or before its start on a stale '
        'small total', () {
      // A layer starting at 4s with a stale total of 3s must not anchor its
      // end at 3s (<= start). With no valid existing end it stays un-anchored
      // rather than vanish from the timeline.
      expect(
        resolveLayerEndTime(
          currentEndTime: null,
          startTime: const Duration(seconds: 4),
          totalDuration: const Duration(seconds: 3),
          hasLeaveAnimation: true,
        ),
        isNull,
      );
    });

    test('keeps the existing valid end when the total is stale small', () {
      // total (1s) is stale below the layer window; rather than collapse, keep
      // the real end (4s) that is still after the 2s start.
      expect(
        resolveLayerEndTime(
          currentEndTime: const Duration(seconds: 4),
          startTime: const Duration(seconds: 2),
          totalDuration: const Duration(seconds: 1),
          hasLeaveAnimation: true,
        ),
        const Duration(seconds: 4),
      );
    });
  });

  group('withDivineAnimations', () {
    const total = Duration(seconds: 5);
    const canvas = Size(300, 500);
    const enterSlide = editor.LayerAnimation(
      type: editor.LayerAnimationType.slide,
      phase: editor.AnimationPhase.animateIn,
      duration: Duration(milliseconds: 400),
      slideDirection: editor.SlideDirection.left,
    );
    const leaveFade = editor.LayerAnimation(
      type: editor.LayerAnimationType.fade,
      phase: editor.AnimationPhase.animateOut,
      duration: Duration(milliseconds: 300),
    );
    const bothScale = editor.LayerAnimation(
      type: editor.LayerAnimationType.scale,
      phase: editor.AnimationPhase.animateInOut,
      duration: Duration(milliseconds: 200),
      scaleFrom: 0.5,
    );

    Layer applied(
      Layer layer, {
      List<editor.LayerAnimation> enter = const [],
      List<editor.LayerAnimation> leave = const [],
      LayerSlidePoints points = const LayerSlidePoints(),
    }) => layer.withDivineAnimations(
      enter: enter,
      leave: leave,
      points: points,
      canvasSize: canvas,
      totalDuration: total,
    );

    test('stores the enter and leave animations and anchors the end', () {
      final layer = TextLayer(text: 'Hi', startTime: Duration.zero);

      final result = applied(layer, enter: [enterSlide], leave: [leaveFade]);

      expect(result.divineEnterAnimations, [enterSlide]);
      expect(result.divineLeaveAnimations, [leaveFade]);
      expect(result.endTime, total);
    });

    test('keeps animations of a phase the picker does not model', () {
      final layer = TextLayer(
        text: 'Hi',
        animations: [bothScale].toLayerAnimations(),
      );

      final result = applied(layer, enter: [enterSlide]);

      expect(result.divineAnimations, [enterSlide, bothScale]);
    });

    test('clears a stale full-length end when the leave is removed', () {
      final layer = TextLayer(text: 'Hi', startTime: Duration.zero)
        ..endTime = total
        ..animations = [leaveFade].toLayerAnimations();

      final result = applied(layer);

      expect(result.divineAnimations, isEmpty);
      expect(result.endTime, isNull);
    });

    test('clears the legacy fade fields so nothing falls back to them', () {
      final layer = TextLayer(
        text: 'Hi',
        enterDuration: const Duration(milliseconds: 100),
        exitDuration: const Duration(milliseconds: 100),
      );

      final result = applied(layer);

      expect(result.enterDuration, isNull);
      expect(result.exitDuration, isNull);
      expect(result.effectiveAnimations, isEmpty);
    });

    test('writes a custom point only for a phase that slides', () {
      final layer = TextLayer(text: 'Hi');
      const enterPoint = Offset(-0.5, -0.25);
      const leavePoint = Offset(0.5, 0.25);

      final result = applied(
        layer,
        enter: [enterSlide],
        leave: [leaveFade],
        points: const LayerSlidePoints(enter: enterPoint, leave: leavePoint),
      );

      final stored = LayerSlidePoints.of(result);
      expect(stored.enter, enterPoint);
      // The leave phase fades rather than slides, so its point is dropped.
      expect(stored.leave, isNull);
      // The enter slide carries the point in canvas pixels for the preview.
      final slide = result.animations.firstWhere(
        (animation) => animation.type.name == 'slide',
      );
      expect(slide.slideFrom, const Offset(-150, -125));
    });

    test('drops a stored point once its phase no longer slides', () {
      final layer = TextLayer(
        text: 'Hi',
        meta: const LayerSlidePoints(
          enter: Offset(-0.5, 0),
        ).applyTo({'keep': true}),
      );

      final result = applied(layer, enter: [leaveFade]);

      expect(LayerSlidePoints.of(result).isEmpty, isTrue);
      expect(result.meta, {'keep': true});
    });
  });
}

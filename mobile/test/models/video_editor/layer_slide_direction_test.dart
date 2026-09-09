// ABOUTME: Unit tests for LayerSlideDirection — the decomposition of the eight
// ABOUTME: picker directions into pro_video_editor's axis-aligned slides.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/extensions/layer_animation_storage.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/video_editor/layer_slide_direction.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show Layer, LayerTimelineConfigs;
import 'package:pro_image_editor/shared/widgets/layer/layer_timeline_visibility.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show AnimationPhase, LayerAnimation, LayerAnimationType, SlideDirection;

void main() {
  group(LayerSlideDirection, () {
    group('components', () {
      test('an edge direction yields exactly its own axis', () {
        expect(LayerSlideDirection.left.components, [SlideDirection.left]);
        expect(LayerSlideDirection.right.components, [SlideDirection.right]);
        expect(LayerSlideDirection.up.components, [SlideDirection.top]);
        expect(LayerSlideDirection.down.components, [SlideDirection.bottom]);
      });

      test('a diagonal yields one horizontal and one vertical slide', () {
        expect(LayerSlideDirection.upLeft.components, [
          SlideDirection.left,
          SlideDirection.top,
        ]);
        expect(LayerSlideDirection.upRight.components, [
          SlideDirection.right,
          SlideDirection.top,
        ]);
        expect(LayerSlideDirection.downLeft.components, [
          SlideDirection.left,
          SlideDirection.bottom,
        ]);
        expect(LayerSlideDirection.downRight.components, [
          SlideDirection.right,
          SlideDirection.bottom,
        ]);
      });

      test('every direction decomposes into at most one slide per axis', () {
        for (final direction in LayerSlideDirection.values) {
          final horizontal = direction.components
              .where(
                (c) => c == SlideDirection.left || c == SlideDirection.right,
              )
              .length;
          final vertical = direction.components
              .where(
                (c) => c == SlideDirection.top || c == SlideDirection.bottom,
              )
              .length;
          expect(horizontal, lessThanOrEqualTo(1), reason: '$direction');
          expect(vertical, lessThanOrEqualTo(1), reason: '$direction');
          expect(direction.components, isNotEmpty, reason: '$direction');
        }
      });
    });

    group('isDiagonal', () {
      test('is true only for the four corner directions', () {
        final diagonals = LayerSlideDirection.values
            .where((d) => d.isDiagonal)
            .toSet();

        expect(diagonals, {
          LayerSlideDirection.upLeft,
          LayerSlideDirection.upRight,
          LayerSlideDirection.downLeft,
          LayerSlideDirection.downRight,
        });
      });
    });

    group('fromComponents', () {
      test('round-trips every direction through its own components', () {
        for (final direction in LayerSlideDirection.values) {
          expect(
            LayerSlideDirection.fromComponents(direction.components),
            direction,
            reason: '$direction',
          );
        }
      });

      test('is order-insensitive for a diagonal', () {
        expect(
          LayerSlideDirection.fromComponents([
            SlideDirection.bottom,
            SlideDirection.right,
          ]),
          LayerSlideDirection.downRight,
        );
      });

      test('returns null when nothing names a direction', () {
        expect(LayerSlideDirection.fromComponents(const []), isNull);
      });

      test('keeps the first entry per axis when an axis repeats', () {
        expect(
          LayerSlideDirection.fromComponents([
            SlideDirection.left,
            SlideDirection.right,
          ]),
          LayerSlideDirection.left,
        );
        expect(
          LayerSlideDirection.fromComponents([
            SlideDirection.top,
            SlideDirection.bottom,
            SlideDirection.right,
          ]),
          LayerSlideDirection.upRight,
        );
      });
    });

    // The whole design rests on every renderer *summing* the offsets of a
    // layer's slide animations. That is not something the plugin promises, so
    // pin it against the real in-editor preview widget: if a pro_image_editor
    // bump ever made a second slide override the first instead of adding to it,
    // diagonals would silently collapse to one axis and this fails.
    //
    // Only the preview can be pinned from Dart. The Android and iOS export
    // renderers sum the same way (`ApplyAnimation.kt` accumulates offsetX /
    // offsetY, `ApplyAnimation.swift` chains translatedBy), which stays a
    // read-verified claim until a device export is checked.
    group('composed in the in-editor preview', () {
      const canvas = Size(200, 300);
      const layerSize = Size(40, 40);
      const layerCenter = Offset(100, 150);
      const duration = Duration(milliseconds: 1000);
      const sampleTime = Duration(milliseconds: 400);
      const childKey = ValueKey<String>('layer-child');

      // Curve is left at the default (linear); the composition under test is
      // the same at any easing, since both components share it.
      LayerAnimation slide(SlideDirection direction) => LayerAnimation(
        type: LayerAnimationType.slide,
        phase: AnimationPhase.animateIn,
        duration: duration,
        slideDirection: direction,
      );

      /// The rendered top-left of the layer's child at [time], for a layer
      /// carrying [animations].
      Future<Offset> renderedAt(
        WidgetTester tester,
        List<LayerAnimation> animations,
        Duration time,
      ) async {
        final playTime = ValueNotifier<Duration>(time);
        addTearDown(playTime.dispose);
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Align(
              alignment: Alignment.topLeft,
              child: SizedBox.fromSize(
                size: canvas,
                child: Center(
                  child: LayerTimelineVisibility(
                    layer: Layer(
                      startTime: Duration.zero,
                      endTime: const Duration(seconds: 4),
                      animations: animations.toLayerAnimations(),
                    ),
                    playTimeNotifier: playTime,
                    configs: const LayerTimelineConfigs(),
                    canvasSize: canvas,
                    layerCenter: layerCenter,
                    child: SizedBox.fromSize(
                      size: layerSize,
                      child: const ColoredBox(
                        key: childKey,
                        color: Color(0xFF00FF00),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        return tester.getTopLeft(find.byKey(childKey));
      }

      testWidgets('a diagonal displaces by the sum of its two components', (
        tester,
      ) async {
        final rest = await renderedAt(tester, [], sampleTime);
        final left = await renderedAt(tester, [
          slide(SlideDirection.left),
        ], sampleTime);
        final up = await renderedAt(tester, [
          slide(SlideDirection.top),
        ], sampleTime);
        final upLeft = await renderedAt(
          tester,
          LayerSlideDirection.upLeft.components.map(slide).toList(),
          sampleTime,
        );

        expect(left, isNot(rest));
        expect(up, isNot(rest));
        expect(upLeft - rest, (left - rest) + (up - rest));
      });

      testWidgets('a diagonal moves on both axes, an edge slide on one', (
        tester,
      ) async {
        final rest = await renderedAt(tester, [], sampleTime);
        final left = await renderedAt(tester, [
          slide(SlideDirection.left),
        ], sampleTime);
        final downRight = await renderedAt(
          tester,
          LayerSlideDirection.downRight.components.map(slide).toList(),
          sampleTime,
        );

        expect(left.dy, rest.dy);
        expect(left.dx, lessThan(rest.dx));
        expect(downRight.dx, greaterThan(rest.dx));
        expect(downRight.dy, greaterThan(rest.dy));
      });
    });
  });
}

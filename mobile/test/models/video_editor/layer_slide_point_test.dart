// ABOUTME: Tests the custom slide points a layer stores on Layer.meta as
// ABOUTME: canvas fractions, and how they resolve back to canvas coordinates.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/layer_slide_point.dart';
import 'package:pro_image_editor/core/models/layers/layer.dart' show Layer;
import 'package:pro_video_editor/pro_video_editor.dart' show AnimationPhase;

void main() {
  const canvas = Size(400, 800);

  group(LayerSlidePoints, () {
    group('fromMeta', () {
      test('reads both phases back from the meta a set wrote', () {
        const points = LayerSlidePoints(
          enter: Offset(-0.25, 0.5),
          leave: Offset(0.75, -0.125),
        );

        expect(
          LayerSlidePoints.fromMeta(points.applyTo(null)),
          equals(points),
        );
      });

      test('reads a phase that was set on its own', () {
        const points = LayerSlidePoints(enter: Offset(0.1, 0.2));

        final restored = LayerSlidePoints.fromMeta(points.applyTo(null));

        expect(restored.enter, equals(const Offset(0.1, 0.2)));
        expect(restored.leave, isNull);
      });

      test('is empty for meta that carries no points', () {
        expect(LayerSlidePoints.fromMeta(null).isEmpty, isTrue);
        expect(
          LayerSlidePoints.fromMeta(const {'other': 1}).isEmpty,
          isTrue,
        );
      });

      // Meta survives a draft round-trip as plain JSON, so anything can be
      // sitting under the key. An unreadable entry has to read as "no custom
      // point" — the layer then slides from its edge, which is what it did
      // before a point was ever set — rather than throwing on the way in.
      test('treats unreadable entries as absent', () {
        const malformed = <Object?>[
          'not-a-map',
          42,
          <String, dynamic>{layerSlidePointEnterKey: 'nope'},
          <String, dynamic>{
            layerSlidePointEnterKey: <String, dynamic>{'dx': 'x', 'dy': 1},
          },
          <String, dynamic>{
            layerSlidePointEnterKey: <String, dynamic>{'dy': 1},
          },
          <String, dynamic>{
            layerSlidePointEnterKey: <String, dynamic>{
              'dx': double.nan,
              'dy': 1,
            },
          },
          <String, dynamic>{
            layerSlidePointEnterKey: <String, dynamic>{
              'dx': double.infinity,
              'dy': 1,
            },
          },
        ];
        for (final raw in malformed) {
          expect(
            LayerSlidePoints.fromMeta(<String, dynamic>{
              layerSlidePointsMetaKey: raw,
            }).isEmpty,
            isTrue,
            reason: '$raw',
          );
        }
      });

      test('keeps the readable phase when the other one is malformed', () {
        const meta = <String, dynamic>{
          layerSlidePointsMetaKey: <String, dynamic>{
            layerSlidePointEnterKey: <String, dynamic>{'dx': 0.5, 'dy': -0.5},
            layerSlidePointLeaveKey: 'broken',
          },
        };

        final restored = LayerSlidePoints.fromMeta(meta);

        expect(restored.enter, equals(const Offset(0.5, -0.5)));
        expect(restored.leave, isNull);
      });
    });

    group('of', () {
      test('reads the points a layer carries', () {
        const points = LayerSlidePoints(leave: Offset(-0.5, 0.25));
        final layer = Layer(meta: points.applyTo(null));

        expect(LayerSlidePoints.of(layer), equals(points));
      });

      test('is empty for a layer that never had a point', () {
        expect(LayerSlidePoints.of(Layer()).isEmpty, isTrue);
      });
    });

    group('applyTo', () {
      test('carries every other meta key through untouched', () {
        const points = LayerSlidePoints(enter: Offset(0.25, 0.25));

        final meta = points.applyTo(<String, dynamic>{
          'divine.captionCue': true,
          'stickerId': 'abc',
        });

        expect(meta!['divine.captionCue'], isTrue);
        expect(meta['stickerId'], equals('abc'));
      });

      test('does not mutate the meta it was given', () {
        final original = <String, dynamic>{'stickerId': 'abc'};

        const LayerSlidePoints(enter: Offset.zero).applyTo(original);

        expect(original, equals(<String, dynamic>{'stickerId': 'abc'}));
      });

      // A layer whose point was cleared has to end up byte-identical to one
      // that never had a point, or the export and the draft would carry an
      // empty map around forever.
      test('removes the key when the set is empty', () {
        const set = LayerSlidePoints(enter: Offset(0.25, 0.25));
        final withPoint = set.applyTo(<String, dynamic>{'stickerId': 'abc'});

        final cleared = const LayerSlidePoints().applyTo(withPoint);

        expect(cleared, equals(<String, dynamic>{'stickerId': 'abc'}));
      });

      test('leaves meta alone when it never carried a point', () {
        final meta = <String, dynamic>{'stickerId': 'abc'};

        expect(const LayerSlidePoints().applyTo(meta), same(meta));
        expect(const LayerSlidePoints().applyTo(null), isNull);
      });
    });

    group('fractionFor', () {
      test('reads each phase from its own slot', () {
        const points = LayerSlidePoints(
          enter: Offset(0.1, 0.1),
          leave: Offset(0.2, 0.2),
        );

        expect(
          points.fractionFor(AnimationPhase.animateIn),
          equals(const Offset(0.1, 0.1)),
        );
        expect(
          points.fractionFor(AnimationPhase.animateOut),
          equals(const Offset(0.2, 0.2)),
        );
      });

      // animateInOut plays the same motion at both ends, so it has no slot of
      // its own and reads whichever one is set.
      test('animateInOut prefers the enter point', () {
        const both = LayerSlidePoints(
          enter: Offset(0.1, 0.1),
          leave: Offset(0.2, 0.2),
        );
        const leaveOnly = LayerSlidePoints(leave: Offset(0.2, 0.2));

        expect(
          both.fractionFor(AnimationPhase.animateInOut),
          equals(const Offset(0.1, 0.1)),
        );
        expect(
          leaveOnly.fractionFor(AnimationPhase.animateInOut),
          equals(const Offset(0.2, 0.2)),
        );
        expect(
          const LayerSlidePoints().fractionFor(AnimationPhase.animateInOut),
          isNull,
        );
      });
    });

    group('resolve', () {
      test('scales the fraction onto the canvas, centre-relative', () {
        const points = LayerSlidePoints(enter: Offset(-0.5, 0.25));

        expect(
          points.resolve(AnimationPhase.animateIn, canvas),
          equals(const Offset(-200, 200)),
        );
      });

      // The whole reason a fraction is stored instead of pixels: the canvas
      // resizes (the timeline collapses, a sub-editor opens) and the point has
      // to keep naming the same place on the frame.
      test('names the same relative place on a resized canvas', () {
        const points = LayerSlidePoints(enter: Offset(-0.25, 0.5));

        final small = points.resolve(AnimationPhase.animateIn, canvas)!;
        final large = points.resolve(AnimationPhase.animateIn, canvas * 2)!;

        expect(large, equals(small * 2));
      });

      test('is null for a phase without a point', () {
        expect(
          const LayerSlidePoints(
            leave: Offset(0.5, 0.5),
          ).resolve(AnimationPhase.animateIn, canvas),
          isNull,
        );
      });

      test('is null for a degenerate canvas', () {
        const points = LayerSlidePoints(enter: Offset(0.5, 0.5));

        expect(points.resolve(AnimationPhase.animateIn, Size.zero), isNull);
        expect(
          points.resolve(AnimationPhase.animateIn, const Size(0, 800)),
          isNull,
        );
      });
    });

    group('fractionOf', () {
      test('is the inverse of resolve', () {
        const canvasPoint = Offset(-120, 240);

        final fraction = LayerSlidePoints.fractionOf(canvasPoint, canvas)!;

        expect(
          LayerSlidePoints(enter: fraction) //
              .resolve(AnimationPhase.animateIn, canvas),
          equals(canvasPoint),
        );
      });

      test('is null for a degenerate canvas', () {
        expect(LayerSlidePoints.fractionOf(Offset.zero, Size.zero), isNull);
      });
    });

    group('value semantics', () {
      test('two sets with the same points are equal', () {
        const a = LayerSlidePoints(enter: Offset(0.1, 0.2));
        const b = LayerSlidePoints(enter: Offset(0.1, 0.2));

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('a differing phase makes them unequal', () {
        expect(
          const LayerSlidePoints(enter: Offset(0.1, 0.2)),
          isNot(equals(const LayerSlidePoints(leave: Offset(0.1, 0.2)))),
        );
      });

      test('toString names both phases', () {
        expect(
          const LayerSlidePoints(enter: Offset(0.1, 0.2)).toString(),
          contains('enter: Offset(0.1, 0.2)'),
        );
      });
    });
  });
}

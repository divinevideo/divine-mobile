// ABOUTME: Tests for EditorOverlaySnapshot - windowing overlays onto one clip's
// ABOUTME: slice of the editor timeline.

import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/editor_overlay_snapshot.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show CustomVideoEffect, VideoEffect;

ExportedLayer _layer({String id = 'l', Duration? start, Duration? end}) {
  return ExportedLayer(
    layer: Layer(id: id, startTime: start, endTime: end),
    bytes: Uint8List.fromList([1, 2, 3]),
    logicalSize: const Size(10, 10),
  );
}

ExportedLayer _animatedLayer({
  String id = 'l',
  Duration? start,
  Duration? end,
  Duration? enterDuration,
  Duration? exitDuration,
  List<LayerAnimation> animations = const [],
}) {
  return ExportedLayer(
    layer: Layer(
      id: id,
      startTime: start,
      endTime: end,
      enterDuration: enterDuration,
      exitDuration: exitDuration,
      animations: animations,
    ),
    bytes: Uint8List.fromList([1, 2, 3]),
    logicalSize: const Size(10, 10),
  );
}

LayerAnimation _anim(AnimationPhase phase) => LayerAnimation(
  type: LayerAnimationType.fade,
  phase: phase,
  duration: const Duration(milliseconds: 300),
);

FilterState _filter({String id = 'f', Duration? start, Duration? end}) {
  return FilterState(
    id: id,
    name: id,
    matrices: [
      [1.0],
    ],
    startTime: start,
    endTime: end,
  );
}

TuneAdjustmentMatrix _tune({String id = 't', Duration? start, Duration? end}) {
  return TuneAdjustmentMatrix(
    id: id,
    value: 1,
    matrix: const [1.0],
    startTime: start,
    endTime: end,
  );
}

const _s1 = Duration(seconds: 1);
const _s2 = Duration(seconds: 2);
const _s3 = Duration(seconds: 3);
const _s4 = Duration(seconds: 4);
const _s5 = Duration(seconds: 5);
const _s6 = Duration(seconds: 6);

void main() {
  group(EditorOverlaySnapshot, () {
    group('isEmpty', () {
      test('is true with nothing to bake', () {
        expect(const EditorOverlaySnapshot().isEmpty, isTrue);
      });

      test('is false when only a blur is set', () {
        expect(const EditorOverlaySnapshot(blur: 3).isEmpty, isFalse);
      });

      test('is false when a layer is present', () {
        expect(
          EditorOverlaySnapshot(capturedLayers: [_layer()]).isEmpty,
          isFalse,
        );
      });
    });

    group('windowedTo layers', () {
      test('keeps a layer inside the window, rebased to zero', () {
        // Clip occupies 3s-6s; layer sits at 4s-5s over it.
        final result = EditorOverlaySnapshot(
          capturedLayers: [_layer(start: _s4, end: _s5)],
        ).windowedTo(start: _s3, end: _s6);

        expect(result.capturedLayers, hasLength(1));
        expect(result.capturedLayers.single.layer.startTime, equals(_s1));
        expect(result.capturedLayers.single.layer.endTime, equals(_s2));
      });

      test('drops a layer that ends before the window', () {
        final result = EditorOverlaySnapshot(
          capturedLayers: [_layer(start: _s1, end: _s2)],
        ).windowedTo(start: _s3, end: _s6);

        expect(result.capturedLayers, isEmpty);
      });

      test('drops a layer that starts after the window', () {
        final result = EditorOverlaySnapshot(
          capturedLayers: [_layer(start: const Duration(seconds: 7))],
        ).windowedTo(start: _s3, end: _s6);

        expect(result.capturedLayers, isEmpty);
      });

      test('drops a layer that only touches the window boundary', () {
        // Ends exactly where the clip starts — it was never over this clip.
        final result = EditorOverlaySnapshot(
          capturedLayers: [_layer(start: _s1, end: _s3)],
        ).windowedTo(start: _s3, end: _s6);

        expect(result.capturedLayers, isEmpty);
      });

      test('clamps a layer that starts before the window', () {
        // Layer runs 1s-4s, clip is 3s-6s → visible for the clip's first second.
        final result = EditorOverlaySnapshot(
          capturedLayers: [_layer(start: _s1, end: _s4)],
        ).windowedTo(start: _s3, end: _s6);

        expect(
          result.capturedLayers.single.layer.startTime,
          equals(Duration.zero),
        );
        expect(result.capturedLayers.single.layer.endTime, equals(_s1));
      });

      test('clamps a layer that outlives the window', () {
        // Layer runs 4s-10s, clip is 3s-6s → visible from 1s to the clip's end.
        final result = EditorOverlaySnapshot(
          capturedLayers: [
            _layer(start: _s4, end: const Duration(seconds: 10)),
          ],
        ).windowedTo(start: _s3, end: _s6);

        expect(result.capturedLayers.single.layer.startTime, equals(_s1));
        expect(result.capturedLayers.single.layer.endTime, equals(_s3));
      });

      test('binds an unbounded layer to the window', () {
        // null/null spans the whole composition, so it covers all of the clip.
        final result = EditorOverlaySnapshot(
          capturedLayers: [_layer()],
        ).windowedTo(start: _s3, end: _s6);

        expect(
          result.capturedLayers.single.layer.startTime,
          equals(Duration.zero),
        );
        expect(result.capturedLayers.single.layer.endTime, equals(_s3));
      });

      test('carries the rasterized bytes and layout through untouched', () {
        final source = _layer(start: _s4, end: _s5);
        final result = EditorOverlaySnapshot(
          capturedLayers: [source],
        ).windowedTo(start: _s3, end: _s6);

        expect(result.capturedLayers.single.bytes, same(source.bytes));
        expect(
          result.capturedLayers.single.logicalSize,
          equals(const Size(10, 10)),
        );
      });

      test("does not mutate the editor's live layer", () {
        // Layer.startTime is mutable and this instance belongs to the editor —
        // rebasing it in place would corrupt the running session.
        final source = _layer(start: _s4, end: _s5);
        EditorOverlaySnapshot(
          capturedLayers: [source],
        ).windowedTo(start: _s3, end: _s6);

        expect(source.layer.startTime, equals(_s4));
        expect(source.layer.endTime, equals(_s5));
      });

      test('keeps only the layers overlapping the window', () {
        final result = EditorOverlaySnapshot(
          capturedLayers: [
            _layer(id: 'before', start: Duration.zero, end: _s1),
            _layer(id: 'over', start: _s4, end: _s5),
            _layer(id: 'after', start: const Duration(seconds: 8)),
          ],
        ).windowedTo(start: _s3, end: _s6);

        expect(
          result.capturedLayers.map((l) => l.layer.id),
          equals(['over']),
        );
      });
    });

    group('windowedTo word highlights', () {
      // "one" is lit for the layer's first second, "two" for its second.
      ExportedLayer karaoke() => ExportedLayer(
        layer: TextLayer(
          text: 'one two',
          startTime: const Duration(seconds: 2),
          endTime: const Duration(seconds: 5),
          highlights: const [
            TextHighlight(
              start: 0,
              end: 3,
              startTime: Duration.zero,
              endTime: Duration(seconds: 1),
            ),
            TextHighlight(
              start: 4,
              end: 7,
              startTime: Duration(seconds: 1),
              endTime: Duration(seconds: 2),
            ),
          ],
        ),
        bytes: Uint8List.fromList([0]),
        logicalSize: const Size(10, 10),
        highlightBytes: {
          0: Uint8List.fromList([1]),
          1: Uint8List.fromList([2]),
        },
      );

      List<(int, Duration?, Duration?)> framesOf(ExportedLayer layer) => [
        for (final frame in layer.frames)
          (frame.bytes.single, frame.startTime, frame.endTime),
      ];

      test('keep the words lit at the same moments when the clip cuts into '
          'the caption', () {
        final result = EditorOverlaySnapshot(
          capturedLayers: [karaoke()],
        ).windowedTo(start: _s3, end: _s6);

        // The clip starts at 3s, where "two" lights up; the caption ends at
        // 5s, 2s into the clip.
        expect(framesOf(result.capturedLayers.single), [
          (2, Duration.zero, const Duration(seconds: 1)),
          (0, const Duration(seconds: 1), const Duration(seconds: 2)),
        ]);
      });

      test('are untouched for a caption the clip fully contains', () {
        final result = EditorOverlaySnapshot(
          capturedLayers: [karaoke()],
        ).windowedTo(start: _s1, end: _s6);

        expect(
          (result.capturedLayers.single.layer as TextLayer).highlights,
          (karaoke().layer as TextLayer).highlights,
        );
        expect(framesOf(result.capturedLayers.single), [
          (1, _s1, const Duration(seconds: 2)),
          (2, const Duration(seconds: 2), _s3),
          (0, _s3, const Duration(seconds: 4)),
        ]);
      });
    });

    group('windowedTo text reveal', () {
      // "one two" types itself out word by word over the layer's first second.
      ExportedLayer revealing() => ExportedLayer(
        layer: TextLayer(
          text: 'one two',
          startTime: _s2,
          endTime: _s5,
          animations: const [
            LayerAnimation(
              type: LayerAnimationType.wordByWord,
              phase: AnimationPhase.animateIn,
              duration: Duration(seconds: 1),
            ),
          ],
        ),
        bytes: Uint8List.fromList([0]),
        logicalSize: const Size(10, 10),
        revealBytes: {
          const ExportedTextState(revealedLength: 0): Uint8List.fromList([1]),
          const ExportedTextState(revealedLength: 3): Uint8List.fromList([2]),
        },
      );

      test('keeps the reveal images for a layer the clip contains', () {
        final result = EditorOverlaySnapshot(
          capturedLayers: [revealing()],
        ).windowedTo(start: _s1, end: _s6);

        expect(
          [
            for (final frame in result.capturedLayers.single.frames)
              frame.bytes.single,
          ],
          [1, 2, 0],
        );
      });

      test('drops the reveal of a layer that started before the clip', () {
        final result = EditorOverlaySnapshot(
          capturedLayers: [revealing()],
        ).windowedTo(start: _s3, end: _s6);

        // The text had typed itself out before the clip begins.
        expect(result.capturedLayers.single.frames.single.bytes.single, 0);
      });
    });

    group('windowedTo filters and tune', () {
      test('windows a filter like a layer', () {
        final result = EditorOverlaySnapshot(
          filterStates: [_filter(start: _s4, end: const Duration(seconds: 10))],
        ).windowedTo(start: _s3, end: _s6);

        expect(result.filterStates.single.startTime, equals(_s1));
        expect(result.filterStates.single.endTime, equals(_s3));
      });

      test('drops a filter outside the window', () {
        final result = EditorOverlaySnapshot(
          filterStates: [_filter(start: Duration.zero, end: _s1)],
        ).windowedTo(start: _s3, end: _s6);

        expect(result.filterStates, isEmpty);
      });

      test('windows a tune adjustment like a layer', () {
        final result = EditorOverlaySnapshot(
          tuneAdjustments: [_tune(start: _s1, end: _s4)],
        ).windowedTo(start: _s3, end: _s6);

        expect(result.tuneAdjustments.single.startTime, equals(Duration.zero));
        expect(result.tuneAdjustments.single.endTime, equals(_s1));
      });

      test('drops a tune adjustment outside the window', () {
        final result = EditorOverlaySnapshot(
          tuneAdjustments: [
            _tune(start: const Duration(seconds: 7)),
          ],
        ).windowedTo(start: _s3, end: _s6);

        expect(result.tuneAdjustments, isEmpty);
      });
    });

    group('windowedTo effects', () {
      test('windows a whole-video effect to the clip, from its start', () {
        final result = const EditorOverlaySnapshot(
          effects: [VideoEffect.vhs(intensity: 0.5)],
        ).windowedTo(start: _s3, end: _s6);

        expect(result.isEmpty, isFalse);
        expect(
          result.effects.single,
          const VideoEffect.vhs(
            intensity: 0.5,
            startTime: Duration.zero,
            endTime: _s3,
          ),
        );
      });

      test('drops an effect outside the window', () {
        final result = const EditorOverlaySnapshot(
          effects: [VideoEffect.glitch(startTime: _s6)],
        ).windowedTo(start: _s3, end: _s6);

        expect(result.effects, isEmpty);
      });

      test('windows an echo trail like a built-in effect', () {
        final result = const EditorOverlaySnapshot(
          customEffects: [
            CustomVideoEffect(id: 'divine.echo', params: {'intensity': 0.5}),
            CustomVideoEffect(id: 'divine.echo', startTime: _s6),
          ],
        ).windowedTo(start: _s3, end: _s6);

        expect(result.isEmpty, isFalse);
        expect(result.customEffects, const [
          CustomVideoEffect(
            id: 'divine.echo',
            params: {'intensity': 0.5},
            startTime: Duration.zero,
            endTime: _s3,
          ),
        ]);
      });
    });

    group('windowedTo pass-through', () {
      test(
        'carries blur and bodySize through — neither is a timeline value',
        () {
          final result = const EditorOverlaySnapshot(
            blur: 5,
            bodySize: Size(100, 200),
          ).windowedTo(start: _s3, end: _s6);

          expect(result.blur, equals(5));
          expect(result.bodySize, equals(const Size(100, 200)));
        },
      );

      test('keeps blur but drops timed overlays for an empty window', () {
        final result = EditorOverlaySnapshot(
          capturedLayers: [_layer(start: Duration.zero, end: _s6)],
          filterStates: [_filter()],
          blur: 5,
          bodySize: const Size(100, 200),
        ).windowedTo(start: _s3, end: _s3);

        expect(result.capturedLayers, isEmpty);
        expect(result.filterStates, isEmpty);
        expect(result.blur, equals(5));
        expect(result.bodySize, equals(const Size(100, 200)));
      });
    });

    group('windowedTo clamped-edge animations', () {
      Layer windowedLayer(ExportedLayer source) => EditorOverlaySnapshot(
        capturedLayers: [source],
      ).windowedTo(start: _s3, end: _s6).capturedLayers.single.layer;

      test('keeps enter and exit fades for a layer fully inside the clip', () {
        // 4s-5s sits inside the 3s-6s clip: both edges are the layer's own, so
        // its fades belong.
        final layer = windowedLayer(
          _animatedLayer(
            start: _s4,
            end: _s5,
            enterDuration: const Duration(milliseconds: 200),
            exitDuration: const Duration(milliseconds: 200),
          ),
        );

        expect(layer.enterDuration, equals(const Duration(milliseconds: 200)));
        expect(layer.exitDuration, equals(const Duration(milliseconds: 200)));
      });

      test('drops the enter fade when the layer began before the clip', () {
        // 1s-4s over a 3s-6s clip: the fade-in played at 1s, before the clip.
        final layer = windowedLayer(
          _animatedLayer(
            start: _s1,
            end: _s4,
            enterDuration: const Duration(milliseconds: 200),
            exitDuration: const Duration(milliseconds: 200),
          ),
        );

        expect(layer.enterDuration, isNull);
        // The layer still ends inside the clip, so its exit fade stays.
        expect(layer.exitDuration, equals(const Duration(milliseconds: 200)));
      });

      test('drops the exit fade when the layer outlives the clip', () {
        // 4s-10s over a 3s-6s clip: the fade-out plays at 10s, after the clip.
        final layer = windowedLayer(
          _animatedLayer(
            start: _s4,
            end: const Duration(seconds: 10),
            enterDuration: const Duration(milliseconds: 200),
            exitDuration: const Duration(milliseconds: 200),
          ),
        );

        expect(layer.enterDuration, equals(const Duration(milliseconds: 200)));
        expect(layer.exitDuration, isNull);
      });

      test('drops both fades for an unbounded layer', () {
        // null/null spans the whole composition — steadily on screen over the
        // clip, so neither fade ever played over it.
        final layer = windowedLayer(
          _animatedLayer(
            enterDuration: const Duration(milliseconds: 200),
            exitDuration: const Duration(milliseconds: 200),
          ),
        );

        expect(layer.enterDuration, isNull);
        expect(layer.exitDuration, isNull);
      });

      test('drops the animateIn animation when the layer began earlier', () {
        final layer = windowedLayer(
          _animatedLayer(
            start: _s1,
            end: _s4,
            animations: [
              _anim(AnimationPhase.animateIn),
              _anim(AnimationPhase.animateOut),
            ],
          ),
        );

        expect(
          layer.animations.map((a) => a.phase),
          equals([AnimationPhase.animateOut]),
        );
      });

      test(
        'drops the animateOut animation when the layer outlives the clip',
        () {
          final layer = windowedLayer(
            _animatedLayer(
              start: _s4,
              end: const Duration(seconds: 10),
              animations: [
                _anim(AnimationPhase.animateIn),
                _anim(AnimationPhase.animateOut),
              ],
            ),
          );

          expect(
            layer.animations.map((a) => a.phase),
            equals([AnimationPhase.animateIn]),
          );
        },
      );

      test('drops an animateInOut only when both edges were clamped', () {
        // Layer 1s-10s spans past both edges of the 3s-6s clip.
        final bothClamped = windowedLayer(
          _animatedLayer(
            start: _s1,
            end: const Duration(seconds: 10),
            animations: [_anim(AnimationPhase.animateInOut)],
          ),
        );
        expect(bothClamped.animations, isEmpty);

        // Layer 1s-4s is only clamped at the start, so the inOut phase stays.
        final oneEdgeClamped = windowedLayer(
          _animatedLayer(
            start: _s1,
            end: _s4,
            animations: [_anim(AnimationPhase.animateInOut)],
          ),
        );
        expect(
          oneEdgeClamped.animations.map((a) => a.phase),
          equals([AnimationPhase.animateInOut]),
        );
      });

      test('does not mutate the source layer when stripping animations', () {
        final source = _animatedLayer(
          start: _s1,
          end: const Duration(seconds: 10),
          enterDuration: const Duration(milliseconds: 200),
          exitDuration: const Duration(milliseconds: 200),
          animations: [_anim(AnimationPhase.animateIn)],
        );

        EditorOverlaySnapshot(
          capturedLayers: [source],
        ).windowedTo(start: _s3, end: _s6);

        expect(
          source.layer.enterDuration,
          equals(const Duration(milliseconds: 200)),
        );
        expect(
          source.layer.exitDuration,
          equals(const Duration(milliseconds: 200)),
        );
        expect(source.layer.animations, hasLength(1));
      });
    });
  });
}

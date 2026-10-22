// ABOUTME: Tests for LayerStyle: which layers take a style, and what each kind
// ABOUTME: of layer takes from a copied one — look, animations, opacity, blend
// ABOUTME: mode, mask.

import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/extensions/layer_animation_storage.dart';
import 'package:openvine/models/video_editor/audio_visualizer_layer.dart';
import 'package:openvine/models/video_editor/layer_style.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as pve;

const _canvas = Size(400, 700);
const _total = Duration(seconds: 6);
const _mask = LayerMask(shape: LayerMaskShape.ellipse, size: Size(0.4, 0.4));

const _typewriter = pve.LayerAnimation(
  type: pve.LayerAnimationType.typewriter,
  phase: pve.AnimationPhase.animateIn,
  duration: Duration(milliseconds: 500),
);
const _fadeIn = pve.LayerAnimation(
  type: pve.LayerAnimationType.fade,
  phase: pve.AnimationPhase.animateIn,
  duration: Duration(milliseconds: 300),
);

PaintLayer _drawing({String id = 'd', PaintMode mode = PaintMode.freeStyle}) =>
    PaintLayer(
      id: id,
      rawSize: const Size(10, 10),
      opacity: 1,
      item: PaintedModel(
        mode: mode,
        offsets: const [Offset.zero, Offset(10, 10)],
        erasedOffsets: const [],
        color: const Color(0xFFFF0000),
        strokeWidth: 6,
        opacity: 1,
      ),
    );

void main() {
  group(LayerStyle, () {
    group('canCopyLayerStyle', () {
      test('takes texts, drawings and visualizers but not a hidden area', () {
        expect(canCopyLayerStyle(TextLayer(text: 'Hi')), isTrue);
        expect(canCopyLayerStyle(_drawing()), isTrue);
        expect(
          canCopyLayerStyle(
            WidgetLayer(
              widget: const SizedBox(),
              meta: const AudioVisualizerLayerData().toMeta(),
            ),
          ),
          isTrue,
        );
        expect(canCopyLayerStyle(_drawing(mode: PaintMode.blur)), isFalse);
        expect(canCopyLayerStyle(null), isFalse);
      });
    });

    group('applyTo', () {
      test('gives a text the look and animations of a copied text', () {
        final source = TextLayer(
          text: 'Source',
          color: const Color(0xFFFFF140),
          background: const Color(0xFF07241B),
          colorMode: LayerBackgroundMode.background,
          align: TextAlign.right,
          animations: const [_fadeIn].toLayerAnimations(),
        );
        final target = TextLayer(id: 't', text: 'Target');

        final styled = LayerStyle.of(source, at: Duration.zero).applyTo(
          target,
          canvasSize: _canvas,
          totalDuration: _total,
        ) as TextLayer;

        expect(styled.text, 'Target');
        expect(styled.id, 't');
        expect(styled.color, const Color(0xFFFFF140));
        expect(styled.colorMode, LayerBackgroundMode.background);
        expect(styled.align, TextAlign.right);
        expect(styled.divineEnterAnimations, [_fadeIn]);
      });

      test("gives a drawing a text's animations without its typing", () {
        final source = TextLayer(
          text: 'Hi',
          animations: const [_typewriter, _fadeIn].toLayerAnimations(),
        )..opacity = 0.5;

        final styled = LayerStyle.of(
          source,
          at: Duration.zero,
        ).applyTo(_drawing(), canvasSize: _canvas, totalDuration: _total);

        expect(styled, isA<PaintLayer>());
        expect(styled.divineEnterAnimations, [_fadeIn]);
        expect(styled.opacity, 0.5);
      });

      test('leaves a keyframed layer fading through its keyframes', () {
        final target = _drawing()
          ..keyframes = [
            const LayerKeyframe(
              time: Duration.zero,
              offset: Offset.zero,
              opacity: 0.2,
            ),
            const LayerKeyframe(
              time: Duration(seconds: 1),
              offset: Offset.zero,
              opacity: 0.8,
            ),
          ];

        final styled = const LayerStyle(
          opacity: 0.5,
        ).applyTo(target, canvasSize: _canvas, totalDuration: _total);

        expect(styled.opacity, 1);
        expect(styled.keyframes.map((k) => k.opacity), [0.2, 0.8]);
      });

      test('carries the blend mode, and takes it off when the style has '
          'none', () {
        final source = TextLayer(text: 'a', blendMode: BlendMode.screen);
        final style = LayerStyle.of(source, at: Duration.zero);

        expect(
          style
              .applyTo(_drawing(), canvasSize: _canvas, totalDuration: _total)
              .blendMode,
          BlendMode.screen,
        );
        expect(
          const LayerStyle()
              .applyTo(
                _drawing()..blendMode = BlendMode.multiply,
                canvasSize: _canvas,
                totalDuration: _total,
              )
              .blendMode,
          BlendMode.srcOver,
        );
      });

      test('takes the mask off a layer when the style has none', () {
        final target = _drawing()..mask = _mask;

        final styled = const LayerStyle().applyTo(
          target,
          canvasSize: _canvas,
          totalDuration: _total,
        );

        expect(styled.mask, isNull);
      });

      test('keeps a mask round on a layer of another shape', () {
        final source = _drawing()..mask = _mask;

        final styled =
            LayerStyle.of(
              source,
              at: Duration.zero,
              boxSize: const Size(100, 100),
            ).applyTo(
              _drawing(id: 'wide'),
              canvasSize: _canvas,
              totalDuration: _total,
              boxSize: const Size(200, 100),
            );

        // 40 % of a 100 px square is 40 px across; on a 200 × 100 box that
        // is 20 % of its width and 40 % of its height.
        expect(styled.mask?.size.width, closeTo(0.2, 1e-9));
        expect(styled.mask?.size.height, closeTo(0.4, 1e-9));
      });

      test('gives an audio visualizer no mask', () {
        final visualizer = WidgetLayer(
          widget: const SizedBox(),
          meta: const AudioVisualizerLayerData().toMeta(),
        );

        final styled = const LayerStyle(
          mask: _mask,
        ).applyTo(visualizer, canvasSize: _canvas, totalDuration: _total);

        expect(styled.mask, isNull);
      });
    });
  });
}

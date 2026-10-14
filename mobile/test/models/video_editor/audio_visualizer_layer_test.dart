// ABOUTME: Tests how an audio visualizer layer keeps its look in its meta and
// ABOUTME: how it reaches the export: its box, rotation, color and levels.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/layer_animation_storage.dart';
import 'package:openvine/models/video_editor/audio_visualizer_layer.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:openvine/utils/audio_band_energies.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as pve;
import 'package:pro_video_editor/pro_video_editor.dart'
    show AudioVisualizerStyle;

const _ring = AudioVisualizerLayerData(
  style: AudioVisualizerStyle.circle,
  color: VineTheme.whiteText,
);

WidgetLayer _layer({
  AudioVisualizerLayerData data = _ring,
  bool inExportMeta = true,
  bool inOwnMeta = true,
  Offset offset = Offset.zero,
  double rotation = 0,
  double opacity = 1,
}) => WidgetLayer(
  widget: const SizedBox(),
  width: 100,
  offset: offset,
  rotation: rotation,
  opacity: opacity,
  meta: inOwnMeta ? data.toMeta() : null,
  exportConfigs: WidgetLayerExportConfigs(
    id: 'visualizer',
    meta: inExportMeta ? data.toMeta() : null,
  ),
);

void main() {
  group(AudioVisualizerLayerData, () {
    group('meta', () {
      test('roundtrips its style and color', () {
        expect(AudioVisualizerLayerData.fromMeta(_ring.toMeta()), _ring);
      });

      test('is read from either meta slot of the layer', () {
        expect(AudioVisualizerLayerData.of(_layer(inOwnMeta: false)), _ring);
        expect(AudioVisualizerLayerData.of(_layer(inExportMeta: false)), _ring);
      });

      test('tells a visualizer from a sticker or another layer', () {
        expect(
          AudioVisualizerLayerData.isAudioVisualizerLayer(_layer()),
          isTrue,
        );
        expect(
          AudioVisualizerLayerData.isAudioVisualizerLayer(
            WidgetLayer(
              widget: const SizedBox(),
              meta: const {'assetPath': 'assets/sticker.svg'},
            ),
          ),
          isFalse,
        );
        expect(
          AudioVisualizerLayerData.isAudioVisualizerLayer(TextLayer(text: 'a')),
          isFalse,
        );
      });

      test('roundtrips its band count, reaction and bar width', () {
        const tuned = AudioVisualizerLayerData(
          style: AudioVisualizerStyle.mirroredBars,
          bands: 40,
          reaction: 0.8,
          barFill: 0.4,
        );

        expect(AudioVisualizerLayerData.fromMeta(tuned.toMeta()), tuned);
      });

      test(
        'opens a visualizer saved before the options with their defaults',
        () {
          final data = AudioVisualizerLayerData.fromMeta(const {
            audioVisualizerLayerKindKey: audioVisualizerLayerKind,
            audioVisualizerLayerStyleKey: 'wave',
            audioVisualizerLayerBandCountKey: 200,
            audioVisualizerLayerReactionKey: 3,
            audioVisualizerLayerBarFillKey: 0,
          });

          expect(data?.bands, isNull);
          expect(
            data?.reaction,
            VideoEditorConstants.audioVisualizerDefaultReaction,
          );
          expect(data?.barFill, isNull);
        },
      );

      test('falls back to bars and the default color', () {
        expect(
          AudioVisualizerLayerData.fromMeta(const {
            audioVisualizerLayerKindKey: audioVisualizerLayerKind,
            audioVisualizerLayerStyleKey: 'spiral',
          }),
          const AudioVisualizerLayerData(),
        );
      });
    });

    test('takes its band count and shape from its style', () {
      expect(
        _ring.bandCount,
        VideoEditorConstants.audioVisualizerBandCount(
          AudioVisualizerStyle.circle,
        ),
      );
      expect(_ring.aspectRatio, 1);
      expect(const AudioVisualizerLayerData().aspectRatio, 3);
    });

    test('shows the bands it is given, within what the sound is measured '
        'in', () {
      const bars = AudioVisualizerLayerData();

      expect(
        bars.bandCount,
        VideoEditorConstants.audioVisualizerBandCount(
          AudioVisualizerStyle.bars,
        ),
      );
      expect(bars.copyWith(bands: 37).bandCount, 37);
      expect(bars.copyWith(bands: 100).bandCount, audioBandCount);
      expect(
        bars.copyWith(bands: 1).bandCount,
        VideoEditorConstants.audioVisualizerMinBandCount,
      );
    });

    test('draws its bars at the style width unless given its own', () {
      expect(
        const AudioVisualizerLayerData().effectiveBarFill,
        VideoEditorConstants.audioVisualizerDefaultBarFill(
          AudioVisualizerStyle.bars,
        ),
      );
      expect(
        const AudioVisualizerLayerData(barFill: 0.4).effectiveBarFill,
        0.4,
      );
    });

    test('copyWith changes only what it is given', () {
      final changed = _ring.copyWith(style: AudioVisualizerStyle.wave);

      expect(changed.style, AudioVisualizerStyle.wave);
      expect(changed.color, _ring.color);
    });
  });

  group('visualizerFor', () {
    final energies = bandEnergies(
      Float32List.fromList([
        for (var i = 0; i < 44100; i++)
          0.5 * math.sin(2 * math.pi * 1000 * i / 44100),
      ]),
      sampleRate: 44100,
    );

    test('draws its own look from the energies of the sound', () {
      const data = AudioVisualizerLayerData(
        style: AudioVisualizerStyle.mirroredBars,
        color: VineTheme.whiteText,
        bands: 12,
        barFill: 0.4,
      );
      final visualizer = data.visualizerFor(energies);

      expect(visualizer.style, AudioVisualizerStyle.mirroredBars);
      expect(visualizer.color, VineTheme.whiteText);
      expect(visualizer.bandCount, 12);
      expect(visualizer.barFill, 0.4);
      // A second of sound, 60 rows of 12 bands.
      expect(visualizer.levels, hasLength(60 * 12));
      expect(visualizer.levels.any((level) => level > 0), isTrue);
    });

    test('takes another color when given one', () {
      const data = AudioVisualizerLayerData(style: AudioVisualizerStyle.wave);
      final faded = VineTheme.whiteText.withValues(alpha: 0.5);

      expect(data.visualizerFor(energies, color: faded).color, faded);
    });
  });

  group('audioVisualizerImageLayer', () {
    // A 100 x 200 body mapped onto a 300 x 600 frame: three frame pixels per
    // body pixel, with the body's top-left on the frame's.
    final mapping = ExportLayerMapping(
      bodySize: const Size(100, 200),
      frameSize: const Size(300, 600),
      targetAspectRatio: 0.5,
    );
    final timelineMap = TransitionTimelineMap.fromClips(const []);

    ExportedLayer captured(WidgetLayer layer, Size logicalSize) =>
        ExportedLayer(
          layer: layer,
          bytes: Uint8List.fromList(const [1, 2, 3]),
          logicalSize: logicalSize,
        );

    test("covers the layer's box in frame pixels", () {
      final image = audioVisualizerImageLayer(
        captured(_layer(offset: const Offset(10, -20)), const Size(40, 40)),
        _ring,
        bodySize: const Size(100, 200),
        mapping: mapping,
        timelineMap: timelineMap,
      );

      // A 40 x 40 box around (60, 80), the body's center moved by the
      // offset.
      expect(image.size, const Size(120, 120));
      expect(image.offset, const Offset(120, 180));
      expect(image.audioVisualizer?.style, AudioVisualizerStyle.circle);
    });

    test('passes the rotation on with the unturned box', () {
      final cos = math.cos(0.5).abs();
      final sin = math.sin(0.5).abs();
      final image = audioVisualizerImageLayer(
        captured(
          _layer(rotation: 0.5),
          Size(40 * cos + 40 * sin, 40 * sin + 40 * cos),
        ),
        _ring,
        bodySize: const Size(100, 200),
        mapping: mapping,
        timelineMap: timelineMap,
      );

      expect(image.rotation, 0.5);
      expect(image.size!.width, closeTo(120, 1e-6));
      expect(image.size!.height, closeTo(120, 1e-6));
    });

    test('carries the opacity of the layer in its color', () {
      final image = audioVisualizerImageLayer(
        captured(_layer(opacity: 0.5), const Size(40, 40)),
        _ring,
        bodySize: const Size(100, 200),
        mapping: mapping,
        timelineMap: timelineMap,
      );

      expect(image.audioVisualizer!.color.a, closeTo(0.5, 1e-3));
    });

    test('passes its bar width and reaction on', () {
      final energies = Float32List(2 * audioBandCount)..fillRange(0, 48, 1);
      ExportedLayer item(AudioVisualizerLayerData data) => captured(
        _layer(data: data),
        const Size(40, 40),
      );
      pve.ImageLayer build(AudioVisualizerLayerData data) =>
          audioVisualizerImageLayer(
            item(data),
            data,
            bodySize: const Size(100, 200),
            mapping: mapping,
            timelineMap: timelineMap,
            energies: energies,
          );

      const thin = AudioVisualizerLayerData(barFill: 0.4, reaction: 0);
      const lively = AudioVisualizerLayerData(barFill: 0.4, reaction: 1);
      expect(build(thin).audioVisualizer!.barFill, 0.4);
      // A calm bar rises slowly from silence; a lively one at once.
      expect(
        build(thin).audioVisualizer!.levels.first,
        lessThan(build(lively).audioVisualizer!.levels.first),
      );
    });

    test('draws its levels from the energies of the sound', () {
      final energies = Float32List(2 * audioBandCount)..fillRange(0, 48, 1);
      final image = audioVisualizerImageLayer(
        captured(_layer(), const Size(40, 40)),
        _ring,
        bodySize: const Size(100, 200),
        mapping: mapping,
        timelineMap: timelineMap,
        energies: energies,
      );
      final visualizer = image.audioVisualizer!;

      expect(visualizer.bandCount, _ring.bandCount);
      expect(visualizer.frameCount, 2);
      expect(visualizer.framesPerSecond, audioBandFrameRate);
      expect(visualizer.levels.first, greaterThan(0));
    });

    test('rests without energies', () {
      final image = audioVisualizerImageLayer(
        captured(_layer(), const Size(40, 40)),
        _ring,
        bodySize: const Size(100, 200),
        mapping: mapping,
        timelineMap: timelineMap,
      );

      expect(image.audioVisualizer!.frameCount, 0);
    });
  });
}

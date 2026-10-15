// ABOUTME: Tests which sound an export's audio visualizers are drawn from: the
// ABOUTME: clips, detached clips and music, cut where the render ends.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/audio_visualizer_layer.dart';
import 'package:openvine/services/video_editor/detached_clip_composite.dart';
import 'package:openvine/services/video_editor/render_audio_fetcher.dart';
import 'package:openvine/services/video_editor/render_audio_visualizer_energies.dart';
import 'package:openvine/services/video_editor/video_editor_audio_level_resolver.dart';
import 'package:openvine/utils/audio_band_energies.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show ExportedLayer, Layer, WidgetLayer, WidgetLayerExportConfigs;
import 'package:pro_video_editor/pro_video_editor.dart'
    show AudioExtractConfigs, EditorVideo;

import '../../helpers/audio_samples.dart';

/// The band a 1 kHz tone falls into.
const _toneBand = 25;

Duration _ms(int milliseconds) => Duration(milliseconds: milliseconds);

ExportedLayer _exported(Layer layer) =>
    ExportedLayer(layer: layer, bytes: Uint8List(0), logicalSize: Size.zero);

ExportedLayer _visualizer() {
  final meta = const AudioVisualizerLayerData().toMeta();
  return _exported(
    WidgetLayer(
      widget: const SizedBox(),
      meta: meta,
      exportConfigs: WidgetLayerExportConfigs(id: 'visualizer', meta: meta),
    ),
  );
}

DivineVideoClip _clip(String id, {double volume = 1}) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('${Directory.systemTemp.path}/$id.mp4'),
  duration: const Duration(seconds: 2),
  recordedAt: DateTime(2026),
  targetAspectRatio: model.AspectRatio.vertical,
  originalAspectRatio: 9 / 16,
  volume: volume,
);

/// Extracts a steady 1 kHz tone of the stretch it is asked for, and records
/// every extraction.
class _ToneFile {
  final reads = <AudioExtractConfigs>[];

  Future<Uint8List> call(AudioExtractConfigs configs) async {
    reads.add(configs);
    final from = configs.startTime ?? Duration.zero;
    final to = configs.endTime ?? const Duration(seconds: 30);
    final samples = silentAudio(to - from);
    for (var i = 0; i < samples.length; i++) {
      samples[i] = 0.5 * math.sin(2 * math.pi * 1000 * i / testSampleRate);
    }
    return wavBytes(samples);
  }
}

double _energy(Float32List mix, int row) =>
    mix[row * audioBandCount + _toneBand];

void main() {
  group('audioVisualizerEnergiesForRender', () {
    late Directory tempDir;
    late _ToneFile tone;
    late List<String> tempFilePaths;
    late int downloads;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('render_visualizer_');
      tone = _ToneFile();
      tempFilePaths = [];
      downloads = 0;
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    RenderAudioFetcher fetcher() => RenderAudioFetcher(
      clientFactory: () => MockClient((request) async {
        downloads++;
        return http.Response.bytes(wavBytes(silentAudio(_ms(10))), 200);
      }),
      tempDirectory: tempDir,
      baseDelay: Duration.zero,
    );

    test('reads nothing without an audio visualizer', () async {
      final energies = await audioVisualizerEnergiesForRender(
        capturedLayers: [_exported(Layer(id: 'sticker'))],
        sounds: const [],
        clips: [_clip('a')],
        detached: const [],
        maxOutputDuration: null,
        audioFetcher: fetcher(),
        tempFilePaths: tempFilePaths,
        logName: 'test',
        resolver: VideoEditorAudioLevelResolver(extractAudio: tone.call),
      );

      expect(energies, isNull);
      expect(tone.reads, isEmpty);
    });

    test('follows a detached clip while its layer plays', () async {
      final detached = _clip('detached');
      final energies = await audioVisualizerEnergiesForRender(
        capturedLayers: [_visualizer()],
        sounds: const [],
        clips: [_clip('a', volume: 0)],
        detached: [
          DetachedClipExportLayer(
            clip: detached,
            layer: Layer(
              id: 'detached',
              startTime: _ms(500),
              endTime: _ms(1500),
            ),
            logicalSize: Size.zero,
            sourceOffset: _ms(200),
          ),
        ],
        maxOutputDuration: null,
        audioFetcher: fetcher(),
        tempFilePaths: tempFilePaths,
        logName: 'test',
        resolver: VideoEditorAudioLevelResolver(extractAudio: tone.call),
      );

      expect(
        tone.reads.map((read) => read.video),
        equals([detached.video]),
      );
      // Read from the layer's offset into the clip, with the context before it.
      expect(
        tone.reads.single.startTime,
        equals(_ms(200) - VideoEditorAudioLevelResolver.context),
      );
      expect(_energy(energies!, 15), equals(0));
      expect(_energy(energies, 60), greaterThan(0));
      expect(_energy(energies, 105), equals(0));
    });

    test('ends where the render is cut', () async {
      final energies = await audioVisualizerEnergiesForRender(
        capturedLayers: [_visualizer()],
        sounds: const [],
        clips: [_clip('a')],
        detached: const [],
        maxOutputDuration: const Duration(seconds: 1),
        audioFetcher: fetcher(),
        tempFilePaths: tempFilePaths,
        logName: 'test',
        resolver: VideoEditorAudioLevelResolver(extractAudio: tone.call),
      );

      expect(energies, hasLength(audioBandFrameRate * audioBandCount));
    });

    test('ends with the video when the render is cut later', () async {
      final energies = await audioVisualizerEnergiesForRender(
        capturedLayers: [_visualizer()],
        sounds: const [],
        clips: [_clip('a')],
        detached: const [],
        maxOutputDuration: const Duration(seconds: 5),
        audioFetcher: fetcher(),
        tempFilePaths: tempFilePaths,
        logName: 'test',
        resolver: VideoEditorAudioLevelResolver(extractAudio: tone.call),
      );

      expect(energies, hasLength(2 * audioBandFrameRate * audioBandCount));
    });

    test(
      "downloads a sound two parts share once, into the render's temp files",
      () async {
        final energies = await audioVisualizerEnergiesForRender(
          capturedLayers: [_visualizer()],
          sounds: [
            for (final id in ['music', 'music-again'])
              AudioEvent(
                id: id,
                pubkey: 'a' * 64,
                createdAt: 1735689600,
                url: 'https://example.com/music.m4a',
                duration: 30,
                startTime: id == 'music' ? Duration.zero : _ms(1000),
              ),
          ],
          clips: [_clip('a', volume: 0)],
          detached: const [],
          maxOutputDuration: null,
          audioFetcher: fetcher(),
          tempFilePaths: tempFilePaths,
          logName: 'test',
          resolver: VideoEditorAudioLevelResolver(extractAudio: tone.call),
        );

        expect(energies, isNotNull);
        expect(downloads, equals(1));
        expect(tempFilePaths, hasLength(1));
        expect(tempFilePaths.single, startsWith(tempDir.path));
        expect(
          tone.reads.map((read) => read.video.file?.path).toSet(),
          equals({tempFilePaths.single}),
        );
      },
    );
  });
}

// ABOUTME: Tests optional waveform and duration enrichment for saved sounds.
// ABOUTME: Verifies source mapping, compact samples, and quiet failure.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/saved_sounds/saved_sound_media_probe.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

AudioEvent _sound({
  required String id,
  required String url,
  double? duration,
}) => AudioEvent(
  id: id,
  pubkey: 'creator',
  createdAt: 1,
  url: url,
  duration: duration,
);

WaveformData _waveform({
  required List<double> left,
  List<double>? right,
  Duration duration = const Duration(seconds: 7),
}) => WaveformData(
  leftChannel: Float32List.fromList(left),
  rightChannel: right == null ? null : Float32List.fromList(right),
  sampleRate: 44100,
  duration: duration,
  samplesPerSecond: 10,
);

VideoMetadata _metadata(Duration duration) => VideoMetadata(
  duration: duration,
  extension: 'm4a',
  fileSize: 1,
  resolution: const Size(1, 1),
  rotation: 0,
  bitrate: 1,
);

void main() {
  group(ProVideoEditorSavedSoundMediaProbe, () {
    test('maps asset, file, and network resolved sources', () async {
      final captured = <EditorVideo>[];
      final probe = ProVideoEditorSavedSoundMediaProbe(
        getWaveform: (config) async {
          captured.add(config.video);
          return _waveform(left: const [0.2]);
        },
      );

      await probe.probe(
        _sound(id: 'bundled_bell', url: 'asset://assets/bell.m4a'),
      );
      await probe.probe(
        _sound(id: 'imported_recording', url: '/tmp/recording.m4a'),
      );
      await probe.probe(
        _sound(id: 'remote', url: 'https://example.com/remote.m4a'),
      );

      expect(captured[0].assetPath, 'assets/bell.m4a');
      expect(captured[1].file?.path, '/tmp/recording.m4a');
      expect(captured[2].networkUrl, 'https://example.com/remote.m4a');
    });

    test('combines stereo amplitudes into non-negative mono samples', () async {
      final probe = ProVideoEditorSavedSoundMediaProbe(
        getWaveform: (_) async => _waveform(
          left: const [-0.2, 0.4],
          right: const [0.6, -0.2],
        ),
      );

      final result = await probe.probe(
        _sound(id: 'remote', url: 'https://example.com/audio.m4a'),
      );

      expect(result!.waveformSamples[0], closeTo(0.4, 0.0001));
      expect(result.waveformSamples[1], closeTo(0.3, 0.0001));
      expect(result.waveformSamples, everyElement(isNonNegative));
    });

    test('downsamples waveform to no more than 96 peak buckets', () async {
      final samples = List<double>.generate(300, (index) => index / 300);
      final probe = ProVideoEditorSavedSoundMediaProbe(
        getWaveform: (_) async => _waveform(left: samples),
      );

      final result = await probe.probe(
        _sound(id: 'remote', url: 'https://example.com/audio.m4a'),
      );

      expect(result!.waveformSamples, hasLength(96));
      expect(result.waveformSamples.last, closeTo(299 / 300, 0.0001));
    });

    test('preserves duration returned with waveform data', () async {
      final probe = ProVideoEditorSavedSoundMediaProbe(
        getWaveform: (_) async => _waveform(
          left: const [0.2],
          duration: const Duration(milliseconds: 7250),
        ),
      );

      final result = await probe.probe(
        _sound(id: 'remote', url: 'https://example.com/audio.m4a'),
      );

      expect(result!.durationSeconds, 7.25);
    });

    test('falls back to metadata duration when waveform fails', () async {
      final probe = ProVideoEditorSavedSoundMediaProbe(
        getWaveform: (_) => Future.error(StateError('decoder failed')),
        getMetadata: (_) async => _metadata(
          const Duration(milliseconds: 3500),
        ),
      );

      final result = await probe.probe(
        _sound(id: 'remote', url: 'https://example.com/audio.m4a'),
      );

      expect(result!.durationSeconds, 3.5);
      expect(result.waveformSamples, isEmpty);
    });

    test('complete failure returns no enrichment and does not throw', () async {
      final probe = ProVideoEditorSavedSoundMediaProbe(
        getWaveform: (_) => Future.error(StateError('waveform failed')),
        getMetadata: (_) => Future.error(StateError('metadata failed')),
      );

      final result = await probe.probe(
        _sound(id: 'remote', url: 'https://example.com/audio.m4a'),
      );

      expect(result, isNull);
    });
  });
}

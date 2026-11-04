// ABOUTME: Tests for SoundSilenceTrimmer: silent sounds are refused, silent
// ABOUTME: edges are cut without re-encoding, and failures publish uncut.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/sound_silence_trimmer.dart';
import 'package:openvine/utils/audible_range.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

const _blocksPerSecond = 200;

/// A stereo waveform of [seconds] seconds, digital silence except for the
/// stretches in [loud], given in seconds.
WaveformData _waveform(
  double seconds, {
  List<(double, double)> loud = const [],
}) {
  final peaks = Float32List((seconds * _blocksPerSecond).round());
  for (var block = 0; block < peaks.length; block++) {
    final at = block / _blocksPerSecond;
    if (loud.any((range) => at >= range.$1 && at < range.$2)) {
      peaks[block] = 0.5;
    }
  }
  return WaveformData(
    leftChannel: peaks,
    rightChannel: Float32List.fromList(peaks),
    sampleRate: 48000,
    duration: _seconds(seconds),
    samplesPerSecond: _blocksPerSecond,
  );
}

Duration _seconds(double seconds) =>
    Duration(microseconds: (seconds * Duration.microsecondsPerSecond).round());

class _FakeProVideoEditor extends ProVideoEditor {
  WaveformData? waveform;
  Exception? waveformError;
  Exception? extractError;
  Duration? writtenDuration;
  final measured = <WaveformConfigs>[];
  final extractions = <(String, AudioExtractConfigs)>[];

  @override
  void initializeStream() {}

  @override
  Future<WaveformData> getWaveform(
    WaveformConfigs value, {
    NativeLogLevel? nativeLogLevel,
  }) async {
    measured.add(value);
    if (waveformError case final error?) throw error;
    return waveform!;
  }

  @override
  Future<String> extractAudioToFile(
    String filePath,
    AudioExtractConfigs value, {
    NativeLogLevel? nativeLogLevel,
  }) async {
    extractions.add((filePath, value));
    // A failing extraction can leave a partial file behind.
    File(filePath).writeAsBytesSync(const [1, 2, 3]);
    if (extractError case final error?) throw error;
    return filePath;
  }

  @override
  Future<VideoMetadata> getMetadata(
    EditorVideo value, {
    bool checkStreamingOptimization = false,
    NativeLogLevel? nativeLogLevel,
  }) async {
    final duration = writtenDuration;
    if (duration == null) throw PlatformException(code: 'unreadable');
    return VideoMetadata(
      duration: duration,
      extension: 'wav',
      fileSize: 3,
      resolution: Size.zero,
      rotation: 0,
      bitrate: 0,
    );
  }
}

void main() {
  group(SoundSilenceTrimmer, () {
    late Directory tempDir;
    late File source;
    late _FakeProVideoEditor editor;
    late SoundSilenceTrimmer trimmer;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('sound-silence-trimmer');
      source = File('${tempDir.path}/sound.wav')..writeAsBytesSync(const [0]);
      editor = _FakeProVideoEditor();
      trimmer = SoundSilenceTrimmer(
        editor: editor,
        temporaryDirectory: () async => tempDir,
      );
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    Future<SoundTrimResult> trim([String mimeType = 'audio/wav']) =>
        trimmer.trim(path: source.path, mimeType: mimeType);

    group('trim', () {
      test('measures the sound itself at full resolution', () async {
        editor.waveform = _waveform(6);

        await trim();

        final configs = editor.measured.single;
        expect(configs.video.file?.path, source.path);
        expect(configs.resolution, WaveformResolution.high);
      });

      test('cuts a sound heard on the right channel only', () async {
        final silent = Float32List(10 * _blocksPerSecond);
        editor
          ..waveform = WaveformData(
            leftChannel: silent,
            rightChannel: _waveform(10, loud: [(2, 5)]).leftChannel,
            sampleRate: 48000,
            duration: _seconds(10),
            samplesPerSecond: _blocksPerSecond,
          )
          ..writtenDuration = const Duration(milliseconds: 3400);

        final result = await trim() as AudibleSound;

        final configs = editor.extractions.single.$2;
        expect(configs.startTime, _seconds(2) - soundEdgeMargin);
        expect(configs.endTime, _seconds(5) + soundEdgeMargin);
        expect(result.isTrimmed, isTrue);
      });

      test('refuses a sound with nothing to hear', () async {
        editor.waveform = _waveform(6);

        expect(await trim(), isA<SilentSound>());
        expect(editor.extractions, isEmpty);
      });

      test('keeps a sound audible from edge to edge as it is', () async {
        editor.waveform = _waveform(4, loud: [(0, 4)]);

        final result = await trim() as AudibleSound;

        expect(result.path, source.path);
        expect(result.mimeType, 'audio/wav');
        expect(result.isTrimmed, isFalse);
        expect(editor.extractions, isEmpty);
      });

      test('cuts a WAV to its audible part and the margin', () async {
        editor
          ..waveform = _waveform(10, loud: [(2, 5)])
          ..writtenDuration = const Duration(milliseconds: 3410);

        final result = await trim() as AudibleSound;

        final (output, configs) = editor.extractions.single;
        expect(configs.video.file?.path, source.path);
        expect(configs.format, AudioFormat.wav);
        expect(configs.startTime, _seconds(2) - soundEdgeMargin);
        expect(configs.endTime, _seconds(5) + soundEdgeMargin);
        expect(result.path, output);
        expect(output, endsWith('.wav'));
        expect(result.mimeType, 'audio/wav');
        expect(result.trimmedDuration, const Duration(milliseconds: 3410));
      });

      test('copies AAC into an m4a when it cuts', () async {
        editor
          ..waveform = _waveform(10, loud: [(2, 5)])
          ..writtenDuration = const Duration(milliseconds: 3400);

        final result = await trim('audio/mp4') as AudibleSound;

        expect(editor.extractions.single.$2.format, AudioFormat.m4a);
        expect(result.path, endsWith('.m4a'));
        expect(result.mimeType, 'audio/mp4');
      });

      test('copies an ADTS AAC file into an m4a when it cuts', () async {
        editor
          ..waveform = _waveform(10, loud: [(2, 5)])
          ..writtenDuration = const Duration(milliseconds: 3400);

        final result = await trim('audio/aac') as AudibleSound;

        expect(editor.extractions.single.$2.format, AudioFormat.m4a);
        expect(result.path, endsWith('.m4a'));
        expect(result.mimeType, 'audio/mp4');
      });

      test('takes the cut length when the copy cannot be measured', () async {
        editor.waveform = _waveform(10, loud: [(2, 5)]);

        final result = await trim() as AudibleSound;

        expect(result.trimmedDuration, _seconds(3) + soundEdgeMargin * 2);
      });

      test('publishes an MP3 uncut, which cannot be copied', () async {
        editor.waveform = _waveform(10, loud: [(2, 5)]);

        final result = await trim('audio/mpeg') as AudibleSound;

        expect(result.path, source.path);
        expect(result.isTrimmed, isFalse);
        expect(editor.extractions, isEmpty);
      });

      test('publishes uncut and leaves no copy when the cut fails', () async {
        editor
          ..waveform = _waveform(10, loud: [(2, 5)])
          ..extractError = PlatformException(code: 'extract');

        final result = await trim() as AudibleSound;

        expect(result.path, source.path);
        expect(result.isTrimmed, isFalse);
        expect(File(editor.extractions.single.$1).existsSync(), isFalse);
      });

      test('publishes uncut when the sound cannot be measured', () async {
        editor.waveformError = PlatformException(code: 'decode');

        final result = await trim();

        expect(result, isA<AudibleSound>());
        expect((result as AudibleSound).path, source.path);
      });

      test('publishes uncut when the measurement comes back empty', () async {
        editor.waveform = WaveformData(
          leftChannel: Float32List(0),
          sampleRate: 48000,
          duration: _seconds(2),
          samplesPerSecond: _blocksPerSecond,
        );

        final result = await trim();

        expect(result, isA<AudibleSound>());
        expect((result as AudibleSound).path, source.path);
      });

      test('treats a quiet but audible sound as audible', () async {
        final quiet = math
            .pow(10, (soundSilenceThresholdDbfs + 6) / 20)
            .toDouble();
        editor.waveform = WaveformData(
          leftChannel: Float32List(800)..fillRange(0, 800, quiet),
          sampleRate: 48000,
          duration: _seconds(4),
          samplesPerSecond: _blocksPerSecond,
        );

        final result = await trim();

        expect(result, isA<AudibleSound>());
        expect((result as AudibleSound).isTrimmed, isFalse);
      });
    });

    group('isSilent', () {
      test('is true for a sound with nothing to hear', () async {
        editor.waveform = _waveform(6);

        expect(await trimmer.isSilent(source.path), isTrue);
        expect(editor.extractions, isEmpty);
      });

      test('is false for a sound heard on the right channel only', () async {
        editor.waveform = WaveformData(
          leftChannel: Float32List(10 * _blocksPerSecond),
          rightChannel: _waveform(10, loud: [(2, 5)]).leftChannel,
          sampleRate: 48000,
          duration: _seconds(10),
          samplesPerSecond: _blocksPerSecond,
        );

        expect(await trimmer.isSilent(source.path), isFalse);
      });

      test('is false for a sound with something to hear', () async {
        editor.waveform = _waveform(10, loud: [(2, 5)]);

        expect(await trimmer.isSilent(source.path), isFalse);
        expect(editor.extractions, isEmpty);
      });

      test('is false when the sound cannot be measured', () async {
        editor.waveformError = PlatformException(code: 'decode');

        expect(await trimmer.isSilent(source.path), isFalse);
      });
    });

    group('deleteTrimmedCopy', () {
      test('deletes a cut copy', () async {
        final copy = File('${tempDir.path}/trimmed.wav')
          ..writeAsBytesSync(const [1]);

        await trimmer.deleteTrimmedCopy(
          AudibleSound(
            path: copy.path,
            mimeType: 'audio/wav',
            trimmedDuration: const Duration(seconds: 1),
          ),
        );

        expect(copy.existsSync(), isFalse);
      });

      test('leaves the source alone', () async {
        await trimmer.deleteTrimmedCopy(
          AudibleSound(path: source.path, mimeType: 'audio/wav'),
        );

        expect(source.existsSync(), isTrue);
      });
    });
  });
}

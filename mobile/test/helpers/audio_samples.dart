// ABOUTME: Builds synthetic audio for tests: drums, tones and crackle as mono
// ABOUTME: samples, and WAV files of them like the editor extracts.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pro_video_editor/pro_video_editor.dart';

/// The sample rate of the audio these helpers build.
const int testSampleRate = 16000;

/// Mono silence [length] long.
Float32List silentAudio(Duration length) =>
    Float32List(length.inMicroseconds * testSampleRate ~/ 1000000);

/// Adds a kick drum to [samples] at [at]: a 60 Hz thump fading over about a
/// tenth of a second.
void addKick(Float32List samples, Duration at, {double level = 0.9}) {
  _add(samples, at, const Duration(milliseconds: 400), (time) {
    return level * math.exp(-time / 0.08) * math.sin(2 * math.pi * 60 * time);
  });
}

/// Adds a hi-hat to [samples] at [at]: a short burst of noise.
void addHiHat(Float32List samples, Duration at, {double level = 0.2}) {
  final random = math.Random(at.inMicroseconds);
  _add(samples, at, const Duration(milliseconds: 100), (time) {
    return level * math.exp(-time / 0.015) * (2 * random.nextDouble() - 1);
  });
}

/// Adds a 400 Hz tone to [samples] from [at] for [length], swelling in over
/// 20 ms and fading out over 50 ms, as a spoken word does.
void addWord(
  Float32List samples,
  Duration at,
  Duration length, {
  double level = 0.5,
}) {
  final seconds = length.inMicroseconds / 1e6;
  _add(samples, at, length, (time) {
    final swell = math.min(1, time / 0.02);
    final fade = math.min(1, (seconds - time) / 0.05);
    return level * swell * fade * math.sin(2 * math.pi * 400 * time);
  });
}

/// Adds a crackle to [samples] at [at]: two milliseconds of noise.
void addCrackle(Float32List samples, Duration at, {double level = 0.2}) {
  final random = math.Random(at.inMicroseconds);
  _add(samples, at, const Duration(milliseconds: 2), (_) {
    return level * (2 * random.nextDouble() - 1);
  });
}

/// Adds noise at [level] to all of [samples], as a quiet recording has.
void addNoise(Float32List samples, {double level = 0.05}) {
  final random = math.Random(1);
  for (var i = 0; i < samples.length; i++) {
    samples[i] += level * (2 * random.nextDouble() - 1);
  }
}

void _add(
  Float32List samples,
  Duration at,
  Duration length,
  double Function(double time) sound,
) {
  final start = at.inMicroseconds * testSampleRate ~/ 1000000;
  final count = length.inMicroseconds * testSampleRate ~/ 1000000;
  for (var i = 0; i < count && start + i < samples.length; i++) {
    if (start + i >= 0) samples[start + i] += sound(i / testSampleRate);
  }
}

/// A WAV file of [samples], interleaved when [channels] is more than one.
///
/// [bits] picks integer PCM of 8, 16, 24 or 32 bits, or 32-bit floats with
/// [float]. [extensible] writes the header of WAVE_FORMAT_EXTENSIBLE, and
/// [format] the format code itself. [chunksBefore] go between the header and
/// the samples, and [claimedDataLength] overrides what the data chunk claims
/// to hold.
Uint8List wavBytes(
  List<double> samples, {
  int sampleRate = testSampleRate,
  int channels = 1,
  int bits = 16,
  bool float = false,
  bool extensible = false,
  int? format,
  List<({String id, List<int> body})> chunksBefore = const [],
  int? claimedDataLength,
}) {
  final width = bits ~/ 8;
  final data = ByteData(samples.length * width);
  for (var i = 0; i < samples.length; i++) {
    final value = samples[i];
    final at = i * width;
    if (float) {
      data.setFloat32(at, value, Endian.little);
      continue;
    }
    switch (bits) {
      case 8:
        data.setUint8(at, (value * 128 + 128).round().clamp(0, 255));
      case 16:
        data.setInt16(at, (value * 32767).round(), Endian.little);
      case 24:
        final integer = (value * 8388607).round();
        data
          ..setUint8(at, integer & 0xFF)
          ..setUint8(at + 1, (integer >> 8) & 0xFF)
          ..setUint8(at + 2, (integer >> 16) & 0xFF);
      default:
        data.setInt32(at, (value * 2147483647).round(), Endian.little);
    }
  }

  final code = format ?? (float ? 3 : 1);
  final fmt = ByteData(extensible ? 40 : 16)
    ..setUint16(0, extensible ? 0xFFFE : code, Endian.little)
    ..setUint16(2, channels, Endian.little)
    ..setUint32(4, sampleRate, Endian.little)
    ..setUint32(8, sampleRate * channels * width, Endian.little)
    ..setUint16(12, channels * width, Endian.little)
    ..setUint16(14, bits, Endian.little);
  if (extensible) {
    fmt
      ..setUint16(16, 22, Endian.little)
      ..setUint16(18, bits, Endian.little)
      ..setUint16(24, code, Endian.little);
  }

  final body = BytesBuilder()..add(_ascii('WAVE'));
  void chunk(String id, List<int> bytes, {int? claimedLength}) {
    final size = ByteData(4)
      ..setUint32(0, claimedLength ?? bytes.length, Endian.little);
    body
      ..add(_ascii(id))
      ..add(size.buffer.asUint8List())
      ..add(bytes);
    if (bytes.length.isOdd) body.addByte(0);
  }

  chunk('fmt ', fmt.buffer.asUint8List());
  for (final extra in chunksBefore) {
    chunk(extra.id, extra.body);
  }
  chunk(
    'data',
    data.buffer.asUint8List(),
    claimedLength: claimedDataLength,
  );

  final riff = body.takeBytes();
  final size = ByteData(4)..setUint32(0, riff.length, Endian.little);
  return Uint8List.fromList([
    ..._ascii('RIFF'),
    ...size.buffer.asUint8List(),
    ...riff,
  ]);
}

/// Reads the stretch [configs] asks for out of a drum loop [fileLength] long,
/// with a kick every half second from 0.25 s into it, as a WAV file.
Uint8List drumLoopWav(
  AudioExtractConfigs configs, {
  Duration fileLength = const Duration(seconds: 30),
}) {
  final from = configs.startTime ?? Duration.zero;
  final to = configs.endTime ?? fileLength;
  final samples = silentAudio(to - from);
  for (
    var kick = const Duration(milliseconds: 250);
    kick < to;
    kick += const Duration(milliseconds: 500)
  ) {
    addKick(samples, kick - from);
  }
  return wavBytes(samples);
}

List<int> _ascii(String text) => text.codeUnits;

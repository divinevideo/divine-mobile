// ABOUTME: Reads 16-bit PCM WAV into mono float samples and writes mono float
// ABOUTME: samples back out as 16-bit PCM WAV.

import 'dart:typed_data';

/// Thrown when bytes handed to [decodeWav] are not a WAV it can read.
class WavFormatException implements Exception {
  /// Creates a [WavFormatException] describing [message].
  const WavFormatException(this.message);

  /// What made the bytes unreadable.
  final String message;

  @override
  String toString() => 'WavFormatException: $message';
}

/// Mono PCM audio as floats in `-1.0..1.0`.
class MonoAudio {
  /// Creates mono audio of [samples] recorded at [sampleRate] Hz.
  const MonoAudio({required this.samples, required this.sampleRate});

  /// One float per sample frame.
  final Float32List samples;

  /// Sample frames per second.
  final int sampleRate;
}

const int _pcmFormat = 1;
const int _bitsPerSample = 16;
const int _headerLength = 44;
const double _int16Scale = 32768;

/// Decodes a 16-bit PCM WAV file, averaging its channels into one.
///
/// Only the format `pro_video_editor` writes when it extracts audio — integer
/// PCM at 16 bits — is accepted. A `data` chunk whose declared size runs past
/// the end of [bytes], as a writer that never patched its header leaves it, is
/// read to the end of the file instead.
///
/// Throws a [WavFormatException] when [bytes] are not a RIFF/WAVE file, carry
/// any other sample format, or have no `fmt ` or `data` chunk.
MonoAudio decodeWav(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  if (bytes.length < 12 ||
      _fourCc(bytes, 0) != 'RIFF' ||
      _fourCc(bytes, 8) != 'WAVE') {
    throw const WavFormatException('Not a RIFF/WAVE file');
  }

  int? channels;
  int? sampleRate;
  int? dataOffset;
  int? dataLength;
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final id = _fourCc(bytes, offset);
    final declared = data.getUint32(offset + 4, Endian.little);
    final body = offset + 8;
    final available = bytes.length - body;
    final length = declared > available ? available : declared;
    if (id == 'fmt ') {
      if (length < 16) throw const WavFormatException('Truncated fmt chunk');
      final format = data.getUint16(body, Endian.little);
      final bits = data.getUint16(body + 14, Endian.little);
      if (format != _pcmFormat || bits != _bitsPerSample) {
        throw WavFormatException('Unsupported format $format at $bits bits');
      }
      channels = data.getUint16(body + 2, Endian.little);
      sampleRate = data.getUint32(body + 4, Endian.little);
    } else if (id == 'data') {
      dataOffset = body;
      dataLength = length;
    }
    // Chunks are word-aligned: an odd-sized body carries one pad byte.
    offset = body + length + (length.isOdd ? 1 : 0);
  }

  if (channels == null || sampleRate == null || channels == 0) {
    throw const WavFormatException('Missing fmt chunk');
  }
  if (dataOffset == null || dataLength == null) {
    throw const WavFormatException('Missing data chunk');
  }

  final frameBytes = channels * 2;
  final frames = dataLength ~/ frameBytes;
  final samples = Float32List(frames);
  for (var frame = 0; frame < frames; frame++) {
    var sum = 0;
    final start = dataOffset + frame * frameBytes;
    for (var channel = 0; channel < channels; channel++) {
      sum += data.getInt16(start + channel * 2, Endian.little);
    }
    samples[frame] = sum / channels / _int16Scale;
  }
  return MonoAudio(samples: samples, sampleRate: sampleRate);
}

/// Encodes [samples] at [sampleRate] Hz as a mono 16-bit PCM WAV file.
///
/// Samples outside `-1.0..1.0` are clamped.
Uint8List encodeWav(Float32List samples, int sampleRate) {
  final dataLength = samples.length * 2;
  final bytes = Uint8List(_headerLength + dataLength);
  final data = ByteData.sublistView(bytes)
    ..setUint32(4, 36 + dataLength, Endian.little)
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, _pcmFormat, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, sampleRate, Endian.little)
    ..setUint32(28, sampleRate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, _bitsPerSample, Endian.little)
    ..setUint32(40, dataLength, Endian.little);
  _writeFourCc(bytes, 0, 'RIFF');
  _writeFourCc(bytes, 8, 'WAVE');
  _writeFourCc(bytes, 12, 'fmt ');
  _writeFourCc(bytes, 36, 'data');
  for (var i = 0; i < samples.length; i++) {
    final value = (samples[i] * _int16Scale).round().clamp(-32768, 32767);
    data.setInt16(_headerLength + i * 2, value, Endian.little);
  }
  return bytes;
}

String _fourCc(Uint8List bytes, int offset) =>
    String.fromCharCodes(bytes, offset, offset + 4);

void _writeFourCc(Uint8List bytes, int offset, String id) {
  for (var i = 0; i < 4; i++) {
    bytes[offset + i] = id.codeUnitAt(i);
  }
}

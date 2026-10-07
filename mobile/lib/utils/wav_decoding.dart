// ABOUTME: Reads the samples of a WAV file into mono floats, so audio can be
// ABOUTME: analysed in Dart, for example for its beats.

import 'dart:typed_data';

/// The samples of the WAV file in [bytes], every channel mixed into one, from
/// -1 to 1, and how many there are a second; `null` when [bytes] is not a WAV
/// file of integer PCM (8, 16, 24 or 32 bits) or 32-bit float samples.
({Float32List samples, int sampleRate})? decodeWavMono(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  if (bytes.length < 12 || _tag(data, 0) != 'RIFF' || _tag(data, 8) != 'WAVE') {
    return null;
  }

  int? format;
  int? channels;
  int? sampleRate;
  int? bits;
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final id = _tag(data, offset);
    final size = data.getUint32(offset + 4, Endian.little);
    final body = offset + 8;
    if (id == 'fmt ' && body + 16 <= bytes.length) {
      format = data.getUint16(body, Endian.little);
      channels = data.getUint16(body + 2, Endian.little);
      sampleRate = data.getUint32(body + 4, Endian.little);
      bits = data.getUint16(body + 14, Endian.little);
      // WAVE_FORMAT_EXTENSIBLE names the real format in its sub-format GUID.
      if (format == 0xFFFE && size >= 26 && body + 26 <= bytes.length) {
        format = data.getUint16(body + 24, Endian.little);
      }
    } else if (id == 'data' &&
        format != null &&
        channels != null &&
        sampleRate != null &&
        bits != null) {
      // A file still being written, or streamed, can claim more data than it
      // holds; read what is there.
      final end = (body + size).clamp(body, bytes.length);
      return _mix(data, body, end, format, channels, sampleRate, bits);
    }
    // Chunks are padded to an even size.
    offset = body + size + (size.isOdd ? 1 : 0);
  }
  return null;
}

({Float32List samples, int sampleRate})? _mix(
  ByteData data,
  int start,
  int end,
  int format,
  int channels,
  int sampleRate,
  int bits,
) {
  final isFloat = format == 3 && bits == 32;
  final isInteger = format == 1 && const [8, 16, 24, 32].contains(bits);
  if ((!isFloat && !isInteger) || channels < 1 || sampleRate < 1) return null;
  final width = bits ~/ 8;
  final frames = (end - start) ~/ (width * channels);
  final samples = Float32List(frames);
  for (var frame = 0; frame < frames; frame++) {
    var sum = 0.0;
    for (var channel = 0; channel < channels; channel++) {
      final at = start + (frame * channels + channel) * width;
      sum += switch (bits) {
        _ when isFloat => data.getFloat32(at, Endian.little),
        8 => (data.getUint8(at) - 128) / 128,
        16 => data.getInt16(at, Endian.little) / 32768,
        24 =>
          (data.getUint8(at) |
                  data.getUint8(at + 1) << 8 |
                  data.getInt8(at + 2) << 16) /
              8388608,
        _ => data.getInt32(at, Endian.little) / 2147483648,
      };
    }
    samples[frame] = sum / channels;
  }
  return (samples: samples, sampleRate: sampleRate);
}

String _tag(ByteData data, int offset) => String.fromCharCodes([
  for (var i = 0; i < 4; i++) data.getUint8(offset + i),
]);

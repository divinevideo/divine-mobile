import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:voice_effects/voice_effects.dart';

/// A WAV file assembled chunk by chunk, so a test can shape exactly the file
/// a writer would produce.
Uint8List _wav(List<(String, List<int>)> chunks) {
  final body = BytesBuilder();
  for (final (id, data) in chunks) {
    body
      ..add(id.codeUnits)
      ..add(_uint32(data.length))
      ..add(data);
    if (data.length.isOdd) body.addByte(0);
  }
  final payload = body.takeBytes();
  return Uint8List.fromList([
    ...'RIFF'.codeUnits,
    ..._uint32(4 + payload.length),
    ...'WAVE'.codeUnits,
    ...payload,
  ]);
}

List<int> _fmt({int format = 1, int channels = 1, int bits = 16}) {
  final data = ByteData(16)
    ..setUint16(0, format, Endian.little)
    ..setUint16(2, channels, Endian.little)
    ..setUint32(4, 44100, Endian.little)
    ..setUint32(8, 44100 * channels * bits ~/ 8, Endian.little)
    ..setUint16(12, channels * bits ~/ 8, Endian.little)
    ..setUint16(14, bits, Endian.little);
  return data.buffer.asUint8List();
}

List<int> _int16(List<int> values) {
  final data = ByteData(values.length * 2);
  for (var i = 0; i < values.length; i++) {
    data.setInt16(i * 2, values[i], Endian.little);
  }
  return data.buffer.asUint8List();
}

List<int> _uint32(int value) =>
    (ByteData(4)..setUint32(0, value, Endian.little)).buffer.asUint8List();

void main() {
  group('encodeWav', () {
    test('round-trips through decodeWav', () {
      final samples = Float32List.fromList([0, 0.25, -0.5, 0.999, -1]);

      final decoded = decodeWav(encodeWav(samples, 48000));

      expect(decoded.sampleRate, equals(48000));
      expect(decoded.samples, hasLength(samples.length));
      for (var i = 0; i < samples.length; i++) {
        expect(decoded.samples[i], closeTo(samples[i], 1 / 32768));
      }
    });

    test('clamps samples outside full scale', () {
      final decoded = decodeWav(
        encodeWav(Float32List.fromList([1.5, -2]), 44100),
      );

      expect(decoded.samples[0], closeTo(32767 / 32768, 1e-9));
      expect(decoded.samples[1], equals(-1));
    });
  });

  group('decodeWav', () {
    test('averages stereo into mono', () {
      final bytes = _wav([
        ('fmt ', _fmt(channels: 2)),
        ('data', _int16([16384, 0, -16384, -16384])),
      ]);

      final decoded = decodeWav(bytes);

      expect(decoded.samples, equals([0.25, -0.5]));
    });

    test('skips unknown chunks, including their pad byte', () {
      final bytes = _wav([
        ('fmt ', _fmt()),
        ('LIST', [1, 2, 3]),
        ('data', _int16([8192])),
      ]);

      expect(decodeWav(bytes).samples, equals([0.25]));
    });

    test('reads to the end when the data size runs past the file', () {
      final bytes = _wav([
        ('fmt ', _fmt()),
        ('data', _int16([8192, -8192])),
      ]);
      // Declare twice the data that is there, as an unpatched header does.
      ByteData.sublistView(bytes).setUint32(40, 8, Endian.little);

      expect(decodeWav(bytes).samples, equals([0.25, -0.25]));
    });

    test('rejects bytes that are not RIFF/WAVE', () {
      expect(
        () => decodeWav(Uint8List.fromList('not a wav file'.codeUnits)),
        throwsA(isA<WavFormatException>()),
      );
    });

    test('rejects a sample format other than 16-bit PCM', () {
      final floats = _wav([
        ('fmt ', _fmt(format: 3, bits: 32)),
        ('data', [0, 0, 0, 0]),
      ]);

      expect(
        () => decodeWav(floats),
        throwsA(
          isA<WavFormatException>().having(
            (e) => e.toString(),
            'toString',
            contains('Unsupported format 3 at 32 bits'),
          ),
        ),
      );
    });

    test('rejects a truncated fmt chunk', () {
      expect(
        () => decodeWav(_wav([('fmt ', List.filled(8, 0))])),
        throwsA(isA<WavFormatException>()),
      );
    });

    test('rejects a file without a fmt chunk', () {
      expect(
        () => decodeWav(
          _wav([
            ('data', _int16([1])),
          ]),
        ),
        throwsA(isA<WavFormatException>()),
      );
    });

    test('rejects a file without a data chunk', () {
      expect(
        () => decodeWav(_wav([('fmt ', _fmt())])),
        throwsA(isA<WavFormatException>()),
      );
    });
  });
}

// ABOUTME: Tests for identifying a downloaded audio body's container
// ABOUTME: Covers byte sniffing, content-type and URL fallbacks, text bodies

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sound_service/sound_service.dart';

final Uri _url = Uri.parse('https://media.example/abc123');

Uint8List _wavBytes() => Uint8List.fromList([
  ...ascii.encode('RIFF'),
  0x24,
  0x00,
  0x00,
  0x00,
  ...ascii.encode('WAVE'),
  ...ascii.encode('fmt '),
]);

Uint8List _mp4Bytes() => Uint8List.fromList([
  0x00,
  0x00,
  0x00,
  0x18,
  ...ascii.encode('ftyp'),
  ...ascii.encode('isom'),
]);

final Uint8List _opaque = Uint8List.fromList(List<int>.filled(16, 0x42));

void main() {
  group('audioFileExtensionFor', () {
    test('reads the container off the first bytes', () {
      expect(audioFileExtensionFor(_wavBytes(), url: _url), '.wav');
      expect(audioFileExtensionFor(_mp4Bytes(), url: _url), '.mp4');
      expect(
        audioFileExtensionFor(
          Uint8List.fromList([...ascii.encode('OggS'), 0, 0, 0, 0]),
          url: _url,
        ),
        '.ogg',
      );
      expect(
        audioFileExtensionFor(
          Uint8List.fromList([...ascii.encode('fLaC'), 0, 0, 0, 0]),
          url: _url,
        ),
        '.flac',
      );
      expect(
        audioFileExtensionFor(
          Uint8List.fromList([...ascii.encode('ID3'), 4, 0, 0, 0]),
          url: _url,
        ),
        '.mp3',
      );
      expect(
        audioFileExtensionFor(
          Uint8List.fromList([0xFF, 0xFB, 0x90, 0x00]),
          url: _url,
        ),
        '.mp3',
        reason: 'MPEG-1 layer III frame sync',
      );
      expect(
        audioFileExtensionFor(
          Uint8List.fromList([0xFF, 0xF1, 0x50, 0x80]),
          url: _url,
        ),
        '.aac',
        reason: 'ADTS frame sync has the layer bits clear',
      );
    });

    test('bytes win over a content type that disagrees', () {
      expect(
        audioFileExtensionFor(
          _mp4Bytes(),
          url: _url,
          contentType: 'audio/mpeg',
        ),
        '.mp4',
      );
    });

    test('falls back to the content type for unknown bytes', () {
      const expected = {
        'audio/wav; charset=binary': '.wav',
        'audio/x-m4a': '.mp4',
        'AUDIO/MPEG': '.mp3',
        'audio/aac': '.aac',
        'application/ogg': '.ogg',
        'audio/x-flac': '.flac',
      };
      for (final MapEntry(key: contentType, value: extension)
          in expected.entries) {
        expect(
          audioFileExtensionFor(_opaque, url: _url, contentType: contentType),
          extension,
          reason: contentType,
        );
      }
    });

    test('falls back to the URL extension, then .mp3', () {
      expect(
        audioFileExtensionFor(
          _opaque,
          url: Uri.parse('https://cdn.example/track.M4A'),
          contentType: 'application/octet-stream',
        ),
        '.M4A',
      );
      expect(
        audioFileExtensionFor(
          _opaque,
          url: Uri.parse('https://cdn.example/track.notanextension'),
        ),
        '.mp3',
        reason: 'an over-long suffix is not a file extension',
      );
      expect(audioFileExtensionFor(_opaque, url: _url), '.mp3');
      expect(audioFileExtensionFor(Uint8List(0), url: _url), '.mp3');
    });
  });

  group('isClearlyNotAudioBody', () {
    test('is true for a text response with no audio container', () {
      expect(
        isClearlyNotAudioBody(
          Uint8List.fromList(ascii.encode('<html>sign in</html>')),
          'text/html; charset=utf-8',
        ),
        isTrue,
      );
    });

    test('is false when the bytes are audio despite a text type', () {
      expect(isClearlyNotAudioBody(_wavBytes(), 'text/plain'), isFalse);
    });

    test('is false for a non-text or missing content type', () {
      expect(isClearlyNotAudioBody(_opaque, 'audio/mpeg'), isFalse);
      expect(isClearlyNotAudioBody(_opaque, null), isFalse);
    });
  });
}

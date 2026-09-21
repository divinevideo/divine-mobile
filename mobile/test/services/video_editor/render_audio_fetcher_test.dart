// ABOUTME: Unit tests for fetching render audio sources to local files.
// ABOUTME: Covers container sniffing, retries, stalls, and cleanup on failure.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvine/services/video_editor/render_audio_fetcher.dart';
import 'package:path/path.dart' as p;
import 'package:pro_image_editor/pro_image_editor.dart';

final Uri _url = Uri.parse('https://media.example/abc123');

Uint8List _wavBytes() => Uint8List.fromList([
  ...ascii.encode('RIFF'),
  0x24,
  0x00,
  0x00,
  0x00,
  ...ascii.encode('WAVE'),
  ...ascii.encode('fmt '),
  ...List<int>.filled(64, 0x11),
]);

Uint8List _mp4Bytes() => Uint8List.fromList([
  0x00,
  0x00,
  0x00,
  0x18,
  ...ascii.encode('ftyp'),
  ...ascii.encode('isom'),
  ...List<int>.filled(64, 0x22),
]);

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('render_audio_fetcher');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  RenderAudioFetcher fetcher(
    http.Client Function() clientFactory, {
    Duration stallTimeout = const Duration(seconds: 5),
    int maxBytes = 50 * 1024 * 1024,
  }) => RenderAudioFetcher(
    clientFactory: clientFactory,
    tempDirectory: tempDir,
    baseDelay: Duration.zero,
    stallTimeout: stallTimeout,
    maxBytes: maxBytes,
  );

  group('localPathFor', () {
    test('returns a file source path without touching the network', () async {
      final path = await fetcher(
        () => throw StateError('no client expected'),
      ).localPathFor(EditorAudio.file(File('/tmp/song.m4a')), logName: 't');

      expect(path, '/tmp/song.m4a');
    });

    test(
      'downloads a network source and names the file after its container',
      () async {
        final requests = <http.Request>[];
        final path = await fetcher(
          () => MockClient((request) async {
            requests.add(request);
            return http.Response.bytes(
              _mp4Bytes(),
              200,
              headers: {'content-type': 'video/mp4'},
            );
          }),
        ).localPathFor(EditorAudio.network(_url.toString()), logName: 't');

        expect(requests.map((r) => r.url), [_url]);
        expect(p.extension(path), '.mp4');
        expect(p.dirname(path), tempDir.path);
        expect(File(path).readAsBytesSync(), _mp4Bytes());
        expect(
          tempDir.listSync().map((e) => p.basename(e.path)),
          [p.basename(path)],
          reason: 'the .part file must be renamed, not copied',
        );
      },
    );

    test('retries a server error and returns the later success', () async {
      var attempts = 0;
      final path = await fetcher(
        () => MockClient((request) async {
          attempts++;
          if (attempts == 1) return http.Response('busy', 503);
          return http.Response.bytes(_wavBytes(), 200);
        }),
      ).localPathFor(EditorAudio.network(_url.toString()), logName: 't');

      expect(attempts, 2);
      expect(p.extension(path), '.wav');
    });

    test(
      'retries a dropped connection and gives up after the ladder',
      () async {
        var attempts = 0;
        await expectLater(
          fetcher(
            () => MockClient((request) async {
              attempts++;
              throw http.ClientException('connection reset', request.url);
            }),
          ).localPathFor(EditorAudio.network(_url.toString()), logName: 't'),
          throwsA(
            isA<RenderAudioFetchException>()
                .having((e) => e.url, 'url', _url)
                .having((e) => e.statusCode, 'statusCode', isNull)
                .having((e) => e.isTransient, 'isTransient', isTrue),
          ),
        );

        expect(attempts, 3, reason: 'one attempt plus two retries');
        expect(
          tempDir.listSync(),
          isEmpty,
          reason: 'no .part file left behind',
        );
      },
    );

    test('does not retry a missing blob', () async {
      var attempts = 0;
      await expectLater(
        fetcher(
          () => MockClient((request) async {
            attempts++;
            return http.Response('gone', 404);
          }),
        ).localPathFor(EditorAudio.network(_url.toString()), logName: 't'),
        throwsA(
          isA<RenderAudioFetchException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.isTransient, 'isTransient', isFalse),
        ),
      );

      expect(attempts, 1);
    });

    test('does not retry a local temp-file failure', () async {
      final blocker = File(p.join(tempDir.path, 'not-a-directory'));
      blocker.writeAsStringSync('file');
      var attempts = 0;

      await expectLater(
        RenderAudioFetcher(
          clientFactory: () => MockClient((request) async {
            attempts++;
            return http.Response.bytes(_wavBytes(), 200);
          }),
          tempDirectory: Directory(blocker.path),
          baseDelay: Duration.zero,
        ).localPathFor(EditorAudio.network(_url.toString()), logName: 't'),
        throwsA(
          isA<RenderAudioFetchException>()
              .having((e) => e.cause, 'cause', isA<FileSystemException>())
              .having((e) => e.isTransient, 'isTransient', isFalse),
        ),
      );

      expect(attempts, 1);
    });

    test('treats a body that stops arriving as a failed attempt', () async {
      var attempts = 0;
      await expectLater(
        fetcher(
          () => MockClient.streaming((request, bodyStream) async {
            attempts++;
            // Headers arrive, then nothing: the stream never emits or closes.
            return http.StreamedResponse(
              StreamController<List<int>>().stream,
              200,
            );
          }),
          stallTimeout: const Duration(milliseconds: 50),
        ).localPathFor(EditorAudio.network(_url.toString()), logName: 't'),
        throwsA(
          isA<RenderAudioFetchException>().having(
            (e) => e.cause,
            'cause',
            isA<TimeoutException>(),
          ),
        ),
      );

      expect(attempts, 3);
      expect(tempDir.listSync(), isEmpty);
    });

    test(
      'rejects a body larger than the limit, once, and removes the partial '
      'file',
      () async {
        var attempts = 0;
        await expectLater(
          fetcher(
            () => MockClient((request) async {
              attempts++;
              return http.Response.bytes(Uint8List(4096), 200);
            }),
            maxBytes: 1024,
          ).localPathFor(EditorAudio.network(_url.toString()), logName: 't'),
          throwsA(
            isA<RenderAudioFetchException>().having(
              (e) => e.isTransient,
              'isTransient',
              isFalse,
            ),
          ),
        );

        expect(attempts, 1, reason: 'the same body would come back again');
        expect(tempDir.listSync(), isEmpty);
      },
    );

    test('rejects an empty body once', () async {
      var attempts = 0;
      await expectLater(
        fetcher(
          () => MockClient((request) async {
            attempts++;
            return http.Response('', 200);
          }),
        ).localPathFor(EditorAudio.network(_url.toString()), logName: 't'),
        throwsA(
          isA<RenderAudioFetchException>().having(
            (e) => e.isTransient,
            'isTransient',
            isFalse,
          ),
        ),
      );

      expect(attempts, 1);
    });

    test('rejects a text response once', () async {
      var attempts = 0;
      await expectLater(
        fetcher(
          () => MockClient((request) async {
            attempts++;
            return http.Response(
              '<html>sign in</html>',
              200,
              headers: {'content-type': 'text/html'},
            );
          }),
        ).localPathFor(EditorAudio.network(_url.toString()), logName: 't'),
        throwsA(
          isA<RenderAudioFetchException>().having(
            (e) => e.isTransient,
            'isTransient',
            isFalse,
          ),
        ),
      );

      expect(attempts, 1);
      expect(tempDir.listSync(), isEmpty);
    });
  });

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

    test('falls back to the content type, then the URL, then .mp3', () {
      final opaque = Uint8List.fromList(List<int>.filled(16, 0x42));
      expect(
        audioFileExtensionFor(
          opaque,
          url: _url,
          contentType: 'audio/wav; charset=binary',
        ),
        '.wav',
      );
      expect(
        audioFileExtensionFor(
          opaque,
          url: Uri.parse('https://cdn.example/track.M4A'),
        ),
        '.M4A',
      );
      expect(audioFileExtensionFor(opaque, url: _url), '.mp3');
      expect(audioFileExtensionFor(Uint8List(0), url: _url), '.mp3');
    });
  });
}

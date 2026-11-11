// ABOUTME: Tests for downloading remote sounds to kept local files
// ABOUTME: Covers caching, failed downloads, stalls and concurrent downloads

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:sound_service/sound_service.dart';

class _MockHttpClient extends Mock implements HttpClient {}

class _MockHttpClientRequest extends Mock implements HttpClientRequest {}

class _FakeHttpHeaders extends Fake implements HttpHeaders {
  _FakeHttpHeaders(this._contentType);

  final String? _contentType;

  @override
  String? value(String name) =>
      name == HttpHeaders.contentTypeHeader ? _contentType : null;
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FakeHttpClientResponse(this.statusCode, this._body, {String? contentType})
    : headers = _FakeHttpHeaders(contentType);

  @override
  final int statusCode;

  @override
  final HttpHeaders headers;

  final Stream<List<int>> _body;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _body.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The start of an MP4 file: the bytes say `.mp4` although the URL has no
/// extension, as Divine's Blossom URLs do not.
final List<int> _mp4Bytes = [
  0x00,
  0x00,
  0x00,
  0x18,
  ...ascii.encode('ftyp'),
  ...ascii.encode('isom'),
  ...List<int>.filled(32, 0x22),
];

final Uri _soundUrl = Uri.parse('https://media.example/abc123');

HttpClientResponse _ok(List<int> body, {String? contentType}) =>
    _FakeHttpClientResponse(
      HttpStatus.ok,
      Stream.value(body),
      contentType: contentType,
    );

void main() {
  setUpAll(() {
    registerFallbackValue(Uri());
  });

  group(RemoteAudioCache, () {
    late Directory directory;
    late _MockHttpClient client;
    late _MockHttpClientRequest request;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('remote_audio_cache');
      client = _MockHttpClient();
      request = _MockHttpClientRequest();
      when(() => client.getUrl(any())).thenAnswer((_) async => request);
    });

    tearDown(() {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });

    RemoteAudioCache cache({
      Duration stallTimeout = const Duration(seconds: 5),
      int maxBytes = 1024,
    }) => RemoteAudioCache(
      httpClientFactory: () => client,
      directory: directory,
      stallTimeout: stallTimeout,
      maxBytes: maxBytes,
    );

    /// Every file under the cache directory, by path relative to it.
    List<String> filesInCache() =>
        directory
            .listSync(recursive: true)
            .whereType<File>()
            .map((file) => p.relative(file.path, from: directory.path))
            .toList()
          ..sort();

    group('fileFor', () {
      test('downloads a sound and names it after its container', () async {
        when(request.close).thenAnswer((_) async => _ok(_mp4Bytes));

        final file = await cache().fileFor(_soundUrl);

        verify(() => client.getUrl(_soundUrl)).called(1);
        expect(p.basename(file.path), 'sound.mp4');
        expect(p.isWithin(directory.path, file.path), isTrue);
        expect(file.readAsBytesSync(), _mp4Bytes);
        expect(
          filesInCache(),
          [p.relative(file.path, from: directory.path)],
          reason: 'the .part file must be renamed, not copied',
        );
      });

      test('serves a kept sound without downloading it again', () async {
        when(request.close).thenAnswer((_) async => _ok(_mp4Bytes));
        final first = await cache().fileFor(_soundUrl);

        final again = await RemoteAudioCache(
          httpClientFactory: () => throw StateError('no download expected'),
          directory: directory,
        ).fileFor(_soundUrl);

        expect(again.path, first.path);
        verify(() => client.getUrl(_soundUrl)).called(1);
      });

      test('keeps different sounds apart', () async {
        when(request.close).thenAnswer((_) async => _ok(_mp4Bytes));

        final first = await cache().fileFor(_soundUrl);
        final second = await cache().fileFor(
          Uri.parse('https://media.example/def456'),
        );

        expect(second.path, isNot(first.path));
        expect(filesInCache(), hasLength(2));
      });

      test('downloads again past a stranded partial file', () async {
        when(request.close).thenAnswer((_) async => _ok(_mp4Bytes));
        final first = await cache().fileFor(_soundUrl);
        first.deleteSync();
        File(p.join(first.parent.path, '1_0.part')).writeAsBytesSync([1]);

        final again = await cache().fileFor(_soundUrl);

        expect(again.path, first.path);
        expect(again.readAsBytesSync(), _mp4Bytes);
        verify(() => client.getUrl(_soundUrl)).called(2);
      });

      test(
        'keeps sounds in sound_cache under the system temp directory',
        () async {
          when(request.close).thenAnswer((_) async => _ok(_mp4Bytes));
          final url = Uri.parse(
            'https://media.example/'
            'default-dir-${DateTime.now().microsecondsSinceEpoch}',
          );

          final file = await RemoteAudioCache(
            httpClientFactory: () => client,
          ).fileFor(url);
          addTearDown(() => file.parent.deleteSync(recursive: true));

          expect(
            p.isWithin(
              p.join(Directory.systemTemp.path, 'sound_cache'),
              file.path,
            ),
            isTrue,
          );
        },
      );
    });

    group('fileFor failures', () {
      test(
        'throws the status of a server error and keeps nothing',
        () async {
          when(request.close).thenAnswer(
            (_) async => _FakeHttpClientResponse(
              HttpStatus.badGateway,
              const Stream.empty(),
            ),
          );

          await expectLater(
            cache().fileFor(_soundUrl),
            throwsA(
              isA<RemoteAudioDownloadException>()
                  .having((e) => e.statusCode, 'statusCode', 502)
                  .having((e) => e.uri, 'uri', _soundUrl),
            ),
          );
          expect(filesInCache(), isEmpty);

          when(request.close).thenAnswer((_) async => _ok(_mp4Bytes));
          final file = await cache().fileFor(_soundUrl);
          expect(
            file.readAsBytesSync(),
            _mp4Bytes,
            reason: 'a failed download is tried again',
          );
        },
      );

      test('wraps a connection failure', () async {
        when(
          () => client.getUrl(any()),
        ).thenThrow(const SocketException('Connection refused'));

        await expectLater(
          cache().fileFor(_soundUrl),
          throwsA(
            isA<RemoteAudioDownloadException>()
                .having((e) => e.statusCode, 'statusCode', isNull)
                .having((e) => e.cause, 'cause', isA<SocketException>()),
          ),
        );
      });

      test('gives up on a server that never answers', () async {
        when(
          request.close,
        ).thenAnswer((_) => Completer<HttpClientResponse>().future);

        await expectLater(
          cache(stallTimeout: const Duration(milliseconds: 1)).fileFor(
            _soundUrl,
          ),
          throwsA(
            isA<RemoteAudioDownloadException>().having(
              (e) => e.cause,
              'cause',
              isA<TimeoutException>(),
            ),
          ),
        );
      });

      test('gives up on a stalled body and removes its partial file', () async {
        final body = StreamController<List<int>>();
        addTearDown(body.close);
        when(request.close).thenAnswer(
          (_) async => _FakeHttpClientResponse(HttpStatus.ok, body.stream),
        );
        body.add(_mp4Bytes);

        await expectLater(
          cache(stallTimeout: const Duration(milliseconds: 20)).fileFor(
            _soundUrl,
          ),
          throwsA(
            isA<RemoteAudioDownloadException>().having(
              (e) => e.cause,
              'cause',
              isA<TimeoutException>(),
            ),
          ),
        );
        expect(filesInCache(), isEmpty);
      });

      test('removes the partial file of a dropped connection', () async {
        Stream<List<int>> dropping() async* {
          yield _mp4Bytes;
          throw const SocketException('Connection reset by peer');
        }

        when(request.close).thenAnswer(
          (_) async => _FakeHttpClientResponse(HttpStatus.ok, dropping()),
        );

        await expectLater(
          cache().fileFor(_soundUrl),
          throwsA(
            isA<RemoteAudioDownloadException>().having(
              (e) => e.cause,
              'cause',
              isA<SocketException>(),
            ),
          ),
        );
        expect(filesInCache(), isEmpty);
      });

      test('refuses a body larger than maxBytes', () async {
        when(request.close).thenAnswer((_) async => _ok(_mp4Bytes));

        await expectLater(
          cache(maxBytes: _mp4Bytes.length - 1).fileFor(_soundUrl),
          throwsA(
            isA<RemoteAudioDownloadException>().having(
              (e) => e.cause,
              'cause',
              contains('exceeds'),
            ),
          ),
        );
        expect(filesInCache(), isEmpty);
      });

      test('refuses an empty body', () async {
        when(request.close).thenAnswer(
          (_) async =>
              _FakeHttpClientResponse(HttpStatus.ok, const Stream.empty()),
        );

        await expectLater(
          cache().fileFor(_soundUrl),
          throwsA(
            isA<RemoteAudioDownloadException>().having(
              (e) => e.cause,
              'cause',
              'empty body',
            ),
          ),
        );
        expect(filesInCache(), isEmpty);
      });

      test('refuses a text page served instead of audio', () async {
        when(request.close).thenAnswer(
          (_) async => _ok(
            utf8.encode('<html>sign in</html>'),
            contentType: 'text/html; charset=utf-8',
          ),
        );

        await expectLater(
          cache().fileFor(_soundUrl),
          throwsA(
            isA<RemoteAudioDownloadException>().having(
              (e) => e.cause,
              'cause',
              contains('text response'),
            ),
          ),
        );
        expect(filesInCache(), isEmpty);
      });
    });

    // Regression for the `PathNotFoundException: Cannot delete file
    // ... just_audio_cache/remote/<hash>.part` crash: two downloads of one
    // sound shared a .part file, so one deleted or renamed the other's.
    test('a failed download leaves a concurrent one of the same sound '
        'intact', () async {
      final failing = StreamController<List<int>>();
      final succeeding = StreamController<List<int>>();
      final responses = [failing, succeeding];
      when(request.close).thenAnswer(
        (_) async => _FakeHttpClientResponse(
          HttpStatus.ok,
          responses.removeAt(0).stream,
        ),
      );

      final first = cache().fileFor(_soundUrl);
      final second = cache().fileFor(_soundUrl);
      await pumpEventQueue();
      succeeding.add(_mp4Bytes);
      failing
        ..add(_mp4Bytes)
        ..addError(const SocketException('Connection reset by peer'));
      await expectLater(first, throwsA(isA<RemoteAudioDownloadException>()));
      await succeeding.close();
      await failing.close();

      final file = await second;
      expect(file.readAsBytesSync(), _mp4Bytes);
      expect(filesInCache(), [p.relative(file.path, from: directory.path)]);
    });
  });

  group(RemoteAudioDownloadException, () {
    test('names the status, or a transport failure and its cause', () {
      expect(
        RemoteAudioDownloadException(_soundUrl, statusCode: 404).toString(),
        'RemoteAudioDownloadException(404: $_soundUrl)',
      );
      expect(
        RemoteAudioDownloadException(_soundUrl, cause: 'empty body').toString(),
        'RemoteAudioDownloadException(transport: $_soundUrl): empty body',
      );
    });
  });
}

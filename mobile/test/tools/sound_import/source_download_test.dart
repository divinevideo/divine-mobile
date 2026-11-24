// ABOUTME: Tests that a source download which stops sending is tried again,
// ABOUTME: and gives up after its attempts, instead of hanging the whole import.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../../tools/sound_import/source_download.dart';

class _LoopbackHttpOverrides extends HttpOverrides {}

void main() {
  group('SourceDownloader.download', () {
    late Directory work;
    late File file;

    setUp(() {
      work = Directory.systemTemp.createTempSync('source-download-test-');
      file = File('${work.path}/click.wav');
    });
    tearDown(() => work.deleteSync(recursive: true));

    SourceDownloader downloaderWith(http.Client Function() createClient) {
      final downloader = SourceDownloader(createClient: createClient);
      addTearDown(downloader.close);
      return downloader;
    }

    SourceDownloader loopbackDownloader() => downloaderWith(
      () => HttpOverrides.runWithHttpOverrides(
        http.Client.new,
        _LoopbackHttpOverrides(),
      ),
    );

    Future<void> download(MockClient client) =>
        downloaderWith(() => client).download(
          'https://example.com/click.wav',
          file,
          userAgent: 'test',
          idleTimeout: const Duration(milliseconds: 50),
          pauseBefore: (_) => Duration.zero,
        );

    test('tries again when the connection stops sending', () async {
      var requests = 0;
      final client = MockClient.streaming((request, _) async {
        requests++;
        final body = requests == 1
            ? StreamController<List<int>>().stream
            : Stream.value([1, 2, 3]);
        return http.StreamedResponse(body, 200);
      });

      await download(client);

      expect(requests, equals(2));
      expect(file.readAsBytesSync(), equals([1, 2, 3]));
    });

    test('gives up after its attempts without leaving a file', () async {
      var requests = 0;
      final client = MockClient.streaming((request, _) {
        requests++;
        return Completer<http.StreamedResponse>().future;
      });

      await expectLater(download(client), throwsA(isA<HttpException>()));

      expect(requests, equals(downloadAttempts));
      expect(work.listSync(), isEmpty);
    });

    for (final route in ['direct', 'redirected']) {
      test('closes a $route connection stalled before its response headers', () async {
        final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final sockets = <Socket>[];
        addTearDown(() async {
          for (final socket in sockets) {
            socket.destroy();
          }
          await server.close();
        });
        final downloader = loopbackDownloader();
        final firstClosed = Completer<void>();
        server.listen((socket) {
          sockets.add(socket);
          if (sockets.length == 1) {
            socket.listen(
              (_) {},
              onDone: () {
                firstClosed.complete();
                socket.destroy();
              },
            );
            return;
          }
          // The first request never gets headers. A separate connection answers
          // the retry so we can check for closure before the downloader exits.
          socket.listen((_) {});
          socket.add(
            ascii.encode(
              'HTTP/1.1 200 OK\r\n'
              'Content-Length: 3\r\n'
              'Connection: close\r\n\r\n'
              'abc',
            ),
          );
        });

        final target = Uri.http(
          '${server.address.address}:${server.port}',
          '/click.wav',
        );
        var source = target;
        if (route == 'redirected') {
          final redirect = await HttpServer.bind(
            InternetAddress.loopbackIPv4,
            0,
          );
          addTearDown(() => redirect.close(force: true));
          redirect.listen((request) {
            unawaited(request.response.redirect(target));
          });
          source = Uri.http(
            '${redirect.address.address}:${redirect.port}',
            '/source.wav',
          );
        }

        await downloader.download(
          source.toString(),
          file,
          userAgent: 'test',
          idleTimeout: const Duration(milliseconds: 300),
          pauseBefore: (_) => Duration.zero,
        );

        expect(sockets, hasLength(2));
        expect(file.readAsStringSync(), 'abc');
        await firstClosed.future.timeout(const Duration(seconds: 1));
      });
    }

    test('closes an unconsumed response and reports a partial-file write '
        'error only to its caller', () async {
      Directory('${file.path}.part').createSync();
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final sockets = <Socket>[];
      addTearDown(() async {
        for (final socket in sockets) {
          socket.destroy();
        }
        await server.close();
      });
      final firstClosed = Completer<void>();
      server.listen((socket) {
        sockets.add(socket);
        final first = sockets.length == 1;
        var answered = false;
        final request = StringBuffer();
        socket.listen(
          (bytes) {
            if (answered) return;
            request.write(ascii.decode(bytes));
            if (!request.toString().contains('\r\n\r\n')) return;
            answered = true;
            // Keep the first body incomplete so reading it cannot hide a leak.
            socket.add(
              ascii.encode(
                'HTTP/1.1 200 OK\r\n'
                'Content-Length: ${first ? 10000 : 3}\r\n\r\n'
                'abc',
              ),
            );
          },
          onDone: () {
            if (first) firstClosed.complete();
            socket.destroy();
          },
        );
      });
      final downloader = loopbackDownloader();
      final url = Uri.http(
        '${server.address.address}:${server.port}',
        '/click.wav',
      ).toString();
      final uncaught = <Object>[];
      final result = Completer<Object?>();
      unawaited(
        runZonedGuarded(() async {
          try {
            await downloader.download(
              url,
              file,
              userAgent: 'test',
              idleTimeout: const Duration(seconds: 2),
            );
            result.complete(null);
          } on Object catch (error) {
            result.complete(error);
          }
        }, (error, _) => uncaught.add(error)),
      );
      expect(
        await result.future.timeout(const Duration(seconds: 5)),
        isA<FileSystemException>(),
      );
      expect(file.existsSync(), isFalse);
      await firstClosed.future.timeout(const Duration(seconds: 1));
      expect(uncaught, isEmpty);

      // The next candidate can use the downloader after it resets its pool.
      final next = File('${work.path}/next.wav');
      await downloader.download(url, next, userAgent: 'test');
      expect(sockets, hasLength(2));
      expect(next.readAsStringSync(), 'abc');
    });
  });
}

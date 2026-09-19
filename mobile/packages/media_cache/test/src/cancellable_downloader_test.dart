import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:media_cache/src/cancellable_downloader.dart';
import 'package:mocktail/mocktail.dart';
import 'package:unified_logger/unified_logger.dart';

class _MockDirectory extends Mock implements Directory {}

class _CallbackClient extends http.BaseClient {
  _CallbackClient(this._onSend, {this.onClose});

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  _onSend;
  final void Function()? onClose;
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _onSend(request);

  @override
  void close() {
    onClose?.call();
    closed = true;
    super.close();
  }
}

/// A chunk whose element reads throw, so `RandomAccessFile.writeFrom` fails
/// for it the way a full disk or an IO error would after a successful open.
class _UnwritableChunk extends ListBase<int> {
  @override
  int get length => 32;

  @override
  set length(int value) => throw UnsupportedError('fixed length');

  @override
  int operator [](int index) => throw const FileSystemException('write failed');

  @override
  void operator []=(int index, int value) =>
      throw UnsupportedError('fixed length');
}

class _ResultOnlyDownload extends CancellableDownload {
  _ResultOnlyDownload(this._result);

  final CancellableDownloadResult _result;

  @override
  Stream<int> get progressBytes => const Stream.empty();

  @override
  Future<CancellableDownloadResult> get result async => _result;

  @override
  bool get isCancelled => false;

  @override
  void cancel() {}
}

/// Builds a response whose body reports an abort the way `package:http`
/// clients do once `send()` has returned: as a [http.RequestAbortedException]
/// on the body stream, which then closes. [onListen] fires when the download
/// starts reading the body.
http.StreamedResponse _abortableResponse(
  http.BaseRequest request,
  int statusCode, {
  void Function()? onListen,
}) {
  final abortTrigger = (request as http.AbortableRequest).abortTrigger!;
  late final StreamController<List<int>> body;
  body = StreamController<List<int>>(
    onListen: () {
      onListen?.call();
      unawaited(
        abortTrigger.whenComplete(() {
          body.addError(http.RequestAbortedException(request.url));
          unawaited(body.close());
        }),
      );
    },
  );
  return http.StreamedResponse(body.stream, statusCode);
}

void main() {
  group(CancellableDownload, () {
    test('file returns the file from result', () async {
      final file = File('video.mp4');
      final download = _ResultOnlyDownload(
        CancellableDownloadResult(file: file),
      );

      expect(await download.file, same(file));
    });
  });

  group(HttpCancellableDownloader, () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('cancellable_dl_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('downloads file successfully and forwards headers', () async {
      http.BaseRequest? capturedRequest;
      final client = _CallbackClient((request) async {
        capturedRequest = request;
        return http.StreamedResponse(
          Stream<List<int>>.fromIterable([
            utf8.encode('hello '),
            utf8.encode('world'),
          ]),
          200,
        );
      });

      final downloader = HttpCancellableDownloader(client);
      final target = File('${tempDir.path}/nested/video.mp4');

      final download = downloader.download(
        url: 'https://example.com/video.mp4',
        targetFile: target,
        headers: {'Authorization': 'Bearer token'},
      );

      final file = await download.file;

      expect(file, isNotNull);
      expect(file!.path, equals(target.path));
      expect(file.existsSync(), isTrue);
      expect(file.readAsStringSync(), equals('hello world'));
      expect(capturedRequest, isA<http.Request>());
      expect(
        (capturedRequest! as http.Request).headers['Authorization'],
        equals('Bearer token'),
      );
      expect(download.isCancelled, isFalse);
    });

    test('reports cumulative bytes as response chunks arrive', () async {
      final controller = StreamController<List<int>>();
      final client = _CallbackClient(
        (_) async => http.StreamedResponse(controller.stream, 200),
      );
      final downloader = HttpCancellableDownloader(client);
      final target = File('${tempDir.path}/progress.mp4');
      final download = downloader.download(
        url: 'https://example.com/progress.mp4',
        targetFile: target,
      );
      final progress = <int>[];
      final progressDone = Completer<void>();
      download.progressBytes.listen(
        progress.add,
        onDone: progressDone.complete,
      );

      controller
        ..add(const [1, 2, 3])
        ..add(const [4, 5]);
      await controller.close();

      expect(await download.file, same(target));
      await progressDone.future;
      expect(progress, equals([3, 5]));
    });

    // Crashlytics 8ddf179042f3ca20d8b4c90ae75f8f77 (#7298): image cache keys
    // are full URLs, and a web.archive.org-proxied Vine avatar produces a
    // filename past the 255-byte NAME_MAX of APFS and ext4. `File.openWrite()`
    // opens lazily, so the resulting ENAMETOOLONG surfaces only on the sink's
    // `done` future. Nothing observed it, so it reached Crashlytics through
    // runZonedGuarded, and the download settled wrongly on top of that:
    // whichever of the two orderings below occurred, the caller was misled.
    group('when the target file cannot be opened', () {
      late File target;

      setUp(() {
        target = File('${tempDir.path}/${'a' * 300}.jpg');
      });

      test('completes with null when the response ends before the sink '
          'reports its failure', () async {
        final client = _CallbackClient(
          (_) async => http.StreamedResponse(
            Stream<List<int>>.fromIterable([utf8.encode('payload')]),
            200,
          ),
        );
        final downloader = HttpCancellableDownloader(client);

        final zoneErrors = <Object>[];
        File? resolved;
        await runZonedGuarded(() async {
          resolved = await downloader
              .download(
                url: 'https://example.com/avatar.jpg',
                targetFile: target,
              )
              .file;
          // Let any straggling sink error land inside the guarded zone.
          await pumpEventQueue();
        }, (error, _) => zoneErrors.add(error));

        expect(resolved, isNull);
        expect(zoneErrors, isEmpty);
        expect(target.existsSync(), isFalse);
      });

      test('completes with null when the sink reports its failure before the '
          'response ends', () async {
        // The production ordering: bytes arrive over the network, so the open
        // error lands long before the last chunk. `flush()` on a sink that has
        // already reported its failure never completes, which stranded this
        // download — and every caller joined to its cache key — forever.
        final body = StreamController<List<int>>();
        addTearDown(body.close);
        final client = _CallbackClient(
          (_) async => http.StreamedResponse(body.stream, 200),
        );
        final downloader = HttpCancellableDownloader(client);

        final zoneErrors = <Object>[];
        File? resolved;
        await runZonedGuarded(() async {
          final download = downloader.download(
            url: 'https://example.com/avatar.jpg',
            targetFile: target,
          );
          await pumpEventQueue();
          body.add(utf8.encode('payload'));
          await pumpEventQueue();
          resolved = await download.file;
          await pumpEventQueue();
        }, (error, _) => zoneErrors.add(error));

        expect(resolved, isNull);
        expect(zoneErrors, isEmpty);
        expect(target.existsSync(), isFalse);
      });
    });

    // The open succeeding does not make the sink safe: a write can still fail
    // (ENOSPC, EIO) after any number of good chunks, and it surfaces on the
    // same `done` future as a failed open. Both orderings below settle through
    // `_failWithWriteError`, so they regress together with the group above.
    group('when a write fails after the file opened', () {
      late File target;

      setUp(() {
        target = File('${tempDir.path}/video.mp4');
      });

      test('completes with null when the write fails mid-stream', () async {
        // Without the sink's `done` listener this hung forever: nothing
        // observed the write error, the response stream stayed live, and the
        // partial file was left behind for the caller to decode.
        final body = StreamController<List<int>>();
        addTearDown(body.close);
        final client = _CallbackClient(
          (_) async => http.StreamedResponse(body.stream, 200),
        );
        final downloader = HttpCancellableDownloader(client);

        final zoneErrors = <Object>[];
        File? resolved;
        await runZonedGuarded(() async {
          final download = downloader.download(
            url: 'https://example.com/video.mp4',
            targetFile: target,
          );
          await pumpEventQueue();
          body.add(utf8.encode('good bytes '));
          await pumpEventQueue();
          body.add(_UnwritableChunk());
          await pumpEventQueue();
          body.add(utf8.encode('bytes that must be discarded'));
          resolved = await download.file;
          await pumpEventQueue();
        }, (error, _) => zoneErrors.add(error));

        expect(resolved, isNull);
        expect(zoneErrors, isEmpty);
        expect(target.existsSync(), isFalse);
      });

      test('completes with null when the last chunk fails to write', () async {
        // The response ends in the same turn the write fails, so `onDone`
        // races `done`. Previously `close()` reported success and handed back
        // a File holding only the bytes written before the failure.
        final client = _CallbackClient(
          (_) async => http.StreamedResponse(
            Stream<List<int>>.fromIterable([
              utf8.encode('good bytes '),
              _UnwritableChunk(),
            ]),
            200,
          ),
        );
        final downloader = HttpCancellableDownloader(client);

        final zoneErrors = <Object>[];
        File? resolved;
        await runZonedGuarded(() async {
          resolved = await downloader
              .download(
                url: 'https://example.com/video.mp4',
                targetFile: target,
              )
              .file;
          await pumpEventQueue();
        }, (error, _) => zoneErrors.add(error));

        expect(resolved, isNull);
        expect(zoneErrors, isEmpty);
        expect(target.existsSync(), isFalse);
      });
    });

    // Crashlytics 57777ab0fb993019895eb8d52d40ba47 (Android) and
    // e04a68d4904412fdc3970e4f7648d837 (iOS), #9339: a cancel that lands once
    // the headers have arrived no longer throws out of `send()` —
    // `package:http` puts the RequestAbortedException on the body stream
    // instead. The unawaited drain of a body nobody wanted was its only
    // consumer, so every feed scroll or thumbnail dispose in that window was
    // reported as a crash.
    group('when the abort arrives on the response body', () {
      late File target;

      setUp(() {
        target = File('${tempDir.path}/aborted_body.mp4');
      });

      test('settles with null and reports nothing when the response arrives '
          'after cancel()', () async {
        // cupertino_http and cronet_http still return a response whose
        // headers landed just before the cancel; IOClient would throw out of
        // send() here instead.
        final headersArrived = Completer<void>();
        var bodyListened = false;
        final client = _CallbackClient((request) async {
          await headersArrived.future;
          return _abortableResponse(
            request,
            200,
            onListen: () => bodyListened = true,
          );
        });
        final downloader = HttpCancellableDownloader(client);

        final zoneErrors = <Object>[];
        CancellableDownloadResult? resolved;
        await runZonedGuarded(() async {
          final download = downloader.download(
            url: 'https://example.com/aborted_body.mp4',
            targetFile: target,
          )..cancel();
          headersArrived.complete();
          resolved = await download.result;
          // Let the aborted body's error land inside the guarded zone.
          await pumpEventQueue();
        }, (error, _) => zoneErrors.add(error));

        expect(zoneErrors, isEmpty);
        // An unread body never gives its IOClient connection back to the pool.
        expect(bodyListened, isTrue);
        expect(resolved?.file, isNull);
        expect(resolved?.statusCode, equals(200));
        expect(target.existsSync(), isFalse);
      });

      test('reports nothing when cancelled while a non-OK body is being '
          'drained', () async {
        var bodyListened = false;
        final client = _CallbackClient(
          (request) async => _abortableResponse(
            request,
            HttpStatus.tooManyRequests,
            onListen: () => bodyListened = true,
          ),
        );
        final downloader = HttpCancellableDownloader(client);

        final zoneErrors = <Object>[];
        late CancellableDownload download;
        await runZonedGuarded(() async {
          download = downloader.download(
            url: 'https://example.com/aborted_body.mp4',
            targetFile: target,
          );
          // The result settles before the body finishes draining, which is
          // the window a caller's dispose-time cancel() lands in.
          await download.result;
          download.cancel();
          await pumpEventQueue();
        }, (error, _) => zoneErrors.add(error));

        expect(zoneErrors, isEmpty);
        // An unread body never gives its IOClient connection back to the pool.
        expect(bodyListened, isTrue);
        expect(download.isCancelled, isTrue);
        expect(target.existsSync(), isFalse);
      });
    });

    group('when the target directory has to be created', () {
      // IOClient only listens to the underlying response if the abort has not
      // fired by the time the body is first listened to. Otherwise it never
      // releases the connection, and on a one-slot pool the next request to
      // the host waits forever.
      test('reads the body before a cancel() made during the creation can '
          'land', () async {
        var aborted = false;
        var listenedAfterAbort = false;
        final client = _CallbackClient((request) async {
          unawaited(
            (request as http.AbortableRequest).abortTrigger!.whenComplete(
              () => aborted = true,
            ),
          );
          return _abortableResponse(
            request,
            200,
            onListen: () => listenedAfterAbort = aborted,
          );
        });
        final downloader = HttpCancellableDownloader(client);
        final parent = Directory('${tempDir.path}/cache')..createSync();
        late final CancellableDownload download;
        void cancelSoon() => scheduleMicrotask(download.cancel);
        final creatingParent = _MockDirectory();
        when(creatingParent.existsSync).thenReturn(false);
        when(() => creatingParent.create(recursive: true)).thenAnswer((_) {
          cancelSoon();
          // Completes on a later event, as a real mkdir does.
          return Future(() => creatingParent);
        });
        when(
          () => creatingParent.createSync(recursive: true),
        ).thenAnswer((_) => cancelSoon());

        download = IOOverrides.runZoned(
          () => downloader.download(
            url: 'https://example.com/video.mp4',
            targetFile: File('${parent.path}/video.mp4'),
          ),
          createDirectory: (path) => creatingParent,
        );
        await download.result;

        expect(download.isCancelled, isTrue);
        expect(listenedAfterAbort, isFalse);
      });

      test('cancels the response body when the directory cannot be '
          'created', () async {
        var bodyCancelled = false;
        final client = _CallbackClient(
          (_) async => http.StreamedResponse(
            StreamController<List<int>>(
              onCancel: () => bodyCancelled = true,
            ).stream,
            200,
          ),
        );
        final downloader = HttpCancellableDownloader(client);
        // A regular file where the parent directory should go, so mkdir fails.
        final notADirectory = File('${tempDir.path}/not_a_directory')
          ..createSync();

        final file = await downloader
            .download(
              url: 'https://example.com/video.mp4',
              targetFile: File('${notADirectory.path}/video.mp4'),
            )
            .file;

        expect(file, isNull);
        // Nothing reads this body now. Left alone it keeps its request going:
        // IOClient holds the connection, and the native clients download the
        // whole file into memory.
        expect(bodyCancelled, isTrue);
      });
    });

    test('close releases the underlying client', () async {
      final client = _CallbackClient(
        (_) async => http.StreamedResponse(const Stream.empty(), 200),
      );
      final downloader = HttpCancellableDownloader(client);

      await downloader.close();

      expect(client.closed, isTrue);
    });

    test('cancelActiveDownloads aborts in-flight downloads without closing '
        'the client', () async {
      final client = _CallbackClient((request) async {
        await (request as http.AbortableRequest).abortTrigger;
        throw http.RequestAbortedException(request.url);
      });
      final downloader = HttpCancellableDownloader(client);
      final target = File('${tempDir.path}/cancel_active.mp4');

      final download = downloader.download(
        url: 'https://example.com/cancel_active.mp4',
        targetFile: target,
      );
      await Future<void>.delayed(Duration.zero);

      downloader.cancelActiveDownloads();

      expect(await download.file, isNull);
      expect(download.isCancelled, isTrue);
      expect(client.closed, isFalse);
      expect(target.existsSync(), isFalse);
    });

    test('cancelActiveDownloads cancels every concurrent download', () async {
      final client = _CallbackClient((request) async {
        await (request as http.AbortableRequest).abortTrigger;
        throw http.RequestAbortedException(request.url);
      });
      final downloader = HttpCancellableDownloader(client);

      final first = downloader.download(
        url: 'https://example.com/multi_first.mp4',
        targetFile: File('${tempDir.path}/multi_first.mp4'),
      );
      final second = downloader.download(
        url: 'https://example.com/multi_second.mp4',
        targetFile: File('${tempDir.path}/multi_second.mp4'),
      );
      await Future<void>.delayed(Duration.zero);

      downloader.cancelActiveDownloads();

      expect(await first.file, isNull);
      expect(await second.file, isNull);
      expect(first.isCancelled, isTrue);
      expect(second.isCancelled, isTrue);
      expect(client.closed, isFalse);
    });

    test('download still works after cancelActiveDownloads', () async {
      var firstRequest = true;
      final client = _CallbackClient((request) async {
        if (firstRequest) {
          firstRequest = false;
          await (request as http.AbortableRequest).abortTrigger;
          throw http.RequestAbortedException(request.url);
        }
        return http.StreamedResponse(
          Stream<List<int>>.fromIterable([utf8.encode('ok')]),
          200,
        );
      });
      final downloader = HttpCancellableDownloader(client);

      final first = downloader.download(
        url: 'https://example.com/first.mp4',
        targetFile: File('${tempDir.path}/first.mp4'),
      );
      await Future<void>.delayed(Duration.zero);
      downloader.cancelActiveDownloads();
      await first.file;

      final second = await downloader
          .download(
            url: 'https://example.com/second.mp4',
            targetFile: File('${tempDir.path}/second.mp4'),
          )
          .file;

      expect(second, isNotNull);
      expect(second!.readAsStringSync(), equals('ok'));
      expect(client.closed, isFalse);
    });

    test('cancelActiveDownloads is a no-op after close', () async {
      final client = _CallbackClient(
        (_) async => http.StreamedResponse(const Stream.empty(), 200),
      );
      final downloader = HttpCancellableDownloader(client);

      await downloader.close();
      downloader.cancelActiveDownloads();

      expect(client.closed, isTrue);
    });

    test(
      'download after close completes with null without using client',
      () async {
        var sendCalled = false;
        final client = _CallbackClient((_) async {
          sendCalled = true;
          return http.StreamedResponse(const Stream.empty(), 200);
        });
        final downloader = HttpCancellableDownloader(client);
        final target = File('${tempDir.path}/closed.mp4');

        await downloader.close();
        final download = downloader.download(
          url: 'https://example.com/closed.mp4',
          targetFile: target,
        )..cancel();

        expect(await download.file, isNull);
        expect(download.isCancelled, isFalse);
        expect(sendCalled, isFalse);
        expect(target.existsSync(), isFalse);
      },
    );

    test('close aborts a pending request before closing the client', () async {
      var inFlightRequests = 0;
      var closedAfterAbort = false;
      final client = _CallbackClient(
        (request) async {
          inFlightRequests += 1;
          expect(request, isA<http.AbortableRequest>());
          await (request as http.AbortableRequest).abortTrigger;
          inFlightRequests -= 1;
          throw http.RequestAbortedException(request.url);
        },
        onClose: () {
          closedAfterAbort = inFlightRequests == 0;
        },
      );
      final downloader = HttpCancellableDownloader(client);
      final target = File('${tempDir.path}/pending_close.mp4');

      final download = downloader.download(
        url: 'https://example.com/pending.mp4',
        targetFile: target,
      );
      await Future<void>.delayed(Duration.zero);

      await downloader.close();

      expect(await download.file, isNull);
      expect(download.isCancelled, isTrue);
      expect(client.closed, isTrue);
      expect(closedAfterAbort, isTrue);
      expect(target.existsSync(), isFalse);
    });

    test('cancelling an in-flight request does not log a warning', () async {
      await LogCaptureService().clearAllLogs();

      final client = _CallbackClient((request) async {
        await (request as http.AbortableRequest).abortTrigger;
        throw http.RequestAbortedException(request.url);
      });
      final downloader = HttpCancellableDownloader(client);
      final target = File('${tempDir.path}/cancel_no_warning.mp4');

      final download = downloader.download(
        url: 'https://example.com/cancel_no_warning.mp4',
        targetFile: target,
      );
      await Future<void>.delayed(Duration.zero);
      download.cancel();

      expect(await download.file, isNull);
      expect(download.isCancelled, isTrue);

      final downloaderWarnings = LogCaptureService()
          .getRecentLogs()
          .where((entry) => entry.message.contains('CancellableDownload'))
          .toList();
      expect(downloaderWarnings, isEmpty);
    });

    // Canary for the negative assertion above: a genuine failure must
    // surface a captured warning. If the capture path is ever gated or
    // refactored away, this fails loudly instead of letting the
    // "does not log a warning" test quietly go vacuous.
    test('a rate-limited response logs status without the URL', () async {
      await LogCaptureService().clearAllLogs();

      final client = _CallbackClient(
        (_) async => http.StreamedResponse(
          Stream<List<int>>.value(utf8.encode('not found')),
          429,
        ),
      );
      final downloader = HttpCancellableDownloader(client);
      final target = File('${tempDir.path}/non_success_warns.mp4');

      final file = await downloader
          .download(url: 'https://example.com/missing.mp4', targetFile: target)
          .file;

      expect(file, isNull);

      final downloaderWarnings = LogCaptureService()
          .getRecentLogs()
          .where((entry) => entry.message.contains('CancellableDownload'))
          .toList();
      expect(downloaderWarnings, isNotEmpty);
      expect(downloaderWarnings.first.message, contains('returned HTTP 429'));
      expect(
        downloaderWarnings.first.message,
        isNot(contains('https://example.com/missing.mp4')),
      );
    });

    test('non-https rejection does not log the URL', () async {
      await LogCaptureService().clearAllLogs();
      final downloader = HttpCancellableDownloader(
        _CallbackClient((_) async {
          throw StateError('request must not start');
        }),
      );

      final file = await downloader
          .download(
            url: 'http://private.example/avatar.jpg?identity=alice',
            targetFile: File('${tempDir.path}/insecure.jpg'),
          )
          .file;

      expect(file, isNull);
      final warning = LogCaptureService().getRecentLogs().singleWhere(
        (entry) => entry.message.contains('non-https'),
      );
      expect(warning.message, isNot(contains('private.example')));
      expect(warning.message, isNot(contains('alice')));
    });

    test('close waits for active response stream cancellation', () async {
      var streamCancelled = false;
      var closedAfterStreamCancel = false;
      final controller = StreamController<List<int>>(
        onCancel: () async {
          await Future<void>.delayed(Duration.zero);
          streamCancelled = true;
        },
      );
      final client = _CallbackClient(
        (_) async => http.StreamedResponse(controller.stream, 200),
        onClose: () {
          closedAfterStreamCancel = streamCancelled;
        },
      );
      final downloader = HttpCancellableDownloader(client);
      final target = File('${tempDir.path}/stream_close.mp4');

      final download = downloader.download(
        url: 'https://example.com/stream.mp4',
        targetFile: target,
      );
      await Future<void>.delayed(Duration.zero);

      await downloader.close();

      expect(await download.file, isNull);
      expect(download.isCancelled, isTrue);
      expect(client.closed, isTrue);
      expect(closedAfterStreamCancel, isTrue);
      expect(target.existsSync(), isFalse);
    });

    test('returns null for non-OK responses and exposes status', () async {
      final client = _CallbackClient(
        (_) async => http.StreamedResponse(
          Stream<List<int>>.value(utf8.encode('not found')),
          404,
          headers: {'retry-after': '10'},
        ),
      );
      final downloader = HttpCancellableDownloader(client);
      final target = File('${tempDir.path}/non_success.mp4');

      final result = await downloader
          .download(url: 'https://example.com/missing.mp4', targetFile: target)
          .result;

      expect(result.file, isNull);
      expect(result.statusCode, equals(404));
      expect(result.headers['retry-after'], equals('10'));
      expect(target.existsSync(), isFalse);
    });

    test('does not write HTTP 202 processing bodies to disk', () async {
      final client = _CallbackClient(
        (_) async => http.StreamedResponse(
          Stream<List<int>>.value(utf8.encode('{"status":"processing"}')),
          HttpStatus.accepted,
          headers: {'retry-after': '2'},
        ),
      );
      final downloader = HttpCancellableDownloader(client);
      final target = File('${tempDir.path}/processing.mp4');

      final file = await downloader
          .download(
            url: 'https://example.com/processing.mp4',
            targetFile: target,
          )
          .file;

      expect(file, isNull);
      expect(target.existsSync(), isFalse);
    });

    for (final statusCode in [
      HttpStatus.noContent,
      HttpStatus.partialContent,
    ]) {
      test('rejects HTTP $statusCode responses', () async {
        final client = _CallbackClient(
          (_) async => http.StreamedResponse(
            Stream<List<int>>.value(utf8.encode('unexpected bytes')),
            statusCode,
          ),
        );
        final downloader = HttpCancellableDownloader(client);
        final target = File('${tempDir.path}/http_$statusCode.mp4');

        final file = await downloader
            .download(
              url: 'https://example.com/http_$statusCode.mp4',
              targetFile: target,
            )
            .file;

        expect(file, isNull);
        expect(target.existsSync(), isFalse);
      });
    }

    test(
      'returns null when stream emits an error and cleans partial file',
      () async {
        final controller = StreamController<List<int>>();
        final client = _CallbackClient(
          (_) async => http.StreamedResponse(controller.stream, 200),
        );
        final downloader = HttpCancellableDownloader(client);
        final target = File('${tempDir.path}/error_stream.mp4');

        final future = downloader
            .download(url: 'https://example.com/error.mp4', targetFile: target)
            .file;

        controller
          ..add(utf8.encode('partial-bytes'))
          ..addError(Exception('stream failure'));
        await controller.close();

        final file = await future;
        expect(file, isNull);
        expect(target.existsSync(), isFalse);
      },
    );

    test('returns null when client send throws', () async {
      final client = _CallbackClient((_) async {
        throw Exception('send failed');
      });
      final downloader = HttpCancellableDownloader(client);
      final target = File('${tempDir.path}/send_throw.mp4');

      final file = await downloader
          .download(url: 'https://example.com/fail.mp4', targetFile: target)
          .file;

      expect(file, isNull);
      expect(target.existsSync(), isFalse);
    });

    test('rejects non-https urls before sending request', () async {
      var sendCalled = false;
      final client = _CallbackClient((_) async {
        sendCalled = true;
        return http.StreamedResponse(
          Stream<List<int>>.value(utf8.encode('insecure')),
          200,
        );
      });
      final downloader = HttpCancellableDownloader(client);
      final target = File('${tempDir.path}/http_not_allowed.mp4');

      final file = await downloader
          .download(url: 'http://example.com/insecure.mp4', targetFile: target)
          .file;

      expect(file, isNull);
      expect(sendCalled, isFalse);
      expect(target.existsSync(), isFalse);
    });

    test('cancels before response arrives', () async {
      final responseCompleter = Completer<http.StreamedResponse>();
      final client = _CallbackClient((_) => responseCompleter.future);
      final downloader = HttpCancellableDownloader(client);
      final target = File('${tempDir.path}/cancel_before_response.mp4');

      final dl = downloader.download(
        url: 'https://example.com/cancel.mp4',
        targetFile: target,
      )..cancel();

      responseCompleter.complete(
        http.StreamedResponse(
          Stream<List<int>>.value(utf8.encode('late bytes')),
          200,
        ),
      );

      final file = await dl.file;
      expect(file, isNull);
      expect(dl.isCancelled, isTrue);
      expect(target.existsSync(), isFalse);
    });

    test('cancel after completion is a no-op', () async {
      final client = _CallbackClient(
        (_) async => http.StreamedResponse(
          Stream<List<int>>.value(utf8.encode('ok')),
          200,
        ),
      );
      final downloader = HttpCancellableDownloader(client);
      final target = File('${tempDir.path}/completed_then_cancel.mp4');

      final dl = downloader.download(
        url: 'https://example.com/done.mp4',
        targetFile: target,
      );
      final file = await dl.file;

      expect(file, isNotNull);
      dl.cancel();

      // Already completed downloads remain non-cancelled.
      expect(dl.isCancelled, isFalse);
      expect(target.existsSync(), isTrue);
    });

    test('cancel during stream completion keeps successful file', () async {
      final controller = StreamController<List<int>>();
      final client = _CallbackClient(
        (_) async => http.StreamedResponse(controller.stream, 200),
      );
      final downloader = HttpCancellableDownloader(client);
      final target = File('${tempDir.path}/cancel_during_done.mp4');

      final dl = downloader.download(
        url: 'https://example.com/cancel_during_done.mp4',
        targetFile: target,
      );

      // Ensure listener is attached before we trigger completion.
      await Future<void>.delayed(const Duration(milliseconds: 1));
      controller.add(utf8.encode('partial'));
      await controller.close();

      // Trigger cancellation while stream completion is in-flight.
      dl.cancel();

      final file = await dl.file;
      expect(file, isNotNull);
      expect(dl.isCancelled, isFalse);
      expect(target.existsSync(), isTrue);
    });

    test('cancel queued before stream done deletes the target file', () async {
      final controller = StreamController<List<int>>();
      final client = _CallbackClient(
        (_) async => http.StreamedResponse(controller.stream, 200),
      );
      final downloader = HttpCancellableDownloader(client);
      final target = File('${tempDir.path}/cancel_before_done.mp4');

      final dl = downloader.download(
        url: 'https://example.com/cancel_before_done.mp4',
        targetFile: target,
      );

      await Future<void>.delayed(const Duration(milliseconds: 1));
      controller.add(utf8.encode('partial'));
      final closeFuture = controller.close();
      dl.cancel();

      final file = await dl.file;
      await closeFuture;

      expect(file, isNull);
      expect(dl.isCancelled, isTrue);
      expect(target.existsSync(), isFalse);
    });
  });
}

// ABOUTME: Downloads one source file for the importer, retrying a busy server
// ABOUTME: and a connection that stops sending, so one stall cannot hang a run.

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

/// How often [SourceDownloader.download] tries one file before giving up.
const downloadAttempts = 4;

/// The sequential prepare run shares a source connection pool.
class SourceDownloader {
  SourceDownloader({http.Client Function() createClient = http.Client.new})
    : _createClient = createClient;

  final http.Client Function() _createClient;
  http.Client? _client;

  void close() {
    _client?.close();
    _client = null;
  }

  /// Downloads [url] to [file], through a `.part` file so a broken download
  /// never looks finished.
  ///
  /// A 429 or 5xx answer, and a connection that sends nothing for
  /// [idleTimeout], are tried again after [pauseBefore] the next attempt, up to
  /// [downloadAttempts] times. The timeout counts silence, not the whole
  /// download, so a long track on a slow line still finishes.
  ///
  /// Throws [HttpException] for any other answer, and once the attempts run
  /// out.
  Future<void> download(
    String url,
    File file, {
    required String userAgent,
    Duration idleTimeout = const Duration(seconds: 60),
    Duration Function(int attempt) pauseBefore = _growingPause,
  }) async {
    final partial = File('${file.path}.part');
    for (var attempt = 1; ; attempt++) {
      final abort = Completer<void>();
      String failure;
      try {
        final request = http.AbortableRequest(
          'GET',
          Uri.parse(url),
          abortTrigger: abort.future,
        )..headers['User-Agent'] = userAgent;
        final client = _client ??= _createClient();
        final response = await client
            .send(request)
            .timeout(
              idleTimeout,
              onTimeout: () {
                // IOClient follows redirects internally. Closing its pool also
                // cancels a stalled redirected request.
                close();
                throw TimeoutException('response headers', idleTimeout);
              },
            );
        final body = response.stream.timeout(idleTimeout);
        if (response.statusCode == 200) {
          final sink = partial.openWrite();
          var bodyWritten = false;
          try {
            await sink.addStream(body);
            bodyWritten = true;
          } finally {
            try {
              await sink.close();
            } on FileSystemException {
              // addStream can close the file itself on error. Preserve the
              // transfer error (including its timeout) in that case.
              if (bodyWritten) rethrow;
            }
          }
          partial.renameSync(file.path);
          return;
        }
        await body.drain<void>();
        failure = 'answered ${response.statusCode}';
        final retryable =
            response.statusCode == 429 || response.statusCode >= 500;
        if (!retryable) throw HttpException('GET $url $failure');
      } on TimeoutException {
        abort.complete();
        failure = 'sent nothing for ${idleTimeout.inSeconds} s';
      } on FileSystemException {
        // Opening the partial file can fail before the response is listened
        // to. Close the pool to release that connection before moving on.
        close();
        rethrow;
      } finally {
        if (partial.existsSync()) partial.deleteSync();
      }
      if (attempt == downloadAttempts) {
        throw HttpException('GET $url $failure');
      }
      await Future<void>.delayed(pauseBefore(attempt + 1));
    }
  }
}

/// 5 s before the second attempt, 20 s before the third, 45 s before the
/// fourth, as the importer always waited.
Duration _growingPause(int attempt) =>
    Duration(seconds: 5 * (attempt - 1) * (attempt - 1));

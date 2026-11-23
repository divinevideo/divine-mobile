// ABOUTME: Downloads one source file for the importer, retrying a busy server
// ABOUTME: and a connection that stops sending, so one stall cannot hang a run.

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

/// How often [downloadSource] tries one file before giving up.
const downloadAttempts = 4;

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
Future<void> downloadSource(
  http.Client client,
  String url,
  File file, {
  required String userAgent,
  Duration idleTimeout = const Duration(seconds: 60),
  Duration Function(int attempt) pauseBefore = _growingPause,
}) async {
  final partial = File('${file.path}.part');
  for (var attempt = 1; ; attempt++) {
    String failure;
    try {
      final request = http.Request('GET', Uri.parse(url))
        ..headers['User-Agent'] = userAgent;
      final response = await client.send(request).timeout(idleTimeout);
      final body = response.stream.timeout(idleTimeout);
      if (response.statusCode == 200) {
        final sink = partial.openWrite();
        try {
          await body.forEach(sink.add);
        } finally {
          await sink.close();
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
      failure = 'sent nothing for ${idleTimeout.inSeconds} s';
    }
    if (partial.existsSync()) partial.deleteSync();
    if (attempt == downloadAttempts) {
      throw HttpException('GET $url $failure');
    }
    await Future<void>.delayed(pauseBefore(attempt + 1));
  }
}

/// 5 s before the second attempt, 20 s before the third, 45 s before the
/// fourth, as the importer always waited.
Duration _growingPause(int attempt) =>
    Duration(seconds: 5 * (attempt - 1) * (attempt - 1));

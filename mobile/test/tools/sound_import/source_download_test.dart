// ABOUTME: Tests that a source download which stops sending is tried again,
// ABOUTME: and gives up after its attempts, instead of hanging the whole import.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../../tools/sound_import/source_download.dart';

void main() {
  group('downloadSource', () {
    late Directory work;
    late File file;

    setUp(() {
      work = Directory.systemTemp.createTempSync('source-download-test-');
      file = File('${work.path}/click.wav');
    });
    tearDown(() => work.deleteSync(recursive: true));

    Future<void> download(MockClient client) => downloadSource(
      client,
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
  });
}

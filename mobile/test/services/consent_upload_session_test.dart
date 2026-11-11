// ABOUTME: Verifies bounded file snapshots preserve binary multipart bytes and
// ABOUTME: survive retries and are discarded when the submission ends.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/consent_upload.dart';
import 'package:openvine/services/consent_upload_session.dart';

class _FailingCleanupUpload implements ConsentUpload {
  @override
  Future<void> dispose() async => throw StateError('cleanup failed');

  @override
  String get payloadHash => throw UnimplementedError();

  @override
  http.BaseRequest get request => throw UnimplementedError();
}

void main() {
  group('ConsentUploadSession', () {
    test('expected session invalidation is not crash-reportable', () {
      expect(
        asReportableError(
          const ConsentUploadInvalidatedException(),
          context: 'consent upload',
        ),
        isNull,
      );
    });
    test(
      'closing during transport releases the snapshot only after transport ends',
      () async {
        final session = ConsentUploadSession();
        final upload = await ConsentUpload.prepare(
          http.MultipartRequest('POST', Uri.parse('https://api.test'))
            ..fields['email'] = 'parent@example.com',
        );
        final started = Completer<void>();
        final finish = Completer<void>();
        final sending = session.send(
          prepare: () async => upload,
          transmit: (body) async {
            started.complete();
            await finish.future;
            expect(await body.request.finalize().toBytes(), isNotEmpty);
            return http.Response('', 201);
          },
        );
        await started.future;
        await session.dispose();
        finish.complete();
        await sending;
        await expectLater(
          upload.request.finalize().toBytes(),
          throwsA(isA<FileSystemException>()),
        );
        expect(
          () => session.send(
            prepare: () async => upload,
            transmit: (_) async => http.Response('', 201),
          ),
          throwsStateError,
        );
      },
    );

    for (final statusCode in [200, 201, 204]) {
      test(
        'accepted $statusCode releases bytes and reuses its result',
        () async {
          final session = ConsentUploadSession();
          addTearDown(session.dispose);
          final upload = await ConsentUpload.prepare(
            http.MultipartRequest('POST', Uri.parse('https://api.test'))
              ..fields['email'] = 'parent@example.com',
          );
          var sends = 0;
          Future<http.Response> send() => session.send(
            prepare: () async => upload,
            transmit: (_) async {
              sends++;
              return http.Response('', statusCode);
            },
          );
          expect((await send()).statusCode, statusCode);
          expect((await send()).statusCode, statusCode);
          expect(sends, 1);
          await expectLater(
            upload.request.finalize().toBytes(),
            throwsA(isA<FileSystemException>()),
          );
          await session.dispose();
          expect(send, throwsStateError);
        },
      );
    }

    test('accepted upload survives a non-Exception cleanup failure', () async {
      final session = ConsentUploadSession();
      addTearDown(session.dispose);
      final upload = _FailingCleanupUpload();
      final response = await session.send(
        prepare: () async => upload,
        transmit: (_) async => http.Response('', 201),
      );
      expect(response.statusCode, 201);
    });

    test('accepted upload survives snapshot cleanup failure', () async {
      final session = ConsentUploadSession();
      addTearDown(session.dispose);
      final upload = await ConsentUpload.prepare(
        http.MultipartRequest('POST', Uri.parse('https://api.test')),
      );
      var sends = 0;
      Future<http.Response> send() => session.send(
        prepare: () async => upload,
        transmit: (_) async {
          sends++;
          await upload.dispose();
          return http.Response('', 201);
        },
      );
      expect((await send()).statusCode, 201);
      expect((await send()).statusCode, 201);
      expect(sends, 1);
    });

    for (final statusCode in [202, 503]) {
      test('unaccepted $statusCode keeps the snapshot retryable', () async {
        final session = ConsentUploadSession();
        addTearDown(session.dispose);
        final upload = await ConsentUpload.prepare(
          http.MultipartRequest('POST', Uri.parse('https://api.test')),
        );
        var sends = 0;
        Future<http.Response> send() => session.send(
          prepare: () async => upload,
          transmit: (body) async {
            sends++;
            expect(await body.request.finalize().toBytes(), isNotEmpty);
            return http.Response('', sends == 1 ? statusCode : 201);
          },
        );
        expect((await send()).statusCode, statusCode);
        expect((await send()).statusCode, 201);
        expect(sends, 2);
      });
    }

    for (final statusCode in [201, 503]) {
      test('switching account invalidates a $statusCode submission', () async {
        final session = ConsentUploadSession();
        final uri = Uri.parse('https://api.test');
        const firstOwner =
            '0000000000000000000000000000000000000000000000000000000000000001';
        const secondOwner =
            '0000000000000000000000000000000000000000000000000000000000000002';
        await session.bind(
          url: uri,
          email: 'parent@example.com',
          videoPath: '/clip.mp4',
          pubkey: firstOwner,
        );
        final upload = await ConsentUpload.prepare(
          http.MultipartRequest('POST', uri)
            ..fields['email'] = 'parent@example.com',
        );
        await session.send(
          prepare: () async => upload,
          transmit: (_) async => http.Response('', statusCode),
        );
        await expectLater(
          session.bind(
            url: uri,
            email: 'parent@example.com',
            videoPath: '/clip.mp4',
            pubkey: secondOwner,
          ),
          throwsA(isA<ConsentUploadInvalidatedException>()),
        );
        await expectLater(
          upload.request.finalize().toBytes(),
          throwsA(isA<FileSystemException>()),
        );
      });
    }
  });
}

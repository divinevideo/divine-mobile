// ABOUTME: Verifies bounded file snapshots preserve binary multipart bytes and
// ABOUTME: survive retries and are discarded when the submission ends.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/consent_upload.dart';
import 'package:openvine/services/consent_upload_session.dart';

void main() {
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

  test('switching account disposes the previous account snapshot', () async {
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
      transmit: (_) async => http.Response('', 503),
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

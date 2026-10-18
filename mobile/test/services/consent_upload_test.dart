// ABOUTME: Verifies bounded file snapshots preserve binary multipart bytes and
// ABOUTME: are discarded after transport without deleting the accepted clip.
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:openvine/services/consent_upload.dart';

void main() {
  group(ConsentUpload, () {
    test(
      'freezes bytes independently of the recording and removes its file',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'consent-test-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final clip = File('${directory.path}/clip.mp4');
        await clip.writeAsBytes([0, 128, 255]);
        final multipart =
            http.MultipartRequest('POST', Uri.parse('https://api.test'))
              ..fields['email'] = 'parent@example.com'
              ..files.add(
                await http.MultipartFile.fromPath('video', clip.path),
              );
        final upload = await ConsentUpload.prepare(multipart);
        await clip.delete();
        final bytes = await upload.request.finalize().toBytes();
        expect(sha256.convert(bytes).toString(), upload.payloadHash);
        expect(bytes, containsAllInOrder([0, 128, 255]));
        await upload.dispose();
      },
    );

    test(
      'discarding a prepared upload removes its snapshot, retaining the clip',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'consent-test-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final clip = File('${directory.path}/clip.mp4');
        await clip.writeAsBytes([0, 128, 255]);
        final multipart = http.MultipartRequest(
          'POST',
          Uri.parse('https://api.test'),
        )..files.add(await http.MultipartFile.fromPath('video', clip.path));
        final upload = await ConsentUpload.prepare(multipart);
        await upload.dispose();
        expect(await clip.readAsBytes(), [0, 128, 255]);
        await expectLater(
          upload.request.finalize().toBytes(),
          throwsA(isA<FileSystemException>()),
        );
      },
    );
  });
}

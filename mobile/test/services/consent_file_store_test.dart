import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/consent_file_store.dart';

void main() {
  group('ConsentFileStore', () {
    test(
      'next launch removes abandoned clips and multipart snapshots',
      () async {
        final temporary = await Directory.systemTemp.createTemp(
          'consent-store-test-',
        );
        addTearDown(() => temporary.delete(recursive: true));
        final first = ConsentFileStore(temporary);
        final directory = await first.createDirectory();
        final clip = await File('${directory.path}/clip.mp4')
            .writeAsBytes([1, 2]);
        final snapshot = await File('${directory.path}/body')
            .writeAsBytes([3, 4]);
        final unrelated = await File('${temporary.path}/other')
            .writeAsString('keep');
        final nextLaunch = ConsentFileStore(temporary);
        await nextLaunch.initialize();
        expect(clip.existsSync(), isFalse);
        expect(snapshot.existsSync(), isFalse);
        expect(unrelated.existsSync(), isTrue);
      },
    );

    test(
      'initialization is shared and never sweeps active session files',
      () async {
        final temporary = await Directory.systemTemp.createTemp(
          'consent-store-test-',
        );
        addTearDown(() => temporary.delete(recursive: true));
        final store = ConsentFileStore(temporary);
        await Future.wait([store.initialize(), store.initialize()]);
        final directory = await store.createDirectory();
        final clip = await File('${directory.path}/clip.mp4')
            .writeAsString('private');
        await store.initialize();
        expect(clip.existsSync(), isTrue);
      },
    );
  });
}

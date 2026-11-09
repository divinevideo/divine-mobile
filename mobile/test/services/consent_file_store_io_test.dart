import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/consent_file_store_io.dart';

void main() {
  group('Native consent files', () {
    test('recording directories are private siblings and deleting one clip preserves the other', () async {
      final temporary = Directory.systemTemp.createTempSync(
        'consent-native-test-',
      );
      addTearDown(() => temporary.deleteSync(recursive: true));
      final store = ConsentFileStore(temporary);
      final first = await store.createRecordingDirectory();
      final second = await store.createRecordingDirectory();
      expect(first, isNot(second));
      expect(
        Directory(first).parent.path,
        '${temporary.path}/divine-parent-consent',
      );
      final firstClip = File('$first/clip.mp4')..writeAsStringSync('synthetic');
      final secondClip = File('$second/clip.mp4')
        ..writeAsStringSync('synthetic');
      await store.deleteClip(firstClip.path);
      await store.deleteClip(firstClip.path);
      expect(firstClip.existsSync(), isFalse);
      expect(secondClip.existsSync(), isTrue);
    });
  });
}

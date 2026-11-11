import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/consent_file_store_web.dart';

void main() {
  group('Web consent files', () {
    test(
      'startup needs no native filesystem and recording fails closed',
      () async {
        final store = ConsentFileStore();
        await store.initialize();
        await store.deleteClip('no-native-file');
        expect(store.createRecordingDirectory, throwsUnsupportedError);
      },
    );
  });
}

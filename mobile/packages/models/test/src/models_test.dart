// Not required for test files
import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group('Models', () {
    test('exports NIP71VideoKinds', () {
      expect(NIP71VideoKinds.addressableShortVideo, equals(34236));
    });

    test('exports LogLevel enum', () {
      expect(LogLevel.error.value, equals(1000));
    });

    test('exports VideoLoadingState enum', () {
      expect(VideoLoadingState.notLoaded, isNotNull);
    });
  });
}

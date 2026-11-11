import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group(NIP71VideoKinds, () {
    test('subtitleEventKind is 39307', () {
      expect(NIP71VideoKinds.subtitleEventKind, equals(39307));
    });

    group('isAddressableVideoKind', () {
      test('accepts the addressable short and normal video kinds', () {
        expect(NIP71VideoKinds.isAddressableVideoKind(34236), isTrue);
        expect(NIP71VideoKinds.isAddressableVideoKind(34235), isTrue);
      });

      test('rejects regular video kinds and other kinds', () {
        expect(NIP71VideoKinds.isAddressableVideoKind(22), isFalse);
        expect(NIP71VideoKinds.isAddressableVideoKind(21), isFalse);
        expect(NIP71VideoKinds.isAddressableVideoKind(30023), isFalse);
      });
    });
  });
}

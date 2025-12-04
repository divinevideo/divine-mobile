// Not required for test files
// ignore_for_file: prefer_const_constructors
import 'package:db_client/db_client.dart';
import 'package:test/test.dart';

void main() {
  group('DbClient', () {
    test('can be instantiated', () {
      expect(DbClient(), isNotNull);
    });
  });
}

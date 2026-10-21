import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const fixtureHashes = {
  'events.json':
      'aef551d33e5f95004d5c3104be11959ae5e6c24ca2a30b07ef9566161b979699',
  'scenarios.json':
      '7e455dadfdac2430b9c454842358d8868f8bfd0ace499b2c6fcb1fb0d9986efa',
};
Map<String, Object?> decodeFixture(String name, List<int> bytes) {
  if (sha256.convert(bytes).toString() != fixtureHashes[name]) {
    throw const FormatException('Fixture checksum mismatch');
  }
  return jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
}

Map<String, Object?> fixture(String name) => decodeFixture(
  name,
  File('test/fixtures/v1/$name').readAsBytesSync(),
);

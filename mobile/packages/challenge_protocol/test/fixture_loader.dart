import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'fixture_file.dart';

const fixtureHashes = {
  'events.json':
      '7a070f57f2246ab2897fc5bd7e5442ec5fc698058a2bdf10df6cc124a8858b37',
  'scenarios.json':
      '003ceae2356b3e5324f21adad253539f68f01eb895530deb366722c723d1d20b',
};
Map<String, Object?> decodeFixture(String name, List<int> bytes) {
  if (sha256.convert(bytes).toString() != fixtureHashes[name]) {
    throw const FormatException('Fixture checksum mismatch');
  }
  return jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
}

Map<String, Object?> fixture(String name) => decodeFixture(
  name,
  fixtureFile('v1/$name').readAsBytesSync(),
);

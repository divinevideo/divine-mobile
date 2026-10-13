// MPL-2.0
// Runs the sealed transport's NIP-44 decrypt against the official vectors.
// The file is the copy nostr_sdk already tests against; its sha256 is the
// one NIP-44 publishes.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/concord_repository.dart';
import 'package:test/test.dart';

Map<String, dynamic> _readVectors() {
  var dir = Directory.current;
  for (var i = 0; i < 8; i++) {
    for (final rel in [
      '../nostr_sdk/test/nip44/fixtures/nip44.vectors.json',
      'packages/nostr_sdk/test/nip44/fixtures/nip44.vectors.json',
    ]) {
      final file = File('${dir.path}/$rel');
      if (file.existsSync()) {
        final all = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        return all['v2'] as Map<String, dynamic>;
      }
    }
    dir = dir.parent;
  }
  throw StateError('nip44.vectors.json not found from ${Directory.current}');
}

void main() {
  group('nip44Decrypt', () {
    final v2 = _readVectors();

    test('decrypts every valid vector', () async {
      final valid = (v2['valid'] as Map)['encrypt_decrypt'] as List;
      for (final raw in valid) {
        final v = raw as Map<String, dynamic>;
        expect(
          await nip44Decrypt(
            v['payload'] as String,
            Uint8List.fromList(hexToBytes(v['conversation_key'] as String)),
          ),
          v['plaintext'],
        );
      }
    });

    test('rejects every invalid vector', () async {
      final invalid = (v2['invalid'] as Map)['decrypt'] as List;
      for (final raw in invalid) {
        final v = raw as Map<String, dynamic>;
        await expectLater(
          nip44Decrypt(
            v['payload'] as String,
            Uint8List.fromList(hexToBytes(v['conversation_key'] as String)),
          ),
          throwsFormatException,
          reason: v['note'] as String,
        );
      }
    });
  });
}

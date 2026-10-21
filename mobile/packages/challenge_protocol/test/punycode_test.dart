import 'dart:convert';

import 'package:challenge_protocol/src/punycode.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

import 'fixture_file.dart';

void main() {
  group('encodePunycode and decodePunycode', () {
    test('optimized codec matches pinned punycode.js source', () {
      final bytes = fixtureFile('punycode-reference.json').readAsBytesSync();
      expect(
        sha256.convert(bytes).toString(),
        '213029748b3be88c148212cb3a49a8d0ec2ffb02fea2d301f248824ff78ca5f4',
      );
      final corpus = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      for (final mode in ['encode', 'decode']) {
        final rows = corpus[mode] as List<dynamic>;
        expect(rows.length, mode == 'encode' ? 201 : 337);
        for (var i = 0; i < rows.length; i++) {
          final row = rows[i] as Map<String, dynamic>;
          final input = row['input'] as String;
          String action() =>
              mode == 'encode' ? encodePunycode(input) : decodePunycode(input);
          if (row['output'] == null) {
            expect(action, throwsFormatException, reason: '$mode row $i');
          } else {
            expect(action(), row['output'], reason: '$mode row $i');
          }
        }
      }
    });
  });
}

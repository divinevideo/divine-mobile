import 'dart:convert';
import 'dart:io';

import 'package:challenge_protocol/src/idna.dart';
import 'package:challenge_protocol/src/normalization.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

String _read(String name, String hash) {
  final bytes = File('test/fixtures/unicode17/$name').readAsBytesSync();
  expect(sha256.convert(bytes).toString(), hash);
  return utf8.decode(bytes);
}

String _unescape(String value) {
  if (value == '""') return '';
  return value.replaceAllMapped(
    RegExp(r'\\u([0-9a-fA-F]{4})|\\x\{([0-9a-fA-F]+)\}'),
    (m) => String.fromCharCode(int.parse(m[1] ?? m[2]!, radix: 16)),
  );
}

void main() {
  test('Unicode 17 IdnaTestV2 under nontransitional WHATWG options', () {
    final source = _read(
      'IdnaTestV2.txt',
      'beb5d0be20e896189b03209a82fdc34f06351502bbd4b8e2523583fc2954d9cf',
    );
    var count = 0;
    for (final line in const LineSplitter().convert(source)) {
      final content = line.split('#').first.trim();
      if (content.isEmpty) continue;
      final fields = content.split(';').map((s) => s.trim()).toList();
      final input = _unescape(fields[0]);
      final unicode = fields[1].isEmpty ? input : _unescape(fields[1]);
      final ascii = fields[3].isEmpty ? unicode : _unescape(fields[3]);
      final status = fields[4].isEmpty ? fields[2] : fields[4];
      final errors =
          RegExp('[A-Z][0-9]+(?:_[0-9]+)?')
              .allMatches(status)
              .map((m) => m[0]!)
              .toSet()
            ..removeAll({'A4_1', 'A4_2', 'V2', 'V3', 'U1', 'X4_2'});
      expect(
        domainToAscii(input),
        errors.isEmpty ? ascii : isNull,
        reason: 'IdnaTestV2 row ${count + 1}: $status',
      );
      count++;
    }
    expect(count, 6391);
  });

  test('Unicode 17 NFC normalization conformance', () {
    final source = _read(
      'NormalizationTest.txt',
      '5019ffd530751a741900c849c0e010332f142a3612234639bd200b82138a87db',
    );
    var count = 0;
    for (final line in const LineSplitter().convert(source)) {
      final content = line.split('#').first.trim();
      if (content.isEmpty || content.startsWith('@')) continue;
      final fields = content
          .split(';')
          .take(5)
          .map(
            (column) => String.fromCharCodes(
              column
                  .trim()
                  .split(RegExp(r'\s+'))
                  .map((hex) => int.parse(hex, radix: 16)),
            ),
          )
          .toList();
      for (var i = 0; i < 5; i++) {
        expect(
          normalizeNfc(fields[i]),
          fields[i < 3 ? 1 : 3],
          reason: 'NormalizationTest row ${count + 1}, column ${i + 1}',
        );
      }
      count++;
    }
    expect(count, 20034);
  });
}

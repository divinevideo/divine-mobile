import 'dart:convert';

import 'package:test/test.dart';

import 'harness.dart' show ReadHarness;

void main() {
  group('authenticated retention', () {
    test('forged object does not occupy durable capacity', () async {
      final h = ReadHarness();
      final forged = jsonEncode({...h.definition, 'id': 'f' * 64});
      h.source.records = [jsonEncode(h.definition), forged];
      await h.repository.refresh(h.coordinate);
      expect(
        await h.repository.store.load(h.coordinate),
        isNot(contains(forged)),
      );
    });
    test('wire whitespace variants retain one authenticated ID', () async {
      final h = ReadHarness();
      h.source.records = [
        jsonEncode(h.definition),
        ' ${jsonEncode(h.definition)} ',
      ];
      await h.repository.refresh(h.coordinate);
      expect(await h.repository.store.load(h.coordinate), hasLength(1));
    });
  });
}

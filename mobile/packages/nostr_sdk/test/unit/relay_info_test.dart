// ABOUTME: Unit tests for RelayInfo's NIP-11 max_limit parsing and round-trip.
// ABOUTME: Covers int/double parsing plus absent and malformed limitation data.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/relay/relay_info.dart';

void main() {
  group(RelayInfo, () {
    group('fromJson maxLimit', () {
      test('parses an int max_limit', () {
        final info = RelayInfo.fromJson({
          'limitation': {'max_limit': 5000},
        });

        expect(info.maxLimit, 5000);
      });

      test('parses a double max_limit as an int', () {
        final info = RelayInfo.fromJson({
          'limitation': {'max_limit': 5000.0},
        });

        expect(info.maxLimit, 5000);
      });

      test('is null when limitation is missing', () {
        final info = RelayInfo.fromJson(const <String, dynamic>{});

        expect(info.maxLimit, isNull);
      });

      test('is null when max_limit is missing from limitation', () {
        final info = RelayInfo.fromJson({'limitation': <String, dynamic>{}});

        expect(info.maxLimit, isNull);
      });

      test('is null when max_limit is a string', () {
        final info = RelayInfo.fromJson({
          'limitation': {'max_limit': '5000'},
        });

        expect(info.maxLimit, isNull);
      });

      test('is null when limitation itself is not a map', () {
        final info = RelayInfo.fromJson({'limitation': 'unlimited'});

        expect(info.maxLimit, isNull);
      });

      // A limit below 1 caps nothing, and taken at its word it would make
      // every query to the relay look capped.
      for (final (description, maxLimit) in [
        ('zero', 0),
        ('negative', -5),
        ('a fraction below one', 0.5),
      ]) {
        test('is null when max_limit is $description', () {
          final info = RelayInfo.fromJson({
            'limitation': {'max_limit': maxLimit},
          });

          expect(info.maxLimit, isNull);
        });
      }
    });

    group('toJson', () {
      test('round-trips maxLimit through fromJson', () {
        final original = RelayInfo.fromJson({
          'limitation': {'max_limit': 5000},
        });

        final roundTripped = RelayInfo.fromJson(original.toJson());

        expect(roundTripped.maxLimit, 5000);
      });

      test('omits limitation when maxLimit is null', () {
        final info = RelayInfo.fromJson(const <String, dynamic>{});

        expect(info.toJson().containsKey('limitation'), isFalse);
      });
    });
  });
}

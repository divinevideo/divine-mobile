import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nostr_sdk/signer/signer_failure.dart';

class _GaveUp implements TransientSignerFailure, Exception {}

void main() {
  group('isUnreachableSignerFailure', () {
    test('is true for a signer that bounded itself and gave up', () {
      expect(isUnreachableSignerFailure(_GaveUp()), isTrue);
    });

    test('is true for a local timeout', () {
      expect(
        isUnreachableSignerFailure(
          TimeoutException('sign_event', const Duration(seconds: 20)),
        ),
        isTrue,
      );
    });

    test('is true for an HTTP transport failure', () {
      expect(
        isUnreachableSignerFailure(
          http.ClientException(
            "Failed host lookup: 'login.divine.video'",
            Uri.parse('https://login.divine.video/api/nostr'),
          ),
        ),
        isTrue,
      );
    });

    test('is false for a refusal the signer answered with', () {
      expect(isUnreachableSignerFailure(Exception('HTTP 403')), isFalse);
    });

    test('is false for a programming error', () {
      expect(isUnreachableSignerFailure(StateError('no key')), isFalse);
    });
  });
}

// ABOUTME: Tests for reading the verifier's reason code as a SignInLapse.

import 'package:flutter_test/flutter_test.dart';
import 'package:profile_repository/profile_repository.dart';

void main() {
  group('signInLapseFromCode', () {
    const cases = <String?, SignInLapse?>{
      'signin_expired': SignInLapse.expired,
      'signin_account_changed': SignInLapse.accountChanged,
      // Only the verifier's exact strings count.
      'SIGNIN_EXPIRED': null,
      'proof_not_found': null,
      'temporarily_unavailable': null,
      '': null,
      null: null,
    };
    for (final MapEntry(key: code, value: lapse) in cases.entries) {
      test('reads ${code == null ? 'no code' : "'$code'"} as $lapse', () {
        expect(signInLapseFromCode(code), equals(lapse));
      });
    }
  });
}

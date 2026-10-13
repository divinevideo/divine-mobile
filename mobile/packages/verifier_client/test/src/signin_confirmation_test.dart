// ABOUTME: Sign-in hashing matches the verifier's and its web page's
// ABOUTME: (shared test vector in the verifier's plan for #113).

import 'dart:math';

import 'package:test/test.dart';
import 'package:verifier_client/verifier_client.dart';

void main() {
  group(SignInSecrets, () {
    final secret = 'S' * 43;
    final code = 'C' * 43;

    test('matches the shared test vector', () {
      final check = SignInSecrets.startCheckFor(secret);
      expect(check, equals('G2CN_J8Es1JmsWz0QXd2Kc-4p-lCo8GCsR-tVw6vre4'));
      expect(
        SignInSecrets.confirmBindingFor(code, check),
        equals('y_rdmZDwlKYUcthysDgPyoiPWBwzgSafjaPHJ4JE1ZY'),
      );
    });

    test('binds to both the code and the start check', () {
      final check = SignInSecrets.startCheckFor(secret);
      expect(
        SignInSecrets.confirmBindingFor('D' * 43, check),
        isNot(equals('y_rdmZDwlKYUcthysDgPyoiPWBwzgSafjaPHJ4JE1ZY')),
      );
      expect(
        SignInSecrets.confirmBindingFor(
          code,
          SignInSecrets.startCheckFor('T' * 43),
        ),
        isNot(equals('y_rdmZDwlKYUcthysDgPyoiPWBwzgSafjaPHJ4JE1ZY')),
      );
    });

    test('makes 43-character base64url secrets that differ', () {
      final a = SignInSecrets.newSecret();
      final b = SignInSecrets.newSecret();
      expect(a, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
      expect(a, isNot(equals(b)));
      expect(
        SignInSecrets.newSecret(Random(1)),
        equals(SignInSecrets.newSecret(Random(1))),
      );
    });
  });

  group(SignInRefusal, () {
    test('reads the verifier codes, and anything else as other', () {
      expect(
        SignInRefusal.fromCode('signin_not_found'),
        SignInRefusal.notFound,
      );
      expect(SignInRefusal.fromCode('signin_used'), SignInRefusal.used);
      expect(
        SignInRefusal.fromCode('signin_wrong_account'),
        SignInRefusal.wrongAccount,
      );
      expect(
        SignInRefusal.fromCode('signin_not_yours'),
        SignInRefusal.notYours,
      );
      expect(
        SignInRefusal.fromCode('signin_claim_mismatch'),
        SignInRefusal.claimMismatch,
      );
      expect(
        SignInRefusal.fromCode('invalid_event'),
        SignInRefusal.invalidEvent,
      );
      expect(SignInRefusal.fromCode('nope'), SignInRefusal.other);
      expect(SignInRefusal.fromCode(null), SignInRefusal.other);
    });
  });
}

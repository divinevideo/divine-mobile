// ABOUTME: Tests mapping Keycast account status to the protected-minor state
// ABOUTME: Covers #174 detection semantics (verified_minor -> protected)

import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:openvine/models/protected_minor_status.dart';

KeycastAccountStatus _status({
  required bool verifiedMinor,
  DateTime? verifiedMinorAt,
  bool verifiedMinorReported = true,
}) {
  return KeycastAccountStatus(
    email: 'a@b.com',
    emailVerified: true,
    publicKey: 'abc',
    verifiedMinor: verifiedMinor,
    verifiedMinorAt: verifiedMinorAt,
    verifiedMinorReported: verifiedMinorReported,
  );
}

void main() {
  group('ProtectedMinorStatus', () {
    test('unknown() is not known and not a protected minor', () {
      final s = ProtectedMinorStatus.unknown();
      expect(s.kind, ProtectedMinorStatusKind.unknown);
      expect(s.isKnown, isFalse);
      expect(s.isProtectedMinor, isFalse);
      expect(s.verifiedMinorAt, isNull);
    });

    test('notProtected() is known and not a protected minor', () {
      final s = ProtectedMinorStatus.notProtected();
      expect(s.kind, ProtectedMinorStatusKind.notProtected);
      expect(s.isKnown, isTrue);
      expect(s.isProtectedMinor, isFalse);
      expect(s.verifiedMinorAt, isNull);
    });

    test('fromKeycast(null) -> unknown', () {
      final status = ProtectedMinorStatus.fromKeycast(null);

      expect(status.kind, ProtectedMinorStatusKind.unknown);
      expect(status.isKnown, isFalse);
      expect(status.isProtectedMinor, isFalse);
    });

    test('verified_minor true -> protected, carries timestamp', () {
      final at = DateTime.utc(2026, 6, 30, 12);
      final s = ProtectedMinorStatus.fromKeycast(
        _status(verifiedMinor: true, verifiedMinorAt: at),
      );
      expect(s.kind, ProtectedMinorStatusKind.protected);
      expect(s.isKnown, isTrue);
      expect(s.isProtectedMinor, isTrue);
      expect(s.verifiedMinorAt, at);
    });

    test('an explicit verified_minor false is reported', () {
      final status = ProtectedMinorStatus.fromKeycast(
        _status(verifiedMinor: false),
      );
      expect(status.verifiedMinorReported, isTrue);
    });

    test(
      'a reply without verified_minor stays not protected but unreported',
      () {
        final status = ProtectedMinorStatus.fromKeycast(
          _status(verifiedMinor: false, verifiedMinorReported: false),
        );
        expect(status.kind, ProtectedMinorStatusKind.notProtected);
        expect(status.verifiedMinorReported, isFalse);
      },
    );

    test('verified_minor false -> not protected', () {
      final status = ProtectedMinorStatus.fromKeycast(
        _status(verifiedMinor: false),
      );

      expect(status.kind, ProtectedMinorStatusKind.notProtected);
      expect(status.isKnown, isTrue);
      expect(status.isProtectedMinor, isFalse);
    });
  });
}

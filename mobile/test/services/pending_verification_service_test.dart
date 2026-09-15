// ABOUTME: Tests for PendingVerification expiry window
// ABOUTME: Verifies the 24h verify window so the PIN path works on late return

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/pending_verification_service.dart';

class _MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  group(PendingVerification, () {
    PendingVerification pendingCreatedAgo(Duration age) {
      return PendingVerification(
        deviceCode: 'device123',
        verifier: 'verifier456',
        email: 'test@example.com',
        createdAt: DateTime.now().subtract(age),
      );
    }

    test('expiration window is 24 hours', () {
      expect(PendingVerification.expirationDuration, const Duration(hours: 24));
    });

    test('is not expired well within the 24h verify window', () {
      expect(pendingCreatedAgo(const Duration(hours: 23)).isExpired, isFalse);
    });

    test('is not expired just before 24h', () {
      expect(
        pendingCreatedAgo(const Duration(hours: 23, minutes: 59)).isExpired,
        isFalse,
      );
    });

    test('is expired after the 24h verify window', () {
      expect(pendingCreatedAgo(const Duration(hours: 25)).isExpired, isTrue);
    });

    test('data older than the previous 30-minute window is still valid', () {
      // Regression guard for the late-return PIN path: a user who returns an
      // hour later must still have the deviceCode + verifier to exchange.
      expect(pendingCreatedAgo(const Duration(hours: 1)).isExpired, isFalse);
    });
  });

  group(PendingVerificationService, () {
    late _MockFlutterSecureStorage storage;
    late Map<String, String> storedValues;
    late PendingVerificationService service;

    setUp(() {
      storage = _MockFlutterSecureStorage();
      storedValues = <String, String>{};
      service = PendingVerificationService(storage);

      when(
        () => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((invocation) async {
        final key = invocation.namedArguments[#key]! as String;
        final value = invocation.namedArguments[#value] as String?;
        if (value == null) {
          storedValues.remove(key);
        } else {
          storedValues[key] = value;
        }
      });
      when(() => storage.read(key: any(named: 'key'))).thenAnswer(
        (invocation) async =>
            storedValues[invocation.namedArguments[#key]! as String],
      );
      when(() => storage.delete(key: any(named: 'key'))).thenAnswer((
        invocation,
      ) async {
        storedValues.remove(invocation.namedArguments[#key]! as String);
      });
    });

    test('round-trips the full owner public-key hex', () async {
      const ownerPublicKeyHex =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

      await service.save(
        deviceCode: 'device123',
        verifier: 'verifier456',
        email: 'test@example.com',
        ownerPublicKeyHex: ownerPublicKeyHex,
      );

      final pending = await service.load();
      expect(pending, isNotNull);
      expect(pending!.ownerPublicKeyHex, ownerPublicKeyHex);
    });

    test('loads a legacy ownerless record as ownerless', () async {
      await service.save(
        deviceCode: 'device123',
        verifier: 'verifier456',
        email: 'test@example.com',
      );

      final pending = await service.load();
      expect(pending, isNotNull);
      expect(pending!.ownerPublicKeyHex, isNull);
    });

    test('save removes retired invite-code data', () async {
      storedValues['pending_verification_invite_code'] = 'ABCD-EFGH';

      await service.save(
        deviceCode: 'device123',
        verifier: 'verifier456',
        email: 'test@example.com',
      );

      expect(storedValues, isNot(contains('pending_verification_invite_code')));
    });

    test(
      'load removes retired invite-code data during startup restore',
      () async {
        storedValues['pending_verification_invite_code'] = 'ABCD-EFGH';

        await service.load();

        expect(
          storedValues,
          isNot(contains('pending_verification_invite_code')),
        );
      },
    );

    test('load continues when retired invite-code deletion fails', () async {
      storedValues
        ..['pending_verification_device_code'] = 'device123'
        ..['pending_verification_verifier'] = 'verifier456'
        ..['pending_verification_email'] = 'test@example.com'
        ..['pending_verification_created_at'] = DateTime.now()
            .toIso8601String();
      when(
        () => storage.delete(key: 'pending_verification_invite_code'),
      ).thenThrow(Exception('delete failed'));

      final pending = await service.load();

      expect(pending, isNotNull);
      expect(pending!.deviceCode, 'device123');
    });

    test('clear removes retired invite-code data', () async {
      storedValues['pending_verification_invite_code'] = 'ABCD-EFGH';

      await service.clear();

      expect(storedValues, isNot(contains('pending_verification_invite_code')));
    });
  });
}

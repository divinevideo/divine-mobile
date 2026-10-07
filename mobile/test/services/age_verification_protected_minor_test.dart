// ABOUTME: Verifies the protected-minor lock on AgeVerificationService — the
// ABOUTME: single choke point that forces adult content off for #175.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const pubkey =
      '1111111111111111111111111111111111111111111111111111111111111111';

  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  group(AgeVerificationService, () {
    test(
      'isAdultContentVerified is false for a protected minor even if stored true',
      () async {
        SharedPreferences.setMockInitialValues({
          'adult_content_verified_$pubkey': true,
        });
        preferences = await SharedPreferences.getInstance();
        final service = AgeVerificationService(
          preferences: preferences,
          isProtectedMinor: () => true,
          currentPubkeyHex: () => pubkey,
        );
        await service.initialize();
        expect(service.isProtectedMinor, isTrue);
        expect(service.isAdultContentVerified, false);
      },
    );

    test(
      'setAdultContentVerified(true) is rejected for a protected minor',
      () async {
        var protected = true;
        final service = AgeVerificationService(
          preferences: preferences,
          isProtectedMinor: () => protected,
          currentPubkeyHex: () => pubkey,
        );
        await service.initialize();
        expect(await service.setAdultContentVerified(true), isFalse);
        // Even after lifting the protection, nothing was persisted as true.
        protected = false;
        expect(service.isAdultContentVerified, false);
      },
    );

    test('non-protected account behaves normally', () async {
      final service = AgeVerificationService(
        preferences: preferences,
        isProtectedMinor: () => false,
        currentPubkeyHex: () => pubkey,
      );
      await service.initialize();
      expect(service.isProtectedMinor, isFalse);
      expect(service.isAdultContentVerified, isFalse);
      await service.setAdultContentVerified(true);
      expect(service.isAdultContentVerified, true);
    });

    test('defaults to not-protected when no callback supplied', () async {
      final service = AgeVerificationService(
        preferences: preferences,
        currentPubkeyHex: () => pubkey,
      );
      await service.initialize();
      await service.setAdultContentVerified(true);
      expect(service.isAdultContentVerified, true);
    });
  });
}

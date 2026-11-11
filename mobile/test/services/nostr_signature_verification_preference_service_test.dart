// ABOUTME: Tests persistence and SDK mapping for Nostr signature policy prefs.
// ABOUTME: Covers platform defaults, invalid values, and round-trip storage.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart' as nostr_sdk;
import 'package:openvine/models/nostr_signature_verification_policy.dart';
import 'package:openvine/services/nostr_signature_verification_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group(NostrSignatureVerificationPreferenceService, () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to verifying all relays on native builds', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = NostrSignatureVerificationPreferenceService(
        prefs,
        isWeb: false,
      );

      expect(
        service.currentPolicy,
        NostrSignatureVerificationPolicy.all,
      );
    });

    test('defaults to trusting Divine relays on the web', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = NostrSignatureVerificationPreferenceService(
        prefs,
        isWeb: true,
      );

      expect(
        service.currentPolicy,
        NostrSignatureVerificationPolicy.nonDivineRelays,
      );
    });

    test('keeps an explicit choice of all relays on the web', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = NostrSignatureVerificationPreferenceService(
        prefs,
        isWeb: true,
      );

      await service.setPolicy(NostrSignatureVerificationPolicy.all);

      expect(
        service.currentPolicy,
        NostrSignatureVerificationPolicy.all,
      );
    });

    test('round-trips every policy through storage', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = NostrSignatureVerificationPreferenceService(prefs);

      for (final policy in NostrSignatureVerificationPolicy.values) {
        await service.setPolicy(policy);
        expect(service.currentPolicy, policy);
        expect(
          prefs.getString(NostrSignatureVerificationPreferenceService.prefsKey),
          policy.storageValue,
        );
      }
    });

    test('falls back to the platform default for unknown values', () async {
      SharedPreferences.setMockInitialValues({
        NostrSignatureVerificationPreferenceService.prefsKey: 'mystery',
      });
      final prefs = await SharedPreferences.getInstance();

      expect(
        NostrSignatureVerificationPreferenceService(
          prefs,
          isWeb: false,
        ).currentPolicy,
        NostrSignatureVerificationPolicy.all,
      );
      expect(
        NostrSignatureVerificationPreferenceService(
          prefs,
          isWeb: true,
        ).currentPolicy,
        NostrSignatureVerificationPolicy.nonDivineRelays,
      );
    });

    test('maps app policies to SDK policies', () {
      expect(
        NostrSignatureVerificationPolicy.all.toSdkPolicy(),
        nostr_sdk.SignatureVerificationPolicy.all,
      );
      expect(
        NostrSignatureVerificationPolicy.untrustedRelays.toSdkPolicy(),
        nostr_sdk.SignatureVerificationPolicy.untrustedRelays,
      );
      expect(
        NostrSignatureVerificationPolicy.nonDivineRelays.toSdkPolicy(),
        nostr_sdk.SignatureVerificationPolicy.nonDivineRelays,
      );
    });
  });
}

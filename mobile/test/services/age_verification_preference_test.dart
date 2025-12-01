// ABOUTME: TDD tests for AdultContentPreference enum and storage
// ABOUTME: Tests preference persistence and retrieval in AgeVerificationService

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openvine/services/age_verification_service.dart';

void main() {
  group('AdultContentPreference', () {
    test('enum has three values', () {
      expect(AdultContentPreference.values.length, 3);
      expect(AdultContentPreference.values, contains(AdultContentPreference.alwaysShow));
      expect(AdultContentPreference.values, contains(AdultContentPreference.askEachTime));
      expect(AdultContentPreference.values, contains(AdultContentPreference.neverShow));
    });
  });

  group('AgeVerificationService adult content preference', () {
    late AgeVerificationService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      service = AgeVerificationService();
      await service.initialize();
    });

    test('default preference is askEachTime', () {
      expect(service.adultContentPreference, AdultContentPreference.askEachTime);
    });

    test('can set preference to alwaysShow', () async {
      await service.setAdultContentPreference(AdultContentPreference.alwaysShow);
      expect(service.adultContentPreference, AdultContentPreference.alwaysShow);
    });

    test('can set preference to neverShow', () async {
      await service.setAdultContentPreference(AdultContentPreference.neverShow);
      expect(service.adultContentPreference, AdultContentPreference.neverShow);
    });

    test('preference persists after reinitialization', () async {
      await service.setAdultContentPreference(AdultContentPreference.alwaysShow);

      // Create new instance and reinitialize
      final newService = AgeVerificationService();
      await newService.initialize();

      expect(newService.adultContentPreference, AdultContentPreference.alwaysShow);
    });

    test('clearVerificationStatus also clears preference', () async {
      await service.setAdultContentPreference(AdultContentPreference.alwaysShow);
      await service.clearVerificationStatus();

      expect(service.adultContentPreference, AdultContentPreference.askEachTime);
    });

    test('shouldAutoShowAdultContent returns true only when alwaysShow and verified', () async {
      // Not verified, any preference - should be false
      expect(service.shouldAutoShowAdultContent, false);

      // Verified but askEachTime - should be false
      await service.setAdultContentVerified(true);
      await service.setAdultContentPreference(AdultContentPreference.askEachTime);
      expect(service.shouldAutoShowAdultContent, false);

      // Verified and alwaysShow - should be true
      await service.setAdultContentPreference(AdultContentPreference.alwaysShow);
      expect(service.shouldAutoShowAdultContent, true);

      // Verified but neverShow - should be false
      await service.setAdultContentPreference(AdultContentPreference.neverShow);
      expect(service.shouldAutoShowAdultContent, false);
    });

    test('shouldHideAdultContent returns true when neverShow', () async {
      expect(service.shouldHideAdultContent, false);

      await service.setAdultContentPreference(AdultContentPreference.neverShow);
      expect(service.shouldHideAdultContent, true);

      await service.setAdultContentPreference(AdultContentPreference.alwaysShow);
      expect(service.shouldHideAdultContent, false);
    });

    test('shouldAskForAdultContent returns true when askEachTime or not verified', () async {
      // Default state - askEachTime, not verified
      expect(service.shouldAskForAdultContent, true);

      // Still askEachTime even when verified
      await service.setAdultContentVerified(true);
      expect(service.shouldAskForAdultContent, true);

      // Not asking when alwaysShow and verified
      await service.setAdultContentPreference(AdultContentPreference.alwaysShow);
      expect(service.shouldAskForAdultContent, false);

      // Not asking when neverShow (we hide instead)
      await service.setAdultContentPreference(AdultContentPreference.neverShow);
      expect(service.shouldAskForAdultContent, false);
    });
  });
}

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/secure_storage_options.dart';

void main() {
  group('appMacOsSecureStorageOptions', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    bool usesDataProtectionKeyChain({required bool isDebug}) =>
        appMacOsSecureStorageOptions(
          isDebug: isDebug,
        ).toMap()['useDataProtectionKeyChain'] ==
        'true';

    test('falls back to the file-based keychain on macOS debug', () {
      // The macOS-debug branch is the one that would otherwise hit OSStatus
      // -34018 (errSecMissingEntitlement). #5563.
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(usesDataProtectionKeyChain(isDebug: true), isFalse);
    });

    test('keeps the prior keychain contract on macOS release', () {
      // Release builds are properly signed, so the data-protection keychain
      // stays enabled even on macOS. Asserting the full map locks the
      // no-regression contract: if the helper later set `accessibility`
      // (e.g. to mirror `nostr_key_manager`'s `first_unlock`) the App Store
      // keychain attributes would change silently and could orphan
      // already-stored keys for real users. #5563.
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(
        appMacOsSecureStorageOptions(isDebug: false).toMap(),
        <String, String>{
          'accessibility': 'unlocked',
          'accountName': 'flutter_secure_storage_service',
          'synchronizable': 'false',
          'useDataProtectionKeyChain': 'true',
        },
      );
    });

    test('keeps the data-protection keychain on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(usesDataProtectionKeyChain(isDebug: true), isTrue);
    });

    test('keeps the data-protection keychain on Android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(usesDataProtectionKeyChain(isDebug: true), isTrue);
    });
  });

  group('appDbCipherKeyIosSecureStorageOptions', () {
    test('stores the database key readable after first unlock, and '
        'restorable onto a new device', () {
      // `unlocked` is what made every locked-screen launch fail with -25308
      // and land on the database-failure screen (#9343); the full map pins
      // the rest of the item's identity so a rewrite keeps finding what
      // earlier installs wrote.
      //
      // `first_unlock_this_device` fixes #9343 just as well and is the trap:
      // its items never migrate to a new device, while `divine_db.db` is in
      // the backup, so a restore onto a new iPhone would find the database,
      // find no key and wipe it through key-loss recovery (#9385). Plain
      // `first_unlock` is also what `nostr_key_manager` already stores the
      // Nostr identity key under, in the same backup.
      expect(appDbCipherKeyIosSecureStorageOptions().toMap(), <String, String>{
        'accessibility': 'first_unlock',
        'accountName': 'flutter_secure_storage_service',
        'synchronizable': 'false',
      });
    });
  });

  group('legacyDbCipherKeyIosSecureStorageOptions', () {
    test('names the pre-#9343 accessibility explicitly', () {
      // The iOS plugin puts the accessibility into its delete query, so the
      // old item is only reachable through options that spell out `unlocked`
      // — regardless of what the package default becomes.
      expect(
        legacyDbCipherKeyIosSecureStorageOptions().toMap(),
        <String, String>{
          'accessibility': 'unlocked',
          'accountName': 'flutter_secure_storage_service',
          'synchronizable': 'false',
        },
      );
    });
  });

  group('dbCipherKeyV2IosSecureStorageOptions', () {
    test('names the item #9380 wrote to the .v2 slot', () {
      // The full map #9380 pinned for the options it stored the key under. A
      // delete naming anything else leaves that item in the Keychain, and a
      // reset that leaves it behind hands the old key to the next launch.
      expect(dbCipherKeyV2IosSecureStorageOptions().toMap(), <String, String>{
        'accessibility': 'first_unlock_this_device',
        'accountName': 'flutter_secure_storage_service',
        'synchronizable': 'false',
      });
    });
  });
}

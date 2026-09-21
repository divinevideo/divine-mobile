// ABOUTME: Shared Keychain options for the app's FlutterSecureStorage instances.
// ABOUTME: Centralizes the macOS-debug keychain fallback (#5563) + the DB key's iOS accessibility (#9343).

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// macOS Keychain options for the app's `FlutterSecureStorage` instances.
///
/// macOS debug builds are ad-hoc/linker-signed without a Keychain-Sharing
/// provisioning profile, so the data-protection keychain rejects every
/// read/write with OSStatus `-34018` (`errSecMissingEntitlement`). That blocks
/// the at-rest database cipher-key resolve at startup and surfaces the restart
/// screen. In that case fall back to the file-based keychain, which needs no
/// `keychain-access-groups` entitlement; release builds are properly signed and
/// keep the recommended data-protection keychain.
///
/// Mirrors the `useDataProtectionKeyChain` gate already used by
/// `nostr_key_manager`'s `PlatformSecureStorage`. `accessibility` is
/// intentionally left at the package default (`unlocked`) to preserve the app
/// stores' prior macOS behavior. See #5563.
///
/// Because of this gate, macOS debug and release builds read from *different*
/// keychains on the same Mac. Switching build modes locally won't find the
/// other mode's database cipher key and triggers the dev-only
/// backup-then-recreate key-loss path in `DatabaseEncryptionBootstrap`. This is
/// harmless for end users — who only ever run a single signed release build —
/// but surprising during local development.
///
/// [isDebug] defaults to [kDebugMode] (a compile-time constant) and exists only
/// so tests can exercise the macOS release branch, which `kDebugMode` cannot
/// reach under `flutter test`. Production callers omit it.
MacOsOptions appMacOsSecureStorageOptions({bool isDebug = kDebugMode}) =>
    MacOsOptions(
      useDataProtectionKeyChain:
          defaultTargetPlatform != TargetPlatform.macOS || !isDebug,
    );

/// iOS Keychain options for the at-rest database cipher key.
///
/// `first_unlock_this_device` keeps the key readable from the first unlock
/// after boot until the next reboot — including while the device is locked,
/// which is exactly when a silent push, a background refresh or a prewarmed
/// launch runs the database bootstrap. The package default, `unlocked`, made
/// every such launch fail with `errSecInteractionNotAllowed` (-25308) and land
/// on the database-failure screen (#9343). The `this_device` half keeps the
/// key out of device backups: the database file is backed up, and a restore
/// onto another device must not carry the key that opens it along.
///
/// Only the database key uses this. `nostr_key_manager` stores the identity
/// key under `first_unlock` on purpose, so an account survives a restore.
IOSOptions appDbCipherKeyIosSecureStorageOptions() => const IOSOptions(
  accessibility: KeychainAccessibility.first_unlock_this_device,
);

/// The iOS options the database cipher key was stored under before #9343: the
/// package default, spelled out so a later change to that default cannot
/// silently redefine which item the one-time migration reads and deletes.
///
/// The Keychain refuses to hand this item over whenever the device is locked,
/// so it exists only to be read once and moved under
/// [appDbCipherKeyIosSecureStorageOptions]. Never write a new key with it.
IOSOptions legacyDbCipherKeyIosSecureStorageOptions() =>
    // Spelled out on purpose: `defaultOptions` would follow a future change to
    // the package default, and this must keep naming what was written.
    // ignore: use_named_constants, avoid_redundant_argument_values
    const IOSOptions(accessibility: KeychainAccessibility.unlocked);

// ABOUTME: Shared Keychain options for the app's FlutterSecureStorage instances.
// ABOUTME: Centralizes the macOS-debug keychain fallback (#5563) + the DB key's iOS accessibility (#9343, #9385).

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
/// `first_unlock` keeps the key readable from the first unlock after boot until
/// the next reboot — including while the device is locked, which is exactly when
/// a silent push, a background refresh or a prewarmed launch runs the database
/// bootstrap. The package default, `unlocked`, made every such launch fail with
/// `errSecInteractionNotAllowed` (-25308) and land on the database-failure
/// screen (#9343).
///
/// Deliberately **not** `first_unlock_this_device`, which is readable at exactly
/// the same times but whose items, per `SecItem.h`, "will never migrate to a new
/// device, so after a backup is restored to a new device these items will be
/// missing". `divine_db.db` lives under Application Support and nothing excludes
/// it from backup, so a device-bound key would travel less far than the data it
/// opens: a restore onto a new iPhone would find the database, find no key, wipe
/// it through key-loss recovery and leave a permanently unreadable
/// `.pre_key_loss_wipe_backup` behind. What that costs is the local-only data
/// nothing can re-fetch — drafts, pending uploads and actions, outgoing DMs,
/// pending gift wraps, saved caption and title styles. See #9385.
///
/// Keeping an at-rest key out of backups is a defensible threat model, but it is
/// not this app's: the same backup already carries the Nostr identity key under
/// `first_unlock` (`nostr_key_manager`'s `PlatformSecureStorage`), and carries
/// `cache_sync.db`, the Hive boxes and SharedPreferences in the clear. The
/// at-rest design protects the device's filesystem, not its backups — see
/// `docs/sqlcipher_at_rest_plan.md`.
IOSOptions appDbCipherKeyIosSecureStorageOptions() =>
    const IOSOptions(accessibility: KeychainAccessibility.first_unlock);

/// The iOS options the database cipher key may still be stored under: the
/// package default from before #9343, spelled out so a later change to that
/// default cannot silently redefine which item a delete removes.
///
/// The key keeps one slot for its whole life and is rewritten *in place* to
/// carry [appDbCipherKeyIosSecureStorageOptions]; until that rewrite has run on
/// a given device the item still carries this class. Reads do not need these
/// options — the iOS plugin leaves the accessibility out of its read query — but
/// deletes do, because it puts the accessibility into that one. Read and delete
/// only; never write a new key with it.
IOSOptions legacyDbCipherKeyIosSecureStorageOptions() =>
    // Spelled out on purpose: `defaultOptions` would follow a future change to
    // the package default, and this must keep naming what was written.
    // ignore: use_named_constants, avoid_redundant_argument_values
    const IOSOptions(accessibility: KeychainAccessibility.unlocked);

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show NostrRemoteSignerInfo;
import 'package:openvine/models/authentication_source.dart';
import 'package:unified_logger/unified_logger.dart';

part 'signer_account_removal.dart';

const _kBunkerInfoKey = 'bunker_info';
const _kAmberPubkeyKey = 'amber_pubkey';
const _kAmberPackageKey = 'amber_package';
const _kKeycastRefreshTokenKey = 'keycast_refresh_token';
const _kKeycastAuthHandleKey = 'keycast_auth_handle';
String _keycastSessionKey(String pubkeyHex) => 'keycast_session_$pubkeyHex';

/// Owns secure-storage persistence for external-signer credentials — NIP-46
/// bunker, NIP-55 Amber, and Divine/Keycast OAuth sessions — plus the
/// per-account archive used to swap signer keys when switching accounts.
///
/// Extracted from `AuthService` (#4741) as the first client-tier collaborator.
/// `AuthService` delegates to it and keeps the auth-source SharedPreferences
/// write; this store touches only [FlutterSecureStorage].
class SignerSecureStore {
  SignerSecureStore(this._storage);

  final FlutterSecureStorage? _storage;

  // === NIP-46 bunker ===

  Future<void> saveBunker(
    NostrRemoteSignerInfo info, {
    void Function()? ensureCurrent,
  }) async {
    ensureCurrent?.call();
    if (_storage == null) return;
    try {
      // Serialize bunker info as bunker URL (includes all needed data)
      final bunkerUrl = info.toString();
      await _storage.write(key: _kBunkerInfoKey, value: bunkerUrl);
      ensureCurrent?.call();
      if (ensureCurrent != null) {
        final stored = await _storage.read(key: _kBunkerInfoKey);
        ensureCurrent();
        if (stored != bunkerUrl) {
          throw StateError('Bunker credentials readback did not match');
        }
      }
      Log.info(
        'Saved bunker info to secure storage',
        name: 'SignerSecureStore',
        category: LogCategory.auth,
      );
    } catch (e) {
      Log.error(
        'Failed to save bunker info: $e',
        name: 'SignerSecureStore',
        category: LogCategory.auth,
      );
      if (ensureCurrent != null) {
        rethrow;
      }
    }
  }

  Future<NostrRemoteSignerInfo?> loadBunker() async {
    if (_storage == null) return null;
    try {
      final bunkerUrl = await _storage.read(key: _kBunkerInfoKey);
      if (bunkerUrl == null || bunkerUrl.isEmpty) return null;

      final info = NostrRemoteSignerInfo.parseBunkerUrl(bunkerUrl);
      Log.info(
        'Loaded bunker info from secure storage',
        name: 'SignerSecureStore',
        category: LogCategory.auth,
      );
      return info;
    } catch (e) {
      Log.error(
        'Failed to load bunker info: $e',
        name: 'SignerSecureStore',
        category: LogCategory.auth,
      );
      return null;
    }
  }

  Future<void> clearBunker() async {
    if (_storage == null) return;
    try {
      await _storage.delete(key: _kBunkerInfoKey);
      Log.info(
        'Cleared bunker info from secure storage',
        name: 'SignerSecureStore',
        category: LogCategory.auth,
      );
    } catch (e) {
      Log.error(
        'Failed to clear bunker info: $e',
        name: 'SignerSecureStore',
        category: LogCategory.auth,
      );
    }
  }

  // === NIP-55 Amber ===

  Future<void> saveAmber(
    String pubkey,
    String? package, {
    void Function()? ensureCurrent,
  }) async {
    ensureCurrent?.call();
    if (_storage == null) return;
    try {
      await _storage.write(key: _kAmberPubkeyKey, value: pubkey);
      ensureCurrent?.call();
      if (package != null) {
        await _storage.write(key: _kAmberPackageKey, value: package);
      } else if (ensureCurrent != null) {
        await _storage.delete(key: _kAmberPackageKey);
      }
      ensureCurrent?.call();
      if (ensureCurrent != null) {
        final storedPubkey = await _storage.read(key: _kAmberPubkeyKey);
        ensureCurrent();
        final storedPackage = await _storage.read(key: _kAmberPackageKey);
        ensureCurrent();
        if (storedPubkey != pubkey || storedPackage != package) {
          throw StateError('Amber credentials readback did not match');
        }
      }
      Log.info(
        'Saved Amber info to secure storage',
        name: 'SignerSecureStore',
        category: LogCategory.auth,
      );
    } catch (e) {
      Log.error(
        'Failed to save Amber info: $e',
        name: 'SignerSecureStore',
        category: LogCategory.auth,
      );
      if (ensureCurrent != null) {
        rethrow;
      }
    }
  }

  Future<({String pubkey, String? package})?> loadAmber() async {
    if (_storage == null) return null;
    try {
      final pubkey = await _storage.read(key: _kAmberPubkeyKey);
      if (pubkey == null || pubkey.isEmpty) return null;

      final package = await _storage.read(key: _kAmberPackageKey);
      Log.info(
        'Loaded Amber info from secure storage',
        name: 'SignerSecureStore',
        category: LogCategory.auth,
      );
      return (pubkey: pubkey, package: package);
    } catch (e) {
      Log.error(
        'Failed to load Amber info: $e',
        name: 'SignerSecureStore',
        category: LogCategory.auth,
      );
      return null;
    }
  }

  Future<void> clearAmber() async {
    if (_storage == null) return;
    try {
      await _storage.delete(key: _kAmberPubkeyKey);
      await _storage.delete(key: _kAmberPackageKey);
      Log.info(
        'Cleared Amber info from secure storage',
        name: 'SignerSecureStore',
        category: LogCategory.auth,
      );
    } catch (e) {
      Log.error(
        'Failed to clear Amber info: $e',
        name: 'SignerSecureStore',
        category: LogCategory.auth,
      );
    }
  }

  // === Divine/Keycast OAuth session ===

  /// Commits one exact bound OAuth input and its standalone credentials.
  /// The caller owns the device lease; failed writes leave raw evidence intact.
  Future<void> saveKeycastSession(
    KeycastSession session, {
    required void Function() ensureCurrent,
  }) async {
    ensureCurrent();
    final storage = _storage ?? const FlutterSecureStorage();
    await session.save(storage);
    ensureCurrent();
    final stored = await KeycastSession.load(storage);
    ensureCurrent();
    if (jsonEncode(stored?.toJson()) != jsonEncode(session.toJson())) {
      throw StateError('OAuth credentials readback did not match');
    }

    Future<void> commitSlot(String key, String? value) async {
      ensureCurrent();
      if (value == null) {
        await storage.delete(key: key);
      } else {
        await storage.write(key: key, value: value);
      }
      ensureCurrent();
      final persisted = await storage.read(key: key);
      ensureCurrent();
      if (persisted != value) {
        throw StateError('OAuth credential slot readback did not match');
      }
    }

    await commitSlot(_kKeycastRefreshTokenKey, session.refreshToken);
    ensureCurrent();
    await commitSlot(_kKeycastAuthHandleKey, session.authorizationHandle);
    ensureCurrent();
  }

  /// Clears the global Keycast session, refresh token, and auth handle.
  ///
  /// Used when a stale or ambiguous OAuth session must be discarded
  /// (e.g., during initialization tiebreaker branches).
  Future<void> clearKeycastSessionAndTokens() async {
    Object? firstError;
    StackTrace? firstStack;

    Future<void> deleteKey(Future<void> Function() delete) async {
      try {
        await delete();
      } catch (e, stack) {
        firstError ??= e;
        firstStack ??= stack;
      }
    }

    await deleteKey(() => KeycastSession.clear(_storage));
    await deleteKey(() async {
      await _storage?.delete(key: _kKeycastRefreshTokenKey);
    });
    await deleteKey(() async {
      await _storage?.delete(key: _kKeycastAuthHandleKey);
    });

    if (firstError != null) {
      Error.throwWithStackTrace(firstError!, firstStack!);
    }
  }

  // === Per-account archive (account switching) ===

  /// Archives the currently-active signer keys under per-account keys for
  /// [pubkeyHex], so they can be restored when switching back to this account.
  ///
  /// Failures are logged and swallowed by default, which suits sign-out: the
  /// session is going away either way. Pass [throwOnFailure] when the caller
  /// depends on the archive having landed — the in-place account switch does,
  /// because the incoming sign-in overwrites the shared slots it copies from.
  Future<void> archive(String pubkeyHex, {bool throwOnFailure = false}) async {
    if (_storage == null) return;
    try {
      // Archive Amber info
      final amberInfo = await loadAmber();
      if (amberInfo != null) {
        await _storage.write(
          key: '${_kAmberPubkeyKey}_$pubkeyHex',
          value: amberInfo.pubkey,
        );
        if (amberInfo.package != null) {
          await _storage.write(
            key: '${_kAmberPackageKey}_$pubkeyHex',
            value: amberInfo.package,
          );
        }
      }

      // Archive Bunker info
      final bunkerUrl = await _storage.read(key: _kBunkerInfoKey);
      if (bunkerUrl != null && bunkerUrl.isNotEmpty) {
        await _storage.write(
          key: '${_kBunkerInfoKey}_$pubkeyHex',
          value: bunkerUrl,
        );
      }

      // Archive OAuth session — only if it has a bound userPubkey
      // matching this account. Null userPubkey means the session was
      // created before pubkey binding (legacy) and cannot be verified
      // as belonging to any specific account; archiving an unverifiable
      // session risks cross-contamination (Bug 2). A fresh OAuth
      // sign-in via signInWithDivineOAuth always binds userPubkey.
      final oauthSession = await KeycastSession.load(_storage);
      final oauthOwnerMatches =
          oauthSession?.userPubkey != null &&
          oauthSession?.userPubkey == pubkeyHex;
      final archiveOauth = oauthSession != null && oauthOwnerMatches;
      if (archiveOauth) {
        await _storage.write(
          key: _keycastSessionKey(pubkeyHex),
          value: jsonEncode(oauthSession.toJson()),
        );
      } else if (oauthSession != null) {
        Log.warning(
          'archive: skipping OAuth archive for ${pubkeyForLogs(pubkeyHex)} — '
          'global session pubkey='
          '${pubkeyForLogs(oauthSession.userPubkey, whenNull: "null (legacy)")} '
          '(cannot verify ownership, not archiving to avoid corruption)',
          name: 'SignerSecureStore',
          category: LogCategory.auth,
        );
      }

      Log.info(
        'archive: archived for ${pubkeyForLogs(pubkeyHex)} — '
        'amber=${amberInfo != null}, '
        'bunker=${bunkerUrl != null && bunkerUrl.isNotEmpty}, '
        'oauth=$archiveOauth',
        name: 'SignerSecureStore',
        category: LogCategory.auth,
      );
    } catch (e) {
      Log.warning(
        'archive: failed for ${pubkeyForLogs(pubkeyHex)}: $e',
        name: 'SignerSecureStore',
        category: LogCategory.auth,
      );
      if (throwOnFailure) rethrow;
    }
  }

  /// Restores per-account archived signer keys to the active-session keys.
  ///
  /// The raw switch is kept here without a try/catch or auth-source write;
  /// `AuthService` wraps this call and persists the auth source, preserving
  /// the original error-handling scope.
  Future<void> restoreActiveKeys(
    String pubkeyHex,
    AuthenticationSource source, {
    void Function()? ensureCurrent,
  }) async {
    ensureCurrent?.call();
    final storage = _storage;
    if (storage == null) return;
    switch (source) {
      case AuthenticationSource.amber:
        final pubkey = await storage.read(
          key: '${_kAmberPubkeyKey}_$pubkeyHex',
        );
        ensureCurrent?.call();
        Log.debug(
          'restoreActiveKeys: amber archive lookup — found=${pubkey != null}',
          name: 'SignerSecureStore',
          category: LogCategory.auth,
        );
        if (pubkey != null) {
          await storage.write(key: _kAmberPubkeyKey, value: pubkey);
          ensureCurrent?.call();
          final package = await storage.read(
            key: '${_kAmberPackageKey}_$pubkeyHex',
          );
          ensureCurrent?.call();
          if (package != null) {
            await storage.write(key: _kAmberPackageKey, value: package);
            ensureCurrent?.call();
          }
        }

      case AuthenticationSource.bunker:
        final bunkerUrl = await storage.read(
          key: '${_kBunkerInfoKey}_$pubkeyHex',
        );
        ensureCurrent?.call();
        Log.debug(
          'restoreActiveKeys: bunker archive lookup — '
          'found=${bunkerUrl != null && bunkerUrl.isNotEmpty}',
          name: 'SignerSecureStore',
          category: LogCategory.auth,
        );
        if (bunkerUrl != null) {
          await storage.write(key: _kBunkerInfoKey, value: bunkerUrl);
          ensureCurrent?.call();
        }

      case AuthenticationSource.divineOAuth:
        final sessionJson = await storage.read(
          key: _keycastSessionKey(pubkeyHex),
        );
        ensureCurrent?.call();
        Log.debug(
          'restoreActiveKeys: OAuth session archive lookup — '
          'found=${sessionJson != null}',
          name: 'SignerSecureStore',
          category: LogCategory.auth,
        );
        if (sessionJson != null) {
          final sessionMap = jsonDecode(sessionJson) as Map<String, dynamic>;
          final session = KeycastSession.fromJson(sessionMap);

          // Validate archive ownership. If the archive's userPubkey
          // is set and does NOT match the requested account, the
          // archive is corrupt (e.g., from pre-fix cross-contamination).
          // Delete it so Bug 1's recovery cascade can handle the
          // fallback via SessionExpiredException → login options.
          // Corrupt if userPubkey is null (legacy, unverifiable) or
          // mismatches the requested account (cross-contamination).
          final archivePubkey = session.userPubkey;
          final corrupt = archivePubkey == null || archivePubkey != pubkeyHex;
          if (corrupt) {
            Log.warning(
              'restoreActiveKeys: corrupt OAuth archive for '
              '${pubkeyForLogs(pubkeyHex)} — archive pubkey='
              '${pubkeyForLogs(archivePubkey, whenNull: "null (legacy)")}. '
              'Deleting corrupt archive.',
              name: 'SignerSecureStore',
              category: LogCategory.auth,
            );
            await storage.delete(key: _keycastSessionKey(pubkeyHex));
            ensureCurrent?.call();
          } else {
            await session.save(storage);
            ensureCurrent?.call();
            // Also restore the refresh token and auth handle to
            // their standalone keys — KeycastOAuth.refreshSession()
            // reads these separately from the session JSON, and
            // _oauthClient.logout() clears them. Without this,
            // expired restored sessions can never be refreshed.
            if (session.refreshToken != null) {
              await storage.write(
                key: _kKeycastRefreshTokenKey,
                value: session.refreshToken,
              );
              ensureCurrent?.call();
            }
            if (session.authorizationHandle != null) {
              await storage.write(
                key: _kKeycastAuthHandleKey,
                value: session.authorizationHandle,
              );
              ensureCurrent?.call();
            }
          }
        }

      case AuthenticationSource.automatic:
      case AuthenticationSource.importedKeys:
      case AuthenticationSource.none:
      case AuthenticationSource.nip07:
        // Clear any stale global signer keys so they don't hijack signing
        // operations for the non-bunker/non-keycast account.
        await clearBunker();
        ensureCurrent?.call();
        await clearAmber();
        ensureCurrent?.call();
        await KeycastSession.clear(storage);
        ensureCurrent?.call();
        Log.debug(
          'restoreActiveKeys: local key-based auth — cleared stale signer keys',
          name: 'SignerSecureStore',
          category: LogCategory.auth,
        );
    }
  }

  /// Deletes all per-account archived signer keys for a given pubkey.
  Future<void> clearArchive(String pubkeyHex) async {
    if (_storage == null) return;
    Log.info(
      'clearArchive: removing all archives for ${pubkeyForLogs(pubkeyHex)}',
      name: 'SignerSecureStore',
      category: LogCategory.auth,
    );
    try {
      await _storage.delete(key: '${_kAmberPubkeyKey}_$pubkeyHex');
      await _storage.delete(key: '${_kAmberPackageKey}_$pubkeyHex');
      await _storage.delete(key: '${_kBunkerInfoKey}_$pubkeyHex');
      await _storage.delete(key: _keycastSessionKey(pubkeyHex));
    } catch (e) {
      Log.warning(
        'clearArchive: failed for ${pubkeyForLogs(pubkeyHex)}: $e',
        name: 'SignerSecureStore',
        category: LogCategory.auth,
      );
    }
  }

  /// Removes only raw signer records with verified ownership and readback.
  /// Unknown or mismatched archives remain intact and make removal incomplete.
  Future<void> clearAccount(
    String pubkeyHex, {
    void Function()? ensureCurrent,
  }) => _clearVerifiedAccount(pubkeyHex, ensureCurrent: ensureCurrent);

  /// Whether a restorable per-account signer archive exists for [pubkeyHex]
  /// under [source]. For divineOAuth, also validates the archived session's
  /// bound pubkey matches.
  Future<bool> hasArchive(String pubkeyHex, AuthenticationSource source) async {
    final storage = _storage;
    if (storage == null) return false;
    try {
      switch (source) {
        case AuthenticationSource.amber:
          final pubkey = await storage.read(
            key: '${_kAmberPubkeyKey}_$pubkeyHex',
          );
          return pubkey != null && pubkey.isNotEmpty;
        case AuthenticationSource.bunker:
          final bunkerUrl = await storage.read(
            key: '${_kBunkerInfoKey}_$pubkeyHex',
          );
          return bunkerUrl != null && bunkerUrl.isNotEmpty;
        case AuthenticationSource.divineOAuth:
          final sessionJson = await storage.read(
            key: _keycastSessionKey(pubkeyHex),
          );
          if (sessionJson == null || sessionJson.isEmpty) return false;
          final sessionMap = jsonDecode(sessionJson) as Map<String, dynamic>;
          final session = KeycastSession.fromJson(sessionMap);
          return session.userPubkey == pubkeyHex;
        case AuthenticationSource.automatic:
        case AuthenticationSource.importedKeys:
        case AuthenticationSource.none:
        case AuthenticationSource.nip07:
          return false;
      }
    } catch (e) {
      Log.warning(
        'hasArchive: failed for ${pubkeyForLogs(pubkeyHex)}: $e',
        name: 'SignerSecureStore',
        category: LogCategory.auth,
      );
      return false;
    }
  }
}

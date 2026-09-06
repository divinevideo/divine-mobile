// ABOUTME: Shared harness for the #4741 AuthService characterization suite —
// ABOUTME: channel mocks, cleanup-service stubs, and discovery-error silencing.
//
// Every file in the characterization suite spins a real AuthService up against
// channel-backed storage and needs the same secure-storage / capability /
// native-signer channel mocks, the same UserDataCleanupService success stubs,
// and the same guard around the fire-and-forget _performDiscovery(). Centralising
// that plumbing here keeps the upcoming extraction PRs editing one place.
//
// Note: each test file still declares its own private mock class — the repo
// forbids sharing mock *classes* across files (see testing.md). Only the
// non-mock setup lives here.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show generatePrivateKey;
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';

import '../../test_setup.dart';

const _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);
const _capabilityChannel = MethodChannel('openvine.secure_storage');
const _androidPluginChannel = MethodChannel('nostrmoPlugin');

/// Installed platform-channel mocks for an AuthService characterization test.
///
/// Create with [install] in `setUp`, tear down with [remove] in `tearDown`.
/// The public fields are mutable so individual tests can seed storage or flip
/// the native-signer probe.
class AuthServiceChannelMocks {
  AuthServiceChannelMocks._();

  /// Backing store for the mocked flutter_secure_storage channel.
  final Map<String, String> secureStorage = {};

  /// Reported by the native `existAndroidNostrSigner` probe (NIP-55 Amber).
  bool androidSignerInstalled = true;

  /// Installs the secure-storage, capability, and native-signer channel mocks
  /// AuthService reaches during sign-in / restore.
  factory AuthServiceChannelMocks.install() {
    final mocks = AuthServiceChannelMocks._();
    _installSecureStorageHandlers(mocks.secureStorage);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_androidPluginChannel, (call) async {
          if (call.method == 'existAndroidNostrSigner') {
            return mocks.androidSignerInstalled;
          }
          return null;
        });
    return mocks;
  }

  /// Tears the test's handlers down. Call from `tearDown`.
  ///
  /// The secure-storage and capability channels are shared: `setupTestEnvironment()`
  /// installs them once at collection time and other suites rely on them without
  /// re-installing. Under CI's `--optimization` single-isolate run, nulling those
  /// channels here would strand a later suite (MissingPluginException). So we
  /// reinstall the *canonical* shared handlers via [restoreSharedChannelDefaults]
  /// — matching the identity the heal-and-blame tearDown expects (#5738) — and
  /// only remove the auth-only native-signer channel.
  static void remove() {
    restoreSharedChannelDefaults();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_androidPluginChannel, null);
  }

  static void _installSecureStorageHandlers(Map<String, String> store) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(_secureStorageChannel, (call) async {
        switch (call.method) {
          case 'read':
            return store[call.arguments['key'] as String?];
          case 'write':
            final key = call.arguments['key'] as String?;
            final value = call.arguments['value'] as String?;
            if (key != null && value != null) store[key] = value;
            return null;
          case 'delete':
            store.remove(call.arguments['key'] as String?);
            return null;
          case 'deleteAll':
            store.clear();
            return null;
          case 'readAll':
            return store;
          case 'containsKey':
            return store.containsKey(call.arguments['key'] as String?);
          case 'getCapabilities':
            return {'basicSecureStorage': true};
          default:
            return null;
        }
      })
      ..setMockMethodCallHandler(_capabilityChannel, (call) async {
        if (call.method == 'getCapabilities') {
          return {
            'hasHardwareSecurity': false,
            'hasBiometrics': false,
            'hasKeychain': true,
          };
        }
        return null;
      });
  }
}

/// Applies the default success stubs for a mocked [UserDataCleanupService] so
/// AuthService sign-in / sign-out paths run without a real cleanup backend.
void stubUserDataCleanupSuccess(UserDataCleanupService cleanupService) {
  when(() => cleanupService.shouldClearDataForUser(any())).thenReturn(false);
  when(
    () => cleanupService.clearUserSpecificData(
      reason: any(named: 'reason'),
      isIdentityChange: any(named: 'isIdentityChange'),
      userPubkey: any(named: 'userPubkey'),
      deleteUserData: any(named: 'deleteUserData'),
    ),
  ).thenAnswer((_) async => 0);
  when(() => cleanupService.claimLegacyRows(any())).thenAnswer((_) async {});
  when(
    () => cleanupService.markOwnerScopedLegacyDataForUser(any()),
  ).thenAnswer((_) async {});
}

/// Builds an [AuthService] wired to a real channel-backed [SecureKeyStorage]
/// (hardware backing disabled for tests) and the mocked secure storage.
AuthService buildTestAuthService({
  required UserDataCleanupService cleanupService,
  RemoteSignerFactory? remoteSignerFactory,
  AuthUrlLauncher? launchAuthUrl,
  KeycastOAuth? oauthClient,
  Future<void> Function(String pubkeyHex)? preFetchFollowing,
}) {
  return AuthService(
    backgroundActivityManager: BackgroundActivityManager(),
    userDataCleanupService: cleanupService,
    keyStorage: SecureKeyStorage(
      securityConfig: const SecurityConfig(requireHardwareBacked: false),
    ),
    flutterSecureStorage: const FlutterSecureStorage(),
    remoteSignerFactory: remoteSignerFactory,
    launchAuthUrl: launchAuthUrl,
    oauthClient: oauthClient,
    preFetchFollowing: preFetchFollowing,
  );
}

/// Runs [body], completing with its result, while guarding the fire-and-forget
/// `_performDiscovery()` that initialize()/sign-in kicks off — it opens real
/// relay WebSockets that fail fast under test and would otherwise surface as
/// unhandled async errors.
///
/// Errors from the awaited [body] itself still propagate. Only errors that
/// escape as unhandled are caught, and they are reported via [printOnFailure]
/// so a genuine async bug shows up in a failing test rather than vanishing.
Future<T> ignoringDiscoveryErrors<T>(Future<T> Function() body) async {
  final completer = Completer<T>();
  runZonedGuarded(
    () async {
      try {
        completer.complete(await body());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    },
    (error, stack) {
      printOnFailure(
        'Ignored unhandled async error (discovery): $error\n$stack',
      );
    },
  );
  return completer.future;
}

/// A fresh random public key hex, for identity assertions.
String freshPubkeyHex() =>
    SecureKeyContainer.fromPrivateKeyHex(generatePrivateKey()).publicKeyHex;

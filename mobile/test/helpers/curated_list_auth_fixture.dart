// ABOUTME: Real generated-account and signed-default evidence for list tests.
// ABOUTME: Storage mocks supply actual generated keys, never fabricated permits.

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/relay_discovery_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _KeyStorage extends Mock implements SecureKeyStorage {}

class _Discovery extends Mock implements RelayDiscoveryService {}

class CuratedListFreshAccountFixture {
  CuratedListFreshAccountFixture(this.auth, this.keys);
  final AuthService auth;
  final SecureKeyContainer keys;
  String get owner => keys.publicKeyHex;
}

/// Traverses actual key-generation origin and terminal account settlement.
/// Native storage is mocked; key generation, signing, receipts and permits are real.
Future<CuratedListFreshAccountFixture> createFreshCuratedListAccount({
  required SharedPreferences preferences,
  required NostrClient client,
}) async {
  final keys = await SecureKeyContainer.generate();
  registerFallbackValue(keys);
  final storage = _KeyStorage();
  when(storage.initialize).thenAnswer((_) async {});
  when(storage.hasKeys).thenAnswer((_) async => true);
  when(storage.clearCache).thenReturn(null);
  when(storage.dispose).thenReturn(null);
  when(
    () => storage.generateAndStoreKeys(
      primaryWriteGuard: any(named: 'primaryWriteGuard'),
    ),
  ).thenAnswer((invocation) async {
    final guard =
        invocation.namedArguments[#primaryWriteGuard]
            as PrimaryKeyPersistenceGuard;
    await guard(keys.publicKeyHex, () async {});
    return keys;
  });
  when(storage.getKeyContainer).thenAnswer((_) async => keys);
  when(() => storage.getIdentityKeyContainer(any()))
      .thenAnswer((_) async => keys);
  when(() => storage.storeIdentityKeyContainer(any(), any()))
      .thenAnswer((_) async {});
  when(() => storage.switchToIdentity(any())).thenAnswer((_) async => true);
  final discovery = _Discovery();
  when(() => discovery.discoverRelays(any())).thenAnswer(
    (_) async => RelayDiscoveryResult.failure('No network in test'),
  );
  final cleanup = UserDataCleanupService(preferences);
  cleanup.onDatabaseCleanup = ({
    String? userPubkey,
    bool deleteUserData = false,
    bool preserveActiveSession = false,
  }) async {};
  final auth = AuthService(
    userDataCleanupService: cleanup,
    backgroundActivityManager: BackgroundActivityManager(),
    keyStorage: storage,
    relayDiscoveryService: discovery,
    profileCheckIndexerUrl: 'unsupported://profile.invalid',
  );
  expect((await auth.createNewIdentity()).success, isTrue);
  expect(auth.committedAccountActivationReceipt?.isCurrent, isTrue);
  verify(
    () => storage.generateAndStoreKeys(
      primaryWriteGuard: any(named: 'primaryWriteGuard'),
    ),
  ).called(1);
  when(() => client.signer)
      .thenReturn(keys.withPrivateKey(LocalNostrSigner.new));
  addTearDown(auth.dispose);
  return CuratedListFreshAccountFixture(auth, keys);
}

/// Uses an existing synthetic owner's actual signed complete private revision.
/// This grants no key-generation origin or fresh-account creation permit.
Future<Event> stubReadableCuratedDefault({
  required AuthService auth,
  required NostrClient client,
  List<String> items = const [],
  int? createdAt,
}) async {
  final signer = LocalNostrSigner('1'.padLeft(64, '0'));
  final owner = await signer.getPublicKey();
  if (owner == null) throw StateError('Synthetic fixture signer has no owner');
  expect(auth.isAuthenticated, isTrue);
  expect(auth.currentPublicKeyHex, owner);
  when(() => client.signer).thenReturn(signer);
  when(
    () => auth.createAndSignEvent(
      kind: any(named: 'kind'),
      content: any(named: 'content'),
      tags: any(named: 'tags'),
      createdAt: any(named: 'createdAt'),
    ),
  ).thenAnswer((invocation) async {
    final event = Event(
      owner,
      invocation.namedArguments[#kind] as int,
      invocation.namedArguments[#tags] as List<List<String>>,
      invocation.namedArguments[#content] as String,
      createdAt: invocation.namedArguments[#createdAt] as int?,
    );
    await signer.signEvent(event);
    return event;
  });
  final content = await signer.nip44Encrypt(
    owner,
    jsonEncode([
      for (final id in items) ['e', id],
    ]),
  );
  final event = Event(
    owner,
    30005,
    [
      ['d', CuratedListService.defaultListId],
      ['title', 'My List'],
    ],
    content!,
    createdAt:
        createdAt ??
        clock
                .now()
                .subtract(const Duration(seconds: 4))
                .millisecondsSinceEpoch ~/
            1000,
  );
  await signer.signEvent(event);
  expect(event.isValid && event.isSigned, isTrue);
  return event;
}

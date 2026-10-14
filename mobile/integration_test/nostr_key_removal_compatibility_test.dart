// ABOUTME: Native iOS Keychain proof for account-owned login record removal.
// ABOUTME: Covers both accessibility histories without touching app login keys.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('iOS owned login record removal', () {
    for (final accessibility in [
      KeychainAccessibility.first_unlock,
      KeychainAccessibility.first_unlock_this_device,
    ]) {
      final history = accessibility == KeychainAccessibility.first_unlock
          ? 'current'
          : 'legacy';
      for (final foreignPrimary in [false, true]) {
        final primary = foreignPrimary ? 'foreign' : 'owned';
        testWidgets('removes $history records with $primary primary', (
          _,
        ) async {
          expect(
            Platform.isIOS,
            isTrue,
            reason: 'Requires native iOS Keychain',
          );
          await _verifyOwnedRemoval(
            accessibility: accessibility,
            foreignPrimary: foreignPrimary,
          );
        });
      }
    }
  });
}

Future<void> _verifyOwnedRemoval({
  required KeychainAccessibility accessibility,
  required bool foreignPrimary,
}) async {
  // The service and IDs belong only to this invocation. Never use the app's
  // shared PRIMARY/identity slots or deleteAll to prepare or clean this test.
  final service =
      'divine.owned-removal.integration.${DateTime.now().microsecondsSinceEpoch}';
  final current = FlutterSecureStorage(
    iOptions: IOSOptions(
      accountName: service,
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );
  final legacy = FlutterSecureStorage(
    iOptions: IOSOptions(
      accountName: service,
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  const primaryId = 'test-primary';
  const identityId = 'test-identity';
  addTearDown(() async {
    for (final storage in [current, legacy]) {
      for (final keyId in [primaryId, identityId]) {
        await storage.delete(key: keyId);
      }
    }
  });

  final alice = SecureKeyContainer.fromPrivateKeyHex(
    '0000000000000000000000000000000000000000000000000000000000000001',
  );
  final bob = SecureKeyContainer.fromPrivateKeyHex(
    '0000000000000000000000000000000000000000000000000000000000000002',
  );
  addTearDown(alice.dispose);
  addTearDown(bob.dispose);
  final ownedRecord = _record(alice);
  final primaryRecord = foreignPrimary ? _record(bob) : ownedRecord;
  final seeded = accessibility == KeychainAccessibility.first_unlock
      ? current
      : legacy;
  await seeded.write(key: primaryId, value: primaryRecord);
  await seeded.write(key: identityId, value: ownedRecord);

  // iOS reads the same native record through both accessibility options;
  // deletion still filters by the requested accessibility. Boolean assertions
  // retain that contract without printing synthetic private-key bytes on error.
  for (final storage in [current, legacy]) {
    expect(await storage.read(key: primaryId) == primaryRecord, isTrue);
    expect(await storage.read(key: identityId) == ownedRecord, isTrue);
  }

  final platformStorage = PlatformSecureStorage.forPlatform(
    TargetPlatform.iOS,
    fallbackStorage: current,
    legacyStorage: legacy,
  );
  await platformStorage.deleteOwnedLoginRecordsStrict(
    primaryKeyId: primaryId,
    identityKeyId: identityId,
    ownerPubkey: alice.publicKeyHex,
  );

  for (final storage in [current, legacy]) {
    expect(
      await storage.read(key: identityId) == null,
      isTrue,
      reason: 'The selected identity must be absent through both readers',
    );
    final remainingPrimary = await storage.read(key: primaryId);
    expect(
      foreignPrimary
          ? remainingPrimary == primaryRecord
          : remainingPrimary == null,
      isTrue,
      reason: foreignPrimary
          ? 'Another account’s primary record must remain byte-for-byte intact'
          : 'The selected primary must be absent through both readers',
    );
  }
}

String _record(SecureKeyContainer container) => container.withPrivateKey(
  (privateKeyHex) =>
      'privateKeyHex:$privateKeyHex|'
      'publicKeyHex:${container.publicKeyHex}|npub:${container.npub}',
);

// ABOUTME: Verifies owner-proven login removal in current and legacy storage.
// ABOUTME: Preserves foreign records and refuses uncertain deletion evidence.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const fallbackChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  const nativeChannel = MethodChannel('openvine.secure_storage');
  const primary = 'nostr_primary_key';
  const current = 'first_unlock';
  const legacy = 'first_unlock_this_device';
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late SecureKeyContainer alice;
  late SecureKeyContainer bob;
  late String aliceSaved;
  late Map<String, String> fallbackRecords;
  late Map<String, Map<String, Object?>> nativeRecords;
  late List<String> deletes;
  late Map<String, int> readCounts;
  late SecureKeyStorage storage;
  String? failingRead;
  String? failingDelete;
  String? silentlyRetained;
  String? mutateBeforeDelete;
  Completer<void>? heldRead;
  Completer<void>? readStarted;
  var retired = false;
  var useNative = false;
  var nativeDeletionRefused = false;
  var nativeRetrievalRefused = false;
  var missingNativeInitialization = false;
  var missingNativeCapabilities = false;
  var failingNativeCapabilities = false;
  var nullNativeCapabilities = false;
  var missingNativeReadMethods = false;
  String? implementedNativeReadMethod;
  String? implementedNativeReadKey;
  var failImplementedNativeRead = false;

  String fallbackId(String slot, String key) => '$slot::$key';

  String rawRecord(SecureKeyContainer keys) => keys.withPrivateKey(
    (privateKey) =>
        'privateKeyHex:$privateKey|'
        'publicKeyHex:${keys.publicKeyHex}|'
        'npub:${keys.npub}',
  );

  Map<String, Object?> nativeRecord(SecureKeyContainer keys) =>
      keys.withPrivateKey(
        (privateKey) => {
          'success': true,
          'privateKeyHex': privateKey,
          'publicKeyHex': keys.publicKeyHex,
          'npub': keys.npub,
        },
      );

  void ensureCurrent() {
    if (retired) throw StateError('fixture retired account operation');
  }

  setUp(() {
    alice = SecureKeyContainer.fromPrivateKeyHex(
      '0000000000000000000000000000000000000000000000000000000000000001',
    );
    bob = SecureKeyContainer.fromPrivateKeyHex(
      '0000000000000000000000000000000000000000000000000000000000000002',
    );
    aliceSaved = 'saved_identity_${alice.npub}';
    fallbackRecords = {};
    nativeRecords = {};
    deletes = [];
    readCounts = {};
    failingRead = null;
    failingDelete = null;
    silentlyRetained = null;
    mutateBeforeDelete = null;
    heldRead = null;
    readStarted = null;
    retired = false;
    useNative = false;
    nativeDeletionRefused = false;
    nativeRetrievalRefused = false;
    missingNativeInitialization = false;
    missingNativeCapabilities = false;
    failingNativeCapabilities = false;
    nullNativeCapabilities = false;
    missingNativeReadMethods = false;
    implementedNativeReadMethod = null;
    implementedNativeReadKey = null;
    failImplementedNativeRead = false;

    messenger
      ..setMockMethodCallHandler(fallbackChannel, (call) async {
        final args = call.arguments as Map<dynamic, dynamic>;
        final options = args['options'] as Map<dynamic, dynamic>;
        final slot =
            options['accessibility'] ??
            options['fixtureStorageSlot'] ??
            options['preferencesKeyPrefix'];
        expect(slot, anyOf(current, legacy));
        final id = fallbackId(slot as String, args['key'] as String);
        switch (call.method) {
          case 'read':
            readCounts[id] = (readCounts[id] ?? 0) + 1;
            if (readStarted != null && !readStarted!.isCompleted) {
              readStarted!.complete();
              await heldRead!.future;
            }
            if (failingRead == id) {
              throw PlatformException(code: 'fixture_read_unavailable');
            }
            if (mutateBeforeDelete == id && readCounts[id] == 3) {
              fallbackRecords[id] = rawRecord(bob);
            }
            return fallbackRecords[id];
          case 'delete':
            deletes.add(id);
            if (failingDelete == id) {
              throw PlatformException(code: 'fixture_delete_refused');
            }
            if (silentlyRetained != id) fallbackRecords.remove(id);
            return null;
          default:
            fail('Owner removal must not write or migrate key records');
        }
      })
      ..setMockMethodCallHandler(nativeChannel, (call) async {
        if (missingNativeCapabilities &&
            missingNativeInitialization &&
            missingNativeReadMethods &&
            implementedNativeReadMethod == null) {
          throw MissingPluginException();
        }
        final args = call.arguments as Map<dynamic, dynamic>? ?? {};
        final key = args['keyId'] as String?;
        switch (call.method) {
          case 'getCapabilities':
            if (missingNativeCapabilities) throw MissingPluginException();
            if (failingNativeCapabilities) {
              throw PlatformException(
                code: 'fixture_native_capabilities_unavailable',
              );
            }
            if (nullNativeCapabilities) return null;
            return {
              'platform': 'Android',
              'capabilities': ['basic_secure_storage'],
            };
          case 'initializeAndroid':
            if (missingNativeInitialization) throw MissingPluginException();
            return true;
          case 'hasKey':
            if (missingNativeReadMethods &&
                (implementedNativeReadMethod != call.method ||
                    implementedNativeReadKey != key)) {
              throw MissingPluginException();
            }
            if (failImplementedNativeRead) {
              throw PlatformException(code: 'fixture_native_read_unavailable');
            }
            return nativeRecords.containsKey(key);
          case 'retrieveKey':
            if (missingNativeReadMethods &&
                (implementedNativeReadMethod != call.method ||
                    implementedNativeReadKey != key)) {
              throw MissingPluginException();
            }
            if (failImplementedNativeRead) {
              throw PlatformException(code: 'fixture_native_read_unavailable');
            }
            if (nativeRetrievalRefused) return {'success': false};
            return nativeRecords[key];
          case 'deleteKey':
            deletes.add(key!);
            if (nativeDeletionRefused) return {'success': false};
            if (silentlyRetained != key) nativeRecords.remove(key);
            return {'success': true};
          default:
            fail('Owner removal must not write native key records');
        }
      });
    storage = SecureKeyStorage(
      securityConfig: SecurityConfig.desktop,
      platformStorage: PlatformSecureStorage.forPlatform(
        TargetPlatform.iOS,
        fallbackStorage: _storageForSlot(current),
        legacyStorage: _storageForSlot(legacy),
      ),
    );
  });

  tearDown(() {
    if (heldRead case final gate? when !gate.isCompleted) gate.complete();
    storage.dispose();
    alice.dispose();
    bob.dispose();
    messenger
      ..setMockMethodCallHandler(fallbackChannel, null)
      ..setMockMethodCallHandler(nativeChannel, null);
  });

  Future<void> removeAlice() async {
    if (useNative) {
      storage.dispose();
      storage = SecureKeyStorage(
        securityConfig: SecurityConfig.desktop,
        platformStorage: PlatformSecureStorage.forPlatform(
          TargetPlatform.android,
          fallbackStorage: _storageForSlot(current),
          legacyStorage: _storageForSlot(legacy),
        ),
      );
    }
    await storage.deleteOwnedLoginStrict(
      alice.publicKeyHex,
      ensureCurrent: ensureCurrent,
    );
  }

  group('Fallback owner-proven removal', () {
    test(
      'removes all four verified copies and proves they stayed absent',
      () async {
        for (final slot in [current, legacy]) {
          for (final key in [primary, aliceSaved]) {
            fallbackRecords[fallbackId(slot, key)] = rawRecord(alice);
          }
        }
        await removeAlice();
        expect(fallbackRecords, isEmpty);
        expect(
          deletes,
          unorderedEquals([
            fallbackId(current, primary),
            fallbackId(legacy, primary),
            fallbackId(current, aliceSaved),
            fallbackId(legacy, aliceSaved),
          ]),
        );
      },
    );

    test('foreign current PRIMARY cannot hide an owned legacy copy', () async {
      final foreign = rawRecord(bob);
      fallbackRecords[fallbackId(current, primary)] = foreign;
      fallbackRecords[fallbackId(legacy, primary)] = rawRecord(alice);
      fallbackRecords[fallbackId(current, aliceSaved)] = rawRecord(alice);
      await removeAlice();
      expect(fallbackRecords.keys, [fallbackId(current, primary)]);
      expect(fallbackRecords[fallbackId(current, primary)] == foreign, isTrue);
      expect(deletes, isNot(contains(fallbackId(current, primary))));
    });

    test('foreign legacy PRIMARY survives owned current removal', () async {
      final foreign = rawRecord(bob);
      fallbackRecords[fallbackId(current, primary)] = rawRecord(alice);
      fallbackRecords[fallbackId(legacy, primary)] = foreign;
      await removeAlice();
      expect(fallbackRecords.keys, [fallbackId(legacy, primary)]);
      expect(fallbackRecords[fallbackId(legacy, primary)] == foreign, isTrue);
      expect(deletes, [fallbackId(current, primary)]);
    });

    test('proven absence requires no destructive operation', () async {
      await removeAlice();
      expect(fallbackRecords, isEmpty);
      expect(deletes, isEmpty);
    });

    test(
      'removes the matching live cache only after proven native removal',
      () async {
        fallbackRecords[fallbackId(current, primary)] = rawRecord(alice);
        final cached = await storage.getKeyContainer();
        expect(cached!.publicKeyHex, alice.publicKeyHex);
        await removeAlice();
        expect(cached.isDisposed, isTrue);
        expect(fallbackRecords, isEmpty);
      },
    );

    test(
      'a disposed matching cache cannot invalidate successful removal',
      () async {
        fallbackRecords[fallbackId(current, primary)] = rawRecord(alice);
        final cached = await storage.getKeyContainer();
        cached!.dispose();
        await removeAlice();
        expect(fallbackRecords, isEmpty);
      },
    );

    test(
      'an unverified removal leaves the matching live cache usable',
      () async {
        final id = fallbackId(current, primary);
        fallbackRecords[id] = rawRecord(alice);
        final cached = await storage.getKeyContainer();
        expect(cached!.publicKeyHex, alice.publicKeyHex);
        silentlyRetained = id;
        await expectLater(
          removeAlice(),
          throwsA(
            isA<PlatformSecureStorageException>().having(
              (error) => error.code,
              'code',
              'key_deletion_unverified',
            ),
          ),
        );
        expect(cached.isDisposed, isFalse);
        expect(await storage.getKeyContainer(), same(cached));
      },
    );

    test(
      'foreign native bytes and the foreign live cache remain intact',
      () async {
        fallbackRecords[fallbackId(current, primary)] = rawRecord(bob);
        fallbackRecords[fallbackId(legacy, primary)] = rawRecord(alice);
        final cached = await storage.getKeyContainer();
        expect(cached!.publicKeyHex, bob.publicKeyHex);
        await removeAlice();
        expect(cached.isDisposed, isFalse);
        expect(await storage.getKeyContainer(), same(cached));
        expect(deletes, [fallbackId(legacy, primary)]);
      },
    );

    for (final slot in [current, legacy]) {
      test('$slot unreadable PRIMARY refuses all deletions', () async {
        fallbackRecords[fallbackId(current, aliceSaved)] = rawRecord(alice);
        fallbackRecords[fallbackId(slot, primary)] = 'unreadable-record';
        final before = Map<String, String>.of(fallbackRecords);
        await expectLater(
          removeAlice(),
          throwsA(isA<PlatformSecureStorageException>()),
        );
        expect(mapEquals(fallbackRecords, before), isTrue);
        expect(deletes, isEmpty);
      });

      test('$slot unavailable saved record refuses all deletions', () async {
        fallbackRecords[fallbackId(current, primary)] = rawRecord(alice);
        failingRead = fallbackId(slot, aliceSaved);
        final before = Map<String, String>.of(fallbackRecords);
        await expectLater(removeAlice(), throwsA(isA<PlatformException>()));
        expect(mapEquals(fallbackRecords, before), isTrue);
        expect(deletes, isEmpty);
      });
    }

    test('contradictory public metadata never authorizes deletion', () async {
      fallbackRecords[fallbackId(current, primary)] = rawRecord(alice)
          .replaceFirst(
            'publicKeyHex:${alice.publicKeyHex}',
            'publicKeyHex:${bob.publicKeyHex}',
          );
      final before = Map<String, String>.of(fallbackRecords);
      await expectLater(
        removeAlice(),
        throwsA(isA<PlatformSecureStorageException>()),
      );
      expect(mapEquals(fallbackRecords, before), isTrue);
      expect(deletes, isEmpty);
    });

    test('contradictory npub metadata never authorizes deletion', () async {
      fallbackRecords[fallbackId(current, primary)] = rawRecord(alice)
          .replaceFirst(
            'npub:${alice.npub}',
            'npub:${bob.npub}',
          );
      final before = Map<String, String>.of(fallbackRecords);
      await expectLater(
        removeAlice(),
        throwsA(isA<PlatformSecureStorageException>()),
      );
      expect(mapEquals(fallbackRecords, before), isTrue);
      expect(deletes, isEmpty);
    });

    test(
      'a saved identity with a foreign key refuses every deletion',
      () async {
        fallbackRecords[fallbackId(current, primary)] = rawRecord(alice);
        fallbackRecords[fallbackId(legacy, aliceSaved)] = rawRecord(bob);
        final before = Map<String, String>.of(fallbackRecords);
        await expectLater(
          removeAlice(),
          throwsA(isA<PlatformSecureStorageException>()),
        );
        expect(mapEquals(fallbackRecords, before), isTrue);
        expect(deletes, isEmpty);
      },
    );

    test('a record replaced before deletion is preserved', () async {
      final id = fallbackId(current, primary);
      fallbackRecords[id] = rawRecord(alice);
      mutateBeforeDelete = id;
      await expectLater(
        removeAlice(),
        throwsA(isA<PlatformSecureStorageException>()),
      );
      expect(fallbackRecords[id] == rawRecord(bob), isTrue);
      expect(deletes, isEmpty);
    });

    for (final slot in [current, legacy]) {
      test('$slot silent deletion failure remains incomplete', () async {
        final id = fallbackId(slot, primary);
        final raw = rawRecord(alice);
        fallbackRecords[id] = raw;
        silentlyRetained = id;
        await expectLater(
          removeAlice(),
          throwsA(
            isA<PlatformSecureStorageException>().having(
              (error) => error.code,
              'code',
              'key_deletion_unverified',
            ),
          ),
        );
        expect(fallbackRecords[id] == raw, isTrue);
      });
    }

    test('a native deletion exception preserves the owned record', () async {
      final id = fallbackId(current, primary);
      final raw = rawRecord(alice);
      fallbackRecords[id] = raw;
      failingDelete = id;
      await expectLater(removeAlice(), throwsA(isA<PlatformException>()));
      expect(fallbackRecords[id] == raw, isTrue);
    });

    test(
      'retirement during an awaited read rejects before any deletion',
      () async {
        fallbackRecords[fallbackId(current, primary)] = rawRecord(alice);
        final before = Map<String, String>.of(fallbackRecords);
        heldRead = Completer<void>();
        readStarted = Completer<void>();
        final operation = removeAlice();
        final observed = expectLater(operation, throwsA(isA<StateError>()));
        await readStarted!.future;
        retired = true;
        heldRead!.complete();
        await observed;
        expect(mapEquals(fallbackRecords, before), isTrue);
        expect(deletes, isEmpty);
      },
    );

    test(
      'an invalid or truncated owner refuses before any storage IO',
      () async {
        await expectLater(
          storage.deleteOwnedLoginStrict('invalid-owner'),
          throwsA(isA<SecureKeyStorageException>()),
        );
        expect(readCounts, isEmpty);
        expect(deletes, isEmpty);
      },
    );
  });

  group('Native owner-proven removal', () {
    setUp(() {
      useNative = true;
    });

    test(
      'removes matching native records using actual key derivation',
      () async {
        nativeRecords[primary] = nativeRecord(alice);
        nativeRecords[aliceSaved] = nativeRecord(alice);
        await removeAlice();
        expect(nativeRecords, isEmpty);
        expect(deletes, [primary, aliceSaved]);
      },
    );

    test(
      'preserves a foreign native PRIMARY while removing an owned archive',
      () async {
        final foreign = nativeRecord(bob);
        nativeRecords[primary] = foreign;
        nativeRecords[aliceSaved] = nativeRecord(alice);
        await removeAlice();
        expect(nativeRecords.keys, [primary]);
        expect(mapEquals(nativeRecords[primary], foreign), isTrue);
        expect(deletes, [aliceSaved]);
      },
    );

    test('an unreadable native record refuses every deletion', () async {
      nativeRecords[primary] = nativeRecord(alice);
      nativeRetrievalRefused = true;
      await expectLater(
        removeAlice(),
        throwsA(isA<PlatformSecureStorageException>()),
      );
      expect(nativeRecords.keys, [primary]);
      expect(deletes, isEmpty);
    });

    test('contradictory native metadata refuses every deletion', () async {
      nativeRecords[primary] = nativeRecord(alice)..['npub'] = bob.npub;
      await expectLater(
        removeAlice(),
        throwsA(isA<PlatformSecureStorageException>()),
      );
      expect(nativeRecords.keys, [primary]);
      expect(deletes, isEmpty);
    });

    test('an explicit refused native deletion remains incomplete', () async {
      nativeRecords[primary] = nativeRecord(alice);
      nativeDeletionRefused = true;
      await expectLater(
        removeAlice(),
        throwsA(isA<PlatformSecureStorageException>()),
      );
      expect(nativeRecords.keys, [primary]);
      expect(deletes, [primary]);
    });

    test('native success without actual removal remains incomplete', () async {
      nativeRecords[primary] = nativeRecord(alice);
      silentlyRetained = primary;
      await expectLater(
        removeAlice(),
        throwsA(isA<PlatformSecureStorageException>()),
      );
      expect(nativeRecords.keys, [primary]);
      expect(deletes, [primary]);
    });
  });

  group('Aliased current and legacy fallback namespaces', () {
    for (final platform in [TargetPlatform.android, TargetPlatform.linux]) {
      test(
        '$platform owned records are removed once and prove absence',
        () async {
          missingNativeCapabilities = true;
          missingNativeInitialization = true;
          missingNativeReadMethods = true;
          storage.dispose();
          storage = SecureKeyStorage(
            securityConfig: SecurityConfig.desktop,
            platformStorage: PlatformSecureStorage.forPlatform(platform),
          );
          final physicalRecords = {
            primary: rawRecord(alice),
            aliceSaved: rawRecord(alice),
          };
          messenger.setMockMethodCallHandler(fallbackChannel, (call) async {
            final args = call.arguments as Map<dynamic, dynamic>;
            final key = args['key'] as String;
            switch (call.method) {
              case 'read':
                return physicalRecords[key];
              case 'delete':
                deletes.add(key);
                physicalRecords.remove(key);
                return null;
              default:
                fail('Aliased cleanup must not write key records');
            }
          });
          await removeAlice();
          expect(physicalRecords, isEmpty);
          expect(deletes, [primary, aliceSaved]);
        },
      );

      test(
        '$platform foreign PRIMARY survives owned archived removal',
        () async {
          missingNativeCapabilities = true;
          missingNativeInitialization = true;
          missingNativeReadMethods = true;
          storage.dispose();
          storage = SecureKeyStorage(
            securityConfig: SecurityConfig.desktop,
            platformStorage: PlatformSecureStorage.forPlatform(platform),
          );
          final foreign = rawRecord(bob);
          final physicalRecords = {
            primary: foreign,
            aliceSaved: rawRecord(alice),
          };
          messenger.setMockMethodCallHandler(fallbackChannel, (call) async {
            final args = call.arguments as Map<dynamic, dynamic>;
            final key = args['key'] as String;
            switch (call.method) {
              case 'read':
                return physicalRecords[key];
              case 'delete':
                deletes.add(key);
                physicalRecords.remove(key);
                return null;
              default:
                fail('Aliased cleanup must not write key records');
            }
          });
          await removeAlice();
          expect(physicalRecords.keys, [primary]);
          expect(physicalRecords[primary] == foreign, isTrue);
          expect(deletes, [aliceSaved]);
        },
      );
    }
  });

  group('Simultaneously selected fallback and native backends', () {
    setUp(() {
      missingNativeCapabilities = true;
      useNative = true;
    });

    test('removes verified copies from both physical backends', () async {
      fallbackRecords[fallbackId(current, primary)] = rawRecord(alice);
      fallbackRecords[fallbackId(legacy, aliceSaved)] = rawRecord(alice);
      nativeRecords[primary] = nativeRecord(alice);
      nativeRecords[aliceSaved] = nativeRecord(alice);
      await removeAlice();
      expect(fallbackRecords, isEmpty);
      expect(nativeRecords, isEmpty);
      expect(
        deletes,
        unorderedEquals([
          fallbackId(current, primary),
          fallbackId(legacy, aliceSaved),
          primary,
          aliceSaved,
        ]),
      );
    });

    test('native absence cannot hide an owned fallback copy', () async {
      fallbackRecords[fallbackId(current, primary)] = rawRecord(alice);
      await removeAlice();
      expect(fallbackRecords, isEmpty);
      expect(nativeRecords, isEmpty);
      expect(deletes, [fallbackId(current, primary)]);
    });
  });

  group('Installed native backend with a missing setup method', () {
    setUp(() {
      useNative = true;
      missingNativeInitialization = true;
    });

    for (final evidence in ['success', 'null', 'failure']) {
      test(
        '$evidence capability evidence refuses terminal owner removal',
        () async {
          nullNativeCapabilities = evidence == 'null';
          failingNativeCapabilities = evidence == 'failure';
          fallbackRecords[fallbackId(current, primary)] = rawRecord(alice);
          nativeRecords[primary] = nativeRecord(alice);
          final fallbackBefore = Map<String, String>.of(fallbackRecords);
          final nativeBefore = Map<String, Object?>.of(nativeRecords[primary]!);
          var completed = false;
          await expectLater(
            removeAlice().then((_) => completed = true),
            throwsA(isA<MissingPluginException>()),
          );
          expect(completed, isFalse);
          expect(mapEquals(fallbackRecords, fallbackBefore), isTrue);
          expect(mapEquals(nativeRecords[primary], nativeBefore), isTrue);
          expect(readCounts, isEmpty);
          expect(deletes, isEmpty);
        },
      );
    }

    test(
      'a whole missing channel permits proven fallback owner removal',
      () async {
        missingNativeCapabilities = true;
        missingNativeReadMethods = true;
        fallbackRecords[fallbackId(current, primary)] = rawRecord(alice);
        await removeAlice();
        expect(fallbackRecords, isEmpty);
        expect(nativeRecords, isEmpty);
        expect(deletes, [fallbackId(current, primary)]);
      },
    );

    for (final coordinate in ['primary', 'saved']) {
      for (final method in ['hasKey', 'retrieveKey']) {
        test(
          '$coordinate $method rejects cleanup with both setup methods absent',
          () async {
            missingNativeCapabilities = true;
            missingNativeReadMethods = true;
            implementedNativeReadMethod = method;
            final key = coordinate == 'primary' ? primary : aliceSaved;
            implementedNativeReadKey = key;
            fallbackRecords[fallbackId(current, primary)] = rawRecord(alice);
            nativeRecords[key] = nativeRecord(alice);
            final fallbackBefore = Map<String, String>.of(fallbackRecords);
            final nativeBefore = Map<String, Object?>.of(nativeRecords[key]!);
            var completed = false;
            await expectLater(
              removeAlice().then((_) => completed = true),
              throwsA(
                isA<PlatformSecureStorageException>().having(
                  (error) => error.code,
                  'code',
                  'native_initialization_unverified',
                ),
              ),
            );
            expect(completed, isFalse);
            expect(mapEquals(fallbackRecords, fallbackBefore), isTrue);
            expect(mapEquals(nativeRecords[key], nativeBefore), isTrue);
            expect(readCounts, isEmpty);
            expect(deletes, isEmpty);
          },
        );
      }
    }

    for (final method in ['hasKey', 'retrieveKey']) {
      test('$method native error rejects cleanup with absent setup', () async {
        missingNativeCapabilities = true;
        missingNativeReadMethods = true;
        implementedNativeReadMethod = method;
        implementedNativeReadKey = primary;
        failImplementedNativeRead = true;
        nativeRecords[primary] = nativeRecord(alice);
        final before = Map<String, Object?>.of(nativeRecords[primary]!);
        await expectLater(removeAlice(), throwsA(isA<PlatformException>()));
        expect(mapEquals(nativeRecords[primary], before), isTrue);
        expect(deletes, isEmpty);
      });
    }
  });
}

FlutterSecureStorage _storageForSlot(String slot) {
  final accessibility = slot == 'first_unlock'
      ? KeychainAccessibility.first_unlock
      : KeychainAccessibility.first_unlock_this_device;
  return FlutterSecureStorage(
    aOptions: AndroidOptions(preferencesKeyPrefix: slot),
    iOptions: IOSOptions(accessibility: accessibility),
    mOptions: MacOsOptions(accessibility: accessibility),
    lOptions: _SlotLinuxOptions(slot),
    wOptions: _SlotWindowsOptions(slot),
  );
}

// These options separate the MethodChannel test ports on non-Apple hosts.
// Production constructors retain the existing platform options unchanged.
class _SlotLinuxOptions extends LinuxOptions {
  const _SlotLinuxOptions(this.slot);

  final String slot;

  @override
  Map<String, String> toMap() => {'fixtureStorageSlot': slot};
}

class _SlotWindowsOptions extends WindowsOptions {
  const _SlotWindowsOptions(this.slot);

  final String slot;

  @override
  Map<String, String> toMap() => {'fixtureStorageSlot': slot};
}

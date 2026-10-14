// ABOUTME: Tests generated PRIMARY writes through real platform storage.
// ABOUTME: Retired guards cannot write or dispose keys before IO drains.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';

import '../test_setup.dart';

void main() {
  group('Generated PRIMARY persistence guard', () {
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    const primary = 'nostr_primary_key';
    late SecureKeyStorage storage;
    late Map<String, String> native;
    late Completer<void> writeStarted;
    Completer<void>? writeGate;
    var primaryWrites = 0;
    var refuseWrite = false;

    setUp(() async {
      setupTestEnvironment();
      native = {};
      writeStarted = Completer<void>();
      writeGate = null;
      primaryWrites = 0;
      refuseWrite = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            final args = call.arguments as Map<dynamic, dynamic>? ?? {};
            final key = args['key'] as String?;
            switch (call.method) {
              case 'write':
                if (key == primary) {
                  primaryWrites++;
                  if (!writeStarted.isCompleted) writeStarted.complete();
                  await writeGate?.future;
                  if (refuseWrite) {
                    throw PlatformException(code: 'fixture_write_refused');
                  }
                }
                if (key != null) native[key] = args['value'] as String;
                return null;
              case 'read':
                return native[key];
              case 'containsKey':
                return native.containsKey(key);
              case 'readAll':
                return Map<String, String>.of(native);
              case 'delete':
                native.remove(key);
                return null;
              case 'deleteAll':
                native.clear();
                return null;
              default:
                return null;
            }
          });
      storage = SecureKeyStorage(securityConfig: SecurityConfig.desktop);
      await storage.initialize();
    });

    tearDown(() {
      if (writeGate case final gate? when !gate.isCompleted) gate.complete();
      storage.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test(
      'the ordinary path persists one genuine key without a guard',
      () async {
        final keys = await storage.generateAndStoreKeys();
        expect(primaryWrites, 1);
        expect(native[primary], contains('publicKeyHex:${keys.publicKeyHex}'));
        expect(keys.isDisposed, isFalse);
        expect(await storage.getKeyContainer(), same(keys));
      },
    );

    test('a healthy guard awaits the complete platform write', () async {
      writeGate = Completer<void>();
      String? owner;
      var settled = false;
      final operation = storage.generateAndStoreKeys(
        primaryWriteGuard: (pubkey, persist) async {
          owner = pubkey;
          await persist();
        },
      );
      unawaited(operation.then<void>((_) => settled = true));
      await writeStarted.future;
      await pumpEventQueue();
      expect(settled, isFalse);
      expect(native.containsKey(primary), isFalse);
      writeGate!.complete();
      final keys = await operation;
      expect(owner, keys.publicKeyHex);
      expect(keys.isDisposed, isFalse);
      expect(primaryWrites, 1);
      expect(await storage.getKeyContainer(), same(keys));
    });

    for (final throwsFromGuard in [false, true]) {
      final failureMode = throwsFromGuard
          ? 'propagating the guard failure'
          : 'rejecting an early guard return';
      test(
        'drains a launched write before $failureMode',
        () async {
          writeGate = Completer<void>();
          final guardFailure = StateError('retired owner');
          String? owner;
          var settled = false;
          final operation = storage.generateAndStoreKeys(
            primaryWriteGuard: (pubkey, persist) async {
              owner = pubkey;
              unawaited(persist());
              await writeStarted.future;
              if (throwsFromGuard) throw guardFailure;
            },
          );
          final observed = expectLater(
            operation,
            throwsFromGuard
                ? throwsA(same(guardFailure))
                : throwsA(
                    isA<SecureKeyStorageException>().having(
                      (error) => error.message,
                      'message',
                      contains('before persistence settled'),
                    ),
                  ),
          );
          unawaited(
            operation.then<void>(
              (_) => settled = true,
              onError: (Object _, StackTrace _) => settled = true,
            ),
          );
          await writeStarted.future;
          await pumpEventQueue();
          expect(settled, isFalse);
          expect(native.containsKey(primary), isFalse);
          writeGate!.complete();
          await observed;
          expect(primaryWrites, 1);
          expect(native[primary], contains('publicKeyHex:$owner'));
          // The failed operation disposes its private container only after IO;
          // a subsequent recovery reads a new usable container from the bytes.
          final recovered = await storage.getKeyContainer();
          expect(recovered!.publicKeyHex, owner);
          expect(recovered.isDisposed, isFalse);
          expect(primaryWrites, 1);
        },
      );
    }

    test('a captured callback cannot start after a failed guard', () async {
      late Future<void> Function() retained;
      final guardFailure = StateError('no authority');
      await expectLater(
        storage.generateAndStoreKeys(
          primaryWriteGuard: (_, persist) async {
            retained = persist;
            throw guardFailure;
          },
        ),
        throwsA(same(guardFailure)),
      );
      expect(retained, throwsA(isA<SecureKeyStorageException>()));
      expect(primaryWrites, 0);
      expect(native.containsKey(primary), isFalse);
      expect(await storage.getKeyContainer(), isNull);
    });

    test('a guard must actually invoke persistence', () async {
      late Future<void> Function() retained;
      await expectLater(
        storage.generateAndStoreKeys(
          primaryWriteGuard: (_, persist) async {
            retained = persist;
          },
        ),
        throwsA(isA<SecureKeyStorageException>()),
      );
      expect(retained, throwsA(isA<SecureKeyStorageException>()));
      expect(primaryWrites, 0);
      expect(native.containsKey(primary), isFalse);
    });

    test('even a live guard may invoke persistence only once', () async {
      late Future<void> Function() retained;
      final keys = await storage.generateAndStoreKeys(
        primaryWriteGuard: (_, persist) async {
          retained = persist;
          await persist();
          expect(persist, throwsA(isA<SecureKeyStorageException>()));
        },
      );
      expect(retained, throwsA(isA<SecureKeyStorageException>()));
      expect(primaryWrites, 1);
      expect(keys.isDisposed, isFalse);
      expect(await storage.getKeyContainer(), same(keys));
    });

    test(
      'a refused write preserves the previous cached and native key',
      () async {
        final previous = await storage.generateAndStoreKeys();
        final previousBytes = native[primary];
        refuseWrite = true;
        await expectLater(
          storage.generateAndStoreKeys(
            primaryWriteGuard: (_, persist) => persist(),
          ),
          throwsA(isA<SecureKeyStorageException>()),
        );
        expect(primaryWrites, 2);
        expect(native[primary], previousBytes);
        expect(previous.isDisposed, isFalse);
        expect(await storage.getKeyContainer(), same(previous));
      },
    );

    test(
      'a failure after saving clears only the undelivered generated cache',
      () async {
        SecureKeyContainer? undelivered;
        final guardFailure = StateError('guard retired after persistence');
        await expectLater(
          storage.generateAndStoreKeys(
            primaryWriteGuard: (_, persist) async {
              await persist();
              undelivered = await storage.getKeyContainer();
              throw guardFailure;
            },
          ),
          throwsA(same(guardFailure)),
        );
        expect(undelivered, isNotNull);
        expect(undelivered!.isDisposed, isTrue);
        final recovered = await storage.getKeyContainer();
        expect(recovered, isNot(same(undelivered)));
        expect(recovered!.isDisposed, isFalse);
        expect(
          native[primary],
          contains('publicKeyHex:${recovered.publicKeyHex}'),
        );
        expect(primaryWrites, 1);
      },
    );

    test(
      'a fire-and-forget failed write is drained without a late error',
      () async {
        writeGate = Completer<void>();
        refuseWrite = true;
        final guardFailure = StateError('retired while write was in flight');
        final operation = storage.generateAndStoreKeys(
          primaryWriteGuard: (_, persist) async {
            unawaited(persist());
            await writeStarted.future;
            throw guardFailure;
          },
        );
        final observed = expectLater(operation, throwsA(same(guardFailure)));
        await writeStarted.future;
        await pumpEventQueue();
        writeGate!.complete();
        await observed;
        await pumpEventQueue();
        expect(primaryWrites, 1);
        expect(native.containsKey(primary), isFalse);
        expect(await storage.getKeyContainer(), isNull);
      },
    );
  });
}

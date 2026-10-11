// ABOUTME: Verifies raw PRIMARY presence through native method channels.
// ABOUTME: Read failures and unverified native results never prove absence.

import 'dart:io' show Platform;

import 'package:flutter/services.dart';
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

  late Map<String, String> records;
  late List<String> fallbackReads;
  late List<String> nativeCalls;
  Object? nativePresence;
  Object? nativeInitialization;
  String? failingRead;
  var failNativePresence = false;
  var missingNativeInitialization = false;
  var failingNativeInitialization = false;
  var missingNativeCapabilities = false;
  var failingNativeCapabilities = false;
  var nullNativeCapabilities = false;
  var missingNativeReadMethods = false;
  String? implementedNativeReadMethod;

  setUp(() {
    records = {};
    fallbackReads = [];
    nativeCalls = [];
    nativePresence = false;
    nativeInitialization = true;
    failingRead = null;
    failNativePresence = false;
    missingNativeInitialization = false;
    failingNativeInitialization = false;
    missingNativeCapabilities = false;
    failingNativeCapabilities = false;
    nullNativeCapabilities = false;
    missingNativeReadMethods = false;
    implementedNativeReadMethod = null;

    messenger
      ..setMockMethodCallHandler(fallbackChannel, (call) async {
        expect(call.method, 'read', reason: 'A presence probe must not mutate');
        final args = call.arguments as Map<dynamic, dynamic>;
        expect(args['key'], primary);
        final options = args['options'] as Map<dynamic, dynamic>;
        final accessibility = options['accessibility'] as String?;
        // Linux and Android have one fallback namespace. The read order still
        // identifies the two actual storage reads; Apple has distinct slots.
        final slot =
            accessibility ?? (fallbackReads.isEmpty ? current : legacy);
        if (Platform.isMacOS || Platform.isIOS) {
          expect(accessibility, anyOf(current, legacy));
        }
        fallbackReads.add(slot);
        if (failingRead == slot) {
          throw PlatformException(code: 'fixture_${slot}_read_unavailable');
        }
        return records[slot];
      })
      ..setMockMethodCallHandler(nativeChannel, (call) async {
        nativeCalls.add(call.method);
        if (missingNativeCapabilities &&
            missingNativeInitialization &&
            missingNativeReadMethods &&
            implementedNativeReadMethod == null) {
          throw MissingPluginException();
        }
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
            if (failingNativeInitialization) {
              throw PlatformException(code: 'fixture_native_init_unavailable');
            }
            return nativeInitialization;
          case 'hasKey':
            if (missingNativeReadMethods &&
                implementedNativeReadMethod != call.method) {
              throw MissingPluginException();
            }
            final args = call.arguments as Map<dynamic, dynamic>;
            expect(args['keyId'], primary);
            if (failNativePresence) {
              throw PlatformException(code: 'fixture_native_read_unavailable');
            }
            return nativePresence;
          case 'retrieveKey':
            if (missingNativeReadMethods &&
                implementedNativeReadMethod != call.method) {
              throw MissingPluginException();
            }
            if (failNativePresence) {
              throw PlatformException(code: 'fixture_native_read_unavailable');
            }
            return {'success': true};
          default:
            fail('Unexpected native operation during a presence probe');
        }
      });
  });

  tearDown(() {
    messenger
      ..setMockMethodCallHandler(fallbackChannel, null)
      ..setMockMethodCallHandler(nativeChannel, null);
  });

  group('Strict fallback PRIMARY presence', () {
    late PlatformSecureStorage platformStorage;

    setUp(() {
      platformStorage = PlatformSecureStorage.forPlatform(TargetPlatform.iOS);
    });

    test('absence requires successful current and legacy reads', () async {
      expect(await platformStorage.hasKeyStrict(primary), isFalse);
      expect(fallbackReads, [current, legacy]);
      expect(records, isEmpty);
    });

    final currentRecords = {'malformed': 'unreadable-record', 'empty': ''};
    for (final entry in currentRecords.entries) {
      test('${entry.key} current bytes are present without decoding', () async {
        final raw = entry.value;
        records[current] = raw;
        expect(await platformStorage.hasKeyStrict(primary), isTrue);
        expect(fallbackReads, [current]);
        expect(records, {current: raw});
      });
    }

    test('legacy bytes are present and never migrated', () async {
      const raw = 'unreadable-legacy-record';
      records[legacy] = raw;
      expect(await platformStorage.hasKeyStrict(primary), isTrue);
      expect(fallbackReads, [current, legacy]);
      expect(records, {legacy: raw});
    });

    for (final slot in [current, legacy]) {
      test('$slot read failure cannot be mistaken for absence', () async {
        records[slot] = 'retained-unreadable-record';
        failingRead = slot;
        await expectLater(
          platformStorage.hasKeyStrict(primary),
          throwsA(
            isA<PlatformException>().having(
              (error) => error.code,
              'code',
              'fixture_${slot}_read_unavailable',
            ),
          ),
        );
        expect(fallbackReads, slot == current ? [current] : [current, legacy]);
        expect(records, {slot: 'retained-unreadable-record'});
      });
    }

    test('the ordinary probe keeps its existing fallback behavior', () async {
      failingRead = current;
      expect(await platformStorage.hasKey(primary), isFalse);
      expect(fallbackReads, [current]);
    });
  });

  group('Strict native PRIMARY presence', () {
    late PlatformSecureStorage platformStorage;

    setUp(() {
      platformStorage = PlatformSecureStorage.forPlatform(
        TargetPlatform.android,
      );
    });

    for (final result in [false, true]) {
      test('an explicit native $result is authoritative', () async {
        nativePresence = result;
        expect(await platformStorage.hasKeyStrict(primary), result);
        expect(nativeCalls, ['getCapabilities', 'initializeAndroid', 'hasKey']);
        expect(fallbackReads, isEmpty);
      });
    }

    final uncertainResults = <String, Object?>{
      'null': null,
      'string': 'false',
      'number': 0,
      'map': <String, Object?>{},
    };
    for (final entry in uncertainResults.entries) {
      test('a native ${entry.key} result cannot prove absence', () async {
        nativePresence = entry.value;
        await expectLater(
          platformStorage.hasKeyStrict(primary),
          throwsA(
            isA<PlatformSecureStorageException>().having(
              (error) => error.code,
              'code',
              'key_presence_unverified',
            ),
          ),
        );
        expect(nativeCalls, ['getCapabilities', 'initializeAndroid', 'hasKey']);
        expect(fallbackReads, isEmpty);
      });
    }

    test('native read failure propagates without probing fallback', () async {
      failNativePresence = true;
      await expectLater(
        platformStorage.hasKeyStrict(primary),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'fixture_native_read_unavailable',
          ),
        ),
      );
      expect(fallbackReads, isEmpty);
    });

    test(
      'an inaccessible installed backend cannot attest fallback absence',
      () async {
        failingNativeInitialization = true;
        await expectLater(
          platformStorage.hasKeyStrict(primary),
          throwsA(
            isA<PlatformException>().having(
              (error) => error.code,
              'code',
              'fixture_native_init_unavailable',
            ),
          ),
        );
        expect(nativeCalls, ['getCapabilities', 'initializeAndroid']);
        expect(fallbackReads, isEmpty);
        // The strict API preserves ordinary fallback compatibility.
        expect(await platformStorage.hasKey(primary), isFalse);
        expect(fallbackReads, [current, legacy]);
      },
    );

    for (final result in [false, null]) {
      test(
        'a native $result initialization cannot attest fallback absence',
        () async {
          nativeInitialization = result;
          await expectLater(
            platformStorage.hasKeyStrict(primary),
            throwsA(isA<PlatformSecureStorageException>()),
          );
          expect(fallbackReads, isEmpty);
          expect(nativeCalls, ['getCapabilities', 'initializeAndroid']);
        },
      );
    }

    test(
      'a genuinely missing plugin permits proven fallback absence',
      () async {
        missingNativeCapabilities = true;
        missingNativeInitialization = true;
        missingNativeReadMethods = true;
        expect(await platformStorage.hasKeyStrict(primary), isFalse);
        expect(fallbackReads, [current, legacy]);
        expect(nativeCalls, [
          'getCapabilities',
          'initializeAndroid',
          'hasKey',
          'retrieveKey',
        ]);
      },
    );

    test(
      'a genuinely missing plugin still preserves fallback presence',
      () async {
        missingNativeCapabilities = true;
        missingNativeInitialization = true;
        missingNativeReadMethods = true;
        records[current] = 'retained-fallback-record';
        expect(await platformStorage.hasKeyStrict(primary), isTrue);
        expect(records, {current: 'retained-fallback-record'});
        expect(fallbackReads, [current]);
        expect(nativeCalls, [
          'getCapabilities',
          'initializeAndroid',
          'hasKey',
          'retrieveKey',
        ]);
      },
    );

    for (final evidence in ['success', 'null', 'failure']) {
      test(
        '$evidence native capability evidence makes missing setup uncertain',
        () async {
          nullNativeCapabilities = evidence == 'null';
          failingNativeCapabilities = evidence == 'failure';
          missingNativeInitialization = true;
          nativePresence = true;
          await expectLater(
            platformStorage.hasKeyStrict(primary),
            throwsA(isA<MissingPluginException>()),
          );
          expect(nativePresence, isTrue);
          expect(nativeCalls, ['getCapabilities', 'initializeAndroid']);
          expect(fallbackReads, isEmpty);
        },
      );
    }

    for (final method in ['hasKey', 'retrieveKey']) {
      for (final readFails in [false, true]) {
        test(
          '$method with absent setup refuses proof '
          'when read failure=$readFails',
          () async {
            missingNativeCapabilities = true;
            missingNativeInitialization = true;
            missingNativeReadMethods = true;
            implementedNativeReadMethod = method;
            nativePresence = true;
            failNativePresence = readFails;
            await expectLater(
              platformStorage.hasKeyStrict(primary),
              readFails
                  ? throwsA(isA<PlatformException>())
                  : throwsA(
                      isA<PlatformSecureStorageException>().having(
                        (error) => error.code,
                        'code',
                        'native_initialization_unverified',
                      ),
                    ),
            );
            expect(nativePresence, isTrue);
            expect(fallbackReads, isEmpty);
            expect(nativeCalls, [
              'getCapabilities',
              'initializeAndroid',
              'hasKey',
              if (method == 'retrieveKey') 'retrieveKey',
            ]);
          },
        );
      }
    }

    test(
      'a missing capabilities method checks fallback and native presence',
      () async {
        missingNativeCapabilities = true;
        nativePresence = true;
        expect(await platformStorage.hasKeyStrict(primary), isTrue);
        expect(nativeCalls, ['getCapabilities', 'initializeAndroid', 'hasKey']);
        expect(fallbackReads, [current, legacy]);
      },
    );

    test(
      'native absence cannot hide bytes in the selected fallback backend',
      () async {
        missingNativeCapabilities = true;
        records[current] = 'retained-fallback-record';
        nativePresence = false;
        expect(await platformStorage.hasKeyStrict(primary), isTrue);
        expect(fallbackReads, [current]);
        expect(records, {current: 'retained-fallback-record'});
      },
    );

    test(
      'both selected backends must be empty before absence is proven',
      () async {
        missingNativeCapabilities = true;
        nativePresence = false;
        expect(await platformStorage.hasKeyStrict(primary), isFalse);
        expect(nativeCalls, ['getCapabilities', 'initializeAndroid', 'hasKey']);
        expect(fallbackReads, [current, legacy]);
      },
    );
  });

  group('SecureKeyStorage strict PRIMARY delegation', () {
    late SecureKeyStorage storage;

    setUp(() {
      storage = SecureKeyStorage(securityConfig: SecurityConfig.desktop);
    });

    tearDown(() {
      storage.dispose();
    });

    test('readable absence checks both actual slots', () async {
      expect(await storage.hasKeysStrict(), isFalse);
      expect(fallbackReads, [current, legacy]);
    });

    test('an unreadable legacy record remains present and unchanged', () async {
      records[legacy] = 'retained-unreadable-record';
      expect(await storage.hasKeysStrict(), isTrue);
      expect(fallbackReads, [current, legacy]);
      expect(records, {legacy: 'retained-unreadable-record'});
    });

    test(
      'a current storage failure propagates through the public API',
      () async {
        failingRead = current;
        await expectLater(
          storage.hasKeysStrict(),
          throwsA(isA<PlatformException>()),
        );
        expect(fallbackReads, [current]);
      },
    );

    test(
      'a legacy storage failure propagates through the public API',
      () async {
        failingRead = legacy;
        await expectLater(
          storage.hasKeysStrict(),
          throwsA(isA<PlatformException>()),
        );
        expect(fallbackReads, [current, legacy]);
      },
    );
  });
}

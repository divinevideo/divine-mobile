import 'dart:async';
import 'dart:convert';
import 'package:account_state_repository/account_state_repository.dart';
import 'package:crypto/crypto.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends Mock implements NostrClient {}

class _Preferences extends Mock implements SharedPreferences {}

class _Signer extends LocalNostrSigner {
  _Signer() : super('1'.padLeft(64, '0'));
  bool decryptFails = false;
  Future<void>? decryptGate;
  bool encryptFails = false;
  Future<void>? encryptGate;
  Future<void>? signingGate;
  Future<void>? publicKeyGate;
  int publicKeyCalls = 0;
  String? publicKeyOverride;
  Exception? publicKeyError;
  int? holdPublicKeyAt;
  void Function(String)? onPreparation;
  @override
  Future<String?> getPublicKey() async {
    publicKeyCalls++;
    if (publicKeyCalls == holdPublicKeyAt) {
      onPreparation?.call('final signer check');
      await publicKeyGate;
    }
    if (publicKeyError != null) throw publicKeyError!;
    return publicKeyOverride ?? await super.getPublicKey();
  }

  bool signingFails = false;
  @override
  Future<String?> nip44Decrypt(String pubkey, String ciphertext) async {
    await decryptGate;
    return decryptFails ? null : super.nip44Decrypt(pubkey, ciphertext);
  }

  @override
  Future<String?> nip44Encrypt(String pubkey, String plaintext) async {
    onPreparation?.call('encryption');
    await encryptGate;
    return encryptFails ? null : super.nip44Encrypt(pubkey, plaintext);
  }

  @override
  Future<Event?> signEvent(Event event) async {
    onPreparation?.call('signing');
    await signingGate;
    return signingFails ? null : super.signEvent(event);
  }
}

void main() {
  late _Client client;
  late LocalNostrSigner signer;
  late String pubkey;
  late List<Event> relay;
  late bool offline;
  late bool incomplete;
  late StreamController<Event> incoming;
  late StreamController<Map<String, RelayConnectionStatus>> statuses;
  late List<AccountStateRepository> repositories;
  SharedPreferences store({
    bool Function()? writeSucceeds,
    Exception? Function()? writeError,
    Future<void> Function()? beforeWrite,
  }) {
    final data = <String, String>{};
    final preferences = _Preferences();
    when(
      () => preferences.getString(any()),
    ).thenAnswer((call) => data[call.positionalArguments[0]]);
    when(() => preferences.setString(any(), any())).thenAnswer((call) async {
      data[call.positionalArguments[0] as String] =
          call.positionalArguments[1] as String;
      await beforeWrite?.call();
      final error = writeError?.call();
      if (error != null) throw error;
      return writeSucceeds?.call() ?? true;
    });
    when(() => preferences.remove(any())).thenAnswer((call) async {
      data.remove(call.positionalArguments[0]);
      return true;
    });
    when(preferences.getKeys).thenAnswer((_) => data.keys.toSet());
    return preferences;
  }

  AccountStateRepository device({
    SharedPreferences? preferences,
    NostrSigner Function()? getSigner,
    Map<String, AccountStateMergeRule> rules = const {},
    bool perFieldSnapshots = false,
  }) {
    final repository = AccountStateRepository(
      nostrClient: client,
      sharedPreferences: preferences ?? store(),
      pubkey: pubkey,
      signer: getSigner ?? () => signer,
      namespace: 'divine:test-settings',
      mergeRules: rules,
      perFieldSnapshots: perFieldSnapshots,
    );
    repositories.add(repository);
    return repository;
  }

  Future<Event> snapshot(
    Map<String, Object?> entries, {
    int version = 1,
    int createdAt = 1000,
  }) async {
    final content = (await signer.nip44Encrypt(
      pubkey,
      jsonEncode({'version': version, 'entries': entries}),
    ))!;
    return (await signer.signEvent(
      Event(
        pubkey,
        EventKind.appSpecificData,
        [
          ['d', 'divine:test-settings'],
        ],
        content,
        createdAt: createdAt,
      ),
    ))!;
  }

  group('AccountStateRepository', () {
    setUpAll(() {
      registerFallbackValue(<Filter>[]);
      registerFallbackValue(Event('1'.padLeft(64, '0'), 1, [], ''));
    });
    setUp(() async {
      client = _Client();
      signer = LocalNostrSigner('1'.padLeft(64, '0'));
      pubkey = (await signer.getPublicKey())!;
      relay = [];
      offline = false;
      incomplete = false;
      repositories = [];
      incoming = StreamController<Event>.broadcast();
      statuses =
          StreamController<Map<String, RelayConnectionStatus>>.broadcast();
      when(() => client.subscribe(any())).thenAnswer((_) => incoming.stream);
      when(() => client.relayStatusStream).thenAnswer((_) => statuses.stream);
      when(
        () => client.queryEventsDetailed(
          any(),
          useCache: false,
          requireAllRelaysSettled: true,
        ),
      ).thenAnswer(
        (_) async =>
            (events: relay.toList(), timedOut: incomplete, noRelays: offline),
      );
      when(() => client.publishEventAwaitOk(any())).thenAnswer((call) async {
        final event = call.positionalArguments[0] as Event;
        if (!offline) relay.add(event);
        return PublishOutcome(
          eventId: event.id,
          acceptedBy: offline ? const [] : const ['wss://relay.example'],
          rejectedBy: const {},
          noResponseFrom: const [],
        );
      });
    });
    tearDown(() async {
      for (final repository in repositories) {
        await repository.close();
      }
      await incoming.close();
      await statuses.close();
    });
    test('sharded snapshots sync beyond one NIP44 plaintext limit', () async {
      final phone = device(perFieldSnapshots: true);
      await phone.setValues({
        for (var i = 0; i < 400; i++)
          '${i.toString().padLeft(64, '0')}:${'b' * 64}': {
            'through': i,
            'known': ['c' * 64],
          },
      });
      await phone.synchronize();
      expect(relay, hasLength(400));
      final desktop = device(perFieldSnapshots: true);
      await desktop.synchronize();
      expect(desktop.values, phone.values);
      expect(relay, hasLength(400));
      await phone.setValue(phone.values.keys.first, null);
      await phone.synchronize();
      expect(relay, hasLength(401));
      await desktop.synchronize();
      expect(desktop.values, phone.values);
      expect(relay, hasLength(401));
    });

    test(
      'opaque shard addresses hide tuples and cross-device edits reuse the learned address',
      () async {
        final key = '${'a' * 64},${'b' * 64}';
        final phone = device(perFieldSnapshots: true);
        await phone.setValue(key, {
          'through': 1,
          'known': ['c' * 64],
        });
        await phone.synchronize();
        final tag = relay.single.dTagValue;
        expect(
          tag,
          matches(RegExp(r'^divine:test-settings/field/[0-9a-f]{64}$')),
        );
        expect(tag, isNot(contains('a' * 64)));
        expect(
          tag,
          isNot(contains(sha256.convert(utf8.encode(key)).toString())),
        );
        final desktop = device(perFieldSnapshots: true);
        await desktop.synchronize();
        await desktop.setValue(key, null);
        await desktop.synchronize();
        expect(relay.last.dTagValue, tag);
        await phone.synchronize();
        expect(phone.contains(key), true);
        expect(phone.value(key), null);
      },
    );
    test(
      'partitioned initial opaque addresses converge on one canonical address',
      () async {
        final phone = device(perFieldSnapshots: true);
        await phone.setValue('tuple', true);
        await phone.synchronize();
        final first = relay.single;
        relay.clear();
        final desktop = device(perFieldSnapshots: true);
        await desktop.setValue('tuple', false);
        await desktop.synchronize();
        final second = relay.single;
        expect(first.dTagValue, isNot(second.dTagValue));
        relay.add(first);
        await phone.synchronize();
        await desktop.synchronize();
        final canonical = ([first.dTagValue, second.dTagValue]..sort()).first;
        await desktop.setValue('tuple', null);
        await desktop.synchronize();
        expect(relay.last.dTagValue, canonical);
        await phone.synchronize();
        expect(phone.values, desktop.values);
        final published = relay.length;
        await desktop.synchronize();
        expect(relay, hasLength(published));
      },
    );
    test(
      'partial shard acknowledgments survive restart without republishing successful fields',
      () async {
        final preferences = store();
        final phone = device(preferences: preferences, perFieldSnapshots: true);
        await phone.setValues({'a': true, 'b': null});
        var attempts = 0;
        when(() => client.publishEventAwaitOk(any())).thenAnswer((call) async {
          final event = call.positionalArguments[0] as Event;
          attempts++;
          if (attempts != 2) relay.add(event);
          return PublishOutcome(
            eventId: event.id,
            acceptedBy: attempts == 2 ? [] : ['wss://relay.example'],
            rejectedBy: const {},
            noResponseFrom: const [],
          );
        });
        await expectLater(
          phone.synchronize(),
          throwsA(isA<AccountStateException>()),
        );
        final acknowledged = relay.single;
        expect(phone.hasPendingChanges, true);
        await phone.close();
        final restarted = device(
          preferences: preferences,
          perFieldSnapshots: true,
        );
        await restarted.synchronize();
        expect(relay, hasLength(2));
        expect(
          relay.where((event) => event.id == acknowledged.id),
          hasLength(1),
        );
        expect(restarted.hasPendingChanges, false);
        final originalIds = relay.map((event) => event.id).toSet();
        relay.clear();
        await restarted.synchronize();
        expect(relay.map((event) => event.id).toSet(), originalIds);
      },
    );
    test(
      'oversize individual shard stays pending and does not truncate intent',
      () async {
        final phone = device(perFieldSnapshots: true);
        await phone.setValue('large', 'x' * 65536);
        await expectLater(
          phone.synchronize(),
          throwsA(
            isA<AccountStateException>().having(
              (error) => error.message,
              'message',
              contains('plaintext limit'),
            ),
          ),
        );
        expect(phone.value('large'), hasLength(65536));
        expect(phone.hasPendingChanges, true);
        expect(relay, isEmpty);
      },
    );

    test(
      'refused opaque-address persistence cannot reach a signer or transport',
      () async {
        var writes = 0;
        var refuse = true;
        final preferences = store(
          writeSucceeds: () {
            writes++;
            return !(refuse && writes == 4);
          },
        );
        final phone = device(preferences: preferences, perFieldSnapshots: true);
        await phone.setValue('tuple', true);
        await expectLater(
          phone.synchronize(),
          throwsA(isA<AccountStateException>()),
        );
        expect(relay, isEmpty);
        expect(phone.hasPendingChanges, true);
        refuse = false;
        await phone.synchronize();
        expect(relay, hasLength(1));
      },
    );
    test(
      'source received while opaque addresses save fences the first shard',
      () async {
        late SharedPreferences preferences;
        var inject = false;
        final newer = await snapshot({}, version: 2);
        preferences = store(
          beforeWrite: () async {
            final raw = preferences.getString(
              'account_state_divine:test-settings_${pubkey}_state',
            );
            if (inject &&
                raw != null &&
                ((jsonDecode(raw) as Map)['fieldTags'] as Map).isNotEmpty) {
              inject = false;
              incoming.add(newer);
              await pumpEventQueue();
            }
          },
        );
        final phone = device(preferences: preferences, perFieldSnapshots: true);
        await phone.start();
        await pumpEventQueue();
        inject = true;
        await phone.setValue('tuple', true);
        await pumpEventQueue();
        await expectLater(phone.synchronize(), throwsFormatException);
        expect(relay, isEmpty);
        expect(phone.hasPendingChanges, true);
      },
    );

    test(
      'offline choice persists before publication and retries after restart',
      () async {
        final preferences = store();
        final phone = device(preferences: preferences);
        offline = true;
        await phone.setValue('appearance', 'dark');
        expect(phone.value('appearance'), 'dark');
        expect(phone.hasPendingChanges, isTrue);
        await expectLater(phone.synchronize(), throwsA(isA<Exception>()));
        await phone.close();
        final restarted = device(preferences: preferences);
        expect(restarted.value('appearance'), 'dark');
        expect(restarted.hasPendingChanges, isTrue);
        offline = false;
        await restarted.synchronize();
        final desktop = device();
        await desktop.synchronize();
        expect(desktop.value('appearance'), 'dark');
        expect(restarted.hasPendingChanges, isFalse);
        expect(relay.single.isSigned, isTrue);
        expect(relay.single.content, isNot(contains('appearance')));
      },
    );
    test(
      'different concurrent fields and explicit null reset converge',
      () async {
        final phone = device();
        final desktop = device();
        await phone.setValue('language', 'es');
        await desktop.setValue('appearance', 'dark');
        await phone.synchronize();
        await desktop.synchronize();
        await phone.synchronize();
        expect(phone.values, {'language': 'es', 'appearance': 'dark'});
        await phone.setValue('appearance', null);
        await phone.synchronize();
        await desktop.synchronize();
        expect(desktop.contains('appearance'), isTrue);
        expect(desktop.value('appearance'), isNull);
      },
    );
    test(
      'setters finish while network blocked and later edits survive acknowledgment',
      () async {
        final read =
            Completer<({List<Event> events, bool timedOut, bool noRelays})>();
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: false,
            requireAllRelaysSettled: true,
          ),
        ).thenAnswer((_) => read.future);
        final phone = device();
        final sync = phone.synchronize();
        await phone.setValue('choice', true);
        expect(phone.value('choice'), isTrue);
        read.complete((events: <Event>[], timedOut: false, noRelays: false));
        await sync;
        final acknowledgment = Completer<PublishOutcome>();
        Event? published;
        when(() => client.publishEventAwaitOk(any())).thenAnswer((call) {
          published = call.positionalArguments[0] as Event;
          return acknowledgment.future;
        });
        await phone.setValue('choice', false);
        final publishing = phone.synchronize();
        await pumpEventQueue();
        await phone.setValue('choice', null);
        acknowledgment.complete(
          PublishOutcome(
            eventId: published!.id,
            acceptedBy: const ['wss://relay.example'],
            rejectedBy: const {},
            noResponseFrom: const [],
          ),
        );
        await publishing;
        expect(phone.value('choice'), isNull);
        expect(phone.hasPendingChanges, isTrue);
      },
    );
    test(
      'unknown schema remains a durable publication barrier after restart',
      () async {
        final preferences = store();
        final phone = device(preferences: preferences);
        relay.add(await snapshot({}, version: 2));
        await phone.setValue('choice', true);
        await expectLater(phone.synchronize(), throwsFormatException);
        relay.clear();
        final restarted = device(preferences: preferences);
        await expectLater(restarted.synchronize(), throwsFormatException);
        expect(relay, isEmpty);
        expect(restarted.hasPendingChanges, isTrue);
      },
    );
    test(
      'incomplete reads retain signed union across restart and repair relay loss',
      () async {
        final preferences = store();
        relay = [
          await snapshot({
            'one': {'value': true, 'updated_at': 10},
          }),
          await snapshot({
            'two': {'value': true, 'updated_at': 11},
          }, createdAt: 1001),
        ];
        incomplete = true;
        final phone = device(preferences: preferences);
        await expectLater(phone.synchronize(), throwsA(isA<Exception>()));
        expect(phone.values, {'one': true, 'two': true});
        relay.clear();
        incomplete = false;
        final restarted = device(preferences: preferences);
        await restarted.synchronize();
        final desktop = device();
        await desktop.synchronize();
        expect(desktop.values, {'one': true, 'two': true});
      },
    );
    test('ties choose undo and numeric cursors never regress', () async {
      relay = [
        await snapshot({
          'hidden': {'value': true, 'updated_at': 10},
          'cursor': {'value': 100, 'updated_at': 9},
        }),
        await snapshot({
          'hidden': {'value': false, 'updated_at': 10},
          'cursor': {'value': 50, 'updated_at': 20},
        }, createdAt: 1001),
      ];
      final phone = device(
        rules: {'cursor': AccountStateMergeRule.numericMaximum},
      );
      await phone.synchronize();
      expect(phone.values, {'hidden': false, 'cursor': 100});
      await phone.setValue('cursor', 1);
      expect(phone.value('cursor'), 100);
    });
    test(
      'incoming snapshots and reconnect synchronize and close stops callbacks',
      () async {
        final phone = device();
        await phone.start();
        await pumpEventQueue();
        final event = await snapshot({
          'appearance': {'value': 'light', 'updated_at': 10},
        });
        incoming.add(event);
        await pumpEventQueue();
        expect(phone.value('appearance'), 'light');
        offline = true;
        await phone.setValue('language', 'fr');
        offline = false;
        statuses.add({
          'wss://relay.example': RelayConnectionStatus.connected(
            'wss://relay.example',
          ),
        });
        await pumpEventQueue();
        expect(phone.hasPendingChanges, isFalse);
        await phone.close();
        relay = [
          await snapshot({
            'appearance': {'value': 'dark', 'updated_at': 20},
          }),
        ];
        incoming.add(relay.single);
        await pumpEventQueue();
        expect(phone.value('appearance'), 'light');
      },
    );
    test('closing during read prevents wrong-account publication', () async {
      NostrSigner active = signer;
      final phone = device(getSigner: () => active);
      await phone.setValue('choice', true);
      final read =
          Completer<({List<Event> events, bool timedOut, bool noRelays})>();
      when(
        () => client.queryEventsDetailed(
          any(),
          useCache: false,
          requireAllRelaysSettled: true,
        ),
      ).thenAnswer((_) => read.future);
      final sync = phone.synchronize();
      await pumpEventQueue();
      active = LocalNostrSigner('2'.padLeft(64, '0'));
      await phone.close();
      read.complete((events: <Event>[], timedOut: false, noRelays: false));
      await sync;
      expect(relay, isEmpty);
    });
    test('failed durable write does not mutate visible state', () async {
      final preferences = store();
      final phone = device(preferences: preferences);
      when(
        () => preferences.setString(any(), any()),
      ).thenAnswer((_) async => false);
      await expectLater(
        phone.setValue('choice', true),
        throwsA(isA<Exception>()),
      );
      expect(phone.values, isEmpty);
      expect(phone.hasPendingChanges, isFalse);
    });
    test(
      'incoming newer schema during publish survives compaction and restart',
      () async {
        final preferences = store();
        final phone = device(preferences: preferences);
        await phone.start();
        await pumpEventQueue();
        final acknowledgment = Completer<PublishOutcome>();
        Event? published;
        when(() => client.publishEventAwaitOk(any())).thenAnswer((call) {
          published = call.positionalArguments[0] as Event;
          return acknowledgment.future;
        });
        await phone.setValue('choice', true);
        await pumpEventQueue();
        incoming.add(await snapshot({}, version: 2));
        await pumpEventQueue();
        acknowledgment.complete(
          PublishOutcome(
            eventId: published!.id,
            acceptedBy: const ['wss://relay.example'],
            rejectedBy: const {},
            noResponseFrom: const [],
          ),
        );
        await pumpEventQueue();
        await phone.close();
        relay.clear();
        final restarted = device(preferences: preferences);
        await expectLater(restarted.synchronize(), throwsFormatException);
        expect(relay, isEmpty);
      },
    );

    group('durable outbox retry', () {
      test('rejected publish retries without reconnect or another edit', () {
        var attempts = 0;
        when(() => client.publishEventAwaitOk(any())).thenAnswer((call) async {
          final event = call.positionalArguments[0] as Event;
          attempts++;
          final accepted = attempts >= 2;
          if (accepted) relay.add(event);
          return PublishOutcome(
            eventId: event.id,
            acceptedBy: accepted ? const ['wss://relay.example'] : const [],
            rejectedBy: const {},
            noResponseFrom: const [],
          );
        });
        fakeAsync((clock) {
          final phone = device();
          unawaited(phone.start());
          clock.flushMicrotasks();
          unawaited(phone.setValue('choice', true));
          clock.flushMicrotasks();
          expect(attempts, 1);
          expect(phone.hasPendingChanges, true);
          clock
            ..elapse(const Duration(milliseconds: 999))
            ..flushMicrotasks();
          expect(attempts, 1);
          clock
            ..elapse(const Duration(milliseconds: 1))
            ..flushMicrotasks();
          expect(attempts, 2);
          expect(phone.hasPendingChanges, false);
          unawaited(phone.close());
          clock.flushMicrotasks();
        });
      });
      test('backoff is bounded and close cancels the pending retry', () {
        var attempts = 0;
        when(() => client.publishEventAwaitOk(any())).thenAnswer((call) async {
          attempts++;
          return PublishOutcome(
            eventId: (call.positionalArguments[0] as Event).id,
            acceptedBy: const [],
            rejectedBy: const {},
            noResponseFrom: const [],
          );
        });
        fakeAsync((clock) {
          final phone = device();
          unawaited(phone.start());
          clock.flushMicrotasks();
          unawaited(phone.setValue('choice', true));
          clock.flushMicrotasks();
          expect(attempts, 1);
          for (final seconds in [1, 2, 4, 8, 16, 32, 60, 60]) {
            final previous = attempts;
            clock
              ..elapse(Duration(seconds: seconds - 1))
              ..flushMicrotasks();
            expect(attempts, previous);
            clock
              ..elapse(const Duration(seconds: 1))
              ..flushMicrotasks();
            expect(attempts, previous + 1);
          }
          unawaited(phone.close());
          clock.flushMicrotasks();
          final beforeClose = attempts;
          clock
            ..elapse(const Duration(minutes: 2))
            ..flushMicrotasks();
          expect(attempts, beforeClose);
          expect(phone.hasPendingChanges, true);
        });
      });
      test(
        'successful acknowledgment keeps retry for a source whose persistence failed',
        () async {
          final unknown = await snapshot({}, version: 2);
          Exception? storageError;
          final preferences = store(writeError: () => storageError);
          late Completer<PublishOutcome> acknowledgment;
          Event? published;
          when(() => client.publishEventAwaitOk(any())).thenAnswer((call) {
            published = call.positionalArguments[0] as Event;
            return acknowledgment.future;
          });
          fakeAsync((clock) {
            acknowledgment = Completer<PublishOutcome>();
            final phone = device(preferences: preferences);
            unawaited(phone.start());
            clock.flushMicrotasks();
            unawaited(phone.setValue('choice', true));
            clock.flushMicrotasks();
            expect(published, isNotNull);
            storageError = PlatformException(code: 'storage_unavailable');
            incoming.add(unknown);
            clock.flushMicrotasks();
            storageError = null;
            acknowledgment.complete(
              PublishOutcome(
                eventId: published!.id,
                acceptedBy: const ['wss://relay.example'],
                rejectedBy: const {},
                noResponseFrom: const [],
              ),
            );
            clock
              ..flushMicrotasks()
              ..elapse(const Duration(seconds: 1))
              ..flushMicrotasks();
            unawaited(phone.close());
            clock.flushMicrotasks();
            final restarted = device(preferences: preferences);
            Object? failure;
            unawaited(
              restarted.synchronize().catchError((Object error) {
                failure = error;
              }),
            );
            clock.flushMicrotasks();
            expect(failure, isFormatException);
            unawaited(restarted.close());
            clock.flushMicrotasks();
          });
        },
      );

      for (final delayedRecovery in [false, true]) {
        test(
          'received source persists before locked signer retry (delayed disk: $delayedRecovery)',
          () async {
            final unknown = await snapshot({}, version: 2);
            var diskBroken = false;
            var signerLocked = false;
            var signerCalls = 0;
            final preferences = store(
              writeError: () => diskBroken
                  ? PlatformException(code: 'storage_unavailable')
                  : null,
            );
            fakeAsync((clock) {
              final phone = device(
                preferences: preferences,
                getSigner: () {
                  signerCalls++;
                  if (signerLocked) throw StateError('signer locked');
                  return signer;
                },
              );
              unawaited(phone.start());
              clock.flushMicrotasks();
              unawaited(phone.setValue('choice', true));
              clock.flushMicrotasks();
              diskBroken = true;
              incoming.add(unknown);
              clock.flushMicrotasks();
              signerLocked = true;
              final beforeRetry = signerCalls;
              diskBroken = delayedRecovery;
              clock
                ..elapse(const Duration(seconds: 1))
                ..flushMicrotasks();
              if (delayedRecovery) {
                expect(
                  signerCalls,
                  beforeRetry,
                  reason: 'source persistence must precede authorization',
                );
                diskBroken = false;
                clock
                  ..elapse(const Duration(seconds: 2))
                  ..flushMicrotasks();
              }
              final blockedCalls = signerCalls;
              clock
                ..elapse(const Duration(minutes: 2))
                ..flushMicrotasks();
              expect(
                signerCalls,
                blockedCalls,
                reason:
                    'a refused signer must not be prompted by persistence retry',
              );
              unawaited(phone.close());
              clock.flushMicrotasks();
              relay.clear();
              Object? failure;
              final restarted = device(preferences: preferences);
              unawaited(
                restarted.synchronize().catchError((Object error) {
                  failure = error;
                }),
              );
              clock.flushMicrotasks();
              expect(failure, isFormatException);
              expect(relay, isEmpty);
              unawaited(restarted.close());
              clock.flushMicrotasks();
            });
          },
        );
      }
      test(
        'source-only retry survives refusal while public key request is in flight',
        () async {
          final unknown = await snapshot({}, version: 2);
          final controlled = _Signer();
          var diskBroken = false;
          final preferences = store(
            writeError: () => diskBroken
                ? PlatformException(code: 'storage_unavailable')
                : null,
          );
          fakeAsync((clock) {
            final phone = device(
              preferences: preferences,
              getSigner: () => controlled,
            );
            unawaited(phone.start());
            clock.flushMicrotasks();
            unawaited(phone.setValue('choice', true));
            clock.flushMicrotasks();
            final gate = Completer<void>();
            controlled.holdPublicKeyAt = controlled.publicKeyCalls + 1;
            controlled.publicKeyGate = gate.future;
            unawaited(phone.synchronize().catchError((Object _) {}));
            clock.flushMicrotasks();
            diskBroken = true;
            incoming.add(unknown);
            clock.flushMicrotasks();
            controlled.publicKeyError = Exception('signer locked');
            gate.complete();
            clock.flushMicrotasks();
            final refusedCalls = controlled.publicKeyCalls;
            clock
              ..elapse(const Duration(seconds: 1))
              ..flushMicrotasks();
            diskBroken = false;
            clock
              ..elapse(const Duration(seconds: 2))
              ..flushMicrotasks();
            expect(controlled.publicKeyCalls, refusedCalls);
            unawaited(phone.close());
            clock.flushMicrotasks();
            relay.clear();
            Object? failure;
            final restarted = device(preferences: preferences);
            unawaited(
              restarted.synchronize().catchError((Object error) {
                failure = error;
              }),
            );
            clock.flushMicrotasks();
            expect(failure, isFormatException);
            expect(relay, isEmpty);
            unawaited(restarted.close());
            clock.flushMicrotasks();
          });
        },
      );

      test('explicit successful flush cancels scheduled retry', () {
        var attempts = 0;
        var reject = true;
        when(() => client.publishEventAwaitOk(any())).thenAnswer((call) async {
          attempts++;
          return PublishOutcome(
            eventId: (call.positionalArguments[0] as Event).id,
            acceptedBy: reject ? const [] : const ['wss://relay.example'],
            rejectedBy: const {},
            noResponseFrom: const [],
          );
        });
        fakeAsync((clock) {
          final phone = device();
          unawaited(phone.start());
          clock.flushMicrotasks();
          unawaited(phone.setValue('choice', true));
          clock.flushMicrotasks();
          reject = false;
          unawaited(phone.synchronize());
          clock.flushMicrotasks();
          expect(attempts, 2);
          clock
            ..elapse(const Duration(minutes: 2))
            ..flushMicrotasks();
          expect(attempts, 2);
          expect(phone.hasPendingChanges, false);
          unawaited(phone.close());
          clock.flushMicrotasks();
        });
      });
      for (final refusal in [
        'encryption',
        'signing',
        'decryption',
        'identity',
      ]) {
        test('refused $refusal waits for a new external trigger', () async {
          final controlled = _Signer();
          if (refusal == 'encryption') controlled.encryptFails = true;
          if (refusal == 'signing') controlled.signingFails = true;
          if (refusal == 'decryption') {
            controlled.decryptFails = true;
            relay.add(
              await snapshot({
                'remote': {'value': true, 'updated_at': 1},
              }),
            );
          }
          if (refusal == 'identity') {
            controlled.publicKeyOverride = '2'.padLeft(64, '0');
          }
          var reads = 0;
          when(
            () => client.queryEventsDetailed(
              any(),
              useCache: false,
              requireAllRelaysSettled: true,
            ),
          ).thenAnswer((_) async {
            reads++;
            return (events: relay.toList(), timedOut: false, noRelays: false);
          });
          fakeAsync((clock) {
            final phone = device(getSigner: () => controlled);
            unawaited(phone.setValue('choice', true));
            clock.flushMicrotasks();
            unawaited(phone.start());
            clock.flushMicrotasks();
            final initialReads = reads;
            final initialPublicKeyCalls = controlled.publicKeyCalls;
            clock
              ..elapse(const Duration(minutes: 2))
              ..flushMicrotasks();
            expect(reads, initialReads);
            expect(controlled.publicKeyCalls, initialPublicKeyCalls);
            expect(phone.hasPendingChanges, true);
            expect(relay.where((event) => event.createdAt > 1000), isEmpty);
            unawaited(phone.close());
            clock.flushMicrotasks();
          });
        });
      }

      test(
        'failed startup read with no pending data does not become polling',
        () {
          var reads = 0;
          when(
            () => client.queryEventsDetailed(
              any(),
              useCache: false,
              requireAllRelaysSettled: true,
            ),
          ).thenAnswer((_) async {
            reads++;
            throw StateError('network unavailable');
          });
          fakeAsync((clock) {
            final phone = device();
            unawaited(phone.start());
            clock.flushMicrotasks();
            expect(reads, 1);
            clock
              ..elapse(const Duration(minutes: 2))
              ..flushMicrotasks();
            expect(reads, 1);
            expect(phone.hasPendingChanges, false);
            unawaited(phone.close());
            clock.flushMicrotasks();
          });
        },
      );

      test('unknown schema does not schedule automatic retry', () async {
        relay.add(await snapshot({}, version: 2));
        var reads = 0;
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: false,
            requireAllRelaysSettled: true,
          ),
        ).thenAnswer((_) async {
          reads++;
          return (events: relay.toList(), timedOut: false, noRelays: false);
        });
        fakeAsync((clock) {
          final phone = device();
          unawaited(phone.setValue('choice', true));
          clock.flushMicrotasks();
          unawaited(phone.start());
          clock.flushMicrotasks();
          expect(reads, 1);
          clock
            ..elapse(const Duration(minutes: 2))
            ..flushMicrotasks();
          expect(reads, 1);
          expect(phone.hasPendingChanges, true);
          unawaited(phone.close());
          clock.flushMicrotasks();
        });
      });
    });

    group('publication and storage failure fences', () {
      for (final sharded in [false, true]) {
        for (final window in [
          'encryption',
          'signing',
          'final signer check',
          'queued source write',
          'failed source write',
        ]) {
          test(
            'newer schema received during $window prevents prepared publication (sharded: $sharded)',
            () async {
              final controlled = _Signer();
              Future<void>? diskGate;
              Exception? sourceWriteError;
              final preferences = store(
                writeError: () => sourceWriteError,
                beforeWrite: () async {
                  await diskGate;
                },
              );
              final phone = device(
                preferences: preferences,
                getSigner: () => controlled,
                perFieldSnapshots: sharded,
              );
              await phone.start();
              await pumpEventQueue();
              final gate = Completer<void>();
              final reached = Completer<void>();
              final signerWindow = window.endsWith('source write')
                  ? 'final signer check'
                  : window;
              controlled.onPreparation = (stage) {
                if (stage == signerWindow && !reached.isCompleted) {
                  reached.complete();
                }
              };
              if (window == 'encryption') controlled.encryptGate = gate.future;
              if (window == 'signing') controlled.signingGate = gate.future;
              if (signerWindow == 'final signer check') {
                controlled.holdPublicKeyAt = controlled.publicKeyCalls + 2;
                controlled.publicKeyGate = gate.future;
              }
              await phone.setValue('choice', true);
              await reached.future;
              final pendingDisk = Completer<void>();
              if (window == 'queued source write') {
                diskGate = pendingDisk.future;
              }
              if (window == 'failed source write') {
                sourceWriteError = PlatformException(
                  code: 'storage_unavailable',
                );
              }
              incoming.add(await snapshot({}, version: 2));
              await pumpEventQueue();
              sourceWriteError = null;
              gate.complete();
              await pumpEventQueue();
              if (window == 'queued source write') {
                expect(
                  relay,
                  isEmpty,
                  reason: 'publication must fence queued source persistence',
                );
                diskGate = null;
                pendingDisk.complete();
                await pumpEventQueue();
              }
              expect(
                relay,
                isEmpty,
                reason: 'a newer schema must not be replaced with version one',
              );
              expect(phone.hasPendingChanges, true);
              await phone.close();
              await expectLater(
                device(
                  preferences: preferences,
                  perFieldSnapshots: sharded,
                ).synchronize(),
                throwsFormatException,
              );
            },
          );
        }
      }
      for (final hasPrevious in [false, true]) {
        test(
          'thrown platform write restores eager cache (previous: $hasPrevious)',
          () async {
            Exception? storageError;
            final preferences = store(writeError: () => storageError);
            final phone = device(preferences: preferences);
            if (hasPrevious) await phone.setValue('choice', true);
            storageError = PlatformException(code: 'storage_unavailable');
            await expectLater(
              phone.setValue('choice', false),
              throwsA(same(storageError)),
            );
            expect(phone.contains('choice'), hasPrevious);
            final restarted = device(preferences: preferences);
            expect(restarted.contains('choice'), hasPrevious);
            expect(restarted.value('choice'), hasPrevious ? true : null);
            expect(restarted.hasPendingChanges, hasPrevious);
          },
        );
      }
    });

    group('transport and storage boundaries', () {
      test(
        'legacy signed cache repairs the original signature and filters other accounts',
        () async {
          final preferences = store();
          final original = await snapshot({
            'choice': {'value': true, 'updated_at': 10},
          });
          final otherSigner = LocalNostrSigner('2'.padLeft(64, '0'));
          final foreign = (await otherSigner.signEvent(
            Event(
              (await otherSigner.getPublicKey())!,
              original.kind,
              original.tags,
              original.content,
            ),
          ))!;
          await preferences.setString(
            'account_state_divine:test-settings_$pubkey',
            jsonEncode([original, foreign]),
          );
          final phone = device(preferences: preferences);
          await phone.synchronize();
          expect(relay.single.id, original.id);
          expect(phone.value('choice'), true);
          final keys = AccountStateRepository.localAccountKeys(
            preferences,
            pubkey,
          );
          expect(
            keys,
            contains('account_state_divine:test-settings_${pubkey}_state'),
          );
          await preferences.setString('badge_dismissal_event_$pubkey', '[]');
          await preferences.setString(
            'account_state_other_${(await otherSigner.getPublicKey())!}_state',
            '{}',
          );
          expect(
            AccountStateRepository.localAccountKeys(preferences, pubkey),
            hasLength(3),
          );
        },
      );
      test(
        'corrupt journal and legacy cache recover without leaking payload errors',
        () async {
          final preferences = store();
          await preferences.setString(
            'account_state_divine:test-settings_${pubkey}_state',
            jsonEncode({'version': 2}),
          );
          await preferences.setString(
            'account_state_divine:test-settings_$pubkey',
            'invalid',
          );
          final phone = device(preferences: preferences);
          expect(phone.values, isEmpty);
          await phone.setValue('nested', {
            'b': [1, null],
            'a': 'choice',
          });
          expect(phone.value('nested'), {
            'a': 'choice',
            'b': [1, null],
          });
          await phone.setValue('nested', {
            'a': 'choice',
            'b': [1, null],
          });
          await phone.synchronize();
          await phone.close();
          await expectLater(phone.seed({'other': true}), throwsStateError);
          await expectLater(phone.start(), throwsStateError);
        },
      );
      test(
        'failed write restores the previous SharedPreferences cache',
        () async {
          var saveWorks = true;
          final preferences = store(writeSucceeds: () => saveWorks);
          final phone = device(preferences: preferences);
          await phone.setValue('choice', true);
          saveWorks = false;
          await expectLater(
            phone.setValue('choice', false),
            throwsA(
              isA<AccountStateException>().having(
                (e) => e.toString(),
                'message',
                contains('Could not save'),
              ),
            ),
          );
          expect(phone.value('choice'), true);
          expect(device(preferences: preferences).value('choice'), true);
        },
      );
      test(
        'signer switch without closing cannot publish another account state',
        () async {
          final phone = device(
            getSigner: () => LocalNostrSigner('2'.padLeft(64, '0')),
          );
          await phone.setValue('choice', true);
          await expectLater(
            phone.synchronize(),
            throwsA(isA<AccountStateException>()),
          );
          expect(relay, isEmpty);
        },
      );
      for (final payload in <Object>[
        {
          'version': 1,
          'entries': {'bad': true},
        },
        {
          'version': 1,
          'entries': {
            'bad': {'value': true, 'updated_at': -1},
          },
        },
        {'version': 1, 'entries': <Object?>[]},
      ]) {
        test('invalid remote entries block repair: $payload', () async {
          final content = (await signer.nip44Encrypt(
            pubkey,
            jsonEncode(payload),
          ))!;
          relay = [
            (await signer.signEvent(
              Event(pubkey, EventKind.appSpecificData, [
                ['d', 'divine:test-settings'],
              ], content),
            ))!,
          ];
          await expectLater(device().synchronize(), throwsFormatException);
          expect(relay, hasLength(1));
        });
      }
      test('malformed plaintext errors never contain private data', () async {
        final content = (await signer.nip44Encrypt(
          pubkey,
          'private invalid JSON',
        ))!;
        relay = [
          (await signer.signEvent(
            Event(pubkey, EventKind.appSpecificData, [
              ['d', 'divine:test-settings'],
            ], content),
          ))!,
        ];
        await expectLater(
          device().synchronize(),
          throwsA(
            isA<FormatException>().having((e) => e.source, 'source', isNull),
          ),
        );
      });
      test(
        'encryption, signature, decrypt and relay refusal retain retry intent',
        () async {
          final controlled = _Signer();
          final phone = device(getSigner: () => controlled);
          await phone.setValue('choice', true);
          controlled.encryptFails = true;
          await expectLater(
            phone.synchronize(),
            throwsA(isA<AccountStateException>()),
          );
          controlled
            ..encryptFails = false
            ..signingFails = true;
          await expectLater(
            phone.synchronize(),
            throwsA(isA<AccountStateException>()),
          );
          controlled.signingFails = false;
          when(() => client.publishEventAwaitOk(any())).thenAnswer(
            (call) async => PublishOutcome(
              eventId: (call.positionalArguments[0] as Event).id,
              acceptedBy: const [],
              rejectedBy: const {},
              noResponseFrom: const [],
            ),
          );
          await expectLater(
            phone.synchronize(),
            throwsA(isA<AccountStateException>()),
          );
          expect(phone.hasPendingChanges, true);
          relay.add(
            await snapshot({
              'other': {'value': true, 'updated_at': 1},
            }),
          );
          controlled.decryptFails = true;
          await expectLater(
            phone.synchronize(),
            throwsA(isA<AccountStateException>()),
          );
        },
      );
      test(
        'large sequence of cached snapshots remains bounded and deterministic',
        () async {
          final phone = device();
          for (var i = 1; i <= 10; i++) {
            relay = [
              await snapshot({
                'choice': {'value': i, 'updated_at': i},
              }, createdAt: i),
            ];
            await phone.synchronize();
          }
          expect(phone.value('choice'), 10);
        },
      );
    });

    test(
      'reconcile hooks and streams observe committed union and survive transport errors',
      () async {
        final phone = device();
        final changes = <Map<String, Object?>>[];
        final subscription = phone.changes.listen(changes.add);
        var reconciled = false;
        await phone.synchronize(
          beforeMerge: () => phone.seed({'legacy': true}),
          onReconciled: () {
            reconciled = true;
            expect(phone.value('legacy'), true);
          },
        );
        expect(reconciled, true);
        await phone.start();
        await phone.start();
        incoming.addError(StateError('transport closed'));
        statuses.addError(StateError('transport closed'));
        await pumpEventQueue();
        expect(changes, isNotEmpty);
        await subscription.cancel();
      },
    );
    test(
      'new signed source arriving during decryption is processed before repair',
      () async {
        final controlled = _Signer();
        final gate = Completer<void>();
        controlled.decryptGate = gate.future;
        relay = [
          await snapshot({
            'old': {'value': true, 'updated_at': 1},
          }),
        ];
        final phone = device(getSigner: () => controlled);
        await phone.start();
        await pumpEventQueue();
        incoming.add(await snapshot({}, version: 2, createdAt: 1001));
        await pumpEventQueue();
        gate.complete();
        await pumpEventQueue();
        expect(relay, hasLength(1));
        await expectLater(phone.synchronize(), throwsFormatException);
      },
    );

    test('seed cannot replace a known reset', () async {
      final phone = device();
      await phone.seed({'choice': true});
      await phone.setValue('choice', null);
      await phone.seed({'choice': true, 'other': false});
      expect(phone.values, {'choice': null, 'other': false});
    });
  });
}

import 'dart:async';
import 'dart:convert';
import 'package:account_state_repository/account_state_repository.dart';
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
  bool signingFails = false;
  @override
  Future<String?> nip44Decrypt(String pubkey, String ciphertext) async {
    await decryptGate;
    return decryptFails ? null : super.nip44Decrypt(pubkey, ciphertext);
  }

  @override
  Future<String?> nip44Encrypt(String pubkey, String plaintext) =>
      encryptFails ? Future.value() : super.nip44Encrypt(pubkey, plaintext);
  @override
  Future<Event?> signEvent(Event event) =>
      signingFails ? Future.value() : super.signEvent(event);
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
  SharedPreferences store({bool Function()? writeSucceeds}) {
    final data = <String, String>{};
    final preferences = _Preferences();
    when(
      () => preferences.getString(any()),
    ).thenAnswer((call) => data[call.positionalArguments[0]]);
    when(() => preferences.setString(any(), any())).thenAnswer((call) async {
      data[call.positionalArguments[0] as String] =
          call.positionalArguments[1] as String;
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
  }) {
    final repository = AccountStateRepository(
      nostrClient: client,
      sharedPreferences: preferences ?? store(),
      pubkey: pubkey,
      signer: getSigner ?? () => signer,
      namespace: 'divine:test-settings',
      mergeRules: rules,
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

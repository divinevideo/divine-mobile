import 'dart:async';
import 'dart:convert';
import 'package:account_state_repository/account_state_repository.dart';
import 'package:db_client/db_client.dart' hide Filter;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends Mock implements NostrClient {}

class _HeldStorage implements AccountStateStorage {
  _HeldStorage(this.delegate);
  final AccountStateStorage delegate;
  final gate = Completer<void>();
  @override
  Future<String?> read() async {
    await gate.future;
    return delegate.read();
  }

  @override
  Future<void> write(String value) => delegate.write(value);
}

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  final owner = 'a' * 64;
  setUp(() async {
    db = AppDatabase.test(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });
  tearDown(() => db.close());
  AccountStateRepository create(String account) => AccountStateRepository(
    nostrClient: _Client(),
    sharedPreferences: prefs,
    pubkey: account,
    signer: () => LocalNostrSigner('1'.padLeft(64, '0')),
    namespace: 'dm',
    perFieldSnapshots: true,
    storage: DriftAccountStateStorage(
      db.accountSyncDao,
      owner: account,
      namespace: 'dm',
    ),
  );
  group('close (late shard acknowledgment)', () {
    test(
      'every close caller waits for the same local migration drain',
      () async {
        final storage = _HeldStorage(
          DriftAccountStateStorage(
            db.accountSyncDao,
            owner: owner,
            namespace: 'dm',
          ),
        );
        final repository = AccountStateRepository(
          nostrClient: _Client(),
          sharedPreferences: prefs,
          pubkey: owner,
          signer: () => LocalNostrSigner('1'.padLeft(64, '0')),
          namespace: 'dm',
          storage: storage,
        );
        var secondFinished = false;
        final first = repository.close();
        final second = repository.close().then((_) => secondFinished = true);
        await pumpEventQueue();
        final completedBeforeDrain = secondFinished;
        storage.gate.complete();
        await first;
        await second;
        await db.accountSyncDao.clearAccount(owner);
        expect(completedBeforeDrain, isFalse);
        expect(await db.accountSyncDao.readState(owner, 'dm'), isEmpty);
      },
    );

    test(
      'relay OK after close and erasure cannot restore owner rows',
      () async {
        final signer = LocalNostrSigner('1'.padLeft(64, '0'));
        final account = (await signer.getPublicKey())!;
        final client = _Client();
        registerFallbackValue(Filter());
        registerFallbackValue(Event(account, 1, [], ''));
        final submitted = Completer<Event>();
        final acknowledgment = Completer<PublishOutcome>();
        when(() => client.readAllEvents(any())).thenAnswer(
          (_) async =>
              const PagedQueryResult(events: [], isComplete: true, pages: 1),
        );
        when(() => client.publishEventAwaitOk(any())).thenAnswer((call) {
          submitted.complete(call.positionalArguments[0] as Event);
          return acknowledgment.future;
        });
        final repository = AccountStateRepository(
          nostrClient: client,
          sharedPreferences: prefs,
          pubkey: account,
          signer: () => signer,
          namespace: 'dm',
          perFieldSnapshots: true,
          storage: DriftAccountStateStorage(
            db.accountSyncDao,
            owner: account,
            namespace: 'dm',
          ),
        );
        await repository.setValue('private-tuple', {'through': 1});
        final syncing = repository.synchronize();
        final event = await submitted.future;
        await repository.close();
        await db.accountSyncDao.clearAccount(account);
        acknowledgment.complete(
          PublishOutcome(
            eventId: event.id,
            acceptedBy: const ['wss://relay.example'],
            rejectedBy: const {},
            noResponseFrom: const [],
          ),
        );
        await syncing;
        expect(await db.accountSyncDao.readState(account, 'dm'), isEmpty);
      },
    );
  });

  group('eager restoration', () {
    test(
      'observes corrupt Drift restoration before a later operation awaits it',
      () async {
        await db.accountSyncDao.writeState(owner, 'dm', {
          'entries': {'broken': '{invalid'},
        });
        final unhandled = <Object>[];
        await runZonedGuarded(() async {
          final repository = create(owner);
          await pumpEventQueue();
          await expectLater(repository.seed({}), throwsFormatException);
          await expectLater(repository.start(), throwsFormatException);
          await repository.close();
        }, (error, _) => unhandled.add(error));
        expect(unhandled, isEmpty);
        expect(
          (await db.accountSyncDao.readState(owner, 'dm')).single.value,
          '{invalid',
        );
      },
    );
  });

  group('write / read', () {
    test(
      'structured adapter round-trips opaque addresses and signed source records',
      () async {
        final adapter = DriftAccountStateStorage(
          db.accountSyncDao,
          owner: owner,
          namespace: 'dm',
        );
        final event = await LocalNostrSigner('1'.padLeft(64, '0')).signEvent(
          Event(owner, 30078, [
            ['d', 'dm'],
          ], 'encrypted'),
        );
        final state = {
          'version': 1,
          'pending': true,
          'fieldTags': {'tuple': 'dm/field/${'d' * 64}'},
          'entries': <String, Object?>{},
          'events': [event!.toJson()],
        };
        await adapter.write(jsonEncode(state));
        expect(jsonDecode((await adapter.read())!), state);
      },
    );
  });

  group('seed', () {
    test(
      'legacy signed cache retires only after its source is migrated',
      () async {
        final signer = LocalNostrSigner('1'.padLeft(64, '0'));
        final account = (await signer.getPublicKey())!;
        final event = (await signer.signEvent(
          Event(account, 30078, [
            ['d', 'dm'],
          ], 'encrypted'),
        ))!;
        final key = 'account_state_dm_$account';
        await prefs.setString(key, jsonEncode([event.toJson()]));
        final repository = create(account);
        await repository.seed({});
        expect(prefs.getString(key), isNull);
        expect(
          (await db.accountSyncDao.readState(
            account,
            'dm',
          )).where((r) => r.section == 'events'),
          hasLength(1),
        );
        await repository.close();
      },
    );
  });

  group('close', () {
    test(
      'closing drains startup migration before explicit owner erasure',
      () async {
        final storage = _HeldStorage(
          DriftAccountStateStorage(
            db.accountSyncDao,
            owner: owner,
            namespace: 'dm',
          ),
        );
        final repository = AccountStateRepository(
          nostrClient: _Client(),
          sharedPreferences: prefs,
          pubkey: owner,
          signer: () => LocalNostrSigner('1'.padLeft(64, '0')),
          namespace: 'dm',
          storage: storage,
          perFieldSnapshots: true,
        );
        var closed = false;
        final closing = repository.close().then((_) => closed = true);
        await pumpEventQueue();
        expect(closed, false);
        storage.gate.complete();
        await closing;
        await db.accountSyncDao.clearAccount(owner);
        await pumpEventQueue();
        expect(await db.accountSyncDao.readState(owner, 'dm'), isEmpty);
      },
    );
  });

  group('setValues', () {
    test(
      'pending fields and null tombstones survive restart without preference history',
      () async {
        final first = create(owner);
        await first.setValues({
          'one': {
            'through': 100,
            'known': ['b' * 64],
          },
          'reset': null,
        });
        await first.close();
        final restarted = create(owner);
        await restarted.seed({});
        expect(restarted.hasPendingChanges, true);
        expect(restarted.value('one'), {
          'through': 100,
          'known': ['b' * 64],
        });
        expect(restarted.contains('reset'), true);
        expect(prefs.getKeys(), isEmpty);
        final other = create('c' * 64);
        await other.seed({});
        expect(other.values, isEmpty);
        await other.close();
        await restarted.close();
      },
    );
  });

  group('seed (legacy journal)', () {
    test(
      'readable legacy journal migrates before its source is removed',
      () async {
        const key = 'account_state_dm_';
        await prefs.setString(
          '$key${owner}_state',
          jsonEncode({
            'version': 1,
            'entries': {
              'reset': {'value': null, 'updated_at': 9},
            },
            'pending': true,
            'events': <Object>[],
          }),
        );
        final repository = create(owner);
        await repository.seed({});
        expect(repository.contains('reset'), true);
        expect(repository.hasPendingChanges, true);
        expect(prefs.getString('$key${owner}_state'), isNull);
        expect(
          (await db.accountSyncDao.readState(
            owner,
            'dm',
          )).map((r) => r.section),
          contains('entries'),
        );
        await repository.close();
      },
    );
  });

  group('setValue', () {
    test(
      'unreadable legacy input is preserved while new intent uses Drift',
      () async {
        final key = 'account_state_dm_${owner}_state';
        await prefs.setString(key, '{');
        final repository = create(owner);
        await repository.setValue('new', null);
        expect(prefs.getString(key), '{');
        expect(repository.contains('new'), true);
        await repository.close();
      },
    );
  });
}

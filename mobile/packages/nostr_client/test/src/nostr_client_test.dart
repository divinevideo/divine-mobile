import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:db_client/db_client.dart' hide Filter;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/utils/hash_util.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostr extends Mock implements Nostr {
  /// Drives the `timedOut` field of the record synthesized below.
  bool timedOut = false;

  /// Drives the `noRelaysParticipated` field of that same record — the SDK
  /// reporting that no relay took the REQ, which a connected-relay snapshot
  /// cannot see.
  bool noRelaysParticipated = false;

  /// What the client last asked for full relay settlement, so a test can pin
  /// that the flag is threaded down rather than dropped on the floor.
  bool? lastRequireAllRelaysSettled;

  /// Mirror of the real [Nostr.queryEvents]/[Nostr.queryEventsDetailed]
  /// relationship, inverted: the SDK delegates the list-returning method to
  /// the detailed one, so this double delegates the detailed one back to the
  /// list-returning method that tests stub. Tests that care about the timeout
  /// signal set [timedOut] instead of stubbing a second method.
  @override
  Future<({List<Event> events, bool timedOut, bool noRelaysParticipated})>
  queryEventsDetailed(
    List<Map<String, dynamic>> filters, {
    String? id,
    List<String>? tempRelays,
    List<int> relayTypes = RelayType.all,
    bool sendAfterAuth = false,
    Duration timeout = const Duration(seconds: 5),
    bool requireAllRelaysSettled = false,
  }) async {
    lastRequireAllRelaysSettled = requireAllRelaysSettled;
    final events = await queryEvents(
      filters,
      id: id,
      tempRelays: tempRelays,
      relayTypes: relayTypes,
      sendAfterAuth: sendAfterAuth,
      timeout: timeout,
    );
    return (
      events: events,
      timedOut: timedOut,
      noRelaysParticipated: noRelaysParticipated,
    );
  }
}

class _MockRelayManager extends Mock implements RelayManager {}

class _MockAppDbClient extends Mock implements AppDbClient {}

class _MockAppDatabase extends Mock implements AppDatabase {}

class _MockNostrEventsDao extends Mock implements NostrEventsDao {}

class _FakeEvent extends Fake implements Event {}

class _FakeFilter extends Fake implements Filter {}

class _FakeContactList extends Fake implements ContactList {}

class _FakeRelay extends Fake implements Relay {
  @override
  final String url = 'wss://fake.example.com';

  @override
  RelayStatus relayStatus = RelayStatus('wss://fake.example.com');
}

const testPublicKey =
    '82341f882b6eabcd2ba7f1ef90aad961cf074af15b9ef44a09f9d2a8fbfbe6a2';

Event _createTestEvent({
  String? id,
  String? pubkey,
  int? kind,
  String? content,
  int? createdAt,
}) {
  final eventPubkey = pubkey ?? testPublicKey;
  final eventKind = kind ?? EventKind.textNote;
  final eventContent = content ?? 'Test content';
  final event = Event(
    eventPubkey,
    eventKind,
    [],
    eventContent,
    createdAt: createdAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
  );
  if (id != null) {
    // Override the generated ID for testing
    event.id = id;
  }
  return event;
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NostrClient', () {
    late _MockNostr mockNostr;
    late _MockRelayManager mockRelayManager;
    late NostrClient client;

    setUpAll(() {
      registerFallbackValue(_FakeEvent());
      registerFallbackValue(_FakeFilter());
      registerFallbackValue(_FakeContactList());
      registerFallbackValue(_FakeRelay());
      registerFallbackValue(<Map<String, dynamic>>[]);
      registerFallbackValue(<String>[]);
      registerFallbackValue(RelayType.all);
      registerFallbackValue(RelayAddSource.automatic);
      registerFallbackValue(RelayRemoveSource.user);
      registerFallbackValue(const Duration(seconds: 10));
      registerFallbackValue(const CountResponse(count: 0));
    });

    setUp(() {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      Nip89ClientTag.resetForTest();
      mockNostr = _MockNostr();
      mockRelayManager = _MockRelayManager();

      // Set up default mock behavior
      when(() => mockNostr.publicKey).thenReturn(testPublicKey);
      when(() => mockNostr.beginClose()).thenReturn(null);
      when(() => mockNostr.close()).thenReturn(null);
      when(() => mockRelayManager.dispose()).thenAnswer((_) async {});
      // Default to having connected relays (tests can override if needed)
      when(
        () => mockRelayManager.connectedRelays,
      ).thenReturn(['wss://relay.example.com']);
      // Default: no environment lock (production behavior). Tests that
      // exercise the lock override specific URLs to false.
      when(() => mockRelayManager.isRelayAllowed(any())).thenReturn(true);
      when(
        () => mockRelayManager.defaultRelayUrl,
      ).thenReturn('wss://relay.example.com');

      client = NostrClient.forTesting(
        nostr: mockNostr,
        relayManager: mockRelayManager,
      );
    });

    tearDown(() {
      Nip89ClientTag.resetForTest();
      reset(mockNostr);
      reset(mockRelayManager);
    });
    group('constructor and properties', () {
      test('publicKey returns the nostr public key', () {
        expect(client.publicKey, equals(testPublicKey));
        verify(() => mockNostr.publicKey).called(1);
      });

      test('creates client without dbClient', () {
        final localMockRelayManager = _MockRelayManager();
        final clientWithoutDb = NostrClient.forTesting(
          nostr: mockNostr,
          relayManager: localMockRelayManager,
        );
        expect(clientWithoutDb.publicKey, equals(testPublicKey));
      });

      group('resolvePublicKey (#6813)', () {
        test('returns the cached key without asking the signer', () async {
          expect(await client.resolvePublicKey(), equals(testPublicKey));
          verifyNever(() => mockNostr.refreshPublicKey());
        });

        test('refreshes from the signer when the cache is empty', () async {
          // The signer acquired its key after the client initialized, so the
          // cache is stale — the refresh is what makes it visible.
          var cached = '';
          when(() => mockNostr.publicKey).thenAnswer((_) => cached);
          when(() => mockNostr.refreshPublicKey()).thenAnswer((_) async {
            cached = testPublicKey;
          });

          expect(await client.resolvePublicKey(), equals(testPublicKey));
          verify(() => mockNostr.refreshPublicKey()).called(1);
        });

        test('returns null when the signer still has no key', () async {
          when(() => mockNostr.publicKey).thenReturn('');
          when(() => mockNostr.refreshPublicKey()).thenAnswer((_) async {});

          expect(await client.resolvePublicKey(), isNull);
        });

        test('returns null when the signer refresh throws', () async {
          when(() => mockNostr.publicKey).thenReturn('');
          when(
            () => mockNostr.refreshPublicKey(),
          ).thenThrow(StateError('refresh failed'));

          expect(await client.resolvePublicKey(), isNull);
        });

        test('concurrent callers share a single signer refresh', () async {
          // A cache miss reaches the signer, and under NIP-55 that is a
          // user-visible Amber prompt — three repositories resolving the key
          // at startup must not raise three of them.
          var cached = '';
          final gate = Completer<void>();
          when(() => mockNostr.publicKey).thenAnswer((_) => cached);
          when(() => mockNostr.refreshPublicKey()).thenAnswer((_) async {
            await gate.future;
            cached = testPublicKey;
          });

          final calls = Future.wait([
            client.resolvePublicKey(),
            client.resolvePublicKey(),
            client.resolvePublicKey(),
          ]);
          gate.complete();

          expect(await calls, everyElement(equals(testPublicKey)));
          verify(() => mockNostr.refreshPublicKey()).called(1);
        });

        test(
          'a later miss refreshes again once the first has settled',
          () async {
            when(() => mockNostr.publicKey).thenReturn('');
            when(() => mockNostr.refreshPublicKey()).thenAnswer((_) async {});

            expect(await client.resolvePublicKey(), isNull);
            expect(await client.resolvePublicKey(), isNull);

            verify(() => mockNostr.refreshPublicKey()).called(2);
          },
        );

        test(
          'shares an initialize refresh with concurrent resolvers',
          () async {
            var cached = '';
            final gate = Completer<void>();
            when(() => mockNostr.publicKey).thenAnswer((_) => cached);
            when(() => mockNostr.refreshPublicKey()).thenAnswer((_) async {
              await gate.future;
              cached = testPublicKey;
            });
            when(() => mockRelayManager.initialize()).thenAnswer((_) async {});

            final initialization = client.initialize();
            final resolved = client.resolvePublicKey();
            gate.complete();

            await initialization;
            expect(await resolved, equals(testPublicKey));
            verify(() => mockNostr.refreshPublicKey()).called(1);
          },
        );
      });
    });

    group('initialize seeds known-verified event ids', () {
      late RelayPool realPool;

      setUp(() {
        RelayBase tempRelay(String url) => RelayBase(url, RelayStatus(url));
        realPool = RelayPool(mockNostr, <EventFilter>[], tempRelay);
        when(() => mockNostr.refreshPublicKey()).thenAnswer((_) async {});
        when(() => mockNostr.relayPool).thenReturn(realPool);
        when(mockRelayManager.initialize).thenAnswer((_) async {});
      });

      NostrClient buildClientWithDao(_MockNostrEventsDao dao) {
        final dbClient = _MockAppDbClient();
        final database = _MockAppDatabase();
        when(() => dbClient.database).thenReturn(database);
        when(() => database.nostrEventsDao).thenReturn(dao);
        return NostrClient.forTesting(
          nostr: mockNostr,
          relayManager: mockRelayManager,
          dbClient: dbClient,
        );
      }

      test('wires the pool lookup from persisted (id, sig) pairs', () async {
        final dao = _MockNostrEventsDao();
        when(
          dao.getRecentEventIdSigs,
        ).thenAnswer((_) async => [(id: 'idA', sig: 'sigA')]);
        final clientWithDb = buildClientWithDao(dao);

        await clientWithDb.initialize();

        final lookup = realPool.isKnownVerifiedEvent;
        expect(lookup, isNotNull);
        expect(lookup!('idA', 'sigA'), isTrue);
        // A known id carrying a different signature is not trusted — the id
        // does not commit to sig, so this must fall through to a full verify.
        expect(lookup('idA', 'other-sig'), isFalse);
        expect(lookup('never-seen', 'sigA'), isFalse);
      });

      test('leaves the lookup unset when there is no db client', () async {
        final clientWithoutDb = NostrClient.forTesting(
          nostr: mockNostr,
          relayManager: mockRelayManager,
        );

        await clientWithoutDb.initialize();

        expect(realPool.isKnownVerifiedEvent, isNull);
      });

      test('initialize still completes when seeding fails', () async {
        final dao = _MockNostrEventsDao();
        when(dao.getRecentEventIdSigs).thenThrow(Exception('boom'));
        final clientWithDb = buildClientWithDao(dao);

        await expectLater(clientWithDb.initialize(), completes);
        expect(realPool.isKnownVerifiedEvent, isNull);
      });
    });

    group('queryEvents', () {
      test('caps concurrent WebSocket queries and releases slots', () async {
        final originalMaxConcurrentQueries = NostrClient.maxConcurrentQueries;
        NostrClient.maxConcurrentQueries = 2;
        addTearDown(
          () => NostrClient.maxConcurrentQueries = originalMaxConcurrentQueries,
        );

        var activeQueries = 0;
        var maxActiveQueries = 0;
        final pendingQueries = Queue<Completer<List<Event>>>();

        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) {
          activeQueries++;
          if (activeQueries > maxActiveQueries) {
            maxActiveQueries = activeQueries;
          }
          final completer = Completer<List<Event>>();
          pendingQueries.add(completer);
          return completer.future.whenComplete(() => activeQueries--);
        });

        final results = [
          for (var i = 0; i < 4; i++)
            client
                .queryEvents(
                  [
                    Filter(kinds: const [1059]),
                  ],
                  useCache: false,
                )
                .then<Object>((events) => events.map((e) => e.id).toList())
                .catchError((Object _) => 'error'),
        ];

        await pumpEventQueue();

        expect(pendingQueries, hasLength(2));
        expect(activeQueries, 2);

        pendingQueries.removeFirst().complete([
          _createTestEvent(id: 'one', kind: 1059),
        ]);
        await pumpEventQueue();

        expect(pendingQueries, hasLength(2));
        expect(activeQueries, 2);

        pendingQueries.removeFirst().completeError(StateError('boom'));
        await pumpEventQueue();

        expect(pendingQueries, hasLength(2));
        expect(activeQueries, 2);

        pendingQueries.removeFirst().complete([
          _createTestEvent(id: 'three', kind: 1059),
        ]);
        pendingQueries.removeFirst().complete([
          _createTestEvent(id: 'four', kind: 1059),
        ]);

        await expectLater(
          Future.wait(results),
          completion([
            ['one'],
            'error',
            ['three'],
            ['four'],
          ]),
        );
        expect(maxActiveQueries, 2);
      });

      test(
        'reconnects before querying when no relays are connected (#5202)',
        () async {
          // A cold query (e.g. the DM history drain firing before the pool
          // connects) must reconnect first, mirroring publishEvent().
          when(() => mockRelayManager.connectedRelays).thenReturn([]);
          when(
            mockRelayManager.retryDisconnectedRelays,
          ).thenAnswer((_) async {});
          when(
            () => mockNostr.queryEvents(
              any(),
              id: any(named: 'id'),
              tempRelays: any(named: 'tempRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((_) async => <Event>[]);

          await client.queryEvents(
            [
              Filter(kinds: const [1059]),
            ],
            useCache: false,
          );

          verify(mockRelayManager.retryDisconnectedRelays).called(1);
        },
      );

      test('does not reconnect when relays are already connected', () async {
        // Default mock has a connected relay.
        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => <Event>[]);

        await client.queryEvents(
          [
            Filter(kinds: const [1059]),
          ],
          useCache: false,
        );

        verifyNever(mockRelayManager.retryDisconnectedRelays);
      });

      test(
        'does not reconnect when explicit tempRelays are provided',
        () async {
          when(() => mockRelayManager.connectedRelays).thenReturn([]);
          when(
            () => mockRelayManager.configuredRelays,
          ).thenReturn(['wss://relay.example.com']);
          when(
            mockRelayManager.retryDisconnectedRelays,
          ).thenAnswer((_) async {});
          when(
            () => mockNostr.queryEvents(
              any(),
              id: any(named: 'id'),
              tempRelays: any(named: 'tempRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((_) async => <Event>[]);

          await client.queryEvents(
            [
              Filter(kinds: const [1059]),
            ],
            tempRelays: const ['wss://temp.example.com'],
            useCache: false,
          );

          verifyNever(mockRelayManager.retryDisconnectedRelays);
        },
      );

      test(
        'reconnects before querying when every tempRelay is a disconnected '
        'pool relay (#8550)',
        () async {
          // The DM history drain dials the account's own kind-10050 inbox as
          // tempRelays, and for a divine account that list names the pool's
          // own relays. RelayPool resolves those to the pooled relay objects,
          // so once the pool has idled out nobody can take the REQ: the
          // tempRelays exemption must not skip the reconnect.
          when(() => mockRelayManager.connectedRelays).thenReturn([]);
          when(
            () => mockRelayManager.configuredRelays,
          ).thenReturn(['wss://relay.example.com']);
          when(
            mockRelayManager.retryDisconnectedRelays,
          ).thenAnswer((_) async {});
          when(
            () => mockNostr.queryEvents(
              any(),
              id: any(named: 'id'),
              tempRelays: any(named: 'tempRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((_) async => <Event>[]);

          await client.queryEvents(
            [
              Filter(kinds: const [1059]),
            ],
            // Trailing slash: the pool membership check has to normalize.
            tempRelays: const ['wss://relay.example.com/'],
            useCache: false,
          );

          verify(mockRelayManager.retryDisconnectedRelays).called(1);
        },
      );

      test(
        'does not reconnect when a tempRelay lies outside the pool, even '
        'with the pool disconnected',
        () async {
          // An outside relay can answer on its own connection, so a lookup
          // that names one keeps today's no-wait path.
          when(() => mockRelayManager.connectedRelays).thenReturn([]);
          when(
            () => mockRelayManager.configuredRelays,
          ).thenReturn(['wss://relay.example.com']);
          when(
            mockRelayManager.retryDisconnectedRelays,
          ).thenAnswer((_) async {});
          when(
            () => mockNostr.queryEvents(
              any(),
              id: any(named: 'id'),
              tempRelays: any(named: 'tempRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((_) async => <Event>[]);

          await client.queryEvents(
            [
              Filter(kinds: const [1059]),
            ],
            tempRelays: const [
              'wss://relay.example.com',
              'wss://temp.example.com',
            ],
            useCache: false,
          );

          verifyNever(mockRelayManager.retryDisconnectedRelays);
        },
      );
    });

    group('publishEvent', () {
      test('publishes event successfully', () async {
        final event = _createTestEvent();
        when(
          () => mockNostr.sendEvent(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => event);

        final result = await client.publishEvent(event);

        expect(result, isA<PublishSuccess>());
        expect((result as PublishSuccess).event, equals(event));
        verify(() => mockNostr.sendEvent(event)).called(1);
      });

      test('publishes event with target relays', () async {
        final event = _createTestEvent();
        final targetRelays = ['wss://relay1.example.com'];
        when(
          () => mockNostr.sendEvent(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => event);

        await client.publishEvent(event, targetRelays: targetRelays);

        verify(
          () => mockNostr.sendEvent(
            event,
            targetRelays: targetRelays,
            tempRelays: targetRelays,
          ),
        ).called(1);
      });

      test('publishes event to explicit target relays without connected '
          'pool relays', () async {
        final event = _createTestEvent();
        final targetRelays = ['wss://relay1.example.com'];
        when(() => mockRelayManager.connectedRelays).thenReturn([]);
        when(mockRelayManager.retryDisconnectedRelays).thenAnswer((_) async {});
        when(
          () => mockNostr.sendEvent(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => event);

        final result = await client.publishEvent(
          event,
          targetRelays: targetRelays,
        );

        expect(result, isA<PublishSuccess>());
        verifyNever(mockRelayManager.retryDisconnectedRelays);
        verify(
          () => mockNostr.sendEvent(
            event,
            targetRelays: targetRelays,
            tempRelays: targetRelays,
          ),
        ).called(1);
      });

      test('returns PublishFailed when sendEvent fails', () async {
        final event = _createTestEvent();
        when(
          () => mockNostr.sendEvent(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => null);

        final result = await client.publishEvent(event);

        expect(result, isA<PublishFailed>());
      });

      test(
        'drops targetRelays rejected by the environment host lock',
        () async {
          const envRelay = 'wss://relay.staging.divine.video';
          const crossEnvRelay = 'wss://relay.divine.video';
          final event = _createTestEvent();
          when(
            () => mockRelayManager.isRelayAllowed(envRelay),
          ).thenReturn(true);
          when(
            () => mockRelayManager.isRelayAllowed(crossEnvRelay),
          ).thenReturn(false);
          when(
            () => mockNostr.sendEvent(
              any(),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
            ),
          ).thenAnswer((_) async => event);

          await client.publishEvent(
            event,
            targetRelays: const [envRelay, crossEnvRelay],
          );

          final captured = verify(
            () => mockNostr.sendEvent(
              any(),
              targetRelays: captureAny(named: 'targetRelays'),
              tempRelays: any(named: 'tempRelays'),
            ),
          ).captured;
          expect(captured.single, equals(const [envRelay]));
        },
      );

      test('attempts reconnection when no relays connected', () async {
        final event = _createTestEvent();
        final connectedRelays = ['wss://relay1.example.com'];

        // Initially no relays connected
        when(() => mockRelayManager.connectedRelays).thenReturn([]);
        when(mockRelayManager.retryDisconnectedRelays).thenAnswer((_) async {
          // Simulate successful reconnection by updating connected relays
          when(
            () => mockRelayManager.connectedRelays,
          ).thenReturn(connectedRelays);
        });
        when(
          () => mockNostr.sendEvent(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => event);

        final result = await client.publishEvent(event);

        expect(result, isA<PublishSuccess>());
        expect((result as PublishSuccess).event, equals(event));
        verify(mockRelayManager.retryDisconnectedRelays).called(1);
        verify(() => mockNostr.sendEvent(event)).called(1);
      });

      test('returns PublishNoRelays when reconnection fails', () async {
        final event = _createTestEvent();

        // No relays connected before and after reconnection attempt
        when(() => mockRelayManager.connectedRelays).thenReturn([]);
        when(mockRelayManager.retryDisconnectedRelays).thenAnswer((_) async {});

        final result = await client.publishEvent(event);

        expect(result, isA<PublishNoRelays>());
        verify(mockRelayManager.retryDisconnectedRelays).called(1);
        verifyNever(
          () => mockNostr.sendEvent(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        );
      });

      test('does not attempt reconnection when relays are connected', () async {
        final event = _createTestEvent();
        final connectedRelays = ['wss://relay1.example.com'];

        when(
          () => mockRelayManager.connectedRelays,
        ).thenReturn(connectedRelays);
        when(
          () => mockNostr.sendEvent(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => event);

        final result = await client.publishEvent(event);

        expect(result, isA<PublishSuccess>());
        expect((result as PublishSuccess).event, equals(event));
        verifyNever(mockRelayManager.retryDisconnectedRelays);
        verify(() => mockNostr.sendEvent(event)).called(1);
      });

      group('optimistic cache rollback on reconnection failure', () {
        late _MockAppDbClient mockDbClient;
        late _MockAppDatabase mockDatabase;
        late _MockNostrEventsDao mockNostrEventsDao;
        late NostrClient clientWithCache;

        setUp(() {
          mockDbClient = _MockAppDbClient();
          mockDatabase = _MockAppDatabase();
          mockNostrEventsDao = _MockNostrEventsDao();

          when(() => mockDbClient.database).thenReturn(mockDatabase);
          when(
            () => mockDatabase.nostrEventsDao,
          ).thenReturn(mockNostrEventsDao);

          clientWithCache = NostrClient.forTesting(
            nostr: mockNostr,
            relayManager: mockRelayManager,
            dbClient: mockDbClient,
          );
        });

        tearDown(() {
          reset(mockDbClient);
          reset(mockDatabase);
          reset(mockNostrEventsDao);
        });

        test('rolls back optimistic cache when reconnection fails', () async {
          // Use a kind that DOES support optimistic caching
          // (Kind 1 = text note)
          final event = _createTestEvent(kind: EventKind.textNote);

          // No relays connected, reconnection fails
          when(() => mockRelayManager.connectedRelays).thenReturn([]);
          when(
            mockRelayManager.retryDisconnectedRelays,
          ).thenAnswer((_) async {});
          when(
            () => mockNostrEventsDao.upsertEvent(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockNostrEventsDao.deleteEventsByIds(any()),
          ).thenAnswer((_) async => 1);

          final result = await clientWithCache.publishEvent(event);

          expect(result, isA<PublishNoRelays>());
          // Should have optimistically cached the event
          verify(() => mockNostrEventsDao.upsertEvent(event)).called(1);
          // Should have rolled back the cache
          verify(
            () => mockNostrEventsDao.deleteEventsByIds([event.id]),
          ).called(1);
        });

        test(
          'does not roll back cache for replaceable events when reconnection '
          'fails',
          () async {
            // Use a replaceable event kind (Kind 0 = metadata)
            final event = _createTestEvent(kind: EventKind.metadata);

            // No relays connected, reconnection fails
            when(() => mockRelayManager.connectedRelays).thenReturn([]);
            when(
              mockRelayManager.retryDisconnectedRelays,
            ).thenAnswer((_) async {});
            when(
              () => mockNostrEventsDao.upsertEvent(any()),
            ).thenAnswer((_) async {});
            when(
              () => mockNostrEventsDao.deleteEventsByIds(any()),
            ).thenAnswer((_) async => 1);

            final result = await clientWithCache.publishEvent(event);

            expect(result, isA<PublishNoRelays>());
            // Should NOT have optimistically cached (replaceable events)
            verifyNever(() => mockNostrEventsDao.upsertEvent(any()));
            // Should NOT roll back (nothing was cached)
            verifyNever(() => mockNostrEventsDao.deleteEventsByIds(any()));
          },
        );

        test('continues normal flow after successful reconnection', () async {
          final event = _createTestEvent(kind: EventKind.textNote);
          final connectedRelays = ['wss://relay1.example.com'];

          // Initially no relays, but reconnection succeeds
          when(() => mockRelayManager.connectedRelays).thenReturn([]);
          when(mockRelayManager.retryDisconnectedRelays).thenAnswer((_) async {
            when(
              () => mockRelayManager.connectedRelays,
            ).thenReturn(connectedRelays);
          });
          when(
            () => mockNostr.sendEvent(
              any(),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
            ),
          ).thenAnswer((_) async => event);
          when(
            () => mockNostrEventsDao.upsertEvent(any()),
          ).thenAnswer((_) async {});

          final result = await clientWithCache.publishEvent(event);

          expect(result, isA<PublishSuccess>());
          expect((result as PublishSuccess).event, equals(event));
          // Should have optimistically cached
          verify(() => mockNostrEventsDao.upsertEvent(event)).called(1);
          // Should NOT have rolled back (send succeeded)
          verifyNever(() => mockNostrEventsDao.deleteEventsByIds(any()));
        });
      });
    });

    group('publishEventAwaitOk', () {
      PublishOutcome accepted(String eventId) => PublishOutcome(
        eventId: eventId,
        acceptedBy: const ['wss://relay.test'],
        rejectedBy: const {},
        noResponseFrom: const [],
      );

      PublishOutcome rejected(String eventId) => PublishOutcome(
        eventId: eventId,
        acceptedBy: const [],
        rejectedBy: const {'wss://relay.test': 'blocked: policy'},
        noResponseFrom: const [],
      );

      test('returns confirmed outcome when relay accepts the event', () async {
        final event = _createTestEvent();
        when(
          () => mockRelayManager.connectedRelays,
        ).thenReturn(['wss://relay.test']);
        when(
          () => mockNostr.sendEventAwaitOk(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => accepted(event.id));

        final outcome = await client.publishEventAwaitOk(event);

        expect(outcome.confirmed, isTrue);
        expect(outcome.acceptedBy, equals(['wss://relay.test']));
      });

      test('returns failed outcome and rolls back optimistic cache when relay '
          'rejects', () async {
        final mockDbClient = _MockAppDbClient();
        final mockDatabase = _MockAppDatabase();
        final mockNostrEventsDao = _MockNostrEventsDao();
        when(() => mockDbClient.database).thenReturn(mockDatabase);
        when(() => mockDatabase.nostrEventsDao).thenReturn(mockNostrEventsDao);
        when(
          () => mockNostrEventsDao.upsertEvent(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockNostrEventsDao.deleteEventsByIds(any()),
        ).thenAnswer((_) async => 1);

        final clientWithCache = NostrClient.forTesting(
          nostr: mockNostr,
          relayManager: mockRelayManager,
          dbClient: mockDbClient,
        );

        final event = _createTestEvent(kind: EventKind.textNote);
        when(
          () => mockRelayManager.connectedRelays,
        ).thenReturn(['wss://relay.test']);
        when(
          () => mockNostr.sendEventAwaitOk(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => rejected(event.id));

        final outcome = await clientWithCache.publishEventAwaitOk(event);

        expect(outcome.failed, isTrue);
        verify(() => mockNostrEventsDao.upsertEvent(event)).called(1);
        verify(
          () => mockNostrEventsDao.deleteEventsByIds([event.id]),
        ).called(1);
      });

      test('rolls back optimistic cache when SDK dispatch throws', () async {
        final mockDbClient = _MockAppDbClient();
        final mockDatabase = _MockAppDatabase();
        final mockNostrEventsDao = _MockNostrEventsDao();
        when(() => mockDbClient.database).thenReturn(mockDatabase);
        when(() => mockDatabase.nostrEventsDao).thenReturn(mockNostrEventsDao);
        when(
          () => mockNostrEventsDao.upsertEvent(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockNostrEventsDao.deleteEventsByIds(any()),
        ).thenAnswer((_) async => 1);

        final clientWithCache = NostrClient.forTesting(
          nostr: mockNostr,
          relayManager: mockRelayManager,
          dbClient: mockDbClient,
        );
        final event = _createTestEvent(kind: EventKind.reaction);
        final error = StateError('SDK dispatch failed');
        when(
          () => mockNostr.sendEventAwaitOk(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            timeout: any(named: 'timeout'),
          ),
        ).thenThrow(error);

        await expectLater(
          clientWithCache.publishEventAwaitOk(event),
          throwsA(same(error)),
        );

        verify(() => mockNostrEventsDao.upsertEvent(event)).called(1);
        verify(
          () => mockNostrEventsDao.deleteEventsByIds([event.id]),
        ).called(1);
      });

      test('returns failed outcome without attempting send when no relays are '
          'reachable', () async {
        final event = _createTestEvent();
        when(() => mockRelayManager.connectedRelays).thenReturn([]);
        when(mockRelayManager.retryDisconnectedRelays).thenAnswer((_) async {});

        final outcome = await client.publishEventAwaitOk(event);

        expect(outcome.failed, isTrue);
        expect(outcome.eventId, equals(event.id));
        verify(mockRelayManager.retryDisconnectedRelays).called(1);
        verifyNever(
          () => mockNostr.sendEventAwaitOk(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            timeout: any(named: 'timeout'),
          ),
        );
      });

      test('attempts explicit target relays without retrying disconnected pool '
          'relays', () async {
        final event = _createTestEvent();
        const targetRelays = ['wss://relay.divine.video'];
        const timeout = Duration(seconds: 5);
        when(() => mockRelayManager.connectedRelays).thenReturn([]);
        when(mockRelayManager.retryDisconnectedRelays).thenAnswer((_) async {});
        when(
          () => mockNostr.sendEventAwaitOk(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => accepted(event.id));

        final outcome = await client.publishEventAwaitOk(
          event,
          targetRelays: targetRelays,
          timeout: timeout,
        );

        expect(outcome.confirmed, isTrue);
        verifyNever(mockRelayManager.retryDisconnectedRelays);
        verify(
          () => mockNostr.sendEventAwaitOk(
            event,
            targetRelays: targetRelays,
            tempRelays: targetRelays,
            timeout: timeout,
          ),
        ).called(1);
      });

      test(
        'removes target events from cache after confirmed deletion',
        () async {
          final mockDbClient = _MockAppDbClient();
          final mockDatabase = _MockAppDatabase();
          final mockNostrEventsDao = _MockNostrEventsDao();
          when(() => mockDbClient.database).thenReturn(mockDatabase);
          when(
            () => mockDatabase.nostrEventsDao,
          ).thenReturn(mockNostrEventsDao);
          when(
            () => mockNostrEventsDao.deleteEventsByIds(any()),
          ).thenAnswer((_) async => 1);

          final clientWithCache = NostrClient.forTesting(
            nostr: mockNostr,
            relayManager: mockRelayManager,
            dbClient: mockDbClient,
          );

          final deleteEvent = Event(
            testPublicKey,
            EventKind.eventDeletion,
            [
              ['e', 'target_event_id'],
              ['k', '34236'],
            ],
            'deleted',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          )..sig = 'test_sig';

          when(
            () => mockRelayManager.connectedRelays,
          ).thenReturn(['wss://relay.test']);
          when(
            () => mockNostr.sendEventAwaitOk(
              any(),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((_) async => accepted(deleteEvent.id));

          final outcome = await clientWithCache.publishEventAwaitOk(
            deleteEvent,
          );

          expect(outcome.confirmed, isTrue);
          verify(
            () => mockNostrEventsDao.deleteEventsByIds(['target_event_id']),
          ).called(1);
        },
      );

      test(
        'removes addressable target events from cache after confirmed deletion',
        () async {
          final mockDbClient = _MockAppDbClient();
          final mockDatabase = _MockAppDatabase();
          final mockNostrEventsDao = _MockNostrEventsDao();
          when(() => mockDbClient.database).thenReturn(mockDatabase);
          when(
            () => mockDatabase.nostrEventsDao,
          ).thenReturn(mockNostrEventsDao);

          final cachedReplacement = Event(
            testPublicKey,
            34236,
            [
              ['d', 'shared-vine-id'],
            ],
            'replacement',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          )..id = 'replacement_event_id';
          when(
            () => mockNostrEventsDao.getEventsByFilter(any()),
          ).thenAnswer((_) async => [cachedReplacement]);
          when(
            () => mockNostrEventsDao.deleteEventsByIds(any()),
          ).thenAnswer((_) async => 2);

          final clientWithCache = NostrClient.forTesting(
            nostr: mockNostr,
            relayManager: mockRelayManager,
            dbClient: mockDbClient,
          );

          const addressableId = '34236:$testPublicKey:shared-vine-id';
          final deleteEvent = Event(
            testPublicKey,
            EventKind.eventDeletion,
            [
              ['e', 'target_event_id'],
              ['a', addressableId],
              ['k', '34236'],
            ],
            'deleted',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          )..sig = 'test_sig';

          when(
            () => mockRelayManager.connectedRelays,
          ).thenReturn(['wss://relay.test']);
          when(
            () => mockNostr.sendEventAwaitOk(
              any(),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((_) async => accepted(deleteEvent.id));

          final outcome = await clientWithCache.publishEventAwaitOk(
            deleteEvent,
          );

          expect(outcome.confirmed, isTrue);
          final capturedFilter =
              verify(
                    () => mockNostrEventsDao.getEventsByFilter(captureAny()),
                  ).captured.single
                  as Filter;
          expect(capturedFilter.kinds, equals([34236]));
          expect(capturedFilter.authors, equals([testPublicKey]));
          expect(capturedFilter.d, equals(['shared-vine-id']));
          expect(capturedFilter.until, equals(deleteEvent.createdAt));
          verify(
            () => mockNostrEventsDao.deleteEventsByIds(
              any(
                that: unorderedEquals([
                  'target_event_id',
                  'replacement_event_id',
                ]),
              ),
            ),
          ).called(1);
        },
      );

      test(
        'ignores addressable deletion tags from a different pubkey',
        () async {
          final mockDbClient = _MockAppDbClient();
          final mockDatabase = _MockAppDatabase();
          final mockNostrEventsDao = _MockNostrEventsDao();
          when(() => mockDbClient.database).thenReturn(mockDatabase);
          when(
            () => mockDatabase.nostrEventsDao,
          ).thenReturn(mockNostrEventsDao);

          final clientWithCache = NostrClient.forTesting(
            nostr: mockNostr,
            relayManager: mockRelayManager,
            dbClient: mockDbClient,
          );

          const victimPubkey =
              'ffffffffffffffffffffffffffffffff'
              'ffffffffffffffffffffffffffffffff';
          const addressableId = '34236:$victimPubkey:shared-vine-id';
          final deleteEvent = Event(
            testPublicKey,
            EventKind.eventDeletion,
            [
              ['a', addressableId],
              ['k', '34236'],
            ],
            'deleted',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          )..sig = 'test_sig';

          when(
            () => mockRelayManager.connectedRelays,
          ).thenReturn(['wss://relay.test']);
          when(
            () => mockNostr.sendEventAwaitOk(
              any(),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((_) async => accepted(deleteEvent.id));

          final outcome = await clientWithCache.publishEventAwaitOk(
            deleteEvent,
          );

          expect(outcome.confirmed, isTrue);
          verifyNever(() => mockNostrEventsDao.getEventsByFilter(any()));
          verifyNever(() => mockNostrEventsDao.deleteEventsByIds(any()));
        },
      );

      test(
        'keeps confirmed deletion publishes successful when cache cleanup '
        'fails',
        () async {
          final mockDbClient = _MockAppDbClient();
          final mockDatabase = _MockAppDatabase();
          final mockNostrEventsDao = _MockNostrEventsDao();
          when(() => mockDbClient.database).thenReturn(mockDatabase);
          when(
            () => mockDatabase.nostrEventsDao,
          ).thenReturn(mockNostrEventsDao);
          when(
            () => mockNostrEventsDao.deleteEventsByIds(any()),
          ).thenThrow(StateError('database unavailable'));

          final clientWithCache = NostrClient.forTesting(
            nostr: mockNostr,
            relayManager: mockRelayManager,
            dbClient: mockDbClient,
          );

          final deleteEvent = Event(
            testPublicKey,
            EventKind.eventDeletion,
            [
              ['e', 'target_event_id'],
              ['k', '34236'],
            ],
            'deleted',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          )..sig = 'test_sig';

          when(
            () => mockRelayManager.connectedRelays,
          ).thenReturn(['wss://relay.test']);
          when(
            () => mockNostr.sendEventAwaitOk(
              any(),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((_) async => accepted(deleteEvent.id));

          final outcome = await clientWithCache.publishEventAwaitOk(
            deleteEvent,
          );

          expect(outcome.confirmed, isTrue);
        },
      );
    });

    group('queryEvents', () {
      test('queries events via WebSocket', () async {
        final filters = [
          Filter(kinds: [EventKind.textNote], limit: 10),
        ];
        final events = [_createTestEvent(), _createTestEvent()];

        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => events);

        final result = await client.queryEvents(filters);

        expect(result, equals(events));
        verify(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).called(1);
      });

      test('returns empty list when WebSocket returns empty', () async {
        final filters = [
          Filter(kinds: [EventKind.textNote], limit: 10),
        ];

        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => []);

        final result = await client.queryEvents(filters);

        expect(result, isEmpty);
      });

      test('queries with multiple filters', () async {
        final filters = [
          Filter(kinds: [EventKind.textNote], limit: 10),
          Filter(kinds: [EventKind.metadata], limit: 5),
        ];
        final events = [_createTestEvent()];

        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => events);

        final result = await client.queryEvents(filters);

        expect(result, equals(events));
      });

      test('passes all parameters to WebSocket query', () async {
        final filters = [
          Filter(kinds: [EventKind.textNote], limit: 10),
        ];
        final events = [_createTestEvent()];
        final tempRelays = ['wss://temp.example.com'];

        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => events);

        await client.queryEvents(
          filters,
          subscriptionId: 'test-sub',
          tempRelays: tempRelays,
          relayTypes: [RelayType.normal],
          sendAfterAuth: true,
        );

        verify(
          () => mockNostr.queryEvents(
            any(),
            id: 'test-sub',
            tempRelays: tempRelays,
            relayTypes: [RelayType.normal],
            sendAfterAuth: true,
          ),
        ).called(1);
      });

      test(
        'returns empty without touching cache or relays when already '
        'disposed',
        () async {
          // The upfront isDisposed early-return: a disposed client must not
          // read the cache or attempt a reconnect. connectedRelays is empty
          // so the reconnect branch WOULD fire if the early-return were gone.
          final mockDbClient = _MockAppDbClient();
          final mockDatabase = _MockAppDatabase();
          final dao = _MockNostrEventsDao();
          when(() => mockDbClient.database).thenReturn(mockDatabase);
          when(() => mockDatabase.nostrEventsDao).thenReturn(dao);
          when(
            () => dao.getEventsByFilter(any()),
          ).thenAnswer((_) async => <Event>[]);
          when(() => mockRelayManager.connectedRelays).thenReturn([]);
          when(
            mockRelayManager.retryDisconnectedRelays,
          ).thenAnswer((_) async {});
          when(() => mockNostr.unsubscribe(any())).thenReturn(null);

          final clientWithCache = NostrClient.forTesting(
            nostr: mockNostr,
            relayManager: mockRelayManager,
            dbClient: mockDbClient,
          );
          await clientWithCache.dispose();

          final result = await clientWithCache.queryEvents([
            Filter(kinds: [EventKind.textNote], limit: 10),
          ]);

          expect(result, isEmpty);
          verifyNever(() => dao.getEventsByFilter(any()));
          verifyNever(mockRelayManager.retryDisconnectedRelays);
          verifyNever(
            () => mockNostr.queryEvents(
              any(),
              id: any(named: 'id'),
              tempRelays: any(named: 'tempRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
            ),
          );
        },
      );

      test(
        'skips the WebSocket query without throwing when dispose races the '
        'cache read (pooled path)',
        () async {
          // Park the query at the cache await, then dispose() mid-flight so
          // it resumes past the upfront isDisposed check and reaches the
          // pre-query guard with a closed pool. Deleting that guard makes
          // this throw "withResource() may not be called on a closed Pool".
          final mockDbClient = _MockAppDbClient();
          final mockDatabase = _MockAppDatabase();
          final dao = _MockNostrEventsDao();
          when(() => mockDbClient.database).thenReturn(mockDatabase);
          when(() => mockDatabase.nostrEventsDao).thenReturn(dao);

          final cacheGate = Completer<List<Event>>();
          when(
            () => dao.getEventsByFilter(any()),
          ).thenAnswer((_) => cacheGate.future);
          when(() => mockNostr.unsubscribe(any())).thenReturn(null);

          final clientWithCache = NostrClient.forTesting(
            nostr: mockNostr,
            relayManager: mockRelayManager,
            dbClient: mockDbClient,
          );

          final pending = clientWithCache.queryEvents([
            Filter(kinds: [EventKind.textNote], limit: 10),
          ]);
          await pumpEventQueue();
          // Confirm we actually parked in the race window.
          verify(() => dao.getEventsByFilter(any())).called(1);

          await clientWithCache.dispose();
          cacheGate.complete([_createTestEvent(id: 'cached')]);

          final result = await pending;

          // The already-read cache result survives; the network is skipped.
          expect(result.map((e) => e.id), ['cached']);
          verifyNever(
            () => mockNostr.queryEvents(
              any(),
              id: any(named: 'id'),
              tempRelays: any(named: 'tempRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
            ),
          );
        },
      );

      test(
        'skips the WebSocket query when dispose races the cache read '
        '(non-pooled useQueryPool: false path)',
        () async {
          // Same race for the queryUsers path. With the old
          // `useQueryPool && _queryPool.isClosed` guard this fell through to
          // `_nostr.queryEvents` on a closed client, re-opening WebSockets to
          // the search relays. verifyNever below is what catches that.
          final mockDbClient = _MockAppDbClient();
          final mockDatabase = _MockAppDatabase();
          final dao = _MockNostrEventsDao();
          when(() => mockDbClient.database).thenReturn(mockDatabase);
          when(() => mockDatabase.nostrEventsDao).thenReturn(dao);

          final cacheGate = Completer<List<Event>>();
          when(
            () => dao.getEventsByFilter(any()),
          ).thenAnswer((_) => cacheGate.future);
          when(() => mockNostr.unsubscribe(any())).thenReturn(null);

          final clientWithCache = NostrClient.forTesting(
            nostr: mockNostr,
            relayManager: mockRelayManager,
            dbClient: mockDbClient,
          );

          final pending = clientWithCache.queryEvents(
            [
              Filter(kinds: [EventKind.metadata], search: 'alice', limit: 100),
            ],
            tempRelays: const ['wss://search.example.com'],
            useQueryPool: false,
          );
          await pumpEventQueue();
          verify(() => dao.getEventsByFilter(any())).called(1);

          await clientWithCache.dispose();
          cacheGate.complete(const []);

          final result = await pending;

          expect(result, isEmpty);
          verifyNever(
            () => mockNostr.queryEvents(
              any(),
              id: any(named: 'id'),
              tempRelays: any(named: 'tempRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
            ),
          );
        },
      );
    });

    // Callers that must not read an empty result as "this account has no
    // content" — account deletion's relay sweep is the motivating one — need
    // to tell an empty answer apart from an answer that never arrived.
    group('queryEventsDetailed', () {
      Filter textNoteFilter() => Filter(kinds: [EventKind.textNote], limit: 10);

      void stubWebSocketEvents(List<Event> events) {
        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => events);
      }

      test(
        'reports a healthy query as neither timed out nor relayless',
        () async {
          final events = [_createTestEvent()];
          stubWebSocketEvents(events);

          final result = await client.queryEventsDetailed([textNoteFilter()]);

          expect(result.events, equals(events));
          expect(result.timedOut, isFalse);
          expect(result.noRelays, isFalse);
        },
      );

      test('does not demand full relay settlement by default', () async {
        stubWebSocketEvents([]);

        await client.queryEventsDetailed([textNoteFilter()]);

        expect(mockNostr.lastRequireAllRelaysSettled, isFalse);
      });

      test('forwards a caller demand for full relay settlement', () async {
        // Dropping this on the floor is silent: the query still succeeds, it
        // just answers on the relays that replied first — which is what lets a
        // replacing publish truncate a replaceable list.
        stubWebSocketEvents([]);

        await client.queryEventsDetailed(
          [textNoteFilter()],
          requireAllRelaysSettled: true,
        );

        expect(mockNostr.lastRequireAllRelaysSettled, isTrue);
      });

      test(
        'reports a closed query pool as inconclusive for a full-settlement '
        'caller',
        () async {
          // Same dispose race as the pooled-path test above: park at the cache
          // await, dispose so the pool closes, then resume into the pre-query
          // guard. The websocket leg is skipped there, so nothing asked the
          // relays anything — and an answer nobody was asked for must not
          // reach a caller that is about to replace what it read.
          final mockDbClient = _MockAppDbClient();
          final mockDatabase = _MockAppDatabase();
          final dao = _MockNostrEventsDao();
          when(() => mockDbClient.database).thenReturn(mockDatabase);
          when(() => mockDatabase.nostrEventsDao).thenReturn(dao);

          final cacheGate = Completer<List<Event>>();
          when(
            () => dao.getEventsByFilter(any()),
          ).thenAnswer((_) => cacheGate.future);
          when(() => mockNostr.unsubscribe(any())).thenReturn(null);

          final clientWithCache = NostrClient.forTesting(
            nostr: mockNostr,
            relayManager: mockRelayManager,
            dbClient: mockDbClient,
          );

          final pending = clientWithCache.queryEventsDetailed(
            [textNoteFilter()],
            requireAllRelaysSettled: true,
          );
          await pumpEventQueue();
          verify(() => dao.getEventsByFilter(any())).called(1);

          await clientWithCache.dispose();
          cacheGate.complete(const []);

          final result = await pending;

          expect(result.events, isEmpty);
          expect(
            result.noRelays,
            isFalse,
            reason: 'relays are connected, so nothing else flags this answer',
          );
          expect(
            result.timedOut,
            isTrue,
            reason:
                'the skipped websocket leg otherwise reads as "the relays '
                'answered and hold nothing", which is what lets the next '
                'publish replace a kind 10003 it never read',
          );
        },
      );

      test('propagates the relay timeout alongside partial events', () async {
        final events = [_createTestEvent()];
        stubWebSocketEvents(events);
        mockNostr.timedOut = true;

        final result = await client.queryEventsDetailed([textNoteFilter()]);

        // Events that did arrive are still returned — the caller decides what
        // a partial answer means.
        expect(result.events, equals(events));
        expect(result.timedOut, isTrue);
        expect(
          result.noRelays,
          isFalse,
          reason:
              'the relays were reachable and slow. bookmark_service tests '
              'noRelays first, so conflating the two tells the user their '
              'relays are unreachable when they are not',
        );
      });

      test('reports noRelays when nothing reconnected', () async {
        when(() => mockRelayManager.connectedRelays).thenReturn([]);
        when(mockRelayManager.retryDisconnectedRelays).thenAnswer((_) async {});
        stubWebSocketEvents([]);

        final result = await client.queryEventsDetailed([textNoteFilter()]);

        expect(result.events, isEmpty);
        expect(result.noRelays, isTrue);
      });

      test(
        'reports noRelays when no relay took the REQ despite being connected',
        () async {
          // The pre-flight snapshot cannot see this: a write-only relay, or
          // one whose socket died since its last status update, is still
          // reported as connected. Only the fan-out knows nothing was asked.
          stubWebSocketEvents([]);
          mockNostr.noRelaysParticipated = true;

          final result = await client.queryEventsDetailed([textNoteFilter()]);

          expect(
            mockRelayManager.connectedRelays,
            isNotEmpty,
            reason: 'otherwise the pre-flight check would have flagged it',
          );
          expect(result.events, isEmpty);
          expect(
            result.noRelays,
            isTrue,
            reason:
                'reported as a timeout, this reads as "the relays were '
                'reachable and slow" — the caller retries instead of telling '
                'the user their relays are unreachable',
          );
        },
      );

      test('reports noRelays on a disposed client', () async {
        await client.dispose();

        final result = await client.queryEventsDetailed([textNoteFilter()]);

        expect(result.events, isEmpty);
        expect(result.noRelays, isTrue);
        expect(result.timedOut, isFalse);
      });

      test(
        'queryEvents still returns partial events after a timeout',
        () async {
          final events = [_createTestEvent(), _createTestEvent()];
          stubWebSocketEvents(events);
          mockNostr.timedOut = true;

          // The simple form drops the timeout signal, but must not drop the
          // events that arrived before it.
          expect(await client.queryEvents([textNoteFilter()]), equals(events));
        },
      );

      test(
        'drops websocket events that do not match any requested filter',
        () async {
          final matching = _createTestEvent(kind: EventKind.textNote);
          final offFilter = _createTestEvent(kind: EventKind.relayListMetadata);
          stubWebSocketEvents([offFilter, matching]);

          final result = await client.queryEventsDetailed([textNoteFilter()]);

          expect(result.events, [matching]);
        },
      );

      test(
        'drops cached events that do not match the requested filter',
        () async {
          final mockDbClient = _MockAppDbClient();
          final mockDatabase = _MockAppDatabase();
          final dao = _MockNostrEventsDao();
          when(() => mockDbClient.database).thenReturn(mockDatabase);
          when(() => mockDatabase.nostrEventsDao).thenReturn(dao);

          final matching = _createTestEvent(kind: EventKind.textNote);
          final offFilter = _createTestEvent(kind: EventKind.relayListMetadata);
          // A row the cache holds but this query did not ask for — what an
          // older build persisted before the gate existed, or what one of the
          // other writers into this table put there.
          when(
            () => dao.getEventsByFilter(any()),
          ).thenAnswer((_) async => [offFilter, matching]);

          final clientWithCache = NostrClient.forTesting(
            nostr: mockNostr,
            relayManager: mockRelayManager,
            dbClient: mockDbClient,
          );
          stubWebSocketEvents([]);

          final result = await clientWithCache.queryEventsDetailed([
            textNoteFilter(),
          ]);

          expect(
            result.events,
            [matching],
            reason:
                'the cache leg is held to the same filter as the network leg',
          );
        },
      );
    });

    group('fetchEventById', () {
      test('fetches event via WebSocket', () async {
        const eventId = 'test-event-id';
        final event = _createTestEvent(id: eventId);

        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => [event]);

        final result = await client.fetchEventById(eventId);

        expect(result, equals(event));
      });

      test('uses provided relayUrl', () async {
        const eventId = 'test-event-id';
        const relayUrl = 'wss://relay.example.com';
        final event = _createTestEvent(id: eventId);

        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => [event]);

        await client.fetchEventById(eventId, relayUrl: relayUrl);

        verify(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: [relayUrl],
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).called(1);
      });

      test('returns null when no events found', () async {
        const eventId = 'nonexistent-id';

        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => []);

        final result = await client.fetchEventById(eventId);

        expect(result, isNull);
      });
    });

    group('fetchProfile', () {
      test('fetches profile via WebSocket', () async {
        const pubkey = testPublicKey;
        final profileEvent = _createTestEvent(
          pubkey: pubkey,
          kind: EventKind.metadata,
          content: '{"name":"Test User"}',
        );

        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => [profileEvent]);

        final result = await client.fetchProfile(pubkey);

        expect(result, equals(profileEvent));
      });

      test('returns null when no profile found', () async {
        const pubkey = testPublicKey;

        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => []);

        final result = await client.fetchProfile(pubkey);

        expect(result, isNull);
      });
    });

    group('subscribe NIP-09 auto-cache suppression', () {
      // NIP-71 addressable short video (parameterized replaceable).
      const addressableShortVideoKind = 34236;

      late _MockNostrEventsDao mockNostrEventsDao;
      late NostrClient clientWithCache;

      /// Subscribes and returns the relay callback the SDK was handed, so a
      /// test can deliver events exactly as a relay would.
      void Function(Event) subscribeAndCaptureRelayCallback() {
        when(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
            onClosed: any(named: 'onClosed'),
          ),
        ).thenReturn('test-sub-id');

        clientWithCache.subscribe([
          Filter(kinds: [addressableShortVideoKind], limit: 10),
        ]);

        final captured = verify(
          () => mockNostr.subscribe(
            any(),
            captureAny(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
            onClosed: any(named: 'onClosed'),
          ),
        ).captured.single;
        return captured as void Function(Event);
      }

      Event videoEvent({
        String? id,
        List<List<String>>? tags,
        String? pubkey,
        int createdAt = 1000,
      }) {
        final event = Event(
          pubkey ?? testPublicKey,
          addressableShortVideoKind,
          tags ??
              [
                ['d', 'clip-1'],
              ],
          'a video',
          createdAt: createdAt,
        );
        if (id != null) event.id = id;
        return event;
      }

      Event deletionEvent(
        List<List<String>> tags, {
        String? pubkey,
        int createdAt = 2000,
      }) => Event(
        pubkey ?? testPublicKey,
        EventKind.eventDeletion,
        tags,
        'deleted',
        createdAt: createdAt,
      );

      setUp(() {
        final mockDbClient = _MockAppDbClient();
        final mockDatabase = _MockAppDatabase();
        mockNostrEventsDao = _MockNostrEventsDao();
        when(() => mockDbClient.database).thenReturn(mockDatabase);
        when(() => mockDatabase.nostrEventsDao).thenReturn(mockNostrEventsDao);
        when(
          () => mockNostrEventsDao.upsertEvent(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockNostrEventsDao.deleteEventsByIds(any()),
        ).thenAnswer((_) async => 1);
        when(
          () => mockNostrEventsDao.getEventsByFilter(
            any(),
            sortBy: any(named: 'sortBy'),
          ),
        ).thenAnswer((_) async => <Event>[]);
        when(() => mockRelayManager.connectedRelays).thenReturn([
          'wss://relay.test',
        ]);

        clientWithCache = NostrClient.forTesting(
          nostr: mockNostr,
          relayManager: mockRelayManager,
          dbClient: mockDbClient,
        );
      });

      test(
        'does not re-cache an event a Kind 5 already removed by id',
        () async {
          final onEvent = subscribeAndCaptureRelayCallback();
          final video = videoEvent(id: 'a' * 64);

          onEvent(
            deletionEvent([
              ['e', video.id],
            ]),
          );
          await pumpEventQueue();

          // A relay that never saw the deletion redelivers the same event.
          onEvent(video);

          verifyNever(() => mockNostrEventsDao.upsertEvent(video));
        },
      );

      test(
        'does not re-cache an edit of a coordinate a Kind 5 removed',
        () async {
          final onEvent = subscribeAndCaptureRelayCallback();

          onEvent(
            deletionEvent([
              [
                'a',
                '$addressableShortVideoKind:$testPublicKey:clip-1',
              ],
            ]),
          );
          await pumpEventQueue();

          // An edit carries a new event id but the same pubkey:d-tag identity.
          final edited = videoEvent(id: 'b' * 64);
          onEvent(edited);

          verifyNever(() => mockNostrEventsDao.upsertEvent(edited));
        },
      );

      test('still caches events that were never tombstoned', () async {
        final onEvent = subscribeAndCaptureRelayCallback();

        onEvent(
          deletionEvent([
            ['e', 'a' * 64],
          ]),
        );
        await pumpEventQueue();

        final other = videoEvent(
          id: 'c' * 64,
          tags: [
            ['d', 'clip-2'],
          ],
        );
        onEvent(other);

        verify(() => mockNostrEventsDao.upsertEvent(other)).called(1);
      });

      test(
        'ignores an `e` tag from someone other than the event author',
        () async {
          final onEvent = subscribeAndCaptureRelayCallback();
          final video = videoEvent(id: 'a' * 64);

          // NIP-09: a client MUST check the referenced event's pubkey against
          // the deletion request's. Relays are not authoritative here, and
          // inbound REQ filters are not enforced client-side, so any connected
          // relay can land a forged deletion on an open subscription.
          onEvent(
            deletionEvent([
              ['e', video.id],
            ], pubkey: 'f' * 64),
          );
          await pumpEventQueue();

          onEvent(video);

          verify(() => mockNostrEventsDao.upsertEvent(video)).called(1);
        },
      );

      test(
        'caches a coordinate republished after the deletion request',
        () async {
          final onEvent = subscribeAndCaptureRelayCallback();

          onEvent(
            deletionEvent([
              ['a', '$addressableShortVideoKind:$testPublicKey:clip-1'],
            ], createdAt: 3000),
          );
          await pumpEventQueue();

          // NIP-09 scopes an `a` deletion to versions up to its own created_at,
          // so a later version under the same coordinate is not covered.
          final republished = videoEvent(id: 'e' * 64, createdAt: 5000);
          onEvent(republished);

          verify(() => mockNostrEventsDao.upsertEvent(republished)).called(1);
        },
      );

      test(
        'still skips a coordinate version older than the deletion request',
        () async {
          final onEvent = subscribeAndCaptureRelayCallback();

          onEvent(
            deletionEvent([
              ['a', '$addressableShortVideoKind:$testPublicKey:clip-1'],
            ], createdAt: 3000),
          );
          await pumpEventQueue();

          // Default created_at (1000) predates the deletion above (3000).
          final older = videoEvent(id: 'f' * 64);
          onEvent(older);

          verifyNever(() => mockNostrEventsDao.upsertEvent(older));
        },
      );

      test(
        'skips a coordinate version signed in the deletion second',
        () async {
          final onEvent = subscribeAndCaptureRelayCallback();

          onEvent(
            deletionEvent([
              ['a', '$addressableShortVideoKind:$testPublicKey:clip-1'],
            ], createdAt: 3000),
          );
          await pumpEventQueue();

          // "up to created_at" is inclusive, and _deleteCachedEventsForDeletion
          // passes the same value as `until`, which the DAO maps to
          // `created_at <= ?`. If this side were exclusive the auto-cache would
          // write back the very row that purge just deleted.
          final boundary = videoEvent(id: '1' * 64, createdAt: 3000);
          onEvent(boundary);

          verifyNever(() => mockNostrEventsDao.upsertEvent(boundary));
        },
      );

      test(
        'keeps the newest bound when an older deletion arrives second',
        () async {
          final onEvent = subscribeAndCaptureRelayCallback();

          // NIP-09 has relays serve deletion requests indefinitely, so a
          // cold-start flood can deliver an old Kind 5 after a newer one
          // for the same coordinate.
          onEvent(
            deletionEvent([
              ['a', '$addressableShortVideoKind:$testPublicKey:clip-1'],
            ], createdAt: 3000),
          );
          await pumpEventQueue();
          onEvent(
            deletionEvent([
              ['a', '$addressableShortVideoKind:$testPublicKey:clip-1'],
            ], createdAt: 1000),
          );
          await pumpEventQueue();

          final covered = videoEvent(id: '2' * 64, createdAt: 2000);
          onEvent(covered);

          verifyNever(() => mockNostrEventsDao.upsertEvent(covered));
        },
      );
    });

    group('subscribe', () {
      test('creates subscription and returns stream', () {
        final filters = [
          Filter(kinds: [EventKind.textNote], limit: 10),
        ];

        when(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
            onClosed: any(named: 'onClosed'),
          ),
        ).thenReturn('test-sub-id');

        final stream = client.subscribe(filters);

        expect(stream, isA<Stream<Event>>());
        verify(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
            onClosed: any(named: 'onClosed'),
          ),
        ).called(1);
      });

      test(
        'closeOnEose releases the relay subscription and closes the stream',
        () async {
          void Function()? onEose;
          when(
            () => mockNostr.subscribe(
              any(),
              any(),
              id: any(named: 'id'),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
              onEose: any(named: 'onEose'),
              onClosed: any(named: 'onClosed'),
            ),
          ).thenAnswer((invocation) {
            onEose = invocation.namedArguments[#onEose] as void Function()?;
            return invocation.namedArguments[#id] as String;
          });
          when(() => mockNostr.unsubscribe(any())).thenReturn(null);

          final stream = client.subscribe(
            [
              Filter(kinds: [EventKind.textNote]),
            ],
            closeOnEose: true,
          );
          final done = expectLater(stream, emitsDone);

          onEose!();

          await done;
          verify(() => mockNostr.unsubscribe(any())).called(1);
          expect(client.activeSubscriptionCount, 0);
        },
      );

      test('EOSE preserves long-lived subscriptions by default', () async {
        void Function()? onEose;
        when(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
            onClosed: any(named: 'onClosed'),
          ),
        ).thenAnswer((invocation) {
          onEose = invocation.namedArguments[#onEose] as void Function()?;
          return invocation.namedArguments[#id] as String;
        });
        when(() => mockNostr.unsubscribe(any())).thenReturn(null);

        var done = false;
        final subscription = client
            .subscribe([
              Filter(kinds: [EventKind.textNote]),
            ])
            .listen((_) {}, onDone: () => done = true);

        onEose!();
        await pumpEventQueue();

        expect(done, isFalse);
        expect(client.activeSubscriptionCount, 1);
        verifyNever(() => mockNostr.unsubscribe(any()));
        await subscription.cancel();
      });

      test('CLOSED surfaces its reason as a typed stream error', () async {
        void Function(String reason)? onClosed;
        when(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
            onClosed: any(named: 'onClosed'),
          ),
        ).thenAnswer((invocation) {
          onClosed =
              invocation.namedArguments[#onClosed]
                  as void Function(String reason)?;
          return invocation.namedArguments[#id] as String;
        });
        when(() => mockNostr.unsubscribe(any())).thenReturn(null);

        final stream = client.subscribe([
          Filter(kinds: [EventKind.textNote]),
        ]);
        final expectation = expectLater(
          stream,
          emitsInOrder([
            emitsError(
              isA<RelaySubscriptionRefusedException>().having(
                (error) => error.reason,
                'reason',
                'error: too many subscriptions',
              ),
            ),
            emitsDone,
          ]),
        );

        onClosed!('error: too many subscriptions');

        await expectation;
        verify(() => mockNostr.unsubscribe(any())).called(1);
        expect(client.activeSubscriptionCount, 0);
      });

      test('creates new subscription for different filters', () {
        final filters1 = [
          Filter(kinds: [EventKind.textNote], limit: 10),
        ];
        final filters2 = [
          Filter(kinds: [EventKind.metadata], limit: 5),
        ];

        when(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
            onClosed: any(named: 'onClosed'),
          ),
        ).thenReturn('test-sub-id');

        client
          ..subscribe(filters1)
          ..subscribe(filters2);

        // Should create two separate subscriptions
        verify(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
            onClosed: any(named: 'onClosed'),
          ),
        ).called(2);
      });

      test('creates fresh anonymous subscriptions for identical filters', () {
        final filters = [
          Filter(kinds: [EventKind.textNote], limit: 10),
        ];
        final requestedIds = <String>[];

        when(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
            onClosed: any(named: 'onClosed'),
          ),
        ).thenAnswer((invocation) {
          final id = invocation.namedArguments[#id] as String;
          requestedIds.add(id);
          return id;
        });

        client
          ..subscribe(filters)
          ..subscribe(filters);

        expect(requestedIds, hasLength(2));
        expect(requestedIds.toSet(), hasLength(2));
        verify(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
            onClosed: any(named: 'onClosed'),
          ),
        ).called(2);
      });

      test(
        'cancels anonymous relay subscription when listener cancels',
        () async {
          final filters = [
            Filter(kinds: [EventKind.textNote], limit: 10),
          ];

          when(
            () => mockNostr.subscribe(
              any(),
              any(),
              id: any(named: 'id'),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
              onEose: any(named: 'onEose'),
              onClosed: any(named: 'onClosed'),
            ),
          ).thenAnswer(
            (invocation) => invocation.namedArguments[#id] as String,
          );
          when(() => mockNostr.unsubscribe(any())).thenReturn(null);

          final stream = client.subscribe(filters);
          final subscription = stream.listen((_) {});

          await subscription.cancel();

          verify(() => mockNostr.unsubscribe(any())).called(1);
          expect(client.activeSubscriptionCount, 0);
        },
      );

      test('closes anonymous stream after last listener cancels', () async {
        final filters = [
          Filter(kinds: [EventKind.textNote], limit: 10),
        ];

        when(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
            onClosed: any(named: 'onClosed'),
          ),
        ).thenAnswer(
          (invocation) => invocation.namedArguments[#id] as String,
        );
        when(() => mockNostr.unsubscribe(any())).thenReturn(null);

        final stream = client.subscribe(filters);
        final subscription = stream.listen((_) {});

        await subscription.cancel();

        await expectLater(stream, emitsDone);
      });

      test('uses custom subscription ID when provided', () {
        final filters = [
          Filter(kinds: [EventKind.textNote], limit: 10),
        ];
        const customId = 'my-custom-subscription';

        when(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
            onClosed: any(named: 'onClosed'),
          ),
        ).thenReturn(customId);

        client.subscribe(filters, subscriptionId: customId);

        verify(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: customId,
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
            onClosed: any(named: 'onClosed'),
          ),
        ).called(1);
      });

      test('passes all parameters correctly', () {
        final filters = [
          Filter(kinds: [EventKind.textNote], limit: 10),
        ];
        final tempRelays = ['wss://temp.example.com'];
        final targetRelays = ['wss://target.example.com'];

        when(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
            onClosed: any(named: 'onClosed'),
          ),
        ).thenReturn('test-sub-id');

        client.subscribe(
          filters,
          subscriptionId: 'test-id',
          tempRelays: tempRelays,
          targetRelays: targetRelays,
          relayTypes: [RelayType.normal],
          sendAfterAuth: true,
        );

        verify(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: 'test-id',
            tempRelays: tempRelays,
            targetRelays: targetRelays,
            relayTypes: [RelayType.normal],
            sendAfterAuth: true,
            onEose: any(named: 'onEose'),
            onClosed: any(named: 'onClosed'),
          ),
        ).called(1);
      });

      test('handles nostr returning different subscription ID', () {
        final filters = [
          Filter(kinds: [EventKind.textNote], limit: 10),
        ];

        // Nostr returns a different ID than what was requested
        when(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
            onClosed: any(named: 'onClosed'),
          ),
        ).thenReturn('nostr-generated-id');

        final stream = client.subscribe(filters, subscriptionId: 'my-id');

        expect(stream, isA<Stream<Event>>());
      });
    });

    group('unsubscribe', () {
      test('unsubscribes and closes stream', () async {
        const subscriptionId = 'test-sub-id';
        final filters = [
          Filter(kinds: [EventKind.textNote], limit: 10),
        ];

        when(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
            onClosed: any(named: 'onClosed'),
          ),
        ).thenReturn(subscriptionId);
        when(() => mockNostr.unsubscribe(any())).thenReturn(null);

        client.subscribe(filters, subscriptionId: subscriptionId);
        await client.unsubscribe(subscriptionId);

        verify(() => mockNostr.unsubscribe(subscriptionId)).called(1);
      });

      test('handles unsubscribing non-existent subscription', () async {
        when(() => mockNostr.unsubscribe(any())).thenReturn(null);

        // Should not throw
        await client.unsubscribe('nonexistent-id');

        verify(() => mockNostr.unsubscribe('nonexistent-id')).called(1);
      });
    });

    group('closeAllSubscriptions', () {
      test('closes all active subscriptions', () async {
        final filters1 = [
          Filter(kinds: [EventKind.textNote], limit: 10),
        ];
        final filters2 = [
          Filter(kinds: [EventKind.metadata], limit: 5),
        ];

        var callCount = 0;
        when(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
            onClosed: any(named: 'onClosed'),
          ),
        ).thenAnswer((_) => 'sub-${callCount++}');
        when(() => mockNostr.unsubscribe(any())).thenReturn(null);

        client
          ..subscribe(filters1)
          ..subscribe(filters2);
        await client.closeAllSubscriptions();

        verify(() => mockNostr.unsubscribe(any())).called(2);
      });

      test('handles no active subscriptions', () async {
        when(() => mockNostr.unsubscribe(any())).thenReturn(null);

        // Should not throw
        await client.closeAllSubscriptions();

        verifyNever(() => mockNostr.unsubscribe(any()));
      });
    });

    group('addRelay', () {
      test('delegates to RelayManager', () async {
        const relayUrl = 'wss://relay.example.com';
        when(
          () => mockRelayManager.addRelay(
            relayUrl,
            source: any(named: 'source'),
          ),
        ).thenAnswer((_) async => true);

        final result = await client.addRelay(relayUrl);

        expect(result, isTrue);
        final captured = verify(
          () => mockRelayManager.addRelay(
            relayUrl,
            source: captureAny(named: 'source'),
          ),
        ).captured;
        expect(captured, equals([RelayAddSource.automatic]));
      });

      test('forwards explicit add source to RelayManager', () async {
        const relayUrl = 'wss://relay.example.com';
        when(
          () =>
              mockRelayManager.addRelay(relayUrl, source: RelayAddSource.user),
        ).thenAnswer((_) async => true);

        final result = await client.addRelay(
          relayUrl,
          source: RelayAddSource.user,
        );

        expect(result, isTrue);
        verify(
          () =>
              mockRelayManager.addRelay(relayUrl, source: RelayAddSource.user),
        ).called(1);
      });

      test('returns false when RelayManager returns false', () async {
        const relayUrl = 'wss://relay.example.com';
        when(
          () => mockRelayManager.addRelay(
            relayUrl,
            source: any(named: 'source'),
          ),
        ).thenAnswer((_) async => false);

        final result = await client.addRelay(relayUrl);

        expect(result, isFalse);
      });
    });

    group('addRelays', () {
      test(
        'adds multiple relays and returns count of successful additions',
        () async {
          final relayUrls = [
            'wss://relay1.example.com',
            'wss://relay2.example.com',
            'wss://relay3.example.com',
          ];

          when(
            () => mockRelayManager.addRelay(
              any(),
              source: any(named: 'source'),
            ),
          ).thenAnswer((_) async => true);

          final result = await client.addRelays(relayUrls);

          expect(result, equals(3));
          verify(
            () => mockRelayManager.addRelay(
              relayUrls[0],
              source: any(named: 'source'),
            ),
          ).called(1);
          verify(
            () => mockRelayManager.addRelay(
              relayUrls[1],
              source: any(named: 'source'),
            ),
          ).called(1);
          verify(
            () => mockRelayManager.addRelay(
              relayUrls[2],
              source: any(named: 'source'),
            ),
          ).called(1);
        },
      );

      test('forwards explicit source for multiple relays', () async {
        final relayUrls = [
          'wss://relay1.example.com',
          'wss://relay2.example.com',
        ];
        when(
          () => mockRelayManager.addRelay(any(), source: RelayAddSource.user),
        ).thenAnswer((_) async => true);

        final result = await client.addRelays(
          relayUrls,
          source: RelayAddSource.user,
        );

        expect(result, equals(2));
        verify(
          () => mockRelayManager.addRelay(
            relayUrls[0],
            source: RelayAddSource.user,
          ),
        ).called(1);
        verify(
          () => mockRelayManager.addRelay(
            relayUrls[1],
            source: RelayAddSource.user,
          ),
        ).called(1);
      });

      test('returns 0 when empty list is provided', () async {
        final result = await client.addRelays([]);

        expect(result, equals(0));
        verifyNever(
          () => mockRelayManager.addRelay(any(), source: any(named: 'source')),
        );
      });

      test(
        'handles partial failures and returns count of successful only',
        () async {
          final relayUrls = [
            'wss://relay1.example.com',
            'wss://relay2.example.com',
            'wss://relay3.example.com',
          ];

          // First and third succeed, second fails
          when(
            () => mockRelayManager.addRelay(
              'wss://relay1.example.com',
              source: any(named: 'source'),
            ),
          ).thenAnswer((_) async => true);
          when(
            () => mockRelayManager.addRelay(
              'wss://relay2.example.com',
              source: any(named: 'source'),
            ),
          ).thenAnswer((_) async => false);
          when(
            () => mockRelayManager.addRelay(
              'wss://relay3.example.com',
              source: any(named: 'source'),
            ),
          ).thenAnswer((_) async => true);

          final result = await client.addRelays(relayUrls);

          expect(result, equals(2));
        },
      );

      test('returns 0 when all relays fail to add', () async {
        final relayUrls = [
          'wss://relay1.example.com',
          'wss://relay2.example.com',
        ];

        when(
          () => mockRelayManager.addRelay(
            any(),
            source: any(named: 'source'),
          ),
        ).thenAnswer((_) async => false);

        final result = await client.addRelays(relayUrls);

        expect(result, equals(0));
      });

      test('adds single relay successfully', () async {
        final relayUrls = ['wss://single-relay.example.com'];

        when(
          () => mockRelayManager.addRelay(
            any(),
            source: any(named: 'source'),
          ),
        ).thenAnswer((_) async => true);

        final result = await client.addRelays(relayUrls);

        expect(result, equals(1));
        verify(
          () => mockRelayManager.addRelay(
            'wss://single-relay.example.com',
            source: any(named: 'source'),
          ),
        ).called(1);
      });
    });

    group('removeRelay', () {
      test('delegates to RelayManager', () async {
        const relayUrl = 'wss://relay.example.com';
        when(
          () => mockRelayManager.removeRelay(
            relayUrl,
            source: any(named: 'source'),
          ),
        ).thenAnswer((_) async => true);

        final result = await client.removeRelay(
          relayUrl,
          source: RelayRemoveSource.user,
        );

        expect(result, isTrue);
        final captured = verify(
          () => mockRelayManager.removeRelay(
            relayUrl,
            source: captureAny(named: 'source'),
          ),
        ).captured;
        expect(captured, equals([RelayRemoveSource.user]));
      });

      test('forwards explicit remove source to RelayManager', () async {
        const relayUrl = 'wss://relay.example.com';
        when(
          () => mockRelayManager.removeRelay(
            relayUrl,
            source: RelayRemoveSource.automatic,
          ),
        ).thenAnswer((_) async => true);

        final result = await client.removeRelay(
          relayUrl,
          source: RelayRemoveSource.automatic,
        );

        expect(result, isTrue);
        verify(
          () => mockRelayManager.removeRelay(
            relayUrl,
            source: RelayRemoveSource.automatic,
          ),
        ).called(1);
      });
    });

    group('primaryRelay', () {
      test(
        'falls back to environment default when no relays are configured',
        () {
          when(() => mockRelayManager.connectedRelays).thenReturn(const []);
          when(() => mockRelayManager.configuredRelays).thenReturn(const []);
          when(
            () => mockRelayManager.defaultRelayUrl,
          ).thenReturn('wss://relay.staging.divine.video');

          expect(
            client.primaryRelay,
            equals('wss://relay.staging.divine.video'),
          );
        },
      );
    });

    group('connectedRelays', () {
      test('delegates to RelayManager', () {
        final expectedRelays = [
          'wss://relay1.example.com',
          'wss://relay2.example.com',
        ];
        when(() => mockRelayManager.connectedRelays).thenReturn(expectedRelays);

        final result = client.connectedRelays;

        expect(result, equals(expectedRelays));
        verify(() => mockRelayManager.connectedRelays).called(1);
      });

      test('returns empty list when no relays connected', () {
        when(() => mockRelayManager.connectedRelays).thenReturn([]);

        final result = client.connectedRelays;

        expect(result, isEmpty);
      });
    });

    group('connectedRelayCount', () {
      test('delegates to RelayManager', () {
        when(() => mockRelayManager.connectedRelayCount).thenReturn(3);

        expect(client.connectedRelayCount, equals(3));
        verify(() => mockRelayManager.connectedRelayCount).called(1);
      });

      test('returns 0 when no relays connected', () {
        when(() => mockRelayManager.connectedRelayCount).thenReturn(0);

        expect(client.connectedRelayCount, equals(0));
      });
    });

    group('relayStatuses', () {
      test('delegates to RelayManager', () {
        final expectedStatuses = {
          'wss://relay1.example.com': RelayConnectionStatus.connected(
            'wss://relay1.example.com',
          ),
          'wss://relay2.example.com': RelayConnectionStatus.connected(
            'wss://relay2.example.com',
          ),
        };
        when(
          () => mockRelayManager.currentStatuses,
        ).thenReturn(expectedStatuses);

        final result = client.relayStatuses;

        expect(result, equals(expectedStatuses));
        verify(() => mockRelayManager.currentStatuses).called(1);
      });

      test('returns empty map when no relays', () {
        when(() => mockRelayManager.currentStatuses).thenReturn({});

        final result = client.relayStatuses;

        expect(result, isEmpty);
      });
    });

    group('configuredRelays', () {
      test('delegates to RelayManager', () {
        final expectedRelays = [
          'wss://relay1.example.com',
          'wss://relay2.example.com',
        ];
        when(
          () => mockRelayManager.configuredRelays,
        ).thenReturn(expectedRelays);

        final result = client.configuredRelays;

        expect(result, equals(expectedRelays));
        verify(() => mockRelayManager.configuredRelays).called(1);
      });
    });

    group('configuredRelayCount', () {
      test('delegates to RelayManager', () {
        when(() => mockRelayManager.configuredRelayCount).thenReturn(2);

        expect(client.configuredRelayCount, equals(2));
        verify(() => mockRelayManager.configuredRelayCount).called(1);
      });

      test('returns 0 when no relays configured', () {
        when(() => mockRelayManager.configuredRelayCount).thenReturn(0);

        expect(client.configuredRelayCount, equals(0));
      });
    });

    group('relayStatusStream', () {
      test('delegates to RelayManager', () async {
        final controller =
            StreamController<Map<String, RelayConnectionStatus>>.broadcast();
        when(
          () => mockRelayManager.statusStream,
        ).thenAnswer((_) => controller.stream);

        final result = client.relayStatusStream;

        expect(result, isNotNull);
        verify(() => mockRelayManager.statusStream).called(1);

        await controller.close();
      });
    });

    group('retryDisconnectedRelays', () {
      test('delegates to RelayManager', () async {
        when(mockRelayManager.retryDisconnectedRelays).thenAnswer((_) async {});

        await client.retryDisconnectedRelays();

        verify(mockRelayManager.retryDisconnectedRelays).called(1);
      });
    });

    group('forceReconnectAll', () {
      test('delegates to RelayManager', () async {
        when(mockRelayManager.forceReconnectAll).thenAnswer((_) async {});

        await client.forceReconnectAll();

        verify(mockRelayManager.forceReconnectAll).called(1);
      });
    });

    group('sendLike', () {
      void stubOutcome(PublishOutcome outcome) {
        when(
          () => mockNostr.sendEventAwaitOk(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => outcome);
      }

      test('sends like successfully', () async {
        const eventId = 'event-to-like';
        stubOutcome(
          const PublishOutcome(
            eventId: eventId,
            acceptedBy: ['wss://relay.example.com'],
            rejectedBy: {},
            noResponseFrom: [],
          ),
        );

        final result = await client.sendLike(eventId);

        expect(result, isNotNull);
        final captured =
            verify(
                  () => mockNostr.sendEventAwaitOk(
                    captureAny(),
                    tempRelays: any(named: 'tempRelays'),
                    targetRelays: any(named: 'targetRelays'),
                    timeout: any(named: 'timeout'),
                  ),
                ).captured.single
                as Event;
        expect(captured.kind, EventKind.reaction);
        expect(captured.content, '+');
        expect(captured.tags.firstWhere((tag) => tag[0] == 'e'), [
          'e',
          eventId,
        ]);
        expect(
          captured.tags.firstWhere((tag) => tag[0] == 'client'),
          Nip89ClientTag.tag,
        );
      });

      test('sends like with custom content', () async {
        const eventId = 'event-to-like';
        const content = '❤️';
        stubOutcome(
          const PublishOutcome(
            eventId: eventId,
            acceptedBy: ['wss://relay.example.com'],
            rejectedBy: {},
            noResponseFrom: [],
          ),
        );

        await client.sendLike(eventId, content: content);

        final captured =
            verify(
                  () => mockNostr.sendEventAwaitOk(
                    captureAny(),
                    tempRelays: any(named: 'tempRelays'),
                    targetRelays: any(named: 'targetRelays'),
                    timeout: any(named: 'timeout'),
                  ),
                ).captured.single
                as Event;
        expect(captured.content, content);
      });

      test('sends like with relay parameters', () async {
        const eventId = 'event-to-like';
        final tempRelays = ['wss://temp.example.com'];
        final targetRelays = ['wss://target.example.com'];
        stubOutcome(
          const PublishOutcome(
            eventId: eventId,
            acceptedBy: ['wss://target.example.com'],
            rejectedBy: {},
            noResponseFrom: [],
          ),
        );

        await client.sendLike(
          eventId,
          tempRelays: tempRelays,
          targetRelays: targetRelays,
        );

        verify(
          () => mockNostr.sendEventAwaitOk(
            any(),
            tempRelays: targetRelays,
            targetRelays: targetRelays,
            timeout: any(named: 'timeout'),
          ),
        ).called(1);
      });

      test('throws a typed restricted result for trusted rejection', () async {
        const eventId = 'event-to-like';
        stubOutcome(
          const PublishOutcome(
            eventId: eventId,
            acceptedBy: [],
            rejectedBy: {
              'wss://relay.example.com/': 'blocked: pubkey is suspended',
            },
            noResponseFrom: [],
          ),
        );

        await expectLater(
          client.sendLike(eventId),
          throwsA(
            isA<SocialPublishException>().having(
              (error) => error.result.status,
              'status',
              SocialPublishStatus.accountRestricted,
            ),
          ),
        );
      });

      test('any relay acceptance wins over a trusted rejection', () async {
        const eventId = 'event-to-like';
        stubOutcome(
          const PublishOutcome(
            eventId: eventId,
            acceptedBy: ['wss://personal.example.com'],
            rejectedBy: {
              'wss://relay.example.com': 'blocked: pubkey is banned',
            },
            noResponseFrom: [],
          ),
        );

        expect(await client.sendLike(eventId), isNotNull);
      });

      test('distinguishes rate limiting from unrelated rejection', () async {
        const eventId = 'event-to-like';
        stubOutcome(
          const PublishOutcome(
            eventId: eventId,
            acceptedBy: [],
            rejectedBy: {
              'wss://relay.example.com': 'rate-limited: slow down',
            },
            noResponseFrom: [],
          ),
        );

        await expectLater(
          client.sendLike(eventId),
          throwsA(
            isA<SocialPublishException>().having(
              (error) => error.result.status,
              'status',
              SocialPublishStatus.rateLimited,
            ),
          ),
        );

        reset(mockNostr);
        when(() => mockNostr.publicKey).thenReturn(testPublicKey);
        stubOutcome(
          const PublishOutcome(
            eventId: eventId,
            acceptedBy: [],
            rejectedBy: {
              'wss://relay.example.com': 'blocked: event rejected by policy',
            },
            noResponseFrom: [],
          ),
        );
        await expectLater(
          client.sendLike(eventId),
          throwsA(
            isA<SocialPublishException>().having(
              (error) => error.result.status,
              'status',
              SocialPublishStatus.rejected,
            ),
          ),
        );
      });

      test('distinguishes no relays from SDK send failure', () async {
        const eventId = 'event-to-like';
        when(() => mockRelayManager.connectedRelays).thenReturn(const []);
        when(mockRelayManager.retryDisconnectedRelays).thenAnswer((_) async {});

        await expectLater(
          client.sendLike(eventId),
          throwsA(
            isA<SocialPublishException>().having(
              (error) => error.result.status,
              'status',
              SocialPublishStatus.noRelays,
            ),
          ),
        );

        when(
          () => mockRelayManager.connectedRelays,
        ).thenReturn(['wss://relay.example.com']);
        when(
          () => mockNostr.sendEventAwaitOk(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => null);
        await expectLater(
          client.sendLike(eventId),
          throwsA(
            isA<SocialPublishException>().having(
              (error) => error.result.status,
              'status',
              SocialPublishStatus.sendFailed,
            ),
          ),
        );
      });

      test(
        'maps a thrown SDK failure to the typed send-failed result',
        () async {
          const eventId = 'event-to-like';
          when(
            () => mockNostr.sendEventAwaitOk(
              any(),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
              timeout: any(named: 'timeout'),
            ),
          ).thenThrow(StateError('SDK dispatch failed'));

          await expectLater(
            client.sendLike(eventId),
            throwsA(
              isA<SocialPublishException>().having(
                (error) => error.result.status,
                'status',
                SocialPublishStatus.sendFailed,
              ),
            ),
          );
        },
      );
    });

    group('sendProfileAwaitOk', () {
      PublishOutcome accepted() => const PublishOutcome(
        eventId: 'kind0',
        acceptedBy: ['wss://relay.test'],
        rejectedBy: {},
        noResponseFrom: [],
      );

      PublishOutcome rejected() => const PublishOutcome(
        eventId: 'kind0',
        acceptedBy: [],
        rejectedBy: {'wss://relay.test': 'rate-limited: slow down'},
        noResponseFrom: [],
      );

      PublishOutcome timedOut() => const PublishOutcome(
        eventId: 'kind0',
        acceptedBy: [],
        rejectedBy: {},
        noResponseFrom: ['wss://relay.test'],
      );

      void stubAwaitOk(PublishOutcome outcome) {
        when(
          () => mockNostr.sendEventAwaitOk(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => outcome);
      }

      test('returns PublishSuccess with the Kind 0 event when a relay '
          'confirms', () async {
        final profileContent = {'display_name': 'Alice', 'about': 'Hello'};
        stubAwaitOk(accepted());

        final result = await client.sendProfileAwaitOk(
          profileContent: profileContent,
        );

        expect(result, isA<PublishSuccess>());
        final event = (result as PublishSuccess).event;
        expect(event.kind, equals(EventKind.metadata));
        expect(event.content, equals(jsonEncode(profileContent)));
      });

      test('includes supplied tags on the Kind 0 event', () async {
        final tags = [
          ['i', 'github:alice', 'proof'],
          ['alt', 'profile metadata'],
        ];
        stubAwaitOk(accepted());

        final result = await client.sendProfileAwaitOk(
          profileContent: {'display_name': 'Alice'},
          tags: tags,
        );

        expect(result, isA<PublishSuccess>());
        final event = (result as PublishSuccess).event;
        expect(event.tags.take(tags.length).toList(), equals(tags));
        verify(
          () => mockNostr.sendEventAwaitOk(
            any(
              that: isA<Event>().having(
                (e) => e.tags.take(tags.length).toList(),
                'leading tags',
                equals(tags),
              ),
            ),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            timeout: any(named: 'timeout'),
          ),
        ).called(1);
      });

      test('returns PublishSuccess when at least one relay confirms even if '
          'another rejects', () async {
        stubAwaitOk(
          const PublishOutcome(
            eventId: 'kind0',
            acceptedBy: ['wss://relay.ok'],
            rejectedBy: {'wss://relay.bad': 'blocked: policy'},
            noResponseFrom: [],
          ),
        );

        final result = await client.sendProfileAwaitOk(
          profileContent: {'display_name': 'Alice'},
        );

        expect(result, isA<PublishSuccess>());
      });

      test('retries disconnected relays and returns PublishSuccess when '
          'a relay confirms', () async {
        var connectedRelays = <String>[];
        when(
          () => mockRelayManager.connectedRelays,
        ).thenAnswer((_) => connectedRelays);
        when(mockRelayManager.retryDisconnectedRelays).thenAnswer((_) async {
          connectedRelays = ['wss://relay.test'];
        });
        stubAwaitOk(accepted());

        final result = await client.sendProfileAwaitOk(
          profileContent: {'display_name': 'Alice'},
        );

        expect(result, isA<PublishSuccess>());
        verify(mockRelayManager.retryDisconnectedRelays).called(1);
        verify(
          () => mockNostr.sendEventAwaitOk(
            any(
              that: isA<Event>()
                  .having((e) => e.kind, 'kind', EventKind.metadata)
                  .having(
                    (e) => e.content,
                    'content',
                    jsonEncode({'display_name': 'Alice'}),
                  ),
            ),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            timeout: any(named: 'timeout'),
          ),
        ).called(1);
      });

      test('returns PublishFailed when every relay rejects the event '
          '(accepted at socket, OK false)', () async {
        stubAwaitOk(rejected());

        final result = await client.sendProfileAwaitOk(
          profileContent: {'display_name': 'Alice'},
        );

        expect(result, isA<PublishFailed>());
      });

      test(
        'returns PublishFailed when no relay responds before timeout',
        () async {
          stubAwaitOk(timedOut());

          final result = await client.sendProfileAwaitOk(
            profileContent: {'display_name': 'Alice'},
          );

          expect(result, isA<PublishFailed>());
        },
      );

      test(
        'returns PublishFailed when relays are connected but the send fails '
        'before any OK (SDK returns null, e.g. signer failure)',
        () async {
          // connectedRelays defaults to non-empty in setUp, so the no-relays
          // connectivity check passes. The all-empty outcome here comes from
          // the null-send fallback inside publishEventAwaitOk (signing failure
          // with relays connected), which must surface as PublishFailed — not
          // PublishNoRelays.
          when(
            () => mockNostr.sendEventAwaitOk(
              any(),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((_) async => null);

          final result = await client.sendProfileAwaitOk(
            profileContent: {'display_name': 'Alice'},
          );

          expect(result, isA<PublishFailed>());
        },
      );

      test('returns PublishNoRelays when no relay is reachable, without '
          'attempting a send', () async {
        when(() => mockRelayManager.connectedRelays).thenReturn([]);
        when(mockRelayManager.retryDisconnectedRelays).thenAnswer((_) async {});

        final result = await client.sendProfileAwaitOk(
          profileContent: {'display_name': 'Alice'},
        );

        expect(result, isA<PublishNoRelays>());
        verifyNever(
          () => mockNostr.sendEventAwaitOk(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            timeout: any(named: 'timeout'),
          ),
        );
      });
    });

    group('sendRepost', () {
      test('sends repost successfully', () async {
        const eventId = 'event-to-repost';
        final repostEvent = _createTestEvent(kind: EventKind.repost);

        when(
          () => mockNostr.sendEvent(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => repostEvent);

        final result = await client.sendRepost(eventId);

        expect(result, equals(repostEvent));
        final captured =
            verify(
                  () => mockNostr.sendEvent(
                    captureAny(),
                    tempRelays: any(named: 'tempRelays'),
                    targetRelays: any(named: 'targetRelays'),
                  ),
                ).captured.single
                as Event;
        expect(captured.kind, EventKind.repost);
        expect(captured.content, isEmpty);
        expect(captured.tags.firstWhere((tag) => tag[0] == 'e'), [
          'e',
          eventId,
        ]);
        expect(
          captured.tags.firstWhere((tag) => tag[0] == 'client'),
          Nip89ClientTag.tag,
        );
      });

      test('sends repost with all parameters', () async {
        const eventId = 'event-to-repost';
        const relayAddr = 'wss://relay.example.com';
        const content = '{"event":"data"}';
        final tempRelays = ['wss://temp.example.com'];
        final targetRelays = ['wss://target.example.com'];
        final repostEvent = _createTestEvent(kind: EventKind.repost);

        when(
          () => mockNostr.sendEvent(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => repostEvent);

        await client.sendRepost(
          eventId,
          relayAddr: relayAddr,
          content: content,
          tempRelays: tempRelays,
          targetRelays: targetRelays,
        );

        final verification = verify(
          () => mockNostr.sendEvent(
            captureAny(),
            tempRelays: targetRelays,
            targetRelays: targetRelays,
          ),
        );
        final captured = verification.captured.single as Event;
        expect(captured.content, content);
        expect(captured.tags.firstWhere((tag) => tag[0] == 'e'), [
          'e',
          eventId,
          relayAddr,
        ]);
      });

      test('returns null when sendRepost fails', () async {
        const eventId = 'event-to-repost';

        when(
          () => mockNostr.sendEvent(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => null);

        final result = await client.sendRepost(eventId);

        expect(result, isNull);
      });
    });

    group('sendGenericRepost', () {
      const addressableId = '''
34236:82341f882b6eabcd2ba7f1ef90aad961cf074af15b9ef44a09f9d2a8fbfbe6a2
:unique-identifier''';
      const targetKind = 34236;
      const authorPubkey =
          '82341f882b6eabcd2ba7f1ef90aad961cf074af15b9ef44a09f9d2a8fbfbe6a2';

      test('sends generic repost successfully', () async {
        final repostEvent = _createTestEvent(kind: EventKind.genericRepost);

        when(
          () => mockNostr.sendEvent(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => repostEvent);

        final result = await client.sendGenericRepost(
          addressableId: addressableId,
          targetKind: targetKind,
          authorPubkey: authorPubkey,
        );

        expect(result, equals(repostEvent));
        final captured =
            verify(
                  () => mockNostr.sendEvent(
                    captureAny(),
                    tempRelays: any(named: 'tempRelays'),
                    targetRelays: any(named: 'targetRelays'),
                  ),
                ).captured.single
                as Event;

        expect(captured.kind, equals(EventKind.genericRepost));
        expect(captured.content, isEmpty);
        expect(
          captured.tags,
          containsAll([
            ['k', '$targetKind'],
            ['a', addressableId],
            ['p', authorPubkey],
            Nip89ClientTag.tag,
          ]),
        );
      });

      test('sends generic repost with all parameters', () async {
        const content = 'Test repost content';
        final tempRelays = ['wss://temp.example.com'];
        final targetRelays = ['wss://target.example.com'];
        final repostEvent = _createTestEvent(kind: EventKind.genericRepost);

        when(
          () => mockNostr.sendEvent(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => repostEvent);

        final result = await client.sendGenericRepost(
          addressableId: addressableId,
          targetKind: targetKind,
          authorPubkey: authorPubkey,
          content: content,
          tempRelays: tempRelays,
          targetRelays: targetRelays,
        );

        expect(result, equals(repostEvent));
        final captured =
            verify(
                  () => mockNostr.sendEvent(
                    captureAny(),
                    tempRelays: targetRelays,
                    targetRelays: targetRelays,
                  ),
                ).captured.single
                as Event;

        expect(captured.content, equals(content));
      });

      test('returns null when sendEvent fails', () async {
        when(
          () => mockNostr.sendEvent(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => null);

        final result = await client.sendGenericRepost(
          addressableId: addressableId,
          targetKind: targetKind,
          authorPubkey: authorPubkey,
        );

        expect(result, isNull);
      });

      test('creates event with correct tag structure', () async {
        final repostEvent = _createTestEvent(kind: EventKind.genericRepost);

        when(
          () => mockNostr.sendEvent(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => repostEvent);

        await client.sendGenericRepost(
          addressableId: addressableId,
          targetKind: targetKind,
          authorPubkey: authorPubkey,
        );

        final captured =
            verify(
                  () => mockNostr.sendEvent(
                    captureAny(),
                    tempRelays: any(named: 'tempRelays'),
                    targetRelays: any(named: 'targetRelays'),
                  ),
                ).captured.single
                as Event;

        // Verify tags are in correct order: k, a, p, client
        expect(captured.tags.length, equals(4));
        final tag0 = captured.tags[0] as List<dynamic>;
        final tag1 = captured.tags[1] as List<dynamic>;
        final tag2 = captured.tags[2] as List<dynamic>;
        final tag3 = captured.tags[3] as List<dynamic>;
        expect(tag0[0], equals('k'));
        expect(tag0[1], equals('$targetKind'));
        expect(tag1[0], equals('a'));
        expect(tag1[1], equals(addressableId));
        expect(tag2[0], equals('p'));
        expect(tag2[1], equals(authorPubkey));
        expect(tag3, equals(Nip89ClientTag.tag));
      });
    });

    group('deleteEvent', () {
      void stubOutcome(PublishOutcome outcome) {
        when(
          () => mockNostr.sendEventAwaitOk(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => outcome);
      }

      test('deletes event successfully', () async {
        const eventId = 'event-to-delete';
        stubOutcome(
          const PublishOutcome(
            eventId: eventId,
            acceptedBy: ['wss://relay.example.com'],
            rejectedBy: {},
            noResponseFrom: [],
          ),
        );

        final result = await client.deleteEvent(eventId);

        expect(result, isNotNull);
        final captured =
            verify(
                  () => mockNostr.sendEventAwaitOk(
                    captureAny(),
                    tempRelays: any(named: 'tempRelays'),
                    targetRelays: any(named: 'targetRelays'),
                    timeout: any(named: 'timeout'),
                  ),
                ).captured.single
                as Event;
        expect(captured.kind, EventKind.eventDeletion);
        expect(captured.content, 'delete');
        expect(captured.tags.firstWhere((tag) => tag[0] == 'e'), [
          'e',
          eventId,
        ]);
        expect(
          captured.tags.firstWhere((tag) => tag[0] == 'client'),
          Nip89ClientTag.tag,
        );
      });

      test('deletes event with relay parameters', () async {
        const eventId = 'event-to-delete';
        final tempRelays = ['wss://temp.example.com'];
        final targetRelays = ['wss://target.example.com'];
        stubOutcome(
          const PublishOutcome(
            eventId: eventId,
            acceptedBy: ['wss://target.example.com'],
            rejectedBy: {},
            noResponseFrom: [],
          ),
        );

        await client.deleteEvent(
          eventId,
          tempRelays: tempRelays,
          targetRelays: targetRelays,
        );

        verify(
          () => mockNostr.sendEventAwaitOk(
            any(),
            tempRelays: targetRelays,
            targetRelays: targetRelays,
            timeout: any(named: 'timeout'),
          ),
        ).called(1);
      });

      test('throws a typed no-response result when no relay answers', () async {
        const eventId = 'event-to-delete';
        stubOutcome(
          const PublishOutcome(
            eventId: eventId,
            acceptedBy: [],
            rejectedBy: {},
            noResponseFrom: ['wss://relay.example.com'],
          ),
        );

        await expectLater(
          client.deleteEvent(eventId),
          throwsA(
            isA<SocialPublishException>().having(
              (error) => error.result.status,
              'status',
              SocialPublishStatus.noResponse,
            ),
          ),
        );
      });
    });

    group('deleteEvents', () {
      test('deletes multiple events successfully', () async {
        final eventIds = ['event-1', 'event-2', 'event-3'];
        final deleteEvent = _createTestEvent(kind: EventKind.eventDeletion);

        when(
          () => mockNostr.sendEvent(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => deleteEvent);

        final result = await client.deleteEvents(eventIds);

        expect(result, equals(deleteEvent));
        final captured =
            verify(
                  () => mockNostr.sendEvent(
                    captureAny(),
                    targetRelays: any(named: 'targetRelays'),
                  ),
                ).captured.single
                as Event;
        expect(captured.kind, EventKind.eventDeletion);
        expect(captured.content, 'delete');
        expect(
          captured.tags.where((tag) => tag[0] == 'e').toList(),
          eventIds.map((eventId) => ['e', eventId]).toList(),
        );
        expect(
          captured.tags.firstWhere((tag) => tag[0] == 'client'),
          Nip89ClientTag.tag,
        );
      });

      test('deletes events with relay parameters', () async {
        final eventIds = ['event-1', 'event-2'];
        final tempRelays = ['wss://temp.example.com'];
        final targetRelays = ['wss://target.example.com'];
        final deleteEvent = _createTestEvent(kind: EventKind.eventDeletion);

        when(
          () => mockNostr.sendEvent(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => deleteEvent);

        await client.deleteEvents(
          eventIds,
          tempRelays: tempRelays,
          targetRelays: targetRelays,
        );

        verify(
          () => mockNostr.sendEvent(
            any(),
            tempRelays: targetRelays,
            targetRelays: targetRelays,
          ),
        ).called(1);
      });

      test('returns null when deleteEvents fails', () async {
        final eventIds = ['event-1', 'event-2'];

        when(
          () => mockNostr.sendEvent(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => null);

        final result = await client.deleteEvents(eventIds);

        expect(result, isNull);
      });
    });

    group('sendContactList', () {
      test('sends contact list successfully', () async {
        final contacts = ContactList();
        const content = '{"relay":"preferences"}';
        final contactListEvent = _createTestEvent(kind: EventKind.contactList);

        when(
          () => mockNostr.sendEvent(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => contactListEvent);

        final result = await client.sendContactList(contacts, content);

        expect(result, equals(contactListEvent));
        final captured =
            verify(
                  () => mockNostr.sendEvent(
                    captureAny(),
                    targetRelays: any(named: 'targetRelays'),
                  ),
                ).captured.single
                as Event;
        expect(captured.kind, EventKind.contactList);
        expect(captured.content, content);
        expect(
          captured.tags.firstWhere((tag) => tag[0] == 'client'),
          Nip89ClientTag.tag,
        );
      });

      test('sends contact list with relay parameters', () async {
        final contacts = ContactList();
        const content = '{"relay":"preferences"}';
        final tempRelays = ['wss://temp.example.com'];
        final targetRelays = ['wss://target.example.com'];
        final contactListEvent = _createTestEvent(kind: EventKind.contactList);

        when(
          () => mockNostr.sendEvent(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => contactListEvent);

        await client.sendContactList(
          contacts,
          content,
          tempRelays: tempRelays,
          targetRelays: targetRelays,
        );

        verify(
          () => mockNostr.sendEvent(
            any(),
            tempRelays: targetRelays,
            targetRelays: targetRelays,
          ),
        ).called(1);
      });

      test('returns null when sendContactList fails', () async {
        final contacts = ContactList();
        const content = '{"relay":"preferences"}';

        when(
          () => mockNostr.sendEvent(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => null);

        final result = await client.sendContactList(contacts, content);

        expect(result, isNull);
      });
    });

    group('createNip98AuthHeader', () {
      test(
        'returns "Nostr <base64>" with payload tag when payload is provided',
        () async {
          when(() => mockNostr.signEvent(any())).thenAnswer((invocation) {
            invocation.positionalArguments[0] as Event
              ..id = 'id'
              ..sig = 'sig';
            return Future.value();
          });

          const url = 'https://divine.video/api/username/claim';
          final authHeader = await client.createNip98AuthHeader(
            url: url,
            method: 'POST',
            payload: 'payload',
          );
          final decoded =
              jsonDecode(utf8.decode(base64Decode(authHeader!.split(' ')[1])))
                  as Map<String, dynamic>;
          final tags = (decoded['tags'] as List).cast<List<dynamic>>();

          expect(authHeader, startsWith('Nostr '));
          expect(decoded['kind'], equals(EventKind.httpAuth));
          expect(tags[0][1], equals(url));
          expect(tags[1][1], equals('POST'));
          expect(
            tags[2][1],
            equals(HashUtil.sha256Bytes(utf8.encode('payload'))),
          );
        },
      );

      test('returns "Nostr <base64>" without payload tag when payload is not '
          'provided', () async {
        when(() => mockNostr.signEvent(any())).thenAnswer((invocation) {
          invocation.positionalArguments[0] as Event
            ..id = 'id'
            ..sig = 'sig';
          return Future.value();
        });

        const url = 'https://divine.video/api/username/claim';
        final authHeader = await client.createNip98AuthHeader(
          url: url,
          method: 'POST',
        );
        final decoded =
            jsonDecode(utf8.decode(base64Decode(authHeader!.split(' ')[1])))
                as Map<String, dynamic>;
        final tags = (decoded['tags'] as List).cast<List<dynamic>>();

        expect(authHeader, startsWith('Nostr '));
        expect(decoded['kind'], equals(EventKind.httpAuth));
        expect(tags[0][1], equals(url));
        expect(tags[1][1], equals('POST'));
        expect(tags.length, equals(2));
      });

      test('returns null when signing fails', () async {
        when(
          () => mockNostr.signEvent(any()),
        ).thenAnswer((_) => Future.value());

        const url = 'https://divine.video/api/username/claim';
        final authHeader = await client.createNip98AuthHeader(
          url: url,
          method: 'POST',
        );
        expect(authHeader, isNull);
      });
    });

    group('dispose', () {
      test('closes all subscriptions and nostr client', () async {
        when(() => mockNostr.unsubscribe(any())).thenReturn(null);

        await client.dispose();

        verify(() => mockNostr.close()).called(1);
      });

      test('closes active subscriptions before disposing', () async {
        final filters = [
          Filter(kinds: [EventKind.textNote], limit: 10),
        ];

        when(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
            onClosed: any(named: 'onClosed'),
          ),
        ).thenReturn('test-sub-id');
        when(() => mockNostr.unsubscribe(any())).thenReturn(null);

        client.subscribe(filters);
        await client.dispose();

        verify(() => mockNostr.unsubscribe(any())).called(1);
        verify(() => mockNostr.close()).called(1);
      });

      test('marks the relay pool as closing before its first await', () async {
        when(() => mockNostr.unsubscribe(any())).thenReturn(null);

        final disposing = client.dispose();

        // Asserted before awaiting, so it pins the ordering rather than just
        // the call: every await below this point in dispose() is a window in
        // which an armed relay repair could open a socket that the teardown
        // at the end has already walked past (#7367).
        verify(() => mockNostr.beginClose()).called(1);
        verifyNever(() => mockNostr.close());

        await disposing;
        verify(() => mockNostr.close()).called(1);
      });
    });

    group('Database caching integration', () {
      late _MockAppDbClient mockDbClient;
      late _MockAppDatabase mockDatabase;
      late _MockNostrEventsDao mockNostrEventsDao;
      late NostrClient clientWithCache;

      setUp(() {
        mockDbClient = _MockAppDbClient();
        mockDatabase = _MockAppDatabase();
        mockNostrEventsDao = _MockNostrEventsDao();

        when(() => mockDbClient.database).thenReturn(mockDatabase);
        when(() => mockDatabase.nostrEventsDao).thenReturn(mockNostrEventsDao);

        clientWithCache = NostrClient.forTesting(
          nostr: mockNostr,
          relayManager: mockRelayManager,
          dbClient: mockDbClient,
        );
      });

      tearDown(() {
        reset(mockDbClient);
        reset(mockDatabase);
        reset(mockNostrEventsDao);
      });

      group('constructor with dbClient', () {
        test('creates client with dbClient', () {
          expect(clientWithCache.publicKey, equals(testPublicKey));
        });

        test('creates client without dbClient (backward compat)', () {
          final clientWithoutCache = NostrClient.forTesting(
            nostr: mockNostr,
            relayManager: mockRelayManager,
          );
          expect(clientWithoutCache.publicKey, equals(testPublicKey));
        });
      });

      group('subscribe with auto-caching', () {
        test('caches events received from subscription', () async {
          final filters = [
            Filter(kinds: [EventKind.textNote], limit: 10),
          ];
          final event = _createTestEvent();

          // Capture the callback passed to nostr.subscribe
          void Function(Event)? capturedCallback;
          when(
            () => mockNostr.subscribe(
              any(),
              any(),
              id: any(named: 'id'),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
              onEose: any(named: 'onEose'),
              onClosed: any(named: 'onClosed'),
            ),
          ).thenAnswer((invocation) {
            capturedCallback =
                invocation.positionalArguments[1] as void Function(Event);
            return 'test-sub-id';
          });

          when(
            () => mockNostrEventsDao.upsertEvent(any()),
          ).thenAnswer((_) async {});

          // Subscribe to get the stream
          final stream = clientWithCache.subscribe(filters);
          final receivedEvents = <Event>[];
          final subscription = stream.listen(receivedEvents.add);

          // Simulate receiving an event from nostr_sdk
          capturedCallback?.call(event);

          // Give async operations time to complete
          await Future<void>.delayed(Duration.zero);

          expect(receivedEvents, contains(event));
          verify(() => mockNostrEventsDao.upsertEvent(event)).called(1);

          await subscription.cancel();
        });

        test('does not cache when dbClient is null', () async {
          final filters = [
            Filter(kinds: [EventKind.textNote], limit: 10),
          ];
          final event = _createTestEvent();

          // Use client without cache
          void Function(Event)? capturedCallback;
          when(
            () => mockNostr.subscribe(
              any(),
              any(),
              id: any(named: 'id'),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
              onEose: any(named: 'onEose'),
              onClosed: any(named: 'onClosed'),
            ),
          ).thenAnswer((invocation) {
            capturedCallback =
                invocation.positionalArguments[1] as void Function(Event);
            return 'test-sub-id';
          });

          final stream = client.subscribe(filters);
          final receivedEvents = <Event>[];
          final subscription = stream.listen(receivedEvents.add);

          capturedCallback?.call(event);
          await Future<void>.delayed(Duration.zero);

          expect(receivedEvents, contains(event));
          // Should not interact with DAO since client has no dbClient
          verifyNever(() => mockNostrEventsDao.upsertEvent(any()));

          await subscription.cancel();
        });

        test('still emits event even if caching fails', () async {
          final filters = [
            Filter(kinds: [EventKind.textNote], limit: 10),
          ];
          final event = _createTestEvent();

          void Function(Event)? capturedCallback;
          when(
            () => mockNostr.subscribe(
              any(),
              any(),
              id: any(named: 'id'),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
              onEose: any(named: 'onEose'),
              onClosed: any(named: 'onClosed'),
            ),
          ).thenAnswer((invocation) {
            capturedCallback =
                invocation.positionalArguments[1] as void Function(Event);
            return 'test-sub-id';
          });

          // Make caching fail
          when(
            () => mockNostrEventsDao.upsertEvent(any()),
          ).thenThrow(Exception('Cache error'));

          final stream = clientWithCache.subscribe(filters);
          final receivedEvents = <Event>[];
          final subscription = stream.listen(receivedEvents.add);

          capturedCallback?.call(event);
          await Future<void>.delayed(Duration.zero);

          // Event should still be emitted even if caching failed
          expect(receivedEvents, contains(event));

          await subscription.cancel();
        });
      });

      group('queryEvents with cache-first', () {
        test('limited merge does not reorder the persistence batch', () async {
          final filters = [
            Filter(kinds: [EventKind.textNote], limit: 1),
          ];
          final older = _createTestEvent(content: 'older', createdAt: 1);
          final newer = _createTestEvent(content: 'newer', createdAt: 2);
          final websocketEvents = [older, newer];
          late List<Event> persistedEvents;

          when(
            () => mockNostrEventsDao.getEventsByFilter(any()),
          ).thenAnswer((_) async => []);
          when(
            () => mockNostr.queryEvents(
              any(),
              id: any(named: 'id'),
              tempRelays: any(named: 'tempRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
            ),
          ).thenAnswer((_) async => websocketEvents);
          when(
            () => mockNostrEventsDao.upsertEventsBatch(any()),
          ).thenAnswer((invocation) async {
            persistedEvents =
                invocation.positionalArguments.first as List<Event>;
          });

          final result = await clientWithCache.queryEvents(filters);

          expect(result, equals([newer]));
          expect(persistedEvents, equals([older, newer]));
          expect(websocketEvents, equals([older, newer]));
        });

        test('returns merged cache + websocket events', () async {
          final filters = [
            Filter(kinds: [EventKind.textNote], limit: 10),
          ];
          final cachedEvents = [_createTestEvent(content: 'cached 1')];
          final wsEvents = [_createTestEvent(content: 'from websocket')];

          when(
            () => mockNostrEventsDao.getEventsByFilter(any()),
          ).thenAnswer((_) async => cachedEvents);
          when(
            () => mockNostr.queryEvents(
              any(),
              id: any(named: 'id'),
              tempRelays: any(named: 'tempRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
            ),
          ).thenAnswer((_) async => wsEvents);
          when(
            () => mockNostrEventsDao.upsertEventsBatch(any()),
          ).thenAnswer((_) async {});

          final result = await clientWithCache.queryEvents(filters);

          // Cache + WebSocket results merged
          expect(result.length, 2);
          verify(
            () => mockNostrEventsDao.getEventsByFilter(filters.first),
          ).called(1);
        });

        test('queries websocket when cache is empty', () async {
          final filters = [
            Filter(kinds: [EventKind.textNote], limit: 10),
          ];
          final wsEvents = [_createTestEvent(content: 'from websocket')];

          when(
            () => mockNostrEventsDao.getEventsByFilter(any()),
          ).thenAnswer((_) async => []);
          when(
            () => mockNostr.queryEvents(
              any(),
              id: any(named: 'id'),
              tempRelays: any(named: 'tempRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
            ),
          ).thenAnswer((_) async => wsEvents);
          when(
            () => mockNostrEventsDao.upsertEventsBatch(any()),
          ).thenAnswer((_) async {});

          final result = await clientWithCache.queryEvents(filters);

          expect(result, equals(wsEvents));
          verify(
            () => mockNostrEventsDao.upsertEventsBatch(wsEvents),
          ).called(1);
        });

        test('returns empty when both cache and websocket are empty', () async {
          final filters = [
            Filter(kinds: [EventKind.textNote], limit: 10),
          ];

          when(
            () => mockNostrEventsDao.getEventsByFilter(any()),
          ).thenAnswer((_) async => []);
          when(
            () => mockNostr.queryEvents(
              any(),
              id: any(named: 'id'),
              tempRelays: any(named: 'tempRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
            ),
          ).thenAnswer((_) async => []);

          final result = await clientWithCache.queryEvents(filters);

          expect(result, isEmpty);
          verify(() => mockNostrEventsDao.getEventsByFilter(any())).called(1);
        });

        test('works without dbClient (backward compat)', () async {
          final filters = [
            Filter(kinds: [EventKind.textNote], limit: 10),
          ];
          final wsEvents = [_createTestEvent(content: 'from websocket')];

          when(
            () => mockNostr.queryEvents(
              any(),
              id: any(named: 'id'),
              tempRelays: any(named: 'tempRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
            ),
          ).thenAnswer((_) async => wsEvents);

          // Using client without cache
          final result = await client.queryEvents(filters);

          expect(result, equals(wsEvents));
          verifyNever(() => mockNostrEventsDao.getEventsByFilter(any()));
          verifyNever(() => mockNostrEventsDao.upsertEventsBatch(any()));
        });

        test('skips cache when multiple filters provided', () async {
          final filters = [
            Filter(kinds: [EventKind.textNote], limit: 10),
            Filter(kinds: [EventKind.metadata], limit: 5),
          ];
          final wsEvents = [_createTestEvent(content: 'from websocket')];

          // Cache should not be checked for multiple filters
          when(
            () => mockNostr.queryEvents(
              any(),
              id: any(named: 'id'),
              tempRelays: any(named: 'tempRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
            ),
          ).thenAnswer((_) async => wsEvents);
          when(
            () => mockNostrEventsDao.upsertEventsBatch(any()),
          ).thenAnswer((_) async {});

          final result = await clientWithCache.queryEvents(filters);

          expect(result, equals(wsEvents));
          // Cache should not be checked for multiple filters
          verifyNever(() => mockNostrEventsDao.getEventsByFilter(any()));
        });
      });

      group('fetchEventById with cache-first', () {
        test('returns cached event when available', () async {
          const eventId = 'test-event-id-12345';
          final cachedEvent = _createTestEvent(id: eventId);

          when(
            () => mockNostrEventsDao.getEventById(eventId),
          ).thenAnswer((_) async => cachedEvent);

          final result = await clientWithCache.fetchEventById(eventId);

          expect(result, equals(cachedEvent));
          verify(() => mockNostrEventsDao.getEventById(eventId)).called(1);
        });

        test('falls back to websocket when cache misses', () async {
          const eventId = 'test-event-id-12345';
          final wsEvent = _createTestEvent(id: eventId);

          when(
            () => mockNostrEventsDao.getEventById(eventId),
          ).thenAnswer((_) async => null);
          when(
            () => mockNostr.queryEvents(
              any(),
              id: any(named: 'id'),
              tempRelays: any(named: 'tempRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
            ),
          ).thenAnswer((_) async => [wsEvent]);
          when(
            () => mockNostrEventsDao.upsertEvent(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockNostrEventsDao.upsertEventsBatch(any()),
          ).thenAnswer((_) async {});

          final result = await clientWithCache.fetchEventById(eventId);

          expect(result, equals(wsEvent));
          // Should cache the websocket result
          verify(() => mockNostrEventsDao.upsertEvent(wsEvent)).called(1);
        });
      });

      group('fetchProfile with cache-first', () {
        test('returns cached profile when available', () async {
          const pubkey = testPublicKey;
          final cachedProfile = _createTestEvent(
            pubkey: pubkey,
            kind: EventKind.metadata,
            content: '{"name":"Cached User"}',
          );

          when(
            () => mockNostrEventsDao.getProfileByPubkey(pubkey),
          ).thenAnswer((_) async => cachedProfile);

          final result = await clientWithCache.fetchProfile(pubkey);

          expect(result, equals(cachedProfile));
          verify(() => mockNostrEventsDao.getProfileByPubkey(pubkey)).called(1);
        });

        test('falls back to websocket when cache misses', () async {
          const pubkey = testPublicKey;
          final wsProfile = _createTestEvent(
            pubkey: pubkey,
            kind: EventKind.metadata,
            content: '{"name":"WebSocket User"}',
          );

          when(
            () => mockNostrEventsDao.getProfileByPubkey(pubkey),
          ).thenAnswer((_) async => null);
          when(
            () => mockNostr.queryEvents(
              any(),
              id: any(named: 'id'),
              tempRelays: any(named: 'tempRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
            ),
          ).thenAnswer((_) async => [wsProfile]);
          when(
            () => mockNostrEventsDao.upsertEvent(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockNostrEventsDao.upsertEventsBatch(any()),
          ).thenAnswer((_) async {});

          final result = await clientWithCache.fetchProfile(pubkey);

          expect(result, equals(wsProfile));
          // Should cache the websocket result
          verify(() => mockNostrEventsDao.upsertEvent(wsProfile)).called(1);
        });
      });
    });

    group('state properties', () {
      test(
        'isInitialized returns false when relay manager not initialized',
        () {
          when(() => mockRelayManager.isInitialized).thenReturn(false);
          expect(client.isInitialized, isFalse);
        },
      );

      test('isInitialized returns true when relay manager is initialized', () {
        when(() => mockRelayManager.isInitialized).thenReturn(true);
        expect(client.isInitialized, isTrue);
      });

      test('isDisposed returns false before dispose', () {
        expect(client.isDisposed, isFalse);
      });

      test('isDisposed returns true after dispose', () async {
        when(() => mockNostr.unsubscribe(any())).thenReturn(null);

        await client.dispose();

        expect(client.isDisposed, isTrue);
      });

      test('hasKeys returns true when public key is not empty', () {
        when(() => mockNostr.publicKey).thenReturn(testPublicKey);

        expect(client.hasKeys, isTrue);
      });

      test('hasKeys returns false when public key is empty', () {
        when(() => mockNostr.publicKey).thenReturn('');

        expect(client.hasKeys, isFalse);
      });

      test('ready completes after initialize() succeeds', () async {
        when(() => mockNostr.refreshPublicKey()).thenAnswer((_) async {});
        when(() => mockRelayManager.initialize()).thenAnswer((_) async {});

        // ready must be pending before initialize().
        var resolved = false;
        unawaited(client.ready.then((_) => resolved = true));
        await Future<void>.delayed(Duration.zero);
        expect(resolved, isFalse);

        await client.initialize();
        await Future<void>.delayed(Duration.zero);

        expect(resolved, isTrue);
      });

      test('initialize reports the stage reached before each await', () async {
        when(() => mockNostr.refreshPublicKey()).thenAnswer((_) async {});
        when(() => mockRelayManager.initialize()).thenAnswer((_) async {});
        final observedStages = <NostrClientInitializationStage>[];
        client.initializationObserver = observedStages.add;

        await client.initialize();

        expect(
          observedStages,
          equals([
            NostrClientInitializationStage.refreshingPublicKey,
            NostrClientInitializationStage.loadingVerifiedEvents,
            NostrClientInitializationStage.startingVerificationWorker,
            NostrClientInitializationStage.connectingRelays,
          ]),
        );
      });

      test('a throwing stage observer does not fail initialization', () async {
        when(() => mockNostr.refreshPublicKey()).thenAnswer((_) async {});
        when(() => mockRelayManager.initialize()).thenAnswer((_) async {});
        client.initializationObserver = (_) {
          throw StateError('diagnostics failed');
        };

        await expectLater(client.initialize(), completes);
        await expectLater(client.ready, completes);
      });

      test('ready stays resolved on a second initialize() call', () async {
        when(() => mockNostr.refreshPublicKey()).thenAnswer((_) async {});
        when(() => mockRelayManager.initialize()).thenAnswer((_) async {});

        await client.initialize();
        // Second call must not throw "Future already completed".
        await client.initialize();

        // Reading ready a second time must still resolve normally.
        await client.ready;
      });

      test(
        'ready stays pending when dispose() runs before initialize() — the '
        'surrounding provider rebuilds with a fresh client and a fresh future',
        () async {
          when(() => mockNostr.unsubscribe(any())).thenReturn(null);

          final readyFuture = client.ready;
          await client.dispose();

          // Pending — short timeout proves no completion in either direction.
          await expectLater(
            readyFuture.timeout(
              const Duration(milliseconds: 50),
              onTimeout: () =>
                  throw StateError('intentional timeout — ready is pending'),
            ),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('intentional timeout'),
              ),
            ),
          );
          expect(client.isDisposed, isTrue);
        },
      );

      test(
        'ready completes with error when refreshPublicKey() throws',
        () async {
          final boom = StateError('refresh failed');
          when(() => mockNostr.refreshPublicKey()).thenThrow(boom);

          // Attach the ready listener before initialize() so completeError
          // has a handler — otherwise the test zone treats it as unhandled.
          final readyExpectation = expectLater(
            client.ready,
            throwsA(same(boom)),
          );

          await expectLater(client.initialize(), throwsA(same(boom)));
          await readyExpectation;
        },
      );

      test(
        'ready completes with error when relayManager.initialize() throws',
        () async {
          final boom = StateError('relay init failed');
          when(() => mockNostr.refreshPublicKey()).thenAnswer((_) async {});
          when(() => mockRelayManager.initialize()).thenThrow(boom);

          final readyExpectation = expectLater(
            client.ready,
            throwsA(same(boom)),
          );

          await expectLater(client.initialize(), throwsA(same(boom)));
          await readyExpectation;
        },
      );

      test('isReadyResolved is false before initialize() runs', () {
        expect(client.isReadyResolved, isFalse);
      });

      test('isReadyResolved is true after initialize() succeeds', () async {
        when(() => mockNostr.refreshPublicKey()).thenAnswer((_) async {});
        when(() => mockRelayManager.initialize()).thenAnswer((_) async {});

        await client.initialize();

        expect(client.isReadyResolved, isTrue);
      });

      test(
        'isReadyResolved is true after initialize() fails — gives '
        'isNostrReadyProvider a synchronous "future already settled" '
        'check so it stops re-arming .then on a completed completer',
        () async {
          final boom = StateError('refresh failed');
          when(() => mockNostr.refreshPublicKey()).thenThrow(boom);

          final readyExpectation = expectLater(
            client.ready,
            throwsA(same(boom)),
          );
          await expectLater(client.initialize(), throwsA(same(boom)));
          await readyExpectation;

          expect(client.isReadyResolved, isTrue);
        },
      );
    });

    group('relay convenience properties', () {
      test('configuredRelayCount returns count from manager', () {
        when(() => mockRelayManager.configuredRelayCount).thenReturn(3);

        expect(client.configuredRelayCount, equals(3));
        verify(() => mockRelayManager.configuredRelayCount).called(1);
      });

      test('configuredRelays returns list from manager', () {
        final expectedRelays = [
          'wss://relay1.example.com',
          'wss://relay2.example.com',
        ];
        when(
          () => mockRelayManager.configuredRelays,
        ).thenReturn(expectedRelays);

        expect(client.configuredRelays, equals(expectedRelays));
        verify(() => mockRelayManager.configuredRelays).called(1);
      });
    });

    group('searchVideos', () {
      test('returns stream of video events matching query', () async {
        const query = 'test video';
        final videoEvent = _createTestEvent(
          kind: 34236,
          content: 'Test video content',
        );

        when(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
            onClosed: any(named: 'onClosed'),
          ),
        ).thenAnswer((invocation) {
          // Get the callback and call it with test event
          final callback =
              invocation.positionalArguments[1] as void Function(Event);
          unawaited(Future.microtask(() => callback(videoEvent)));
          return 'search-sub-id';
        });

        final stream = client.searchVideos(query);
        final events = await stream.take(1).toList();

        expect(events, hasLength(1));
        expect(events.first.kind, equals(34236));
      });

      test('passes correct filter parameters', () async {
        const query = 'test';
        final since = DateTime(2024);
        final until = DateTime(2024, 12, 31);
        const limit = 50;

        when(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
            onClosed: any(named: 'onClosed'),
          ),
        ).thenReturn('search-sub-id');

        client.searchVideos(query, since: since, until: until, limit: limit);

        // Verify subscribe was called with filter containing search
        final captured = verify(
          () => mockNostr.subscribe(
            captureAny(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
            onClosed: any(named: 'onClosed'),
          ),
        ).captured;

        final filters = captured.first as List<Map<String, dynamic>>;
        expect(filters.first['search'], equals(query));
        expect(filters.first['kinds'], contains(34236));
        expect(filters.first['limit'], equals(limit));
      });
    });

    group('searchUsers', () {
      test('returns stream of profile events matching query', () async {
        const query = 'test user';
        final profileEvent = _createTestEvent(
          kind: EventKind.metadata,
          content: '{"name": "Test User"}',
        );

        when(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
            onClosed: any(named: 'onClosed'),
          ),
        ).thenAnswer((invocation) {
          final callback =
              invocation.positionalArguments[1] as void Function(Event);
          unawaited(Future.microtask(() => callback(profileEvent)));
          return 'search-sub-id';
        });

        final stream = client.searchUsers(query);
        final events = await stream.take(1).toList();

        expect(events, hasLength(1));
        expect(events.first.kind, equals(EventKind.metadata));
      });

      test('uses metadata kind filter', () async {
        const query = 'user';

        when(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
            onClosed: any(named: 'onClosed'),
          ),
        ).thenReturn('search-sub-id');

        client.searchUsers(query);

        final captured = verify(
          () => mockNostr.subscribe(
            captureAny(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
            onClosed: any(named: 'onClosed'),
          ),
        ).captured;

        final filters = captured.first as List<Map<String, dynamic>>;
        expect(filters.first['search'], equals(query));
        expect(filters.first['kinds'], contains(EventKind.metadata));
      });
    });

    group('queryUsers', () {
      test('returns list of profile events matching query', () async {
        const query = 'test user';
        final profileEvent = _createTestEvent(
          kind: EventKind.metadata,
          content: '{"name": "Test User"}',
        );

        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => [profileEvent]);

        final result = await client.queryUsers(query);

        expect(result, hasLength(1));
        expect(result.first.kind, equals(EventKind.metadata));
      });

      test('uses metadata kind and search filter', () async {
        const query = 'user';

        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => []);

        await client.queryUsers(query);

        final captured = verify(
          () => mockNostr.queryEvents(
            captureAny(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).captured;

        final filters = captured.first as List<Map<String, dynamic>>;
        expect(filters.first['search'], equals(query));
        expect(filters.first['kinds'], contains(EventKind.metadata));
      });

      test('uses default limit of 100', () async {
        const query = 'user';

        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => []);

        await client.queryUsers(query);

        final captured = verify(
          () => mockNostr.queryEvents(
            captureAny(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).captured;

        final filters = captured.first as List<Map<String, dynamic>>;
        expect(filters.first['limit'], equals(100));
      });

      test('uses custom limit when provided', () async {
        const query = 'user';
        const customLimit = 50;

        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => []);

        await client.queryUsers(query, limit: customLimit);

        final captured = verify(
          () => mockNostr.queryEvents(
            captureAny(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).captured;

        final filters = captured.first as List<Map<String, dynamic>>;
        expect(filters.first['limit'], equals(customLimit));
      });

      test('returns empty list when no results', () async {
        const query = 'nonexistent';

        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => []);

        final result = await client.queryUsers(query);

        expect(result, isEmpty);
      });

      test('returns multiple profile events', () async {
        const query = 'alice';
        final profileEvent1 = _createTestEvent(
          kind: EventKind.metadata,
          content: '{"name": "Alice Smith"}',
        );
        final profileEvent2 = _createTestEvent(
          kind: EventKind.metadata,
          content: '{"name": "Alice Wonder"}',
        );

        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => [profileEvent1, profileEvent2]);

        final result = await client.queryUsers(query);

        expect(result, hasLength(2));
        expect(result[0].kind, equals(EventKind.metadata));
        expect(result[1].kind, equals(EventKind.metadata));
      });

      test('passes NIP-50 search relays as tempRelays', () async {
        const query = 'alice';

        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => []);

        await client.queryUsers(query);

        final captured = verify(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: captureAny(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).captured;

        final tempRelays = captured.first as List<String>;
        expect(tempRelays, contains('wss://relay.nostr.band'));
        expect(tempRelays, contains('wss://search.nos.today'));
        expect(tempRelays, contains('wss://nostr.wine'));
        expect(tempRelays, hasLength(3));
      });

      test('bypasses general query pool for interactive search', () async {
        final originalMaxConcurrentQueries = NostrClient.maxConcurrentQueries;
        NostrClient.maxConcurrentQueries = 1;
        addTearDown(
          () => NostrClient.maxConcurrentQueries = originalMaxConcurrentQueries,
        );

        var callCount = 0;
        final pendingBackgroundQuery = Completer<List<Event>>();
        final profileEvent = _createTestEvent(
          kind: EventKind.metadata,
          content: '{"name": "Alice"}',
        );

        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) {
          callCount++;
          if (callCount == 1) {
            return pendingBackgroundQuery.future;
          }
          return Future.value([profileEvent]);
        });

        final backgroundQuery = client.queryEvents(
          [
            Filter(kinds: const [1059]),
          ],
          useCache: false,
        );
        await pumpEventQueue();

        final result = await client
            .queryUsers('alice')
            .timeout(const Duration(milliseconds: 100));

        expect(result, [profileEvent]);
        expect(callCount, 2);

        pendingBackgroundQuery.complete(<Event>[]);
        await backgroundQuery;
      });
    });

    group('countEvents', () {
      test('returns count from relay COUNT response', () async {
        final filters = [
          Filter(kinds: [EventKind.textNote], authors: [testPublicKey]),
        ];
        const countResponse = CountResponse(count: 42);

        when(
          () => mockNostr.countEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => countResponse);

        final result = await client.countEvents(filters);

        expect(result.count, equals(42));
        expect(result.approximate, isFalse);
        expect(result.source, equals(CountSource.websocket));
      });

      test('handles approximate counts', () async {
        final filters = [
          Filter(kinds: [EventKind.textNote]),
        ];
        const countResponse = CountResponse(count: 1000, approximate: true);

        when(
          () => mockNostr.countEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => countResponse);

        final result = await client.countEvents(filters);

        expect(result.count, equals(1000));
        expect(result.approximate, isTrue);
        expect(result.source, equals(CountSource.websocket));
      });

      test('normalizes relay sentinel counts to zero', () async {
        final filters = [
          Filter(kinds: [EventKind.textNote]),
        ];
        const countResponse = CountResponse(count: 9223372036854775807);

        when(
          () => mockNostr.countEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => countResponse);

        final result = await client.countEvents(filters);

        expect(result.count, equals(0));
        expect(result.source, equals(CountSource.websocket));
      });

      test('throws $CountUnavailableException when no relay answers, '
          'without fetching events', () async {
        final filters = [
          Filter(kinds: [EventKind.textNote]),
        ];
        when(
          () => mockNostr.countEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            timeout: any(named: 'timeout'),
          ),
        ).thenThrow(CountNotSupportedException('No relay responded to COUNT'));
        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => [_createTestEvent(), _createTestEvent()]);

        await expectLater(
          client.countEvents(filters),
          throwsA(isA<CountUnavailableException>()),
        );
        verifyNever(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        );
      });

      test(
        'redials once and asks again when no relay took the COUNT',
        () async {
          final calls = <String>[];
          var attempts = 0;
          when(
            () => mockNostr.countEvents(
              any(),
              id: any(named: 'id'),
              tempRelays: any(named: 'tempRelays'),
              relayTypes: any(named: 'relayTypes'),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((_) async {
            calls.add('COUNT');
            attempts++;
            if (attempts == 1) {
              throw CountNotSentException('No relay accepted COUNT');
            }
            return const CountResponse(count: 7);
          });
          when(mockRelayManager.retryDisconnectedRelays).thenAnswer((_) async {
            calls.add('redial');
          });

          final result = await client.countEvents([
            Filter(kinds: [EventKind.textNote]),
          ]);

          expect(calls, equals(['COUNT', 'redial', 'COUNT']));
          expect(result.count, equals(7));
        },
      );

      test('gives up after one redial when no relay takes the COUNT either '
          'time', () async {
        when(
          () => mockNostr.countEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            timeout: any(named: 'timeout'),
          ),
        ).thenThrow(CountNotSentException('No relay accepted COUNT'));
        when(mockRelayManager.retryDisconnectedRelays).thenAnswer((_) async {});

        await expectLater(
          client.countEvents([
            Filter(kinds: [EventKind.textNote]),
          ]),
          throwsA(isA<CountUnavailableException>()),
        );
        verify(mockRelayManager.retryDisconnectedRelays).called(1);
        verify(
          () => mockNostr.countEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            timeout: any(named: 'timeout'),
          ),
        ).called(2);
      });

      test(
        'does not redial when a relay took the COUNT but none answered',
        () async {
          when(
            () => mockNostr.countEvents(
              any(),
              id: any(named: 'id'),
              tempRelays: any(named: 'tempRelays'),
              relayTypes: any(named: 'relayTypes'),
              timeout: any(named: 'timeout'),
            ),
          ).thenThrow(
            CountNotSupportedException('No relay responded to COUNT'),
          );

          await expectLater(
            client.countEvents([
              Filter(kinds: [EventKind.textNote]),
            ]),
            throwsA(isA<CountUnavailableException>()),
          );
          verifyNever(mockRelayManager.retryDisconnectedRelays);
        },
      );

      test(
        'does not ask again once the redial has spent the whole timeout',
        () async {
          final redial = Completer<void>();
          addTearDown(() {
            if (!redial.isCompleted) redial.complete();
          });
          when(
            () => mockNostr.countEvents(
              any(),
              id: any(named: 'id'),
              tempRelays: any(named: 'tempRelays'),
              relayTypes: any(named: 'relayTypes'),
              timeout: any(named: 'timeout'),
            ),
          ).thenThrow(CountNotSentException('No relay accepted COUNT'));
          when(
            mockRelayManager.retryDisconnectedRelays,
          ).thenAnswer((_) => redial.future);

          await expectLater(
            client.countEvents(
              [
                Filter(kinds: [EventKind.textNote]),
              ],
              timeout: const Duration(milliseconds: 200),
            ),
            throwsA(isA<CountUnavailableException>()),
          );
          verify(
            () => mockNostr.countEvents(
              any(),
              id: any(named: 'id'),
              tempRelays: any(named: 'tempRelays'),
              relayTypes: any(named: 'relayTypes'),
              timeout: any(named: 'timeout'),
            ),
          ).called(1);
        },
        timeout: const Timeout(Duration(seconds: 3)),
      );

      test('asks again after an earlier reconnect timeout', () async {
        var attempts = 0;
        when(
          () => mockNostr.countEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async {
          attempts++;
          if (attempts == 1) {
            throw CountNotSentException('No relay accepted COUNT');
          }
          return const CountResponse(count: 7);
        });
        when(
          mockRelayManager.retryDisconnectedRelays,
        ).thenThrow(TimeoutException('Reconnect timed out'));

        final result = await client.countEvents([
          Filter(kinds: [EventKind.textNote]),
        ]);

        expect(result.count, equals(7));
        verify(
          () => mockNostr.countEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            timeout: any(named: 'timeout'),
          ),
        ).called(2);
      });

      test('passes subscriptionId parameter', () async {
        final filters = [
          Filter(kinds: [EventKind.textNote]),
        ];
        const customId = 'my-count-sub';

        when(
          () => mockNostr.countEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => const CountResponse(count: 10));

        await client.countEvents(filters, subscriptionId: customId);

        verify(
          () => mockNostr.countEvents(
            any(),
            id: customId,
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            timeout: any(named: 'timeout'),
          ),
        ).called(1);
      });

      test('passes timeout parameter', () async {
        final filters = [
          Filter(kinds: [EventKind.textNote]),
        ];
        const customTimeout = Duration(seconds: 10);

        when(
          () => mockNostr.countEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => const CountResponse(count: 10));

        await client.countEvents(filters, timeout: customTimeout);

        verify(
          () => mockNostr.countEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            timeout: customTimeout,
          ),
        ).called(1);
      });

      test('passes tempRelays parameter', () async {
        final filters = [
          Filter(kinds: [EventKind.textNote]),
        ];
        final tempRelays = ['wss://temp.example.com'];

        when(
          () => mockNostr.countEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => const CountResponse(count: 10));

        await client.countEvents(filters, tempRelays: tempRelays);

        verify(
          () => mockNostr.countEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: tempRelays,
            relayTypes: any(named: 'relayTypes'),
            timeout: any(named: 'timeout'),
          ),
        ).called(1);
      });

      test('passes relayTypes parameter', () async {
        final filters = [
          Filter(kinds: [EventKind.textNote]),
        ];
        final relayTypes = [RelayType.normal];

        when(
          () => mockNostr.countEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => const CountResponse(count: 10));

        await client.countEvents(filters, relayTypes: relayTypes);

        verify(
          () => mockNostr.countEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: relayTypes,
            timeout: any(named: 'timeout'),
          ),
        ).called(1);
      });

      test('converts Filter objects to JSON', () async {
        final filters = [
          Filter(kinds: [EventKind.textNote], authors: [testPublicKey]),
        ];

        when(
          () => mockNostr.countEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => const CountResponse(count: 5));

        await client.countEvents(filters);

        final captured = verify(
          () => mockNostr.countEvents(
            captureAny(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            timeout: any(named: 'timeout'),
          ),
        ).captured;

        final capturedFilters = captured.first as List<Map<String, dynamic>>;
        expect(capturedFilters.first['kinds'], contains(EventKind.textNote));
        expect(capturedFilters.first['authors'], contains(testPublicKey));
      });
    });

    group('end-to-end query timeout (#7091)', () {
      test(
        'a pool waiter that exhausts its budget never starts a query',
        () async {
          final originalMax = NostrClient.maxConcurrentQueries;
          NostrClient.maxConcurrentQueries = 1;
          addTearDown(() => NostrClient.maxConcurrentQueries = originalMax);

          final firstQueryStarted = Completer<void>();
          final releaseFirstQuery = Completer<void>();
          var queryCount = 0;
          when(
            () => mockNostr.queryEvents(
              any(),
              id: any(named: 'id'),
              tempRelays: any(named: 'tempRelays'),
              relayTypes: any(named: 'relayTypes'),
              sendAfterAuth: any(named: 'sendAfterAuth'),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((_) async {
            queryCount++;
            if (queryCount == 1) {
              firstQueryStarted.complete();
              await releaseFirstQuery.future;
            }
            return const [];
          });

          final pooledClient = NostrClient.forTesting(
            nostr: mockNostr,
            relayManager: mockRelayManager,
          );
          addTearDown(pooledClient.dispose);
          final firstQuery = pooledClient.queryEventsDetailed(
            [
              Filter(kinds: const [EventKind.textNote]),
            ],
            useCache: false,
          );
          await firstQueryStarted.future;

          final expired = await pooledClient.queryEventsDetailed(
            [
              Filter(kinds: const [EventKind.reaction]),
            ],
            useCache: false,
            timeout: Duration.zero,
          );
          expect(expired.timedOut, isTrue);

          releaseFirstQuery.complete();
          await firstQuery;
          await Future<void>.delayed(Duration.zero);

          expect(
            queryCount,
            1,
            reason:
                'an expired pool waiter must release its eventual slot '
                'without dispatching abandoned network work',
          );
        },
      );

      test('a stalled reconnect is spent from the query budget', () async {
        // An empty connected set routes the call through the pre-query
        // reconnect. That reconnect is awaited, so unless it spends from the
        // same budget the declared timeout bounds only the websocket leg --
        // measured at 48s against a declared 5s on device (#7091).
        when(() => mockRelayManager.connectedRelays).thenReturn(const []);
        final stalledReconnect = Completer<void>();
        addTearDown(() {
          if (!stalledReconnect.isCompleted) stalledReconnect.complete();
        });
        when(
          mockRelayManager.retryDisconnectedRelays,
        ).thenAnswer((_) => stalledReconnect.future);
        // A real REQ does not settle in a microtask, so an instantly
        // completing stub would win the race against a zero-length deadline
        // and hide the behaviour under test.
        final stalledQuery = Completer<List<Event>>();
        addTearDown(() {
          if (!stalledQuery.isCompleted) stalledQuery.complete(const []);
        });
        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) => stalledQuery.future);

        final result = await client.queryEventsDetailed(
          [
            Filter(kinds: const [EventKind.dmRelaysList]),
          ],
          useCache: false,
          timeout: Duration.zero,
        );
        expect(
          result.timedOut,
          isTrue,
          reason: 'exhausting the budget is inconclusive, not an empty answer',
        );
      });

      test('the non-pooled query path spends the same deadline', () async {
        final stalledQuery = Completer<List<Event>>();
        addTearDown(() {
          if (!stalledQuery.isCompleted) stalledQuery.complete(const []);
        });
        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) => stalledQuery.future);

        final result = await client.queryEventsDetailed(
          [
            Filter(kinds: const [EventKind.metadata]),
          ],
          useCache: false,
          useQueryPool: false,
          timeout: Duration.zero,
        );

        expect(result.timedOut, isTrue);
      });
    });
  });
}

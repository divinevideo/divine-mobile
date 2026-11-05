// ABOUTME: Tests for NIP-65 kind:10002 relay-list publishing.
// ABOUTME: Covers marker preservation, indexer acceptance, cache, and retry state.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/repositories/relay_list_repository.dart';
import 'package:openvine/services/relay_discovery_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockRelayDiscoveryService extends Mock
    implements RelayDiscoveryService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockNostrClient nostrClient;
  late _MockRelayDiscoveryService relayDiscoveryService;
  late SharedPreferences prefs;
  late LocalNostrSigner signer;
  late String pubkey;
  late List<DiscoveredRelay> discoveredRelays;

  setUpAll(() {
    registerFallbackValue(
      Event('0' * 64, EventKind.relayListMetadata, const [], ''),
    );
    registerFallbackValue(Duration.zero);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    nostrClient = _MockNostrClient();
    relayDiscoveryService = _MockRelayDiscoveryService();
    signer = LocalNostrSigner(generatePrivateKey());
    pubkey = (await signer.getPublicKey())!;
    discoveredRelays = const [];

    when(
      () => nostrClient.queryEventsDetailed(
        any(),
        useCache: false,
        requireAllRelaysSettled: true,
        tempRelays: any(named: 'tempRelays'),
      ),
    ).thenAnswer(
      (_) async => (events: <Event>[], timedOut: false, noRelays: false),
    );
    when(() => nostrClient.hasKeys).thenReturn(true);
    when(() => nostrClient.publicKey).thenReturn(pubkey);
    when(() => nostrClient.signer).thenReturn(signer);
    when(() => nostrClient.configuredRelays).thenReturn(const [
      'wss://relay.divine.video',
      'wss://read.example',
      'wss://write.example',
      'wss://new.example',
    ]);
    when(
      () => relayDiscoveryService.clearCache(any()),
    ).thenAnswer((_) async {});
    when(
      () => nostrClient.publishEventAwaitOk(
        any(),
        targetRelays: any(named: 'targetRelays'),
        timeout: any(named: 'timeout'),
      ),
    ).thenAnswer((invocation) async {
      final event = invocation.positionalArguments.first as Event;
      return PublishOutcome(
        eventId: event.id,
        acceptedBy: const ['wss://purplepag.es'],
        rejectedBy: const {},
        noResponseFrom: const [],
      );
    });
  });

  RelayListRepository buildRepository({
    EnvironmentConfig environment = EnvironmentConfig.production,
  }) {
    return RelayListRepository(
      nostrClient: nostrClient,
      environment: environment,
      relayDiscoveryService: relayDiscoveryService,
      sharedPreferences: prefs,
      discoveredRelays: () => discoveredRelays,
    );
  }

  group('publishConfiguredRelayList', () {
    test(
      'publishes configured relays as kind 10002 and preserves markers',
      () async {
        discoveredRelays = const [
          DiscoveredRelay(url: 'wss://read.example', write: false),
          DiscoveredRelay(url: 'wss://write.example', read: false),
        ];

        final result = await buildRepository().publishConfiguredRelayList();

        expect(result.status, RelayListPublishStatus.published);
        final captured = verify(
          () => nostrClient.publishEventAwaitOk(
            captureAny(),
            targetRelays: captureAny(named: 'targetRelays'),
            timeout: captureAny(named: 'timeout'),
          ),
        ).captured;
        // mocktail returns captures ordered by argument name, not call order.
        final event = captured[0] as Event;
        final timeout = captured[1] as Duration;
        final targetRelays = captured[2] as List<String>;

        expect(event.kind, EventKind.relayListMetadata);
        expect(event.pubkey, pubkey);
        expect(event.tags, [
          ['r', 'wss://relay.divine.video'],
          ['r', 'wss://read.example', 'read'],
          ['r', 'wss://write.example', 'write'],
          ['r', 'wss://new.example'],
        ]);
        expect(targetRelays, contains('wss://relay.divine.video'));
        expect(targetRelays, contains('wss://purplepag.es'));
        // Settings blocks on this publish, so it must not inherit the 15s
        // default on top of the signer timeout.
        expect(timeout, lessThan(const Duration(seconds: 15)));
        verify(
          () => relayDiscoveryService.clearCache(Nip19.encodePubKey(pubkey)),
        ).called(1);
        expect(buildRepository().isDirty(pubkey), isFalse);
      },
    );

    test('preserves unseen relay entries and opaque event data', () async {
      final remote = Event(
        pubkey,
        EventKind.relayListMetadata,
        [
          ['r', 'wss://remote.example', 'write', 'opaque-extension'],
          ['client', 'another-client'],
        ],
        'opaque-content',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      when(
        () => nostrClient.queryEventsDetailed(
          any(),
          useCache: false,
          requireAllRelaysSettled: true,
          tempRelays: any(named: 'tempRelays'),
        ),
      ).thenAnswer(
        (_) async => (events: [remote], timedOut: false, noRelays: false),
      );

      await buildRepository().publishConfiguredRelayList();

      final event =
          verify(
                () => nostrClient.publishEventAwaitOk(
                  captureAny(),
                  targetRelays: any(named: 'targetRelays'),
                  timeout: any(named: 'timeout'),
                ),
              ).captured.single
              as Event;
      expect(event.tags, containsAll(remote.tags));
      expect(event.content, remote.content);
      expect(event.createdAt, greaterThan(remote.createdAt));
    });

    test(
      'refuses a partial relay read even when it returned an event',
      () async {
        when(
          () => nostrClient.queryEventsDetailed(
            any(),
            useCache: false,
            requireAllRelaysSettled: true,
            tempRelays: any(named: 'tempRelays'),
          ),
        ).thenAnswer(
          (_) async => (
            events: [Event(pubkey, EventKind.relayListMetadata, [], '')],
            timedOut: true,
            noRelays: false,
          ),
        );

        final result = await buildRepository().publishConfiguredRelayList();

        expect(result.status, RelayListPublishStatus.failed);
        verifyNever(
          () => nostrClient.publishEventAwaitOk(
            any(),
            targetRelays: any(named: 'targetRelays'),
            timeout: any(named: 'timeout'),
          ),
        );
      },
    );

    test(
      'removes only the selected relay and preserves every other tag',
      () async {
        final remote = Event(pubkey, 10002, [
          ['r', 'wss://removed.example', 'read'],
          ['r', 'wss://remote.example', 'write', 'extension'],
          ['opaque', 'value'],
        ], 'private-content');
        when(
          () => nostrClient.queryEventsDetailed(
            any(),
            useCache: false,
            requireAllRelaysSettled: true,
            tempRelays: any(named: 'tempRelays'),
          ),
        ).thenAnswer(
          (_) async => (events: [remote], timedOut: false, noRelays: false),
        );

        await buildRepository().publishConfiguredRelayList(
          removedRelay: 'wss://removed.example',
        );

        final event =
            verify(
                  () => nostrClient.publishEventAwaitOk(
                    captureAny(),
                    targetRelays: any(named: 'targetRelays'),
                    timeout: any(named: 'timeout'),
                  ),
                ).captured.single
                as Event;
        expect(event.tags, remote.tags.skip(1).toList());
        expect(event.content, remote.content);
      },
    );

    test(
      'adds only the requested relay without publishing automatic connections',
      () async {
        final remote = Event(pubkey, 10002, [
          ['r', 'wss://remote.example', 'read', 'opaque'],
        ], 'opaque');
        when(
          () => nostrClient.queryEventsDetailed(
            any(),
            useCache: false,
            requireAllRelaysSettled: true,
            tempRelays: any(named: 'tempRelays'),
          ),
        ).thenAnswer(
          (_) async => (events: [remote], timedOut: false, noRelays: false),
        );
        await buildRepository().publishConfiguredRelayList(
          addedRelay: 'wss://added.example',
        );
        final event =
            verify(
                  () => nostrClient.publishEventAwaitOk(
                    captureAny(),
                    targetRelays: any(named: 'targetRelays'),
                    timeout: any(named: 'timeout'),
                  ),
                ).captured.single
                as Event;
        expect(event.tags, [
          ...remote.tags,
          ['r', 'wss://added.example'],
        ]);
      },
    );

    test(
      'retains an accepted addition across restart before relay echo',
      () async {
        await buildRepository().publishConfiguredRelayList(
          addedRelay: 'wss://one.example',
        );
        await buildRepository().publishConfiguredRelayList(
          addedRelay: 'wss://two.example',
        );
        final events = verify(
          () => nostrClient.publishEventAwaitOk(
            captureAny(),
            targetRelays: any(named: 'targetRelays'),
            timeout: any(named: 'timeout'),
          ),
        ).captured.cast<Event>();
        expect(events.last.tags, [
          ['r', 'wss://one.example'],
          ['r', 'wss://two.example'],
        ]);
      },
    );

    test('durable retry applies removal to the latest remote list', () async {
      final remote = Event(pubkey, 10002, [
        ['r', 'wss://removed.example'],
        ['r', 'wss://remote.example', 'read'],
      ], 'opaque');
      var inconclusive = true;
      when(
        () => nostrClient.queryEventsDetailed(
          any(),
          useCache: false,
          requireAllRelaysSettled: true,
          tempRelays: any(named: 'tempRelays'),
        ),
      ).thenAnswer(
        (_) async =>
            (events: [remote], timedOut: inconclusive, noRelays: false),
      );
      final first = buildRepository();
      expect(
        (await first.publishConfiguredRelayList(
          removedRelay: 'wss://removed.example',
        )).status,
        RelayListPublishStatus.failed,
      );
      inconclusive = false;
      final second = buildRepository();
      expect(
        (await second.retryDirtyPublish()).status,
        RelayListPublishStatus.published,
      );
      final event =
          verify(
                () => nostrClient.publishEventAwaitOk(
                  captureAny(),
                  targetRelays: any(named: 'targetRelays'),
                  timeout: any(named: 'timeout'),
                ),
              ).captured.single
              as Event;
      expect(event.tags, [
        ['r', 'wss://remote.example', 'read'],
      ]);
      expect(second.isDirty(pubkey), isFalse);
    });

    test(
      'settings waits for another relay writer on the same client',
      () async {
        final entered = Completer<void>();
        final release = Completer<void>();
        final bootstrap = serializeRelayListWrite(nostrClient, () async {
          entered.complete();
          await release.future;
        });
        await entered.future;
        final settings = buildRepository().publishConfiguredRelayList(
          addedRelay: 'wss://added.example',
        );
        await pumpEventQueue();
        verifyNever(
          () => nostrClient.queryEventsDetailed(
            any(),
            useCache: false,
            requireAllRelaysSettled: true,
            tempRelays: any(named: 'tempRelays'),
          ),
        );
        release.complete();
        await bootstrap;
        expect((await settings).status, RelayListPublishStatus.published);
      },
    );

    test(
      'bootstrap does not replace an accepted settings list before echo',
      () async {
        await buildRepository().publishConfiguredRelayList(
          addedRelay: 'wss://chosen.example',
        );
        final bootstrap = await signer.signEvent(
          Event(
            pubkey,
            10002,
            [
              ['r', 'wss://relay.divine.video'],
            ],
            '',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 10,
          ),
        );

        expect(
          await NostrService.bootstrapCallbackFor(nostrClient)(
            bootstrap!,
            EnvironmentConfig.production.indexerRelays,
          ),
          isTrue,
        );
        final events = verify(
          () => nostrClient.publishEventAwaitOk(
            captureAny(),
            targetRelays: any(named: 'targetRelays'),
            timeout: any(named: 'timeout'),
          ),
        ).captured.cast<Event>();
        expect(events, hasLength(1));
        expect(events.single.tags, [
          ['r', 'wss://chosen.example'],
        ]);
      },
    );

    test('settings preserves an accepted bootstrap list before echo', () async {
      final bootstrap = await signer.signEvent(
        Event(pubkey, 10002, [
          ['r', 'wss://bootstrap.example'],
        ], ''),
      );
      expect(
        await NostrService.bootstrapCallbackFor(nostrClient)(
          bootstrap!,
          EnvironmentConfig.production.indexerRelays,
        ),
        isTrue,
      );
      await buildRepository().publishConfiguredRelayList(
        addedRelay: 'wss://chosen.example',
      );
      final events = verify(
        () => nostrClient.publishEventAwaitOk(
          captureAny(),
          targetRelays: any(named: 'targetRelays'),
          timeout: any(named: 'timeout'),
        ),
      ).captured.cast<Event>();
      expect(events, hasLength(2));
      expect(events.last.tags, [
        ['r', 'wss://bootstrap.example'],
        ['r', 'wss://chosen.example'],
      ]);
      expect(events.last.createdAt, greaterThan(events.first.createdAt));
    });

    test(
      'serializes reads and retains a just-accepted addition before relay echo',
      () async {
        final firstRead =
            Completer<({List<Event> events, bool timedOut, bool noRelays})>();
        final readStarted = Completer<void>();
        var reads = 0;
        when(
          () => nostrClient.queryEventsDetailed(
            any(),
            useCache: false,
            requireAllRelaysSettled: true,
            tempRelays: any(named: 'tempRelays'),
          ),
        ).thenAnswer((_) {
          reads++;
          if (reads == 1) readStarted.complete();
          return reads == 1
              ? firstRead.future
              : Future.value((
                  events: <Event>[],
                  timedOut: false,
                  noRelays: false,
                ));
        });
        final repository = buildRepository();
        final first = repository.publishConfiguredRelayList(
          addedRelay: 'wss://one.example',
        );
        final second = repository.publishConfiguredRelayList(
          addedRelay: 'wss://two.example',
        );
        await readStarted.future;
        expect(reads, 1);
        firstRead.complete((
          events: <Event>[],
          timedOut: false,
          noRelays: false,
        ));
        await Future.wait([first, second]);
        final events = verify(
          () => nostrClient.publishEventAwaitOk(
            captureAny(),
            targetRelays: any(named: 'targetRelays'),
            timeout: any(named: 'timeout'),
          ),
        ).captured.cast<Event>();
        expect(events.last.tags, [
          ['r', 'wss://one.example'],
          ['r', 'wss://two.example'],
        ]);
        expect(events.last.createdAt, greaterThan(events.first.createdAt));
      },
    );

    test(
      'skips without dirtying when the client has no signing keys',
      () async {
        when(() => nostrClient.hasKeys).thenReturn(false);
        when(() => nostrClient.publicKey).thenReturn('');

        final result = await buildRepository().publishConfiguredRelayList();

        expect(result.status, RelayListPublishStatus.skippedNoKeys);
        verifyNever(
          () => nostrClient.publishEventAwaitOk(
            any(),
            targetRelays: any(named: 'targetRelays'),
            timeout: any(named: 'timeout'),
          ),
        );
        expect(buildRepository().isDirty(pubkey), isFalse);
      },
    );

    test('skips publishing in non-production environments', () async {
      final result = await buildRepository(
        environment: const EnvironmentConfig(
          environment: AppEnvironment.staging,
        ),
      ).publishConfiguredRelayList();

      expect(result.status, RelayListPublishStatus.skippedNonProduction);
      verifyNever(
        () => nostrClient.publishEventAwaitOk(
          any(),
          targetRelays: any(named: 'targetRelays'),
          timeout: any(named: 'timeout'),
        ),
      );
      expect(buildRepository().isDirty(pubkey), isFalse);
    });

    test(
      'marks dirty and does not clear cache when no indexer accepts',
      () async {
        when(
          () => nostrClient.publishEventAwaitOk(
            any(),
            targetRelays: any(named: 'targetRelays'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((invocation) async {
          final event = invocation.positionalArguments.first as Event;
          return PublishOutcome(
            eventId: event.id,
            acceptedBy: const ['wss://relay.divine.video'],
            rejectedBy: const {},
            noResponseFrom: const [],
          );
        });

        final repository = buildRepository();
        final result = await repository.publishConfiguredRelayList();

        expect(result.status, RelayListPublishStatus.failed);
        expect(repository.isDirty(pubkey), isTrue);
        verifyNever(() => relayDiscoveryService.clearCache(any()));
      },
    );
  });

  group('retryDirtyPublish', () {
    test(
      'retryDirtyPublish republishes only when the dirty flag is set',
      () async {
        final repository = buildRepository();

        expect(
          await repository.retryDirtyPublish(),
          isA<RelayListPublishResult>()
              .having(
                (result) => result.status,
                'status',
                RelayListPublishStatus.skippedNotDirty,
              )
              .having((result) => result.localOnly, 'localOnly', isFalse),
        );
        verifyNever(
          () => nostrClient.publishEventAwaitOk(
            any(),
            targetRelays: any(named: 'targetRelays'),
            timeout: any(named: 'timeout'),
          ),
        );

        await prefs.setBool('relay_list_publish_dirty_$pubkey', true);
        final result = await repository.retryDirtyPublish();

        expect(result.status, RelayListPublishStatus.published);
        verify(
          () => nostrClient.publishEventAwaitOk(
            any(),
            targetRelays: any(named: 'targetRelays'),
            timeout: any(named: 'timeout'),
          ),
        ).called(1);
        expect(repository.isDirty(pubkey), isFalse);
      },
    );
  });
}

import 'dart:async';

import 'package:badge_repository/badge_repository.dart';
import 'package:clock/clock.dart' as app_clock;
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends Mock implements NostrClient {}

class _Api extends Mock implements FunnelcakeApiClient {}

class _Verifier extends Mock implements EventVerifyWorker {}

class _ExpiredStopwatch extends Stopwatch {
  @override
  Duration get elapsed => const Duration(seconds: 11);
}

class _MutableStopwatch extends Stopwatch {
  Duration elapsedValue = Duration.zero;
  @override
  Duration get elapsed => elapsedValue;
}

void main() {
  late _Client client;
  late _Api api;
  late BadgeRepository repository;
  var events = <Event>[];
  var deletions = <Event>[];
  var incomplete = false;
  final incompleteIssuers = <String>{};
  final cappedIssuers = <String>{};
  final hidden = <String>{};
  final requests = <Filter>[];
  final key1 = '1'.padLeft(64, '0');
  final key2 = '2'.padLeft(64, '0');
  final issuer1 = getPublicKey(key1);
  final issuer2 = getPublicKey(key2);

  Event definition(
    String key, {
    int at = 100,
    String name = 'Loop makers',
    String identifier = 'shared',
  }) => Event(
    getPublicKey(key),
    EventKind.badgeDefinition,
    [
      ['d', identifier],
      ['name', name],
    ],
    '',
    createdAt: at,
  )..sign(key);

  Event deletion(
    String key,
    Event target, {
    int at = 100,
    bool address = true,
  }) => Event(
    getPublicKey(key),
    EventKind.eventDeletion,
    [
      [
        if (address) 'a' else 'e',
        if (address) '30009:${target.pubkey}:shared' else target.id,
      ],
    ],
    '',
    createdAt: at,
  )..sign(key);

  Future<BadgeRepository> makeRepository({
    EventVerifyWorkerSpawner? spawner,
    List<String> pinnedIssuers = const [],
    Stopwatch Function()? stopwatchFactory,
  }) async => BadgeRepository(
    nostrClient: client,
    sharedPreferences: await SharedPreferences.getInstance(),
    currentPubkey: () => null,
    signer: () => LocalNostrSigner(key1),
    signEvent:
        ({required kind, required content, required tags, createdAt}) async =>
            null,
    definitionRelayUrl: 'wss://relay.example',
    funnelcakeApiClient: api,
    isHiddenPubkey: hidden.contains,
    discoveryVerifierSpawner: spawner,
    discoveryIssuerPubkeys: pinnedIssuers,
    stopwatchFactory: stopwatchFactory,
  );

  setUpAll(() {
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(Filter());
    registerFallbackValue(Duration.zero);
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    client = _Client();
    api = _Api();
    events = [];
    deletions = [];
    incomplete = false;
    incompleteIssuers.clear();
    cappedIssuers.clear();
    hidden.clear();
    requests.clear();
    when(
      () => client.queryEventsDetailed(
        any(),
        tempRelays: any(named: 'tempRelays'),
        relayTypes: any(named: 'relayTypes'),
        useCache: false,
        timeout: any(named: 'timeout'),
        requireAllRelaysSettled: true,
      ),
    ).thenAnswer((call) async {
      final filters = call.positionalArguments.single as List<Filter>;
      final filter = filters.first;
      requests.addAll(filters);
      expect(call.namedArguments[#tempRelays], ['wss://relay.example']);
      expect(call.namedArguments[#relayTypes], [RelayType.temp]);
      return (
        events: filter.kinds!.contains(EventKind.badgeDefinition)
            ? events
            : deletions,
        timedOut: incomplete,
        noRelays: false,
      );
    });
    when(
      () => client.readEvents(
        any(),
        tempRelays: any(named: 'tempRelays'),
        relayTypes: any(named: 'relayTypes'),
        useCache: false,
        timeout: any(named: 'timeout'),
        requireAllRelaysSettled: true,
        maxCollectedEvents: any(named: 'maxCollectedEvents'),
      ),
    ).thenAnswer((call) async {
      final filters = call.positionalArguments.single as List<Filter>;
      requests.addAll(filters);
      final issuer = filters.first.authors!.single;
      return QueryResult(
        events: deletions.where((event) => event.pubkey == issuer).toList(),
        endedBy: incompleteIssuers.contains(issuer)
            ? QueryEnd.deadline
            : QueryEnd.complete,
        possiblyCapped: cappedIssuers.contains(issuer),
      );
    });
    repository = await makeRepository();
  });
  tearDown(() => repository.dispose());

  group('loadPublicDefinitions', () {
    test(
      'keeps pinned catalogue definitions outside a flooded recency window',
      () async {
        await repository.dispose();
        repository = await makeRepository(pinnedIssuers: [issuer2]);
        events = [
          for (var i = 0; i < 300; i++)
            definition(key1, at: 1000 + i, identifier: 'group-$i'),
        ];
        final pinned = definition(key2, at: 10, name: 'Official award');
        when(
          () => api.getBadgeDefinitions(issuer: issuer2),
        ).thenAnswer((_) async => BadgeDefinitionsResponse(badges: [pinned]));
        final result = await repository.loadPublicDefinitions();
        expect(result.where((d) => d.event.pubkey == issuer1), hasLength(3));
        expect(result.map((d) => d.name), contains('Official award'));
        expect(result.first.dTag, 'group-299');
      },
    );

    test('catalogue outage preserves discovered communities', () async {
      await repository.dispose();
      repository = await makeRepository(pinnedIssuers: [issuer2]);
      events = [definition(key1)];
      when(
        () => api.getBadgeDefinitions(issuer: issuer2),
      ).thenThrow(Exception('offline'));
      when(
        () => client.readAllEvents(
          any(),
          timeout: any(named: 'timeout'),
          tempRelays: any(named: 'tempRelays'),
        ),
      ).thenAnswer(
        (_) async =>
            const PagedQueryResult(events: [], isComplete: false, pages: 0),
      );
      expect(
        (await repository.loadPublicDefinitions()).single.event.pubkey,
        issuer1,
      );
    });

    test('the deletion phase deadline prevents queued issuer reads', () async {
      await repository.dispose();
      repository = await makeRepository(
        stopwatchFactory: _ExpiredStopwatch.new,
      );
      events = [definition(key1), definition(key2)];
      expect(await repository.loadPublicDefinitions(), isEmpty);
      expect(requests, hasLength(1));
    });

    test(
      'reuses the worker but skips signatures already verified by the pool',
      () async {
        await repository.dispose();
        final verifier = _Verifier();
        when(() => verifier.verify(any())).thenAnswer((_) async => true);
        var spawns = 0;
        repository = await makeRepository(
          spawner: () async {
            spawns++;
            return verifier;
          },
        );
        events = [definition(key1), definition(key2)..markSignatureVerified()];
        expect(await repository.loadPublicDefinitions(), hasLength(2));
        expect(await repository.loadPublicDefinitions(), hasLength(2));
        expect(spawns, 1);
        verify(() => verifier.verify(any())).called(2);
      },
    );

    test(
      'a missing native verifier falls back to signature verification on retry',
      () async {
        await repository.dispose();
        repository = await makeRepository(
          spawner: () async => throw UnsupportedError('native unavailable'),
        );
        final forged = definition(key2)..sig = '0' * 128;
        events = [definition(key1), forged];
        expect(
          (await repository.loadPublicDefinitions()).single.event.pubkey,
          issuer1,
        );
        expect(
          (await repository.loadPublicDefinitions()).single.event.pubkey,
          issuer1,
        );
      },
    );

    test(
      'disposal before the initial relay answer never creates a worker',
      () async {
        await repository.dispose();
        var spawns = 0;
        final verifier = _Verifier();
        when(() => verifier.verify(any())).thenAnswer((_) async => true);
        repository = await makeRepository(
          spawner: () async {
            spawns++;
            return verifier;
          },
        );
        final response =
            Completer<({List<Event> events, bool timedOut, bool noRelays})>();
        when(
          () => client.queryEventsDetailed(
            any(),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            useCache: false,
            timeout: any(named: 'timeout'),
            requireAllRelaysSettled: true,
          ),
        ).thenAnswer((_) => response.future);
        final loading = repository.loadPublicDefinitions();
        await repository.dispose();
        response.complete((
          events: [definition(key1)],
          timedOut: false,
          noRelays: false,
        ));
        expect(await loading, isEmpty);
        expect(spawns, 0);
      },
    );

    test('signature work consumes the deletion phase deadline', () async {
      await repository.dispose();
      final timer = _MutableStopwatch();
      final verifier = _Verifier();
      when(() => verifier.verify(any())).thenAnswer((_) async {
        timer.elapsedValue = const Duration(seconds: 11);
        return true;
      });
      repository = await makeRepository(
        spawner: () async => verifier,
        stopwatchFactory: () => timer,
      );
      events = [definition(key1)..markSignatureVerified()];
      // A foreign-target deletion cannot remove the issuer's badge by itself.
      deletions = [deletion(key1, definition(key2))];
      expect(await repository.loadPublicDefinitions(), isEmpty);
    });

    test(
      'deleted recent badges do not consume an issuer display allowance',
      () async {
        events = [
          for (var i = 0; i < 4; i++)
            definition(key1, at: 100 + i, identifier: 'group-$i'),
        ];
        deletions = events
            .skip(1)
            .map((event) => deletion(key1, event, address: false))
            .toList();
        final result = await repository.loadPublicDefinitions();
        expect(result.single.dTag, 'group-0');
      },
    );

    test('a pending signature check stops at the deletion deadline', () async {
      await repository.dispose();
      fakeAsync((clock) {
        final verified = Completer<bool>();
        final verifier = _Verifier();
        when(() => verifier.verify(any())).thenAnswer((_) => verified.future);
        events = [definition(key1)..markSignatureVerified()];
        deletions = [deletion(key1, definition(key2))];
        List<Nip58BadgeDefinition>? result;
        unawaited(
          makeRepository(
                spawner: () async => verifier,
                stopwatchFactory: app_clock.clock.stopwatch,
              )
              .then((created) {
                repository = created;
                return repository.loadPublicDefinitions();
              })
              .then((value) {
                result = value;
              }),
        );
        clock.flushMicrotasks();
        expect(result, isNull);
        clock.elapse(const Duration(seconds: 10));
        expect(result, isEmpty);
        verified.complete(true);
        clock.flushMicrotasks();
        var disposed = false;
        unawaited(repository.dispose().then((_) => disposed = true));
        clock.flushMicrotasks();
        expect(disposed, isTrue);
      });
      repository = await makeRepository();
    });

    test(
      'disposal during worker startup closes the late worker exactly once',
      () async {
        await repository.dispose();
        final started = Completer<EventVerifyWorker>();
        final verifier = _Verifier();
        repository = await makeRepository(spawner: () => started.future);
        events = [definition(key1)];
        final loading = repository.loadPublicDefinitions();
        await pumpEventQueue();
        final closing = repository.dispose();
        started.complete(verifier);
        await closing;
        expect(await loading, isEmpty);
        verify(verifier.close).called(1);
        repository = await makeRepository();
      },
    );

    test(
      'uses the injected platform verifier and closes it on disposal',
      () async {
        await repository.dispose();
        final verifier = _Verifier();
        when(() => verifier.verify(any())).thenAnswer((_) async => false);
        repository = await makeRepository(spawner: () async => verifier);
        events = [definition(key1)];
        expect(await repository.loadPublicDefinitions(), isEmpty);
        verify(() => verifier.verify(events.single.toJson())).called(1);
        await repository.dispose();
        verify(verifier.close).called(1);
        repository = await makeRepository();
      },
    );

    test(
      'discovers community issuers and keeps shared identifiers distinct',
      () async {
        events = [
          definition(key1),
          definition(key2, at: 200),
          definition(key1, at: 300, name: 'Updated'),
        ];
        final result = await repository.loadPublicDefinitions();
        expect(result.map((d) => d.coordinate), [
          '30009:$issuer1:shared',
          '30009:$issuer2:shared',
        ]);
        expect(result.first.name, 'Updated');
        expect(requests.first.limit, 300);
        expect(requests.first.authors, isNull);
        expect(requests[1].authors, [issuer1]);
        expect(requests[1].a, ['30009:$issuer1:shared']);
        expect(requests[1].since, 300);
        expect(requests[2].e, [events[2].id]);
        expect(requests[2].since, isNull);
      },
    );
    test(
      'same-second revisions select the lowest event ID in either relay order',
      () async {
        final first = definition(key1, name: 'First');
        final second = definition(key1, name: 'Second');
        // Independently derived canonical event hashes start bca9 and e276;
        // the First revision is the NIP-33 tie winner in both arrival orders.
        for (final order in [
          [second, first],
          [first, second],
        ]) {
          events = order;
          final result = await repository.loadPublicDefinitions();
          expect(result.single.name, 'First');
        }
      },
    );

    test(
      'drops hidden, unsigned, hash-corrupt and forged definitions',
      () async {
        hidden.add(issuer2);
        final unsigned = Event(issuer1, EventKind.badgeDefinition, [
          ['d', 'unsigned'],
        ], '');
        final corrupt = definition(key1)..content = 'changed';
        final forged = definition(key1)..sig = '0' * 128;
        events = [unsigned, corrupt, forged, definition(key2)];
        expect(await repository.loadPublicDefinitions(), isEmpty);
      },
    );
    test(
      'honors issuer deletion, rejects foreign deletion and retains newer replacement',
      () async {
        final a = definition(key1);
        final b = definition(key2);
        events = [a, b];
        deletions = [deletion(key1, a), deletion(key1, b)];
        expect(
          (await repository.loadPublicDefinitions()).map((d) => d.event.pubkey),
          [issuer2],
        );
        events = [definition(key1, at: 101)];
        expect(await repository.loadPublicDefinitions(), hasLength(1));
      },
    );
    test('event-id deletion cannot resurrect an older revision', () async {
      final old = definition(key1);
      final latest = definition(key1, at: 200);
      events = [old, latest];
      deletions = [deletion(key1, latest, at: 201, address: false)];
      expect(await repository.loadPublicDefinitions(), isEmpty);
    });
    test(
      'an event-ID deletion applies even when its clock is behind',
      () async {
        events = [definition(key1, at: 200)];
        deletions = [deletion(key1, events.first, at: 150, address: false)];
        expect(await repository.loadPublicDefinitions(), isEmpty);
      },
    );
    test('ignores a deletion whose signature does not verify', () async {
      events = [definition(key1)];
      deletions = [deletion(key1, events.first, at: 101)..sig = '0' * 128];
      final result = await repository.loadPublicDefinitions();
      expect(result.map((d) => d.coordinate), ['30009:$issuer1:shared']);
    });
    test('a saturated issuer cannot hide another community', () async {
      events = [definition(key1), definition(key2)];
      // Backdated, so none of them deletes the badge on its own.
      deletions = List.filled(1000, deletion(key1, events.first, at: 50));
      final result = await repository.loadPublicDefinitions();
      expect(result.map((d) => d.event.pubkey), [issuer2]);
    });
    test('a relay-clamped issuer cannot hide another community', () async {
      events = [definition(key1), definition(key2)];
      cappedIssuers.add(issuer1);
      final result = await repository.loadPublicDefinitions();
      expect(result.map((d) => d.event.pubkey), [issuer2]);
    });
    test('unanswered discovery does not claim an empty catalogue', () async {
      incomplete = true;
      await expectLater(
        repository.loadPublicDefinitions(),
        throwsA(isA<BadgeReadIncompleteException>()),
      );
    });
    test(
      'unanswered deletion read does not expose possibly deleted badges',
      () async {
        events = [definition(key1), definition(key2)];
        incompleteIssuers.add(issuer1);
        final result = await repository.loadPublicDefinitions();
        expect(result.map((d) => d.event.pubkey), [issuer2]);
      },
    );
  });

  group('loadHolderPreview', () {
    test('slow successful preview stays within its owning client budget', () {
      fakeAsync((clock) {
        final response = Completer<List<String>>();
        when(
          () =>
              api.getBadgeHolderPreview(creatorPubkey: issuer1, dTag: 'shared'),
        ).thenAnswer((_) => response.future);
        List<String>? result;
        Object? failure;
        unawaited(
          repository
              .loadHolderPreview(
                BadgeCoordinate(pubkey: issuer1, identifier: 'shared'),
              )
              .then<void>(
                (value) {
                  result = value;
                },
                onError: (Object error) {
                  failure = error;
                },
              ),
        );
        clock.elapse(const Duration(seconds: 11));
        expect(
          failure,
          isNull,
          reason: 'The API owns a 15-second whole-call deadline.',
        );
        expect(result, isNull);
        response.complete([issuer2]);
        clock.flushMicrotasks();
        expect(result, [issuer2]);
      });
    });

    test(
      'preview caps distinct valid visible people without a relay holder walk',
      () async {
        hidden.add(issuer2);
        final members = [
          for (var n = 3; n < 9; n++) n.toRadixString(16).padLeft(64, '0'),
        ];
        when(
          () =>
              api.getBadgeHolderPreview(creatorPubkey: issuer1, dTag: 'shared'),
        ).thenAnswer(
          (_) async => [issuer2, 'invalid', ...members, members.first],
        );
        expect(
          await repository.loadHolderPreview(
            BadgeCoordinate(pubkey: issuer1, identifier: 'shared'),
          ),
          members.take(3),
        );
        expect(requests, isEmpty);
      },
    );
  });
}

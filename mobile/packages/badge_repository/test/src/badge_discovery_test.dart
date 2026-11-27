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
import 'package:unified_logger/unified_logger.dart';

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

  Event ambiguousDefinition({String? firstIdentifier}) => Event(
    issuer1,
    EventKind.badgeDefinition,
    [
      ['d', ?firstIdentifier],
      ['d', 'shared'],
    ],
    '',
    createdAt: 200,
  )..sign(key1);

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
    signer: () => const UnauthenticatedSigner(),
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
      expect(call.namedArguments[#tempRelays], ['wss://relay.example']);
      expect(call.namedArguments[#relayTypes], [RelayType.temp]);
      final cap = call.namedArguments[#maxCollectedEvents];
      if (filters.first.kinds!.single == EventKind.badgeDefinition) {
        expect(cap, 300);
        return QueryResult(
          events: events.take(300).toList(),
          endedBy: incomplete ? QueryEnd.deadline : QueryEnd.complete,
          possiblyCapped: events.length >= 300,
        );
      }
      expect(cap, 1000);
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

  group('mergeBadgeDiscoveryDefinitions', () {
    test('keeps ranked order, deduplicates, and caps across sources', () {
      Nip58BadgeDefinition badge(String key, String identifier) =>
          Nip58BadgeParser.parseDefinition(
            definition(key, identifier: identifier),
          )!;
      final primary = [badge(key1, 'ranked'), badge(key2, 'official')];
      final external = [
        primary.first,
        for (var i = 0; i < 4; i++) badge(key1, 'external-$i'),
        for (var i = 0; i < 4; i++) badge(key2, 'official-$i'),
      ];
      final merged = mergeBadgeDiscoveryDefinitions(
        primary,
        external,
        pinnedIssuers: {issuer2},
      );
      expect(
        repository
            .mergeDiscoveryDefinitions(primary, external)
            .where((d) => d.event.pubkey == issuer2),
        hasLength(3),
      );
      expect(merged.take(2), primary);
      expect(merged.where((d) => d.event.pubkey == issuer1), hasLength(3));
      expect(merged.where((d) => d.event.pubkey == issuer2), hasLength(5));
      expect(mergeBadgeDiscoveryDefinitions(primary, []), same(primary));
    });
  });

  group('loadIndexedDiscovery', () {
    test('a retired caller does not start relay fallback', () async {
      final pending = Completer<List<IndexedBadgeCard>>();
      when(api.getBadgeDiscovery).thenAnswer((_) => pending.future);
      var active = true;
      final load = repository.loadIndexedDiscovery(isActive: () => active);
      active = false;
      pending.complete([]);
      expect(await load, isEmpty);
      expect(requests, isEmpty);
    });

    test('uses an index answer slowed by a cold connection', () {
      fakeAsync((clock) {
        events = [definition(key2)];
        final pending = Completer<List<IndexedBadgeCard>>();
        when(api.getBadgeDiscovery).thenAnswer((_) => pending.future);
        List<IndexedBadgeDiscovery>? cards;
        unawaited(
          repository.loadIndexedDiscovery().then((value) => cards = value),
        );
        // The first index read after app start took 1.3–2.1 s on device.
        clock.elapse(const Duration(seconds: 2));
        pending.complete([
          (
            definition: definition(key1),
            holderCount: 0,
            followerCount: 0,
            videos: <BadgeVideoPreview>[],
          ),
        ]);
        clock.flushMicrotasks();

        expect(cards?.map((card) => card.definition.event.pubkey), [issuer1]);
        expect(requests, isEmpty);
      });
    });

    test('falls back to relays only once a hung index used its budget', () {
      fakeAsync((clock) {
        events = [definition(key2)];
        when(
          api.getBadgeDiscovery,
        ).thenAnswer((_) => Completer<List<IndexedBadgeCard>>().future);
        unawaited(repository.loadIndexedDiscovery());

        clock.elapse(const Duration(milliseconds: 4900));
        expect(requests, isEmpty);

        clock.elapse(const Duration(milliseconds: 200));
        expect(requests, isNotEmpty);
      });
    });

    test('an empty raw page falls back to primary relay definitions', () async {
      final badge = definition(key1);
      events = [badge];
      when(api.getBadgeDiscovery).thenAnswer((_) async => []);
      final cards = await repository.loadIndexedDiscovery();
      expect(cards.map((card) => card.definition.event.id), [badge.id]);
      expect(requests, isNotEmpty);
    });

    test('a page with no valid definition falls back to relays', () async {
      final relayBadge = definition(key2);
      events = [relayBadge];
      final invalid = definition(key1)..sig = '';
      when(api.getBadgeDiscovery).thenAnswer(
        (_) async => [
          (
            definition: invalid,
            holderCount: 0,
            followerCount: 0,
            videos: <BadgeVideoPreview>[],
          ),
        ],
      );
      final cards = await repository.loadIndexedDiscovery();
      expect(cards.map((card) => card.definition.event.id), [relayBadge.id]);
    });

    test('a valid page hidden by viewer policy does not fall back', () async {
      events = [definition(key2)];
      hidden.add(issuer1);
      when(api.getBadgeDiscovery).thenAnswer(
        (_) async => [
          (
            definition: definition(key1),
            holderCount: 0,
            followerCount: 0,
            videos: <BadgeVideoPreview>[],
          ),
        ],
      );
      expect(await repository.loadIndexedDiscovery(), isEmpty);
      expect(requests, isEmpty);
    });

    test('404 is logged and cached for subsequent relay refreshes', () async {
      events = [definition(key1)];
      when(api.getBadgeDiscovery).thenThrow(
        const FunnelcakeApiException(
          message: 'not found',
          statusCode: 404,
          url: 'https://api.example/api/badges/discovery',
        ),
      );
      expect(await repository.loadIndexedDiscovery(), hasLength(1));
      expect(await repository.loadIndexedDiscovery(), hasLength(1));
      verify(api.getBadgeDiscovery).called(1);
      expect(
        LogCaptureService().getRecentLogs().map((entry) => entry.message),
        contains(
          contains('https://api.example/api/badges/discovery returned 404'),
        ),
      );
    });

    for (final error in <Exception>[
      const FunnelcakeApiException(message: 'server', statusCode: 503),
      TimeoutException('index deadline'),
      const FormatException('malformed page'),
      const FunnelcakeNotConfiguredException(),
    ]) {
      test('first-load $error uses verified relay cards', () async {
        final badge = definition(key1);
        events = [badge];
        when(api.getBadgeDiscovery).thenThrow(error);
        expect(
          (await repository.loadIndexedDiscovery()).single.definition.event.id,
          badge.id,
        );
        if (error is! FunnelcakeNotConfiguredException) {
          expect(
            LogCaptureService().getRecentLogs().any(
              (entry) =>
                  entry.message ==
                      'Badge discovery index unavailable; using relays' &&
                  entry.error.toString().contains(error.toString()) &&
                  entry.stackTrace != null,
            ),
            isTrue,
          );
        }
      });
    }

    test('one invalid definition does not drop valid neighbors', () async {
      final invalid = definition(key1)..sig = '';
      final valid = definition(key2);
      when(api.getBadgeDiscovery).thenAnswer(
        (_) async => [
          for (final event in [invalid, valid])
            (
              definition: event,
              holderCount: 0,
              followerCount: 0,
              videos: <BadgeVideoPreview>[],
            ),
        ],
      );
      final cards = await repository.loadIndexedDiscovery();
      expect(cards.single.definition.event.id, valid.id);
      expect(
        LogCaptureService().getRecentLogs().map((e) => e.message),
        contains(contains(invalid.id)),
      );
    });

    test('skips an indexed definition whose ID does not match it', () async {
      final signed = definition(key1);
      // Keep the signed ID and signature but change what they cover, so only
      // the hash check can tell the definition was altered.
      final altered = Event.fromJson({
        ...signed.toJson(),
        'tags': [
          ['d', 'shared'],
          ['name', 'Altered name'],
        ],
      });
      final valid = definition(key2);
      when(api.getBadgeDiscovery).thenAnswer(
        (_) async => [
          for (final event in [altered, valid])
            (
              definition: event,
              holderCount: 0,
              followerCount: 0,
              videos: <BadgeVideoPreview>[],
            ),
        ],
      );
      final cards = await repository.loadIndexedDiscovery();
      expect(cards.single.definition.event.id, valid.id);
    });

    test(
      'uses server order without relay reads and hides blocked videos',
      () async {
        final official = definition(key2, at: 1);
        final community = definition(key1);
        final hiddenAuthor = '9' * 64;
        hidden.add(hiddenAuthor);
        final clip = (
          id: 'a' * 64,
          pubkey: issuer1,
          title: 'Clip',
          thumbnail: '',
          createdAt: 1700000000,
          kind: 34236,
          moderationLabels: const <String>[],
          verifiedArchive: false,
          archiveProvenanceAvailable: true,
          tags: const [
            ['d', 'clip'],
            ['url', 'https://media.divine.video/clip.mp4'],
          ],
        );
        when(api.getBadgeDiscovery).thenAnswer(
          (_) async => [
            (
              definition: official,
              holderCount: 1,
              followerCount: 2,
              videos: [
                (
                  id: 'b' * 64,
                  pubkey: hiddenAuthor,
                  title: 'Hidden',
                  thumbnail: '',
                  createdAt: 1700000000,
                  kind: 34236,
                  moderationLabels: const <String>[],
                  verifiedArchive: false,
                  archiveProvenanceAvailable: true,
                  tags: const [
                    ['d', 'clip'],
                    ['url', 'https://media.divine.video/clip.mp4'],
                  ],
                ),
                (
                  id: 'invalid',
                  pubkey: issuer2,
                  title: 'Invalid',
                  thumbnail: '',
                  createdAt: 1700000000,
                  kind: 34236,
                  moderationLabels: const <String>[],
                  verifiedArchive: false,
                  archiveProvenanceAvailable: true,
                  tags: const [
                    ['d', 'clip'],
                    ['url', 'https://media.divine.video/clip.mp4'],
                  ],
                ),
                clip,
              ],
            ),
            (
              definition: community,
              holderCount: 50,
              followerCount: 10,
              videos: [],
            ),
            (
              definition: community,
              holderCount: 50,
              followerCount: 10,
              videos: [],
            ),
            for (var i = 0; i < 4; i++)
              (
                definition: definition(key1, identifier: 'badge-$i'),
                holderCount: 0,
                followerCount: 0,
                videos: [],
              ),
          ],
        );
        final indexed = await repository.loadIndexedDiscovery();
        expect(indexed.map((card) => card.definition.event.id).take(2), [
          official.id,
          community.id,
        ]);
        expect(indexed.first.videos, [clip]);
        expect(
          indexed.where((card) => card.definition.event.pubkey == issuer1),
          hasLength(3),
        );
        expect(requests, isEmpty);
      },
    );

    test('skips corrupt signed data and filters hidden issuers', () async {
      final hiddenBadge = definition(key1);
      hidden.add(issuer1);
      when(api.getBadgeDiscovery).thenAnswer(
        (_) async => [
          (
            definition: hiddenBadge,
            holderCount: 0,
            followerCount: 0,
            videos: [],
          ),
        ],
      );
      expect(await repository.loadIndexedDiscovery(), isEmpty);
      expect(requests, isEmpty);
      hiddenBadge.sig = '';
      expect(await repository.loadIndexedDiscovery(), isEmpty);
    });

    test('a result arriving after disposal is discarded', () async {
      final pending = Completer<List<IndexedBadgeCard>>();
      when(api.getBadgeDiscovery).thenAnswer((_) => pending.future);
      final load = repository.loadIndexedDiscovery();
      await repository.dispose();
      pending.complete([
        (
          definition: definition(key1),
          holderCount: 0,
          followerCount: 0,
          videos: [],
        ),
      ]);
      expect(await load, isEmpty);
    });
  });

  group('loadFederatedDiscovery', () {
    test('does no cross-relay work for a primary-only connection', () async {
      when(() => client.configuredRelays).thenReturn(['wss://relay.example']);
      expect(await repository.loadFederatedDiscovery(), isEmpty);
      expect(requests, isEmpty);
    });

    test(
      'discovers external definitions and checks deletion on both sources',
      () async {
        const external = 'wss://external.example';
        when(
          () => client.configuredRelays,
        ).thenReturn(['wss://relay.example', external]);
        when(() => client.isRelayAllowed(external)).thenReturn(true);
        final externalBadge = definition(key1);
        when(
          () => client.readEvents(
            any(),
            tempRelays: [external],
            relayTypes: RelayType.onlyTemp,
            useCache: false,
            timeout: any(named: 'timeout'),
            requireAllRelaysSettled: true,
            maxCollectedEvents: 300,
          ),
        ).thenAnswer(
          (_) async =>
              QueryResult(events: [externalBadge], endedBy: QueryEnd.complete),
        );
        when(
          () => client.readEvents(
            any(),
            tempRelays: ['wss://relay.example', external],
            relayTypes: RelayType.onlyTemp,
            useCache: false,
            timeout: any(named: 'timeout'),
            requireAllRelaysSettled: true,
            maxCollectedEvents: 1000,
          ),
        ).thenAnswer(
          (_) async =>
              const QueryResult(events: [], endedBy: QueryEnd.complete),
        );
        expect(
          (await repository.loadFederatedDiscovery()).single.event.id,
          externalBadge.id,
        );
      },
    );
  });

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

    test(
      'a full recency window has a physical cap and still returns badges',
      () async {
        events = [
          definition(key1, at: 301),
          for (var at = 300; at > 1; at--)
            Event(
              issuer1,
              EventKind.badgeDefinition,
              [
                ['d', 'unverified-$at'],
              ],
              '',
              createdAt: at,
            ),
          definition(key2, at: 1),
        ];
        expect(
          (await repository.loadPublicDefinitions()).single.event.id,
          events.first.id,
        );
        verify(
          () => client.readEvents(
            any(),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            useCache: false,
            timeout: any(named: 'timeout'),
            requireAllRelaysSettled: true,
            maxCollectedEvents: 300,
          ),
        ).called(1);
      },
    );

    test(
      'gallery compares only revisions with a canonical first identifier',
      () async {
        final genuine = definition(key1);
        events = [ambiguousDefinition(), genuine];
        expect(
          (await repository.loadPublicDefinitions()).single.event.id,
          genuine.id,
        );
      },
    );

    test(
      'the pinned catalogue also validates candidates before choosing a revision',
      () async {
        await repository.dispose();
        repository = await makeRepository(pinnedIssuers: [issuer1]);
        final genuine = definition(key1);
        when(() => api.getBadgeDefinitions(issuer: issuer1)).thenAnswer(
          (_) async => BadgeDefinitionsResponse(
            badges: [
              ambiguousDefinition(),
              definition(key1, at: 300)..sig = '0' * 128,
              genuine,
            ],
          ),
        );
        expect(
          (await repository.loadPublicDefinitions()).single.event.id,
          genuine.id,
        );
      },
    );

    test('the per-issuer cap never trims the pinned catalogue', () async {
      await repository.dispose();
      repository = await makeRepository(pinnedIssuers: [issuer2]);
      events = [definition(key1)];
      final pinned = [
        for (var i = 0; i < 5; i++)
          definition(key2, at: 10 + i, identifier: 'official-$i'),
      ];
      when(
        () => api.getBadgeDefinitions(issuer: issuer2),
      ).thenAnswer((_) async => BadgeDefinitionsResponse(badges: pinned));
      final result = await repository.loadPublicDefinitions();
      expect(result.where((d) => d.event.pubkey == issuer2), hasLength(5));
    });

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

    test('a hung catalogue shares the recent window deadline', () async {
      await repository.dispose();
      repository = await makeRepository(
        pinnedIssuers: [issuer2],
        stopwatchFactory: () => app_clock.clock.stopwatch(),
      );
      fakeAsync((clock) {
        final catalogue = Completer<BadgeDefinitionsResponse>();
        final recent = Completer<QueryResult>();
        when(
          () => api.getBadgeDefinitions(issuer: issuer2),
        ).thenAnswer((_) => catalogue.future);
        when(
          () => client.readEvents(
            any(),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            useCache: false,
            timeout: any(named: 'timeout'),
            requireAllRelaysSettled: true,
            maxCollectedEvents: 300,
          ),
        ).thenAnswer((_) => recent.future);
        List<Nip58BadgeDefinition>? result;
        unawaited(
          repository.loadPublicDefinitions().then((value) => result = value),
        );
        clock.flushMicrotasks();
        verify(() => api.getBadgeDefinitions(issuer: issuer2)).called(1);
        clock.elapse(const Duration(seconds: 7));
        recent.complete(
          QueryResult(
            events: [definition(key1), definition(key2)],
            endedBy: QueryEnd.complete,
          ),
        );
        clock.flushMicrotasks();
        expect(result, isNull);
        clock.elapse(const Duration(seconds: 3));
        expect(
          result?.map((badge) => badge.event.pubkey),
          unorderedEquals([issuer1, issuer2]),
        );
        expect(
          LogCaptureService().getRecentLogs().map((entry) => entry.message),
          contains(
            'Pinned badge catalogue unavailable for ${pubkeyForLogs(issuer2)}',
          ),
        );

        catalogue.complete(
          BadgeDefinitionsResponse(
            badges: [definition(key2, identifier: 'too-late')],
            nextCursor: 'next-page',
          ),
        );
        clock.flushMicrotasks();
        expect(result, hasLength(2));
        verifyNever(
          () => api.getBadgeDefinitions(issuer: issuer2, cursor: 'next-page'),
        );
        verifyNever(
          () => client.readAllEvents(
            any(),
            timeout: any(named: 'timeout'),
            tempRelays: any(named: 'tempRelays'),
          ),
        );
      });
    });

    test(
      'a stalled community deletion read leaves official badges visible',
      () async {
        await repository.dispose();
        repository = await makeRepository(
          pinnedIssuers: [issuer2],
          stopwatchFactory: () => app_clock.clock.stopwatch(),
        );
        final official = definition(key2);
        events = [
          definition(key1),
          for (var i = 3; i < 6; i++) definition(i.toString().padLeft(64, '0')),
        ];
        when(() => api.getBadgeDefinitions(issuer: issuer2)).thenAnswer(
          (_) async => BadgeDefinitionsResponse(badges: [official]),
        );
        fakeAsync((clock) {
          final slow = Completer<QueryResult>();
          final communities = Completer<QueryResult>();
          const settled = QueryResult(events: [], endedBy: QueryEnd.complete);
          final deletionOrder = <String>[];
          when(
            () => client.readEvents(
              any(),
              tempRelays: any(named: 'tempRelays'),
              relayTypes: any(named: 'relayTypes'),
              useCache: false,
              timeout: any(named: 'timeout'),
              requireAllRelaysSettled: true,
              maxCollectedEvents: 1000,
            ),
          ).thenAnswer((call) async {
            final filters = call.positionalArguments.single as List<Filter>;
            final issuer = filters.first.authors!.single;
            deletionOrder.add(issuer);
            if (issuer == issuer1) return slow.future;
            return issuer == issuer2 ? settled : communities.future;
          });
          List<Nip58BadgeDefinition>? result;
          unawaited(
            repository.loadPublicDefinitions().then((value) => result = value),
          );
          clock.flushMicrotasks();
          expect(deletionOrder, hasLength(5));
          expect(deletionOrder.take(2), [issuer2, issuer1]);
          expect(result, isNull);
          clock.elapse(const Duration(seconds: 7));
          communities.complete(settled);
          clock.elapse(const Duration(seconds: 3));
          final expected = unorderedEquals([
            official.id,
            ...events.skip(1).map((event) => event.id),
          ]);
          expect(result?.map((badge) => badge.event.id), expected);
          expect(
            LogCaptureService().getRecentLogs().map((entry) => entry.message),
            containsAll([
              'Omitted badge issuer ${pubkeyForLogs(issuer1)}: deletion read failed',
              'Badge discovery omitted 1 of 5 issuers',
            ]),
          );
          slow.complete(settled);
          clock.flushMicrotasks();
          expect(result?.map((badge) => badge.event.id), expected);
        });
      },
    );

    test('the deletion phase deadline prevents queued issuer reads', () async {
      await repository.dispose();
      repository = await makeRepository(
        stopwatchFactory: _ExpiredStopwatch.new,
      );
      events = [definition(key1), definition(key2)];
      await expectLater(
        repository.loadPublicDefinitions(),
        throwsA(isA<BadgeReadIncompleteException>()),
      );
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
      'a worker error falls back, while a false result rejects the event',
      () async {
        await repository.dispose();
        final verifier = _Verifier();
        final genuine = definition(key1);
        final rejected = definition(key2);
        final forged = definition(key1, identifier: 'forged')..sig = '0' * 128;
        when(() => verifier.verify(any())).thenAnswer((call) async {
          final raw = call.positionalArguments.single as Map<String, dynamic>;
          if (raw['id'] == rejected.id) return false;
          throw StateError('worker failed');
        });
        repository = await makeRepository(spawner: () async => verifier);
        events = [genuine, rejected, forged];
        expect(
          (await repository.loadPublicDefinitions()).single.event.id,
          genuine.id,
        );
      },
    );

    for (final checkingDeletion in [false, true]) {
      test(
        'disposing the worker discards discovery during a '
        '${checkingDeletion ? 'deletion' : 'definition'} check',
        () async {
          await repository.dispose();
          final verifier = _Verifier();
          final started = Completer<void>();
          final verified = Completer<bool>();
          when(() => verifier.verify(any())).thenAnswer((_) {
            started.complete();
            return verified.future;
          });
          when(verifier.close).thenAnswer((_) {
            if (!verified.isCompleted) {
              verified.completeError(StateError('worker closed'));
            }
          });
          repository = await makeRepository(spawner: () async => verifier);
          final candidate = definition(key1);
          if (checkingDeletion) {
            candidate.markSignatureVerified();
            deletions = [deletion(key1, candidate)];
          }
          events = [candidate];

          final loading = repository.loadPublicDefinitions();
          final expectation = expectLater(loading, completion(isEmpty));
          await started.future;
          await repository.dispose();
          await expectation;
        },
      );
    }

    test(
      'skips signature work for deletions that cannot remove a badge',
      () async {
        await repository.dispose();
        final verifier = _Verifier();
        final candidate = definition(key1)..markSignatureVerified();
        final applicable = deletion(key1, candidate, at: 99, address: false);
        final verifiedIds = <String>[];
        when(() => verifier.verify(any())).thenAnswer((call) async {
          final raw = call.positionalArguments.single as Map<String, dynamic>;
          verifiedIds.add(raw['id'] as String);
          return true;
        });
        repository = await makeRepository(spawner: () async => verifier);
        events = [candidate];
        deletions = [
          deletion(key1, candidate, at: 99),
          deletion(key1, definition(key2)),
          applicable,
        ];
        expect(await repository.loadPublicDefinitions(), isEmpty);
        expect(verifiedIds, [applicable.id]);
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
        final response = Completer<QueryResult>();
        when(
          () => client.readEvents(
            any(),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            useCache: false,
            timeout: any(named: 'timeout'),
            requireAllRelaysSettled: true,
            maxCollectedEvents: 300,
          ),
        ).thenAnswer((_) => response.future);
        final loading = repository.loadPublicDefinitions();
        await repository.dispose();
        response.complete(
          QueryResult(
            events: [definition(key1)],
            endedBy: QueryEnd.complete,
          ),
        );
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
      deletions = [deletion(key1, events.single)];
      await expectLater(
        repository.loadPublicDefinitions(),
        throwsA(isA<BadgeReadIncompleteException>()),
      );
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

    for (final timerFiresFirst in [false, true]) {
      test(
        timerFiresFirst
            ? 'an expired verifier timer omits the issuer before stopwatch expiry'
            : 'a pending signature check stops at the deletion deadline',
        () async {
          await repository.dispose();
          fakeAsync((clock) {
            final verified = Completer<bool>();
            final verifier = _Verifier();
            when(
              () => verifier.verify(any()),
            ).thenAnswer((_) => verified.future);
            events = [definition(key1)..markSignatureVerified()];
            deletions = [deletion(key1, events.single)];
            Object? failure;
            final timer = _MutableStopwatch()
              ..elapsedValue = const Duration(seconds: 9, microseconds: 999999);
            unawaited(
              makeRepository(
                    spawner: () async => verifier,
                    stopwatchFactory: timerFiresFirst
                        ? () => timer
                        : app_clock.clock.stopwatch,
                  )
                  .then((created) {
                    repository = created;
                    return repository.loadPublicDefinitions();
                  })
                  .then<void>(
                    (_) => fail('Expected an incomplete deletion read'),
                    onError: (Object error) => failure = error,
                  ),
            );
            clock.flushMicrotasks();
            expect(failure, isNull);
            clock.elapse(
              timerFiresFirst
                  ? const Duration(microseconds: 1)
                  : const Duration(seconds: 10),
            );
            expect(failure, isA<BadgeReadIncompleteException>());
            verified.complete(true);
            clock.flushMicrotasks();
            var disposed = false;
            unawaited(repository.dispose().then((_) => disposed = true));
            clock.flushMicrotasks();
            expect(disposed, isTrue);
          });
          repository = await makeRepository();
        },
      );
    }

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
      'drops a validly signed definition whose pubkey is not lowercase hex',
      () async {
        // Signing accepts an uppercase pubkey, which would put a second,
        // differently cased coordinate for the same key into the gallery.
        final uppercase = Event(
          issuer2.toUpperCase(),
          EventKind.badgeDefinition,
          [
            ['d', 'uppercase'],
          ],
          '',
        )..sign(key2);
        expect(uppercase.isSigned, isTrue);
        events = [uppercase, definition(key1)];
        expect(
          (await repository.loadPublicDefinitions()).single.event.pubkey,
          issuer1,
        );
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
    test(
      'all deletion windows unknown cannot establish an empty gallery',
      () async {
        events = [definition(key1), definition(key2)];
        incompleteIssuers.add(issuer1);
        cappedIssuers.add(issuer2);
        await expectLater(
          repository.loadPublicDefinitions(),
          throwsA(isA<BadgeReadIncompleteException>()),
        );
      },
    );

    test('an entirely saturated deletion window needs a retry', () async {
      events = [definition(key1)];
      deletions = List.filled(1000, deletion(key1, events.single, at: 50));
      await expectLater(
        repository.loadPublicDefinitions(),
        throwsA(isA<BadgeReadIncompleteException>()),
      );
    });

    test(
      'a deleted badge does not establish that an unknown issuer is empty',
      () async {
        events = [definition(key1), definition(key2)];
        deletions = [deletion(key1, events.first)];
        incompleteIssuers.add(issuer2);
        await expectLater(
          repository.loadPublicDefinitions(),
          throwsA(isA<BadgeReadIncompleteException>()),
        );
      },
    );

    test(
      'retry is offered when the only settled issuer becomes hidden',
      () async {
        await repository.dispose();
        repository = await makeRepository(
          stopwatchFactory: () {
            // The omission phase starts after both definitions were collected.
            hidden.add(issuer2);
            return Stopwatch();
          },
        );
        events = [definition(key1), definition(key2)];
        incompleteIssuers.add(issuer1);
        await expectLater(
          repository.loadPublicDefinitions(),
          throwsA(isA<BadgeReadIncompleteException>()),
        );
      },
    );

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

  group('independent detail reads', () {
    final coordinate = BadgeCoordinate(pubkey: issuer1, identifier: 'shared');

    test(
      'detail selects the newest authentic canonical revision within its read window',
      () async {
        final genuine = definition(key1, name: 'First');
        final sameSecond = definition(key1, name: 'Second');
        final candidates = [
          definition(key1, at: 400)..sig = '0' * 128,
          ambiguousDefinition(),
          ambiguousDefinition(firstIdentifier: 'another'),
          sameSecond,
          genuine,
          definition(key1, at: 10),
        ];
        QueryResult answer(Invocation call) {
          final filter =
              (call.positionalArguments.single as List<Filter>).single;
          expect(call.namedArguments[#maxCollectedEvents], filter.limit);
          final matches = candidates
              .where(filter.checkEvent)
              .take(filter.limit!);
          return QueryResult(
            events: matches.toList(),
            endedBy: QueryEnd.complete,
          );
        }

        when(
          () => client.queryEvents(any(), tempRelays: any(named: 'tempRelays')),
        ).thenAnswer((_) async => []);
        when(
          () => client.readEvents(
            any(),
            tempRelays: any(named: 'tempRelays'),
            maxCollectedEvents: any(named: 'maxCollectedEvents'),
          ),
        ).thenAnswer((call) async => answer(call));
        expect(
          (await repository.loadBadgeDetail(coordinate)).definition?.event.id,
          genuine.id,
        );
      },
    );

    test(
      'only authenticates a definition for the exact requested coordinate',
      () async {
        var response = definition(key1);
        when(
          () => client.queryEvents(any(), tempRelays: any(named: 'tempRelays')),
        ).thenAnswer((_) async => []);
        when(
          () => client.readEvents(
            any(),
            tempRelays: any(named: 'tempRelays'),
            maxCollectedEvents: any(named: 'maxCollectedEvents'),
          ),
        ).thenAnswer(
          (_) async =>
              QueryResult(events: [response], endedBy: QueryEnd.complete),
        );
        final valid = await repository.loadBadgeDetail(coordinate);
        expect(valid.definition?.event.id, response.id);
        for (final invalid in [
          definition(key1)..sig = '0' * 128,
          definition(key1)
            ..markSignatureVerified()
            ..content = 'changed after signing',
          definition(key2),
          definition(key1, identifier: 'other'),
          Event(issuer1, EventKind.badgeDefinition, [
            ['d'],
            ['d', 'shared'],
          ], '')..sign(key1),
          deletion(key1, response),
        ]) {
          response = invalid;
          expect(
            (await repository.loadBadgeDetail(coordinate)).definition,
            isNull,
          );
        }
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

import 'package:badge_repository/badge_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends Mock implements NostrClient {}

class _Api extends Mock implements FunnelcakeApiClient {}

void main() {
  late _Client client;
  late _Api api;
  late BadgeRepository repository;
  var events = <Event>[];
  var deletions = <Event>[];
  var incomplete = false;
  final hidden = <String>{};
  final requests = <Filter>[];
  final key1 = '1'.padLeft(64, '0');
  final key2 = '2'.padLeft(64, '0');
  final issuer1 = getPublicKey(key1);
  final issuer2 = getPublicKey(key2);

  Event definition(String key, {int at = 100, String name = 'Loop makers'}) =>
      Event(
        getPublicKey(key),
        EventKind.badgeDefinition,
        [
          ['d', 'shared'],
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

  setUpAll(() {
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(Duration.zero);
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    client = _Client();
    api = _Api();
    events = [];
    deletions = [];
    incomplete = false;
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
    repository = BadgeRepository(
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
    );
  });
  tearDown(() => repository.dispose());

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
      expect(requests[1].a, ['30009:$issuer1:shared', '30009:$issuer2:shared']);
      expect(requests[2].e, [events[2].id, events[1].id]);
    },
  );
  test('drops hidden, unsigned, hash-corrupt and forged definitions', () async {
    hidden.add(issuer2);
    final unsigned = Event(issuer1, EventKind.badgeDefinition, [
      ['d', 'unsigned'],
    ], '');
    final corrupt = definition(key1)..content = 'changed';
    final forged = definition(key1)..sig = '0' * 128;
    events = [unsigned, corrupt, forged, definition(key2)];
    expect(await repository.loadPublicDefinitions(), isEmpty);
  });
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
      events = [definition(key1)];
      var calls = 0;
      when(
        () => client.queryEventsDetailed(
          any(),
          tempRelays: any(named: 'tempRelays'),
          relayTypes: any(named: 'relayTypes'),
          useCache: false,
          timeout: any(named: 'timeout'),
          requireAllRelaysSettled: true,
        ),
      ).thenAnswer(
        (_) async => (
          events: calls++ == 0 ? events : <Event>[],
          timedOut: calls > 1,
          noRelays: false,
        ),
      );
      await expectLater(
        repository.loadPublicDefinitions(),
        throwsA(isA<BadgeReadIncompleteException>()),
      );
    },
  );
  test(
    'preview caps distinct valid visible people without a relay holder walk',
    () async {
      hidden.add(issuer2);
      final members = [
        for (var n = 3; n < 9; n++) n.toRadixString(16).padLeft(64, '0'),
      ];
      when(
        () => api.getBadgeHolderPreview(creatorPubkey: issuer1, dTag: 'shared'),
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
}

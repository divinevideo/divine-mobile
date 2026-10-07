// ABOUTME: Counts thumbnail HTTP transport through the real provider pipeline.
// ABOUTME: Covers unchanged notifications, mutable snapshots and session races.

import 'dart:async';
import 'dart:convert';

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _ownerA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _ownerB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _eventA =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _eventB =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

class _Service extends Mock implements CuratedListService {}

class _Relay extends Mock implements NostrClient {}

class _Auth extends Mock implements AuthService {}

class _Preferences extends Mock implements SharedPreferences {}

/// Holds the real legacy-key retirement before its verification notification.
class _GatedAgeVerification extends AgeVerificationService {
  _GatedAgeVerification({
    required super.preferences,
    required this.gate,
    required void Function() onChanged,
  }) : super(
         currentPubkeyHex: () => _ownerA,
         onAdultContentVerificationChanged: onChanged,
       );

  final Completer<void> gate;

  @override
  Future<void> get initialized async {
    await gate.future;
    await super.initialized;
  }
}

class _AuthState extends CurrentAuthState {
  @override
  AuthState build() => AuthState.authenticated;
}

class _ClientState extends NostrService {
  _ClientState(this.input);

  final Provider<NostrClient> input;

  @override
  NostrClient build() => ref.watch(input);
}

class _ListsState extends CuratedListsState {
  _ListsState(this.currentService, {this.buildGate});

  CuratedListService currentService;
  Completer<void>? buildGate;

  @override
  CuratedListService get service => currentService;

  @override
  Future<List<CuratedList>> build() async {
    await buildGate?.future;
    return List.unmodifiable(currentService.lists);
  }

  void emit() => state = AsyncData(List.unmodifiable(currentService.lists));
}

CuratedList _list({
  String id = 'my_vine_list',
  String owner = _ownerA,
  List<String>? videos,
}) => CuratedList(
  id: id,
  pubkey: owner,
  name: 'Own list',
  videoEventIds: videos ?? [_eventA],
  tags: List.of(const ['original']),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

http.Response _positive(String thumbnail) => http.Response(
  jsonEncode({
    'id': _eventA,
    'pubkey': _ownerA,
    'created_at': 1770000000,
    'kind': 34236,
    'd_tag': 'video',
    'thumbnail': thumbnail,
    'video_url': 'https://example.com/video.mp4',
  }),
  200,
  headers: {'content-type': 'application/json'},
);

class _Fixture {
  _Fixture({
    Completer<void>? buildGate,
    bool initializePolicy = false,
    Future<void>? policyInitialized,
    List<Override> additionalOverrides = const [],
  }) {
    auth = _Auth();
    when(() => auth.currentPublicKeyHex).thenAnswer((_) => owner);
    relay = _Relay();
    when(() => relay.queryEvents(any())).thenAnswer((_) async {
      relayReads++;
      return [];
    });
    client = relay;
    service = _newService();
    notifier = _ListsState(service, buildGate: buildGate);
    httpClient = MockClient((request) async {
      requests.add(request);
      final handler = onRequest;
      if (handler != null) return handler(request, requests.length);
      return response;
    });
    api = FunnelcakeApiClient(
      baseUrl: 'https://example.com',
      httpClient: httpClient,
    );
    repository = _newRepository();
    repositories.add(repository);
    clientInput = Provider<NostrClient>((_) => client);
    repositoryInput = Provider<CuratedListRepository>((_) => repository);
    policyInput = Provider<CuratedListVideoFilter>(
      (_) =>
          (_) => policyHidden,
    );
    container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        curatedListThumbnailFilterProvider.overrideWith(
          (ref) {
            ref.watch(adultContentVerificationVersionProvider);
            return ref.watch(policyInput);
          },
        ),
        if (!initializePolicy)
          curatedListThumbnailPolicyInitializedProvider.overrideWith(
            (_) => policyInitialized ?? Future<void>.value(),
          ),
        currentAuthStateProvider.overrideWith(_AuthState.new),
        sharedPreferencesProvider.overrideWithValue(_Preferences()),
        nostrServiceProvider.overrideWith(() => _ClientState(clientInput)),
        curatedListsStateProvider.overrideWith(() => notifier),
        curatedListRepositoryProvider.overrideWith(
          (ref) => ref.watch(repositoryInput),
        ),
        ...additionalOverrides,
      ],
    );
    subscription = container.listen(myListsWithThumbnailsProvider, (_, _) {});
    addTearDown(() async {
      subscription.close();
      container.dispose();
      for (final repository in repositories) {
        await repository.dispose();
      }
      httpClient.close();
    });
  }

  String owner = _ownerA;
  List<CuratedList> rows = [_list()];
  List<CuratedList> otherRows = [];
  final List<http.Request> requests = [];
  final List<CuratedListRepository> repositories = [];
  int relayReads = 0;
  bool policyHidden = false;
  http.Response response = _positive('https://example.com/first.jpg');
  Future<http.Response> Function(http.Request, int)? onRequest;
  late final _Auth auth;
  late final _Relay relay;
  late NostrClient client;
  late _Service service;
  late final _ListsState notifier;
  late final MockClient httpClient;
  late final FunnelcakeApiClient api;
  late CuratedListRepository repository;
  late final Provider<NostrClient> clientInput;
  late final Provider<CuratedListRepository> repositoryInput;
  late final Provider<CuratedListVideoFilter> policyInput;
  late final ProviderContainer container;
  late final ProviderSubscription<AsyncValue<List<CuratedList>>> subscription;

  _Service _newService() {
    final next = _Service();
    when(() => next.myLists).thenAnswer((_) => List.of(rows));
    when(() => next.lists).thenAnswer((_) => [...rows, ...otherRows]);
    return next;
  }

  CuratedListRepository _newRepository() => CuratedListRepository(
    nostrClient: relay,
    funnelcakeApiClient: api,
    videoFilter: (_) => policyHidden,
  );

  Future<List<CuratedList>> read() =>
      container.read(myListsWithThumbnailsProvider.future);

  Future<void> emit() async {
    notifier.emit();
    await container.pump();
  }

  Future<void> replaceService() async {
    service = _newService();
    notifier.currentService = service;
    await emit();
  }

  Future<void> replaceRepository() async {
    repository = _newRepository();
    repositories.add(repository);
    container.invalidate(repositoryInput);
    await container.pump();
  }

  Future<void> switchAccount(String nextOwner) async {
    owner = nextOwner;
    client = _Relay();
    container.invalidate(clientInput);
    await container.pump();
  }
}

void main() {
  setUpAll(() => registerFallbackValue(<Filter>[]));

  group(myListsWithThumbnailsProvider, () {
    test(
      'policy startup settles before one initial metadata request',
      () async {
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();
        final gate = Completer<void>();
        late _Fixture fixture;
        final age = _GatedAgeVerification(
          preferences: preferences,
          gate: gate,
          onChanged: () => fixture.container
              .read(adultContentVerificationVersionProvider.notifier)
              .increment(),
        );
        final content = ContentFilterService(ageVerificationService: age);
        addTearDown(content.dispose);
        fixture = _Fixture(
          initializePolicy: true,
          additionalOverrides: [
            ageVerificationServiceProvider.overrideWithValue(age),
            contentFilterServiceProvider.overrideWithValue(content),
          ],
        );
        await fixture.container.pump();
        expect(fixture.requests, isEmpty);
        fixture.container
            .read(adultContentVerificationVersionProvider.notifier)
            .increment();
        await fixture.container.pump();
        expect(fixture.requests, isEmpty);
        gate.complete();
        final current = await fixture.read();
        expect(current.single.thumbnailUrls, hasLength(1));
        expect(fixture.requests, hasLength(1));
        expect(content.isInitialized, isTrue);
        expect(
          fixture.container.read(adultContentVerificationVersionProvider),
          2,
        );
        fixture.container.invalidate(myListsWithThumbnailsProvider);
        await fixture.read();
        expect(fixture.requests, hasLength(2));
      },
    );

    test(
      'failed policy startup retains lists without exposing previews',
      () async {
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();
        final gate = Completer<void>();
        final age = _GatedAgeVerification(
          preferences: preferences,
          gate: gate,
          onChanged: () {},
        );
        final content = ContentFilterService(ageVerificationService: age);
        addTearDown(content.dispose);
        final fixture = _Fixture(
          initializePolicy: true,
          additionalOverrides: [
            ageVerificationServiceProvider.overrideWithValue(age),
            contentFilterServiceProvider.overrideWithValue(content),
          ],
        );
        final result = fixture.read();
        await fixture.container.pump();
        final assertion = expectLater(
          result,
          throwsA(isA<ParallelWaitError>()),
        );
        gate.completeError(StateError('verification initialization failed'));
        await assertion;
        expect(fixture.requests, isEmpty);
        expect(fixture.service.myLists.single.id, 'my_vine_list');
        expect(
          fixture.container.read(myListsWithThumbnailsProvider).hasError,
          isTrue,
        );
      },
    );

    test('a policy tightening retires an in-flight preview pass', () async {
      final fixture = _Fixture();
      final started = Completer<void>();
      final release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      fixture.onRequest = (_, count) async {
        if (count == 1) {
          started.complete();
          await release.future;
        }
        return fixture.response;
      };
      await started.future;
      fixture.policyHidden = true;
      fixture.container.invalidate(fixture.policyInput);
      await fixture.container.pump();
      expect((await fixture.read()).single.thumbnailUrls, isEmpty);
      expect(fixture.requests, hasLength(2));
      release.complete();
      await fixture.container.pump();
      expect((await fixture.read()).single.thumbnailUrls, isEmpty);
      expect(fixture.requests, hasLength(2));
    });

    test(
      'pending policy startup follows the replacement account and repository',
      () async {
        final gate = Completer<void>();
        final fixture = _Fixture(policyInitialized: gate.future);
        await fixture.container.pump();
        expect(fixture.requests, isEmpty);
        fixture.rows = [_list(owner: _ownerB)];
        await fixture.switchAccount(_ownerB);
        await fixture.replaceService();
        await fixture.replaceRepository();
        expect(fixture.requests, isEmpty);
        gate.complete();
        final current = await fixture.read();
        expect(current.single.pubkey, _ownerB);
        expect(current.single.thumbnailUrls, hasLength(1));
        expect(fixture.requests, hasLength(1));
      },
    );

    testWidgets('disposed policy startup never starts a stale resolver', (
      tester,
    ) async {
      final gate = Completer<void>();
      final fixture = _Fixture(policyInitialized: gate.future);
      await tester.pump();
      fixture.subscription.close();
      fixture.container.dispose();
      gate.complete();
      await tester.pump();
      expect(fixture.requests, isEmpty);
    });

    test(
      'changes to another author list do not restart own-list hydration',
      () async {
        final fixture = _Fixture();
        await fixture.read();
        fixture.otherRows = [_list(id: 'other', owner: _ownerB)];
        await fixture.emit();
        await fixture.read();
        expect(fixture.requests, hasLength(1));
      },
    );
    for (final found in [true, false]) {
      test(
        'unchanged notifications reuse the ${found ? 'positive' : 'missing'} pass',
        () async {
          final fixture = _Fixture();
          if (!found) fixture.response = http.Response('', 404);
          await fixture.read();
          await fixture.emit();
          await fixture.emit();
          await fixture.read();
          expect(fixture.requests, hasLength(1));
          expect(fixture.relayReads, found ? 0 : 1);
        },
      );
    }

    test(
      'unchanged notifications do not duplicate an in-flight HTTP request',
      () async {
        final fixture = _Fixture();
        final started = Completer<void>();
        final release = Completer<void>();
        addTearDown(() {
          if (!release.isCompleted) release.complete();
        });
        fixture.onRequest = (_, _) async {
          started.complete();
          await release.future;
          return fixture.response;
        };
        await started.future;
        await fixture.emit();
        expect(fixture.requests, hasLength(1));
        release.complete();
        expect((await fixture.read()).single.thumbnailUrls, hasLength(1));
      },
    );

    for (final found in [true, false]) {
      test(
        'explicit refresh retries ${found ? 'positive metadata' : 'missing thumbnails'}',
        () async {
          final fixture = _Fixture();
          if (!found) fixture.response = http.Response('', 404);
          await fixture.read();
          fixture.response = _positive('https://example.com/changed.jpg');
          fixture.container.invalidate(myListsWithThumbnailsProvider);
          final refreshed = await fixture.read();
          expect(refreshed.single.thumbnailUrls, [
            'https://example.com/changed.jpg',
          ]);
          expect(fixture.requests, hasLength(2));
          expect(fixture.relayReads, found ? 0 : 1);
        },
      );
    }

    test(
      'mutable membership input is captured before the next notification',
      () async {
        final fixture = _Fixture();
        await fixture.read();
        fixture.rows.single.videoEventIds.add(_eventB);
        await fixture.emit();
        final changed = await fixture.read();
        expect(changed.single.videoEventIds, [_eventA, _eventB]);
        expect(fixture.requests, hasLength(3));
        expect(fixture.requests.last.url.path, '/api/videos/$_eventB/stats');
      },
    );

    test('full metadata and mutable tags invalidate hydration', () async {
      final fixture = _Fixture();
      await fixture.read();
      fixture.rows.single.tags.add('changed');
      await fixture.emit();
      expect((await fixture.read()).single.tags, ['original', 'changed']);
      expect(fixture.requests, hasLength(2));
      fixture.rows = [
        fixture.rows.single.copyWith(
          name: 'Changed name',
          isPublic: false,
          description: 'Changed description',
          thumbnailEventId: _eventB,
          playOrder: PlayOrder.reverse,
        ),
      ];
      await fixture.emit();
      final changed = (await fixture.read()).single;
      expect(changed.name, 'Changed name');
      expect(changed.isPublic, isFalse);
      expect(changed.description, 'Changed description');
      expect(changed.thumbnailEventId, _eventB);
      expect(changed.playOrder, PlayOrder.reverse);
      expect(fixture.requests, hasLength(3));
    });

    test(
      'list insertion and order changes return the current membership',
      () async {
        final fixture = _Fixture();
        await fixture.read();
        fixture.rows = [fixture.rows.single, _list(id: 'second', videos: [])];
        await fixture.emit();
        expect((await fixture.read()).map((list) => list.id), [
          'my_vine_list',
          'second',
        ]);
        fixture.rows = fixture.rows.reversed.toList();
        await fixture.emit();
        expect((await fixture.read()).map((list) => list.id), [
          'second',
          'my_vine_list',
        ]);
      },
    );

    test(
      'equal lists from a replacement service retry independently',
      () async {
        final fixture = _Fixture();
        await fixture.read();
        await fixture.replaceService();
        await fixture.read();
        expect(fixture.requests, hasLength(2));
      },
    );

    test(
      'replacement repository retries independently of list snapshots',
      () async {
        final fixture = _Fixture();
        await fixture.read();
        await fixture.replaceRepository();
        await fixture.read();
        expect(fixture.requests, hasLength(2));
      },
    );

    test(
      'account generation changes invalidate even equal list snapshots',
      () async {
        final fixture = _Fixture();
        await fixture.read();
        await fixture.switchAccount(_ownerB);
        await fixture.read();
        await fixture.switchAccount(_ownerA);
        await fixture.read();
        expect(fixture.requests, hasLength(3));
      },
    );

    test(
      'an old completion cannot overwrite the A to B to A replacement pass',
      () async {
        final fixture = _Fixture();
        final started = Completer<void>();
        final release = Completer<void>();
        addTearDown(() {
          if (!release.isCompleted) release.complete();
        });
        fixture.onRequest = (_, count) async {
          if (count == 1) {
            started.complete();
            await release.future;
          }
          return _positive('https://example.com/pass-$count.jpg');
        };
        await started.future;
        await fixture.switchAccount(_ownerB);
        await fixture.read();
        await fixture.switchAccount(_ownerA);
        final current = await fixture.read();
        expect(current.single.thumbnailUrls, [
          'https://example.com/pass-3.jpg',
        ]);
        release.complete();
        await fixture.container.pump();
        expect(
          (await fixture.read()).single.thumbnailUrls,
          current.single.thumbnailUrls,
        );
      },
    );

    testWidgets('disposed selected work never starts a stale resolver', (
      tester,
    ) async {
      final release = Completer<void>();
      final fixture = _Fixture(buildGate: release);
      fixture.container.invalidate(myListsWithThumbnailsProvider);
      fixture.subscription.close();
      fixture.container.dispose();
      release.complete();
      await tester.pump();
      expect(fixture.requests, isEmpty);
    });
  });
}

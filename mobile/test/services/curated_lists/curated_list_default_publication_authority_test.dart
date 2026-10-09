// ABOUTME: Guards canonical default publication using positive real event evidence.
// ABOUTME: Uses real Schnorr signatures and NIP-44; relay transport is controlled.

import 'dart:async';
import 'dart:convert';

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/auth/account_activation_coordinator.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/curated_lists/prefs_curated_list_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _Client extends Mock implements NostrClient {}

class _Auth extends Mock implements AuthService {}

class _Api extends Mock implements FunnelcakeApiClient {}

class _RefusingDefaultBackend extends InMemorySharedPreferencesStore {
  _RefusingDefaultBackend(super.data) : super.withData();
  bool refuseCache = false;
  Completer<void>? cacheEntered;
  Completer<void>? releaseCache;

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (refuseCache && key == 'flutter.${CuratedListService.listsStorageKey}') {
      if (cacheEntered?.isCompleted == false) cacheEntered!.complete();
      if (releaseCache != null) await releaseCache!.future;
      return false;
    }
    return super.setValue(type, key, value);
  }
}

class _PausingSigner extends LocalNostrSigner {
  _PausingSigner() : super(_testKey);
  String? pausedCiphertext;
  final entered = Completer<void>();
  final released = Completer<void>();

  @override
  Future<String?> nip44Decrypt(String pubkey, String ciphertext) async {
    if (ciphertext == pausedCiphertext) {
      if (!entered.isCompleted) entered.complete();
      await released.future;
    }
    return super.nip44Decrypt(pubkey, ciphertext);
  }
}

// Fixed public test key, unrelated to any application account.
final String _testKey = '1'.padLeft(64, '0');
final String _otherTestKey = '2'.padLeft(64, '0');
const String _defaultId = CuratedListService.defaultListId;
const _video =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

class _Harness {
  _Harness(
    this.prefs,
    this.owner,
    this.signer,
    AccountActivationReceipt receipt, {
    Duration relayTimeout = const Duration(milliseconds: 10),
  }) {
    when(() => auth.isAuthenticated).thenReturn(true);
    when(() => auth.currentPublicKeyHex).thenReturn(owner);
    when(() => auth.committedAccountActivationReceipt).thenReturn(receipt);
    when(() => client.signer).thenReturn(signer);
    when(
      () => client.subscribe(any(), closeOnEose: true),
    ).thenAnswer((_) => relay());
    when(
      () => auth.createAndSignEvent(
        kind: any(named: 'kind'),
        content: any(named: 'content'),
        tags: any(named: 'tags'),
        createdAt: any(named: 'createdAt'),
      ),
    ).thenAnswer((i) async {
      final event = Event(
        owner,
        i.namedArguments[#kind] as int,
        i.namedArguments[#tags] as List<List<String>>,
        i.namedArguments[#content] as String,
        createdAt: i.namedArguments[#createdAt] as int?,
      );
      await signer.signEvent(event);
      signed.add(event);
      return event;
    });
    when(() => client.publishEvent(any())).thenAnswer((i) async {
      final event = i.positionalArguments.first as Event;
      sent.add(event);
      return PublishSuccess(event: event);
    });
    when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
      final event = i.positionalArguments.first as Event;
      sent.add(event);
      return PublishOutcome(
        eventId: event.id,
        acceptedBy: const ['wss://fixture.invalid'],
        rejectedBy: const {},
        noResponseFrom: const [],
      );
    });
    service = CuratedListService(
      nostrService: client,
      authService: auth,
      prefs: prefs,
      relaySyncTimeout: relayTimeout,
    );
  }
  final SharedPreferences prefs;
  final String owner;
  final LocalNostrSigner signer;
  final client = _Client();
  final auth = _Auth();
  final signed = <Event>[];
  final sent = <Event>[];
  late final CuratedListService service;
  Stream<Event> Function() relay = () => const Stream.empty();

  Future<void> settle() async {
    await service.initialize();
    await service.fetchUserListsFromRelays(force: true);
  }

  void close() => service.dispose();
}

Future<_Harness> _makeHarness(
  SharedPreferences prefs,
  String owner,
  LocalNostrSigner signer, {
  Duration relayTimeout = const Duration(milliseconds: 10),
}) async {
  final coordinator = AccountActivationCoordinator.forPreferences(prefs);
  final ticket = await coordinator.begin(
    ownerPubkey: owner,
    isCurrent: () => true,
  );
  await coordinator.markIdentityReady(ticket);
  final receipt = await coordinator.commit(ticket);
  return _Harness(prefs, owner, signer, receipt, relayTimeout: relayTimeout);
}

CuratedList _cached(
  String owner, {
  String id = _defaultId,
  List<String> items = const [],
  String? eventId,
  bool pending = false,
}) => CuratedList(
  id: id,
  name: 'Retained draft',
  pubkey: owner,
  videoEventIds: items,
  isPublic: false,
  nostrEventId: eventId,
  pendingRepublish: pending,
  createdAt: DateTime.utc(2000),
  updatedAt: DateTime.utc(2000),
);

Future<Event> _privateEvent(
  LocalNostrSigner signer,
  String owner, {
  String id = _defaultId,
  List<String> items = const [_video],
  int at = 1700000000,
  String? plaintext,
  int kind = 30005,
}) async {
  final sealed = await signer.nip44Encrypt(
    owner,
    plaintext ??
        jsonEncode([
          for (final v in items) ['e', v],
        ]),
  );
  final event = Event(
    owner,
    kind,
    [
      ['d', id],
      ['title', 'Verified My List'],
    ],
    sealed!,
    createdAt: at,
  );
  await signer.signEvent(event);
  expect(event.isValid && event.isSigned, isTrue);
  return event;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    registerFallbackValue(Event('a'.padRight(64, 'a'), 1, [], ''));
    registerFallbackValue(<Filter>[]);
  });
  group('Unknown default authority', () {
    late _Harness h;
    late String owner;
    late LocalNostrSigner signer;
    setUp(() async {
      signer = LocalNostrSigner(_testKey);
      owner = (await signer.getPublicKey())!;
      SharedPreferences.setMockInitialValues({});
    });
    tearDown(() => h.close());
    Future<void> make({
      List<CuratedList> cached = const [],
      List<String> deletions = const [],
    }) async {
      SharedPreferences.setMockInitialValues({
        if (cached.isNotEmpty)
          CuratedListService.listsStorageKey: jsonEncode(
            cached.map((x) => x.toJson()).toList(),
          ),
        if (deletions.isNotEmpty)
          PrefsCuratedListStore.deletedCoordinatesStorageKey: deletions,
      });
      h = await _makeHarness(
        await SharedPreferences.getInstance(),
        owner,
        signer,
      );
    }

    test(
      'empty finite read completes init without creating or signing a default',
      () async {
        await make();
        await h.settle();
        expect(h.service.isInitialized, isTrue);
        expect(h.service.isReadyForMutations, isTrue);
        expect(h.service.getDefaultList(), isNull);
        expect(h.signed, isEmpty);
        expect(h.sent, isEmpty);
      },
    );
    test(
      'restored private remote default is recovered before any replacement',
      () async {
        await make();
        final event = await _privateEvent(signer, owner);
        h.relay = () => Stream.value(event);
        await h.settle();
        expect(h.signed, isEmpty);
        expect(h.service.getDefaultList()!.videoEventIds, [_video]);
        expect(h.service.getDefaultList()!.isPublic, isFalse);
      },
    );
    test(
      'owner tombstone survives missing shared deleted flag and repeated sync',
      () async {
        final coordinate = '$owner:$_defaultId';
        await make(deletions: [coordinate]);
        final before = h.prefs.getStringList(
          PrefsCuratedListStore.deletedCoordinatesStorageKey,
        );
        h.relay = () => Stream.value(_publicEvent(owner));
        await h.settle();
        expect(
          h.prefs.getStringList(
            PrefsCuratedListStore.deletedCoordinatesStorageKey,
          ),
          before,
        );
        expect(h.service.getDefaultList(), isNull);
        expect(h.signed, isEmpty);
      },
    );
    test(
      'null-event empty default cannot backfill while another owned list can',
      () async {
        await make(
          cached: [
            _cached(owner),
            _cached(owner, id: 'ordinary', items: [_video]),
          ],
        );
        await h.settle();
        expect(
          h.signed.where(
            (e) => e.tags.any(
              (t) => t.length > 1 && t[0] == 'd' && t[1] == _defaultId,
            ),
          ),
          isEmpty,
        );
        expect(
          h.signed.any(
            (e) => e.tags.any(
              (t) => t.length > 1 && t[0] == 'd' && t[1] == 'ordinary',
            ),
          ),
          isTrue,
        );
        expect(h.service.getDefaultList()!.nostrEventId, isNull);
      },
    );
    test(
      'an unknown cached default cannot be deleted or create a tombstone',
      () async {
        await make(
          cached: [
            _cached(owner, items: [_video]),
          ],
        );
        await h.settle();
        final raw = h.prefs.getString(CuratedListService.listsStorageKey);
        expect(await h.service.deleteOwnedList(_defaultId), isFalse);
        expect(h.prefs.getString(CuratedListService.listsStorageKey), raw);
        expect(
          h.prefs.getStringList(
            PrefsCuratedListStore.deletedCoordinatesStorageKey,
          ),
          isNull,
        );
        expect(h.service.getDefaultList()!.videoEventIds, [_video]);
        expect(h.signed, isEmpty);
        expect(h.sent, isEmpty);
      },
    );
    test(
      'pending flag and cached event ID do not provide signed baseline authority',
      () async {
        await make(
          cached: [
            _cached(owner, eventId: 'b'.padRight(64, 'b'), pending: true),
          ],
        );
        await h.settle();
        expect(h.signed, isEmpty);
        expect(h.service.getDefaultList()!.pendingRepublish, isTrue);
      },
    );
    test(
      'unknown populated draft rejects add without losing its saved items',
      () async {
        await make(
          cached: [
            _cached(owner, items: [_video]),
          ],
        );
        await h.settle();
        h.signed.clear();
        expect(
          await h.service.addVideoToList(_defaultId, 'c'.padRight(64, 'c')),
          isFalse,
        );
        expect(h.service.getDefaultList()!.videoEventIds, [_video]);
        expect(h.signed, isEmpty);
      },
    );
    test(
      'wrong-kind signed default does not authorize a reserved list',
      () async {
        await make();
        final event = await _privateEvent(signer, owner, kind: 30006);
        h.relay = () => Stream.value(event);
        await h.settle();
        expect(h.service.getDefaultList(), isNull);
        expect(h.signed, isEmpty);
      },
    );
    test(
      'hash-consistent but invalid signature does not authorize default',
      () async {
        await make();
        final event = await _privateEvent(signer, owner);
        event.sig = '0'.padRight(128, '0');
        expect(event.isValid, isTrue);
        expect(event.isSigned, isFalse);
        h.relay = () => Stream.value(event);
        await h.settle();
        expect(h.service.getDefaultList(), isNull);
        expect(h.signed, isEmpty);
      },
    );
    test(
      'foreign-owner signed default grants no current-owner permission',
      () async {
        await make();
        final foreign = LocalNostrSigner(_otherTestKey);
        final event = await _privateEvent(
          foreign,
          (await foreign.getPublicKey())!,
        );
        h.relay = () => Stream.value(event);
        await h.settle();
        expect(h.service.getDefaultList(), isNull);
        expect(h.signed, isEmpty);
      },
    );
    test(
      'timeout without a positive event does not create authority',
      () async {
        await make();
        h.relay = () => StreamController<Event>().stream;
        await h.settle();
        expect(h.service.isInitialized, isTrue);
        expect(h.service.getDefaultList(), isNull);
        expect(h.signed, isEmpty);
      },
    );
    test(
      'unknown default does not leave the actual repository bridge loading',
      () async {
        await make();
        await h.settle();
        expect(h.service.initializationError, isNull);
        expect(hasCompleteSubscriptionSnapshotForHomeBridge(h.service), isTrue);
        final repository = CuratedListRepository(
          nostrClient: h.client,
          funnelcakeApiClient: _Api(),
        );
        addTearDown(repository.dispose);
        repository.setSubscribedLists(
          subscribedListsForHomeBridge(h.service),
          isComplete: hasCompleteSubscriptionSnapshotForHomeBridge(h.service),
        );
        repository.setOwnLists(h.service.myLists);
        expect(repository.hasCompleteSubscriptionSnapshot, isTrue);
        expect(repository.subscriptionSnapshot.lists, isEmpty);
        expect(h.service.getDefaultList(), isNull);
      },
    );
    test(
      'unknown default leaves ordinary Create usable and returns a signed owned row',
      () async {
        await make();
        await h.settle();
        h.signed.clear();
        final list = await h.service.createList(
          name: 'Explicit ordinary list',
          isPublic: false,
        );
        expect(list, isNotNull);
        expect(list!.id, isNot(_defaultId));
        expect(
          h.service.pickerListsForOwner(owner).map((x) => x.id),
          contains(list.id),
        );
        expect(h.signed.single.isValid && h.signed.single.isSigned, isTrue);
      },
    );
    test(
      'unknown default leaves Follow and Unfollow usable for a verified public list',
      () async {
        await make();
        await h.settle();
        h.signed.clear();
        final foreign = LocalNostrSigner(_otherTestKey);
        final event = Event(
          (await foreign.getPublicKey())!,
          30005,
          [
            ['d', 'friend-list'],
            ['title', 'Friend list'],
            ['e', _video],
          ],
          '',
          createdAt: 1700000000,
        );
        await foreign.signEvent(event);
        final list = CuratedListConverter.fromEvent(event)!;
        expect(
          await h.service.subscribeToList(list.authorScopedId, list),
          isTrue,
        );
        expect(h.service.isSubscribedToList(list.authorScopedId), isTrue);
        expect(
          await h.service.unsubscribeFromList(list.authorScopedId),
          isTrue,
        );
        expect(h.service.isSubscribedToList(list.authorScopedId), isFalse);
        expect(h.signed, isEmpty);
      },
    );
  });

  group('Positive readable signed baseline controls', () {
    late _Harness h;
    late LocalNostrSigner signer;
    late String owner;
    setUp(() async {
      signer = LocalNostrSigner(_testKey);
      owner = (await signer.getPublicKey())!;
      SharedPreferences.setMockInitialValues({});
      h = await _makeHarness(
        await SharedPreferences.getInstance(),
        owner,
        signer,
        relayTimeout: const Duration(seconds: 1),
      );
    });
    tearDown(() => h.close());
    test(
      'intentional removal of last item can publish a genuinely signed private empty list',
      () async {
        final baseline = await _privateEvent(signer, owner);
        h.relay = () => Stream.value(baseline);
        await h.settle();
        h.signed.clear();
        h.sent.clear();
        expect(await h.service.removeVideoFromList(_defaultId, _video), isTrue);
        expect(h.signed, hasLength(1));
        expect(h.signed.single.isSigned, isTrue);
        expect(
          jsonDecode(
            (await signer.nip44Decrypt(owner, h.signed.single.content))!,
          ),
          isEmpty,
        );
        expect(h.service.getDefaultList()!.videoEventIds, isEmpty);
      },
    );
    test(
      'signed empty remote version is observed without implicit replacement and allows explicit add',
      () async {
        final baseline = await _privateEvent(signer, owner, items: []);
        h.relay = () => Stream.value(baseline);
        await h.settle();
        expect(h.signed, isEmpty);
        expect(await h.service.addVideoToList(_defaultId, _video), isTrue);
        expect(h.signed.single.isSigned, isTrue);
        expect(h.service.getDefaultList()!.videoEventIds, [_video]);
      },
    );
    test(
      'newest opaque signed version fences old readable state without dropping it',
      () async {
        final older = await _privateEvent(signer, owner);
        h.relay = () => Stream.value(older);
        await h.settle();
        h.signed.clear();
        final opaque = await _privateEvent(
          signer,
          owner,
          plaintext: 'not item JSON',
          at: 1700000001,
        );
        h.relay = () => Stream.fromIterable([older, opaque]);
        await h.service.fetchUserListsFromRelays(force: true);
        expect(h.service.getDefaultList()!.videoEventIds, [_video]);
        expect(
          await h.service.removeVideoFromList(_defaultId, _video),
          isFalse,
        );
        expect(h.signed, isEmpty);
      },
    );
    test(
      'an error after a positive event preserves presence without inferring relay absence',
      () async {
        final event = await _privateEvent(signer, owner);
        h.relay = () async* {
          yield event;
          throw StateError('controlled read interrupted');
        };
        await h.settle();
        h.signed.clear();
        expect(h.service.isInitialized, isTrue);
        expect(h.service.getDefaultList()!.videoEventIds, [_video]);
        expect(await h.service.removeVideoFromList(_defaultId, _video), isTrue);
        expect(h.signed.single.isSigned, isTrue);
      },
    );
    test(
      'authenticated header retirement does not await stream close or EOSE',
      () async {
        final baseline = await _privateEvent(signer, owner);
        h.relay = () => Stream.value(baseline);
        await h.settle();
        h.signed.clear();
        h.sent.clear();
        final newer = await _privateEvent(
          signer,
          owner,
          plaintext: 'opaque pending body',
          at: 1700000001,
        );
        final observed = Completer<void>();
        final close = Completer<void>();
        h.relay = () async* {
          yield newer;
          observed.complete();
          await close.future;
        };
        var readCompleted = false;
        final refresh = h.service
            .fetchUserListsFromRelays(force: true)
            .whenComplete(() => readCompleted = true);
        await observed.future;
        expect(readCompleted, isFalse);
        expect(
          await h.service.removeVideoFromList(_defaultId, _video),
          isFalse,
        );
        expect(h.service.getDefaultList()!.videoEventIds, [_video]);
        expect(h.signed, isEmpty);
        expect(h.sent, isEmpty);
        close.complete();
        await refresh;
        expect(h.sent, isEmpty);
      },
    );
    test('a genuine newer header retires old authority before private decryption settles', () async {
      final baseline = await _privateEvent(signer, owner);
      h.relay = () => Stream.value(baseline);
      await h.settle();
      h.signed.clear();
      h.sent.clear();
      final opaque = await _privateEvent(
        signer,
        owner,
        plaintext: 'unsupported schema',
        at: 1700000001,
      );
      final paused = _PausingSigner()..pausedCiphertext = opaque.content;
      when(() => h.client.signer).thenReturn(paused);
      h.relay = () => Stream.value(opaque);
      final refresh = h.service.fetchUserListsFromRelays(force: true);
      await paused.entered.future;
      expect(await h.service.removeVideoFromList(_defaultId, _video), isFalse);
      expect(h.service.getDefaultList()!.videoEventIds, [_video]);
      expect(h.signed, isEmpty);
      expect(h.sent, isEmpty);
      paused.released.complete();
      await refresh;
      expect(await h.service.removeVideoFromList(_defaultId, _video), isFalse);
      expect(h.sent, isEmpty);
    });
    test(
      'new opaque evidence during signing prevents network dispatch and backfill',
      () async {
        final baseline = await _privateEvent(signer, owner);
        h.relay = () => Stream.value(baseline);
        await h.settle();
        h.signed.clear();
        h.sent.clear();
        expect(h.service.getDefaultList()!.videoEventIds, contains(_video));
        final signing = Completer<Event?>();
        final entered = Completer<void>();
        when(
          () => h.auth.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
            createdAt: any(named: 'createdAt'),
          ),
        ).thenAnswer((i) async {
          final event = Event(
            owner,
            i.namedArguments[#kind] as int,
            i.namedArguments[#tags] as List<List<String>>,
            i.namedArguments[#content] as String,
            createdAt: i.namedArguments[#createdAt] as int?,
          );
          await signer.signEvent(event);
          h.signed.add(event);
          entered.complete();
          return signing.future;
        });
        final mutation = h.service.removeVideoFromList(_defaultId, _video);
        await entered.future;
        final opaque = await _privateEvent(
          signer,
          owner,
          plaintext: 'unsupported recovery schema',
          at: 1700000001,
        );
        h.relay = () => Stream.value(opaque);
        await h.service.fetchUserListsFromRelays(force: true);
        signing.complete(h.signed.single);
        await mutation;
        expect(h.sent, isEmpty);
        h.relay = () => const Stream.empty();
        await h.service.fetchUserListsFromRelays(force: true);
        expect(h.sent, isEmpty);
        expect(
          await h.service.removeVideoFromList(_defaultId, _video),
          isFalse,
        );
      },
    );
    test(
      'a newer opaque default during deletion signing prevents dispatch and tombstone',
      () async {
        final baseline = await _privateEvent(signer, owner);
        h.relay = () => Stream.value(baseline);
        await h.settle();
        h.signed.clear();
        h.sent.clear();
        final signing = Completer<Event?>();
        final entered = Completer<void>();
        when(
          () => h.auth.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
            createdAt: any(named: 'createdAt'),
          ),
        ).thenAnswer((i) async {
          final event = Event(
            owner,
            i.namedArguments[#kind] as int,
            i.namedArguments[#tags] as List<List<String>>,
            i.namedArguments[#content] as String,
            createdAt: i.namedArguments[#createdAt] as int?,
          );
          await signer.signEvent(event);
          h.signed.add(event);
          entered.complete();
          return signing.future;
        });
        final deletion = h.service.deleteOwnedList(_defaultId);
        await entered.future;
        final opaque = await _privateEvent(
          signer,
          owner,
          plaintext: 'unknown schema',
          at: 1700000001,
        );
        h.relay = () => Stream.value(opaque);
        await h.service.fetchUserListsFromRelays(force: true);
        signing.complete(h.signed.single);
        expect(await deletion, isFalse);
        expect(h.sent, isEmpty);
        expect(h.service.getDefaultList()!.videoEventIds, [_video]);
        expect(
          h.prefs.getStringList(
            PrefsCuratedListStore.deletedCoordinatesStorageKey,
          ),
          isNull,
        );
      },
    );
    test('retired service cannot reuse a prior signed baseline', () async {
      final baseline = await _privateEvent(signer, owner);
      h.relay = () => Stream.value(baseline);
      await h.settle();
      h.signed.clear();
      h.service.dispose();
      expect(await h.service.removeVideoFromList(_defaultId, _video), isFalse);
      expect(h.signed, isEmpty);
    });
    test(
      'signed but unknown private item schema is opaque rather than a known empty default',
      () async {
        final event = await _privateEvent(
          signer,
          owner,
          plaintext: jsonEncode([
            ['new-item-schema', _video],
          ]),
        );
        h.relay = () => Stream.value(event);
        await h.settle();
        expect(h.service.getDefaultList(), isNull);
        expect(h.signed, isEmpty);
      },
    );
    test(
      'signed malformed tag payload cannot silently discard records to grant empty authority',
      () async {
        final event = await _privateEvent(
          signer,
          owner,
          plaintext: jsonEncode([
            42,
            ['e', _video],
          ]),
        );
        h.relay = () => Stream.value(event);
        await h.settle();
        expect(h.service.getDefaultList(), isNull);
        expect(h.signed, isEmpty);
      },
    );
    test(
      'signed mixed public reference and encrypted content stays opaque',
      () async {
        final hidden = 'f'.padRight(64, 'f');
        final content = await signer.nip44Encrypt(
          owner,
          jsonEncode([
            ['e', hidden],
          ]),
        );
        final mixed = Event(
          owner,
          30005,
          [
            ['d', _defaultId],
            ['e', _video],
          ],
          content!,
          createdAt: 1700000000,
        );
        await signer.signEvent(mixed);
        expect(mixed.isValid && mixed.isSigned, isTrue);
        expect(
          CuratedListConverter.isEncryptedItemPayload(mixed.content),
          isTrue,
        );
        h.relay = () => Stream.value(mixed);
        await h.settle();
        h.signed.clear();
        h.sent.clear();
        expect(
          await h.service.removeVideoFromList(_defaultId, _video),
          isFalse,
        );
        expect(h.signed, isEmpty);
        expect(h.sent, isEmpty);
      },
    );
    test(
      'first batch authenticates default candidates before choosing newest revision',
      () async {
        final baseline = await _privateEvent(signer, owner);
        final forged = await _privateEvent(signer, owner, at: 1700000002);
        forged.sig = '0'.padRight(128, '0');
        h.relay = () => Stream.fromIterable([baseline, forged]);
        await h.settle();
        expect(h.service.getDefaultList()!.videoEventIds, [_video]);
        expect(h.signed, isEmpty);
      },
    );
    test(
      'forged newer revision cannot retire or prevent recovery of a valid signed baseline',
      () async {
        final baseline = await _privateEvent(signer, owner);
        h.relay = () => Stream.value(baseline);
        await h.settle();
        h.signed.clear();
        final forged = await _privateEvent(signer, owner, at: 1700000002);
        forged.sig = '0'.padRight(128, '0');
        expect(forged.isValid, isTrue);
        expect(forged.isSigned, isFalse);
        h.relay = () => Stream.value(forged);
        await h.service.fetchUserListsFromRelays(force: true);
        h.relay = () => Stream.value(baseline);
        await h.service.fetchUserListsFromRelays(force: true);
        expect(await h.service.removeVideoFromList(_defaultId, _video), isTrue);
        expect(h.signed.single.isSigned, isTrue);
      },
    );
    test(
      'unsupported public item reference keeps the membership opaque',
      () async {
        final event = Event(
          owner,
          30005,
          [
            ['d', _defaultId],
            ['e', _video],
            ['a', '99999:$owner:unknown-video'],
          ],
          '',
          createdAt: 1700000000,
        );
        await signer.signEvent(event);
        h.relay = () => Stream.value(event);
        await h.settle();
        h.signed.clear();
        h.sent.clear();
        expect(
          await h.service.removeVideoFromList(_defaultId, _video),
          isFalse,
        );
        expect(h.signed, isEmpty);
        expect(h.sent, isEmpty);
      },
    );
    test(
      'identical verified re-read preserves the exact in-flight explicit intent',
      () async {
        final baseline = await _privateEvent(signer, owner);
        h.relay = () => Stream.value(baseline);
        await h.settle();
        expect(h.service.getDefaultList()!.videoEventIds, contains(_video));
        h.signed.clear();
        h.sent.clear();
        final signing = Completer<Event?>();
        final entered = Completer<void>();
        when(
          () => h.auth.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
            createdAt: any(named: 'createdAt'),
          ),
        ).thenAnswer((i) async {
          final event = Event(
            owner,
            i.namedArguments[#kind] as int,
            i.namedArguments[#tags] as List<List<String>>,
            i.namedArguments[#content] as String,
            createdAt: i.namedArguments[#createdAt] as int?,
          );
          await signer.signEvent(event);
          h.signed.add(event);
          entered.complete();
          return signing.future;
        });
        final mutation = h.service.removeVideoFromList(_defaultId, _video);
        await entered.future;
        await h.service.fetchUserListsFromRelays(force: true);
        signing.complete(h.signed.single);
        expect(await mutation, isTrue);
        expect(h.sent, hasLength(1));
        expect(
          jsonDecode(
            (await signer.nip44Decrypt(owner, h.sent.single.content))!,
          ),
          isEmpty,
        );
      },
    );
    for (final observeNewerOpaque in [false, true]) {
      test(
        'a refused second mutation preserves only current prior intent (opaque=$observeNewerOpaque)',
        () async {
          h.close();
          final originalBackend = SharedPreferencesStorePlatform.instance;
          final backend = _RefusingDefaultBackend({});
          SharedPreferences.resetStatic();
          SharedPreferencesStorePlatform.instance = backend;
          addTearDown(() {
            SharedPreferences.resetStatic();
            SharedPreferencesStorePlatform.instance = originalBackend;
          });
          h = await _makeHarness(
            await SharedPreferences.getInstance(),
            owner,
            signer,
            relayTimeout: const Duration(seconds: 1),
          );
          final baseline = await _privateEvent(signer, owner);
          h.relay = () => Stream.value(baseline);
          await h.settle();
          final saved = 'c' * 64;
          final rejected = 'd' * 64;
          when(() => h.client.publishEvent(any()))
              .thenAnswer((_) async => const PublishFailed());
          expect(await h.service.addVideoToList(_defaultId, saved), isFalse);
          expect(h.service.getDefaultList()!.videoEventIds, [_video, saved]);
          expect(h.service.getDefaultList()!.pendingRepublish, isTrue);
          h.signed.clear();
          h.sent.clear();
          backend.refuseCache = true;
          Future<void>? refresh;
          if (observeNewerOpaque) {
            backend.cacheEntered = Completer<void>();
            backend.releaseCache = Completer<void>();
          }
          final mutation = h.service.addVideoToList(_defaultId, rejected);
          if (observeNewerOpaque) {
            await backend.cacheEntered!.future;
            final opaque = await _privateEvent(
              signer,
              owner,
              plaintext: 'unreadable membership',
              at: 1700000001,
            );
            final observed = Completer<void>();
            h.relay = () async* {
              yield opaque;
              observed.complete();
            };
            refresh = h.service.fetchUserListsFromRelays(force: true);
            await observed.future;
            backend.releaseCache!.complete();
          }
          expect(await mutation, isFalse);
          backend.refuseCache = false;
          if (refresh != null) await refresh;
          expect(h.service.getDefaultList()!.videoEventIds, [_video, saved]);
          expect(h.signed, isEmpty);
          expect(h.sent, isEmpty);
          when(() => h.client.publishEventAwaitOk(any())).thenAnswer((i) async {
            final event = i.positionalArguments.single as Event;
            h.sent.add(event);
            return PublishOutcome(
              eventId: event.id,
              acceptedBy: const ['wss://fixture.invalid'],
              rejectedBy: const {},
              noResponseFrom: const [],
            );
          });
          h.relay = () => const Stream.empty();
          await h.service.fetchUserListsFromRelays(force: true);
          if (observeNewerOpaque) {
            expect(h.sent, isEmpty);
            expect(
              await h.service.removeVideoFromList(_defaultId, saved),
              isFalse,
            );
          } else {
            expect(h.sent, hasLength(1));
            expect(
              jsonDecode(
                (await signer.nip44Decrypt(owner, h.sent.single.content))!,
              ),
              [
                ['e', _video],
                ['e', saved],
              ],
            );
          }
          final durable = await backend.getAll();
          final decoded = jsonDecode(
            durable['flutter.${CuratedListService.listsStorageKey}']! as String,
          ) as List<dynamic>;
          expect((decoded.single as Map<String, dynamic>)['videoEventIds'], [
            _video,
            saved,
          ]);
        },
      );
    }
    for (final extra in [
      ['client', 'Another app'],
      ['e', 'd'.padRight(64, 'd')],
    ]) {
      test(
        'signed default rejects unauthorized extra ${extra.first} tag',
        () async {
          final baseline = await _privateEvent(signer, owner);
          h.relay = () => Stream.value(baseline);
          await h.settle();
          h.signed.clear();
          h.sent.clear();
          when(
            () => h.auth.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
              createdAt: any(named: 'createdAt'),
            ),
          ).thenAnswer((invocation) async {
            final event = Event(
              owner,
              invocation.namedArguments[#kind] as int,
              [
                ...invocation.namedArguments[#tags] as List<List<String>>,
                extra,
              ],
              invocation.namedArguments[#content] as String,
              createdAt: invocation.namedArguments[#createdAt] as int?,
            );
            await signer.signEvent(event);
            h.signed.add(event);
            return event;
          });
          expect(
            await h.service.removeVideoFromList(_defaultId, _video),
            isFalse,
          );
          expect(h.signed, hasLength(1));
          expect(h.signed.single.isValid && h.signed.single.isSigned, isTrue);
          expect(h.sent, isEmpty);
        },
      );
    }
    test(
      'failed explicit publication cannot authorize backfill of a concurrently changed value',
      () async {
        final baseline = await _privateEvent(signer, owner);
        h.relay = () => Stream.value(baseline);
        await h.settle();
        expect(h.service.getDefaultList()!.videoEventIds, contains(_video));
        h.signed.clear();
        h.sent.clear();
        final added = 'c'.padRight(64, 'c');
        final concurrent = 'd'.padRight(64, 'd');
        when(() => h.client.publishEvent(any())).thenAnswer((i) async {
          final local = h.service.getDefaultList()!;
          await h.prefs.setString(
            CuratedListService.listsStorageKey,
            jsonEncode([
              local
                  .copyWith(
                    videoEventIds: [...local.videoEventIds, concurrent],
                    pendingRepublish: true,
                  )
                  .toJson(),
            ]),
          );
          return const PublishFailed();
        });
        expect(await h.service.addVideoToList(_defaultId, added), isFalse);
        expect(h.service.getDefaultList()!.pendingRepublish, isTrue);
        expect(h.service.getDefaultList()!.videoEventIds, contains(added));
        expect(h.service.getDefaultList()!.videoEventIds, contains(concurrent));
        h.signed.clear();
        h.sent.clear();
        h.relay = () => const Stream.empty();
        await h.service.fetchUserListsFromRelays(force: true);
        expect(h.signed, isEmpty);
        expect(h.sent, isEmpty);
      },
    );
    test(
      'retry of the same failed explicit value remains permitted without broadening intent',
      () async {
        final baseline = await _privateEvent(signer, owner);
        h.relay = () => Stream.value(baseline);
        await h.settle();
        expect(h.service.getDefaultList()!.videoEventIds, contains(_video));
        h.signed.clear();
        h.sent.clear();
        when(
          () => h.client.publishEvent(any()),
        ).thenAnswer((_) async => const PublishFailed());
        final added = 'c'.padRight(64, 'c');
        expect(await h.service.addVideoToList(_defaultId, added), isFalse);
        expect(h.service.getDefaultList()!.pendingRepublish, isTrue);
        expect(h.service.getDefaultList()!.videoEventIds, contains(added));
        h.signed.clear();
        h.sent.clear();
        h.relay = () => const Stream.empty();
        await h.service.fetchUserListsFromRelays(force: true);
        expect(h.sent, hasLength(1));
        final items = jsonDecode(
          (await signer.nip44Decrypt(owner, h.sent.single.content))!,
        ) as List;
        expect(items, [
          ['e', _video],
          ['e', added],
        ]);
        await h.service.fetchUserListsFromRelays(force: true);
        expect(h.sent, hasLength(1));
      },
    );
  });
}

Event _publicEvent(String owner) {
  final event = Event(
    owner,
    30005,
    [
      ['d', _defaultId],
    ],
    '',
    createdAt: 1700000000,
  );
  event.sign(_testKey);
  return event;
}

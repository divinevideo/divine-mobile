// ABOUTME: List providers replace a fenced service after real account settlement.
// ABOUTME: Rendered frames, native receipts and event payloads grant no early writes.

import 'dart:async';
import 'dart:convert';

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/container_swap_host.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/auth/account_activation_coordinator.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/relay_discovery_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../test_setup.dart';

class _Keys extends Mock implements SecureKeyStorage {}

class _Discovery extends Mock implements RelayDiscoveryService {}

class _Client extends Mock implements NostrClient {}

class _Api extends Mock implements FunnelcakeApiClient {}

class _ForgedReceipt extends Mock implements AccountActivationReceipt {}

class _Backend extends InMemorySharedPreferencesStore {
  _Backend(super.data) : super.withData();

  bool refuseCommitted = false;
  Completer<void>? committedEntered;
  Completer<void>? releaseCommitted;

  void holdCommittedWrite() {
    committedEntered = Completer<void>();
    releaseCommitted = Completer<void>();
  }

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key.endsWith(AccountActivationCoordinator.storageKey) &&
        value.toString().contains('"phase":"committed"')) {
      committedEntered?.complete();
      final release = releaseCommitted;
      releaseCommitted = null;
      if (release != null) await release.future;
      if (refuseCommitted) return false;
    }
    return super.setValue(type, key, value);
  }
}

/// Only the notification wire has a seam. Identity, terminal receipt getters,
/// native metadata and all account activation operations use AuthService.
class _NotificationAuth extends AuthService {
  _NotificationAuth({
    required super.userDataCleanupService,
    required super.backgroundActivityManager,
    required super.keyStorage,
    required super.relayDiscoveryService,
  }) : super(profileCheckIndexerUrl: 'unsupported://profile.invalid') {
    _native = super.accountActivationChanges.listen(_notifications.add);
  }

  final _notifications =
      StreamController<AccountActivationReceipt?>.broadcast();
  late final StreamSubscription<AccountActivationReceipt?> _native;

  @override
  Stream<AccountActivationReceipt?> get accountActivationChanges =>
      _notifications.stream;

  void deliverUntrustedNotification(AccountActivationReceipt receipt) =>
      _notifications.add(receipt);

  @override
  Future<void> dispose() async {
    await _native.cancel();
    await _notifications.close();
    await super.dispose();
  }
}

void main() {
  setupTestEnvironment();

  const nsec =
      'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5';
  final foreignOwner = 'b' * 64;
  final video = 'c' * 64;
  late SharedPreferencesStorePlatform originalStore;
  late _Backend backend;
  late SharedPreferences prefs;
  late _NotificationAuth auth;
  late _Client client;
  late SecureKeyContainer keys;
  late CuratedList own;
  late CuratedList foreign;
  late AccountSwitchController controller;
  ProviderContainer? incoming;
  ProviderSubscription<AsyncValue<List<CuratedList>>>? listSubscription;
  ProviderSubscription<AuthState>? authSubscription;

  setUpAll(() {
    registerFallbackValue(SecureKeyContainer.fromNsec(nsec));
    registerFallbackValue(<Filter>[]);
  });

  setUp(() {
    incoming = null;
    listSubscription = null;
    authSubscription = null;
    originalStore = SharedPreferencesStorePlatform.instance;
  });

  Future<void> initializeFixture() async {
    keys = SecureKeyContainer.fromNsec(nsec);
    own = CuratedList(
      id: CuratedListService.defaultListId,
      name: 'Own saved list',
      pubkey: keys.publicKeyHex,
      nostrEventId: 'd' * 64,
      videoEventIds: [video],
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    foreign = CuratedList(
      id: 'foreign-list',
      name: 'Other account',
      pubkey: foreignOwner,
      nostrEventId: 'e' * 64,
      videoEventIds: const [],
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    backend = _Backend({
      'flutter.current_user_pubkey_hex': keys.publicKeyHex,
      'flutter.authentication_source': 'imported_keys',
      'flutter.known_accounts': '[]',
      'flutter.${CuratedListService.listsStorageKey}': jsonEncode([
        own.toJson(),
        foreign.toJson(),
      ]),
      'flutter.${CuratedListService.subscribedListsStorageKey}': jsonEncode([
        own.authorScopedId,
      ]),
    });
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = backend;
    prefs = await SharedPreferences.getInstance();
    final secureKeys = _Keys();
    when(secureKeys.initialize).thenAnswer((_) async {});
    when(secureKeys.hasKeys).thenAnswer((_) async => true);
    when(secureKeys.clearCache).thenReturn(null);
    when(secureKeys.dispose).thenReturn(null);
    when(secureKeys.getKeyContainer).thenAnswer((_) async => keys);
    when(() => secureKeys.getIdentityKeyContainer(any())).thenAnswer(
      (call) async =>
          call.positionalArguments.single == keys.npub ? keys : null,
    );
    when(() => secureKeys.switchToIdentity(any()))
        .thenAnswer((_) async => true);
    when(() => secureKeys.storeIdentityKeyContainer(any(), any()))
        .thenAnswer((_) async {});
    final discovery = _Discovery();
    when(() => discovery.clearCache(any())).thenAnswer((_) async {});
    when(() => discovery.discoverRelays(any())).thenAnswer(
      (_) async => RelayDiscoveryResult.failure('No network in provider test'),
    );
    final cleanup = UserDataCleanupService(prefs);
    cleanup.onDatabaseCleanup = ({
      String? userPubkey,
      bool deleteUserData = false,
      bool preserveActiveSession = false,
    }) async {};
    auth = _NotificationAuth(
      userDataCleanupService: cleanup,
      backgroundActivityManager: BackgroundActivityManager(),
      keyStorage: secureKeys,
      relayDiscoveryService: discovery,
    );
    client = _Client();
    when(() => client.subscribe(any(), closeOnEose: true))
        .thenAnswer((_) => const Stream<Event>.empty());
    controller = AccountSwitchController();
  }

  tearDown(() async {
    listSubscription?.close();
    authSubscription?.close();
    await auth.dispose();
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = originalStore;
  });

  Map<String, Object?> snapshot() => {
    for (final key in prefs.getKeys()) key: prefs.get(key),
  };

  Future<CuratedListService> prepareIncoming(WidgetTester tester) async {
    await tester.runAsync(initializeFixture);
    await tester.pumpWidget(
      ContainerSwapHost(
        initialContainer: ProviderContainer(),
        controller: controller,
        child: const SizedBox(),
      ),
    );
    final outgoingFrame = controller.currentCommit!;
    await tester.runAsync(() async {
      await auth.initializeForAccountSwitch();
      await auth.prepareAccountSwitchActivation(
        prefs,
        ownerPubkey: keys.publicKeyHex,
        outgoingHostIsCurrent: () => outgoingFrame.isCurrent,
      );
      await auth.signInForAccount(
        keys.publicKeyHex,
        AuthenticationSource.importedKeys,
        claimLegacyRows: false,
      );
      await pumpEventQueue();
    });
    expect(auth.authState, AuthState.authenticated);
    expect(auth.currentPublicKeyHex, keys.publicKeyHex);
    expect(auth.committedAccountActivationReceipt, isNull);
    // Starting the async provider and awaiting its future must share the real
    // async zone. Waiting on a build started in fake async cannot drain it.
    await tester.runAsync(() async {
      incoming = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          sharedPreferencesProvider.overrideWithValue(prefs),
          nostrServiceProvider.overrideWithValue(client),
        ],
      );
      listSubscription = incoming!.listen(
        curatedListsStateProvider,
        (_, _) {},
        fireImmediately: true,
      );
      await incoming!.read(curatedListsStateProvider.future);
    });
    return incoming!.read(curatedListsStateProvider.notifier).service!;
  }

  Future<AccountContainerCommitReceipt> commitFrame(WidgetTester tester) async {
    var delivered = false;
    final pending = controller.swapToAndCommit(incoming!).then((receipt) {
      delivered = true;
      return receipt;
    });
    expect(delivered, isFalse);
    expect(controller.currentCommit, isNull);
    expect(auth.committedAccountActivationReceipt, isNull);
    await tester.pump();
    final frame = await pending;
    expect(frame.isCurrent, isTrue);
    expect(auth.committedAccountActivationReceipt, isNull);
    return frame;
  }

  void expectIncomplete(CuratedListService service) {
    expect(service.isCurrentSession, isFalse);
    expect(service.isInitialized, isFalse);
    expect(service.isReadyForMutations, isFalse);
    expect(
      service.initializationError,
      isA<CuratedListAccountBoundaryException>(),
    );
    expect(hasCompleteSubscriptionSnapshotForHomeBridge(service), isFalse);
    expect(service.pickerListsForOwner(keys.publicKeyHex), isEmpty);
    expect(incoming!.read(currentAccountActivationReceiptProvider), isNull);
    expect(incoming!.read(curatedListsStateProvider).requireValue, isEmpty);
    verifyZeroInteractions(client);
  }

  Future<void> settleListProvider(WidgetTester tester) async {
    // A mounted container can rebuild in the widget's fake async zone. Drive
    // both native event delivery and widget microtasks instead of awaiting a
    // fake-zone provider future from a suspended runAsync callback.
    for (var attempts = 0; attempts < 20; attempts++) {
      await tester.runAsync(pumpEventQueue);
      await tester.pump();
      if (!incoming!.read(curatedListsStateProvider).isLoading) {
        break;
      }
    }
    final state = incoming!.read(curatedListsStateProvider);
    expect(state.isLoading, isFalse, reason: 'list initialization must settle');
    expect(state.hasValue, isTrue);
  }

  group('terminal account activation list provider', () {
    testWidgets(
      'terminal receipt replaces the fenced service without another auth enum',
      (tester) async {
        final fenced = await prepareIncoming(tester);
        final authStates = <AuthState>[];
        authSubscription = incoming!.listen(
          currentAuthStateProvider,
          (_, next) => authStates.add(next),
          fireImmediately: true,
        );
        expectIncomplete(fenced);
        final pendingSnapshot = snapshot();
        expect(
          await fenced.removeVideoFromList(own.authorScopedId, video),
          isFalse,
        );
        expect(snapshot(), pendingSnapshot);
        final frame = await commitFrame(tester);
        expectIncomplete(fenced);

        late Completer<void> release;
        late Future<void> terminal;
        await tester.runAsync(() async {
          backend.holdCommittedWrite();
          release = backend.releaseCommitted!;
          terminal = auth.commitAccountSwitchActivation(
            hostIsCurrent: () => frame.isCurrent,
          );
          await backend.committedEntered!.future;
        });
        expectIncomplete(fenced);
        expect(auth.authState, AuthState.authenticated);
        await tester.runAsync(() async {
          release.complete();
          await terminal;
          await pumpEventQueue();
        });
        await settleListProvider(tester);
        final current = incoming!
            .read(curatedListsStateProvider.notifier)
            .service!;
        expect(current, isNot(same(fenced)));
        expect(current.isCurrentSession, isTrue);
        expect(current.isInitialized, isTrue);
        expect(current.isReadyForMutations, isTrue);
        expect(current.initializationError, isNull);
        expect(current.pickerListsForOwner(keys.publicKeyHex), [own]);
        expect(current.pickerListsForOwner(foreignOwner), isEmpty);
        expect(hasCompleteSubscriptionSnapshotForHomeBridge(current), isTrue);
        expect(
          incoming!.read(currentAccountActivationReceiptProvider),
          same(auth.committedAccountActivationReceipt),
        );
        expect(authStates, [AuthState.authenticated]);

        final repository = CuratedListRepository(
          nostrClient: client,
          funnelcakeApiClient: _Api(),
        );
        addTearDown(repository.dispose);
        syncCuratedListRepositoryBridge(
          repository,
          fenced,
          viewerPubkey: keys.publicKeyHex,
          isDataReady: true,
        );
        expect(repository.hasCompleteSubscriptionSnapshot, isFalse);
        expect(repository.getSubscribedLists(), isEmpty);
        syncCuratedListRepositoryBridge(
          repository,
          current,
          viewerPubkey: keys.publicKeyHex,
          isDataReady: true,
        );
        expect(repository.hasCompleteSubscriptionSnapshot, isTrue);
        expect(repository.getSubscribedLists(), [own]);
        expect(repository.searchLists('Own saved list'), [own]);
        expect(repository.searchLists('Other account'), isEmpty);

        final committedSnapshot = snapshot();
        expect(fenced.isCurrentSession, isFalse);
        expect(
          await fenced.removeVideoFromList(own.authorScopedId, video),
          isFalse,
        );
        expect(snapshot(), committedSnapshot);
        await tester.pumpWidget(const SizedBox());
        expect(current.isCurrentSession, isFalse);
        expect(
          await current.removeVideoFromList(own.authorScopedId, video),
          isFalse,
        );
        expect(snapshot(), committedSnapshot);
      },
    );

    testWidgets(
      'a rendered frame with a refused native commit remains fenced',
      (
        tester,
      ) async {
        final fenced = await prepareIncoming(tester);
        final frame = await commitFrame(tester);
        backend.refuseCommitted = true;
        await tester.runAsync(() async {
          await expectLater(
            auth.commitAccountSwitchActivation(
              hostIsCurrent: () => frame.isCurrent,
            ),
            throwsStateError,
          );
          await pumpEventQueue();
        });
        await tester.pump();
        expect(auth.authState, AuthState.authenticated);
        expect(auth.committedAccountActivationReceipt, isNull);
        expect(
          incoming!.read(curatedListsStateProvider.notifier).service,
          same(fenced),
        );
        expectIncomplete(fenced);
        final before = snapshot();
        expect(
          await fenced.removeVideoFromList(own.authorScopedId, video),
          isFalse,
        );
        expect(snapshot(), before);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'an event claiming a current owner cannot replace native proof',
      (
        tester,
      ) async {
        final fenced = await prepareIncoming(tester);
        final frame = await commitFrame(tester);
        final forged = _ForgedReceipt();
        when(() => forged.isCurrent).thenReturn(true);
        when(() => forged.ownerPubkey).thenReturn(keys.publicKeyHex);
        final before = snapshot();
        auth.deliverUntrustedNotification(forged);
        await tester.pump();
        expect(auth.committedAccountActivationReceipt, isNull);
        expect(
          incoming!.read(curatedListsStateProvider.notifier).service,
          same(fenced),
        );
        expectIncomplete(fenced);
        expect(
          await fenced.removeVideoFromList(own.authorScopedId, video),
          isFalse,
        );
        expect(snapshot(), before);
        verifyZeroInteractions(forged);

        await tester.runAsync(() async {
          await auth.commitAccountSwitchActivation(
            hostIsCurrent: () => frame.isCurrent,
          );
          await pumpEventQueue();
        });
        await settleListProvider(tester);
        final current = incoming!
            .read(curatedListsStateProvider.notifier)
            .service!;
        expect(current, isNot(same(fenced)));
        expect(current.isCurrentSession, isTrue);
        expect(current.pickerListsForOwner(keys.publicKeyHex), [own]);
        verifyZeroInteractions(forged);
        await tester.pumpWidget(const SizedBox());
      },
    );
  });
}

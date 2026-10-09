// ABOUTME: Tests swapAccount orchestration — build, sign in, swap; roll back
// ABOUTME: (dispose the new container, leave the old) when sign-in fails.

import 'dart:async';
import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/container_swap_host.dart';
import 'package:openvine/providers/device_scope.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/notifications_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/swap_account.dart'
    show accountSwitchInitialLocation;
import 'package:openvine/providers/swap_account.dart' as switching;
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/services/auth/account_activation_coordinator.dart';
import 'package:openvine/services/auth/pending_account_cleanup.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/feed_mode_persistence.dart';
import 'package:openvine/services/push_notification_session_coordinator.dart';
import 'package:openvine/services/relay_discovery_service.dart';
import 'package:openvine/services/startup_performance_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:openvine/utils/log_message_batcher.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
// Override lives in riverpod's misc barrel; flutter_riverpod does not
// re-export the type name even though it accepts List<Override>.
import 'package:riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/curated_list_publish_stubs.dart';

class _MockDiscovery extends Mock implements RelayDiscoveryService {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockPushNotificationSessionCoordinator extends Mock
    implements PushNotificationSessionCoordinator {}

class _MockDmRepository extends Mock implements DmRepository {}

bool _isDisposed(ProviderContainer c) {
  try {
    c.read(sharedPreferencesProvider);
    return false;
    // A disposed ProviderContainer throws StateError on read — that is exactly
    // the disposal signal these tests assert on, so catching it is intentional.
    // ignore: avoid_catching_errors
  } on StateError {
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late DeviceScope deviceScope;
  late AccountSwitchController controller;
  late _FakeSecureKeyStorage keyStorage;
  late _FakeAuthService currentAuthService;

  final leavingHex = SecureKeyContainer.fromPrivateKeyHex('2' * 64)
      .publicKeyHex;
  late SecureKeyContainer leavingKeys;
  final targetHex = SecureKeyContainer.fromPrivateKeyHex('1' * 64).publicKeyHex;
  // A third identity, belonging to neither account. A preserve case built on
  // the target's own npub cannot fail: both the retarget branch and the
  // preserve branch emit the same string.
  const strangerHex =
      '3333333333333333333333333333333333333333333333333333333333333333';
  final leavingNpub = NostrKeyUtils.encodePubKey(leavingHex);
  final targetNpub = NostrKeyUtils.encodePubKey(targetHex);
  final strangerNpub = NostrKeyUtils.encodePubKey(strangerHex);
  final leavingNprofile = NIP19Tlv.encodeNprofile(
    Nprofile(pubkey: leavingHex, relays: const ['wss://relay.divine.video']),
  );

  final account = KnownAccount(
    pubkeyHex: targetHex,
    authSource: AuthenticationSource.automatic,
    addedAt: DateTime(2026),
    lastUsedAt: DateTime(2026),
  );

  WidgetTester? activeTester;
  AuthService? incomingAuthOverride;

  setUp(() async {
    activeTester = null;
    incomingAuthOverride = null;
    database = AppDatabase.test(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    controller = AccountSwitchController();
    leavingKeys = SecureKeyContainer.fromPrivateKeyHex('2' * 64);
    keyStorage = _FakeSecureKeyStorage()..primary = leavingKeys;
    final outgoingStorage = _RestorableSecureKeyStorage(leavingKeys)
      ..primary = leavingKeys;
    final discovery = _MockDiscovery();
    when(() => discovery.discoverRelays(any())).thenAnswer(
      (_) async => RelayDiscoveryResult.failure('No network in swap tests'),
    );
    currentAuthService = _FakeAuthService(
      userDataCleanupService: UserDataCleanupService(prefs),
      backgroundActivityManager: BackgroundActivityManager(),
      keyStorage: outgoingStorage,
      relayDiscoveryService: discovery,
      profileCheckIndexerUrl: 'unsupported://profile.invalid',
    );
    await currentAuthService.initializeForAccountSwitch();
    await currentAuthService.signInForAccount(
      leavingHex,
      AuthenticationSource.automatic,
    );
    expect(
      currentAuthService.committedAccountActivationReceipt?.isCurrent,
      isTrue,
    );
    await pumpEventQueue();
    deviceScope = DeviceScope(
      database: database,
      sharedPreferences: prefs,
      feedModePersistence: FeedModePersistenceRegistry(
        sharedPreferences: prefs,
      ),
      switchController: controller,
      appVersion: 'test',
      crashReporting: CrashReportingService(),
      startupPerformance: StartupPerformanceService(
        crashReporting: CrashReportingService(),
      ),
      documentsPath: '/documents',
      logMessageBatcher: LogMessageBatcher(),
      accountOverrides: [
        secureKeyStorageProvider.overrideWithValue(keyStorage),
        pushNotificationSyncProvider.overrideWithValue(null),
      ],
    );
  });

  tearDown(() async {
    await currentAuthService.dispose();
    await database.close();
  });

  void overridePushSync(PushNotificationSessionCoordinator? coordinator) {
    deviceScope = DeviceScope(
      database: database,
      sharedPreferences: deviceScope.sharedPreferences,
      feedModePersistence: deviceScope.feedModePersistence,
      switchController: controller,
      appVersion: 'test',
      crashReporting: CrashReportingService(),
      startupPerformance: StartupPerformanceService(
        crashReporting: CrashReportingService(),
      ),
      documentsPath: '/documents',
      logMessageBatcher: LogMessageBatcher(),
      accountOverrides: [
        secureKeyStorageProvider.overrideWithValue(keyStorage),
        pushNotificationSyncProvider.overrideWithValue(coordinator),
      ],
    );
  }

  AuthService makeIncomingAuth({bool failClaim = false}) {
    final discovery = _MockDiscovery();
    when(() => discovery.discoverRelays(any())).thenAnswer(
      (_) async =>
          RelayDiscoveryResult.failure('No network in account swap tests'),
    );
    final cleanup = UserDataCleanupService(deviceScope.sharedPreferences);
    if (failClaim) {
      cleanup.onClaimLegacyRows = (owner) async =>
          throw StateError('database unavailable');
    }
    return AuthService(
      userDataCleanupService: cleanup,
      backgroundActivityManager: BackgroundActivityManager(),
      keyStorage: keyStorage,
      relayDiscoveryService: discovery,
      profileCheckIndexerUrl: 'unsupported://profile.invalid',
    );
  }

  // Callback fixtures continue to assert routing, push and DM orchestration;
  // their success path now also performs the real identity/session settlement.
  Future<void> swapAccount({
    required DeviceScope deviceScope,
    required AccountSwitchController controller,
    required AuthService currentAuthService,
    required KnownAccount account,
    switching.AccountSignIn? signIn,
  }) async {
    Future<void> run() {
      if (signIn == null) {
        return switching.swapAccount(
          deviceScope: deviceScope,
          controller: controller,
          currentAuthService: currentAuthService,
          account: account,
        );
      }
      final scope = DeviceScope(
        database: deviceScope.database,
        sharedPreferences: deviceScope.sharedPreferences,
        feedModePersistence: deviceScope.feedModePersistence,
        switchController: deviceScope.switchController,
        appVersion: deviceScope.appVersion,
        documentsPath: deviceScope.documentsPath,
        startupPerformance: deviceScope.startupPerformance,
        crashReporting: deviceScope.crashReporting,
        logMessageBatcher: deviceScope.logMessageBatcher,
        accountOverrides: [
          ...deviceScope.accountOverrides.where(
            (o) => o.origin != authServiceProvider,
          ),
          authServiceProvider.overrideWith((ref) {
            final auth = incomingAuthOverride ?? makeIncomingAuth();
            ref.onDispose(() => unawaited(auth.dispose()));
            return auth;
          }),
        ],
      );
      return switching.swapAccount(
        deviceScope: scope,
        controller: controller,
        currentAuthService: currentAuthService,
        account: account,
        signIn: (container, selected) async {
          await signIn(container, selected);
          final auth = container.read(authServiceProvider);
          await auth.initializeForAccountSwitch();
          await auth.signInForAccount(
            selected.pubkeyHex,
            selected.authSource,
            claimLegacyRows: false,
          );
        },
      );
    }

    return run();
  }

  Future<void> driveSwap(
    Future<void> operation, {
    Object? expected,
    String reason = 'Account switch must settle within explicit frames',
  }) => TestAsyncUtils.guard(() async {
    final tester = activeTester!;
    var settled = false;
    final watched = operation.whenComplete(() {
      settled = true;
    });
    // Install the exact matcher before any guarded widget operation begins.
    final checked = expectLater(watched, expected ?? completes);
    for (var frame = 0; !settled && frame < 250; frame += 1) {
      // Native storage and coordinator tails may originate in setUp's
      // real async zone. Let those callbacks progress between host frames.
      await tester.runAsync(pumpEventQueue);
      await tester.pump();
    }
    expect(
      settled,
      isTrue,
      reason: reason,
    );
    await checked;
  });

  group('accountSwitchInitialLocation', () {
    test('retargets the leaving account own-profile route', () {
      expect(
        accountSwitchInitialLocation(
          currentLocation: '/profile/$leavingNpub',
          currentPubkeyHex: leavingHex,
          targetPubkeyHex: targetHex,
        ),
        '/profile/$targetNpub',
      );
    });

    test('retargets the relative own-profile route', () {
      expect(
        accountSwitchInitialLocation(
          currentLocation: '/profile/me',
          currentPubkeyHex: leavingHex,
          targetPubkeyHex: targetHex,
        ),
        '/profile/$targetNpub',
      );
    });

    test('retargets own-profile video routes and preserves URI metadata', () {
      expect(
        accountSwitchInitialLocation(
          currentLocation: '/profile/$leavingNpub/7?source=notification#clip',
          currentPubkeyHex: leavingHex,
          targetPubkeyHex: targetHex,
        ),
        '/profile/$targetNpub/7?source=notification#clip',
      );
    });

    // The own-profile route accepts three encodings of the same identity. A
    // raw string compare against the npub leaves the other two stranded on the
    // leaving account — /profile/{hex} is a documented deep-link form.
    test('retargets an own-profile route carried as bare hex', () {
      expect(
        accountSwitchInitialLocation(
          currentLocation: '/profile/$leavingHex',
          currentPubkeyHex: leavingHex,
          targetPubkeyHex: targetHex,
        ),
        '/profile/$targetNpub',
      );
    });

    test('retargets an own-profile route carried as uppercase hex', () {
      expect(
        accountSwitchInitialLocation(
          currentLocation: '/profile/${leavingHex.toUpperCase()}',
          currentPubkeyHex: leavingHex,
          targetPubkeyHex: targetHex,
        ),
        '/profile/$targetNpub',
      );
    });

    test('retargets an own-profile route carried as nprofile', () {
      expect(
        accountSwitchInitialLocation(
          currentLocation: '/profile/$leavingNprofile',
          currentPubkeyHex: leavingHex,
          targetPubkeyHex: targetHex,
        ),
        '/profile/$targetNpub',
      );
    });

    test('preserves another user profile', () {
      expect(
        accountSwitchInitialLocation(
          currentLocation: '/profile/$strangerNpub',
          currentPubkeyHex: leavingHex,
          targetPubkeyHex: targetHex,
        ),
        '/profile/$strangerNpub',
      );
    });

    test('preserves another user profile carried as hex', () {
      // Normalizing the comparison must not widen it: a stranger's hex is
      // still a stranger.
      expect(
        accountSwitchInitialLocation(
          currentLocation: '/profile/$strangerHex',
          currentPubkeyHex: leavingHex,
          targetPubkeyHex: targetHex,
        ),
        '/profile/$strangerHex',
      );
    });

    test('preserves an undecodable identifier for an unknown identity', () {
      // Both sides normalize to null here; treating that as a match would
      // retarget a garbage route.
      expect(
        accountSwitchInitialLocation(
          currentLocation: '/profile/not-an-identifier',
          currentPubkeyHex: null,
          targetPubkeyHex: targetHex,
        ),
        '/profile/not-an-identifier',
      );
    });

    test('preserves a profile route when the leaving identity is unknown', () {
      expect(
        accountSwitchInitialLocation(
          currentLocation: '/profile/$leavingNpub',
          currentPubkeyHex: null,
          targetPubkeyHex: targetHex,
        ),
        '/profile/$leavingNpub',
      );
    });

    test('retargets the leaving account followers route', () {
      expect(
        accountSwitchInitialLocation(
          currentLocation: '/followers/$leavingNpub',
          currentPubkeyHex: leavingHex,
          targetPubkeyHex: targetHex,
        ),
        '/followers/$targetHex',
      );
    });

    test('retargets the leaving account following route', () {
      expect(
        accountSwitchInitialLocation(
          currentLocation: '/following/$leavingNpub',
          currentPubkeyHex: leavingHex,
          targetPubkeyHex: targetHex,
        ),
        '/following/$targetHex',
      );
    });

    test('retargets the leaving account profile-view route', () {
      expect(
        accountSwitchInitialLocation(
          currentLocation: '/profile-view/$leavingNpub',
          currentPubkeyHex: leavingHex,
          targetPubkeyHex: targetHex,
        ),
        '/profile-view/$targetNpub',
      );
    });

    test('retargets following route with bare hex identifier', () {
      expect(
        accountSwitchInitialLocation(
          currentLocation: '/following/$leavingHex',
          currentPubkeyHex: leavingHex,
          targetPubkeyHex: targetHex,
        ),
        '/following/$targetHex',
      );
    });

    test('retargets profile-view route with nprofile identifier', () {
      expect(
        accountSwitchInitialLocation(
          currentLocation: '/profile-view/$leavingNprofile',
          currentPubkeyHex: leavingHex,
          targetPubkeyHex: targetHex,
        ),
        '/profile-view/$targetNpub',
      );
    });

    test('preserves followers route for another user', () {
      expect(
        accountSwitchInitialLocation(
          currentLocation: '/followers/$strangerNpub',
          currentPubkeyHex: leavingHex,
          targetPubkeyHex: targetHex,
        ),
        '/followers/$strangerNpub',
      );
    });

    test('preserves following route for another user', () {
      expect(
        accountSwitchInitialLocation(
          currentLocation: '/following/$strangerNpub',
          currentPubkeyHex: leavingHex,
          targetPubkeyHex: targetHex,
        ),
        '/following/$strangerNpub',
      );
    });

    test('preserves profile-view route for another user', () {
      expect(
        accountSwitchInitialLocation(
          currentLocation: '/profile-view/$strangerNpub',
          currentPubkeyHex: leavingHex,
          targetPubkeyHex: targetHex,
        ),
        '/profile-view/$strangerNpub',
      );
    });

    test('retargets followers route and preserves URI metadata', () {
      expect(
        accountSwitchInitialLocation(
          currentLocation: '/followers/$leavingNpub?sort=recent#top',
          currentPubkeyHex: leavingHex,
          targetPubkeyHex: targetHex,
        ),
        '/followers/$targetHex?sort=recent#top',
      );
    });

    test('preserves an unlisted route that carries the leaving pubkey', () {
      expect(
        accountSwitchInitialLocation(
          currentLocation: '/original-sound/$leavingHex',
          currentPubkeyHex: leavingHex,
          targetPubkeyHex: targetHex,
        ),
        '/original-sound/$leavingHex',
      );
    });

    test('preserves a single-segment route', () {
      expect(
        accountSwitchInitialLocation(
          currentLocation: '/settings',
          currentPubkeyHex: leavingHex,
          targetPubkeyHex: targetHex,
        ),
        '/settings',
      );
    });

    test('returns null when there is no current location', () {
      expect(
        accountSwitchInitialLocation(
          currentLocation: null,
          currentPubkeyHex: leavingHex,
          targetPubkeyHex: targetHex,
        ),
        isNull,
      );
    });
  });

  Future<ProviderContainer> pumpHost(
    WidgetTester tester, {
    List<Override> accountOverrides = const [],
    Widget Function(ProviderContainer container)? childBuilder,
  }) async {
    activeTester = tester;
    final initial = buildAccountContainer(
      deviceScope,
      accountOverrides: [
        if (!deviceScope.accountOverrides.any(
              (override) => override.origin == authServiceProvider,
            ) &&
            !accountOverrides.any(
              (override) => override.origin == authServiceProvider,
            ))
          authServiceProvider.overrideWithValue(currentAuthService),
        ...accountOverrides,
      ],
    );
    await tester.pumpWidget(
      ContainerSwapHost(
        initialContainer: initial,
        controller: controller,
        child: childBuilder?.call(initial) ?? const SizedBox(),
      ),
    );
    return initial;
  }

  group('account cleanup rollback', () {
    testWidgets(
      'default sign-in rolls back when the real identity sweep refuses removal',
      (tester) async {
        final prefs = deviceScope.sharedPreferences;
        await prefs.setString('current_user_pubkey_hex', leavingHex);
        final outgoingCache = jsonEncode([
          CuratedList(
            id: 'outgoing-list',
            name: 'Outgoing account list',
            videoEventIds: const [],
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
            pubkey: leavingHex,
          ).toJson(),
        ]);
        await prefs.setString(
          CuratedListService.listsStorageKey,
          outgoingCache,
        );
        final targetKey = SecureKeyContainer.fromPrivateKeyHex('1' * 64);
        final storage = _RestorableSecureKeyStorage(targetKey);
        final oldKey = leavingKeys;
        storage.primary = oldKey;
        final refusingPrefs = _RefusingCleanupPreferences(prefs);
        final cleanup = UserDataCleanupService(refusingPrefs);
        var databaseCleanups = 0;
        cleanup.onDatabaseCleanup =
            ({
              String? userPubkey,
              bool deleteUserData = false,
              bool preserveActiveSession = false,
            }) async {
              databaseCleanups++;
            };
        var incomingDisposed = false;
        var authContainers = 0;
        final oldAuth = currentAuthService;
        deviceScope = DeviceScope(
          database: database,
          sharedPreferences: prefs,
          feedModePersistence: FeedModePersistenceRegistry(
            sharedPreferences: prefs,
          ),
          switchController: controller,
          appVersion: 'test',
          crashReporting: deviceScope.crashReporting,
          startupPerformance: deviceScope.startupPerformance,
          documentsPath: '/documents',
          logMessageBatcher: deviceScope.logMessageBatcher,
          accountOverrides: [
            secureKeyStorageProvider.overrideWithValue(storage),
            pushNotificationSyncProvider.overrideWithValue(null),
            authServiceProvider.overrideWith((ref) {
              if (authContainers++ == 0) {
                return oldAuth;
              }
              final auth = AuthService(
                backgroundActivityManager: BackgroundActivityManager(),
                userDataCleanupService: cleanup,
                keyStorage: storage,
              );
              ref.onDispose(() {
                incomingDisposed = true;
                unawaited(auth.dispose());
              });
              return auth;
            }),
          ],
        );
        final initial = await pumpHost(tester);
        initial.read(authServiceProvider);
        final targetAccount = KnownAccount(
          pubkeyHex: targetKey.publicKeyHex,
          authSource: AuthenticationSource.automatic,
          addedAt: DateTime(2026),
          lastUsedAt: DateTime(2026),
        );
        await driveSwap(
          swapAccount(
            deviceScope: deviceScope,
            controller: controller,
            currentAuthService: currentAuthService,
            account: targetAccount,
          ),
          expected: throwsA(isA<UserDataCleanupException>()),
        );
        expect(controller.currentContainer, same(initial));
        expect(_isDisposed(initial), isFalse);
        expect(incomingDisposed, isTrue);
        expect(storage.primary, same(oldKey));
        expect(storage.restoredPrimary, same(oldKey));
        expect(currentAuthService.calls, ['archive', 'restore']);
        expect(
          refusingPrefs.refusedKeys,
          contains(CuratedListService.listsStorageKey),
        );
        await prefs.reload();
        final pendingCleanup = PendingAccountCleanup.read(prefs);
        expect(pendingCleanup, isNotNull);
        expect(pendingCleanup!.userPubkey, leavingHex);
        expect(pendingCleanup.isIdentityChange, isTrue);
        expect(pendingCleanup.deleteUserData, isFalse);
        expect(prefs.getString('current_user_pubkey_hex'), leavingHex);
        expect(
          prefs.getString(CuratedListService.listsStorageKey),
          outgoingCache,
        );
        expect(databaseCleanups, 0);
      },
    );
  });

  /// Switches away from [from] and reports the location [swapAccount] seeded
  /// into the container it built for the target account.
  ///
  /// The router has to be both created in the container and mounted in a
  /// `Router` widget. `_currentRouterLocation` gates on
  /// `container.exists(goRouterProvider)`, and `currentConfiguration` stays
  /// `RouteMatchList.empty` until a `Router` attaches and parses the initial
  /// location — without either, it returns null and the whole retarget path
  /// goes inert.
  Future<String?> seededLocationSwitchingFrom(
    WidgetTester tester,
    String from,
  ) async {
    final auth = currentAuthService;
    final router = GoRouter(
      initialLocation: from,
      routes: [
        GoRoute(
          path: ProfileScreenRouter.pathWithNpub,
          builder: (_, _) => const SizedBox(),
        ),
        GoRoute(
          path: ProfileScreenRouter.pathWithIndex,
          builder: (_, _) => const SizedBox(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await pumpHost(
      tester,
      accountOverrides: [
        goRouterProvider.overrideWithValue(router),
        authServiceProvider.overrideWithValue(auth),
      ],
      childBuilder: (container) => MaterialApp.router(
        routerConfig: container.read(goRouterProvider),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );

    String? seeded;
    await driveSwap(
      swapAccount(
        deviceScope: deviceScope,
        controller: controller,
        currentAuthService: currentAuthService,
        account: account,
        signIn: (container, _) async {
          seeded = container.read(routerInitialLocationProvider);
        },
      ),
    );
    await tester.pump();
    return seeded;
  }

  group('navigation', () {
    testWidgets('seeds the swapped-in container with the retargeted route', (
      tester,
    ) async {
      expect(
        await seededLocationSwitchingFrom(
          tester,
          ProfileScreenRouter.pathForNpub(leavingNpub),
        ),
        ProfileScreenRouter.pathForNpub(targetNpub),
      );
    });

    testWidgets('seeds another user profile route unchanged', (tester) async {
      expect(
        await seededLocationSwitchingFrom(
          tester,
          ProfileScreenRouter.pathForNpub(strangerNpub),
        ),
        ProfileScreenRouter.pathForNpub(strangerNpub),
      );
    });
  });

  group('push lifecycle', () {
    testWidgets('deregisters outgoing push after target swap succeeds', (
      tester,
    ) async {
      ProviderContainer? signedInto;
      final events = <String>[];
      final cleanupCompleter = Completer<void>();
      final pushCoordinator = _MockPushNotificationSessionCoordinator();
      when(
        pushCoordinator.deregisterLastReadyPubkeyAfterAccountSwitch,
      ).thenAnswer((
        _,
      ) async {
        expectSync(controller.currentContainer, same(signedInto));
        events.add('deregister outgoing');
        await cleanupCompleter.future;
      });
      overridePushSync(pushCoordinator);
      final initial = await pumpHost(tester);
      initial.read(pushNotificationSyncProvider);

      await driveSwap(
        swapAccount(
          deviceScope: deviceScope,
          controller: controller,
          currentAuthService: currentAuthService,
          account: account,
          signIn: (container, acct) async {
            signedInto = container;
            events.add('sign in target');
            expectSync(acct, equals(account));
          },
        ),
      );
      await tester.pump();

      // Signed into a freshly-built container, not the initial one.
      expect(signedInto, isNotNull);
      expect(signedInto, isNot(same(initial)));
      // The target is live, but the old container still owns the signer needed by
      // the outgoing cleanup and cannot be disposed until that work settles.
      expect(_isDisposed(signedInto!), isFalse);
      expect(_isDisposed(initial), isFalse);
      expect(events, ['sign in target', 'deregister outgoing']);

      cleanupCompleter.complete();
      await tester.pump();

      expect(_isDisposed(initial), isTrue);
    });
  });

  group('account swap failure boundaries', () {
    testWidgets(
      'account label alone cannot grant outgoing rollback authority',
      (tester) async {
        final initial = await pumpHost(tester);
        final before = currentAuthService.committedAccountActivationReceipt;
        final unauthenticated = makeIncomingAuth();
        addTearDown(unauthenticated.dispose);
        var signInAttempted = false;
        await driveSwap(
          swapAccount(
            deviceScope: deviceScope,
            controller: controller,
            currentAuthService: unauthenticated,
            account: account,
            signIn: (_, _) async => signInAttempted = true,
          ),
          expected: throwsA(isA<AccountActivationRetiredException>()),
        );
        expect(signInAttempted, isFalse);
        expect(currentAuthService.calls, isEmpty);
        expect(controller.currentContainer, same(initial));
        expect(
          currentAuthService.committedAccountActivationReceipt,
          same(before),
        );
        expect(before!.isCurrent, isTrue);
        expect(keyStorage.restoredPrimary, isNull);
      },
    );

    testWidgets(
      'foreign primary snapshot cannot be restored for the old owner',
      (tester) async {
        final initial = await pumpHost(tester);
        final receipt = currentAuthService.committedAccountActivationReceipt!;
        final foreignKeys = SecureKeyContainer.fromPrivateKeyHex('1' * 64);
        keyStorage.primary = foreignKeys;
        var signInAttempted = false;
        await driveSwap(
          swapAccount(
            deviceScope: deviceScope,
            controller: controller,
            currentAuthService: currentAuthService,
            account: account,
            signIn: (_, _) async => signInAttempted = true,
          ),
          expected: throwsA(isA<StateError>()),
        );
        expect(signInAttempted, isFalse);
        expect(controller.currentContainer, same(initial));
        expect(keyStorage.primary, same(foreignKeys));
        expect(keyStorage.restoredPrimary, isNull);
        expect(currentAuthService.calls, ['archive']);
        expect(receipt.isCurrent, isTrue);
        expect(
          deviceScope.sharedPreferences.getString('current_user_pubkey_hex'),
          leavingHex,
        );
      },
    );

    testWidgets(
      'failed switch positively restores the original session owner',
      (tester) async {
        await pumpHost(tester);
        final original = currentAuthService.committedAccountActivationReceipt!;
        await driveSwap(
          swapAccount(
            deviceScope: deviceScope,
            controller: controller,
            currentAuthService: currentAuthService,
            account: account,
            signIn: (_, _) async => throw _FakeSignInException(),
          ),
          expected: throwsA(isA<_FakeSignInException>()),
        );
        final restored = currentAuthService.committedAccountActivationReceipt!;
        expect(original.isCurrent, isFalse);
        expect(restored.isCurrent, isTrue);
        expect(restored.ownerPubkey, leavingHex);
        expect(currentAuthService.isAuthenticated, isTrue);
        expect(keyStorage.restoredPrimary, same(leavingKeys));
        expect(currentAuthService.takeFreshAccountListCreationPermit(), isNull);
        expect(
          AccountActivationCoordinator.forPreferences(
            deviceScope.sharedPreferences,
          ).hasUnresolvedActivation,
          isFalse,
        );
      },
    );

    testWidgets(
      'retired native rollback drains before the next real owner writes',
      (tester) async {
        await pumpHost(tester);
        keyStorage.restoreEntered = Completer<void>();
        keyStorage.resumeRestore = Completer<void>();
        final resumed = keyStorage.resumeRestore!;
        final failure = expectLater(
          swapAccount(
            deviceScope: deviceScope,
            controller: controller,
            currentAuthService: currentAuthService,
            account: account,
            signIn: (_, _) async => throw _FakeSignInException(),
          ),
          throwsA(isA<_FakeSignInException>()),
        );
        AuthService? nextAuth;
        Future<void>? nextChecked;
        final nextKeys = SecureKeyContainer.fromPrivateKeyHex('3' * 64);
        var nextSettled = false;
        try {
          for (
            var frame = 0;
            !keyStorage.restoreEntered!.isCompleted && frame < 250;
            frame += 1
          ) {
            await tester.runAsync(pumpEventQueue);
            await tester.pump();
          }
          expect(keyStorage.restoreEntered!.isCompleted, isTrue);
          await tester.pumpWidget(const SizedBox());
          keyStorage.restorationTarget = nextKeys;
          nextAuth = makeIncomingAuth();
          addTearDown(nextAuth.dispose);
          await nextAuth.initializeForAccountSwitch();
          final nextBegun = AccountActivationCoordinator.forPreferences(
            deviceScope.sharedPreferences,
          ).changes.first;
          final nextOperation = nextAuth
              .signInForAccount(
                nextKeys.publicKeyHex,
                AuthenticationSource.automatic,
              )
              .whenComplete(() => nextSettled = true);
          nextChecked = expectLater(nextOperation, completes);
          await nextBegun;
          expect(
            nextSettled,
            isFalse,
            reason: 'The pending native lease must drain before new metadata',
          );
          expect(
            deviceScope.sharedPreferences.getString('current_user_pubkey_hex'),
            leavingHex,
          );
        } finally {
          if (!resumed.isCompleted) {
            resumed.complete();
          }
          await failure;
          if (nextChecked != null) {
            await nextChecked;
          }
        }
        expect(nextSettled, isTrue);
        expect(currentAuthService.committedAccountActivationReceipt, isNull);
        expect(nextAuth.committedAccountActivationReceipt!.isCurrent, isTrue);
        expect(nextAuth.currentPublicKeyHex, nextKeys.publicKeyHex);
        expect(keyStorage.primary, same(nextKeys));
        expect(
          deviceScope.sharedPreferences.getString('current_user_pubkey_hex'),
          nextKeys.publicKeyHex,
        );
        expect(
          jsonDecode(
            deviceScope.sharedPreferences.getString(
              AccountActivationCoordinator.storageKey,
            )!,
          )['ownerPubkey'],
          nextKeys.publicKeyHex,
        );
      },
    );

    testWidgets('failed switch rebuilds a fresh outgoing list session', (
      tester,
    ) async {
      final prefs = deviceScope.sharedPreferences;
      final oldKeys = SecureKeyContainer.fromPrivateKeyHex('2' * 64);
      final owner = oldKeys.publicKeyHex;
      final oldStorage = _RestorableSecureKeyStorage(oldKeys)
        ..primary = oldKeys;
      keyStorage.primary = oldKeys;
      final discovery = _MockDiscovery();
      when(() => discovery.discoverRelays(any())).thenAnswer(
        (_) async =>
            RelayDiscoveryResult.failure('No network in account swap tests'),
      );
      final liveAuth = (await tester.runAsync(() async {
        final auth = AuthService(
          userDataCleanupService: UserDataCleanupService(prefs),
          backgroundActivityManager: BackgroundActivityManager(),
          keyStorage: oldStorage,
          relayDiscoveryService: discovery,
          profileCheckIndexerUrl: 'unsupported://profile.invalid',
        );
        currentAuthService.retireAccountSwitchActivation();
        await auth.initializeForAccountSwitch();
        await auth.signInForAccount(owner, AuthenticationSource.automatic);
        await pumpEventQueue();
        return auth;
      }))!;
      addTearDown(liveAuth.dispose);
      final client = _MockNostrClient();
      stubListSigner(client, owner);
      when(() => client.publishEventAwaitOk(any())).thenAnswer(
        (i) async => acceptedOutcome(i.positionalArguments[0] as Event),
      );
      when(() => client.publishEvent(any())).thenAnswer(
        (i) async => PublishSuccess(event: i.positionalArguments[0] as Event),
      );
      when(
        () => client.subscribe(any(), closeOnEose: any(named: 'closeOnEose')),
      ).thenAnswer((_) => const Stream.empty());
      final row = CuratedList(
        id: CuratedListService.defaultListId,
        pubkey: owner,
        name: 'Existing list',
        isPublic: false,
        videoEventIds: const [],
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        nostrEventId:
            'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
      );
      await prefs.setString(
        CuratedListService.listsStorageKey,
        jsonEncode([row.toJson()]),
      );
      final initial = await pumpHost(
        tester,
        accountOverrides: [
          authServiceProvider.overrideWithValue(liveAuth),
          nostrServiceProvider.overrideWithValue(client),
        ],
      );
      final listening = initial.listen(curatedListsStateProvider, (_, _) {});
      await driveSwap(
        initial.read(curatedListsStateProvider.future).then<void>((_) {}),
        reason: 'Outgoing list provider must settle within explicit frames',
      );
      final retired = initial.read(curatedListsStateProvider.notifier).service!;
      await driveSwap(
        swapAccount(
          deviceScope: deviceScope,
          controller: controller,
          currentAuthService: liveAuth,
          account: account,
          signIn: (_, _) async {
            expectSync(retired.isCurrentSession, isFalse);
            await UserDataCleanupService(prefs).clearUserSpecificData(
              userPubkey: owner,
              isIdentityChange: true,
            );
            throw _FakeSignInException();
          },
        ),
        expected: throwsA(isA<_FakeSignInException>()),
      );
      expect(controller.currentContainer, same(initial));
      expect(liveAuth.committedAccountActivationReceipt!.isCurrent, isTrue);
      expect(oldKeys.isDisposed, isFalse);
      expect(liveAuth.currentPublicKeyHex, owner);
      await driveSwap(
        initial.read(curatedListsStateProvider.future).then<void>((_) {}),
        reason: 'Restored list provider must settle within explicit frames',
      );
      final restored = initial
          .read(curatedListsStateProvider.notifier)
          .service!;
      expect(restored, isNot(same(retired)));
      expect(restored.isCurrentSession, isTrue);
      expect(retired.isCurrentSession, isFalse);
      expect(
        await retired.updateList(listId: row.id, name: 'Old callback'),
        isFalse,
      );
      await driveSwap(
        restored.subscribeToList(row.authorScopedId, row).then<void>((saved) {
          expectSync(saved, isTrue);
        }),
        reason: 'Restored list subscription must settle within explicit frames',
      );
      listening.close();
    });
    testWidgets('keeps the target account live when push cleanup fails', (
      tester,
    ) async {
      final pushCoordinator = _MockPushNotificationSessionCoordinator();
      when(
        pushCoordinator.deregisterLastReadyPubkeyAfterAccountSwitch,
      ).thenAnswer((_) async => throw Exception('relay unavailable'));
      overridePushSync(pushCoordinator);
      final initial = await pumpHost(tester);
      initial.read(pushNotificationSyncProvider);
      ProviderContainer? signedInto;

      await driveSwap(
        swapAccount(
          deviceScope: deviceScope,
          controller: controller,
          currentAuthService: currentAuthService,
          account: account,
          signIn: (container, _) async => signedInto = container,
        ),
      );
      await tester.pump();

      expect(controller.currentContainer, same(signedInto));
      expect(_isDisposed(signedInto!), isFalse);
      expect(_isDisposed(initial), isTrue);
      expect(currentAuthService.calls, equals(['archive']));
    });

    testWidgets('bounds push cleanup before disposing the outgoing account', (
      tester,
    ) async {
      final cleanupCompleter = Completer<void>();
      final pushCoordinator = _MockPushNotificationSessionCoordinator();
      when(
        pushCoordinator.deregisterLastReadyPubkeyAfterAccountSwitch,
      ).thenAnswer((_) => cleanupCompleter.future);
      overridePushSync(pushCoordinator);
      final initial = await pumpHost(tester);
      initial.read(pushNotificationSyncProvider);

      await driveSwap(
        swapAccount(
          deviceScope: deviceScope,
          controller: controller,
          currentAuthService: currentAuthService,
          account: account,
          signIn: (_, _) async {},
        ),
      );
      await tester.pump();

      expect(_isDisposed(initial), isFalse);

      await tester.pump(const Duration(seconds: 15));

      expect(_isDisposed(initial), isTrue);
    });

    testWidgets('keeps outgoing push registration when target swap fails', (
      tester,
    ) async {
      final pushCoordinator = _MockPushNotificationSessionCoordinator();
      when(pushCoordinator.deregisterLastReadyPubkeyAfterAccountSwitch)
          .thenAnswer((_) async {});
      overridePushSync(pushCoordinator);
      final initial = await pumpHost(tester);
      initial.read(pushNotificationSyncProvider);
      ProviderContainer? attempted;
      final entered = Completer<void>();
      final resume = Completer<void>();
      final operation = swapAccount(
        deviceScope: deviceScope,
        controller: controller,
        currentAuthService: currentAuthService,
        account: account,
        signIn: (container, _) async {
          attempted = container;
          entered.complete();
          await resume.future;
        },
      );
      final assertion = expectLater(
        operation,
        throwsA(isA<AccountActivationRetiredException>()),
      );
      try {
        for (var frame = 0; !entered.isCompleted && frame < 100; frame += 1) {
          await tester.runAsync(pumpEventQueue);
          await tester.pump();
        }
        expect(entered.isCompleted, isTrue);
      } finally {
        // Retire the real host before releasing sign-in, even if its entry
        // assertion fails, and settle the watched operation before teardown.
        await tester.pumpWidget(const SizedBox());
        if (!resume.isCompleted) {
          resume.complete();
        }
        await driveSwap(
          assertion,
          reason: 'Retired host switch must settle within explicit frames',
        );
      }
      expect(attempted, isNotNull);
      expect(_isDisposed(attempted!), isTrue);
      // A retired host must never restore old signer slots over a newer host.
      expect(currentAuthService.calls, equals(['archive']));
      verifyNever(pushCoordinator.deregisterLastReadyPubkeyAfterAccountSwitch);
    });

    testWidgets('keeps the target account live when legacy claiming fails', (
      tester,
    ) async {
      final targetAuthService = makeIncomingAuth(failClaim: true);
      incomingAuthOverride = targetAuthService;
      deviceScope = DeviceScope(
        database: database,
        sharedPreferences: deviceScope.sharedPreferences,
        feedModePersistence: deviceScope.feedModePersistence,
        switchController: controller,
        appVersion: 'test',
        crashReporting: CrashReportingService(),
        startupPerformance: StartupPerformanceService(
          crashReporting: CrashReportingService(),
        ),
        documentsPath: '/documents',
        logMessageBatcher: LogMessageBatcher(),
        accountOverrides: [
          secureKeyStorageProvider.overrideWithValue(keyStorage),
          authServiceProvider.overrideWithValue(targetAuthService),
          pushNotificationSyncProvider.overrideWithValue(null),
        ],
      );
      final initial = await pumpHost(tester);
      ProviderContainer? signedInto;

      await driveSwap(
        swapAccount(
          deviceScope: deviceScope,
          controller: controller,
          currentAuthService: currentAuthService,
          account: account,
          signIn: (container, _) async => signedInto = container,
        ),
      );
      await tester.pump();

      expect(controller.currentContainer, same(signedInto));
      expect(_isDisposed(signedInto!), isFalse);
      expect(_isDisposed(initial), isTrue);
      expect(currentAuthService.calls, equals(['archive']));
    });
  });

  group('interactions', () {
    testWidgets('keeps outgoing push registration when target sign-in fails', (
      tester,
    ) async {
      final pushCoordinator = _MockPushNotificationSessionCoordinator();
      when(
        pushCoordinator.deregisterLastReadyPubkeyAfterAccountSwitch,
      ).thenAnswer((_) async {});
      overridePushSync(pushCoordinator);
      final initial = await pumpHost(tester);
      initial.read(pushNotificationSyncProvider);
      ProviderContainer? attempted;
      keyStorage.primary = leavingKeys;

      await driveSwap(
        swapAccount(
          deviceScope: deviceScope,
          controller: controller,
          currentAuthService: currentAuthService,
          account: account,
          signIn: (container, acct) async {
            attempted = container;
            throw Exception('signer unreachable');
          },
        ),
        expected: throwsException,
      );
      await tester.pump();

      // The half-built container is disposed; the current account is untouched.
      expect(attempted, isNotNull);
      expect(_isDisposed(attempted!), isTrue);
      expect(_isDisposed(initial), isFalse);
      expect(keyStorage.restoredPrimary, same(keyStorage.primary));
      // A sign-in that got far enough to fail already restored the target
      // account's signer keys and auth source over the shared slots. Disposing
      // its container does not undo that — the leaving account's own keys have
      // to go back, or it reads the wrong signer at the next launch.
      expect(currentAuthService.calls, equals(['archive', 'restore']));
      verifyNever(pushCoordinator.deregisterLastReadyPubkeyAfterAccountSwitch);
    });

    testWidgets('archives the leaving account before signing the new one in', (
      tester,
    ) async {
      await pumpHost(tester);

      await driveSwap(
        swapAccount(
          deviceScope: deviceScope,
          controller: controller,
          currentAuthService: currentAuthService,
          account: account,
          signIn: (_, _) async => currentAuthService.calls.add('signIn'),
        ),
      );
      await tester.pump();

      // Signing the incoming account in overwrites the shared signer slots, so
      // the leaving account's credentials must already be in its own archive.
      expect(currentAuthService.calls, equals(['archive', 'signIn']));
    });
  });

  group('DM lifecycle', () {
    testWidgets('quiesces outgoing DM persistence before target sign-in', (
      tester,
    ) async {
      final dmRepository = _MockDmRepository();
      final events = <String>[];
      when(dmRepository.stopListening).thenAnswer((_) async {
        events.add('stop outgoing DMs');
      });
      when(dmRepository.startListening).thenAnswer((_) async {});
      final initial = await pumpHost(
        tester,
        accountOverrides: [
          dmRepositoryProvider.overrideWithValue(dmRepository),
        ],
      );
      initial.read(dmRepositoryProvider);

      await driveSwap(
        swapAccount(
          deviceScope: deviceScope,
          controller: controller,
          currentAuthService: currentAuthService,
          account: account,
          signIn: (_, _) async => events.add('sign in target'),
        ),
      );
      await tester.pump();

      expect(events, ['stop outgoing DMs', 'sign in target']);
      verify(dmRepository.stopListening).called(1);
      verifyNever(dmRepository.startListening);
    });

    testWidgets('resumes outgoing DMs when target sign-in fails', (
      tester,
    ) async {
      final dmRepository = _MockDmRepository();
      final events = <String>[];
      when(dmRepository.stopListening).thenAnswer((_) async {
        events.add('stop outgoing DMs');
      });
      when(dmRepository.startListening).thenAnswer((_) async {
        events.add('resume outgoing DMs');
      });
      final initial = await pumpHost(
        tester,
        accountOverrides: [
          dmRepositoryProvider.overrideWithValue(dmRepository),
        ],
      );
      initial.read(dmRepositoryProvider);

      await driveSwap(
        swapAccount(
          deviceScope: deviceScope,
          controller: controller,
          currentAuthService: currentAuthService,
          account: account,
          signIn: (_, _) async {
            events.add('sign in target');
            throw Exception('signer unavailable');
          },
        ),
        expected: throwsException,
      );
      await tester.pump();

      expect(events, [
        'stop outgoing DMs',
        'sign in target',
        'resume outgoing DMs',
      ]);
      expect(_isDisposed(initial), isFalse);
    });
  });

  group('interactions', () {
    testWidgets('aborts before building anything when the archive fails', (
      tester,
    ) async {
      final initial = await pumpHost(tester);
      currentAuthService.archiveError = Exception('keychain unavailable');
      var signInAttempted = false;

      await driveSwap(
        swapAccount(
          deviceScope: deviceScope,
          controller: controller,
          currentAuthService: currentAuthService,
          account: account,
          signIn: (_, _) async => signInAttempted = true,
        ),
        expected: throwsException,
      );
      await tester.pump();

      // Carrying on past a failed archive would let the incoming sign-in wipe
      // the shared slots the archive was meant to copy, destroying the leaving
      // account's session for a log line.
      expect(signInAttempted, isFalse);
      expect(_isDisposed(initial), isFalse);
    });

    testWidgets('surfaces the sign-in failure even when the rollback throws', (
      tester,
    ) async {
      await pumpHost(tester);
      keyStorage.primary = leavingKeys;
      keyStorage.restoreError = Exception('primary restore failed');

      // The caller dispatches on this type to offer a fresh sign-in, so a
      // rollback failure must not replace it with its own.
      await driveSwap(
        swapAccount(
          deviceScope: deviceScope,
          controller: controller,
          currentAuthService: currentAuthService,
          account: account,
          signIn: (_, _) async => throw _FakeSignInException(),
        ),
        expected: throwsA(isA<_FakeSignInException>()),
      );
      await tester.pump();

      // The signer restore is ordered ahead of the throwing primary restore, so
      // it still ran.
      expect(currentAuthService.calls, equals(['archive', 'restore']));
    });
  });

  // The leaving account's DM repository keeps draining relay history into the
  // DeviceScope-shared database, and the identity-change cleanup that wipes
  // that database runs from the INCOMING container — where
  // dmListeningStopProvider finds no repository and returns early. No writer
  // for an account may be live while that account's data is wiped, so the swap
  // has to quiesce the leaving container before signing the target in.
  // dm_repository's own suite covers what stopListening then stops. See #7318.
  group('outgoing DM ingest (#7318)', () {
    late _MockDmRepository dmRepository;
    late List<String> events;

    setUp(() {
      dmRepository = _MockDmRepository();
      events = <String>[];
      when(dmRepository.stopListening).thenAnswer((_) async {
        events.add('stop dm ingest');
      });
      when(dmRepository.startListening).thenAnswer((_) async {
        events.add('resume dm ingest');
      });
    });

    Future<ProviderContainer> pumpLeavingHost(WidgetTester tester) async {
      final leaving = await pumpHost(
        tester,
        accountOverrides: [
          dmRepositoryProvider.overrideWithValue(dmRepository),
        ],
      );
      // dmListeningStopProvider gates on ref.exists, so the repository has to
      // have been built in this container — as it is in production, where the
      // inbox mounts it.
      leaving.read(dmRepositoryProvider);
      return leaving;
    }

    testWidgets(
      'stops the leaving account ingest before signing the target in',
      (
        tester,
      ) async {
        await pumpLeavingHost(tester);

        await driveSwap(
          swapAccount(
            deviceScope: deviceScope,
            controller: controller,
            currentAuthService: currentAuthService,
            account: account,
            // Stands in for AuthService._setupUserSession, whose
            // clearUserSpecificData wipes the shared DM tables.
            signIn: (_, _) async => events.add('sign in target'),
          ),
        );
        await tester.pump();

        expect(events, equals(['stop dm ingest', 'sign in target']));
      },
    );

    testWidgets('gives the ingest back when the target sign-in fails', (
      tester,
    ) async {
      await pumpLeavingHost(tester);

      await driveSwap(
        swapAccount(
          deviceScope: deviceScope,
          controller: controller,
          currentAuthService: currentAuthService,
          account: account,
          signIn: (_, _) async => throw _FakeSignInException(),
        ),
        expected: throwsA(isA<_FakeSignInException>()),
      );
      await tester.pump();

      // The leaving container stays live on a rollback, so stopping its ingest
      // must not cost the still-signed-in user their DMs.
      expect(events, equals(['stop dm ingest', 'resume dm ingest']));
    });

    testWidgets('gives the ingest back even when the key restore throws', (
      tester,
    ) async {
      await pumpLeavingHost(tester);
      keyStorage.primary = leavingKeys;
      keyStorage.restoreError = Exception('primary restore failed');

      await driveSwap(
        swapAccount(
          deviceScope: deviceScope,
          controller: controller,
          currentAuthService: currentAuthService,
          account: account,
          signIn: (_, _) async => throw _FakeSignInException(),
        ),
        expected: throwsA(isA<_FakeSignInException>()),
      );
      await tester.pump();

      // A rollback that cannot restore the keys still owes the user the DMs it
      // took away, so the resume cannot sit behind a restore that throws.
      expect(events, equals(['stop dm ingest', 'resume dm ingest']));
    });
  });
}

class _RefusingCleanupPreferences extends Fake implements SharedPreferences {
  _RefusingCleanupPreferences(this.backing);
  final SharedPreferences backing;
  final refusedKeys = <String>[];
  @override
  Object? get(String key) => backing.get(key);
  @override
  Set<String> getKeys() => backing.getKeys();
  @override
  String? getString(String key) => backing.getString(key);
  @override
  bool containsKey(String key) => backing.containsKey(key);
  @override
  Future<bool> setString(String key, String value) =>
      backing.setString(key, value);
  @override
  Future<void> reload() => backing.reload();
  @override
  Future<bool> remove(String key) async {
    refusedKeys.add(key);
    return false;
  }
}

class _RestorableSecureKeyStorage extends _FakeSecureKeyStorage {
  _RestorableSecureKeyStorage(this._restoredTarget);
  final SecureKeyContainer _restoredTarget;
  @override
  SecureKeyContainer get target => _restoredTarget;
  @override
  Future<void> initialize() async {}
  @override
  Future<SecureKeyContainer?> getIdentityKeyContainer(String npub) async =>
      target;
  @override
  Future<bool> switchToIdentity(String npub) async {
    primary = target;
    return true;
  }

  @override
  void dispose() {}
}

class _FakeSignInException implements Exception {}

class _FakeAuthService extends AuthService {
  _FakeAuthService({
    required super.userDataCleanupService,
    required super.backgroundActivityManager,
    required super.keyStorage,
    required super.relayDiscoveryService,
    required super.profileCheckIndexerUrl,
  });

  final calls = <String>[];

  /// Set to make the pre-swap archive fail, as a keychain write would.
  Object? archiveError;

  @override
  Future<void> archiveCurrentSignerInfo() async {
    calls.add('archive');
    final error = archiveError;
    if (error != null) {
      throw error;
    }
    await super.archiveCurrentSignerInfo();
  }

  @override
  Future<void> restoreSignerInfoForCurrentAccount({
    void Function()? ensureCurrent,
  }) async {
    calls.add('restore');
    await super.restoreSignerInfoForCurrentAccount(
      ensureCurrent: ensureCurrent,
    );
  }
}

class _FakeSecureKeyStorage extends SecureKeyStorage {
  SecureKeyContainer? primary;
  SecureKeyContainer? restoredPrimary;
  final _target = SecureKeyContainer.fromPrivateKeyHex('1' * 64);
  SecureKeyContainer? restorationTarget;
  SecureKeyContainer get target => restorationTarget ?? _target;
  Completer<void>? restoreEntered;
  Completer<void>? resumeRestore;

  @override
  Future<void> initialize() async {}
  @override
  Future<SecureKeyContainer?> getIdentityKeyContainer(String npub) async =>
      npub == target.npub ? target : null;
  @override
  Future<bool> switchToIdentity(String npub) async {
    primary = target;
    return true;
  }

  @override
  Future<void> storeIdentityKeyContainer(
    String npub,
    SecureKeyContainer key,
  ) async {}
  @override
  void dispose() {}

  /// Set to make the rollback's primary restore fail. The real one can: it
  /// hands the snapshot to `storeKey`, which reaches into the private key.
  Object? restoreError;

  @override
  Future<SecureKeyContainer?> getKeyContainer() async {
    return primary;
  }

  @override
  Future<void> restorePrimaryKeyContainer(
    SecureKeyContainer? keyContainer,
  ) async {
    final error = restoreError;
    if (error != null) {
      throw error;
    }
    restoredPrimary = keyContainer;
    primary = keyContainer;
    final entered = restoreEntered;
    final resume = resumeRestore;
    resumeRestore = null;
    entered?.complete();
    if (resume != null) {
      await resume.future;
    }
  }
}

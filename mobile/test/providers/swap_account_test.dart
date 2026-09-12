// ABOUTME: Tests swapAccount orchestration — build, sign in, swap; roll back
// ABOUTME: (dispose the new container, leave the old) when sign-in fails.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/container_swap_host.dart';
import 'package:openvine/providers/device_scope.dart';
import 'package:openvine/providers/notifications_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/swap_account.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/push_notification_session_coordinator.dart';
import 'package:openvine/services/startup_performance_service.dart';
import 'package:openvine/utils/log_message_batcher.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
// Override lives in riverpod's misc barrel; flutter_riverpod does not
// re-export the type name even though it accepts List<Override>.
import 'package:riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

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

  const leavingHex =
      '2222222222222222222222222222222222222222222222222222222222222222';
  const targetHex =
      '1111111111111111111111111111111111111111111111111111111111111111';
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

  setUp(() async {
    database = AppDatabase.test(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    controller = AccountSwitchController();
    keyStorage = _FakeSecureKeyStorage();
    currentAuthService = _FakeAuthService();
    deviceScope = DeviceScope(
      database: database,
      sharedPreferences: prefs,
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

  tearDown(() => database.close());

  void overridePushSync(PushNotificationSessionCoordinator? coordinator) {
    deviceScope = DeviceScope(
      database: database,
      sharedPreferences: deviceScope.sharedPreferences,
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
    final initial = buildAccountContainer(
      deviceScope,
      accountOverrides: accountOverrides,
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
    final auth = _MockAuthService();
    when(() => auth.currentPublicKeyHex).thenReturn(leavingHex);
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
    await swapAccount(
      deviceScope: deviceScope,
      controller: controller,
      currentAuthService: currentAuthService,
      account: account,
      signIn: (container, _) async {
        seeded = container.read(routerInitialLocationProvider);
      },
    );
    await tester.pump();
    return seeded;
  }

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
        expect(controller.currentContainer, same(signedInto));
        events.add('deregister outgoing');
        await cleanupCompleter.future;
      });
      overridePushSync(pushCoordinator);
      final initial = await pumpHost(tester);
      initial.read(pushNotificationSyncProvider);

      await swapAccount(
        deviceScope: deviceScope,
        controller: controller,
        currentAuthService: currentAuthService,
        account: account,
        signIn: (container, acct) async {
          signedInto = container;
          events.add('sign in target');
          expect(acct, equals(account));
        },
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

      await swapAccount(
        deviceScope: deviceScope,
        controller: controller,
        currentAuthService: currentAuthService,
        account: account,
        signIn: (container, _) async => signedInto = container,
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

      await swapAccount(
        deviceScope: deviceScope,
        controller: controller,
        currentAuthService: currentAuthService,
        account: account,
        signIn: (_, _) async {},
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
      when(
        pushCoordinator.deregisterLastReadyPubkeyAfterAccountSwitch,
      ).thenAnswer((_) async {});
      overridePushSync(pushCoordinator);
      final initial = await pumpHost(tester);
      initial.read(pushNotificationSyncProvider);
      ProviderContainer? attempted;

      await expectLater(
        swapAccount(
          deviceScope: deviceScope,
          controller: controller,
          currentAuthService: currentAuthService,
          account: account,
          signIn: (container, _) async {
            attempted = container;
            await tester.pumpWidget(const SizedBox());
          },
        ),
        throwsStateError,
      );

      expect(attempted, isNotNull);
      expect(_isDisposed(attempted!), isTrue);
      expect(currentAuthService.calls, equals(['archive', 'restore']));
      verifyNever(pushCoordinator.deregisterLastReadyPubkeyAfterAccountSwitch);
    });

    testWidgets('keeps the target account live when legacy claiming fails', (
      tester,
    ) async {
      final targetAuthService = _MockAuthService();
      when(
        targetAuthService.claimLegacyRowsForCurrentUser,
      ).thenThrow(Exception('database unavailable'));
      deviceScope = DeviceScope(
        database: database,
        sharedPreferences: deviceScope.sharedPreferences,
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

      await swapAccount(
        deviceScope: deviceScope,
        controller: controller,
        currentAuthService: currentAuthService,
        account: account,
        signIn: (container, _) async => signedInto = container,
      );
      await tester.pump();

      expect(controller.currentContainer, same(signedInto));
      expect(_isDisposed(signedInto!), isFalse);
      expect(_isDisposed(initial), isTrue);
      expect(currentAuthService.calls, equals(['archive']));
    });
  });

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
    keyStorage.primary = _FakeSecureKeyContainer(
      npub: 'npub_previous',
      publicKeyHex:
          '2222222222222222222222222222222222222222222222222222222222222222',
    );

    await expectLater(
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
      throwsException,
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

    await swapAccount(
      deviceScope: deviceScope,
      controller: controller,
      currentAuthService: currentAuthService,
      account: account,
      signIn: (_, _) async => currentAuthService.calls.add('signIn'),
    );
    await tester.pump();

    // Signing the incoming account in overwrites the shared signer slots, so
    // the leaving account's credentials must already be in its own archive.
    expect(currentAuthService.calls, equals(['archive', 'signIn']));
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

      await swapAccount(
        deviceScope: deviceScope,
        controller: controller,
        currentAuthService: currentAuthService,
        account: account,
        signIn: (_, _) async => events.add('sign in target'),
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

      await expectLater(
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
        throwsException,
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

  testWidgets('aborts before building anything when the archive fails', (
    tester,
  ) async {
    final initial = await pumpHost(tester);
    currentAuthService.archiveError = Exception('keychain unavailable');
    var signInAttempted = false;

    await expectLater(
      swapAccount(
        deviceScope: deviceScope,
        controller: controller,
        currentAuthService: currentAuthService,
        account: account,
        signIn: (_, _) async => signInAttempted = true,
      ),
      throwsException,
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
    keyStorage.primary = _FakeSecureKeyContainer(
      npub: 'npub_previous',
      publicKeyHex:
          '2222222222222222222222222222222222222222222222222222222222222222',
    );
    keyStorage.restoreError = Exception('primary restore failed');

    // The caller dispatches on this type to offer a fresh sign-in, so a
    // rollback failure must not replace it with its own.
    await expectLater(
      swapAccount(
        deviceScope: deviceScope,
        controller: controller,
        currentAuthService: currentAuthService,
        account: account,
        signIn: (_, _) async => throw _FakeSignInException(),
      ),
      throwsA(isA<_FakeSignInException>()),
    );
    await tester.pump();

    // The signer restore is ordered ahead of the throwing primary restore, so
    // it still ran.
    expect(currentAuthService.calls, equals(['archive', 'restore']));
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

        await swapAccount(
          deviceScope: deviceScope,
          controller: controller,
          currentAuthService: currentAuthService,
          account: account,
          // Stands in for AuthService._setupUserSession, whose
          // clearUserSpecificData wipes the shared DM tables.
          signIn: (_, _) async => events.add('sign in target'),
        );
        await tester.pump();

        expect(events, equals(['stop dm ingest', 'sign in target']));
      },
    );

    testWidgets('gives the ingest back when the target sign-in fails', (
      tester,
    ) async {
      await pumpLeavingHost(tester);

      await expectLater(
        swapAccount(
          deviceScope: deviceScope,
          controller: controller,
          currentAuthService: currentAuthService,
          account: account,
          signIn: (_, _) async => throw _FakeSignInException(),
        ),
        throwsA(isA<_FakeSignInException>()),
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
      keyStorage.primary = _FakeSecureKeyContainer(
        npub: 'npub_previous',
        publicKeyHex: leavingHex,
      );
      keyStorage.restoreError = Exception('primary restore failed');

      await expectLater(
        swapAccount(
          deviceScope: deviceScope,
          controller: controller,
          currentAuthService: currentAuthService,
          account: account,
          signIn: (_, _) async => throw _FakeSignInException(),
        ),
        throwsA(isA<_FakeSignInException>()),
      );
      await tester.pump();

      // A rollback that cannot restore the keys still owes the user the DMs it
      // took away, so the resume cannot sit behind a restore that throws.
      expect(events, equals(['stop dm ingest', 'resume dm ingest']));
    });
  });
}

class _FakeSignInException implements Exception {}

class _FakeAuthService implements AuthService {
  final calls = <String>[];

  /// Set to make the pre-swap archive fail, as a keychain write would.
  Object? archiveError;

  @override
  Future<void> archiveCurrentSignerInfo() async {
    calls.add('archive');
    final error = archiveError;
    if (error != null) throw error;
  }

  @override
  Future<void> restoreSignerInfoForCurrentAccount() async =>
      calls.add('restore');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSecureKeyStorage extends SecureKeyStorage {
  SecureKeyContainer? primary;
  SecureKeyContainer? restoredPrimary;

  /// Set to make the rollback's primary restore fail. The real one can: it
  /// hands the snapshot to `storeKey`, which reaches into the private key.
  Object? restoreError;

  @override
  Future<SecureKeyContainer?> getKeyContainer({String? biometricPrompt}) async {
    return primary;
  }

  @override
  Future<void> restorePrimaryKeyContainer(
    SecureKeyContainer? keyContainer, {
    String? biometricPrompt,
  }) async {
    final error = restoreError;
    if (error != null) throw error;
    restoredPrimary = keyContainer;
    primary = keyContainer;
  }
}

class _FakeSecureKeyContainer implements SecureKeyContainer {
  _FakeSecureKeyContainer({required this.npub, required this.publicKeyHex});

  @override
  final String npub;

  @override
  final String publicKeyHex;

  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

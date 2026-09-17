// ABOUTME: On-device proof that two local accounts can each hold their own copy
// ABOUTME: of one shared NIP-17 group rumor, and that the ordinary account
// ABOUTME: switch still wipes the leaving account's DM rows.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openvine/models/authentication_source.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/container_swap_host.dart';
import 'package:openvine/providers/device_scope.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/providers/swap_account.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/startup_performance_service.dart';
import 'package:openvine/utils/log_message_batcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_setup.dart';

/// Sign-in fires relay discovery this offline test cannot avoid; swallow only
/// that noise so real failures still surface.
bool _isNetworkNoise(String m) =>
    m.contains('ClientException') ||
    m.contains('SocketException') ||
    m.contains('WebSocket') ||
    m.contains('CERTIFICATE_VERIFY_FAILED') ||
    m.contains('Failed host lookup') ||
    m.contains('Connection') ||
    m.contains('Relay rejected');

Future<void> _guarded(Future<void> Function() body) {
  final completer = Completer<void>();
  unawaited(
    runZonedGuarded(
      () async {
        try {
          await body();
          if (!completer.isCompleted) completer.complete();
        } catch (e, s) {
          if (!completer.isCompleted) completer.completeError(e, s);
        }
      },
      (error, stack) {
        if (_isNetworkNoise(error.toString())) return;
        if (!completer.isCompleted) completer.completeError(error, stack);
      },
    ),
  );
  return completer.future;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Captured from a real fan-out against the local funnelcake relay: peer `P`
  // sealed ONE kind-14 rumor p-tagged for both recipients and published it as
  // two kind-1059 wraps with distinct ephemeral keys. The shared rumor id and
  // the distinct wrap ids are the whole precondition for #6645.
  const rumorId =
      '55cea695f7c939b145cec012e3528e7fd5724059ce85322b383e3c0862d5f8ae';
  const wrapForA =
      '969fa2e8506ba3ea827584f230d8e321560539f1da73c87f4915ece2d954e6e1';
  const wrapForB =
      'cbb61b729393d2e3977754532b5085aa152eefd85432e7510ba727219dd31bc7';
  const peerP =
      'd74e52042a7ae318370833940105ab912686f7ea605a83a71159899344cfd4fb';

  group('owner-scoped DM uniqueness', () {
    testWidgets(
      'an in-place account swap still wipes the leaving account DM rows',
      (tester) async {
        final originalOnError = suppressSetStateErrors();
        addTearDown(() => restoreErrorHandler(originalOnError));

        final database = AppDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        final controller = AccountSwitchController();
        final deviceScope = DeviceScope(
          database: database,
          sharedPreferences: prefs,
          switchController: controller,
          startupPerformance: StartupPerformanceService(
            crashReporting: CrashReportingService(),
          ),
          appVersion: 'test',
          crashReporting: CrashReportingService(),
          documentsPath: '/documents',
          logMessageBatcher: LogMessageBatcher(),
        );

        String? pubkeyA;
        String? pubkeyB;
        await _guarded(() async {
          final setup = buildAccountContainer(deviceScope);
          final setupAuth = setup.read(authServiceProvider);
          await setupAuth.initialize();
          await setupAuth.createNewIdentity();
          pubkeyA = setupAuth.currentPublicKeyHex;
          await setupAuth.signOut();
          await setupAuth.createNewIdentity();
          pubkeyB = setupAuth.currentPublicKeyHex;
          setup.dispose();
        });
        expect(pubkeyA, isNotNull);
        expect(pubkeyB, isNotNull);
        expect(pubkeyB, isNot(equals(pubkeyA)));

        final aContainer = buildAccountContainer(deviceScope);
        await _guarded(
          () => aContainer
              .read(authServiceProvider)
              .signInForAccount(pubkeyA!, AuthenticationSource.automatic),
        );
        await tester.pumpWidget(
          ContainerSwapHost(
            initialContainer: aContainer,
            controller: controller,
            child: const SizedBox(),
          ),
        );

        await database.directMessagesDao.insertMessage(
          id: rumorId,
          conversationId: 'conv_for_a',
          senderPubkey: peerP,
          content: 'shared group rumor',
          createdAt: 1788519794,
          giftWrapId: wrapForA,
          ownerPubkey: pubkeyA,
        );

        await _guarded(
          () => swapAccount(
            deviceScope: deviceScope,
            controller: controller,
            currentAuthService: aContainer.read(authServiceProvider),
            account: KnownAccount(
              pubkeyHex: pubkeyB!,
              authSource: AuthenticationSource.automatic,
              addedAt: DateTime(2026),
              lastUsedAt: DateTime(2026),
            ),
            signIn: (container, account) async {
              await container
                  .read(environmentServiceProvider)
                  .initialize(sharedPreferences: prefs);
              await container
                  .read(authServiceProvider)
                  .initializeForAccountSwitch();
              await container
                  .read(authServiceProvider)
                  .signInForAccount(
                    account.pubkeyHex,
                    account.authSource,
                    claimLegacyRows: false,
                  );
            },
          ),
        );
        await tester.pump();

        final afterSwap = await database.select(database.directMessages).get();
        expect(
          afterSwap,
          isEmpty,
          reason:
              'the identity-change cleanup must still delete the leaving '
              "account's DM rows — the owner-scoped key does not relax that",
        );

        drainAsyncErrors(tester);
      },
    );

    testWidgets(
      'two coexisting accounts each keep their own copy of one group rumor',
      (tester) async {
        final originalOnError = suppressSetStateErrors();
        addTearDown(() => restoreErrorHandler(originalOnError));

        final database = AppDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        final controller = AccountSwitchController();
        final deviceScope = DeviceScope(
          database: database,
          sharedPreferences: prefs,
          switchController: controller,
          startupPerformance: StartupPerformanceService(
            crashReporting: CrashReportingService(),
          ),
          appVersion: 'test',
          crashReporting: CrashReportingService(),
          documentsPath: '/documents',
          logMessageBatcher: LogMessageBatcher(),
        );

        const ownerA =
            'aaaa111111111111111111111111111111111111111111111111111111111111';
        const ownerB =
            'bbbb222222222222222222222222222222222222222222222222222222222222';

        final dmDao = database.directMessagesDao;
        await dmDao.insertMessage(
          id: rumorId,
          conversationId: 'conv_for_a',
          senderPubkey: peerP,
          content: 'shared group rumor',
          createdAt: 1788519794,
          giftWrapId: wrapForA,
          ownerPubkey: ownerA,
        );

        // The production call `_setupUserSession` makes when the stored
        // `current_user_pubkey_hex` is absent: with no account to scope to it
        // deletes only unattributed rows and preserves every known account's
        // (#8119). That is the state in which two owners coexist.
        final container = buildAccountContainer(deviceScope);
        addTearDown(container.dispose);
        await _guarded(
          () => container
              .read(userDataCleanupServiceProvider)
              .clearUserSpecificData(
                reason: 'identity_change',
                isIdentityChange: true,
              ),
        );

        final surviving = await database.select(database.directMessages).get();
        expect(
          surviving.map((row) => row.ownerPubkey),
          equals([ownerA]),
          reason: "the unattributed-only cleanup must keep account A's row",
        );

        // Account B now ingests ITS OWN wrap of the SAME rumor. NIP-17 seals
        // one rumor per group message, so the id is identical; NIP-59 gives
        // each recipient a distinct wrap.
        final insertedForB = await dmDao.insertMessage(
          id: rumorId,
          conversationId: 'conv_for_b',
          senderPubkey: peerP,
          content: 'shared group rumor',
          createdAt: 1788519794,
          giftWrapId: wrapForB,
          ownerPubkey: ownerB,
        );
        expect(
          insertedForB,
          isTrue,
          reason: 'account B must persist its own copy (#6645)',
        );

        expect(
          await dmDao.getMessagesForConversation(
            'conv_for_b',
            ownerPubkey: ownerB,
          ),
          hasLength(1),
          reason: 'and must be able to read it back',
        );
        expect(
          await dmDao.getMessagesForConversation(
            'conv_for_a',
            ownerPubkey: ownerA,
          ),
          hasLength(1),
          reason: "without disturbing account A's copy",
        );

        drainAsyncErrors(tester);
      },
    );
  });
}

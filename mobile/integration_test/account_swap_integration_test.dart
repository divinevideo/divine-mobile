// ABOUTME: On-device proof that the in-place container swap actually switches
// ABOUTME: between two real local-key accounts using the real signInForAccount.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openvine/models/authentication_source.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/container_swap_host.dart';
import 'package:openvine/providers/device_scope.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/swap_account.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/feed_mode_persistence.dart';
import 'package:openvine/services/startup_performance_service.dart';
import 'package:openvine/utils/log_message_batcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_setup.dart';

/// Sign-in triggers fire-and-forget relay discovery (HTTP + WebSocket to real
/// indexers), which throws network errors this offline test can't avoid.
bool _isNetworkNoise(String m) =>
    m.contains('ClientException') ||
    m.contains('SocketException') ||
    m.contains('WebSocket') ||
    m.contains('CERTIFICATE_VERIFY_FAILED') ||
    m.contains('Failed host lookup') ||
    m.contains('Connection') ||
    m.contains('Relay rejected');

/// Runs [body] in a child zone that swallows [_isNetworkNoise] errors,
/// surfacing only real failures.
Future<void> _guarded(Future<void> Function() body) {
  final completer = Completer<void>();
  // The zone's callback can outlive this call. `_guarded` exposes the
  // completer below as the operation's completion signal, including errors
  // reported by the zone handler.
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

  group('in-place account swap', () {
    testWidgets('in-place swap switches between two real local accounts', (
      tester,
    ) async {
      await runWithAppErrorHandlers(() async {
        // Real device dependencies: native (in-memory) DB, real SharedPreferences,
        // and — because integration_test does not mock platform channels — the
        // real iOS Keychain backs SecureKeyStorage.
        final database = AppDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final controller = AccountSwitchController();
        final deviceScope = DeviceScope(
          database: database,
          sharedPreferences: prefs,
          feedModePersistence: FeedModePersistenceRegistry(
            sharedPreferences: prefs,
          ),
          switchController: controller,
          startupPerformance: StartupPerformanceService(
            crashReporting: CrashReportingService(),
          ),
          appVersion: 'test',
          crashReporting: CrashReportingService(),
          documentsPath: '/documents',
          logMessageBatcher: LogMessageBatcher(),
        );

        // Create two real local-key identities in a setup container. Guarded
        // because createNewIdentity kicks off fire-and-forget relay discovery.
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
        expect(pubkeyA, isNotNull, reason: 'Account A should be created');
        expect(pubkeyB, isNotNull, reason: 'Account B should be created');
        expect(
          pubkeyB,
          isNot(equals(pubkeyA)),
          reason: 'Two distinct accounts',
        );

        // Mount the host on a container signed in as B (the "current" account).
        final bContainer = buildAccountContainer(deviceScope);
        await _guarded(
          () => bContainer
              .read(authServiceProvider)
              .signInForAccount(pubkeyB!, AuthenticationSource.automatic),
        );
        await tester.pumpWidget(
          ContainerSwapHost(
            initialContainer: bContainer,
            controller: controller,
            child: const SizedBox(),
          ),
        );

        // Perform the REAL in-place swap to account A. Capture the swapped-in
        // container so the result can be asserted; the sign-in itself is the real
        // production signInForAccount.
        ProviderContainer? swapped;
        await _guarded(
          () => swapAccount(
            deviceScope: deviceScope,
            controller: controller,
            currentAuthService: bContainer.read(authServiceProvider),
            account: KnownAccount(
              pubkeyHex: pubkeyA!,
              authSource: AuthenticationSource.automatic,
              addedAt: DateTime(2026),
              lastUsedAt: DateTime(2026),
            ),
            signIn: (container, account) async {
              swapped = container;
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

        // The swapped-in container is authenticated as A, in place.
        final swappedAuth = swapped!.read(authServiceProvider);
        expect(
          swappedAuth.currentPublicKeyHex,
          equals(pubkeyA),
          reason: 'After the swap the live account is A',
        );
        expect(swappedAuth.isAuthenticated, isTrue);

        drainAsyncErrors(tester);
      });
    });
  });
}

// ABOUTME: On-device proof that the in-place container swap actually switches
// ABOUTME: between two real local-key accounts using the real signInForAccount.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openvine/models/authentication_source.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/container_swap_host.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/swap_account.dart';
import 'package:openvine/services/auth/account_activation_coordinator.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:openvine/services/curated_lists/curated_list_account_authority.dart';

import 'helpers/native_account_test_scope.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('in-place account swap', () {
    testWidgets('in-place swap switches between two real local accounts', (
      tester,
    ) async {
      final scope = await NativeAccountTestScope.create();
      addTearDown(() => scope.close(tester));

      // Real local keys use native Keychain. The relay responds in-process;
      // preferences are simulated and SQLite is native but in-memory.
      final setup = scope.buildContainer();
      final setupAuth = setup.read(authServiceProvider);
      await setupAuth.initialize();
      await setupAuth.createNewIdentity();
      final pubkeyA = setupAuth.currentPublicKeyHex;

      // A live content filter is the production path that recreates an empty
      // migration marker during sign-out. Exercise it with native key storage.
      final contentFilter = setup.read(contentFilterServiceProvider);
      await contentFilter.initialized;
      await contentFilter.setPreference(
        ContentLabel.spoiler,
        ContentFilterPreference.hide,
      );

      await setupAuth.signOut();
      expect(setupAuth.currentPublicKeyHex, isNull);
      expect(
        contentFilter.getPreference(ContentLabel.spoiler),
        ContentFilterPreference.warn,
      );
      expect(
        scope.prefs.containsKey(ContentFilterService.filterPrefsStorageKey),
        isFalse,
      );
      expect(
        scope.prefs.get(ContentFilterService.filterMigratedStorageKey),
        isTrue,
      );
      final signedOutAuthority = CuratedListAccountAuthority(
        authService: setupAuth,
        preferences: scope.prefs,
      );
      final terminalRecord = scope.prefs.get(
        AccountActivationCoordinator.storageKey,
      );
      expect(signedOutAuthority.isCurrent, isTrue);
      await setupAuth.signOut();
      expect(signedOutAuthority.isCurrent, isTrue);
      expect(
        AccountActivationCoordinator.forPreferences(scope.prefs)
            .hasUnresolvedActivation,
        isFalse,
      );
      expect(
        scope.prefs.get(AccountActivationCoordinator.storageKey),
        terminalRecord,
      );
      await setupAuth.createNewIdentity();
      final pubkeyB = setupAuth.currentPublicKeyHex;
      setup.dispose();
      expect(pubkeyA, isNotNull, reason: 'Account A should be created');
      expect(pubkeyB, isNotNull, reason: 'Account B should be created');
      expect(pubkeyB, isNot(equals(pubkeyA)), reason: 'Two distinct accounts');

      final bContainer = scope.buildContainer();
      await bContainer
          .read(authServiceProvider)
          .signInForAccount(pubkeyB!, AuthenticationSource.automatic);
      await tester.pumpWidget(
        ContainerSwapHost(
          initialContainer: bContainer,
          controller: scope.controller,
          child: const SizedBox(),
        ),
      );

      // The injected entry uses production signInForAccount and its actual
      // native storage and cleanup dependencies in the incoming container.
      ProviderContainer? swapped;
      final switchFuture = swapAccount(
        deviceScope: scope.deviceScope,
        controller: scope.controller,
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
              .initialize(sharedPreferences: scope.prefs);
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
      );
      await scope.pumpUntilComplete(tester, switchFuture);
      await tester.pump();

      final swappedAuth = swapped!.read(authServiceProvider);
      expect(
        swappedAuth.currentPublicKeyHex,
        equals(pubkeyA),
        reason: 'After the swap the live account is A',
      );
      expect(swappedAuth.isAuthenticated, isTrue);
      expect(scope.controller.currentContainer, same(swapped));
      expect(scope.controller.currentCommit?.isCurrent, isTrue);
      expect(
        swappedAuth.committedAccountActivationReceipt?.ownerPubkey,
        pubkeyA,
      );
      expect(
        swappedAuth.committedAccountActivationReceipt?.isCurrent,
        isTrue,
      );
      await swappedAuth.signOut(
        deleteKeys: true,
        abortOnKeyDeletionFailure: true,
      );
      final destructiveAuthority = CuratedListAccountAuthority(
        authService: swappedAuth,
        preferences: scope.prefs,
      );
      final destructiveRecord = scope.prefs.get(
        AccountActivationCoordinator.storageKey,
      );
      expect(destructiveAuthority.isCurrent, isTrue);
      expect(
        await swapped!.read(secureKeyStorageProvider).hasKeysStrict(),
        isFalse,
      );
      await swappedAuth.signOut(
        deleteKeys: true,
        abortOnKeyDeletionFailure: true,
      );
      expect(destructiveAuthority.isCurrent, isTrue);
      expect(
        AccountActivationCoordinator.forPreferences(scope.prefs)
            .hasUnresolvedActivation,
        isFalse,
      );
      expect(
        scope.prefs.get(AccountActivationCoordinator.storageKey),
        destructiveRecord,
      );
      expect(tester.takeException(), isNull);
    });
  });
}

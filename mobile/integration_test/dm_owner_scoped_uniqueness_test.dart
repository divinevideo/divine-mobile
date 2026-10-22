// ABOUTME: Native SQLite proof that two owners retain their own copy of a rumor.
// ABOUTME: Real local-key account switching still clears the outgoing DM rows.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openvine/models/authentication_source.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/container_swap_host.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/providers/swap_account.dart';

import 'helpers/native_account_test_scope.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Direct DAO fixtures retain the shared rumor and different recipient wraps
  // captured from the local relay. This does not exercise live DM decryption.
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
        final scope = await NativeAccountTestScope.create();
        addTearDown(() => scope.close(tester));
        final database = scope.database;

        final setup = scope.buildContainer();
        final setupAuth = setup.read(authServiceProvider);
        await setupAuth.initialize();
        await setupAuth.createNewIdentity();
        final pubkeyA = setupAuth.currentPublicKeyHex;
        await setupAuth.signOut();
        await setupAuth.createNewIdentity();
        final pubkeyB = setupAuth.currentPublicKeyHex;
        setup.dispose();
        expect(pubkeyA, isNotNull);
        expect(pubkeyB, isNotNull);
        expect(pubkeyB, isNot(equals(pubkeyA)));

        final aContainer = scope.buildContainer();
        await aContainer
            .read(authServiceProvider)
            .signInForAccount(pubkeyA!, AuthenticationSource.automatic);
        await tester.pumpWidget(
          ContainerSwapHost(
            initialContainer: aContainer,
            controller: scope.controller,
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

        final switchFuture = swapAccount(
          deviceScope: scope.deviceScope,
          controller: scope.controller,
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

        expect(scope.controller.currentCommit?.isCurrent, isTrue);
        expect(
          scope.controller.currentContainer!
              .read(authServiceProvider)
              .committedAccountActivationReceipt
              ?.ownerPubkey,
          pubkeyB,
        );
        expect(
          scope.controller.currentContainer!
              .read(authServiceProvider)
              .committedAccountActivationReceipt
              ?.isCurrent,
          isTrue,
        );

        final afterSwap = await database.select(database.directMessages).get();
        expect(
          afterSwap,
          isEmpty,
          reason:
              'the identity-change cleanup must still delete the leaving '
              "account's DM rows — the owner-scoped key does not relax that",
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'two coexisting accounts each keep their own copy of one group rumor',
      (tester) async {
        final scope = await NativeAccountTestScope.create();
        addTearDown(() => scope.close(tester));
        final database = scope.database;

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

        // Real unattributed cleanup preserves both accounts' owned rows.
        final container = scope.buildContainer();
        // This case has no AuthService to retain the auto-dispose cleanup
        // dependency while its asynchronous callbacks use the provider ref.
        final cleanupSubscription = container.listen(
          userDataCleanupServiceProvider,
          (_, _) {},
        );
        addTearDown(cleanupSubscription.close);
        await cleanupSubscription.read().clearUserSpecificData(
          reason: 'identity_change',
          isIdentityChange: true,
        );

        final surviving = await database.select(database.directMessages).get();
        expect(
          surviving.map((row) => row.ownerPubkey),
          equals([ownerA]),
          reason: "the unattributed-only cleanup must keep account A's row",
        );

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
        expect(tester.takeException(), isNull);
      },
    );
  });
}

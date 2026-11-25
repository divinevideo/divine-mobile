// ABOUTME: Exercises the real Messages route handoff over account and DB changes.
import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/blocs/dm/conversation/conversation_participants_cubit.dart';
import 'package:openvine/blocs/dm/message_requests/request_preview_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/notifications/routing/dm_message_visibility.dart';
import 'package:openvine/notifications/routing/dm_push_navigation.dart';
import 'package:openvine/notifications/routing/notification_tap_target.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/official_accounts_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/router/route_extra_codec.dart';
import 'package:openvine/router/routes/messaging_routes.dart';
import 'package:openvine/router/routes/minor_account_review_routes.dart';
import 'package:openvine/router/routes/shell.dart';
import 'package:openvine/screens/minor_account_review_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/official_accounts_service.dart';

import '../helpers/test_provider_overrides.dart';

class _Publish extends Mock implements BackgroundPublishBloc {}

class _Auth extends Mock implements AuthService {}

class _Nostr extends Mock implements NostrClient {}

class _Dm extends Mock implements DmRepository {}

class _Official extends Mock implements OfficialAccountsService {}

class _Session extends NostrSession {
  _Session(this.initial);
  final NostrSessionReadiness initial;
  @override
  NostrSessionReadiness build() => initial;
}

void main() {
  final owner = 'a' * 64;
  final wrap = 'b' * 64;
  final other = 'c' * 64;
  final target = OpenDirectMessageTarget(
    receiverPubkey: owner,
    giftWrapId: wrap,
  );

  group('DM push navigation', () {
    late _Auth auth;
    late _Dm dm;
    late _Official official;
    late _Publish publish;
    var switches = 0;
    Object? pushedExtra;
    late GoRouter router;
    late ProviderContainer container;
    var mountedContainer = false;
    late StreamController<DmWrapLookup> messages;
    late NostrSessionReadiness ready;

    setUp(() {
      mountedContainer = false;
      auth = _Auth();
      switches = 0;
      pushedExtra = null;
      official = _Official();
      when(() => official.isReadableByProtectedMinor(any())).thenReturn(false);
      publish = _Publish();
      when(() => publish.state).thenReturn(const BackgroundPublishState());
      when(() => publish.stream).thenAnswer((_) => const Stream.empty());
      when(publish.parkInFlight).thenAnswer((_) async {});
      dm = _Dm();
      when(() => dm.userPubkey).thenReturn(owner);
      when(() => dm.getConversation(any())).thenAnswer((_) async => null);
      when(() => dm.countMessagesInConversation(any()))
          .thenAnswer((_) async => 1);
      when(() => dm.getMessages(any(), limit: any(named: 'limit')))
          .thenAnswer((_) async => const []);
      final client = _Nostr();
      messages = StreamController<DmWrapLookup>.broadcast();
      when(() => dm.watchWrapLookup(ownerPubkey: owner, giftWrapId: wrap))
          .thenAnswer((_) => messages.stream);
      when(() => auth.currentPublicKeyHex).thenReturn(owner);
      when(auth.getKnownAccounts).thenAnswer((_) async => []);
      when(() => client.publicKey).thenReturn(owner);
      when(() => client.hasKeys).thenReturn(true);
      ready = NostrSessionReadiness.nostrReady(pubkey: owner, client: client);
      router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('Home')),
          ),
          GoRoute(
            path: '/inbox',
            builder: (_, state) {
              const child = Scaffold(body: Text('Messages'));
              final intent = state.extra;
              return intent is DmPushIntent
                  ? DmPushListener(
                      key: ObjectKey(intent),
                      intent: intent,
                      child: child,
                    )
                  : child;
            },
          ),
          for (final path in [
            '/inbox/conversation/:id',
            '/inbox/message-requests/:id',
          ])
            GoRoute(
              path: path,
              builder: (_, state) {
                pushedExtra = state.extra;
                return Scaffold(body: Text(state.uri.toString()));
              },
            ),
        ],
      );
    });
    Future<void> mount(
      WidgetTester t, {
      bool cold = false,
      bool restricted = false,
    }) async {
      container = ProviderContainer(
        overrides: [
          dmPushAccountSwitchProvider.overrideWithValue((account) async {
            switches++;
            when(() => auth.currentPublicKeyHex).thenReturn(account.pubkeyHex);
            final client = _Nostr();
            when(() => client.hasKeys).thenReturn(true);
            when(() => client.publicKey).thenReturn(account.pubkeyHex);
            container
                .read(nostrSessionProvider.notifier)
                .update(
                  NostrSessionReadiness.nostrReady(
                    pubkey: account.pubkeyHex,
                    client: client,
                  ),
                );
            return container;
          }),
          authServiceProvider.overrideWithValue(auth),
          dmRepositoryProvider.overrideWithValue(dm),
          goRouterProvider.overrideWithValue(router),
          isDmRestrictedProvider.overrideWithValue(restricted),
          officialAccountsServiceProvider.overrideWithValue(official),
          currentMinorAccountReviewStatusProvider.overrideWith(
            (_) async => MinorAccountReviewStatus.active(),
          ),
          nostrSessionProvider.overrideWith(
            () => _Session(
              cold ? NostrSessionReadiness.identityKnown(pubkey: owner) : ready,
            ),
          ),
        ],
      );
      mountedContainer = true;
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: BlocProvider<BackgroundPublishBloc>.value(
            value: publish,
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    tearDown(() async {
      await messages.close();
      if (mountedContainer) container.dispose();
      router.dispose();
    });

    test(
      'generic foreground alerts honor exact visibility, request and minor rules',
      () {
        final found = DmWrapFound(
          conversationId: 'room',
          messageId: 'rumor',
          participants: {other},
          isRequest: false,
        );
        bool show(
          DmWrapLookup result, {
          bool restricted = false,
          String? viewing,
        }) => shouldDisplayDmAlert(
          result,
          owner: owner,
          restricted: restricted,
          allowedPeer: (_) => false,
          visible: (o, c, m) => o == owner && c == 'room' && m == viewing,
        );
        expect(show(found), isTrue);
        expect(show(found, viewing: 'another'), isTrue);
        expect(show(found, viewing: 'rumor'), isFalse);
        expect(show(found, restricted: true), isFalse);
        expect(show(const DmWrapSuppressed()), isFalse);
        expect(show(const DmWrapDeleted()), isFalse);
        expect(show(const DmWrapPending(), restricted: true), isFalse);
        expect(
          show(
            DmWrapFound(
              conversationId: 'room',
              messageId: 'rumor',
              participants: {other},
              isRequest: true,
            ),
          ),
          isFalse,
        );
      },
    );

    testWidgets(
      'protected minor never opens an unreadable verified room or request',
      (t) async {
        await mount(t, restricted: true);
        for (final request in [false, true]) {
          openDmPush(container, target);
          await t.pumpAndSettle();
          expect(messages.hasListener, isTrue);
          messages.add(
            DmWrapFound(
              conversationId: 'room',
              messageId: 'rumor',
              participants: {other},
              isRequest: request,
            ),
          );
          await t.pumpAndSettle();
          expect(router.routeInformationProvider.value.uri.path, '/inbox');
          expect(messages.hasListener, isFalse);
        }
      },
    );

    testWidgets(
      'protected minor passes verified peers to conversation and request destination gates',
      (t) async {
        final approvedPeer = 'f' * 64;
        when(
          () => official.isReadableByProtectedMinor(approvedPeer),
        ).thenReturn(true);
        await mount(t, restricted: true);

        openDmPush(container, target);
        await t.pumpAndSettle();
        messages.add(
          DmWrapFound(
            conversationId: 'room',
            messageId: 'rumor',
            participants: {approvedPeer},
            isRequest: false,
          ),
        );
        await t.pumpAndSettle();
        expect(
          find.text('/inbox/conversation/room?messageId=rumor'),
          findsOneWidget,
        );
        expect(pushedExtra, [approvedPeer]);

        final participantsCubit = ConversationParticipantsCubit(
          dmRepository: dm,
          conversationId: 'room',
          isDmRestricted: () => true,
          isApprovedRecipient: official.isReadableByProtectedMinor,
          initialParticipantPubkeys: dmRouteExtra(pushedExtra)
              .participantPubkeys,
        );
        addTearDown(participantsCubit.close);
        await participantsCubit.load();
        expect(
          participantsCubit.state.status,
          ConversationParticipantsStatus.ready,
        );
        expect(participantsCubit.state.participantPubkeys, [approvedPeer]);

        pushedExtra = null;
        router.go('/');
        await t.pumpAndSettle();

        openDmPush(container, target);
        await t.pumpAndSettle();
        messages.add(
          DmWrapFound(
            conversationId: 'room-req',
            messageId: 'rumor-req',
            participants: {approvedPeer},
            isRequest: true,
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('/inbox/message-requests/room-req'), findsOneWidget);
        expect(pushedExtra, [approvedPeer]);

        final previewCubit = RequestPreviewCubit(
          dmRepository: dm,
          conversationId: 'room-req',
          isDmRestricted: () => true,
          isApprovedRecipient: official.isReadableByProtectedMinor,
          initialParticipantPubkeys: dmRouteExtra(pushedExtra)
              .participantPubkeys,
        );
        addTearDown(previewCubit.close);
        await previewCubit.load();
        expect(previewCubit.state.status, RequestPreviewStatus.loaded);
        expect(previewCubit.state.participantPubkeys, [approvedPeer]);
      },
    );

    for (final cold in [false, true]) {
      for (final isRequest in [false, true]) {
        testWidgets(
          'cold=$cold request=$isRequest opens once after verification',
          (t) async {
            await mount(t, cold: cold);
            openDmPush(container, target);
            await t.pumpAndSettle();
            openDmPush(container, target);
            if (cold) {
              container.read(nostrSessionProvider.notifier).update(ready);
            }
            await t.pump();
            messages.add(const DmWrapPending());
            await t.pump();
            expect(find.text('Messages'), findsOneWidget);
            messages.add(
              DmWrapFound(
                conversationId: 'room',
                messageId: 'rumor',
                participants: const {'peer'},
                isRequest: isRequest,
              ),
            );
            await t.pumpAndSettle();
            final path = isRequest
                ? '/inbox/message-requests/room'
                : '/inbox/conversation/room?messageId=rumor';
            expect(find.text(path), findsOneWidget);
            openDmPush(container, target);
            await t.pumpAndSettle();
            expect(find.text(path), findsOneWidget);
            verify(
              () => dm.watchWrapLookup(ownerPubkey: owner, giftWrapId: wrap),
            ).called(1);
          },
        );
      }
    }
    for (final accept in [true, false]) {
      testWidgets(
        'a known other account needs explicit confirmation: $accept',
        (
          t,
        ) async {
          when(auth.getKnownAccounts).thenAnswer(
            (_) async => [
              KnownAccount(
                pubkeyHex: other,
                authSource: AuthenticationSource.importedKeys,
                addedAt: DateTime.utc(2026),
                lastUsedAt: DateTime.utc(2026),
              ),
            ],
          );
          when(() => dm.watchWrapLookup(ownerPubkey: other, giftWrapId: wrap))
              .thenAnswer((_) => messages.stream);
          await mount(t);
          openDmPush(
            container,
            OpenDirectMessageTarget(receiverPubkey: other, giftWrapId: wrap),
          );
          await t.pumpAndSettle();
          expect(find.byType(VineBottomSheet), findsOneWidget);
          expect(messages.hasListener, isFalse);
          await t.tap(
            find.widgetWithText(
              DivineButton,
              accept ? 'Switch account' : 'Cancel',
            ),
          );
          await t.pumpAndSettle();
          expect(switches, accept ? 1 : 0);
          expect(messages.hasListener, accept);
          verifyNever(
            () => dm.watchWrapLookup(ownerPubkey: owner, giftWrapId: wrap),
          );
        },
      );
    }

    testWidgets('unknown account never queries the current account', (t) async {
      await mount(t);
      openDmPush(
        container,
        OpenDirectMessageTarget(receiverPubkey: other, giftWrapId: wrap),
      );
      await t.pumpAndSettle();
      expect(find.text('Messages'), findsOneWidget);
      verifyNever(
        () => dm.watchWrapLookup(
          ownerPubkey: any(named: 'ownerPubkey'),
          giftWrapId: any(named: 'giftWrapId'),
        ),
      );
    });
    testWidgets(
      'a superseding tap cancels the earlier wrap, then deletion settles',
      (t) async {
        final secondWrap = 'd' * 64;
        final second = StreamController<DmWrapLookup>.broadcast();
        addTearDown(second.close);
        when(
          () => dm.watchWrapLookup(ownerPubkey: owner, giftWrapId: secondWrap),
        ).thenAnswer((_) => second.stream);
        await mount(t);
        openDmPush(container, target);
        await t.pumpAndSettle();
        openDmPush(
          container,
          OpenDirectMessageTarget(
            receiverPubkey: owner,
            giftWrapId: secondWrap,
          ),
        );
        await t.pumpAndSettle();
        expect(messages.hasListener, isFalse);
        expect(second.hasListener, isTrue);
        second.add(const DmWrapDeleted());
        await t.pump();
        expect(second.hasListener, isFalse);
        expect(find.text('Messages'), findsOneWidget);
      },
    );

    testWidgets('a sign-out while waiting cannot route the previous owner', (
      t,
    ) async {
      await mount(t);
      openDmPush(container, target);
      await t.pumpAndSettle();
      container
          .read(nostrSessionProvider.notifier)
          .update(const NostrSessionReadiness.signedOut());
      await t.pump();
      expect(messages.hasListener, isFalse);
      expect(find.text('Messages'), findsOneWidget);
    });

    testWidgets(
      'leaving the Messages pane rejects a late verification on the same route',
      (t) async {
        await mount(t);
        openDmPush(container, target);
        await t.pumpAndSettle();
        final intent = t
            .widget<DmPushListener>(find.byType(DmPushListener))
            .intent;
        intent.cancel();
        expect(messages.hasListener, isFalse);
        messages.add(
          DmWrapFound(
            conversationId: 'room',
            messageId: 'rumor',
            participants: {other},
            isRequest: false,
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('Messages'), findsOneWidget);
        expect(router.routeInformationProvider.value.uri.path, '/inbox');
      },
    );
    testWidgets('leaving Messages cancels the lookup', (t) async {
      await mount(t);
      openDmPush(container, target);
      await t.pumpAndSettle();
      expect(messages.hasListener, isTrue);
      router.go('/');
      await t.pumpAndSettle();
      expect(messages.hasListener, isFalse);
      messages.add(const DmWrapDeleted());
      await t.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
    });
    testWidgets('DM initialization consumes the same ten second budget', (
      t,
    ) async {
      await mount(t, cold: true);
      openDmPush(container, target);
      await t.pumpAndSettle();
      await t.pump(const Duration(seconds: 10));
      await t.pumpAndSettle();
      container.read(nostrSessionProvider.notifier).update(ready);
      await t.pump();
      expect(messages.hasListener, isFalse);
      expect(find.text('Messages'), findsOneWidget);
    });
  });

  group(
    'redirect preservation across review loading and restricted accounts',
    () {
      late _Dm dm;
      late _Official official;
      late _Publish publish;
      Object? pushedExtra;
      late StreamController<DmWrapLookup> messages;
      late NostrSessionReadiness ready;

      setUp(() {
        pushedExtra = null;
        official = _Official();
        when(() => official.isReadableByProtectedMinor(any()))
            .thenReturn(false);
        publish = _Publish();
        when(() => publish.state).thenReturn(const BackgroundPublishState());
        when(() => publish.stream).thenAnswer((_) => const Stream.empty());
        when(publish.parkInFlight).thenAnswer((_) async {});
        dm = _Dm();
        when(() => dm.userPubkey).thenReturn(owner);
        when(() => dm.getConversation(any())).thenAnswer((_) async => null);
        when(() => dm.countMessagesInConversation(any()))
            .thenAnswer((_) async => 1);
        when(() => dm.getMessages(any(), limit: any(named: 'limit')))
            .thenAnswer((_) async => const []);
        final client = _Nostr();
        messages = StreamController<DmWrapLookup>.broadcast();
        when(() => dm.watchWrapLookup(ownerPubkey: owner, giftWrapId: wrap))
            .thenAnswer((_) => messages.stream);
        when(() => client.publicKey).thenReturn(owner);
        when(() => client.hasKeys).thenReturn(true);
        ready = NostrSessionReadiness.nostrReady(pubkey: owner, client: client);
      });

      tearDown(() async {
        await messages.close();
      });

      MinorAccountReviewStatus restrictedStatus({
        required String moderationPubkey,
        String? moderationConversationId,
      }) {
        return MinorAccountReviewStatus(
          restrictionStatus: AccountRestrictionStatus.restrictedMinorReview,
          currentCase: MinorReviewCase(
            id: 'case-1',
            state: MinorReviewCaseState.restrictedPendingUserResponse,
            suspectedAgeBand: SuspectedAgeBand.age13To15,
            allowedResolution: MinorReviewResolutionType.parentVideoOrEmail,
            instructions: const MinorReviewInstructions(
              title: 'Account review required',
              body: 'Review details.',
            ),
            supportEmail: 'support@divine.video',
            moderationConversationPubkey: moderationPubkey,
            moderationConversationId: moderationConversationId,
          ),
        );
      }

      Future<ProviderContainer> mountRedirectedRouter(
        WidgetTester t, {
        required Future<MinorAccountReviewStatus> Function() loadReviewStatus,
        bool restrictedMinor = false,
        String? initialLocation,
      }) async {
        resetNavigationState();
        final mockAuth = createMockAuthService();
        when(() => mockAuth.isAuthenticated).thenReturn(true);
        when(() => mockAuth.authState).thenReturn(AuthState.authenticated);
        when(() => mockAuth.currentPublicKeyHex).thenReturn(owner);
        when(
          () => mockAuth.authStateStream,
        ).thenAnswer((_) => const Stream<AuthState>.empty());
        when(mockAuth.getKnownAccounts).thenAnswer((_) async => []);

        final refreshListenable = ValueNotifier<int>(0);
        addTearDown(refreshListenable.dispose);

        final redirectedContainer = ProviderContainer(
          overrides: [
            ...getStandardTestOverrides(mockAuthService: mockAuth),
            dmRepositoryProvider.overrideWithValue(dm),
            isDmRestrictedProvider.overrideWithValue(restrictedMinor),
            officialAccountsServiceProvider.overrideWithValue(official),
            nostrSessionProvider.overrideWith(() => _Session(ready)),
            currentAccountDeletionAttemptProvider.overrideWith(
              (_) async => null,
            ),
            currentMinorAccountReviewStatusProvider.overrideWith(
              (_) => loadReviewStatus(),
            ),
            goRouterProvider.overrideWith((ref) {
              ref.listen(currentMinorAccountReviewStatusProvider, (_, _) {
                refreshListenable.value++;
              });
              final redirectedRouter = GoRouter(
                initialLocation: initialLocation ?? '/home/0',
                extraCodec: RouteExtraCodec(),
                refreshListenable: refreshListenable,
                redirect: (_, state) => appRouterRedirect(ref, state),
                routes: [
                  GoRoute(
                    path: '/welcome',
                    builder: (_, _) => const Scaffold(body: Text('Welcome')),
                  ),
                  GoRoute(
                    path: '/home/:index',
                    builder: (_, _) => const Scaffold(body: Text('Home')),
                  ),
                  GoRoute(
                    path: MinorAccountReviewLoadingScreen.path,
                    builder: (_, _) => const MinorAccountReviewLoadingScreen(),
                  ),
                  GoRoute(
                    path: MinorAccountReviewScreen.path,
                    builder: (context, state) => MinorAccountReviewRouteData(
                      dmTap: state.uri.queryParameters['dmTap'],
                    ).build(context, state),
                  ),
                  GoRoute(
                    path: '/inbox',
                    builder: (context, state) {
                      const child = Scaffold(body: Text('Messages'));
                      final isMessages =
                          state.uri.queryParameters['messages'] == 'true';
                      final intent = isMessages
                          ? activeDmPushIntent(
                              ProviderScope.containerOf(context, listen: false),
                              extra: state.extra,
                              token: state.uri.queryParameters['dmTap'],
                            )
                          : null;
                      return intent != null
                          ? DmPushListener(
                              key: ObjectKey(intent),
                              intent: intent,
                              child: child,
                            )
                          : child;
                    },
                  ),
                  for (final path in [
                    '/inbox/conversation/:id',
                    '/inbox/message-requests/:id',
                  ])
                    GoRoute(
                      path: path,
                      builder: (_, state) {
                        pushedExtra = state.extra;
                        return Scaffold(body: Text(state.uri.toString()));
                      },
                    ),
                ],
              );
              ref.onDispose(redirectedRouter.dispose);
              return redirectedRouter;
            }),
          ],
        );
        addTearDown(redirectedContainer.dispose);
        await t.pumpWidget(
          UncontrolledProviderScope(
            container: redirectedContainer,
            child: BlocProvider<BackgroundPublishBloc>.value(
              value: publish,
              child: MaterialApp.router(
                theme: VineTheme.theme,
                routerConfig: redirectedContainer.read(goRouterProvider),
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
              ),
            ),
          ),
        );
        await t.pump();
        return redirectedContainer;
      }

      testWidgets(
        'cold tap survives review-status loading redirect and opens verified message',
        (t) async {
          final reviewCompleter = Completer<MinorAccountReviewStatus>();
          final redirectedContainer = await mountRedirectedRouter(
            t,
            loadReviewStatus: () => reviewCompleter.future,
          );
          final redirectedRouter = redirectedContainer.read(goRouterProvider);

          expect(
            redirectedRouter.routeInformationProvider.value.uri.path,
            MinorAccountReviewLoadingScreen.path,
          );

          openDmPush(redirectedContainer, target);
          await t.pump();
          expect(
            redirectedRouter.routeInformationProvider.value.uri.path,
            MinorAccountReviewLoadingScreen.path,
          );
          expect(messages.hasListener, isFalse);

          reviewCompleter.complete(MinorAccountReviewStatus.active());
          await t.pumpAndSettle();

          expect(
            redirectedRouter.routeInformationProvider.value.uri.path,
            '/inbox',
          );
          expect(messages.hasListener, isTrue);

          messages.add(
            DmWrapFound(
              conversationId: 'room',
              messageId: 'rumor',
              participants: {other},
              isRequest: false,
            ),
          );
          await t.pumpAndSettle();

          expect(
            find.text('/inbox/conversation/room?messageId=rumor'),
            findsOneWidget,
          );
          expect(pushedExtra, [other]);
        },
      );

      testWidgets(
        'cold tap whose 10s deadline expires while waiting on review status settles unavailable without resetting timer',
        (t) async {
          final reviewCompleter = Completer<MinorAccountReviewStatus>();
          final redirectedContainer = await mountRedirectedRouter(
            t,
            loadReviewStatus: () => reviewCompleter.future,
          );
          final redirectedRouter = redirectedContainer.read(goRouterProvider);

          openDmPush(redirectedContainer, target);
          await t.pump();

          await t.pump(const Duration(seconds: 10));
          reviewCompleter.complete(MinorAccountReviewStatus.active());
          await t.pumpAndSettle();

          expect(
            redirectedRouter.routeInformationProvider.value.uri.path,
            '/inbox',
          );
          expect(messages.hasListener, isFalse);
          expect(find.text('This message is unavailable.'), findsOneWidget);
        },
      );

      testWidgets(
        'restricted account cold and warm moderation taps open the moderation conversation with peer extra',
        (t) async {
          final modPubkey = 'e' * 64;
          final modConversationId = DmRepository.computeConversationId([
            owner,
            modPubkey,
          ]);
          when(() => official.isReadableByProtectedMinor(modPubkey)).thenReturn(
            true,
          );
          final reviewCompleter = Completer<MinorAccountReviewStatus>();
          final redirectedContainer = await mountRedirectedRouter(
            t,
            restrictedMinor: true,
            loadReviewStatus: () => reviewCompleter.future,
          );
          final redirectedRouter = redirectedContainer.read(goRouterProvider);

          // Cold tap while review status is still loading.
          openDmPush(redirectedContainer, target);
          await t.pump();
          expect(
            redirectedRouter.routeInformationProvider.value.uri.path,
            MinorAccountReviewLoadingScreen.path,
          );

          reviewCompleter.complete(
            restrictedStatus(moderationPubkey: modPubkey),
          );
          await t.pumpAndSettle();

          expect(
            redirectedRouter.routeInformationProvider.value.uri.path,
            MinorAccountReviewScreen.path,
          );
          expect(messages.hasListener, isTrue);

          messages.add(
            DmWrapFound(
              conversationId: modConversationId,
              messageId: 'mod-rumor-1',
              participants: {modPubkey},
              isRequest: true,
            ),
          );
          await t.pumpAndSettle();

          expect(
            find.text(
              '/inbox/conversation/$modConversationId?messageId=mod-rumor-1',
            ),
            findsOneWidget,
          );
          expect(pushedExtra, [modPubkey]);

          // Warm tap while already restricted on the review screen.
          pushedExtra = null;
          redirectedRouter.go(MinorAccountReviewScreen.path);
          await t.pumpAndSettle();

          final warmWrap = 'f' * 64;
          when(
            () => dm.watchWrapLookup(ownerPubkey: owner, giftWrapId: warmWrap),
          ).thenAnswer((_) => messages.stream);
          openDmPush(
            redirectedContainer,
            OpenDirectMessageTarget(
              receiverPubkey: owner,
              giftWrapId: warmWrap,
            ),
          );
          await t.pumpAndSettle();

          expect(
            redirectedRouter.routeInformationProvider.value.uri.path,
            MinorAccountReviewScreen.path,
          );
          messages.add(
            DmWrapFound(
              conversationId: modConversationId,
              messageId: 'mod-rumor-2',
              participants: {modPubkey},
              isRequest: false,
            ),
          );
          await t.pumpAndSettle();

          expect(
            find.text(
              '/inbox/conversation/$modConversationId?messageId=mod-rumor-2',
            ),
            findsOneWidget,
          );
          expect(pushedExtra, [modPubkey]);
        },
      );

      testWidgets(
        'restricted account tapping a non-moderation DM settles unavailable on review screen',
        (t) async {
          final modPubkey = 'e' * 64;
          final redirectedContainer = await mountRedirectedRouter(
            t,
            restrictedMinor: true,
            loadReviewStatus: () async =>
                restrictedStatus(moderationPubkey: modPubkey),
          );
          await redirectedContainer.read(
            currentMinorAccountReviewStatusProvider.future,
          );
          await t.pumpAndSettle();

          openDmPush(redirectedContainer, target);
          await t.pumpAndSettle();

          expect(
            redirectedContainer
                .read(goRouterProvider)
                .routeInformationProvider
                .value
                .uri
                .path,
            MinorAccountReviewScreen.path,
          );
          expect(messages.hasListener, isTrue);

          messages.add(
            DmWrapFound(
              conversationId: 'peer-room',
              messageId: 'peer-rumor',
              participants: {other},
              isRequest: false,
            ),
          );
          await t.pumpAndSettle();

          expect(
            redirectedContainer
                .read(goRouterProvider)
                .routeInformationProvider
                .value
                .uri
                .path,
            MinorAccountReviewScreen.path,
          );
          expect(messages.hasListener, isFalse);
          expect(find.text('This message is unavailable.'), findsOneWidget);
        },
      );

      testWidgets('stale or foreign dmTap tokens do not navigate', (t) async {
        final redirectedContainer = await mountRedirectedRouter(
          t,
          loadReviewStatus: () async => MinorAccountReviewStatus.active(),
        );
        await redirectedContainer.read(
          currentMinorAccountReviewStatusProvider.future,
        );
        await t.pumpAndSettle();
        final redirectedRouter = redirectedContainer.read(goRouterProvider);

        // Foreign token with no live intent in container.
        redirectedRouter.go(
          const InboxRouteData(messages: true, dmTap: 'foreign-token').location,
        );
        await t.pumpAndSettle();
        expect(messages.hasListener, isFalse);
        expect(find.text('Messages'), findsOneWidget);

        // Finished intent token must not re-arm on return.
        openDmPush(redirectedContainer, target);
        await t.pumpAndSettle();
        final token = redirectedRouter
            .routeInformationProvider
            .value
            .uri
            .queryParameters['dmTap'];
        expect(token, isNotNull);
        messages.add(const DmWrapDeleted());
        await t.pumpAndSettle();
        expect(messages.hasListener, isFalse);

        redirectedRouter.go('/home/0');
        await t.pumpAndSettle();
        redirectedRouter.go(
          InboxRouteData(messages: true, dmTap: token).location,
        );
        await t.pumpAndSettle();
        expect(messages.hasListener, isFalse);
      });
    },
  );
}

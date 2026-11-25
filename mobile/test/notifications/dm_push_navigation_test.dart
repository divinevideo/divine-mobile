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
import 'package:openvine/notifications/routing/dm_message_visibility.dart';
import 'package:openvine/notifications/routing/dm_push_navigation.dart';
import 'package:openvine/notifications/routing/notification_tap_target.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/official_accounts_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/router/routes/messaging_routes.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/official_accounts_service.dart';

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
  late OpenDirectMessageTarget target;

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
    target = OpenDirectMessageTarget(receiverPubkey: owner, giftWrapId: wrap);
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

  group('DM push navigation', () {
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
}

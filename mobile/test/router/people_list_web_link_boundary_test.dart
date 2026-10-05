// ABOUTME: Public people-list links preserve authors and destinations through
// ABOUTME: the real link stream, coordinator, redirect, and list route table.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/nip19.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/people_lists/people_lists.dart';
import 'package:openvine/features/people_lists/view/add_people_to_list_screen.dart';
import 'package:openvine/features/people_lists/view/create_people_list_page.dart';
import 'package:openvine/features/people_lists/view/people_list_members_screen.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/deep_link_coordinator.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/router/routes/lists_routes.dart';
import 'package:openvine/router/universal_link_resolver.dart';
import 'package:openvine/screens/minor_account_review_screen.dart';
import 'package:openvine/screens/user_list_people_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/deep_link_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

import '../helpers/test_provider_overrides.dart';

class _MockListsBloc extends MockBloc<PeopleListsEvent, PeopleListsState>
    implements PeopleListsBloc {}

class _MockListsRepository extends Mock implements PeopleListsRepository {}

final _refProvider = Provider<Ref>((ref) => ref);
final String _owner = 'a' * 64;
final String _foreignOwner = 'b' * 64;

UserList _list(String id, {bool editable = true}) => UserList(
  id: id,
  name: editable ? 'Own cached list' : 'Public list',
  pubkeys: const [],
  isEditable: editable,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  group('Public people-list link boundary', () {
    late _MockListsBloc bloc;
    late _MockListsRepository repository;
    late GoRouter router;
    late DeepLinkService links;
    Widget? selected;
    final strings = lookupAppLocalizations(const Locale('en'));

    setUpAll(() {
      registerFallbackValue(
        PeopleListsCreateRequested(
          expectedOwnerPubkey: _owner,
          name: 'Fixture',
        ),
      );
    });

    setUp(() {
      resetNavigationState();
      bloc = _MockListsBloc();
      repository = _MockListsRepository();
      selected = null;
    });

    Future<void> start(
      WidgetTester tester, {
      String id = 'crew',
      bool render = true,
      AuthState authState = AuthState.authenticated,
      bool restricted = false,
    }) async {
      whenListen(
        bloc,
        const Stream<PeopleListsState>.empty(),
        initialState: PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: _owner,
          lists: [_list(id)],
        ),
      );
      final auth = createMockAuthService(
        authState: authState,
        currentPublicKeyHex: _owner,
      );
      when(() => auth.hasExpiredOAuthSession).thenReturn(false);
      final container = ProviderContainer(
        overrides: [
          ...getStandardTestOverrides(mockAuthService: auth),
          videoEventServiceProvider.overrideWithValue(
            createMockVideoEventService(),
          ),
          isFeatureEnabledProvider(FeatureFlag.curatedLists)
              .overrideWith((ref) => true),
          peopleListsRepositoryProvider.overrideWithValue(repository),
          hasFollowingInCacheProvider.overrideWithValue(true),
          currentAccountDeletionAttemptProvider.overrideWith(
            (ref) async => null,
          ),
          currentMinorAccountReviewStatusProvider.overrideWith(
            (ref) async => restricted
                ? const MinorAccountReviewStatus(
                    restrictionStatus:
                        AccountRestrictionStatus.restrictedMinorReview,
                  )
                : MinorAccountReviewStatus.active(),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(currentMinorAccountReviewStatusProvider.future);
      await container.read(currentAccountDeletionAttemptProvider.future);
      final ref = container.read(_refProvider);
      router = GoRouter(
        initialLocation: '/home/0',
        redirect: (_, state) => appRouterRedirect(ref, state),
        routes: [
          for (final path in [
            '/home/:index',
            '/welcome',
            MinorAccountReviewScreen.path,
          ])
            GoRoute(
              path: path,
              builder: (_, _) => Scaffold(body: Text(path)),
            ),
          ...listsRoutes(ref).cast<GoRoute>().map(
            (route) => GoRoute(
              path: route.path,
              name: route.name,
              redirect: route.redirect,
              builder: (context, state) {
                final widget = route.builder!(context, state);
                selected = widget;
                return render ? widget : const Scaffold(body: Text('Selected'));
              },
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      links = DeepLinkService();
      final coordinator = DeepLinkCoordinator(
        router: router,
        authService: auth,
      );
      final subscription = links.linkStream.listen(
        (link) => coordinator.handle(AsyncValue.data(link)),
      );
      addTearDown(() async {
        await subscription.cancel();
        links.dispose();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: BlocProvider<PeopleListsBloc>.value(
            value: bloc,
            child: MaterialApp.router(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('en'),
              routerConfig: router,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    void publicListAvailable(String id) {
      when(
        () =>
            repository.fetchPublicList(ownerPubkey: _foreignOwner, listId: id),
      ).thenAnswer((_) async => _list(id, editable: false));
    }

    Future<void> navigate(
      WidgetTester tester,
      String url, {
      required bool live,
    }) async {
      if (live) {
        links.pushLink(DeepLinkService.parseDeepLink(url));
      } else {
        router.go(url);
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    Future<void> openOwnerPicker(WidgetTester tester) async {
      expect(find.byTooltip(strings.peopleListsActionsTooltip), findsOneWidget);
      await tester.tap(find.byTooltip(strings.peopleListsActionsTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(strings.peopleListsAddPeopleTooltip));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(AddPeopleToListScreen), findsOneWidget);
      expect(
        tester
            .widget<AddPeopleToListScreen>(find.byType(AddPeopleToListScreen))
            .listId,
        'crew',
      );
    }

    for (final live in [false, true]) {
      for (final id in ['crew', _owner, 'a b/c%d?雪', '%2F']) {
        testWidgets(
          '${live ? 'listener' : 'router'} preserves qualified roster for $id',
          (tester) async {
            publicListAvailable(id);
            await start(tester, id: id);
            await navigate(
              tester,
              'https://divine.video/people-lists/${Uri.encodeComponent(id)}/members?owner=$_foreignOwner',
              live: live,
            );
            expect(selected, isA<PeopleListMembersScreen>());
            final roster = selected! as PeopleListMembersScreen;
            expect(roster.listId, id);
            expect(roster.ownerPubkey, _foreignOwner);
            expect(find.text('Public list'), findsOneWidget);
            expect(
              find.byTooltip(strings.peopleListsAddPeopleTooltip),
              findsNothing,
            );
            verify(
              () => repository.fetchPublicList(
                ownerPubkey: _foreignOwner,
                listId: id,
              ),
            ).called(1);
            verifyNever(() => bloc.add(any()));
          },
        );
      }

      for (final suffix in [
        'members',
        'add-people',
        'new',
        'a b/c%d?雪',
        '%2F',
      ]) {
        testWidgets(
          '${live ? 'listener' : 'router'} canonical d-tag $suffix selects detail',
          (tester) async {
            publicListAvailable(suffix);
            await start(tester, id: suffix);
            await navigate(
              tester,
              'https://divine.video/people-lists/$_foreignOwner/${Uri.encodeComponent(suffix)}',
              live: live,
            );
            expect(selected, isA<UserListPeopleScreen>());
            expect((selected! as UserListPeopleScreen).listId, suffix);
            expect(
              (selected! as UserListPeopleScreen).ownerPubkey,
              _foreignOwner,
            );
            expect(find.byType(CreatePeopleListPage), findsNothing);
            expect(
              find.byTooltip(strings.peopleListsActionsTooltip),
              findsNothing,
            );
            expect(
              find.byTooltip(strings.peopleListsAddPeopleTooltip),
              findsNothing,
            );
            verify(
              () => repository.fetchPublicList(
                ownerPubkey: _foreignOwner,
                listId: suffix,
              ),
            ).called(1);
          },
        );
      }

      for (final owner in [
        _owner,
        _owner.toUpperCase(),
        NostrKeyUtils.encodePubKey(_owner),
        NostrKeyUtils.encodePubKey(_owner).toUpperCase(),
      ]) {
        testWidgets(
          '${live ? 'listener' : 'router'} encoded own picker $owner retains author',
          (tester) async {
            await start(tester, render: false, id: 'a b/c%d?雪');
            await navigate(
              tester,
              'https://divine.video/people-lists/${Uri.encodeComponent('a b/c%d?雪')}/add-people?owner=$owner',
              live: live,
            );
            expect(selected, isA<AddPeopleToListScreen>());
            expect((selected! as AddPeopleToListScreen).listId, 'a b/c%d?雪');
            expect(router.state.uri.queryParameters['owner'], _owner);
            verifyNever(
              () => repository.fetchPublicList(
                ownerPubkey: any(named: 'ownerPubkey'),
                listId: any(named: 'listId'),
              ),
            );
          },
        );
      }

      testWidgets(
        '${live ? 'listener' : 'router'} foreign picker rejects own-cache fallback',
        (tester) async {
          await start(tester);
          await navigate(
            tester,
            'https://divine.video/people-lists/crew/add-people?owner=$_foreignOwner',
            live: live,
          );
          expect(find.byType(RouteErrorScreen), findsOneWidget);
          expect(find.byType(AddPeopleToListScreen), findsNothing);
          verifyNever(() => bloc.add(any()));
          verifyNever(
            () => repository.fetchPublicList(
              ownerPubkey: any(named: 'ownerPubkey'),
              listId: any(named: 'listId'),
            ),
          );
        },
      );
    }

    for (final live in [false, true]) {
      testWidgets(
        '${live ? 'listener' : 'router'} own canonical npub retains edit controls',
        (tester) async {
          await start(tester);
          await navigate(
            tester,
            'https://divine.video/people-lists/${NostrKeyUtils.encodePubKey(_owner)}/crew',
            live: live,
          );
          expect(selected, isA<UserListPeopleScreen>());
          expect((selected! as UserListPeopleScreen).ownerPubkey, _owner);
          await openOwnerPicker(tester);
          verifyNever(
            () => repository.fetchPublicList(
              ownerPubkey: any(named: 'ownerPubkey'),
              listId: any(named: 'listId'),
            ),
          );
        },
      );
    }

    for (final invalidOwner in [
      'npub1invalid',
      'not-a-key',
      NostrKeyUtils.encodePubKey('11'),
      Nip19.encodePrivateKey(_owner),
    ]) {
      for (final id in ['members', 'add-people', 'new']) {
        testWidgets(
          'invalid canonical author $invalidOwner/$id cannot enter legacy own view',
          (tester) async {
            await start(tester, id: invalidOwner);
            final url = 'https://divine.video/people-lists/$invalidOwner/$id';
            await navigate(tester, url, live: true);
            expect(selected, isNull);
            expect(router.state.uri.path, '/home/0');
            await navigate(tester, url, live: false);
            expect(selected, isA<RouteErrorScreen>());
            expect(find.byType(RouteErrorScreen), findsOneWidget);
            final pushRoute = divineUrlToPushRoute(Uri.parse(url));
            expect(pushRoute, isNotNull);
            expect(Uri.parse(pushRoute!).queryParameters['owner'], '');
            expect(find.text(strings.routeInvalidListId), findsOneWidget);
            expect(find.byType(UserListPeopleScreen), findsNothing);
            expect(find.byType(PeopleListMembersScreen), findsNothing);
            expect(find.byType(AddPeopleToListScreen), findsNothing);
            verifyNever(
              () => repository.fetchPublicList(
                ownerPubkey: any(named: 'ownerPubkey'),
                listId: any(named: 'listId'),
              ),
            );
            verifyNever(() => bloc.add(any()));
          },
        );
      }
    }

    for (final query in [
      'owner=',
      'owner=me',
      'owner=$_owner&owner=$_foreignOwner',
    ]) {
      testWidgets(
        'invalid query $query fails closed in router and is ignored by listener',
        (tester) async {
          await start(tester);
          final url = 'https://divine.video/people-lists/crew/members?$query';
          await navigate(tester, url, live: true);
          expect(selected, isNull);
          expect(router.state.uri.path, '/home/0');
          await navigate(tester, url, live: false);
          expect(find.byType(RouteErrorScreen), findsOneWidget);
          verifyNever(() => bloc.add(any()));
          verifyNever(
            () => repository.fetchPublicList(
              ownerPubkey: any(named: 'ownerPubkey'),
              listId: any(named: 'listId'),
            ),
          );
        },
      );
    }

    for (final suffix in ['', '/members', '/add-people']) {
      testWidgets('path-only legacy crew$suffix remains its original view', (
        tester,
      ) async {
        await start(tester, render: suffix != '/add-people');
        router.go('/people-lists/crew$suffix');
        await tester.pumpAndSettle();
        expect(
          selected,
          suffix == '/members'
              ? isA<PeopleListMembersScreen>()
              : suffix == '/add-people'
              ? isA<AddPeopleToListScreen>()
              : isA<UserListPeopleScreen>(),
        );
      });
    }

    testWidgets('bare web ID retains legacy own-list navigation', (
      tester,
    ) async {
      await start(tester);
      await navigate(
        tester,
        'https://divine.video/people-lists/crew',
        live: false,
      );
      expect(selected, isA<UserListPeopleScreen>());
      expect((selected! as UserListPeopleScreen).ownerPubkey, isNull);
      await openOwnerPicker(tester);
    });

    for (final authState in [
      AuthState.unauthenticated,
      AuthState.authenticated,
    ]) {
      for (final url in [
        'https://divine.video/people-lists/not-a-key/members',
        'https://divine.video/people-lists/crew/members?owner=$_foreignOwner',
      ]) {
        testWidgets('$authState gates $url after resolution', (tester) async {
          await start(
            tester,
            authState: authState,
            restricted: authState == AuthState.authenticated,
          );
          await navigate(tester, url, live: false);
          expect(
            router.state.uri.path,
            authState == AuthState.unauthenticated
                ? '/welcome'
                : MinorAccountReviewScreen.path,
          );
          expect(selected, isNull);
          verifyNever(
            () => repository.fetchPublicList(
              ownerPubkey: any(named: 'ownerPubkey'),
              listId: any(named: 'listId'),
            ),
          );
        });
      }
    }
  });
}

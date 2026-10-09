// ABOUTME: Exercises the real people-list route table and its author boundary.
// ABOUTME: Invalid author input cannot fall back to an editable same-ID list.

import 'package:bech32/bech32.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderFamily;
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
import 'package:openvine/features/people_lists/view/edit_people_list_page.dart';
import 'package:openvine/features/people_lists/view/people_list_members_screen.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/router/providers/page_context_provider.dart';
import 'package:openvine/router/route_error_screen.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/routes/lists_routes.dart';
import 'package:openvine/screens/user_list_people_screen.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockPeopleListsBloc extends MockBloc<PeopleListsEvent, PeopleListsState>
    implements PeopleListsBloc {}

class _MockPeopleListsRepository extends Mock
    implements PeopleListsRepository {}

// Synthetic complete keys; no real accounts are used.
final String _owner = 'a' * 64;
final String _foreignOwner = 'b' * 64;
Widget? _selected;

final ProviderFamily<GoRouter, (String, bool)> _routerProvider =
    Provider.family<GoRouter, (String, bool)>((ref, args) {
      final (location, render) = args;
      final routes = listsRoutes(ref).cast<GoRoute>().map(
        (route) => GoRoute(
          path: route.path,
          name: route.name,
          redirect: route.redirect,
          builder: (context, state) {
            final widget = route.builder!(context, state);
            _selected = widget;
            return render
                ? widget
                : const Scaffold(body: Text('Selected route'));
          },
        ),
      );
      final router = GoRouter(
        initialLocation: location,
        routes: [
          GoRoute(
            path: '/home/:index',
            builder: (_, _) => const Scaffold(body: Text('Home')),
          ),
          ...routes,
        ],
      );
      ref.onDispose(router.dispose);
      return router;
    });

/// Builds an nprofile with a valid checksum around arbitrary TLV payloads, so a
/// test can hand the decoder a relay hint that is not valid UTF-8.
String _nprofileWithRelayBytes(String pubkeyHex, List<int> relayBytes) {
  final tlv = <int>[
    0,
    32,
    for (var i = 0; i < 64; i += 2)
      int.parse(pubkeyHex.substring(i, i + 2), radix: 16),
    1,
    relayBytes.length,
    ...relayBytes,
  ];
  return Bech32Encoder().convert(
    Bech32('nprofile', Nip19.convertBits(tlv, 8, 5, true)),
    2000,
  );
}

/// An nprofile whose first TLV entry is not a 32-byte public key.
String _nprofileWithShortKey() {
  final tlv = <int>[0, 2, 0xab, 0xcd];
  return Bech32Encoder().convert(
    Bech32('nprofile', Nip19.convertBits(tlv, 8, 5, true)),
    2000,
  );
}

UserList _list(String id, {bool editable = true}) => UserList(
  id: id,
  name: editable ? 'Own cached list' : 'Public list',
  pubkeys: const [],
  isEditable: editable,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  group('People-list author routes', () {
    late _MockPeopleListsBloc bloc;
    late _MockPeopleListsRepository repository;
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
      _selected = null;
      bloc = _MockPeopleListsBloc();
      repository = _MockPeopleListsRepository();
    });

    void publicListAvailable(String id) {
      when(
        () =>
            repository.fetchPublicList(ownerPubkey: _foreignOwner, listId: id),
      ).thenAnswer((_) async => _list(id, editable: false));
    }

    Future<void> pumpRoute(
      WidgetTester tester,
      String location, {
      bool render = false,
      String listId = 'crew',
      bool enabled = true,
      PeopleListsState? initialState,
    }) async {
      whenListen(
        bloc,
        const Stream<PeopleListsState>.empty(),
        initialState:
            initialState ??
            PeopleListsState(
              status: PeopleListsStatus.ready,
              ownerPubkey: _owner,
              lists: [_list(listId)],
            ),
      );
      final auth = createMockAuthService();
      when(() => auth.currentPublicKeyHex).thenReturn(_owner);
      await tester.pumpWidget(
        testProviderScope(
          mockAuthService: auth,
          additionalOverrides: [
            isFeatureEnabledProvider(
              FeatureFlag.curatedLists,
            ).overrideWith((ref) => enabled),
            peopleListsRepositoryProvider.overrideWithValue(repository),
          ],
          child: BlocProvider<PeopleListsBloc>.value(
            value: bloc,
            child: Consumer(
              builder: (context, ref, child) => MaterialApp.router(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                locale: const Locale('en'),
                routerConfig: ref.watch(_routerProvider((location, render))),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    testWidgets('opens the owned list editor with its current name', (
      tester,
    ) async {
      await pumpRoute(tester, '/people-lists/crew/edit', render: true);
      expect(find.text(strings.listEditTitle), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Own cached list'),
        findsOneWidget,
      );
    });

    testWidgets('editor reports missing list only after owner read settles', (
      tester,
    ) async {
      await pumpRoute(
        tester,
        '/people-lists/crew/edit',
        render: true,
        initialState: PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: _owner,
        ),
      );
      expect(find.text(strings.peopleListsListNotFoundTitle), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
    });

    testWidgets('editor exposes retry after failed owner read', (tester) async {
      await pumpRoute(
        tester,
        '/people-lists/crew/edit',
        render: true,
        initialState: PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: _owner,
          ownerReadStatus: PeopleListsOwnerReadStatus.failed,
        ),
      );
      expect(find.text(strings.peopleListsLoadFailed), findsOneWidget);
      expect(find.text(strings.peopleListsListNotFoundTitle), findsNothing);
      await tester.tap(find.text(strings.peopleListsAddPeopleRetry));
      verify(() => bloc.add(const PeopleListsOwnerSyncRequested())).called(1);
    });

    testWidgets('rejects editing another owner list', (tester) async {
      await pumpRoute(
        tester,
        '/people-lists/crew/edit?owner=$_foreignOwner',
        render: true,
      );
      expect(find.byType(RouteErrorScreen), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
    });

    for (final suffix in ['', '/members', '/add-people', '/edit']) {
      for (final query in [
        'owner',
        'owner=',
        'owner=me',
        'owner=not-a-public-key',
        'owner=npub1invalid',
        'owner=${Nip19.encodePrivateKey(_owner)}',
        'owner=${NostrKeyUtils.encodePubKey('11')}',
        'owner=${NostrKeyUtils.encodePubKey(_owner).replaceFirst('npub', 'Npub')}',
        'owner=$_owner&owner=$_foreignOwner',
        'owner=$_owner&owner=$_owner',
      ]) {
        testWidgets(
          'crew$suffix?$query rejects author without own-cache fallback',
          (
            tester,
          ) async {
            await pumpRoute(
              tester,
              '/people-lists/crew$suffix?$query',
              render: true,
            );
            expect(find.byType(RouteErrorScreen), findsOneWidget);
            expect(find.byType(UserListPeopleScreen), findsNothing);
            expect(find.byType(PeopleListMembersScreen), findsNothing);
            expect(find.byType(AddPeopleToListScreen), findsNothing);
            expect(find.text('Own cached list'), findsNothing);
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

    for (final suffix in ['', '/members', '/add-people', '/edit']) {
      testWidgets(
        'crew$suffix with an nprofile whose relay hint is not UTF-8 is rejected',
        (tester) async {
          final nprofile = _nprofileWithRelayBytes(_owner, const [0xff, 0xfe]);
          await pumpRoute(
            tester,
            '/people-lists/crew$suffix?owner=$nprofile',
            render: true,
          );
          expect(find.byType(RouteErrorScreen), findsOneWidget);
          expect(find.text('Own cached list'), findsNothing);
          verifyNever(
            () => repository.fetchPublicList(
              ownerPubkey: any(named: 'ownerPubkey'),
              listId: any(named: 'listId'),
            ),
          );
        },
      );
    }

    for (final suffix in ['', '/members']) {
      for (final upper in [false, true]) {
        testWidgets(
          'crew$suffix accepts a valid ${upper ? 'uppercase ' : ''}nprofile '
          'author and resolves its public list',
          (tester) async {
            publicListAvailable('crew');
            final nprofile = _nprofileWithRelayBytes(
              _foreignOwner,
              'wss://relay.example'.codeUnits,
            );
            await pumpRoute(
              tester,
              '/people-lists/crew$suffix'
              '?owner=${upper ? nprofile.toUpperCase() : nprofile}',
              render: true,
            );
            expect(find.byType(RouteErrorScreen), findsNothing);
            verify(
              () => repository.fetchPublicList(
                ownerPubkey: _foreignOwner,
                listId: 'crew',
              ),
            ).called(1);
          },
        );
      }
    }

    testWidgets('an nprofile whose key is not 32 bytes is rejected', (
      tester,
    ) async {
      await pumpRoute(
        tester,
        '/people-lists/crew?owner=${_nprofileWithShortKey()}',
        render: true,
      );
      expect(find.byType(RouteErrorScreen), findsOneWidget);
      verifyNever(
        () => repository.fetchPublicList(
          ownerPubkey: any(named: 'ownerPubkey'),
          listId: any(named: 'listId'),
        ),
      );
    });

    testWidgets('absent author retains the legacy own-list route', (
      tester,
    ) async {
      await pumpRoute(tester, '/people-lists/crew', render: true);
      expect(
        find.byTooltip(strings.peopleListsAddPeopleTooltip),
        findsOneWidget,
      );
      expect((_selected! as UserListPeopleScreen).ownerPubkey, isNull);
    });

    for (final encodedOwner in [
      _owner,
      _owner.toUpperCase(),
      NostrKeyUtils.encodePubKey(_owner),
      NostrKeyUtils.encodePubKey(_owner).toUpperCase(),
    ]) {
      for (final suffix in ['', '/members']) {
        testWidgets(
          'own author $encodedOwner on $suffix retains owner controls',
          (
            tester,
          ) async {
            await pumpRoute(
              tester,
              '/people-lists/crew$suffix?owner=$encodedOwner',
              render: true,
            );
            expect(
              find.byTooltip(strings.peopleListsAddPeopleTooltip),
              findsOneWidget,
            );
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
        'own addressed picker accepts canonical author $encodedOwner',
        (
          tester,
        ) async {
          await pumpRoute(
            tester,
            '/people-lists/crew/add-people?owner=$encodedOwner',
          );
          expect(_selected, isA<AddPeopleToListScreen>());
        },
      );
    }

    for (final suffix in ['', '/members']) {
      testWidgets('foreign author on $suffix resolves public list read-only', (
        tester,
      ) async {
        publicListAvailable('crew');
        await pumpRoute(
          tester,
          '/people-lists/crew$suffix?owner=${NostrKeyUtils.encodePubKey(_foreignOwner)}',
          render: true,
        );
        expect(
          find.byTooltip(strings.peopleListsAddPeopleTooltip),
          findsNothing,
        );
        expect(find.byTooltip(strings.peopleListsActionsTooltip), findsNothing);
        expect(find.text('Own cached list'), findsNothing);
        expect(find.text('Public list'), findsWidgets);
        verify(
          () => repository.fetchPublicList(
            ownerPubkey: _foreignOwner,
            listId: 'crew',
          ),
        ).called(1);
      });
    }

    testWidgets('foreign picker author never selects own colliding list', (
      tester,
    ) async {
      await pumpRoute(
        tester,
        '/people-lists/crew/add-people?owner=$_foreignOwner',
        render: true,
      );
      expect(find.byType(RouteErrorScreen), findsOneWidget);
      expect(find.byType(AddPeopleToListScreen), findsNothing);
    });

    testWidgets('unqualified new remains creation and keeps initial member', (
      tester,
    ) async {
      await pumpRoute(tester, '/people-lists/new?initialPubkey=$_foreignOwner');
      expect(_selected, isA<CreatePeopleListPage>());
      expect((_selected! as CreatePeopleListPage).initialPubkey, _foreignOwner);
      expect(parseRoute('/people-lists/new').type, RouteType.peopleListCreate);
    });

    testWidgets('addressed new selects its public d-tag, not creation', (
      tester,
    ) async {
      publicListAvailable('new');
      final location = RoutePaths.peopleListForId(
        'new',
        ownerPubkey: _foreignOwner,
      );
      await pumpRoute(tester, location, render: true, listId: 'new');
      expect(find.byType(UserListPeopleScreen), findsOneWidget);
      expect(find.byType(CreatePeopleListPage), findsNothing);
      expect(parseRoute(location).type, RouteType.peopleListMembers);
      expect(parseRoute(location).listId, 'new');
      verify(
        () => repository.fetchPublicList(
          ownerPubkey: _foreignOwner,
          listId: 'new',
        ),
      ).called(1);
    });

    testWidgets('addressed new stays behind the people-list feature flag', (
      tester,
    ) async {
      await pumpRoute(
        tester,
        RoutePaths.peopleListForId('new', ownerPubkey: _foreignOwner),
        render: true,
        listId: 'new',
        enabled: false,
      );
      expect(find.text('Home'), findsOneWidget);
      expect(find.byType(UserListPeopleScreen), findsNothing);
      verifyNever(
        () => repository.fetchPublicList(
          ownerPubkey: any(named: 'ownerPubkey'),
          listId: any(named: 'listId'),
        ),
      );
    });

    testWidgets('new with explicitly empty author does not become creation', (
      tester,
    ) async {
      await pumpRoute(
        tester,
        '/people-lists/new?owner=',
        render: true,
        listId: 'new',
      );
      expect(find.byType(RouteErrorScreen), findsOneWidget);
      expect(find.byType(CreatePeopleListPage), findsNothing);
    });

    for (final id in ['members', 'add-people', 'edit', 'a b/c%d?雪', '%2F']) {
      testWidgets(
        'list d-tag $id roundtrips without route collision or double decoding',
        (
          tester,
        ) async {
          await pumpRoute(tester, RoutePaths.peopleListForId(id), listId: id);
          expect(_selected, isA<UserListPeopleScreen>());
          expect((_selected! as UserListPeopleScreen).listId, id);
          await pumpRoute(
            tester,
            RoutePaths.peopleListMembersForId(id),
            listId: id,
          );
          expect(_selected, isA<PeopleListMembersScreen>());
          expect((_selected! as PeopleListMembersScreen).listId, id);
          await pumpRoute(
            tester,
            RoutePaths.peopleListAddPeopleForId(id),
            listId: id,
          );
          expect(_selected, isA<AddPeopleToListScreen>());
          expect((_selected! as AddPeopleToListScreen).listId, id);
          await pumpRoute(
            tester,
            RoutePaths.peopleListEditForId(id),
            listId: id,
          );
          expect(_selected, isA<EditPeopleListPage>());
          expect((_selected! as EditPeopleListPage).listId, id);
          expect(parseRoute(RoutePaths.peopleListEditForId(id)).listId, id);
          expect(
            buildRoute(
              RouteContext(type: RouteType.peopleListEdit, listId: id),
            ),
            RoutePaths.peopleListEditForId(id),
          );

          expect(
            parseRoute(RoutePaths.peopleListAddPeopleForId(id)).listId,
            id,
          );
          expect(
            buildRoute(
              RouteContext(type: RouteType.peopleListAddPeople, listId: id),
            ),
            RoutePaths.peopleListAddPeopleForId(id),
          );
        },
      );
    }
  });
}

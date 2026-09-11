import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/people_lists/people_lists.dart';
import 'package:openvine/features/people_lists/view/people_list_member_tile.dart';
import 'package:openvine/features/people_lists/view/people_list_members_screen.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:profile_repository/profile_repository.dart';

import '../../../helpers/test_provider_overrides.dart';

class _MockPeopleListsBloc extends MockBloc<PeopleListsEvent, PeopleListsState>
    implements PeopleListsBloc {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

// Full-length 64-char pubkeys — never truncate.
final String _ownerPubkey = 'f' * 64;
final String _otherOwnerPubkey = '0' * 64;
final String _quiet = 'a' * 64;
final String _busy = 'b' * 64;
final String _busiest = 'c' * 64;

UserList _list({
  String id = 'crew',
  List<String>? pubkeys,
  bool isEditable = true,
}) {
  final now = DateTime.utc(2026);
  return UserList(
    id: id,
    name: 'Approved',
    pubkeys: pubkeys ?? [_quiet, _busy, _busiest],
    createdAt: now,
    updatedAt: now,
    isEditable: isEditable,
  );
}

UserProfileFound _found(String pubkey, {required int videos}) =>
    UserProfileFound(
      profile: UserProfileData(pubkey: pubkey),
      stats: ProfileStatsData(videoCount: videos, reactionCount: 0),
    );

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  late _MockPeopleListsBloc bloc;
  late _MockProfileRepository profileRepository;
  late List<String> pushedLocations;

  setUp(() {
    bloc = _MockPeopleListsBloc();
    profileRepository = _MockProfileRepository();
    pushedLocations = [];
    when(() => profileRepository.getBulkProfilesFromApi(any())).thenAnswer(
      (_) async => BulkProfilesResponse(
        profiles: {
          _quiet: _found(_quiet, videos: 1),
          _busy: _found(_busy, videos: 20),
          _busiest: _found(_busiest, videos: 300),
        },
      ),
    );
  });

  Future<void> pumpRoster(
    WidgetTester tester, {
    required PeopleListsState blocState,
    String listId = 'crew',
    String? ownerPubkey,
    List<Override> overrides = const [],
  }) async {
    whenListen(
      bloc,
      const Stream<PeopleListsState>.empty(),
      initialState: blocState,
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => PeopleListMembersScreen(
            listId: listId,
            ownerPubkey: ownerPubkey,
          ),
        ),
        GoRoute(
          path: '/profile-view/:npub',
          builder: (context, state) {
            pushedLocations.add(state.uri.toString());
            return const Scaffold(body: Text('profile'));
          },
        ),
        GoRoute(
          path: '/people-lists/:listId/add-people',
          builder: (context, state) {
            pushedLocations.add(state.uri.toString());
            return const Scaffold(body: Text('add people'));
          },
        ),
      ],
    );
    await tester.pumpWidget(
      testProviderScope(
        additionalOverrides: [
          profileRepositoryProvider.overrideWithValue(profileRepository),
          ...overrides,
        ],
        child: BlocProvider<PeopleListsBloc>.value(
          value: bloc,
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  List<String> rosterOrder(WidgetTester tester) => tester
      .widgetList<PeopleListMemberTile>(find.byType(PeopleListMemberTile))
      .map((tile) => tile.pubkey)
      .toList();

  group(PeopleListMembersScreen, () {
    test('exposes route name and path constants', () {
      expect(PeopleListMembersScreen.routeName, equals('people-list-roster'));
      expect(
        PeopleListMembersScreen.path,
        equals('/people-lists/:listId/members'),
      );
    });

    group('renders', () {
      testWidgets("the viewer's own list, members ranked by video count", (
        tester,
      ) async {
        await pumpRoster(
          tester,
          blocState: PeopleListsState(
            status: PeopleListsStatus.ready,
            ownerPubkey: _ownerPubkey,
            lists: [_list()],
          ),
        );

        expect(find.text('Approved'), findsOneWidget);
        expect(find.text(l10n.peopleListsPeopleCount(3)), findsOneWidget);
        expect(rosterOrder(tester), equals([_busiest, _busy, _quiet]));
        expect(
          tester
              .widgetList<PeopleListMemberTile>(
                find.byType(PeopleListMemberTile),
              )
              .every((tile) => tile.canRemove),
          isTrue,
        );
      });

      testWidgets('a discovered list read-only, resolved from relays', (
        tester,
      ) async {
        final list = _list(isEditable: false);
        await pumpRoster(
          tester,
          blocState: PeopleListsState(
            status: PeopleListsStatus.ready,
            ownerPubkey: _ownerPubkey,
          ),
          ownerPubkey: _otherOwnerPubkey,
          overrides: [
            publicPeopleListProvider(
              ownerPubkey: _otherOwnerPubkey,
              listId: 'crew',
            ).overrideWith((ref) async => list),
          ],
        );

        expect(rosterOrder(tester), equals([_busiest, _busy, _quiet]));
        expect(
          tester
              .widgetList<PeopleListMemberTile>(
                find.byType(PeopleListMemberTile),
              )
              .any((tile) => tile.canRemove),
          isFalse,
        );
        expect(find.byTooltip(l10n.peopleListsAddPeopleTooltip), findsNothing);
      });

      testWidgets('the list order while stats are unavailable', (
        tester,
      ) async {
        when(
          () => profileRepository.getBulkProfilesFromApi(any()),
        ).thenAnswer((_) async => null);
        await pumpRoster(
          tester,
          blocState: PeopleListsState(
            status: PeopleListsStatus.ready,
            ownerPubkey: _ownerPubkey,
            lists: [_list()],
          ),
        );

        expect(rosterOrder(tester), equals([_quiet, _busy, _busiest]));
      });

      testWidgets('the empty state for a list with no members', (
        tester,
      ) async {
        await pumpRoster(
          tester,
          blocState: PeopleListsState(
            status: PeopleListsStatus.ready,
            ownerPubkey: _ownerPubkey,
            lists: [_list(pubkeys: const [])],
          ),
        );

        expect(find.text(l10n.peopleListsNoPeopleTitle), findsOneWidget);
        expect(find.byType(PeopleListMemberTile), findsNothing);
      });

      testWidgets('not found when the list is not in the bloc', (
        tester,
      ) async {
        await pumpRoster(
          tester,
          blocState: PeopleListsState(
            status: PeopleListsStatus.ready,
            ownerPubkey: _ownerPubkey,
          ),
        );

        expect(find.text(l10n.peopleListsListNotFoundTitle), findsOneWidget);
      });
    });

    group('navigation', () {
      testWidgets('tapping a member opens their profile', (tester) async {
        await pumpRoster(
          tester,
          blocState: PeopleListsState(
            status: PeopleListsStatus.ready,
            ownerPubkey: _ownerPubkey,
            lists: [_list()],
          ),
        );

        await tester.tap(find.byType(PeopleListMemberTile).first);
        await tester.pumpAndSettle();
        expect(pushedLocations, hasLength(1));
        expect(pushedLocations.single, startsWith('/profile-view/npub1'));
      });

      testWidgets('the add-people action opens the picker for the owner', (
        tester,
      ) async {
        await pumpRoster(
          tester,
          blocState: PeopleListsState(
            status: PeopleListsStatus.ready,
            ownerPubkey: _ownerPubkey,
            lists: [_list()],
          ),
        );

        await tester.tap(find.byTooltip(l10n.peopleListsAddPeopleTooltip));
        await tester.pumpAndSettle();

        expect(pushedLocations, equals(['/people-lists/crew/add-people']));
      });
    });
  });
}

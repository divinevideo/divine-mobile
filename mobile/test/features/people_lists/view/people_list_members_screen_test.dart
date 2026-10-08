import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/people_lists/people_lists.dart';
import 'package:openvine/features/people_lists/view/people_list_member_avatar.dart';
import 'package:openvine/features/people_lists/view/people_list_member_tile.dart';
import 'package:openvine/features/people_lists/view/people_list_members_screen.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/nip05_verification_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
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
      stats: ProfileStatsData(
        videoCount: videos + 10,
        reactionCount: 0,
        verticalVideos: videos,
      ),
    );

void main() {
  setUpAll(
    () => registerFallbackValue(
      PeopleListsPubkeyRemoveRequested(listId: 'crew', pubkey: _quiet),
    ),
  );
  final l10n = lookupAppLocalizations(const Locale('en'));

  late _MockPeopleListsBloc bloc;
  late _MockProfileRepository profileRepository;
  late List<String> pushedLocations;

  setUp(() {
    bloc = _MockPeopleListsBloc();
    when(() => bloc.submit(any()))
        .thenAnswer((_) async => PeopleListsOperationResult.succeeded);
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
    Stream<PeopleListsState>? blocStream,
  }) async {
    whenListen(
      bloc,
      blocStream ?? const Stream<PeopleListsState>.empty(),
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
            localizationsDelegates: appLocalizationsDelegates,
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
    testWidgets(
      'membership replacement preserves roster scroll',
      (tester) async {
        final updates = StreamController<PeopleListsState>.broadcast();
        addTearDown(updates.close);
        final members = List.generate(
          40,
          (index) => index.toRadixString(16).padLeft(64, '0'),
        );
        when(() => profileRepository.getBulkProfilesFromApi(any()))
            .thenAnswer((_) async => null);
        await pumpRoster(
          tester,
          blocState: PeopleListsState(
            status: PeopleListsStatus.ready,
            ownerPubkey: _ownerPubkey,
            lists: [_list(pubkeys: members)],
          ),
          blocStream: updates.stream,
        );
        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(
          tester
              .state<ScrollableState>(find.byType(Scrollable))
              .position
              .pixels,
          greaterThan(0),
        );
        updates.add(
          PeopleListsState(
            status: PeopleListsStatus.ready,
            ownerPubkey: _ownerPubkey,
            lists: [_list(pubkeys: members.skip(1).toList())],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(l10n.peopleListsPeopleCount(39)), findsOneWidget);
        expect(
          tester
              .state<ScrollableState>(find.byType(Scrollable))
              .position
              .pixels,
          greaterThan(0),
        );
      },
    );

    testWidgets(
      'review regression roster retry stays visibly loading until settled',
      (tester) async {
        var attempts = 0;
        final pending = Completer<UserList?>();
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
            ).overrideWith((ref) async {
              attempts++;
              if (attempts == 1) throw Exception('offline');
              return pending.future;
            }),
          ],
        );
        await tester.pump();
        await tester.tap(find.text(l10n.commonRetry));
        await tester.pump();
        await tester.pump();
        expect(attempts, 2);
        expect(find.byType(DivineCircularProgressIndicator), findsOneWidget);
        pending.complete(_list(isEditable: false));
        await tester.pump();
        await tester.pump();
        expect(find.text('Approved'), findsOneWidget);
      },
    );

    testWidgets(
      'review regression roster hides vanished identity and photograph',
      (tester) async {
        final profile = UserProfile(
          pubkey: _quiet,
          displayName: 'Stale identity',
          nip05: '_@stale.divine.video',
          picture: 'https://example.invalid/stale.png',
          rawData: const {},
          createdAt: DateTime(2026),
          eventId: 'e' * 64,
        );
        await pumpRoster(
          tester,
          blocState: PeopleListsState(
            status: PeopleListsStatus.ready,
            ownerPubkey: _ownerPubkey,
            lists: [
              _list(pubkeys: [_quiet]),
            ],
          ),
          overrides: [
            userProfileReactiveProvider(_quiet)
                .overrideWith((ref) => Stream.value(profile)),
            profileVanishedProvider(_quiet).overrideWith((ref) => true),
            nip05VerificationProvider(_quiet)
                .overrideWith((ref) async => Nip05VerificationStatus.verified),
          ],
        );
        await tester.pump();
        expect(find.text('Stale identity'), findsNothing);
        expect(find.text(l10n.profileDeletedAccountName), findsOneWidget);
        expect(find.text('@stale'), findsNothing);
        expect(
          tester
              .widget<PeopleListMemberAvatar>(
                find.byType(PeopleListMemberAvatar),
              )
              .pictureUrl,
          isNull,
        );
      },
    );

    for (final status in [
      Nip05VerificationStatus.failed,
      Nip05VerificationStatus.error,
      Nip05VerificationStatus.pending,
      Nip05VerificationStatus.verified,
    ]) {
      testWidgets(
        'review regression roster NIP05 handles follow verification status $status',
        (tester) async {
          final profile = UserProfile(
            pubkey: _quiet,
            displayName: 'Live identity',
            nip05: '_@claimed.divine.video',
            rawData: const {},
            createdAt: DateTime(2026),
            eventId: 'e' * 64,
          );
          await pumpRoster(
            tester,
            blocState: PeopleListsState(
              status: PeopleListsStatus.ready,
              ownerPubkey: _ownerPubkey,
              lists: [
                _list(pubkeys: [_quiet]),
              ],
            ),
            overrides: [
              userProfileReactiveProvider(_quiet)
                  .overrideWith((ref) => Stream.value(profile)),
              profileVanishedProvider(_quiet).overrideWith((ref) => false),
              nip05VerificationProvider(_quiet)
                  .overrideWith((ref) async => status),
            ],
          );
          await tester.pump();
          expect(
            find.text('@claimed'),
            status == Nip05VerificationStatus.failed
                ? findsNothing
                : findsOneWidget,
          );
        },
      );
    }

    testWidgets('review regression malformed member does not break roster', (
      tester,
    ) async {
      await pumpRoster(
        tester,
        blocState: PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: _ownerPubkey,
          lists: [
            _list(pubkeys: ['not-a-key']),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(PeopleListMemberTile), findsOneWidget);
    });

    testWidgets(
      'removal reports success only after confirmation and exposes failed retry',
      (tester) async {
        final pending = Completer<PeopleListsOperationResult>();
        when(() => bloc.submit(any())).thenAnswer((_) => pending.future);
        await pumpRoster(
          tester,
          blocState: PeopleListsState(
            status: PeopleListsStatus.ready,
            ownerPubkey: _ownerPubkey,
            lists: [_list()],
          ),
        );
        final row = find.byWidgetPredicate(
          (widget) => widget is PeopleListMemberTile && widget.pubkey == _quiet,
        );
        await tester.longPress(row);
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.peopleListsRemove));
        await tester.pumpAndSettle();
        expect(find.text(l10n.peopleListsUndo), findsNothing);
        pending.complete(PeopleListsOperationResult.failed);
        await tester.pumpAndSettle();
        expect(find.text(l10n.listUpdateFailed), findsOneWidget);
        expect(find.text(l10n.peopleListsUndo), findsNothing);
        when(() => bloc.submit(any()))
            .thenAnswer((_) async => PeopleListsOperationResult.succeeded);
        await tester.tap(find.text(l10n.peopleListsAddPeopleRetry));
        await tester.pumpAndSettle();
        expect(find.text(l10n.peopleListsUndo), findsOneWidget);
      },
    );

    testWidgets('review regression removal survives roster re-ranking', (
      tester,
    ) async {
      final pending = Completer<BulkProfilesResponse?>();
      when(() => profileRepository.getBulkProfilesFromApi(any()))
          .thenAnswer((_) => pending.future);
      await pumpRoster(
        tester,
        blocState: PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: _ownerPubkey,
          lists: [_list()],
        ),
      );
      final row = find.byWidgetPredicate(
        (widget) => widget is PeopleListMemberTile && widget.pubkey == _quiet,
      );
      await tester.longPress(row);
      await tester.pumpAndSettle();
      pending.complete(
        BulkProfilesResponse(
          profiles: {
            _quiet: _found(_quiet, videos: 1),
            _busy: _found(_busy, videos: 20),
            _busiest: _found(_busiest, videos: 300),
          },
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(rosterOrder(tester), [_busiest, _busy, _quiet]);
      await tester.tap(find.text(l10n.peopleListsRemove));
      await tester.pumpAndSettle();
      verify(
        () => bloc.submit(
          PeopleListsPubkeyRemoveRequested(listId: 'crew', pubkey: _quiet),
        ),
      ).called(1);
    });

    testWidgets(
      'removal goes through when its row is disposed behind the sheet',
      (
        tester,
      ) async {
        final members = List.generate(
          40,
          (index) => index.toRadixString(16).padLeft(64, '0'),
        );
        when(() => profileRepository.getBulkProfilesFromApi(any()))
            .thenAnswer((_) async => null);
        await pumpRoster(
          tester,
          blocState: PeopleListsState(
            status: PeopleListsStatus.ready,
            ownerPubkey: _ownerPubkey,
            lists: [_list(pubkeys: members)],
          ),
        );
        Finder rowOf(String pubkey) => find.byWidgetPredicate(
          (widget) => widget is PeopleListMemberTile && widget.pubkey == pubkey,
        );
        await tester.longPress(rowOf(members.first));
        await tester.pumpAndSettle();

        final position = tester
            .state<ScrollableState>(
              find
                  .descendant(
                    of: find.byType(PeopleListMembersScreen),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            )
            .position;
        position.jumpTo(position.maxScrollExtent);
        await tester.pump();
        expect(rowOf(members.first), findsNothing);

        await tester.tap(find.text(l10n.peopleListsRemove));
        await tester.pumpAndSettle();

        verify(
          () => bloc.submit(
            PeopleListsPubkeyRemoveRequested(
              listId: 'crew',
              pubkey: members.first,
            ),
          ),
        ).called(1);
        expect(find.byType(SnackBar), findsOneWidget);
      },
    );

    testWidgets(
      'a roster row reads as one labelled button, not its text twice',
      (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await pumpRoster(
          tester,
          blocState: PeopleListsState(
            status: PeopleListsStatus.ready,
            ownerPubkey: _ownerPubkey,
            lists: [_list()],
          ),
        );

        final node = tester.getSemantics(
          find.byWidgetPredicate(
            (widget) =>
                widget is PeopleListMemberTile && widget.pubkey == _quiet,
          ),
        );

        expect(
          node.label,
          l10n.peopleListsProfileLongPressHint(
            UserProfile.defaultDisplayNameFor(_quiet),
          ),
        );
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
        expect(
          node.getSemanticsData().hasAction(SemanticsAction.longPress),
          isTrue,
        );
        SemanticsOwner? semanticsOwner;
        tester.binding.rootPipelineOwner.visitChildren((child) {
          semanticsOwner ??= child.semanticsOwner;
        });
        semanticsOwner!.performAction(
          node.id,
          SemanticsAction.longPress,
        );
        await tester.pumpAndSettle();
        expect(find.text(l10n.peopleListsRemove), findsOneWidget);
        await tester.tap(find.text(l10n.commonCancel));
        await tester.pumpAndSettle();
        semanticsOwner!.performAction(
          node.id,
          SemanticsAction.tap,
        );
        await tester.pumpAndSettle();
        expect(pushedLocations, hasLength(1));
        expect(pushedLocations.single, startsWith('/profile-view/'));
        semantics.dispose();
      },
    );

    for (final scenario
        in <
          ({
            String name,
            UserList list,
            String member,
            bool tap,
            bool longPress,
          })
        >[
          (
            name: 'a read-only list offers opening the profile but not removal',
            list: _list(isEditable: false),
            member: _quiet,
            tap: true,
            longPress: false,
          ),
          (
            name: 'a malformed member entry offers no profile action',
            list: _list(pubkeys: ['not-a-key']),
            member: 'not-a-key',
            tap: false,
            longPress: true,
          ),
        ]) {
      testWidgets(
        'a roster row only offers actions it can perform: ${scenario.name}',
        (
          tester,
        ) async {
          final semantics = tester.ensureSemantics();
          await pumpRoster(
            tester,
            blocState: PeopleListsState(
              status: PeopleListsStatus.ready,
              ownerPubkey: _ownerPubkey,
              lists: [scenario.list],
            ),
          );

          final data = tester
              .getSemantics(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is PeopleListMemberTile &&
                      widget.pubkey == scenario.member,
                ),
              )
              .getSemanticsData();
          semantics.dispose();

          expect(data.hasAction(SemanticsAction.tap), scenario.tap);
          expect(data.hasAction(SemanticsAction.longPress), scenario.longPress);
        },
      );
    }

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

      testWidgets("shows loading until the viewer's lists have arrived", (
        tester,
      ) async {
        // A cold deep link reaches the roster before the bloc has delivered
        // the viewer's lists; that is not "not found" yet.
        await pumpRoster(
          tester,
          blocState: PeopleListsState(
            status: PeopleListsStatus.loading,
            ownerPubkey: _ownerPubkey,
          ),
        );

        expect(find.byType(DivineCircularProgressIndicator), findsOneWidget);
        expect(find.text(l10n.peopleListsListNotFoundTitle), findsNothing);
      });
    });

    group('roster surface', () {
      const roundedTop = BorderRadius.vertical(
        top: Radius.circular(VineTheme.shellInnerCornerRadius),
      );

      ClipRRect clipAround(WidgetTester tester, Finder content) =>
          tester.widget<ClipRRect>(
            find.ancestor(of: content, matching: find.byType(ClipRRect)).first,
          );

      testWidgets('rounds the top corners of the member list', (tester) async {
        await pumpRoster(
          tester,
          blocState: PeopleListsState(
            status: PeopleListsStatus.ready,
            ownerPubkey: _ownerPubkey,
            lists: [_list()],
          ),
        );

        final clip = clipAround(tester, find.byType(ListView));
        expect(clip.borderRadius, roundedTop);
      });

      testWidgets('sits on the nav-colored page the bar is drawn on', (
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

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.backgroundColor, VineTheme.darkColors.nav);
        final surface = tester.widget<ColoredBox>(
          find
              .ancestor(
                of: find.byType(ListView),
                matching: find.byType(ColoredBox),
              )
              .first,
        );
        expect(surface.color, VineTheme.darkColors.surfaceContainerHigh);
      });

      testWidgets('keeps the same frame while the list loads', (tester) async {
        await pumpRoster(
          tester,
          blocState: PeopleListsState(
            status: PeopleListsStatus.loading,
            ownerPubkey: _ownerPubkey,
          ),
        );

        final clip = clipAround(
          tester,
          find.byType(DivineCircularProgressIndicator),
        );
        expect(clip.borderRadius, roundedTop);
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

    group('hidden members', () {
      late ContentBlocklistRepository blocklist;

      setUp(() {
        blocklist = ContentBlocklistRepository();
        addTearDown(blocklist.dispose);
      });

      Future<void> pumpOwnRoster(WidgetTester tester) => pumpRoster(
        tester,
        blocState: PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: _ownerPubkey,
          lists: [_list()],
        ),
        overrides: [
          contentBlocklistRepositoryProvider.overrideWithValue(blocklist),
        ],
      );

      testWidgets(
        "leaves a blocked member out of the viewer's own list, even the "
        'busiest',
        (tester) async {
          await blocklist.blockUser(_busiest);

          await pumpOwnRoster(tester);

          expect(rosterOrder(tester), equals([_busy, _quiet]));
          // The count stays list-wide, as #9740 kept it.
          expect(find.text(l10n.peopleListsPeopleCount(3)), findsOneWidget);
        },
      );

      testWidgets('drops a member blocked while the roster is open', (
        tester,
      ) async {
        await pumpOwnRoster(tester);
        expect(rosterOrder(tester), equals([_busiest, _busy, _quiet]));

        await blocklist.blockUser(_busy);
        await tester.pump();

        expect(rosterOrder(tester), equals([_busiest, _quiet]));
      });

      testWidgets('says so when every member is hidden', (tester) async {
        await blocklist.blockUsers([_quiet, _busy, _busiest]);

        await pumpOwnRoster(tester);

        expect(find.byType(PeopleListMemberTile), findsNothing);
        expect(
          find.text(l10n.peopleListsAllMembersHiddenTitle),
          findsOneWidget,
        );
        expect(find.text(l10n.peopleListsNoPeopleTitle), findsNothing);
      });
    });
  });
}

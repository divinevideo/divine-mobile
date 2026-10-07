import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/list_search/list_search_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/routes/route_extras.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/screens/search_results/widgets/lists_section.dart';
import 'package:openvine/screens/search_results/widgets/search_section_empty_state.dart';
import 'package:openvine/screens/search_results/widgets/search_section_error_state.dart';
import 'package:openvine/screens/search_results/widgets/section_header.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/divine_list_thumbnail.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

import '../../../helpers/go_router.dart';
import '../../../helpers/test_provider_overrides.dart';

class _MockListSearchBloc extends MockBloc<ListSearchEvent, ListSearchState>
    implements ListSearchBloc {}

// Full-length 64-char Nostr pubkey — never truncate.
const String _authorOne =
    '1111111111111111111111111111111111111111111111111111111111111111';

void main() {
  group(ListsSection, () {
    late _MockListSearchBloc mockBloc;

    final now = DateTime(2024, 6, 15);
    final testList = CuratedList(
      id: 'cl1',
      name: 'Top Videos',
      pubkey: _authorOne,
      videoEventIds: const ['vid1'],
      createdAt: now,
      updatedAt: now,
    );

    setUp(() {
      mockBloc = _MockListSearchBloc();
    });

    tearDown(() async {
      await mockBloc.close();
    });

    Widget buildSubject({bool showAll = false}) {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 1000,
            child: BlocProvider<ListSearchBloc>.value(
              value: mockBloc,
              child: CustomScrollView(
                slivers: [ListsSection(showAll: showAll)],
              ),
            ),
          ),
        ),
      );
    }

    for (final showAll in [false, true]) {
      testWidgets(
        'partial people failure keeps video cards (showAll: $showAll)',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            ListSearchState(
              status: ListSearchStatus.success,
              query: 'test',
              videoResults: [testList],
              videoStatus: ListSearchSourceStatus.success,
              peopleStatus: ListSearchSourceStatus.failure,
            ),
          );
          await tester.pumpWidget(
            ProviderScope(
              overrides: getStandardTestOverrides(),
              child: buildSubject(showAll: showAll),
            ),
          );
          expect(
            find.text('People lists are unavailable right now.'),
            findsOneWidget,
          );
          expect(find.text('Top Videos'), findsOneWidget);
          expect(find.byType(SearchSectionEmptyState), findsNothing);
          await tester.tap(find.text('Try again'));
          verify(() => mockBloc.add(const ListSearchRetried())).called(1);
        },
      );

      testWidgets(
        'unavailable people and empty video never claim no matches (showAll: $showAll)',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            const ListSearchState(
              status: ListSearchStatus.failure,
              query: 'test',
              videoStatus: ListSearchSourceStatus.success,
              peopleStatus: ListSearchSourceStatus.failure,
            ),
          );
          await tester.pumpWidget(buildSubject(showAll: showAll));
          expect(
            find.text('People lists are unavailable right now.'),
            findsOneWidget,
          );
          expect(find.byType(SearchSectionEmptyState), findsNothing);
          expect(find.text('Try again'), findsOneWidget);
        },
      );
    }

    group('showAll: false (All tab preview)', () {
      testWidgets('hides entirely when success with empty results', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const ListSearchState(
            status: ListSearchStatus.success,
            query: 'test',
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.byType(SectionHeader), findsNothing);
        expect(find.byType(SearchSectionEmptyState), findsNothing);
      });

      testWidgets('renders header and content when success with results', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          ListSearchState(
            status: ListSearchStatus.success,
            query: 'test',
            videoResults: [testList],
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.byType(SectionHeader), findsOneWidget);
        expect(find.text('Lists'), findsOneWidget);
      });

      testWidgets('renders $SearchSectionErrorState on failure', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const ListSearchState(
            status: ListSearchStatus.failure,
            query: 'test',
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.byType(SearchSectionErrorState), findsOneWidget);
      });
    });

    group('showAll: true (dedicated tab)', () {
      testWidgets(
        'renders $SearchSectionEmptyState when success with empty results',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            const ListSearchState(
              status: ListSearchStatus.success,
              query: 'test',
            ),
          );

          await tester.pumpWidget(buildSubject(showAll: true));

          expect(find.byType(SearchSectionEmptyState), findsOneWidget);
        },
      );

      testWidgets(
        'renders $SearchSectionErrorState on failure',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            const ListSearchState(
              status: ListSearchStatus.failure,
              query: 'test',
            ),
          );

          await tester.pumpWidget(buildSubject(showAll: true));

          expect(find.byType(SearchSectionErrorState), findsOneWidget);
        },
      );
    });

    for (final showAll in [false, true]) {
      testWidgets(
        'people result without a description does not name members (showAll: $showAll)',
        (tester) async {
          var identityReads = 0;
          final member = 'a' * 64;
          final cachedProfile = UserProfile(
            pubkey: member,
            eventId: 'e' * 64,
            createdAt: now,
            rawData: const {},
            displayName: 'Cached member',
            picture: 'https://example.com/cached-member.jpg',
          );
          when(() => mockBloc.state).thenReturn(
            ListSearchState(
              status: ListSearchStatus.success,
              query: 'test',
              peopleResults: [
                PeopleListSearchResult(
                  ownerPubkey: _authorOne,
                  list: UserList(
                    id: 'pl1',
                    name: 'Crew',
                    pubkeys: [member],
                    createdAt: now,
                    updatedAt: now,
                  ),
                ),
              ],
            ),
          );
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                ...getStandardTestOverrides(),
                fetchUserProfileProvider(member).overrideWith((ref) async {
                  identityReads++;
                  return cachedProfile;
                }),
                userProfileReactiveProvider(member).overrideWith((ref) {
                  identityReads++;
                  return Stream<UserProfile?>.value(cachedProfile);
                }),
              ],
              child: buildSubject(showAll: showAll),
            ),
          );
          await tester.pump();
          expect(identityReads, 0);
          expect(find.text('Crew'), findsOneWidget);
          expect(find.textContaining('Cached member'), findsNothing);
          expect(find.byType(UserAvatar), findsNothing);
        },
      );

      testWidgets(
        'people result navigates with owner (showAll: $showAll)',
        (tester) async {
          var identityReads = 0;
          final member = 'a' * 64;
          final description =
              'With nostr:${NostrKeyUtils.encodePubKey(member)}';
          final cachedProfile = UserProfile(
            pubkey: member,
            eventId: 'e' * 64,
            createdAt: now,
            rawData: const {},
            displayName: 'Cached member',
            picture: 'https://example.com/cached-member.jpg',
          );
          final goRouter = MockGoRouter();
          when(
            () => goRouter.push<void>(any()),
          ).thenAnswer((_) async {});
          when(() => mockBloc.state).thenReturn(
            ListSearchState(
              status: ListSearchStatus.success,
              query: 'test',
              videoResults: [testList],
              peopleResults: [
                PeopleListSearchResult(
                  ownerPubkey: _authorOne,
                  list: UserList(
                    id: 'pl1',
                    name: 'Crew',
                    description: description,
                    pubkeys: [member],
                    createdAt: now,
                    updatedAt: now,
                  ),
                ),
              ],
            ),
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                ...getStandardTestOverrides(),
                fetchUserProfileProvider(member).overrideWith((ref) async {
                  identityReads++;
                  return cachedProfile;
                }),
                userProfileReactiveProvider(member).overrideWith((ref) {
                  identityReads++;
                  return Stream<UserProfile?>.value(cachedProfile);
                }),
              ],
              child: MaterialApp(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: SizedBox(
                    width: 800,
                    height: 1000,
                    child: BlocProvider<ListSearchBloc>.value(
                      value: mockBloc,
                      child: MockGoRouterProvider(
                        goRouter: goRouter,
                        child: CustomScrollView(
                          slivers: [ListsSection(showAll: showAll)],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();

          expect(
            identityReads,
            0,
            reason: 'Public search cards must not resolve member identities.',
          );
          expect(find.byType(DivineListThumbnail), findsNWidgets(2));
          expect(find.text('Crew'), findsOneWidget);
          expect(find.text(description), findsOneWidget);
          expect(find.textContaining('Cached member'), findsNothing);
          expect(find.byType(UserAvatar), findsNothing);

          await tester.tap(find.text(description));

          verify(
            () => goRouter.push<void>('/people-lists/pl1?owner=$_authorOne'),
          ).called(1);
        },
      );
    }

    group('video list result navigation', () {
      late MockGoRouter goRouter;

      setUp(() {
        goRouter = MockGoRouter();
        when(
          () => goRouter.push<void>(any(), extra: any(named: 'extra')),
        ).thenAnswer((_) async {});
      });

      Widget buildRoutedSubject({required bool showAll}) {
        return ProviderScope(
          overrides: getStandardTestOverrides(),
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 1000,
                child: BlocProvider<ListSearchBloc>.value(
                  value: mockBloc,
                  child: MockGoRouterProvider(
                    goRouter: goRouter,
                    child: CustomScrollView(
                      slivers: [ListsSection(showAll: showAll)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      for (final showAll in [false, true]) {
        testWidgets(
          'opens the author-qualified route so a lost route extra cannot '
          'change which list opens (showAll: $showAll)',
          (tester) async {
            when(() => mockBloc.state).thenReturn(
              ListSearchState(
                status: ListSearchStatus.success,
                query: 'test',
                videoResults: [testList],
              ),
            );
            await tester.pumpWidget(buildRoutedSubject(showAll: showAll));
            await tester.pump();

            await tester.tap(find.text('Top Videos'));

            final captured = verify(
              () => goRouter.push<void>(
                captureAny(),
                extra: captureAny(named: 'extra'),
              ),
            ).captured;
            expect(captured.first, equals('/list/$_authorOne/cl1'));
            expect(
              captured.last,
              isA<CuratedListRouteExtra>()
                  .having((extra) => extra.list, 'list', testList)
                  .having(
                    (extra) => extra.authorPubkey,
                    'authorPubkey',
                    _authorOne,
                  ),
            );
          },
        );

        testWidgets(
          'falls back to the list id route when the author is unknown '
          '(showAll: $showAll)',
          (tester) async {
            final unattributed = CuratedList(
              id: 'legacy',
              name: 'Legacy List',
              videoEventIds: const ['vid1'],
              createdAt: now,
              updatedAt: now,
            );
            when(() => mockBloc.state).thenReturn(
              ListSearchState(
                status: ListSearchStatus.success,
                query: 'test',
                videoResults: [unattributed],
              ),
            );
            await tester.pumpWidget(buildRoutedSubject(showAll: showAll));
            await tester.pump();

            await tester.tap(find.text('Legacy List'));

            final captured = verify(
              () => goRouter.push<void>(
                captureAny(),
                extra: captureAny(named: 'extra'),
              ),
            ).captured;
            expect(
              captured.first,
              equals(CuratedListFeedScreen.pathForId('legacy')),
            );
          },
        );
      }
    });

    testWidgets('retry dispatches $ListSearchQueryChanged with current query', (
      tester,
    ) async {
      when(() => mockBloc.state).thenReturn(
        const ListSearchState(
          status: ListSearchStatus.failure,
          query: 'retry-test',
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      verify(
        () => mockBloc.add(const ListSearchQueryChanged('retry-test')),
      ).called(1);
    });
  });
}

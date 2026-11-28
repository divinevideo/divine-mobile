import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:clock/clock.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/generated/app_localizations_en.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/search_results/widgets/people_section.dart';
import 'package:openvine/screens/search_results/widgets/search_section_empty_state.dart';
import 'package:openvine/screens/search_results/widgets/search_section_error_state.dart';
import 'package:openvine/screens/search_results/widgets/search_user_tile.dart';
import 'package:openvine/screens/search_results/widgets/section_header.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:user_ranking/user_ranking.dart';

import '../../../helpers/test_provider_overrides.dart';

class _MockUserSearchBloc extends MockBloc<UserSearchEvent, UserSearchState>
    implements UserSearchBloc {}

Finder _divineIcon(DivineIconName name) =>
    find.byWidgetPredicate((w) => w is DivineIcon && w.icon == name);

void main() {
  group(PeopleSection, () {
    late _MockUserSearchBloc mockBloc;

    final testProfile = UserProfile(
      pubkey:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      name: 'Test User',
      rawData: const <String, dynamic>{},
      createdAt: DateTime(2024),
      eventId: 'event1',
    );

    final secondProfile = UserProfile(
      pubkey:
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      name: 'Second User',
      rawData: const <String, dynamic>{},
      createdAt: DateTime(2024),
      eventId: 'event2',
    );

    setUp(() {
      mockBloc = _MockUserSearchBloc();
    });

    tearDown(() async {
      await mockBloc.close();
    });

    Widget buildSubject({bool showAll = false}) {
      return testProviderScope(
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider<UserSearchBloc>.value(
              value: mockBloc,
              child: CustomScrollView(
                slivers: [PeopleSection(showAll: showAll)],
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders cached ranking activity on search results', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      when(() => mockBloc.state).thenReturn(
        UserSearchState(
          status: UserSearchStatus.success,
          results: [testProfile],
          rankingSignals: {
            testProfile.pubkey: UserRankingSignals(
              pubkey: testProfile.pubkey,
              videoCount: 18,
              lastPostedAt: clock.now().subtract(const Duration(hours: 2)),
            ),
          },
        ),
      );
      await tester.pumpWidget(buildSubject());
      await tester.pump();
      expect(
        find.textContaining(l10n.searchUserVideoCount(18, '18')),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          l10n.userRowPosted(l10n.timeAgo(l10n.timeShortHours(2))),
        ),
        findsOneWidget,
      );
    });

    group('showAll: false (All tab preview)', () {
      testWidgets('hides entirely when success with empty results', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const UserSearchState(
            status: UserSearchStatus.success,
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
          UserSearchState(
            status: UserSearchStatus.success,
            query: 'test',
            results: [testProfile],
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.byType(SectionHeader), findsOneWidget);
        expect(
          find.text(AppLocalizationsEn().searchPeopleSectionHeader),
          findsOneWidget,
        );
      });

      testWidgets('anchors the header and each row for UI tests', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          UserSearchState(
            status: UserSearchStatus.success,
            query: 'test',
            results: [testProfile, secondProfile],
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(
          find.bySemanticsIdentifier(
            SemanticIds.searchSectionHeader('people'),
          ),
          findsOneWidget,
        );
        // Ordinal anchors let a flow tap "the first result" without knowing
        // a pubkey up front; the pubkey-keyed anchor stays for targeted taps.
        expect(
          find.bySemanticsIdentifier(SemanticIds.searchUserTileAt(0)),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier(SemanticIds.searchUserTileAt(1)),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('search_user_tile_${testProfile.pubkey}'),
          findsOneWidget,
        );
      });

      testWidgets(
        'shows add-to-list action on search user tiles',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            UserSearchState(
              status: UserSearchStatus.success,
              query: 'test',
              results: [testProfile],
            ),
          );

          await tester.pumpWidget(
            testProviderScope(
              child: MaterialApp(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: BlocProvider<UserSearchBloc>.value(
                    value: mockBloc,
                    child: const CustomScrollView(
                      slivers: [PeopleSection()],
                    ),
                  ),
                ),
              ),
            ),
          );

          expect(_divineIcon(DivineIconName.listPlus), findsOneWidget);
        },
      );

      testWidgets('renders $SearchSectionErrorState on failure', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const UserSearchState(
            status: UserSearchStatus.failure,
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
            const UserSearchState(
              status: UserSearchStatus.success,
              query: 'test',
            ),
          );

          await tester.pumpWidget(buildSubject(showAll: true));

          expect(find.byType(SearchSectionEmptyState), findsOneWidget);
        },
      );

      testWidgets('renders $SearchSectionErrorState on failure', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const UserSearchState(
            status: UserSearchStatus.failure,
            query: 'test',
          ),
        );

        await tester.pumpWidget(buildSubject(showAll: true));

        expect(find.byType(SearchSectionErrorState), findsOneWidget);
      });
    });

    group('degraded-empty (#3791)', () {
      const failedRelay = UserSearchState(
        status: UserSearchStatus.success,
        query: 'friend-name',
        sourceOutcomes: {
          SearchSource.nip50Relay: SearchSourceFailed(
            reason: SearchSourceFailureReason.timeout,
            latencyMs: 5000,
          ),
        },
      );

      const allSucceeded = UserSearchState(
        status: UserSearchStatus.success,
        query: 'friend-name',
        sourceOutcomes: {
          SearchSource.localCache: SearchSourceSuccess(
            resultCount: 0,
            latencyMs: 1,
          ),
          SearchSource.funnelcakeApi: SearchSourceSuccess(
            resultCount: 0,
            latencyMs: 50,
          ),
          SearchSource.nip50Relay: SearchSourceSuccess(
            resultCount: 0,
            latencyMs: 500,
          ),
        },
      );

      testWidgets(
        'renders $SearchSectionErrorState when results empty AND a source '
        'failed (degraded-empty)',
        (tester) async {
          when(() => mockBloc.state).thenReturn(failedRelay);

          await tester.pumpWidget(buildSubject(showAll: true));

          expect(find.byType(SearchSectionErrorState), findsOneWidget);
          expect(find.byType(SearchSectionEmptyState), findsNothing);
        },
      );

      testWidgets(
        'renders $SearchSectionEmptyState when results empty AND all '
        'sources succeeded (true empty)',
        (tester) async {
          when(() => mockBloc.state).thenReturn(allSucceeded);

          await tester.pumpWidget(buildSubject(showAll: true));

          expect(find.byType(SearchSectionEmptyState), findsOneWidget);
          expect(find.byType(SearchSectionErrorState), findsNothing);
        },
      );

      testWidgets(
        'shows section header and error in All tab preview when '
        'degraded-empty (so user sees retry instead of hidden section)',
        (tester) async {
          when(() => mockBloc.state).thenReturn(failedRelay);

          await tester.pumpWidget(buildSubject());

          expect(find.byType(SectionHeader), findsOneWidget);
          expect(find.byType(SearchSectionErrorState), findsOneWidget);
        },
      );

      testWidgets(
        'hides section entirely in All tab preview when truly empty',
        (tester) async {
          when(() => mockBloc.state).thenReturn(allSucceeded);

          await tester.pumpWidget(buildSubject());

          expect(find.byType(SectionHeader), findsNothing);
          expect(find.byType(SearchSectionErrorState), findsNothing);
        },
      );
    });

    testWidgets('retry dispatches $UserSearchQueryChanged with current query', (
      tester,
    ) async {
      when(() => mockBloc.state).thenReturn(
        const UserSearchState(
          status: UserSearchStatus.failure,
          query: 'retry-test',
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      verify(
        () => mockBloc.add(const UserSearchQueryChanged('retry-test')),
      ).called(1);
    });

    group('loading', () {
      testWidgets(
        'renders demo $SearchUserTile rows inside a $Skeletonizer, '
        'announcing only the loading label',
        (tester) async {
          final semantics = tester.ensureSemantics();
          when(() => mockBloc.state).thenReturn(
            const UserSearchState(
              status: UserSearchStatus.loading,
              query: 'alice',
            ),
          );

          await tester.pumpWidget(buildSubject());

          final skeleton = find.bySubtype<Skeletonizer>();
          expect(skeleton, findsOneWidget);
          expect(
            find.descendant(
              of: skeleton,
              matching: find.byType(SearchUserTile),
            ),
            findsNWidgets(3),
          );
          expect(
            find.bySemanticsLabel(
              AppLocalizationsEn().searchPeopleLoadingLabel,
            ),
            findsOneWidget,
          );
          expect(
            find.bySemanticsLabel(RegExp('Demo Display Name')),
            findsNothing,
          );

          semantics.dispose();
        },
      );

      group('when results arrive', () {
        late StreamController<UserSearchState> states;

        setUp(() {
          states = StreamController<UserSearchState>();
          whenListen(
            mockBloc,
            states.stream,
            initialState: const UserSearchState(
              status: UserSearchStatus.loading,
              query: 'test',
            ),
          );
        });

        tearDown(() => states.close());

        Future<void> deliverResults(WidgetTester tester) async {
          states.add(
            UserSearchState(
              status: UserSearchStatus.success,
              query: 'test',
              results: [testProfile],
            ),
          );
          await tester.pump();
        }

        testWidgets('cross-fades the skeleton into the loaded rows', (
          tester,
        ) async {
          await tester.pumpWidget(buildSubject());
          expect(find.byType(SearchUserTile), findsNWidgets(3));

          await deliverResults(tester);

          // Mid-fade: the outgoing skeleton rows and the incoming row.
          expect(find.byType(SearchUserTile), findsNWidgets(4));

          // Past the 90 ms fade, which starts on the frame after the rebuild.
          await tester.pump(const Duration(milliseconds: 250));

          expect(find.byType(SearchUserTile), findsOneWidget);
          expect(find.text('Test User'), findsOneWidget);
        });

        testWidgets('swaps without a fade when animations are disabled', (
          tester,
        ) async {
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(disableAnimations: true);
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
          await tester.pumpWidget(buildSubject());

          await deliverResults(tester);
          await tester.pump();

          expect(find.byType(SearchUserTile), findsOneWidget);
        });
      });
    });

    group('loading more indicator', () {
      testWidgets('shows loading indicator when showAll and isLoadingMore', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          UserSearchState(
            status: UserSearchStatus.success,
            results: [testProfile],
            hasMore: true,
            isLoadingMore: true,
          ),
        );

        await tester.pumpWidget(buildSubject(showAll: true));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets(
        'hides loading indicator when showAll and not isLoadingMore',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            UserSearchState(
              status: UserSearchStatus.success,
              results: [testProfile],
            ),
          );

          await tester.pumpWidget(buildSubject(showAll: true));

          expect(find.byType(CircularProgressIndicator), findsNothing);
        },
      );

      testWidgets('does not show loading indicator when not showAll', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          UserSearchState(
            status: UserSearchStatus.success,
            results: [testProfile],
            isLoadingMore: true,
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.byType(CircularProgressIndicator), findsNothing);
      });
    });
  });
}

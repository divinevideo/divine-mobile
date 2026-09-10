import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/l10n/generated/app_localizations_en.dart';
import 'package:openvine/screens/search_results/widgets/people_section.dart';
import 'package:openvine/screens/search_results/widgets/search_section_empty_state.dart';
import 'package:openvine/screens/search_results/widgets/search_section_error_state.dart';
import 'package:openvine/screens/search_results/widgets/section_header.dart';
import 'package:profile_repository/profile_repository.dart';

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

    tearDown(() {
      mockBloc.close();
    });

    Widget buildSubject({bool showAll = false}) {
      return testProviderScope(
        additionalOverrides: [
          isFeatureEnabledProvider(
            FeatureFlag.profileListFeatures,
          ).overrideWithValue(false),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
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
        'hides add-to-list action on search user tiles when profile list '
        'features flag is disabled',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            UserSearchState(
              status: UserSearchStatus.success,
              query: 'test',
              results: [testProfile],
            ),
          );

          await tester.pumpWidget(buildSubject());

          expect(_divineIcon(DivineIconName.listPlus), findsNothing);
        },
      );

      testWidgets(
        'shows add-to-list action on search user tiles when profile list '
        'features flag is enabled',
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
              additionalOverrides: [
                isFeatureEnabledProvider(
                  FeatureFlag.profileListFeatures,
                ).overrideWithValue(true),
              ],
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
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

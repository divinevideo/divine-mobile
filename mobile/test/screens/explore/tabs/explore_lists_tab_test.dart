// ABOUTME: Tests for the Explore Lists discovery gallery view: two
// ABOUTME: independent columns, per-column loading/error, empty state,
// ABOUTME: and card navigation.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/lists_discovery/cubit/lists_discovery_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/explore/tabs/explore_lists_tab.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/divine_list_thumbnail.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

import '../../../helpers/go_router.dart';
import '../../../helpers/test_provider_overrides.dart';

class _MockListsDiscoveryCubit extends MockCubit<ListsDiscoveryState>
    implements ListsDiscoveryCubit {}

final String _author = 'a' * 64;

CuratedList _videoList(String id) => CuratedList(
  id: id,
  name: 'Video $id',
  pubkey: _author,
  videoEventIds: const ['v1'],
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

PeopleListSearchResult _peopleList(String id) => PeopleListSearchResult(
  ownerPubkey: _author,
  list: UserList(
    id: id,
    name: 'People $id',
    pubkeys: [_author],
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
);

void main() {
  group(ExploreListsView, () {
    late _MockListsDiscoveryCubit cubit;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUp(() {
      cubit = _MockListsDiscoveryCubit();
    });

    Widget buildSubject({MockGoRouter? goRouter}) {
      const view = ExploreListsView();
      return ProviderScope(
        overrides: [...getStandardTestOverrides()],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider<ListsDiscoveryCubit>.value(
              value: cubit,
              child: goRouter == null
                  ? view
                  : MockGoRouterProvider(goRouter: goRouter, child: view),
            ),
          ),
        ),
      );
    }

    testWidgets('renders both columns from state', (tester) async {
      whenListen(
        cubit,
        const Stream<ListsDiscoveryState>.empty(),
        initialState: ListsDiscoveryState(
          videoStatus: ListsDiscoveryColumnStatus.success,
          peopleStatus: ListsDiscoveryColumnStatus.success,
          videoLists: [_videoList('skate')],
          peopleLists: [_peopleList('crew')],
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byType(DivineListThumbnail), findsNWidgets(2));
      expect(find.text('Video skate'), findsOneWidget);
      expect(find.text('People crew'), findsOneWidget);
    });

    testWidgets('video and people cards align to equal heights', (
      tester,
    ) async {
      // Both card types share the media aspect ratio and the fixed
      // two-line footer, so equal-width columns read as rows — even when
      // one list has a description and the other does not.
      whenListen(
        cubit,
        const Stream<ListsDiscoveryState>.empty(),
        initialState: ListsDiscoveryState(
          videoStatus: ListsDiscoveryColumnStatus.success,
          peopleStatus: ListsDiscoveryColumnStatus.success,
          videoLists: [
            CuratedList(
              id: 'skate',
              name: 'Video \u{1F51D} skate',
              description:
                  'A description long enough to wrap onto a second line '
                  'and then keep going past it for the ellipsis.',
              pubkey: _author,
              videoEventIds: const ['v1'],
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
          ],
          peopleLists: [_peopleList('crew')],
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final cards = find.byType(DivineListThumbnail);
      expect(cards, findsNWidgets(2));
      final videoSize = tester.getSize(cards.at(0));
      final peopleSize = tester.getSize(cards.at(1));
      expect(videoSize.width, peopleSize.width);
      expect(videoSize.height, peopleSize.height);
    });

    testWidgets('keeps one column alive while the other loads', (
      tester,
    ) async {
      whenListen(
        cubit,
        const Stream<ListsDiscoveryState>.empty(),
        initialState: ListsDiscoveryState(
          videoStatus: ListsDiscoveryColumnStatus.success,
          peopleStatus: ListsDiscoveryColumnStatus.loading,
          videoLists: [_videoList('skate')],
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byType(DivineListThumbnail), findsOneWidget);
      expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
    });

    testWidgets('shows a quiet error line for a failed empty column', (
      tester,
    ) async {
      whenListen(
        cubit,
        const Stream<ListsDiscoveryState>.empty(),
        initialState: ListsDiscoveryState(
          videoStatus: ListsDiscoveryColumnStatus.success,
          peopleStatus: ListsDiscoveryColumnStatus.failure,
          videoLists: [_videoList('skate')],
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.text(l10n.exploreErrorLoadingLists), findsOneWidget);
      expect(find.byType(DivineListThumbnail), findsOneWidget);
    });

    testWidgets('shows the empty message when both columns finish empty', (
      tester,
    ) async {
      whenListen(
        cubit,
        const Stream<ListsDiscoveryState>.empty(),
        initialState: const ListsDiscoveryState(
          videoStatus: ListsDiscoveryColumnStatus.success,
          peopleStatus: ListsDiscoveryColumnStatus.success,
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.text(l10n.listsDiscoveryEmpty), findsOneWidget);
      expect(find.byType(DivineListThumbnail), findsNothing);
    });

    testWidgets('video card navigates to the list detail route', (
      tester,
    ) async {
      final goRouter = MockGoRouter();
      when(
        () => goRouter.push<Object?>(any(), extra: any(named: 'extra')),
      ).thenAnswer((_) async => null);
      whenListen(
        cubit,
        const Stream<ListsDiscoveryState>.empty(),
        initialState: ListsDiscoveryState(
          videoStatus: ListsDiscoveryColumnStatus.success,
          peopleStatus: ListsDiscoveryColumnStatus.success,
          videoLists: [_videoList('skate')],
        ),
      );

      await tester.pumpWidget(buildSubject(goRouter: goRouter));
      await tester.pump();

      await tester.tap(find.text('Video skate'));

      verify(
        () => goRouter.push<Object?>(
          '/list/skate',
          extra: any(named: 'extra'),
        ),
      ).called(1);
    });

    testWidgets('people card navigates with the owner query param', (
      tester,
    ) async {
      final goRouter = MockGoRouter();
      when(() => goRouter.push<Object?>(any())).thenAnswer((_) async => null);
      whenListen(
        cubit,
        const Stream<ListsDiscoveryState>.empty(),
        initialState: ListsDiscoveryState(
          videoStatus: ListsDiscoveryColumnStatus.success,
          peopleStatus: ListsDiscoveryColumnStatus.success,
          peopleLists: [_peopleList('crew')],
        ),
      );

      await tester.pumpWidget(buildSubject(goRouter: goRouter));
      await tester.pump();

      await tester.tap(find.text('People crew'));

      verify(
        () => goRouter.push<Object?>('/people-lists/crew?owner=$_author'),
      ).called(1);
    });
  });
}

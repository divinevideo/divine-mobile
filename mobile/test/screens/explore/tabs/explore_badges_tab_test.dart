import 'dart:async';

import 'package:badge_repository/badge_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/blocs/badges/explore_badges_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/screens/badges/badge_detail_screen.dart';
import 'package:openvine/screens/explore/tabs/explore_badges_tab.dart';

import '../../../helpers/test_provider_overrides.dart';

class _MockExploreBadgesCubit extends MockCubit<ExploreBadgesState>
    implements ExploreBadgesCubit {}

class _MockBadgeRepository extends Mock implements BadgeRepository {}

void main() {
  group(ExploreBadgesTab, () {
    testWidgets('loads curated badges when the actual tab mounts', (
      tester,
    ) async {
      final repository = _MockBadgeRepository();
      when(() => repository.loadDefinitionsByIssuers(exploreBadgeIssuers))
          .thenAnswer((_) async => [_definition]);
      await tester.pumpWidget(
        testProviderScope(
          additionalOverrides: [
            badgeRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ExploreBadgesTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      verify(() => repository.loadDefinitionsByIssuers(exploreBadgeIssuers))
          .called(1);
      expect(find.text('Diviner of the Day'), findsOneWidget);
    });
  });
  group(ExploreBadgesView, () {
    late _MockExploreBadgesCubit cubit;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUp(() {
      cubit = _MockExploreBadgesCubit();
    });

    Widget buildSubject() => testMaterialApp(
      home: Scaffold(
        body: BlocProvider<ExploreBadgesCubit>.value(
          value: cubit,
          child: const ExploreBadgesView(),
        ),
      ),
    );

    group('renders', () {
      testWidgets('the curated badges', (tester) async {
        when(() => cubit.state).thenReturn(
          ExploreBadgesState(
            status: ExploreBadgesStatus.loaded,
            definitions: [_definition],
          ),
        );

        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(find.text('Diviner of the Day'), findsOneWidget);
        expect(find.text('One creator a day'), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('badge row opens its complete coordinate route', (
        tester,
      ) async {
        when(() => cubit.state).thenReturn(
          ExploreBadgesState(
            status: ExploreBadgesStatus.loaded,
            definitions: [_definition],
          ),
        );
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => Scaffold(
                body: BlocProvider<ExploreBadgesCubit>.value(
                  value: cubit,
                  child: const ExploreBadgesView(),
                ),
              ),
            ),
            GoRoute(
              path: BadgeDetailScreen.path,
              builder: (_, state) =>
                  Scaffold(body: Text(state.pathParameters['naddr']!)),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          testProviderScope(
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Diviner of the Day'));
        await tester.pumpAndSettle();
        expect(
          find.text(BadgeCoordinate.parse(_definition.coordinate)!.toNaddr()),
          findsOneWidget,
        );
      });

      testWidgets('refresh failure reset shows no duplicate snackbar', (
        tester,
      ) async {
        final states = StreamController<ExploreBadgesState>();
        addTearDown(states.close);
        final loaded = ExploreBadgesState(
          status: ExploreBadgesStatus.loaded,
          definitions: [_definition],
        );
        whenListen(cubit, states.stream, initialState: loaded);
        await tester.pumpWidget(buildSubject());
        states.add(loaded.copyWith(refreshFailures: 1));
        await tester.pumpAndSettle();
        expect(find.text(l10n.badgesLoadError), findsOneWidget);
        ScaffoldMessenger.of(tester.element(find.byType(ExploreBadgesView)))
            .removeCurrentSnackBar();
        await tester.pumpAndSettle();
        states.add(loaded);
        await tester.pumpAndSettle();
        expect(find.text(l10n.badgesLoadError), findsNothing);
        states.add(loaded.copyWith(refreshFailures: 1));
        await tester.pumpAndSettle();
        expect(find.text(l10n.badgesLoadError), findsOneWidget);
      });

      testWidgets('failed refresh keeps badges and shows feedback', (
        tester,
      ) async {
        final loaded = ExploreBadgesState(
          status: ExploreBadgesStatus.loaded,
          definitions: [_definition],
        );
        whenListen(
          cubit,
          Stream.value(loaded.copyWith(refreshFailures: 1)),
          initialState: loaded,
        );
        await tester.pumpWidget(buildSubject());
        await tester.pump();
        expect(find.text('Diviner of the Day'), findsOneWidget);
        expect(find.text(l10n.badgesLoadError), findsOneWidget);
        expect(find.text(l10n.commonRetry), findsNothing);
      });

      testWidgets('retries a failed load', (tester) async {
        when(() => cubit.state).thenReturn(
          const ExploreBadgesState(status: ExploreBadgesStatus.failure),
        );
        when(() => cubit.load()).thenAnswer((_) async {});

        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(find.text(l10n.badgesLoadError), findsOneWidget);
        await tester.tap(find.text(l10n.commonRetry));

        verify(() => cubit.load()).called(1);
      });
    });
  });
}

const _issuer =
    'e21369e63b98f58de8aa171ec9794006eb0118891ae70895106d44525b718d2b';

final _definition = Nip58BadgeDefinition(
  event: Event.fromJson({
    'id': '1'.padLeft(64, '0'),
    'pubkey': _issuer,
    'created_at': 1000,
    'kind': EventKind.badgeDefinition,
    'tags': <List<String>>[],
    'content': '',
    'sig': '',
  }),
  coordinate: '30009:$_issuer:daily-diviner',
  dTag: 'daily-diviner',
  name: 'Diviner of the Day',
  description: 'One creator a day',
);

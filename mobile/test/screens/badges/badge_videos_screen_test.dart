import 'dart:async';

import 'package:badge_repository/badge_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/badges/badge_videos_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/badges/badge_videos_screen.dart';
import 'package:videos_repository/videos_repository.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockBadgeVideosCubit extends MockCubit<BadgeVideosState>
    implements BadgeVideosCubit {}

class _MockBadgeRepository extends Mock implements BadgeRepository {}

class _MockVideosRepository extends Mock implements VideosRepository {}

void main() {
  group(BadgeVideosScreen, () {
    testWidgets(
      'uses detail holders once and re-resolves after moderation changes',
      (tester) async {
        final repository = _MockBadgeRepository();
        final videos = _MockVideosRepository();
        when(() => repository.loadAcceptedHolders(_coordinate))
            .thenAnswer((_) async => <String>{});
        await tester.pumpWidget(
          testProviderScope(
            additionalOverrides: [
              badgeRepositoryProvider.overrideWithValue(repository),
              videosRepositoryProvider.overrideWithValue(videos),
            ],
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: BadgeVideosScreen(
                coordinate: _coordinate,
                seed: BadgeVideosSeed(coordinate: _coordinate, holders: {}),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        verifyNever(() => repository.loadAcceptedHolders(_coordinate));
        ProviderScope.containerOf(
          tester.element(find.byType(BadgeVideosScreen)),
        ).read(blocklistVersionProvider.notifier).increment();
        await tester.pumpAndSettle();
        verify(() => repository.loadAcceptedHolders(_coordinate)).called(1);
      },
    );

    testWidgets('reloads holders when the blocklist changes', (tester) async {
      final repository = _MockBadgeRepository();
      final videos = _MockVideosRepository();
      when(() => repository.loadAcceptedHolders(_coordinate))
          .thenAnswer((_) async => <String>{});
      await tester.pumpWidget(
        testProviderScope(
          additionalOverrides: [
            badgeRepositoryProvider.overrideWithValue(repository),
            videosRepositoryProvider.overrideWithValue(videos),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BadgeVideosScreen(coordinate: _coordinate),
          ),
        ),
      );
      await tester.pumpAndSettle();
      ProviderScope.containerOf(tester.element(find.byType(BadgeVideosScreen)))
          .read(blocklistVersionProvider.notifier)
          .increment();
      await tester.pumpAndSettle();
      verify(() => repository.loadAcceptedHolders(_coordinate)).called(2);
    });
  });

  group(BadgeVideosView, () {
    late _MockBadgeVideosCubit cubit;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUp(() {
      cubit = _MockBadgeVideosCubit();
    });

    Widget buildSubject() => testMaterialApp(
      home: BlocProvider<BadgeVideosCubit>.value(
        value: cubit,
        child: const BadgeVideosView(coordinate: _coordinate),
      ),
    );

    group('renders', () {
      testWidgets('an empty state when no holder has videos', (tester) async {
        when(() => cubit.state).thenReturn(
          const BadgeVideosState(status: BadgeVideosStatus.loaded),
        );

        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(find.text(l10n.exploreNoVideosAvailable), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('back button returns to the page that opened videos', (
        tester,
      ) async {
        when(
          () => cubit.state,
        ).thenReturn(const BadgeVideosState(status: BadgeVideosStatus.loaded));
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, _) => Scaffold(
                body: TextButton(
                  onPressed: () => context.push('/videos'),
                  child: const Text('open'),
                ),
              ),
            ),
            GoRoute(
              path: '/videos',
              builder: (_, _) => BlocProvider<BadgeVideosCubit>.value(
                value: cubit,
                child: const BadgeVideosView(coordinate: _coordinate),
              ),
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
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        final appBar = tester.widget<DiVineAppBar>(find.byType(DiVineAppBar));
        expect(appBar.showBackButton, isTrue);
        appBar.onBackPressed!();
        await tester.pumpAndSettle();
        expect(find.text('open'), findsOneWidget);
      });

      testWidgets('retries a failed load', (tester) async {
        when(() => cubit.state).thenReturn(
          const BadgeVideosState(status: BadgeVideosStatus.failure),
        );
        when(() => cubit.load()).thenAnswer((_) async {});

        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(find.text(l10n.feedFailedToLoadVideos), findsOneWidget);
        await tester.tap(find.text(l10n.commonRetry));

        verify(() => cubit.load()).called(1);
      });

      testWidgets('refresh reset does not repeat a pagination error', (
        tester,
      ) async {
        final states = StreamController<BadgeVideosState>();
        addTearDown(states.close);
        const loaded = BadgeVideosState(status: BadgeVideosStatus.loaded);
        whenListen(cubit, states.stream, initialState: loaded);
        await tester.pumpWidget(buildSubject());
        states.add(loaded.copyWith(loadMoreFailures: 1));
        await tester.pumpAndSettle();
        expect(find.text(l10n.feedFailedToLoadVideos), findsOneWidget);
        ScaffoldMessenger.of(tester.element(find.byType(BadgeVideosView)))
            .removeCurrentSnackBar();
        await tester.pumpAndSettle();
        states.add(loaded);
        await tester.pumpAndSettle();
        expect(find.text(l10n.feedFailedToLoadVideos), findsNothing);
        states.add(loaded.copyWith(loadMoreFailures: 1));
        await tester.pumpAndSettle();
        expect(find.text(l10n.feedFailedToLoadVideos), findsOneWidget);
      });

      testWidgets('reports a page that failed to load', (tester) async {
        const loaded = BadgeVideosState(status: BadgeVideosStatus.loaded);
        whenListen(
          cubit,
          Stream.value(loaded.copyWith(loadMoreFailures: 1)),
          initialState: loaded,
        );

        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(find.text(l10n.feedFailedToLoadVideos), findsOneWidget);
      });
    });
  });
}

const _coordinate = BadgeCoordinate(
  pubkey: '0000000000000000000000000000000000000000000000000000000000000065',
  identifier: 'scene-stealer',
);

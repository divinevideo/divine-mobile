import 'package:badge_repository/badge_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

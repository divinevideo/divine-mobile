import 'package:badge_repository/badge_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/badges/badge_videos_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/badges/badge_videos_screen.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockBadgeVideosCubit extends MockCubit<BadgeVideosState>
    implements BadgeVideosCubit {}

void main() {
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

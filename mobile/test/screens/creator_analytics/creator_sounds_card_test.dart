// ABOUTME: Widget tests for the Creator Analytics "Your Sounds" card.
// ABOUTME: Covers loading, empty, error-with-retry, and ranked sound rows.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/creator_sounds/creator_sounds_cubit.dart';
import 'package:openvine/features/creator_analytics/creator_analytics_repository.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/creator_analytics/creator_sounds_card.dart';
import 'package:openvine/screens/sound_detail_screen.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';

import '../../helpers/accessibility_guidelines.dart';
import '../../helpers/go_router.dart';

class _MockCreatorSoundsCubit extends MockCubit<CreatorSoundsState>
    implements CreatorSoundsCubit {}

void main() {
  group(CreatorSoundsCard, () {
    late _MockCreatorSoundsCubit cubit;
    late MockGoRouter goRouter;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUp(() {
      cubit = _MockCreatorSoundsCubit();
      goRouter = MockGoRouter();
    });

    Future<void> pumpCard(WidgetTester tester, CreatorSoundsState state) {
      when(() => cubit.state).thenReturn(state);
      return tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: MockGoRouterProvider(
            goRouter: goRouter,
            child: Scaffold(
              body: BlocProvider<CreatorSoundsCubit>.value(
                value: cubit,
                child: const CreatorSoundsCard(),
              ),
            ),
          ),
        ),
      );
    }

    SoundStats sound(String id, String title, int usageCount) => SoundStats(
      id: id,
      pubkey: 'a' * 64,
      title: title,
      createdAt: DateTime.now().toUtc().subtract(const Duration(days: 3)),
      usageCount: usageCount,
    );

    group('renders', () {
      testWidgets('a loading indicator while the sounds load', (tester) async {
        await pumpCard(
          tester,
          const CreatorSoundsState(status: CreatorSoundsStatus.loading),
        );

        expect(find.text(l10n.analyticsYourSounds), findsOneWidget);
        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
      });

      testWidgets('the empty prompt when the creator has no sounds', (
        tester,
      ) async {
        await pumpCard(
          tester,
          const CreatorSoundsState(status: CreatorSoundsStatus.success),
        );

        expect(find.text(l10n.analyticsYourSoundsEmpty), findsOneWidget);
        expect(find.text(l10n.analyticsYourSoundsExplainer), findsNothing);
      });

      testWidgets('each sound with its rank and video count', (tester) async {
        await pumpCard(
          tester,
          CreatorSoundsState(
            status: CreatorSoundsStatus.success,
            sounds: [
              sound('sound-a', 'Test sound', 42),
              sound('sound-b', 'Original sound', 1),
              sound('sound-c', 'Fresh upload', 0),
            ],
          ),
        );

        expect(find.text(l10n.analyticsYourSoundsExplainer), findsOneWidget);
        expect(
          find.bySemanticsLabel(
            'Test sound, ${l10n.soundVideoCount(42)}, '
            '${l10n.timeAgo(l10n.timeShortDays(3))}',
          ),
          findsOneWidget,
        );
        expect(find.text(l10n.soundVideoCount(1)), findsOneWidget);
        expect(find.text(l10n.soundNoVideoCount), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
      });

      testWidgets('sound rows large enough to tap', (tester) async {
        await pumpCard(
          tester,
          CreatorSoundsState(
            status: CreatorSoundsStatus.success,
            sounds: [
              sound('sound-a', 'Test sound', 42),
              sound('sound-b', 'Original sound', 1),
            ],
          ),
        );

        await expectMeetsAccessibilityGuidelines(
          tester,
          guidelines: const [androidTapTargetGuideline],
        );
      });

      testWidgets('the localized failure message', (tester) async {
        await pumpCard(
          tester,
          const CreatorSoundsState(
            status: CreatorSoundsStatus.failure,
            failureKind: CreatorAnalyticsFailureKind.connectionIssue,
          ),
        );

        expect(find.text(l10n.analyticsConnectionIssue), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('retry reloads the sounds', (tester) async {
        when(() => cubit.load()).thenAnswer((_) async {});
        await pumpCard(
          tester,
          const CreatorSoundsState(
            status: CreatorSoundsStatus.failure,
            failureKind: CreatorAnalyticsFailureKind.serverUnavailable,
          ),
        );

        await tester.tap(find.text(l10n.analyticsRetry));

        verify(() => cubit.load()).called(1);
      });

      testWidgets('tapping a sound opens its detail page', (tester) async {
        when(() => goRouter.push<Object?>(any())).thenAnswer((_) async => null);
        await pumpCard(
          tester,
          CreatorSoundsState(
            status: CreatorSoundsStatus.success,
            sounds: [sound('sound-a', 'Test sound', 42)],
          ),
        );

        await tester.tap(find.text('Test sound'));

        verify(
          () => goRouter.push<Object?>(SoundDetailScreen.pathForId('sound-a')),
        ).called(1);
      });
    });
  });
}

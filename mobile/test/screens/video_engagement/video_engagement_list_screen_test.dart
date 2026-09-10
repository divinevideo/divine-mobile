// ABOUTME: Widget tests for VideoEngagementListScreen — the canonical Page/View
// ABOUTME: split template. Verifies that the ConsumerWidget Page correctly wires
// ABOUTME: Riverpod-provided repositories into VideoEngagementBloc, and that the
// ABOUTME: extracted VideoEngagementListView renders bloc state correctly.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_engagement/video_engagement_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/screens/video_engagement/video_engagement_list_screen.dart';
import 'package:openvine/screens/video_engagement/video_engagement_list_view.dart';
import 'package:reposts_repository/reposts_repository.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockRepostsRepository extends Mock implements RepostsRepository {}

void main() {
  late _MockLikesRepository likesRepository;
  late _MockRepostsRepository repostsRepository;

  const testEventId =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const testPubkey1 =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const testPubkey2 =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

  setUp(() {
    likesRepository = _MockLikesRepository();
    repostsRepository = _MockRepostsRepository();
  });

  Widget buildSubject({
    VideoEngagementType type = VideoEngagementType.likers,
    String? addressableId,
  }) {
    return testMaterialApp(
      additionalOverrides: [
        likesRepositoryProvider.overrideWithValue(likesRepository),
        repostsRepositoryProvider.overrideWithValue(repostsRepository),
      ],
      home: VideoEngagementListScreen(
        eventId: testEventId,
        type: type,
        addressableId: addressableId,
      ),
    );
  }

  group('VideoEngagementListScreen (Page)', () {
    testWidgets(
      'renders VideoEngagementListView as its child',
      (tester) async {
        when(
          () => likesRepository.fetchEventLikers(eventId: testEventId),
        ).thenAnswer((_) async => const []);

        await tester.pumpWidget(buildSubject());

        expect(find.byType(VideoEngagementListView), findsOneWidget);
      },
    );

    testWidgets(
      'shows a loading indicator while the bloc is fetching',
      (tester) async {
        // Completer that never completes — keeps bloc in loading state.
        final completer = Completer<List<String>>();
        when(
          () => likesRepository.fetchEventLikers(eventId: testEventId),
        ).thenAnswer((_) => completer.future);

        await tester.pumpWidget(buildSubject());
        // One pump: BlocProvider creates the bloc, dispatches
        // VideoEngagementLoadRequested, bloc emits loading.
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Clean up: complete the future to avoid pending-timer leak.
        completer.complete([]);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'shows a list when the bloc emits success with pubkeys',
      (tester) async {
        when(
          () => likesRepository.fetchEventLikers(eventId: testEventId),
        ).thenAnswer((_) async => const [testPubkey1, testPubkey2]);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        // UserProfileTile renders one item per pubkey inside a ListView.
        expect(find.byType(ListView), findsOneWidget);
      },
    );

    testWidgets(
      'shows empty-state widget when success state has no pubkeys',
      (tester) async {
        when(
          () => likesRepository.fetchEventLikers(eventId: testEventId),
        ).thenAnswer((_) async => const []);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          find.text(l10n.videoEngagementLikersEmpty),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'shows likers title in app bar for VideoEngagementType.likers',
      (tester) async {
        when(
          () => likesRepository.fetchEventLikers(eventId: testEventId),
        ).thenAnswer((_) async => const []);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.videoEngagementLikersTitle), findsOneWidget);
      },
    );

    testWidgets(
      'shows reposters title in app bar for VideoEngagementType.reposters',
      (tester) async {
        when(
          () => repostsRepository.fetchEventReposters(eventId: testEventId),
        ).thenAnswer((_) async => const []);

        await tester.pumpWidget(
          buildSubject(type: VideoEngagementType.reposters),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.videoEngagementRepostersTitle), findsOneWidget);
      },
    );

    testWidgets(
      'dispatches VideoEngagementLoadRequested on construction',
      (tester) async {
        when(
          () => likesRepository.fetchEventLikers(eventId: testEventId),
        ).thenAnswer((_) async => const []);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        // The repo method being called proves the initial event was dispatched.
        verify(
          () => likesRepository.fetchEventLikers(eventId: testEventId),
        ).called(1);
      },
    );
  });

  group('VideoEngagementListView (View)', () {
    testWidgets(
      'has no Riverpod dependency — can be rendered without ProviderScope',
      (tester) async {
        // Provide the bloc directly, with no ProviderScope wrapping the view.
        // This proves VideoEngagementListView is a pure StatelessWidget
        // with zero Riverpod dependency.
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: _BlocProviderWidget(
              bloc: VideoEngagementBloc(
                eventId: testEventId,
                type: VideoEngagementType.likers,
                likesRepository: likesRepository,
                repostsRepository: repostsRepository,
                profileRepository: null,
              ),
              child: const VideoEngagementListView(),
            ),
          ),
        );

        // Initial state renders a loading indicator.
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );
  });
}

/// Tiny helper to provide a single bloc without ProviderScope.
/// Keeps the "no Riverpod" test self-contained and makes the intent explicit.
class _BlocProviderWidget extends StatelessWidget {
  const _BlocProviderWidget({
    required this.bloc,
    required this.child,
  });

  final VideoEngagementBloc bloc;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<VideoEngagementBloc>.value(
      value: bloc,
      child: child,
    );
  }
}

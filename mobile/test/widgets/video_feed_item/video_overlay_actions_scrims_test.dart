// ABOUTME: Widget tests for the scrims VideoOverlayActions lays under its
// ABOUTME: controls, and their absence from a grid tile's flying copy.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:openvine/widgets/video_tile_transition/video_tile_transition_target.dart';
import 'package:reposts_repository/reposts_repository.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockVideoInteractionsBloc extends Mock
    implements VideoInteractionsBloc {}

class _MockRepostsRepository extends Mock implements RepostsRepository {}

/// The scrims drawn, as the opacity each one reaches at its dark edge.
List<double> _scrimOpacities(WidgetTester tester) => [
  for (final box in tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)))
    if (box.decoration
        case BoxDecoration(
          gradient: LinearGradient(:final colors),
        )
        when colors.every(
          (color) => color.withValues(alpha: 1) == VideoOverlayScrims.color,
        ))
      colors.map((color) => color.a).reduce((a, b) => a > b ? a : b),
];

void main() {
  group('$VideoOverlayActions scrims', () {
    late _MockVideoInteractionsBloc interactionsBloc;
    late _MockRepostsRepository repostsRepository;
    late VideoEvent video;

    setUp(() {
      interactionsBloc = _MockVideoInteractionsBloc();
      repostsRepository = _MockRepostsRepository();
      when(
        () => interactionsBloc.stream,
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => interactionsBloc.state,
      ).thenReturn(const VideoInteractionsState());
      when(
        () => repostsRepository.fetchEventReposters(
          eventId: any(named: 'eventId'),
          addressableId: any(named: 'addressableId'),
        ),
      ).thenAnswer((_) async => const RepostersPage(pubkeys: []));
      video = VideoEvent(
        id: '2222222222222222222222222222222222222222222222222222222222222222',
        pubkey:
            'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        createdAt: 1757385263,
        content: 'Scrimmed',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
        videoUrl: 'https://example.com/video.mp4',
        title: 'Scrimmed video',
      );
    });

    Future<void> pumpActions(
      WidgetTester tester, {
      required bool flying,
    }) async {
      final actions = VideoOverlayActions(
        video: video,
        isVisible: true,
        isActive: true,
        isFullscreen: true,
        showTopGradient: true,
      );
      Widget content = actions;
      if (flying) content = VideoTileFlightCopy(child: actions);
      await tester.pumpWidget(
        testProviderScope(
          additionalOverrides: [
            repostsRepositoryProvider.overrideWithValue(repostsRepository),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: BlocProvider<VideoInteractionsBloc>.value(
                value: interactionsBloc,
                child: content,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('draws its top and bottom scrims', (tester) async {
      await pumpActions(tester, flying: false);

      expect(
        _scrimOpacities(tester),
        unorderedEquals([
          VideoOverlayScrims.topOpacity,
          VideoOverlayScrims.bottomOpacity,
        ]),
      );
    });

    testWidgets("leaves them to a grid tile's flying picture", (tester) async {
      await pumpActions(tester, flying: true);

      expect(_scrimOpacities(tester), isEmpty);
    });
  });
}

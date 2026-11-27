// ABOUTME: Widget tests for the series chip on VideoOverlayActions.
// ABOUTME: Pins that an episode shows the chip above its author row.

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/widgets/video_feed_item/series_chip.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:reposts_repository/reposts_repository.dart';

import '../../helpers/test_provider_overrides.dart';
import '../../helpers/test_pubkeys.dart';

class _MockVideoInteractionsBloc extends Mock
    implements VideoInteractionsBloc {}

class _MockRepostsRepository extends Mock implements RepostsRepository {}

class _MockCuratedListRepository extends Mock
    implements CuratedListRepository {}

final String _author = testPubkeyFromSeed(1);
final String _seriesCoordinate = '30005:$_author:road-trip';
final String _episode = '34236:$_author:day-2';

void main() {
  group('$VideoOverlayActions series chip', () {
    late _MockVideoInteractionsBloc interactionsBloc;
    late _MockRepostsRepository repostsRepository;
    late _MockCuratedListRepository curatedListRepository;

    final series = CuratedList(
      id: 'road-trip',
      name: 'Road trip',
      pubkey: _author,
      videoEventIds: ['34236:$_author:day-1', _episode],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      playOrder: PlayOrder.manual,
      preservedTags: const [
        ['series', 'true'],
      ],
    );

    VideoEvent video({String? seriesCoordinate}) => VideoEvent(
      id: 'f' * 64,
      pubkey: _author,
      createdAt: 1757385263,
      content: 'Day two',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
      videoUrl: 'https://example.com/day-2.mp4',
      authorName: 'Valentina',
      addressableDTag: 'day-2',
      seriesCoordinate: seriesCoordinate,
    );

    Future<void> pumpOverlay(WidgetTester tester, VideoEvent video) async {
      await tester.pumpWidget(
        testProviderScope(
          additionalOverrides: [
            repostsRepositoryProvider.overrideWithValue(repostsRepository),
            curatedListRepositoryProvider.overrideWithValue(
              curatedListRepository,
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: BlocProvider<VideoInteractionsBloc>.value(
                value: interactionsBloc,
                child: VideoOverlayActions(
                  video: video,
                  isVisible: true,
                  isActive: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    setUp(() {
      interactionsBloc = _MockVideoInteractionsBloc();
      repostsRepository = _MockRepostsRepository();
      curatedListRepository = _MockCuratedListRepository();
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
      when(
        () => curatedListRepository.fetchSeriesContaining(
          seriesCoordinate: _seriesCoordinate,
          episodeCoordinate: _episode,
        ),
      ).thenAnswer((_) async => series);
    });

    group('renders', () {
      testWidgets('the chip above the author row for an episode', (
        tester,
      ) async {
        await pumpOverlay(tester, video(seriesCoordinate: _seriesCoordinate));

        final chip = find.text('Road trip');
        expect(chip, findsOneWidget);
        expect(
          tester.getBottomLeft(chip).dy,
          lessThan(tester.getTopLeft(find.text('Valentina')).dy),
        );
      });

      testWidgets('no chip for a video that is not an episode', (tester) async {
        await pumpOverlay(tester, video());

        expect(find.byType(SeriesChip), findsNothing);
        expect(find.text('Valentina'), findsOneWidget);
      });
    });
  });
}

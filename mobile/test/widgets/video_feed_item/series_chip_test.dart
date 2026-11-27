// ABOUTME: Widget tests for SeriesChip: what it shows for an episode, when it
// ABOUTME: shows nothing, and that a tap opens the series at this episode.

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/router/routes/route_extras.dart';
import 'package:openvine/screens/curated_list_by_author_screen.dart';
import 'package:openvine/widgets/video_feed_item/series_chip.dart';

import '../../helpers/test_provider_overrides.dart';
import '../../helpers/test_pubkeys.dart';

class _MockCuratedListRepository extends Mock
    implements CuratedListRepository {}

final String _author = testPubkeyFromSeed(1);
final String _seriesCoordinate = '30005:$_author:road-trip';

String _episode(String dTag) => '34236:$_author:$dTag';

final _series = CuratedList(
  id: 'road-trip',
  name: 'Road trip',
  pubkey: _author,
  videoEventIds: [_episode('day-1'), _episode('day-2'), _episode('day-3')],
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  playOrder: PlayOrder.manual,
  preservedTags: const [
    ['series', 'true'],
  ],
);

VideoEvent _video({String? seriesCoordinate}) => VideoEvent(
  id: 'f' * 64,
  pubkey: _author,
  createdAt: 1757385263,
  content: 'Day two',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
  videoUrl: 'https://example.com/day-2.mp4',
  addressableDTag: 'day-2',
  seriesCoordinate: seriesCoordinate,
);

void main() {
  group(SeriesChip, () {
    late _MockCuratedListRepository repository;
    final l10n = lookupAppLocalizations(const Locale('en'));

    Uri? pushed;
    Object? pushedExtra;

    void answerSeries(CuratedList? series) {
      when(
        () => repository.fetchSeriesContaining(
          seriesCoordinate: any(named: 'seriesCoordinate'),
          episodeCoordinate: any(named: 'episodeCoordinate'),
        ),
      ).thenAnswer((_) async => series);
    }

    Future<void> pumpChip(WidgetTester tester, Widget chip) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(body: Center(child: chip)),
          ),
          GoRoute(
            path: CuratedListByAuthorScreen.path,
            builder: (_, state) {
              pushed = state.uri;
              pushedExtra = state.extra;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        testProviderScope(
          additionalOverrides: [
            curatedListRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
    }

    setUp(() {
      repository = _MockCuratedListRepository();
      pushed = null;
      pushedExtra = null;
    });

    group('renders', () {
      testWidgets('the series name and the episode for an episode', (
        tester,
      ) async {
        answerSeries(_series);
        await pumpChip(
          tester,
          SeriesChip(video: _video(seriesCoordinate: _seriesCoordinate)),
        );

        expect(find.text('Road trip'), findsOneWidget);
        expect(
          find.text(l10n.videoSeriesChipEpisode('2', '3')),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(
            l10n.videoSeriesChipSemanticLabel('Road trip', '2', '3'),
          ),
          findsOneWidget,
        );
        verify(
          () => repository.fetchSeriesContaining(
            seriesCoordinate: _seriesCoordinate,
            episodeCoordinate: _episode('day-2'),
          ),
        ).called(1);
      });

      testWidgets('nothing for a video that names no series', (tester) async {
        answerSeries(_series);
        await pumpChip(tester, SeriesChip(video: _video()));

        expect(find.byType(SeriesChipView), findsNothing);
        verifyNever(
          () => repository.fetchSeriesContaining(
            seriesCoordinate: any(named: 'seriesCoordinate'),
            episodeCoordinate: any(named: 'episodeCoordinate'),
          ),
        );
      });

      testWidgets('nothing when the series does not hold the video', (
        tester,
      ) async {
        answerSeries(null);
        await pumpChip(
          tester,
          SeriesChip(video: _video(seriesCoordinate: _seriesCoordinate)),
        );

        expect(find.byType(SeriesChipView), findsOneWidget);
        expect(find.text('Road trip'), findsNothing);
      });

      testWidgets('nothing inside the player of its own series', (
        tester,
      ) async {
        answerSeries(_series);
        await pumpChip(
          tester,
          PlayingListScope(
            authorPubkey: _author,
            listId: 'road-trip',
            child: SeriesChip(
              video: _video(seriesCoordinate: _seriesCoordinate),
            ),
          ),
        );

        expect(find.byType(SeriesChipView), findsNothing);
        verifyNever(
          () => repository.fetchSeriesContaining(
            seriesCoordinate: any(named: 'seriesCoordinate'),
            episodeCoordinate: any(named: 'episodeCoordinate'),
          ),
        );
      });

      testWidgets('the chip inside the player of another list', (tester) async {
        answerSeries(_series);
        await pumpChip(
          tester,
          PlayingListScope(
            authorPubkey: _author,
            listId: 'favorites',
            child: SeriesChip(
              video: _video(seriesCoordinate: _seriesCoordinate),
            ),
          ),
        );

        expect(find.text('Road trip'), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('a tap opens the series at this episode', (tester) async {
        answerSeries(_series);
        await pumpChip(
          tester,
          SeriesChip(video: _video(seriesCoordinate: _seriesCoordinate)),
        );

        await tester.tap(find.text('Road trip'));
        await tester.pumpAndSettle();

        expect(pushed?.path, equals('/list/$_author/road-trip'));
        expect(pushed?.queryParameters['play'], equals('1'));
        expect(
          pushedExtra,
          isA<CuratedListRouteExtra>().having(
            (extra) => extra.list,
            'list',
            equals(_series),
          ),
        );
      });
    });
  });
}

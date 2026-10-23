// ABOUTME: Widget tests for the list attribution chip on VideoOverlayActions.
// ABOUTME: Pins that a chip tap opens the curated list by id with its hint.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/routes/route_extras.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/widgets/video_feed_item/list_attribution_chip.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:reposts_repository/reposts_repository.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockVideoInteractionsBloc extends Mock
    implements VideoInteractionsBloc {}

class _MockRepostsRepository extends Mock implements RepostsRepository {}

class _MockCuratedListService extends Mock implements CuratedListService {
  @override
  bool recoveryNeedsRepair = false;
}

_MockCuratedListService? _service;

/// Hands the chip the mocked service without building the real one, which
/// needs the relay client and the database.
class _FakeCuratedListsState extends CuratedListsState {
  @override
  CuratedListService? get service => _service;

  @override
  Future<List<CuratedList>> build() async => const [];
}

const _videoId =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _author =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

void main() {
  group('$VideoOverlayActions list attribution', () {
    late _MockVideoInteractionsBloc interactionsBloc;
    late _MockRepostsRepository repostsRepository;
    late VideoEvent video;
    final skate = CuratedList(
      id: 'skate',
      name: 'Skate',
      pubkey: _author,
      videoEventIds: const [_videoId],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    setUp(() {
      interactionsBloc = _MockVideoInteractionsBloc();
      repostsRepository = _MockRepostsRepository();
      _service = _MockCuratedListService();
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
      ).thenAnswer((_) async => const <String>[]);
      when(() => _service!.getListById('skate')).thenReturn(skate);
      video = VideoEvent(
        id: _videoId,
        pubkey: _author,
        createdAt: 1757385263,
        content: 'From a list',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
        videoUrl: 'https://example.com/video.mp4',
        title: 'Listed video',
      );
    });

    testWidgets('a chip tap opens the list by id with its name hint', (
      tester,
    ) async {
      Uri? pushed;
      Object? pushedExtra;
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: BlocProvider<VideoInteractionsBloc>.value(
                value: interactionsBloc,
                child: VideoOverlayActions(
                  video: video,
                  isVisible: true,
                  isActive: true,
                  listSources: const {'skate'},
                  showListAttribution: true,
                ),
              ),
            ),
          ),
          GoRoute(
            path: CuratedListFeedScreen.path,
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
            repostsRepositoryProvider.overrideWithValue(repostsRepository),
            curatedListsStateProvider.overrideWith(_FakeCuratedListsState.new),
          ],
          child: MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(ListAttributionChip),
          matching: find.text('Skate'),
        ),
      );
      await tester.pumpAndSettle();

      // The list opens at its id route, warmed with what the chip knows.
      expect(
        pushed?.toString(),
        equals(CuratedListFeedScreen.pathForId('skate')),
      );
      expect(
        pushedExtra,
        isA<CuratedListRouteExtra>()
            .having((extra) => extra.listName, 'listName', 'Skate')
            .having((extra) => extra.videoIds, 'videoIds', const [_videoId])
            .having((extra) => extra.authorPubkey, 'authorPubkey', _author),
      );
    });
  });
}

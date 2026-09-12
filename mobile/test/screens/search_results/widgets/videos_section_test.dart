import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_search/video_search_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/generated/app_localizations_en.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/search_results/widgets/search_section_empty_state.dart';
import 'package:openvine/screens/search_results/widgets/search_section_error_state.dart';
import 'package:openvine/screens/search_results/widgets/section_header.dart';
import 'package:openvine/screens/search_results/widgets/videos_section.dart';

class _MockVideoSearchBloc extends MockBloc<VideoSearchEvent, VideoSearchState>
    implements VideoSearchBloc {}

void main() {
  group(VideosSection, () {
    late _MockVideoSearchBloc mockBloc;

    final now = DateTime.now();
    final testVideo = VideoEvent(
      id: 'v1',
      pubkey:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      content: '',
      title: 'Test Video',
      createdAt: now.millisecondsSinceEpoch ~/ 1000,
      timestamp: now,
    );

    setUp(() {
      mockBloc = _MockVideoSearchBloc();
    });

    tearDown(() {
      mockBloc.close();
    });

    Widget buildSubject({bool showAll = false}) {
      return ProviderScope(
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider<VideoSearchBloc>.value(
              value: mockBloc,
              child: CustomScrollView(
                slivers: [VideosSection(showAll: showAll)],
              ),
            ),
          ),
        ),
      );
    }

    group('showAll: false (All tab preview)', () {
      testWidgets('hides entirely when success with empty results', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const VideoSearchState(
            status: VideoSearchStatus.success,
            query: 'test',
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.byType(SectionHeader), findsNothing);
        expect(find.byType(SearchSectionEmptyState), findsNothing);
      });

      testWidgets('renders header and content when success with results', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          VideoSearchState(
            status: VideoSearchStatus.success,
            query: 'test',
            videos: [testVideo],
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.byType(SectionHeader), findsOneWidget);
        expect(
          find.text(AppLocalizationsEn().searchVideosSectionHeader),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier(SemanticIds.searchVideoTileAt(0)),
          findsOneWidget,
        );
      });

      testWidgets('renders $SearchSectionErrorState on failure', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const VideoSearchState(
            status: VideoSearchStatus.failure,
            query: 'test',
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.byType(SearchSectionErrorState), findsOneWidget);
      });
    });

    group('showAll: true (dedicated tab)', () {
      testWidgets(
        'renders $SearchSectionEmptyState when success with empty results',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            const VideoSearchState(
              status: VideoSearchStatus.success,
              query: 'test',
            ),
          );

          await tester.pumpWidget(buildSubject(showAll: true));

          expect(find.byType(SearchSectionEmptyState), findsOneWidget);
        },
      );

      testWidgets('renders $SearchSectionErrorState on failure', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const VideoSearchState(
            status: VideoSearchStatus.failure,
            query: 'test',
          ),
        );

        await tester.pumpWidget(buildSubject(showAll: true));

        expect(find.byType(SearchSectionErrorState), findsOneWidget);
      });
    });

    testWidgets(
      'retry dispatches $VideoSearchQueryChanged with current query',
      (tester) async {
        when(() => mockBloc.state).thenReturn(
          const VideoSearchState(
            status: VideoSearchStatus.failure,
            query: 'retry-test',
          ),
        );

        await tester.pumpWidget(buildSubject());
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();

        verify(
          () => mockBloc.add(const VideoSearchQueryChanged('retry-test')),
        ).called(1);
      },
    );

    group('loading more indicator', () {
      testWidgets('shows loading indicator when showAll and isLoadingMore', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          VideoSearchState(
            status: VideoSearchStatus.success,
            videos: [testVideo],
            hasMore: true,
            isLoadingMore: true,
          ),
        );

        await tester.pumpWidget(buildSubject(showAll: true));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets(
        'hides loading indicator when showAll and not isLoadingMore',
        (tester) async {
          when(() => mockBloc.state).thenReturn(
            VideoSearchState(
              status: VideoSearchStatus.success,
              videos: [testVideo],
            ),
          );

          await tester.pumpWidget(buildSubject(showAll: true));

          expect(find.byType(CircularProgressIndicator), findsNothing);
        },
      );

      testWidgets('does not show loading indicator when not showAll', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          VideoSearchState(
            status: VideoSearchStatus.success,
            videos: [testVideo],
            isLoadingMore: true,
          ),
        );

        await tester.pumpWidget(buildSubject());

        // The initial loading spinner is hidden because we have results,
        // and the loading-more indicator is only added when showAll.
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });
    });
  });
}

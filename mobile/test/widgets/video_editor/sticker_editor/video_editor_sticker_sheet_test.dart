// ABOUTME: Widget tests for VideoEditorStickerSheet - sticker selection bottom sheet.
// ABOUTME: Tests search, grid display, empty states, and sticker selection.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart'
    show LocalizedText, StickerData, StickerPackData;
import 'package:openvine/blocs/video_editor/sticker/video_editor_sticker_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/sticker_editor/video_editor_sticker_sheet.dart';

class MockVideoEditorStickerBloc
    extends MockBloc<VideoEditorStickerEvent, VideoEditorStickerState>
    implements VideoEditorStickerBloc {}

void main() {
  group('VideoEditorStickerSheet', () {
    late MockVideoEditorStickerBloc mockBloc;

    final testStickers = [
      const StickerData(
        assetPath: 'assets/stickers/happy.png',
        description: LocalizedText({'en': 'Happy face'}),
        tags: ['happy', 'smile'],
        packData: StickerPackData.fallback,
      ),
      const StickerData(
        assetPath: 'assets/stickers/sad.png',
        description: LocalizedText({'en': 'Sad face'}),
        tags: ['sad', 'cry'],
        packData: StickerPackData.fallback,
      ),
      const StickerData(
        assetPath: 'assets/stickers/star.png',
        description: LocalizedText({'en': 'Golden star'}),
        tags: ['star', 'gold'],
        packData: StickerPackData.fallback,
      ),
    ];

    setUp(() {
      mockBloc = MockVideoEditorStickerBloc();
    });

    Widget buildSubject({VideoEditorStickerState? state}) {
      when(
        () => mockBloc.state,
      ).thenReturn(
        state ??
            VideoEditorStickerLoaded(
              stickers: testStickers,
              allStickers: testStickers,
            ),
      );

      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData.dark(),
        home: Scaffold(
          body: BlocProvider<VideoEditorStickerBloc>.value(
            value: mockBloc,
            child: const VideoEditorStickerSheet(
              enableSearchBar: true,
            ),
          ),
        ),
      );
    }

    group('loading state', () {
      testWidgets('shows loading indicator when state is initial', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(state: const VideoEditorStickerInitial()),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('shows loading indicator when state is loading', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(state: const VideoEditorStickerLoading()),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('loaded state', () {
      testWidgets('displays sticker grid when stickers are loaded', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            state: VideoEditorStickerLoaded(
              stickers: testStickers,
              allStickers: testStickers,
            ),
          ),
        );

        // Should find GestureDetectors for each sticker (tappable items)
        expect(find.byType(GestureDetector), findsWidgets);
      });

      testWidgets('shows empty state message when no stickers available', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            state: const VideoEditorStickerLoaded(
              stickers: [],
              allStickers: [],
            ),
          ),
        );

        expect(find.text('No stickers available'), findsOneWidget);
      });

      testWidgets('shows "No stickers found" when search returns empty', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            state: const VideoEditorStickerLoaded(
              stickers: [],
              allStickers: [],
              searchQuery: 'nonexistent',
            ),
          ),
        );

        expect(find.text('No stickers found'), findsOneWidget);
      });
    });

    group('error state', () {
      testWidgets('shows error message when loading fails', (tester) async {
        await tester.pumpWidget(
          buildSubject(state: const VideoEditorStickerError()),
        );

        expect(find.text('Failed to load stickers'), findsOneWidget);
      });
    });

    group('search functionality', () {
      testWidgets('has search text field', (tester) async {
        await tester.pumpWidget(buildSubject());
        // Use pump() instead of pumpAndSettle() to avoid SliverAppBar animation timeout
        await tester.pump();

        expect(find.byType(TextField), findsOneWidget);
      });

      testWidgets('dispatches search event when text changes', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        await tester.enterText(find.byType(TextField), 'happy');
        await tester.pump();

        verify(
          () => mockBloc.add(const VideoEditorStickerSearch('happy')),
        ).called(1);
      });

      testWidgets('shows clear button when search query is active', (
        tester,
      ) async {
        final stateWithQuery = VideoEditorStickerLoaded(
          stickers: testStickers,
          allStickers: testStickers,
          searchQuery: 'test',
        );
        whenListen(
          mockBloc,
          Stream.value(stateWithQuery),
          initialState: stateWithQuery,
        );

        await tester.pumpWidget(buildSubject(state: stateWithQuery));
        await tester.pump();

        expect(
          find.byWidgetPredicate(
            (widget) => widget is DivineIcon && widget.icon == DivineIconName.x,
          ),
          findsOneWidget,
        );
      });

      testWidgets('hides clear button when no search query', (tester) async {
        when(
          () => mockBloc.state,
        ).thenReturn(
          VideoEditorStickerLoaded(
            stickers: testStickers,
            allStickers: testStickers,
          ),
        );

        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(find.byIcon(Icons.close_rounded), findsNothing);
      });
    });
  });
}

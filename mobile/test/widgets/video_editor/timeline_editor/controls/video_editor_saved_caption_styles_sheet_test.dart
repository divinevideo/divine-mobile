// ABOUTME: Tests for the saved caption styles sheet: the save / apply /
// ABOUTME: rename / delete / reorder flows and the loading states.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/saved_caption_styles/saved_caption_styles_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/caption_style.dart';
import 'package:openvine/models/video_editor/saved_caption_style.dart';
import 'package:openvine/providers/saved_caption_style_repository_provider.dart';
import 'package:openvine/repositories/saved_caption_style_repository.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/caption_style_preview.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/saved_style_name_prompt.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_saved_caption_styles_sheet.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show LayerBackgroundMode;

class _MockSavedCaptionStyleRepository extends Mock
    implements SavedCaptionStyleRepository {}

class _MockSavedCaptionStylesCubit extends MockCubit<SavedCaptionStylesState>
    implements SavedCaptionStylesCubit {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final l10n = lookupAppLocalizations(const Locale('en'));

  // Font index 0 is Inter, the one editor font bundled with the app: any
  // other index asks google_fonts to fetch, which fails the test.
  const current = CaptionCustomStyle(
    fontIndex: 0,
    color: Color(0xFFFFFFFF),
    background: Color(0xA6000000),
    colorMode: LayerBackgroundMode.backgroundAndColor,
    animation: CaptionAnimationStyle.fade,
  );
  const popStyle = CaptionCustomStyle(
    fontIndex: 0,
    color: Color(0xFFFFF140),
    background: Color(0xA6000000),
    colorMode: LayerBackgroundMode.onlyColor,
    animation: CaptionAnimationStyle.pop,
    fontScale: 1.3,
  );

  SavedCaptionStyle saved(String id, String name) => SavedCaptionStyle(
    id: id,
    name: name,
    style: popStyle,
    createdAt: DateTime(2026, 9, 15),
  );

  group(SavedCaptionStylesSheetView, () {
    late _MockSavedCaptionStyleRepository repository;
    late SavedCaptionStylesCubit cubit;

    setUpAll(() {
      registerFallbackValue(current);
    });

    setUp(() {
      repository = _MockSavedCaptionStyleRepository();
      cubit = SavedCaptionStylesCubit(repository: repository);
    });

    tearDown(() => cubit.close());

    /// Pushes the view as a route from a button, so a tapped style pops back
    /// out as the route result the way it does from the real sheet.
    Future<CaptionCustomStyle? Function()> pumpView(
      WidgetTester tester, {
      bool disableAnimations = true,
      CaptionCustomStyle? currentCustomStyle = current,
      SavedCaptionStylesCubit? cubitOverride,
    }) async {
      tester.view
        ..physicalSize = const Size(1080, 2400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      CaptionCustomStyle? result;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: disableAnimations),
            child: child!,
          ),
          theme: VineTheme.theme,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<CaptionCustomStyle>(
                    MaterialPageRoute(
                      builder: (_) =>
                          BlocProvider<SavedCaptionStylesCubit>.value(
                            value: cubitOverride ?? cubit,
                            child: Scaffold(
                              body: SavedCaptionStylesSheetView(
                                currentCustomStyle: currentCustomStyle,
                              ),
                            ),
                          ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      if (disableAnimations) {
        await tester.pumpAndSettle();
      } else {
        // The preview loop never settles; bounded pumps get past the route
        // transition instead.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }
      return () => result;
    }

    Finder applyRow(String name) => find.bySemanticsLabel(
      l10n.videoEditorCaptionsSavedStyleApplySemanticLabel(name),
    );

    testWidgets('shows the empty note when nothing is saved', (tester) async {
      when(() => repository.getStyles()).thenAnswer((_) async => []);
      await cubit.load();

      await pumpView(tester);

      expect(
        find.text(l10n.videoEditorCaptionsSavedStylesEmpty),
        findsOneWidget,
      );
      expect(
        find.text(l10n.videoEditorCaptionsSavedStylesSaveCurrent),
        findsOneWidget,
      );
    });

    testWidgets('hides the save action when the track is on a preset', (
      tester,
    ) async {
      when(
        () => repository.getStyles(),
      ).thenAnswer((_) async => [saved('a', 'Intro')]);
      await cubit.load();

      await pumpView(tester, currentCustomStyle: null);

      expect(
        find.text(l10n.videoEditorCaptionsSavedStylesSaveCurrent),
        findsNothing,
      );
      expect(applyRow('Intro'), findsOneWidget);
    });

    testWidgets('tapping a saved style pops it as the result', (tester) async {
      when(
        () => repository.getStyles(),
      ).thenAnswer((_) async => [saved('a', 'Intro')]);
      await cubit.load();
      final result = await pumpView(tester);

      await tester.tap(applyRow('Intro'));
      await tester.pumpAndSettle();

      expect(result(), equals(popStyle));
      expect(find.byType(SavedCaptionStylesSheetView), findsNothing);
    });

    testWidgets('saves the current style under the suggested font name', (
      tester,
    ) async {
      when(() => repository.getStyles()).thenAnswer((_) async => []);
      when(
        () => repository.save(
          rawName: any(named: 'rawName'),
          style: any(named: 'style'),
        ),
      ).thenAnswer((invocation) async {
        // The list reload after the save must show the new row.
        when(
          () => repository.getStyles(),
        ).thenAnswer((_) async => [saved('new', 'Inter')]);
        return saved('new', 'Inter');
      });
      await cubit.load();
      await pumpView(tester);

      await tester.tap(
        find.text(l10n.videoEditorCaptionsSavedStylesSaveCurrent),
      );
      await tester.pumpAndSettle();

      // The prompt suggests the font's name so a single tap saves.
      final field = tester.widget<DivineTextField>(
        find.byKey(savedStyleNameFieldKey),
      );
      expect(field.controller?.text, equals('Inter'));

      await tester.tap(find.text(l10n.videoEditorCaptionsSavedStyleSaveAction));
      await tester.pumpAndSettle();

      verify(() => repository.save(rawName: 'Inter', style: current)).called(1);
      expect(applyRow('Inter'), findsOneWidget);
      expect(find.text(l10n.videoEditorCaptionsSavedStylesEmpty), findsNothing);
    });

    testWidgets('a typed name replaces the suggestion', (tester) async {
      when(() => repository.getStyles()).thenAnswer((_) async => []);
      when(
        () => repository.save(
          rawName: any(named: 'rawName'),
          style: any(named: 'style'),
        ),
      ).thenAnswer((_) async => saved('new', 'Series intro'));
      await cubit.load();
      await pumpView(tester);

      await tester.tap(
        find.text(l10n.videoEditorCaptionsSavedStylesSaveCurrent),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(savedStyleNameFieldKey),
        'Series intro',
      );
      await tester.pump();
      await tester.tap(find.text(l10n.videoEditorCaptionsSavedStyleSaveAction));
      await tester.pumpAndSettle();

      verify(
        () => repository.save(rawName: 'Series intro', style: current),
      ).called(1);
    });

    testWidgets('renames a saved style through its menu', (tester) async {
      when(
        () => repository.getStyles(),
      ).thenAnswer((_) async => [saved('a', 'Intro')]);
      when(
        () => repository.rename(
          id: any(named: 'id'),
          rawName: any(named: 'rawName'),
        ),
      ).thenAnswer((_) async => true);
      await cubit.load();
      await pumpView(tester);

      await tester.tap(
        find.bySemanticsLabel(
          l10n.videoEditorCaptionsSavedStyleOptionsSemanticLabel('Intro'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(l10n.videoEditorCaptionsSavedStyleRenameAction),
      );
      await tester.pumpAndSettle();

      final field = tester.widget<DivineTextField>(
        find.byKey(savedStyleNameFieldKey),
      );
      expect(field.controller?.text, equals('Intro'));

      await tester.enterText(
        find.byKey(savedStyleNameFieldKey),
        'Outro',
      );
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byType(DivineButton),
          matching: find.text(l10n.videoEditorCaptionsSavedStyleRenameAction),
        ),
      );
      await tester.pumpAndSettle();

      verify(() => repository.rename(id: 'a', rawName: 'Outro')).called(1);
    });

    testWidgets('deletes a saved style after confirming', (tester) async {
      when(
        () => repository.getStyles(),
      ).thenAnswer((_) async => [saved('a', 'Intro')]);
      when(() => repository.delete(any())).thenAnswer((_) async => true);
      await cubit.load();
      await pumpView(tester);

      await tester.tap(
        find.bySemanticsLabel(
          l10n.videoEditorCaptionsSavedStyleOptionsSemanticLabel('Intro'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.commonDelete));
      await tester.pumpAndSettle();

      expect(
        find.text(
          l10n.videoEditorCaptionsSavedStyleDeleteConfirmTitle('Intro'),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(DivineButton),
          matching: find.text(l10n.commonDelete),
        ),
      );
      await tester.pumpAndSettle();

      verify(() => repository.delete('a')).called(1);
    });

    testWidgets('cancelling the delete keeps the style', (tester) async {
      when(
        () => repository.getStyles(),
      ).thenAnswer((_) async => [saved('a', 'Intro')]);
      await cubit.load();
      await pumpView(tester);

      await tester.tap(
        find.bySemanticsLabel(
          l10n.videoEditorCaptionsSavedStyleOptionsSemanticLabel('Intro'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.commonDelete));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();

      verifyNever(() => repository.delete(any()));
      expect(applyRow('Intro'), findsOneWidget);
    });

    testWidgets('dragging a handle reorders and persists the order', (
      tester,
    ) async {
      when(
        () => repository.getStyles(),
      ).thenAnswer((_) async => [saved('a', 'Intro'), saved('b', 'Outro')]);
      when(() => repository.reorder(any())).thenAnswer((_) async {});
      await cubit.load();
      await pumpView(tester);

      // The list wraps each row in its own semantics node, so the label
      // resolves to the row; the listener is the handle itself.
      expect(
        find.bySemanticsLabel(
          l10n.videoEditorCaptionsSavedStyleReorderSemanticLabel('Intro'),
        ),
        findsOneWidget,
      );
      final handle = find.byType(ReorderableDragStartListener).first;
      final rowHeight =
          tester.getCenter(applyRow('Outro')).dy -
          tester.getCenter(applyRow('Intro')).dy;

      // Step the pointer the way a finger travels: the list moves its gap
      // only while the dragged row passes a neighbour's midpoint, so a single
      // jump past it registers no reorder at all.
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump();
      for (var step = 0; step < 10; step++) {
        await gesture.moveBy(Offset(0, rowHeight * 0.15));
        await tester.pump(const Duration(milliseconds: 20));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      verify(() => repository.reorder(['b', 'a'])).called(1);
    });

    testWidgets('offers a retry when the styles could not be read', (
      tester,
    ) async {
      final failing = _MockSavedCaptionStylesCubit();
      when(() => failing.state).thenReturn(
        const SavedCaptionStylesState(
          status: SavedCaptionStylesStatus.failure,
        ),
      );
      when(failing.load).thenAnswer((_) async {});
      await pumpView(tester, cubitOverride: failing);

      expect(
        find.text(l10n.videoEditorCaptionsSavedStylesLoadFailed),
        findsOneWidget,
      );
      await tester.tap(find.text(l10n.commonRetry));
      await tester.pumpAndSettle();

      verify(failing.load).called(1);
    });

    testWidgets('holds the previews on a visible frame under reduced motion', (
      tester,
    ) async {
      when(
        () => repository.getStyles(),
      ).thenAnswer((_) async => [saved('a', 'Intro')]);
      await cubit.load();

      await pumpView(tester);
      await tester.pump(const Duration(milliseconds: 700));

      final preview = tester.widget<CaptionStylePreview>(
        find.byType(CaptionStylePreview),
      );
      expect(preview.loopValue, equals(0.25));
    });

    testWidgets('loops the previews otherwise', (tester) async {
      when(
        () => repository.getStyles(),
      ).thenAnswer((_) async => [saved('a', 'Intro')]);
      await cubit.load();

      await pumpView(tester, disableAnimations: false);
      CaptionStylePreview preview() => tester.widget<CaptionStylePreview>(
        find.byType(CaptionStylePreview),
      );
      final before = preview().loopValue;
      await tester.pump(const Duration(milliseconds: 700));

      expect(preview().loopValue, isNot(equals(before)));
    });
  });

  group(SavedCaptionStylesSheetPage, () {
    testWidgets('loads the saved styles through the repository provider', (
      tester,
    ) async {
      final repository = _MockSavedCaptionStyleRepository();
      when(repository.getStyles).thenAnswer((_) async => [saved('a', 'Intro')]);
      tester.view
        ..physicalSize = const Size(1080, 2400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            savedCaptionStyleRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            theme: VineTheme.theme,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: SavedCaptionStylesSheetPage(currentCustomStyle: current),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      verify(repository.getStyles).called(1);
      expect(
        find.bySemanticsLabel(
          l10n.videoEditorCaptionsSavedStyleApplySemanticLabel('Intro'),
        ),
        findsOneWidget,
      );
    });
  });
}

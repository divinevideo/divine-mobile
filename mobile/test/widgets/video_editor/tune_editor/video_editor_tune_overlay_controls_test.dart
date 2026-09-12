// ABOUTME: Tests for VideoEditorTuneOverlayControls widget.
// ABOUTME: Validates the close/done toolbar dispatches the right bloc events.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/tune_editor/video_editor_tune_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/tune_editor/video_editor_tune_overlay_controls.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

class _MockVideoEditorTuneBloc
    extends MockBloc<VideoEditorTuneEvent, VideoEditorTuneState>
    implements VideoEditorTuneBloc {}

class _MockVideoEditorMainBloc
    extends MockBloc<VideoEditorMainEvent, VideoEditorMainState>
    implements VideoEditorMainBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final l10n = lookupAppLocalizations(const Locale('en'));
  final closeLabel = l10n.videoEditorDiscardToolChangesSemanticLabel(
    l10n.videoEditorTuneLabel,
  );
  final doneLabel = l10n.videoEditorApplyToolChangesSemanticLabel(
    l10n.videoEditorTuneLabel,
  );

  setUpAll(() {
    registerFallbackValue(const VideoEditorTuneCancelled());
    registerFallbackValue(const VideoEditorTuneConfirmed());
  });

  group('VideoEditorTuneOverlayControls', () {
    late _MockVideoEditorTuneBloc mockBloc;
    late _MockVideoEditorMainBloc mockMainBloc;

    setUp(() {
      mockBloc = _MockVideoEditorTuneBloc();
      mockMainBloc = _MockVideoEditorMainBloc();
      when(() => mockBloc.state).thenReturn(
        const VideoEditorTuneState(
          adjustments: [],
        ),
      );
      when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());
      when(() => mockMainBloc.state).thenReturn(const VideoEditorMainState());
      when(() => mockMainBloc.stream).thenAnswer((_) => const Stream.empty());
    });

    Widget buildWidget() {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: VideoEditorScope(
            editorKey: GlobalKey<ProImageEditorState>(),
            removeAreaKey: GlobalKey(),
            originalClipAspectRatio: 9 / 16,
            bodySizeNotifier: ValueNotifier(const Size(400, 600)),
            zoomMatrixNotifier: ValueNotifier(Matrix4.identity()),
            playTimeNotifier: ValueNotifier(Duration.zero),
            playheadAdvancingNotifier: ValueNotifier<bool>(false),
            fromLibrary: false,
            onOpenCamera: () {},
            onOpenClipsEditor: () {},
            onAddStickers: () {},
            onOpenMusicLibrary: () {},
            onOpenVoiceOver: () {},
            onOpenCaptions: () {},
            onAddEditTextLayer: ([layer]) async => null,
            child: MultiBlocProvider(
              providers: [
                BlocProvider<VideoEditorTuneBloc>.value(value: mockBloc),
                BlocProvider<VideoEditorMainBloc>.value(value: mockMainBloc),
              ],
              child: const SizedBox(
                width: 400,
                height: 600,
                child: VideoEditorTuneOverlayControls(),
              ),
            ),
          ),
        ),
      );
    }

    Finder byLabel(String label) => find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.label == label,
    );

    testWidgets('renders Close and Done buttons', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();

      expect(byLabel(closeLabel), findsOneWidget);
      expect(byLabel(doneLabel), findsOneWidget);
    });

    testWidgets('tapping Close dispatches Cancelled', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();

      await tester.tap(byLabel(closeLabel));
      await tester.pump();

      verify(() => mockBloc.add(const VideoEditorTuneCancelled())).called(1);
    });

    testWidgets('tapping Done dispatches Confirmed', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();

      await tester.tap(byLabel(doneLabel));
      await tester.pump();

      verify(() => mockBloc.add(const VideoEditorTuneConfirmed())).called(1);
    });
  });

  group('computeTuneSetCommit', () {
    String setIdOf(TuneAdjustmentMatrix m) =>
        m.meta[VideoEditorConstants.tuneSetIdMetaKey] as String? ?? m.id;
    String kindOf(TuneAdjustmentMatrix m) =>
        m.meta[VideoEditorConstants.tuneKindMetaKey] as String? ?? m.id;

    TuneAdjustmentMatrix preset(String id, double value) =>
        TuneAdjustmentMatrix(id: id, value: value, matrix: const []);

    test('new session appends a fresh set of the changed adjustments', () {
      final result = VideoEditorTuneOverlayControls.computeTuneSetCommit(
        editorMatrix: [preset('brightness', 0.2), preset('contrast', 0)],
        active: const [],
        editingSetId: null,
        newSetId: 'set-new',
      );

      expect(result, isNotNull);
      final members = result!;
      expect(members, hasLength(1));
      expect(setIdOf(members.first), 'set-new');
      expect(kindOf(members.first), 'brightness');
      expect(members.first.value, 0.2);
    });

    test('new session with no changes returns null', () {
      final result = VideoEditorTuneOverlayControls.computeTuneSetCommit(
        editorMatrix: [preset('brightness', 0)],
        active: const [],
        editingSetId: null,
        newSetId: 'set-new',
      );

      expect(result, isNull);
    });

    test('edit replaces the set in place and preserves its window', () {
      final existing = TuneAdjustmentMatrix(
        id: 'brightness__set-1',
        value: 0.2,
        matrix: const [],
        startTime: const Duration(seconds: 1),
        endTime: const Duration(seconds: 4),
        meta: const {
          VideoEditorConstants.tuneSetIdMetaKey: 'set-1',
          VideoEditorConstants.tuneKindMetaKey: 'brightness',
        },
      );
      final otherSet = TuneAdjustmentMatrix(
        id: 'contrast__set-2',
        value: 0.5,
        matrix: const [],
        meta: const {
          VideoEditorConstants.tuneSetIdMetaKey: 'set-2',
          VideoEditorConstants.tuneKindMetaKey: 'contrast',
        },
      );

      final result = VideoEditorTuneOverlayControls.computeTuneSetCommit(
        editorMatrix: [preset('brightness', -0.3)],
        active: [existing, otherSet],
        editingSetId: 'set-1',
        newSetId: 'set-new',
      )!;

      // set-2 untouched; set-1 replaced (same set id, new value, same window).
      final bySet = {for (final m in result) setIdOf(m): m};
      expect(bySet.keys, containsAll(<String>['set-1', 'set-2']));
      expect(bySet['set-2']!.value, 0.5);
      expect(bySet['set-1']!.value, -0.3);
      expect(bySet['set-1']!.startTime, const Duration(seconds: 1));
      expect(bySet['set-1']!.endTime, const Duration(seconds: 4));
    });

    test('edit keeps the set at its original position in the list', () {
      final setOne = TuneAdjustmentMatrix(
        id: 'brightness__set-1',
        value: 0.2,
        matrix: const [],
        meta: const {
          VideoEditorConstants.tuneSetIdMetaKey: 'set-1',
          VideoEditorConstants.tuneKindMetaKey: 'brightness',
        },
      );
      final setTwo = TuneAdjustmentMatrix(
        id: 'contrast__set-2',
        value: 0.5,
        matrix: const [],
        meta: const {
          VideoEditorConstants.tuneSetIdMetaKey: 'set-2',
          VideoEditorConstants.tuneKindMetaKey: 'contrast',
        },
      );

      final result = VideoEditorTuneOverlayControls.computeTuneSetCommit(
        editorMatrix: [preset('brightness', -0.3)],
        active: [setOne, setTwo],
        editingSetId: 'set-1',
        newSetId: 'set-new',
      )!;

      // set-1 stays first (its render order relative to set-2 is unchanged),
      // rather than being appended to the end.
      expect(setIdOf(result.first), 'set-1');
      expect(setIdOf(result.last), 'set-2');
    });

    test('edit that neutralises every adjustment removes the set', () {
      final existing = TuneAdjustmentMatrix(
        id: 'brightness__set-1',
        value: 0.2,
        matrix: const [],
        meta: const {
          VideoEditorConstants.tuneSetIdMetaKey: 'set-1',
          VideoEditorConstants.tuneKindMetaKey: 'brightness',
        },
      );

      final result = VideoEditorTuneOverlayControls.computeTuneSetCommit(
        editorMatrix: [preset('brightness', 0)],
        active: [existing],
        editingSetId: 'set-1',
        newSetId: 'set-new',
      );

      expect(result, isEmpty);
    });
  });
}

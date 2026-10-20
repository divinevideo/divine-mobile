// ABOUTME: Tests for the listeners that finish a detach, its way back and a
// ABOUTME: freeze frame — each lands in one editor-history entry

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/widgets/video_editor/clip_editor_result_listeners.dart';
import 'package:openvine/widgets/video_editor/detached_clip/detached_clip_layer_view.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

class _MockClipEditorBloc extends MockBloc<ClipEditorEvent, ClipEditorState>
    implements ClipEditorBloc {}

class _MockTimelineOverlayBloc
    extends MockBloc<TimelineOverlayEvent, TimelineOverlayState>
    implements TimelineOverlayBloc {}

class _MockProImageEditorState extends Mock implements ProImageEditorState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      '_MockProImageEditorState';
}

class _MockStateManager extends Mock implements StateManager {}

DivineVideoClip _clip(String id, {bool isPlaceholder = false}) =>
    DivineVideoClip(
      id: id,
      video: EditorVideo.file('/documents/$id.mp4'),
      duration: const Duration(seconds: 2),
      recordedAt: DateTime(2026),
      targetAspectRatio: .vertical,
      originalAspectRatio: 9 / 16,
      isPlaceholder: isPlaceholder,
    );

void main() {
  group(ClipEditorResultListeners, () {
    late _MockClipEditorBloc clipBloc;
    late _MockTimelineOverlayBloc overlayBloc;
    late _MockProImageEditorState editor;
    late _MockStateManager stateManager;

    setUp(() {
      clipBloc = _MockClipEditorBloc();
      overlayBloc = _MockTimelineOverlayBloc();
      editor = _MockProImageEditorState();
      stateManager = _MockStateManager();
      when(() => overlayBloc.state).thenReturn(const TimelineOverlayState());
      when(() => editor.stateManager).thenReturn(stateManager);
      when(() => stateManager.activeMeta).thenReturn({});
    });

    Widget build({
      Widget child = const SizedBox.shrink(),
      ClipEditorBloc? realClipBloc,
    }) => MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MultiBlocProvider(
        providers: [
          BlocProvider<ClipEditorBloc>.value(value: realClipBloc ?? clipBloc),
          BlocProvider<TimelineOverlayBloc>.value(value: overlayBloc),
        ],
        child: VideoEditorScope(
          editorKey: GlobalKey(),
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
          onAddEditTextLayer: ([layer]) async => null,
          onOpenMusicLibrary: () {},
          onOpenVoiceOver: () {},
          onOpenCaptions: () {},
          onOpenEffects: () {},
          editorOverride: editor,
          child: ClipEditorResultListeners(child: child),
        ),
      ),
    );

    group('stabilize', () {
      Future<void> pumpResult(
        WidgetTester tester,
        ClipStabilizeResult result,
      ) async {
        whenListen(
          clipBloc,
          Stream.value(
            ClipEditorState(clips: [_clip('a')], lastStabilizeResult: result),
          ),
          initialState: const ClipEditorState(),
        );
        // A Scaffold below the listeners shows what they send to the messenger.
        await tester.pumpWidget(
          build(child: const Scaffold(body: SizedBox.shrink())),
        );
        await tester.pump();
      }

      testWidgets('tells the user when stabilizing fails', (tester) async {
        await pumpResult(tester, ClipStabilizeFailure(stabilizing: true));

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.videoEditorStabilizeFailed), findsOneWidget);
      });

      testWidgets('tells the user when turning it off fails', (tester) async {
        await pumpResult(tester, ClipStabilizeFailure(stabilizing: false));

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.videoEditorUnstabilizeFailed), findsOneWidget);
      });

      testWidgets(
        'explains that missing original footage cannot be restored',
        (tester) async {
          await pumpResult(tester, ClipStabilizeOriginalMissing());

          final l10n = lookupAppLocalizations(const Locale('en'));
          expect(
            find.text(l10n.videoEditorUnstabilizeOriginalMissing),
            findsOneWidget,
          );
        },
      );

      testWidgets('stays quiet when stabilizing succeeds', (tester) async {
        await pumpResult(tester, ClipStabilizeSuccess(stabilized: true));

        expect(find.byType(SnackBar), findsNothing);
      });
    });

    testWidgets('a detach records the placeholder that took the slot', (
      tester,
    ) async {
      final placeholder = _clip('placeholder_1', isPlaceholder: true);
      whenListen(
        clipBloc,
        Stream.value(
          ClipEditorState(
            clips: [_clip('a'), placeholder],
            lastDetachResult: ClipDetachSuccess(
              previousClips: [_clip('a'), _clip('b')],
              detachedClip: _clip('b'),
              placeholder: placeholder,
            ),
          ),
        ),
        initialState: const ClipEditorState(),
      );

      await tester.pumpWidget(build());
      await tester.pump();

      final layer =
          verify(
                () => editor.addHistory(
                  newLayer: captureAny(named: 'newLayer'),
                  meta: any(named: 'meta'),
                ),
              ).captured.single
              as Layer;
      // Without it, putting the clip back could not find its slot.
      expect(
        DetachedClipLayerData.placeholderClipIdOf(
          DetachedClipLayerData.metaOf(layer),
        ),
        'placeholder_1',
      );
    });

    testWidgets(
      'a layout inserted first detaches in its rendered media shape',
      (tester) async {
        final bloc = (await tester.runAsync(() async {
          final bloc = ClipEditorBloc(
            onFinalClipInvalidated: () {},
            saveClipToLibrary: ({required clip}) async => false,
          );
          bloc.add(
            ClipEditorInitialized([
              _clip('source').copyWith(originalAspectRatio: 3 / 4),
            ]),
          );
          await bloc.stream.first;
          bloc.add(
            ClipEditorSplitScreenLayoutInserted(
              clip: _clip('layout'),
              playhead: Duration.zero,
            ),
          );
          await bloc.stream.first;
          return bloc;
        }))!;
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(bloc.close);
        });
        final inserted = bloc.state;
        expect(inserted.clips.first.originalAspectRatio, 3 / 4);
        expect(inserted.clips.first.videoAspectRatio, 9 / 16);

        await tester.pumpWidget(build(realClipBloc: bloc));
        await tester.runAsync(() async {
          final detached = bloc.stream.firstWhere(
            (state) => state.lastDetachResult is ClipDetachSuccess,
          );
          bloc.add(const ClipEditorClipDetachRequested(clipId: 'layout'));
          await detached;
        });
        await tester.pumpAndSettle();

        final layer =
            verify(
                  () => editor.addHistory(
                    newLayer: captureAny(named: 'newLayer'),
                    meta: any(named: 'meta'),
                  ),
                ).captured.single
                as WidgetLayer;
        final detached = DetachedClipLayerData.fromMeta(
          DetachedClipLayerData.metaOf(layer),
          '/documents',
        )!.clip;
        // The detached preview and export use this geometry; the canvas
        // keeps its existing coordinates throughout insertion and detach.
        expect(detached.originalAspectRatio, 9 / 16);
        expect(detached.videoAspectRatio, 9 / 16);
        expect(bloc.state.clips.single.originalAspectRatio, 3 / 4);

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Center(
              child: SizedBox(
                width: 120,
                child: FittedBox(
                  child: DetachedClipPoster(
                    meta: DetachedClipLayerData.metaOf(layer)!,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final frame = tester.getSize(find.byType(ClipRRect));
        expect(frame.width / frame.height, closeTo(9 / 16, 1e-9));
      },
    );

    testWidgets('detaching a wide source keeps its timeline circle round', (
      tester,
    ) async {
      const circle = LayerMask(
        shape: LayerMaskShape.ellipse,
        size: Size(0.5, 9 / 32),
        feather: 0.2,
      );
      final source = _clip('b').copyWith(
        originalAspectRatio: 16 / 9,
        mask: circle,
      );
      whenListen(
        clipBloc,
        Stream.value(
          ClipEditorState(
            clips: [_clip('a')],
            lastDetachResult: ClipDetachSuccess(
              previousClips: [_clip('a'), source],
              detachedClip: source,
            ),
          ),
        ),
        initialState: const ClipEditorState(),
      );

      await tester.pumpWidget(build());
      await tester.pump();

      final layer =
          verify(
                () => editor.addHistory(
                  newLayer: captureAny(named: 'newLayer'),
                  meta: any(named: 'meta'),
                ),
              ).captured.single
              as Layer;
      final mask = layer.mask!;
      expect(mask.size.width * 16 / 9, closeTo(mask.size.height, 1e-9));
      expect(mask.size.height, circle.size.height);
      expect(mask.feather, closeTo(circle.feather * 9 / 16, 1e-9));
      expect(source.mask, circle);
    });

    testWidgets('every detach gets its own layer id, even for the same clip', (
      tester,
    ) async {
      // A clip that went back to the timeline keeps its id, so detaching it a
      // second time must not hand its new layer the id of the first.
      ClipEditorState detached() => ClipEditorState(
        clips: [_clip('a')],
        lastDetachResult: ClipDetachSuccess(
          previousClips: [_clip('a'), _clip('b')],
          detachedClip: _clip('b'),
        ),
      );
      whenListen(
        clipBloc,
        Stream.fromIterable([detached(), detached()]),
        initialState: const ClipEditorState(),
      );

      await tester.pumpWidget(build());
      await tester.pump();
      await tester.pump();

      final layers = verify(
        () => editor.addHistory(
          newLayer: captureAny(named: 'newLayer'),
          meta: any(named: 'meta'),
        ),
      ).captured.cast<Layer>();
      expect(layers, hasLength(2));
      expect(layers.first.id, isNot(layers.last.id));
      // The meta names the layer by the same id, or its window is read off the
      // wrong timeline item.
      for (final layer in layers) {
        expect(
          DetachedClipLayerData.layerIdOf(DetachedClipLayerData.metaOf(layer)),
          layer.id,
        );
      }
    });

    testWidgets('a layout clip joins editor history at its seam', (
      tester,
    ) async {
      when(() => overlayBloc.state).thenReturn(
        const TimelineOverlayState(timelineMarkers: [Duration(seconds: 3)]),
      );
      whenListen(
        clipBloc,
        Stream.value(
          ClipEditorState(
            clips: [_clip('a'), _clip('split_layout_1'), _clip('b')],
            lastSplitScreenLayoutResult: ClipSplitScreenLayoutResult(
              previousClips: [_clip('a'), _clip('b')],
              clipId: 'split_layout_1',
            ),
          ),
        ),
        initialState: const ClipEditorState(),
      );

      await tester.pumpWidget(build());
      await tester.pump();

      // The marker on the clip after the layout follows its footage.
      verify(
        () => overlayBloc.add(
          const TimelineMarkersRebased([Duration(seconds: 5)]),
        ),
      ).called(1);
      final meta =
          verify(
                () => editor.addHistory(meta: captureAny(named: 'meta')),
              ).captured.single
              as Map<String, dynamic>;
      final clips =
          meta[VideoEditorConstants.clipsStateHistoryKey] as List<dynamic>;
      expect(clips.map((c) => (c as Map<String, dynamic>)['id']), [
        'a',
        'split_layout_1',
        'b',
      ]);
    });

    testWidgets('putting a clip back removes its layer in the same entry', (
      tester,
    ) async {
      when(() => editor.activeLayers).thenReturn([
        TextLayer(id: 'text', text: 'hi'),
        TextLayer(id: 'detached_b', text: 'clip'),
      ]);
      whenListen(
        clipBloc,
        Stream.value(
          ClipEditorState(
            clips: [_clip('a'), _clip('b')],
            lastDetachedClipReattachResult: DetachedClipReattachResult(
              previousClips: [
                _clip('a'),
                _clip('placeholder_1', isPlaceholder: true),
              ],
              layerId: 'detached_b',
              clipId: 'b',
            ),
          ),
        ),
        initialState: const ClipEditorState(),
      );

      await tester.pumpWidget(build());
      await tester.pump();

      final captured = verify(
        () => editor.addHistory(
          layers: captureAny(named: 'layers'),
          meta: captureAny(named: 'meta'),
        ),
      ).captured;
      expect((captured[0] as List<Layer>).map((l) => l.id), ['text']);
      final clips =
          (captured[1] as Map<String, dynamic>)[VideoEditorConstants
                  .clipsStateHistoryKey]
              as List<dynamic>;
      expect(clips.map((c) => (c as Map<String, dynamic>)['id']), ['a', 'b']);
    });

    testWidgets('a freeze moves the markers after it and commits the clips', (
      tester,
    ) async {
      final freeze = _clip('freeze_1').copyWith(
        isFreezeFrame: true,
        trimEnd: const Duration(milliseconds: 1500),
      );
      when(() => overlayBloc.state).thenReturn(
        const TimelineOverlayState(
          timelineMarkers: [Duration(seconds: 1), Duration(seconds: 3)],
        ),
      );
      whenListen(
        clipBloc,
        Stream.value(
          ClipEditorState(
            clips: [_clip('a'), freeze, _clip('b')],
            lastFreezeFrameResult: ClipFreezeFrameSuccess(
              previousClips: [_clip('a'), _clip('b')],
              freezeClipId: 'freeze_1',
            ),
          ),
        ),
        initialState: const ClipEditorState(),
      );

      await tester.pumpWidget(build());
      await tester.pump();

      // The marker on the clip after the freeze follows its footage half a
      // second later; the one before it stays put.
      const markers = [Duration(seconds: 1), Duration(milliseconds: 3500)];
      verify(
        () => overlayBloc.add(const TimelineMarkersRebased(markers)),
      ).called(1);
      final meta =
          verify(
                () => editor.addHistory(meta: captureAny(named: 'meta')),
              ).captured.single
              as Map<String, dynamic>;
      final clips =
          meta[VideoEditorConstants.clipsStateHistoryKey] as List<dynamic>;
      expect(clips.map((c) => (c as Map<String, dynamic>)['id']), [
        'a',
        'freeze_1',
        'b',
      ]);
    });
  });
}

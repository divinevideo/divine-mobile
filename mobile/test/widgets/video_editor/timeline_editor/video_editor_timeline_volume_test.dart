// ABOUTME: Widget tests for VideoEditorTimelineVolume.
// ABOUTME: Covers clip/custom-audio rendering and volume interactions.

import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_volume.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group(VideoEditorTimelineVolume, () {
    late ClipEditorBloc clipBloc;
    late TimelineOverlayBloc overlayBloc;
    late ValueNotifier<double?> volumePreviewNotifier;

    setUp(() {
      clipBloc = ClipEditorBloc(
        onFinalClipInvalidated: () {},
        saveClipToLibrary: ({required clip}) async => false,
      );
      overlayBloc = TimelineOverlayBloc();
      volumePreviewNotifier = ValueNotifier<double?>(null);
    });

    tearDown(() async {
      volumePreviewNotifier.dispose();
      await clipBloc.close();
      await overlayBloc.close();
    });

    Widget buildWidget() {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<ClipEditorBloc>.value(value: clipBloc),
              BlocProvider<TimelineOverlayBloc>.value(value: overlayBloc),
            ],
            child: VideoEditorTimelineVolume(
              volumePreviewNotifier: volumePreviewNotifier,
            ),
          ),
        ),
      );
    }

    testWidgets(
      'renders clip arcs and independent audio arcs, hiding only '
      'clip-anchored original sound',
      (tester) async {
        clipBloc.add(
          ClipEditorInitialized([
            _createTestClip(id: 'clip-a'),
            _createTestClip(id: 'clip-b'),
          ]),
        );
        overlayBloc.add(
          TimelineOverlayItemsUpdate(
            layers: const <Layer>[],
            filters: const <FilterState>[],
            audioTracks: [
              _audioTrack(id: 'custom-1', title: 'Beat'),
              // Original sound added from another video (not anchored to a
              // clip) — keeps its own volume arc.
              _audioTrack(id: 'video_added', title: 'Added sound'),
              // Original sound anchored to a clip — controlled via the clip
              // arc, so no separate arc.
              _audioTrack(
                id: 'video_original',
                title: 'Original sound',
                anchorClipId: 'clip-a',
              ),
            ],
            totalVideoDuration: const Duration(seconds: 10),
          ),
        );

        await tester.pumpWidget(buildWidget());
        await tester.pump();

        expect(find.bySemanticsLabel('Clip 1'), findsOneWidget);
        expect(find.bySemanticsLabel('Clip 2'), findsOneWidget);
        expect(find.bySemanticsLabel('Beat'), findsOneWidget);
        expect(find.bySemanticsLabel('Added sound'), findsOneWidget);
        expect(find.bySemanticsLabel('Original sound'), findsNothing);
      },
    );

    testWidgets('tap toggles a clip to mute', (tester) async {
      clipBloc.add(ClipEditorInitialized([_createTestClip(id: 'clip-a')]));

      await tester.pumpWidget(buildWidget());
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Clip 1'));
      await tester.pump();

      expect(clipBloc.state.clips.first.volume, 0.0);
      expect(clipBloc.state.clipsVolumeRevision, 1);
    });

    testWidgets('drag previews and commits custom audio volume on release', (
      tester,
    ) async {
      overlayBloc.add(
        TimelineOverlayItemsUpdate(
          layers: const <Layer>[],
          filters: const <FilterState>[],
          audioTracks: [_audioTrack(id: 'custom-1', title: 'Beat')],
          totalVideoDuration: const Duration(seconds: 10),
        ),
      );

      await tester.pumpWidget(buildWidget());
      await tester.pump();

      final beatFinder = find.bySemanticsLabel('Beat');
      await tester.drag(beatFinder, const Offset(200, 0));
      await tester.pump();

      expect(volumePreviewNotifier.value, isNull);
      expect(overlayBloc.state.audioTracks.first.volume, lessThan(0.1));
      expect(overlayBloc.state.audioTracksRevision, 1);
    });

    testWidgets('clip arc exposes long-press semantic action and hint', (
      tester,
    ) async {
      clipBloc.add(ClipEditorInitialized([_createTestClip(id: 'clip-a')]));

      final handle = tester.ensureSemantics();
      await tester.pumpWidget(buildWidget());
      await tester.pump();

      final data = tester.getSemantics(find.bySemanticsLabel('Clip 1'));
      expect(
        data.getSemanticsData().hasAction(SemanticsAction.longPress),
        isTrue,
      );

      handle.dispose();
    });
  });
}

DivineVideoClip _createTestClip({required String id}) {
  return DivineVideoClip(
    id: id,
    video: EditorVideo.file('/tmp/$id.mp4'),
    duration: const Duration(seconds: 3),
    recordedAt: DateTime(2025),
    originalAspectRatio: 9 / 16,
    targetAspectRatio: .vertical,
  );
}

AudioEvent _audioTrack({
  required String id,
  required String title,
  String? anchorClipId,
}) {
  return AudioEvent(
    id: id,
    pubkey: 'pubkey-$id',
    createdAt: 1704067200,
    title: title,
    startTime: const Duration(seconds: 1),
    endTime: const Duration(seconds: 4),
    anchorClipId: anchorClipId,
  );
}

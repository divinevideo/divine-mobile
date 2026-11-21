// ABOUTME: Exercises camera-return cleanup against the real editor lifecycle.
// ABOUTME: Holds storage cleanup pending while the editor is removed.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/screens/video_editor/video_editor_screen.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

import '../../helpers/test_provider_overrides.dart';

// Only draft loading is held: the real screen, scope and blocs own the lifecycle.
class _Editor extends VideoEditorNotifier {
  final initialized = Completer<void>();

  @override
  VideoEditorProviderState build() => VideoEditorProviderState();

  @override
  Future<void> initialize({String? draftId}) => initialized.future;
}

// Replace storage-bound clip removal with a completion boundary under test control.
class _Clips extends ClipManagerNotifier {
  _Clips(this.initialClips);

  final List<DivineVideoClip> initialClips;
  final cleanupStarted = <String>[];
  final cleanupFinished = <String>[];
  final cleanup = Completer<void>();

  @override
  ClipManagerState build() => ClipManagerState(clips: initialClips);

  @override
  List<DivineVideoClip> get clips => state.clips;

  @override
  void replaceClips(List<DivineVideoClip> clips, {bool autosave = true}) {
    state = state.copyWith(clips: clips);
  }

  @override
  Future<bool> removeClipById(String clipId) async {
    cleanupStarted.add(clipId);
    await cleanup.future;
    replaceClips(clips.where((clip) => clip.id != clipId).toList());
    cleanupFinished.add(clipId);
    return true;
  }
}

class _Library extends Mock implements ClipLibraryService {
  final cleanupStarted = <String>[];
  final cleanupFinished = <String>[];
  final cleanup = Completer<void>();

  @override
  Future<void> deleteClipRow(String id) async {
    cleanupStarted.add(id);
    await cleanup.future;
    cleanupFinished.add(id);
  }
}

DivineVideoClip _clip(String id, {bool stopMotion = false}) => DivineVideoClip(
  id: id,
  video: stopMotion ? null : EditorVideo.file('/documents/$id.mp4'),
  stopMotionFrames: stopMotion
      ? [
          StopMotionClipFrame(
            path: '/documents/$id.jpg',
            duration: const Duration(milliseconds: 100),
          ),
        ]
      : null,
  duration: const Duration(milliseconds: 100),
  recordedAt: DateTime(2026),
  originalAspectRatio: 9 / 16,
  targetAspectRatio: .vertical,
);

void main() {
  group('camera return cleanup', () {
    final logs = LogCaptureService();
    setUp(logs.clearAllLogs);
    tearDown(logs.clearAllLogs);

    Future<
      ({
        VideoEditorScope scope,
        ClipEditorBloc bloc,
        GlobalKey<NavigatorState> navigator,
        _Editor editor,
      })
    >
    pumpEditor(WidgetTester tester, _Clips clips, _Library library) async {
      final editor = _Editor();
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...getStandardTestOverrides(),
            clipManagerProvider.overrideWith(() => clips),
            clipLibraryServiceProvider.overrideWithValue(library),
            videoEditorProvider.overrideWith(() => editor),
            forYouSoundCoversProvider.overrideWith((ref) async => {}),
            divineSoundsProvider.overrideWith((ref) async => []),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            navigatorKey: navigator,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: const VideoEditorScreen(draftId: 'draft'),
          ),
        ),
      );
      final scope = tester.widget<VideoEditorScope>(
        find.byType(VideoEditorScope),
      );
      final bloc = tester
          .element(find.byType(VideoEditorScope))
          .read<ClipEditorBloc>();
      return (scope: scope, bloc: bloc, navigator: navigator, editor: editor);
    }

    void expectNoEditorFailure(WidgetTester tester) {
      expect(tester.takeException(), isNull);
      expect(
        logs
            .getRecentLogs()
            .where(
              (entry) =>
                  entry.name == 'VideoEditorScreen' &&
                  entry.level == LogLevel.error,
            )
            .map((entry) => '${entry.error}\n${entry.stackTrace}'),
        isEmpty,
      );
    }

    for (final stopMotion in [false, true]) {
      for (final unmount in [false, true]) {
        testWidgets(
          '${stopMotion ? 'stop-motion commit' : 'cancel rollback'} '
          '${unmount ? 'finishes after unmount' : 'syncs the mounted editor'}',
          (tester) async {
            final original = _clip('original', stopMotion: stopMotion);
            final clips = _Clips([original]);
            final library = _Library();
            final fixture = await pumpEditor(tester, clips, library);
            await tester.pump();
            expect(fixture.bloc.state.clips.map((clip) => clip.id), [
              'original',
            ]);

            fixture.scope.onOpenCamera();
            // Metadata enrichment can finish while the recorder is open.
            final returningOriginal = stopMotion
                ? original
                : original.copyWith(
                    duration: const Duration(milliseconds: 200),
                  );
            clips.replaceClips([
              returningOriginal,
              _clip('capture-a', stopMotion: stopMotion),
              _clip('capture-b', stopMotion: stopMotion),
            ]);
            // Return before the camera's first frame: device camera APIs are
            // outside this test's camera-return/cleanup boundary.
            fixture.navigator.currentState!.pop(stopMotion);
            await tester.pump();
            expect(
              stopMotion ? library.cleanupStarted : clips.cleanupStarted,
              ['capture-a'],
            );

            if (unmount) {
              // Keep app-scoped providers alive while disposing the screen.
              fixture.navigator.currentState!.pushReplacement<void, void>(
                MaterialPageRoute(builder: (_) => const SizedBox()),
              );
              await tester.pumpAndSettle();
              expect(find.byType(VideoEditorScreen), findsNothing);
              expect(fixture.bloc.isClosed, isTrue);
            }

            library.cleanup.complete();
            clips.cleanup.complete();
            await tester.pumpAndSettle();
            expect(
              stopMotion ? library.cleanupFinished : clips.cleanupFinished,
              ['capture-a', 'capture-b'],
            );
            expect(clips.clips.map((clip) => clip.id), ['original']);
            if (stopMotion) {
              expect(
                clips.clips.single.stopMotionFrames!.map((frame) => frame.path),
                [
                  '/documents/capture-a.jpg',
                  '/documents/capture-b.jpg',
                  '/documents/original.jpg',
                ],
              );
            }
            if (!unmount) {
              expect(fixture.bloc.isClosed, isFalse);
              expect(fixture.bloc.state.clips, clips.clips);
              if (!stopMotion) {
                expect(
                  fixture.bloc.state.clips.single.duration,
                  const Duration(milliseconds: 200),
                );
              }
            }
            expectNoEditorFailure(tester);

            await tester.pumpWidget(const SizedBox());
            fixture.editor.initialized.complete();
            await tester.pumpAndSettle();
          },
        );
      }
    }
  });
}

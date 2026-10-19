// ABOUTME: Looks for where the last clip can end so the video loops without a
// ABOUTME: visible jump, and holds the suggestion until it is kept (#10249).

import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/loop_point_search.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/video_editor/clip_loop_point_service.dart';
import 'package:openvine/services/video_editor/video_render_failures.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show RenderCanceledException;
import 'package:unified_logger/unified_logger.dart';

part 'loop_suggestion_state.dart';

/// Suggests a trim of the last clip that makes the video loop seamlessly.
///
/// The clips stay in the clip editor: this only reports the trimmed clip,
/// and the editor shows it, plays the seam, and keeps or drops it before it
/// calls [resultHandled].
class LoopSuggestionCubit extends Cubit<LoopSuggestionState>
    with CloseGuardedEmit<LoopSuggestionState> {
  LoopSuggestionCubit({
    FindClipLoopPointFn? findLoopPoint,
    CancelClipLoopPointFn? cancelSearch,
  }) : _findLoopPoint = findLoopPoint ?? ClipLoopPointService.findLoopPoint,
       _cancelSearch = cancelSearch ?? ClipLoopPointService.cancel,
       super(const LoopSuggestionState());

  static const _logName = 'LoopSuggestionCubit';

  final FindClipLoopPointFn _findLoopPoint;
  final CancelClipLoopPointFn _cancelSearch;

  /// Looks for a smoother end of [clips]' last clip. Does nothing while a
  /// search runs or a suggestion waits, or when [loopPointSearchFor] finds
  /// nothing to compare.
  Future<void> search(List<DivineVideoClip> clips) async {
    if (state.status != LoopSuggestionStatus.idle) return;
    final search = loopPointSearchFor(clips);
    if (search == null) return;
    final clip = clips.last;
    emit(
      LoopSuggestionState(
        status: LoopSuggestionStatus.searching,
        original: clip,
      ),
    );
    try {
      final point = await _findLoopPoint(
        search: search,
        taskId: ClipLoopPointService.taskIdFor(clip.id),
        onProgress: (progress) {
          if (state.isSearching && state.clipId == clip.id) {
            emitIfOpen(state.copyWith(progress: progress));
          }
        },
      );
      Log.info(
        '🔁 Loop point for clip ${clip.id}: end '
        '${search.end.inMicroseconds} -> ${point.end.inMicroseconds} µs, '
        'seam ${point.currentDifference.toStringAsFixed(4)} -> '
        '${point.difference.toStringAsFixed(4)}',
        name: _logName,
        category: LogCategory.video,
      );
      final smoother =
          point.end != search.end &&
          point.difference <
              point.currentDifference *
                  VideoEditorConstants.loopPointImprovementShare;
      const closeMatch = VideoEditorConstants.loopPointCloseMatchDifference;
      emitIfOpen(
        smoother
            ? LoopSuggestionState(
                status: LoopSuggestionStatus.suggested,
                progress: 1,
                original: clip,
                suggested: clipEndingAt(clip, point.end),
                isCloseMatch: point.difference <= closeMatch,
              )
            : LoopSuggestionState(
                status: point.currentDifference <= closeMatch
                    ? LoopSuggestionStatus.alreadySmooth
                    : LoopSuggestionStatus.noMatch,
                progress: 1,
                original: clip,
              ),
      );
    } on RenderCanceledException {
      emitIfOpen(const LoopSuggestionState());
    } on PlatformException catch (error, stackTrace) {
      // A clip could not be decoded: an expected failure of the footage.
      Log.error(
        'Loop point search could not read a clip: $error',
        name: _logName,
        category: LogCategory.video,
      );
      addError(error, stackTrace);
      emitIfOpen(_failed(clip));
    } on VideoRenderFailedException catch (error, stackTrace) {
      // The watchdog gave up; it reported the timeout itself.
      addError(error, stackTrace);
      emitIfOpen(_failed(clip));
    } catch (error, stackTrace) {
      Log.error(
        'Loop point search failed: $error',
        name: _logName,
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
      addError(Reportable(error, context: 'search'), stackTrace);
      emitIfOpen(_failed(clip));
    }
  }

  static LoopSuggestionState _failed(DivineVideoClip clip) =>
      LoopSuggestionState(status: LoopSuggestionStatus.failed, original: clip);

  /// Stops the search that runs now; [state] then goes back to idle.
  Future<void> cancel() async {
    final clipId = state.clipId;
    if (!state.isSearching || clipId == null) return;
    await _cancelSearch(ClipLoopPointService.taskIdFor(clipId));
  }

  /// Forgets the last result once the editor kept, dropped or reported it.
  void resultHandled() {
    if (state.isSearching || state.status == LoopSuggestionStatus.idle) return;
    emit(const LoopSuggestionState());
  }

  @override
  Future<void> close() {
    // The decoding would run on for a closed editor.
    if (state.isSearching) {
      runDetached(
        cancel(),
        'cancel loop point search',
        logName: _logName,
        category: LogCategory.video,
      );
    }
    return super.close();
  }
}

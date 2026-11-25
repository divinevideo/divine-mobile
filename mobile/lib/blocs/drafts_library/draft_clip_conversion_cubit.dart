// ABOUTME: Renders a saved draft into one clip and stores it in the library.
// ABOUTME: The draft stays as it is; the clip is a new library entry.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/video_editor/draft_render_parameters_service.dart';
import 'package:openvine/services/video_editor/video_render_failures.dart';
import 'package:unified_logger/unified_logger.dart';

/// Where converting a draft into a library clip stands.
enum DraftClipConversionStatus {
  /// Nothing is being converted.
  idle,

  /// The draft is being rendered and saved.
  converting,

  /// The clip is in the library.
  converted,

  /// The conversion failed for a reason the user cannot act on.
  failed,

  /// The draft's text and stickers could not be prepared for the render.
  overlaysUnavailable,

  /// The device ran out of storage during the render.
  lowStorage,
}

/// Turns a saved draft into one clip in the clip library.
///
/// Only one conversion runs at a time: a render holds the device's encoder,
/// and a second one would only slow the first down.
class DraftClipConversionCubit extends Cubit<DraftClipConversionStatus>
    with CloseGuardedEmit<DraftClipConversionStatus> {
  DraftClipConversionCubit({
    required Future<DivineVideoDraft?> Function(String draftId) loadDraft,
    required Future<DivineVideoClip> Function(DivineVideoDraft draft)
    renderDraft,
    required Future<void> Function(DivineVideoClip clip) saveClip,
    required Future<void> Function(
      DivineVideoClip clip,
      DivineVideoDraft draft,
    )
    discardClip,
  }) : _loadDraft = loadDraft,
       _renderDraft = renderDraft,
       _saveClip = saveClip,
       _discardClip = discardClip,
       super(DraftClipConversionStatus.idle);

  final Future<DivineVideoDraft?> Function(String draftId) _loadDraft;
  final Future<DivineVideoClip> Function(DivineVideoDraft draft) _renderDraft;
  final Future<void> Function(DivineVideoClip clip) _saveClip;

  /// Deletes the files of a clip rendered from the draft that never reached
  /// the library, sparing the files the draft still uses.
  final Future<void> Function(DivineVideoClip clip, DivineVideoDraft draft)
  _discardClip;

  static const _logName = 'DraftClipConversionCubit';

  /// Renders the draft [draftId] and saves the result as a library clip.
  ///
  /// The conversion goes on when this cubit closes, so the clip still lands
  /// in the library after the user leaves the screen.
  Future<void> convert(String draftId) async {
    if (state == DraftClipConversionStatus.converting) return;
    emit(DraftClipConversionStatus.converting);

    // The render writes into the persistent documents dir, so a clip that
    // does not reach the library must be deleted here.
    DivineVideoClip? unsaved;
    DivineVideoDraft? draft;
    try {
      draft = await _loadDraft(draftId);
      // Deleted or emptied of media since the list loaded.
      if (draft == null || !draft.canPost) {
        Log.warning(
          '📚 Draft $draftId is no longer available to convert',
          name: _logName,
          category: LogCategory.video,
        );
        emitIfOpen(DraftClipConversionStatus.failed);
        return;
      }

      unsaved = await _renderDraft(draft);
      await _saveClip(unsaved);
      Log.info(
        '✅ Converted draft $draftId into library clip ${unsaved.id}',
        name: _logName,
        category: LogCategory.video,
      );
      unsaved = null;
      emitIfOpen(DraftClipConversionStatus.converted);
    } on DraftOverlayRestoreException catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(DraftClipConversionStatus.overlaysUnavailable);
    } on VideoRenderFailedException catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(
        error.reason == VideoRenderFailureReason.insufficientStorage
            ? DraftClipConversionStatus.lowStorage
            : DraftClipConversionStatus.failed,
      );
    } on Object catch (error, stackTrace) {
      Log.error(
        '❌ Failed to convert draft $draftId into a clip: $error',
        name: _logName,
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
      addError(
        switch (error) {
          StateError() ||
          TypeError() ||
          RangeError() => Reportable(error, context: 'convert'),
          _ => error,
        },
        stackTrace,
      );
      emitIfOpen(DraftClipConversionStatus.failed);
    } finally {
      if (unsaved != null && draft != null) await _discardClip(unsaved, draft);
    }
  }
}

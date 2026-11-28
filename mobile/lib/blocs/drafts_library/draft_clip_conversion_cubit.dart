// ABOUTME: Renders a saved draft into one clip and stores it in the library.
// ABOUTME: The draft stays as it is; the clip is a new library entry.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/video_editor/draft_render_parameters_service.dart';
import 'package:openvine/services/video_editor/video_editor_clip_library_save_service.dart';
import 'package:openvine/services/video_editor/video_render_failures.dart';
import 'package:openvine/utils/detached_future.dart';
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

/// The draft conversion running in the app, if any.
///
/// The render outlives the library screen that started it, and every screen
/// creates its own [DraftClipConversionCubit]. Sharing this between them lets
/// a library opened mid-render follow that conversion instead of rendering
/// the draft a second time.
class DraftClipConversions {
  Future<DraftClipConversionStatus>? _running;

  /// The outcome of the conversion in flight, or null when none runs.
  Future<DraftClipConversionStatus>? get running => _running;

  /// Starts [conversion], or returns the outcome of the one already running.
  ///
  /// Only one runs at a time: a render holds the device's encoder, and a
  /// second one would only slow the first down.
  Future<DraftClipConversionStatus> run(
    Future<DraftClipConversionStatus> Function() conversion,
  ) {
    if (_running case final running?) return running;
    final started = conversion();
    _running = started;
    return started.whenComplete(() => _running = null);
  }
}

/// Turns a saved draft into one clip in the clip library.
class DraftClipConversionCubit extends Cubit<DraftClipConversionStatus>
    with CloseGuardedEmit<DraftClipConversionStatus> {
  /// Starts out converting when [conversions] already has a conversion
  /// running, and reports its outcome: the screen that started it may be
  /// gone.
  DraftClipConversionCubit({
    required DraftClipConversions conversions,
    required Future<DivineVideoDraft?> Function(String draftId) loadDraft,
    required Future<DraftLibraryRender> Function(DivineVideoDraft draft)
    renderDraft,
    required Future<void> Function(DivineVideoClip clip) saveClip,
    required Future<void> Function(
      DivineVideoClip clip, {
      String? keepThumbnailPath,
    })
    discardClip,
  }) : _conversions = conversions,
       _loadDraft = loadDraft,
       _renderDraft = renderDraft,
       _saveClip = saveClip,
       _discardClip = discardClip,
       super(
         conversions.running == null
             ? DraftClipConversionStatus.idle
             : DraftClipConversionStatus.converting,
       ) {
    if (conversions.running case final running?) {
      runDetached(
        running.then(emitIfOpen),
        'follow a running draft conversion',
        logName: _logName,
        category: LogCategory.video,
      );
    }
  }

  final DraftClipConversions _conversions;
  final Future<DivineVideoDraft?> Function(String draftId) _loadDraft;
  final Future<DraftLibraryRender> Function(DivineVideoDraft draft)
  _renderDraft;
  final Future<void> Function(DivineVideoClip clip) _saveClip;

  /// Deletes the files of a clip rendered from the draft that never reached
  /// the library, sparing the thumbnail it may have borrowed.
  final Future<void> Function(
    DivineVideoClip clip, {
    String? keepThumbnailPath,
  })
  _discardClip;

  static const _logName = 'DraftClipConversionCubit';

  /// Renders the draft [draftId] and saves the result as a library clip.
  ///
  /// The conversion goes on when this cubit closes, so the clip still lands
  /// in the library after the user leaves the screen. While another
  /// conversion runs, this reports that one's outcome instead.
  Future<void> convert(String draftId) async {
    if (state == DraftClipConversionStatus.converting) return;
    emit(DraftClipConversionStatus.converting);
    emitIfOpen(await _conversions.run(() => _convert(draftId)));
  }

  Future<DraftClipConversionStatus> _convert(String draftId) async {
    // The render writes into the persistent documents dir, so a clip that
    // does not reach the library must be deleted here.
    DraftLibraryRender? unsaved;
    try {
      final draft = await _loadDraft(draftId);
      // Deleted or emptied of media since the list loaded.
      if (draft == null || !draft.canPost) {
        Log.warning(
          '📚 Draft $draftId is no longer available to convert',
          name: _logName,
          category: LogCategory.video,
        );
        return DraftClipConversionStatus.failed;
      }

      unsaved = await _renderDraft(draft);
      await _saveClip(unsaved.clip);
      Log.info(
        '✅ Converted draft $draftId into library clip ${unsaved.clip.id}',
        name: _logName,
        category: LogCategory.video,
      );
      unsaved = null;
      return DraftClipConversionStatus.converted;
    } on DraftOverlayRestoreException catch (error, stackTrace) {
      addError(error, stackTrace);
      return DraftClipConversionStatus.overlaysUnavailable;
    } on VideoRenderFailedException catch (error, stackTrace) {
      addError(error, stackTrace);
      return error.reason == VideoRenderFailureReason.insufficientStorage
          ? DraftClipConversionStatus.lowStorage
          : DraftClipConversionStatus.failed;
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
      return DraftClipConversionStatus.failed;
    } finally {
      if (unsaved != null) {
        await _discardClip(
          unsaved.clip,
          keepThumbnailPath: unsaved.sourceThumbnailPath,
        );
      }
    }
  }
}

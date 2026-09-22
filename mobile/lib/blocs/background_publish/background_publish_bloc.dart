import 'dart:io';
import 'dart:typed_data';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/background_publish/publish_foreground_session.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/video_publish/publish_error_kind.dart';
import 'package:openvine/services/video_publish/video_publish_service.dart';
import 'package:unified_logger/unified_logger.dart';

part 'background_publish_event.dart';
part 'background_publish_state.dart';

class BackgroundPublishBloc
    extends Bloc<BackgroundPublishEvent, BackgroundPublishState> {
  BackgroundPublishBloc({
    required Future<VideoPublishService> Function({
      required OnProgressChanged onProgress,
    })
    videoPublishServiceFactory,
    required DraftStorageService draftStorageService,
    PublishForegroundSession? foregroundSession,
  }) : _videoPublishServiceFactory = videoPublishServiceFactory,
       _draftStorageService = draftStorageService,
       _foregroundSession = foregroundSession,
       super(const BackgroundPublishState()) {
    on<BackgroundPublishRequested>(
      _onBackgroundPublishRequested,
      transformer: sequential(),
    );
    on<BackgroundPublishProgressChanged>(_onBackgroundPublishProgressChanged);
    on<BackgroundPublishVanished>(_onBackgroundPublishVanished);
    on<BackgroundPublishRetryRequested>(_onBackgroundPublishRetryRequested);
    on<BackgroundPublishFailed>(_onBackgroundPublishFailed);
  }

  final Future<VideoPublishService> Function({
    required OnProgressChanged onProgress,
  })
  _videoPublishServiceFactory;

  final DraftStorageService _draftStorageService;

  /// Keeps the process foregrounded for the whole publish so the in-process
  /// steps after the OS-backed upload (signing, relay broadcast) survive app
  /// suspension, and so do the durable writes that record how the publish
  /// ended. Null disables the behaviour (e.g. in tests).
  final PublishForegroundSession? _foregroundSession;

  Future<void> _onBackgroundPublishRequested(
    BackgroundPublishRequested event,
    Emitter<BackgroundPublishState> emit,
  ) async {
    // Check if the upload is already in progress
    final alreadyUploading = state.uploads.any(
      (upload) => upload.draft.id == event.draft.id,
    );
    if (!alreadyUploading) {
      final newUpload = BackgroundUpload(
        draft: event.draft,
        result: null,
        progress: 0,
      );
      emit(state.copyWith(uploads: [...state.uploads, newUpload]));
    }

    await _beginForegroundSession(event.draft.id);
    try {
      final result = await _awaitPublishResult(event.publishmentProcess);

      // Remove the upload if it was successful
      if (result is PublishSuccess) {
        final updatedUploads = state.uploads
            .where((upload) => upload.draft.id != event.draft.id)
            .toList();

        // Read before the emit: _deletePublishedDrafts below reclaims the
        // cover file, so a path handed to the confirmation would dangle by
        // the time the sheet decoded it.
        final thumbnailBytes = await _readCoverThumbnail(event.draft);

        emit(
          state.copyWith(
            uploads: updatedUploads,
            recentlyPublished: [
              PublishedVideo(
                draftId: event.draft.id,
                stableId: result.stableId,
                thumbnailBytes: thumbnailBytes,
              ),
            ],
          ),
        );

        // After the emit — the video is already live, so the draft row and its
        // unreferenced media are reclaimed off the publish critical path
        // rather than in front of the success state (#6548). Still inside the
        // foreground session: deleting the row is the only record that this
        // publish finished, so losing the process first makes resume offer a
        // retry for an already-published video.
        await _deletePublishedDrafts(event.draft);
      } else if (result is PublishScheduled) {
        // The media is up and the signed event waits for its time (#3538).
        // The publish copy stays as the scheduled draft the Scheduled tab
        // shows and a cancel parks; only the source it was copied from is
        // reclaimed, as it would be after an immediate publish.
        final updatedUploads = state.uploads
            .where((upload) => upload.draft.id != event.draft.id)
            .toList();
        emit(state.copyWith(uploads: updatedUploads));
        await _persistPublishStatus(
          draftId: event.draft.id,
          status: PublishStatus.scheduled,
        );
        await _deleteSourceDraft(event.draft);
      } else {
        // Update the upload with the result
        final updatedUploads = state.uploads.map((upload) {
          if (upload.draft.id == event.draft.id) {
            return upload.copyWith(result: result, progress: 1.0);
          }
          return upload;
        }).toList();

        emit(state.copyWith(uploads: updatedUploads));

        // Persist the classified kind (same encoding the service writes), so
        // the service/bloc writes are idempotent and resume re-localizes
        // correctly.
        final publishError = result is PublishError
            ? result.toPersistedString()
            : null;
        await _persistPublishStatus(
          draftId: event.draft.id,
          status: PublishStatus.failed,
          publishError: publishError,
        );
      }
    } finally {
      await _endForegroundSession(event.draft.id);
    }
  }

  /// Awaits the publish, turning a thrown error into a [PublishError] so the
  /// caller always has a result to record.
  Future<PublishResult> _awaitPublishResult(
    Future<PublishResult> publishmentProcess,
  ) async {
    try {
      return await publishmentProcess;
    } catch (e, stackTrace) {
      Log.error(
        'Publish process threw an exception: $e',
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
      addError(e, stackTrace);
      return const PublishError(PublishErrorKind.generic);
    }
  }

  /// Best-effort: keeping the process foregrounded is an optimisation, so a
  /// failure here must never abort the publish itself.
  Future<void> _beginForegroundSession(String sessionId) async {
    try {
      await _foregroundSession?.begin(sessionId);
    } catch (e) {
      Log.warning(
        'Failed to begin publish foreground session: $e',
        category: LogCategory.video,
      );
    }
  }

  Future<void> _endForegroundSession(String sessionId) async {
    try {
      await _foregroundSession?.end(sessionId);
    } catch (e) {
      Log.warning(
        'Failed to end publish foreground session: $e',
        category: LogCategory.video,
      );
    }
  }

  void _onBackgroundPublishProgressChanged(
    BackgroundPublishProgressChanged event,
    Emitter<BackgroundPublishState> emit,
  ) {
    final upload = state.uploads.cast<BackgroundUpload?>().firstWhere(
      (upload) => upload!.draft.id == event.draftId,
      orElse: () => null,
    );

    // Disregard progress events if the upload already has a result
    // or if the progress is not greater than the current value,
    // since events can arrive out of order.
    if (upload == null ||
        upload.result != null ||
        event.progress <= upload.progress) {
      return;
    }

    final updatedUploads = state.uploads.map((upload) {
      if (upload.draft.id == event.draftId) {
        return upload.copyWith(progress: event.progress);
      }
      return upload;
    }).toList();

    emit(state.copyWith(uploads: updatedUploads));
  }

  Future<void> _onBackgroundPublishVanished(
    BackgroundPublishVanished event,
    Emitter<BackgroundPublishState> emit,
  ) async {
    final uploadToVanish = state.uploads.cast<BackgroundUpload?>().firstWhere(
      (upload) => upload!.draft.id == event.draftId,
      orElse: () => null,
    );
    final remainingUploads = state.uploads.where((upload) {
      return upload.draft.id != event.draftId;
    }).toList();
    emit(state.copyWith(uploads: remainingUploads));

    await _park(draftId: event.draftId, draft: uploadToVanish?.draft);
  }

  /// Parks every upload that has not finished yet back as a draft, awaiting
  /// the writes.
  ///
  /// A caller that is about to tear down the container this bloc lives in —
  /// the account switch — must use this instead of adding one
  /// [BackgroundPublishVanished] per upload: `add` is fire-and-forget, so the
  /// handler's writes would race the teardown and the video would be lost on
  /// anything slower than a single fast write. The events are still dispatched
  /// afterwards, for the in-memory cleanup only; re-parking an already parked
  /// upload is a no-op.
  Future<void> parkInFlight() async {
    final inFlight = state.uploads
        .where((upload) => upload.result == null)
        .toList();
    if (inFlight.isEmpty) return;

    for (final upload in inFlight) {
      await _park(
        draftId: upload.draft.id,
        draft: upload.draft,
        propagateFailure: true,
      );
    }
    for (final upload in inFlight) {
      if (isClosed) return;
      add(BackgroundPublishVanished(draftId: upload.draft.id));
    }
  }

  /// Keeps an abandoned upload's video reachable.
  ///
  /// Dropping the publish copy is only safe while the draft it was copied from
  /// is still there to fall back on; otherwise the copy is the last row holding
  /// the video and deleting it would discard the video instead of saving it.
  /// Park the copy as a draft in that case.
  ///
  /// [VideoEditorConstants.autoSaveId] never counts as a surviving source, even
  /// when a row under that id is on disk. A fresh recording's source *is* that
  /// autosave draft, which `clearAll` reaps ~600ms after the publish handoff —
  /// and it is a single slot every later editor session recycles, so whatever
  /// sits there by the time this upload is parked belongs to a different
  /// session, or (since [DraftStorageService.draftExists] is deliberately
  /// unscoped) to another account. Reading that as "the source survived" would
  /// delete the only copy of the video. Parking a copy whose autosave row does
  /// still hold the same video costs a duplicate draft; the other way round
  /// costs the video.
  ///
  /// Idempotent: a repeat call finds the copy already deleted, or rewrites the
  /// same draft status. Ownership-neutral by design — every write it makes is
  /// keyed on the draft's primary key and none of them touch `ownerPubkey`, so
  /// the row stays with the account that recorded it no matter which account
  /// the service handed here belongs to.
  Future<void> _park({
    required String draftId,
    required DivineVideoDraft? draft,
    bool propagateFailure = false,
  }) async {
    final sourceDraftId = draft?.sourceDraftId;
    if (sourceDraftId != null &&
        sourceDraftId != draft!.id &&
        sourceDraftId != VideoEditorConstants.autoSaveId &&
        await _draftStorageService.draftExists(sourceDraftId)) {
      await _deleteDraft(draft.id);
      return;
    }

    await _persistPublishStatus(
      draftId: draftId,
      status: PublishStatus.draft,
      propagateFailure: propagateFailure,
    );
  }

  Future<void> _onBackgroundPublishRetryRequested(
    BackgroundPublishRetryRequested event,
    Emitter<BackgroundPublishState> emit,
  ) async {
    final uploadToRetry = state.uploads.firstWhere(
      (upload) => upload.draft.id == event.draftId,
    );

    // Clear previous result
    final clearedUploads = state.uploads.where((upload) {
      return upload.draft.id != event.draftId;
    }).toList();
    emit(state.copyWith(uploads: clearedUploads));

    final videoPublishService = await _videoPublishServiceFactory(
      onProgress: ({required String draftId, required double progress}) {
        if (isClosed) return;
        add(
          BackgroundPublishProgressChanged(
            draftId: draftId,
            progress: progress,
          ),
        );
      },
    );
    if (isClosed) return;

    final newPublishProcess = videoPublishService.publishVideo(
      draft: uploadToRetry.draft,
    );

    add(
      BackgroundPublishRequested(
        draft: uploadToRetry.draft,
        publishmentProcess: newPublishProcess,
      ),
    );
  }

  void _onBackgroundPublishFailed(
    BackgroundPublishFailed event,
    Emitter<BackgroundPublishState> emit,
  ) {
    final alreadyTracked = state.uploads.any(
      (upload) => upload.draft.id == event.draft.id,
    );
    if (alreadyTracked) return;

    final failedUpload = BackgroundUpload(
      draft: event.draft,
      result: event.error,
      progress: 0,
    );
    emit(state.copyWith(uploads: [...state.uploads, failedUpload]));
  }

  /// Reads the draft's cover frame so the post-publish confirmation can
  /// outlive the draft's files.
  ///
  /// Null when the draft carried no cover, the file is already gone, or it
  /// cannot be read — the confirmation renders its placeholder, which is
  /// strictly better than failing the publish over a preview image.
  Future<Uint8List?> _readCoverThumbnail(DivineVideoDraft draft) async {
    final path = draft.coverThumbnailPath;
    if (path == null || path.isEmpty) return null;
    try {
      final file = File(path);
      if (!file.existsSync()) return null;
      return await file.readAsBytes();
    } catch (error) {
      Log.warning(
        'Failed to read cover thumbnail for ${draft.id}: $error',
        name: 'BackgroundPublishBloc',
        category: LogCategory.video,
      );
      return null;
    }
  }

  /// Reclaims a published draft: the publish copy, plus the draft it was
  /// copied from. Sole owner of post-publish draft deletion — the publish
  /// service intentionally leaves the draft in place (see
  /// [VideoPublishService.publishVideo]).
  Future<void> _deletePublishedDrafts(DivineVideoDraft publishedDraft) async {
    await _deleteDraft(publishedDraft.id);
    await _deleteSourceDraft(publishedDraft);
  }

  /// Reclaims the draft a publish copy was made from, never the autosave
  /// slot (see [_park]).
  Future<void> _deleteSourceDraft(DivineVideoDraft publishCopy) async {
    final sourceDraftId = publishCopy.sourceDraftId;
    if (sourceDraftId != null &&
        sourceDraftId != publishCopy.id &&
        sourceDraftId != VideoEditorConstants.autoSaveId) {
      await _deleteDraft(sourceDraftId);
    }
  }

  Future<void> _deleteDraft(String draftId) async {
    try {
      await _draftStorageService.deleteDraft(draftId);
    } catch (error, stackTrace) {
      Log.error(
        'Failed to delete publish draft $draftId: $error',
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
      addError(error, stackTrace);
    }
  }

  Future<void> _persistPublishStatus({
    required String draftId,
    required PublishStatus status,
    String? publishError,
    bool propagateFailure = false,
  }) async {
    try {
      final updated = await _draftStorageService.updatePublishStatus(
        draftId: draftId,
        status: status,
        publishError: publishError,
      );
      if (!updated) {
        throw StateError('Draft $draftId was missing during status update');
      }
    } catch (error, stackTrace) {
      Log.error(
        'Failed to persist publish status for draft $draftId: $error',
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
      addError(error, stackTrace);
      if (propagateFailure) rethrow;
    }
  }
}

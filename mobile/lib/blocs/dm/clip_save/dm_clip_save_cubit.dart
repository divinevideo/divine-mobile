// ABOUTME: Cubit that adds a clip received in a DM to the clip library,
// ABOUTME: once its C2PA credential proves it is a Divine camera capture.

import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/models/dm_clip_tag.dart';
import 'package:openvine/services/clip_provenance_verifier.dart';
import 'package:openvine/services/dm_video_decryptor.dart';
import 'package:openvine/services/video_clip_import_service.dart';

/// Adds a verified received clip to one account's clip library.
typedef ReceivedClipImporter = Future<VideoClipImportResult> Function({
  required File source,
  required String messageId,
  required String senderPubkey,
  required String c2paManifestId,
  AspectRatio? targetAspectRatio,
  List<String> contributorPubkeys,
});

/// Returns the [ReceivedClipImporter] for the signed-in account's library.
///
/// Resolved when a save starts rather than when the screen opens, since the
/// library is per account and a screen can outlive an account switch. Not
/// resolved once the check is done either: the check can take many seconds,
/// and the clip belongs to the account that received it and asked to save it.
typedef ReceivedClipImporterResolver = ReceivedClipImporter Function();

/// Lifecycle of adding one received clip to the library.
enum DmClipSaveStatus {
  /// Nothing is being saved.
  idle,

  /// The clip is being downloaded, decrypted and checked.
  checking,

  /// The clip passed the check and is in the library.
  saved,

  /// The clip's credential does not prove a Divine camera capture, so it was
  /// not added.
  notVerified,

  /// The check could not run right now; nothing is known about the clip.
  checkUnavailable,

  /// Downloading, decrypting or saving failed. Reported through `addError`.
  failed,
}

/// [DmClipSaveCubit] state.
class DmClipSaveState extends Equatable {
  /// Creates a [DmClipSaveState].
  const DmClipSaveState({this.status = DmClipSaveStatus.idle});

  /// Outcome of the most recent save.
  final DmClipSaveStatus status;

  @override
  List<Object?> get props => [status];
}

/// Adds a clip received in a direct message to the clip library.
///
/// A clip is only added when [ClipProvenanceVerifier] confirms it is an
/// untouched Divine camera capture, so a clip library never holds footage
/// whose origin is unknown or generated. The decrypted temp file is always
/// removed before the save settles; the library keeps its own copy.
class DmClipSaveCubit extends Cubit<DmClipSaveState>
    with CloseGuardedEmit<DmClipSaveState> {
  /// Creates a [DmClipSaveCubit].
  DmClipSaveCubit({
    required DmVideoDecryptor decryptor,
    required ClipProvenanceVerifier verifier,
    required ReceivedClipImporterResolver resolveImporter,
  }) : _decryptor = decryptor,
       _verifier = verifier,
       _resolveImporter = resolveImporter,
       super(const DmClipSaveState());

  final DmVideoDecryptor _decryptor;
  final ClipProvenanceVerifier _verifier;
  final ReceivedClipImporterResolver _resolveImporter;

  /// Containers the C2PA reader is given. The decrypted file's extension
  /// comes from the sender's `file-type` tag and picks the reader's parser,
  /// so anything else is refused before it is decrypted. Divine recordings
  /// are always MP4.
  static const Set<String> verifiableFileTypes = {
    'video/mp4',
    'video/quicktime',
  };

  /// Downloads, decrypts and checks [message]'s clip, and adds it to the
  /// library of the account signed in when this was called if it passes.
  ///
  /// Saves run independently, so a second video can be added while another
  /// is still being checked; each call returns its own outcome. The work is
  /// not cancelled by [close], so a caller that outlives the screen can still
  /// report the outcome.
  Future<DmClipSaveStatus> save(DmMessage message) async {
    final importClip = _resolveImporter();
    emit(const DmClipSaveState(status: DmClipSaveStatus.checking));

    final status = await _save(message, importClip);
    emitIfOpen(DmClipSaveState(status: status));
    return status;
  }

  Future<DmClipSaveStatus> _save(
    DmMessage message,
    ReceivedClipImporter importClip,
  ) async {
    final fileType = message.fileMetadata?.fileType.toLowerCase();
    if (!verifiableFileTypes.contains(fileType)) {
      return DmClipSaveStatus.notVerified;
    }

    String? path;
    try {
      path = await _decryptor.decryptToFile(message);

      final provenance = await _verifier.verify(path);
      if (!provenance.isVerified) {
        return provenance.isRejected
            ? DmClipSaveStatus.notVerified
            : DmClipSaveStatus.checkUnavailable;
      }

      final result = await importClip(
        source: File(path),
        messageId: message.id,
        senderPubkey: message.senderPubkey,
        c2paManifestId: provenance.activeManifestId!,
        targetAspectRatio: message.clipTargetAspectRatio,
        contributorPubkeys: provenance.contributors,
      );
      switch (result) {
        case VideoClipImportSuccess():
          return DmClipSaveStatus.saved;
        case VideoClipImportFailure(
          reason: VideoClipImportFailureReason.sourceLookupFailed,
        ):
          // Whether it is a published post, and so whom to credit, could not
          // be checked; like a check that could not run, try again later.
          return DmClipSaveStatus.checkUnavailable;
        case VideoClipImportFailure(:final reason):
          addError(DmClipImportFailure(reason), StackTrace.current);
          return DmClipSaveStatus.failed;
      }
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      return DmClipSaveStatus.failed;
    } finally {
      if (path != null) _decryptor.deleteClip(path);
    }
  }
}

/// A verified clip the library import could not store. Diagnostic only.
class DmClipImportFailure implements Exception {
  /// Creates a [DmClipImportFailure] for [reason].
  const DmClipImportFailure(this.reason);

  /// Why the import failed.
  final VideoClipImportFailureReason reason;

  @override
  String toString() => 'DmClipImportFailure: ${reason.name}';
}

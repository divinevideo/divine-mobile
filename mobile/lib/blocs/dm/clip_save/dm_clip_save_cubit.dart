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

/// Adds a verified received clip to the signed-in account's clip library.
///
/// A function rather than a [VideoClipImportService], so the caller resolves
/// the library at the moment of the save: the library is per account, and a
/// service captured when the thread opened would outlive an account switch.
typedef ReceivedClipImporter = Future<VideoClipImportResult> Function({
  required File source,
  required String senderPubkey,
  required String c2paManifestId,
  AspectRatio? targetAspectRatio,
});

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
    required ReceivedClipImporter importClip,
  }) : _decryptor = decryptor,
       _verifier = verifier,
       _importClip = importClip,
       super(const DmClipSaveState());

  final DmVideoDecryptor _decryptor;
  final ClipProvenanceVerifier _verifier;
  final ReceivedClipImporter _importClip;

  /// Downloads, decrypts and checks [message]'s clip, and adds it to the
  /// library if it passes. A second call while one is running is dropped.
  Future<void> save(DmMessage message) async {
    if (state.status == DmClipSaveStatus.checking) return;
    emit(const DmClipSaveState(status: DmClipSaveStatus.checking));

    String? path;
    try {
      path = await _decryptor.decryptToFile(message);

      final provenance = await _verifier.verify(path);
      if (!provenance.isVerified) {
        emitIfOpen(
          DmClipSaveState(
            status: provenance.isRejected
                ? DmClipSaveStatus.notVerified
                : DmClipSaveStatus.checkUnavailable,
          ),
        );
        return;
      }

      final result = await _importClip(
        source: File(path),
        senderPubkey: message.senderPubkey,
        c2paManifestId: provenance.activeManifestId!,
        targetAspectRatio: message.clipTargetAspectRatio,
      );
      switch (result) {
        case VideoClipImportSuccess():
          emitIfOpen(const DmClipSaveState(status: DmClipSaveStatus.saved));
        case VideoClipImportFailure(:final reason):
          addError(DmClipImportFailure(reason), StackTrace.current);
          emitIfOpen(const DmClipSaveState(status: DmClipSaveStatus.failed));
      }
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(const DmClipSaveState(status: DmClipSaveStatus.failed));
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

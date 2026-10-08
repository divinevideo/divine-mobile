// ABOUTME: Cubit for the encrypted video DM send flow.
// ABOUTME: Owns the picker-free send lifecycle so the composer renders
// ABOUTME: progress without knowing the encrypt/upload/send pipeline.

import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/dm_clip_tag.dart';
import 'package:openvine/services/clip_provenance_verifier.dart';
import 'package:openvine/services/dm_video_encryption.dart';
import 'package:openvine/services/dm_video_send_service.dart';

/// Size limit for a picked video, in whole megabytes, for display copy.
const int videoDmMaxMegabytes = dmVideoMaxPlaintextBytes ~/ (1024 * 1024);

/// Maps a picked file's extension to the plaintext MIME type recorded in the
/// kind 15 metadata. Defaults to `video/mp4`, the format the gallery picker
/// returns on both platforms.
String videoDmMimeTypeFor(String path) {
  final extension = path.split('.').last.toLowerCase();
  return switch (extension) {
    'mov' => 'video/quicktime',
    'm4v' => 'video/x-m4v',
    'webm' => 'video/webm',
    'avi' => 'video/x-msvideo',
    'mkv' => 'video/x-matroska',
    '3gp' => 'video/3gpp',
    _ => 'video/mp4',
  };
}

/// How a [VideoDmSendCubit.sendClips] call ended.
class ClipSendOutcome extends Equatable {
  /// Creates a [ClipSendOutcome].
  const ClipSendOutcome(
    this.status, {
    required this.sentCount,
    required this.total,
  });

  /// The terminal status: [VideoDmSendStatus.sent] when every clip went out.
  final VideoDmSendStatus status;

  /// How many clips were delivered before the send ended.
  final int sentCount;

  /// How many clips were picked.
  final int total;

  /// Whether some, but not all, clips went out.
  bool get isPartial => sentCount > 0 && sentCount < total;

  @override
  List<Object?> get props => [status, sentCount, total];
}

/// Lifecycle of a single encrypted video DM send.
enum VideoDmSendStatus {
  /// No send has started.
  idle,

  /// A library clip's C2PA credential is being checked before it is sent.
  checking,

  /// The plaintext file is being encrypted for upload.
  encrypting,

  /// The ciphertext is being uploaded to Blossom.
  uploading,

  /// The kind 15 file message is being published to relays.
  sending,

  /// The recipient gift wrap reached a relay.
  sent,

  /// The picked file exceeds [dmVideoMaxPlaintextBytes]; nothing was
  /// uploaded.
  tooLarge,

  /// A library clip failed its C2PA camera-capture check, so it was not
  /// sent: the recipient could never add it to their clips.
  clipNotVerified,

  /// The send did not complete. The cause is reported through `addError`.
  failed,
}

/// [VideoDmSendCubit] state: the current pipeline stage.
class VideoDmSendState extends Equatable {
  /// Creates a [VideoDmSendState].
  const VideoDmSendState({this.status = VideoDmSendStatus.idle});

  /// Current pipeline stage.
  final VideoDmSendStatus status;

  /// Whether a send is actively running and the composer should show progress.
  bool get isSending =>
      status == VideoDmSendStatus.checking ||
      status == VideoDmSendStatus.encrypting ||
      status == VideoDmSendStatus.uploading ||
      status == VideoDmSendStatus.sending;

  @override
  List<Object?> get props => [status];
}

/// Drives one encrypted video DM send: encrypt, upload, publish.
///
/// A send already in flight drops a second call rather than queueing it, so a
/// double tap cannot publish two events for one picked file.
class VideoDmSendCubit extends Cubit<VideoDmSendState>
    with CloseGuardedEmit<VideoDmSendState> {
  /// Creates a [VideoDmSendCubit] backed by [service].
  ///
  /// [clipVerifier] checks a library clip before [sendClips] uploads it.
  /// Without one the check is left to the recipient, whose own check is the
  /// one that decides whether the clip may enter their library.
  ///
  /// [signOwnRecordings] signs the sender's own recordings among the clips
  /// whose signing at record time failed, for example offline, so they can
  /// still be sent as clips.
  VideoDmSendCubit({
    required DmVideoSendService service,
    ClipProvenanceVerifier? clipVerifier,
    Future<void> Function(List<DivineVideoClip> clips)? signOwnRecordings,
  }) : _service = service,
       _clipVerifier = clipVerifier,
       _signOwnRecordings = signOwnRecordings,
       super(const VideoDmSendState());

  final DmVideoSendService _service;
  final ClipProvenanceVerifier? _clipVerifier;
  final Future<void> Function(List<DivineVideoClip> clips)? _signOwnRecordings;

  /// Sends [videoFile] to [recipientPubkey] as a NIP-17 kind 15 file message.
  ///
  /// The plaintext MIME type is derived from the file extension with
  /// [videoDmMimeTypeFor]. The cubit only maps the service's phase callbacks
  /// and result to state; it holds no display copy.
  Future<void> send({
    required String recipientPubkey,
    required File videoFile,
  }) async {
    if (state.isSending) return;

    emit(const VideoDmSendState(status: VideoDmSendStatus.encrypting));
    try {
      final result = await _service.sendVideo(
        recipientPubkey: recipientPubkey,
        videoFile: videoFile,
        mimeType: videoDmMimeTypeFor(videoFile.path),
        onPhase: _onPhase,
      );
      if (result.success) {
        emitIfOpen(const VideoDmSendState(status: VideoDmSendStatus.sent));
        return;
      }
      addError(
        VideoDmSendFailure(result.error ?? 'unknown'),
        StackTrace.current,
      );
      emitIfOpen(const VideoDmSendState(status: VideoDmSendStatus.failed));
    } on DmVideoTooLargeException catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(const VideoDmSendState(status: VideoDmSendStatus.tooLarge));
    } catch (error, stackTrace) {
      // DivineBlocObserver logs every addError and forwards only
      // programming-invariant errors to crash reporting.
      addError(error, stackTrace);
      emitIfOpen(const VideoDmSendState(status: VideoDmSendStatus.failed));
    }
  }

  /// Sends each of [clips] to [recipientPubkey] as a kind 15 file message
  /// marked with a [DmClipTag], one after another.
  ///
  /// Every clip's C2PA credential is checked before the first upload, so a
  /// clip the recipient could not add to their library is never uploaded,
  /// and one failing clip keeps the whole selection from going out. A check
  /// that cannot run (no trust anchors, no C2PA on this platform) does not
  /// block the send, since the recipient checks again anyway. A send that
  /// fails stops the remaining clips, so the selection can end up partly
  /// sent; [ClipSendOutcome.sentCount] says how far it got.
  ///
  /// The work is not cancelled by [close]: leaving the chat lets the clips
  /// finish going out, and the caller reports the returned outcome. Progress
  /// is emitted while the cubit is open; it returns to idle at the end.
  ///
  /// Returns null when a send is already running or [clips] is empty.
  Future<ClipSendOutcome?> sendClips({
    required String recipientPubkey,
    required List<DivineVideoClip> clips,
  }) async {
    if (state.isSending || clips.isEmpty) return null;

    final outcome = await _sendClips(recipientPubkey, clips);
    emitIfOpen(const VideoDmSendState());
    return outcome;
  }

  Future<ClipSendOutcome> _sendClips(
    String recipientPubkey,
    List<DivineVideoClip> clips,
  ) async {
    final total = clips.length;
    var sentCount = 0;
    ClipSendOutcome outcome(VideoDmSendStatus status) =>
        ClipSendOutcome(status, sentCount: sentCount, total: total);

    try {
      final paths = <String>[];
      for (final clip in clips) {
        final path = clip.video?.file?.path;
        if (path == null) {
          addError(
            VideoDmSendFailure('clip ${clip.id} has no video file'),
            StackTrace.current,
          );
          return outcome(VideoDmSendStatus.failed);
        }
        paths.add(path);
      }

      final verifier = _clipVerifier;
      if (verifier != null) {
        emitIfOpen(const VideoDmSendState(status: VideoDmSendStatus.checking));
        await _signOwnRecordings?.call(clips);
        for (final path in paths) {
          final provenance = await verifier.verify(path);
          if (provenance.isRejected) {
            return outcome(VideoDmSendStatus.clipNotVerified);
          }
        }
      }

      for (final (index, clip) in clips.indexed) {
        final path = paths[index];
        emitIfOpen(
          const VideoDmSendState(status: VideoDmSendStatus.encrypting),
        );
        final result = await _service.sendVideo(
          recipientPubkey: recipientPubkey,
          videoFile: File(path),
          mimeType: videoDmMimeTypeFor(path),
          extraTags: [DmClipTag.build(clip.targetAspectRatio)],
          onPhase: _onPhase,
        );
        if (!result.success) {
          addError(
            VideoDmSendFailure(result.error ?? 'unknown'),
            StackTrace.current,
          );
          return outcome(VideoDmSendStatus.failed);
        }
        sentCount++;
      }
      return outcome(VideoDmSendStatus.sent);
    } on DmVideoTooLargeException catch (error, stackTrace) {
      addError(error, stackTrace);
      return outcome(VideoDmSendStatus.tooLarge);
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      return outcome(VideoDmSendStatus.failed);
    }
  }

  void _onPhase(DmVideoSendPhase phase) {
    if (isClosed) return;
    final status = switch (phase) {
      DmVideoSendPhase.encrypting => VideoDmSendStatus.encrypting,
      DmVideoSendPhase.uploading => VideoDmSendStatus.uploading,
      DmVideoSendPhase.sending => VideoDmSendStatus.sending,
    };
    if (status == state.status) return;
    emitIfOpen(VideoDmSendState(status: status));
  }
}

/// A send the pipeline refused or could not complete, carrying the
/// repository's diagnostic reason for logs. Never shown to the user.
class VideoDmSendFailure implements Exception {
  /// Creates a [VideoDmSendFailure] with a diagnostic [reason].
  const VideoDmSendFailure(this.reason);

  /// Diagnostic text from the send result.
  final String reason;

  @override
  String toString() => 'VideoDmSendFailure: $reason';
}

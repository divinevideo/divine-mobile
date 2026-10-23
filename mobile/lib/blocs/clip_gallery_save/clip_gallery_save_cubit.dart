// ABOUTME: Cubit that saves library clips to the device gallery, signing the
// ABOUTME: app's own unsigned clips first and naming copies left without proof.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/clip_provenance_verifier.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:openvine/services/video_editor/stop_motion_render_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show RenderCanceledException;

/// Signs the app's own clips among `clips` that were left unsigned, and
/// returns the ids of those still unsigned afterwards that signing again
/// later can fix, such as recordings made offline.
typedef ClipLateSigner = Future<Set<String>> Function(
  List<DivineVideoClip> clips,
);

/// Why a clip went to the gallery without a C2PA credential that proves it
/// was shot with Divine, so the gallery import turns its copy away.
enum ClipGallerySaveWarning {
  /// Its proof could not be added right now, for example offline. Saving it
  /// again later can add it.
  signingUnavailable,

  /// A stop-motion clip, rendered from stills, which carry no proof.
  stopMotion,

  /// This build of the app cannot sign clips.
  signingUnsupported,

  /// It has no proof and none can be added: footage this app did not
  /// record, or an edit whose history cannot be shown.
  noProof,

  /// It carries a credential, but one that does not prove a Divine capture,
  /// for example because the file changed after it was signed.
  notVerified;

  /// Whether saving the clip again later can add its proof.
  bool get isRetryable => this == signingUnavailable;
}

/// How one clip of a gallery save went.
class ClipGallerySaveResult extends Equatable {
  /// Creates a [ClipGallerySaveResult].
  const ClipGallerySaveResult(this.clip, {required this.saved, this.warning});

  /// The library clip.
  final DivineVideoClip clip;

  /// Whether a copy of [clip] reached the gallery in this save.
  final bool saved;

  /// Why [clip] has no proof that it was shot with Divine. Null when it has
  /// one, or when that could not be checked.
  final ClipGallerySaveWarning? warning;

  @override
  List<Object?> get props => [clip, saved, warning];
}

/// How a [ClipGallerySaveCubit.saveClips] call ended.
class ClipGallerySaveOutcome extends Equatable {
  /// Creates a [ClipGallerySaveOutcome].
  const ClipGallerySaveOutcome({
    required this.results,
    required this.total,
    this.permissionDenied = false,
  });

  /// How each clip went, in the order given. Shorter than [total] when the
  /// save stopped early.
  final List<ClipGallerySaveResult> results;

  /// How many clips were to be saved.
  final int total;

  /// Whether the save stopped because the gallery refused access.
  final bool permissionDenied;

  /// How many clips reached the gallery.
  int get savedCount => results.where((result) => result.saved).length;

  /// How many clips were tried and did not reach the gallery.
  int get failedCount => results.length - savedCount;

  /// The clips whose copy reached the gallery without proof, so it cannot be
  /// brought back into the clip library.
  List<ClipGallerySaveResult> get savedWithoutProof => [
    for (final result in results)
      if (result.saved && result.warning != null) result,
  ];

  @override
  List<Object?> get props => [results, total, permissionDenied];
}

/// What [ClipGallerySaveCubit] is doing.
enum ClipGallerySaveStatus {
  /// No save is running.
  idle,

  /// The app's own unsigned clips are being signed.
  signing,

  /// Clips are being checked and saved, one after another.
  saving,
}

/// [ClipGallerySaveCubit] state.
class ClipGallerySaveState extends Equatable {
  /// Creates a [ClipGallerySaveState].
  const ClipGallerySaveState({
    this.status = ClipGallerySaveStatus.idle,
    this.results = const [],
    this.savingCount = 0,
    this.doneCount = 0,
  });

  /// What the cubit is doing.
  final ClipGallerySaveStatus status;

  /// How many clips the running save handles. Zero when none is running.
  final int savingCount;

  /// How many clips of the running save are done.
  final int doneCount;

  /// How each clip saved so far went the last time it was saved, in the
  /// order the clips were first handed over.
  final List<ClipGallerySaveResult> results;

  /// Whether a save is running.
  bool get isSaving => status != ClipGallerySaveStatus.idle;

  /// Whether a clip in [results] can get its proof by being saved again.
  bool get hasRetryableClips =>
      results.any((result) => result.warning?.isRetryable ?? false);

  @override
  List<Object?> get props => [status, results, savingCount, doneCount];
}

/// Saves clips from the clip library to the device gallery so they can be
/// brought back with the gallery import (#10062), which only takes videos
/// whose C2PA credential proves a Divine camera capture.
///
/// A clip leaves as its exact file and keeps whatever manifest it has. The
/// app's own clips whose signing failed earlier, for example offline, are
/// signed first, as the DM clip send does. A clip that still has no proof is
/// saved anyway, and its result says why, so the user can be told that its
/// copy cannot come back.
class ClipGallerySaveCubit extends Cubit<ClipGallerySaveState>
    with CloseGuardedEmit<ClipGallerySaveState> {
  /// Creates a [ClipGallerySaveCubit].
  ///
  /// Without a [verifier] no clip is signed or checked, and none gets a
  /// warning: on a platform that cannot read C2PA there is no gallery import
  /// to bring clips back with. [signOwnClips] signs the app's own clips that
  /// were left unsigned, and [canSign] says whether this build can sign at
  /// all. [results] seeds the state, for a page that shows an earlier save.
  ClipGallerySaveCubit({
    required GallerySaveService gallerySaveService,
    ClipProvenanceVerifier? verifier,
    ClipLateSigner? signOwnClips,
    bool canSign = true,
    List<ClipGallerySaveResult> results = const [],
  }) : _gallerySaveService = gallerySaveService,
       _verifier = verifier,
       _signOwnClips = signOwnClips,
       _canSign = canSign,
       super(ClipGallerySaveState(results: results));

  final GallerySaveService _gallerySaveService;
  final ClipProvenanceVerifier? _verifier;
  final ClipLateSigner? _signOwnClips;
  final bool _canSign;

  /// What this platform calls the gallery clips are saved to, such as
  /// "Camera Roll".
  String get destinationName => GallerySaveService.destinationName;

  /// Saves each of [clips] to the device gallery, one after another.
  ///
  /// The app's own clips that were left unsigned are signed first, then each
  /// clip is checked the way the gallery import checks its copy. A clip is
  /// saved whether or not it has proof, unless [onlyWithProof] is set, which
  /// leaves a clip that still has none unsaved, so trying again does not add
  /// a second copy without it. Saving stops at the first clip the gallery
  /// refuses for lack of permission.
  ///
  /// The work is not cancelled by [close]: leaving the library lets the clips
  /// finish saving, and the caller reports the returned outcome. Progress is
  /// emitted while the cubit is open.
  ///
  /// Returns null when a save is already running or [clips] is empty.
  Future<ClipGallerySaveOutcome?> saveClips(
    List<DivineVideoClip> clips, {
    bool onlyWithProof = false,
  }) async {
    if (state.isSaving || clips.isEmpty) return null;

    emitIfOpen(_progress(ClipGallerySaveStatus.signing, clips.length));
    final pending = await _signLate(clips);

    final results = <ClipGallerySaveResult>[];
    for (final clip in clips) {
      emitIfOpen(
        _progress(
          ClipGallerySaveStatus.saving,
          clips.length,
          done: results.length,
        ),
      );
      final warning = await _warningFor(clip, pending);
      if (onlyWithProof && warning != null) {
        results.add(
          ClipGallerySaveResult(clip, saved: false, warning: warning),
        );
        continue;
      }
      final saved = await _save(clip);
      if (saved == null) {
        return _finish(results, clips.length, permissionDenied: true);
      }
      results.add(ClipGallerySaveResult(clip, saved: saved, warning: warning));
    }
    return _finish(results, clips.length);
  }

  /// Saves again the clips in [ClipGallerySaveState.results] whose proof
  /// could not be added before, leaving out those that still cannot get it.
  ///
  /// Returns null when a save is already running or no clip can be retried.
  Future<ClipGallerySaveOutcome?> retry() => saveClips([
    for (final result in state.results)
      if (result.warning?.isRetryable ?? false) result.clip,
  ], onlyWithProof: true);

  ClipGallerySaveState _progress(
    ClipGallerySaveStatus status,
    int count, {
    int done = 0,
  }) => ClipGallerySaveState(
    status: status,
    results: state.results,
    savingCount: count,
    doneCount: done,
  );

  /// Signs the app's own unsigned clips, and returns the ids of those that
  /// signing again later can still fix.
  Future<Set<String>> _signLate(List<DivineVideoClip> clips) async {
    final sign = _signOwnClips;
    if (_verifier == null || sign == null || !_canSign) return const <String>{};
    try {
      return await sign(clips);
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      // Nothing is known about what was signed, so trying again may help.
      return {for (final clip in clips) clip.id};
    }
  }

  Future<ClipGallerySaveWarning?> _warningFor(
    DivineVideoClip clip,
    Set<String> pending,
  ) async {
    final verifier = _verifier;
    if (verifier == null) return null;
    if (clip.isStopMotion) return ClipGallerySaveWarning.stopMotion;
    final path = clip.video?.file?.path;
    if (path == null) return null;

    final provenance = await verifier.verify(path);
    return switch (provenance.status) {
      ClipProvenanceStatus.verified || ClipProvenanceStatus.unavailable => null,
      ClipProvenanceStatus.noCredentials when !_canSign =>
        ClipGallerySaveWarning.signingUnsupported,
      ClipProvenanceStatus.noCredentials when pending.contains(clip.id) =>
        ClipGallerySaveWarning.signingUnavailable,
      ClipProvenanceStatus.noCredentials => ClipGallerySaveWarning.noProof,
      ClipProvenanceStatus.untrustedSigner ||
      ClipProvenanceStatus.invalid ||
      ClipProvenanceStatus.notCameraCapture =>
        ClipGallerySaveWarning.notVerified,
    };
  }

  /// Saves [clip]'s video to the gallery. Returns null when the gallery
  /// refused access, so the save stops.
  Future<bool?> _save(DivineVideoClip clip) async {
    DivineVideoClip? materialized;
    try {
      // Stop-motion clips render their mp4 on demand before saving.
      try {
        materialized = await StopMotionRenderService.materialize(clip);
      } on RenderCanceledException {
        return false;
      }
      if (materialized == null) return false;
      final result = await _gallerySaveService.saveVideoToGallery(
        materialized.requireVideo,
        // A clip added from a DM is named after the message.
        copyUnderNeutralName: clip.isFromDirectMessage,
      );
      return switch (result) {
        GallerySaveSuccess() => true,
        GallerySavePermissionDenied() => null,
        GallerySaveFailure() => false,
      };
    } catch (error, stackTrace) {
      // GallerySaveService reports failures as results rather than throwing,
      // so this only guards against that contract drifting.
      addError(error, stackTrace);
      return false;
    } finally {
      await StopMotionRenderService.cleanupMaterializedOutput(
        sourceClip: clip,
        materializedClip: materialized,
      );
    }
  }

  ClipGallerySaveOutcome _finish(
    List<ClipGallerySaveResult> results,
    int total, {
    bool permissionDenied = false,
  }) {
    final latest = {for (final result in results) result.clip.id: result};
    final earlier = {for (final result in state.results) result.clip.id};
    emitIfOpen(
      ClipGallerySaveState(
        results: List.unmodifiable([
          for (final result in state.results) latest[result.clip.id] ?? result,
          for (final result in results)
            if (!earlier.contains(result.clip.id)) result,
        ]),
      ),
    );
    return ClipGallerySaveOutcome(
      results: List.unmodifiable(results),
      total: total,
      permissionDenied: permissionDenied,
    );
  }
}

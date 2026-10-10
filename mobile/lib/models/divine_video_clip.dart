// ABOUTME: Data model for a recorded video segment in the Clip Manager
// ABOUTME: Supports ordering, thumbnails, crop metadata, and JSON serialization

import 'dart:async';
import 'dart:io';

import 'package:divine_camera/divine_camera.dart'
    show CameraLensMetadata, DivineCameraLens;
import 'package:models/models.dart'
    as model
    show AspectRatio, ClipSourceCredit, EqualizerSettings;
import 'package:openvine/models/c2pa_edit_source.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/models/video_editor/clip_placeholder_fill.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

class DivineVideoClip {
  DivineVideoClip({
    required this.id,
    required this.duration,
    required this.recordedAt,
    required this.targetAspectRatio,
    required double? originalAspectRatio,
    double? videoAspectRatio,
    this.video,
    this.stopMotionFrames,
    this.libraryTitle,
    this.thumbnailPath,
    Duration? thumbnailTimestamp,
    this.processingCompleter,
    this.lensMetadata,
    this.ghostFramePath,
    this.trimStart = Duration.zero,
    this.trimEnd = Duration.zero,
    this.sourceStartOffset = Duration.zero,
    this.minTrimStart = Duration.zero,
    this.volume = 1,
    this.equalizer = model.EqualizerSettings.none,
    this.playbackSpeed,
    this.reversed = false,
    this.isPlaceholder = false,
    this.placeholderFill,
    this.isFreezeFrame = false,
    this.forwardVideoPath,
    this.reversedVideoPath,
    this.proofManifestJson,
    this.deletedAt,
    this.categoryId,
    this.archivedAt,
    this.transition,
    this.chromaKey,
    this.chromaKeySourcePath,
    this.captureChromaKey,
    this.derivedFrom,
    this.recordingSha256,
    String? sourceAuthorPubkey,
    String? sourceEventId,
    String? sourceAddressableId,
    String? sourceRelayHint,
    List<model.ClipSourceCredit> sourceCredits = const [],
  }) : assert(
         video != null || stopMotionFrames != null,
         'A clip must have either a video file or stop-motion frames',
       ),
       sourceCredits = _normalizedSourceCredits(
         sourceCredits: sourceCredits,
         sourceAuthorPubkey: sourceAuthorPubkey,
         sourceEventId: sourceEventId,
         sourceAddressableId: sourceAddressableId,
         sourceRelayHint: sourceRelayHint,
       ),
       _thumbnailTimestamp = thumbnailTimestamp,
       _originalAspectRatio = originalAspectRatio,
       _videoAspectRatio = videoAspectRatio;

  final String id;

  /// Rendered video for a normal clip, or `null` for a stop-motion clip whose
  /// source of truth is [stopMotionFrames] (an mp4 is rendered on demand at
  /// publish / gallery save).
  final EditorVideo? video;

  /// Captured stop-motion stills (source of truth) for a frames-based clip, or
  /// `null` for a normal video clip.
  final List<StopMotionClipFrame>? stopMotionFrames;

  final String? libraryTitle;
  final Duration duration;
  final DateTime recordedAt;
  final String? thumbnailPath;

  /// Video position where the thumbnail was extracted from (raw value, may be null)
  final Duration? _thumbnailTimestamp;

  /// Original aspect ratio from the recorded video (raw value, may be null)
  final double? _originalAspectRatio;

  /// Frame ratio of [video] once a bake changed it from the recording's (raw
  /// value, null while the file still has the recording's shape)
  final double? _videoAspectRatio;

  final Completer<bool>? processingCompleter;

  /// The target aspect ratio for this clip (used for deferred cropping)
  final model.AspectRatio targetAspectRatio;

  /// Camera lens metadata at the time of recording (focal length, aperture, etc.)
  final CameraLensMetadata? lensMetadata;

  /// File path to the last frame of this clip (used for ghost frame overlay).
  final String? ghostFramePath;

  /// How much has been trimmed from the start of the clip.
  final Duration trimStart;

  /// How much has been trimmed from the end of the clip.
  final Duration trimEnd;

  /// Where this clip's video file starts within the original source
  /// recording it was cut from. `Duration.zero` for clips whose file *is*
  /// the original recording; a split render sets it on the end half (its
  /// file starts at the split point) so downstream consumers — notably the
  /// timeline thumbnail raster — can stay anchored to the original
  /// recording's timeline instead of re-anchoring at the new file's zero.
  final Duration sourceStartOffset;

  /// The lowest [trimStart] this clip may be trimmed back to — its floor within
  /// the source file.
  ///
  /// `Duration.zero` for normal clips. A trim-based split (which cuts a clip
  /// into two clips that share the *same* source file rather than re-encoding
  /// two separate files) sets it on the end half to the split point, so the
  /// end half's left trim handle can't be dragged back before the split into
  /// the start half's frames.
  final Duration minTrimStart;

  /// Playback volume for this clip, between 0 (muted) and 1 (full volume).
  final double volume;

  /// How this clip's audio is raised or lowered in each frequency band.
  ///
  /// Applied by the preview player and the export ahead of [volume], never
  /// baked into [video].
  final model.EqualizerSettings equalizer;

  /// Playback speed multiplier for this clip (e.g. 0.5 = half speed, 2.0 = double speed).
  /// Null means normal speed (1.0).
  final double? playbackSpeed;

  /// Whether this clip plays in reverse.
  final bool reversed;

  /// Whether this clip is the still that fills the slot a detached clip left
  /// behind — a solid colour or a photographed frame, rendered to video.
  ///
  /// It is an ordinary video clip in every other respect, on purpose: the
  /// timeline gives a frames-based clip a frame-first action bar, which makes
  /// no sense for a one-image backdrop. This flag exists only to keep actions
  /// that are meaningless on a still off it — detaching a placeholder would
  /// put a frozen frame on the canvas and ask for a second placeholder to fill
  /// the slot it just vacated.
  final bool isPlaceholder;

  /// What the placeholder still was rendered from — a solid colour or a
  /// photographed image — or `null` when this is not a placeholder.
  ///
  /// Kept so the backdrop stays editable: the action bar reopens the colour
  /// picker on the shade that is already there, and the sheet can show which
  /// of the two the slot currently holds. The rendered mp4 records neither —
  /// a photo and a flat colour are the same frames once encoded.
  ///
  /// `null` on a placeholder written by a draft from before this was
  /// recorded; the backdrop is still changeable then, just without the
  /// current choice pre-selected.
  final ClipPlaceholderFill? placeholderFill;

  /// Whether this clip is a frame held still for a beat — the frame under the
  /// playhead of another clip, rendered to video by `FreezeFrameRenderService`.
  ///
  /// The still is rendered longer than it plays and trimmed down to the length
  /// the user picked, so the trim handles change how long it holds without a
  /// second render. That makes [duration] a reserve rather than footage, which
  /// is why [budgetDuration] counts only the visible part. Like [isPlaceholder]
  /// it also keeps actions that are meaningless on a still off the clip.
  final bool isFreezeFrame;

  /// Cached forward file path used to restore the clip after a reverse toggle.
  final String? forwardVideoPath;

  /// Cached reversed file path so repeated reverse toggles can reuse it.
  final String? reversedVideoPath;

  /// JSON-encoded ProofMode / C2PA attestation data for this individual clip.
  final String? proofManifestJson;

  /// When this clip was soft-deleted to the trash bin, or `null` for
  /// active clips. Sourced from the Drift `clips.deleted_at` column and
  /// only populated when the clip is loaded via the trash-bin path.
  final DateTime? deletedAt;

  /// Id of the user-created library category this clip is filed under, or
  /// `null` when it is uncategorized. Sourced from the Drift
  /// `clips.category_id` column, not from the JSON payload, so the column
  /// stays the single source of truth.
  final String? categoryId;

  /// When this clip was archived out of the library's default view, or
  /// `null` while it is active. Sourced from the Drift `clips.archived_at`
  /// column.
  final DateTime? archivedAt;

  /// How this clip transitions into the **next** clip on the timeline
  /// (dissolve, fade-to-black, slide, …), or `null` for a hard cut.
  ///
  /// On the **last clip** there is no following clip, so this is the
  /// loop-restart wrap (`pro_video_editor` ≥ 2.5): it blends the last clip's
  /// tail into the first clip's head so a looping player restarts seamlessly.
  /// Drives both the live editor preview and the final rendered composition.
  final ClipTransition? transition;

  /// Green-screen settings the clip's file was last baked with, or `null` when
  /// it carries no key.
  ///
  /// The key is already burned into [video] — this is not applied again at
  /// export. It exists so re-opening the green-screen editor restores what the
  /// user set instead of starting over.
  final ClipChromaKey? chromaKey;

  /// Path of the clip's video *before* its green screen was baked in.
  ///
  /// Re-keying always renders from this file, never from the already-keyed
  /// one, so repeated edits neither stack keys nor lose a generation. Cleared
  /// whenever another operation re-renders the clip (transform, reverse) or it
  /// becomes a new logical clip (split, duplicate), since the source no longer
  /// matches what the clip is now.
  final String? chromaKeySourcePath;

  /// Chroma-key settings the clip was *recorded* with, not yet baked.
  ///
  /// Set by the recorder's chroma key mode, which keys the viewfinder live
  /// but writes the raw camera footage. This is an intent, which is why it is
  /// not [chromaKey]: that one asserts the key is already burned into [video].
  /// It is baked in the background right after the take. If that has not
  /// happened yet, the editor bakes it when it opens. Either way it moves to
  /// [chromaKey] on success. Until then it seeds the chroma key screen for
  /// this clip.
  final ClipChromaKey? captureChromaKey;

  /// The files this clip's [video] was edited from, when it is an editor
  /// intermediate rather than media in its own right.
  ///
  /// Reversing, transforming, keying, freezing a frame and filling a
  /// placeholder render new files without a C2PA manifest of their own. An
  /// edit of the clip is signed against these sources instead, so the camera
  /// proof of the footage they came from carries through (#9893). `null`
  /// means [video] itself is the source; an empty list means the editor drew
  /// the clip from nothing, like a solid colour.
  final List<C2paEditSource>? derivedFrom;

  /// SHA-256 of [video] as this app recorded it, set only on the app's own
  /// recordings.
  ///
  /// Marks a recording whose capture signing may be retried later, for
  /// example after it failed offline. A file that no longer matches has been
  /// changed since and is never signed as a capture. It is carried in
  /// [signingSources], so clips edited from this one keep it.
  final String? recordingSha256;

  /// The files to name as this clip's sources when an edit of it is signed:
  /// [derivedFrom], or else the clip's own video file.
  ///
  /// `null` when the clip has no file to name yet, such as a stop-motion clip
  /// before its stills are rendered; an edit containing it cannot be signed.
  List<C2paEditSource>? get signingSources {
    if (derivedFrom case final sources?) return sources;
    final path = video?.file?.path;
    return path == null
        ? null
        : [C2paEditSource(path: path, recordingSha256: recordingSha256)];
  }

  /// The sources of the footage this clip's chroma key was applied to, or of
  /// the clip itself when it carries no key.
  ///
  /// This is what the clip is made from once its key is removed, and what a
  /// new key is applied to: re-keying renders from the pre-key footage again,
  /// so the old backdrop is no longer part of the clip.
  List<C2paEditSource>? get unkeyedSources {
    final key = chromaKey;
    final source = chromaKeySourcePath;
    if (key == null || source == null) return signingSources;
    final sources = derivedFrom;
    if (sources == null) return [C2paEditSource(path: source)];
    final backdrop = key.backdropSources;
    return sources.where((source) => !backdrop.contains(source)).toList();
  }

  /// What this clip is made from once [key] is baked into it: the unkeyed
  /// footage plus [key]'s backdrop, or `null` when that footage cannot be
  /// named.
  List<C2paEditSource>? sourcesWithChromaKey(ClipChromaKey key) {
    final footage = unkeyedSources;
    if (footage == null) return null;
    return [...footage, ...key.backdropSources];
  }

  /// Whether this clip was recorded in chroma key mode and still waits for
  /// its key to be baked.
  bool get hasPendingCaptureChromaKey =>
      captureChromaKey != null && chromaKey == null && video != null;

  /// This clip with the bake of its recorded key, [keyed], swapped in: the
  /// keyed file, the key, the raw take as its source, and the keyed poster.
  /// Everything else on this copy, such as trims or edits, stays.
  DivineVideoClip withCapturedChromaKeyBake(DivineVideoClip keyed) => copyWith(
    video: keyed.video,
    chromaKey: keyed.chromaKey,
    chromaKeySourcePath: keyed.chromaKeySourcePath,
    clearCaptureChromaKey: true,
    clearForwardVideoPath: true,
    clearReversedVideoPath: true,
    derivedFrom: keyed.derivedFrom,
    thumbnailPath: keyed.thumbnailPath,
    thumbnailTimestamp: keyed.thumbnailTimestamp,
  );

  /// All factual source credits carried by this clip.
  ///
  /// A clip imported from a published video has one; a clip merged from
  /// several imported clips has one per distinct source. The legacy scalar
  /// getters below are a back-compat view of the first credit.
  final List<model.ClipSourceCredit> sourceCredits;

  model.ClipSourceCredit? get _firstSourceCredit =>
      sourceCredits.isEmpty ? null : sourceCredits.first;

  /// Original video author's pubkey when this local clip was imported from an
  /// existing published video.
  String? get sourceAuthorPubkey => _firstSourceCredit?.authorPubkey;

  /// Original source event id for imported clips.
  String? get sourceEventId => _firstSourceCredit?.eventId;

  /// Addressable kind 34236 coordinate for the source video when available.
  String? get sourceAddressableId => _firstSourceCredit?.addressableId;

  /// Relay hint for fetching the source video or author attribution.
  String? get sourceRelayHint => _firstSourceCredit?.relayUrl;

  double get durationInSeconds => duration.inMilliseconds / 1000.0;

  /// Whether this is a frames-based stop-motion clip (no rendered mp4 yet).
  ///
  /// Video-first: once [materialize] has rendered the stills into an mp4 the
  /// clip is a normal video clip, even if it still carries [stopMotionFrames]
  /// (e.g. a draft persisted before frames were cleared). A clip with a
  /// [video] is never "still-based".
  bool get isStopMotion => video == null && stopMotionFrames != null;

  /// The rendered [video], asserting it exists.
  ///
  /// Use at call sites that only ever handle normal video clips (e.g. the
  /// video editor pipeline, which stop-motion clips never enter).
  ///
  /// Throws [StateError] if this is a stop-motion clip whose mp4 has not been
  /// rendered yet — that signals a frames-clip leaked into a video-only path.
  EditorVideo get requireVideo {
    final video = this.video;
    if (video == null) {
      throw StateError(
        'requireVideo on a stop-motion clip ($id) without a rendered video',
      );
    }
    return video;
  }

  /// Effective duration after trimming (clamped to zero).
  Duration get trimmedDuration {
    final result = duration - trimStart - trimEnd;
    return result.isNegative ? Duration.zero : result;
  }

  /// The span of source recording time this clip contributes to the total
  /// recording budget.
  ///
  /// Equal to [duration] for a normal clip. A trim-based split's end half keeps
  /// the full source [duration] but shares its file with the start half, so the
  /// region before the split ([minTrimStart]) is already counted by the start
  /// half — subtract it here so summing clips doesn't double-count the split
  /// region against the recording cap.
  ///
  /// A freeze frame counts only what plays: see [isFreezeFrame].
  Duration get budgetDuration {
    if (isFreezeFrame) return trimmedDuration;
    final result = duration - minTrimStart;
    return result.isNegative ? Duration.zero : result;
  }

  /// Effective duration in seconds after trimming.
  double get trimmedDurationInSeconds =>
      trimmedDuration.inMilliseconds / 1000.0;

  /// Wall-clock duration this clip occupies in the final composition,
  /// i.e. [trimmedDuration] divided by [playbackSpeed].
  ///
  /// A 10 s clip at 2× speed occupies 5 s of playback time.
  Duration get playbackDuration =>
      sourceDurationToPlaybackDuration(trimmedDuration);

  /// Converts a duration measured in this clip's source media time into the
  /// wall-clock duration it occupies after [playbackSpeed] is applied.
  Duration sourceDurationToPlaybackDuration(Duration sourceDuration) {
    final speed = playbackSpeed ?? 1.0;
    if (speed <= 0 || speed == 1.0) return sourceDuration;
    return Duration(
      microseconds: (sourceDuration.inMicroseconds / speed).round(),
    );
  }

  /// Inverse of [sourceDurationToPlaybackDuration]: converts a wall-clock
  /// (playback) duration into the span of this clip's source media it covers
  /// once [playbackSpeed] is applied.
  ///
  /// A 1 s wall-clock span on a 2× clip maps to 2 s of source media.
  Duration playbackDurationToSourceDuration(Duration playbackDuration) {
    final speed = playbackSpeed ?? 1.0;
    if (speed <= 0 || speed == 1.0) return playbackDuration;
    return Duration(
      microseconds: (playbackDuration.inMicroseconds * speed).round(),
    );
  }

  /// [playbackDuration] expressed as fractional seconds.
  double get playbackDurationInSeconds =>
      playbackDuration.inMilliseconds / 1000.0;
  bool get isProcessing =>
      processingCompleter != null && !processingCompleter!.isCompleted;

  /// Whether this clip's source media currently exists on disk: the video
  /// file, or — for a frames-only stop-motion clip — every captured still.
  ///
  /// A clip can outlive its media: when a clip is removed, [FileCleanupService]
  /// deletes its source file as soon as no clip/draft row references it — but
  /// the editor's undo history (and any draft that persisted that history) can
  /// still resurrect the clip. Handing a clip whose file is gone to the native
  /// preview player makes the whole composition fail with `COMPOSITION_ERROR`
  /// and freezes the editor, so restore/undo paths use this to drop orphaned
  /// clips. See `restoreDraft` and `VideoEditorCanvas._syncMainCapabilities`.
  bool get hasResolvableVideoFile {
    // Video-first: a materialized stop-motion clip carries a rendered mp4 (and
    // may still carry its now-transient stills). Resolve against the mp4 so a
    // clip whose throwaway stills were cleaned up isn't wrongly dropped as
    // orphaned once it has a playable video.
    final path = video?.file?.path;
    if (path != null) return File(path).existsSync();

    // Frames-only stop-motion clips have no video by design; their stills are
    // the source of truth. Without this branch every history sync would treat
    // the clip as orphaned and step the editor history backwards, silently
    // undoing frame edits.
    final frames = stopMotionFrames;
    if (frames != null) {
      return frames.isNotEmpty &&
          frames.every((frame) => File(frame.path).existsSync());
    }
    return false;
  }

  /// Every local file this clip holds a reference to.
  ///
  /// The canonical answer to "which files does this clip own", so the cleanup
  /// paths that diff one clip against another — the editor's superseded-file
  /// queue, the autosave orphan diff, the clip/library deletes — agree on the
  /// set instead of each keeping its own list and drifting apart.
  ///
  /// Mirrored on the persistence side by `ClipsDao._jsonFilePathKeys`, which
  /// answers the same question against a serialized clip; a field added here
  /// needs its JSON key added there or the reference check stops protecting it.
  ///
  /// Yields nulls and duplicates: a clip's video is commonly also one of its
  /// reverse caches. Callers filter.
  Iterable<String?> get ownedFilePaths sync* {
    yield video?.file?.path;
    // Cached reverse renders: a transform or a de-key clears both, which
    // orphans whichever of them is not also the clip's current video.
    yield forwardVideoPath;
    yield reversedVideoPath;
    final frames = stopMotionFrames;
    if (frames != null) {
      yield* frames.map((frame) => frame.path);
    }
    yield thumbnailPath;
    yield ghostFramePath;
    yield chromaKeySourcePath;
    yield chromaKey?.backgroundImagePath;
    yield captureChromaKey?.backgroundImagePath;
    // An edit is signed against these, so they live as long as the clip.
    yield* (derivedFrom ?? const <C2paEditSource>[]).map(
      (source) => source.path,
    );
  }

  /// Whether this clip was recorded with a front-facing camera.
  bool get isFrontCameraLens =>
      DivineCameraLens.isFrontCameraLens(lensMetadata?.lensType);

  /// Returns the thumbnail timestamp, or a fallback of 210ms or half the
  /// video duration (whichever is smaller) if not set.
  Duration get thumbnailTimestamp {
    if (_thumbnailTimestamp != null) return _thumbnailTimestamp;
    final halfDuration = Duration(milliseconds: duration.inMilliseconds ~/ 2);
    const fallback = Duration(milliseconds: 210);
    return halfDuration < fallback ? halfDuration : fallback;
  }

  /// Returns the original aspect ratio, or 9/16 as fallback if not set.
  ///
  /// Non-positive and non-finite stored values fall back too: this now divides
  /// a layout box in `computeSurfaceSize`, where a 0 gives an infinite
  /// constraint and a NaN gives a NaN one, both of which are layout assertions
  /// rather than a wrong shape.
  double get originalAspectRatio =>
      _usableRatio(_originalAspectRatio) ?? 9 / 16;

  /// Aspect ratio of the frames in [video].
  ///
  /// A crop / rotate transform bakes a new file whose shape no longer matches
  /// the recording, so the preview must fit *this* ratio rather than
  /// [originalAspectRatio]. A timeline clip's transform leaves that one alone:
  /// the first clip's value is the editor canvas's coordinate system for the
  /// whole session (and every draft saved from it), so layers authored against
  /// it would shift if a transform rewrote it. A detached clip is not on the
  /// canvas, so its transform does rewrite it instead of setting this field.
  double get videoAspectRatio =>
      _usableRatio(_videoAspectRatio) ?? originalAspectRatio;

  /// A ratio only counts when it can divide a box: finite and above zero.
  ///
  /// Both fields are persisted and one of them is measured off a file, so a
  /// bad value survives in a draft rather than being recomputed.
  static double? _usableRatio(double? ratio) =>
      (ratio != null && ratio.isFinite && ratio > 0) ? ratio : null;

  DivineVideoClip copyWith({
    String? id,
    EditorVideo? video,
    List<StopMotionClipFrame>? stopMotionFrames,
    bool clearStopMotionFrames = false,
    String? libraryTitle,
    bool clearLibraryTitle = false,
    Duration? duration,
    DateTime? recordedAt,
    String? thumbnailPath,
    Duration? thumbnailTimestamp,
    double? originalAspectRatio,
    double? videoAspectRatio,
    model.AspectRatio? targetAspectRatio,
    Completer<bool>? processingCompleter,
    CameraLensMetadata? lensMetadata,
    String? ghostFramePath,
    Duration? trimStart,
    Duration? trimEnd,
    Duration? sourceStartOffset,
    Duration? minTrimStart,
    double? volume,
    model.EqualizerSettings? equalizer,
    double? playbackSpeed,
    bool clearPlaybackSpeed = false,
    bool? reversed,
    bool? isPlaceholder,
    ClipPlaceholderFill? placeholderFill,
    bool? isFreezeFrame,
    String? forwardVideoPath,
    bool clearForwardVideoPath = false,
    String? reversedVideoPath,
    bool clearReversedVideoPath = false,
    String? proofManifestJson,
    bool clearProofManifestJson = false,
    DateTime? deletedAt,
    String? categoryId,
    DateTime? archivedAt,
    ClipTransition? transition,
    bool clearTransition = false,
    ClipChromaKey? chromaKey,
    String? chromaKeySourcePath,
    bool clearChromaKey = false,
    ClipChromaKey? captureChromaKey,
    bool clearCaptureChromaKey = false,
    List<C2paEditSource>? derivedFrom,
    bool clearDerivedFrom = false,
    String? recordingSha256,
    bool clearRecordingSha256 = false,
    // Provenance is copied as a whole list: the scalar source fields are a
    // read-only view of its first entry, so setting one here could only mean
    // "replace the whole list with a single credit" — which silently drops the
    // rest of a merged clip's credits.
    List<model.ClipSourceCredit>? sourceCredits,
    bool clearSourceCredits = false,
  }) {
    final isNewLogicalClip = id != null && id != this.id;
    final nextSourceCredits = clearSourceCredits
        ? const <model.ClipSourceCredit>[]
        : (sourceCredits ?? this.sourceCredits);

    return DivineVideoClip(
      id: id ?? this.id,
      video: video ?? this.video,
      stopMotionFrames: clearStopMotionFrames
          ? null
          : (stopMotionFrames ?? this.stopMotionFrames),
      libraryTitle: clearLibraryTitle
          ? null
          : (libraryTitle ?? this.libraryTitle),
      duration: duration ?? this.duration,
      recordedAt: recordedAt ?? this.recordedAt,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      thumbnailTimestamp: thumbnailTimestamp ?? _thumbnailTimestamp,
      originalAspectRatio: originalAspectRatio ?? _originalAspectRatio,
      videoAspectRatio: videoAspectRatio ?? _videoAspectRatio,
      targetAspectRatio: targetAspectRatio ?? this.targetAspectRatio,
      processingCompleter: processingCompleter ?? this.processingCompleter,
      lensMetadata: lensMetadata ?? this.lensMetadata,
      ghostFramePath: ghostFramePath ?? this.ghostFramePath,
      trimStart: trimStart ?? this.trimStart,
      trimEnd: trimEnd ?? this.trimEnd,
      sourceStartOffset: sourceStartOffset ?? this.sourceStartOffset,
      minTrimStart: minTrimStart ?? this.minTrimStart,
      volume: volume ?? this.volume,
      equalizer: equalizer ?? this.equalizer,
      playbackSpeed: clearPlaybackSpeed
          ? null
          : (playbackSpeed ?? this.playbackSpeed),
      reversed: reversed ?? this.reversed,
      isPlaceholder: isPlaceholder ?? this.isPlaceholder,
      placeholderFill: placeholderFill ?? this.placeholderFill,
      isFreezeFrame: isFreezeFrame ?? this.isFreezeFrame,
      forwardVideoPath: isNewLogicalClip
          ? null
          : clearForwardVideoPath
          ? null
          : (forwardVideoPath ?? this.forwardVideoPath),
      reversedVideoPath: isNewLogicalClip
          ? null
          : clearReversedVideoPath
          ? null
          : (reversedVideoPath ?? this.reversedVideoPath),
      proofManifestJson: clearProofManifestJson
          ? null
          : (proofManifestJson ?? this.proofManifestJson),
      deletedAt: deletedAt ?? this.deletedAt,
      categoryId: categoryId ?? this.categoryId,
      archivedAt: archivedAt ?? this.archivedAt,
      transition: clearTransition ? null : (transition ?? this.transition),
      chromaKey: isNewLogicalClip || clearChromaKey
          ? null
          : (chromaKey ?? this.chromaKey),
      chromaKeySourcePath: isNewLogicalClip || clearChromaKey
          ? null
          : (chromaKeySourcePath ?? this.chromaKeySourcePath),
      // Unlike the baked key this survives a split or duplicate: it describes
      // how the footage was shot, not a particular file, so both halves of a
      // chroma-key take still want it applied.
      captureChromaKey: clearCaptureChromaKey
          ? null
          : (captureChromaKey ?? this.captureChromaKey),
      derivedFrom: clearDerivedFrom ? null : (derivedFrom ?? this.derivedFrom),
      recordingSha256: clearRecordingSha256
          ? null
          : (recordingSha256 ?? this.recordingSha256),
      sourceCredits: nextSourceCredits,
    );
  }

  Map<String, dynamic> toJson() {
    // Store only filenames (relative paths) for iOS compatibility
    // iOS changes the container path on app updates, so absolute paths break
    final videoPath = video?.file?.path;
    return {
      'id': id,
      'filePath': videoPath != null ? p.basename(videoPath) : null,
      if (stopMotionFrames != null)
        'stopMotionFrames': [
          for (final frame in stopMotionFrames!) frame.toJson(),
        ],
      if (libraryTitle != null) 'libraryTitle': libraryTitle,
      'durationMs': duration.inMilliseconds,
      'recordedAt': recordedAt.toIso8601String(),
      'thumbnailPath': thumbnailPath != null
          ? p.basename(thumbnailPath!)
          : null,
      'thumbnailTimestampMs': _thumbnailTimestamp?.inMilliseconds,
      'originalAspectRatio': _originalAspectRatio,
      if (_videoAspectRatio != null) 'videoAspectRatio': _videoAspectRatio,
      'targetAspectRatio': targetAspectRatio.name,
      'lensMetadata': lensMetadata?.toMap(),
      'ghostFramePath': ghostFramePath != null
          ? p.basename(ghostFramePath!)
          : null,
      'trimStartMs': trimStart.inMilliseconds,
      'trimEndMs': trimEnd.inMilliseconds,
      if (sourceStartOffset > Duration.zero)
        'sourceStartOffsetMs': sourceStartOffset.inMilliseconds,
      if (minTrimStart > Duration.zero)
        'minTrimStartMs': minTrimStart.inMilliseconds,
      'volume': volume,
      if (!equalizer.isNone) 'equalizer': equalizer.toJson(),
      if (playbackSpeed != null) 'playbackSpeed': playbackSpeed,
      if (reversed) 'reversed': true,
      if (isPlaceholder) 'isPlaceholder': true,
      if (placeholderFill case final fill?) 'placeholderFill': fill.toJson(),
      if (isFreezeFrame) 'isFreezeFrame': true,
      if (forwardVideoPath != null)
        'forwardVideoPath': p.basename(forwardVideoPath!),
      if (reversedVideoPath != null)
        'reversedVideoPath': p.basename(reversedVideoPath!),
      if (proofManifestJson != null) 'proofManifestJson': proofManifestJson,
      if (transition != null) 'transition': transition!.toMap(),
      if (chromaKey != null) 'chromaKey': chromaKey!.toJson(),
      if (chromaKeySourcePath != null)
        'chromaKeySourcePath': p.basename(chromaKeySourcePath!),
      if (captureChromaKey != null)
        'captureChromaKey': captureChromaKey!.toJson(),
      if (derivedFrom case final sources?)
        'derivedFrom': [for (final source in sources) source.toJson()],
      if (recordingSha256 != null) 'recordingSha256': recordingSha256,
      if (sourceAuthorPubkey != null) 'sourceAuthorPubkey': sourceAuthorPubkey,
      if (sourceEventId != null) 'sourceEventId': sourceEventId,
      if (sourceAddressableId != null)
        'sourceAddressableId': sourceAddressableId,
      if (sourceRelayHint != null) 'sourceRelayHint': sourceRelayHint,
      if (sourceCredits.isNotEmpty)
        'sourceCredits': sourceCredits
            .map((credit) => credit.toJson())
            .toList(),
    };
  }

  factory DivineVideoClip.fromJson(
    Map<String, dynamic> json,
    String documentsPath, {
    bool useOriginalPath = false,
  }) {
    final aspectRatioName =
        (json['targetAspectRatio'] ?? json['aspectRatio']) as String?;
    final thumbnailTimestampMs = json['thumbnailTimestampMs'] as int?;
    final filePath = json['filePath'] as String?;
    final stopMotionFramesJson = json['stopMotionFrames'] as List<dynamic>?;
    final stopMotionFrames = stopMotionFramesJson
        ?.map(
          (e) => StopMotionClipFrame.fromJson(
            e as Map<String, dynamic>,
            documentsPath,
            useOriginalPath: useOriginalPath,
          ),
        )
        .toList();

    // A clip's video source is either a persisted file path or, for
    // stop-motion clips, the captured [stopMotionFrames] (an mp4 is rendered
    // on demand). A clip with neither can't be reconstructed (`EditorVideo`
    // requires a non-null source). Validate the required fields up front and
    // throw a typed error so the loader can skip this single corrupt row
    // instead of a cryptic `Null is not a subtype of String` cast aborting the
    // whole library/draft load.
    final id = json['id'] as String?;
    final rawRecordedAt = (json['recordedAt'] ?? json['createdAt']) as String?;
    final durationMs = json['durationMs'] as int?;
    if (id == null ||
        (filePath == null && stopMotionFrames == null) ||
        rawRecordedAt == null ||
        durationMs == null) {
      throw const FormatException(
        'DivineVideoClip JSON is missing a required field '
        '(id, a video source [filePath or stopMotionFrames], recordedAt, or '
        'durationMs); cannot reconstruct the clip.',
      );
    }

    return DivineVideoClip(
      id: id,
      video: filePath != null
          ? EditorVideo.file(
              resolvePath(
                filePath,
                documentsPath,
                useOriginalPath: useOriginalPath,
              ),
            )
          : null,
      stopMotionFrames: stopMotionFrames,
      libraryTitle: json['libraryTitle'] as String?,
      // Frame holds are persisted in microseconds; recompute the clip duration
      // from them (rather than the ms-truncated `durationMs`) so a reloaded
      // stop-motion clip's duration matches its frames exactly on the frame
      // grid. Falls back to `durationMs` for normal video clips.
      duration: stopMotionFrames != null && stopMotionFrames.isNotEmpty
          ? stopMotionFrames.fold<Duration>(
              Duration.zero,
              (sum, frame) => sum + frame.duration,
            )
          : Duration(milliseconds: durationMs),
      recordedAt: DateTime.parse(rawRecordedAt),
      thumbnailPath: resolvePath(
        json['thumbnailPath'] as String?,
        documentsPath,
        useOriginalPath: useOriginalPath,
      ),
      thumbnailTimestamp: thumbnailTimestampMs != null
          ? Duration(milliseconds: thumbnailTimestampMs)
          : null,
      originalAspectRatio: json['originalAspectRatio'] as double?,
      videoAspectRatio: (json['videoAspectRatio'] as num?)?.toDouble(),
      targetAspectRatio: model.AspectRatio.values.firstWhere(
        (e) => e.name == aspectRatioName,
        orElse: () => model.AspectRatio.square,
      ),
      lensMetadata: json['lensMetadata'] != null
          ? CameraLensMetadata.fromMap(
              json['lensMetadata'] as Map<String, dynamic>,
            )
          : null,
      ghostFramePath: resolvePath(
        json['ghostFramePath'] as String?,
        documentsPath,
        useOriginalPath: useOriginalPath,
      ),
      trimStart: Duration(milliseconds: (json['trimStartMs'] as int?) ?? 0),
      trimEnd: Duration(milliseconds: (json['trimEndMs'] as int?) ?? 0),
      sourceStartOffset: Duration(
        milliseconds: (json['sourceStartOffsetMs'] as int?) ?? 0,
      ),
      minTrimStart: Duration(
        milliseconds: (json['minTrimStartMs'] as int?) ?? 0,
      ),
      volume: (json['volume'] as num?)?.toDouble() ?? 1,
      equalizer: switch (json['equalizer']) {
        final Map<dynamic, dynamic> equalizer =>
          model.EqualizerSettings.fromJson(
            Map<String, dynamic>.from(equalizer),
          ),
        _ => model.EqualizerSettings.none,
      },
      playbackSpeed: (json['playbackSpeed'] as num?)?.toDouble(),
      reversed: (json['reversed'] as bool?) ?? false,
      isPlaceholder: (json['isPlaceholder'] as bool?) ?? false,
      placeholderFill: _placeholderFillFromJson(
        json['placeholderFill'],
        documentsPath,
        useOriginalPath: useOriginalPath,
      ),
      isFreezeFrame: (json['isFreezeFrame'] as bool?) ?? false,
      forwardVideoPath: resolvePath(
        json['forwardVideoPath'] as String?,
        documentsPath,
        useOriginalPath: useOriginalPath,
      ),
      reversedVideoPath: resolvePath(
        json['reversedVideoPath'] as String?,
        documentsPath,
        useOriginalPath: useOriginalPath,
      ),
      proofManifestJson: json['proofManifestJson'] as String?,
      transition: _transitionFromJson(json['transition']),
      chromaKey: _chromaKeyFromJson(
        json['chromaKey'],
        documentsPath,
        useOriginalPath: useOriginalPath,
      ),
      chromaKeySourcePath: resolvePath(
        json['chromaKeySourcePath'] as String?,
        documentsPath,
        useOriginalPath: useOriginalPath,
      ),
      captureChromaKey: _chromaKeyFromJson(
        json['captureChromaKey'],
        documentsPath,
        useOriginalPath: useOriginalPath,
      ),
      derivedFrom: _derivedFromFromJson(
        json['derivedFrom'],
        documentsPath,
        useOriginalPath: useOriginalPath,
      ),
      recordingSha256: json['recordingSha256'] as String?,
      sourceAuthorPubkey: json['sourceAuthorPubkey'] as String?,
      sourceEventId: json['sourceEventId'] as String?,
      sourceAddressableId: json['sourceAddressableId'] as String?,
      sourceRelayHint: json['sourceRelayHint'] as String?,
      sourceCredits: model.ClipSourceCredit.listFromJson(json['sourceCredits']),
    );
  }

  static List<model.ClipSourceCredit> _normalizedSourceCredits({
    required List<model.ClipSourceCredit> sourceCredits,
    String? sourceAuthorPubkey,
    String? sourceEventId,
    String? sourceAddressableId,
    String? sourceRelayHint,
  }) {
    final credits = <model.ClipSourceCredit>[
      ...sourceCredits,
      if (sourceAuthorPubkey != null && sourceAuthorPubkey.isNotEmpty)
        model.ClipSourceCredit(
          authorPubkey: sourceAuthorPubkey,
          eventId: sourceEventId,
          addressableId: sourceAddressableId,
          relayUrl: sourceRelayHint,
        )
      else if (sourceAddressableId != null && sourceAddressableId.isNotEmpty)
        model.ClipSourceCredit.fromAddressableId(
          addressableId: sourceAddressableId,
          eventId: sourceEventId,
          relayUrl: sourceRelayHint,
        ),
    ];

    final seen = <String>{};
    return List.unmodifiable([
      for (final credit in credits)
        if (credit.authorPubkey.isNotEmpty && seen.add(credit.identityKey))
          credit,
    ]);
  }

  /// Parses a persisted [ClipTransition], degrading to `null` (a hard cut) when
  /// the stored type/curve/direction names can't be resolved — e.g. a
  /// forward-incompatible draft written by a newer build, or partial
  /// corruption. `ClipTransition.fromMap` resolves enums via `byName`, which
  /// throws on an unknown name; since a draft deserializes every clip through
  /// `fromJson`, an unguarded throw here would abort the *whole* draft load.
  /// Mirrors the `targetAspectRatio` `orElse` fallback above.
  static ClipTransition? _transitionFromJson(Object? raw) {
    if (raw is! Map) return null;
    try {
      return ClipTransition.fromMap(raw.cast<String, dynamic>());
    } catch (error, stackTrace) {
      Log.error(
        'Dropping unparseable clip transition; falling back to a hard cut',
        name: 'DivineVideoClip',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Parses the persisted placeholder fill, degrading to `null` when the
  /// stored shape can't be read. Same rationale as [_transitionFromJson]: one
  /// unreadable field must not abort a whole draft load. The still is already
  /// rendered, so losing this costs the pre-selected colour in the picker, not
  /// the backdrop itself.
  static ClipPlaceholderFill? _placeholderFillFromJson(
    Object? raw,
    String documentsPath, {
    required bool useOriginalPath,
  }) {
    if (raw is! Map) return null;
    try {
      return ClipPlaceholderFill.fromJson(
        raw.cast<String, dynamic>(),
        documentsPath,
        useOriginalPath: useOriginalPath,
      );
    } catch (error, stackTrace) {
      Log.error(
        'Dropping unparseable placeholder fill; the rendered still is '
        'unaffected',
        name: 'DivineVideoClip',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Parses the persisted [derivedFrom] sources, degrading to `null` when any
  /// entry can't be read. Same rationale as [_transitionFromJson]: one
  /// unreadable field must not abort a whole draft load.
  ///
  /// The whole list is dropped, never just the bad entry: a partial list would
  /// sign an edit against part of its history. `null` makes the clip's own
  /// file the source, and an editor render has no manifest, so an edit of it
  /// stays unsigned.
  static List<C2paEditSource>? _derivedFromFromJson(
    Object? raw,
    String documentsPath, {
    required bool useOriginalPath,
  }) {
    if (raw is! List) return null;
    try {
      return [
        for (final source in raw.cast<Map<String, dynamic>>())
          C2paEditSource.fromJson(
            source,
            documentsPath,
            useOriginalPath: useOriginalPath,
          ),
      ];
    } catch (error, stackTrace) {
      Log.error(
        'Dropping unparseable derivedFrom sources; the clip is its own source',
        name: 'DivineVideoClip',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Parses persisted green-screen settings, degrading to `null` when the
  /// stored shape can't be read. Same rationale as [_transitionFromJson]: a
  /// draft deserializes every clip through `fromJson`, so one unreadable
  /// effect must not abort the whole draft load. For [chromaKey] the key is
  /// already baked into the video, so losing it costs re-editability, not the
  /// effect itself; for [captureChromaKey] it costs the automatic bake, and the
  /// raw footage stays keyable by hand.
  static ClipChromaKey? _chromaKeyFromJson(
    Object? raw,
    String documentsPath, {
    required bool useOriginalPath,
  }) {
    if (raw is! Map) return null;
    try {
      return ClipChromaKey.fromJson(
        raw.cast<String, dynamic>(),
        documentsPath,
        useOriginalPath: useOriginalPath,
      );
    } catch (error, stackTrace) {
      Log.error(
        'Dropping unparseable clip chroma key; the baked video is unaffected',
        name: 'DivineVideoClip',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  @override
  String toString() {
    return 'RecordingClip(id: $id, duration: ${durationInSeconds}s)';
  }
}

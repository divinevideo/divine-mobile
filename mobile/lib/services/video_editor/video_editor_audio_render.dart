// ABOUTME: Maps editor audio events to render audio tracks and resolves them
// ABOUTME: to local files for muxing, keeping render audio logic in one place

import 'dart:io';

import 'package:models/models.dart' show AudioEvent;
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

const _logName = 'VideoEditorAudioRender';

/// Resolves the [EditorAudio] source for a render [event], or `null` when it
/// has no usable source.
///
/// Routes bundled → asset, local-import or absolute path → file, and http(s)
/// → network. Guards every nullable field so a malformed event is skipped by
/// the caller instead of throwing a null-check during render.
EditorAudio? _resolveRenderAudioSource(AudioEvent event) {
  if (event.isBundled && event.assetPath != null) {
    return EditorAudio.asset(event.assetPath!);
  }
  if (event.isLocalImport && event.localFilePath != null) {
    return EditorAudio.file(File(event.localFilePath!));
  }
  final url = event.url;
  if (url != null && url.isNotEmpty) {
    return url.startsWith('/')
        ? EditorAudio.file(File(url))
        : EditorAudio.network(url);
  }
  return null;
}

/// Builds the render [AudioTrack] for the legacy single selected sound.
///
/// The selected sound carries no timeline placement, so it is normalized to
/// start at the beginning of the video and span its source length before
/// mapping. Setting `startTime`/`endTime` is essential: a bare sound's
/// `startTime` defaults to its source `startOffset` and its `endTime` is
/// `null`, which the native renderer reads as a zero-length `[offset, 0]`
/// composition window and drops with "no time remaining in composition".
///
/// Returns `null` (and logs a warning) when the sound has no resolvable source
/// or no known duration.
AudioTrack? audioTrackFromSoundForRender(AudioEvent sound) {
  final durationMs = ((sound.duration ?? 0) * 1000).toInt();
  if (durationMs <= 0) {
    Log.warning(
      'Skipping selected sound ${sound.id} for render: unknown duration',
      name: _logName,
      category: LogCategory.video,
    );
    return null;
  }
  final track = audioTrackFromMetaForRender(
    sound.copyWith(
      startTime: Duration.zero,
      endTime: Duration(milliseconds: durationMs),
    ),
  );
  if (track != null) {
    _logPreparedTrack(track, origin: 'selected-sound fallback');
  }
  return track;
}

/// Builds the render [AudioTrack] for a timeline audio [track] taken from the
/// editor meta.
///
/// Returns `null` (and logs a warning) when the track has no resolvable audio
/// source, so a single unusable track is skipped instead of aborting the whole
/// render with a thrown null-check. Routes bundled → asset, local-import or
/// absolute path → file, and everything else (http(s)) → network.
AudioTrack? audioTrackFromMetaForRender(AudioEvent track) {
  final audio = _resolveRenderAudioSource(track);
  if (audio == null) {
    Log.warning(
      'Skipping audio track ${track.id} for render: no resolvable source',
      name: _logName,
      category: LogCategory.video,
    );
    return null;
  }

  // A persisted track can carry an invalid composition window — e.g. a sound
  // added before its duration was known ends up with endTime=0 (see
  // _openMusicLibrary). Treat any missing/inverted window as "play across the
  // whole video" (both null per VideoAudioTrack's contract) so existing drafts
  // still render audio instead of being dropped as a zero-length range.
  final endTime = track.endTime;
  final hasWindow = endTime != null && endTime > track.startTime;
  return AudioTrack(
    id: track.id,
    title: track.title ?? '',
    subtitle: track.source ?? '',
    duration: Duration(milliseconds: ((track.duration ?? 0) * 1000).toInt()),
    audio: audio,
    startTime: hasWindow ? track.startTime : null,
    endTime: hasWindow ? endTime : null,
    audioStartTime: track.startOffset,
    // audioEndTime is intentionally left at its default (null = "play to the
    // end of the file"); the composition window clips it. This drops the
    // dependency on a possibly-missing source duration, which previously
    // produced an invalid `[startOffset, 0]` source range.
    volume: track.volume,
  );
}

/// Records the timing boundary between editor state and render parameters.
///
/// Source paths and URLs are deliberately omitted: local paths can contain
/// user-identifying directory names, while the timing fields are sufficient
/// to distinguish source-offset failures from composition-placement failures.
void _logPreparedTrack(AudioTrack track, {required String origin}) {
  Log.info(
    'Prepared $origin audio track ${track.id}: '
    'composition=[${_durationMs(track.startTime)}, '
    '${_durationMs(track.endTime)}], '
    'source=[${_durationMs(track.audioStartTime)}, '
    '${_durationMs(track.audioEndTime)}]',
    name: _logName,
    category: LogCategory.video,
  );
}

String _durationMs(Duration? duration) =>
    duration == null ? 'unbounded' : '${duration.inMilliseconds}ms';

/// Builds the render audio tracks for a session from its timeline
/// [metaTracks], falling back to the recorder's [selectedSound].
///
/// [selectedSound] is legacy single-sound state from the recorder flow. When
/// the timeline already carries audio it is the same sound, so adding it again
/// duplicates the audio — hence the fallback only applies to an empty
/// timeline. Tracks that resolve to no usable source are dropped by the
/// mappers and logged there.
///
/// Both render entry points go through this: the in-editor export and the
/// headless draft render used when publishing from the library. Keeping it in
/// one place is what stops the two from disagreeing about whether a
/// recorder-picked sound survives.
List<AudioTrack> buildRenderAudioTracks({
  required List<AudioEvent> metaTracks,
  required AudioEvent? selectedSound,
}) {
  final tracks = <AudioTrack>[];
  for (final event in metaTracks) {
    final track = audioTrackFromMetaForRender(event);
    if (track == null) continue;
    _logPreparedTrack(track, origin: 'timeline');
    tracks.add(track);
  }
  if (metaTracks.isEmpty && selectedSound != null) {
    final track = audioTrackFromSoundForRender(selectedSound);
    if (track != null) tracks.add(track);
  }
  return tracks;
}

/// Clamps an audio composition window so it cannot extend past [videoDuration],
/// or returns `null` when the window lies entirely past the video and the track
/// should be dropped.
///
/// A stop-motion export is only as long as its (looped) stills — often under a
/// second — while a selected song's window spans the whole track. Muxing a
/// full-length song onto a short video produces an mp4 whose audio track
/// outlives its video track; on iOS the last frame freezes while the audio
/// keeps playing. Clamping the window to the video length keeps the two tracks
/// the same length. A `null` [videoDuration] (or a `null` `endTime`, which
/// already means "play to the end of the video") is left untouched.
///
/// A window that starts at or after [videoDuration] has nothing left to play —
/// clamping both ends would collapse it to a zero-length `[videoDuration,
/// videoDuration]`, which violates [VideoAudioTrack]'s `startTime < endTime`
/// assert. Such a track is reported as `null` so the caller drops it.
({Duration? startTime, Duration? endTime})? clampAudioWindowToVideo({
  required Duration? startTime,
  required Duration? endTime,
  required Duration? videoDuration,
}) {
  if (videoDuration == null) return (startTime: startTime, endTime: endTime);
  if (startTime != null && startTime >= videoDuration) return null;
  return (
    startTime: startTime,
    endTime: endTime != null && endTime > videoDuration
        ? videoDuration
        : endTime,
  );
}

/// Resolves each render [AudioTrack] to a [VideoAudioTrack] with a local file
/// path, downloading network sources on demand.
///
/// A track that cannot be resolved (e.g. a failed network download) is skipped
/// and logged rather than aborting the whole render. A warning is logged when
/// audio was requested but none could be resolved, so a silent (audio-less)
/// export is diagnosable from logs.
///
/// When [videoDuration] is set, each track's composition window is clamped to
/// it (see [clampAudioWindowToVideo]) so audio cannot outlast the video track.
Future<List<VideoAudioTrack>> resolveRenderAudioTracks(
  List<AudioTrack> customTracks, {
  required String logName,
  Duration? videoDuration,
}) async {
  final audioTracks = <VideoAudioTrack>[];
  for (final track in customTracks) {
    try {
      final audioPath = await track.audio.safeFilePath();
      final window = clampAudioWindowToVideo(
        startTime: track.startTime,
        endTime: track.endTime,
        videoDuration: videoDuration,
      );
      if (window == null) {
        Log.warning(
          'Audio track ${track.id} starts at or after the end of the video '
          '— skipping it',
          name: logName,
          category: LogCategory.video,
        );
        continue;
      }
      final (:startTime, :endTime) = window;
      final resolvedTrack = VideoAudioTrack(
        path: audioPath,
        startTime: startTime,
        endTime: endTime,
        audioStartTime: track.audioStartTime,
        audioEndTime: track.audioEndTime,
        loop: track.loop,
        volume: track.volume,
      );
      audioTracks.add(resolvedTrack);
      Log.info(
        'Resolved audio track ${track.id} for mux: '
        'composition=[${_durationMs(startTime)}, ${_durationMs(endTime)}], '
        'source=[${_durationMs(track.audioStartTime)}, '
        '${_durationMs(track.audioEndTime)}], '
        'videoDuration=${_durationMs(videoDuration)}',
        name: logName,
        category: LogCategory.video,
      );
    } catch (e, stackTrace) {
      Log.error(
        'Failed to resolve audio track ${track.id} for render — skipping it',
        name: logName,
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  if (customTracks.isNotEmpty && audioTracks.isEmpty) {
    Log.warning(
      'Render produced no usable audio from ${customTracks.length} '
      'requested track(s); custom audio will be missing from the output',
      name: logName,
      category: LogCategory.video,
    );
  }

  return audioTracks;
}

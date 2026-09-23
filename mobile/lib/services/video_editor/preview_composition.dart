// ABOUTME: Owns the preview player's composition: background seam and speed
// ABOUTME: renders spliced into the clip list plus the matching position map.

import 'package:divine_video_player/divine_video_player.dart' show VideoClip;
import 'package:flutter/foundation.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:openvine/services/video_editor/clip_speed_render_service.dart';
import 'package:openvine/services/video_editor/render_slot_pool.dart';
import 'package:openvine/services/video_editor/transition_seam_render_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show ClipTransition;

/// The clip list the preview player actually plays, and the mapping between
/// its positions and the editor timeline.
///
/// The editor draws clips at full length; the player plays trimmed bodies with
/// rendered transition seams and normal-rate speed bodies spliced in — a
/// different, usually shorter, timeline. This owner renders those files in the
/// background (idempotently, so it is safe to call on every clip, trim, speed
/// or transition change), tells the canvas when one lands through
/// [onSeamRendered] / [onSpeedClipRendered], and keeps a memoized
/// [SeamTimeline] that always describes the composition last handed to the
/// player.
class PreviewComposition {
  /// Seam and speed renders share one [RenderSlotPool] unless a service is
  /// injected, so together they never open more native encoder sessions than
  /// the pool allows.
  factory PreviewComposition({
    required List<DivineVideoClip> Function() readClips,
    required void Function(Future<void> operation, String description)
    runDetached,
    required VoidCallback onSeamRendered,
    required VoidCallback onSpeedClipRendered,
    TransitionSeamRenderService? seamService,
    ClipSpeedRenderService? speedRenderService,
  }) {
    final renderSlots = RenderSlotPool();
    return PreviewComposition._(
      readClips: readClips,
      runDetached: runDetached,
      onSeamRendered: onSeamRendered,
      onSpeedClipRendered: onSpeedClipRendered,
      seamService:
          seamService ?? TransitionSeamRenderService(renderSlots: renderSlots),
      speedRenderService:
          speedRenderService ??
          ClipSpeedRenderService(renderSlots: renderSlots),
    );
  }

  PreviewComposition._({
    required List<DivineVideoClip> Function() readClips,
    required void Function(Future<void> operation, String description)
    runDetached,
    required VoidCallback onSeamRendered,
    required VoidCallback onSpeedClipRendered,
    required TransitionSeamRenderService seamService,
    required ClipSpeedRenderService speedRenderService,
  }) : _readClips = readClips,
       _runDetached = runDetached,
       _onSeamRendered = onSeamRendered,
       _onSpeedClipRendered = onSpeedClipRendered,
       _seamService = seamService,
       _speedRenderService = speedRenderService;

  final List<DivineVideoClip> Function() _readClips;
  final void Function(Future<void> operation, String description) _runDetached;
  final VoidCallback _onSeamRendered;
  final VoidCallback _onSpeedClipRendered;

  /// Renders and caches transition seams so the preview can splice them in
  /// between the trimmed neighbour clips (instead of compositing live).
  final TransitionSeamRenderService _seamService;

  /// Renders and caches per-clip normal-rate speed bodies so a non-1× clip can
  /// play its pre-rendered file at 1× instead of retiming live — smoother on
  /// both platforms. Rendered in the background; the preview shows the instant
  /// live-retimed clip until the render swaps in (no overlay, no wait).
  final ClipSpeedRenderService _speedRenderService;

  final _pendingSeamRenders = ValueNotifier<int>(0);
  bool _disposed = false;

  /// Seam renders this composition started and that have not finished yet,
  /// keyed by [TransitionSeamRenderService.seamKey]. The value identifies the
  /// attempt, so a cancelled attempt finishing late cannot clear the entry of
  /// a newer attempt for the same key.
  final _seamRendersInFlight = <String, Object>{};

  /// Number of transition seams the current clips need that are still
  /// rendering. Drives the preview's "rendering transition" overlay so the
  /// wait isn't silent; a superseded render never holds it up.
  ValueListenable<int> get pendingSeamRenders => _pendingSeamRenders;

  /// The seam keys [clips] need, including the loop-restart wrap, each paired
  /// with the boundary it renders.
  Map<String, ({DivineVideoClip a, DivineVideoClip b, ClipTransition t})>
  _neededSeams(List<DivineVideoClip> clips) {
    final clamped = clampTransitions(clips);
    final needed =
        <String, ({DivineVideoClip a, DivineVideoClip b, ClipTransition t})>{};
    void add(DivineVideoClip a, DivineVideoClip b, ClipTransition? t) {
      if (t == null) return;
      needed[_seamService.seamKey(a, b, t)] = (a: a, b: b, t: t);
    }

    for (var i = 0; i < clips.length - 1; i++) {
      add(clips[i], clips[i + 1], clamped[clips[i].id]);
    }
    // Loop-restart wrap: the last clip's transition blends its tail into the
    // first clip's head (the same clip on a single-clip timeline) so the
    // looping preview restarts through the blend instead of a hard cut.
    if (clips.isNotEmpty) add(clips.last, clips.first, clamped[clips.last.id]);
    return needed;
  }

  void _updatePendingSeamRenders(Set<String> neededKeys) {
    if (_disposed) return;
    _pendingSeamRenders.value = _seamRendersInFlight.keys
        .where(neededKeys.contains)
        .length;
  }

  /// Kicks off (once) the seam render for every transition boundary in
  /// [clips], including the loop-restart wrap. Idempotent — cached seams are
  /// skipped, so it is safe to call on every clip change.
  ///
  /// Renders the no-overlap-clamped transition ([clampTransitions]) so the
  /// preview consumes exactly what the export will, and a clip touched by
  /// transitions on both sides is split between them rather than
  /// over-consumed.
  ///
  /// Renders a seam the timeline no longer needs — a trim, speed or transition
  /// change since it started — are cancelled, so they neither hold a render
  /// slot nor reload the player when they would have landed.
  void ensureSeamsRendered(List<DivineVideoClip> clips) {
    if (_disposed) return;
    final needed = _neededSeams(clips);
    final neededKeys = needed.keys.toSet();
    _seamService.cancelRendersExcept(neededKeys);
    _seamRendersInFlight.removeWhere((key, _) => !neededKeys.contains(key));
    for (final MapEntry(:key, value: (:a, :b, :t)) in needed.entries) {
      _renderSeam(key, a, b, t);
    }
    _updatePendingSeamRenders(neededKeys);
  }

  /// Renders (once) the transition seam blending [clipA]'s tail into [clipB]'s
  /// head. Idempotent — cached / in-flight seams are skipped.
  void _renderSeam(
    String key,
    DivineVideoClip clipA,
    DivineVideoClip clipB,
    ClipTransition transition,
  ) {
    if (_seamService.cached(clipA, clipB, transition) != null) return;
    if (_seamService.isRendering(clipA, clipB, transition)) return;
    final attempt = Object();
    _seamRendersInFlight[key] = attempt;
    _runDetached(
      _renderSeamAndResync(key, attempt, clipA, clipB, transition),
      'render transition seam',
    );
  }

  Future<void> _renderSeamAndResync(
    String key,
    Object attempt,
    DivineVideoClip clipA,
    DivineVideoClip clipB,
    ClipTransition transition,
  ) async {
    final seam = await _seamService.render(
      clipA: clipA,
      clipB: clipB,
      transition: transition,
    );
    if (_disposed) return;
    if (identical(_seamRendersInFlight[key], attempt)) {
      final _ = _seamRendersInFlight.remove(key);
    }
    // Checked against the clips as they are now, not as they were when the
    // render started: a seam for a boundary that has since changed is never
    // spliced in, and reloading the player for it only hitches playback.
    final neededKeys = _neededSeams(_readClips()).keys.toSet();
    _updatePendingSeamRenders(neededKeys);
    if (seam != null && neededKeys.contains(key)) _onSeamRendered();
  }

  /// Kicks off background renders of the normal-rate body for any non-1× clip,
  /// then asks the canvas to swap the player onto the rendered file when each
  /// finishes. Idempotent — cached / in-flight clips are skipped — so it is
  /// safe to call on every clip, trim or speed change. The preview keeps
  /// playing the instant live-retimed clip until the swap lands.
  void ensureSpeedClipsRendered(List<DivineVideoClip> clips) {
    final clamped = clampTransitions(clips);
    // The loop-restart wrap consumes the first clip's head and the last clip's
    // tail eagerly (see buildSeamAwarePlayerClips); those clips stay on live
    // retiming like interior seam-consumed clips.
    final wrapActive =
        clips.isNotEmpty &&
        LoopWrapDisplay.fromClamped(clips, clamped[clips.last.id]).isActive;
    for (var i = 0; i < clips.length; i++) {
      final clip = clips[i];
      // Skip a clip whose body is consumed by a rendered seam on either side:
      // it stays on live retiming (the seam already bakes its speed), so its
      // whole-body speed render would never be spliced in — matching the gate
      // in [buildSeamAwarePlayerClips]. Avoids a native encode the player can't
      // use. Until the seam lands the clip isn't consumed, so it still renders.
      final incoming = i > 0 ? clamped[clips[i - 1].id] : null;
      final consumedByIncoming =
          incoming != null &&
          _seamService.cached(clips[i - 1], clip, incoming) != null;
      final outgoing = clamped[clip.id];
      final consumedByOutgoing =
          i + 1 < clips.length &&
          outgoing != null &&
          _seamService.cached(clip, clips[i + 1], outgoing) != null;
      final consumedByWrap = wrapActive && (i == 0 || i == clips.length - 1);
      if (consumedByIncoming || consumedByOutgoing || consumedByWrap) continue;

      if (_speedRenderService.cached(clip) != null) continue;
      if (_speedRenderService.isRendering(clip)) continue;
      _runDetached(_renderSpeedClipAndResync(clip), 'render speed clip');
    }
  }

  Future<void> _renderSpeedClipAndResync(DivineVideoClip clip) async {
    final rendered = await _speedRenderService.render(clip);
    if (_disposed) return;
    if (rendered != null) _onSpeedClipRendered();
  }

  /// Memoized [SeamTimeline] for the current clips + seam-cache state, so the
  /// per-tick position mappings don't rebuild it on every player update.
  SeamTimeline? _cachedSeamTimeline;
  int? _cachedSeamTimelineClipsHash;
  int? _cachedSeamTimelineVersion;

  /// Returns the current [SeamTimeline], rebuilding when the clips change
  /// identity or the seam cache mutates ([TransitionSeamRenderService.version]).
  ///
  /// Deliberately **not** keyed on the speed render cache: a landed speed body
  /// must only shift the mapping once its file is actually spliced into the
  /// player composition. Because a speed swap can be deferred while playback
  /// runs (the canvas waits for an idle player), keying on the speed cache
  /// would move the mapping ahead of the still-live-retimed player and drift
  /// the playhead. Instead [buildPlayerClips] refreshes this timeline from the
  /// same snapshot it hands the player, so mapping and composition always
  /// agree.
  SeamTimeline get _seamTimeline {
    final clips = _readClips();
    final clipsHash = Object.hashAll(clips);
    final version = _seamService.version;
    final cached = _cachedSeamTimeline;
    if (cached != null &&
        _cachedSeamTimelineClipsHash == clipsHash &&
        _cachedSeamTimelineVersion == version) {
      return cached;
    }
    return _refreshSeamTimeline(clips);
  }

  /// Builds the preview player's clip list for [clips] (rendered seams + speed
  /// bodies spliced in) and refreshes the memoized [SeamTimeline] from the same
  /// cache snapshot, so the player↔editor position mapping always matches the
  /// composition that was actually loaded — including a speed body that landed
  /// while playing whose swap was deferred to the next pause.
  List<VideoClip> buildPlayerClips(List<DivineVideoClip> clips) {
    final playerClips = buildSeamAwarePlayerClips(
      clips,
      _seamService,
      speedRenders: _speedRenderService,
    );
    _refreshSeamTimeline(clips);
    return playerClips;
  }

  SeamTimeline _refreshSeamTimeline(List<DivineVideoClip> clips) {
    final timeline = SeamTimeline(
      clips,
      _seamService,
      speedRenders: _speedRenderService,
    );
    _cachedSeamTimeline = timeline;
    _cachedSeamTimelineClipsHash = Object.hashAll(clips);
    _cachedSeamTimelineVersion = _seamService.version;
    return timeline;
  }

  /// Converts a player (composite) position into editor-timeline space. The
  /// player plays trimmed clip bodies with spliced seams (a shorter timeline);
  /// the editor draws clips at full length. A no-op when no seam is spliced.
  Duration playerToTimeline(Duration playerPosition) =>
      _seamTimeline.compositeToTimeline(playerPosition);

  /// Converts an editor-timeline position into player (composite) space.
  Duration timelineToPlayer(Duration timelinePosition) =>
      _seamTimeline.timelineToComposite(timelinePosition);

  /// Drops both render caches and stops reporting renders that land later.
  void dispose() {
    _disposed = true;
    _seamService.clear();
    _speedRenderService.clear();
    _pendingSeamRenders.dispose();
  }
}

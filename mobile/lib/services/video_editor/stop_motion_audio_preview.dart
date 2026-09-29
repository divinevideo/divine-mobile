// ABOUTME: Plays timeline audio tracks in sync with the stop-motion preview
// ABOUTME: clock — frames-only clips have no native video player to do it.

import 'dart:async';

import 'package:openvine/models/video_editor/audio_fade.dart';
import 'package:sound_service/sound_service.dart';

/// One timeline sound scheduled against the stop-motion preview clock.
class StopMotionAudioPreviewTrack {
  const StopMotionAudioPreviewTrack({
    required this.id,
    required this.source,
    required this.windowStart,
    required this.windowEnd,
    this.volume = 1,
    this.fadeIn = Duration.zero,
    this.fadeOut = Duration.zero,
  });

  /// Timeline item id of the sound.
  final String id;

  /// Audio source already clipped to this window's slice of the track
  /// (clip start = the sound's own start offset into the source).
  final AudioSourceConfig source;

  /// Playback volume, `0.0..1.0`.
  final double volume;

  /// Editor-timeline position where this sound becomes audible.
  final Duration windowStart;

  /// Editor-timeline position where this sound stops.
  final Duration windowEnd;

  /// How long the sound rises from silence after [windowStart].
  final Duration fadeIn;

  /// How long the sound falls to silence before [windowEnd].
  final Duration fadeOut;

  bool get _hasFade => fadeIn > Duration.zero || fadeOut > Duration.zero;
}

/// Creates the per-track player; injectable for tests.
typedef AudioClipPlayerFactory = AudioClipPlayer Function();

/// Audio engine for the frames-only stop-motion preview.
///
/// A normal composition plays its overlay sounds through the native video
/// player (`setAudioTracks`), which follows native playback. A stop-motion
/// clip has no mp4 and therefore no native player — its playhead is a widget
/// [Ticker] — so this class schedules one [AudioClipPlayer] per sound and
/// follows that clock instead: [syncTo] starts a sound when the playhead
/// enters its window, stops it when the playhead leaves, and re-seeks on
/// scrubs and loop wraps.
class StopMotionAudioPreview {
  StopMotionAudioPreview({AudioClipPlayerFactory? playerFactory})
    : _playerFactory = playerFactory ?? AudioClipPlayer.new;

  /// A backwards jump, or a forward jump larger than this, is a scrub / loop
  /// wrap and forces active tracks to re-seek. Normal ticks advance by a
  /// frame (~17 ms), far below this.
  static const Duration seekJumpThreshold = Duration(milliseconds: 500);

  final AudioClipPlayerFactory _playerFactory;
  final Map<String, _ScheduledTrack> _tracks = {};
  Duration _lastPosition = Duration.zero;
  bool _disposed = false;

  /// Serializes every player-touching operation. [setTracks], [pauseAll],
  /// [dispose] and each admitted [syncTo] chain onto this tail so they never
  /// interleave at an `await`: without it, a [setTracks]/[dispose] that clears
  /// `_tracks` while a suspended [syncTo] is mid-iteration would throw a
  /// `ConcurrentModificationError` (or call `play()` on a just-disposed
  /// player). The stop-motion ticker fires [syncTo] every frame while overlay
  /// edits fire [setTracks], so that interleaving is a normal-usage race.
  Future<void> _queue = Future<void>.value();

  /// Drops per-frame [syncTo] calls that arrive while one is already queued or
  /// running, so a slow seek can't let ticker calls pile up unbounded (and so
  /// two overlapping calls can't race on the shared `active` / `_lastPosition`
  /// state and leave a track playing past its window).
  bool _syncInFlight = false;

  /// A scrub ([syncTo] with `isSeek`) that arrived while a sync was in flight
  /// and got dropped. The dropped call changed nothing, but its re-seek intent
  /// must survive: an in-flight transition sync (loop wrap / window seek)
  /// already advanced `_lastPosition`, so the scrub's small forward hop would
  /// then read as a normal tick and never re-seek, leaving a sound playing from
  /// the pre-scrub offset. The next admitted sync ORs this in to force a
  /// re-seek. User scrubs can't pile up at ticker rate, so this can't starve.
  bool _pendingSeek = false;

  Future<T> _enqueue<T>(Future<T> Function() op) {
    final next = _queue.then((_) => op());
    // Keep the chain alive even if an op throws; callers still observe the
    // error through the returned future.
    _queue = next.then((_) {}, onError: (Object _) {});
    return next;
  }

  /// Replaces the scheduled sounds. Existing players are disposed; the next
  /// [syncTo] starts whichever new sounds the playhead sits inside.
  Future<void> setTracks(List<StopMotionAudioPreviewTrack> tracks) {
    if (_disposed) return Future<void>.value();
    return _enqueue(() => _setTracks(tracks));
  }

  Future<void> _setTracks(List<StopMotionAudioPreviewTrack> tracks) async {
    await _disposeAllPlayers();
    if (_disposed) return;

    for (final track in tracks) {
      final player = _playerFactory();
      try {
        await player.setClip(track.source);
        await player.setVolume(track.volume);
      } on Exception {
        await player.dispose();
        continue;
      }
      if (_disposed) {
        await player.dispose();
        return;
      }
      _tracks[track.id] = _ScheduledTrack(track: track, player: player)
        ..appliedVolume = track.volume;
    }
  }

  /// Aligns every sound with the preview clock at [position].
  ///
  /// While [isPlaying], a sound whose window contains [position] plays from
  /// the matching offset; sounds outside their window are paused. When not
  /// playing, everything pauses. Cheap when nothing changed — steady playback
  /// inside a window is a no-op. Fire-and-forget: dispatched `unawaited` from
  /// the ticker, so a call that arrives while another is in flight is dropped
  /// (the next frame re-syncs).
  ///
  /// Set [isSeek] when [position] comes from a scrub rather than the ticker.
  /// The playhead moved discontinuously, so active sounds re-seek even when the
  /// delta is small enough to pass for a normal tick.
  Future<void> syncTo(
    Duration position, {
    required bool isPlaying,
    bool isSeek = false,
  }) {
    if (_disposed) return Future<void>.value();
    if (_syncInFlight) {
      // Drop the piled-up ticker call, but keep a scrub's re-seek intent so it
      // isn't lost against the in-flight sync's advanced `_lastPosition`.
      if (isSeek) _pendingSeek = true;
      return Future<void>.value();
    }
    _syncInFlight = true;
    return _enqueue(
          () => _syncTo(position, isPlaying: isPlaying, isSeek: isSeek),
        )
        // Fire-and-forget from the ticker: never surface as an unhandled
        // async error.
        .catchError((Object _) {})
        .whenComplete(() => _syncInFlight = false);
  }

  Future<void> _syncTo(
    Duration position, {
    required bool isPlaying,
    required bool isSeek,
  }) async {
    if (_disposed) return;
    // The threshold still covers the ticker's own discontinuity — a loop wrap
    // arrives as a backward move — while [isSeek] catches the scrub the ticker
    // can't be distinguished from: a small forward hop.
    final jumped =
        isSeek ||
        _pendingSeek ||
        position < _lastPosition ||
        position - _lastPosition > seekJumpThreshold;
    _pendingSeek = false;
    _lastPosition = position;

    // Snapshot: the queue already prevents concurrent mutation, but iterating a
    // copy keeps this loop safe against any future non-queued edit too.
    for (final scheduled in _tracks.values.toList()) {
      final track = scheduled.track;
      final inWindow =
          position >= track.windowStart && position < track.windowEnd;
      final shouldPlay = isPlaying && inWindow;

      // The ticker calls in every frame, which steps a fade finely enough
      // that no single step is audible. Before a start, so it does not blip
      // at full volume inside a fade in.
      if (shouldPlay) {
        await _applyFade(scheduled, position);
        if (_disposed) return;
      }

      if (shouldPlay && (!scheduled.active || jumped)) {
        scheduled.active = true;
        await scheduled.player.seek(position - track.windowStart);
        if (_disposed) return;
        // play() resolves when playback finishes, so awaiting it here would
        // stall the queue for the length of the sound. Left outside the queue
        // deliberately — which also puts it outside the queue's teardown
        // ordering, so a setTracks/dispose landing while it resolves can make
        // it throw. Swallow that the same way syncTo does; there is nothing to
        // recover once the player it targeted is gone.
        unawaited(scheduled.player.play().catchError((Object _) {}));
      } else if (!shouldPlay && scheduled.active) {
        scheduled.active = false;
        await scheduled.player.pause();
        if (_disposed) return;
      }
    }
  }

  /// Sets [scheduled]'s volume to its fade at [position], when that changed.
  Future<void> _applyFade(_ScheduledTrack scheduled, Duration position) async {
    final track = scheduled.track;
    if (!track._hasFade) return;
    final volume =
        track.volume *
        audioFadeGain(
          position: position - track.windowStart,
          length: track.windowEnd - track.windowStart,
          fadeIn: track.fadeIn,
          fadeOut: track.fadeOut,
        );
    if (volume == scheduled.appliedVolume) return;
    scheduled.appliedVolume = volume;
    await scheduled.player.setVolume(volume);
  }

  /// Pauses every sound (preview paused). Positions re-sync on the next
  /// [syncTo].
  Future<void> pauseAll() {
    if (_disposed) return Future<void>.value();
    return _enqueue(_pauseAll);
  }

  Future<void> _pauseAll() async {
    for (final scheduled in _tracks.values.toList()) {
      if (!scheduled.active) continue;
      scheduled.active = false;
      await scheduled.player.pause();
      if (_disposed) return;
    }
  }

  /// Releases every player. The instance cannot be reused afterwards.
  Future<void> dispose() {
    _disposed = true;
    return _enqueue(_disposeAllPlayers);
  }

  Future<void> _disposeAllPlayers() async {
    final players = _tracks.values.map((s) => s.player).toList();
    _tracks.clear();
    for (final player in players) {
      await player.dispose();
    }
  }
}

class _ScheduledTrack {
  _ScheduledTrack({required this.track, required this.player});

  final StopMotionAudioPreviewTrack track;
  final AudioClipPlayer player;

  /// Whether the playhead currently has this sound playing.
  bool active = false;

  /// The volume last sent to [player].
  double? appliedVolume;
}

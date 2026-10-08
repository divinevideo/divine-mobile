// ABOUTME: Overlay widget displaying subtitle text on video playback.
// ABOUTME: Shows verified translation attribution alongside timed caption cues.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/subtitle_providers.dart';
import 'package:openvine/services/subtitle_service.dart';
import 'package:openvine/widgets/caption_pill.dart';

/// Streams playback position into the shared caption pill renderer.
class SubtitleCueStreamPill extends ConsumerStatefulWidget {
  const SubtitleCueStreamPill({
    required this.video,
    required this.positionStream,
    this.initialPosition = Duration.zero,
    super.key,
  });

  final VideoEvent video;
  final Stream<Duration> positionStream;
  final Duration initialPosition;

  @override
  ConsumerState<SubtitleCueStreamPill> createState() =>
      _SubtitleCueStreamPillState();
}

class _SubtitleCueStreamPillState extends ConsumerState<SubtitleCueStreamPill> {
  Stream<_SubtitleCueDisplay>? _displayStream;
  List<SubtitleCue>? _displayStreamCues;
  Stream<Duration>? _displayStreamSource;
  String? _displayStreamVideoId;
  int? _latestPositionMs;

  @override
  void didUpdateWidget(covariant SubtitleCueStreamPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.id != widget.video.id ||
        oldWidget.positionStream != widget.positionStream) {
      _clearDisplayStream();
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = ref.watch(subtitleVisibilityProvider);
    if (!visible || !widget.video.hasSubtitles) {
      _clearDisplayStream();
      return const SizedBox.shrink();
    }

    final cuesAsync = ref.watch(
      _subtitleTrackProvider(
        widget.video,
        Localizations.localeOf(context).languageCode,
      ),
    );

    return cuesAsync.when(
      skipLoadingOnReload: true,
      data: (track) {
        final cues = track.cues;
        final initialPositionMs =
            _latestPositionMs ?? widget.initialPosition.inMilliseconds;
        final initialDisplay = _SubtitleCueDisplayTracker(
          cues,
        ).displayFor(initialPositionMs);

        return StreamBuilder<_SubtitleCueDisplay>(
          key: ObjectKey(cues),
          stream: _displayStreamFor(cues, initialPositionMs),
          initialData: initialDisplay,
          builder: (context, snapshot) {
            final display = snapshot.data ?? const _SubtitleCueDisplay.hidden();
            if (display.text == null) return const SizedBox.shrink();
            return CaptionPill(
              text: display.text!,
              label: track.isMachineTranslated
                  ? context.l10n.subtitleMachineTranslated
                  : null,
            );
          },
        );
      },
      loading: () {
        _clearDisplayStream();
        return const SizedBox.shrink();
      },
      error: (_, _) {
        _clearDisplayStream();
        return const SizedBox.shrink();
      },
    );
  }

  Stream<_SubtitleCueDisplay> _displayStreamFor(
    List<SubtitleCue> cues,
    int initialPositionMs,
  ) {
    final existing = _displayStream;
    if (existing != null &&
        identical(_displayStreamCues, cues) &&
        _displayStreamSource == widget.positionStream &&
        _displayStreamVideoId == widget.video.id) {
      return existing;
    }

    _displayStreamCues = cues;
    _displayStreamSource = widget.positionStream;
    _displayStreamVideoId = widget.video.id;
    return _displayStream = _createDisplayStream(
      cues,
      initialPositionMs,
      widget.positionStream,
    );
  }

  Stream<_SubtitleCueDisplay> _createDisplayStream(
    List<SubtitleCue> cues,
    int initialPositionMs,
    Stream<Duration> positionStream,
  ) async* {
    final tracker = _SubtitleCueDisplayTracker(cues);
    var previousDisplay = tracker.displayFor(initialPositionMs);

    await for (final position in positionStream) {
      final positionMs = position.inMilliseconds;
      _latestPositionMs = positionMs;
      final display = tracker.displayFor(positionMs);
      if (display == previousDisplay) continue;

      previousDisplay = display;
      yield display;
    }
  }

  void _clearDisplayStream() {
    _latestPositionMs = null;
    _displayStream = null;
    _displayStreamCues = null;
    _displayStreamSource = null;
    _displayStreamVideoId = null;
  }
}

SubtitleTrackProvider _subtitleTrackProvider(
  VideoEvent video,
  String appLocaleCode,
) {
  return subtitleTrackProvider(
    videoId: video.id,
    textTrackRef: video.textTrackRef,
    textTrackRefs: video.textTrackRefs,
    textTrackContent: video.textTrackContent,
    sha256: video.sha256,
    sourceLang: video.textTrackLang,
    appLocaleCode: appLocaleCode,
  );
}

@immutable
class _SubtitleCueDisplay {
  const _SubtitleCueDisplay(this.text);

  const _SubtitleCueDisplay.hidden() : text = null;

  final String? text;

  @override
  bool operator ==(Object other) {
    return other is _SubtitleCueDisplay && other.text == text;
  }

  @override
  int get hashCode => text.hashCode;
}

class _SubtitleCueDisplayTracker {
  _SubtitleCueDisplayTracker(this._cues);

  final List<SubtitleCue> _cues;
  SubtitleCue? _lastCue;
  int _prevPositionMs = 0;

  static const _gapBridgeMs = 300;

  _SubtitleCueDisplay displayFor(int positionMs) {
    final currentCue = _findCurrentCue(positionMs);
    final didSeekBackward = positionMs < _prevPositionMs;
    _prevPositionMs = positionMs;

    if (currentCue != null) {
      _lastCue = currentCue;
    } else if (_lastCue != null &&
        (didSeekBackward || positionMs > _lastCue!.end + _gapBridgeMs)) {
      _lastCue = null;
    }

    final displayCue = _lastCue;
    if (displayCue == null) return const _SubtitleCueDisplay.hidden();
    return _SubtitleCueDisplay(displayCue.text);
  }

  SubtitleCue? _findCurrentCue(int positionMs) {
    for (final cue in _cues) {
      if (positionMs >= cue.start && positionMs <= cue.end) {
        return cue;
      }
    }
    return null;
  }
}
